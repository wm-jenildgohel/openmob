import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../../core/res_colors.dart';
import '../../main.dart';

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
  Player? _player;
  VideoController? _controller;
  bool _isLoading = true;
  bool _hasError = false;
  String? _errorMsg;

  @override
  void initState() {
    super.initState();
    _startMirroring();
  }

  Future<void> _startMirroring() async {
    try {
      // Start scrcpy stream
      final tcpUrl = await scrcpyStreamService.startStream(widget.deviceSerial);

      if (tcpUrl == null) {
        setState(() {
          _isLoading = false;
          _hasError = true;
          _errorMsg = 'scrcpy not available — showing screenshots instead';
        });
        return;
      }

      // Create media_kit player with low-latency config
      final player = Player();
      final controller = VideoController(player);

      // Configure for low-latency H.264 TCP playback
      if (player.platform is NativePlayer) {
        final native = player.platform as NativePlayer;
        await native.setProperty('profile', 'low-latency');
        await native.setProperty('untimed', '');
        await native.setProperty('no-cache', '');
        await native.setProperty('demuxer-lavf-format', 'h264');
        await native.setProperty('demuxer-lavf-o', 'live=1');
        await native.setProperty('video-sync', 'display-resample');
        await native.setProperty('vd-lavc-threads', '1');
        await native.setProperty('cache', 'no');
        await native.setProperty('cache-secs', '0');
      }

      await player.open(Media(tcpUrl));

      if (mounted) {
        setState(() {
          _player = player;
          _controller = controller;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
          _errorMsg = 'Mirror failed: $e';
        });
      }
    }
  }

  @override
  void dispose() {
    _player?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return _buildPlaceholder('Connecting to device...');
    }

    if (_hasError || _controller == null) {
      // Fall back to the existing LivePreview widget (screenshot polling)
      return _buildFallback();
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: widget.width,
        height: widget.height,
        color: Colors.black,
        child: Stack(
          children: [
            Video(
              controller: _controller!,
              fit: BoxFit.contain,
            ),
            // Live indicator
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.red.withAlpha(200),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.circle, size: 8, color: Colors.white),
                    SizedBox(width: 4),
                    Text(
                      'LIVE',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholder(String message) {
    return Container(
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(
        color: ResColors.bgElevated,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: ResColors.accent,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            message,
            style: const TextStyle(
              color: ResColors.textMuted,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFallback() {
    return Container(
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(
        color: ResColors.bgElevated,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ResColors.cardBorder),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.screenshot_monitor, size: 32, color: ResColors.textMuted),
          const SizedBox(height: 8),
          Text(
            _errorMsg ?? 'Live mirror unavailable',
            style: const TextStyle(color: ResColors.textMuted, fontSize: 11),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          const Text(
            'Using screenshot preview',
            style: TextStyle(color: ResColors.textMuted, fontSize: 10),
          ),
        ],
      ),
    );
  }
}
