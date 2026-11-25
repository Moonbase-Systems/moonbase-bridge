# Lokalny RTMP do testów

Bridge i FFmpeg publikują na **MediaMTX** w Dockerze. Odbiór: `ffplay`, VLC albo HLS w przeglądarce/odtwarzaczu.

## Szybki start

```bash
just rtmp-up           # MediaMTX: Docker albo binarka w .rtmp-dev
just rtmp-publish-test # plansza testsrc + ton (osobny terminal)
just rtmp-play         # podgląd RTMP w ffplay
```

Zatrzymanie serwera: `just rtmp-down`.

`rtmp-up` próbuje najpierw **Docker** (`compose.rtmp.yaml`). Gdy Docker Desktop nie jest podpięty do WSL, pobiera [MediaMTX](https://github.com/bluenviron/mediamtx) do `.rtmp-dev/` i startuje w tle. Wymuszony Docker: `just rtmp-up-docker`. Tylko binarka: `just rtmp-up-native`.

## Adresy: WSL vs Windows

MediaMTX słucha w **WSL** (`0.0.0.0:1935`). **`127.0.0.1` w WSL** to nie to samo co **`127.0.0.1` w Windowsie** (chyba że masz włączony *mirrored networking* w `.wslconfig`).

Po `just rtmp-up` uruchom:

```bash
just rtmp-urls
```

Dostaniesz m.in. adres **eth0 WSL** (np. `172.30.x.x`) — **tego używaj w VLC na Windowsie**.

| Skąd | RTMP | HLS (gdy coś publikuje) |
| --- | --- | --- |
| WSL (`ffmpeg`, `just rtmp-play`) | `rtmp://127.0.0.1:1935/live/moonbase` | `http://127.0.0.1:8888/live/moonbase/index.m3u8` |
| **Windows (VLC)** | `rtmp://<WSL_IP>:1935/live/moonbase` | `http://<WSL_IP>:8888/live/moonbase/index.m3u8` |

W PowerShell: `wsl hostname -I` (pierwszy adres).

**Kolejność:** najpierw `just rtmp-up`, potem w **drugim** terminalu WSL `just rtmp-publish-test` (stream musi lecieć), dopiero wtedy VLC/HLS ma co odtwarzać.

Bridge na Windows publikuje na `127.0.0.1:1935` — trafia w MediaMTX w WSL przez przekierowanie portów WSL2; odtwarzacz na Windowsie i tak najpewniej potrzebuje **IP WSL**, nie localhost.

## Wymagania

- Docker (Desktop z WSL2 albo silnik w Linuxie)
- `ffmpeg` i `ffplay` w WSL (`sudo apt install ffmpeg`)
- VLC na Windows: *Otwórz strumień sieciowy* → URL z `just rtmp-urls` (kolumna Windows)

## Ręcznie (bez just)

```bash
docker compose -f compose.rtmp.yaml up -d

ffmpeg -re \
  -f lavfi -i testsrc=size=1280x720:rate=30 \
  -f lavfi -i sine=frequency=440:sample_rate=48000 \
  -c:v libx264 -preset veryfast -pix_fmt yuv420p -g 60 \
  -c:a aac -ar 48000 -b:a 128k \
  -f flv rtmp://127.0.0.1:1935/live/moonbase
```

## Typowe problemy

- **Connection refused** — `just rtmp-up` albo `docker ps` (kontener `moonbase-mediamtx`).
- **Broken pipe / VLC nie otwiera RTMP** — MediaMTX v1.11 bez `mediamtx.yml` odrzuca path (`not configured`). Zrób `just rtmp-down` i `just rtmp-up` po aktualizacji repo. Log: `just rtmp-logs`.
- **Dwa serwery naraz** (Docker + binarka w `.rtmp-dev`) — `just rtmp-down`, potem jedno `just rtmp-up`.
- **HLS 404 w VLC** — HLS jest dopiero gdy **coś publikuje** (`just rtmp-publish-test` w drugim terminalu).
- **Drugi publisher na tym samym path** — zatrzymaj poprzedni `ffmpeg` (`Ctrl+C`).
- **Opóźnienie w ffplay** — spróbuj `just rtmp-play-hls` albo VLC na HLS (po starcie publish).

Nginx-rtmp nie jest potrzebny na dev; MediaMTX wystarczy pod kamień milowy z [plan.md](./plan.md) (sekcja 6).
