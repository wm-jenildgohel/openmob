class Rect {
  final int left;
  final int top;
  final int right;
  final int bottom;

  const Rect({
    required this.left,
    required this.top,
    required this.right,
    required this.bottom,
  });

  int get centerX => (left + right) ~/ 2;
  int get centerY => (top + bottom) ~/ 2;

  Map<String, dynamic> toJson() {
    return {
      'left': left,
      'top': top,
      'right': right,
      'bottom': bottom,
      'centerX': centerX,
      'centerY': centerY,
    };
  }

  factory Rect.fromJson(Map<String, dynamic> json) {
    return Rect(
      left: json['left'] as int,
      top: json['top'] as int,
      right: json['right'] as int,
      bottom: json['bottom'] as int,
    );
  }
}

class UiNode {
  final int index;
  final String text;
  final String className;
  final String resourceId;
  final String contentDesc;
  final Rect bounds;
  final bool visible;

  const UiNode({
    required this.index,
    this.text = '',
    this.className = '',
    this.resourceId = '',
    this.contentDesc = '',
    required this.bounds,
    this.visible = true,
  });

  Map<String, dynamic> toJson() {
    return {
      'index': index,
      'text': text,
      'className': className,
      'resourceId': resourceId,
      'contentDesc': contentDesc,
      'bounds': bounds.toJson(),
      'visible': visible,
    };
  }

  factory UiNode.fromJson(Map<String, dynamic> json) {
    return UiNode(
      index: json['index'] as int,
      text: json['text'] as String? ?? '',
      className: json['className'] as String? ?? '',
      resourceId: json['resourceId'] as String? ?? '',
      contentDesc: json['contentDesc'] as String? ?? '',
      bounds: Rect.fromJson(json['bounds'] as Map<String, dynamic>),
      visible: json['visible'] as bool? ?? true,
    );
  }
}

class UiTreeFilter {
  final RegExp? textPattern;
  final bool? visibleOnly;

  const UiTreeFilter({
    this.textPattern,
    this.visibleOnly,
  });

  bool matches(UiNode node) {
    if (visibleOnly == true && !node.visible) return false;
    if (textPattern != null && !textPattern!.hasMatch(node.text)) return false;
    return true;
  }
}
