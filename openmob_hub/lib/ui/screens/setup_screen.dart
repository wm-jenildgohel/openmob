import 'package:flutter/material.dart';
import 'package:rxdart_flutter/rxdart_flutter.dart';

import '../../core/res_colors.dart';
import '../../main.dart';
import '../../services/auto_setup_service.dart';

class SetupScreen extends StatelessWidget {
  final VoidCallback onComplete;

  const SetupScreen({super.key, required this.onComplete});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ResColors.bg,
      body: Center(
        child: SizedBox(
          width: 480,
          child: ValueStreamBuilder<SetupStatus>(
            stream: autoSetupService.status$,
            builder: (context, status, child) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Logo
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.asset('assets/openmob.png', width: 72, height: 72),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'OpenMob',
                    style: TextStyle(
                      color: ResColors.textPrimary,
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Setting up your environment',
                    style: TextStyle(color: ResColors.textSecondary, fontSize: 14),
                  ),
                  const SizedBox(height: 40),

                  // Progress bar
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: status.progress,
                      backgroundColor: ResColors.bgSurface,
                      color: status.phase == SetupPhase.failed
                          ? ResColors.error
                          : ResColors.accent,
                      minHeight: 6,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Status message
                  Text(
                    status.message,
                    style: TextStyle(
                      color: status.phase == SetupPhase.failed
                          ? ResColors.error
                          : ResColors.textSecondary,
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),

                  // Phase icon
                  _PhaseIndicator(phase: status.phase),

                  const SizedBox(height: 32),

                  // Setup steps checklist
                  _SetupChecklist(currentPhase: status.phase),

                  const SizedBox(height: 24),

                  // Continue button (shows when complete)
                  if (status.phase == SetupPhase.complete)
                    ElevatedButton(
                      onPressed: status.needsRestart ? null : onComplete,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: ResColors.accent,
                        foregroundColor: ResColors.textOnAccent,
                        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: Text(
                        status.needsRestart ? 'Restart app to continue' : 'Get Started',
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _PhaseIndicator extends StatelessWidget {
  final SetupPhase phase;
  const _PhaseIndicator({required this.phase});

  @override
  Widget build(BuildContext context) {
    if (phase == SetupPhase.complete) {
      return const Icon(Icons.check_circle_rounded, color: ResColors.accent, size: 24);
    }
    if (phase == SetupPhase.failed) {
      return const Icon(Icons.error_rounded, color: ResColors.error, size: 24);
    }
    return const SizedBox(
      width: 20, height: 20,
      child: CircularProgressIndicator(strokeWidth: 2, color: ResColors.accent),
    );
  }
}

class _SetupChecklist extends StatelessWidget {
  final SetupPhase currentPhase;
  const _SetupChecklist({required this.currentPhase});

  @override
  Widget build(BuildContext context) {
    final steps = [
      _Step('Check system', SetupPhase.checking),
      _Step('Android tools (ADB)', SetupPhase.installingAdb),
      _Step('MCP Server', SetupPhase.installingNode),
      _Step('AI tool configuration', SetupPhase.configuringAiTools),
      _Step('Start services', SetupPhase.startingServices),
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ResColors.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ResColors.cardBorder),
      ),
      child: Column(
        children: steps.map((step) {
          final isDone = currentPhase.index > step.phase.index;
          final isCurrent = currentPhase == step.phase ||
              (step.phase == SetupPhase.installingNode &&
                  currentPhase == SetupPhase.buildingMcp);
          final isPending = !isDone && !isCurrent;

          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                if (isDone)
                  const Icon(Icons.check_circle_rounded, size: 18, color: ResColors.accent)
                else if (isCurrent)
                  const SizedBox(
                    width: 18, height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: ResColors.accent),
                  )
                else
                  Icon(Icons.circle_outlined, size: 18,
                      color: isPending ? ResColors.textMuted : ResColors.textSecondary),
                const SizedBox(width: 12),
                Text(
                  step.label,
                  style: TextStyle(
                    color: isDone
                        ? ResColors.accent
                        : isCurrent
                            ? ResColors.textPrimary
                            : ResColors.textMuted,
                    fontSize: 13,
                    fontWeight: isCurrent ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _Step {
  final String label;
  final SetupPhase phase;
  const _Step(this.label, this.phase);
}
