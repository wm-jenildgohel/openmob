class ToolStatus {
  final String name;
  final bool available;
  final String? version;
  final String? path;
  final String installHint;

  const ToolStatus({
    required this.name,
    required this.available,
    required this.installHint,
    this.version,
    this.path,
  });
}
