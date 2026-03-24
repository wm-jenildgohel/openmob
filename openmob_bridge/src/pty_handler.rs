use portable_pty::{native_pty_system, Child, CommandBuilder, MasterPty, PtySize};
use std::io::{self, Read, Write};

/// Manages a pseudo-terminal session for a child process.
/// Provides spawn, read, write, inject, resize, and lifecycle operations.
pub struct PtyHandler {
    child: Box<dyn Child + Send>,
    master: Box<dyn MasterPty + Send>,
    reader: Box<dyn Read + Send>,
    writer: Box<dyn Write + Send>,
    pub paranoid: bool,
    pub inject_delay_ms: u64,
}

impl PtyHandler {
    /// Spawn a command inside a new PTY.
    /// `command` is a slice where the first element is the program and the rest are arguments.
    /// `size` is (cols, rows) for the initial terminal size.
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
            child,
            master: pair.master,
            reader,
            writer,
            paranoid,
            inject_delay_ms,
        })
    }

    /// Read from PTY master into the provided buffer.
    /// Returns the number of bytes read, or an I/O error.
    pub fn read(&mut self, buf: &mut [u8]) -> io::Result<usize> {
        self.reader.read(buf)
    }

    /// Write data to PTY master (forwards user input to the child process).
    pub fn write_all(&mut self, data: &[u8]) -> io::Result<()> {
        self.writer.write_all(data)
    }

    /// Inject text into the PTY as if a user typed it.
    /// If not in paranoid mode, waits inject_delay_ms then sends Enter (\r).
    pub fn inject_text(&mut self, text: &str) -> io::Result<()> {
        self.writer.write_all(text.as_bytes())?;

        if self.paranoid {
            return Ok(());
        }

        if self.inject_delay_ms > 0 {
            std::thread::sleep(std::time::Duration::from_millis(self.inject_delay_ms));
        }

        self.writer.write_all(b"\r")
    }

    /// Resize the PTY to the given dimensions.
    pub fn resize(&self, cols: u16, rows: u16) -> anyhow::Result<()> {
        self.master.resize(PtySize {
            rows,
            cols,
            pixel_width: 0,
            pixel_height: 0,
        })?;
        Ok(())
    }

    /// Check if the child process is still running.
    pub fn is_alive(&mut self) -> bool {
        self.child.try_wait().ok().flatten().is_none()
    }

    /// Kill the child process.
    pub fn kill(&mut self) {
        let _ = self.child.kill();
    }
}
