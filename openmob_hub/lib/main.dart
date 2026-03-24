import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import 'server/api_server.dart';
import 'services/adb_service.dart';
import 'app.dart';

late final AdbService adbService;
late final ApiServer apiServer;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await windowManager.ensureInitialized();

  // Configure window
  const windowOptions = WindowOptions(
    size: Size(1024, 768),
    minimumSize: Size(800, 600),
    title: 'OpenMob Hub',
    center: true,
  );
  await windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.show();
    await windowManager.focus();
  });

  // Initialize services
  adbService = AdbService();
  apiServer = ApiServer();
  await apiServer.start();

  runApp(const OpenMobApp());
}
