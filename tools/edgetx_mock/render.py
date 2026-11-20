"""Run the built EdgeTX widgets in the Lua mock and render PNG previews for several radios.
    python3 tools/edgetx_mock/render.py <pack dir> [out_dir]
"""
import os, sys
from PIL import Image, ImageDraw, ImageFont
ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.path.insert(0, os.path.join(ROOT, "tools"))
import lua54
MOCK = open(os.path.join(ROOT, "tools", "edgetx_mock", "mock.lua")).read()
FONT = "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"

def lua(v):
    if isinstance(v, bool): return "true" if v else "false"
    if isinstance(v, (int, float)): return repr(v)
    if isinstance(v, str): return '"%s"' % v
    if isinstance(v, (list, tuple)): return "{" + ",".join(lua(x) for x in v) + "}"
    if isinstance(v, dict): return "{" + ",".join("%s=%s" % (k, lua(x)) for k, x in v.items()) + "}"
    raise TypeError(v)

# radios: pots { name, label, value }, switches { name, positions, value }
SW8 = [["sa", 2, -1024], ["sb", 3, 0], ["sc", 3, 1024], ["sd", 2, -1024],
       ["se", 3, -1024], ["sf", 2, 1024], ["sg", 3, 0], ["sh", 2, -1024]]
RADIOS = {
    "tx15": dict(w=480, h=320, pots=[["s1", "S1", 410], ["s2", "S2", -820]],
                 switches=[["sa", 2, -1024], ["sb", 3, 0], ["sc", 3, 1024], ["sd", 2, -1024], ["se", 2, -1024],
                           ["sf", 2, 1024]] + [["sw%d" % i, 2, -1024 if i % 2 else 1024] for i in range(1, 7)]),
    "tx16s": dict(w=480, h=272, pots=[["s1", "S1", 410], ["s2", "S2", -820], ["ls", "LS", 0], ["rs", "RS", 256]],
                  switches=SW8),
    "v15": dict(w=480, h=272, pots=[["s1", "S1", 0], ["s2", "S2", 300]], switches=SW8[:6]),
    "pa01": dict(w=320, h=240, pots=[["s1", "S1", 0]], switches=SW8[:6]),
    "tx16smk3": dict(w=800, h=480, pots=[["s1", "S1", 410], ["s2", "S2", -820], ["ls", "LS", 0], ["rs", "RS", 256]],
                     switches=SW8 + [["sw%d" % i, 2, -1024] for i in range(1, 7)]),
}

def run(pack, widget_dir, radio, scen, png):
    r = RADIOS[radio]
    ops = "/tmp/edgetx_ops.txt"
    head = "SCRIPT=%s OUT_FILE=%s LCD_W=%d LCD_H=%d RADIO=%s S=%s\n" % (
        lua(os.path.join(pack, "WIDGETS", widget_dir, "main.lua")), lua(ops), r["w"], r["h"],
        lua({"pots": r["pots"], "switches": r["switches"], "noIterator": scen.get("noIterator", False)}), lua(scen))
    ok, msg = lua54.run(head + MOCK, "mock")
    if not ok:
        raise SystemExit("%s/%s: %s" % (radio, widget_dir, msg))
    W, H = r["w"], r["h"]
    im = Image.new("RGB", (W, H)); d = ImageDraw.Draw(im)
    f = ImageFont.truetype(FONT, 11)
    def c565(c): return (((c >> 11) & 31) * 255 // 31, ((c >> 5) & 63) * 255 // 63, (c & 31) * 255 // 31)
    for line in open(ops).read().splitlines():
        p = line.split(" ")
        if p[0] in "RB":
            x, y, w, h, c = map(int, p[1:6])
            if w > 0 and h > 0:
                if p[0] == "R": d.rectangle([x, y, x + w - 1, y + h - 1], fill=c565(c))
                else: d.rectangle([x, y, x + w - 1, y + h - 1], outline=c565(c))
        elif p[0] == "L":
            x1, y1, x2, y2, c = map(int, p[1:6]); n = max(abs(x2 - x1), abs(y2 - y1), 1)
            for i in range(0, n + 1, 2): d.point((x1 + (x2 - x1) * i // n, y1 + (y2 - y1) * i // n), fill=c565(c))
        elif p[0] == "T":
            x, y, c, right, mid = map(int, p[1:6]); t = " ".join(p[6:])
            if right: x -= int(d.textlength(t, font=f))
            d.text((x, y), t, fill=c565(c), font=f)
    im.save(png)

if __name__ == "__main__":
    pack = sys.argv[1]
    out = sys.argv[2] if len(sys.argv) > 2 else "/tmp/edgetx_shots"
    os.makedirs(out, exist_ok=True)
    wdirs = sorted(os.listdir(os.path.join(pack, "WIDGETS")))
    for radio in RADIOS:
        for wdir in wdirs:
            png = os.path.join(out, "%s_%s.png" % (radio, wdir.lower()))
            run(pack, wdir, radio, {"live": True, "gps": True, "fm": "ACRO"}, png)
            print("ok", os.path.basename(png))
