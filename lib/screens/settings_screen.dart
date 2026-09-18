import 'package:flutter/material.dart';
import '../services/api_config.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _urlController = TextEditingController();
  bool _loading = true;
  Map<String, dynamic>? _user;
  bool _paired = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final url = await ApiConfig.getBaseUrl();
    final user = await ApiConfig.getUser();
    final paired = await ApiConfig.isPaired();
    if (!mounted) return;
    setState(() {
      _urlController.text = url;
      _user = user;
      _paired = paired;
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

  Future<void> _disconnect() async {
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
      appBar: AppBar(
        title: const Text('Ajustes'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Text(
                  'Servidor del sistema',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.grey.shade800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'IP o dominio donde corre el backend (ej. http://192.168.1.20:3000). '
                  'No uses localhost desde el celular.',
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _urlController,
                  decoration: const InputDecoration(
                    labelText: 'URL base API',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.link),
                  ),
                  keyboardType: TextInputType.url,
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: _saveUrl,
                  icon: const Icon(Icons.save_outlined),
                  label: const Text('Guardar URL'),
                ),
                const SizedBox(height: 32),
                Text(
                  'Sesión QR',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.grey.shade800,
                  ),
                ),
                const SizedBox(height: 12),
                if (_paired && _user != null)
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.verified_user, color: Colors.green),
                      title: Text(_user!['nombre']?.toString() ?? _user!['username']?.toString() ?? 'Usuario'),
                      subtitle: Text('Rol: ${_user!['role'] ?? '-'}'),
                      trailing: TextButton(
                        onPressed: _disconnect,
                        child: const Text('Desconectar'),
                      ),
                    ),
                  )
                else
                  Card(
                    child: ListTile(
                      leading: Icon(Icons.link_off, color: Colors.grey.shade500),
                      title: const Text('No conectado'),
                      subtitle: const Text('Escanea el QR de Conectar móvil'),
                    ),
                  ),
              ],
            ),
    );
  }
}
