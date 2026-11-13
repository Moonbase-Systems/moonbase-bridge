use anyhow::Result;

/// Waits until the process is asked to stop.
///
/// Ctrl+C on every platform, plus SIGTERM on Unix so `systemctl --user stop` ends the process cleanly.
pub(crate) async fn wait_for_signal() -> Result<()> {
    #[cfg(unix)]
    {
        use tokio::signal::unix::{SignalKind, signal};

        let mut terminate = signal(SignalKind::terminate())?;
        tokio::select! {
            result = tokio::signal::ctrl_c() => result?,
            _ = terminate.recv() => {}
        }
    }

    #[cfg(not(unix))]
    tokio::signal::ctrl_c().await?;

    Ok(())
}
