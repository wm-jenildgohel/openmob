import 'package:flutter/material.dart';
import 'package:rxdart_flutter/rxdart_flutter.dart';

import '../../core/res_colors.dart';
import '../../main.dart';
import '../../models/device.dart';
import '../widgets/device_card.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: ValueStreamBuilder<List<Device>>(
        stream: deviceManager.devices$,
        builder: (context, devices, child) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    'Connected Devices',
                    style: textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: ResColors.accent,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${devices.length}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    tooltip: 'Refresh devices',
                    onPressed: () => deviceManager.refreshDevices(),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (devices.isEmpty)
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.phone_android, size: 64, color: ResColors.muted),
                        const SizedBox(height: 16),
                        Text(
                          'No devices connected',
                          style: textTheme.titleMedium?.copyWith(color: ResColors.muted),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Connect an Android device via USB, WiFi ADB, or start an emulator',
                          style: TextStyle(color: ResColors.muted),
                        ),
                      ],
                    ),
                  ),
                )
              else
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final crossAxisCount = constraints.maxWidth >= 1200
                          ? 4
                          : constraints.maxWidth >= 900
                              ? 3
                              : constraints.maxWidth >= 600
                                  ? 2
                                  : 1;

                      return GridView.builder(
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: crossAxisCount,
                          childAspectRatio: 2.2,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                        ),
                        itemCount: devices.length,
                        itemBuilder: (context, index) {
                          return DeviceCard(
                            device: devices[index],
                            onTap: () => Navigator.pushNamed(
                              context,
                              '/device/${devices[index].id}',
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
