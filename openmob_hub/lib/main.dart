import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import 'server/api_server.dart';
import 'services/adb_service.dart';
import 'services/action_service.dart';
import 'services/device_manager.dart';
import 'services/log_service.dart';
import 'services/process_manager.dart';
import 'services/screenshot_service.dart';
import 'services/system_check_service.dart';
import 'services/test_runner_service.dart';
import 'services/ui_tree_service.dart';
import 'services/simctl_service.dart';
import 'services/idb_service.dart';
import 'core/constants.dart';
import 'app.dart';

late final AdbService adbService;
late final DeviceManager deviceManager;
late final ScreenshotService screenshotService;
late final UiTreeService uiTreeService;
late final ActionService actionService;
late final ApiServer apiServer;
late final TestRunnerService testRunnerService;
late final LogService logService;
late final SystemCheckService systemCheckService;
late final ProcessManager processManager;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await windowManager.ensureInitialized();

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

  // Initialize logging first — everything else can log errors to it
  logService = LogService();

  // Initialize core services with safe defaults
  adbService = AdbService();
  final simctlService = SimctlService();
  final idbService = IdbService();

  // Check iOS tool availability (safe — returns false on error)
  var simctlAvail = false;
  var idbAvail = false;
  try {
    simctlAvail = await simctlService.isAvailable;
    idbAvail = await idbService.isAvailable;
  } catch (e) {
    logService.addLine('hub', 'iOS tool check failed: $e', level: LogLevel.warning);
  }

  deviceManager = DeviceManager(
    adbService,
    simctl: simctlAvail ? simctlService : null,
    idb: idbAvail ? idbService : null,
  );
  screenshotService = ScreenshotService(
    adbService,
    simctl: simctlAvail ? simctlService : null,
    dm: deviceManager,
  );
  uiTreeService = UiTreeService(
    adbService,
    idb: idbAvail ? idbService : null,
    dm: deviceManager,
  );
  actionService = ActionService(
    adbService,
    uiTreeService,
    simctl: simctlAvail ? simctlService : null,
    idb: idbAvail ? idbService : null,
    dm: deviceManager,
  );
  testRunnerService = TestRunnerService(
    actionService,
    screenshotService,
    deviceManager,
    logService,
    uiTree: uiTreeService,
  );
  systemCheckService = SystemCheckService();
  processManager = ProcessManager(logService);

  // Start API server — if port is busy, log error but don't crash
  apiServer = ApiServer(deviceManager, screenshotService, uiTreeService, actionService, testRunnerService);
  try {
    await apiServer.start();
    logService.addLine('hub', 'API server started on port ${ApiConstants.port}');
  } catch (e) {
    logService.addLine('hub', 'API server failed to start: $e', level: LogLevel.error);
  }

  // Run the UI immediately — don't block on device scan or system check
  runApp(const OpenMobApp());

  // Background tasks — run after UI is visible
  _initBackground();
}

Future<void> _initBackground() async {
  // System check
  try {
    await systemCheckService.checkAll();
  } catch (e) {
    logService.addLine('hub', 'System check failed: $e', level: LogLevel.warning);
  }

  // Initial device scan
  try {
    await deviceManager.refreshDevices();
  } catch (e) {
    logService.addLine('hub', 'Initial device scan failed: $e', level: LogLevel.warning);
  }

  // Poll devices every 5 seconds
  Stream.periodic(const Duration(seconds: 5)).listen((_) {
    try {
      deviceManager.refreshDevices();
    } catch (_) {}
  });
}
