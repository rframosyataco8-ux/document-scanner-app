import 'package:flutter/material.dart';
import '../services/api_client.dart';
import '../services/api_config.dart';
import '../services/fcm_service.dart';
import '../services/upload_queue.dart';
import '../theme/app_theme.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _urlController = TextEditingController();
  bool _loading = true;
  bool _checking = false;
  Map<String, dynamic>? _user;
  bool _paired = false;
  DateTime? _pairedAt;
  String? _healthMsg;
  bool? _healthOk;
  bool _fcmEnabled = true;
  bool _fcmReady = false;
  bool _processingQueue = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final url = await ApiConfig.getBaseUrl();
    final user = await ApiConfig.getUser();
    final paired = await ApiConfig.isPaired();
    final pairedAt = await ApiConfig.getPairedAt();
    final fcmEnabled = await FcmService.instance.isEnabled();
    if (!mounted) return;
    setState(() {
      _urlController.text = url;
      _user = user;
      _paired = paired;
      _pairedAt = pairedAt;
      _fcmEnabled = fcmEnabled;
      _fcmReady = FcmService.instance.isReady;
      _loading = false;
    });
  }

  Future<void> _saveUrl() async {
    await ApiConfig.setBaseUrl(_urlController.text);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('URL del servidor guardada')),
    );
  }

  Future<void> _checkHealth() async {
    setState(() {
      _checking = true;
      _healthMsg = null;
      _healthOk = null;
    });
    await ApiConfig.setBaseUrl(_urlController.text);
    final result = await ApiClient.healthCheck();
    if (!mounted) return;
    setState(() {
      _checking = false;
      _healthOk = result.ok;
      _healthMsg = result.message;
    });
  }

  Future<void> _toggleFcm(bool v) async {
    await FcmService.instance.setEnabled(v);
    setState(() => _fcmEnabled = v);
  }

  Future<void> _runQueue() async {
    setState(() => _processingQueue = true);
    await UploadQueue.instance.processQueue();
    if (!mounted) return;
    setState(() => _processingQueue = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Cola offline procesada')),
    );
  }

  Future<void> _disconnect() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Desconectar'),
        content: const Text('¿Cerrar la sesión obtenida por QR?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Desconectar')),
        ],
      ),
    );
    if (ok != true) return;
    await FcmService.instance.unregisterFromBackend();
    await ApiConfig.clearSession();
    await _load();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Sesión cerrada')),
    );
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ajustes')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                _sectionTitle('Servidor del sistema'),
                const SizedBox(height: 6),
                Text(
                  'IP o dominio del backend. En el celular no uses localhost; usa la IP de la PC en la misma Wi-Fi.',
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _urlController,
                  decoration: const InputDecoration(
                    labelText: 'URL base API',
                    prefixIcon: Icon(Icons.link),
                  ),
                  keyboardType: TextInputType.url,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _checking ? null : _checkHealth,
                        icon: _checking
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.wifi_tethering),
                        label: const Text('Probar'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _saveUrl,
                        icon: const Icon(Icons.save_outlined),
                        label: const Text('Guardar'),
                      ),
                    ),
                  ],
                ),
                if (_healthMsg != null) ...[
                  const SizedBox(height: 12),
                  _infoBanner(_healthOk == true, _healthMsg!),
                ],
                const SizedBox(height: 28),
                _sectionTitle('Cola offline'),
                const SizedBox(height: 8),
                Text(
                  'Si no hay red al subir, la guía queda en cola y se envía sola al recuperar conexión.',
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _processingQueue ? null : _runQueue,
                  icon: _processingQueue
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.cloud_sync_outlined),
                  label: const Text('Procesar cola ahora'),
                ),
                const SizedBox(height: 28),
                _sectionTitle('Notificaciones push (FCM)'),
                const SizedBox(height: 8),
                if (!_fcmReady)
                  _infoBanner(
                    false,
                    'Firebase no configurado. Añade google-services.json y activa el plugin en build.gradle (ver README).',
                  )
                else
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Recibir avisos de nuevas guías'),
                    subtitle: const Text('Registro del token en el servidor RomEx'),
                    value: _fcmEnabled,
                    activeColor: RomexColors.primary,
                    onChanged: _toggleFcm,
                  ),
                const SizedBox(height: 28),
                _sectionTitle('Sesión QR'),
                const SizedBox(height: 12),
                if (_paired && _user != null)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                backgroundColor: RomexColors.primary.withOpacity(0.15),
                                child: Icon(Icons.person, color: RomexColors.primary),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _user!['nombre']?.toString() ??
                                          _user!['username']?.toString() ??
                                          'Usuario',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 16,
                                      ),
                                    ),
                                    Text(
                                      'Rol: ${_user!['role'] ?? '-'}',
                                      style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.green.shade50,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  'Activa',
                                  style: TextStyle(
                                    color: Colors.green.shade800,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (_pairedAt != null) ...[
                            const SizedBox(height: 10),
                            Text(
                              'Conectado: ${DateFormatHelper.format(_pairedAt!)}',
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                            ),
                          ],
                          const SizedBox(height: 12),
                          OutlinedButton.icon(
                            onPressed: _disconnect,
                            icon: const Icon(Icons.link_off, size: 18),
                            label: const Text('Desconectar'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.red.shade700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  Card(
                    child: ListTile(
                      leading: Icon(Icons.link_off, color: Colors.grey.shade500),
                      title: const Text('No conectado'),
                      subtitle: const Text('Escanea el QR de Conectar móvil en la PC'),
                    ),
                  ),
                const SizedBox(height: 28),
                _sectionTitle('Acerca de'),
                const SizedBox(height: 8),
                Text(
                  'DocScan Pro v1.3 · Exportadora Romex S.A. Cola offline + FCM + QR + ML Kit.',
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade600, height: 1.4),
                ),
              ],
            ),
    );
  }

  Widget _sectionTitle(String t) => Text(
        t,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: Colors.grey.shade800,
        ),
      );

  Widget _infoBanner(bool ok, String msg) {
    return Material(
      color: (ok ? Colors.green : Colors.orange).withOpacity(0.12),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              ok ? Icons.check_circle : Icons.warning_amber,
              color: ok ? Colors.green.shade700 : Colors.orange.shade800,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                msg,
                style: TextStyle(
                  fontSize: 13,
                  color: ok ? Colors.green.shade900 : Colors.orange.shade900,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class DateFormatHelper {
  static String format(DateTime d) {
    final two = (int n) => n.toString().padLeft(2, '0');
    return '${two(d.day)}/${two(d.month)}/${d.year} ${two(d.hour)}:${two(d.minute)}';
  }
}
