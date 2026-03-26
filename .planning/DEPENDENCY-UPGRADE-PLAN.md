# OpenMob Dependency Upgrade Plan

> Generated: 2026-03-26
> Scope: All three components + CI/CD pipeline

---

## Summary

1. **[High] Rust AiBridge has a deprecated dependency (`atty`)** that must be replaced with `is-terminal`. The `portable-pty` crate has a minor version bump (0.8 -> 0.9) and `crossterm` went from 0.28 to 0.29.
2. **[High] MCP Server is pinned to Zod v3** while the SDK now supports Zod v4, which is 14x faster. TypeScript 6.0 is available but migration requires care due to new strict defaults.
3. **[High] Flutter Hub is on 3.29.3** while 3.41.x is the latest stable, bringing multi-window APIs and Dart 3.11 dot shorthand syntax. No major breaking changes for most apps.
4. **[High] CI/CD GitHub Actions are outdated** -- checkout@v4 should be v6, setup-node@v4 should be v6, and Node target should be 24 not 22.

---

## 1. Flutter Hub (openmob_hub)

### Flutter SDK & Dart

| Dependency | Current | Latest | Delta | Upgrade? |
|------------|---------|--------|-------|----------|
| Flutter SDK (CI) | 3.29.3 | **3.41.5** | Major | YES |
| Dart SDK constraint | ^3.5.0 | **^3.11.0** | Major | YES |

**Breaking changes (3.29 -> 3.41):**
- Semantics matchers renamed in tests (auto-fixable via `dart fix --apply`)
- Linux threading change (default since 3.39)
- iOS UIScene lifecycle now default
- Android Gradle Plugin 9 support in progress (not relevant for desktop-only)

**Performance:** Dart 3.11 includes dot shorthand syntax, improved AOT compilation, faster hot reload.

**Recommendation:** Upgrade. Run `dart fix --apply` after bumping. Desktop-only project minimizes risk.

### Pub Dependencies

| Package | Current | Latest | Breaking? | Upgrade? |
|---------|---------|--------|-----------|----------|
| rxdart | ^0.28.0 | **0.28.0** | No | CURRENT |
| rxdart_flutter | ^0.0.2 | **0.0.2** | No | CURRENT |
| http | ^1.4.0 | **1.6.0** | No | YES (minor) |
| shelf | ^1.4.2 | **1.4.2** | No | CURRENT |
| shelf_router | ^1.1.4 | **1.1.4** | No | CURRENT |
| xml | ^6.0.0 | **6.6.1** | No | YES (minor) |
| window_manager | ^0.5.1 | **0.5.1** | No | CURRENT |
| url_launcher | ^6.3.2 | **6.3.2** | No | CURRENT |

**Action items:**
1. Update `pubspec.yaml` environment SDK constraint to `^3.11.0`
2. Update CI `FLUTTER_VERSION` from `3.29.3` to `3.41.5`
3. Bump `http` constraint to `^1.6.0` (non-breaking, gains performance fixes)
4. Bump `xml` constraint to `^6.6.0` (non-breaking)
5. Run `flutter pub upgrade` and `dart fix --apply`

---

## 2. Rust AiBridge (openmob_bridge)

### Rust Toolchain

| Item | Current | Latest | Upgrade? |
|------|---------|--------|----------|
| Rust stable | (whatever CI resolves) | **1.94.0** | Auto via dtolnay/rust-toolchain@stable |
| Edition | 2021 | 2024 available | OPTIONAL (consider later) |

### Cargo Dependencies

| Crate | Current | Latest | Breaking? | Upgrade? |
|-------|---------|--------|-----------|----------|
| portable-pty | "0.8" | **0.9.0** | YES (minor API) | YES |
| clap | "4" | **4.6.0** | No (semver) | YES (auto) |
| axum | "0.8" | **0.8.8** | No (patch) | YES (auto) |
| tokio | "1" | **1.50.0** | No (semver) | YES (auto) |
| crossterm | "0.28" | **0.29.0** | YES (minor) | YES |
| tower-http | "0.6" | **0.6.8** | No (patch) | YES (auto) |
| serde | "1" | **1.0.228** | No (semver) | YES (auto) |
| serde_json | "1" | **1.0.149** | No (semver) | YES (auto) |
| regex | "1" | **1.12.2** | No (semver) | YES (auto) |
| anyhow | "1" | **1.0.100** | No (semver) | YES (auto) |
| uuid | "1" | **1.22.0** | No (semver) | YES (auto) |
| tokio-util | "0.7" | **0.7.18** | No (patch) | YES (auto) |
| terminal_size | "0.4" | **0.4.2** | No (patch) | YES (auto) |
| strip-ansi-escapes | "0.2" | **0.2.1** | No (patch) | YES (auto) |
| which | "7" | **7.x** | No | CURRENT |
| **atty** | **"0.2"** | **DEPRECATED** | N/A | **REMOVE** |

### Critical: Replace `atty` with `is-terminal`

The `atty` crate has not been updated in ~6 years and is officially deprecated. Replace with `is-terminal` v0.4.17.

**Migration:**
```rust
// Before (atty)
use atty::Stream;
if atty::is(Stream::Stdout) { ... }

// After (is-terminal)
use std::io::IsTerminal;
if std::io::stdout().is_terminal() { ... }
```

Note: `IsTerminal` is in Rust stdlib since 1.70.0, so you may not even need the `is-terminal` crate -- just use `std::io::IsTerminal` directly.

### portable-pty 0.8 -> 0.9

Version 0.9.0 was released ~1 year ago. The crate is part of the wezterm project. Changelog not publicly documented in detail, but API surface is small. Test after bump.

### crossterm 0.28 -> 0.29

Minor version bump. Ratatui supports both 0.28 and 0.29 as separate features, indicating some API changes. Test terminal handling after bump.

**Action items:**
1. Remove `atty = "0.2"` from Cargo.toml
2. Replace all `atty` usage with `std::io::IsTerminal` (stdlib, no crate needed)
3. Bump `portable-pty` to `"0.9"`
4. Bump `crossterm` to `"0.29"`
5. Run `cargo update` to pull latest patch versions of all other deps
6. Run `cargo clippy` and fix any new warnings

---

## 3. TypeScript MCP Server (openmob_mcp)

### Runtime

| Item | Current | Latest | Upgrade? |
|------|---------|--------|----------|
| Node.js target | 22 (in CI) | **24.x LTS** | YES |
| Node.js (esbuild target) | node20 | **node24** | YES |

### NPM Dependencies

| Package | Current | Latest | Breaking? | Upgrade? |
|---------|---------|--------|-----------|----------|
| @modelcontextprotocol/sdk | ^1.27.0 | **1.28.0** | No (minor) | YES |
| zod | ^3.24.0 | **4.3.6** | YES (major) | YES (see notes) |
| typescript | ^5.7.0 | **6.0.0** | YES (major) | DEFER |
| @types/node | ^22.0.0 | **25.4.0** | YES (major) | YES |
| tsx | ^4.21.0 | **4.21.0** | No | CURRENT |

### Zod v3 -> v4 Migration

**Key facts:**
- Zod v4 is 14.71x faster string parsing, 2x smaller bundle
- MCP SDK 1.28 now supports Zod v4 internally (imports from `zod/v4`)
- There were compatibility issues (SDK issue #925, #1429) that have been resolved
- Migration path: Zod v4 is available at `zod/v4` subpath alongside v3

**Migration approach:**
1. First bump `@modelcontextprotocol/sdk` to `^1.28.0`
2. Then upgrade `zod` to `^4.3.0`
3. Update tool schema definitions -- most changes are in error customization APIs
4. Test all MCP tools thoroughly

**Breaking changes in Zod v4:**
- Error customization APIs changed
- String format validators changed
- Record schema updates
- `z.object()` strict by default (use `z.looseObject()` for old behavior)

### TypeScript 5.7 -> 6.0

**Recommendation: DEFER to a separate PR.**

TypeScript 6.0 is the last JS-based compiler before TS 7.0 (Go-native). Key breaking changes:
- `strict: true` is now default (project likely already has this)
- `module: esnext` and `target: es2025` are new defaults
- `esModuleInterop` behavior change in emit
- Deprecates `moduleResolution: node` (use `node16` or `nodenext`)

This is a significant migration. A `ts5to6` tool exists. Do this as a separate task.

### node-fetch

**Not needed.** Node.js 22+ (and 24 LTS) have stable built-in `fetch()` based on Undici. If `node-fetch` is not in package.json (it isn't), no action needed.

**Action items:**
1. Bump `@modelcontextprotocol/sdk` to `^1.28.0`
2. Upgrade `zod` from `^3.24.0` to `^4.3.0` and update schemas
3. Bump `@types/node` to `^24.0.0` (match Node 24 LTS)
4. Update esbuild target from `node20` to `node24` in package.json scripts
5. Update CI `NODE_VERSION` from `22` to `24`
6. Update pkg targets from `node20-*` to `node24-*`
7. DEFER TypeScript 6.0 upgrade to a separate effort

---

## 4. CI/CD Pipeline (release.yml)

### GitHub Actions

| Action | Current | Latest | Breaking? | Upgrade? |
|--------|---------|--------|-----------|----------|
| actions/checkout | **@v4** | **@v6** | YES | YES |
| actions/setup-node | **@v4** | **@v6** | YES | YES |
| actions/upload-artifact | @v4 | @v4 | No | CURRENT |
| actions/download-artifact | @v4 | @v4 | No | CURRENT |
| subosito/flutter-action | @v2 | **@v2** (2.15.0) | No | CURRENT |
| dtolnay/rust-toolchain | @stable | @stable | No | CURRENT |
| softprops/action-gh-release | @v2 | **@v2** (2.5.0) | No | CURRENT |

### checkout@v4 -> @v6

- v6 uses Node 24 runtime (v4 uses Node 20 which is being deprecated)
- Requires Actions Runner v2.329.0+
- Credentials now stored under `$RUNNER_TEMP` instead of local git config
- `github-hosted` runners already support this

### setup-node@v4 -> @v6

- v6 uses Node 24 runtime
- Requires runner v2.327.1+
- Supports `lts/*`, `latest`, `nightly`, `canary` aliases

### Environment Variables

| Variable | Current | New |
|----------|---------|-----|
| FLUTTER_VERSION | '3.29.3' | '3.41.5' |
| NODE_VERSION | '22' | '24' |

### Build Targets

| Item | Current | New |
|------|---------|-----|
| esbuild --target | node20 | node24 |
| @yao-pkg/pkg --target | node20-linux-x64, etc. | node24-linux-x64, etc. |

**Action items:**
1. Replace `actions/checkout@v4` with `actions/checkout@v6`
2. Replace `actions/setup-node@v4` with `actions/setup-node@v6`
3. Update `FLUTTER_VERSION` to `3.41.5`
4. Update `NODE_VERSION` to `24`
5. Update all `--target node20` to `--target node24` in build scripts

---

## Execution Order

Upgrades should be done in this order to minimize risk:

### Phase 1: Low-risk patches (1 PR)
- [ ] Cargo.toml: Remove `atty`, use `std::io::IsTerminal`
- [ ] Cargo.toml: Bump `crossterm` to `"0.29"`
- [ ] Cargo.toml: Bump `portable-pty` to `"0.9"`
- [ ] Run `cargo update` for all patch bumps
- [ ] Run `cargo clippy`, fix warnings

### Phase 2: Flutter upgrade (1 PR)
- [ ] Update CI `FLUTTER_VERSION` to `3.41.5`
- [ ] Update `pubspec.yaml` SDK constraint to `^3.11.0`
- [ ] Bump `http` to `^1.6.0`, `xml` to `^6.6.0`
- [ ] Run `flutter pub upgrade`
- [ ] Run `dart fix --apply`
- [ ] Smoke test Hub on Linux desktop

### Phase 3: MCP + CI modernization (1 PR)
- [ ] Bump `@modelcontextprotocol/sdk` to `^1.28.0`
- [ ] Migrate `zod` from v3 to v4 (`^4.3.0`)
- [ ] Bump `@types/node` to `^24.0.0`
- [ ] Update CI: checkout@v6, setup-node@v6
- [ ] Update CI: NODE_VERSION to 24
- [ ] Update build targets: node20 -> node24
- [ ] Test all MCP tools (screenshot, tap, swipe, type, ui_dump)

### Phase 4: TypeScript 6.0 (separate future PR)
- [ ] Install `typescript@6`
- [ ] Run `ts5to6` migration tool
- [ ] Update tsconfig.json for new defaults
- [ ] Test compilation and runtime behavior

---

## Risk Assessment

| Change | Risk | Mitigation |
|--------|------|------------|
| atty -> IsTerminal | LOW | stdlib replacement, trivial |
| portable-pty 0.8 -> 0.9 | MEDIUM | Test PTY spawn/read/write |
| crossterm 0.28 -> 0.29 | LOW | Minor API, compile will catch |
| Flutter 3.29 -> 3.41 | LOW | Desktop-only, no mobile concerns |
| Zod v3 -> v4 | MEDIUM | Schema changes needed, test all tools |
| MCP SDK 1.27 -> 1.28 | LOW | Patch-level, OAuth fixes only |
| TypeScript 5.7 -> 6.0 | HIGH | New defaults, emit changes, defer |
| GitHub Actions v4 -> v6 | LOW | Runner version requirement only concern |
| Node 22 -> 24 | LOW | LTS to LTS, stable APIs |

---

## Sources

- [rxdart - pub.dev](https://pub.dev/packages/rxdart) - v0.28.0
- [rxdart_flutter - pub.dev](https://pub.dev/packages/rxdart_flutter) - v0.0.2
- [http - pub.dev](https://pub.dev/packages/http) - v1.6.0
- [shelf - pub.dev](https://pub.dev/packages/shelf) - v1.4.2
- [shelf_router - pub.dev](https://pub.dev/packages/shelf_router) - v1.1.4
- [xml - pub.dev](https://pub.dev/packages/xml) - v6.6.1
- [window_manager - pub.dev](https://pub.dev/packages/window_manager) - v0.5.1
- [url_launcher - pub.dev](https://pub.dev/packages/url_launcher) - v6.3.2
- [Flutter 3.41 announcement](https://blog.flutter.dev/whats-new-in-flutter-3-41-302ec140e632)
- [Dart SDK archive](https://dart.dev/get-dart/archive) - Dart 3.11.x
- [portable-pty - crates.io](https://crates.io/crates/portable-pty) - v0.9.0
- [clap - crates.io](https://crates.io/crates/clap) - v4.6.0
- [axum - crates.io](https://crates.io/crates/axum) - v0.8.8
- [tokio - crates.io](https://crates.io/crates/tokio) - v1.50.0
- [crossterm - crates.io](https://crates.io/crates/crossterm) - v0.29.0
- [tower-http - crates.io](https://crates.io/crates/tower-http) - v0.6.8
- [serde - crates.io](https://crates.io/crates/serde) - v1.0.228
- [serde_json - crates.io](https://crates.io/crates/serde_json) - v1.0.149
- [regex - crates.io](https://crates.io/crates/regex) - v1.12.2
- [anyhow - crates.io](https://crates.io/crates/anyhow) - v1.0.100
- [uuid - crates.io](https://crates.io/crates/uuid) - v1.22.0
- [is-terminal - crates.io](https://crates.io/crates/is-terminal) - v0.4.17 (atty replacement)
- [@modelcontextprotocol/sdk - npm](https://www.npmjs.com/package/@modelcontextprotocol/sdk) - v1.28.0
- [MCP TS SDK releases](https://github.com/modelcontextprotocol/typescript-sdk/releases) - v1.28.0
- [Zod v4 release notes](https://zod.dev/v4) - v4.3.6
- [TypeScript 6.0 announcement](https://devblogs.microsoft.com/typescript/announcing-typescript-6-0/) - v6.0.0
- [esbuild - npm](https://www.npmjs.com/package/esbuild) - v0.27.4
- [tsx - npm](https://www.npmjs.com/package/tsx) - v4.21.0
- [@types/node - npm](https://www.npmjs.com/package/@types/node) - v25.4.0
- [Node.js 24.14.0 LTS](https://nodejs.org/en/blog/release/v24.14.0)
- [Rust 1.94.0](https://blog.rust-lang.org/releases/latest/)
- [actions/checkout releases](https://github.com/actions/checkout/releases) - v6.0.2
- [actions/setup-node](https://github.com/actions/setup-node) - v6
- [subosito/flutter-action](https://github.com/subosito/flutter-action) - v2.15.0
- [dtolnay/rust-toolchain](https://github.com/dtolnay/rust-toolchain) - @stable
- [softprops/action-gh-release](https://github.com/softprops/action-gh-release) - v2.5.0
- [Axum 0.8.0 announcement](https://tokio.rs/blog/2025-01-01-announcing-axum-0-8-0)
- [MCP SDK Zod v4 compatibility issue](https://github.com/modelcontextprotocol/typescript-sdk/issues/925)
