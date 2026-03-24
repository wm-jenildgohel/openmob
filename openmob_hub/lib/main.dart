import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import 'server/api_server.dart';
import 'services/adb_service.dart';
import 'services/action_service.dart';
import 'services/device_manager.dart';
import 'services/screenshot_service.dart';
import 'services/ui_tree_service.dart';
import 'app.dart';

late final AdbService adbService;
late final DeviceManager deviceManager;
late final ScreenshotService screenshotService;
late final UiTreeService uiTreeService;
late final ActionService actionService;
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
  deviceManager = DeviceManager(adbService);
  screenshotService = ScreenshotService(adbService);
  uiTreeService = UiTreeService(adbService);
  actionService = ActionService(adbService, uiTreeService);

  // Start API server with all services wired in
  apiServer = ApiServer(deviceManager, screenshotService, uiTreeService, actionService);
  await apiServer.start();

  // Initial device scan
  await deviceManager.refreshDevices();

  // Poll devices every 5 seconds for real-time status
  Stream.periodic(const Duration(seconds: 5)).listen((_) {
    deviceManager.refreshDevices();
  });

  runApp(const OpenMobApp());
}
