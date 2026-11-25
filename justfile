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

# --- Local RTMP (MediaMTX) ----------------------------------------------------
# Ingest for Bridge / FFmpeg tests. See docs/rtmp-dev.md.

rtmp_compose := "compose.rtmp.yaml"
rtmp_path := "live/moonbase"
rtmp_url := "rtmp://127.0.0.1:1935/" + rtmp_path
rtmp_hls := "http://127.0.0.1:8888/" + rtmp_path + "/index.m3u8"
rtmp_dev_dir := justfile_directory() + "/.rtmp-dev"
mediamtx_version := "v1.11.3"

# Resolve `docker` on Linux or through Docker Desktop on WSL2
[private]
rtmp-docker +cmd:
    #!/usr/bin/env bash
    set -euo pipefail
    win_docker="/mnt/c/Program Files/Docker/Docker/resources/bin/docker.exe"
    if [[ -x "${win_docker}" ]] && "${win_docker}" version >/dev/null 2>&1; then
        DOCKER="${win_docker}"
    elif command -v docker >/dev/null 2>&1 && docker version >/dev/null 2>&1; then
        DOCKER=docker
    else
        echo "Brak działającego Dockera. Uruchom Docker Desktop i włącz WSL integration." >&2
        exit 1
    fi
    cd "{{ justfile_directory() }}" && "$DOCKER" {{ cmd }}

# Start MediaMTX: Docker when available, otherwise a local binary
rtmp-up:
    #!/usr/bin/env bash
    set -euo pipefail
    if just rtmp-up-docker 2>/dev/null; then
        :
    else
        echo "Docker niedostępny — uruchamiam MediaMTX z binarki (.rtmp-dev)…" >&2
        just rtmp-up-native
    fi
    just rtmp-print-urls

# Print publish / play URLs
rtmp-print-urls:
    @echo "RTMP publish/play: {{ rtmp_url }}"
    @echo "HLS:               {{ rtmp_hls }}"

# MediaMTX in Docker (background)
rtmp-up-docker:
    @just rtmp-docker compose -f {{ rtmp_compose }} up -d

# MediaMTX binary for WSL without Docker Desktop integration
rtmp-up-native:
    #!/usr/bin/env bash
    set -euo pipefail
    dir="{{ rtmp_dev_dir }}"
    bin="${dir}/mediamtx"
    pidfile="${dir}/mediamtx.pid"
    arch="$(uname -m)"
    case "${arch}" in
        x86_64) suffix="linux_amd64" ;;
        aarch64) suffix="linux_arm64" ;;
        *) echo "Nieobsługiwana architektura: ${arch}" >&2; exit 1 ;;
    esac
    version="{{ mediamtx_version }}"
    url="https://github.com/bluenviron/mediamtx/releases/download/${version}/mediamtx_${version}_${suffix}.tar.gz"
    mkdir -p "${dir}"
    if [[ ! -x "${bin}" ]]; then
        echo "Pobieram MediaMTX ${version}…" >&2
        tmp="$(mktemp -d)"
        trap 'rm -rf "${tmp}"' EXIT
        curl -fsSL "${url}" -o "${tmp}/mediamtx.tgz"
        tar -xzf "${tmp}/mediamtx.tgz" -C "${tmp}"
        mv "${tmp}/mediamtx" "${bin}"
    fi
    if [[ -f "${pidfile}" ]] && kill -0 "$(cat "${pidfile}")" 2>/dev/null; then
        echo "MediaMTX już działa (pid $(cat "${pidfile}"))" >&2
        exit 0
    fi
    nohup "${bin}" >"${dir}/mediamtx.log" 2>&1 &
    echo $! >"${pidfile}"
    sleep 0.5
    if ! kill -0 "$(cat "${pidfile}")" 2>/dev/null; then
        echo "MediaMTX nie wystartował. Log: ${dir}/mediamtx.log" >&2
        exit 1
    fi
    echo "MediaMTX pid $(cat "${pidfile}")"

# Stop MediaMTX (Docker or native)
rtmp-down:
    #!/usr/bin/env bash
    set -euo pipefail
    if just rtmp-docker compose -f {{ rtmp_compose }} ps -q 2>/dev/null | grep -q .; then
        just rtmp-docker compose -f {{ rtmp_compose }} down
    fi
    pidfile="{{ rtmp_dev_dir }}/mediamtx.pid"
    if [[ -f "${pidfile}" ]]; then
        pid="$(cat "${pidfile}")"
        if kill -0 "${pid}" 2>/dev/null; then
            kill "${pid}" || true
        fi
        rm -f "${pidfile}"
        echo "Zatrzymano natywny MediaMTX"
    fi

# Show container status
rtmp-status:
    @just rtmp-docker compose -f {{ rtmp_compose }} ps

# Follow MediaMTX logs
rtmp-logs:
    @just rtmp-docker compose -f {{ rtmp_compose }} logs -f --tail 50

# Test pattern + tone (same idea as bridge-encoder lavfi milestone)
rtmp-publish-test path=rtmp_path:
    #!/usr/bin/env bash
    set -euo pipefail
    url="rtmp://127.0.0.1:1935/{{ path }}"
    echo "Publishing to ${url} (Ctrl+C to stop)"
    exec ffmpeg -hide_banner -loglevel warning -re \
        -f lavfi -i testsrc=size=1280x720:rate=30 \
        -f lavfi -i sine=frequency=440:sample_rate=48000 \
        -c:v libx264 -preset veryfast -pix_fmt yuv420p -g 60 \
        -c:a aac -ar 48000 -b:a 128k \
        -f flv "${url}"

# Play the default stream in ffplay (run rtmp-publish-test in another terminal)
rtmp-play path=rtmp_path:
    ffplay -hide_banner -fflags nobuffer -flags low_delay \
        "rtmp://127.0.0.1:1935/{{ path }}"

# Play via HLS (lower latency tuning is server-side; good VLC fallback)
rtmp-play-hls path=rtmp_path:
    ffplay -hide_banner "http://127.0.0.1:8888/{{ path }}/index.m3u8"
