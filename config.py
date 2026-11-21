"""
Build configuration for every TR4CEPIL0T pack.

Focus: only the public TR4CEPIL0T_TX15 pack is built by default (DEFAULT_BUILD).
The other variants are kept for reference and can still be built by name.
To add a variant, copy one entry and adjust it; build_all.py does the rest.
"""

VERSION = "1.1.0"
ETHOS_VERSION = "0.9.0"   # FrSky Ethos pack (beta until tested on an X18RS)
KOFI_URL = "https://ko-fi.com/tr4cepil0t"
REPO_URL = "https://github.com/DGangJ/TR4CEPIL0T"   # shown in the pack README.txt and Lua headers
LICENSE = "GPL-3.0"

WHITE = (215, 242, 247)
ORANGE = (255, 84, 40)
RED = (255, 28, 40)

# EdgeTX theme colours (theme.yml). QM_BG / QM_FG need EdgeTX 2.12+.
THEME_ORANGE = dict(PRIMARY1=0xAAC8D2, PRIMARY2=0xFFFFFF, PRIMARY3=0x5A6E78, SECONDARY1=0x101417,
                    SECONDARY2=0x1A2024, SECONDARY3=0x000000, FOCUS=0xFF5428, EDIT=0xFF1400,
                    ACTIVE=0x2C5560, WARNING=0xFF3232, DISABLED=0x3C464C, QM_BG=0x0A0D0F, QM_FG=0xAAC8D2)
THEME_RED = dict(THEME_ORANGE, FOCUS=0xFF1C28, EDIT=0xA01420, WARNING=0xFFD200)

VARIANTS = {
    # public version
    "TR4CEPIL0T_TX15": dict(
        screen=(480, 320),
        widgets=dict(trails="TPTrails", inputs="TPInputs", trails_dir="TPTRAIL", inputs_dir="TPINPUT",
                     sim="TPSim", sim_dir="TPSIM"),   # TPSim: page for a "Sim Mode" model
        brand="TR4CEPIL0T",
        accent=ORANGE, warn=(255, 176, 0),                 # widget accent + warning colours
        splash_accent=ORANGE, splash_brand=None,            # None = "EDGETX FPV COPILOT" subtitle
        leds=dict(colour=(255, 20, 0), name="reddish amber", pa01=False, variants=True),
        theme=dict(dir="TR4CE", name="TR4CEPIL0T", info="Black, orange and cyan dot-matrix (TPTrails)",
                   colors=THEME_ORANGE, logo="logo_tr4ce.png", shots="orange_480"),
        sound_prefix="tp",
        # alternative splash/shutdown images shipped in IMAGES/SPLASH/ (copy one over IMAGES/splash.png to use it)
        alt_splashes=[("ibass.png", ORANGE, [("iBass&FPV", WHITE)]),
                      ("squadq.png", RED, [("Squadding", WHITE), ("Quads", RED)])],
    ),
    # ---- archived variants (not built by default; build them by name: python3 build_all.py iBassFPV_TX15)
    # personal version (iBass&FPV)
    "iBassFPV_TX15": dict(
        screen=(480, 320),
        widgets=dict(trails="iBFTrails", inputs="iBFInputs", trails_dir="IBFTRAIL", inputs_dir="IBFINPUT"),
        brand="TR4CEPIL0T / iBass&FPV",
        accent=ORANGE, warn=(255, 176, 0),
        splash_accent=ORANGE, splash_brand=[("iBass&FPV", WHITE)],
        leds=dict(colour=(255, 20, 0), name="reddish amber", pa01=False, variants=True),
        theme=dict(dir="iBassFPV", name="iBass&FPV", info="Black, orange and cyan dot-matrix (iBFTrails)",
                   colors=THEME_ORANGE, logo="logo_ibass.png", shots="orange_480"),
        sound_prefix="ibf",
    ),
    # Squadding Quads, RadioMaster TX15
    "SquaddingQuads_TX15": dict(
        screen=(480, 320),
        widgets=dict(trails="SQTrails", inputs="SQInputs", trails_dir="SQTRAIL", inputs_dir="SQINPUT"),
        brand="TR4CEPIL0T / Squadding Quads",
        accent=RED, warn=(255, 210, 0),
        splash_accent=RED, splash_brand=[("Squadding", WHITE), ("Quads", RED)],
        leds=dict(colour=(255, 0, 8), name="red", pa01=False, variants=True),
        theme=dict(dir="SquadQ", name="Squadding Quads", info="Black, red and cyan dot-matrix (SQTrails)",
                   colors=THEME_RED, logo="logo_sq.png", shots="red_480"),
        sound_prefix="sq",
    ),
    # Squadding Quads, FlySky PA01 (320x240, LED layout still unknown, no colour variants)
    "SquaddingQuads_PA01": dict(
        screen=(320, 240),
        widgets=dict(trails="SQTrails", inputs="SQInputs", trails_dir="SQTRAIL", inputs_dir="SQINPUT"),
        brand="TR4CEPIL0T / Squadding Quads (PA01)",
        accent=RED, warn=(255, 210, 0),
        splash_accent=RED, splash_brand=[("Squadding", WHITE), ("Quads", RED)],
        leds=dict(colour=(255, 0, 8), name="red", pa01=True, variants=False),
        theme=dict(dir="SquadQ", name="Squadding Quads", info="Black, red and cyan dot-matrix (SQTrails, PA01 320x240)",
                   colors=THEME_RED, logo="logo_sq.png", shots="red_320"),
        sound_prefix="sq",
    ),
}

# ---- Global EdgeTX packs: one per screen resolution (same widgets, no LED effects)
GLOBAL_RADIOS = {
    (480, 320): "RadioMaster TX15 / GX15, Jumper T15 / T15 Pro / T15-H7 / T22, Flysky PL18 / PL18EV / PL18U / ST16",
    (480, 272): "RadioMaster TX16S / TX16S MkII, HelloRadioSky V15 / V16, Jumper T16 / T18 / T18H7, "
                "FrSky X10 / X12S, iFlight Commando 14, Fatfish F16, Senduwing H17",
    (320, 240): "Flysky PA01, HelloRadioSky V12",
    (800, 480): "RadioMaster TX16S MK3",
}
for (gw, gh), radios in GLOBAL_RADIOS.items():
    VARIANTS["TR4CEPIL0T_EdgeTX_%dx%d" % (gw, gh)] = dict(
        screen=(gw, gh), global_pack=True, radios=radios,
        widgets=dict(trails="TPTrails", inputs="TPInputs", trails_dir="TPTRAIL", inputs_dir="TPINPUT",
                     sim="TPSim", sim_dir="TPSIM"),
        brand="TR4CEPIL0T",
        accent=ORANGE, warn=(255, 176, 0),
        splash_accent=ORANGE, splash_brand=None,
        leds=None,                                         # LED effects only in the TX15 pack
        theme=dict(dir="TR4CE", name="TR4CEPIL0T", info="Black, orange and cyan dot-matrix (TPTrails)",
                   colors=THEME_ORANGE, logo="logo_tr4ce.png", shots="mock"),
        sound_prefix="tp",
        alt_splashes=[("ibass.png", ORANGE, [("iBass&FPV", WHITE)]),
                      ("squadq.png", RED, [("Squadding", WHITE), ("Quads", RED)])],
    )
VARIANTS["TR4CEPIL0T_TX15"]["radios"] = "RadioMaster TX15 / TX15 Max (optimised pack with LED effects)"

GLOBAL_BUILD = ["TR4CEPIL0T_EdgeTX_%dx%d" % r for r in GLOBAL_RADIOS]
DEFAULT_BUILD = ["TR4CEPIL0T_TX15"] + GLOBAL_BUILD

# ---- optional local packs (not in git): local/config_local.py may add entries to VARIANTS and LOCAL_BUILD.
# Used for private packs that are built with every update but never published.
import os as _os
LOCAL_BUILD = []
_local = _os.path.join(_os.path.dirname(_os.path.abspath(__file__)), "local", "config_local.py")
if _os.path.exists(_local):
    exec(compile(open(_local).read(), _local, "exec"))
DEFAULT_BUILD = DEFAULT_BUILD + LOCAL_BUILD
