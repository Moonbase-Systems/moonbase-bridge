//! MoonBase Bridge: local execution engine for MoonBase Studio.
//!
//! The process has no operator window. Studio shows its state.

// Release builds on Windows start without a console window.
#![cfg_attr(all(windows, not(debug_assertions)), windows_subsystem = "windows")]

mod cli;
mod logging;
mod shutdown;

use anyhow::Result;
use bridge_contract::CONTRACT_VERSION;
use clap::Parser;

use crate::cli::Cli;

#[tokio::main]
async fn main() -> Result<()> {
    let cli = Cli::parse();
    let log_dir = cli.log_dir.clone().map_or_else(logging::default_log_dir, Ok)?;
    let _log_guard = logging::init(&log_dir, &cli.log_filter)?;

    tracing::info!(
        version = env!("CARGO_PKG_VERSION"),
        contract = %CONTRACT_VERSION,
        os = std::env::consts::OS,
        arch = std::env::consts::ARCH,
        log_dir = %log_dir.display(),
        "bridge started",
    );

    shutdown::wait_for_signal().await?;
    tracing::info!("bridge stopped");
    Ok(())
}
