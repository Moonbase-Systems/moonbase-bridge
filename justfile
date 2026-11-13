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
