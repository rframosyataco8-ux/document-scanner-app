import 'package:flutter/material.dart';
import '../services/network_validator.dart';
import '../theme/app_theme.dart';

/// Bottom sheet con pasos de validación de red en vivo.
Future<bool> showNetworkValidation(
  BuildContext context, {
  bool requireAuth = false,
  String title = 'Validando red',
}) async {
  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    isDismissible: false,
    enableDrag: false,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => _NetworkValidationBody(
      requireAuth: requireAuth,
      title: title,
    ),
  );
  return result == true;
}

class _NetworkValidationBody extends StatefulWidget {
  final bool requireAuth;
  final String title;

  const _NetworkValidationBody({
    required this.requireAuth,
    required this.title,
  });

  @override
  State<_NetworkValidationBody> createState() => _NetworkValidationBodyState();
}

class _NetworkValidationBodyState extends State<_NetworkValidationBody> {
  List<NetStep> _steps = [];
  String _summary = 'Iniciando…';
  bool? _ok;
  bool _running = true;

  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _run() async {
    final result = await NetworkValidator.run(
      requireAuth: widget.requireAuth,
      onStep: (steps) {
        if (mounted) setState(() => _steps = steps);
      },
    );
    if (!mounted) return;
    setState(() {
      _steps = result.steps;
      _summary = result.summary;
      _ok = result.ok;
      _running = false;
    });
    if (result.ok) {
      await Future.delayed(const Duration(milliseconds: 400));
      if (mounted) Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        16,
        20,
        20 + MediaQuery.of(context).padding.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            widget.title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 16),
          ..._steps.map(_stepTile),
          const SizedBox(height: 12),
          if (_summary.isNotEmpty)
            Text(
              _summary,
              style: TextStyle(
                fontSize: 13,
                color: _ok == true
                    ? Colors.green.shade800
                    : _ok == false
                        ? Colors.red.shade800
                        : Colors.grey.shade600,
                fontWeight: FontWeight.w600,
              ),
            ),
          const SizedBox(height: 16),
          if (_running)
            const LinearProgressIndicator(
              color: RomexColors.primary,
              minHeight: 3,
            )
          else if (_ok == false)
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Cerrar'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    onPressed: () {
                      setState(() {
                        _running = true;
                        _ok = null;
                        _summary = 'Reintentando…';
                      });
                      _run();
                    },
                    child: const Text('Reintentar'),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _stepTile(NetStep s) {
    IconData icon;
    Color color;
    switch (s.status) {
      case NetStepStatus.ok:
        icon = Icons.check_circle;
        color = Colors.green;
        break;
      case NetStepStatus.fail:
        icon = Icons.cancel;
        color = Colors.red;
        break;
      case NetStepStatus.running:
        icon = Icons.hourglass_top;
        color = RomexColors.primary;
        break;
      case NetStepStatus.skip:
        icon = Icons.remove_circle_outline;
        color = Colors.grey;
        break;
      case NetStepStatus.pending:
        icon = Icons.radio_button_unchecked;
        color = Colors.grey.shade400;
        break;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (s.status == NetStepStatus.running)
            const SizedBox(
              width: 22,
              height: 22,
              child: Padding(
                padding: EdgeInsets.all(2),
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            Icon(icon, size: 22, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(s.title, style: const TextStyle(fontWeight: FontWeight.w600)),
                Text(
                  s.detail,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
