import 'package:flutter/material.dart';
import 'package:rxdart_flutter/rxdart_flutter.dart';

import '../../core/res_colors.dart';
import '../../main.dart';
import '../../models/tool_status.dart';
import '../widgets/tool_status_card.dart';

class SystemCheckScreen extends StatelessWidget {
  const SystemCheckScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return ValueStreamBuilder<List<ToolStatus>>(
      stream: systemCheckService.tools$,
      builder: (context, tools, child) {
        if (tools.isEmpty) {
          return const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Checking tools...'),
              ],
            ),
          );
        }

        final available = tools.where((t) => t.available).length;
        final total = tools.length;
        final allAvailable = available == total;

        // Separate into required and optional
        const requiredNames = {'ADB', 'MCP Server'};
        final required = tools.where((t) => requiredNames.contains(t.name)).toList();
        final optional = tools.where((t) => !requiredNames.contains(t.name)).toList();

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    'System Check',
                    style: textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  ElevatedButton.icon(
                    onPressed: () => systemCheckService.checkAll(),
                    icon: const Icon(Icons.refresh),
                    label: const Text('Re-check'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                '$available/$total tools available',
                style: textTheme.titleMedium?.copyWith(
                  color: allAvailable ? ResColors.connected : ResColors.warning,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Required Tools',
                style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 3.0,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                ),
                itemCount: required.length,
                itemBuilder: (context, index) => ToolStatusCard(tool: required[index]),
              ),
              const SizedBox(height: 16),
              if (optional.isNotEmpty) ...[
                Text(
                  'Optional Tools',
                  style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 3.0,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  itemCount: optional.length,
                  itemBuilder: (context, index) => ToolStatusCard(tool: optional[index]),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
