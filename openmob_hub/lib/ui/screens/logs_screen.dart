import 'package:flutter/material.dart';

import '../../core/res_colors.dart';

/// Placeholder - fully implemented in Task 2
class LogsScreen extends StatelessWidget {
  const LogsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text('Logs', style: TextStyle(color: ResColors.muted)),
    );
  }
}
