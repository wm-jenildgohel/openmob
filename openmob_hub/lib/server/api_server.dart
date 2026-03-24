import 'dart:convert';
import 'dart:io';

import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';

import '../core/constants.dart';
import 'middleware/cors_middleware.dart';
import 'middleware/json_middleware.dart';

class ApiServer {
  final Router _router = Router();
  HttpServer? _server;

  ApiServer() {
    _router.get('/health', _healthHandler);

    // TODO: device_routes
    // TODO: action_routes
  }

  Response _healthHandler(Request request) {
    return Response.ok(
      jsonEncode({'status': 'ok'}),
      headers: {'Content-Type': 'application/json'},
    );
  }

  Future<void> start() async {
    final handler = const Pipeline()
        .addMiddleware(logRequests())
        .addMiddleware(corsMiddleware())
        .addMiddleware(jsonMiddleware())
        .addHandler(_router.call);

    _server = await shelf_io.serve(
      handler,
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
