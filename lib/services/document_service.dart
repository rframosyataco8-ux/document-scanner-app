import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/scanned_document.dart';

/// Interfaz limpia.
/// Cuando conectemos PostgreSQL + API, solo creamos
/// una nueva clase que implemente esto.
abstract class DocumentService {
  Future<List<ScannedDocument>> getAllDocuments();
  Future<void> saveDocument(ScannedDocument document);
  Future<void> deleteDocument(String id);
  Future<void> updateDocument(ScannedDocument document);
  Future<ScannedDocument> uploadToSystem(ScannedDocument document);
}

/// Implementación local con persistencia real.
/// Los documentos sobreviven al cerrar la app.
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

  /// Simula la subida al sistema.
  /// Aquí es donde más adelante pondremos la llamada real a la API + PostgreSQL.
  @override
  Future<ScannedDocument> uploadToSystem(ScannedDocument document) async {
    // Simulamos el tiempo de red
    await Future.delayed(const Duration(seconds: 2));

    // ======================================================
    // AQUÍ IRÁ LA CONEXIÓN REAL:
    //
    // final response = await http.post(
    //   Uri.parse('https://tu-api.com/documents'),
    //   headers: {'Authorization': 'Bearer $token'},
    //   body: {...}
    // );
    //
    // El backend guardará en PostgreSQL y devolverá el id.
    // ======================================================

    final uploaded = document.copyWith(
      status: DocumentStatus.uploaded,
      remoteId: 'PG-${DateTime.now().millisecondsSinceEpoch}',
      uploadedAt: DateTime.now(),
    );

    await updateDocument(uploaded);
    return uploaded;
  }

  Future<void> _persist(List<ScannedDocument> docs) async {
    final prefs = await _prefs;
    final raw = docs.map((d) => jsonEncode(d.toJson())).toList();
    await prefs.setStringList(_storageKey, raw);
  }
}
