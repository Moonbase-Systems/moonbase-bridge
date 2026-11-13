# Architecture

## Place in the system

```
moonbase-studio-web  ── edits ProjectFile v2, sends commands ──►  moonbase-bridge
        ▲                                                            │
        └──────────── session state, devices, runtime numbers ───────┘
                                                                     │ camera frames
moonbase-ai  ◄───────────────────────────────────────────────────────┘
        └──────────── shot recommendation as a command ──────────────► moonbase-bridge
```

- **Studio** owns the document. Bridge receives the whole project when a session starts and incremental changes afterwards. Undo history never travels.
- **Bridge** owns devices, the Program Output, the program mix, and the RTMP publication.
- **AI** reads frames from Bridge, including cameras that are not on Program. It never writes the project and never opens devices.

The transport is local (127.0.0.1). The command set and session states are defined by the contract (STU-23) and live in `bridge-contract`.

## Program Output

There is exactly one Program Output. It draws the active scene in `scene.elements` order (index 0 at the bottom), with visibility, transform, crop, opacity, and background. The same frame, together with the program mix, goes to the encoder. No second render path exists for the stream.

Placement semantics (anchor, crop, flip, fit mode) follow the Studio preview in `moonbase-studio-web/layers/studio/app/infrastructure/pixi/`, so the editor preview and Program Output agree.

Program state and RTMP state are separate:

- Pause disconnects the RTMP publication. The process and the project stay.
- Resume reconnects to the same address.
- Switching scenes changes the composition. It does not drop the publication.

## Crates

| Crate | Platform | Purpose |
| --- | --- | --- |
| `bridge-contract` | any | Contract version, commands, state events, session ids |
| `moonbase-bridge` | any | Executable: CLI, logging, signal handling, wiring |

Planned as the work in Linear progresses:

| Crate | Platform | Purpose |
| --- | --- | --- |
| `bridge-project` | any | Serde model of `ProjectFile` v2, read-only |
| `bridge-session` | any | Session lifecycle: connected, initializing, ready, running, stopping, error |
| `bridge-render` | any (GPU) | wgpu compositor that produces the Program Output |
| `bridge-audio` | any | Program mix and the DSP chain |
| `bridge-encoder` | any | `ffmpeg` child process, `-progress` parsing, RTMP state |
| `bridge-platform` | per OS | Device backends behind `CameraBackend`, `ScreenBackend`, `AudioBackend` |
| `bridge-server` | any | Axum HTTP + WebSocket transport, no command logic |

## Platform boundary

Everything except device access is platform-neutral and tested on both Linux and Windows. Device code sits in `bridge-platform`:

```
bridge-platform
├── src/windows/   # cfg(windows): Media Foundation, Windows.Graphics.Capture
└── src/linux/     # cfg(target_os = "linux"): V4L2, xdg-desktop-portal + PipeWire
```

- Platform dependencies go under `[target.'cfg(windows)'.dependencies]` or `[target.'cfg(target_os = "linux")'.dependencies]`.
- Each backend reports devices with a platform-specific `deviceId`: the Media Foundation symbolic link on Windows, `/dev/v4l/by-id/...` on Linux. Studio stores the id on a camera position.
- On Wayland the first screen capture shows the portal consent dialog. Bridge keeps the portal restore token, so later sessions skip it.
- `unsafe` is allowed only in platform code, and every block needs a `// SAFETY:` comment.

## Failure isolation

| Failure | Effect |
| --- | --- |
| Studio disconnects | The program keeps running and RTMP keeps publishing |
| One source disappears | A source error is reported. The rest of the program keeps drawing |
| Microphone lost | The picture continues |
| `ffmpeg` exits | RTMP state becomes `error`. Bridge and the program stay up |
| AI stops | Manual switching and RTMP continue |
