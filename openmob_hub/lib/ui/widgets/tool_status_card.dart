import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';

import '../../core/res_colors.dart';
import '../../main.dart';
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
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(
                  tool.installing
                      ? Iconsax.import_1
                      : tool.available
                          ? Iconsax.tick_circle
                          : Iconsax.close_circle,
                  color: tool.installing
                      ? ResColors.warning
                      : tool.available
                          ? ResColors.connected
                          : ResColors.error,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    tool.name,
                    style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
                if (!tool.available && tool.canAutoInstall && !tool.installing)
                  TextButton.icon(
                    onPressed: () => _handleInstall(context),
                    icon: const Icon(Iconsax.import_1, size: 16),
                    label: const Text('Install'),
                    style: TextButton.styleFrom(
                      foregroundColor: ResColors.connected,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
              ],
            ),
            if (tool.installing) ...[
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: tool.installProgress > 0 ? tool.installProgress : null,
                backgroundColor: ResColors.surface,
                color: ResColors.connected,
              ),
              const SizedBox(height: 4),
              Text(
                'Installing...',
                style: textTheme.bodySmall?.copyWith(color: ResColors.warning),
              ),
            ],
            if (tool.available && !tool.installing) ...[
              const SizedBox(height: 4),
              Text(
                tool.version ?? 'Ready',
                style: textTheme.bodySmall?.copyWith(color: ResColors.connected),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            if (!tool.available && !tool.installing && tool.installHint.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                tool.canAutoInstall
                    ? 'Not installed — click Install'
                    : tool.installHint,
                style: textTheme.bodySmall?.copyWith(color: ResColors.muted),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _handleInstall(BuildContext context) {
    switch (tool.name) {
      case 'ADB':
        systemCheckService.installAdb();
      case 'MCP Server':
        systemCheckService.installNode();
      case 'AiBridge':
        systemCheckService.installAiBridge();
    }
  }
}
