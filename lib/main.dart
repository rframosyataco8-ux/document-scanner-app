import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'screens/home_screen.dart';
import 'services/fcm_service.dart';
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

  // FCM opcional: si no hay google-services.json, la app sigue funcionando
  await FcmService.instance.init();

  // Cola offline siempre activa
  await UploadQueue.instance.start();

  runApp(const DocScanProApp());
}

class DocScanProApp extends StatelessWidget {
  const DocScanProApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DocScan Pro · RomEx',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      home: const HomeScreen(),
    );
  }
}
