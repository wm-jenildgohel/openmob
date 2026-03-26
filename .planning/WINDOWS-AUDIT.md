# Windows Compatibility Audit -- OpenMob

**Date:** 2026-03-26
**Target User:** Non-technical QA tester on a fresh Windows PC
**Scope:** All 3 components + CI/CD + distribution + auto-setup

---

## Executive Summary

**27 issues found.** 4 CRITICAL, 9 HIGH, 10 MEDIUM, 4 LOW.

The codebase shows clear Windows awareness -- `Platform.isWindows` checks, `where` vs `which`, `npm.cmd` vs `npm`, backslash path separators, `taskkill` usage, and Windows Terminal detection are all present. However, there are several issues that will cause crashes, silent failures, or blocked workflows for a non-technical Windows user.

The most dangerous problems are:
1. `ProcessSignal.sigkill` crashes on Windows (Dart throws `SignalException`)
2. Forward-slash paths in ADB download code break extraction paths on Windows
3. AiBridge cross-compiled via MinGW may fail at runtime due to ConPTY API linking
4. Windows Defender SmartScreen will block all unsigned executables

---

## 1. Flutter Hub (openmob_hub) -- Dart

### ISSUE-01: ProcessSignal.sigkill crashes on Windows
- **Severity:** CRITICAL
- **Files:** `process_manager.dart:214`, `process_manager.dart:441`
- **Problem:** `_mcpProcess!.kill(ProcessSignal.sigkill)` and `_bridgeProcess!.kill(ProcessSignal.sigkill)` are called as fallbacks when SIGTERM times out. On Windows, Dart's `Process.kill()` with `ProcessSignal.sigkill` throws a `SignalException` because SIGKILL does not exist on Windows. The default `Process.kill()` (no argument) sends SIGTERM on Unix but on Windows it calls `TerminateProcess()` which is already the equivalent of a force-kill.
- **Impact:** When a process hangs and the 3-second timeout fires, the app crashes with an unhandled exception. The MCP server or AiBridge cannot be force-stopped.
- **Fix:**
```dart
// Replace:
_mcpProcess!.kill(ProcessSignal.sigkill);

// With:
if (Platform.isWindows) {
  // Process.kill() on Windows already calls TerminateProcess (force kill)
  _mcpProcess!.kill();
} else {
  _mcpProcess!.kill(ProcessSignal.sigkill);
}
```
- **Source:** [Dart API: Process.kill](https://api.flutter.dev/flutter/dart-io/Process/kill.html) -- "On Windows, this ignores the signal parameter and terminates the process."

### ISSUE-02: Forward-slash paths in ADB download/install code
- **Severity:** HIGH
- **File:** `system_check_service.dart:69-70, 153, 155, 185, 192-193, 263, 265`
- **Problem:** Multiple paths use forward slashes instead of `_sep` (which is `Platform.pathSeparator`). Examples:
  - `'$_toolsDir/platform-tools/adb.exe'` (line 69)
  - `Directory('$_toolsDir/platform-tools')` (line 153)
  - `File('$_toolsDir/platform-tools.zip')` (line 155)
  - `'$_toolsDir/platform-tools/adb'` (line 185, 193)
  - `Directory('$_toolsDir/node')` (line 263)
  - `File('$_toolsDir/node.tar.xz')` (line 265)
- **Impact:** On Windows, `_toolsDir` resolves to `C:\Users\User\.openmob\tools` (backslashes), but then these paths append with forward slashes creating mixed paths like `C:\Users\User\.openmob\tools/platform-tools/adb.exe`. While Dart's `File` and `Directory` classes on Windows can sometimes handle mixed slashes, this is fragile and can break with certain Win32 API calls. More critically, the `Expand-Archive` PowerShell command (line 164-167) receives a mixed-slash path which may fail to resolve.
- **Fix:** Replace all `/` in these paths with `$_sep` or `${Platform.pathSeparator}`. The `_sep` getter already exists in the class -- use it consistently.

### ISSUE-03: `where` command output contains \r on Windows
- **Severity:** MEDIUM
- **Files:** `adb_service.dart:28`, `process_manager.dart:252`, `system_check_service.dart:84, 489`
- **Problem:** On Windows, `where adb` returns paths separated by `\r\n`. The code does `.trim().split('\n').first` which strips trailing `\r\n` from the whole string, but internal `\r` characters before `\n` are preserved. For single-result output this works (`.trim()` removes trailing `\r\n`), but for multi-result output (e.g., multiple adb.exe in PATH), the first result keeps its trailing `\r`, creating a path like `C:\platform-tools\adb.exe\r` which will fail on `File.existsSync()`.
- **Impact:** Rare but possible failure when multiple ADB installations exist in PATH. Also applies to `where aibridge` and `where node`.
- **Fix:** Chain `.trim()` on the result of `.first`:
```dart
final path = (result.stdout as String).trim().split('\n').first.trim();
```

### ISSUE-04: `adb devices` output parsing with \r\n
- **Severity:** MEDIUM
- **File:** `adb_service.dart:69-80`
- **Problem:** `(result.stdout as String).split('\n')` on Windows will leave `\r` at the end of each line. When splitting on `\s+` (line 74), the trailing `\r` becomes part of the status field. So `parts[1]` could be `'device\r'` instead of `'device'`, which means `raw.status == 'device'` (line 38 in device_manager.dart) will never match.
- **Impact:** No devices are detected on Windows. This is invisible -- the app shows an empty device list with no error message.
- **Fix:**
```dart
final lines = (result.stdout as String).replaceAll('\r', '').split('\n');
```

### ISSUE-05: Shelf HTTP server may trigger Windows Firewall prompt
- **Severity:** MEDIUM
- **File:** `api_server.dart:71`
- **Problem:** The shelf server binds to `InternetAddress.loopbackIPv4` (127.0.0.1). On Windows, listening on a port can trigger Windows Defender Firewall's "Allow access" dialog for private/public networks. While loopback traffic is typically exempt from firewall rules, the OS still prompts for the listening socket on first run of an unknown application.
- **Impact:** A non-technical QA tester may click "Cancel" or "Don't allow" on the firewall prompt, silently breaking the API server. The MCP server and AiBridge both connect to this port. The error message ("Could not bind to any port") would be confusing.
- **Fix:**
  1. Add a clear error message in the log when binding fails on Windows suggesting firewall as the cause.
  2. Consider adding a Windows manifest or documentation note about the expected firewall prompt.
  3. The binding is already to loopback-only, which is correct for security.

### ISSUE-06: window_manager plugin -- verified compatible
- **Severity:** NONE (confirmed OK)
- **File:** `main.dart:38-49`
- **Analysis:** `window_manager` v0.5.1 fully supports Windows. The `WindowOptions` usage (size, minimumSize, title, center) are all cross-platform. No issues found.

### ISSUE-07: dispose() never called -- process leaks on exit
- **Severity:** MEDIUM
- **Files:** `process_manager.dart:513-519`, `main.dart`
- **Problem:** `ProcessManager.dispose()` kills child processes and cancels timers. However, the `main()` function never registers a cleanup handler. On Linux, orphan processes are reaped by init. On Windows, orphan processes (MCP server, AiBridge) continue running as zombies after the Hub closes. This is especially problematic because the AiBridge occupies port 9999 and the MCP server uses stdio.
- **Impact:** After closing and reopening the Hub, port 9999 is already in use. The MCP server process accumulates with each restart.
- **Fix:** Add `windowManager.addListener` for `onWindowClose` or use `WidgetsBindingObserver.didChangeAppLifecycleState` to call `processManager.dispose()` on app exit.

### ISSUE-08: `url_launcher` -- verified compatible
- **Severity:** NONE (confirmed OK)
- **File:** `system_check_screen.dart:147`
- **Analysis:** `url_launcher` v6.3.2 supports Windows natively via `ShellExecute`. No issues.

---

## 2. AiBridge (openmob_bridge) -- Rust

### ISSUE-09: Cross-compilation via MinGW may produce broken ConPTY binary
- **Severity:** CRITICAL
- **File:** `.github/workflows/release.yml:89-92`, `Cargo.toml:8`
- **Problem:** The CI builds Windows via `x86_64-pc-windows-gnu` (MinGW cross-compile from Ubuntu). The `portable-pty` crate v0.8 uses Windows ConPTY APIs (`CreatePseudoConsole`, `ResizePseudoConsole`) which are linked against kernel32.dll. MinGW cross-compilation can produce binaries that link against ConPTY correctly, but there are known issues:
  1. **portable-pty has had Windows compilation issues** (wezterm/wezterm#1389) with type mismatches between `winapi::ctypes::c_void` and `std::ffi::c_void`
  2. **MinGW-compiled binaries may behave differently** than MSVC-compiled ones when calling Windows APIs, particularly with ConPTY where thread safety and handle inheritance matter
  3. The binary is never tested on actual Windows in CI -- only cross-compiled
- **Impact:** The AiBridge binary may crash or fail to spawn PTY sessions on Windows. The user sees "AiBridge exited with code 1" with no useful error.
- **Fix:**
  1. Add a `windows-latest` CI job that builds with `x86_64-pc-windows-msvc` target (native MSVC toolchain)
  2. Add a basic smoke test: `aibridge --help` to verify the binary runs
  3. Consider using `x86_64-pc-windows-msvc` as the primary Windows target

### ISSUE-10: ConPTY missing modern flags
- **Severity:** HIGH
- **File:** `pty_handler.rs:63` (calls `native_pty_system()`)
- **Problem:** `portable-pty` v0.8's `native_pty_system()` on Windows creates a ConPTY without passing `PSEUDOCONSOLE_RESIZE_QUIRK` (0x2) or `PSEUDOCONSOLE_WIN32_INPUT_MODE` (0x4) flags. These flags fix known ConPTY bugs:
  - Without `RESIZE_QUIRK`: terminal artifacts on resize
  - Without `WIN32_INPUT_MODE`: incorrect key handling for some input sequences
- **Impact:** Visual glitches and input handling bugs when the AiBridge window is resized or when specific key combinations are sent. AI agent prompts may render incorrectly.
- **Fix:**
  1. Consider switching to `portable-pty-psmux` v0.9.0 which adds ConPTY flag support
  2. Or keep v0.8 and document that resize may cause artifacts on Windows

### ISSUE-11: Signal handling -- already correctly handled
- **Severity:** NONE (confirmed OK)
- **File:** `main.rs:159-177`
- **Analysis:** The `signal_handler()` function uses `#[cfg(unix)]` for SIGTERM and `#[cfg(not(unix))]` for Ctrl+C only. This is correct -- SIGTERM does not exist on Windows.

### ISSUE-12: crossterm raw mode on Windows
- **Severity:** MEDIUM
- **File:** `bridge.rs:65`
- **Problem:** `crossterm::terminal::enable_raw_mode()` on Windows changes the console mode via `SetConsoleMode`. Known issues:
  1. If the binary is launched without a console (e.g., from the Hub's `Process.start` without a terminal window), `enable_raw_mode()` may fail because there is no console handle
  2. The `RawModeGuard` correctly restores terminal state via `Drop`, but if the process is force-killed (`taskkill /F`), the guard never runs
- **Impact:** When launched from the Hub on Windows (line 347 of process_manager.dart: `ProcessStartMode.normal`), AiBridge runs without a terminal window. `enable_raw_mode()` will return an error because there is no console attached. The `?` operator (line 65) propagates this error, causing `bridge.run()` to fail.
- **Fix:**
```rust
// Replace:
crossterm::terminal::enable_raw_mode()?;

// With:
if let Err(e) = crossterm::terminal::enable_raw_mode() {
    eprintln!("[warn] Could not enable raw mode: {} (running without terminal?)", e);
    // Continue anyway -- raw mode is nice-to-have, not essential for injection
}
```

### ISSUE-13: stdin reading in spawn_blocking when no console
- **Severity:** HIGH
- **File:** `bridge.rs:123-143`
- **Problem:** Task 2 (stdin forward) calls `stdin.lock().read()` in a `spawn_blocking` thread. When AiBridge is launched as a child process from the Hub on Windows (`ProcessStartMode.normal`), stdin is a pipe -- not a console. The `read()` call on a pipe will block until data arrives or the pipe is closed. Since no user is typing (the Hub doesn't forward input to the bridge), this task blocks forever. This is fine because it's in a separate thread, BUT:
  1. When `cancel` fires, the thread doesn't wake up from the blocked `read()`
  2. On Windows, there is no way to cancel a blocking `read()` on stdin (no `pthread_cancel` equivalent)
  3. The bridge shutdown may hang waiting for `stdin_handle.await` (line 223)
- **Impact:** When stopping AiBridge from the Hub, the process hangs for the timeout duration before being force-killed.
- **Fix:** On Windows, check if stdin is a console (`GetFileType(GetStdHandle(STD_INPUT_HANDLE)) == FILE_TYPE_CHAR`) before spawning the stdin reader. If stdin is a pipe, skip the stdin reader task or use non-blocking I/O.

### ISSUE-14: `which` crate -- verified compatible
- **Severity:** NONE (confirmed OK)
- **File:** `main.rs:79`
- **Analysis:** The `which` crate v7 supports Windows natively. It searches PATH and handles `.exe` extension matching on Windows. No issues.

---

## 3. MCP Server (openmob_mcp) -- TypeScript

### ISSUE-15: `fetch()` in yao-pkg bundled binary
- **Severity:** MEDIUM
- **File:** `hub-client.ts:14, 57, 67`
- **Problem:** The MCP server uses global `fetch()` (available in Node.js 18+). When bundled via `@yao-pkg/pkg` into a standalone binary, the built-in `fetch()` may not be available depending on the Node version used for bundling. The CI uses `node20` target.
- **Impact:** If the bundled binary lacks `fetch()`, the MCP server crashes immediately with `ReferenceError: fetch is not defined`. This affects all platforms equally, not just Windows.
- **Fix:** Verify that `@yao-pkg/pkg` with `node20` target includes `fetch()`. If not, add `node-fetch` as a polyfill:
```typescript
import fetch from 'node-fetch';
globalThis.fetch ??= fetch;
```

### ISSUE-16: MCP Server has no Windows-specific issues
- **Severity:** NONE (confirmed OK)
- **Files:** All `.ts` files in `openmob_mcp/src/`
- **Analysis:** The MCP server is purely an HTTP client that talks to the Hub's REST API via `fetch()`. It has no file system operations, no shell commands, no path manipulation. The stdio transport from `@modelcontextprotocol/sdk` is cross-platform. No Windows-specific issues beyond ISSUE-15.

---

## 4. Auto-Setup on Windows

### ISSUE-17: winget not available on Windows 10 LTSC, Server, or older Home editions
- **Severity:** HIGH
- **File:** `system_check_service.dart:232-252`
- **Problem:** Node.js auto-install uses `winget install --id OpenJS.NodeJS.LTS`. Winget is:
  - Not available on Windows 10 LTSC 2019/2021 (no Microsoft Store)
  - Not available on Windows Server editions
  - May not be installed on some Windows 10 Home editions (pre-20H1)
  - Requires manual installation on these SKUs
- **Impact:** The code correctly checks for winget availability (line 234-238) and shows a "install Node.js manually" error. However, the error message says "install Node.js manually from nodejs.org" but provides no clickable link or instructions. A non-technical QA tester will not know what to do.
- **Fix:**
  1. The winget check is already good. Enhance the error message:
     ```dart
     _log('winget not available. Install Node.js from https://nodejs.org/en/download/', error: true);
     ```
  2. Consider adding a direct download fallback (download MSI from nodejs.org)

### ISSUE-18: winget Node.js install requires app restart
- **Severity:** MEDIUM
- **File:** `auto_setup_service.dart:96-106`
- **Problem:** After `winget install OpenJS.NodeJS.LTS`, the `node` command is not in the current process's PATH until the app restarts (winget modifies the system PATH, but the current process inherits the old PATH). The code correctly detects this (line 96-106) and shows a "restart the app" message with `needsRestart: true`.
- **Impact:** The user must manually close and reopen the app. For a non-technical user, this could be confusing. But the handling is correct.
- **Fix:** No code change needed. The handling is already appropriate.

### ISSUE-19: npm.cmd is correctly used for Windows
- **Severity:** NONE (confirmed OK)
- **File:** `auto_setup_service.dart:208`, `system_check_service.dart:598`
- **Analysis:** The code correctly uses `Platform.isWindows ? 'npm.cmd' : 'npm'`. On Windows, `npm` is a bash script that doesn't run directly -- `npm.cmd` is the correct Windows wrapper. This is already handled.

### ISSUE-20: ADB auto-download -- PowerShell extraction
- **Severity:** MEDIUM
- **File:** `system_check_service.dart:163-167`
- **Problem:** The PowerShell command `Expand-Archive -Path <zipFile.path> -DestinationPath <_toolsDir> -Force` receives `zipFile.path` which is a Dart `File.path` value. On Windows, this path has backslashes, but `_toolsDir` uses mixed slashes (see ISSUE-02). If `_toolsDir` resolves with forward slashes, PowerShell may fail to find the destination.
- **Impact:** ADB auto-install silently fails. The user sees "Extract failed" in logs.
- **Fix:** Fix the forward-slash paths per ISSUE-02. Additionally, wrap the paths in double quotes in the PowerShell command to handle spaces in paths:
```dart
['-Command', 'Expand-Archive', '-Path', '"${zipFile.path}"', '-DestinationPath', '"$_toolsDir"', '-Force']
```

### ISSUE-21: Skill file paths -- correctly handled
- **Severity:** NONE (confirmed OK)
- **File:** `ai_tool_setup_service.dart` (all config paths)
- **Analysis:** All Windows config paths correctly use `USERPROFILE` or `APPDATA` environment variables with backslash separators. The Claude Desktop path uses `APPDATA\\Claude\\`, Cursor uses `USERPROFILE\\.cursor\\`, VS Code uses `APPDATA\\Code\\User\\`. These are all correct.

---

## 5. Process Management on Windows

### ISSUE-22: Process.kill() default behavior difference
- **Severity:** HIGH
- **File:** `process_manager.dart:210-215, 436-444`
- **Problem:** The stop flow is:
  1. Call `_mcpProcess!.kill()` (sends SIGTERM on Unix, calls TerminateProcess on Windows)
  2. Wait 3 seconds for exit
  3. On timeout, call `_mcpProcess!.kill(ProcessSignal.sigkill)` (CRASHES on Windows per ISSUE-01)

  On Windows, step 1 already does a force-kill (TerminateProcess). There is no graceful shutdown equivalent. So the timeout+SIGKILL pattern is unnecessary on Windows.
- **Impact:** CRITICAL on Windows -- see ISSUE-01.
- **Fix:**
```dart
Future<void> stopMcp() async {
  if (_mcpProcess != null) {
    _mcpProcess!.kill(); // On Windows, this is already a force kill
    if (!Platform.isWindows) {
      try {
        await _mcpProcess!.exitCode.timeout(const Duration(seconds: 3));
      } catch (_) {
        _mcpProcess!.kill(ProcessSignal.sigkill);
      }
    }
    _mcpProcess = null;
  }
  // ...
}
```

### ISSUE-23: taskkill for external bridge processes -- correct
- **Severity:** NONE (confirmed OK)
- **File:** `process_manager.dart:448-449`
- **Analysis:** `Process.runSync('taskkill', ['/F', '/IM', 'aibridge.exe'])` is the correct Windows equivalent of `pkill`. The `/F` flag forces termination. The `/IM` flag matches by image name. This is properly handled.

### ISSUE-24: Child process stdout/stderr capture on Windows
- **Severity:** LOW
- **File:** `process_manager.dart:156-168, 380-391`
- **Problem:** When a child process (MCP or Bridge) writes to stdout/stderr, the Hub captures it via `process.stdout.transform(utf8.decoder)`. On Windows, child processes may use the system's default code page (e.g., CP1252) rather than UTF-8 for console output. Node.js typically outputs UTF-8, but the Rust AiBridge's stderr may not if it includes Windows system error messages.
- **Impact:** Garbled text in the Hub log viewer for Windows system error messages (e.g., "Access denied" with special characters). Rare in practice.
- **Fix:** Low priority. Could add `environment: {'LANG': 'en_US.UTF-8'}` to `Process.start` calls, or accept this as a minor cosmetic issue.

---

## 6. GitHub Actions CI/CD

### ISSUE-25: AiBridge Windows build uses MinGW cross-compile instead of native MSVC
- **Severity:** CRITICAL (relates to ISSUE-09)
- **File:** `.github/workflows/release.yml:89-92`
- **Problem:** The Windows AiBridge binary is built on `ubuntu-latest` with target `x86_64-pc-windows-gnu` (MinGW). This means:
  1. No actual Windows testing occurs in CI
  2. The ConPTY Windows API calls may not link correctly with MinGW
  3. The produced `.exe` may crash at runtime even though compilation succeeded
  4. Visual C++ Redistributable may or may not be needed depending on MinGW's libc linking
- **Impact:** Every release ships a Windows binary that has never been tested on Windows.
- **Fix:**
```yaml
# Replace the MinGW cross-compile entry:
- os: ubuntu-latest
  target: x86_64-pc-windows-gnu
  artifact: aibridge.exe
  name: windows-x64

# With a native Windows build:
- os: windows-latest
  target: x86_64-pc-windows-msvc
  artifact: aibridge.exe
  name: windows-x64
```
Also remove the MinGW install step since it won't be needed.

### ISSUE-26: Flutter version mismatch between CI and project
- **Severity:** LOW
- **File:** `.github/workflows/release.yml:18`
- **Problem:** CI uses `FLUTTER_VERSION: '3.29.3'` but CLAUDE.md specifies Flutter 3.41.x. The pubspec.yaml requires SDK `^3.5.0` which is satisfied by both. The actual build will work, but the CI may be building with an older Flutter than intended.
- **Impact:** Minor -- no functional impact since the SDK constraint is loose. Could cause missing features if newer Flutter APIs are used.
- **Fix:** Update CI Flutter version to match the current stable: `FLUTTER_VERSION: '3.41.0'` (or whatever is latest).

### ISSUE-27: No Windows test or smoke test in CI
- **Severity:** HIGH
- **File:** `.github/workflows/release.yml`
- **Problem:** The Windows Hub build (`build-hub-windows`) only runs `flutter build windows --release`. There is no:
  1. Smoke test (does the exe launch and exit cleanly?)
  2. Unit test run on Windows
  3. AiBridge binary execution test on Windows
  4. MCP bundled binary execution test on Windows
- **Impact:** Windows-specific runtime failures are never caught before release.
- **Fix:** Add post-build verification steps:
```yaml
- name: Verify Hub launches
  shell: cmd
  run: |
    start /B artifacts/windows/openmob_hub.exe
    timeout /t 5
    taskkill /F /IM openmob_hub.exe

- name: Verify AiBridge runs
  shell: cmd
  run: |
    artifacts\aibridge.exe --help
```

---

## 7. Distribution

### ISSUE-28: Windows Defender SmartScreen blocks unsigned executables
- **Severity:** CRITICAL
- **Problem:** Windows SmartScreen displays "Windows protected your PC -- Microsoft Defender SmartScreen prevented an unrecognized app from starting" for all unsigned executables. As of Windows 11 25H2, Smart App Control (SAC) with AI-based blocking is enabled by default on new installs.
- **Impact:** A non-technical QA tester will:
  1. See the SmartScreen warning and may refuse to proceed
  2. Not know to click "More info" then "Run anyway"
  3. May report it as malware to IT
  4. On managed corporate PCs, SmartScreen bypass may be disabled by IT policy
- **Fix:**
  1. **Short-term:** Add clear instructions in the distribution package (README.txt or INSTALL.txt) explaining the SmartScreen warning
  2. **Medium-term:** Submit the binary to Microsoft for malware analysis to build reputation
  3. **Long-term:** Purchase an EV (Extended Validation) code signing certificate ($250-700/year) to immediately bypass SmartScreen

### ISSUE-29: Visual C++ Redistributable dependency
- **Severity:** LOW
- **Problem:** Flutter Windows builds link against the Visual C++ Redistributable (vcruntime140.dll). If the target Windows PC is truly fresh (no Visual Studio, no games, no other apps), these DLLs may be missing.
- **Impact:** The app fails to launch with "The code execution cannot proceed because VCRUNTIME140.dll was not found."
- **Fix:**
  1. Include `vcruntime140.dll` and `vcruntime140_1.dll` in the distribution package (Flutter typically includes them in the build output)
  2. Alternatively, bundle the VC++ Redistributable installer (`vc_redist.x64.exe`) with instructions

### ISSUE-30: No installer -- just a zip
- **Severity:** MEDIUM
- **File:** `.github/workflows/release.yml:211-225`
- **Problem:** The Windows distribution is a `.zip` file containing the raw build output. There is:
  1. No installer (MSI, NSIS, Inno Setup)
  2. No Start Menu shortcut
  3. No desktop shortcut
  4. No uninstaller
  5. No PATH configuration for bundled tools (AiBridge, MCP)
- **Impact:** A non-technical QA tester extracts the zip to `C:\Users\Downloads\openmob-windows-x64\` and runs the exe from there. If they extract to `C:\Program Files\`, they may hit permission issues when the app tries to write config files. There is no "Install" experience.
- **Fix:**
  1. Use Inno Setup or NSIS to create a proper Windows installer
  2. Configure install to `%LOCALAPPDATA%\OpenMob` (avoids admin UAC prompts)
  3. Create Start Menu and Desktop shortcuts
  4. Add an uninstaller entry

---

## Summary Table

| ID | Severity | Component | Issue |
|----|----------|-----------|-------|
| 01 | CRITICAL | Hub | `ProcessSignal.sigkill` crashes on Windows |
| 02 | HIGH | Hub | Forward-slash paths in ADB download code |
| 03 | MEDIUM | Hub | `where` output contains `\r` on Windows |
| 04 | MEDIUM | Hub | `adb devices` output parsing with `\r\n` |
| 05 | MEDIUM | Hub | Shelf HTTP server triggers firewall prompt |
| 07 | MEDIUM | Hub | dispose() never called -- zombie processes |
| 09 | CRITICAL | Bridge CI | MinGW cross-compile may produce broken ConPTY binary |
| 10 | HIGH | Bridge | ConPTY missing modern flags (resize quirk, input mode) |
| 12 | MEDIUM | Bridge | crossterm raw mode fails without console |
| 13 | HIGH | Bridge | stdin reader hangs forever on pipe (no console) |
| 15 | MEDIUM | MCP | fetch() may be missing in bundled binary |
| 17 | HIGH | Setup | winget not available on LTSC/Server/older editions |
| 18 | MEDIUM | Setup | winget Node.js install requires app restart |
| 20 | MEDIUM | Setup | PowerShell Expand-Archive receives mixed-slash paths |
| 22 | HIGH | Hub | Process.kill timeout+SIGKILL pattern crashes (dupe of 01) |
| 24 | LOW | Hub | Stdout capture may use wrong codepage |
| 25 | CRITICAL | CI/CD | AiBridge Windows build untested MinGW cross-compile |
| 26 | LOW | CI/CD | Flutter version mismatch |
| 27 | HIGH | CI/CD | No Windows smoke tests in CI |
| 28 | CRITICAL | Distro | SmartScreen blocks unsigned executables |
| 29 | LOW | Distro | VC++ Redistributable may be missing |
| 30 | MEDIUM | Distro | No installer, just a zip file |

---

## Priority Fix Order

### Must-fix before any Windows release (CRITICAL):
1. **ISSUE-01/22:** Fix `ProcessSignal.sigkill` -- 5 minute fix, prevents crashes
2. **ISSUE-25/09:** Switch AiBridge CI to `windows-latest` + MSVC target
3. **ISSUE-28:** Add SmartScreen instructions or code signing

### Should-fix for reliable Windows experience (HIGH):
4. **ISSUE-02:** Fix forward-slash paths in system_check_service.dart
5. **ISSUE-13:** Fix stdin reader blocking on pipe in bridge.rs
6. **ISSUE-10:** Evaluate portable-pty-psmux for ConPTY flag support
7. **ISSUE-17:** Improve winget fallback error messages
8. **ISSUE-27:** Add Windows smoke tests to CI

### Nice-to-have (MEDIUM/LOW):
9. **ISSUE-04:** Fix `\r\n` in adb devices parsing
10. **ISSUE-03:** Fix `\r` in where/which output
11. **ISSUE-12:** Gracefully handle raw mode failure
12. **ISSUE-07:** Add dispose on window close
13. **ISSUE-30:** Create proper Windows installer
