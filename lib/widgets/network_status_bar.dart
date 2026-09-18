import 'dart:async';
import 'package:flutter/material.dart';
import '../services/network_monitor.dart';
import '../theme/app_theme.dart';

/// Barra compacta de estado de red en tiempo real.
class NetworkStatusBar extends StatefulWidget {
  const NetworkStatusBar({super.key});

  @override
  State<NetworkStatusBar> createState() => _NetworkStatusBarState();
}

class _NetworkStatusBarState extends State<NetworkStatusBar> {
  StreamSubscription<NetworkSnapshot>? _sub;
  NetworkSnapshot _snap = NetworkMonitor.instance.current;

  @override
  void initState() {
    super.initState();
    _snap = NetworkMonitor.instance.current;
    _sub = NetworkMonitor.instance.stream.listen((s) {
      if (mounted) setState(() => _snap = s);
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Color get _bg {
    if (!_snap.deviceOnline) return Colors.red.shade50;
    if (_snap.server == ServerReachability.reachable) {
      return RomexColors.primary.withOpacity(0.08);
    }
    if (_snap.server == ServerReachability.unknown) {
      return Colors.blue.shade50;
    }
    return Colors.orange.shade50;
  }

  Color get _fg {
    if (!_snap.deviceOnline) return Colors.red.shade800;
    if (_snap.server == ServerReachability.reachable) {
      return RomexColors.primaryDark;
    }
    if (_snap.server == ServerReachability.unknown) {
      return Colors.blue.shade800;
    }
    return Colors.orange.shade900;
  }

  IconData get _icon {
    if (!_snap.deviceOnline) return Icons.cloud_off;
    if (_snap.server == ServerReachability.reachable) return Icons.cloud_done;
    if (_snap.server == ServerReachability.unknown) return Icons.cloud_sync;
    return Icons.cloud_queue;
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _bg,
      child: InkWell(
        onTap: () => NetworkMonitor.instance.refreshNow(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Icon(_icon, size: 18, color: _fg),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _snap.label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _fg,
                  ),
                ),
              ),
              if (_snap.serverDetail != null)
                Text(
                  _snap.serverDetail!,
                  style: TextStyle(fontSize: 11, color: _fg.withOpacity(0.75)),
                ),
              const SizedBox(width: 6),
              Icon(Icons.refresh, size: 16, color: _fg.withOpacity(0.7)),
            ],
          ),
        ),
      ),
    );
  }
}
