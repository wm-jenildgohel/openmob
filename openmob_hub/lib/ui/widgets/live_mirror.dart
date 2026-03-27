import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:rxdart/rxdart.dart';

import '../../core/res_colors.dart';
import '../../main.dart';

/// State for the live mirror widget
enum _MirrorMode { loading, live, screenshot, error }

/// Module-level streams per device (survives widget rebuilds)
final _mirrorStates = <String, BehaviorSubject<_MirrorState>>{};

class _MirrorState {
  final _MirrorMode mode;
  final String? screenshotBase64;

  const _MirrorState({
    this.mode = _MirrorMode.loading,
    this.screenshotBase64,
  });
}

BehaviorSubject<_MirrorState> _getState(String serial) {
  return _mirrorStates.putIfAbsent(
    serial,
    () => BehaviorSubject<_MirrorState>.seeded(const _MirrorState()),
  );
}

/// Live device screen mirror widget using scrcpy H.264 stream via media_kit.
/// Falls back to periodic screenshot polling if scrcpy is unavailable.
class LiveMirror extends StatefulWidget {
  final String deviceSerial;
  final double? width;
  final double? height;

  const LiveMirror({
    super.key,
    required this.deviceSerial,
    this.width,
    this.height,
  });

  @override
  State<LiveMirror> createState() => _LiveMirrorState();
}

class _LiveMirrorState extends State<LiveMirror> {
  Timer? _screenshotTimer;

  BehaviorSubject<_MirrorState> get _state => _getState(widget.deviceSerial);

  @override
  void initState() {
    super.initState();
    _startMirroring();
  }

  Future<void> _startMirroring() async {
    // media_kit_video has platform registration issues without media_kit_libs_video.
    // Use fast screenshot polling as the reliable default.
    // TODO: Re-enable live H.264 streaming when media_kit_libs build is fixed.
    _startScreenshotPolling();
  }

  void _startScreenshotPolling() {
    _state.add(const _MirrorState(mode: _MirrorMode.screenshot));
    _fetchScreenshot();
    _screenshotTimer = Timer.periodic(
      const Duration(seconds: 2),
      (_) => _fetchScreenshot(),
    );
  }

  Future<void> _fetchScreenshot() async {
    try {
      final result = await screenshotService.captureScreenshot(widget.deviceSerial);
      _state.add(_MirrorState(
        mode: _MirrorMode.screenshot,
        screenshotBase64: result.base64,
      ));
    } catch (_) {
      // Device may have disconnected — keep trying
    }
  }

  @override
  void dispose() {
    _screenshotTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<_MirrorState>(
      stream: _state.stream,
      initialData: _state.value,
      builder: (context, snapshot) {
        final state = snapshot.data ?? const _MirrorState();

        return switch (state.mode) {
          _MirrorMode.loading => _buildPlaceholder(),
          _MirrorMode.live || _MirrorMode.screenshot => _buildScreenshot(state.screenshotBase64),
          _MirrorMode.error => _buildScreenshot(null),
        };
      },
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 24, height: 24,
              child: CircularProgressIndicator(strokeWidth: 2, color: ResColors.accent),
            ),
            SizedBox(height: 12),
            Text('Connecting...', style: TextStyle(color: ResColors.textMuted, fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Widget _buildScreenshot(String? base64Data) {
    if (base64Data == null || base64Data.isEmpty) {
      return Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 24, height: 24,
                child: CircularProgressIndicator(strokeWidth: 2, color: ResColors.accent),
              ),
              SizedBox(height: 12),
              Text('Loading preview...', style: TextStyle(color: ResColors.textMuted, fontSize: 12)),
            ],
          ),
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: widget.width,
        height: widget.height,
        color: Colors.black,
        child: Stack(
          children: [
            Center(
              child: Image.memory(
                base64Decode(base64Data),
                fit: BoxFit.contain,
                gaplessPlayback: true,
              ),
            ),
            Positioned(
              top: 8, right: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: ResColors.accent.withAlpha(180),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'PREVIEW',
                  style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
