#!/usr/bin/env python3
"""Generate Overstomp placeholder pixel art (characters, ability icons, tiles, palette).

Kept in-repo so assets can be regenerated/iterated: tweak colors or shapes here,
re-run, and Godot reimports. Requires Pillow: pip install pillow
Run from repo root: python assets/tools/generate_placeholders.py
"""
from PIL import Image, ImageDraw
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

# ---- Master palette: "pixel Arcane" — dusk purples/teals + neon accents ----
PALETTE = [
    "#0d0716", "#1a1030", "#2a1d4a", "#3b2d63",  # night/dusk ramp
    "#14232e", "#1f3a4a", "#2e5a66", "#3f7d85",  # teal shadow ramp
    "#402039", "#6b2d5b", "#a03e78", "#d95763",  # warm shadow/skin ramp
    "#f2a65a", "#ffd23f", "#fff3b0", "#ffffff",  # gold/light ramp
    "#ff2e88", "#ff6ec7", "#2de2e6", "#7df9ff",  # neon magenta / cyan
    "#ffb454", "#ffe66d", "#9d4edd", "#c77dff",  # neon amber / violet
    "#3ddc84", "#a4f9c8", "#f5f5fa", "#b8b8d1",  # green accent / UI grays
    "#5b5b7a", "#33334d", "#e63946", "#457b9d",  # UI/team rims (red/blue)
]

HEROES = {
    # name: (suit_dark, suit_mid, accent, accent_light)
    "deadeye": ("#1a1030", "#3b2d63", "#ff2e88", "#ff6ec7"),
    "skyla":   ("#14232e", "#2e5a66", "#2de2e6", "#7df9ff"),
    "mason":   ("#2a1d4a", "#402039", "#ffb454", "#ffe66d"),
    "nova":    ("#1a1030", "#33334d", "#9d4edd", "#c77dff"),
}

SKIN = "#d95763"
SKIN_HI = "#f2a65a"


def px(d, x, y, c):
    d.point((x, y), fill=c)


def rect(d, x0, y0, x1, y1, c):
    d.rectangle([x0, y0, x1, y1], fill=c)


def character(name, dark, mid, accent, accent_light):
    """32x48 idle frame. Head occupies the top 12px (~25%) = the stomp hurtbox,
    marked by the accent 'cowl'. Chunky silhouette + rim light on the right edge."""
    im = Image.new("RGBA", (32, 48), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    # legs
    rect(d, 9, 36, 13, 46, dark); rect(d, 18, 36, 22, 46, dark)
    rect(d, 8, 45, 14, 47, mid); rect(d, 17, 45, 23, 47, mid)      # boots
    rect(d, 8, 45, 14, 45, accent); rect(d, 17, 45, 23, 45, accent)  # boot trim
    # torso
    rect(d, 8, 20, 23, 36, mid)
    rect(d, 8, 20, 23, 24, dark)                                    # chest shadow
    rect(d, 13, 24, 18, 31, accent)                                 # emblem
    rect(d, 14, 25, 17, 27, accent_light)
    # arms
    rect(d, 5, 21, 8, 33, dark); rect(d, 23, 21, 26, 33, dark)
    rect(d, 5, 31, 8, 34, SKIN); rect(d, 23, 31, 26, 34, SKIN)       # hands
    # cape hint
    rect(d, 24, 20, 27, 40, dark)
    # head (top 12 rows): cowl in accent = readable stomp zone
    rect(d, 10, 2, 21, 12, accent)                                  # cowl
    rect(d, 10, 2, 21, 4, accent_light)                             # cowl top light
    rect(d, 11, 8, 20, 13, SKIN)                                    # jaw
    rect(d, 11, 8, 20, 8, SKIN_HI)
    rect(d, 12, 6, 14, 7, "#fff3b0"); rect(d, 17, 6, 19, 7, "#fff3b0")  # visor eyes
    # rim light (right edge, dusk-key light like Arcane frames)
    for y in range(3, 46):
        for x in range(31, 3, -1):
            if im.getpixel((x, y))[3] > 0:
                px(d, x, y, accent_light)
                break
    im.save(ROOT / "characters" / f"{name}_idle_32x48.png")
    # tiny 3-frame run strip (naive leg swap) to show sheet layout
    strip = Image.new("RGBA", (96, 48), (0, 0, 0, 0))
    for i in range(3):
        f = im.copy()
        if i == 1:
            f = f.transform(f.size, Image.AFFINE, (1, 0, 0, 0, 1, -1))
        strip.paste(f, (i * 32, 0))
    strip.save(ROOT / "characters" / f"{name}_run_strip_3f.png")


def icon(name, painter):
    im = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    rect(d, 0, 0, 15, 15, "#1a1030")
    d.rectangle([0, 0, 15, 15], outline="#5b5b7a")
    painter(d)
    im.save(ROOT / "abilities" / f"icon_{name}.png")


def make_icons():
    icon("deadeye_bolt", lambda d: (rect(d, 3, 7, 12, 8, "#ff2e88"), rect(d, 10, 5, 12, 10, "#ff6ec7")))
    icon("skyla_jump", lambda d: (d.polygon([(8, 3), (3, 12), (13, 12)], fill="#2de2e6"),
                                  rect(d, 7, 10, 8, 13, "#7df9ff")))
    icon("mason_block", lambda d: (rect(d, 3, 3, 12, 12, "#ffb454"), rect(d, 3, 3, 12, 5, "#ffe66d")))
    icon("nova_burst", lambda d: (d.ellipse([3, 3, 12, 12], outline="#c77dff"),
                                  d.ellipse([6, 6, 9, 9], fill="#9d4edd")))
    icon("ultimate_ready", lambda d: d.polygon([(8, 2), (11, 8), (8, 14), (5, 8)], fill="#ffd23f"))


def tile(name, painter):
    im = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
    painter(ImageDraw.Draw(im))
    im.save(ROOT / "stages" / f"tile_{name}.png")


def make_tiles():
    tile("ground", lambda d: (rect(d, 0, 0, 15, 15, "#2a1d4a"), rect(d, 0, 0, 15, 3, "#3b2d63"),
                              rect(d, 0, 0, 15, 0, "#a03e78")))
    tile("ice", lambda d: (rect(d, 0, 0, 15, 15, "#2e5a66"), rect(d, 0, 0, 15, 2, "#7df9ff"),
                           px(d, 4, 7, "#a4f9c8"), px(d, 11, 10, "#a4f9c8")))
    tile("stun_line", lambda d: (rect(d, 0, 7, 15, 8, "#ffd23f"),
                                 *[px(d, x, 6, "#fff3b0") for x in range(0, 16, 4)],
                                 *[px(d, x, 9, "#fff3b0") for x in range(2, 16, 4)]))
    tile("spring", lambda d: (rect(d, 2, 12, 13, 15, "#5b5b7a"), rect(d, 3, 4, 12, 7, "#3ddc84"),
                              rect(d, 3, 4, 12, 4, "#a4f9c8"), rect(d, 6, 8, 9, 11, "#33334d")))
    tile("speed_pad", lambda d: (rect(d, 0, 10, 15, 15, "#1f3a4a"),
                                 d.polygon([(3, 12), (7, 12), (7, 10), (11, 13), (7, 15), (7, 14), (3, 14)],
                                           fill="#2de2e6")))
    tile("portal", lambda d: (d.ellipse([2, 1, 13, 14], outline="#9d4edd"),
                              d.ellipse([4, 3, 11, 12], outline="#c77dff"),
                              d.ellipse([6, 5, 9, 10], fill="#1a1030")))
    tile("pole", lambda d: (rect(d, 7, 0, 8, 15, "#b8b8d1"), rect(d, 7, 0, 7, 15, "#f5f5fa"),
                            *[px(d, 8, y, "#5b5b7a") for y in range(1, 16, 3)]))
    tile("wind", lambda d: (*[d.line([(1, y), (10, y)], fill="#7df9ff") for y in (4, 8, 12)],
                            *[d.line([(10, y), (13, y)], fill="#f5f5fa") for y in (4, 8, 12)]))
    tile("explosion_vent", lambda d: (rect(d, 0, 8, 15, 15, "#33334d"), rect(d, 5, 4, 10, 8, "#e63946"),
                                      rect(d, 6, 2, 9, 4, "#ffd23f")))


def make_palette():
    im = Image.new("RGBA", (len(PALETTE) * 8, 16))
    d = ImageDraw.Draw(im)
    for i, c in enumerate(PALETTE):
        rect(d, i * 8, 0, i * 8 + 7, 15, c)
    im.save(ROOT / "palettes" / "master_palette_32.png")
    with open(ROOT / "palettes" / "master_palette.gpl", "w") as f:  # Aseprite/GIMP palette
        f.write("GIMP Palette\n#Name: Overstomp Master 32\n")
        for c in PALETTE:
            r, g, b = int(c[1:3], 16), int(c[3:5], 16), int(c[5:7], 16)
            f.write(f"{r} {g} {b}\t{c}\n")


def make_stage_mock():
    """Tiny mock of Rooftop Rumble to communicate composition/palette intent."""
    W, H = 320, 192
    im = Image.new("RGBA", (W, H))
    d = ImageDraw.Draw(im)
    for y in range(H):  # dusk gradient in 4 bands
        d.line([(0, y), (W, y)], fill=["#1a1030", "#2a1d4a", "#3b2d63", "#6b2d5b"][min(3, y * 4 // H)])
    rect(d, 0, 176, 319, 191, "#0d0716")                      # street base (sealed)
    for x0, y0, w in [(20, 120, 90), (140, 90, 70), (240, 130, 70)]:  # rooftops
        rect(d, x0, y0, x0 + w, 175, "#14232e")
        rect(d, x0, y0, x0 + w, y0 + 3, "#3f7d85")
    rect(d, 0, 0, 3, 191, "#0d0716"); rect(d, 316, 0, 319, 191, "#0d0716")  # sealed walls
    rect(d, 170, 60, 171, 89, "#b8b8d1")                      # antenna pole
    rect(d, 60, 114, 71, 119, "#3ddc84")                      # awning spring
    for y in (40, 48, 56):
        d.line([(200, y), (236, y)], fill="#7df9ff")          # wind corridor
    d.ellipse([300, 100, 311, 126], outline="#9d4edd")        # portal
    im.save(ROOT / "stages" / "mock_rooftop_rumble.png")


if __name__ == "__main__":
    for p in ("characters", "abilities", "stages", "palettes"):
        (ROOT / p).mkdir(exist_ok=True)
    for n, cols in HEROES.items():
        character(n, *cols)
    make_icons()
    make_tiles()
    make_palette()
    make_stage_mock()
    print("Placeholder assets regenerated.")
