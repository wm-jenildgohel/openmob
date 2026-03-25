import 'package:flutter/material.dart';
import 'package:rxdart_flutter/rxdart_flutter.dart';

import '../../core/res_colors.dart';
import '../../main.dart';
import '../../models/process_info.dart';

class ProcessControls extends StatelessWidget {
  const ProcessControls({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: _buildMcpCard(context)),
        const SizedBox(width: 16),
        Expanded(child: _buildBridgeCard(context)),
      ],
    );
  }

  Widget _buildMcpCard(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: ValueStreamBuilder<ProcessInfo>(
          stream: processManager.mcpStatus$,
          builder: (context, info, child) {
            final statusColor = _statusColor(info.status);
            final statusText = switch (info.status) {
              ProcessStatus.running => 'Running (PID: ${info.pid})',
              ProcessStatus.stopped => 'Stopped',
              ProcessStatus.starting => 'Starting...',
              ProcessStatus.error => 'Error: ${info.errorMessage ?? "Unknown"}',
            };

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'MCP Server',
                      style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: statusColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(statusText, style: textTheme.bodyMedium?.copyWith(color: statusColor)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    ElevatedButton(
                      onPressed: (info.status == ProcessStatus.running ||
                              info.status == ProcessStatus.starting)
                          ? null
                          : () => processManager.startMcp(),
                      child: const Text('Start'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: info.status == ProcessStatus.stopped
                          ? null
                          : () => processManager.stopMcp(),
                      child: const Text('Stop'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () => processManager.restartMcp(),
                      child: const Text('Restart'),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildBridgeCard(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: ValueStreamBuilder<ProcessInfo>(
          stream: processManager.bridgeStatus$,
          builder: (context, info, child) {
            final statusColor = _statusColor(info.status);

            final statusLabel = switch (info.status) {
              ProcessStatus.running => 'Running${info.pid != null ? ' (PID: ${info.pid})' : ''}',
              ProcessStatus.stopped => 'Not running',
              ProcessStatus.starting => 'Starting...',
              ProcessStatus.error => info.errorMessage ?? 'Error',
            };

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'AiBridge',
                      style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: statusColor,
                      ),
                    ),
                    const Spacer(),
                    Tooltip(
                      message: 'Optional: wraps terminal AI agents (Claude Code, Codex, Gemini)\n'
                          'with context injection. Not needed for MCP-based testing.',
                      child: Icon(Icons.info_outline, size: 18, color: ResColors.muted),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  statusLabel,
                  style: textTheme.bodyMedium?.copyWith(color: statusColor),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    ElevatedButton(
                      onPressed: (info.status == ProcessStatus.running ||
                              info.status == ProcessStatus.starting)
                          ? null
                          : () => _showAgentPicker(context),
                      child: const Text('Start'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: (info.status == ProcessStatus.running ||
                              info.status == ProcessStatus.error)
                          ? () => processManager.stopBridge()
                          : null,
                      child: const Text('Stop'),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  void _showAgentPicker(BuildContext context) {
    final agents = processManager.availableAgents;

    if (agents.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'No AI agents found in PATH. Install claude, codex, or gemini first.',
          ),
          backgroundColor: ResColors.error,
          duration: const Duration(seconds: 5),
        ),
      );
      return;
    }

    if (agents.length == 1) {
      processManager.startBridge(agent: agents.first);
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Select AI Agent'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: agents.map((agent) {
            return ListTile(
              leading: const Icon(Icons.terminal),
              title: Text(agent),
              subtitle: Text('Wrap $agent with context injection'),
              onTap: () {
                Navigator.of(ctx).pop();
                processManager.startBridge(agent: agent);
              },
            );
          }).toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  Color _statusColor(ProcessStatus status) {
    return switch (status) {
      ProcessStatus.running => ResColors.running,
      ProcessStatus.stopped => ResColors.stopped,
      ProcessStatus.starting => ResColors.warning,
      ProcessStatus.error => ResColors.error,
    };
  }
}
