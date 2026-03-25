import 'package:flutter/material.dart';
import 'package:rxdart_flutter/rxdart_flutter.dart';

import '../../core/res_colors.dart';
import '../../main.dart';
import '../widgets/log_viewer.dart';

final _logFilter = BehaviorSubject<String?>.seeded(null);

class LogsScreen extends StatelessWidget {
  const LogsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Logs',
                style: textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.delete_outline),
                tooltip: 'Clear all logs',
                onPressed: () => logService.clear(),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ValueStreamBuilder<String?>(
            stream: _logFilter.stream,
            builder: (context, activeFilter, child) {
              return Row(
                children: [
                  _buildFilterChip('All', null, activeFilter),
                  const SizedBox(width: 8),
                  _buildFilterChip('Hub', 'hub', activeFilter),
                  const SizedBox(width: 8),
                  _buildFilterChip('MCP', 'mcp', activeFilter),
                  const SizedBox(width: 8),
                  _buildFilterChip('AiBridge', 'aibridge', activeFilter),
                ],
              );
            },
          ),
          const SizedBox(height: 12),
          Expanded(
            child: ValueStreamBuilder<String?>(
              stream: _logFilter.stream,
              builder: (context, filter, child) {
                return LogViewer(filterSource: filter);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String? value, String? activeFilter) {
    final selected = activeFilter == value;
    return FilterChip(
      label: Text(label),
      selected: selected,
      selectedColor: ResColors.accent,
      checkmarkColor: Colors.white,
      onSelected: (isSelected) {
        if (isSelected) {
          _logFilter.add(value);
        } else {
          _logFilter.add(null);
        }
      },
    );
  }
}
