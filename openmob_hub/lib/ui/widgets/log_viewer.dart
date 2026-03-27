import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:rxdart_flutter/rxdart_flutter.dart';

import '../../core/res_colors.dart';
import '../../main.dart';
import '../../services/log_service.dart';

final _autoScroll = BehaviorSubject<bool>.seeded(true);

class LogViewer extends StatelessWidget {
  final String? filterSource;

  const LogViewer({super.key, this.filterSource});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Logs', style: textTheme.titleMedium),
            const Spacer(),
            // Auto-scroll toggle
            ValueStreamBuilder<bool>(
              stream: _autoScroll.stream,
              builder: (context, isAutoScroll, child) {
                return _AutoScrollToggle(
                  enabled: isAutoScroll,
                  onToggle: () => _autoScroll.add(!isAutoScroll),
                );
              },
            ),
            const SizedBox(width: 4),
            ValueStreamBuilder<List<LogEntry>>(
              stream: logService.logs$,
              builder: (context, logs, child) {
                return IconButton(
                  icon: const Icon(Icons.copy, size: 18),
                  tooltip: 'Copy logs',
                  onPressed: logs.isEmpty
                      ? null
                      : () {
                          final filtered = filterSource != null
                              ? logs
                                  .where((e) => e.source == filterSource)
                                  .toList()
                              : logs;
                          final text = filtered.map((e) {
                            final ts =
                                '${e.timestamp.hour.toString().padLeft(2, '0')}:'
                                '${e.timestamp.minute.toString().padLeft(2, '0')}:'
                                '${e.timestamp.second.toString().padLeft(2, '0')}';
                            return '[$ts] [${e.source}] ${e.message}';
                          }).join('\n');
                          Clipboard.setData(ClipboardData(text: text));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Logs copied to clipboard'),
                              duration: Duration(seconds: 2),
                            ),
                          );
                        },
                );
              },
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 18),
              tooltip: 'Clear logs',
              onPressed: () => logService.clear(),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: ResColors.logBg,
              borderRadius: BorderRadius.circular(8),
            ),
            child: ValueStreamBuilder<List<LogEntry>>(
              stream: logService.logs$,
              builder: (context, logs, child) {
                final filtered = filterSource != null
                    ? logs.where((e) => e.source == filterSource).toList()
                    : logs;

                if (filtered.isEmpty) {
                  return Center(
                    child: Text(
                      'No logs yet',
                      style: TextStyle(color: ResColors.muted),
                    ),
                  );
                }

                return _LogList(
                  entries: filtered,
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

/// Auto-scroll toggle button with animated icon rotation.
class _AutoScrollToggle extends StatefulWidget {
  final bool enabled;
  final VoidCallback onToggle;
  const _AutoScrollToggle({required this.enabled, required this.onToggle});

  @override
  State<_AutoScrollToggle> createState() => _AutoScrollToggleState();
}

class _AutoScrollToggleState extends State<_AutoScrollToggle>
    with SingleTickerProviderStateMixin {
  late AnimationController _iconController;

  @override
  void initState() {
    super.initState();
    _iconController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
      value: widget.enabled ? 1.0 : 0.0,
    );
  }

  @override
  void didUpdateWidget(_AutoScrollToggle oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.enabled != oldWidget.enabled) {
      if (widget.enabled) {
        _iconController.forward();
      } else {
        _iconController.reverse();
      }
    }
  }

  @override
  void dispose() {
    _iconController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: AnimatedBuilder(
        animation: _iconController,
        builder: (context, child) {
          return Transform.rotate(
            angle: _iconController.value * 0.5,
            child: Icon(
              widget.enabled
                  ? Icons.vertical_align_bottom_rounded
                  : Icons.vertical_align_center_rounded,
              size: 18,
              color: widget.enabled ? ResColors.accent : ResColors.textMuted,
            ),
          );
        },
      ),
      tooltip: widget.enabled ? 'Auto-scroll ON' : 'Auto-scroll OFF',
      onPressed: widget.onToggle,
    );
  }
}

/// Log list that respects auto-scroll setting.
class _LogList extends StatefulWidget {
  final List<LogEntry> entries;
  const _LogList({required this.entries});

  @override
  State<_LogList> createState() => _LogListState();
}

class _LogListState extends State<_LogList> {
  final ScrollController _scrollController = ScrollController();

  @override
  void didUpdateWidget(_LogList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_autoScroll.value &&
        widget.entries.length != oldWidget.entries.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
        }
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Display oldest first (entries are stored newest-first)
    final reversed = widget.entries.reversed.toList();

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(8),
      itemCount: reversed.length,
      itemBuilder: (context, index) {
        final entry = reversed[index];
        final isEven = index % 2 == 0;
        return _buildLogLine(entry, isEven);
      },
    );
  }

  Widget _buildLogLine(LogEntry entry, bool isEven) {
    final ts = '${entry.timestamp.hour.toString().padLeft(2, '0')}:'
        '${entry.timestamp.minute.toString().padLeft(2, '0')}:'
        '${entry.timestamp.second.toString().padLeft(2, '0')}';

    final sourceColor = switch (entry.source) {
      'mcp' => ResColors.bridged,
      'aibridge' => ResColors.connected,
      _ => ResColors.textMuted,
    };

    final messageColor = switch (entry.level) {
      LogLevel.info => ResColors.logText,
      LogLevel.warning => ResColors.logWarning,
      LogLevel.error => ResColors.logError,
      LogLevel.debug => ResColors.muted,
    };

    final (badgeColor, badgeLabel) = switch (entry.level) {
      LogLevel.info => (ResColors.connected, 'INF'),
      LogLevel.warning => (ResColors.warning, 'WRN'),
      LogLevel.error => (ResColors.error, 'ERR'),
      LogLevel.debug => (ResColors.textMuted, 'DBG'),
    };

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 4),
      decoration: BoxDecoration(
        color: isEven
            ? Colors.transparent
            : ResColors.bgSurface.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(2),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '[$ts]',
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 12,
              color: ResColors.logTimestamp,
            ),
          ),
          const SizedBox(width: 6),
          // Level badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            decoration: BoxDecoration(
              color: badgeColor.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(3),
              border: Border.all(
                color: badgeColor.withValues(alpha: 0.3),
                width: 0.5,
              ),
            ),
            child: Text(
              badgeLabel,
              style: TextStyle(
                fontSize: 9,
                color: badgeColor,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
          ),
          const SizedBox(width: 6),
          // Source badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(
              color: sourceColor.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              entry.source,
              style: TextStyle(
                fontSize: 11,
                color: sourceColor,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              entry.message,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
                color: messageColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
