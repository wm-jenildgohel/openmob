# openmob-bridge (AiBridge)

Wrap terminal AI agents (Claude Code, Codex, Gemini CLI) with a PTY layer and HTTP injection API.

Part of [OpenMob](https://github.com/wm-jenildgohel/openmob) — free, open-source mobile device automation for AI agents.

## Install

```bash
cargo install openmob-bridge
```

## Usage

```bash
# Wrap Claude Code
aibridge -- claude

# Wrap Codex CLI
aibridge -- codex

# Wrap Gemini CLI
aibridge -- gemini

# Custom port and paranoid mode (review before submit)
aibridge --port 9999 --paranoid -- claude
```

## HTTP API

Once running, AiBridge exposes these endpoints on `127.0.0.1:9999`:

| Method | Endpoint | Description |
|--------|----------|-------------|
| `POST` | `/inject` | Inject text into the AI agent when idle |
| `GET` | `/health` | Health check |
| `GET` | `/status` | Agent status (idle/busy, queue depth, uptime) |
| `DELETE` | `/queue` | Clear injection queue |

### Inject text

```bash
curl -X POST http://127.0.0.1:9999/inject \
  -H "Content-Type: application/json" \
  -d '{"text": "look at the device screenshot and fix the layout bug"}'
```

## Options

| Flag | Default | Description |
|------|---------|-------------|
| `--port` | `9999` | HTTP server port |
| `--host` | `127.0.0.1` | Bind address (localhost only) |
| `--paranoid` | `false` | Inject text without pressing Enter |
| `--busy-pattern` | auto | Custom regex for idle detection |
| `--timeout` | `300` | Sync injection timeout (seconds) |
| `--inject-delay` | `50` | Delay (ms) between text and Enter |
| `--verbose` | `false` | Debug logging |

## How It Works

```
You (terminal) ←→ AiBridge (PTY) ←→ AI Agent (claude/codex/gemini)
                       ↑
                  HTTP API (:9999)
                       ↑
              OpenMob Hub / MCP Server
              (injects device context)
```

AiBridge wraps the AI agent in a pseudo-terminal, monitors output for idle patterns, and delivers queued context when the agent is ready.

## License

MIT
