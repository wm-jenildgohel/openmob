class TestStep {
  final String action;
  final Map<String, dynamic> params;
  final Map<String, dynamic>? assertion;
  final String? description;

  const TestStep({
    required this.action,
    this.params = const {},
    this.assertion,
    this.description,
  });

  Map<String, dynamic> toJson() {
    return {
      'action': action,
      'params': params,
      if (assertion != null) 'assertion': assertion,
      if (description != null) 'description': description,
    };
  }

  factory TestStep.fromJson(Map<String, dynamic> json) {
    return TestStep(
      action: json['action'] as String,
      params: (json['params'] as Map<String, dynamic>?) ?? {},
      assertion: json['assertion'] as Map<String, dynamic>?,
      description: json['description'] as String?,
    );
  }
}

class TestScript {
  final String id;
  final String name;
  final String deviceId;
  final List<TestStep> steps;
  final DateTime createdAt;
  final String? flutterTestPath;

  TestScript({
    String? id,
    required this.name,
    required this.deviceId,
    this.steps = const [],
    DateTime? createdAt,
    this.flutterTestPath,
  })  : id = id ?? DateTime.now().millisecondsSinceEpoch.toString(),
        createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'device_id': deviceId,
      'steps': steps.map((s) => s.toJson()).toList(),
      'created_at': createdAt.toIso8601String(),
      if (flutterTestPath != null) 'flutter_test_path': flutterTestPath,
    };
  }

  factory TestScript.fromJson(Map<String, dynamic> json) {
    return TestScript(
      id: json['id'] as String?,
      name: json['name'] as String,
      deviceId: json['device_id'] as String,
      steps: (json['steps'] as List<dynamic>?)
              ?.map((s) => TestStep.fromJson(s as Map<String, dynamic>))
              .toList() ??
          [],
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
      flutterTestPath: json['flutter_test_path'] as String?,
    );
  }
}
