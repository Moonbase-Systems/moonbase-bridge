# Architectural Decisions — MoonBase Bridge

## ADR-001: Rust process without an operator window, on Windows and Linux

**Decision:** Bridge is a Rust executable for Windows 10/11 and Linux, each on x64 and arm64, with the same feature set on both systems. It has no operator window. Release builds on Windows use `windows_subsystem = "windows"`, so no console opens. On Linux it runs as a background process or a `systemd --user` service. Studio shows its state.

**Why:** The December 2026 scope moves device access, rendering, and RTMP out of the browser (ADR-010 in `moonbase-studio-web`). Linux support lets the team run the full Studio + Bridge loop on their development machines. It also satisfies NFR-10 (operating-system independence) in the thesis.

---

## ADR-002: Stack

**Decision:**

| Area | Crates |
| --- | --- |
| Async runtime | `tokio` |
| Local transport | `axum` (HTTP for requests, WebSocket for state events) on 127.0.0.1, `serde`, `serde_json` |
| Contract schema | `schemars`. The JSON Schema is generated into `schema/`, and CI fails when the committed file is stale |
| Logging | `tracing`, `tracing-subscriber`, `tracing-appender` (session log file) |
| Errors | `thiserror` in libraries, `anyhow` in the executable |
| CLI | `clap` |
| Rendering | `wgpu` (D3D12 / Vulkan), `glyphon` for text |
| Images and animations | `image` (PNG, GIF, animated WebP, APNG) |
| Cameras | `windows` (Media Foundation `IMFSourceReader`) / `v4l` (V4L2, without libv4l) |
| Screen capture | `windows-capture` (Windows.Graphics.Capture) / `ashpd` (ScreenCast portal) + `pipewire` |
| Audio I/O | `cpal` (WASAPI / ALSA and PipeWire) |
| Audio DSP | in-house: biquad EQ, compressor, limiter, noise gate |
| Runtime numbers | `sysinfo` for CPU and memory, FFmpeg progress for FPS and bitrate |

**Why:**

- Tokio, Axum, and Serde are the stack the thesis already names (chapter 3).
- The same crates are used by large Rust desktop media projects. Cap, for example, uses `windows`, `windows-capture`, `cpal`, and `wgpu`.
- `nokhwa` was rejected: it is lightly maintained, and Cap had to fork it.
- `fundsp` was rejected: the four required effects are small and easier to test as plain code.
- Crates are added when a Linear task needs them, not ahead of time.

---

## ADR-003: FFmpeg as a child process

**Decision:** Bridge starts `ffmpeg` as a child process through `tokio::process`. It writes raw video frames and PCM audio to stdin, and FFmpeg encodes, muxes, and publishes over RTMP. Bridge reads `-progress` output for FPS, bitrate, and speed. FFmpeg also decodes video files and network sources and returns raw frames over a pipe.

- On Windows, `ffmpeg.exe` ships inside the release package.
- On Linux, `ffmpeg` comes from the system package manager.
- Hardware encoders are picked per system and fall back to `libx264`:
  - Windows: NVENC, QSV, or AMF;
  - Linux: NVENC or VAAPI.

**Why:**

- STU-31 requires runtime numbers to come from the process and from FFmpeg progress.
- A crashing encoder ends a child process, not Bridge, so RTMP errors become a state instead of a crash.
- The build stays a plain `cargo build` on every target.
- Linking libav through `ffmpeg-next` was rejected: it needs per-target FFmpeg development libraries in CI and in every developer setup.

---

## ADR-004: Bridge reads the project, Studio owns it

**Decision:** Bridge deserializes `ProjectFile` v2 from Studio and never writes it. Layer order is the index in `scene.elements`. Bridge never keeps a second layer list. Runtime state never enters the document: device sessions, RTMP connection state, FFmpeg progress, and AI scores.

**Why:** ADR-008 and ADR-010 in `moonbase-studio-web`. Studio must keep working while Bridge is stopped. A second copy of the document would drift.

---

## ADR-005: Tooling

**Decision:**

| Concern | Tool |
| --- | --- |
| Formatting | `rustfmt` (style edition 2024, width 120), `taplo` for TOML |
| Lints | `clippy` with `pedantic` and selected restriction lints, `-D warnings` in CI |
| Spelling | `typos` |
| Tests | `cargo-nextest` (JUnit report in CI) and `cargo test --doc` |
| Dependencies | `cargo-deny`: licenses, advisories, bans, sources |
| Git hooks | `prek` with `prek.toml` |
| Commit messages | `committed`, Conventional Commits |
| Task runner | `just` |

**Why:**

- These match the TypeScript repositories:
  - ESLint and Prettier → clippy, rustfmt, and taplo;
  - husky → prek;
  - commitlint → committed;
  - pnpm scripts → just.
- They follow what large Rust repositories use: axum, uv, ruff, wgpu, rerun, and bevy.
- prek and committed are single Rust binaries. The repository does not need Node or Python.
