use std::path::PathBuf;

use clap::Parser;

/// Command-line options. Bridge has no window, so configuration comes from here.
#[derive(Debug, Parser)]
#[command(name = "moonbase-bridge", version, about)]
pub(crate) struct Cli {
    /// Directory for session logs. Defaults to the per-user state directory.
    #[arg(long, env = "MOONBASE_BRIDGE_LOG_DIR")]
    pub(crate) log_dir: Option<PathBuf>,

    /// Log filter in `tracing` env-filter syntax, e.g. `info` or `moonbase_bridge=debug`.
    #[arg(long, env = "MOONBASE_BRIDGE_LOG", default_value = "info")]
    pub(crate) log_filter: String,
}

#[cfg(test)]
mod tests {
    use clap::CommandFactory;

    use super::*;

    #[test]
    fn command_definition_is_valid() {
        Cli::command().debug_assert();
    }

    #[test]
    fn defaults_without_arguments() {
        let cli = Cli::try_parse_from(["moonbase-bridge"]).unwrap();
        assert_eq!(cli.log_dir, None);
        assert_eq!(cli.log_filter, "info");
    }

    #[test]
    fn accepts_log_options() {
        let cli = Cli::try_parse_from(["moonbase-bridge", "--log-dir", "/tmp/logs", "--log-filter", "debug"]).unwrap();
        assert_eq!(cli.log_dir, Some(PathBuf::from("/tmp/logs")));
        assert_eq!(cli.log_filter, "debug");
    }
}
