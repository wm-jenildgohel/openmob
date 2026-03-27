import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:rxdart_flutter/rxdart_flutter.dart';

import '../../core/res_colors.dart';
import '../../main.dart';
import '../../models/device.dart';
import '../../models/test_result.dart';
import '../../models/test_script.dart';

// ---------------------------------------------------------------------------
// Reactive state — module-level BehaviorSubjects (no setState)
// ---------------------------------------------------------------------------
final _selectedScriptId = BehaviorSubject<String?>.seeded(null);
final _editorSteps = BehaviorSubject<List<_EditableStep>>.seeded([]);
final _editorScriptName = BehaviorSubject<String>.seeded('');
final _editorDeviceId = BehaviorSubject<String>.seeded('');
final _isEditorDirty = BehaviorSubject<bool>.seeded(false);
final _expandedResultId = BehaviorSubject<String?>.seeded(null);

// Available actions for the step builder
const _kActions = [
  'tap',
  'type_text',
  'swipe',
  'launch_app',
  'terminate_app',
  'open_url',
  'go_home',
  'wait',
  'press_key',
  'gesture',
];

IconData _iconForAction(String action) {
  return switch (action) {
    'tap' => Iconsax.finger_cricle,
    'type_text' => Iconsax.keyboard,
    'swipe' => Iconsax.arrow_swap_horizontal,
    'launch_app' => Iconsax.play_circle,
    'terminate_app' => Iconsax.close_circle,
    'open_url' => Iconsax.global,
    'go_home' => Iconsax.home_2,
    'wait' => Iconsax.timer_1,
    'press_key' => Iconsax.command,
    'gesture' => Iconsax.finger_scan,
    _ => Iconsax.code_1,
  };
}

Color _colorForStatus(TestStatus status) {
  return switch (status) {
    TestStatus.passed => ResColors.testPassed,
    TestStatus.failed => ResColors.testFailed,
    TestStatus.running => ResColors.testRunning,
    TestStatus.error => ResColors.testFailed,
  };
}

/// Mutable step model used only inside the editor.
class _EditableStep {
  String action;
  String description;
  Map<String, String> params;

  _EditableStep({
    this.action = 'tap',
    this.description = '',
    Map<String, String>? params,
  }) : params = params ?? {};
}

// ---------------------------------------------------------------------------
// Helper: convert editor state -> TestStep list
// ---------------------------------------------------------------------------
List<TestStep> _editorToSteps() {
  return _editorSteps.value.map((e) {
    final dynamic parsedParams = <String, dynamic>{};
    for (final entry in e.params.entries) {
      final v = num.tryParse(entry.value);
      (parsedParams as Map<String, dynamic>)[entry.key] =
          v ?? entry.value;
    }
    return TestStep(
      action: e.action,
      params: parsedParams as Map<String, dynamic>,
      description: e.description.isEmpty ? null : e.description,
    );
  }).toList();
}

void _loadScriptIntoEditor(TestScript script) {
  _editorScriptName.add(script.name);
  _editorDeviceId.add(script.deviceId);
  _editorSteps.add(
    script.steps
        .map((s) => _EditableStep(
              action: s.action,
              description: s.description ?? '',
              params: s.params
                  .map((k, v) => MapEntry(k, v.toString())),
            ))
        .toList(),
  );
  _isEditorDirty.add(false);
}

void _clearEditor() {
  _editorScriptName.add('');
  _editorDeviceId.add('');
  _editorSteps.add([]);
  _isEditorDirty.add(false);
}

// ============================================================================
// TestingScreen
// ============================================================================
class TestingScreen extends StatelessWidget {
  const TestingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildToolbar(context),
          const SizedBox(height: 16),
          _buildRunningBanner(),
          Expanded(child: _buildBody(context)),
        ],
      ),
    );
  }

  // ---- Top toolbar ----
  Widget _buildToolbar(BuildContext context) {
    return Row(
      children: [
        const Icon(Iconsax.task_square, color: ResColors.accent, size: 22),
        const SizedBox(width: 10),
        Text(
          'QA Testing',
          style: Theme.of(context)
              .textTheme
              .headlineSmall
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        const Spacer(),
        // Record (future)
        _ToolbarButton(
          icon: Iconsax.record,
          label: 'Record',
          color: ResColors.textMuted,
          onTap: null, // disabled — future feature
          tooltip: 'Coming soon',
        ),
        const SizedBox(width: 8),
        // Run All
        ValueStreamBuilder<List<TestScript>>(
          stream: testRunnerService.scripts$,
          builder: (context, scripts, _) {
            return _ToolbarButton(
              icon: Iconsax.play,
              label: 'Run All',
              color: ResColors.testRunning,
              onTap: scripts.isEmpty
                  ? null
                  : () => _runAll(context),
            );
          },
        ),
        const SizedBox(width: 8),
        // New Test
        _ToolbarButton(
          icon: Iconsax.add_circle,
          label: 'New Test',
          color: ResColors.accent,
          filled: true,
          onTap: () => _newTest(),
        ),
      ],
    );
  }

  // ---- Running banner ----
  Widget _buildRunningBanner() {
    return ValueStreamBuilder<TestResult?>(
      stream: testRunnerService.currentRun$,
      builder: (context, currentRun, _) {
        if (currentRun == null) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: ResColors.testRunning.withAlpha(20),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: ResColors.testRunning.withAlpha(60)),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: ResColors.testRunning,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Running: ${currentRun.scriptName}',
                  style: const TextStyle(
                    color: ResColors.testRunning,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                const Spacer(),
                Text(
                  '${currentRun.passedCount}/${currentRun.steps.length} steps',
                  style: TextStyle(
                    color: ResColors.testRunning.withAlpha(180),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ---- Body: 3-column or empty ----
  Widget _buildBody(BuildContext context) {
    return ValueStreamBuilder<List<TestScript>>(
      stream: testRunnerService.scripts$,
      builder: (context, scripts, _) {
        if (scripts.isEmpty) {
          return _buildEmptyState(context);
        }
        return LayoutBuilder(
          builder: (context, constraints) {
            // 2-column below 1100, 3-column above
            final wide = constraints.maxWidth >= 1100;
            if (wide) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(width: 260, child: _ScriptListPanel()),
                  const SizedBox(width: 16),
                  Expanded(child: _ScriptEditorPanel()),
                  const SizedBox(width: 16),
                  SizedBox(width: 320, child: _ResultsPanel()),
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(width: 260, child: _ScriptListPanel()),
                const SizedBox(width: 16),
                Expanded(
                  child: ValueStreamBuilder<String?>(
                    stream: _selectedScriptId.stream,
                    builder: (context, selectedId, _) {
                      if (selectedId != null) {
                        return _ScriptEditorPanel();
                      }
                      return _ResultsPanel();
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ---- Empty state ----
  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: ResColors.accentSoft,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(
              Iconsax.task_square,
              size: 40,
              color: ResColors.accent,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Create your first test',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Build automated test scripts for any mobile device.\nAdd steps like tap, swipe, type, launch, and assert.',
            textAlign: TextAlign.center,
            style: TextStyle(color: ResColors.textSecondary, height: 1.5),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _newTest,
            icon: const Icon(Iconsax.add_circle, size: 18),
            label: const Text('New Test Script'),
            style: FilledButton.styleFrom(
              backgroundColor: ResColors.accent,
              padding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            ),
          ),
        ],
      ),
    );
  }

  // ---- Actions ----
  void _newTest() {
    _selectedScriptId.add(null);
    _clearEditor();
    _editorSteps.add([_EditableStep()]);
    _isEditorDirty.add(true);
    // Signal the editor to show by setting a sentinel
    _selectedScriptId.add('__new__');
  }

  void _runAll(BuildContext context) {
    final scripts = testRunnerService.scripts$.value;
    _runScriptsSequentially(context, scripts, 0);
  }

  static void _runScriptsSequentially(
    BuildContext context,
    List<TestScript> scripts,
    int index,
  ) {
    if (index >= scripts.length) return;
    testRunnerService.runScript(scripts[index].id).then((_) {
      _runScriptsSequentially(context, scripts, index + 1);
    }, onError: (Object e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error in "${scripts[index].name}": $e'),
            backgroundColor: ResColors.testFailed,
          ),
        );
      }
      _runScriptsSequentially(context, scripts, index + 1);
    });
  }
}

// ============================================================================
// Toolbar button widget
// ============================================================================
class _ToolbarButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool filled;
  final VoidCallback? onTap;
  final String? tooltip;

  const _ToolbarButton({
    required this.icon,
    required this.label,
    required this.color,
    this.filled = false,
    this.onTap,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    final isDisabled = onTap == null;
    final effectiveColor = isDisabled ? ResColors.textMuted : color;

    final child = Material(
      color: filled ? effectiveColor : Colors.transparent,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: filled
                ? null
                : Border.all(
                    color: effectiveColor.withAlpha(80),
                  ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 16,
                color: filled ? ResColors.textOnAccent : effectiveColor,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: filled ? ResColors.textOnAccent : effectiveColor,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (tooltip != null) {
      return Tooltip(message: tooltip!, child: child);
    }
    return child;
  }
}

// ============================================================================
// Left Panel — Script List
// ============================================================================
class _ScriptListPanel extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Iconsax.document_code, size: 16, color: ResColors.textSecondary),
            const SizedBox(width: 8),
            Text(
              'Test Scripts',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: ResColors.textSecondary,
                    letterSpacing: 0.5,
                  ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Expanded(
          child: ValueStreamBuilder<List<TestScript>>(
            stream: testRunnerService.scripts$,
            builder: (context, scripts, _) {
              return ValueStreamBuilder<String?>(
                stream: _selectedScriptId.stream,
                builder: (context, selectedId, _) {
                  return ListView.separated(
                    itemCount: scripts.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 6),
                    itemBuilder: (context, index) {
                      final script = scripts[index];
                      final isSelected = selectedId == script.id;
                      return _ScriptListTile(
                        script: script,
                        isSelected: isSelected,
                      );
                    },
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ScriptListTile extends StatelessWidget {
  final TestScript script;
  final bool isSelected;

  const _ScriptListTile({
    required this.script,
    required this.isSelected,
  });

  @override
  Widget build(BuildContext context) {
    // Determine last result status for this script
    final results = testRunnerService.results$.value;
    final lastResult = results
        .where((r) => r.scriptId == script.id)
        .fold<TestResult?>(null, (prev, r) => r);

    final statusColor = lastResult != null
        ? _colorForStatus(lastResult.status)
        : ResColors.textMuted;

    return Material(
      color: isSelected ? ResColors.accentSoft : ResColors.cardBg,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: () {
          _selectedScriptId.add(script.id);
          _loadScriptIntoEditor(script);
        },
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? ResColors.accent : ResColors.cardBorder,
            ),
          ),
          child: Row(
            children: [
              // Status dot
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: statusColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      script.name,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: isSelected
                            ? ResColors.textPrimary
                            : ResColors.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${script.steps.length} steps',
                      style: const TextStyle(
                        color: ResColors.textMuted,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              // Play button
              _SmallIconButton(
                icon: Iconsax.play,
                color: ResColors.testRunning,
                tooltip: 'Run',
                onTap: () => _runScript(context, script.id),
              ),
              const SizedBox(width: 2),
              // Delete button
              _SmallIconButton(
                icon: Iconsax.trash,
                color: ResColors.testFailed,
                tooltip: 'Delete',
                onTap: () {
                  testRunnerService.removeScript(script.id);
                  if (_selectedScriptId.value == script.id) {
                    _selectedScriptId.add(null);
                    _clearEditor();
                  }
                },
              ),
            ],
          ),
        ),
      ),
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
}

class _SmallIconButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback onTap;

  const _SmallIconButton({
    required this.icon,
    required this.color,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(icon, size: 14, color: color),
        ),
      ),
    );
  }
}

// ============================================================================
// Center Panel — Visual Step Builder / Editor
// ============================================================================
class _ScriptEditorPanel extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ValueStreamBuilder<String?>(
      stream: _selectedScriptId.stream,
      builder: (context, selectedId, _) {
        if (selectedId == null) {
          return _buildEditorPlaceholder(context);
        }
        return Container(
          decoration: BoxDecoration(
            color: ResColors.cardBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: ResColors.cardBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildEditorHeader(context, selectedId),
              const Divider(color: ResColors.cardBorder, height: 1),
              Expanded(child: _buildStepList(context)),
              _buildEditorFooter(context, selectedId),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEditorPlaceholder(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: ResColors.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ResColors.cardBorder),
      ),
      child: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Iconsax.edit_2, size: 36, color: ResColors.textMuted),
            SizedBox(height: 12),
            Text(
              'Select a script to edit',
              style: TextStyle(color: ResColors.textMuted, fontSize: 14),
            ),
            SizedBox(height: 4),
            Text(
              'or create a new test',
              style: TextStyle(color: ResColors.textMuted, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEditorHeader(BuildContext context, String selectedId) {
    final isNew = selectedId == '__new__';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Iconsax.edit_2, size: 16, color: ResColors.accent),
              const SizedBox(width: 8),
              Text(
                isNew ? 'New Test Script' : 'Edit Script',
                style: const TextStyle(
                  color: ResColors.accent,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
              const Spacer(),
              ValueStreamBuilder<bool>(
                stream: _isEditorDirty.stream,
                builder: (context, dirty, _) {
                  if (!dirty) return const SizedBox.shrink();
                  return Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: ResColors.warning.withAlpha(30),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'unsaved',
                      style: TextStyle(
                        color: ResColors.warning,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Script name
          ValueStreamBuilder<String>(
            stream: _editorScriptName.stream,
            builder: (context, name, _) {
              return _EditorTextField(
                icon: Iconsax.text,
                hint: 'Script name',
                initialValue: name,
                onChanged: (v) {
                  _editorScriptName.add(v);
                  _isEditorDirty.add(true);
                },
              );
            },
          ),
          const SizedBox(height: 8),
          // Device selector
          ValueStreamBuilder<List<Device>>(
            stream: deviceManager.devices$,
            builder: (context, devices, _) {
              return ValueStreamBuilder<String>(
                stream: _editorDeviceId.stream,
                builder: (context, currentDeviceId, _) {
                  if (devices.isEmpty) {
                    return _EditorTextField(
                      icon: Iconsax.mobile,
                      hint: 'Device ID (no devices connected)',
                      initialValue: currentDeviceId,
                      onChanged: (v) {
                        _editorDeviceId.add(v);
                        _isEditorDirty.add(true);
                      },
                    );
                  }
                  return Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                    decoration: BoxDecoration(
                      color: ResColors.bgSurface,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Iconsax.mobile, size: 14, color: ResColors.textMuted),
                        const SizedBox(width: 8),
                        Expanded(
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: devices.any((d) => d.id == currentDeviceId)
                                  ? currentDeviceId
                                  : (devices.isNotEmpty ? devices.first.id : ''),
                              isExpanded: true,
                              dropdownColor: ResColors.bgElevated,
                              style: const TextStyle(
                                color: ResColors.textPrimary,
                                fontSize: 13,
                              ),
                              items: devices
                                  .map((d) => DropdownMenuItem(
                                        value: d.id,
                                        child: Text(
                                          '${d.model} (${d.id})',
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ))
                                  .toList(),
                              onChanged: (v) {
                                if (v != null) {
                                  _editorDeviceId.add(v);
                                  _isEditorDirty.add(true);
                                }
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildStepList(BuildContext context) {
    return ValueStreamBuilder<List<_EditableStep>>(
      stream: _editorSteps.stream,
      builder: (context, steps, _) {
        if (steps.isEmpty) {
          return const Center(
            child: Text(
              'No steps yet. Add one below.',
              style: TextStyle(color: ResColors.textMuted, fontSize: 13),
            ),
          );
        }
        return ReorderableListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          itemCount: steps.length,
          onReorder: (oldIndex, newIndex) {
            final list = List<_EditableStep>.from(steps);
            if (newIndex > oldIndex) newIndex--;
            final item = list.removeAt(oldIndex);
            list.insert(newIndex, item);
            _editorSteps.add(list);
            _isEditorDirty.add(true);
          },
          proxyDecorator: (child, index, animation) {
            return Material(
              color: ResColors.accentSoft,
              borderRadius: BorderRadius.circular(10),
              elevation: 4,
              child: child,
            );
          },
          itemBuilder: (context, index) {
            return _StepCard(
              key: ValueKey('step_$index'),
              step: steps[index],
              index: index,
              total: steps.length,
              onChanged: () {
                _editorSteps.add(List.from(steps));
                _isEditorDirty.add(true);
              },
              onRemove: () {
                final list = List<_EditableStep>.from(steps);
                list.removeAt(index);
                _editorSteps.add(list);
                _isEditorDirty.add(true);
              },
            );
          },
        );
      },
    );
  }

  Widget _buildEditorFooter(BuildContext context, String selectedId) {
    final isNew = selectedId == '__new__';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: ResColors.cardBorder)),
      ),
      child: Row(
        children: [
          // Add step
          InkWell(
            onTap: () {
              final steps = List<_EditableStep>.from(_editorSteps.value);
              steps.add(_EditableStep());
              _editorSteps.add(steps);
              _isEditorDirty.add(true);
            },
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: ResColors.accent.withAlpha(80),
                ),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Iconsax.add, size: 14, color: ResColors.accent),
                  SizedBox(width: 6),
                  Text(
                    'Add Step',
                    style: TextStyle(
                      color: ResColors.accent,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Spacer(),
          // Cancel
          TextButton(
            onPressed: () {
              if (isNew) {
                _selectedScriptId.add(null);
                _clearEditor();
              } else {
                // Reload original
                final script = testRunnerService.getScript(selectedId);
                if (script != null) _loadScriptIntoEditor(script);
              }
            },
            child: const Text(
              'Cancel',
              style: TextStyle(color: ResColors.textMuted),
            ),
          ),
          const SizedBox(width: 8),
          // Save
          FilledButton.icon(
            onPressed: () => _saveScript(context, isNew, selectedId),
            icon: const Icon(Iconsax.tick_circle, size: 16),
            label: const Text('Save'),
            style: FilledButton.styleFrom(
              backgroundColor: ResColors.accent,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
          ),
        ],
      ),
    );
  }

  void _saveScript(BuildContext context, bool isNew, String selectedId) {
    final name = _editorScriptName.value.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Script name is required'),
          backgroundColor: ResColors.testFailed,
        ),
      );
      return;
    }

    final steps = _editorToSteps();
    final deviceId = _editorDeviceId.value;

    if (isNew) {
      final script = TestScript(
        name: name,
        deviceId: deviceId,
        steps: steps,
      );
      testRunnerService.addScript(script);
      _selectedScriptId.add(script.id);
      _loadScriptIntoEditor(script);
    } else {
      // Remove old, add updated (preserves id)
      testRunnerService.removeScript(selectedId);
      final script = TestScript(
        id: selectedId,
        name: name,
        deviceId: deviceId,
        steps: steps,
      );
      testRunnerService.addScript(script);
      _loadScriptIntoEditor(script);
    }

    _isEditorDirty.add(false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Saved "$name"'),
        backgroundColor: ResColors.testPassed,
        duration: const Duration(seconds: 1),
      ),
    );
  }
}

// ============================================================================
// Step card inside the editor
// ============================================================================
class _StepCard extends StatelessWidget {
  final _EditableStep step;
  final int index;
  final int total;
  final VoidCallback onChanged;
  final VoidCallback onRemove;

  const _StepCard({
    super.key,
    required this.step,
    required this.index,
    required this.total,
    required this.onChanged,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        decoration: BoxDecoration(
          color: ResColors.bgSurface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: ResColors.cardBorder),
        ),
        padding: const EdgeInsets.all(10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag handle
            ReorderableDragStartListener(
              index: index,
              child: const Padding(
                padding: EdgeInsets.only(top: 4, right: 8),
                child: Icon(
                  Iconsax.menu_1,
                  size: 16,
                  color: ResColors.textMuted,
                ),
              ),
            ),
            // Step number + action icon
            Column(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: ResColors.accentSoft,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Text(
                      '${index + 1}',
                      style: const TextStyle(
                        color: ResColors.accent,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Icon(
                  _iconForAction(step.action),
                  size: 14,
                  color: ResColors.textMuted,
                ),
              ],
            ),
            const SizedBox(width: 10),
            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Action dropdown
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      color: ResColors.bgElevated,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: step.action,
                        isExpanded: true,
                        dropdownColor: ResColors.bgElevated,
                        style: const TextStyle(
                          color: ResColors.textPrimary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                        items: _kActions
                            .map((a) => DropdownMenuItem(
                                  value: a,
                                  child: Row(
                                    children: [
                                      Icon(_iconForAction(a),
                                          size: 13,
                                          color: ResColors.textSecondary),
                                      const SizedBox(width: 6),
                                      Text(a),
                                    ],
                                  ),
                                ))
                            .toList(),
                        onChanged: (v) {
                          if (v != null) {
                            step.action = v;
                            step.params = _defaultParamsFor(v);
                            onChanged();
                          }
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  // Description
                  _MiniTextField(
                    hint: 'Description (optional)',
                    initialValue: step.description,
                    onChanged: (v) {
                      step.description = v;
                      onChanged();
                    },
                  ),
                  const SizedBox(height: 6),
                  // Params
                  _ParamEditor(
                    step: step,
                    onChanged: onChanged,
                  ),
                ],
              ),
            ),
            // Remove button
            InkWell(
              onTap: onRemove,
              borderRadius: BorderRadius.circular(6),
              child: const Padding(
                padding: EdgeInsets.all(4),
                child:
                    Icon(Iconsax.close_circle, size: 16, color: ResColors.testFailed),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Map<String, String> _defaultParamsFor(String action) {
    return switch (action) {
      'tap' => {'x': '100', 'y': '200'},
      'type_text' => {'text': ''},
      'swipe' => {'x1': '100', 'y1': '500', 'x2': '100', 'y2': '200'},
      'launch_app' => {'package': ''},
      'terminate_app' => {'package': ''},
      'open_url' => {'url': ''},
      'wait' => {'duration': '1000'},
      'press_key' => {'keyCode': '4'},
      'gesture' => {'type': 'pinch'},
      _ => {},
    };
  }
}

// ============================================================================
// Param editor for a step
// ============================================================================
class _ParamEditor extends StatelessWidget {
  final _EditableStep step;
  final VoidCallback onChanged;

  const _ParamEditor({required this.step, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final params = step.params;
    if (params.isEmpty) {
      // Show an "add param" hint
      return InkWell(
        onTap: () {
          step.params['key'] = 'value';
          onChanged();
        },
        borderRadius: BorderRadius.circular(6),
        child: const Padding(
          padding: EdgeInsets.symmetric(vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Iconsax.add, size: 12, color: ResColors.textMuted),
              SizedBox(width: 4),
              Text(
                'Add parameter',
                style: TextStyle(color: ResColors.textMuted, fontSize: 11),
              ),
            ],
          ),
        ),
      );
    }

    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: params.entries.map((entry) {
        return _ParamChip(
          paramKey: entry.key,
          paramValue: entry.value,
          onValueChanged: (v) {
            step.params[entry.key] = v;
            onChanged();
          },
          onRemove: () {
            step.params.remove(entry.key);
            onChanged();
          },
        );
      }).toList(),
    );
  }
}

class _ParamChip extends StatelessWidget {
  final String paramKey;
  final String paramValue;
  final ValueChanged<String> onValueChanged;
  final VoidCallback onRemove;

  const _ParamChip({
    required this.paramKey,
    required this.paramValue,
    required this.onValueChanged,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: ResColors.bgElevated,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: ResColors.cardBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$paramKey:',
            style: const TextStyle(
              color: ResColors.textMuted,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 4),
          IntrinsicWidth(
            child: ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 30, maxWidth: 120),
              child: _InlineEdit(
                value: paramValue,
                onChanged: onValueChanged,
              ),
            ),
          ),
          const SizedBox(width: 2),
          InkWell(
            onTap: onRemove,
            child: const Icon(Iconsax.close_square, size: 12, color: ResColors.textMuted),
          ),
        ],
      ),
    );
  }
}

/// Inline editable text for param values.
class _InlineEdit extends StatefulWidget {
  final String value;
  final ValueChanged<String> onChanged;

  const _InlineEdit({required this.value, required this.onChanged});

  @override
  State<_InlineEdit> createState() => _InlineEditState();
}

class _InlineEditState extends State<_InlineEdit> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value);
  }

  @override
  void didUpdateWidget(covariant _InlineEdit oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value &&
        widget.value != _controller.text) {
      _controller.text = widget.value;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      style: const TextStyle(
        color: ResColors.textPrimary,
        fontSize: 11,
      ),
      decoration: const InputDecoration(
        isDense: true,
        contentPadding: EdgeInsets.zero,
        border: InputBorder.none,
      ),
      onChanged: widget.onChanged,
    );
  }
}

// ============================================================================
// Right Panel — Results
// ============================================================================
class _ResultsPanel extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Iconsax.chart_2, size: 16, color: ResColors.textSecondary),
            const SizedBox(width: 8),
            Text(
              'Results',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: ResColors.textSecondary,
                    letterSpacing: 0.5,
                  ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Summary chips
        ValueStreamBuilder<List<TestResult>>(
          stream: testRunnerService.results$,
          builder: (context, results, _) {
            final passed =
                results.where((r) => r.status == TestStatus.passed).length;
            final failed =
                results.where((r) => r.status == TestStatus.failed).length;
            return Row(
              children: [
                _SummaryChip(
                  icon: Iconsax.chart_1,
                  label: '${results.length}',
                  color: ResColors.accent,
                ),
                const SizedBox(width: 6),
                _SummaryChip(
                  icon: Iconsax.tick_circle,
                  label: '$passed',
                  color: ResColors.testPassed,
                ),
                const SizedBox(width: 6),
                _SummaryChip(
                  icon: Iconsax.close_circle,
                  label: '$failed',
                  color: ResColors.testFailed,
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
            builder: (context, results, _) {
              if (results.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Iconsax.chart_fail,
                          size: 36, color: ResColors.textMuted),
                      const SizedBox(height: 12),
                      const Text(
                        'No results yet',
                        style: TextStyle(color: ResColors.textMuted),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Run a test to see results here',
                        style:
                            TextStyle(color: ResColors.textMuted, fontSize: 12),
                      ),
                    ],
                  ),
                );
              }

              // Newest first
              final sorted = results.reversed.toList();
              return ValueStreamBuilder<String?>(
                stream: _expandedResultId.stream,
                builder: (context, expandedId, _) {
                  return ListView.separated(
                    itemCount: sorted.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final result = sorted[index];
                      final isExpanded =
                          expandedId == '${result.scriptId}_${result.startedAt.millisecondsSinceEpoch}';
                      return _ResultCard(
                        result: result,
                        isExpanded: isExpanded,
                      );
                    },
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _SummaryChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _SummaryChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withAlpha(25),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withAlpha(60)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// Result card with expandable step breakdown
// ============================================================================
class _ResultCard extends StatelessWidget {
  final TestResult result;
  final bool isExpanded;

  const _ResultCard({
    required this.result,
    required this.isExpanded,
  });

  String get _resultKey =>
      '${result.scriptId}_${result.startedAt.millisecondsSinceEpoch}';

  @override
  Widget build(BuildContext context) {
    final statusColor = _colorForStatus(result.status);
    final statusIcon = switch (result.status) {
      TestStatus.passed => Iconsax.tick_circle,
      TestStatus.failed => Iconsax.close_circle,
      TestStatus.running => Iconsax.timer_1,
      TestStatus.error => Iconsax.warning_2,
    };

    return Container(
      decoration: BoxDecoration(
        color: ResColors.cardBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: statusColor.withAlpha(60)),
      ),
      child: Column(
        children: [
          // Header
          InkWell(
            onTap: () {
              _expandedResultId
                  .add(isExpanded ? null : _resultKey);
            },
            borderRadius: BorderRadius.circular(10),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  // Status badge
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: statusColor.withAlpha(25),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: result.status == TestStatus.running
                        ? Padding(
                            padding: const EdgeInsets.all(6),
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: statusColor,
                            ),
                          )
                        : Icon(statusIcon, size: 16, color: statusColor),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          result.scriptName,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${result.passedCount}/${result.steps.length} passed  |  ${result.totalDurationMs}ms',
                          style: const TextStyle(
                            color: ResColors.textMuted,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    isExpanded ? Iconsax.arrow_up_2 : Iconsax.arrow_down_1,
                    size: 16,
                    color: ResColors.textMuted,
                  ),
                ],
              ),
            ),
          ),
          // Step breakdown (if expanded)
          if (isExpanded) ...[
            const Divider(color: ResColors.cardBorder, height: 1),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                children: result.steps
                    .map((step) => _buildStepRow(context, step))
                    .toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStepRow(BuildContext context, StepResult step) {
    final stepColor =
        step.success ? ResColors.testPassed : ResColors.testFailed;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Icon(
            step.success ? Iconsax.tick_circle : Iconsax.close_circle,
            size: 14,
            color: stepColor,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Step ${step.stepIndex + 1}: ${step.action}',
                  style: const TextStyle(fontSize: 12),
                ),
                if (step.error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      step.error!,
                      style: const TextStyle(
                        color: ResColors.testFailed,
                        fontSize: 10,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Text(
            '${step.durationMs}ms',
            style: const TextStyle(color: ResColors.textMuted, fontSize: 10),
          ),
          if (step.screenshotBase64 != null) ...[
            const SizedBox(width: 4),
            _SmallIconButton(
              icon: Iconsax.image,
              color: ResColors.accent,
              tooltip: 'View screenshot',
              onTap: () =>
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
          backgroundColor: ResColors.bgElevated,
          title: const Row(
            children: [
              Icon(Iconsax.image, size: 18, color: ResColors.accent),
              SizedBox(width: 8),
              Text('Failure Screenshot'),
            ],
          ),
          content: SizedBox(
            width: 400,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.memory(
                Uint8List.fromList(bytes),
                fit: BoxFit.contain,
              ),
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
}

// ============================================================================
// Shared tiny widgets
// ============================================================================

class _EditorTextField extends StatefulWidget {
  final IconData icon;
  final String hint;
  final String initialValue;
  final ValueChanged<String> onChanged;

  const _EditorTextField({
    required this.icon,
    required this.hint,
    required this.initialValue,
    required this.onChanged,
  });

  @override
  State<_EditorTextField> createState() => _EditorTextFieldState();
}

class _EditorTextFieldState extends State<_EditorTextField> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void didUpdateWidget(covariant _EditorTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialValue != widget.initialValue &&
        widget.initialValue != _controller.text) {
      _controller.text = widget.initialValue;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      style: const TextStyle(color: ResColors.textPrimary, fontSize: 13),
      decoration: InputDecoration(
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        prefixIcon: Padding(
          padding: const EdgeInsets.only(left: 10, right: 8),
          child: Icon(widget.icon, size: 14, color: ResColors.textMuted),
        ),
        prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
        hintText: widget.hint,
        hintStyle: const TextStyle(color: ResColors.textMuted, fontSize: 13),
        filled: true,
        fillColor: ResColors.bgSurface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
      ),
      onChanged: widget.onChanged,
    );
  }
}

class _MiniTextField extends StatefulWidget {
  final String hint;
  final String initialValue;
  final ValueChanged<String> onChanged;

  const _MiniTextField({
    required this.hint,
    required this.initialValue,
    required this.onChanged,
  });

  @override
  State<_MiniTextField> createState() => _MiniTextFieldState();
}

class _MiniTextFieldState extends State<_MiniTextField> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void didUpdateWidget(covariant _MiniTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialValue != widget.initialValue &&
        widget.initialValue != _controller.text) {
      _controller.text = widget.initialValue;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      style: const TextStyle(color: ResColors.textSecondary, fontSize: 11),
      decoration: InputDecoration(
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        hintText: widget.hint,
        hintStyle: const TextStyle(color: ResColors.textMuted, fontSize: 11),
        filled: true,
        fillColor: ResColors.bgElevated,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: BorderSide.none,
        ),
      ),
      onChanged: widget.onChanged,
    );
  }
}
