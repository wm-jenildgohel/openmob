<!-- GSD:project-start source:PROJECT.md -->
## Project

- Remember Codex is monitoring and reviewing your code and functionality.

**OpenMob**

OpenMob is a free, self-hosted, open-source alternative to MobAI that gives AI coding agents the ability to see and control mobile devices. It consists of three core components: a Go-based AiBridge CLI that wraps terminal AI agents with a PTY layer and HTTP API for context injection, an MCP server for mobile device automation, and a Flutter Desktop hub app for device management and bridge control. It supports Android and iOS devices via USB, WiFi, and emulator/simulator connections.

**Core Value:** AI coding agents can see what's on a mobile device screen and interact with it programmatically — no quotas, no limits, completely self-hosted.

### Constraints

- **Tech Stack**: AiBridge CLI in Go (matches reference), MCP server in TypeScript (Node.js), Hub in Flutter Desktop — proven stack per component
- **Self-hosted**: No external API calls, no telemetry, no license validation — runs fully offline
- **Security**: Localhost-only HTTP binding by default, no authentication needed for local dev
- **Compatibility**: Must work with Claude Code, Codex CLI, Gemini CLI, and any MCP-compatible client
<!-- GSD:project-end -->

<!-- GSD:stack-start source:research/STACK.md -->
## Technology Stack

## Recommended Stack
### Component 1: AiBridge CLI (Go)
#### Runtime & Language
| Technology | Version | Purpose | Why | Confidence |
|------------|---------|---------|-----|------------|
| Go | 1.26 | Language runtime | Latest stable (released Feb 2026). Single binary compilation, excellent concurrency primitives, first-class PTY support on Unix. Matches MobAI reference implementation. | HIGH |
#### Core Libraries
| Technology | Version | Purpose | Why | Confidence |
|------------|---------|---------|-----|------------|
| creack/pty | v1.1.24 | PTY management | The standard Go PTY library. Used by nearly every Go terminal wrapper including MobAI's aibridge. Stable, actively maintained, supports Linux/macOS/BSDs. Latest release adds z/OS support. | HIGH |
| spf13/cobra | v2.3.0 | CLI framework | Industry standard for Go CLIs (used by kubectl, Hugo, gh). v2 brings improved Go module support, enhanced command generation, better Viper integration. No real alternative worth considering. | HIGH |
| spf13/viper | v1.8+ | Configuration | Pairs with Cobra naturally. Supports YAML/JSON/TOML/env/flags. Handles config file discovery, env var binding, and flag binding. The standard choice for Go CLI config. | MEDIUM |
| net/http (stdlib) | Go 1.26 | HTTP API server | Go 1.22+ ServeMux now supports method-based routing and path wildcards. For a simple localhost API (4-5 endpoints: /health, /status, /inject, /queue), the stdlib is sufficient. No need for chi or gin for this scope. | HIGH |
| log/slog (stdlib) | Go 1.26 | Structured logging | Standard library structured logger since Go 1.21. For a CLI tool, slog provides structured JSON logging without third-party deps. If perf becomes critical, slog's handler interface lets you swap in zerolog later. | HIGH |
| coder/websocket | v1.8.x | WebSocket (optional) | If real-time hub-to-CLI communication is needed beyond HTTP polling. Maintained successor to nhooyr/websocket. Context-aware, handles concurrent writes safely. Preferred over archived gorilla/websocket. | MEDIUM |
#### Why NOT These Alternatives
| Library | Why Not |
|---------|---------|
| gorilla/websocket | Archived since late 2022. Do not build on unmaintained dependencies. |
| gin / echo / fiber | Overkill for a localhost API with 5 endpoints. Adds unnecessary dependency weight. stdlib net/http with Go 1.22+ routing is sufficient. |
| go-chi/chi v5 | Good library, but for this scope net/http stdlib covers the routing needs. chi adds value for larger APIs with complex middleware chains, which this is not. |
| zerolog / zap | Unnecessary third-party dep when slog covers the use case. slog handler interface allows future swap if needed. |
| gorilla/mux | Deprecated in favor of stdlib improvements in Go 1.22+. |
### Component 2: MCP Server (TypeScript/Node.js)
#### Runtime & Language
| Technology | Version | Purpose | Why | Confidence |
|------------|---------|---------|-----|------------|
| Node.js | 24.x LTS | Runtime | Current Active LTS (24.14.0 as of March 2026). Long-term support through Oct 2026. The MCP SDK targets Node.js primarily. | HIGH |
| TypeScript | 5.7+ | Language | MCP SDK is TypeScript-first. Type safety critical for tool definitions and schema validation. | HIGH |
#### Core Libraries
| Technology | Version | Purpose | Why | Confidence |
|------------|---------|---------|-----|------------|
| @modelcontextprotocol/sdk | 1.27.x | MCP protocol implementation | Official TypeScript SDK for MCP. v1.27.1 is latest stable. v2 is anticipated Q1 2026 but v1.x is recommended for production. Provides McpServer class, tool/resource registration, stdio + Streamable HTTP transports. | HIGH |
| zod | 4.3.x | Schema validation | Used internally by MCP SDK for tool input validation. v4 is stable with 14x faster string parsing, 2x smaller bundle than v3. Define tool parameter schemas with full TypeScript type inference. | HIGH |
| execa | 9.6.x | Process execution (ADB/xcrun) | Wraps child_process with promise API, proper error handling, automatic cleanup. Use for spawning adb and xcrun commands. Better than raw child_process for TypeScript ergonomics and zombie process prevention. | HIGH |
| sharp | 0.34.x | Screenshot processing | High-perf image processing (resize, compress, convert). Use for processing device screenshots before sending to AI agents. 4-5x faster than jimp, includes TypeScript types. Native dependency via libvips. | MEDIUM |
#### Why NOT These Alternatives
| Library | Why Not |
|---------|---------|
| MCP SDK v2 | Not yet stable. v2 anticipated Q1 2026 but v1.x is the recommended production version. Start with v1.27.x, migrate to v2 when stable. |
| jimp | Pure JS (no native deps) but significantly slower than sharp. Screenshot processing needs to be fast for real-time device automation. |
| child_process (raw) | No automatic cleanup, poor error handling, callback-based API. execa handles all edge cases including Windows shebangs and process cleanup. |
| Appium/WebDriverAgent | Heavy, complex setup. Direct ADB/xcrun commands via execa are simpler and more reliable for the narrow set of operations needed (screenshot, tap, swipe, type, UI dump). |
| @zod/mini | Too minimal for MCP tool schemas. Full zod provides better developer experience with chained validators. |
### Component 3: Flutter Desktop Hub
#### Runtime & Framework
| Technology | Version | Purpose | Why | Confidence |
|------------|---------|---------|-----|------------|
| Flutter | 3.41.x | UI framework | Latest stable (Feb 2026). Desktop support mature since Flutter 3.0 (2022). New multi-window APIs, popup windows, dialog windows for desktop. Cross-platform (Win/Mac/Linux) from single codebase. | HIGH |
| Dart | 3.11.x | Language | Ships with Flutter 3.41. New dot shorthand syntax (.center instead of MainAxisAlignment.center). Mature null-safety. | HIGH |
#### Core Packages
| Technology | Version | Purpose | Why | Confidence |
|------------|---------|---------|-----|------------|
| rxdart | 0.28.x | Reactive streams / state | ReactiveX for Dart. Extends Dart streams with BehaviorSubject, CombineLatest, Debounce, etc. Per project preference, use rxdart for state management over setState. New rxdart_flutter companion package provides ValueStreamBuilder, ValueStreamListener, ValueStreamConsumer widgets. | HIGH |
| rxdart_flutter | 0.0.1+ | Flutter-specific RxDart widgets | Official companion to rxdart with Flutter-specific widgets (ValueStreamBuilder, ValueStreamConsumer, ValueStreamListener). Bridges rxdart streams to Flutter widget tree. | MEDIUM |
| http | latest | HTTP client | Dart's standard HTTP package for communicating with AiBridge CLI's HTTP API. Lightweight, well-tested. | HIGH |
| process_run | latest | Process management | Launch and manage ADB/xcrun/CLI processes from Flutter desktop. Cross-platform process execution. | MEDIUM |
| window_manager | latest | Desktop window control | Window title, size, position, always-on-top. Essential for desktop hub UX. | MEDIUM |
#### Why NOT These Alternatives
| Library | Why Not |
|---------|---------|
| BLoC/Cubit | Project preference is rxdart. BLoC adds boilerplate overhead for what is essentially a device management dashboard, not an enterprise audit-trail app. |
| Riverpod | Good library but project explicitly prefers rxdart for reactive state. Riverpod adds its own paradigm that conflicts with rxdart patterns. |
| Provider | Legacy pattern. rxdart with StreamBuilder/ValueStreamBuilder is more powerful and the project's chosen approach. |
| GetX | Poor separation of concerns, magic string routing. Not suitable for a maintainable open-source project. |
### Component 4: Device Automation Layer
#### Android (ADB)
| Technology | Version | Purpose | Why | Confidence |
|------------|---------|---------|-----|------------|
| ADB (Android Debug Bridge) | Latest (Android SDK Platform-Tools) | Device communication | Standard Android tool for USB/WiFi/emulator communication. Commands for screenshot, UI dump, tap, swipe, type, app management. No alternative needed. | HIGH |
| uiautomator dump | Android built-in | UI tree extraction | `adb shell uiautomator dump` outputs XML accessibility tree of all on-screen elements. Standard approach used by MobAI, mobile-mcp, and all ADB-based automation tools. | HIGH |
| screencap | Android built-in | Screenshot capture | `adb shell screencap -p` captures PNG screenshot. Fast, reliable, no additional tooling needed. | HIGH |
| input | Android built-in | Touch/type simulation | `adb shell input tap x y`, `adb shell input swipe`, `adb shell input text`. Standard input simulation. | HIGH |
#### iOS (Xcode Toolchain)
| Technology | Version | Purpose | Why | Confidence |
|------------|---------|---------|-----|------------|
| xcrun simctl | Xcode 16+ | Simulator control | Apple's official simulator CLI. Boot, shutdown, install apps, screenshots, input. Standard for iOS simulator automation. | HIGH |
| xcrun devicectl | Xcode 16+ | Physical device control | Apple's newer device management CLI replacing older instruments-based approach. Device discovery, app install, diagnostics. | MEDIUM |
| facebook/idb | Latest | Enhanced iOS automation | Facebook's iOS Development Bridge. Extends xcrun capabilities with faster screenshot capture, accessibility tree access, and granular UI interaction commands. Works with both simulators and physical devices. More feature-rich than raw xcrun for automation scenarios. | MEDIUM |
| xcrun xctrace | Xcode 16+ | Device discovery | `xcrun xctrace list devices` for discovering connected devices and their UDIDs. Replaces deprecated `instruments -s devices`. | HIGH |
#### Why NOT These Alternatives
| Tool | Why Not |
|------|---------|
| Appium | Heavy dependency (Java runtime, WebDriverAgent, complex setup). Direct ADB/xcrun commands are simpler, faster, and have fewer failure modes for the specific operations needed. |
| Detox | Testing framework, not a general automation bridge. Wrong abstraction level. |
| mobile-mcp (mobile-next) | Existing MCP server for mobile, but building our own gives full control over the architecture and avoids dependency on their paid tier. Study their tool interface design as reference. |
| Maestro | Testing-focused DSL. Not suitable as a programmable bridge layer. |
## Infrastructure & Tooling
| Category | Tool | Purpose | Why |
|----------|------|---------|-----|
| Build (Go) | `go build` | Compile single binary | Native Go toolchain. CGO_ENABLED=0 for fully static binaries. |
| Build (TS) | `tsx` / `tsc` | TypeScript compilation | tsx for development (fast, no config), tsc for production builds. |
| Package (TS) | npm | Package management | Standard. MCP SDK published on npm. |
| Package (Flutter) | pub | Package management | Standard Flutter/Dart package manager. |
| Linting (Go) | golangci-lint | Code quality | Standard Go linter aggregator. |
| Linting (TS) | ESLint + @typescript-eslint | Code quality | Standard TypeScript linting. |
| Formatting (Go) | gofmt / goimports | Code formatting | Built-in, no config needed. |
| Formatting (TS) | Prettier | Code formatting | Standard TypeScript formatter. |
| Formatting (Dart) | dart format | Code formatting | Built-in, no config needed. |
## Version Summary
| Component | Language/Runtime | Key Dependency | Version |
|-----------|-----------------|----------------|---------|
| AiBridge CLI | Go 1.26 | creack/pty | v1.1.24 |
| AiBridge CLI | Go 1.26 | spf13/cobra | v2.3.0 |
| MCP Server | Node.js 24.x LTS | @modelcontextprotocol/sdk | 1.27.x |
| MCP Server | TypeScript 5.7+ | zod | 4.3.x |
| MCP Server | Node.js 24.x LTS | execa | 9.6.x |
| Hub App | Flutter 3.41.x / Dart 3.11.x | rxdart | 0.28.x |
| Android | ADB (Platform-Tools) | uiautomator | built-in |
| iOS | Xcode 16+ | xcrun simctl/devicectl | built-in |
| iOS | -- | facebook/idb | latest |
## Installation
### Go CLI Setup
# Initialize Go module
# Core dependencies
# Optional (WebSocket)
### MCP Server Setup
# Initialize Node.js project
# Core dependencies
# Dev dependencies
### Flutter Hub Setup
# Create Flutter desktop project
# Add dependencies (in pubspec.yaml)
# rxdart: ^0.28.0
# rxdart_flutter: ^0.0.1
# http: latest
# process_run: latest
# window_manager: latest
## Sources
- [creack/pty GitHub](https://github.com/creack/pty) - v1.1.24 confirmed
- [spf13/cobra GitHub](https://github.com/spf13/cobra) - v2.3.0 for Go 2026
- [MCP TypeScript SDK](https://github.com/modelcontextprotocol/typescript-sdk) - v1.27.1 latest
- [@modelcontextprotocol/sdk npm](https://www.npmjs.com/package/@modelcontextprotocol/sdk) - v1.27.1
- [Go 1.26 Release](https://go.dev/blog/go1.26) - Feb 2026
- [Flutter 3.41 Release](https://blog.flutter.dev/whats-new-in-flutter-3-41-302ec140e632) - Feb 2026
- [Go 1.22 Routing Enhancements](https://go.dev/blog/routing-enhancements) - stdlib HTTP routing
- [coder/websocket](https://github.com/coder/websocket) - Maintained successor to nhooyr/websocket
- [mobile-next/mobile-mcp](https://github.com/mobile-next/mobile-mcp) - Reference MCP mobile automation
- [MobAI AiBridge](https://github.com/MobAI-App/aibridge) - Reference Go PTY wrapper architecture
- [facebook/idb](https://github.com/facebook/idb) - iOS Development Bridge
- [Node.js 24 LTS](https://nodejs.org/en/about/previous-releases) - Active LTS through Oct 2026
- [Zod v4](https://zod.dev/v4) - 14x faster parsing, 2x smaller bundle
- [execa GitHub](https://github.com/sindresorhus/execa) - v9.6.1
- [sharp](https://sharp.pixelplumbing.com/) - v0.34.x high-perf image processing
- [rxdart pub.dev](https://pub.dev/packages/rxdart) - Reactive extensions for Dart
- [Go slog vs zerolog](https://leapcell.io/blog/high-performance-structured-logging-in-go-with-slog-and-zerolog) - stdlib preferred for new projects
<!-- GSD:stack-end -->

<!-- GSD:conventions-start source:CONVENTIONS.md -->
## Conventions

Conventions not yet established. Will populate as patterns emerge during development.
<!-- GSD:conventions-end -->

<!-- GSD:architecture-start source:ARCHITECTURE.md -->
## Architecture

Architecture not yet mapped. Follow existing patterns found in the codebase.
<!-- GSD:architecture-end -->

<!-- GSD:workflow-start source:GSD defaults -->
## GSD Workflow Enforcement

Before using Edit, Write, or other file-changing tools, start work through a GSD command so planning artifacts and execution context stay in sync.

Use these entry points:
- `/gsd:quick` for small fixes, doc updates, and ad-hoc tasks
- `/gsd:debug` for investigation and bug fixing
- `/gsd:execute-phase` for planned phase work

Do not make direct repo edits outside a GSD workflow unless the user explicitly asks to bypass it.
<!-- GSD:workflow-end -->



<!-- GSD:profile-start -->
## Developer Profile

> Profile not yet configured. Run `/gsd:profile-user` to generate your developer profile.
> This section is managed by `generate-claude-profile` -- do not edit manually.
<!-- GSD:profile-end -->
