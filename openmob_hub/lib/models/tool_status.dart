class ToolStatus {
  final String name;
  final bool available;
  final String? version;
  final String? path;
  final String installHint;
  final bool canAutoInstall;
  final bool installing;
  final double installProgress;

  const ToolStatus({
    required this.name,
    required this.available,
    required this.installHint,
    this.version,
    this.path,
    this.canAutoInstall = false,
    this.installing = false,
    this.installProgress = 0.0,
  });

  ToolStatus copyWith({
    bool? available,
    String? version,
    String? path,
    bool? installing,
    double? installProgress,
  }) {
    return ToolStatus(
      name: name,
      available: available ?? this.available,
      version: version ?? this.version,
      path: path ?? this.path,
      installHint: installHint,
      canAutoInstall: canAutoInstall,
      installing: installing ?? this.installing,
      installProgress: installProgress ?? this.installProgress,
    );
  }
}
