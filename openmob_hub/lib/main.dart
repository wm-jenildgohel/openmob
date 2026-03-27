import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:window_manager/window_manager.dart';

import 'server/api_server.dart';
import 'services/adb_service.dart';
import 'services/action_service.dart';
import 'services/device_manager.dart';
import 'services/log_service.dart';
import 'services/process_manager.dart';
import 'services/screenshot_service.dart';
import 'services/ai_tool_setup_service.dart';
import 'services/auto_setup_service.dart';
import 'services/system_check_service.dart';
import 'services/recording_service.dart';
import 'services/scrcpy_stream_service.dart';
import 'services/test_runner_service.dart';
import 'services/ui_tree_service.dart';
import 'services/update_service.dart';
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
late final RecordingService recordingService;
late final LogService logService;
late final SystemCheckService systemCheckService;
late final ProcessManager processManager;
late final AiToolSetupService aiToolSetupService;
late final AutoSetupService autoSetupService;
late final UpdateService updateService;
late final ScrcpyStreamService scrcpyStreamService;
bool mediaKitAvailable = false;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    MediaKit.ensureInitialized();
    mediaKitAvailable = true;
  } catch (e) {
    debugPrint('media_kit init failed (live mirroring disabled): $e');
    mediaKitAvailable = false;
  }
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
  recordingService = RecordingService(adbService, logService: logService);
  scrcpyStreamService = ScrcpyStreamService(adbService, logService: logService);
  systemCheckService = SystemCheckService(logService: logService);
  processManager = ProcessManager(logService);
  aiToolSetupService = AiToolSetupService(logService);
  autoSetupService = AutoSetupService(
    systemCheckService,
    aiToolSetupService,
    processManager,
    logService,
  );
  updateService = UpdateService(logService);

  // Start API server — try the configured port, then try next 4 ports
  apiServer = ApiServer(deviceManager, screenshotService, uiTreeService, actionService, testRunnerService, recordingService);
  bool serverStarted = false;
  for (int attempt = 0; attempt < 5; attempt++) {
    final port = ApiConstants.port + attempt;
    try {
      await apiServer.start(port: port);
      logService.addLine('hub', 'Hub ready on port $port');
      serverStarted = true;
      break;
    } catch (e) {
      if (attempt == 0) {
        logService.addLine('hub', 'Port ${ApiConstants.port} in use — trying alternatives...', level: LogLevel.warning);
      }
      if (attempt < 4) {
        await Future.delayed(const Duration(milliseconds: 200));
      }
    }
  }
  if (!serverStarted) {
    logService.addLine('hub', 'Could not bind to any port (tried ${ApiConstants.port}-${ApiConstants.port + 4}) — close other OpenMob instances and restart', level: LogLevel.error);
  }

  // Clean up child processes when the app window closes
  windowManager.addListener(_AppWindowListener());

  // Run the UI immediately — don't block on device scan or system check
  runApp(const OpenMobApp());

  // Background tasks — run after UI is visible
  _initBackground();
}

Future<void> _initBackground() async {
  // Run device scan + auto-setup + update check ALL in parallel
  // Device scan completes in ~1s, auto-setup in 2-30s — don't let setup block devices
  await Future.wait([
    // Device scan — users see their devices immediately
    () async {
      try {
        await deviceManager.refreshDevices();
      } catch (e) {
        logService.addLine('hub', 'Initial device scan failed: $e', level: LogLevel.warning);
      }
    }(),
    // Auto-setup — installs missing tools, configures AI tools
    () async {
      try {
        await autoSetupService.runAutoSetup();
      } catch (e) {
        logService.addLine('hub', 'Auto-setup failed: $e', level: LogLevel.warning);
      }
    }(),
    // Update check — non-blocking
    () async {
      try {
        await updateService.checkForUpdate();
      } catch (_) {}
    }(),
  ]);

  // Poll devices every 5 seconds
  Stream.periodic(const Duration(seconds: 5)).listen((_) {
    try {
      deviceManager.refreshDevices();
    } catch (_) {}
  });
}

/// Kills child processes (MCP, AiBridge) when the app window closes.
/// Without this, orphan processes keep running and block ports on restart.
class _AppWindowListener extends WindowListener {
  @override
  void onWindowClose() {
    processManager.dispose();
  }
}
