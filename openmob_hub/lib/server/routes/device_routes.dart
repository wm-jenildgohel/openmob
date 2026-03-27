import 'dart:convert';

import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '../../models/ui_node.dart';
import '../../services/action_service.dart';
import '../../services/device_manager.dart';
import '../../services/screenshot_service.dart';
import '../../services/ui_tree_service.dart';

Router deviceRoutes(
  DeviceManager dm,
  ScreenshotService ss,
  UiTreeService uts,
  ActionService action,
) {
  final router = Router();

  // GET / -> list all devices
  router.get('/', (Request request) {
    final devices = dm.currentDevices.map((d) => d.toJson()).toList();
    return Response.ok(jsonEncode(devices));
  });

  // GET /<id> -> single device detail
  router.get('/<id>', (Request request, String id) {
    final device = dm.getDevice(id);
    if (device == null) {
      return Response.notFound(jsonEncode({'error': 'Device not found'}));
    }
    return Response.ok(jsonEncode(device.toJson()));
  });

  // GET /<id>/screenshot -> capture and return base64 screenshot
  router.get('/<id>/screenshot', (Request request, String id) async {
    final device = dm.getDevice(id);
    if (device == null) {
      return Response.notFound(jsonEncode({'error': 'Device not found'}));
    }
    try {
      final result = await ss.captureScreenshot(device.serial);
      return Response.ok(jsonEncode({
        'screenshot': result.base64,
        'width': result.width,
        'height': result.height,
      }));
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({'error': 'Screenshot failed: $e'}),
      );
    }
  });

  // GET /<id>/ui-tree -> dump UI tree with optional filter
  router.get('/<id>/ui-tree', (Request request, String id) async {
    final device = dm.getDevice(id);
    if (device == null) {
      return Response.notFound(jsonEncode({'error': 'Device not found'}));
    }
    try {
      final textParam = request.url.queryParameters['text'];
      final visibleParam = request.url.queryParameters['visible'];

      UiTreeFilter? filter;
      if (textParam != null || visibleParam != null) {
        filter = UiTreeFilter(
          textPattern: textParam != null ? RegExp(textParam) : null,
          visibleOnly: visibleParam == 'true' ? true : null,
        );
      }

      final nodes = await uts.getUiTree(device.serial, filter: filter);
      return Response.ok(jsonEncode({
        'nodes': nodes.map((n) => n.toJson()).toList(),
      }));
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({'error': 'UI tree failed: $e'}),
      );
    }
  });

  // POST /connect-wifi -> connect to device over WiFi
  router.post('/connect-wifi', (Request request) async {
    try {
      final body = jsonDecode(await request.readAsString()) as Map<String, dynamic>;
      final address = body['address'] as String?;
      if (address == null || address.isEmpty) {
        return Response(400, body: jsonEncode({'error': 'Missing address field'}));
      }
      final success = await dm.connectWifi(address);
      if (success) {
        return Response.ok(jsonEncode({'success': true, 'serial': address}));
      }
      return Response.ok(jsonEncode({'success': false, 'error': 'Connection failed'}));
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({'error': 'WiFi connect failed: $e'}),
      );
    }
  });

  // POST /pair-wireless -> pair with device wirelessly (Android 11+)
  router.post('/pair-wireless', (Request request) async {
    try {
      final body = jsonDecode(await request.readAsString()) as Map<String, dynamic>;
      final address = body['address'] as String?;
      final code = body['pairing_code'] as String?;
      if (address == null || address.isEmpty || code == null || code.isEmpty) {
        return Response(400, body: jsonEncode({'error': 'Missing address or pairing_code'}));
      }
      final success = await dm.pairWireless(address, code);
      if (success) {
        return Response.ok(jsonEncode({
          'success': true,
          'summary': 'Device paired successfully. Now connect using the wireless debugging port.',
        }));
      }
      return Response.ok(jsonEncode({
        'success': false,
        'error': 'Pairing failed — check the IP, port, and pairing code',
      }));
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({'error': 'Wireless pairing failed: $e'}),
      );
    }
  });

  // GET /<id>/screen-size -> get device screen dimensions
  router.get('/<id>/screen-size', (Request request, String id) async {
    final device = dm.getDevice(id);
    if (device == null) {
      return Response.notFound(jsonEncode({'error': 'Device not found'}));
    }
    try {
      final result = await action.getScreenSize(device.serial);
      return Response.ok(jsonEncode(result.toJson()));
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({'error': 'Screen size failed: $e'}),
      );
    }
  });

  // GET /<id>/orientation -> get current screen orientation
  router.get('/<id>/orientation', (Request request, String id) async {
    final device = dm.getDevice(id);
    if (device == null) {
      return Response.notFound(jsonEncode({'error': 'Device not found'}));
    }
    try {
      final result = await action.getOrientation(device.serial);
      return Response.ok(jsonEncode(result.toJson()));
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({'error': 'Orientation failed: $e'}),
      );
    }
  });

  // POST /<id>/save-screenshot -> save screenshot to file on host
  router.post('/<id>/save-screenshot', (Request request, String id) async {
    final device = dm.getDevice(id);
    if (device == null) {
      return Response.notFound(jsonEncode({'error': 'Device not found'}));
    }
    try {
      final body = jsonDecode(await request.readAsString()) as Map<String, dynamic>;
      final path = body['path'] as String;
      final result = await action.saveScreenshot(device.serial, path);
      return Response.ok(jsonEncode(result.toJson()));
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({'error': 'Save screenshot failed: $e'}),
      );
    }
  });

  // GET /<id>/find-element -> smart element search by text, class, resource_id
  router.get('/<id>/find-element', (Request request, String id) async {
    final device = dm.getDevice(id);
    if (device == null) {
      return Response.notFound(jsonEncode({'error': 'Device not found'}));
    }
    try {
      final text = request.url.queryParameters['text'];
      final className = request.url.queryParameters['class'];
      final resourceId = request.url.queryParameters['resource_id'];
      final result = await action.findElement(
        device.serial,
        text: text,
        className: className,
        resourceId: resourceId,
      );
      return Response.ok(jsonEncode(result.toJson()));
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({'error': 'Find element failed: $e'}),
      );
    }
  });

  // POST /<id>/bridge/start -> start bridge for device
  router.post('/<id>/bridge/start', (Request request, String id) {
    final device = dm.getDevice(id);
    if (device == null) {
      return Response.notFound(jsonEncode({'error': 'Device not found'}));
    }
    dm.startBridge(id);
    return Response.ok(jsonEncode({'status': 'active'}));
  });

  // POST /<id>/bridge/stop -> stop bridge for device
  router.post('/<id>/bridge/stop', (Request request, String id) {
    final device = dm.getDevice(id);
    if (device == null) {
      return Response.notFound(jsonEncode({'error': 'Device not found'}));
    }
    dm.stopBridge(id);
    return Response.ok(jsonEncode({'status': 'stopped'}));
  });

  return router;
}
