import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/scanned_document.dart';
import '../services/api_client.dart';
import '../services/document_service.dart';
import '../theme/app_theme.dart';
import '../widgets/network_validation_sheet.dart';

class UploadGuiaScreen extends StatefulWidget {
  final ScannedDocument document;
  final DocumentService documentService;

  const UploadGuiaScreen({
    super.key,
    required this.document,
    required this.documentService,
  });

  @override
  State<UploadGuiaScreen> createState() => _UploadGuiaScreenState();
}

class _UploadGuiaScreenState extends State<UploadGuiaScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _numero;
  late final TextEditingController _zona;
  late final TextEditingController _fecha;
  late final TextEditingController _sacos;
  late final TextEditingController _kilos;

  bool _uploading = false;
  double _progress = 0;
  List<String> _zonas = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    final d = widget.document;
    _numero = TextEditingController(text: d.numeroGuia ?? '');
    _zona = TextEditingController(text: d.zona ?? '');
    _fecha = TextEditingController(
      text: d.fechaRecepcion ?? DateFormat('yyyy-MM-dd').format(DateTime.now()),
    );
    _sacos = TextEditingController(text: d.cantidadSacos ?? '');
    _kilos = TextEditingController(text: d.kilos ?? '');
    _loadZonas();
  }

  Future<void> _loadZonas() async {
    final z = await ApiClient.fetchZonas();
    if (mounted) setState(() => _zonas = z);
  }

  @override
  void dispose() {
    _numero.dispose();
    _zona.dispose();
    _fecha.dispose();
    _sacos.dispose();
    _kilos.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final initial = DateTime.tryParse(_fecha.text) ?? now;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 1),
    );
    if (picked != null) {
      _fecha.text = DateFormat('yyyy-MM-dd').format(picked);
      setState(() {});
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    // Validación de red + sesión antes de subir
    final netOk = await showNetworkValidation(
      context,
      requireAuth: true,
      title: 'Validando red antes de subir',
    );
    if (!netOk || !mounted) return;

    setState(() {
      _uploading = true;
      _error = null;
      _progress = 0.15;
    });

    final meta = {
      'numero_guia': _numero.text.trim(),
      'zona': _zona.text.trim(),
      'fecha_recepcion': _fecha.text.trim(),
      'cantidad_sacos': _sacos.text.trim(),
      'kilos': _kilos.text.trim(),
    };

    try {
      setState(() => _progress = 0.4);
      final uploaded = await widget.documentService.uploadToSystem(
        widget.document,
        meta: meta,
      );
      setState(() => _progress = 1.0);
      if (!mounted) return;
      Navigator.pop(context, uploaded);
    } catch (e) {
      setState(() {
        _uploading = false;
        _progress = 0;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Subir guía al sistema'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: RomexColors.primary.withOpacity(0.06),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: RomexColors.primary.withOpacity(0.15)),
              ),
              child: Row(
                children: [
                  Icon(Icons.picture_as_pdf, color: Colors.red.shade400),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.document.pdfPath != null
                              ? 'PDF listo para subir'
                              : 'Sin PDF — vuelve a escanear',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        Text(
                          '${widget.document.imagePaths.length} página(s)',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _numero,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                labelText: 'Número de guía *',
                hintText: 'G-2026-00487',
                prefixIcon: Icon(Icons.tag),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Obligatorio' : null,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _zona,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                labelText: 'Zona *',
                hintText: 'Ayacucho',
                prefixIcon: const Icon(Icons.place_outlined),
                suffixIcon: _zonas.isEmpty
                    ? null
                    : PopupMenuButton<String>(
                        icon: const Icon(Icons.arrow_drop_down),
                        onSelected: (z) => setState(() => _zona.text = z),
                        itemBuilder: (_) => _zonas
                            .map((z) => PopupMenuItem(value: z, child: Text(z)))
                            .toList(),
                      ),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Obligatorio' : null,
            ),
            if (_zonas.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: _zonas.take(8).map((z) {
                  final selected =
                      _zona.text.trim().toLowerCase() == z.toLowerCase();
                  return ChoiceChip(
                    label: Text(z, style: const TextStyle(fontSize: 12)),
                    selected: selected,
                    onSelected: (_) => setState(() => _zona.text = z),
                    selectedColor: RomexColors.primary.withOpacity(0.2),
                  );
                }).toList(),
              ),
            ],
            const SizedBox(height: 14),
            TextFormField(
              controller: _fecha,
              readOnly: true,
              onTap: _pickDate,
              decoration: const InputDecoration(
                labelText: 'Fecha de recepción *',
                prefixIcon: Icon(Icons.calendar_today_outlined),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Obligatorio' : null,
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _sacos,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Sacos',
                      prefixIcon: Icon(Icons.inventory_2_outlined),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _kilos,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Kilos',
                      prefixIcon: Icon(Icons.scale_outlined),
                    ),
                  ),
                ),
              ],
            ),
            if (_error != null) ...[
              const SizedBox(height: 16),
              Material(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.error_outline, color: Colors.red.shade700),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _error!,
                          style: TextStyle(color: Colors.red.shade800, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            if (_uploading) ...[
              const SizedBox(height: 20),
              LinearProgressIndicator(
                value: _progress > 0 ? _progress : null,
                borderRadius: BorderRadius.circular(8),
                minHeight: 8,
                color: RomexColors.primary,
              ),
              const SizedBox(height: 8),
              Text(
                'Subiendo al sistema…',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
              ),
            ],
            const SizedBox(height: 28),
            FilledButton.icon(
              onPressed: _uploading ? null : _submit,
              icon: _uploading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.cloud_upload_rounded),
              label: Text(_uploading ? 'Subiendo…' : 'Subir guía al sistema'),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
