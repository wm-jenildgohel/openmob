import 'dart:convert';

import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '../../models/test_script.dart';
import '../../services/test_runner_service.dart';

Router testRoutes(TestRunnerService runner) {
  final router = Router();

  // GET / -- list all saved test scripts
  router.get('/', (Request request) {
    final scripts = runner.scripts$.value.map((s) => s.toJson()).toList();
    return Response.ok(
      jsonEncode(scripts),
      headers: {'Content-Type': 'application/json'},
    );
  });

  // GET /results -- list all test results
  router.get('/results', (Request request) {
    final results = runner.results$.value.map((r) => r.toJson()).toList();
    return Response.ok(
      jsonEncode(results),
      headers: {'Content-Type': 'application/json'},
    );
  });

  // GET /results/current -- get currently running test result or null
  router.get('/results/current', (Request request) {
    final current = runner.currentRun$.value;
    return Response.ok(
      jsonEncode(current?.toJson()),
      headers: {'Content-Type': 'application/json'},
    );
  });

  // POST / -- create/save a test script
  router.post('/', (Request request) async {
    try {
      final body =
          jsonDecode(await request.readAsString()) as Map<String, dynamic>;
      final script = TestScript.fromJson(body);
      runner.addScript(script);
      return Response(
        201,
        body: jsonEncode(script.toJson()),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({'error': 'Failed to create script: $e'}),
      );
    }
  });

  // DELETE /<id> -- remove a test script
  router.delete('/<id>', (Request request, String id) {
    runner.removeScript(id);
    return Response.ok(
      jsonEncode({'deleted': true}),
      headers: {'Content-Type': 'application/json'},
    );
  });

  // POST /<id>/run -- execute a test script by id
  router.post('/<id>/run', (Request request, String id) async {
    try {
      final result = await runner.runScript(id);
      return Response.ok(
        jsonEncode(result.toJson()),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({'error': 'Test execution failed: $e'}),
      );
    }
  });

  // POST /flutter-test -- run a flutter test directly
  router.post('/flutter-test', (Request request) async {
    try {
      final body =
          jsonDecode(await request.readAsString()) as Map<String, dynamic>;
      final path = body['path'] as String;
      final deviceId = (body['device_id'] as String?) ?? '';

      final script = TestScript(
        name: 'Flutter Test: $path',
        deviceId: deviceId,
        flutterTestPath: path,
      );
      runner.addScript(script);
      final result = await runner.runScript(script.id);
      return Response.ok(
        jsonEncode(result.toJson()),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({'error': 'Flutter test failed: $e'}),
      );
    }
  });

  return router;
}
