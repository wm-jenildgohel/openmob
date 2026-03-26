import 'package:flutter/material.dart';
import 'package:rxdart_flutter/rxdart_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/res_colors.dart';
import '../../main.dart';
import '../../models/ai_tool.dart';
import '../../models/tool_status.dart';
import '../../services/update_service.dart';
import '../widgets/tool_status_card.dart';

class SystemCheckScreen extends StatelessWidget {
  const SystemCheckScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('System Check', style: textTheme.headlineSmall),
                  const SizedBox(height: 4),
                  Text('Check if everything is set up correctly', style: textTheme.bodyMedium),
                ],
              ),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: () {
                  systemCheckService.checkAll();
                  aiToolSetupService.detectAll();
                },
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: const Text('Re-check'),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildUpdateSection(context),
          const SizedBox(height: 32),
          _buildToolsSection(context),
          const SizedBox(height: 32),
          _buildAiToolsSection(context),
        ],
      ),
    );
  }

  Widget _buildUpdateSection(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return ValueStreamBuilder<UpdateInfo>(
      stream: updateService.status$,
      builder: (context, info, child) {
        final Color statusColor;
        final IconData statusIcon;
        final String statusText;
        final String subtitle;

        switch (info.status) {
          case UpdateStatus.idle:
          case UpdateStatus.checking:
            statusColor = ResColors.textSecondary;
            statusIcon = Icons.update_rounded;
            statusText = 'Checking for updates...';
            subtitle = 'Current version: v${info.currentVersion}';
          case UpdateStatus.upToDate:
            statusColor = ResColors.connected;
            statusIcon = Icons.check_circle_rounded;
            statusText = 'Up to date';
            subtitle = 'v${info.currentVersion} is the latest version';
          case UpdateStatus.available:
            statusColor = ResColors.accent;
            statusIcon = Icons.new_releases_rounded;
            statusText = 'Update available: v${info.latestVersion}';
            subtitle = 'Current: v${info.currentVersion}';
          case UpdateStatus.downloading:
            statusColor = ResColors.warning;
            statusIcon = Icons.downloading_rounded;
            statusText = 'Downloading v${info.latestVersion}...';
            subtitle = '${(info.progress * 100).toInt()}%';
          case UpdateStatus.installing:
            statusColor = ResColors.warning;
            statusIcon = Icons.install_desktop_rounded;
            statusText = 'Installing...';
            subtitle = 'Please wait';
          case UpdateStatus.error:
            statusColor = ResColors.error;
            statusIcon = Icons.error_outline_rounded;
            statusText = 'Update check failed';
            subtitle = info.error ?? 'Unknown error';
        }

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: ResColors.cardBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: info.status == UpdateStatus.available
                  ? ResColors.accent.withValues(alpha: 0.4)
                  : ResColors.cardBorder,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(statusIcon, color: statusColor, size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(statusText, style: textTheme.titleSmall?.copyWith(
                          color: statusColor,
                          fontWeight: FontWeight.w600,
                        )),
                        const SizedBox(height: 2),
                        Text(subtitle, style: textTheme.bodySmall?.copyWith(
                          color: ResColors.textSecondary,
                        )),
                      ],
                    ),
                  ),
                  if (info.status == UpdateStatus.available) ...[
                    if (info.downloadUrl != null)
                      ElevatedButton.icon(
                        onPressed: () => updateService.downloadAndInstall(),
                        icon: const Icon(Icons.download_rounded, size: 16),
                        label: const Text('Download'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: ResColors.accent,
                          foregroundColor: ResColors.textOnAccent,
                        ),
                      ),
                    const SizedBox(width: 8),
                    OutlinedButton(
                      onPressed: () => launchUrl(
                        Uri.parse('https://github.com/wm-jenildgohel/openmob/releases'),
                      ),
                      child: const Text('View Release'),
                    ),
                  ],
                  if (info.status == UpdateStatus.upToDate || info.status == UpdateStatus.error)
                    TextButton.icon(
                      onPressed: () => updateService.checkForUpdate(),
                      icon: const Icon(Icons.refresh_rounded, size: 16),
                      label: const Text('Check Again'),
                    ),
                  if (info.status == UpdateStatus.idle || info.status == UpdateStatus.checking)
                    const SizedBox(
                      width: 20, height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                ],
              ),
              if (info.status == UpdateStatus.downloading) ...[
                const SizedBox(height: 12),
                LinearProgressIndicator(
                  value: info.progress,
                  backgroundColor: ResColors.cardBorder,
                  color: ResColors.accent,
                ),
              ],
              if (info.status == UpdateStatus.available && info.releaseNotes != null && info.releaseNotes!.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: ResColors.bg,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('What\'s new:', style: textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: ResColors.textPrimary,
                      )),
                      const SizedBox(height: 4),
                      Text(
                        info.releaseNotes!.length > 300
                            ? '${info.releaseNotes!.substring(0, 300)}...'
                            : info.releaseNotes!,
                        style: textTheme.bodySmall?.copyWith(
                          color: ResColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        );
      },
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
                const Icon(Icons.build_rounded, size: 18, color: ResColors.textSecondary),
                const SizedBox(width: 8),
                Text('Required Software', style: textTheme.titleMedium),
                const SizedBox(width: 12),
                _StatusBadge(
                  text: '$available of $total ready',
                  color: available == total ? ResColors.accent : ResColors.warning,
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text('REQUIRED', style: textTheme.titleSmall?.copyWith(
              letterSpacing: 1.0,
              fontSize: 11,
            )),
            const SizedBox(height: 8),
            LayoutBuilder(
              builder: (context, constraints) {
                final cardWidth = (constraints.maxWidth - 12) / 2;
                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: required.map((t) => SizedBox(
                    width: cardWidth,
                    child: ToolStatusCard(tool: t),
                  )).toList(),
                );
              },
            ),
            if (optional.isNotEmpty) ...[
              const SizedBox(height: 20),
              Text('OPTIONAL', style: textTheme.titleSmall?.copyWith(
                letterSpacing: 1.0,
                fontSize: 11,
              )),
              const SizedBox(height: 8),
              LayoutBuilder(
                builder: (context, constraints) {
                  final cardWidth = (constraints.maxWidth - 12) / 2;
                  return Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: optional.map((t) => SizedBox(
                      width: cardWidth,
                      child: ToolStatusCard(tool: t),
                    )).toList(),
                  );
                },
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
        if (tools.isEmpty) return const SizedBox.shrink();

        final detected = tools.where((t) => t.detected).toList();
        final configured = tools.where((t) => t.configured).length;
        final unconfigured = detected.where((t) => !t.configured).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.smart_toy_rounded, size: 18, color: ResColors.textSecondary),
                const SizedBox(width: 8),
                Text('AI Tools', style: textTheme.titleMedium),
                const SizedBox(width: 12),
                _StatusBadge(
                  text: '$configured/${detected.length} configured',
                  color: configured == detected.length ? ResColors.accent : ResColors.warning,
                ),
                const Spacer(),
                if (unconfigured.isNotEmpty)
                  ElevatedButton.icon(
                    onPressed: () => aiToolSetupService.installAll(),
                    icon: const Icon(Icons.auto_fix_high_rounded, size: 16),
                    label: const Text('Setup All'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: ResColors.accent,
                      foregroundColor: ResColors.textOnAccent,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            LayoutBuilder(
              builder: (context, constraints) {
                final cardWidth = (constraints.maxWidth - 12) / 2;
                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: tools.map((t) => SizedBox(
                    width: cardWidth,
                    child: _AiToolCard(tool: t),
                  )).toList(),
                );
              },
            ),
          ],
        );
      },
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String text;
  final Color color;
  const _StatusBadge({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        text,
        style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _AiToolCard extends StatelessWidget {
  final AiTool tool;
  const _AiToolCard({required this.tool});

  @override
  Widget build(BuildContext context) {
    final Color statusColor;
    final IconData statusIcon;
    final String statusText;

    if (!tool.detected) {
      statusColor = ResColors.textMuted;
      statusIcon = Icons.remove_circle_outline_rounded;
      statusText = 'Not installed';
    } else if (tool.configured) {
      statusColor = ResColors.connected;
      statusIcon = Icons.check_circle_rounded;
      statusText = 'Configured';
    } else if (tool.installing) {
      statusColor = ResColors.warning;
      statusIcon = Icons.downloading_rounded;
      statusText = 'Configuring...';
    } else {
      statusColor = ResColors.warning;
      statusIcon = Icons.warning_amber_rounded;
      statusText = 'Detected \u2014 not configured';
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: ResColors.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: tool.configured
              ? ResColors.accent.withValues(alpha: 0.3)
              : ResColors.cardBorder,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(statusIcon, color: statusColor, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  tool.name,
                  style: const TextStyle(
                    color: ResColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (tool.detected && !tool.configured && !tool.installing)
                GestureDetector(
                  onTap: () => _handleSetup(),
                  child: MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: ResColors.accent,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text('Setup', style: TextStyle(
                        color: ResColors.textOnAccent,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      )),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(statusText, style: TextStyle(color: statusColor, fontSize: 12)),
          if (tool.installing) ...[
            const SizedBox(height: 6),
            const LinearProgressIndicator(),
          ],
        ],
      ),
    );
  }

  void _handleSetup() {
    switch (tool.name) {
      case 'Cursor': aiToolSetupService.installCursor();
      case 'Claude Desktop': aiToolSetupService.installClaudeDesktop();
      case 'Claude Code': aiToolSetupService.installClaudeCode();
      case 'VS Code': aiToolSetupService.installVSCode();
      case 'Windsurf': aiToolSetupService.installWindsurf();
      case 'Codex CLI': aiToolSetupService.installCodexCli();
      case 'Gemini CLI': aiToolSetupService.installGeminiCli();
    }
  }
}
