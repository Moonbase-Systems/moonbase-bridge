# Task runner. `just` lists the recipes.

default:
    @just --list

# Check formatting, lints, TOML and spelling (what CI runs)
lint:
    cargo fmt --all --check
    cargo clippy --workspace --all-targets --locked -- -D warnings
    taplo fmt --check
    typos

# Fix what the linters can fix
lint-fix:
    cargo fmt --all
    cargo clippy --workspace --all-targets --fix --allow-dirty --allow-staged
    taplo fmt
    typos --write-changes

# Run unit and doc tests
test:
    cargo nextest run --workspace --locked
    cargo test --workspace --doc --locked

# Check licenses, advisories, bans and sources
deny:
    cargo deny --locked check

# Build the release binary
build:
    cargo build --release --locked -p moonbase-bridge

# Run Bridge locally with debug logs
run *args:
    cargo run -p moonbase-bridge -- --log-filter debug {{ args }}

# Run every git hook against all files
hooks:
    prek run --all-files

# --- Windows from WSL ---------------------------------------------------------
# WSL cannot see cameras, screens or WASAPI devices. These recipes cross-compile
# with cargo-xwin and start the .exe through WSL interop, so Bridge runs as a
# real Windows process. Studio in a Windows browser reaches it on 127.0.0.1.

win_target := "x86_64-pc-windows-msvc"
win_exe := "target/" + win_target + "/debug/moonbase-bridge.exe"

# cargo-xwin defaults the runner to wine. WSL can start .exe files directly.
export CARGO_TARGET_X86_64_PC_WINDOWS_MSVC_RUNNER := "env"

# Build the Windows debug binary
[linux]
build-win:
    cargo xwin build --target {{ win_target }} -p moonbase-bridge

# Build the Windows release binary
[linux]
build-win-release:
    cargo xwin build --release --locked --target {{ win_target }} -p moonbase-bridge

# Run Bridge on Windows with debug logs (stops a leftover instance first)
[linux]
run-win *args: stop-win build-win
    ./{{ win_exe }} --log-filter debug {{ args }}

# Rebuild and restart Bridge on Windows on every change in crates/
[linux]
watch-win *args:
    watchexec --restart --watch crates --watch Cargo.toml --exts rs,toml -- just run-win {{ args }}

# Run the tests as Windows binaries
[linux]
test-win:
    cargo xwin test --target {{ win_target }} --workspace

# Kill a Bridge process left running on Windows
[linux]
stop-win:
    -taskkill.exe /IM moonbase-bridge.exe /F > /dev/null 2>&1

# Follow today's Windows log file
[linux]
logs-win:
    powershell.exe -NoProfile -Command '$f = Get-ChildItem "$env:LOCALAPPDATA\MoonBase\Bridge\logs" | Sort-Object LastWriteTime | Select-Object -Last 1; Get-Content -Wait -Tail 50 $f.FullName'
