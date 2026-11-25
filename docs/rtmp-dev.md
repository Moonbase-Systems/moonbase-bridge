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

## Adresy (domyślne)

| Cel | URL |
| --- | --- |
| Publikacja (Bridge / FFmpeg) | `rtmp://127.0.0.1:1935/live/moonbase` |
| Odtwarzanie RTMP | ten sam URL |
| HLS (gdy RTMP w VLC szwankuje) | `http://127.0.0.1:8888/live/moonbase/index.m3u8` |

Ścieżkę `live/moonbase` możesz zmienić flagą w `just rtmp-publish-test` (`path=live/inny`).

## Wymagania

- Docker (Desktop z WSL2 albo silnik w Linuxie)
- `ffmpeg` i `ffplay` w WSL (`sudo apt install ffmpeg`)
- Na Windows: VLC → Media → Open Network Stream → `rtmp://127.0.0.1:1935/live/moonbase`

Bridge na Windows i serwer w WSL dzielą `127.0.0.1` przez przekierowanie localhost WSL2 — ten sam URL z obu stron.

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
- **Drugi publisher na tym samym path** — zatrzymaj poprzedni `ffmpeg` (`Ctrl+C`).
- **Opóźnienie w ffplay** — spróbuj `just rtmp-play-hls` albo VLC na HLS.

Nginx-rtmp nie jest potrzebny na dev; MediaMTX wystarczy pod kamień milowy z [plan.md](./plan.md) (sekcja 6).
