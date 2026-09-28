import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'screens/home_screen.dart';
import 'screens/splash_screen.dart';
import 'services/network_monitor.dart';
import 'services/upload_queue.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );

  // Arranque en paralelo: no bloquea el splash
  unawaited(UploadQueue.instance.start());
  unawaited(NetworkMonitor.instance.start());

  runApp(const DocScanProApp());
}

void unawaited(Future<void> f) {}

class DocScanProApp extends StatelessWidget {
  const DocScanProApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DocScan Pro · RomEx',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      home: const SplashScreen(),
    );
  }
}
