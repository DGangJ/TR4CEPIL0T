#!/usr/bin/env python3
"""
Builds every pack defined in config.py into dist/<variant>/ and dist/<variant>.zip.

    python3 build_all.py            # DEFAULT_BUILD (the public TR4CEPIL0T_TX15 pack)
    python3 build_all.py iBassFPV_TX15

Each pack is copied to the root of the radio SD card as is:
    WIDGETS/<trails>/main.lua, WIDGETS/<inputs>/main.lua
    IMAGES/splash.png, IMAGES/shutdown.png
    SCRIPTS/RGBLED/*.lua
    THEMES/<theme>/theme.yml + images
    SOUNDS/pt/*.wav   (move to SOUNDS/en if the radio voice language is English)
Requires: Python 3, Pillow (art). Sounds are copied from src/sounds/wav (regenerate with src/sounds/make_sfx.py).
"""
import os, sys, shutil, subprocess, zipfile

ROOT = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, ROOT)
sys.path.insert(0, os.path.join(ROOT, "src", "leds"))
sys.path.insert(0, os.path.join(ROOT, "src", "art"))
from config import VARIANTS, DEFAULT_BUILD, VERSION, KOFI_URL, REPO_URL, LICENSE
import leds
from PIL import Image

SRC = os.path.join(ROOT, "src")
DIST = os.path.join(ROOT, "dist")


def credits(prefix):
    """Version / licence / support lines added to Lua headers and the pack README."""
    lines = ["TR4CEPIL0T v%s - licence %s" % (VERSION, LICENSE)]
    if REPO_URL:
        lines.append("Source: " + REPO_URL)
    lines.append("Support the project: " + KOFI_URL)
    return "".join(prefix + l + "\n" for l in lines)


def build_readme(out, v):
    w = v["widgets"]
    txt = """TR4CEPIL0T v{ver} - EdgeTX dot-matrix layout for FPV radios
{brand} pack ({sw}x{sh} screen, RadioMaster TX15 / TX15 Max)

INSTALL
1. Back up your SD card.
2. Copy every folder of this pack (WIDGETS, IMAGES, SCRIPTS, THEMES, SOUNDS) to the
   root of the radio SD card, merging with the existing folders.
3. Restart the radio.

SET UP
- Theme: SYS > Themes > {theme}.
- Screens: Model > Screens > add a screen, layout "Full screen (1x1)", top bar and
  sliders off, widget {trails} (page 1). Add a second screen with {inputs} (page 2).
- Simulator model: a screen with {sim}.
- Widget options (colours, stick mode, alerts): long press the widget > Widget settings.
- LED effects: Special Functions > RGB leds > choose a script (e.g. iOrbit, iStick).
- Sounds: Special Functions > Play Track (SOUNDS/pt; move them to SOUNDS/en for an
  English voice pack).
- Alternative splash screens: IMAGES/SPLASH (copy one over IMAGES/splash.png).

Use at your own risk. Always check the radio before flying.
Not affiliated with RadioMaster or EdgeTX.

""".format(sw=v["screen"][0], sh=v["screen"][1], ver=VERSION, brand=v["brand"], theme=v["theme"]["name"], trails=w["trails"],
           inputs=w["inputs"], sim=w.get("sim") or "-")
    open(os.path.join(out, "README.txt"), "w").write(txt + credits(""))


def build_widgets(out, v):
    w = v["widgets"]
    c = open(os.path.join(SRC, "widgets", "common.lua")).read()
    tb = open(os.path.join(SRC, "widgets", "trails_body.lua")).read()
    ib = open(os.path.join(SRC, "widgets", "inputs_body.lua")).read()
    sb = open(os.path.join(SRC, "widgets", "sim_body.lua")).read()
    a, b = "local ORANGE   = lcd.RGB(255, 28, 40)    -- main colour", "local AMBER    = lcd.RGB(255, 210, 0)    -- warning colour"
    assert a in c and b in c, "colour placeholders not found in common.lua"
    c = c.replace(a, "local ORANGE   = lcd.RGB(%d, %d, %d)    -- main colour (change it in Widget Settings > Accent)" % v["accent"])
    c = c.replace(b, "local AMBER    = lcd.RGB(%d, %d, %d)    -- warning colour" % v["warn"])
    for body, name, folder, desc in (
            (tb, w["trails"], w["trails_dir"], "page 1: gimbal trails, telemetry top bar, flight mode, date and time"),
            (ib, w["inputs"], w["inputs_dir"], "page 2: sticks, pots, gyro, switches and extra telemetry"),
            (sb, w.get("sim"), w.get("sim_dir"), "simulator page: RF state, session, flights, virtual pack, trails")):
        if not name:
            continue
        body = body.replace("/WIDGETS/SQTRAIL/", "/WIDGETS/%s/" % w["trails_dir"])
        body = body.replace('"TPSim"', '"%s"' % (w.get("sim") or "TPSim"))
        body = body.replace('"SQTrails"', '"%s"' % w["trails"]).replace('"SQInputs"', '"%s"' % w["inputs"]).replace("SQTrails", w["trails"])
        hdr = ("-- %s  (/WIDGETS/%s/main.lua)  -  %s\n-- %s\n" % (name, folder, v["brand"], desc)) + credits("-- ") + (
               "-- Works on 480x320 (TX15) and 320x240 (PA01) screens: the layout adapts automatically.\n"
               "-- Use on a screen with a Full screen (1x1) layout, top bar and sliders turned off.\n\n")
        d = os.path.join(out, "WIDGETS", folder)
        os.makedirs(d, exist_ok=True)
        open(os.path.join(d, "main.lua"), "w").write(hdr + c + body)


def build_images(out, v):
    from splash import splash
    W, H = v["screen"]
    im = splash(W, H, v["splash_accent"], v["splash_brand"])
    d = os.path.join(out, "IMAGES")
    os.makedirs(d, exist_ok=True)
    im.save(os.path.join(d, "splash.png"))
    im.save(os.path.join(d, "shutdown.png"))
    alts = v.get("alt_splashes", [])
    if alts:
        ad = os.path.join(d, "SPLASH")
        os.makedirs(ad, exist_ok=True)
        notes = ["Alternative splash / shutdown images for TR4CEPIL0T.",
                 "To use one: copy it to /IMAGES/ and rename it to splash.png (boot) and/or shutdown.png (power off).",
                 "The original TR4CEPIL0T image is also here as tr4ce.png.", ""]
        im.save(os.path.join(ad, "tr4ce.png"))
        for fname, acc, brand in alts:
            splash(W, H, acc, brand).save(os.path.join(ad, fname))
            notes.append("%-12s TR4CEPIL0T + %s" % (fname, " ".join(t for t, _ in brand)))
        open(os.path.join(ad, "README.txt"), "w").write("\n".join(notes) + "\n")
    return im


def build_theme(out, v, splash_im):
    t = v["theme"]
    W, H = v["screen"]
    d = os.path.join(out, "THEMES", t["dir"])
    os.makedirs(d, exist_ok=True)
    w = v["widgets"]
    lines = ["---", "summary:", "  name: %s" % t["name"], "  author: %s" % t["name"], "  info: %s" % t["info"],
             "  description: Theme matching the %s and %s widgets and the %s splash." % (w["trails"], w["inputs"], v["brand"]),
             "colors:"]
    for k, val in t["colors"].items():
        lines.append("  %-11s 0x%06X" % (k + ":", val))
    open(os.path.join(d, "theme.yml"), "w").write("\n".join(lines) + "\n")
    art = os.path.join(SRC, "art", "theme")
    shutil.copy(os.path.join(art, "background_%dx%d.png" % (W, H)), os.path.join(d, "background_%dx%d.png" % (W, H)))
    shutil.copy(os.path.join(art, t["logo"]), os.path.join(d, "logo.png"))
    for i in (1, 2):
        shutil.copy(os.path.join(art, "shot%d_%s.png" % (i, t["shots"])), os.path.join(d, "screenshot%d.png" % i))
    splash_im.save(os.path.join(d, "screenshot3.png"))


def build_leds(out, v):
    l = v["leds"]
    leds.generate(os.path.join(out, "SCRIPTS", "RGBLED"), v["brand"], l["colour"], l["name"], pa01=l["pa01"], variants=l["variants"])


def build_sounds(out, v):
    src = os.path.join(SRC, "sounds", "wav")
    d = os.path.join(out, "SOUNDS", "pt")
    os.makedirs(d, exist_ok=True)
    for f in os.listdir(src):
        if not f.endswith(".wav") or f.startswith("_"):
            continue
        name = f.replace("ibfon", v["sound_prefix"] + "on").replace("ibfoff", v["sound_prefix"] + "off")
        shutil.copy(os.path.join(src, f), os.path.join(d, name))


def check_lua(out):
    files = []
    for dp, _, fs in os.walk(out):
        files += [os.path.join(dp, f) for f in fs if f.endswith(".lua")]
    r = subprocess.run([sys.executable, os.path.join(ROOT, "tools", "luacheck.py")] + files, capture_output=True, text=True)
    bad = [l for l in r.stdout.splitlines() if not l.endswith(" OK")]
    if bad:
        raise SystemExit("Lua balance check failed:\n" + "\n".join(bad))
    return len(files)


def build(name):
    v = VARIANTS[name]
    out = os.path.join(DIST, name)
    shutil.rmtree(out, ignore_errors=True)
    build_widgets(out, v)
    im = build_images(out, v)
    build_theme(out, v, im)
    build_leds(out, v)
    build_sounds(out, v)
    build_readme(out, v)
    n = check_lua(out)
    z = os.path.join(DIST, name + ".zip")
    with zipfile.ZipFile(z, "w", zipfile.ZIP_DEFLATED) as zf:
        for dp, _, fs in os.walk(out):
            for f in fs:
                p = os.path.join(dp, f)
                zf.write(p, os.path.relpath(p, out))
    print("%-22s %3d Lua files -> %s" % (name, n, os.path.relpath(z, ROOT)))


if __name__ == "__main__":
    names = sys.argv[1:] or DEFAULT_BUILD
    for n in names:
        build(n)
