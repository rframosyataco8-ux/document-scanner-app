import '../models/scanned_document.dart';

/// Servicio abstracto listo para conectar con el sistema real.
/// Por ahora funciona en modo local. Cuando tengamos la API,
/// solo implementamos esta interfaz.
abstract class DocumentService {
  Future<List<ScannedDocument>> getAllDocuments();
  Future<void> saveDocument(ScannedDocument document);
  Future<void> deleteDocument(String id);
  Future<ScannedDocument> uploadToSystem(ScannedDocument document);
  Future<void> updateDocument(ScannedDocument document);
}

/// Implementación local (temporal).
/// Más adelante se reemplaza por ApiDocumentService.
class LocalDocumentService implements DocumentService {
  final List<ScannedDocument> _documents = [];

  @override
  Future<List<ScannedDocument>> getAllDocuments() async {
    // Simula un pequeño delay de red
    await Future.delayed(const Duration(milliseconds: 200));
    return List.from(_documents);
  }

  @override
  Future<void> saveDocument(ScannedDocument document) async {
    _documents.insert(0, document);
  }

  @override
  Future<void> deleteDocument(String id) async {
    _documents.removeWhere((d) => d.id == id);
  }

  @override
  Future<void> updateDocument(ScannedDocument document) async {
    final index = _documents.indexWhere((d) => d.id == document.id);
    if (index != -1) {
      _documents[index] = document;
    }
  }

  /// Simula la subida al sistema.
  /// Aquí es donde más adelante pondremos la llamada real a la API.
  @override
  Future<ScannedDocument> uploadToSystem(ScannedDocument document) async {
    // Simulamos tiempo de subida
    await Future.delayed(const Duration(seconds: 2));

    // Aquí iría:
    // final response = await http.post(...)
    // final remoteId = response.data['id'];

    final uploaded = document.copyWith(
      status: DocumentStatus.uploaded,
      remoteId: 'SYS-${DateTime.now().millisecondsSinceEpoch}',
      uploadedAt: DateTime.now().toIso8601String(),
    );

    await updateDocument(uploaded);
    return uploaded;
  }
}
