import 'package:shared_preferences/shared_preferences.dart';

/// Configuración de conexión al Sistema de Guías de Cacao.
/// El QR apunta a una URL; el app extrae el código y habla con /api.
class ApiConfig {
  static const _keyBaseUrl = 'api_base_url';
  static const _keyToken = 'auth_token';
  static const _keyUserJson = 'auth_user_json';
  static const _keyPairedAt = 'paired_at';

  /// Valor por defecto (cámbialo en Ajustes o al emparejar).
  /// En red local usa la IP de la PC, ej: http://192.168.1.10:3000
  static const String defaultBaseUrl = 'http://10.0.2.2:3000';

  static Future<SharedPreferences> get _prefs => SharedPreferences.getInstance();

  static Future<String> getBaseUrl() async {
    final p = await _prefs;
    return p.getString(_keyBaseUrl) ?? defaultBaseUrl;
  }

  static Future<void> setBaseUrl(String url) async {
    final p = await _prefs;
    final clean = url.trim().replaceAll(RegExp(r'/$'), '');
    await p.setString(_keyBaseUrl, clean);
  }

  static Future<String?> getToken() async {
    final p = await _prefs;
    return p.getString(_keyToken);
  }

  static Future<void> setSession({
    required String token,
    required Map<String, dynamic> user,
  }) async {
    final p = await _prefs;
    await p.setString(_keyToken, token);
    await p.setString(_keyUserJson, _encodeUser(user));
    await p.setString(_keyPairedAt, DateTime.now().toIso8601String());
  }

  static Future<Map<String, dynamic>?> getUser() async {
    final p = await _prefs;
    final raw = p.getString(_keyUserJson);
    if (raw == null || raw.isEmpty) return null;
    return _decodeUser(raw);
  }

  static Future<bool> isPaired() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }

  static Future<void> clearSession() async {
    final p = await _prefs;
    await p.remove(_keyToken);
    await p.remove(_keyUserJson);
    await p.remove(_keyPairedAt);
  }

  static String _encodeUser(Map<String, dynamic> user) {
    // Simple key=value para no añadir dependencia de json en este archivo
    // (usamos jsonEncode desde otros sitios).
    return user.entries.map((e) => '${e.key}=${e.value}').join('|');
  }

  static Map<String, dynamic> _decodeUser(String raw) {
    final map = <String, dynamic>{};
    for (final part in raw.split('|')) {
      final i = part.indexOf('=');
      if (i > 0) {
        map[part.substring(0, i)] = part.substring(i + 1);
      }
    }
    return map;
  }
}
