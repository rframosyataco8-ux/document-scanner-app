import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/scanned_document.dart';
import 'api_config.dart';

/// Interfaz limpia.
abstract class DocumentService {
  Future<List<ScannedDocument>> getAllDocuments();
  Future<void> saveDocument(ScannedDocument document);
  Future<void> deleteDocument(String id);
  Future<void> updateDocument(ScannedDocument document);

  /// Sube al Sistema de Guías (RomEx).
  /// [meta] debe contener: numero_guia, zona, fecha_recepcion
  /// y opcionalmente cantidad_sacos, kilos.
  Future<ScannedDocument> uploadToSystem(
    ScannedDocument document, {
    required Map<String, String> meta,
  });
}

/// Implementación local + subida real al API cuando hay sesión QR.
class LocalDocumentService implements DocumentService {
  static const _storageKey = 'scanned_documents';

  Future<SharedPreferences> get _prefs async => SharedPreferences.getInstance();

  @override
  Future<List<ScannedDocument>> getAllDocuments() async {
    final prefs = await _prefs;
    final raw = prefs.getStringList(_storageKey) ?? [];
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

  @override
  Future<ScannedDocument> uploadToSystem(
    ScannedDocument document, {
    required Map<String, String> meta,
  }) async {
    final token = await ApiConfig.getToken();
    if (token == null || token.isEmpty) {
      throw Exception('No hay sesión. Escanea el QR de "Conectar móvil" primero.');
    }

    final pdfPath = document.pdfPath;
    if (pdfPath == null || !File(pdfPath).existsSync()) {
      throw Exception('No hay PDF disponible. Escanea de nuevo generando PDF.');
    }

    final baseUrl = await ApiConfig.getBaseUrl();
    final uri = Uri.parse('$baseUrl/api/guias');

    final request = http.MultipartRequest('POST', uri);
    request.headers['Authorization'] = 'Bearer $token';
    request.headers['Accept'] = 'application/json';

    request.fields['numero_guia'] = meta['numero_guia']?.trim() ?? '';
    request.fields['zona'] = meta['zona']?.trim() ?? '';
    request.fields['fecha_recepcion'] = meta['fecha_recepcion']?.trim() ?? '';
    if ((meta['cantidad_sacos'] ?? '').isNotEmpty) {
      request.fields['cantidad_sacos'] = meta['cantidad_sacos']!;
    }
    if ((meta['kilos'] ?? '').isNotEmpty) {
      request.fields['kilos'] = meta['kilos']!;
    }

    request.files.add(await http.MultipartFile.fromPath(
      'archivo',
      pdfPath,
      filename: 'guia_${document.id}.pdf',
    ));

    final streamed = await request.send().timeout(const Duration(seconds: 60));
    final response = await http.Response.fromStream(streamed);
    final body = _tryJson(response.body);

    if (response.statusCode == 201 || response.statusCode == 200) {
      final guia = body['guia'] as Map<String, dynamic>?;
      final remoteId = guia != null ? '${guia['id']}' : 'OK-${DateTime.now().millisecondsSinceEpoch}';

      final uploaded = document.copyWith(
        status: DocumentStatus.uploaded,
        remoteId: remoteId,
        uploadedAt: DateTime.now(),
        title: meta['numero_guia']?.isNotEmpty == true
            ? meta['numero_guia']!
            : document.title,
      );
      await updateDocument(uploaded);
      return uploaded;
    }

    final msg = body['error'] as String? ?? 'Error al subir la guía (${response.statusCode})';
    throw Exception(msg);
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
