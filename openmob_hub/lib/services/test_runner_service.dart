import 'dart:convert';
import 'dart:io';

import 'package:rxdart/rxdart.dart';

import '../models/test_result.dart';
import '../models/test_script.dart';
import 'action_service.dart';
import 'device_manager.dart';
import 'log_service.dart';
import 'screenshot_service.dart';
import 'ui_tree_service.dart';

class TestRunnerService {
  final ActionService _actionService;
  final ScreenshotService _screenshotService;
  final DeviceManager _deviceManager;
  final LogService _logService;
  final UiTreeService? _uiTree;

  TestRunnerService(
    this._actionService,
    this._screenshotService,
    this._deviceManager,
    this._logService, {
    UiTreeService? uiTree,
  }) : _uiTree = uiTree;

  final _scripts = BehaviorSubject<List<TestScript>>.seeded([]);
  final _results = BehaviorSubject<List<TestResult>>.seeded([]);
  final _currentRun = BehaviorSubject<TestResult?>.seeded(null);

  ValueStream<List<TestScript>> get scripts$ => _scripts.stream;
  ValueStream<List<TestResult>> get results$ => _results.stream;
  ValueStream<TestResult?> get currentRun$ => _currentRun.stream;

  void addScript(TestScript script) {
    _scripts.add([..._scripts.value, script]);
  }

  void removeScript(String id) {
    _scripts.add(_scripts.value.where((s) => s.id != id).toList());
  }

  TestScript? getScript(String id) {
    try {
      return _scripts.value.firstWhere((s) => s.id == id);
    } catch (_) {
      return null;
    }
  }

  Future<TestResult> runScript(String scriptId) async {
    final script = getScript(scriptId);
    if (script == null) {
      throw Exception('Test script not found: $scriptId');
    }

    final device = _deviceManager.getDevice(script.deviceId);
    if (device == null && script.flutterTestPath == null) {
      throw Exception('Device not found: ${script.deviceId}');
    }

    _logService.addLine('test', 'Starting test: ${script.name}');

    if (script.flutterTestPath != null) {
      return _runFlutterTest(script);
    }

    return _runSteps(script);
  }

  Future<TestResult> _runSteps(TestScript script) async {
    final sw = Stopwatch()..start();
    final startedAt = DateTime.now();
    final stepResults = <StepResult>[];

    var result = TestResult(
      scriptId: script.id,
      scriptName: script.name,
      status: TestStatus.running,
      totalDurationMs: 0,
      startedAt: startedAt,
    );
    _currentRun.add(result);

    var hasFailed = false;

    for (var i = 0; i < script.steps.length; i++) {
      final step = script.steps[i];
      final stepSw = Stopwatch()..start();
      String? screenshotB64;
      Map<String, dynamic>? assertResult;
      bool success = true;
      String? stepError;

      _logService.addLine(
        'test',
        'Step ${i + 1}/${script.steps.length}: ${step.description ?? step.action}',
      );

      try {
        final actionResult = await _executeAction(script.deviceId, step);
        if (!actionResult.success) {
          success = false;
          stepError = actionResult.error;
        }
      } catch (e) {
        success = false;
        stepError = e.toString();
      }

      // Run assertion if present and action succeeded
      if (success && step.assertion != null) {
        try {
          assertResult = await _runAssertion(script.deviceId, step.assertion!);
          if (assertResult['passed'] != true) {
            success = false;
            stepError = assertResult['error'] as String? ?? 'Assertion failed';
          }
        } catch (e) {
          success = false;
          stepError = 'Assertion error: $e';
        }
      }

      // Capture screenshot on failure
      if (!success) {
        hasFailed = true;
        try {
          final screenshot =
              await _screenshotService.captureScreenshot(script.deviceId);
          screenshotB64 = screenshot.base64;
        } catch (_) {
          // Screenshot capture failed -- continue without it
        }
      }

      stepSw.stop();
      stepResults.add(StepResult(
        stepIndex: i,
        action: step.action,
        success: success,
        error: stepError,
        durationMs: stepSw.elapsedMilliseconds,
        screenshotBase64: screenshotB64,
        assertionResult: assertResult,
      ));

      // Update current run
      result = result.copyWith(
        steps: List.of(stepResults),
        totalDurationMs: sw.elapsedMilliseconds,
      );
      _currentRun.add(result);

      if (!success) {
        _logService.addLine(
          'test',
          'Step ${i + 1} FAILED: $stepError',
          level: LogLevel.error,
        );
        break;
      }

      _logService.addLine('test', 'Step ${i + 1} PASSED');
    }

    sw.stop();
    final finalResult = result.copyWith(
      status: hasFailed ? TestStatus.failed : TestStatus.passed,
      totalDurationMs: sw.elapsedMilliseconds,
      completedAt: DateTime.now(),
    );

    _results.add([..._results.value, finalResult]);
    _currentRun.add(null);

    _logService.addLine(
      'test',
      'Test "${script.name}" ${finalResult.status.name}: '
      '${finalResult.passedCount}/${finalResult.steps.length} steps passed '
      'in ${finalResult.totalDurationMs}ms',
    );

    return finalResult;
  }

  Future<({bool success, String? error})> _executeAction(
    String deviceId,
    TestStep step,
  ) async {
    final p = step.params;

    switch (step.action) {
      case 'tap':
        if (p.containsKey('index')) {
          final r = await _actionService.tapElement(
            deviceId,
            (p['index'] as num).toInt(),
          );
          return (success: r.success, error: r.error);
        }
        final r = await _actionService.tap(
          deviceId,
          (p['x'] as num).toInt(),
          (p['y'] as num).toInt(),
        );
        return (success: r.success, error: r.error);

      case 'swipe':
        final r = await _actionService.swipe(
          deviceId,
          (p['x1'] as num).toInt(),
          (p['y1'] as num).toInt(),
          (p['x2'] as num).toInt(),
          (p['y2'] as num).toInt(),
          durationMs: (p['duration'] as num?)?.toInt() ?? 300,
        );
        return (success: r.success, error: r.error);

      case 'type_text':
        final r = await _actionService.typeText(
          deviceId,
          p['text'] as String,
        );
        return (success: r.success, error: r.error);

      case 'press_key':
        final r = await _actionService.pressKey(
          deviceId,
          (p['keyCode'] as num).toInt(),
        );
        return (success: r.success, error: r.error);

      case 'launch_app':
        final r = await _actionService.launchApp(
          deviceId,
          p['package'] as String,
        );
        return (success: r.success, error: r.error);

      case 'terminate_app':
        final r = await _actionService.terminateApp(
          deviceId,
          p['package'] as String,
        );
        return (success: r.success, error: r.error);

      case 'open_url':
        final r = await _actionService.openUrl(
          deviceId,
          p['url'] as String,
        );
        return (success: r.success, error: r.error);

      case 'go_home':
        final r = await _actionService.goHome(deviceId);
        return (success: r.success, error: r.error);

      case 'gesture':
        final r = await _actionService.gesture(
          deviceId,
          p['type'] as String,
          Map<String, dynamic>.from(p)..remove('type'),
        );
        return (success: r.success, error: r.error);

      case 'wait':
        final ms = (p['duration'] as num?)?.toInt() ?? 1000;
        await Future.delayed(Duration(milliseconds: ms));
        return (success: true, error: null);

      default:
        return (success: false, error: 'Unknown action: ${step.action}');
    }
  }

  Future<Map<String, dynamic>> _runAssertion(
    String deviceId,
    Map<String, dynamic> assertion,
  ) async {
    final type = assertion['type'] as String?;

    switch (type) {
      case 'element_exists':
        if (_uiTree == null) {
          return {'passed': false, 'error': 'UiTreeService not available'};
        }
        final index = assertion['index'] as int?;
        if (index == null) {
          return {'passed': false, 'error': 'assertion.index required for element_exists'};
        }
        final nodes = await _uiTree.getUiTree(deviceId);
        final found = nodes.any((n) => n.index == index);
        return {
          'passed': found,
          'type': 'element_exists',
          'index': index,
          if (!found) 'error': 'Element at index $index not found',
        };

      case 'element_text':
        if (_uiTree == null) {
          return {'passed': false, 'error': 'UiTreeService not available'};
        }
        final index = assertion['index'] as int?;
        final expected = assertion['text'] as String?;
        if (index == null || expected == null) {
          return {
            'passed': false,
            'error': 'assertion.index and assertion.text required for element_text',
          };
        }
        final nodes = await _uiTree.getUiTree(deviceId);
        final matches = nodes.where((n) => n.index == index);
        if (matches.isEmpty) {
          return {
            'passed': false,
            'type': 'element_text',
            'error': 'Element at index $index not found',
          };
        }
        final actual = matches.first.text;
        final passed = actual == expected;
        return {
          'passed': passed,
          'type': 'element_text',
          'expected': expected,
          'actual': actual,
          if (!passed) 'error': 'Expected "$expected" but got "$actual"',
        };

      case 'screenshot_match':
        // Capture screenshot for comparison -- store it in result
        try {
          final screenshot =
              await _screenshotService.captureScreenshot(deviceId);
          return {
            'passed': true,
            'type': 'screenshot_match',
            'screenshot_base64': screenshot.base64,
            'note': 'Screenshot captured for visual comparison',
          };
        } catch (e) {
          return {
            'passed': false,
            'type': 'screenshot_match',
            'error': 'Screenshot capture failed: $e',
          };
        }

      case 'none':
      case null:
        return {'passed': true, 'type': 'none'};

      default:
        return {'passed': false, 'error': 'Unknown assertion type: $type'};
    }
  }

  Future<TestResult> _runFlutterTest(TestScript script) async {
    final sw = Stopwatch()..start();
    final startedAt = DateTime.now();

    var result = TestResult(
      scriptId: script.id,
      scriptName: script.name,
      status: TestStatus.running,
      totalDurationMs: 0,
      startedAt: startedAt,
    );
    _currentRun.add(result);

    _logService.addLine(
      'test',
      'Running flutter test: ${script.flutterTestPath}',
    );

    // Resolve project root by walking up to find pubspec.yaml
    final projectRoot = _resolveProjectRoot();
    if (projectRoot == null) {
      sw.stop();
      final failResult = result.copyWith(
        status: TestStatus.error,
        steps: [
          StepResult(
            stepIndex: 0,
            action: 'flutter_test',
            success: false,
            error: 'Could not find project root (no pubspec.yaml found)',
            durationMs: sw.elapsedMilliseconds,
          ),
        ],
        totalDurationMs: sw.elapsedMilliseconds,
        completedAt: DateTime.now(),
      );
      _results.add([..._results.value, failResult]);
      _currentRun.add(null);
      return failResult;
    }

    final testPath = script.flutterTestPath!;
    final isIntegration =
        testPath.contains('drive') || testPath.contains('integration');

    final args = <String>[];
    if (isIntegration) {
      args.addAll(['drive', '--target', testPath]);
      if (script.deviceId.isNotEmpty) {
        args.addAll(['-d', script.deviceId]);
      }
    } else {
      args.addAll(['test', testPath]);
    }

    final outputBuffer = StringBuffer();
    int exitCode = -1;

    try {
      final process = await Process.start(
        'flutter',
        args,
        workingDirectory: projectRoot,
      );

      process.stdout
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen((line) {
        outputBuffer.writeln(line);
        _logService.addLine('flutter_test', line);
      });

      process.stderr
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen((line) {
        outputBuffer.writeln(line);
        _logService.addLine('flutter_test', line, level: LogLevel.error);
      });

      exitCode = await process.exitCode;
    } catch (e) {
      outputBuffer.writeln('Process error: $e');
    }

    sw.stop();
    final success = exitCode == 0;
    final stepResult = StepResult(
      stepIndex: 0,
      action: 'flutter_test',
      success: success,
      error: success ? null : 'Flutter test exited with code $exitCode',
      durationMs: sw.elapsedMilliseconds,
    );

    final finalResult = result.copyWith(
      status: success ? TestStatus.passed : TestStatus.failed,
      steps: [stepResult],
      totalDurationMs: sw.elapsedMilliseconds,
      completedAt: DateTime.now(),
    );

    _results.add([..._results.value, finalResult]);
    _currentRun.add(null);

    _logService.addLine(
      'test',
      'Flutter test "${script.name}" ${finalResult.status.name} '
      'in ${finalResult.totalDurationMs}ms',
    );

    return finalResult;
  }

  String? _resolveProjectRoot() {
    var dir = Directory.current;
    for (var i = 0; i < 5; i++) {
      if (File('${dir.path}${Platform.pathSeparator}pubspec.yaml').existsSync()) {
        return dir.path;
      }
      final parent = dir.parent;
      if (parent.path == dir.path) break;
      dir = parent;
    }
    return null;
  }

  void dispose() {
    _scripts.close();
    _results.close();
    _currentRun.close();
  }
}
