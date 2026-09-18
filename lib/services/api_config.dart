import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'secure_store.dart';

class ApiConfig {
  static const _keyBaseUrl = 'api_base_url';
  static const _keyPairedAt = 'paired_at';
  static const _keyLastZonas = 'last_zonas';
  // Legacy keys (migración)
  static const _legacyToken = 'auth_token';
  static const _legacyUser = 'auth_user_json';

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
    // Preferir secure storage
    final secure = await SecureStore.instance.getJwt();
    if (secure != null && secure.isNotEmpty) return secure;

    // Migrar desde prefs si existía
    final p = await _prefs;
    final legacy = p.getString(_legacyToken);
    if (legacy != null && legacy.isNotEmpty) {
      await SecureStore.instance.saveJwt(legacy);
      await p.remove(_legacyToken);
      return legacy;
    }
    return null;
  }

  static Future<void> setSession({
    required String token,
    required Map<String, dynamic> user,
  }) async {
    await SecureStore.instance.saveJwt(token);
    await SecureStore.instance.saveUserJson(jsonEncode(user));
    final p = await _prefs;
    await p.setString(_keyPairedAt, DateTime.now().toIso8601String());
    // Limpiar legacy
    await p.remove(_legacyToken);
    await p.remove(_legacyUser);
  }

  static Future<Map<String, dynamic>?> getUser() async {
    final raw = await SecureStore.instance.getUserJson();
    if (raw != null && raw.isNotEmpty) {
      try {
        final v = jsonDecode(raw);
        if (v is Map<String, dynamic>) return v;
      } catch (_) {}
    }
    // Legacy
    final p = await _prefs;
    final legacy = p.getString(_legacyUser);
    if (legacy != null) {
      try {
        final v = jsonDecode(legacy);
        if (v is Map<String, dynamic>) {
          await SecureStore.instance.saveUserJson(legacy);
          await p.remove(_legacyUser);
          return v;
        }
      } catch (_) {}
    }
    return null;
  }

  static Future<DateTime?> getPairedAt() async {
    final p = await _prefs;
    final raw = p.getString(_keyPairedAt);
    if (raw == null) return null;
    return DateTime.tryParse(raw);
  }

  static Future<bool> isPaired() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }

  static Future<void> clearSession() async {
    await SecureStore.instance.clearSession();
    final p = await _prefs;
    await p.remove(_keyPairedAt);
    await p.remove(_legacyToken);
    await p.remove(_legacyUser);
  }

  static Future<void> saveZonas(List<String> zonas) async {
    final p = await _prefs;
    await p.setStringList(_keyLastZonas, zonas);
  }

  static Future<List<String>> getZonas() async {
    final p = await _prefs;
    return p.getStringList(_keyLastZonas) ?? [];
  }
}
