import 'package:flutter/material.dart';

import 'ui/screens/home_screen.dart';
import 'ui/screens/device_detail_screen.dart';

class OpenMobApp extends StatelessWidget {
  const OpenMobApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'OpenMob Hub',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true),
      home: const HomeScreen(),
      onGenerateRoute: (settings) {
        final uri = Uri.parse(settings.name ?? '');

        // /device/:id
        if (uri.pathSegments.length == 2 && uri.pathSegments[0] == 'device') {
          final deviceId = uri.pathSegments[1];
          return MaterialPageRoute(
            builder: (_) => DeviceDetailScreen(deviceId: deviceId),
            settings: settings,
          );
        }

        return null;
      },
    );
  }
}
