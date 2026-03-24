import 'package:xml/xml.dart';
import '../models/ui_node.dart';
import 'adb_service.dart';

class UiTreeService {
  final AdbService _adb;

  UiTreeService(this._adb);

  /// Dump, parse, index, and optionally filter the Android UI tree.
  ///
  /// Uses uiautomator dump /dev/tty via exec-out for direct stdout XML.
  /// Assigns sequential indices to ALL nodes before filtering, so indices
  /// remain stable regardless of filter.
  Future<List<UiNode>> getUiTree(
    String serial, {
    UiTreeFilter? filter,
  }) async {
    try {
      final result = await _adb.run(
        serial,
        ['exec-out', 'uiautomator', 'dump', '/dev/tty'],
      );

      var xml = (result.stdout as String).trim();

      // Strip trailing "UI hierchary dumped to: /dev/tty" message
      xml = xml.replaceAll('UI hierchary dumped to: /dev/tty', '');
      xml = xml.replaceAll('UI hierachy dumped to: /dev/tty', '');
      xml = xml.trim();

      if (xml.isEmpty) return [];

      final doc = XmlDocument.parse(xml);
      final allNodes = <UiNode>[];
      int index = 0;

      for (final element in doc.descendants.whereType<XmlElement>()) {
        if (element.name.local != 'node') continue;

        final text = element.getAttribute('text') ?? '';
        final className = element.getAttribute('class') ?? '';
        final resourceId = element.getAttribute('resource-id') ?? '';
        final contentDesc = element.getAttribute('content-desc') ?? '';
        final boundsStr = element.getAttribute('bounds') ?? '';
        final visibleStr = element.getAttribute('visible-to-user') ?? 'true';

        final bounds = _parseBounds(boundsStr);
        final visible = visibleStr.toLowerCase() == 'true';

        final node = UiNode(
          index: index,
          text: text,
          className: className,
          resourceId: resourceId,
          contentDesc: contentDesc,
          bounds: bounds,
          visible: visible,
        );

        allNodes.add(node);
        index++;
      }

      // Apply filter after index assignment so indices stay stable
      if (filter != null) {
        return allNodes.where((node) => filter.matches(node)).toList();
      }

      return allNodes;
    } catch (_) {
      // uiautomator dump can fail on animated screens; return empty gracefully
      return [];
    }
  }

  /// Parse bounds string like "[0,0][1080,1920]" into a Rect.
  Rect _parseBounds(String boundsStr) {
    final match = RegExp(r'\[(\d+),(\d+)\]\[(\d+),(\d+)\]').firstMatch(boundsStr);
    if (match == null) {
      return const Rect(left: 0, top: 0, right: 0, bottom: 0);
    }
    return Rect(
      left: int.parse(match.group(1)!),
      top: int.parse(match.group(2)!),
      right: int.parse(match.group(3)!),
      bottom: int.parse(match.group(4)!),
    );
  }
}
