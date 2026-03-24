# Domain Pitfalls

**Domain:** AI-powered mobile device automation bridge (Go PTY + MCP server + Flutter Desktop + ADB/Xcode)
**Researched:** 2026-03-24
**Confidence:** MEDIUM-HIGH (multiple sources corroborate; some areas iOS-specific are less documented)

---

## Critical Pitfalls

Mistakes that cause rewrites, security incidents, or fundamental architecture failures.

### Pitfall 1: PTY Read/EOF Race Conditions in Go

**What goes wrong:** `ptmx.Read()` blocks indefinitely or returns unexpected EOF due to race conditions between the child process writing and the Go goroutine reading. On Darwin (macOS), `ptmx.Read()` has documented blocking behavior that differs from Linux. Data races occur when compiled with Go < 1.12, and even on modern Go versions, the nondeterminism of PTY read/write ordering causes intermittent hangs.

**Why it happens:** PTY I/O is inherently racy. The kernel's PTY buffer has no ordering guarantees between the master and slave sides. Go's goroutine scheduler adds another layer of nondeterminism. `process.Wait()` and concurrent reads on the PTY file descriptor create an "inherently racy execution" as documented in Go issue #60481.

**Consequences:** AiBridge CLI hangs after agent exits. Goroutines leak because the read loop never terminates. CI tests pass on Linux but fail on macOS (or vice versa). Users see "frozen" terminal with no error message.

**Warning signs:**
- Tests pass locally but fail in CI intermittently
- Agent wrapper works with Claude Code but hangs with Codex CLI
- `goroutine count` grows over time (visible via pprof)
- macOS-specific bug reports that cannot be reproduced on Linux

**Prevention:**
- Always use `context.WithCancel` or `context.WithTimeout` wrapping all PTY read loops
- Set read deadlines on the PTY file descriptor using `ptmx.SetReadDeadline()`
- Use `select` with a done channel to race between read completion and process exit
- Run `ch <- syscall.SIGWINCH` for initial resize before entering read loop
- Test on both Linux and macOS in CI from day one
- Use `goleak` in tests to detect goroutine leaks early

**Detection:** Add `runtime.NumGoroutine()` logging on each agent session start/stop. If count trends upward across sessions, there is a leak.

**Phase mapping:** Phase 1 (AiBridge CLI core) -- must be addressed in the very first implementation of the PTY wrapper.

**Confidence:** HIGH -- documented in creack/pty issues #114, #167, and Go issue #60481.

---

### Pitfall 2: MCP Server Binding to 0.0.0.0 (NeighborJack)

**What goes wrong:** MCP server binds to all network interfaces instead of localhost only. Any device on the local network (or the internet, if no firewall) can access the MCP server, execute tools, read filesystem contents, and exfiltrate environment variables and API keys. This is not theoretical -- security researchers from Backslash found hundreds of public MCP servers with this exact misconfiguration in June 2025 (CVE-2025-49596, CVSS 9.4).

**Why it happens:** Default configurations in many HTTP frameworks bind to `0.0.0.0` for convenience. Developers copy examples without changing the bind address. During development, binding to all interfaces "just works" across Docker containers and VMs, so it becomes the default.

**Consequences:** Complete host machine compromise. API keys, SSH keys, and environment secrets exfiltrated. Arbitrary code execution via MCP tool calls from any network neighbor. Browsers can exploit this via the "0.0.0.0 Day" technique -- visiting a malicious website triggers requests to localhost MCP servers.

**Warning signs:**
- HTTP server config uses `0.0.0.0` or `:port` without explicit host
- No authentication on the MCP endpoint
- Server accessible from other machines on the network
- Tool descriptions readable without any credentials

**Prevention:**
- Hard-code `127.0.0.1` (not `localhost`, not `0.0.0.0`) as the bind address
- Add a startup check that verifies the server is NOT accessible from non-loopback interfaces
- Even for localhost: add session tokens (as MCP Inspector did in v0.14.1) and origin validation
- Document explicitly in user-facing config that changing bind address has security implications
- Never expose MCP tools that execute arbitrary shell commands without sandboxing

**Detection:** On startup, attempt to connect to the server from a non-loopback address. If it succeeds, refuse to start and log a security warning.

**Phase mapping:** Phase 2 (MCP server) -- must be the first thing implemented when creating the HTTP/transport layer. No exceptions.

**Confidence:** HIGH -- CVE-2025-49596, Backslash Security research, Docker security blog, multiple independent sources.

---

### Pitfall 3: Regex-Based Idle Detection Breaks Across Agent Updates

**What goes wrong:** The busy/idle detection system uses regex patterns matched against terminal output (e.g., matching Claude Code's prompt pattern `$> ` or Codex's `> `). When AI agents update their terminal UI, change prompt formats, add spinners, or modify ANSI escape sequences, the regex patterns break silently. The system either never detects idle (queued injections never fire) or always detects idle (injections fire while the agent is mid-thought).

**Why it happens:** AI coding agents (Claude Code, Codex CLI, Gemini CLI) are rapidly evolving products. Their terminal output format is not a stable API. Regex patterns are brittle against ANSI escape codes, color sequences, Unicode characters, and dynamic content like progress bars or token counts.

**Consequences:** Context injection fires at wrong time, corrupting the agent's input stream. Agent receives screenshot data mid-response and hallucinates. Injection queue backs up indefinitely because idle is never detected. Users blame OpenMob for "breaking" their agent.

**Warning signs:**
- Idle detection works for one agent but not another
- After an agent CLI update, injections stop working
- Pattern matches work in tests with static strings but fail with real terminal output containing ANSI codes
- The 500ms idle timeout triggers false positives during agent "thinking" pauses

**Prevention:**
- Strip ALL ANSI escape sequences before pattern matching (use a proper ANSI parser, not just `\x1b\[[0-9;]*m`)
- Make patterns configurable per-agent via config file, not compiled in
- Include a "pattern test" mode where users can verify their patterns work against actual terminal output
- Implement a fallback heuristic: if no output for N seconds AND last line matches a known prompt prefix, consider idle
- Log raw terminal output (with ANSI codes) alongside stripped output for debugging
- Version-pin the agent patterns and document which agent versions they were tested against
- Consider NTM's approach: recency-weighted pattern matching where recent lines matter more

**Detection:** Add telemetry for idle detection accuracy: log timestamps of detected idle events and compare against actual agent state. If injection success rate drops below threshold, alert.

**Phase mapping:** Phase 1 (AiBridge CLI) -- core feature, but design it for extensibility from the start. Expect to iterate patterns every time a supported agent releases an update.

**Confidence:** MEDIUM-HIGH -- MobAI reference implementation uses this exact approach (500ms timeout + regex), and the fragility is inherent to the design. NTM project independently confirms the challenge.

---

### Pitfall 4: ADB Screenshot/UI Dump Performance Bottleneck

**What goes wrong:** `adb screencap` takes 300-500ms per capture. `adb shell uiautomator dump` takes 1-3 seconds and fails entirely on animated screens with "ERROR: could not get idle state." At the cadence AI agents need feedback (every few seconds during interaction), these latencies make the system feel sluggish and unreliable. The entire automation loop (screenshot -> send to agent -> agent decides -> execute action) becomes 5-10 seconds per interaction.

**Why it happens:** `adb screencap` captures the framebuffer and compresses to PNG on-device before transferring. `uiautomator dump` waits for UI idle state, which never arrives during animations or transitions. The ADB USB protocol has inherent overhead for large data transfers.

**Consequences:** Agent receives stale screenshots. Taps/swipes target elements that have already moved. Users perceive the system as unusable for anything but static screens. Flutter apps are especially problematic because UIAutomator cannot dump Flutter view hierarchies (flutter/flutter#106327).

**Warning signs:**
- Screenshot capture takes > 200ms consistently
- UI tree dump returns empty or error on apps with animations
- Agent actions "miss" buttons that were visible in the last screenshot
- Flutter apps show zero accessibility nodes in the UI tree

**Prevention:**
- Use `adb exec-out screencap -p` (raw stdout, no intermediate file) for faster capture
- Consider MJPEG streaming server approach (as documented by HeadSpin) for continuous screenshot feeds instead of polling
- For UI hierarchy: prefer accessibility service-based dumps over `uiautomator dump` -- they work during animations
- Resize/compress screenshots before sending to AI agent (agent does not need 4K resolution)
- Implement screenshot caching: if screen has not changed (compare hashes), reuse previous capture
- For Flutter apps: use Flutter's own debug protocol (Dart VM service) instead of UIAutomator

**Detection:** Log screenshot capture time for every call. Alert if p95 exceeds 500ms. Track UI dump failures as a percentage of attempts.

**Phase mapping:** Phase 2-3 (MCP server device automation tools) -- initial implementation will use naive approach, but must plan for optimization in the architecture from the start. Do not hardcode the screenshot method.

**Confidence:** HIGH -- ADB performance characteristics are well-documented. Flutter UIAutomator incompatibility is a confirmed Flutter issue.

---

### Pitfall 5: iOS Physical Device Automation is Fundamentally Different from Simulator

**What goes wrong:** Developers build and test the entire iOS automation flow against the Simulator using `xcrun simctl`, then discover that physical device automation requires a completely different toolchain (WebDriverAgent, Xcode signing, devicectl) with different capabilities and severe limitations. Features that work perfectly on Simulator (install app, launch app, take screenshot) require signed provisioning profiles, active developer accounts, and WDA deployment on physical devices.

**Why it happens:** `xcrun simctl` provides a rich, easy API for simulators. Apple's physical device automation tooling is poorly documented (Apple's own docs for simctl are minimal). The gap between simulator and real device is not apparent until you try to ship. iOS security model intentionally restricts what you can do with a physical device without jailbreaking.

**Consequences:** "Works on simulator" becomes the permanent state. Physical device support gets deferred indefinitely or requires a complete second implementation path. Users who only have physical devices cannot use the iOS features. The architecture assumes a uniform device API that does not exist.

**Warning signs:**
- All iOS testing done on Simulator only
- No provisioning profile or signing setup in the development workflow
- iOS automation code only uses `xcrun simctl` commands
- No mention of WebDriverAgent or `xcrun devicectl` in the codebase

**Prevention:**
- Define a `DeviceDriver` interface/abstraction from day one that has separate implementations for iOS Simulator, iOS Physical, Android Emulator, and Android Physical
- Test on a physical iOS device in the first sprint that touches iOS -- not as a "later" task
- Document the signing/provisioning requirements clearly for contributors
- For v1, explicitly scope iOS support to Simulator-only if physical device support is too complex, rather than pretending it works on both
- Consider using `go-ios` or `idb` (Facebook's iOS Development Bridge) as an alternative to raw xcrun for physical devices

**Detection:** Maintain a test matrix: Simulator vs Physical x each automation command. Any cell marked "untested" is a risk.

**Phase mapping:** Phase 3 (iOS device automation) -- the architecture decision (abstract device driver interface) must happen in Phase 2 when Android is implemented, so iOS can plug in cleanly.

**Confidence:** MEDIUM -- based on community reports and Apple's documentation gaps. The fundamental limitation (different toolchains) is well-established, but specific workarounds evolve with each Xcode release.

---

## Moderate Pitfalls

### Pitfall 6: Goroutine and Subprocess Leaks in the PTY Manager

**What goes wrong:** Each agent session spawns a PTY, a child process, and multiple goroutines (read loop, write loop, SIGWINCH handler, idle detector). When the session ends abnormally (user kills terminal, agent crashes, network disconnect), cleanup does not happen. Over hours of use, leaked goroutines and zombie processes accumulate, eventually exhausting system resources.

**Prevention:**
- Use `context.Context` as the lifecycle owner for every session
- Implement a session manager that tracks all active sessions and their resources
- Use `defer` chains with explicit cleanup: close PTY, kill child process (SIGTERM then SIGKILL after timeout), stop goroutines via context cancellation, remove session from registry
- Set process group on child process (`Setpgid: true` in `SysProcAttr`) so that killing the group kills all descendants
- Add a reaper goroutine that periodically checks for orphaned sessions (PTY closed but goroutines still running)
- Run `goleak.VerifyNone(t)` in all test teardowns

**Warning signs:** `ps aux | grep defunct` shows zombie processes. `runtime.NumGoroutine()` climbs over time. System becomes slow after running for hours.

**Phase mapping:** Phase 1 (AiBridge CLI) -- implement cleanup in the same PR as session creation. Never "add cleanup later."

**Confidence:** HIGH -- standard Go concurrency pitfall, well-documented across multiple sources.

---

### Pitfall 7: MCP Transport Choice Lock-in (SSE vs Streamable HTTP vs stdio)

**What goes wrong:** MCP server is built with SSE transport (the legacy approach), then must be rewritten when clients drop SSE support in favor of Streamable HTTP. Or stdio transport is used for local dev, but the architecture cannot support remote connections later.

**Prevention:**
- Use stdio transport for the primary local use case (agent on same machine as MCP server) -- this is the correct choice for OpenMob's self-hosted model
- If HTTP transport is needed (e.g., Flutter hub communicating with MCP server), use Streamable HTTP (introduced March 2025), NOT SSE
- SSE is officially deprecated by the MCP specification as of 2025 -- do not implement it
- Abstract the transport layer so switching is a config change, not a rewrite
- Use the official `@modelcontextprotocol/sdk` TypeScript SDK which handles transport abstraction

**Warning signs:** Code imports SSE-specific libraries. Transport choice is hardcoded rather than configurable. No tests for multiple transport types.

**Phase mapping:** Phase 2 (MCP server) -- transport decision is an architecture decision that must be made upfront.

**Confidence:** HIGH -- MCP specification and roadmap explicitly deprecate SSE in favor of Streamable HTTP.

---

### Pitfall 8: Tool Poisoning via Malicious MCP Tool Descriptions

**What goes wrong:** Even though OpenMob is self-hosted, if users connect additional third-party MCP servers alongside OpenMob's server, a malicious server can inject instructions into tool descriptions that manipulate the AI agent's behavior. The agent sees all tool descriptions across all connected servers -- a poisoned tool description from server B can instruct the agent to exfiltrate data via server A's tools.

**Prevention:**
- Sanitize all tool descriptions: strip any instruction-like text, limit description length
- Implement tool call validation: before executing a tool, verify the request came from user intent (not from another tool's output)
- Log all tool calls with full context for audit
- Document this risk clearly for users who connect multiple MCP servers
- Consider implementing tool allowlists in the MCP server configuration

**Warning signs:** Tool descriptions contain phrases like "always", "before doing anything", "first check", or other instruction-like language. Tools receive parameters that the user never explicitly provided.

**Phase mapping:** Phase 2 (MCP server) -- implement input validation and logging from the start.

**Confidence:** HIGH -- documented attacks with real-world examples (WhatsApp history exfiltration via tool poisoning).

---

### Pitfall 9: Flutter Desktop Subprocess Visibility (cmd.exe Flash)

**What goes wrong:** On Windows, when the Flutter Desktop hub spawns subprocesses (AiBridge CLI, ADB commands, MCP server), each spawn briefly flashes a `cmd.exe` window. This is a known Flutter Desktop issue (#47891) where `Process.start()` creates visible console windows.

**Prevention:**
- On Windows, use `CREATE_NO_WINDOW` or `DETACHED_PROCESS` creation flags via platform channels (Dart's `Process.start` does not expose these flags directly)
- Implement process management via a native Windows plugin that wraps `CreateProcessW` with the correct flags
- On macOS/Linux this is not an issue -- subprocess spawning is invisible
- Consider running long-lived subprocesses (AiBridge, MCP server) as background services rather than spawning on-demand

**Warning signs:** Users report "flickering black windows" on Windows. Bug reports only from Windows users.

**Phase mapping:** Phase 4 (Flutter Desktop hub) -- can be deferred to polish, but must be addressed before any release.

**Confidence:** HIGH -- documented Flutter issue #47891, confirmed unresolved as of 2025.

---

### Pitfall 10: ADB WiFi Connection Instability

**What goes wrong:** ADB over WiFi connections drop when the device changes networks, locks the screen, enters deep sleep, or after periods of inactivity. Android automatically disables wireless debugging after inactivity. The automation bridge loses connection mid-session with no recovery mechanism.

**Prevention:**
- Implement connection health monitoring: periodic `adb devices` polling to detect disconnection
- Auto-reconnect logic with exponential backoff (ADB now supports reconnection attempts for up to 60 seconds)
- Prefer USB connections for reliability; treat WiFi as a secondary option
- Leverage Android's upcoming mDNS-based auto-reconnect (available in newer Android versions)
- Queue pending commands during disconnection and replay on reconnect (with staleness checks)
- Show clear connection status in the Flutter hub UI with manual reconnect button

**Warning signs:** Intermittent "device offline" errors. Commands succeed then fail then succeed. WiFi-connected device disappears from `adb devices` after screen lock.

**Phase mapping:** Phase 2-3 (device automation) -- connection management is infrastructure that must be robust from the start.

**Confidence:** HIGH -- universally reported issue, Google actively working on improvements.

---

## Minor Pitfalls

### Pitfall 11: ANSI Escape Code Pollution in Injected Context

**What goes wrong:** When the AiBridge injects context (screenshots, UI trees) into the terminal, raw ANSI escape codes from the agent's output contaminate the injected text, or the injected text's formatting breaks the agent's ANSI rendering. The terminal becomes garbled.

**Prevention:**
- Inject context as plain text with no ANSI formatting
- Use a well-defined injection protocol (e.g., specific delimiter markers the agent recognizes)
- Strip ANSI from all captured terminal output before processing
- Test injection with agents that use heavy ANSI formatting (Claude Code's markdown rendering)

**Phase mapping:** Phase 1 (AiBridge CLI) -- test injection formatting with each supported agent.

**Confidence:** MEDIUM -- inherent to PTY-based injection, but specific impact depends on agent implementation.

---

### Pitfall 12: Flutter Desktop Multi-Window Performance Degradation

**What goes wrong:** If the Flutter hub uses multiple windows (e.g., device detail views, log windows), performance degrades significantly because all windows share a single Flutter engine process. Raster times increase and FPS drops.

**Prevention:**
- Use single-window navigation (routes/pages) instead of multiple OS windows
- If multi-window is required, use a community plugin like `desktop_multi_window` that spawns separate engines
- Avoid heavy synchronous work in window constructors
- Profile rendering performance with `flutter run --profile` when adding new views

**Phase mapping:** Phase 4 (Flutter Desktop hub) -- architectural decision in the first hub implementation.

**Confidence:** HIGH -- documented Flutter issue #168376, confirmed performance regression.

---

### Pitfall 13: Xcode Version Coupling in iOS Automation

**What goes wrong:** `xcrun simctl` behavior changes between Xcode versions. Commands that work in Xcode 15 may have different syntax or behavior in Xcode 16. Users running different Xcode versions get different results.

**Prevention:**
- Detect active Xcode version at startup via `xcodebuild -version`
- Test against at least two Xcode versions (current and previous)
- Wrap all `xcrun` calls in version-aware wrappers that handle differences
- Document minimum supported Xcode version

**Phase mapping:** Phase 3 (iOS automation) -- implement version detection from the start.

**Confidence:** MEDIUM -- based on historical Xcode breaking changes pattern.

---

### Pitfall 14: HTTP API Design That Cannot Support Future MCP Integration

**What goes wrong:** The AiBridge HTTP API is designed as a simple REST API for injection, but later when the MCP server needs to communicate with AiBridge, the API lacks proper event streaming, session management, or bidirectional communication capabilities.

**Prevention:**
- Design the HTTP API with future MCP integration in mind from day one
- Include WebSocket or SSE endpoint for real-time status updates (agent state, injection results)
- Use session IDs to correlate device actions with specific agent sessions
- Keep the API stateless where possible but support stateful sessions where needed

**Phase mapping:** Phase 1 (AiBridge CLI) -- API design happens here but must anticipate Phase 2 integration.

**Confidence:** MEDIUM -- architectural foresight based on the three-component integration requirement.

---

## Phase-Specific Warnings

| Phase Topic | Likely Pitfall | Mitigation | Severity |
|-------------|---------------|------------|----------|
| Phase 1: AiBridge CLI (Go PTY) | PTY read race conditions (#1) | Context-based lifecycle, read deadlines, cross-platform CI | Critical |
| Phase 1: AiBridge CLI (Go PTY) | Goroutine/subprocess leaks (#6) | Process group cleanup, goleak testing | Critical |
| Phase 1: AiBridge CLI (Go PTY) | Idle detection fragility (#3) | Configurable patterns, ANSI stripping, fallback heuristics | Critical |
| Phase 1: AiBridge CLI (Go PTY) | ANSI injection pollution (#11) | Plain text injection, delimiter protocol | Moderate |
| Phase 1: AiBridge CLI (Go PTY) | HTTP API future-proofing (#14) | Design for MCP integration upfront | Moderate |
| Phase 2: MCP Server | 0.0.0.0 binding (#2) | Hard-code 127.0.0.1, startup verification | Critical |
| Phase 2: MCP Server | Transport lock-in (#7) | Use stdio + Streamable HTTP, never SSE | Moderate |
| Phase 2: MCP Server | Tool poisoning (#8) | Input validation, logging, tool allowlists | Moderate |
| Phase 2-3: Device Automation | ADB screenshot perf (#4) | exec-out, MJPEG streaming, resize before send | Critical |
| Phase 2-3: Device Automation | WiFi disconnection (#10) | Health monitoring, auto-reconnect, prefer USB | Moderate |
| Phase 3: iOS Automation | Simulator vs physical gap (#5) | Abstract DeviceDriver interface, test physical early | Critical |
| Phase 3: iOS Automation | Xcode version coupling (#13) | Version detection, multi-version CI | Minor |
| Phase 4: Flutter Hub | cmd.exe window flash (#9) | Native plugin with CREATE_NO_WINDOW | Moderate |
| Phase 4: Flutter Hub | Multi-window perf (#12) | Single-window navigation, avoid multi-window | Minor |

---

## Meta-Pitfall: The Integration Gap

The single biggest risk in this project is not any individual component pitfall -- it is the integration between three independently-developed components (Go CLI, TypeScript MCP server, Flutter Desktop hub) that speak different protocols and have different lifecycle models. Each component may work perfectly in isolation but fail when composed.

**Prevention:**
- Define the integration protocol (HTTP API contracts, message formats, session lifecycle) BEFORE building any component
- Build a minimal end-to-end integration test in Phase 1 that proves the three components can talk to each other, even with stub implementations
- Use OpenAPI or similar schema for the HTTP API between components
- Avoid "build each component fully, integrate later" -- integrate continuously

**Phase mapping:** Every phase. Integration tests should be a gate for every phase transition.

---

## Sources

- [creack/pty GitHub - PTY interface for Go](https://github.com/creack/pty) -- PTY issues #114, #167
- [Go Issue #60481 - Goroutine-friendly waiting on processes](https://github.com/golang/go/issues/60481)
- [MCP Security: NeighborJack and CVE-2025-49596](https://virtualizationreview.com/articles/2025/06/25/mcp-servers-hit-by-neighborjack-vulnerability-and-more.aspx)
- [Docker MCP Horror Stories: Drive-By Localhost Breach](https://www.docker.com/blog/mpc-horror-stories-cve-2025-49596-local-host-breach/)
- [MCP Vulnerabilities - Composio](https://composio.dev/content/mcp-vulnerabilities-every-developer-should-know)
- [A Timeline of MCP Security Breaches](https://authzed.com/blog/timeline-mcp-breaches)
- [MCP Transport: Why SSE was Deprecated](https://blog.fka.dev/blog/2025-06-06-why-mcp-deprecated-sse-and-go-with-streamable-http/)
- [MCP Transport Comparison - MCPcat](https://mcpcat.io/guides/comparing-stdio-sse-streamablehttp/)
- [ADB Screenshot Performance - Repeato](https://www.repeato.app/efficiently-capturing-screenshots-on-android-devices-via-adb/)
- [MJPEG Screenshot Streaming - HeadSpin](https://www.headspin.io/blog/speeding-up-android-screenshots-with-mjpeg-servers)
- [Flutter UIAutomator Incompatibility - Issue #106327](https://github.com/flutter/flutter/issues/106327)
- [Flutter Desktop cmd.exe Window Flash - Issue #47891](https://github.com/flutter/flutter/issues/47891)
- [Flutter Desktop Multi-Window Performance - Issue #168376](https://github.com/flutter/flutter/issues/168376)
- [ADB WiFi Auto-Reconnect - Android Authority](https://www.androidauthority.com/android-wireless-adb-auto-reconnect-3624945/)
- [MobAI AiBridge Reference - GitHub](https://github.com/MobAI-App/aibridge)
- [NTM - Named Tmux Manager Agent Idle Detection](https://github.com/Dicklesworthstone/ntm)
- [Go Goroutine Leak Prevention](https://oneuptime.com/blog/post/2026-01-07-go-goroutine-leaks/view)
- [MCP 2026 Roadmap](https://blog.modelcontextprotocol.io/posts/2026-mcp-roadmap/)
- [Practical DevSecOps - MCP Security Vulnerabilities](https://www.practical-devsecops.com/mcp-security-vulnerabilities/)
