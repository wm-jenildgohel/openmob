extension StringX on String {
  String trimOutput() {
    return trim().replaceAll(RegExp(r'\n+$'), '');
  }
}
