import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_document_scanner/google_mlkit_document_scanner.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io';
import 'package:intl/intl.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );
  runApp(const DocumentScannerApp());
}

class DocumentScannerApp extends StatelessWidget {
  const DocumentScannerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DocScan Pro',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2563EB),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        fontFamily: 'Roboto',
        scaffoldBackgroundColor: const Color(0xFFF8FAFC),
      ),
      home: const HomeScreen(),
    );
  }
}

// ─── MODELO DE DOCUMENTO ───
class ScannedDocument {
  final String id;
  final List<String> imagePaths;
  final String? pdfPath;
  final DateTime createdAt;
  final String title;

  ScannedDocument({
    required this.id,
    required this.imagePaths,
    this.pdfPath,
    required this.createdAt,
    required this.title,
  });
}

// ─── PANTALLA PRINCIPAL ───
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  final List<ScannedDocument> documents = [];
  bool isScanning = false;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
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
        pageLimit: 20,
        isGalleryImport: true,
      );

      final documentScanner = DocumentScanner(options: options);
      final result = await documentScanner.scanDocument();

      final images = result.images ?? [];
      final pdf = result.pdf?.uri;

      if (images.isNotEmpty || pdf != null) {
        final now = DateTime.now();
        final newDoc = ScannedDocument(
          id: now.millisecondsSinceEpoch.toString(),
          imagePaths: images,
          pdfPath: pdf,
          createdAt: now,
          title: 'Documento ${DateFormat('dd/MM HH:mm').format(now)}',
        );

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
                onDelete: () {
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red.shade600,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // ── HEADER ──
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 16, 8),
              child: Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'DocScan Pro',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          color: Colors.grey.shade900,
                          letterSpacing: -0.5,
                        ),
                      ),
                      Text(
                        'Escanea. Organiza. Comparte.',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade500,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () {},
                    icon: Icon(Icons.settings_outlined, color: Colors.grey.shade700),
                  ),
                ],
              ),
            ),

            // ── BOTÓN PRINCIPAL DE ESCANEO ──
            Expanded(
              flex: documents.isEmpty ? 3 : 2,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ScaleTransition(
                      scale: Tween(begin: 1.0, end: 1.05).animate(
                        CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
                      ),
                      child: GestureDetector(
                        onTap: isScanning ? null : startScan,
                        child: Container(
                          width: 160,
                          height: 160,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const LinearGradient(
                              colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF3B82F6).withOpacity(0.35),
                                blurRadius: 32,
                                offset: const Offset(0, 14),
                              ),
                            ],
                          ),
                          child: isScanning
                              ? const Center(
                                  child: SizedBox(
                                    width: 42,
                                    height: 42,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 3.5,
                                    ),
                                  ),
                                )
                              : const Icon(
                                  Icons.document_scanner_rounded,
                                  size: 64,
                                  color: Colors.white,
                                ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),
                    Text(
                      isScanning ? 'Escaneando documento...' : 'Toca para escanear',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Colors.grey.shade800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Documentos • Recibos • Contratos • IDs',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── LISTA DE DOCUMENTOS ──
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
                            'Documentos recientes',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Colors.grey.shade800,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            '${documents.length}',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
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
                                    onDelete: () {
                                      setState(() => documents.removeWhere((d) => d.id == doc.id));
                                      Navigator.pop(context);
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

// ─── CARD DE DOCUMENTO ───
class _DocumentCard extends StatelessWidget {
  final ScannedDocument document;
  final VoidCallback onTap;

  const _DocumentCard({required this.document, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            // Miniatura
            Container(
              width: 56,
              height: 72,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: Colors.grey.shade100,
                border: Border.all(color: Colors.grey.shade200),
                image: document.imagePaths.isNotEmpty
                    ? Decoration.file(
                        File(document.imagePaths.first),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              child: document.imagePaths.isEmpty
                  ? Icon(Icons.picture_as_pdf_rounded, color: Colors.red.shade400, size: 28)
                  : null,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    document.title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${document.imagePaths.length} página${document.imagePaths.length != 1 ? 's' : ''} • ${DateFormat('dd MMM yyyy • HH:mm').format(document.createdAt)}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade500,
                    ),
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

// ─── PANTALLA DE VISTA PREVIA ───
class PreviewScreen extends StatelessWidget {
  final ScannedDocument document;
  final VoidCallback onDelete;

  const PreviewScreen({
    super.key,
    required this.document,
    required this.onDelete,
  });

  Future<void> _shareDocument() async {
    if (document.pdfPath != null) {
      await Share.shareXFiles([XFile(document.pdfPath!)], text: document.title);
    } else if (document.imagePaths.isNotEmpty) {
      await Share.shareXFiles(
        document.imagePaths.map((p) => XFile(p)).toList(),
        text: document.title,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(
          document.title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        actions: [
          IconButton(
            onPressed: () {
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Eliminar documento'),
                  content: const Text('¿Estás seguro de que quieres eliminar este documento?'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
                    TextButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        onDelete();
                        Navigator.pop(context);
                      },
                      child: const Text('Eliminar', style: TextStyle(color: Colors.red)),
                    ),
                  ],
                ),
              );
            },
            icon: const Icon(Icons.delete_outline_rounded),
          ),
        ],
      ),
      body: Column(
        children: [
          // Imágenes del documento
          Expanded(
            child: document.imagePaths.isEmpty
                ? const Center(
                    child: Icon(Icons.picture_as_pdf_rounded, size: 80, color: Colors.white54),
                  )
                : PageView.builder(
                    itemCount: document.imagePaths.length,
                    itemBuilder: (context, index) {
                      return InteractiveViewer(
                        child: Center(
                          child: Image.file(
                            File(document.imagePaths[index]),
                            fit: BoxFit.contain,
                          ),
                        ),
                      );
                    },
                  ),
          ),

          // Barra de acciones inferior
          Container(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            decoration: BoxDecoration(
              color: Colors.grey.shade900,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              children: [
                // Indicador de páginas
                if (document.imagePaths.length > 1)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Text(
                      '${document.imagePaths.length} páginas',
                      style: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                    ),
                  ),

                Row(
                  children: [
                    // Compartir
                    Expanded(
                      child: _ActionButton(
                        icon: Icons.ios_share_rounded,
                        label: 'Compartir',
                        color: Colors.blue.shade400,
                        onTap: _shareDocument,
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Subir al sistema (preparado para el futuro)
                    Expanded(
                      child: _ActionButton(
                        icon: Icons.cloud_upload_rounded,
                        label: 'Subir al sistema',
                        color: Colors.green.shade400,
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: const Text('Próximamente: conexión al sistema'),
                              backgroundColor: Colors.green.shade700,
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 26),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
