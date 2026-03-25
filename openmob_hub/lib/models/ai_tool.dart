class AiTool {
  final String name;
  final String icon;
  final bool detected;
  final bool configured;
  final String? configPath;
  final bool installing;

  const AiTool({
    required this.name,
    required this.icon,
    this.detected = false,
    this.configured = false,
    this.configPath,
    this.installing = false,
  });

  AiTool copyWith({
    bool? detected,
    bool? configured,
    String? configPath,
    bool? installing,
  }) {
    return AiTool(
      name: name,
      icon: icon,
      detected: detected ?? this.detected,
      configured: configured ?? this.configured,
      configPath: configPath ?? this.configPath,
      installing: installing ?? this.installing,
    );
  }
}
