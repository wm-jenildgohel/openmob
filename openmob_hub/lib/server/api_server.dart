import 'dart:io';

import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';

import '../core/constants.dart';
import '../services/action_service.dart';
import '../services/device_manager.dart';
import '../services/screenshot_service.dart';
import '../services/recording_service.dart';
import '../services/test_runner_service.dart';
import '../services/ui_tree_service.dart';
import 'middleware/cors_middleware.dart';
import 'middleware/json_middleware.dart';
import 'routes/action_routes.dart';
import 'routes/device_routes.dart';
import 'routes/health_routes.dart';
import 'routes/recording_routes.dart';
import 'routes/test_routes.dart';

class ApiServer {
  HttpServer? _server;
  late final Handler _handler;

  ApiServer(
    DeviceManager dm,
    ScreenshotService ss,
    UiTreeService uts,
    ActionService action,
    TestRunnerService testRunner,
    RecordingService recordingSvc,
  ) {
    final deviceRouter = deviceRoutes(dm, ss, uts, action);
    final actionRouter = actionRoutes(action, dm);
    final testRouter = testRoutes(testRunner);
    final recRouter = recordingRoutes(recordingSvc);

    final router = Router();
    router.mount('/', healthRoutes().call);

    // Mount test routes at /api/v1/tests/
    router.mount(
      '${ApiConstants.apiPrefix}/tests/',
      testRouter.call,
    );

    // Mount recording routes at /api/v1/recordings/
    router.mount(
      '${ApiConstants.apiPrefix}/recordings/',
      recRouter.call,
    );

    // Cascade tries device routes first, then action routes on 404
    final deviceActionCascade = Cascade()
        .add(deviceRouter.call)
        .add(actionRouter.call);

    router.mount(
      '${ApiConstants.apiPrefix}/devices/',
      deviceActionCascade.handler,
    );

    _handler = const Pipeline()
        .addMiddleware(logRequests())
        .addMiddleware(corsMiddleware())
        .addMiddleware(jsonMiddleware())
        .addHandler(router.call);
  }

  int _activePort = ApiConstants.port;

  /// The port the server is actually running on (may differ from default if port was in use)
  int get activePort => _activePort;

  Future<void> start({int? port}) async {
    _activePort = port ?? ApiConstants.port;
    _server = await shelf_io.serve(
      _handler,
      InternetAddress.loopbackIPv4,
      _activePort,
    );

    print('API server running on http://127.0.0.1:$_activePort');
  }

  Future<void> stop() async {
    await _server?.close(force: true);
    _server = null;
    print('API server stopped');
  }
}
