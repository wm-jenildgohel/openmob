mod ansi;
mod patterns;
mod pty_handler;

use clap::Parser;

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

#[tokio::main]
async fn main() {
    let cli = Cli::parse();

    if cli.verbose {
        eprintln!("aibridge v{}", VERSION);
        eprintln!("Host: {}:{}", cli.host, cli.port);
        eprintln!("Command: {:?}", cli.command);
        eprintln!("Paranoid: {}", cli.paranoid);
        eprintln!("Inject delay: {}ms", cli.inject_delay);
        eprintln!("Timeout: {}s", cli.timeout);
        if let Some(ref pattern) = cli.busy_pattern {
            eprintln!("Custom busy pattern: {}", pattern);
        }
    }

    let command_str = cli.command.join(" ");
    let pattern = patterns::resolve_pattern(&command_str, cli.busy_pattern.as_deref());

    if cli.verbose {
        eprintln!("Resolved busy pattern: {}", pattern.as_str());
    }

    // Full wiring with PTY, bridge, and HTTP server happens in Plan 03-02/03/04
    eprintln!(
        "aibridge v{} ready - wrapping '{}' on {}:{}",
        VERSION, command_str, cli.host, cli.port
    );
}
