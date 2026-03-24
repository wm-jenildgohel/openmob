use regex::Regex;

/// A built-in agent pattern for idle detection.
/// When the busy_regex matches recent terminal output, the agent is considered BUSY.
/// When no match occurs for a threshold period, the agent is IDLE.
pub struct AgentPattern {
    pub name: &'static str,
    pub busy_regex: &'static str,
}

/// Returns built-in busy patterns for known AI coding agents.
pub fn builtin_patterns() -> Vec<AgentPattern> {
    vec![
        AgentPattern {
            name: "claude",
            busy_regex: r"(?i)thinking",
        },
        AgentPattern {
            name: "codex",
            busy_regex: r"(?i)esc to interrupt",
        },
        AgentPattern {
            name: "gemini",
            busy_regex: r"(?i)esc to cancel",
        },
    ]
}

/// Detect which agent is being wrapped based on the command string.
/// Matches command against known agent names (case-insensitive substring).
pub fn detect_agent(command: &str) -> Option<&'static AgentPattern> {
    // Leak builtin_patterns into static lifetime for returning references.
    // This is safe because builtin patterns are constant data.
    static PATTERNS: std::sync::OnceLock<Vec<AgentPattern>> = std::sync::OnceLock::new();
    let patterns = PATTERNS.get_or_init(builtin_patterns);

    let cmd_lower = command.to_lowercase();
    for pattern in patterns {
        if cmd_lower.contains(pattern.name) {
            return Some(pattern);
        }
    }
    None
}

/// Resolve the busy-detection regex for a given command.
/// Priority: custom_pattern (from --busy-pattern) > auto-detected agent > default fallback.
pub fn resolve_pattern(command: &str, custom_pattern: Option<&str>) -> Regex {
    if let Some(custom) = custom_pattern {
        return Regex::new(custom).unwrap_or_else(|_| {
            eprintln!("Warning: invalid --busy-pattern regex, using default");
            default_pattern()
        });
    }

    if let Some(agent) = detect_agent(command) {
        Regex::new(agent.busy_regex).unwrap_or_else(|_| default_pattern())
    } else {
        default_pattern()
    }
}

/// Default fallback pattern when no agent is detected.
fn default_pattern() -> Regex {
    Regex::new(r"(?i)esc to interrupt").expect("default pattern is valid")
}
