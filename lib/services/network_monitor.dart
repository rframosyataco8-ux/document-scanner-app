import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'api_config.dart';
import 'upload_queue.dart';

enum NetLink { offline, wifi, mobile, ethernet, other }

enum ServerReachability { unknown, reachable, unreachable }

class NetworkSnapshot {
  final bool deviceOnline;
  final NetLink link;
  final ServerReachability server;
  final String? serverDetail;
  final DateTime at;

  const NetworkSnapshot({
    required this.deviceOnline,
    required this.link,
    required this.server,
    this.serverDetail,
    required this.at,
  });

  bool get fullyOnline =>
      deviceOnline && server == ServerReachability.reachable;

  String get label {
    if (!deviceOnline) return 'Sin red';
    final linkName = switch (link) {
      NetLink.wifi => 'Wi‑Fi',
      NetLink.mobile => 'Datos',
      NetLink.ethernet => 'Ethernet',
      NetLink.other => 'Red',
      NetLink.offline => 'Sin red',
    };
    return switch (server) {
      ServerReachability.reachable => '$linkName · Servidor OK',
      ServerReachability.unreachable => '$linkName · Servidor no responde',
      ServerReachability.unknown => '$linkName · Comprobando…',
    };
  }
}

/// Monitoreo continuo de conectividad del dispositivo + alcance del API.
class NetworkMonitor {
  NetworkMonitor._();
  static final NetworkMonitor instance = NetworkMonitor._();

  final _controller = StreamController<NetworkSnapshot>.broadcast();
  StreamSubscription<List<ConnectivityResult>>? _connSub;
  Timer? _pingTimer;
  bool _started = false;
  bool _pinging = false;
  NetworkSnapshot _current = NetworkSnapshot(
    deviceOnline: false,
    link: NetLink.offline,
    server: ServerReachability.unknown,
    at: DateTime.now(),
  );

  NetworkSnapshot get current => _current;
  Stream<NetworkSnapshot> get stream => _controller.stream;

  Future<void> start() async {
    if (_started) return;
    _started = true;

    // Estado inicial
    final initial = await Connectivity().checkConnectivity();
    await _onConnectivity(initial);

    _connSub = Connectivity().onConnectivityChanged.listen((results) {
      _onConnectivity(results);
    });

    // Ping periódico al backend cada 20s cuando hay enlace
    _pingTimer = Timer.periodic(const Duration(seconds: 20), (_) {
      if (_current.deviceOnline) unawaited(_pingServer());
    });
  }

  void dispose() {
    _connSub?.cancel();
    _pingTimer?.cancel();
    _started = false;
  }

  Future<void> refreshNow() async {
    final results = await Connectivity().checkConnectivity();
    await _onConnectivity(results);
  }

  Future<void> _onConnectivity(List<ConnectivityResult> results) async {
    final online = results.any((r) =>
        r == ConnectivityResult.wifi ||
        r == ConnectivityResult.mobile ||
        r == ConnectivityResult.ethernet);

    NetLink link = NetLink.offline;
    if (results.contains(ConnectivityResult.wifi)) {
      link = NetLink.wifi;
    } else if (results.contains(ConnectivityResult.mobile)) {
      link = NetLink.mobile;
    } else if (results.contains(ConnectivityResult.ethernet)) {
      link = NetLink.ethernet;
    } else if (online) {
      link = NetLink.other;
    }

    final wasOnline = _current.deviceOnline;

    _emit(NetworkSnapshot(
      deviceOnline: online,
      link: link,
      server: online ? ServerReachability.unknown : ServerReachability.unreachable,
      serverDetail: online ? 'Comprobando API…' : 'Sin conectividad',
      at: DateTime.now(),
    ));

    if (online) {
      await _pingServer();
      // Si acabamos de recuperar red → procesar cola offline
      if (!wasOnline) {
        debugPrint('[NetMonitor] red recuperada → cola offline');
        unawaited(UploadQueue.instance.processQueue());
      }
    }
  }

  Future<void> _pingServer() async {
    if (_pinging) return;
    if (!_current.deviceOnline) return;
    _pinging = true;

    try {
      final base = await ApiConfig.getBaseUrl();
      final candidates = [
        Uri.parse('$base/api/health'),
        Uri.parse('$base/health'),
        Uri.parse('$base/api'),
      ];

      var ok = false;
      String detail = '';
      for (final u in candidates) {
        try {
          final res = await http
              .get(u, headers: {'Accept': 'application/json'})
              .timeout(const Duration(seconds: 5));
          if (res.statusCode >= 200 && res.statusCode < 500) {
            ok = true;
            detail = 'API ${res.statusCode}';
            break;
          }
          detail = 'HTTP ${res.statusCode}';
        } catch (e) {
          detail = 'timeout/error';
        }
      }

      _emit(NetworkSnapshot(
        deviceOnline: _current.deviceOnline,
        link: _current.link,
        server: ok ? ServerReachability.reachable : ServerReachability.unreachable,
        serverDetail: detail,
        at: DateTime.now(),
      ));
    } finally {
      _pinging = false;
    }
  }

  void _emit(NetworkSnapshot snap) {
    _current = snap;
    if (!_controller.isClosed) _controller.add(snap);
  }
}
