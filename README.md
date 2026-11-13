# MoonBase Bridge

## Local execution engine for MoonBase Studio

MoonBase Bridge is a separate process that the operator downloads and runs next to [MoonBase Studio](https://github.com/Moonbase-Systems/moonbase-studio-web). It has no operator window. Studio edits the project document. Bridge executes it.

- It opens cameras, microphones, screens, and media files.
- It renders **one Program Output** in `scene.elements` order.
- FFmpeg publishes that same picture and the program mix over **RTMP**.
- It reports session state, devices, and runtime numbers (FPS, bitrate, latency, CPU, memory) back to Studio.

Studio works on its own (**Standalone**): edit, undo, and save. With Bridge running it switches to **Connected**, and streaming, the program frame, monitoring, and the director become available. Losing Studio does not stop a running program. Losing Bridge does not stop editing. Losing one source does not stop the program.

MoonBase AI scores camera frames that it gets from Bridge. Its shot recommendation reaches Bridge as a command. AI does not write the project and does not open devices.

> **Status:** early skeleton. The Studio ↔ Bridge contract (STU-23) comes next. Work is tracked in Linear, project **MoonBase Bridge** (target: 18 December 2026).

## Supported platforms

| OS | Architectures | Notes |
| --- | --- | --- |
| Windows 10 / 11 | x64, arm64 | `ffmpeg.exe` ships with the package |
| Linux (Wayland or X11) | x64, arm64 | needs `ffmpeg`, PipeWire, and `xdg-desktop-portal` with a backend for your compositor |

Both systems have the same feature set. Device ids are platform-specific, so a project moved between Windows and Linux needs its cameras assigned again.

## Development

### Requirements

- [rustup](https://rustup.rs). The toolchain version comes from [`rust-toolchain.toml`](./rust-toolchain.toml).
- Tools:

  ```bash
  # Arch Linux
  sudo pacman -S --needed just taplo-cli typos cargo-deny cargo-nextest committed

  # Anywhere else (or cargo install --locked ...)
  cargo binstall just taplo-cli typos-cli cargo-deny cargo-nextest committed

  # Git hooks
  cargo binstall prek
  ```

### Running

```bash
# debug build with debug logs
just run

# release build
just build
./target/release/moonbase-bridge --help
```

Logs go to stderr and to a daily file:

- Windows: `%LOCALAPPDATA%\MoonBase\Bridge\logs`
- Linux: `$XDG_STATE_HOME/moonbase/bridge/logs` (usually `~/.local/state/...`)

Use `--log-dir` / `MOONBASE_BRIDGE_LOG_DIR` and `--log-filter` / `MOONBASE_BRIDGE_LOG` to change them. On Linux you can run Bridge as a user service, see [`docs/moonbase-bridge.service`](./docs/moonbase-bridge.service).

### Checks

```bash
just lint      # rustfmt, clippy (-D warnings), taplo, typos
just test      # nextest + doc tests
just deny      # licenses, advisories, bans, sources
just lint-fix  # apply automatic fixes
```

### Git hooks

[prek](https://github.com/j178/prek) runs the hooks from [`prek.toml`](./prek.toml). Install them once per clone:

```bash
prek install
```

| Stage | Hooks |
| --- | --- |
| pre-commit | whitespace and end-of-file fixes, TOML/YAML syntax, merge markers, typos, `cargo fmt`, `taplo fmt` |
| commit-msg | [committed](https://github.com/crate-ci/committed): Conventional Commits, same rules as `@commitlint/config-conventional` in the TypeScript repositories |
| pre-push | `cargo clippy -D warnings`, `cargo nextest` |

### CI

[`.github/workflows/ci.yaml`](./.github/workflows/ci.yaml) runs on pull requests and on `main`:

- lint on Linux and Windows
- Conventional Commits check on pull request commits
- `cargo deny`
- tests on Linux and Windows

On `main` it also builds release packages on native runners for `linux-x64`, `linux-arm64`, `windows-x64`, and `windows-arm64`, and uploads them as workflow artifacts.

## Project setup

### Directory structure

```bash
crates
├── bridge-contract  # Studio ↔ Bridge contract, platform-neutral
└── moonbase-bridge  # the executable: CLI, logging, process lifecycle
docs
├── architecture.md  # crates, platform boundaries, data flow
└── decisions.md     # architecture decision records
```

The project document format is owned by Studio (`ProjectFile` v2 in `moonbase-studio-web`). Bridge reads it and never writes it.

### Stack

| Area | Choice |
| --- | --- |
| Async runtime and local transport | Tokio, Axum (HTTP + WebSocket on 127.0.0.1), Serde |
| Rendering | wgpu (D3D12 on Windows, Vulkan on Linux), glyphon for text |
| Cameras | Media Foundation (`windows` crate) / V4L2 (`v4l`) |
| Screen capture | Windows.Graphics.Capture (`windows-capture`) / xdg-desktop-portal ScreenCast + PipeWire (`ashpd`, `pipewire`) |
| Audio | cpal and an in-house DSP chain (EQ, compressor, limiter, gate) |
| Encoding and RTMP | an `ffmpeg` child process fed with raw frames and PCM |

The reasons are in [`docs/decisions.md`](./docs/decisions.md).

### VS Code helpers

Recommended extensions are in [`.vscode/extensions.json`](./.vscode/extensions.json). rust-analyzer runs clippy on save.
