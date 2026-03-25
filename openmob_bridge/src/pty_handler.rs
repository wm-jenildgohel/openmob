use portable_pty::{native_pty_system, Child, CommandBuilder, MasterPty, PtySize};
use std::io::{self, Read, Write};
use std::sync::{Arc, Mutex};

/// Thread-safe PTY reader — can be used independently of the writer.
pub struct PtyReader {
    reader: Box<dyn Read + Send>,
}

impl PtyReader {
    pub fn read(&mut self, buf: &mut [u8]) -> io::Result<usize> {
        self.reader.read(buf)
    }
}

/// Thread-safe PTY writer — can be used independently of the reader.
pub struct PtyWriter {
    writer: Box<dyn Write + Send>,
    pub paranoid: bool,
    pub inject_delay_ms: u64,
}

impl PtyWriter {
    pub fn write_all(&mut self, data: &[u8]) -> io::Result<()> {
        self.writer.write_all(data)?;
        self.writer.flush()
    }

    pub fn inject_text(&mut self, text: &str) -> io::Result<()> {
        self.writer.write_all(text.as_bytes())?;

        if self.paranoid {
            return self.writer.flush();
        }

        if self.inject_delay_ms > 0 {
            std::thread::sleep(std::time::Duration::from_millis(self.inject_delay_ms));
        }

        self.writer.write_all(b"\r")?;
        self.writer.flush()
    }
}

/// Manages a pseudo-terminal session for a child process.
/// Reader and writer are split into separate mutex-protected handles
/// so reading PTY output never blocks writing user input.
pub struct PtyHandler {
    pub child: Arc<Mutex<Box<dyn Child + Send>>>,
    #[allow(dead_code)]
    master: Box<dyn MasterPty + Send>,
    pub reader: Arc<Mutex<PtyReader>>,
    pub writer: Arc<Mutex<PtyWriter>>,
}

impl PtyHandler {
    pub fn spawn(
        command: &[String],
        size: (u16, u16),
        paranoid: bool,
        inject_delay_ms: u64,
    ) -> anyhow::Result<PtyHandler> {
        let pty_system = native_pty_system();

        let pty_size = PtySize {
            rows: size.1,
            cols: size.0,
            pixel_width: 0,
            pixel_height: 0,
        };

        let pair = pty_system.openpty(pty_size)?;

        let mut cmd = CommandBuilder::new(&command[0]);
        if command.len() > 1 {
            cmd.args(&command[1..]);
        }

        let child = pair.slave.spawn_command(cmd)?;

        let reader = pair.master.try_clone_reader()?;
        let writer = pair.master.take_writer()?;

        Ok(PtyHandler {
            child: Arc::new(Mutex::new(child)),
            master: pair.master,
            reader: Arc::new(Mutex::new(PtyReader { reader })),
            writer: Arc::new(Mutex::new(PtyWriter {
                writer,
                paranoid,
                inject_delay_ms,
            })),
        })
    }

    #[allow(dead_code)]
    pub fn resize(&self, cols: u16, rows: u16) -> anyhow::Result<()> {
        self.master.resize(PtySize {
            rows,
            cols,
            pixel_width: 0,
            pixel_height: 0,
        })?;
        Ok(())
    }

    #[allow(dead_code)]
    pub fn is_alive(&self) -> bool {
        self.child.lock().unwrap().try_wait().ok().flatten().is_none()
    }

    #[allow(dead_code)]
    pub fn kill(&self) {
        let _ = self.child.lock().unwrap().kill();
    }
}
