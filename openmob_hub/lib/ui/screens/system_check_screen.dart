import 'package:flutter/material.dart';

import '../../core/res_colors.dart';

/// Placeholder - fully implemented in Task 2
class SystemCheckScreen extends StatelessWidget {
  const SystemCheckScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text('System Check', style: TextStyle(color: ResColors.muted)),
    );
  }
}
