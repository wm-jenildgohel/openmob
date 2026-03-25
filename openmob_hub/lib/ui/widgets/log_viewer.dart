import 'package:flutter/material.dart';
import 'package:rxdart_flutter/rxdart_flutter.dart';

import '../../core/res_colors.dart';
import '../../main.dart';
import '../../services/log_service.dart';

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
            IconButton(
              icon: const Icon(Icons.delete_outline),
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

                return ListView.builder(
                  reverse: true,
                  padding: const EdgeInsets.all(8),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    // logs are already newest-first from LogService
                    // reverse:true means index 0 is at the bottom
                    // so we read from the end to show newest at bottom
                    final entry = filtered[filtered.length - 1 - index];
                    return _buildLogLine(entry);
                  },
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLogLine(LogEntry entry) {
    final ts = '${entry.timestamp.hour.toString().padLeft(2, '0')}:'
        '${entry.timestamp.minute.toString().padLeft(2, '0')}:'
        '${entry.timestamp.second.toString().padLeft(2, '0')}';

    final sourceColor = switch (entry.source) {
      'mcp' => Colors.blue,
      'aibridge' => Colors.green,
      _ => Colors.grey,
    };

    final messageColor = switch (entry.level) {
      LogLevel.info => Colors.white70,
      LogLevel.warning => ResColors.warning,
      LogLevel.error => ResColors.error,
      LogLevel.debug => ResColors.muted,
    };

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '[$ts]',
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 12,
              color: ResColors.muted,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(
              color: sourceColor.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              entry.source,
              style: const TextStyle(
                fontSize: 11,
                color: Colors.white,
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
