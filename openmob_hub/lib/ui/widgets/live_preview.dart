import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:rxdart_flutter/rxdart_flutter.dart';

import '../../core/res_colors.dart';
import '../../main.dart';

class LivePreviewController {
  final String deviceId;

  LivePreviewController({required this.deviceId});

  final _image = BehaviorSubject<Uint8List?>.seeded(null);
  final _loading = BehaviorSubject<bool>.seeded(false);
  bool _disposed = false;

  ValueStream<Uint8List?> get image$ => _image.stream;
  ValueStream<bool> get loading$ => _loading.stream;

  Timer? _timer;

  void start() {
    _timer = Timer.periodic(const Duration(milliseconds: 500), (_) => _fetch());
    _fetch();
  }

  Future<void> _fetch() async {
    if (_disposed || _loading.isClosed) return;
    if (_loading.value) return;
    _loading.add(true);
    try {
      final bytes = await screenshotService.capturePreview(deviceId);
      if (_disposed) return;
      _image.add(bytes);
    } catch (_) {
      // Device might be disconnected -- silently ignore
    } finally {
      if (!_disposed) _loading.add(false);
    }
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  void dispose() {
    _disposed = true;
    stop();
    _image.close();
    _loading.close();
  }
}

class LivePreview extends StatelessWidget {
  final LivePreviewController controller;

  const LivePreview({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Container(
        color: ResColors.surface,
        child: ValueStreamBuilder<Uint8List?>(
          stream: controller.image$,
          builder: (context, bytes, child) {
            if (bytes == null) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Iconsax.mobile, size: 48, color: ResColors.muted),
                    const SizedBox(height: 12),
                    Text(
                      'Waiting for screenshot...',
                      style: TextStyle(color: ResColors.muted),
                    ),
                  ],
                ),
              );
            }

            return Image.memory(
              bytes,
              fit: BoxFit.contain,
              gaplessPlayback: true,
            );
          },
        ),
      ),
    );
  }
}
