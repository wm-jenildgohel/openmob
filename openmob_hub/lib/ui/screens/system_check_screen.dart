import 'package:flutter/material.dart';
import 'package:rxdart_flutter/rxdart_flutter.dart';

import '../../core/res_colors.dart';
import '../../main.dart';
import '../../models/ai_tool.dart';
import '../../models/tool_status.dart';
import '../widgets/tool_status_card.dart';

class SystemCheckScreen extends StatelessWidget {
  const SystemCheckScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Text(
                'System Check',
                style: textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: () {
                  systemCheckService.checkAll();
                  aiToolSetupService.detectAll();
                },
                icon: const Icon(Icons.refresh),
                label: const Text('Re-check'),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Platform Tools section
          _buildToolsSection(context),

          const SizedBox(height: 32),

          // AI Tools section
          _buildAiToolsSection(context),
        ],
      ),
    );
  }

  Widget _buildToolsSection(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return ValueStreamBuilder<List<ToolStatus>>(
      stream: systemCheckService.tools$,
      builder: (context, tools, child) {
        if (tools.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        final available = tools.where((t) => t.available).length;
        final total = tools.length;

        const requiredNames = {'ADB', 'MCP Server'};
        final required = tools.where((t) => requiredNames.contains(t.name)).toList();
        final optional = tools.where((t) => !requiredNames.contains(t.name)).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Platform Tools',
                  style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 12),
                Text(
                  '$available/$total available',
                  style: textTheme.bodyMedium?.copyWith(
                    color: available == total ? ResColors.connected : ResColors.warning,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text('Required', style: textTheme.titleSmall?.copyWith(color: ResColors.muted)),
            const SizedBox(height: 8),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 2.5,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: required.length,
              itemBuilder: (context, index) => ToolStatusCard(tool: required[index]),
            ),
            if (optional.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text('Optional', style: textTheme.titleSmall?.copyWith(color: ResColors.muted)),
              const SizedBox(height: 8),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 2.5,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                ),
                itemCount: optional.length,
                itemBuilder: (context, index) => ToolStatusCard(tool: optional[index]),
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _buildAiToolsSection(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return ValueStreamBuilder<List<AiTool>>(
      stream: aiToolSetupService.tools$,
      builder: (context, tools, child) {
        if (tools.isEmpty) {
          return const SizedBox.shrink();
        }

        final detected = tools.where((t) => t.detected).toList();
        final configured = tools.where((t) => t.configured).length;
        final unconfigured = detected.where((t) => !t.configured).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'AI Tool Integration',
                  style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 12),
                Text(
                  '$configured/${detected.length} configured',
                  style: textTheme.bodyMedium?.copyWith(
                    color: configured == detected.length
                        ? ResColors.connected
                        : ResColors.warning,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                if (unconfigured.isNotEmpty)
                  ElevatedButton.icon(
                    onPressed: () => aiToolSetupService.installAll(),
                    icon: const Icon(Icons.auto_fix_high, size: 18),
                    label: const Text('Setup All'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: ResColors.connected,
                      foregroundColor: Colors.white,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 3.0,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: tools.length,
              itemBuilder: (context, index) => _AiToolCard(tool: tools[index]),
            ),
          ],
        );
      },
    );
  }
}

class _AiToolCard extends StatelessWidget {
  final AiTool tool;

  const _AiToolCard({required this.tool});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    final Color statusColor;
    final IconData statusIcon;
    final String statusText;

    if (!tool.detected) {
      statusColor = ResColors.muted;
      statusIcon = Icons.remove_circle_outline;
      statusText = 'Not installed';
    } else if (tool.configured) {
      statusColor = ResColors.connected;
      statusIcon = Icons.check_circle;
      statusText = 'Configured';
    } else if (tool.installing) {
      statusColor = ResColors.warning;
      statusIcon = Icons.downloading;
      statusText = 'Configuring...';
    } else {
      statusColor = ResColors.warning;
      statusIcon = Icons.warning_amber;
      statusText = 'Detected — not configured';
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(statusIcon, color: statusColor, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    tool.name,
                    style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
                if (tool.detected && !tool.configured && !tool.installing)
                  TextButton.icon(
                    onPressed: () => _handleSetup(),
                    icon: const Icon(Icons.settings, size: 16),
                    label: const Text('Setup'),
                    style: TextButton.styleFrom(
                      foregroundColor: ResColors.connected,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              statusText,
              style: textTheme.bodySmall?.copyWith(color: statusColor),
            ),
            if (tool.installing) ...[
              const SizedBox(height: 4),
              const LinearProgressIndicator(),
            ],
          ],
        ),
      ),
    );
  }

  void _handleSetup() {
    switch (tool.name) {
      case 'Cursor':
        aiToolSetupService.installCursor();
      case 'Claude Desktop':
        aiToolSetupService.installClaudeDesktop();
      case 'Claude Code':
        aiToolSetupService.installClaudeCode();
      case 'VS Code':
        aiToolSetupService.installVSCode();
    }
  }
}
