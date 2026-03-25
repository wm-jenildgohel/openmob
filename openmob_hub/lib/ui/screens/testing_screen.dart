import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:rxdart_flutter/rxdart_flutter.dart';

import '../../core/res_colors.dart';
import '../../main.dart';
import '../../models/device.dart';
import '../../models/test_result.dart';
import '../../models/test_script.dart';

// Module-level BehaviorSubjects for reactive state (no setState)
final _selectedScriptId = BehaviorSubject<String?>.seeded(null);

class TestingScreen extends StatelessWidget {
  const TestingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(
            children: [
              Text(
                'Testing',
                style: textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              FilledButton.icon(
                onPressed: () => _showNewScriptDialog(context),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('New Script'),
                style: FilledButton.styleFrom(
                  backgroundColor: ResColors.accent,
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: () => _showFlutterTestDialog(context),
                icon: const Icon(Icons.play_arrow, size: 18),
                label: const Text('Run Flutter Test'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Current run progress indicator
          ValueStreamBuilder<TestResult?>(
            stream: testRunnerService.currentRun$,
            builder: (context, currentRun, child) {
              if (currentRun == null) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Running: ${currentRun.scriptName}',
                      style: TextStyle(
                        color: ResColors.testRunning,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    LinearProgressIndicator(
                      color: ResColors.testRunning,
                      backgroundColor: ResColors.cardBorder,
                    ),
                  ],
                ),
              );
            },
          ),
          // Two-column layout
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Left column: Script List + Editor
                Expanded(child: _buildScriptColumn(context)),
                const SizedBox(width: 16),
                // Right column: Results Dashboard
                Expanded(child: _buildResultsColumn(context)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScriptColumn(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Test Scripts',
          style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: ValueStreamBuilder<List<TestScript>>(
            stream: testRunnerService.scripts$,
            builder: (context, scripts, child) {
              if (scripts.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.science, size: 48, color: ResColors.muted),
                      const SizedBox(height: 12),
                      Text(
                        'No test scripts',
                        style: TextStyle(color: ResColors.muted),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Create a new script to get started',
                        style: TextStyle(
                          color: ResColors.muted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                );
              }

              return ValueStreamBuilder<String?>(
                stream: _selectedScriptId.stream,
                builder: (context, selectedId, child) {
                  return ListView(
                    children: [
                      ...scripts.map((script) => _buildScriptCard(
                            context,
                            script,
                            selectedId == script.id,
                          )),
                      if (selectedId != null)
                        _buildScriptJsonViewer(context, scripts, selectedId),
                    ],
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildScriptCard(
    BuildContext context,
    TestScript script,
    bool isSelected,
  ) {
    return Card(
      color: isSelected ? ResColors.sidebarActive : null,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: isSelected ? ResColors.accent : ResColors.cardBorder,
        ),
      ),
      child: ListTile(
        title: Text(
          script.name,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          script.flutterTestPath != null
              ? 'Flutter test: ${script.flutterTestPath}'
              : '${script.steps.length} steps | Device: ${script.deviceId}',
          style: TextStyle(color: ResColors.muted, fontSize: 12),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(Icons.play_arrow, color: ResColors.testRunning),
              tooltip: 'Run script',
              onPressed: () => _runScript(context, script.id),
            ),
            IconButton(
              icon: Icon(Icons.delete, color: ResColors.testFailed),
              tooltip: 'Delete script',
              onPressed: () {
                testRunnerService.removeScript(script.id);
                if (_selectedScriptId.value == script.id) {
                  _selectedScriptId.add(null);
                }
              },
            ),
          ],
        ),
        onTap: () {
          _selectedScriptId.add(
            _selectedScriptId.value == script.id ? null : script.id,
          );
        },
      ),
    );
  }

  Widget _buildScriptJsonViewer(
    BuildContext context,
    List<TestScript> scripts,
    String selectedId,
  ) {
    final script = scripts.where((s) => s.id == selectedId).firstOrNull;
    if (script == null) return const SizedBox.shrink();

    final jsonStr = const JsonEncoder.withIndent('  ').convert(script.toJson());

    return Card(
      color: ResColors.logBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: ResColors.cardBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.code, size: 16, color: ResColors.accent),
                const SizedBox(width: 8),
                Text(
                  'Script JSON',
                  style: TextStyle(
                    color: ResColors.accent,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SelectableText(
              jsonStr,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultsColumn(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Results',
          style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        // Summary row
        ValueStreamBuilder<List<TestResult>>(
          stream: testRunnerService.results$,
          builder: (context, results, child) {
            final totalPassed =
                results.where((r) => r.status == TestStatus.passed).length;
            final totalFailed =
                results.where((r) => r.status == TestStatus.failed).length;

            return Row(
              children: [
                _buildSummaryChip(
                  'Total: ${results.length}',
                  ResColors.accent,
                ),
                const SizedBox(width: 8),
                _buildSummaryChip(
                  'Passed: $totalPassed',
                  ResColors.testPassed,
                ),
                const SizedBox(width: 8),
                _buildSummaryChip(
                  'Failed: $totalFailed',
                  ResColors.testFailed,
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 12),
        // Results list
        Expanded(
          child: ValueStreamBuilder<List<TestResult>>(
            stream: testRunnerService.results$,
            builder: (context, results, child) {
              if (results.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.assessment, size: 48, color: ResColors.muted),
                      const SizedBox(height: 12),
                      Text(
                        'No test results yet',
                        style: TextStyle(color: ResColors.muted),
                      ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                itemCount: results.length,
                itemBuilder: (context, index) {
                  // Show newest first
                  final result = results[results.length - 1 - index];
                  return _buildResultTile(context, result);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(30),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withAlpha(80)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _buildResultTile(BuildContext context, TestResult result) {
    final statusIcon = switch (result.status) {
      TestStatus.passed => Icon(Icons.check_circle, color: ResColors.testPassed),
      TestStatus.failed => Icon(Icons.cancel, color: ResColors.testFailed),
      TestStatus.running =>
        SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: ResColors.testRunning,
          ),
        ),
      TestStatus.error => Icon(Icons.error, color: ResColors.testFailed),
    };

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: ResColors.cardBorder),
      ),
      child: ExpansionTile(
        leading: statusIcon,
        title: Text(
          result.scriptName,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          '${result.passedCount}/${result.steps.length} steps passed | ${result.totalDurationMs}ms',
          style: TextStyle(color: ResColors.muted, fontSize: 12),
        ),
        children: result.steps
            .map((step) => _buildStepResultRow(context, step))
            .toList(),
      ),
    );
  }

  Widget _buildStepResultRow(BuildContext context, StepResult step) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          Icon(
            step.success ? Icons.check : Icons.close,
            size: 16,
            color: step.success ? ResColors.testPassed : ResColors.testFailed,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Step ${step.stepIndex + 1}: ${step.action}',
                  style: const TextStyle(fontSize: 13),
                ),
                if (step.error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      step.error!,
                      style: TextStyle(
                        color: ResColors.testFailed,
                        fontSize: 11,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Text(
            '${step.durationMs}ms',
            style: TextStyle(color: ResColors.muted, fontSize: 11),
          ),
          if (step.screenshotBase64 != null) ...[
            const SizedBox(width: 8),
            IconButton(
              icon: Icon(Icons.image, size: 16, color: ResColors.accent),
              tooltip: 'View failure screenshot',
              onPressed: () =>
                  _showScreenshotDialog(context, step.screenshotBase64!),
            ),
          ],
        ],
      ),
    );
  }

  void _showScreenshotDialog(BuildContext context, String base64Data) {
    final bytes = base64Decode(base64Data);

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Failure Screenshot'),
          content: SizedBox(
            width: 400,
            child: Image.memory(
              Uint8List.fromList(bytes),
              fit: BoxFit.contain,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  void _runScript(BuildContext context, String scriptId) {
    testRunnerService.runScript(scriptId).then((_) {}, onError: (Object e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Test error: $e'),
            backgroundColor: ResColors.testFailed,
          ),
        );
      }
    });
  }

  void _showNewScriptDialog(BuildContext context) {
    final nameController = TextEditingController();
    final stepsController = TextEditingController(
      text: '[\n  {\n    "action": "tap",\n    "params": {"x": 100, "y": 200},\n    "description": "Tap on element"\n  }\n]',
    );
    final selectedDeviceId = BehaviorSubject<String>.seeded('');

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('New Test Script'),
          content: SizedBox(
            width: 500,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Script Name',
                      hintText: 'e.g. Login Flow Test',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ValueStreamBuilder<List<Device>>(
                    stream: deviceManager.devices$,
                    builder: (context, devices, child) {
                      if (devices.isEmpty) {
                        return TextField(
                          onChanged: (v) => selectedDeviceId.add(v),
                          decoration: const InputDecoration(
                            labelText: 'Device ID',
                            hintText: 'No devices connected - enter ID manually',
                            border: OutlineInputBorder(),
                          ),
                        );
                      }
                      if (selectedDeviceId.value.isEmpty && devices.isNotEmpty) {
                        selectedDeviceId.add(devices.first.id);
                      }
                      return ValueStreamBuilder<String>(
                        stream: selectedDeviceId.stream,
                        builder: (context, currentId, child) {
                          return DropdownButtonFormField<String>(
                            // ignore: deprecated_member_use
                            value: devices.any((d) => d.id == currentId)
                                ? currentId
                                : devices.first.id,
                            decoration: const InputDecoration(
                              labelText: 'Device',
                              border: OutlineInputBorder(),
                            ),
                            items: devices
                                .map((d) => DropdownMenuItem(
                                      value: d.id,
                                      child: Text('${d.model} (${d.id})'),
                                    ))
                                .toList(),
                            onChanged: (v) {
                              if (v != null) selectedDeviceId.add(v);
                            },
                          );
                        },
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Steps (JSON array)',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                  const SizedBox(height: 4),
                  TextField(
                    controller: stepsController,
                    maxLines: 12,
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      hintText: 'Enter JSON array of test steps',
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                selectedDeviceId.close();
                Navigator.of(ctx).pop();
              },
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final name = nameController.text.trim();
                final deviceId = selectedDeviceId.value;
                if (name.isEmpty) return;

                try {
                  final stepsJson =
                      jsonDecode(stepsController.text) as List<dynamic>;
                  final steps = stepsJson
                      .map((s) =>
                          TestStep.fromJson(s as Map<String, dynamic>))
                      .toList();

                  final script = TestScript(
                    name: name,
                    deviceId: deviceId,
                    steps: steps,
                  );

                  testRunnerService.addScript(script);
                  selectedDeviceId.close();
                  Navigator.of(ctx).pop();
                } catch (e) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(
                      content: Text('Invalid JSON: $e'),
                      backgroundColor: ResColors.testFailed,
                    ),
                  );
                }
              },
              style: FilledButton.styleFrom(
                backgroundColor: ResColors.accent,
              ),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  void _showFlutterTestDialog(BuildContext context) {
    final pathController = TextEditingController(text: 'test/widget_test.dart');
    final selectedDeviceId = BehaviorSubject<String>.seeded('');

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Run Flutter Test'),
          content: SizedBox(
            width: 450,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: pathController,
                  decoration: const InputDecoration(
                    labelText: 'Test File Path',
                    hintText: 'e.g. test/widget_test.dart',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                ValueStreamBuilder<List<Device>>(
                  stream: deviceManager.devices$,
                  builder: (context, devices, child) {
                    if (devices.isEmpty) {
                      return Text(
                        'No devices connected (optional for unit tests)',
                        style: TextStyle(
                          color: ResColors.muted,
                          fontSize: 12,
                        ),
                      );
                    }
                    if (selectedDeviceId.value.isEmpty && devices.isNotEmpty) {
                      selectedDeviceId.add(devices.first.id);
                    }
                    return ValueStreamBuilder<String>(
                      stream: selectedDeviceId.stream,
                      builder: (context, currentId, child) {
                        return DropdownButtonFormField<String>(
                          // ignore: deprecated_member_use
                          value: devices.any((d) => d.id == currentId)
                              ? currentId
                              : devices.first.id,
                          decoration: const InputDecoration(
                            labelText: 'Device (for integration tests)',
                            border: OutlineInputBorder(),
                          ),
                          items: devices
                              .map((d) => DropdownMenuItem(
                                    value: d.id,
                                    child: Text('${d.model} (${d.id})'),
                                  ))
                              .toList(),
                          onChanged: (v) {
                            if (v != null) selectedDeviceId.add(v);
                          },
                        );
                      },
                    );
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                selectedDeviceId.close();
                Navigator.of(ctx).pop();
              },
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final testPath = pathController.text.trim();
                if (testPath.isEmpty) return;

                final script = TestScript(
                  name: 'Flutter: $testPath',
                  deviceId: selectedDeviceId.value,
                  flutterTestPath: testPath,
                );

                testRunnerService.addScript(script);
                selectedDeviceId.close();
                Navigator.of(ctx).pop();

                // Run the script immediately
                testRunnerService.runScript(script.id).then((_) {}, onError: (Object e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Flutter test error: $e'),
                        backgroundColor: ResColors.testFailed,
                      ),
                    );
                  }
                });
              },
              style: FilledButton.styleFrom(
                backgroundColor: ResColors.accent,
              ),
              child: const Text('Run'),
            ),
          ],
        );
      },
    );
  }
}
