import 'dart:convert';
import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'api_config.dart';
import 'secure_store.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('[FCM bg] id=${message.messageId}');
}

/// Push FCM con almacenamiento seguro del token.
class FcmService {
  FcmService._();
  static final FcmService instance = FcmService._();

  bool _ready = false;
  bool get isReady => _ready;

  final _local = FlutterLocalNotificationsPlugin();
  static const _channelId = 'romex_guias';
  static const _channelName = 'Guías RomEx';
  static const _prefsEnabled = 'fcm_enabled';

  Future<bool> init() async {
    try {
      await Firebase.initializeApp();
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

      const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
      await _local.initialize(
        const InitializationSettings(android: androidInit),
      );

      final androidPlugin = _local.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      await androidPlugin?.createNotificationChannel(
        const AndroidNotificationChannel(
          _channelId,
          _channelName,
          description: 'Avisos de nuevas guías en el sistema',
          importance: Importance.high,
        ),
      );

      final messaging = FirebaseMessaging.instance;
      await messaging.requestPermission(alert: true, badge: true, sound: true);

      FirebaseMessaging.onMessage.listen(_showForeground);

      messaging.onTokenRefresh.listen((token) async {
        if (!SecureStore.isPlausibleFcmToken(token)) {
          debugPrint('[FCM] token refresh inválido ignorado');
          return;
        }
        await SecureStore.instance.saveFcmToken(token);
        await registerWithBackend();
      });

      final token = await messaging.getToken();
      if (SecureStore.isPlausibleFcmToken(token)) {
        await SecureStore.instance.saveFcmToken(token!);
        debugPrint('[FCM] token ${SecureStore.maskToken(token)}');
      }

      _ready = true;
      debugPrint('[FCM] listo');
      return true;
    } catch (e) {
      debugPrint('[FCM] desactivado: $e');
      _ready = false;
      return false;
    }
  }

  Future<bool> isEnabled() async {
    final p = await SharedPreferences.getInstance();
    return p.getBool(_prefsEnabled) ?? true;
  }

  Future<void> setEnabled(bool value) async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(_prefsEnabled, value);
    if (value) {
      await registerWithBackend();
    } else {
      await unregisterFromBackend();
    }
  }

  Future<String?> getToken() => SecureStore.instance.getFcmToken();

  /// Registra token en backend solo si es plausible y hay sesión.
  Future<void> registerWithBackend() async {
    if (!_ready) return;
    if (!await isEnabled()) return;

    final auth = await ApiConfig.getToken();
    final fcmToken = await getToken();
    if (auth == null || fcmToken == null) return;

    if (!SecureStore.isPlausibleFcmToken(fcmToken)) {
      debugPrint('[FCM] registro abortado: token no plausible');
      return;
    }

    final base = await ApiConfig.getBaseUrl();
    try {
      final res = await http
          .post(
            Uri.parse('$base/api/devices/register'),
            headers: {
              'Authorization': 'Bearer $auth',
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode({
              'token': fcmToken,
              'platform': Platform.isIOS ? 'ios' : 'android',
            }),
          )
          .timeout(const Duration(seconds: 12));
      debugPrint(
        '[FCM] register status=${res.statusCode} token=${SecureStore.maskToken(fcmToken)}',
      );
    } catch (e) {
      debugPrint('[FCM] register error: $e');
    }
  }

  Future<void> unregisterFromBackend() async {
    if (!_ready) return;
    final auth = await ApiConfig.getToken();
    final fcmToken = await getToken();
    if (auth == null || fcmToken == null) return;

    final base = await ApiConfig.getBaseUrl();
    try {
      await http
          .delete(
            Uri.parse('$base/api/devices/register'),
            headers: {
              'Authorization': 'Bearer $auth',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({'token': fcmToken}),
          )
          .timeout(const Duration(seconds: 10));
    } catch (_) {}
    // No borramos el token local: se reutiliza al reactivar notificaciones.
  }

  void _showForeground(RemoteMessage message) {
    final n = message.notification;
    if (n == null) return;
    _local.show(
      n.hashCode,
      n.title ?? 'RomEx',
      n.body ?? '',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
      payload: message.data['numero_guia'],
    );
  }
}
