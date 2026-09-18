import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:http/http.dart' as http;
import 'api_config.dart';

enum NetStepStatus { pending, running, ok, fail, skip }

class NetStep {
  final String id;
  final String title;
  final String detail;
  final NetStepStatus status;

  const NetStep({
    required this.id,
    required this.title,
    required this.detail,
    required this.status,
  });

  NetStep copyWith({NetStepStatus? status, String? detail}) => NetStep(
        id: id,
        title: title,
        detail: detail ?? this.detail,
        status: status ?? this.status,
      );
}

class NetworkValidationResult {
  final bool ok;
  final List<NetStep> steps;
  final String summary;

  NetworkValidationResult({
    required this.ok,
    required this.steps,
    required this.summary,
  });
}

/// Validación de red por pasos antes de emparejar o subir.
class NetworkValidator {
  /// Ejecuta la batería de checks. [onStep] notifica UI en tiempo real.
  static Future<NetworkValidationResult> run({
    void Function(List<NetStep> steps)? onStep,
    bool requireAuth = false,
  }) async {
    final steps = <NetStep>[
      const NetStep(
        id: 'connectivity',
        title: '1. Conectividad del dispositivo',
        detail: 'Comprobando Wi‑Fi / datos…',
        status: NetStepStatus.pending,
      ),
      const NetStep(
        id: 'url',
        title: '2. URL del servidor',
        detail: 'Validando formato…',
        status: NetStepStatus.pending,
      ),
      const NetStep(
        id: 'dns',
        title: '3. Resolución del host',
        detail: 'Resolviendo nombre/IP…',
        status: NetStepStatus.pending,
      ),
      const NetStep(
        id: 'api',
        title: '4. API del sistema',
        detail: 'Ping al backend…',
        status: NetStepStatus.pending,
      ),
      const NetStep(
        id: 'auth',
        title: '5. Sesión QR',
        detail: requireAuth ? 'Verificando token…' : 'Opcional',
        status: requireAuth ? NetStepStatus.pending : NetStepStatus.skip,
      ),
    ];

    void emit() => onStep?.call(List.unmodifiable(steps));

    void set(int i, NetStepStatus s, String detail) {
      steps[i] = steps[i].copyWith(status: s, detail: detail);
      emit();
    }

    // 1. Connectivity
    set(0, NetStepStatus.running, 'Comprobando…');
    final connectivity = await Connectivity().checkConnectivity();
    final online = connectivity.any((r) =>
        r == ConnectivityResult.wifi ||
        r == ConnectivityResult.mobile ||
        r == ConnectivityResult.ethernet);
    if (!online) {
      set(0, NetStepStatus.fail, 'Sin red. Activa Wi‑Fi o datos móviles.');
      return NetworkValidationResult(
        ok: false,
        steps: steps,
        summary: 'Sin conectividad en el dispositivo',
      );
    }
    final kind = connectivity.map((e) => e.name).join(', ');
    set(0, NetStepStatus.ok, 'Conectado ($kind)');

    // 2. URL
    set(1, NetStepStatus.running, 'Leyendo URL…');
    final base = await ApiConfig.getBaseUrl();
    final uri = Uri.tryParse(base);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      set(1, NetStepStatus.fail, 'URL inválida: $base');
      return NetworkValidationResult(
        ok: false,
        steps: steps,
        summary: 'Configura la URL del servidor en Ajustes',
      );
    }
    if (uri.host == 'localhost' || uri.host == '127.0.0.1') {
      set(1, NetStepStatus.fail,
          'No uses localhost en el celular. Pon la IP de la PC (ej. 192.168.x.x).');
      return NetworkValidationResult(
        ok: false,
        steps: steps,
        summary: 'localhost no es alcanzable desde el teléfono',
      );
    }
    if (uri.scheme != 'http' && uri.scheme != 'https') {
      set(1, NetStepStatus.fail, 'Usa http:// o https://');
      return NetworkValidationResult(
        ok: false,
        steps: steps,
        summary: 'Esquema de URL no soportado',
      );
    }
    set(1, NetStepStatus.ok, base);

    // 3. DNS / host lookup
    set(2, NetStepStatus.running, 'Resolviendo ${uri.host}…');
    try {
      final addrs = await InternetAddress.lookup(uri.host)
          .timeout(const Duration(seconds: 5));
      if (addrs.isEmpty) {
        set(2, NetStepStatus.fail, 'Host sin dirección IP');
        return NetworkValidationResult(
          ok: false,
          steps: steps,
          summary: 'No se resolvió el host',
        );
      }
      set(2, NetStepStatus.ok, '${addrs.first.address}');
    } catch (e) {
      set(2, NetStepStatus.fail, 'No se pudo resolver ${uri.host}');
      return NetworkValidationResult(
        ok: false,
        steps: steps,
        summary: 'Error de DNS / host inaccesible',
      );
    }

    // 4. API health
    set(3, NetStepStatus.running, 'Contactando API…');
    final candidates = [
      Uri.parse('$base/api/health'),
      Uri.parse('$base/health'),
      Uri.parse('$base/api'),
    ];
    var apiOk = false;
    String apiDetail = '';
    for (final u in candidates) {
      try {
        final res = await http
            .get(u, headers: {'Accept': 'application/json'})
            .timeout(const Duration(seconds: 6));
        if (res.statusCode >= 200 && res.statusCode < 500) {
          apiOk = true;
          apiDetail = 'OK (${res.statusCode}) · ${u.path}';
          break;
        }
        apiDetail = 'HTTP ${res.statusCode}';
      } catch (e) {
        apiDetail = e.toString().replaceFirst('Exception: ', '');
      }
    }
    if (!apiOk) {
      set(3, NetStepStatus.fail, apiDetail);
      return NetworkValidationResult(
        ok: false,
        steps: steps,
        summary: 'El backend no responde. Revisa que el servidor esté en marcha.',
      );
    }
    set(3, NetStepStatus.ok, apiDetail);

    // 5. Auth opcional
    if (requireAuth) {
      set(4, NetStepStatus.running, 'Comprobando sesión…');
      final token = await ApiConfig.getToken();
      if (token == null || token.isEmpty) {
        set(4, NetStepStatus.fail, 'Sin sesión. Escanea el QR de Conectar móvil.');
        return NetworkValidationResult(
          ok: false,
          steps: steps,
          summary: 'Se requiere emparejamiento QR',
        );
      }
      set(4, NetStepStatus.ok, 'Sesión presente');
    } else {
      set(4, NetStepStatus.skip, 'No requerido en este paso');
    }

    return NetworkValidationResult(
      ok: true,
      steps: steps,
      summary: 'Red y servidor listos',
    );
  }
}
