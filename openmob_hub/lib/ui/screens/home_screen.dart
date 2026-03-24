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
    return Scaffold(
      appBar: AppBar(
        title: const Text('OpenMob Hub'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh devices',
            onPressed: () => deviceManager.refreshDevices(),
          ),
        ],
      ),
      body: ValueStreamBuilder<List<Device>>(
        stream: deviceManager.devices$,
        builder: (context, devices, child) {
          if (devices.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.phone_android, size: 64, color: ResColors.muted),
                  const SizedBox(height: 16),
                  const Text('No devices connected'),
                  const SizedBox(height: 8),
                  Text(
                    'Connect an Android device via USB, WiFi ADB, or start an emulator',
                    style: TextStyle(color: ResColors.muted),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: devices.length,
            itemBuilder: (context, index) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: DeviceCard(
                device: devices[index],
                onTap: () => Navigator.pushNamed(
                  context,
                  '/device/${devices[index].id}',
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
