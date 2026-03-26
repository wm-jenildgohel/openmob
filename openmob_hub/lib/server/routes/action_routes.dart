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
      final duration = (body['duration'] as num?)?.toInt() ?? 300;

      int x1, y1, x2, y2;

      if (body.containsKey('direction')) {
        // Convert direction to coordinates using device screen center
        final screenW = device.screenWidth > 0 ? device.screenWidth : 1080;
        final screenH = device.screenHeight > 0 ? device.screenHeight : 1920;
        final centerX = screenW ~/ 2;
        final centerY = screenH ~/ 2;
        final swipeDistance = screenH ~/ 3;

        switch (body['direction'] as String) {
          case 'up':
            x1 = centerX; y1 = centerY + swipeDistance ~/ 2;
            x2 = centerX; y2 = centerY - swipeDistance ~/ 2;
          case 'down':
            x1 = centerX; y1 = centerY - swipeDistance ~/ 2;
            x2 = centerX; y2 = centerY + swipeDistance ~/ 2;
          case 'left':
            x1 = centerX + swipeDistance ~/ 2; y1 = centerY;
            x2 = centerX - swipeDistance ~/ 2; y2 = centerY;
          case 'right':
            x1 = centerX - swipeDistance ~/ 2; y1 = centerY;
            x2 = centerX + swipeDistance ~/ 2; y2 = centerY;
          default:
            return Response.badRequest(
              body: jsonEncode({'error': 'Invalid direction. Use: up, down, left, right'}),
            );
        }
      } else {
        x1 = (body['x1'] as num).toInt();
        y1 = (body['y1'] as num).toInt();
        x2 = (body['x2'] as num).toInt();
        y2 = (body['y2'] as num).toInt();
      }

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

  // POST /<id>/unlock -> wake screen + swipe to unlock
  router.post('/<id>/unlock', (Request request, String id) async {
    final device = dm.getDevice(id);
    if (device == null) {
      return Response.notFound(jsonEncode({'error': 'Device not found'}));
    }
    try {
      final result = await action.unlockDevice(device.serial);
      return Response.ok(jsonEncode(result.toJson()));
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({'error': 'Unlock failed: $e'}),
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
