# Plan prac

Bridge to proces w Rust bez okna. Studio edytuje dokument, Bridge go wykonuje: jeden Program Output, miks, RTMP przez FFmpeg. Termin to 18 grudnia 2026. Zadania są w Linearze, projekt **MoonBase Bridge**. Zasady są w [architecture.md](./architecture.md), [decisions.md](./decisions.md) i w ADR-010 w `moonbase-studio-web`.

Dziś jest szkielet: CLI, logi, zamknięcie na Ctrl+C i SIGTERM, `CONTRACT_VERSION` 0.1. Nie ma transportu, kontraktu, modelu projektu ani urządzeń. W Studio pasek trzyma `bridgeOnline` na `false` (`StudioTopBar.vue`), a pola `Po Bridge` w opcjach czekają na sesję.

Kolejność idzie dwoma szkieletami „od końca do końca”. Najpierw Studio widzi żywy Bridge. Potem Bridge publikuje planszę testową na RTMP. Render, kamery i miks wchodzą dopiero do działającej rury.

## 0. Środowisko

- [x] Rust w WSL: `rustup`, toolchain z `rust-toolchain.toml` (1.98), `just`, `taplo`, `typos`, `cargo-nextest`, `cargo-deny`, `committed`, `prek`. Zostaje `prek install` w klonie.
- [x] Windows: cross-kompilacja z WSL (`cargo-xwin`), `.exe` startuje z WSL jako proces Windows. Recepty `just *-win` i zadania VS Code, opis w README.
- [x] `moonbase-bridge` w `.code-workspace` Studio obok `moonbase-core`.
- [x] Lokalny serwer RTMP do testów: MediaMTX (`just rtmp-up`), odbiór w `ffplay` / VLC — [rtmp-dev.md](./rtmp-dev.md).

### Testy na Windows

WSL nie widzi kamer USB ani Media Foundation. Kamera, ekran i WASAPI wymagają procesu Windows. Wybrana droga A. B zostaje na wypadek potrzeby debuggera. Dwie drogi:

| Droga | Jak | Za | Przeciw |
| --- | --- | --- | --- |
| A. Cross-kompilacja z WSL | `cargo xwin build --target x86_64-pc-windows-msvc`, potem `./target/x86_64-pc-windows-msvc/debug/moonbase-bridge.exe` wprost z WSL. Proces startuje jako proces Windows | jeden klon, jedno IDE, ten sam target co CI | brak debuggera Visual Studio, `cargo-xwin` pobiera SDK MSVC |
| B. Drugi klon na dysku Windows | `C:\dev\moonbase-bridge`, rustup i Build Tools MSVC na Windows, VS Code z Windows | natywny build i debugger | dwa klony, synchronizacja przez git |

Klonu w `/mnt/c` z buildem w WSL nie robimy. `cargo` na `/mnt/c` jest bardzo wolny.

W obu drogach Bridge na Windows słucha na `127.0.0.1`. Przeglądarka na Windows łączy się z nim wprost. Dev serwer Studio w WSL jest widoczny z Windows pod `localhost:3000` (przekierowanie localhost WSL2).

## 1. Kontrakt Studio ↔ Bridge (STU-23)

Wszystko dalej zależy od tego kroku.

- [ ] Typy w `bridge-contract`: `serde` + `schemars`. Ramki `{ type, id?, payload }` z korelacją żądania i odpowiedzi.
- [ ] Powitanie: wersja kontraktu, wersja Bridge, OS, architektura, możliwości (lista koderów, platforma urządzeń). Różny `major` kończy rozmowę czytelnym błędem w Studio.
- [ ] Stany sesji: `connected`, `initializing`, `ready`, `running`, `stopping`, `error`. Stan RTMP osobno: `idle`, `connecting`, `live`, `paused`, `error`.
- [ ] Komendy: `session.load` (cały `ProjectFile`), `project.update`, `program.setScene`, `stream.start` / `stop` / `pause` / `resume`, `devices.list`.
- [ ] Zdarzenia: stan sesji, stan RTMP, lista urządzeń, liczby wykonania, błąd źródła.
- [ ] `just schema` zapisuje JSON Schema do `schema/`. CI pada, gdy plik jest nieaktualny (ADR-002).
- [ ] Studio generuje typy TS z `schema/` (np. `json-schema-to-typescript`). Jedno źródło prawdy, ręcznie nie przepisujemy.

## 2. Transport: `bridge-server`

- [ ] Axum na `127.0.0.1`, stały port z możliwością zmiany flagą `--port`.
- [ ] `GET /health`: wersja i kontrakt, bez sesji. Studio odpytuje go, żeby wykryć Bridge.
- [ ] `GET /ws`: WebSocket na zdarzenia i komendy.
- [ ] Bezpieczeństwo: lista dozwolonych `Origin` (produkcyjna domena Studio, `http://localhost:3000` w dev). Inna strona w przeglądarce nie może sterować transmisją.
- [ ] Chrome: strona `https` łącząca się z loopback przechodzi przez Local Network Access (zgoda użytkownika, preflight). Sprawdzić na produkcyjnym adresie Studio, nie tylko na dev.
- [ ] Zachowanie przy drugiej karcie Studio (do decyzji: jeden klient czy wielu).
- [ ] Zerwanie WebSocketu nie dotyka programu ani RTMP.

## 3. Pierwsze połączenie w Studio (STU-7)

- [ ] Port `BridgeClient` w `layers/studio/app/ports/`, adapter WebSocket w `layers/studio/app/infrastructure/bridge/`: wykrycie przez `/health`, powitanie, ponowne łączenie z backoffem.
- [ ] Stan połączenia w osobnym store sesji, nie w `ProjectFile` (ADR-010).
- [ ] `bridgeOnline` w `StudioTopBar.vue` czyta stan z tego store. Wskaźnik pokazuje `ok`, `offline` i niezgodną wersję.
- [ ] Tryb Standalone i Connected: pola `Po Bridge` pokazują się tylko przy gotowej sesji. Zerwanie chowa je i zostawia wartości w pliku.
- [ ] **Kamień milowy:** Bridge na Windows, Studio w przeglądarce, kropka „Bridge” zielona.

## 4. Model projektu: `bridge-project`

- [ ] Model `serde` aktualnego `ProjectFile`, tylko odczyt. Studio jest dziś na `formatVersion: 4`, a README i ADR-004 Bridge mówią o v2. Poprawić dokumenty.
- [ ] Nieznane pola przechodzą bez błędu. Studio dodaje pola szybciej niż Bridge.
- [ ] Fixtury: Studio eksportuje przykładowe projekty (`serializeProjectFile`) do `crates/bridge-project/tests/fixtures/`. Opcjonalnie `z.toJSONSchema` z Zod 4 w Studio do kontroli zgodności.
- [ ] `session.load` przy starcie sesji, potem `project.update` po każdej zatwierdzonej zmianie. Undo nie idzie przez transport. Na start wysyłamy cały dokument z numerem rewizji, łatki (JSON Patch) dopiero, gdy rozmiar zacznie przeszkadzać.

## 5. Sesja: `bridge-session`

- [ ] Automat stanów z kroku 1, testowany bez urządzeń.
- [ ] Studio pokazuje stan, który zgłasza Bridge, a nie skutek kliknięcia.

## 6. RTMP z planszą testową: `bridge-encoder` (STU-19, STU-31)

- [ ] `ffmpeg` jako proces potomny (`tokio::process`). Najpierw wejście `lavfi testsrc` + `sine`, bez renderu.
- [ ] Ustawienia transmisji z dokumentu: adres, klucz, rozdzielczość, klatki, bitrate. Najpierw w Studio jako pola dokumentu (FR-02), dziś `ProjectOutputSettings` ma tylko `profile`.
- [ ] Start, stop, pauza, wznowienie z paska Studio. Pauza rozłącza RTMP, proces i projekt zostają.
- [ ] Parsowanie `-progress`: FPS, bitrate, prędkość. `sysinfo`: CPU i pamięć. Zdarzenie co sekundę.
- [ ] Wyjście `ffmpeg` to stan RTMP `error`. Bridge żyje dalej.
- [ ] Panel monitoringu w Studio (STU-18). Brak pomiaru zostaje pustym polem.
- [ ] Windows: `ffmpeg.exe` w paczce. Wybór kodera NVENC / QSV / AMF z powrotem na `libx264`.
- [ ] **Kamień milowy:** przycisk Stream w Studio, plansza testowa w VLC z lokalnego serwera RTMP.

## 7. Program Output: `bridge-render`

- [ ] `wgpu` (D3D12 / Vulkan), kanwa z `settings.outputProfile`.
- [ ] Kolejność to indeks `scene.elements`, 0 na spodzie. Widoczność, transform, crop, krycie, tło.
- [ ] Rozmieszczenie zgodne z podglądem Pixi w `layers/studio/app/infrastructure/pixi/`. Testy porównawcze na tych samych fixturach.
- [ ] Obrazy, tekst (`glyphon`), kolor. Potem wideo z pliku przez `ffmpeg` jako dekoder.
- [ ] Surowe klatki do stdin `ffmpeg` zamiast planszy testowej.
- [ ] Klatka programu w Studio: podgląd o niskim klatkażu (do decyzji: JPEG po WebSocket albo MJPEG po HTTP).
- [ ] `program.setScene`: zmiana kompozycji bez zrywania RTMP (FR-06).

## 8. Urządzenia: `bridge-platform` (STU-26, STU-65)

- [ ] Najpierw Windows: lista kamer z Media Foundation, `deviceId` to symbolic link. Klatki do renderu.
- [ ] Lista wejść i wyjść audio przez `cpal`.
- [ ] Ekran: Windows.Graphics.Capture.
- [ ] Linux: V4L2 (`/dev/v4l/by-id/...`), portal ScreenCast + PipeWire z tokenem przywrócenia.
- [ ] Studio: wybór `deviceId` kamery, `displayId`, `programMicDeviceId` z listy Bridge.
- [ ] Utrata źródła to błąd źródła. Reszta programu rysuje się dalej.

## 9. Miks programu: `bridge-audio` (STU-29)

- [ ] Kanały z dokumentu: głośność, mute, balans.
- [ ] DSP: EQ, kompresor, limiter, bramka. Testy na buforach, bez urządzeń.
- [ ] PCM do `ffmpeg` razem z obrazem. Utrata mikrofonu nie zatrzymuje obrazu.

## 10. Później w tym samym terminie

- [ ] Klatki kamer dla MoonBase AI i komenda rekomendacji ujęcia. Awaria AI nie gasi RTMP.
- [ ] Przejścia między scenami na programie.
- [ ] Nagrywanie na maszynie Bridge: katalog, `mkv` / `mov`, koder sprzętowy.
- [ ] Paczki release z CI (`windows-x64`, `windows-arm64`, `linux-x64`, `linux-arm64`). Link „Pobierz Bridge” w Studio przy trybie Standalone.

## Bramki

- Kontrakt i schemat są, zanim Studio pisze klienta.
- Kropka Bridge w Studio jest zielona, zanim jest RTMP.
- Plansza testowa jest na RTMP, zanim jest render.
- Render jest zgodny z podglądem Pixi na fixturach, zanim są kamery.
- Kamera i miks są na tym samym Program Output, zanim jest start RTMP z prawdziwym obrazem.
- Studio dostaje rzeczywisty stan RTMP, zanim panel pokazuje FPS i bitrate.

## Otwarte pytania

- Czy STU-23 w Linearze ma już spisany zestaw komend i stanów?
- Port Bridge i produkcyjna domena Studio (lista `Origin`).
- Jeden klient Studio naraz czy wielu.
- Format klatki programu w Studio.
