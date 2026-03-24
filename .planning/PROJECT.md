# OpenMob

## What This Is

OpenMob is a free, self-hosted, open-source alternative to MobAI that gives AI coding agents the ability to see and control mobile devices. It consists of three core components: a Go-based AiBridge CLI that wraps terminal AI agents with a PTY layer and HTTP API for context injection, an MCP server for mobile device automation, and a Flutter Desktop hub app for device management and bridge control. It supports Android and iOS devices via USB, WiFi, and emulator/simulator connections.

## Core Value

AI coding agents can see what's on a mobile device screen and interact with it programmatically — no quotas, no limits, completely self-hosted.

## Requirements

### Validated

(None yet — ship to validate)

### Active

- [ ] AiBridge CLI wraps terminal AI agents (Claude Code, Codex, Gemini CLI) with PTY and exposes HTTP API for context injection
- [ ] MCP server exposes mobile device automation tools (screenshot, UI tree, tap, swipe, type, launch app)
- [ ] Flutter Desktop hub manages connected devices, starts/stops bridges, and provides device overview
- [ ] Android device automation via ADB (USB + WiFi + emulator)
- [ ] iOS device automation via Xcode instruments (USB + simulator)
- [ ] Idle detection for supported AI agents (regex-based pattern matching)
- [ ] Injection queue with priority support for context delivery
- [ ] Web automation support for mobile browsers and WebViews
- [ ] Self-hosted with zero cloud dependency — everything runs locally
- [ ] No quotas, no daily limits, unlimited devices

### Out of Scope

- Browser extension (ContextBox-like) — not selected for v1, can add later
- AI test generation / .mob DSL — MobAI proprietary feature, out of scope
- Cloud/SaaS deployment — contradicts self-hosted differentiator
- App Store screenshot automation — growth feature, not core

## Context

- MobAI (mobai.run) is the commercial reference product with free tier limits (100 points/day, 1 device)
- AiBridge repo (github.com/MobAI-App/aibridge) is MIT licensed Go project — can study architecture
- MCP (Model Context Protocol) is the standard for AI tool integration — supported by Cursor, Claude Desktop, Windsurf, VS Code
- The Go PTY wrapper pattern (creack/pty + cobra CLI) is well-established
- ADB (Android Debug Bridge) provides programmatic device control on Android
- Xcode instruments / xcrun provide iOS device automation
- Flutter Desktop supports Windows, macOS, and Linux from a single codebase

## Constraints

- **Tech Stack**: AiBridge CLI in Go (matches reference), MCP server in TypeScript (Node.js), Hub in Flutter Desktop — proven stack per component
- **Self-hosted**: No external API calls, no telemetry, no license validation — runs fully offline
- **Security**: Localhost-only HTTP binding by default, no authentication needed for local dev
- **Compatibility**: Must work with Claude Code, Codex CLI, Gemini CLI, and any MCP-compatible client

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Go for AiBridge CLI | Matches reference implementation, excellent PTY support, single binary distribution | — Pending |
| Flutter Desktop for Hub | Cross-platform desktop from single codebase, user's expertise | — Pending |
| TypeScript for MCP Server | MCP SDK is TypeScript-first, matches reference mobai-mcp | — Pending |
| No browser extension in v1 | Focus on core mobile automation flow first | — Pending |
| Self-hosted only | Key differentiator vs MobAI's quota-based model | — Pending |

## Evolution

This document evolves at phase transitions and milestone boundaries.

**After each phase transition** (via `/gsd:transition`):
1. Requirements invalidated? → Move to Out of Scope with reason
2. Requirements validated? → Move to Validated with phase reference
3. New requirements emerged? → Add to Active
4. Decisions to log? → Add to Key Decisions
5. "What This Is" still accurate? → Update if drifted

**After each milestone** (via `/gsd:complete-milestone`):
1. Full review of all sections
2. Core Value check — still the right priority?
3. Audit Out of Scope — reasons still valid?
4. Update Context with current state

---
*Last updated: 2026-03-24 after initialization*
