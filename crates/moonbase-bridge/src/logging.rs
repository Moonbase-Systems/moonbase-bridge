use std::path::{Path, PathBuf};

use anyhow::{Context, Result};
use directories::BaseDirs;
use tracing_appender::non_blocking::WorkerGuard;
use tracing_subscriber::{EnvFilter, fmt, prelude::*};

const LOG_FILE_PREFIX: &str = "bridge";

/// Per-user log directory.
///
/// - Windows: `%LOCALAPPDATA%\MoonBase\Bridge\logs`
/// - Linux: `$XDG_STATE_HOME/moonbase/bridge/logs` (`~/.local/state/...`)
/// - Elsewhere: the local data directory with the Linux layout
pub(crate) fn default_log_dir() -> Result<PathBuf> {
    let dirs = BaseDirs::new().context("cannot determine the user's home directory")?;
    Ok(log_dir_under(&dirs))
}

#[cfg(windows)]
fn log_dir_under(dirs: &BaseDirs) -> PathBuf {
    dirs.data_local_dir().join("MoonBase").join("Bridge").join("logs")
}

#[cfg(not(windows))]
fn log_dir_under(dirs: &BaseDirs) -> PathBuf {
    dirs.state_dir()
        .unwrap_or_else(|| dirs.data_local_dir())
        .join("moonbase")
        .join("bridge")
        .join("logs")
}

/// Sends logs to stderr and to a daily rolling file in `log_dir`.
///
/// Keep the returned guard alive until exit, or buffered file lines are lost.
pub(crate) fn init(log_dir: &Path, filter: &str) -> Result<WorkerGuard> {
    std::fs::create_dir_all(log_dir).with_context(|| format!("cannot create log directory {}", log_dir.display()))?;

    let file_appender = tracing_appender::rolling::daily(log_dir, LOG_FILE_PREFIX);
    let (file_writer, guard) = tracing_appender::non_blocking(file_appender);
    let filter = EnvFilter::try_new(filter).with_context(|| format!("invalid log filter `{filter}`"))?;

    tracing_subscriber::registry()
        .with(filter)
        .with(fmt::layer().with_writer(std::io::stderr))
        .with(fmt::layer().with_ansi(false).with_writer(file_writer))
        .try_init()
        .context("cannot install the log subscriber")?;

    Ok(guard)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn default_log_dir_ends_with_bridge_logs() {
        let dir = default_log_dir().unwrap();
        let tail: Vec<_> = dir.components().rev().take(3).collect();
        let tail: Vec<_> = tail
            .iter()
            .rev()
            .map(|c| c.as_os_str().to_string_lossy().to_lowercase())
            .collect();
        assert_eq!(tail, ["moonbase", "bridge", "logs"]);
    }
}
