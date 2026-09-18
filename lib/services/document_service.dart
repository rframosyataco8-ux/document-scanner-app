import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/scanned_document.dart';
import 'api_config.dart';

abstract class DocumentService {
  Future<List<ScannedDocument>> getAllDocuments();
  Future<void> saveDocument(ScannedDocument document);
  Future<void> deleteDocument(String id);
  Future<void> updateDocument(ScannedDocument document);
  Future<ScannedDocument> uploadToSystem(
    ScannedDocument document, {
    required Map<String, String> meta,
    bool enqueueOnNetworkError = true,
  });
}

class LocalDocumentService implements DocumentService {
  static const _storageKey = 'scanned_documents_v2';

  Future<SharedPreferences> get _prefs async => SharedPreferences.getInstance();

  @override
  Future<List<ScannedDocument>> getAllDocuments() async {
    final prefs = await _prefs;
    final raw = prefs.getStringList(_storageKey) ?? [];
    if (raw.isEmpty) {
      final legacy = prefs.getStringList('scanned_documents') ?? [];
      if (legacy.isNotEmpty) {
        await prefs.setStringList(_storageKey, legacy);
        return legacy
            .map((e) => ScannedDocument.fromJson(jsonDecode(e) as Map<String, dynamic>))
            .toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      }
    }
    return raw
        .map((e) => ScannedDocument.fromJson(jsonDecode(e) as Map<String, dynamic>))
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  @override
  Future<void> saveDocument(ScannedDocument document) async {
    final docs = await getAllDocuments();
    docs.insert(0, document);
    await _persist(docs);
  }

  @override
  Future<void> deleteDocument(String id) async {
    final docs = await getAllDocuments();
    docs.removeWhere((d) => d.id == id);
    await _persist(docs);
  }

  @override
  Future<void> updateDocument(ScannedDocument document) async {
    final docs = await getAllDocuments();
    final index = docs.indexWhere((d) => d.id == document.id);
    if (index != -1) {
      docs[index] = document;
      await _persist(docs);
    }
  }

  bool _isNetworkError(Object e) {
    final m = e.toString().toLowerCase();
    return m.contains('socket') ||
        m.contains('network') ||
        m.contains('connection') ||
        m.contains('timeout') ||
        m.contains('failed host') ||
        m.contains('unreachable') ||
        m.contains('timed out') ||
        m.contains('clientexception') ||
        m.contains('handshake');
  }

  @override
  Future<ScannedDocument> uploadToSystem(
    ScannedDocument document, {
    required Map<String, String> meta,
    bool enqueueOnNetworkError = true,
  }) async {
    final token = await ApiConfig.getToken();
    if (token == null || token.isEmpty) {
      throw Exception('No hay sesión. Escanea el QR de "Conectar móvil" primero.');
    }

    final pdfPath = document.pdfPath;
    if (pdfPath == null || !File(pdfPath).existsSync()) {
      throw Exception('No hay PDF disponible. Escanea de nuevo generando PDF.');
    }

    final numero = meta['numero_guia']?.trim() ?? '';
    final zona = meta['zona']?.trim() ?? '';
    final fecha = meta['fecha_recepcion']?.trim() ?? '';
    if (numero.isEmpty || zona.isEmpty || fecha.isEmpty) {
      throw Exception('Número de guía, zona y fecha son obligatorios.');
    }

    var working = document.copyWith(
      status: DocumentStatus.uploading,
      clearError: true,
      numeroGuia: numero,
      zona: zona,
      fechaRecepcion: fecha,
      cantidadSacos: meta['cantidad_sacos']?.trim(),
      kilos: meta['kilos']?.trim(),
      title: numero,
    );
    await updateDocument(working);

    final baseUrl = await ApiConfig.getBaseUrl();
    final uri = Uri.parse('$baseUrl/api/guias');

    final request = http.MultipartRequest('POST', uri);
    request.headers['Authorization'] = 'Bearer $token';
    request.headers['Accept'] = 'application/json';

    request.fields['numero_guia'] = numero;
    request.fields['zona'] = zona;
    request.fields['fecha_recepcion'] = fecha;
    if ((meta['cantidad_sacos'] ?? '').trim().isNotEmpty) {
      request.fields['cantidad_sacos'] = meta['cantidad_sacos']!.trim();
    }
    if ((meta['kilos'] ?? '').trim().isNotEmpty) {
      request.fields['kilos'] = meta['kilos']!.trim();
    }

    request.files.add(await http.MultipartFile.fromPath(
      'archivo',
      pdfPath,
      filename: 'guia_${numero.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_')}.pdf',
    ));

    try {
      final streamed = await request.send().timeout(const Duration(seconds: 90));
      final response = await http.Response.fromStream(streamed);
      final body = _tryJson(response.body);

      if (response.statusCode == 201 || response.statusCode == 200) {
        final guia = body['guia'] as Map<String, dynamic>?;
        final remoteId =
            guia != null ? '${guia['id']}' : 'OK-${DateTime.now().millisecondsSinceEpoch}';

        final uploaded = working.copyWith(
          status: DocumentStatus.uploaded,
          remoteId: remoteId,
          uploadedAt: DateTime.now(),
          clearError: true,
          retryCount: 0,
        );
        await updateDocument(uploaded);
        return uploaded;
      }

      if (response.statusCode == 401 || response.statusCode == 403) {
        await ApiConfig.clearSession();
        final msg = body['error'] as String? ?? 'Sesión expirada. Vuelve a escanear el QR.';
        final failed = working.copyWith(status: DocumentStatus.error, lastError: msg);
        await updateDocument(failed);
        throw Exception(msg);
      }

      // 409 conflicto = error de negocio, no reencolar
      final msg = body['error'] as String? ?? 'Error al subir la guía (${response.statusCode})';
      final failed = working.copyWith(status: DocumentStatus.error, lastError: msg);
      await updateDocument(failed);
      throw Exception(msg);
    } catch (e) {
      if (e is Exception && e.toString().contains('Sesión expirada')) rethrow;

      final msg = e.toString().replaceFirst('Exception: ', '');

      if (enqueueOnNetworkError && _isNetworkError(e)) {
        final queued = working.copyWith(
          status: DocumentStatus.queued,
          lastError: 'Sin red — en cola automática (intento ${working.retryCount + 1})',
          retryCount: working.retryCount + 1,
        );
        await updateDocument(queued);
        throw Exception(
          'Sin conexión. La guía quedó en cola y se subirá automáticamente.',
        );
      }

      final failed = working.copyWith(
        status: DocumentStatus.error,
        lastError: msg,
        retryCount: working.retryCount + 1,
      );
      await updateDocument(failed);
      rethrow;
    }
  }

  Future<void> _persist(List<ScannedDocument> docs) async {
    final prefs = await _prefs;
    final raw = docs.map((d) => jsonEncode(d.toJson())).toList();
    await prefs.setStringList(_storageKey, raw);
  }

  Map<String, dynamic> _tryJson(String raw) {
    try {
      final v = jsonDecode(raw);
      if (v is Map<String, dynamic>) return v;
    } catch (_) {}
    return {};
  }
}
