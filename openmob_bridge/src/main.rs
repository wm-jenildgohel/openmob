mod ansi;
mod bridge;
mod busy_detector;
mod handlers;
mod patterns;
mod pty_handler;
mod queue;
mod server;

use bridge::Bridge;
use clap::Parser;
use server::AppState;
use std::sync::Arc;
use std::time::Duration;

const VERSION: &str = env!("CARGO_PKG_VERSION");

/// AiBridge - Wrap terminal AI agents with PTY layer and HTTP injection API
#[derive(Parser, Debug)]
#[command(name = "aibridge", version = VERSION, about = "Wrap AI coding agents with context injection")]
struct Cli {
    /// The wrapped command and its arguments (e.g., claude, codex, gemini)
    #[arg(trailing_var_arg = true, required = true)]
    command: Vec<String>,

    /// HTTP server port
    #[arg(short, long, default_value = "9999")]
    port: u16,

    /// HTTP server bind address
    #[arg(long, default_value = "127.0.0.1")]
    host: String,

    /// Custom regex for busy detection (overrides auto-detect)
    #[arg(long)]
    busy_pattern: Option<String>,

    /// Sync injection timeout in seconds
    #[arg(short, long, default_value = "300")]
    timeout: u64,

    /// Enable debug logging
    #[arg(short, long)]
    verbose: bool,

    /// Inject text without auto-submitting (no Enter key sent)
    #[arg(long)]
    paranoid: bool,

    /// Delay in ms between injected text and Enter key
    #[arg(long, default_value = "50")]
    inject_delay: u64,
}

/// RAII guard that restores terminal state on drop (even on panic).
/// This is a top-level guard separate from the one inside Bridge::run()
/// to ensure terminal is never left in raw mode.
struct TerminalRestoreGuard;

impl Drop for TerminalRestoreGuard {
    fn drop(&mut self) {
        let _ = crossterm::terminal::disable_raw_mode();
    }
}

#[tokio::main]
async fn main() {
    let cli = Cli::parse();

    // Validate command is not empty (clap `required = true` handles this,
    // but belt-and-suspenders for safety)
    if cli.command.is_empty() {
        eprintln!("Error: no command specified. Usage: aibridge -- <command> [args...]");
        std::process::exit(1);
    }

    // Tool detection: check if the wrapped command exists in PATH
    let tool_name = &cli.command[0];
    if which::which(tool_name).is_err() {
        eprintln!("Error: '{}' not found in PATH.\n", tool_name);
        eprintln!("Install guides:");
        eprintln!("  claude  -> npm install -g @anthropic-ai/claude-code");
        eprintln!("  codex   -> npm install -g @openai/codex");
        eprintln!("  gemini  -> npm install -g @google/gemini-cli");
        eprintln!("  other   -> ensure the command is installed and in your PATH");
        std::process::exit(1);
    }

    // Resolve agent pattern for idle/busy detection
    let command_str = cli.command.join(" ");
    let pattern = patterns::resolve_pattern(&command_str, cli.busy_pattern.as_deref());

    let detected_agent = patterns::detect_agent(&command_str)
        .map(|a| a.name)
        .unwrap_or("custom");

    if cli.verbose {
        eprintln!("[verbose] Detected agent: {}", detected_agent);
        eprintln!("[verbose] Busy pattern: {}", pattern.as_str());
    }

    // Startup banner (to stderr -- stdout is the PTY)
    eprintln!("AiBridge v{}", VERSION);
    eprintln!("Wrapping: {}", command_str);
    eprintln!("Agent: {}", detected_agent);
    eprintln!("HTTP API: http://{}:{}", cli.host, cli.port);
    eprintln!("Paranoid: {}", if cli.paranoid { "yes" } else { "no" });

    // Create Bridge
    let bridge = match Bridge::new(&cli.command, pattern, cli.paranoid, cli.inject_delay) {
        Ok(b) => Arc::new(b),
        Err(e) => {
            eprintln!("Error: failed to create bridge: {}", e);
            std::process::exit(1);
        }
    };

    // Create HTTP server router
    let state = AppState {
        bridge: bridge.clone(),
        timeout: Duration::from_secs(cli.timeout),
    };
    let router = server::create_router(state);

    // Top-level terminal restore guard (safety net)
    let _terminal_guard = TerminalRestoreGuard;

    // Clone bridge for signal handler
    let bridge_signal = bridge.clone();

    // Run bridge, HTTP server, and signal handler concurrently
    tokio::select! {
        result = bridge.run() => {
            // PTY exited (child process done)
            match result {
                Ok(()) => eprintln!("\nChild process exited."),
                Err(e) => eprintln!("\nBridge error: {}", e),
            }
        }
        result = server::start_server(&cli.host, cli.port, router) => {
            // Server exited unexpectedly
            match result {
                Ok(()) => eprintln!("\nHTTP server stopped."),
                Err(e) => eprintln!("\nHTTP server error: {}", e),
            }
            bridge_signal.shutdown();
        }
        _ = signal_handler() => {
            // User interrupted (Ctrl+C / SIGTERM)
            eprintln!("\nShutting down...");
            bridge_signal.shutdown();
        }
    }

    eprintln!("AiBridge stopped.");
}

/// Wait for shutdown signal: Ctrl+C on all platforms, SIGTERM on Unix.
async fn signal_handler() {
    #[cfg(unix)]
    {
        use tokio::signal::unix::{signal, SignalKind};
        let mut sigterm = signal(SignalKind::terminate())
            .expect("failed to register SIGTERM handler");
        tokio::select! {
            _ = tokio::signal::ctrl_c() => {}
            _ = sigterm.recv() => {}
        }
    }

    #[cfg(not(unix))]
    {
        tokio::signal::ctrl_c()
            .await
            .expect("failed to listen for Ctrl+C");
    }
}
