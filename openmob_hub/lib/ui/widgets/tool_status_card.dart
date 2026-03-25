import 'package:flutter/material.dart';

import '../../core/res_colors.dart';
import '../../models/tool_status.dart';

class ToolStatusCard extends StatelessWidget {
  final ToolStatus tool;

  const ToolStatusCard({super.key, required this.tool});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  tool.available ? Icons.check_circle : Icons.cancel,
                  color: tool.available ? ResColors.connected : ResColors.error,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  tool.name,
                  style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            if (tool.version != null) ...[
              const SizedBox(height: 4),
              Text(
                tool.version!,
                style: textTheme.bodySmall?.copyWith(color: ResColors.muted),
              ),
            ],
            if (tool.path != null) ...[
              const SizedBox(height: 2),
              Text(
                tool.path!,
                style: textTheme.bodySmall?.copyWith(
                  color: ResColors.muted,
                  fontSize: 11,
                ),
              ),
            ],
            if (!tool.available) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: ResColors.warning.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  tool.installHint,
                  style: textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
