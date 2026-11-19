# Changelog

## v1.0.0 — first public release
- Public TR4CEPIL0T pack for the RadioMaster TX15 / TX15 Max.
- GPL-3.0 licence, Ko-fi support link, version and credits in every widget header and in the pack README.txt.
- Public README with screenshots; development notes moved to docs/DEVELOPMENT.md.
- Theme screenshot updated to the current page 1 layout.

## 2026-11-19
- New TPSim widget for a "Sim Mode" model: RF state, session, flights, virtual pack timer, trails with axis values.
- Focus on the public TR4CEPIL0T_TX15 pack (DEFAULT_BUILD); other variants archived.
- Alternative splash images (iBass&FPV, Squadding Quads) in IMAGES/SPLASH/.
- Page 1 bottom: GPS block in the centre (sats / coordinates / GPS LAST / GPS SAVED / NO GPS), last fix saved to the SD card.
- Date moved next to the time (small, accent colour); automatic flight timer and tap cycle time -> T1 -> T2.
- Satellite count, date, T1/T2 tags and GPS LAST use the project accent orange (255,84,40).

## 2026-11-18 — project packaged
- Single source tree + `build_all.py` / `config.py` building the 4 variants (public, iBass&FPV, Squadding Quads TX15 and PA01).
- TR4CEPIL0T splash for every variant (word centred, trail on the left), brand line per variant.
- `TrailCol` widget option (trail colour); trail length fixed at 24 to stay within 5 options.
- LED colour variants: 9 effects x 10 colours on the TX15 packs.
- Theme EDIT colour set to 255,20,0 (orange variants).
- All comments and notes in English.

## 2026-11-17
- Widgets `Accent` option first; `StickMode` renamed from `Mode`; trails widget limited to 5 options.
- FlySky PA01 support: compact layout for 320x240, automatic 3-position switch detection.
- Squadding Quads red repack.
- LED effects confirmed on the TX15 Max: 10 LEDs per ring, mirrored geometry; iStick, iScan, iLevel, iArm added.
- TRON-style sound pack, EdgeTX theme, shutdown image.
- Page 2 (inputs): ROLL/PITCH/THR/YAW, 2-position switch display, extra telemetry instead of channels.
- USB charging indicator (voltage heuristic), bigger trail dots, faint crosshair.
- Page 1 redesign: telemetry top bar, flight mode, date and time; grid / alerts / lost extras.
- Fixed "CPU limit" errors and texture artefacts (plain shapes, no textures, caching).
