---
phase: 05-qa-testing
verified: 2026-03-25T06:00:00Z
status: gaps_found
score: 8/9 must-haves verified
re_verification: false
gaps:
  - truth: "AI agent can call run_test MCP tool with test steps and receive structured pass/fail results"
    status: partial
    reason: "run_test tool POSTs deviceId (camelCase) but Hub TestScript.fromJson reads device_id (snake_case). This causes a runtime null cast error when an AI agent calls run_test, because json['device_id'] returns null and is cast to String."
    artifacts:
      - path: "openmob_mcp/src/mcp/tools/testing/run-test.ts"
        issue: "Line 56: posts `deviceId: device_id` but Hub expects snake_case key `device_id`"
      - path: "openmob_hub/lib/models/test_script.dart"
        issue: "Line 66: fromJson reads `json['device_id'] as String` — will throw when MCP sends camelCase key"
    missing:
      - "Fix run-test.ts to send `device_id: device_id` (snake_case) matching the Hub model's fromJson key"
human_verification:
  - test: "Navigate to Testing tab, create a script, run it with a connected device, observe results"
    expected: "Results appear in the Results column with per-step pass/fail icons, timing, and failure screenshots where applicable"
    why_human: "Visual layout, reactive stream binding, and UI interactivity cannot be verified without running the Flutter desktop app"
  - test: "Call run_test via an MCP client (e.g. Claude Desktop) after fixing the deviceId field name gap"
    expected: "Tool returns structured TestResult JSON with steps array, status, passedCount, failedCount, and totalDurationMs"
    why_human: "Requires a live MCP client connected to a running Hub with a connected device"
---

# Phase 05: QA Testing Verification Report

**Phase Goal:** Users can define, execute, and review test scenarios on devices using AI agents and the Hub
**Verified:** 2026-03-25T06:00:00Z
**Status:** gaps_found
**Re-verification:** No — initial verification

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | Hub can store and retrieve test scripts via HTTP API | VERIFIED | `testRoutes` in `test_routes.dart` implements GET / and POST / with `runner.scripts$.value` and `runner.addScript`. Mounted at `/api/v1/tests/` in `api_server.dart`. |
| 2 | Hub can execute a test script and return structured results | VERIFIED | `TestRunnerService.runScript` executes step-by-step via `_executeAction` switch, captures failure screenshots, updates `_currentRun$`, returns `TestResult` with `passedCount`, `failedCount`, `totalDurationMs`. |
| 3 | Hub can run flutter test/drive as child process and capture output | VERIFIED | `_runFlutterTest` in `test_runner_service.dart` calls `Process.start('flutter', args)`, streams stdout/stderr via LineSplitter to LogService, parses exit code. |
| 4 | Test results include pass/fail status, failure screenshots, and execution timing | VERIFIED | `StepResult` captures `screenshotBase64` on failure (lines 127-137 in service), `durationMs` per step, `TestResult.status` is enum `TestStatus`. |
| 5 | AI agent can call run_test MCP tool with test steps and receive structured pass/fail results | FAILED | Tool exists and is registered, but posts `deviceId` (camelCase) while Hub `TestScript.fromJson` reads `device_id` (snake_case) — causes a runtime cast error. |
| 6 | run_test tool accepts device_id and an array of test steps | VERIFIED | `run-test.ts` uses `deviceIdSchema`, `z.array(z.object({action, params, assertion, description}))` as inputSchema. |
| 7 | User can navigate to a Testing tab in the Hub sidebar | VERIFIED | `sidebar.dart` has 5 `NavigationRailDestination` entries; index 3 is `Testing` with `Icons.science`. |
| 8 | User can define test scripts with a JSON editor and save them | VERIFIED | `_showNewScriptDialog` in `testing_screen.dart` provides name + device + JSON steps textarea; Save button calls `testRunnerService.addScript`. |
| 9 | Test results show pass/fail count, per-step details, failure screenshots, and timing | VERIFIED | `_buildResultsColumn` uses `ValueStreamBuilder` on `results$`; summary chips show Passed/Failed counts; `_buildResultTile` shows `ExpansionTile` with step rows including `durationMs`, error text, and screenshot `IconButton` that opens `Image.memory` dialog. |

**Score:** 8/9 truths verified

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `openmob_hub/lib/models/test_script.dart` | TestScript and TestStep with JSON serialization | VERIFIED | 78 lines. `class TestScript` and `class TestStep` with full `toJson`/`fromJson`. UUID via epoch millis. |
| `openmob_hub/lib/models/test_result.dart` | TestResult and StepResult with pass/fail/screenshot/timing | VERIFIED | 121 lines. `class TestResult`, `class StepResult`, `enum TestStatus`. `passedCount`/`failedCount` getters. |
| `openmob_hub/lib/services/test_runner_service.dart` | Test execution engine and flutter test runner | VERIFIED | 495 lines. `class TestRunnerService` with BehaviorSubjects, `runScript`, `_runSteps`, `_executeAction` (10 action types), `_runFlutterTest`, assertions. |
| `openmob_hub/lib/server/routes/test_routes.dart` | HTTP API endpoints for test CRUD and execution | VERIFIED | 109 lines. `Router testRoutes(TestRunnerService runner)` with 7 endpoints. |
| `openmob_mcp/src/mcp/tools/testing/run-test.ts` | MCP run_test tool registration | VERIFIED (partial wiring) | `registerRunTest` exists and follows established pattern; field name mismatch at line 56 breaks the Hub call. |
| `openmob_mcp/src/mcp/tools/testing/index.ts` | Testing tools barrel export | VERIFIED | 7 lines. `registerTestingTools` calls `registerRunTest`. |
| `openmob_mcp/src/types/test-result.ts` | TypeScript types for test results | VERIFIED | `TestStep`, `StepResult`, `TestResult` interfaces present. |
| `openmob_hub/lib/ui/screens/testing_screen.dart` | Testing UI with script editor, runner, and results dashboard | VERIFIED | 739 lines. `class TestingScreen extends StatelessWidget`. All state via `ValueStreamBuilder` on `testRunnerService` streams. No `setState`. |
| `openmob_hub/lib/ui/widgets/sidebar.dart` | Updated sidebar with Testing nav destination | VERIFIED | 5 `NavigationRailDestination` entries; `Testing` at index 3 with `Icons.science`. |
| `openmob_hub/lib/ui/screens/dashboard_shell.dart` | Updated shell routing to include TestingScreen | VERIFIED | `import 'testing_screen.dart'` present; `case 3 => const TestingScreen()` in `_buildContent`. |

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| `test_runner_service.dart` | `ActionService, ScreenshotService, DeviceManager` | Constructor DI | WIRED | Constructor: `TestRunnerService(this._actionService, this._screenshotService, this._deviceManager, this._logService, {UiTreeService? uiTree})` |
| `test_routes.dart` | `TestRunnerService` | DI parameter | WIRED | `Router testRoutes(TestRunnerService runner)` — pure function pattern |
| `api_server.dart` | `test_routes.dart` | router mount | WIRED | `router.mount('${ApiConstants.apiPrefix}/tests/', testRouter.call)` at line 42 |
| `main.dart` | `TestRunnerService` | global late final | WIRED | `testRunnerService = TestRunnerService(actionService, screenshotService, deviceManager, logService, uiTree: uiTreeService)` at lines 86-92 |
| `api_server.dart` | `TestRunnerService` | constructor param | WIRED | `ApiServer(..., TestRunnerService testRunner)` — passed through to `testRoutes(testRunner)` |
| `testing_screen.dart` | `TestRunnerService` | global `testRunnerService` | WIRED | Used at 9 locations: `scripts$`, `results$`, `currentRun$`, `addScript`, `removeScript`, `runScript` |
| `dashboard_shell.dart` | `testing_screen.dart` | `_buildContent` switch | WIRED | `case 3 => const TestingScreen()` |
| `register-tools.ts` | `testing/index.ts` | `registerTestingTools` import | WIRED | Import at line 5, called at line 10 of `registerAllTools` |
| `run-test.ts` | Hub API `/api/v1/tests/` | `hub.post` | PARTIAL | Calls correct paths but sends `deviceId` (camelCase) — Hub `fromJson` reads `device_id` (snake_case). Runtime null cast error. |
| `types/index.ts` | `test-result.ts` | re-export | WIRED | `export type { TestStep, StepResult, TestResult } from "./test-result.js"` |

### Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
|----------|---------------|--------|--------------------|--------|
| `testing_screen.dart` | `scripts` | `testRunnerService.scripts$` BehaviorSubject seeded `[]` | Yes — scripts added via `addScript` from UI dialog | FLOWING |
| `testing_screen.dart` | `results` | `testRunnerService.results$` BehaviorSubject | Yes — populated by `_runSteps`/`_runFlutterTest` on each `runScript` call | FLOWING |
| `testing_screen.dart` | `currentRun` | `testRunnerService.currentRun$` BehaviorSubject | Yes — set to running `TestResult` during execution, cleared on completion | FLOWING |
| `run-test.ts` (MCP) | Hub response `TestResult` | `hub.post<TestResult>('/tests/{id}/run', {})` | Yes — Hub returns `result.toJson()` from real execution | FLOWING (field name bug blocks it) |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|----------|---------|--------|--------|
| Dart analyzer clean on all phase files | `dart analyze` on 9 modified files | "No issues found!" | PASS |
| TypeScript compiles cleanly | `npx tsc --noEmit` in `openmob_mcp` | No output (success) | PASS |
| Commit hashes from summaries exist | `git log` check: 8d5b1a8, 85fab0d, b22bd94, 5ad1eb7, 2d60e38 | All 5 found in git history | PASS |
| `registerTestingTools` called in `registerAllTools` | grep in `register-tools.ts` | Found at line 10 | PASS |
| `TestResult` types exported from types/index.ts | grep in `types/index.ts` | Found at line 5 | PASS |
| run_test Hub field name mismatch | grep `deviceId` in run-test.ts vs `device_id` in fromJson | Mismatch confirmed: run-test.ts line 56 sends `deviceId`, Hub model reads `device_id` | FAIL |

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|------------|-------------|--------|----------|
| QA-01 | 05-01, 05-02 | AI agent can use MCP tools to execute test scenarios on device and report pass/fail results | PARTIAL | MCP tool registered and wired; `run_test` tool broken at runtime due to `deviceId` vs `device_id` field name mismatch when POSTing to Hub |
| QA-02 | 05-01, 05-03 | User can define test scripts (sequence of actions + assertions) and run them from the hub | SATISFIED | `TestingScreen` dialog allows JSON step authoring; `testRunnerService.addScript` + `runScript` wired; `TestRunnerService._runSteps` executes all 10 action types |
| QA-03 | 05-01, 05-03 | User can run Flutter tests (flutter test / flutter drive) from the hub and view results | SATISFIED | `_runFlutterTest` spawns `flutter test`/`flutter drive` child process; `_showFlutterTestDialog` in `TestingScreen` provides path + device input and runs immediately |
| QA-04 | 05-01, 05-03 | Test results displayed in the hub with pass/fail status, screenshots on failure, and execution time | SATISFIED | `_buildResultTile` uses `ExpansionTile` with status icon, `passedCount/steps.length steps passed`, `totalDurationMs`, per-step rows with pass/fail icon, error text, screenshot button |
| MCP-13 | 05-02 | Tool: run_test — execute a test scenario and return results | PARTIAL | Tool registered and callable; broken at runtime by `deviceId`/`device_id` field name mismatch |

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| `openmob_mcp/src/mcp/tools/testing/run-test.ts` | 56 | `deviceId: device_id` posted to Hub, which expects `device_id` in JSON body | Blocker | AI agent `run_test` calls fail at runtime with a null cast exception in `TestScript.fromJson` |

### Human Verification Required

**1. Hub Testing Tab — End-to-End Workflow**

**Test:** Launch the Hub desktop app, navigate to the Testing tab via sidebar, click "New Script", fill in name and JSON steps, click Save, then click the play button on the saved script.
**Expected:** Script appears in list; clicking play triggers execution; LinearProgressIndicator shows during run; results appear in the right column with pass/fail icons, step count, timing, and failure screenshot button for any failed step.
**Why human:** Visual layout, ReactiveX stream-to-widget binding, and Flutter widget interactivity require the running desktop app.

**2. MCP run_test End-to-End (after field name fix)**

**Test:** After fixing the `deviceId` vs `device_id` mismatch, call `run_test` from a connected MCP client (e.g. Claude Code with `mcp.json` pointing to `openmob_mcp`) with a connected device and a simple tap step.
**Expected:** Returns JSON `TestResult` with `status: "passed"` or `"failed"`, `steps` array with `durationMs`, `passedCount`, and `failedCount`.
**Why human:** Requires a running Hub, a connected Android or iOS device, and an MCP client session.

### Gaps Summary

One gap blocks QA-01 and MCP-13 full satisfaction:

**`deviceId` vs `device_id` field name mismatch in run-test.ts**

When an AI agent calls `run_test`, the tool constructs: `{ name, deviceId: device_id, steps }` and POSTs it to `Hub POST /api/v1/tests/`. The Hub route handler calls `TestScript.fromJson(body)`, which reads `json['device_id'] as String` (snake_case). Since the body contains `deviceId` (camelCase), `json['device_id']` is null. The `as String` cast throws a `TypeError` at runtime, and the Hub returns a 500 error. The fix is a one-line change in `run-test.ts`: change `deviceId: device_id` to `device_id: device_id`.

All other Hub-side functionality (QA-02, QA-03, QA-04) is fully implemented and wired. All dart analysis and TypeScript compilation is clean.

---

_Verified: 2026-03-25T06:00:00Z_
_Verifier: Claude (gsd-verifier)_
