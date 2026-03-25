import 'package:flutter/material.dart';
import 'package:rxdart_flutter/rxdart_flutter.dart';

import '../../core/res_colors.dart';
import '../../main.dart';
import '../../models/device.dart';
import '../widgets/sidebar.dart';
import '../widgets/process_controls.dart';
import 'home_screen.dart';
import 'logs_screen.dart';
import 'system_check_screen.dart';

final _navIndex = BehaviorSubject<int>.seeded(0);

class DashboardShell extends StatelessWidget {
  const DashboardShell({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ValueStreamBuilder<int>(
        stream: _navIndex.stream,
        builder: (context, index, child) {
          return Row(
            children: [
              Sidebar(
                selectedIndex: index,
                onDestinationSelected: (i) => _navIndex.add(i),
              ),
              VerticalDivider(width: 1, color: ResColors.cardBorder),
              Expanded(
                child: _buildContent(context, index),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildContent(BuildContext context, int index) {
    return switch (index) {
      0 => _buildDashboard(context),
      1 => const HomeScreen(),
      2 => const LogsScreen(),
      3 => const SystemCheckScreen(),
      _ => _buildDashboard(context),
    };
  }

  Widget _buildDashboard(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Dashboard',
            style: textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          const ProcessControls(),
          const SizedBox(height: 24),
          Row(
            children: [
              Text(
                'Connected Devices',
                style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              ValueStreamBuilder<List<Device>>(
                stream: deviceManager.devices$,
                builder: (context, devices, child) {
                  return Container(
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
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: ValueStreamBuilder<List<Device>>(
              stream: deviceManager.devices$,
              builder: (context, devices, child) {
                if (devices.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.phone_android, size: 48, color: ResColors.muted),
                        const SizedBox(height: 12),
                        Text(
                          'No devices connected',
                          style: TextStyle(color: ResColors.muted),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: devices.length,
                  itemBuilder: (context, index) {
                    final device = devices[index];
                    return Card(
                      child: ListTile(
                        leading: Icon(
                          Icons.phone_android,
                          color: ResColors.accent,
                        ),
                        title: Text(device.model),
                        subtitle: Text('${device.manufacturer} | ${device.connectionType}'),
                        trailing: Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: device.status == 'connected'
                                ? ResColors.connected
                                : ResColors.offline,
                          ),
                        ),
                        onTap: () => Navigator.pushNamed(
                          context,
                          '/device/${device.id}',
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
