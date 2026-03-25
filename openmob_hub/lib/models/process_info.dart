enum ProcessStatus { stopped, starting, running, error }

class ProcessInfo {
  final String name;
  final ProcessStatus status;
  final int? pid;
  final DateTime? startedAt;
  final String? errorMessage;

  const ProcessInfo({
    required this.name,
    this.status = ProcessStatus.stopped,
    this.pid,
    this.startedAt,
    this.errorMessage,
  });

  ProcessInfo copyWith({
    String? name,
    ProcessStatus? status,
    int? pid,
    DateTime? startedAt,
    String? errorMessage,
  }) {
    return ProcessInfo(
      name: name ?? this.name,
      status: status ?? this.status,
      pid: pid ?? this.pid,
      startedAt: startedAt ?? this.startedAt,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}
