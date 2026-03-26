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

  // POST /<id>/double-tap -> double tap at coordinates or by element index
  router.post('/<id>/double-tap', (Request request, String id) async {
    final device = dm.getDevice(id);
    if (device == null) {
      return Response.notFound(jsonEncode({'error': 'Device not found'}));
    }
    try {
      final body = jsonDecode(await request.readAsString()) as Map<String, dynamic>;
      if (body.containsKey('index')) {
        final index = (body['index'] as num).toInt();
        final result = await action.doubleTapElement(device.serial, index);
        return Response.ok(jsonEncode(result.toJson()));
      }
      final x = (body['x'] as num).toInt();
      final y = (body['y'] as num).toInt();
      final result = await action.doubleTap(device.serial, x, y);
      return Response.ok(jsonEncode(result.toJson()));
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({'error': 'Double tap failed: $e'}),
      );
    }
  });

  // POST /<id>/long-press -> long press at coordinates or by element index
  router.post('/<id>/long-press', (Request request, String id) async {
    final device = dm.getDevice(id);
    if (device == null) {
      return Response.notFound(jsonEncode({'error': 'Device not found'}));
    }
    try {
      final body = jsonDecode(await request.readAsString()) as Map<String, dynamic>;
      final duration = (body['duration'] as num?)?.toInt() ?? 1500;
      if (body.containsKey('index')) {
        final index = (body['index'] as num).toInt();
        final result = await action.longPressElement(device.serial, index, durationMs: duration);
        return Response.ok(jsonEncode(result.toJson()));
      }
      final x = (body['x'] as num).toInt();
      final y = (body['y'] as num).toInt();
      final result = await action.longPress(device.serial, x, y, durationMs: duration);
      return Response.ok(jsonEncode(result.toJson()));
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({'error': 'Long press failed: $e'}),
      );
    }
  });

  // POST /<id>/type -> type text (with optional submit)
  router.post('/<id>/type', (Request request, String id) async {
    final device = dm.getDevice(id);
    if (device == null) {
      return Response.notFound(jsonEncode({'error': 'Device not found'}));
    }
    try {
      final body = jsonDecode(await request.readAsString()) as Map<String, dynamic>;
      final text = body['text'] as String;
      final submit = body['submit'] as bool? ?? false;
      final result = await action.typeText(device.serial, text, submit: submit);
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

  // POST /<id>/install -> install APK from local path
  router.post('/<id>/install', (Request request, String id) async {
    final device = dm.getDevice(id);
    if (device == null) return Response.notFound(jsonEncode({'error': 'Device not found'}));
    try {
      final body = jsonDecode(await request.readAsString()) as Map<String, dynamic>;
      final apkPath = body['path'] as String;
      final replace = body['replace'] as bool? ?? true;
      final grantPerms = body['grant_permissions'] as bool? ?? true;
      final result = await action.installApp(device.serial, apkPath, replace: replace, grantPermissions: grantPerms);
      return Response.ok(jsonEncode(result.toJson()));
    } catch (e) {
      return Response.internalServerError(body: jsonEncode({'error': 'Install failed: $e'}));
    }
  });

  // POST /<id>/uninstall -> uninstall app
  router.post('/<id>/uninstall', (Request request, String id) async {
    final device = dm.getDevice(id);
    if (device == null) return Response.notFound(jsonEncode({'error': 'Device not found'}));
    try {
      final body = jsonDecode(await request.readAsString()) as Map<String, dynamic>;
      final packageName = body['package'] as String;
      final result = await action.uninstallApp(device.serial, packageName);
      return Response.ok(jsonEncode(result.toJson()));
    } catch (e) {
      return Response.internalServerError(body: jsonEncode({'error': 'Uninstall failed: $e'}));
    }
  });

  // GET /<id>/apps -> list installed apps
  router.get('/<id>/apps', (Request request, String id) async {
    final device = dm.getDevice(id);
    if (device == null) return Response.notFound(jsonEncode({'error': 'Device not found'}));
    try {
      final thirdParty = request.url.queryParameters['third_party'] != 'false';
      final result = await action.listApps(device.serial, thirdPartyOnly: thirdParty);
      return Response.ok(jsonEncode(result.toJson()));
    } catch (e) {
      return Response.internalServerError(body: jsonEncode({'error': 'List apps failed: $e'}));
    }
  });

  // GET /<id>/current-activity -> get foreground app/activity
  router.get('/<id>/current-activity', (Request request, String id) async {
    final device = dm.getDevice(id);
    if (device == null) return Response.notFound(jsonEncode({'error': 'Device not found'}));
    try {
      final result = await action.getCurrentActivity(device.serial);
      return Response.ok(jsonEncode(result.toJson()));
    } catch (e) {
      return Response.internalServerError(body: jsonEncode({'error': 'Get activity failed: $e'}));
    }
  });

  // POST /<id>/clear-data -> clear app data
  router.post('/<id>/clear-data', (Request request, String id) async {
    final device = dm.getDevice(id);
    if (device == null) return Response.notFound(jsonEncode({'error': 'Device not found'}));
    try {
      final body = jsonDecode(await request.readAsString()) as Map<String, dynamic>;
      final packageName = body['package'] as String;
      final result = await action.clearAppData(device.serial, packageName);
      return Response.ok(jsonEncode(result.toJson()));
    } catch (e) {
      return Response.internalServerError(body: jsonEncode({'error': 'Clear data failed: $e'}));
    }
  });

  // GET /<id>/logcat -> get device logs
  router.get('/<id>/logcat', (Request request, String id) async {
    final device = dm.getDevice(id);
    if (device == null) return Response.notFound(jsonEncode({'error': 'Device not found'}));
    try {
      final lines = int.tryParse(request.url.queryParameters['lines'] ?? '') ?? 100;
      final tag = request.url.queryParameters['tag'];
      final level = request.url.queryParameters['level'];
      final result = await action.getLogcat(device.serial, lines: lines, tag: tag, level: level);
      return Response.ok(jsonEncode(result.toJson()));
    } catch (e) {
      return Response.internalServerError(body: jsonEncode({'error': 'Logcat failed: $e'}));
    }
  });

  // DELETE /<id>/logcat -> clear logcat buffer
  router.delete('/<id>/logcat', (Request request, String id) async {
    final device = dm.getDevice(id);
    if (device == null) return Response.notFound(jsonEncode({'error': 'Device not found'}));
    try {
      final result = await action.clearLogcat(device.serial);
      return Response.ok(jsonEncode(result.toJson()));
    } catch (e) {
      return Response.internalServerError(body: jsonEncode({'error': 'Clear logcat failed: $e'}));
    }
  });

  // POST /<id>/wait-for-element -> wait until element appears
  router.post('/<id>/wait-for-element', (Request request, String id) async {
    final device = dm.getDevice(id);
    if (device == null) return Response.notFound(jsonEncode({'error': 'Device not found'}));
    try {
      final body = jsonDecode(await request.readAsString()) as Map<String, dynamic>;
      final text = body['text'] as String?;
      final resourceId = body['resource_id'] as String?;
      final timeout = (body['timeout_ms'] as num?)?.toInt() ?? 10000;
      final poll = (body['poll_ms'] as num?)?.toInt() ?? 500;
      final result = await action.waitForElement(device.serial, text: text, resourceId: resourceId, timeoutMs: timeout, pollMs: poll);
      return Response.ok(jsonEncode(result.toJson()));
    } catch (e) {
      return Response.internalServerError(body: jsonEncode({'error': 'Wait failed: $e'}));
    }
  });

  // POST /<id>/file/push -> push file to device
  router.post('/<id>/file/push', (Request request, String id) async {
    final device = dm.getDevice(id);
    if (device == null) return Response.notFound(jsonEncode({'error': 'Device not found'}));
    try {
      final body = jsonDecode(await request.readAsString()) as Map<String, dynamic>;
      final result = await action.pushFile(device.serial, body['local'] as String, body['remote'] as String);
      return Response.ok(jsonEncode(result.toJson()));
    } catch (e) {
      return Response.internalServerError(body: jsonEncode({'error': 'Push failed: $e'}));
    }
  });

  // POST /<id>/file/pull -> pull file from device
  router.post('/<id>/file/pull', (Request request, String id) async {
    final device = dm.getDevice(id);
    if (device == null) return Response.notFound(jsonEncode({'error': 'Device not found'}));
    try {
      final body = jsonDecode(await request.readAsString()) as Map<String, dynamic>;
      final result = await action.pullFile(device.serial, body['remote'] as String, body['local'] as String);
      return Response.ok(jsonEncode(result.toJson()));
    } catch (e) {
      return Response.internalServerError(body: jsonEncode({'error': 'Pull failed: $e'}));
    }
  });

  // GET /<id>/files -> list files on device
  router.get('/<id>/files', (Request request, String id) async {
    final device = dm.getDevice(id);
    if (device == null) return Response.notFound(jsonEncode({'error': 'Device not found'}));
    try {
      final path = request.url.queryParameters['path'] ?? '/sdcard/';
      final result = await action.listFiles(device.serial, path);
      return Response.ok(jsonEncode(result.toJson()));
    } catch (e) {
      return Response.internalServerError(body: jsonEncode({'error': 'List files failed: $e'}));
    }
  });

  // POST /<id>/wifi -> toggle WiFi
  router.post('/<id>/wifi', (Request request, String id) async {
    final device = dm.getDevice(id);
    if (device == null) return Response.notFound(jsonEncode({'error': 'Device not found'}));
    try {
      final body = jsonDecode(await request.readAsString()) as Map<String, dynamic>;
      final result = await action.setWifi(device.serial, body['enabled'] as bool);
      return Response.ok(jsonEncode(result.toJson()));
    } catch (e) {
      return Response.internalServerError(body: jsonEncode({'error': 'WiFi toggle failed: $e'}));
    }
  });

  // POST /<id>/airplane -> toggle airplane mode
  router.post('/<id>/airplane', (Request request, String id) async {
    final device = dm.getDevice(id);
    if (device == null) return Response.notFound(jsonEncode({'error': 'Device not found'}));
    try {
      final body = jsonDecode(await request.readAsString()) as Map<String, dynamic>;
      final result = await action.setAirplaneMode(device.serial, body['enabled'] as bool);
      return Response.ok(jsonEncode(result.toJson()));
    } catch (e) {
      return Response.internalServerError(body: jsonEncode({'error': 'Airplane toggle failed: $e'}));
    }
  });

  // POST /<id>/rotation -> set screen rotation
  router.post('/<id>/rotation', (Request request, String id) async {
    final device = dm.getDevice(id);
    if (device == null) return Response.notFound(jsonEncode({'error': 'Device not found'}));
    try {
      final body = jsonDecode(await request.readAsString()) as Map<String, dynamic>;
      final result = await action.setRotation(device.serial, (body['rotation'] as num).toInt());
      return Response.ok(jsonEncode(result.toJson()));
    } catch (e) {
      return Response.internalServerError(body: jsonEncode({'error': 'Rotation failed: $e'}));
    }
  });

  // POST /<id>/grant-permissions -> grant all runtime permissions
  router.post('/<id>/grant-permissions', (Request request, String id) async {
    final device = dm.getDevice(id);
    if (device == null) return Response.notFound(jsonEncode({'error': 'Device not found'}));
    try {
      final body = jsonDecode(await request.readAsString()) as Map<String, dynamic>;
      final result = await action.grantAllPermissions(device.serial, body['package'] as String);
      return Response.ok(jsonEncode(result.toJson()));
    } catch (e) {
      return Response.internalServerError(body: jsonEncode({'error': 'Grant permissions failed: $e'}));
    }
  });

  // GET /<id>/keyboard -> check if keyboard is showing
  router.get('/<id>/keyboard', (Request request, String id) async {
    final device = dm.getDevice(id);
    if (device == null) return Response.notFound(jsonEncode({'error': 'Device not found'}));
    try {
      final result = await action.isKeyboardShowing(device.serial);
      return Response.ok(jsonEncode(result.toJson()));
    } catch (e) {
      return Response.internalServerError(body: jsonEncode({'error': 'Keyboard check failed: $e'}));
    }
  });

  // POST /<id>/record/start -> start screen recording
  router.post('/<id>/record/start', (Request request, String id) async {
    final device = dm.getDevice(id);
    if (device == null) return Response.notFound(jsonEncode({'error': 'Device not found'}));
    try {
      final body = jsonDecode(await request.readAsString()) as Map<String, dynamic>;
      final duration = (body['max_duration'] as num?)?.toInt() ?? 180;
      final result = await action.startScreenRecording(device.serial, maxDurationSec: duration);
      return Response.ok(jsonEncode(result.toJson()));
    } catch (e) {
      return Response.internalServerError(body: jsonEncode({'error': 'Recording failed: $e'}));
    }
  });

  // POST /<id>/record/stop -> stop screen recording
  router.post('/<id>/record/stop', (Request request, String id) async {
    final device = dm.getDevice(id);
    if (device == null) return Response.notFound(jsonEncode({'error': 'Device not found'}));
    try {
      final result = await action.stopScreenRecording(device.serial);
      return Response.ok(jsonEncode(result.toJson()));
    } catch (e) {
      return Response.internalServerError(body: jsonEncode({'error': 'Stop recording failed: $e'}));
    }
  });

  // GET /<id>/notifications -> get notification bar content
  router.get('/<id>/notifications', (Request request, String id) async {
    final device = dm.getDevice(id);
    if (device == null) return Response.notFound(jsonEncode({'error': 'Device not found'}));
    try {
      final result = await action.getNotifications(device.serial);
      return Response.ok(jsonEncode(result.toJson()));
    } catch (e) {
      return Response.internalServerError(body: jsonEncode({'error': 'Get notifications failed: $e'}));
    }
  });

  return router;
}
