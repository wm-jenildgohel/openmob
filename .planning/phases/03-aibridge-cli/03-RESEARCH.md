# Phase 3: AiBridge CLI (Go PTY Wrapper) - Research

**Researched:** 2026-03-24
**Domain:** Go CLI / PTY management / HTTP API / idle detection / terminal I/O
**Confidence:** HIGH

## Summary

AiBridge is a standalone Go CLI that wraps terminal AI coding agents (Claude Code, Codex CLI, Gemini CLI) in a pseudo-terminal layer, detects when the agent is idle via regex pattern matching on stripped terminal output, and exposes an HTTP API on localhost for text injection. The reference implementation (github.com/MobAI-App/aibridge, MIT licensed) provides a proven architecture with 5 goroutines (HTTP server, PTY reader, stdin forwarder, idle detector ticker, injection loop) communicating via channels and mutex-protected shared state.

Key corrections from prior research: Cobra v2 does not exist -- the latest stable is v1.10.2 (Dec 2024). The MobAI reference uses Cobra v1.8.0, creack/pty v1.1.21, and Go 1.24. We should use Go 1.26 (latest stable, Feb 2026), creack/pty v1.1.24 (latest, Oct 2024), and Cobra v1.10.2. The reference also uses UserExistsError/conpty for Windows ConPTY support, enabling cross-platform PTY.

**Primary recommendation:** Follow the MobAI reference architecture closely (it is MIT licensed and proven). The core structure is: PTY module (platform-split: pty.go for Unix, pty_windows.go for ConPTY), BusyDetector (100ms tick, 500ms idle threshold, ANSI-stripped regex matching), Queue (FIFO with priority, max 100, sync channel pattern), Bridge (orchestrator wiring PTY + detector + queue + injection loop), HTTP Server (stdlib net/http, 5 endpoints), and Patterns (per-agent regex map with default fallback).

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
All implementation choices are at Claude's discretion -- discuss phase was skipped per user setting.

Key constraints:
- Go 1.22+ with creack/pty for PTY management
- cobra CLI framework for command structure
- stdlib net/http for HTTP server (no third-party router needed)
- Bind to 127.0.0.1:9999 only
- ANSI escape code stripping before regex matching
- Built-in idle patterns for Claude Code, Codex CLI, Gemini CLI
- FIFO injection queue with priority support (max 100 items)
- Reference: github.com/MobAI-App/aibridge (MIT licensed)

### Claude's Discretion
All implementation choices are at Claude's discretion -- discuss phase was skipped per user setting.

### Deferred Ideas (OUT OF SCOPE)
None -- discuss phase skipped.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| BRG-01 | AiBridge wraps any terminal AI agent with a PTY layer | creack/pty v1.1.24 for Unix, conpty for Windows; raw mode via golang.org/x/term; SIGWINCH resize handling |
| BRG-02 | HTTP API on localhost with POST /inject | stdlib net/http with Go 1.22+ method routing; JSON request/response; sync mode via ?sync=true query param |
| BRG-03 | Idle detection via regex-based pattern matching | BusyDetector with 100ms ticker, 500ms idle threshold, ANSI-stripped output, ProcessLine on each PTY read |
| BRG-04 | Built-in idle patterns for Claude Code, Codex CLI, Gemini CLI | Patterns: claude="thinking", codex="esc to interrupt", gemini="esc to cancel"; configurable via --busy-pattern |
| BRG-05 | Injection queue (FIFO) with priority support, max 100 | Mutex-protected slice; priority prepends to head; SyncChan for blocking callers; ErrQueueFull at capacity |
| BRG-06 | GET /health and GET /status endpoints | /health returns {"status":"ok","version":"X.X.X"}; /status returns idle, queue_length, child_running, uptime |
| BRG-07 | --paranoid mode (inject without auto-submit) | Flag controls whether Enter key is sent after text injection; inject-delay configurable between text and Enter |
| BRG-08 | Custom --busy-pattern flag | Overrides built-in patterns; passed as regex string to BusyDetector; takes precedence over auto-detected tool pattern |
| BRG-09 | Synchronous injection with configurable --timeout | ?sync=true on /inject; context.WithTimeout using --timeout value (default 300s); blocks until injection completes or 408 |
| BRG-10 | Bind to 127.0.0.1 only | Hard-coded in server config; --host flag defaults to 127.0.0.1; security-critical, documented in pitfalls |
</phase_requirements>

## Project Constraints (from CLAUDE.md)

- Never waste time creating tests (nyquist_validation is enabled in config.json but CLAUDE.md overrides)
- Do not create unnecessary README files or documentation
- Do not build app until prompted
- Use rxdart instead of setState (Flutter only -- not applicable to this Go phase)

## Standard Stack

### Core

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| Go | 1.26.1 | Language runtime | Latest stable (March 2026). Single binary, excellent concurrency, first-class Unix PTY support. |
| creack/pty | v1.1.24 | Unix PTY management | The standard Go PTY library. Used by MobAI reference, terminal emulators, and most Go PTY wrappers. Latest release (Oct 2024) adds z/OS support. |
| UserExistsError/conpty | v0.1.4 | Windows ConPTY | Windows Pseudo Console API wrapper. Required for Windows support. Used by MobAI reference. |
| spf13/cobra | v1.10.2 | CLI framework | Industry standard for Go CLIs (kubectl, Hugo, gh). v1.10.2 is latest (Dec 2024). NOTE: v2 does NOT exist despite prior research claims. |
| golang.org/x/term | v0.39.0 | Terminal raw mode | Official Go extended library. MakeRaw/Restore for terminal state management. |
| google/uuid | v1.6.0 | UUID generation | For injection queue item IDs. Lightweight, well-maintained. |
| net/http (stdlib) | Go 1.26 | HTTP API server | Go 1.22+ ServeMux supports method-based routing (GET /health, POST /inject). No third-party router needed for 5 endpoints. |
| log/slog (stdlib) | Go 1.26 | Structured logging | Standard library structured logger. JSON output for --verbose mode. |
| regexp (stdlib) | Go 1.26 | Pattern matching | For idle detection regex and ANSI stripping. |

### Supporting

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| spf13/pflag | v1.0.5 | POSIX flag parsing | Comes as Cobra dependency. Handles --flag and -f style flags. |
| encoding/json (stdlib) | Go 1.26 | JSON encoding/decoding | HTTP request/response bodies. |
| os/signal (stdlib) | Go 1.26 | Signal handling | SIGWINCH for PTY resize, SIGINT/SIGTERM for graceful shutdown. |
| context (stdlib) | Go 1.26 | Lifecycle management | Context cancellation for goroutine cleanup, sync injection timeouts. |
| sync (stdlib) | Go 1.26 | Mutex/RWMutex | Thread-safe queue and detector state. |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| stdlib net/http | chi v5 / gin | Overkill for 5 endpoints. stdlib with Go 1.22+ routing covers the need. |
| slog (stdlib) | zerolog / zap | Extra dependency. slog handler interface allows swap later if perf matters. |
| spf13/cobra | urfave/cli/v3 | Cobra is the ecosystem standard. More community support, better docs. |
| Manual ANSI strip | acarl005/stripansi | Inline regex is simpler and avoids a dependency for 3 lines of code. |

**Installation:**
```bash
# Initialize Go module
mkdir openmob_bridge && cd openmob_bridge
go mod init github.com/user/openmob-bridge

# Core dependencies
go get github.com/creack/pty@v1.1.24
go get github.com/UserExistsError/conpty@v0.1.4
go get github.com/spf13/cobra@v1.10.2
go get github.com/google/uuid@v1.6.0
go get golang.org/x/term@latest
```

**Version verification:** creack/pty v1.1.24 confirmed from GitHub releases (Oct 31, 2024). Cobra v1.10.2 confirmed from GitHub releases (Dec 4, 2024). Go 1.26.1 confirmed from go.dev (March 5, 2026).

## Architecture Patterns

### Recommended Project Structure
```
openmob_bridge/
├── cmd/
│   └── aibridge/
│       └── main.go              # Cobra root command, flag parsing, wiring
├── internal/
│   ├── bridge/
│   │   ├── bridge.go            # Bridge orchestrator (wires PTY + detector + queue)
│   │   ├── busy.go              # BusyDetector: idle/busy state, 100ms ticker, 500ms threshold
│   │   ├── pty.go               # Unix PTY: creack/pty, raw mode, SIGWINCH, read/write loops
│   │   ├── pty_windows.go       # Windows PTY: conpty wrapper (build tag: windows)
│   │   ├── queue.go             # FIFO injection queue with priority, max 100, SyncChan
│   │   └── ansi.go              # ANSI escape code stripping (regex-based)
│   ├── server/
│   │   ├── server.go            # HTTP server setup, CORS middleware, routing
│   │   └── handlers.go          # Health, Status, Inject, QueueClear handlers
│   └── patterns/
│       └── patterns.go          # Built-in busy patterns per agent (claude, codex, gemini)
├── go.mod
├── go.sum
├── .goreleaser.yaml             # Release automation (later)
└── .golangci.yml                # Linter config (later)
```

### Pattern 1: Goroutine Architecture (5 concurrent goroutines)

**What:** The bridge runs 5 goroutines communicating via channels and mutex-protected state.

**Architecture:**
```
┌─────────────────────────────────────────────────────────────┐
│ main goroutine                                              │
│  ├── starts PTY (raw mode, SIGWINCH handler)                │
│  ├── starts HTTP server                                     │
│  ├── starts bridge.Start() which spawns:                    │
│  │   ├── G1: PTY Read Loop (reads 4KB buffer, writes stdout)│
│  │   ├── G2: Stdin Forward (io.Copy stdin -> PTY)           │
│  │   ├── G3: Busy Detector Ticker (100ms poll)              │
│  │   └── G4: Injection Loop (waits on injectCh channel)     │
│  ├── G5: HTTP Server (net/http.ListenAndServe)              │
│  └── signal handler (SIGINT/SIGTERM -> graceful shutdown)    │
└─────────────────────────────────────────────────────────────┘
```

**Data flow:**
```
PTY Output ──> G1 (Read Loop) ──> stdout (user sees output)
                    │
                    └──> BusyDetector.ProcessLine(stripped_line)
                              │
                              └──> G3 (Ticker): no output for 500ms? -> idle=true -> onIdle callback
                                                                              │
HTTP POST /inject ──> Queue.Enqueue() ──> NotifyEnqueue() ──> injectCh ──> G4 (Injection Loop)
                                                                              │
                                                              if idle: PTY.InjectText(text)
                                                              if !paranoid: send Enter
                                                              if syncChan: signal completion
```

### Pattern 2: BusyDetector State Machine

**What:** Simple state machine with two states (busy/idle) driven by output timing.

```go
type BusyDetector struct {
    mu          sync.RWMutex
    idle        bool
    lastOutput  time.Time
    pattern     *regexp.Regexp  // busy pattern (when matched = busy)
    onIdle      func()          // callback when transitioning to idle
    idleTimeout time.Duration   // 500ms default
    tickRate    time.Duration   // 100ms default
}

// ProcessLine is called for every line of PTY output (ANSI-stripped)
func (d *BusyDetector) ProcessLine(line string) {
    d.mu.Lock()
    d.idle = false
    d.lastOutput = time.Now()
    d.mu.Unlock()
}

// Background ticker goroutine
func (d *BusyDetector) run(ctx context.Context) {
    ticker := time.NewTicker(d.tickRate)
    defer ticker.Stop()
    for {
        select {
        case <-ctx.Done():
            return
        case <-ticker.C:
            d.mu.Lock()
            if !d.idle && time.Since(d.lastOutput) > d.idleTimeout {
                d.idle = true
                d.mu.Unlock()
                d.onIdle()
            } else {
                d.mu.Unlock()
            }
        }
    }
}
```

**When to use:** This is the core idle detection mechanism. Every PTY read triggers ProcessLine, and the ticker checks if output has gone quiet for 500ms.

### Pattern 3: Non-Blocking Channel Signal for Injection

**What:** The injection loop goroutine sleeps until signaled via a buffered channel with capacity 1.

```go
type Bridge struct {
    injectCh chan struct{} // capacity 1
    queue    *Queue
    pty      *PTY
    detector *BusyDetector
}

// Called by Queue.Enqueue and by BusyDetector.onIdle
func (b *Bridge) NotifyEnqueue() {
    select {
    case b.injectCh <- struct{}{}:
    default: // already signaled, don't block
    }
}

// Injection loop goroutine
func (b *Bridge) injectionLoop(ctx context.Context) {
    for {
        select {
        case <-ctx.Done():
            return
        case <-b.injectCh:
            for b.detector.IsIdle() {
                item := b.queue.Dequeue()
                if item == nil {
                    break
                }
                b.pty.InjectText(item.Text)
                if item.SyncChan != nil {
                    close(item.SyncChan)
                }
            }
        }
    }
}
```

### Pattern 4: PTY Text Injection with Echo Detection

**What:** After writing text to the PTY, wait for the echo before sending Enter.

```go
func (p *PTY) InjectText(text string) error {
    // Write text to PTY stdin
    _, err := p.ptmx.Write([]byte(text))
    if err != nil {
        return err
    }

    if p.paranoid {
        return nil // Don't send Enter in paranoid mode
    }

    // Optional: wait for echo confirmation (last 20 chars)
    // with 2-second timeout before sending Enter
    if p.injectDelayMs > 0 {
        time.Sleep(time.Duration(p.injectDelayMs) * time.Millisecond)
    }

    // Send Enter (carriage return)
    _, err = p.ptmx.Write([]byte("\r"))
    return err
}
```

### Pattern 5: ANSI Stripping Before Pattern Matching

**What:** Strip all ANSI escape sequences from PTY output before feeding to the BusyDetector.

```go
// Comprehensive ANSI escape code regex
// Source: acarl005/stripansi (MIT) -- inlined to avoid dependency
var ansiRegex = regexp.MustCompile(
    `[\x1b\x9b][[\\]()#;?]*(?:(?:(?:[a-zA-Z\d]*(?:;[a-zA-Z\d]*)*)?\x07)|(?:(?:\d{1,4}(?:;\d{0,4})*)?[\dA-PRZcf-ntqry=><~]))`,
)

func StripANSI(s string) string {
    return ansiRegex.ReplaceAllString(s, "")
}
```

**Why this regex:** Handles color codes, cursor movement, window title sequences, and other control sequences. The same pattern used by the widely-adopted stripansi npm and Go packages.

### Pattern 6: HTTP API with Stdlib Routing (Go 1.22+)

**What:** Use Go 1.22+ enhanced ServeMux for method-based routing.

```go
func NewServer(addr string, bridge *Bridge) *Server {
    mux := http.NewServeMux()

    // Go 1.22+ method-based routing
    mux.HandleFunc("GET /health", s.handleHealth)
    mux.HandleFunc("GET /status", s.handleStatus)
    mux.HandleFunc("POST /inject", s.handleInject)
    mux.HandleFunc("DELETE /queue", s.handleQueueClear)

    // CORS middleware wrapper
    handler := corsMiddleware(mux)

    srv := &http.Server{
        Addr:    addr,
        Handler: handler,
    }
    return &Server{srv: srv, bridge: bridge}
}
```

### Anti-Patterns to Avoid

- **Sharing PTY file descriptor across goroutines without coordination:** The PTY master fd is used by read loop, injection, and stdin forward. The read loop and stdin forward use separate directions (read vs write) which is safe. But InjectText must coordinate with stdin forward to avoid interleaved writes. Use a write mutex or a dedicated write channel.

- **Using io.Copy for PTY reading:** io.Copy blocks until EOF. Instead, use a manual read loop with a 4KB buffer so each chunk can be processed by the BusyDetector before being written to stdout.

- **Hardcoding idle patterns:** Always load from the patterns map and allow --busy-pattern override. Agent CLIs update frequently and change their prompts.

- **Forgetting to restore terminal state:** If the program crashes without calling term.Restore(), the user's terminal is left in raw mode. Use defer and also handle signals.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| PTY allocation | Manual ioctl/openpty syscalls | creack/pty | Cross-platform (Linux/macOS/BSD/z/OS), handles platform differences, tested extensively |
| Windows PTY | Manual ConPTY API calls | UserExistsError/conpty | Windows ConPTY API is complex with handle lifecycle management |
| Terminal raw mode | Manual termios manipulation | golang.org/x/term MakeRaw/Restore | Handles all terminal flags correctly, restores on cleanup |
| CLI flag parsing | Manual os.Args parsing | spf13/cobra + pflag | Handles help text, completions, subcommands, flag types |
| UUID generation | crypto/rand + formatting | google/uuid | Standard UUID v4, handles formatting and parsing |
| ANSI stripping | Simple `\x1b\[..m` regex | Comprehensive regex pattern (see Pattern 5) | Simple regex misses cursor movement, window title, and other non-color escape sequences |

## Common Pitfalls

### Pitfall 1: PTY Read/EOF Race Conditions

**What goes wrong:** ptmx.Read() blocks indefinitely or returns unexpected EOF when the child process exits. Goroutines leak because the read loop never terminates. Behavior differs between Linux and macOS.

**Why it happens:** PTY I/O is inherently racy. The kernel PTY buffer has no ordering guarantees. process.Wait() and concurrent reads on the PTY fd create nondeterministic behavior (Go issue #60481).

**How to avoid:**
- Use context.WithCancel wrapping all PTY read loops
- Set a "closed" flag checked on each read iteration
- Use select with a done channel to race between read and process exit
- Send initial SIGWINCH before entering the read loop
- On read error after close flag is set, exit gracefully (don't log as error)

**Warning signs:** Tests pass on Linux but fail on macOS. Agent wrapper works with Claude Code but hangs with Codex CLI. Goroutine count grows over session restarts.

### Pitfall 2: Goroutine and Subprocess Leaks

**What goes wrong:** Each session spawns 5+ goroutines and a child process. Abnormal exit (user kills terminal, agent crashes) leaves zombies.

**Why it happens:** No unified lifecycle management. Goroutines read from channels that never close.

**How to avoid:**
- Use context.Context as the lifecycle owner for every session
- defer chains: close PTY, kill child (SIGTERM then SIGKILL after 5s timeout), cancel context
- Set Setpgid: true in SysProcAttr so killing the group kills all descendants
- Signal handler goroutine cancels context on SIGINT/SIGTERM

**Warning signs:** `ps aux | grep defunct` shows zombie processes. runtime.NumGoroutine() climbs over time.

### Pitfall 3: Idle Detection Fragility Across Agent Updates

**What goes wrong:** Regex patterns break when AI agents update their terminal UI. False positives (inject during thinking) or false negatives (never detect idle).

**Why it happens:** AI agent terminal output is not a stable API. Patterns are brittle against ANSI codes, unicode, dynamic content.

**How to avoid:**
- Strip ALL ANSI sequences before matching (comprehensive regex, not just color codes)
- Make patterns configurable (--busy-pattern flag)
- Use the "quiet output" heuristic: if no output for 500ms, consider potentially idle
- The MobAI reference uses "busy" pattern matching (pattern match = busy, no match for 500ms = idle) rather than "idle" pattern matching -- this is the correct approach
- Log raw + stripped output in verbose mode for debugging

**Warning signs:** Injection works for Claude Code but not Codex. After agent update, injections stop.

### Pitfall 4: Terminal State Not Restored on Crash

**What goes wrong:** If the program panics or is killed before term.Restore() runs, the user's terminal is stuck in raw mode (no echo, no line editing, ^C doesn't work).

**Why it happens:** defer doesn't run on os.Exit() or unrecovered panics.

**How to avoid:**
- Signal handler calls term.Restore() before os.Exit()
- Use a recover() in main with term.Restore()
- Document "reset" command for users (stty sane / reset)
- Consider writing the old terminal state to a temp file for recovery

**Warning signs:** Users report "broken terminal" after crash. Characters don't echo. ^C doesn't work.

### Pitfall 5: Write Interleaving on PTY

**What goes wrong:** Stdin forward goroutine (io.Copy stdin -> PTY) and injection goroutine both write to the same PTY fd simultaneously. Bytes from user typing and injected text intermix.

**Why it happens:** os.File.Write is not atomic for large writes. Two concurrent Write calls can interleave.

**How to avoid:**
- Use a write mutex that both stdin forwarding and injection acquire
- Or: route all writes through a single dedicated goroutine via a channel
- MobAI reference handles this implicitly because the injection only happens when the agent is idle (user is presumably not typing)

**Warning signs:** Garbled text appears in agent input. User's keystrokes mixed with injected context.

### Pitfall 6: Localhost Binding Security

**What goes wrong:** Using `:9999` or `0.0.0.0:9999` instead of `127.0.0.1:9999` exposes the injection API to the network.

**Why it happens:** Many HTTP server examples use `:port` which binds to all interfaces.

**How to avoid:** Hard-code `127.0.0.1` as default. Validate --host flag. Log a warning if non-loopback address is used.

## Code Examples

### Complete PTY Setup (Unix)

```go
// Source: MobAI reference architecture + creack/pty README
func (p *PTY) Start(ctx context.Context) error {
    // Start command with PTY
    ptmx, err := pty.Start(p.cmd)
    if err != nil {
        return fmt.Errorf("failed to start PTY: %w", err)
    }
    p.ptmx = ptmx

    // Handle window resize
    ch := make(chan os.Signal, 1)
    signal.Notify(ch, syscall.SIGWINCH)
    go func() {
        for range ch {
            if err := pty.InheritSize(os.Stdin, ptmx); err != nil {
                slog.Warn("resize failed", "error", err)
            }
        }
    }()
    ch <- syscall.SIGWINCH // Initial resize

    // Set terminal to raw mode
    oldState, err := term.MakeRaw(int(os.Stdin.Fd()))
    if err != nil {
        return fmt.Errorf("failed to set raw mode: %w", err)
    }
    p.oldState = oldState

    // Read loop: PTY -> stdout + BusyDetector
    go p.readLoop(ctx)

    // Stdin forward: user keyboard -> PTY
    go func() {
        io.Copy(ptmx, os.Stdin)
    }()

    return nil
}
```

### HTTP Inject Handler with Sync Mode

```go
// Source: MobAI reference handler pattern
type InjectRequest struct {
    Text     string `json:"text"`
    Priority bool   `json:"priority,omitempty"`
}

type InjectResponse struct {
    ID       string `json:"id"`
    Queued   bool   `json:"queued"`
    Position int    `json:"position"`
}

func (h *Handlers) handleInject(w http.ResponseWriter, r *http.Request) {
    if !h.bridge.IsChildRunning() {
        writeError(w, http.StatusServiceUnavailable, "child process not running")
        return
    }

    var req InjectRequest
    if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
        writeError(w, http.StatusBadRequest, "invalid JSON")
        return
    }
    if req.Text == "" {
        writeError(w, http.StatusBadRequest, "text is required")
        return
    }

    // Check for sync mode
    sync := r.URL.Query().Get("sync") == "true"

    if sync {
        inj, err := h.bridge.Queue().EnqueueWithChan(req.Text, req.Priority)
        if err != nil {
            writeError(w, http.StatusTooManyRequests, "queue full")
            return
        }
        h.bridge.NotifyEnqueue()

        // Block until injection completes or timeout
        ctx, cancel := context.WithTimeout(r.Context(), h.timeout)
        defer cancel()
        select {
        case <-inj.SyncChan:
            writeJSON(w, InjectResponse{ID: inj.ID, Queued: false, Position: 0})
        case <-ctx.Done():
            writeError(w, http.StatusRequestTimeout, "injection timeout")
        }
    } else {
        id, err := h.bridge.Queue().Enqueue(req.Text, req.Priority)
        if err != nil {
            writeError(w, http.StatusTooManyRequests, "queue full")
            return
        }
        h.bridge.NotifyEnqueue()
        writeJSON(w, InjectResponse{ID: id, Queued: true, Position: h.bridge.Queue().Len()})
    }
}
```

### Cobra Command Setup

```go
// Source: Cobra v1.10.x standard pattern
var rootCmd = &cobra.Command{
    Use:   "aibridge [flags] -- <command> [args...]",
    Short: "Wrap AI coding agents with context injection",
    Long:  `AiBridge wraps terminal AI agents with a PTY layer and HTTP API for context injection.`,
    Args:  cobra.MinimumNArgs(1),
    RunE:  run,
}

func init() {
    rootCmd.Flags().IntVarP(&flagPort, "port", "p", 9999, "HTTP server port")
    rootCmd.Flags().StringVar(&flagHost, "host", "127.0.0.1", "HTTP server bind address")
    rootCmd.Flags().StringVar(&flagBusyPattern, "busy-pattern", "", "Custom regex for busy detection")
    rootCmd.Flags().IntVarP(&flagTimeout, "timeout", "t", 300, "Sync injection timeout (seconds)")
    rootCmd.Flags().BoolVarP(&flagVerbose, "verbose", "v", false, "Enable debug logging")
    rootCmd.Flags().BoolVar(&flagParanoid, "paranoid", false, "Inject text without auto-submit")
    rootCmd.Flags().IntVar(&flagInjectDelay, "inject-delay", 50, "Delay (ms) between text and Enter")
    rootCmd.Flags().BoolVar(&flagVersion, "version", false, "Print version")
}
```

### Built-in Agent Patterns

```go
// Source: MobAI reference patterns.go
package patterns

type Pattern struct {
    Regex string
}

// BuiltinPatterns maps tool names to their busy-detection regex.
// When the pattern matches recent output, the agent is BUSY.
// When no match for 500ms, the agent is IDLE.
var BuiltinPatterns = map[string]Pattern{
    "claude": {Regex: `thinking`},       // Claude Code shows "thinking" while processing
    "codex":  {Regex: `esc to interrupt`}, // Codex shows "esc to interrupt" while running
    "gemini": {Regex: `esc to cancel`},    // Gemini shows "esc to cancel" while running
}

// DefaultPattern is used when no tool-specific pattern matches.
var DefaultPattern = Pattern{Regex: `esc to interrupt`}

// GetPattern resolves a pattern by tool name.
func GetPattern(toolName string) *Pattern {
    if p, ok := BuiltinPatterns[toolName]; ok {
        return &p
    }
    return nil
}
```

### Queue with Priority and Sync Channel

```go
// Source: MobAI reference queue.go pattern
const MaxQueueSize = 100

var ErrQueueFull = errors.New("queue full")

type Injection struct {
    ID       string
    Text     string
    Priority bool
    SyncChan chan struct{} // nil for async, non-nil for sync
}

type Queue struct {
    mu    sync.Mutex
    items []*Injection
}

func (q *Queue) Enqueue(text string, priority bool) (string, error) {
    q.mu.Lock()
    defer q.mu.Unlock()
    if len(q.items) >= MaxQueueSize {
        return "", ErrQueueFull
    }
    inj := &Injection{ID: uuid.New().String(), Text: text, Priority: priority}
    if priority {
        q.items = append([]*Injection{inj}, q.items...)
    } else {
        q.items = append(q.items, inj)
    }
    return inj.ID, nil
}

func (q *Queue) EnqueueWithChan(text string, priority bool) (*Injection, error) {
    q.mu.Lock()
    defer q.mu.Unlock()
    if len(q.items) >= MaxQueueSize {
        return nil, ErrQueueFull
    }
    inj := &Injection{
        ID:       uuid.New().String(),
        Text:     text,
        Priority: priority,
        SyncChan: make(chan struct{}),
    }
    if priority {
        q.items = append([]*Injection{inj}, q.items...)
    } else {
        q.items = append(q.items, inj)
    }
    return inj, nil
}

func (q *Queue) Dequeue() *Injection {
    q.mu.Lock()
    defer q.mu.Unlock()
    if len(q.items) == 0 {
        return nil
    }
    item := q.items[0]
    q.items = q.items[1:]
    return item
}
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| gorilla/websocket | coder/websocket (if WS needed) | 2022 (gorilla archived) | Do not use gorilla -- it is unmaintained |
| net/http manual routing | net/http method-based routing | Go 1.22 (Feb 2024) | "GET /path" syntax in HandleFunc, no third-party router needed |
| cobra v1.8 | cobra v1.10.2 | Dec 2024 | Minor improvements, no v2 exists |
| creack/pty v1.1.21 | creack/pty v1.1.24 | Oct 2024 | z/OS support, race condition fixes |
| zap / zerolog | log/slog (stdlib) | Go 1.21 (Aug 2023) | stdlib structured logging, no dependency |

**Deprecated/outdated:**
- gorilla/websocket: Archived since late 2022. Use coder/websocket if WebSocket is needed.
- gorilla/mux: Unnecessary since Go 1.22+ stdlib routing.
- Cobra v2: Does not exist. Prior STACK.md incorrectly stated "v2.3.0" -- this version was fabricated. Latest is v1.10.2.

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Go runtime | All code | NOT INSTALLED | -- | Install via `snap install go --classic` or download from go.dev/dl |
| curl/wget | Go install | YES | curl available | -- |
| git | Module management | VERIFY | -- | Required for go get |

**Missing dependencies with no fallback:**
- Go runtime: MUST be installed before any development. `snap install go --classic` or download from https://go.dev/dl/

**Missing dependencies with fallback:**
- None -- Go is the only external dependency and it is mandatory.

## Open Questions

1. **Windows ConPTY testing**
   - What we know: MobAI uses UserExistsError/conpty for Windows. The ConPTY API is available since Windows 10 1809.
   - What's unclear: Whether the user needs Windows support now or can defer it.
   - Recommendation: Include pty_windows.go with build tag but defer testing until specifically needed. The project README says "works on Windows, macOS, and Linux" so Windows support should be in the architecture from the start.

2. **Claude Code "thinking" pattern accuracy**
   - What we know: MobAI uses `thinking` as the busy pattern for Claude Code. Claude Code shows "Esc to interrupt" during processing but also "thinking" text.
   - What's unclear: Whether "thinking" alone is sufficient or if "Esc to interrupt" is more reliable across Claude Code versions.
   - Recommendation: Start with the MobAI reference patterns. Make them easily updatable. Log pattern match/miss rates in verbose mode so users can tune.

3. **Inject delay tuning**
   - What we know: MobAI has a --inject-delay flag (ms between text write and Enter send). Default appears to be around 50ms.
   - What's unclear: Optimal delay per agent. Too fast and the agent may not process the text. Too slow and it feels laggy.
   - Recommendation: Default 50ms, configurable per-user. Document that this may need tuning per agent.

## Sources

### Primary (HIGH confidence)
- [MobAI AiBridge GitHub](https://github.com/MobAI-App/aibridge) - Full reference implementation (MIT licensed), go.mod, architecture, patterns, handlers
- [creack/pty GitHub](https://github.com/creack/pty) - API docs, v1.1.24 release confirmed
- [creack/pty releases](https://github.com/creack/pty/releases) - v1.1.24 = Oct 31, 2024
- [spf13/cobra releases](https://github.com/spf13/cobra/releases) - v1.10.2 = Dec 4, 2024 (NO v2 exists)
- [Go 1.26 release blog](https://go.dev/blog/go1.26) - Feb 2026, confirmed 1.26.1 March 2026
- [Go 1.22 routing enhancements](https://go.dev/blog/routing-enhancements) - Method-based ServeMux routing
- [golang.org/x/term pkg.go.dev](https://pkg.go.dev/golang.org/x/term) - MakeRaw/Restore API

### Secondary (MEDIUM confidence)
- [acarl005/stripansi](https://github.com/acarl005/stripansi) - Comprehensive ANSI regex pattern source
- [UserExistsError/conpty](https://github.com/UserExistsError/conpty) - Windows ConPTY wrapper
- [Claude Code issue #12048](https://github.com/anthropics/claude-code/issues/12048) - Idle notification patterns
- [Gemini CLI issue #3617](https://github.com/google-gemini/gemini-cli/issues/3617) - "Awaiting Further Direction" idle state

### Tertiary (LOW confidence)
- [fearlessdots/ptywrapper](https://github.com/fearlessdots/ptywrapper) - PTY wrapper goroutine pattern reference
- [NTM project](https://github.com/Dicklesworthstone/ntm) - Multi-agent orchestration (referenced in pitfalls but no specific technical detail extracted)

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - Verified all versions against official releases. Corrected Cobra version from fabricated v2.3.0 to actual v1.10.2.
- Architecture: HIGH - Based on MIT-licensed reference implementation (MobAI) with full source analysis.
- Pitfalls: HIGH - Documented in creack/pty issues, Go issue tracker, and confirmed by reference implementation patterns.
- Idle detection patterns: MEDIUM - Patterns from MobAI reference are functional but may need updating as agents evolve.

**Research date:** 2026-03-24
**Valid until:** 2026-04-24 (30 days -- stable domain, library versions unlikely to change)
