import 'dart:convert';

import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '../../services/recording_service.dart';

Router recordingRoutes(RecordingService recording) {
  final router = Router();

  // POST /start — start recording a device
  router.post('/start', (Request request) async {
    try {
      final body =
          jsonDecode(await request.readAsString()) as Map<String, dynamic>;
      final deviceId = body['device_id'] as String?;
      if (deviceId == null || deviceId.isEmpty) {
        return Response(400,
            body: jsonEncode({'error': 'device_id is required'}));
      }

      final rec = await recording.startRecording(
        deviceId,
        format: (body['format'] as String?) ?? 'mkv',
        maxDurationSeconds: (body['max_duration_seconds'] as num?)?.toInt() ?? 180,
        includeAudio: (body['include_audio'] as bool?) ?? false,
        videoBitrate: (body['video_bitrate'] as String?) ?? '4M',
      );

      return Response.ok(jsonEncode({
        'success': true,
        'data': rec.toJson(),
        'summary': 'Started recording device ${rec.deviceSerial} (${rec.backend})',
      }));
    } on StateError catch (e) {
      return Response(409, body: jsonEncode({'error': e.message}));
    } catch (e) {
      return Response.internalServerError(
          body: jsonEncode({'error': 'Failed to start recording: $e'}));
    }
  });

  // POST /stop — stop recording a device
  router.post('/stop', (Request request) async {
    try {
      final body =
          jsonDecode(await request.readAsString()) as Map<String, dynamic>;
      final deviceId = body['device_id'] as String?;
      if (deviceId == null || deviceId.isEmpty) {
        return Response(400,
            body: jsonEncode({'error': 'device_id is required'}));
      }

      final rec = await recording.stopRecording(
        deviceId,
        recordingId: body['recording_id'] as String?,
      );

      return Response.ok(jsonEncode({
        'success': true,
        'data': rec.toJson(),
        'summary':
            'Stopped recording (${(rec.durationMs! / 1000).toStringAsFixed(1)}s, ${rec.backend})',
      }));
    } on StateError catch (e) {
      return Response(404, body: jsonEncode({'error': e.message}));
    } catch (e) {
      return Response.internalServerError(
          body: jsonEncode({'error': 'Failed to stop recording: $e'}));
    }
  });

  // GET / — list all recordings
  router.get('/', (Request request) async {
    final deviceId = request.url.queryParameters['device_id'];
    final recs = recording.listRecordings(deviceSerial: deviceId);
    return Response.ok(jsonEncode({
      'recordings': recs.map((r) => r.toJson()).toList(),
      'count': recs.length,
    }));
  });

  // GET /<id> — get a specific recording
  router.get('/<id>', (Request request, String id) async {
    final rec = recording.getRecording(id);
    if (rec == null) {
      return Response.notFound(
          jsonEncode({'error': 'Recording not found: $id'}));
    }
    return Response.ok(jsonEncode({
      'data': rec.toJson(),
      'events': rec.events.map((e) => e.toJson()).toList(),
    }));
  });

  // POST /event — add a timestamped event to active recording
  router.post('/event', (Request request) async {
    try {
      final body =
          jsonDecode(await request.readAsString()) as Map<String, dynamic>;
      final deviceId = body['device_id'] as String?;
      final action = body['action'] as String? ?? 'unknown';
      final description = body['description'] as String? ?? '';

      if (deviceId == null) {
        return Response(400,
            body: jsonEncode({'error': 'device_id is required'}));
      }

      recording.addEvent(deviceId, action, description);
      return Response.ok(jsonEncode({'success': true}));
    } catch (e) {
      return Response.internalServerError(
          body: jsonEncode({'error': 'Failed to add event: $e'}));
    }
  });

  return router;
}
