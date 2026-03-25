enum TestStatus { passed, failed, running, error }

class StepResult {
  final int stepIndex;
  final String action;
  final bool success;
  final String? error;
  final int durationMs;
  final String? screenshotBase64;
  final Map<String, dynamic>? assertionResult;

  const StepResult({
    required this.stepIndex,
    required this.action,
    required this.success,
    this.error,
    required this.durationMs,
    this.screenshotBase64,
    this.assertionResult,
  });

  Map<String, dynamic> toJson() {
    return {
      'step_index': stepIndex,
      'action': action,
      'success': success,
      if (error != null) 'error': error,
      'duration_ms': durationMs,
      if (screenshotBase64 != null) 'screenshot_base64': screenshotBase64,
      if (assertionResult != null) 'assertion_result': assertionResult,
    };
  }

  factory StepResult.fromJson(Map<String, dynamic> json) {
    return StepResult(
      stepIndex: json['step_index'] as int,
      action: json['action'] as String,
      success: json['success'] as bool,
      error: json['error'] as String?,
      durationMs: json['duration_ms'] as int,
      screenshotBase64: json['screenshot_base64'] as String?,
      assertionResult: json['assertion_result'] as Map<String, dynamic>?,
    );
  }
}

class TestResult {
  final String scriptId;
  final String scriptName;
  final TestStatus status;
  final List<StepResult> steps;
  final int totalDurationMs;
  final DateTime startedAt;
  final DateTime? completedAt;

  const TestResult({
    required this.scriptId,
    required this.scriptName,
    required this.status,
    this.steps = const [],
    required this.totalDurationMs,
    required this.startedAt,
    this.completedAt,
  });

  int get passedCount => steps.where((s) => s.success).length;

  int get failedCount => steps.where((s) => !s.success).length;

  TestResult copyWith({
    TestStatus? status,
    List<StepResult>? steps,
    int? totalDurationMs,
    DateTime? completedAt,
  }) {
    return TestResult(
      scriptId: scriptId,
      scriptName: scriptName,
      status: status ?? this.status,
      steps: steps ?? this.steps,
      totalDurationMs: totalDurationMs ?? this.totalDurationMs,
      startedAt: startedAt,
      completedAt: completedAt ?? this.completedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'script_id': scriptId,
      'script_name': scriptName,
      'status': status.name,
      'steps': steps.map((s) => s.toJson()).toList(),
      'total_duration_ms': totalDurationMs,
      'passed_count': passedCount,
      'failed_count': failedCount,
      'started_at': startedAt.toIso8601String(),
      if (completedAt != null) 'completed_at': completedAt!.toIso8601String(),
    };
  }

  factory TestResult.fromJson(Map<String, dynamic> json) {
    return TestResult(
      scriptId: json['script_id'] as String,
      scriptName: json['script_name'] as String,
      status: TestStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => TestStatus.error,
      ),
      steps: (json['steps'] as List<dynamic>?)
              ?.map((s) => StepResult.fromJson(s as Map<String, dynamic>))
              .toList() ??
          [],
      totalDurationMs: json['total_duration_ms'] as int,
      startedAt: DateTime.parse(json['started_at'] as String),
      completedAt: json['completed_at'] != null
          ? DateTime.parse(json['completed_at'] as String)
          : null,
    );
  }
}
