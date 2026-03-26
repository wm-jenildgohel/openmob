use crate::ansi;
use crate::busy_detector::BusyDetector;
use crate::pty_handler::{PtyHandler, PtyReader, PtyWriter};
use crate::queue::InjectionQueue;
use std::io::IsTerminal;
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::{Arc, Mutex};
use std::time::{Duration, Instant};
use tokio_util::sync::CancellationToken;

/// Bridge orchestrator: wires PTY I/O, idle detection, and injection delivery
/// into 4 concurrent tokio tasks. Reader and writer use separate locks so
/// reading PTY output never blocks writing user input.
pub struct Bridge {
    reader: Arc<Mutex<PtyReader>>,
    writer: Arc<Mutex<PtyWriter>>,
    child: Arc<Mutex<Box<dyn portable_pty::Child + Send>>>,
    detector: Arc<BusyDetector>,
    queue: InjectionQueue,
    inject_notify_tx: tokio::sync::mpsc::Sender<()>,
    inject_notify_rx: std::sync::Mutex<Option<tokio::sync::mpsc::Receiver<()>>>,
    cancel: CancellationToken,
    child_running: Arc<AtomicBool>,
    start_time: Instant,
}

impl Bridge {
    pub fn new(
        command: &[String],
        pattern: regex::Regex,
        paranoid: bool,
        inject_delay_ms: u64,
    ) -> anyhow::Result<Self> {
        let size = terminal_size::terminal_size()
            .map(|(w, h)| (w.0, h.0))
            .unwrap_or((80, 24));

        let pty = PtyHandler::spawn(command, size, paranoid, inject_delay_ms)?;
        let detector = Arc::new(BusyDetector::new(pattern));
        let queue = InjectionQueue::new();
        let (inject_notify_tx, inject_notify_rx) = tokio::sync::mpsc::channel(1);
        let cancel = CancellationToken::new();

        Ok(Self {
            reader: pty.reader,
            writer: pty.writer,
            child: pty.child,
            detector,
            queue,
            inject_notify_tx,
            inject_notify_rx: std::sync::Mutex::new(Some(inject_notify_rx)),
            cancel,
            child_running: Arc::new(AtomicBool::new(true)),
            start_time: Instant::now(),
        })
    }

    pub async fn run(&self) -> anyhow::Result<()> {
        let mut inject_rx = self
            .inject_notify_rx
            .lock()
            .unwrap()
            .take()
            .ok_or_else(|| anyhow::anyhow!("Bridge.run() can only be called once"))?;

        // Raw mode may fail when launched without a console (e.g., from Hub as child process)
        let _raw_guard = match crossterm::terminal::enable_raw_mode() {
            Ok(()) => Some(RawModeGuard),
            Err(e) => {
                eprintln!("[warn] Could not enable raw mode: {} (no terminal attached?)", e);
                None
            }
        };

        let cancel = self.cancel.clone();

        // Task 1: PTY Read — uses reader lock only (never blocks writer)
        let reader = self.reader.clone();
        let detector_read = self.detector.clone();
        let child_running_read = self.child_running.clone();
        let cancel_read = self.cancel.clone();
        let read_handle = tokio::task::spawn_blocking(move || {
            let mut buf = [0u8; 4096];
            loop {
                if cancel_read.is_cancelled() {
                    break;
                }
                let n = {
                    let mut r = reader.lock().unwrap();
                    match r.read(&mut buf) {
                        Ok(0) => {
                            child_running_read.store(false, Ordering::SeqCst);
                            cancel_read.cancel();
                            break;
                        }
                        Ok(n) => n,
                        Err(_) => {
                            child_running_read.store(false, Ordering::SeqCst);
                            cancel_read.cancel();
                            break;
                        }
                    }
                };

                // Write to stdout for user to see
                {
                    use std::io::Write;
                    let _ = std::io::stdout().write_all(&buf[..n]);
                    let _ = std::io::stdout().flush();
                }

                // Feed to detector
                let cleaned = ansi::strip_ansi(&buf[..n]);
                let det = detector_read.clone();
                for line in cleaned.lines() {
                    if !line.trim().is_empty() {
                        let det_inner = det.clone();
                        let line_owned = line.to_string();
                        if let Ok(handle) = tokio::runtime::Handle::try_current() {
                            handle.block_on(det_inner.process_line(&line_owned));
                        }
                    }
                }
            }
        });

        // Task 2: Stdin Forward — uses writer lock only (never blocks reader)
        // Skip stdin forwarding if no terminal is attached (e.g., launched from Hub as child process)
        let has_terminal = std::io::stdin().is_terminal();
        let writer_stdin = self.writer.clone();
        let cancel_stdin = self.cancel.clone();
        let stdin_handle = tokio::task::spawn_blocking(move || {
            if !has_terminal {
                // No terminal attached — just wait for cancellation
                while !cancel_stdin.is_cancelled() {
                    std::thread::sleep(Duration::from_millis(200));
                }
                return;
            }
            use std::io::Read;
            let mut buf = [0u8; 1024];
            let stdin = std::io::stdin();
            let mut stdin_lock = stdin.lock();
            loop {
                if cancel_stdin.is_cancelled() {
                    break;
                }
                match stdin_lock.read(&mut buf) {
                    Ok(0) => break,
                    Ok(n) => {
                        let mut w = writer_stdin.lock().unwrap();
                        if w.write_all(&buf[..n]).is_err() {
                            break;
                        }
                    }
                    Err(_) => break,
                }
            }
        });

        // Task 3: Detector Ticker
        let detector_tick = self.detector.clone();
        let inject_notify_for_tick = self.inject_notify_tx.clone();
        let cancel_tick = self.cancel.clone();
        let tick_handle = tokio::spawn(async move {
            let (on_idle_tx, mut on_idle_rx) = tokio::sync::mpsc::channel::<()>(1);

            let det = detector_tick.clone();
            let cancel_det = cancel_tick.clone();
            let det_task = tokio::spawn(async move {
                det.run(on_idle_tx, cancel_det).await;
            });

            loop {
                tokio::select! {
                    _ = cancel_tick.cancelled() => break,
                    msg = on_idle_rx.recv() => {
                        match msg {
                            Some(()) => {
                                let _ = inject_notify_for_tick.try_send(());
                            }
                            None => break,
                        }
                    }
                }
            }

            det_task.abort();
        });

        // Task 4: Injection Loop — uses writer lock (brief, non-blocking)
        let detector_inject = self.detector.clone();
        let queue_inject = self.queue.clone();
        let writer_inject = self.writer.clone();
        let cancel_inject = self.cancel.clone();
        let inject_handle = tokio::spawn(async move {
            loop {
                tokio::select! {
                    _ = cancel_inject.cancelled() => break,
                    msg = inject_rx.recv() => {
                        if msg.is_none() {
                            break;
                        }
                        while detector_inject.is_idle().await {
                            match queue_inject.dequeue().await {
                                Some(item) => {
                                    let text = item.text.clone();
                                    {
                                        let mut w = writer_inject.lock().unwrap();
                                        let _ = w.inject_text(&text);
                                    }
                                    if let Some(tx) = item.sync_tx {
                                        let _ = tx.send(());
                                    }
                                }
                                None => break,
                            }
                        }
                    }
                }
            }
        });

        // Wait for cancellation or child exit
        cancel.cancelled().await;

        tick_handle.abort();
        inject_handle.abort();

        // Kill child if still running
        {
            let mut child = self.child.lock().unwrap();
            if child.try_wait().ok().flatten().is_none() {
                let _ = child.kill();
            }
        }

        let _ = read_handle.await;
        let _ = stdin_handle.await;

        Ok(())
    }

    pub fn notify_enqueue(&self) {
        let _ = self.inject_notify_tx.try_send(());
    }

    pub async fn is_idle(&self) -> bool {
        self.detector.is_idle().await
    }

    pub async fn queue_len(&self) -> usize {
        self.queue.len().await
    }

    pub fn is_child_running(&self) -> bool {
        self.child_running.load(Ordering::SeqCst)
    }

    pub fn uptime(&self) -> Duration {
        self.start_time.elapsed()
    }

    pub fn queue(&self) -> &InjectionQueue {
        &self.queue
    }

    pub fn shutdown(&self) {
        self.cancel.cancel();
    }
}

struct RawModeGuard;

impl Drop for RawModeGuard {
    fn drop(&mut self) {
        let _ = crossterm::terminal::disable_raw_mode();
    }
}
