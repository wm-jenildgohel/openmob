import 'dart:io';

import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';

import '../core/constants.dart';
import '../services/action_service.dart';
import '../services/device_manager.dart';
import '../services/screenshot_service.dart';
import '../services/ui_tree_service.dart';
import 'middleware/cors_middleware.dart';
import 'middleware/json_middleware.dart';
import 'routes/action_routes.dart';
import 'routes/device_routes.dart';
import 'routes/health_routes.dart';

class ApiServer {
  HttpServer? _server;
  late final Handler _handler;

  ApiServer(
    DeviceManager dm,
    ScreenshotService ss,
    UiTreeService uts,
    ActionService action,
  ) {
    // Build a top-level router that delegates to sub-routers.
    // Device routes (GET endpoints) and action routes (POST endpoints)
    // are under the same prefix, so we use Cascade to try both.
    final deviceRouter = deviceRoutes(dm, ss, uts);
    final actionRouter = actionRoutes(action, dm);

    final router = Router();
    router.mount('/', healthRoutes().call);

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

  Future<void> start() async {
    _server = await shelf_io.serve(
      _handler,
      InternetAddress.loopbackIPv4,
      ApiConstants.port,
    );

    print('API server running on http://127.0.0.1:${ApiConstants.port}');
  }

  Future<void> stop() async {
    await _server?.close(force: true);
    _server = null;
    print('API server stopped');
  }
}
