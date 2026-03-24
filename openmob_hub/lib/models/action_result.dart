class ActionResult {
  final bool success;
  final String? error;
  final Map<String, dynamic>? data;

  const ActionResult({
    required this.success,
    this.error,
    this.data,
  });

  factory ActionResult.ok({Map<String, dynamic>? data}) {
    return ActionResult(success: true, data: data);
  }

  factory ActionResult.fail(String error) {
    return ActionResult(success: false, error: error);
  }

  Map<String, dynamic> toJson() {
    return {
      'success': success,
      if (error != null) 'error': error,
      if (data != null) 'data': data,
    };
  }

  factory ActionResult.fromJson(Map<String, dynamic> json) {
    return ActionResult(
      success: json['success'] as bool,
      error: json['error'] as String?,
      data: json['data'] as Map<String, dynamic>?,
    );
  }
}
