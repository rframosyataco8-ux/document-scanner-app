import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_config.dart';

class ApiClient {
  /// Comprueba si el backend responde.
  static Future<HealthResult> healthCheck() async {
    final base = await ApiConfig.getBaseUrl();
    final candidates = [
      Uri.parse('$base/api/health'),
      Uri.parse('$base/health'),
      Uri.parse('$base/api'),
    ];

    for (final uri in candidates) {
      try {
        final res = await http
            .get(uri, headers: {'Accept': 'application/json'})
            .timeout(const Duration(seconds: 5));
        if (res.statusCode >= 200 && res.statusCode < 500) {
          return HealthResult(ok: true, message: 'Servidor reachable ($base)', statusCode: res.statusCode);
        }
      } catch (_) {
        // try next
      }
    }
    return HealthResult(
      ok: false,
      message: 'No se pudo contactar $base. Revisa IP, puerto y Wi‑Fi.',
    );
  }

  /// Intenta cargar zonas desde estructura de guías (si el token tiene permiso).
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
          .timeout(const Duration(seconds: 10));

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
