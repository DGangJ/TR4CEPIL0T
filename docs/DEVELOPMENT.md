# TR4CEPIL0T — development notes

## Variants

Everything is generated from one source tree by `build_all.py`, in 4 variants:

| Variant | Radio | Splash | Widgets | Main colour |
|

## Repository structure

```
build_all.py          builds dist/<variant>/ and dist/<variant>.zip for every variant
config.py             the 4 variants: names, colours, splash text, LED colour, theme, sound prefix
src/widgets/          Lua sources: common.lua (shared) + trails_body.lua + inputs_body.lua + sim_body.lua
src/leds/leds.py      LED effect generator (TX15 ring geometry, colour variants, PA01 mode)
src/art/splash.py     splash/shutdown renderer (dot-matrix fonts)
src/art/logo.py       TR4CEPIL0T logo renderer
src/art/theme/        theme backgrounds, logos and screenshots
src/sounds/           tronsfx.py (synth toolkit), make_sfx.py (sound design), wav/ (shipped sounds)
tools/luacheck.py     block/bracket balance check for Lua (no Lua interpreter needed)
docs/images/           screenshots used by the README
tools/sim_*.py        PC previews of the widget layouts (480x320 / 320x240)
LICENSE               GNU GPL v3.0
.github/FUNDING.yml   Ko-fi button on the GitHub page
brand/                TR4CEPIL0T logo (black, transparent) and "T4" icon
dist/                 built packs (not committed; published as GitHub Release assets)
```

## Building

Version, licence and support link are set at the top of `config.py` (`VERSION`, `LICENSE`, `KOFI_URL`, `REPO_URL`)
and are written into every Lua header and into the pack `README.txt`.

Requirements: Python 3, Pillow. For sounds: numpy + scipy.

```
python3 build_all.py                  # default: TR4CEPIL0T_TX15
python3 build_all.py iBassFPV_TX15    # one variant
python3 src/sounds/make_sfx.py        # regenerate the WAV files (optional)
```

Widgets are assembled as `header + common.lua + <page>_body.lua`, with the variant colours and names
substituted. A Lua balance check runs on every build.

## Design constraints and lessons learned

- **"CPU limit" errors:** EdgeTX stops a widget whose `refresh()` takes too long. What caused it in the
  early versions: rounded/tab panel shapes drawn as many rectangles, per-segment gradients and
  `Bitmap.resize` textures. Keep drawing to plain rectangles, cache font measurements and colours, and
  avoid per-frame table creation. Test on the radio — the Companion simulator is much faster.
- **`Bitmap.resize` textures produced visible artefacts** on the TX15; textures were removed.
- **Widget options:** EdgeTX up to 2.10 keeps only the first 5 options, so each widget has at most 5
  and colours come first. Changing option order/names requires removing and re-adding the widget.
- **Colours:** `lcd.RGB()` / COLOR options hold RGB565 in the upper 16 bits; `rgbOf()` decodes them
  (used to build the trail gradient from `TrailCol`).
- **Telemetry:** `getSourceValue()` returns the last value plus whether it is current (used for LOST).
- **Lua has no API to switch models, read the USB state or change ELRS packet rate/power.**
- Splash/shutdown: `/IMAGES/splash.png` and `/IMAGES/shutdown.png`, exact screen size.

## Status — to be verified on the radio

- `TrailCol` colour decoding (RGB565 assumption).
- USB charging heuristic (appears ~1 min after plugging in; may not appear with a full battery).
- PA01: LED layout, EdgeTX version (option limit), switch/pot names; gyro source names on the TX15.

## Roadmap (ideas for future development)

Ideas for future versions (not scheduled):
1. **One model for every quad:** read the craft name from Betaflight (MSP over CRSF) and load a per-quad
   profile (timers, alarms, cell count, layout). Requires the same ELRS binding phrase on every quad.
2. **Rates on the radio:** read/edit Betaflight rates via MSP (only while disarmed), with a rate-curve view.
3. **Crash finder:** detect a crash (telemetry loss while armed, sudden altitude/speed drop) and show a QR code
   with the last GPS position; also save it to the SD card.
4. **Sim / RF sleep mode:** switch-activated mode that turns RF off (`model.setModule`) and changes the UI
   (automatic USB detection is not available in Lua).
5. Hover throttle "midpoint" finder, logbook per quad (flights, time, mAh), pre-arm checklist,
   post-flight summary, light/dark themes.
Constraints: LVGL UI needs EdgeTX 2.11+, CPU/memory limits require loading modules on demand.

## Continuing development

Start a new session with this repository and a short brief, for example:
"Continue the TR4CEPIL0T EdgeTX project (README.md). Change X; keep the 4 variants and English comments."
Edit `src/` or `config.py`, run `python3 build_all.py`, test `dist/<variant>` on the radio.

## Releasing a new version

1. Update `VERSION` in `config.py` and add a section to `CHANGELOG.md`.
2. `python3 build_all.py` and test `dist/TR4CEPIL0T_TX15` on the radio.
3. Commit and push, then create a GitHub Release with tag `vX.Y.Z` and attach `dist/TR4CEPIL0T_TX15.zip`.
