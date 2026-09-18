import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_mlkit_document_scanner/google_mlkit_document_scanner.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../models/scanned_document.dart';
import '../services/api_config.dart';
import '../services/document_service.dart';
import 'preview_screen.dart';
import 'qr_pair_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  final DocumentService _service = LocalDocumentService();
  List<ScannedDocument> documents = [];
  bool isScanning = false;
  bool isLoading = true;
  bool isPaired = false;
  String? pairedName;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);
    _loadDocuments();
    _checkPair();
  }

  Future<void> _checkPair() async {
    final paired = await ApiConfig.isPaired();
    final user = await ApiConfig.getUser();
    if (!mounted) return;
    setState(() {
      isPaired = paired;
      pairedName = user?['nombre']?.toString() ?? user?['username']?.toString();
    });
  }

  Future<void> _loadDocuments() async {
    final docs = await _service.getAllDocuments();
    if (mounted) {
      setState(() {
        documents = docs;
        isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _openQrPair() async {
    final ok = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const QrPairScreen()),
    );
    if (ok == true) {
      await _checkPair();
    }
  }

  Future<void> startScan() async {
    if (isScanning) return;
    setState(() => isScanning = true);

    try {
      final options = DocumentScannerOptions(
        documentFormats: {DocumentFormat.jpeg, DocumentFormat.pdf},
        mode: ScannerMode.full,
        pageLimit: 30,
        isGalleryImport: true,
      );

      final scanner = DocumentScanner(options: options);
      final result = await scanner.scanDocument();

      final images = result.images ?? [];
      final pdf = result.pdf?.uri;

      if (images.isNotEmpty || pdf != null) {
        final now = DateTime.now();
        final newDoc = ScannedDocument(
          id: const Uuid().v4(),
          title: 'Documento ${DateFormat('dd/MM/yyyy HH:mm').format(now)}',
          imagePaths: images,
          pdfPath: pdf,
          createdAt: now,
        );

        await _service.saveDocument(newDoc);

        setState(() {
          documents.insert(0, newDoc);
          isScanning = false;
        });

        if (mounted) {
          _openPreview(newDoc);
        }
      } else {
        setState(() => isScanning = false);
      }
    } catch (e) {
      setState(() => isScanning = false);
      if (mounted) {
        _showSnack('Error al escanear: $e', isError: true);
      }
    }
  }

  void _openPreview(ScannedDocument doc) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PreviewScreen(
          document: doc,
          documentService: _service,
          onUpdated: (updated) {
            setState(() {
              final i = documents.indexWhere((d) => d.id == updated.id);
              if (i != -1) documents[i] = updated;
            });
          },
          onDeleted: () {
            setState(() => documents.removeWhere((d) => d.id == doc.id));
          },
        ),
      ),
    );
  }

  void _showSnack(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red.shade600 : Colors.green.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: isLoading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 20, 16, 8),
                    child: Row(
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'DocScan Pro',
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w800,
                                color: Colors.grey.shade900,
                                letterSpacing: -0.8,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              isPaired
                                  ? 'Conectado · ${pairedName ?? 'usuario'}'
                                  : 'Escanea el QR para conectar',
                              style: TextStyle(
                                fontSize: 13,
                                color: isPaired ? Colors.green.shade700 : Colors.grey.shade500,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        const Spacer(),
                        IconButton(
                          onPressed: _openQrPair,
                          tooltip: 'Conectar con QR',
                          icon: Icon(
                            isPaired ? Icons.qr_code_2 : Icons.qr_code_scanner,
                            color: isPaired ? Colors.green.shade700 : Colors.grey.shade700,
                          ),
                        ),
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: IconButton(
                            onPressed: () async {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const SettingsScreen()),
                              );
                              await _checkPair();
                            },
                            icon: Icon(Icons.settings_outlined, color: Colors.grey.shade700),
                          ),
                        ),
                      ],
                    ),
                  ),

                  if (!isPaired)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      child: Material(
                        color: const Color(0xFF126044).withOpacity(0.08),
                        borderRadius: BorderRadius.circular(14),
                        child: InkWell(
                          onTap: _openQrPair,
                          borderRadius: BorderRadius.circular(14),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            child: Row(
                              children: [
                                Icon(Icons.qr_code_scanner, color: Colors.green.shade800),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Conectar al sistema',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                          color: Colors.green.shade900,
                                        ),
                                      ),
                                      Text(
                                        'Escanea el QR de Conectar móvil',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.green.shade700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Icon(Icons.chevron_right, color: Colors.green.shade700),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),

                  Expanded(
                    flex: documents.isEmpty ? 5 : 2,
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          ScaleTransition(
                            scale: Tween(begin: 1.0, end: 1.06).animate(
                              CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
                            ),
                            child: GestureDetector(
                              onTap: isScanning ? null : startScan,
                              child: Container(
                                width: 168,
                                height: 168,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: const LinearGradient(
                                    colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFF3B82F6).withOpacity(0.4),
                                      blurRadius: 36,
                                      offset: const Offset(0, 16),
                                    ),
                                  ],
                                ),
                                child: isScanning
                                    ? const Center(
                                        child: SizedBox(
                                          width: 44,
                                          height: 44,
                                          child: CircularProgressIndicator(
                                            color: Colors.white,
                                            strokeWidth: 3.5,
                                          ),
                                        ),
                                      )
                                    : const Icon(
                                        Icons.document_scanner_rounded,
                                        size: 68,
                                        color: Colors.white,
                                      ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 28),
                          Text(
                            isScanning ? 'Escaneando...' : 'Toca para escanear',
                            style: TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.w700,
                              color: Colors.grey.shade800,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Guías de cacao • PDF profesional',
                            style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
                          ),
                        ],
                      ),
                    ),
                  ),

                  if (documents.isNotEmpty)
                    Expanded(
                      flex: 3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
                            child: Row(
                              children: [
                                Text(
                                  'Mis documentos',
                                  style: TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.grey.shade800,
                                  ),
                                ),
                                const Spacer(),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.shade50,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    '${documents.length}',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.blue.shade700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            child: ListView.builder(
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
                              itemCount: documents.length,
                              itemBuilder: (context, index) {
                                final doc = documents[index];
                                return _DocumentCard(
                                  document: doc,
                                  onTap: () => _openPreview(doc),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
      ),
    );
  }
}

class _DocumentCard extends StatelessWidget {
  final ScannedDocument document;
  final VoidCallback onTap;

  const _DocumentCard({required this.document, required this.onTap});

  Color get statusColor {
    switch (document.status) {
      case DocumentStatus.local:
        return Colors.grey;
      case DocumentStatus.uploading:
        return Colors.orange;
      case DocumentStatus.uploaded:
        return Colors.green;
      case DocumentStatus.error:
        return Colors.red;
    }
  }

  String get statusText {
    switch (document.status) {
      case DocumentStatus.local:
        return 'En el dispositivo';
      case DocumentStatus.uploading:
        return 'Subiendo...';
      case DocumentStatus.uploaded:
        return 'En el sistema';
      case DocumentStatus.error:
        return 'Error al subir';
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 14,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 58,
              height: 74,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: Colors.grey.shade100,
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: document.imagePaths.isNotEmpty
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(11),
                      child: Image.file(
                        File(document.imagePaths.first),
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Icon(
                          Icons.broken_image_outlined,
                          color: Colors.grey.shade400,
                        ),
                      ),
                    )
                  : Icon(Icons.picture_as_pdf_rounded, color: Colors.red.shade400, size: 30),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    document.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade900,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    '${document.imagePaths.length} pág. • ${DateFormat('dd MMM yyyy').format(document.createdAt)}',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: statusColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        statusText,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: statusColor,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: Colors.grey.shade400),
          ],
        ),
      ),
    );
  }
}
