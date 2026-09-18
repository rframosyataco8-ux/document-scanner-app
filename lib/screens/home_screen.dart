import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_mlkit_document_scanner/google_mlkit_document_scanner.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../models/scanned_document.dart';
import '../services/api_config.dart';
import '../services/document_service.dart';
import '../services/upload_queue.dart';
import '../theme/app_theme.dart';
import 'preview_screen.dart';
import 'qr_pair_screen.dart';
import 'settings_screen.dart';

enum _Filter { all, local, queued, uploaded, error }

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
  _Filter filter = _Filter.all;
  late AnimationController _pulseController;
  StreamSubscription<UploadQueueEvent>? _queueSub;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);
    _bootstrap();
    _queueSub = UploadQueue.instance.events.listen((ev) {
      if (ev.document != null) {
        setState(() {
          final i = documents.indexWhere((d) => d.id == ev.document!.id);
          if (i != -1) documents[i] = ev.document!;
        });
      }
      if (ev.type == UploadQueueEventType.success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ev.message ?? 'Guía subida desde la cola'),
            backgroundColor: Colors.green.shade700,
          ),
        );
      }
    });
  }

  Future<void> _bootstrap() async {
    await Future.wait([_loadDocuments(), _checkPair()]);
    await UploadQueue.instance.processQueue();
    await _loadDocuments();
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

  int get queuedCount =>
      documents.where((d) => d.status == DocumentStatus.queued).length;

  List<ScannedDocument> get filtered {
    switch (filter) {
      case _Filter.local:
        return documents
            .where((d) =>
                d.status == DocumentStatus.local || d.status == DocumentStatus.uploading)
            .toList();
      case _Filter.queued:
        return documents.where((d) => d.status == DocumentStatus.queued).toList();
      case _Filter.uploaded:
        return documents.where((d) => d.status == DocumentStatus.uploaded).toList();
      case _Filter.error:
        return documents.where((d) => d.status == DocumentStatus.error).toList();
      case _Filter.all:
        return documents;
    }
  }

  @override
  void dispose() {
    _queueSub?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _openQrPair() async {
    final ok = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const QrPairScreen()),
    );
    if (ok == true) await _checkPair();
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

        if (mounted) _openPreview(newDoc);
      } else {
        setState(() => isScanning = false);
      }
    } catch (e) {
      setState(() => isScanning = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al escanear: $e'),
            backgroundColor: Colors.red.shade600,
          ),
        );
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

  @override
  Widget build(BuildContext context) {
    final list = filtered;

    return Scaffold(
      body: SafeArea(
        child: isLoading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                color: RomexColors.primary,
                onRefresh: () async {
                  await UploadQueue.instance.processQueue();
                  await _loadDocuments();
                  await _checkPair();
                },
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    SliverToBoxAdapter(child: _buildHeader()),
                    if (!isPaired) const SliverToBoxAdapter(child: _PairBanner()),
                    if (queuedCount > 0)
                      SliverToBoxAdapter(child: _QueueBanner(count: queuedCount)),
                    SliverToBoxAdapter(child: _buildScanButton()),
                    if (documents.isNotEmpty) ...[
                      SliverToBoxAdapter(child: _buildFilters()),
                      if (list.isEmpty)
                        const SliverToBoxAdapter(
                          child: Padding(
                            padding: EdgeInsets.all(32),
                            child: Center(child: Text('No hay documentos en este filtro')),
                          ),
                        )
                      else
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
                          sliver: SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (context, index) {
                                final doc = list[index];
                                return _DocumentCard(
                                  document: doc,
                                  onTap: () => _openPreview(doc),
                                );
                              },
                              childCount: list.length,
                            ),
                          ),
                        ),
                    ] else
                      const SliverFillRemaining(
                        hasScrollBody: false,
                        child: Center(
                          child: Padding(
                            padding: EdgeInsets.all(24),
                            child: Text(
                              'Aún no hay documentos. Toca el botón para escanear una guía.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: RomexColors.textMuted),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 12, 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'DocScan Pro',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: Colors.grey.shade900,
                    letterSpacing: -0.6,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  isPaired
                      ? 'Conectado · ${pairedName ?? 'usuario'}'
                      : 'Escanea el QR para conectar',
                  style: TextStyle(
                    fontSize: 13,
                    color: isPaired ? RomexColors.primary : Colors.grey.shade500,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: _openQrPair,
            tooltip: 'Conectar con QR',
            icon: Icon(
              isPaired ? Icons.qr_code_2 : Icons.qr_code_scanner,
              color: isPaired ? RomexColors.primary : Colors.grey.shade700,
            ),
          ),
          IconButton(
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
              await _checkPair();
            },
            icon: Icon(Icons.settings_outlined, color: Colors.grey.shade700),
          ),
        ],
      ),
    );
  }

  Widget _buildScanButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Column(
        children: [
          ScaleTransition(
            scale: Tween(begin: 1.0, end: 1.05).animate(
              CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
            ),
            child: GestureDetector(
              onTap: isScanning ? null : startScan,
              child: Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [RomexColors.primaryLight, RomexColors.primaryDark],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: RomexColors.primary.withOpacity(0.35),
                      blurRadius: 28,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: isScanning
                    ? const Center(
                        child: SizedBox(
                          width: 40,
                          height: 40,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3),
                        ),
                      )
                    : const Icon(Icons.document_scanner_rounded, size: 58, color: Colors.white),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            isScanning ? 'Escaneando...' : 'Toca para escanear',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: Colors.grey.shade800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Guías de cacao · PDF profesional',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
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
                  color: RomexColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${documents.length}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: RomexColors.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _chip('Todos', _Filter.all),
                _chip('Local', _Filter.local),
                _chip('En cola', _Filter.queued),
                _chip('Subidos', _Filter.uploaded),
                _chip('Error', _Filter.error),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(String label, _Filter f) {
    final selected = filter == f;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => setState(() => filter = f),
        selectedColor: RomexColors.primary.withOpacity(0.18),
        checkmarkColor: RomexColors.primary,
        labelStyle: TextStyle(
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          color: selected ? RomexColors.primaryDark : Colors.grey.shade700,
          fontSize: 13,
        ),
      ),
    );
  }
}

class _QueueBanner extends StatelessWidget {
  final int count;
  const _QueueBanner({required this.count});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Material(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: () => UploadQueue.instance.processQueue(),
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Icon(Icons.cloud_queue, color: Colors.orange.shade800),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '$count guía(s) en cola offline — toca para reintentar',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.orange.shade900,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PairBanner extends StatelessWidget {
  const _PairBanner();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Material(
        color: RomexColors.primary.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const QrPairScreen()),
            );
          },
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                const Icon(Icons.qr_code_scanner, color: RomexColors.primaryDark),
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
                        style: TextStyle(fontSize: 12, color: Colors.green.shade700),
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
      case DocumentStatus.queued:
        return Colors.deepOrange;
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
      case DocumentStatus.queued:
        return 'En cola offline';
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
          border: Border.all(color: RomexColors.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 12,
              offset: const Offset(0, 4),
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
                    '${document.imagePaths.length} pag. · ${DateFormat('dd MMM yyyy').format(document.createdAt)}'
                    '${document.zona != null ? ' · ${document.zona}' : ''}',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          (document.status == DocumentStatus.error ||
                                      document.status == DocumentStatus.queued) &&
                                  document.lastError != null
                              ? document.lastError!
                              : statusText,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: statusColor,
                          ),
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
