# TR4CEPIL0T — project history and decisions

Backup summary of how the project was built, what was decided and why, and what is still open.
Read this first when continuing the project in a new session (together with `README.md`,
`docs/DEVELOPMENT.md` and `CHANGELOG.md`).

Last update: 2026-11-20 (after the v1.1.0 release).

---

## 1. Timeline

| Date | Milestone |
|---|---|
| 2026-11 (start) | First widgets on a RadioMaster TX15 Max (EdgeTX 2.12 "Queen Anne's Revenge"): fixed "CPU limit" errors and texture artefacts in third-party widgets. |
| 2026-11 | Own dot-matrix, black-background, TRON-style layout built from reference images: fading gimbal trails. |
| 2026-11 | Page 1 redesign (top telemetry bar, flight mode, date, time) and page 2 (sticks, pots, gyro, switches, extra telemetry). Splash, theme, shutdown image. |
| 2026-11 | LED ring effects for the TX15 Max gimbals, TRON-style sounds, USB charging indicator. |
| 2026-11-17 | Variants: personal iBass&FPV, Squadding Quads (red) for TX15 and FlySky PA01 (320x240). `Accent` / `TrailCol` options. |
| 2026-11-18 | Brand **TR4CEPIL0T** (logo, splash). Single source tree + `build_all.py` / `config.py` for all variants. 9 LED effects x 10 colours. All comments in English. |
| 2026-11-19 | Focus on the public TX15 pack. GPS block with last known position (saved to SD), date next to the time, automatic flight timer + tap cycle time > T1 > T2. **TPSim** widget for a "Sim Mode" model. |
| 2026-11-19 | Public release preparation: GPL-3.0 licence, Ko-fi (`ko-fi.com/tr4cepil0t`) via `.github/FUNDING.yml`, public README with screenshots, release notes **v1.0.0**, clean git history. |
| 2026-11-20 | **FrSky Ethos** port (beta 0.9.0) for the X18RS (800x480): TPTrails + TPInputs, sticks/switches/names read from the radio, ELRS sensor auto-detection, PC mock to run the real script. Fix: switch ranges read from the radio. |
| 2026-11-20 | Research of EdgeTX colour radios; plan approved for a **Global EdgeTX pack** + an **optimised TX15 pack** (see section 8). |
| 2026-11-20 | **v1.1.0**: Global EdgeTX packs per resolution (480x320, 480x272, 320x240, 800x480), switch positions read from the radio, EdgeTX PC mock. |
| 2026-11-20 | v1.1.0 **published** on GitHub (`github.com/DGangJ/TR4CEPIL0T`, one Release with one zip per pack). README Ko-fi button fixed (HTML inside the centred block). |

## 2. Packs

| Pack | Status | Contents |
|---|---|---|
| `TR4CEPIL0T_TX15` | **v1.1.0, public** | TPTrails, TPInputs, TPSim, theme, splash/shutdown (+ alternative iBass&FPV / Squadding Quads splashes), 100 LED scripts, sounds |
| `TR4CEPIL0T_ETHOS` | **0.9.0 beta**, being tested in the Ethos web simulator | TPTrails, TPInputs (no LEDs, no sounds) |
| `iBassFPV_TX15` | archived (personal) | same as TX15 with iBass&FPV branding (iBFTrails / iBFInputs) |
| `SquaddingQuads_TX15` / `_PA01` | archived | red variant (SQTrails / SQInputs), PA01 compact layout |

Build: `python3 build_all.py` (TX15 + Ethos), or by name (`python3 build_all.py iBassFPV_TX15`, `ethos`).

## 3. Visual identity

- Black background, 3x5 dot-matrix font for values, small sans labels.
- Colours (RGB): accent orange **255,84,40**; warning amber 255,176,0; critical red 255,50,50;
  labels 120,140,150; values 170,200,210; dim 70,80,85; head 210,240,245; trail default cyan 130,200,210.
- LED amber **255,20,0** ("reddish amber"); theme EDIT colour 0xFF1400, FOCUS 0xFF5428.
- Squadding Quads variant: red 255,28,40, warning yellow 255,210,0, LEDs 255,0,8; slogan "Send it!" in red.
- Splash: "TR4CEPIL0T" centred on the word only (the trail on the left is not counted), subtitle
  "EDGETX FPV COPILOT".
- Logo files in `brand/` (black, transparent, "T4" icon).

## 4. Widgets — behaviour decided with the user

**Page 1 (Trails)**
- Top bar: MODEL, LQ %, RSSI dBm, DRONE nS (cells auto-detected), RADIO % (+ USB charging bolt).
- Middle: 24-sample fading trails of both gimbals, bigger dots, faint grid and crosshair.
- Bottom left: flight mode (Betaflight `FM`; "*" = disarmed).
- Bottom centre GPS: satellites in accent orange while flying; coordinates when disarmed;
  `GPS LAST` (accent) after crash / telemetry loss; `GPS SAVED` after restart; `NO GPS` without sensor.
  Last fix saved to the SD card (every 10 s while changing, immediately on loss).
- Bottom right: time with small date in accent orange; automatic T1 while it runs;
  tap (full screen) / ENTER cycles time > T1 > T2.
- Alerts: LQ < 70 warn / < 50 critical; RSSI < -95 / < -105 dBm; cell < 3.5 / < 3.3 V; critical blinks.

**Page 2 (Inputs)**: sticks named ROLL / PITCH / THR / YAW, pots/sliders, gyro, switches
(SE/SF and SW1-SW6 are 2-position on the TX15; 3-position learned when seen in the middle),
extra telemetry (TX power, SNR, downlink LQ, current, used mAh, cell V). Channels removed on request.

**TPSim**: RF state (OFF green / ON blinking red), session time, flights (arm count), radio battery,
trails with axis %, ARMED / SAFE, virtual pack timer (counts while armed, amber at 30 s, red at 0 with tones).

## 5. Hardware facts confirmed on the TX15 Max

- 10 LEDs per gimbal ring: right ring 0-9, left ring 10-19; LED 0 of each ring faces the radio centre;
  left ring counts anticlockwise (`BASE = {90, 270}`, `DIR = {-1, 1}`). iStick mapping confirmed on all axes.
- SE, SF and SW1-SW6 are 2-position switches.
- Widget options: max 5 on EdgeTX <= 2.10 (10 from 2.11) — kept at 5 for compatibility; colours first.
- Touch events only reach a widget in full screen mode.

## 6. Lessons learned / constraints

- "CPU limit": avoid many-rectangle rounded shapes, gradients and `Bitmap.resize` textures; cache fonts/colours.
- EdgeTX colours are RGB565 in the upper 16 bits (`rgbOf()` decodes them for the trail gradient).
- No Lua API for USB state, model switching, ELRS packet rate — USB charging is a voltage heuristic.
- Ethos: widgets via `system.registerWidget` (key <= 7 chars), `wakeup` + `lcd.invalidate()` only on change,
  settings via `configure` + `storage`; sensor names differ from EdgeTX (CRSF names, translated), so they are
  auto-detected with manual override; value ranges differ per source type, so they are read/learned at run time.

## 7. Distribution

- Repository: **https://github.com/DGangJ/TR4CEPIL0T**. The README is sometimes edited on github.com:
  check for remote commits and pull before overwriting. `REPO_URL` in `config.py` is set; it reaches the
  packs from the next version (v1.1.0 as published has no source line in the pack README.txt).
- Releases: one Release per version with every pack as a separate zip; Ethos as a separate pre-release when tested.
- Private packs live in the ignored `local/` folder (see `docs/DEVELOPMENT.md`) and are never published.
- GitHub: source in the repo, built zips as Release assets (`v1.0.0` with `TR4CEPIL0T_TX15.zip`).
  Step-by-step with GitHub Desktop (Add local repository > create repository > Publish).
- Support: Ko-fi `ko-fi.com/tr4cepil0t` (Sponsor button via `.github/FUNDING.yml`, README badges, pack README).
- Licence GPL-3.0 for code; TR4CEPIL0T name/logo and the iBass&FPV / Squadding Quads splashes are not covered.
- Ethos pack: install with FrSky Suite > Lua Library (manifest `ethos_lua_manifest.json`, key `com.tr4cepil0t.ethos`)
  or copy `tr4ce/` into `scripts/`. Testing in the Ethos web simulator (ethos-simulator.frsky-rc.com).

## 8. Plan approved on 2026-11-20 (steps 1-3 done in v1.1.0, waiting for tests on real radios)

1. **Global EdgeTX pack "TR4CEPIL0T"** for landscape colour radios, minimum EdgeTX 2.11:
   - 480x320: Jumper T15 / T15 Pro / T15-H7 / T22, RadioMaster TX15 / GX15, Flysky PL18 / PL18EV / PL18U / ST16
   - 480x272: RadioMaster TX16S / MkII, HelloRadioSky V15 / V16, Jumper T16 / T18 / T18H7, FrSky X10 / X12S,
     iFlight Commando 14, Fatfish F16, Senduwing H17
   - 320x240: Flysky PA01, HelloRadioSky V12
   - 800x480: RadioMaster TX16S MK3
   - Page 2 detects switches, their positions (2/3, via the `switches()` iterator + names) and quantity,
     pots/sliders and gyro; layout scales to the resolution; theme background per resolution; sounds included;
     no LED effects. Portrait radios (NV14, EL18, NB4+) left out unless requested.
2. **Optimised TX15 pack**: current pack (LEDs, TPSim, all TX15 tuning) built from the same shared code.
3. Validation: EdgeTX API mock on the PC (like the Ethos one) at all four resolutions; real testers wanted,
   at least one 480x272 radio (TX16S).
4. Ethos: wait for the user's simulator / radio tests, then fix and release.

## 8b. Next session (week of 2026-11-23)

- **v1.2: GPS track + crash finder** (track view with path and last-fix pin, home distance/bearing, track saved
  to SD, QR code with the coordinates). Details in `docs/DEVELOPMENT.md` > Roadmap. Start with a mockup on the radio.
- After v1.2: **TPDrone** page (pixel quad that turns and tilts with the sticks, or with the real attitude from the
  CRSF `Ptch` / `Roll` / `Yaw` sensors when available). Details in `docs/DEVELOPMENT.md` > Roadmap.
- Ethos beta: wait for the user's tests in the simulator / X18RS.

## 9. Open items to verify

- TX15: `TrailCol` decoding, USB charging heuristic timing, gyro source names, TPSim `ArmSw` SWITCH option,
  timer auto-detection, disarm via FM "*", `lastgps.txt` writing.
- Ethos: ELRS sensor names/units, stick range, 3-position detection, touch/ENTER events, `lastgps.txt`.
- Future ideas (analysis only, not scheduled): per-quad profiles via craft name (MSP), rates editing,
  crash QR code with GPS (EdgeTX 2.11 LVGL / Ethos `lcd.renderQrCode`), sim mode RF off, hover midpoint finder,
  logbook, pre-arm checklist.
