import 'dart:convert';

import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '../../services/action_service.dart';
import '../../services/device_manager.dart';

Router actionRoutes(ActionService action, DeviceManager dm) {
  final router = Router();

  // POST /<id>/tap -> tap at coordinates or by element index
  router.post('/<id>/tap', (Request request, String id) async {
    final device = dm.getDevice(id);
    if (device == null) {
      return Response.notFound(jsonEncode({'error': 'Device not found'}));
    }
    try {
      final body = jsonDecode(await request.readAsString()) as Map<String, dynamic>;
      if (body.containsKey('index')) {
        final index = (body['index'] as num).toInt();
        final result = await action.tapElement(device.serial, index);
        return Response.ok(jsonEncode(result.toJson()));
      }
      final x = (body['x'] as num).toInt();
      final y = (body['y'] as num).toInt();
      final result = await action.tap(device.serial, x, y);
      return Response.ok(jsonEncode(result.toJson()));
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({'error': 'Tap failed: $e'}),
      );
    }
  });

  // POST /<id>/swipe -> swipe gesture
  router.post('/<id>/swipe', (Request request, String id) async {
    final device = dm.getDevice(id);
    if (device == null) {
      return Response.notFound(jsonEncode({'error': 'Device not found'}));
    }
    try {
      final body = jsonDecode(await request.readAsString()) as Map<String, dynamic>;
      final x1 = (body['x1'] as num).toInt();
      final y1 = (body['y1'] as num).toInt();
      final x2 = (body['x2'] as num).toInt();
      final y2 = (body['y2'] as num).toInt();
      final duration = (body['duration'] as num?)?.toInt() ?? 300;
      final result = await action.swipe(device.serial, x1, y1, x2, y2, durationMs: duration);
      return Response.ok(jsonEncode(result.toJson()));
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({'error': 'Swipe failed: $e'}),
      );
    }
  });

  // POST /<id>/type -> type text
  router.post('/<id>/type', (Request request, String id) async {
    final device = dm.getDevice(id);
    if (device == null) {
      return Response.notFound(jsonEncode({'error': 'Device not found'}));
    }
    try {
      final body = jsonDecode(await request.readAsString()) as Map<String, dynamic>;
      final text = body['text'] as String;
      final result = await action.typeText(device.serial, text);
      return Response.ok(jsonEncode(result.toJson()));
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({'error': 'Type failed: $e'}),
      );
    }
  });

  // POST /<id>/keyevent -> send key event
  router.post('/<id>/keyevent', (Request request, String id) async {
    final device = dm.getDevice(id);
    if (device == null) {
      return Response.notFound(jsonEncode({'error': 'Device not found'}));
    }
    try {
      final body = jsonDecode(await request.readAsString()) as Map<String, dynamic>;
      final keyCode = (body['keyCode'] as num).toInt();
      final result = await action.pressKey(device.serial, keyCode);
      return Response.ok(jsonEncode(result.toJson()));
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({'error': 'Keyevent failed: $e'}),
      );
    }
  });

  // POST /<id>/launch -> launch app by package name
  router.post('/<id>/launch', (Request request, String id) async {
    final device = dm.getDevice(id);
    if (device == null) {
      return Response.notFound(jsonEncode({'error': 'Device not found'}));
    }
    try {
      final body = jsonDecode(await request.readAsString()) as Map<String, dynamic>;
      final packageName = body['package'] as String;
      final result = await action.launchApp(device.serial, packageName);
      return Response.ok(jsonEncode(result.toJson()));
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({'error': 'Launch failed: $e'}),
      );
    }
  });

  // POST /<id>/terminate -> force-stop app by package name
  router.post('/<id>/terminate', (Request request, String id) async {
    final device = dm.getDevice(id);
    if (device == null) {
      return Response.notFound(jsonEncode({'error': 'Device not found'}));
    }
    try {
      final body = jsonDecode(await request.readAsString()) as Map<String, dynamic>;
      final packageName = body['package'] as String;
      final result = await action.terminateApp(device.serial, packageName);
      return Response.ok(jsonEncode(result.toJson()));
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({'error': 'Terminate failed: $e'}),
      );
    }
  });

  // POST /<id>/open-url -> open URL on device
  router.post('/<id>/open-url', (Request request, String id) async {
    final device = dm.getDevice(id);
    if (device == null) {
      return Response.notFound(jsonEncode({'error': 'Device not found'}));
    }
    try {
      final body = jsonDecode(await request.readAsString()) as Map<String, dynamic>;
      final url = body['url'] as String;
      final result = await action.openUrl(device.serial, url);
      return Response.ok(jsonEncode(result.toJson()));
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({'error': 'Open URL failed: $e'}),
      );
    }
  });

  // POST /<id>/gesture -> execute named gesture
  router.post('/<id>/gesture', (Request request, String id) async {
    final device = dm.getDevice(id);
    if (device == null) {
      return Response.notFound(jsonEncode({'error': 'Device not found'}));
    }
    try {
      final body = jsonDecode(await request.readAsString()) as Map<String, dynamic>;
      final type = body['type'] as String;
      final params = Map<String, dynamic>.from(body);
      params.remove('type');
      final result = await action.gesture(device.serial, type, params);
      return Response.ok(jsonEncode(result.toJson()));
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({'error': 'Gesture failed: $e'}),
      );
    }
  });

  return router;
}
