import 'package:flutter/material.dart';
import '../services/api_client.dart';
import '../services/api_config.dart';
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
    if (!mounted) return;
    setState(() {
      _urlController.text = url;
      _user = user;
      _paired = paired;
      _pairedAt = pairedAt;
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
                  'IP o dominio del backend. En el celular no uses localhost; usa la IP de la PC en la misma Wi-Fi (ej. http://192.168.1.20:3000).',
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
                        label: const Text('Probar conexion'),
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
                  Material(
                    color: (_healthOk == true ? Colors.green : Colors.orange).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          Icon(
                            _healthOk == true ? Icons.check_circle : Icons.warning_amber,
                            color: _healthOk == true ? Colors.green.shade700 : Colors.orange.shade800,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _healthMsg!,
                              style: TextStyle(
                                fontSize: 13,
                                color: _healthOk == true ? Colors.green.shade900 : Colors.orange.shade900,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 28),
                _sectionTitle('Sesion QR'),
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
                      subtitle: const Text('Escanea el QR de Conectar movil en la PC'),
                    ),
                  ),
                const SizedBox(height: 28),
                _sectionTitle('Acerca de'),
                const SizedBox(height: 8),
                Text(
                  'DocScan Pro v1.2 · Exportadora Romex S.A. Escaneo ML Kit + emparejamiento QR + subida de guias.',
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
}

class DateFormatHelper {
  static String format(DateTime d) {
    final two = (int n) => n.toString().padLeft(2, '0');
    return '${two(d.day)}/${two(d.month)}/${d.year} ${two(d.hour)}:${two(d.minute)}';
  }
}
