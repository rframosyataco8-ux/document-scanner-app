import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import '../models/scanned_document.dart';
import 'document_service.dart';

/// Cola offline: reintenta automáticamente cuando vuelve la red.
class UploadQueue {
  UploadQueue._();
  static final UploadQueue instance = UploadQueue._();

  final DocumentService _service = LocalDocumentService();
  StreamSubscription<List<ConnectivityResult>>? _sub;
  bool _processing = false;
  bool _started = false;

  final _events = StreamController<UploadQueueEvent>.broadcast();
  Stream<UploadQueueEvent> get events => _events.stream;

  static const int maxRetries = 8;

  Future<void> start() async {
    if (_started) return;
    _started = true;

    _sub = Connectivity().onConnectivityChanged.listen((results) {
      final online = results.any((r) =>
          r == ConnectivityResult.wifi ||
          r == ConnectivityResult.mobile ||
          r == ConnectivityResult.ethernet);
      if (online) {
        processQueue();
      }
    });

    // Primer intento al arrancar
    unawaited(processQueue());
  }

  void dispose() {
    _sub?.cancel();
    _sub = null;
    _started = false;
  }

  /// Marca documento en cola (meta ya guardada).
  Future<ScannedDocument> enqueue(ScannedDocument doc) async {
    final queued = doc.copyWith(
      status: DocumentStatus.queued,
      lastError: 'En cola — se subirá al recuperar la red',
      clearError: false,
    );
    await _service.updateDocument(queued);
    _events.add(UploadQueueEvent(type: UploadQueueEventType.enqueued, document: queued));
    unawaited(processQueue());
    return queued;
  }

  Future<void> processQueue() async {
    if (_processing) return;
    _processing = true;

    try {
      final connectivity = await Connectivity().checkConnectivity();
      final online = connectivity.any((r) =>
          r == ConnectivityResult.wifi ||
          r == ConnectivityResult.mobile ||
          r == ConnectivityResult.ethernet);
      if (!online) {
        debugPrint('[UploadQueue] sin red, esperando…');
        return;
      }

      final docs = await _service.getAllDocuments();
      final pending = docs.where((d) {
        if (!d.hasGuiaMeta) return false;
        if (d.pdfPath == null) return false;
        if (d.status == DocumentStatus.queued) return true;
        // Reintento suave de errores de red
        if (d.status == DocumentStatus.error &&
            d.retryCount < maxRetries &&
            _looksLikeNetworkError(d.lastError)) {
          return true;
        }
        return false;
      }).toList();

      if (pending.isEmpty) return;

      _events.add(UploadQueueEvent(
        type: UploadQueueEventType.processing,
        message: 'Procesando ${pending.length} guía(s) en cola…',
      ));

      for (final doc in pending) {
        try {
          final result = await _service.uploadToSystem(doc, meta: doc.metaMap);
          _events.add(UploadQueueEvent(
            type: UploadQueueEventType.success,
            document: result,
            message: 'Subida: ${result.numeroGuia ?? result.title}',
          ));
        } catch (e) {
          final msg = e.toString().replaceFirst('Exception: ', '');
          final failed = doc.copyWith(
            status: _looksLikeNetworkError(msg)
                ? DocumentStatus.queued
                : DocumentStatus.error,
            lastError: msg,
            retryCount: doc.retryCount + 1,
          );
          await _service.updateDocument(failed);
          _events.add(UploadQueueEvent(
            type: UploadQueueEventType.failure,
            document: failed,
            message: msg,
          ));

          // Si es auth, no seguir con el resto
          if (msg.contains('Sesión') || msg.contains('sesión')) break;
        }
      }
    } finally {
      _processing = false;
    }
  }

  bool _looksLikeNetworkError(String? msg) {
    if (msg == null) return true;
    final m = msg.toLowerCase();
    return m.contains('socket') ||
        m.contains('network') ||
        m.contains('connection') ||
        m.contains('timeout') ||
        m.contains('failed host') ||
        m.contains('unreachable') ||
        m.contains('timed out') ||
        m.contains('cliente') ||
        m.contains('red');
  }
}

enum UploadQueueEventType { enqueued, processing, success, failure }

class UploadQueueEvent {
  final UploadQueueEventType type;
  final ScannedDocument? document;
  final String? message;

  UploadQueueEvent({required this.type, this.document, this.message});
}
