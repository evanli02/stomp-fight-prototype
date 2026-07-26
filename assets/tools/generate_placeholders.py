#!/usr/bin/env python3
"""Generate Overstomp's non-character placeholder art: ability icons, terrain
tiles, the master palette, and the stage composition mock.

Characters moved to generate_characters.py when they outgrew "one shape, four
palettes" — this file is now everything else.

Stdlib only (see pixel.py). Kept in-repo so assets can be regenerated: tweak
colors or shapes here, re-run, and Godot reimports.
    python assets/tools/generate_placeholders.py
"""
from pathlib import Path

from pixel import Canvas

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


def icon(name: str, painter) -> None:
    c = Canvas(16, 16)
    c.rect(0, 0, 15, 15, "#1a1030")
    for x in range(16):
        c.put(x, 0, "#5b5b7a")
        c.put(x, 15, "#5b5b7a")
    for y in range(16):
        c.put(0, y, "#5b5b7a")
        c.put(15, y, "#5b5b7a")
    painter(c)
    c.save(ROOT / "abilities" / f"icon_{name}.png")


def make_icons() -> None:
    def deadeye(c: Canvas) -> None:
        c.rect(3, 7, 12, 8, "#ff2e88")
        c.rect(10, 5, 12, 10, "#ff6ec7")

    def skyla(c: Canvas) -> None:
        c.poly([(8, 3), (3, 12), (13, 12)], "#2de2e6")
        c.rect(7, 10, 8, 13, "#7df9ff")

    def mason(c: Canvas) -> None:
        c.rect(3, 3, 12, 12, "#ffb454")
        c.rect(3, 3, 12, 5, "#ffe66d")

    def nova(c: Canvas) -> None:
        c.ellipse(8, 8, 5, 5, "#c77dff", filled=False)
        c.ellipse(8, 8, 2, 2, "#9d4edd")

    def ult(c: Canvas) -> None:
        c.poly([(8, 2), (11, 8), (8, 14), (5, 8)], "#ffd23f")

    icon("deadeye_bolt", deadeye)
    icon("skyla_jump", skyla)
    icon("mason_block", mason)
    icon("nova_burst", nova)
    icon("ultimate_ready", ult)


def tile(name: str, painter) -> None:
    c = Canvas(16, 16)
    painter(c)
    c.save(ROOT / "stages" / f"tile_{name}.png")


def make_tiles() -> None:
    def ground(c: Canvas) -> None:
        c.rect(0, 0, 15, 15, "#2a1d4a")
        c.rect(0, 0, 15, 3, "#3b2d63")
        c.rect(0, 0, 15, 0, "#a03e78")

    def ice(c: Canvas) -> None:
        c.rect(0, 0, 15, 15, "#2e5a66")
        c.rect(0, 0, 15, 2, "#7df9ff")
        c.put(4, 7, "#a4f9c8")
        c.put(11, 10, "#a4f9c8")

    def stun_line(c: Canvas) -> None:
        c.rect(0, 7, 15, 8, "#ffd23f")
        for x in range(0, 16, 4):
            c.put(x, 6, "#fff3b0")
        for x in range(2, 16, 4):
            c.put(x, 9, "#fff3b0")

    def spring(c: Canvas) -> None:
        c.rect(2, 12, 13, 15, "#5b5b7a")
        c.rect(3, 4, 12, 7, "#3ddc84")
        c.rect(3, 4, 12, 4, "#a4f9c8")
        c.rect(6, 8, 9, 11, "#33334d")

    def speed_pad(c: Canvas) -> None:
        c.rect(0, 10, 15, 15, "#1f3a4a")
        c.poly([(3, 12), (7, 12), (7, 10), (11, 13), (7, 15), (7, 14), (3, 14)], "#2de2e6")

    def portal(c: Canvas) -> None:
        c.ellipse(7, 7, 6, 6, "#9d4edd", filled=False)
        c.ellipse(7, 7, 4, 4, "#c77dff", filled=False)
        c.ellipse(7, 7, 2, 2, "#1a1030")

    def pole(c: Canvas) -> None:
        c.rect(7, 0, 8, 15, "#b8b8d1")
        c.rect(7, 0, 7, 15, "#f5f5fa")
        for y in range(1, 16, 3):
            c.put(8, y, "#5b5b7a")

    def wind(c: Canvas) -> None:
        for y in (4, 8, 12):
            c.line((1, y), (10, y), "#7df9ff")
            c.line((10, y), (13, y), "#f5f5fa")

    def vent(c: Canvas) -> None:
        c.rect(0, 8, 15, 15, "#33334d")
        c.rect(5, 4, 10, 8, "#e63946")
        c.rect(6, 2, 9, 4, "#ffd23f")

    tile("ground", ground)
    tile("ice", ice)
    tile("stun_line", stun_line)
    tile("spring", spring)
    tile("speed_pad", speed_pad)
    tile("portal", portal)
    tile("pole", pole)
    tile("wind", wind)
    tile("explosion_vent", vent)


def make_palette() -> None:
    c = Canvas(len(PALETTE) * 8, 16)
    for i, col in enumerate(PALETTE):
        c.rect(i * 8, 0, i * 8 + 7, 15, col)
    c.save(ROOT / "palettes" / "master_palette_32.png")
    lines = ["GIMP Palette", "#Name: Overstomp Master 32"]
    for col in PALETTE:
        r, g, b = int(col[1:3], 16), int(col[3:5], 16), int(col[5:7], 16)
        lines.append(f"{r} {g} {b}\t{col}")
    (ROOT / "palettes" / "master_palette.gpl").write_text(
        "\n".join(lines) + "\n", encoding="utf-8", newline="\n")


def make_stage_mock() -> None:
    """Tiny mock of Rooftop Rumble to communicate composition/palette intent."""
    w, h = 320, 192
    c = Canvas(w, h)
    bands = ["#1a1030", "#2a1d4a", "#3b2d63", "#6b2d5b"]
    for y in range(h):
        c.rect(0, y, w - 1, y, bands[min(3, y * 4 // h)])
    c.rect(0, 176, 319, 191, "#0d0716")                       # street base (sealed)
    for x0, y0, wide in ((20, 120, 90), (140, 90, 70), (240, 130, 70)):
        c.rect(x0, y0, x0 + wide, 175, "#14232e")
        c.rect(x0, y0, x0 + wide, y0 + 3, "#3f7d85")
    c.rect(0, 0, 3, 191, "#0d0716")
    c.rect(316, 0, 319, 191, "#0d0716")                       # sealed walls
    c.rect(170, 60, 171, 89, "#b8b8d1")                       # antenna pole
    c.rect(60, 114, 71, 119, "#3ddc84")                       # awning spring
    for y in (40, 48, 56):
        c.line((200, y), (236, y), "#7df9ff")                 # wind corridor
    c.ellipse(305, 113, 6, 13, "#9d4edd", filled=False)       # portal
    c.save(ROOT / "stages" / "mock_rooftop_rumble.png")


if __name__ == "__main__":
    make_icons()
    make_tiles()
    make_palette()
    make_stage_mock()
    print("Icons, tiles, palette, and stage mock regenerated.")
    print("Characters live in generate_characters.py.")
