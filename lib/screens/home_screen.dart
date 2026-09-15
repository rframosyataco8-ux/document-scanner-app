import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_mlkit_document_scanner/google_mlkit_document_scanner.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../models/scanned_document.dart';
import '../services/document_service.dart';
import 'preview_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  final DocumentService _documentService = LocalDocumentService();
  List<ScannedDocument> documents = [];
  bool isScanning = false;
  bool isLoading = true;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);
    _loadDocuments();
  }

  Future<void> _loadDocuments() async {
    final docs = await _documentService.getAllDocuments();
    setState(() {
      documents = docs;
      isLoading = false;
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
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

        await _documentService.saveDocument(newDoc);

        setState(() {
          documents.insert(0, newDoc);
          isScanning = false;
        });

        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => PreviewScreen(
                document: newDoc,
                documentService: _documentService,
                onUpdated: (updated) {
                  setState(() {
                    final index = documents.indexWhere((d) => d.id == updated.id);
                    if (index != -1) documents[index] = updated;
                  });
                },
                onDeleted: () {
                  setState(() => documents.removeWhere((d) => d.id == newDoc.id));
                },
              ),
            ),
          );
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
        child: Column(
          children: [
            // HEADER
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
                        'Listo para conectar con tu sistema',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade500,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: IconButton(
                      onPressed: () {},
                      icon: Icon(Icons.settings_outlined, color: Colors.grey.shade700),
                    ),
                  ),
                ],
              ),
            ),

            // BOTÓN DE ESCANEO
            Expanded(
              flex: documents.isEmpty ? 4 : 2,
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
                      'Documentos • Recibos • Contratos • Identificaciones',
                      style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
                    ),
                  ],
                ),
              ),
            ),

            // LISTA DE DOCUMENTOS
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
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => PreviewScreen(
                                    document: doc,
                                    documentService: _documentService,
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
                            },
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
