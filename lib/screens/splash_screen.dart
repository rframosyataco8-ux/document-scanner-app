import 'dart:async';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'home_screen.dart';

/// Pantalla de entrada con animación de marca RomEx / DocScan Pro.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );
    _scale = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack);
    _fade = CurvedAnimation(
      parent: _ctrl,
      curve: const Interval(0.15, 1.0, curve: Curves.easeOut),
    );
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.25),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _ctrl,
      curve: const Interval(0.2, 1.0, curve: Curves.easeOutCubic),
    ));

    _ctrl.forward();
    Timer(const Duration(milliseconds: 1700), _goHome);
  }

  void _goHome() {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => const HomeScreen(),
        transitionsBuilder: (_, anim, __, child) {
          return FadeTransition(opacity: anim, child: child);
        },
        transitionDuration: const Duration(milliseconds: 380),
      ),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: RomexColors.surface,
      body: Center(
        child: FadeTransition(
          opacity: _fade,
          child: SlideTransition(
            position: _slide,
            child: ScaleTransition(
              scale: _scale,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 108,
                    height: 108,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: [
                          RomexColors.primaryLight,
                          RomexColors.primaryDark,
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: RomexColors.primary.withValues(alpha: 0.35),
                          blurRadius: 28,
                          offset: const Offset(0, 12),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.document_scanner_rounded,
                      size: 52,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 28),
                  Text(
                    'DocScan Pro',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: Colors.grey.shade900,
                      letterSpacing: -0.6,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'RomEx · Guías de Cacao',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: RomexColors.primary,
                    ),
                  ),
                  const SizedBox(height: 36),
                  SizedBox(
                    width: 28,
                    height: 28,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: RomexColors.primary.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
