use strip_ansi_escapes::strip;

/// Strip all ANSI escape sequences from raw PTY output bytes.
/// Returns a clean UTF-8 string (lossy conversion for non-UTF8 bytes).
pub fn strip_ansi(input: &[u8]) -> String {
    let stripped = strip(input);
    String::from_utf8_lossy(&stripped).into_owned()
}
