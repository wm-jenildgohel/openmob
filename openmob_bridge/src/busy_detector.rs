use regex::Regex;
use std::sync::Arc;
use std::time::{Duration, Instant};
use tokio::sync::Mutex;
use tokio_util::sync::CancellationToken;

struct BusyDetectorState {
    idle: bool,
    last_output: Instant,
}

/// Detects when a wrapped AI agent transitions from busy to idle
/// by monitoring PTY output timing. When no output is seen for
/// `idle_timeout` (default 500ms), the agent is considered idle.
pub struct BusyDetector {
    state: Arc<Mutex<BusyDetectorState>>,
    pattern: Regex,
    idle_timeout: Duration,
    tick_rate: Duration,
}

impl BusyDetector {
    pub fn new(pattern: Regex) -> Self {
        Self {
            state: Arc::new(Mutex::new(BusyDetectorState {
                idle: false,
                last_output: Instant::now(),
            })),
            pattern,
            idle_timeout: Duration::from_millis(500),
            tick_rate: Duration::from_millis(100),
        }
    }

    /// Called for every line of ANSI-stripped PTY output.
    /// Resets idle state and updates last_output timestamp.
    /// If the line matches the busy pattern, confirms busy state.
    pub async fn process_line(&self, line: &str) {
        let mut state = self.state.lock().await;
        state.idle = false;
        state.last_output = Instant::now();
        // Pattern match confirms busy -- idle is already false.
        let _ = self.pattern.is_match(line);
    }

    /// Returns whether the agent is currently considered idle.
    pub async fn is_idle(&self) -> bool {
        let state = self.state.lock().await;
        state.idle
    }

    /// Runs the background ticker that checks for idle transitions.
    /// Sends a signal on `on_idle` when transitioning from busy to idle.
    /// Stops when `cancel` is triggered.
    pub async fn run(
        &self,
        on_idle: tokio::sync::mpsc::Sender<()>,
        cancel: CancellationToken,
    ) {
        let mut interval = tokio::time::interval(self.tick_rate);
        loop {
            tokio::select! {
                _ = cancel.cancelled() => {
                    break;
                }
                _ = interval.tick() => {
                    let mut state = self.state.lock().await;
                    if !state.idle && state.last_output.elapsed() > self.idle_timeout {
                        state.idle = true;
                        drop(state);
                        let _ = on_idle.send(()).await;
                    }
                }
            }
        }
    }
}
