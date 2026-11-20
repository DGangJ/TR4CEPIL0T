"""Run the Ethos widgets in the Lua mock and render the recorded draw calls to PNG.
    python3 tools/ethos_mock/render.py [out_dir]
"""
import os, sys
from PIL import Image, ImageDraw, ImageFont
ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.path.insert(0, os.path.join(ROOT, "tools"))
import lua54
SCRIPT = os.path.join(ROOT, "dist", "TR4CEPIL0T_ETHOS", "tr4ce", "main.lua")
MOCK = open(os.path.join(ROOT, "tools", "ethos_mock", "mock.lua")).read()
FONT = "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"

def scenario(name, widget, w, h, **s):
    s.setdefault("live", True); s.setdefault("lq", 100); s.setdefault("fm", "ACRO"); s.setdefault("gps", True)
    s.setdefault("timer", False)
    lua_s = "{" + ",".join("%s=%s" % (k, ('"%s"' % v) if isinstance(v, str) else str(v).lower()) for k, v in s.items()) + "}"
    ops = "/tmp/ethos_ops_%s.txt" % name
    head = 'SCRIPT=%r OUT_FILE=%r WIN_W=%d WIN_H=%d WIDGET=%r SCENARIO=%s\n' % (SCRIPT, ops, w, h, widget, lua_s)
    ok, msg = lua54.run(head.replace("'", '"') + MOCK, "mock")
    if not ok:
        raise SystemExit("%s: %s" % (name, msg))
    im = Image.new("RGB", (w, h)); d = ImageDraw.Draw(im)
    fonts = {}
    for line in open(ops).read().splitlines():
        p = line.split(" ")
        col = lambda c: ((c >> 16) & 255, (c >> 8) & 255, c & 255)
        if p[0] == "R":
            x, y, ww, hh, c = map(int, p[1:6])
            if ww > 0 and hh > 0: d.rectangle([x, y, x + ww - 1, y + hh - 1], fill=col(c))
        elif p[0] == "L":
            x1, y1, x2, y2, c = map(int, p[1:6])
            n = max(abs(x2 - x1), abs(y2 - y1))
            for i in range(0, n + 1, 3):
                d.point((x1 + (x2 - x1) * i // max(n, 1), y1 + (y2 - y1) * i // max(n, 1)), fill=col(c))
        elif p[0] == "T":
            x, y, c, right, fnt = map(int, p[1:6]); text = " ".join(p[6:])
            size = 15 if w >= 600 else 12
            f = fonts.setdefault(size, ImageFont.truetype(FONT, size))
            if right: x -= int(d.textlength(text, font=f))
            d.text((x, y), text, fill=col(c), font=f)
    return im

if __name__ == "__main__":
    out = sys.argv[1] if len(sys.argv) > 1 else "/tmp/ethos_shots"
    os.makedirs(out, exist_ok=True)
    shots = [
        ("p1_armed", "tptrail", 800, 480, {}),
        ("p1_timer", "tptrail", 800, 480, {"timer": True}),
        ("p1_disarmed", "tptrail", 800, 480, {"fm": "ACRO*"}),
        ("p1_lost", "tptrail", 800, 480, {"disarmLater": True}),
        ("p1_nogps", "tptrail", 800, 480, {"gps": False, "lq": 45}),
        ("p1_480", "tptrail", 480, 320, {}),
        ("p2_inputs", "tpinput", 800, 480, {}),
        ("p2_480", "tpinput", 480, 320, {}),
    ]
    for name, wgt, w, h, s in shots:
        scenario(name, wgt, w, h, **s).save(os.path.join(out, name + ".png"))
        print("ok", name)
