import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_config.dart';

class ApiClient {
  /// Comprueba si el backend responde (timeout corto para UI ágil).
  static Future<HealthResult> healthCheck() async {
    final base = await ApiConfig.getBaseUrl();
    final candidates = [
      Uri.parse('$base/api/health'),
      Uri.parse('$base/health'),
    ];

    Object? lastError;
    for (final uri in candidates) {
      try {
        final res = await http
            .get(uri, headers: {'Accept': 'application/json'})
            .timeout(const Duration(seconds: 4));
        if (res.statusCode >= 200 && res.statusCode < 500) {
          String detail = 'OK';
          try {
            final body = jsonDecode(res.body);
            if (body is Map && body['status'] != null) {
              detail = 'status=${body['status']}';
            }
          } catch (_) {}
          return HealthResult(
            ok: true,
            message: 'Servidor alcanzable · $base ($detail)',
            statusCode: res.statusCode,
          );
        }
        lastError = 'HTTP ${res.statusCode}';
      } catch (e) {
        lastError = e;
      }
    }
    return HealthResult(
      ok: false,
      message:
          'No se pudo contactar $base. Revisa IP, puerto 4000, Wi‑Fi y firewall. '
          'Detalle: $lastError',
    );
  }

  /// Zonas desde estructura de guías (cache local si falla).
  static Future<List<String>> fetchZonas() async {
    final token = await ApiConfig.getToken();
    if (token == null) return ApiConfig.getZonas();

    final base = await ApiConfig.getBaseUrl();
    try {
      final res = await http
          .get(
            Uri.parse('$base/api/guias/estructura'),
            headers: {
              'Authorization': 'Bearer $token',
              'Accept': 'application/json',
            },
          )
          .timeout(const Duration(seconds: 8));

      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        if (body is Map) {
          final zonas = body.keys.map((e) => e.toString()).toList()..sort();
          if (zonas.isNotEmpty) {
            await ApiConfig.saveZonas(zonas);
            return zonas;
          }
        }
      }
    } catch (_) {}
    return ApiConfig.getZonas();
  }
}

class HealthResult {
  final bool ok;
  final String message;
  final int? statusCode;
  HealthResult({required this.ok, required this.message, this.statusCode});
}
