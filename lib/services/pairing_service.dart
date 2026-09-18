import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_config.dart';

class PairingResult {
  final String token;
  final Map<String, dynamic> user;

  PairingResult({required this.token, required this.user});
}

class PairingException implements Exception {
  final String message;
  final int? statusCode;
  PairingException(this.message, {this.statusCode});

  @override
  String toString() => message;
}

/// Servicio de emparejamiento con el Sistema de Guías vía código QR.
class PairingService {
  /// Extrae el código de un QR.
  /// Acepta:
  /// - URL completa: https://host/m/SKV6MR4T
  /// - Solo el código: SKV6MR4T
  /// - pair_url relativa: /m/SKV6MR4T
  static String? extractCode(String raw) {
    final text = raw.trim();
    if (text.isEmpty) return null;

    // URL con /m/CODIGO
    final uriMatch = RegExp(r'/m/([A-Za-z0-9]{6,12})', caseSensitive: false).firstMatch(text);
    if (uriMatch != null) {
      return uriMatch.group(1)!.toUpperCase();
    }

    // Código puro (8 chars típicos del backend)
    final codeMatch = RegExp(r'^[A-Za-z0-9]{6,12}$').firstMatch(text);
    if (codeMatch != null) {
      return text.toUpperCase();
    }

    return null;
  }

  /// Reclama el código en el backend y guarda la sesión.
  static Future<PairingResult> claim(String code) async {
    final baseUrl = await ApiConfig.getBaseUrl();
    final uri = Uri.parse('$baseUrl/api/pair/claim');

    final response = await http
        .post(
          uri,
          headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
          body: jsonEncode({'code': code.toUpperCase()}),
        )
        .timeout(const Duration(seconds: 15));

    final body = _tryJson(response.body);

    if (response.statusCode == 200 || response.statusCode == 201) {
      final token = body['token'] as String?;
      final user = body['user'] as Map<String, dynamic>?;
      if (token == null || user == null) {
        throw PairingException('Respuesta inválida del servidor');
      }
      await ApiConfig.setSession(token: token, user: user);
      return PairingResult(token: token, user: user);
    }

    final msg = body['error'] as String? ?? 'No se pudo conectar el dispositivo';
    throw PairingException(msg, statusCode: response.statusCode);
  }

  /// Intenta inferir y guardar la base URL a partir de la URL del QR.
  static Future<void> maybeUpdateBaseUrlFromQr(String qrRaw) async {
    try {
      final uri = Uri.tryParse(qrRaw.trim());
      if (uri == null || !uri.hasScheme || uri.host.isEmpty) return;
      // Solo http/https y no localhost del teléfono
      if (uri.scheme != 'http' && uri.scheme != 'https') return;
      final base = '${uri.scheme}://${uri.host}${uri.hasPort ? ':${uri.port}' : ''}';
      if (uri.host == 'localhost' || uri.host == '127.0.0.1') return;
      await ApiConfig.setBaseUrl(base);
    } catch (_) {}
  }

  static Map<String, dynamic> _tryJson(String raw) {
    try {
      final v = jsonDecode(raw);
      if (v is Map<String, dynamic>) return v;
    } catch (_) {}
    return {};
  }
}
