import 'dart:io';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../models/scanned_document.dart';
import '../services/api_config.dart';
import '../services/document_service.dart';
import '../theme/app_theme.dart';
import 'qr_pair_screen.dart';
import 'upload_guia_screen.dart';

class PreviewScreen extends StatefulWidget {
  final ScannedDocument document;
  final DocumentService documentService;
  final Function(ScannedDocument) onUpdated;
  final VoidCallback onDeleted;

  const PreviewScreen({
    super.key,
    required this.document,
    required this.documentService,
    required this.onUpdated,
    required this.onDeleted,
  });

  @override
  State<PreviewScreen> createState() => _PreviewScreenState();
}

class _PreviewScreenState extends State<PreviewScreen> {
  late ScannedDocument document;

  @override
  void initState() {
    super.initState();
    document = widget.document;
  }

  Future<void> _share() async {
    if (document.pdfPath != null) {
      await Share.shareXFiles([XFile(document.pdfPath!)], text: document.title);
    } else if (document.imagePaths.isNotEmpty) {
      await Share.shareXFiles(
        document.imagePaths.map((p) => XFile(p)).toList(),
        text: document.title,
      );
    }
  }

  Future<void> _uploadToSystem() async {
    if (document.status == DocumentStatus.uploaded) return;

    final paired = await ApiConfig.isPaired();
    if (!paired) {
      if (!mounted) return;
      final go = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Sin sesion'),
          content: const Text('Debes escanear el QR de Conectar movil antes de subir.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Escanear QR')),
          ],
        ),
      );
      if (go == true && mounted) {
        final ok = await Navigator.push<bool>(
          context,
          MaterialPageRoute(builder: (_) => const QrPairScreen()),
        );
        if (ok != true) return;
      } else {
        return;
      }
    }

    if (document.pdfPath == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Este documento no tiene PDF. Escanea de nuevo con formato PDF.'),
        ),
      );
      return;
    }

    final updated = await Navigator.push<ScannedDocument>(
      context,
      MaterialPageRoute(
        builder: (_) => UploadGuiaScreen(
          document: document,
          documentService: widget.documentService,
        ),
      ),
    );

    if (updated != null && mounted) {
      setState(() => document = updated);
      widget.onUpdated(updated);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            updated.status == DocumentStatus.uploaded
                ? 'Guia subida al sistema'
                : (updated.lastError ?? 'Revisa el estado'),
          ),
          backgroundColor: updated.status == DocumentStatus.uploaded
              ? Colors.green.shade700
              : Colors.red.shade700,
        ),
      );
    } else {
      // Recargar por si se guardo meta/error en el servicio
      final all = await widget.documentService.getAllDocuments();
      final fresh = all.where((d) => d.id == document.id).cast<ScannedDocument?>().firstWhere(
            (d) => d != null,
            orElse: () => null,
          );
      if (fresh != null && mounted) {
        setState(() => document = fresh);
        widget.onUpdated(fresh);
      }
    }
  }

  void _confirmDelete() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Eliminar documento'),
        content: const Text('¿Seguro que quieres eliminar este documento?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          TextButton(
            onPressed: () async {
              await widget.documentService.deleteDocument(document.id);
              if (ctx.mounted) Navigator.pop(ctx);
              widget.onDeleted();
              if (mounted) Navigator.pop(context);
            },
            child: const Text('Eliminar', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
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
            onPressed: _confirmDelete,
            icon: const Icon(Icons.delete_outline_rounded),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: document.imagePaths.isEmpty
                ? const Center(
                    child: Icon(Icons.picture_as_pdf_rounded, size: 90, color: Colors.white38),
                  )
                : PageView.builder(
                    itemCount: document.imagePaths.length,
                    itemBuilder: (context, index) {
                      return InteractiveViewer(
                        minScale: 0.8,
                        maxScale: 4.0,
                        child: Center(
                          child: Image.file(
                            File(document.imagePaths[index]),
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) => const Icon(
                              Icons.broken_image_outlined,
                              color: Colors.white38,
                              size: 60,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
          if (document.lastError != null && document.status == DocumentStatus.error)
            Container(
              width: double.infinity,
              color: Colors.red.shade900,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Text(
                document.lastError!,
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
            ),
          Container(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 36),
            decoration: const BoxDecoration(
              color: Color(0xFF111827),
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: Column(
              children: [
                if (document.imagePaths.length > 1)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      '${document.imagePaths.length} paginas',
                      style: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                    ),
                  ),
                if (document.status == DocumentStatus.uploaded)
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.green.withOpacity(0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_circle_rounded, color: Colors.green.shade400, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          'En el sistema${document.remoteId != null ? ' · #${document.remoteId}' : ''}',
                          style: TextStyle(
                            color: Colors.green.shade300,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                Row(
                  children: [
                    Expanded(
                      child: _ActionButton(
                        icon: Icons.ios_share_rounded,
                        label: 'Compartir',
                        color: Colors.blue.shade400,
                        onTap: _share,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _ActionButton(
                        icon: document.status == DocumentStatus.uploaded
                            ? Icons.cloud_done_rounded
                            : document.status == DocumentStatus.error
                                ? Icons.refresh_rounded
                                : Icons.cloud_upload_rounded,
                        label: document.status == DocumentStatus.uploaded
                            ? 'Subido'
                            : document.status == DocumentStatus.error
                                ? 'Reintentar'
                                : 'Subir guia',
                        color: document.status == DocumentStatus.uploaded
                            ? Colors.green.shade400
                            : RomexColors.accent,
                        onTap: _uploadToSystem,
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
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 26),
            const SizedBox(height: 8),
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
