import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Almacenamiento cifrado para JWT y token FCM.
/// No usa SharedPreferences para secretos.
class SecureStore {
  SecureStore._();
  static final SecureStore instance = SecureStore._();

  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  static const _keyJwt = 'romex_jwt';
  static const _keyFcm = 'romex_fcm_token';
  static const _keyUserJson = 'romex_user_json';

  Future<void> saveJwt(String token) => _storage.write(key: _keyJwt, value: token);

  Future<String?> getJwt() => _storage.read(key: _keyJwt);

  Future<void> clearJwt() => _storage.delete(key: _keyJwt);

  Future<void> saveFcmToken(String token) =>
      _storage.write(key: _keyFcm, value: token);

  Future<String?> getFcmToken() => _storage.read(key: _keyFcm);

  Future<void> clearFcmToken() => _storage.delete(key: _keyFcm);

  Future<void> saveUserJson(String json) =>
      _storage.write(key: _keyUserJson, value: json);

  Future<String?> getUserJson() => _storage.read(key: _keyUserJson);

  Future<void> clearUser() => _storage.delete(key: _keyUserJson);

  Future<void> clearSession() async {
    await Future.wait([clearJwt(), clearUser()]);
  }

  Future<void> clearAllSecrets() async {
    await Future.wait([clearJwt(), clearFcmToken(), clearUser()]);
  }

  /// Enmascara token para logs (nunca imprime el valor completo).
  static String maskToken(String? token) {
    if (token == null || token.isEmpty) return '(vacío)';
    if (token.length < 12) return '***';
    return '${token.substring(0, 6)}…${token.substring(token.length - 4)} (len=${token.length})';
  }

  /// Valida formato básico de token FCM antes de enviarlo al backend.
  static bool isPlausibleFcmToken(String? token) {
    if (token == null) return false;
    final t = token.trim();
    if (t.length < 80) return false;
    // FCM tokens suelen ser alfanuméricos con : _ -
    return RegExp(r'^[A-Za-z0-9_\-:]+$').hasMatch(t);
  }
}
