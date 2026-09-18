import 'dart:io';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../models/scanned_document.dart';
import '../services/api_config.dart';
import '../services/document_service.dart';

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
  bool isUploading = false;

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
    if (isUploading || document.status == DocumentStatus.uploaded) return;

    final paired = await ApiConfig.isPaired();
    if (!paired) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Primero escanea el QR de "Conectar móvil"'),
          backgroundColor: Colors.orange.shade800,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (document.pdfPath == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Este documento no tiene PDF. Escanea de nuevo con formato PDF.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final meta = await _askGuiaMeta();
    if (meta == null || !mounted) return;

    setState(() {
      isUploading = true;
      document = document.copyWith(status: DocumentStatus.uploading);
    });
    widget.onUpdated(document);

    try {
      final uploaded = await widget.documentService.uploadToSystem(
        document,
        meta: meta,
      );
      setState(() {
        document = uploaded;
        isUploading = false;
      });
      widget.onUpdated(uploaded);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('¡Guía subida al sistema!'),
            backgroundColor: Colors.green.shade700,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    } catch (e) {
      setState(() {
        document = document.copyWith(status: DocumentStatus.error);
        isUploading = false;
      });
      widget.onUpdated(document);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$e'),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<Map<String, String>?> _askGuiaMeta() async {
    final numero = TextEditingController();
    final zona = TextEditingController();
    final sacos = TextEditingController();
    final kilos = TextEditingController();
    final fecha = TextEditingController(
      text: DateTime.now().toIso8601String().slice(0, 10),
    );

    return showDialog<Map<String, String>>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Datos de la guía'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: numero,
                  decoration: const InputDecoration(
                    labelText: 'Número de guía *',
                    hintText: 'G-2026-00487',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: zona,
                  decoration: const InputDecoration(
                    labelText: 'Zona *',
                    hintText: 'Ayacucho',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: fecha,
                  decoration: const InputDecoration(
                    labelText: 'Fecha recepción *',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.datetime,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: sacos,
                        decoration: const InputDecoration(
                          labelText: 'Sacos',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: kilos,
                        decoration: const InputDecoration(
                          labelText: 'Kilos',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () {
                if (numero.text.trim().isEmpty ||
                    zona.text.trim().isEmpty ||
                    fecha.text.trim().isEmpty) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(content: Text('Número, zona y fecha son obligatorios')),
                  );
                  return;
                }
                Navigator.pop(ctx, {
                  'numero_guia': numero.text.trim(),
                  'zona': zona.text.trim(),
                  'fecha_recepcion': fecha.text.trim(),
                  'cantidad_sacos': sacos.text.trim(),
                  'kilos': kilos.text.trim(),
                });
              },
              child: const Text('Subir'),
            ),
          ],
        );
      },
    );
  }

  void _confirmDelete() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Eliminar documento'),
        content: const Text('¿Estás seguro de que quieres eliminar este documento?'),
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
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Text(
                      '${document.imagePaths.length} páginas',
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
                          'Ya está en el sistema',
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
                        icon: isUploading
                            ? null
                            : document.status == DocumentStatus.uploaded
                                ? Icons.cloud_done_rounded
                                : Icons.cloud_upload_rounded,
                        label: isUploading
                            ? 'Subiendo...'
                            : document.status == DocumentStatus.uploaded
                                ? 'Subido'
                                : 'Subir al sistema',
                        color: document.status == DocumentStatus.uploaded
                            ? Colors.green.shade400
                            : const Color(0xFF34D399),
                        isLoading: isUploading,
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
  final IconData? icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  final bool isLoading;

  const _ActionButton({
    this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isLoading ? null : onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            if (isLoading)
              SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(color: color, strokeWidth: 2.5),
              )
            else
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

extension on String {
  String slice(int start, int end) => substring(start, end > length ? length : end);
}
