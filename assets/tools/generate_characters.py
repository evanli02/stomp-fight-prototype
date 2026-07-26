#!/usr/bin/env python3
"""Generate Overstomp's character sprite sheets.

Every hero is drawn by the same limb rig — hips, shoulders, knees, elbows posed
per frame — wearing a different set of parts. That is the point: DESIGN 5.1 says
heroes share movement, hitboxes, and silhouette *size*, and the pipeline
enforces it structurally.

Art direction (STYLE_GUIDE): comic-book chibi with a punk edge — Big Hero 6 /
My Hero Academia proportions with cyberpunk gear. Short bodies, oversized
heads, one loud accent per hero, thick keylines, minimal clutter.

Rules the rig will not let you break:
  * 32x36 logical pixels, feet on row 35 — the body is ~30% shorter than the
    original 48px sprites, and the head is ~40% of it.
  * The head is the stomp hurtbox and the accent owns it, standing or crouched.

Stdlib only. Run from the repo root:
    python assets/tools/generate_characters.py
"""
from __future__ import annotations

import math
from dataclasses import dataclass, replace
from pathlib import Path

from pixel import Canvas, mix, strip

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "characters"
FRAMES_OUT = ROOT.parent / "src" / "heroes" / "resources" / "frames"

W, H = 32, 36
GROUND = 35
## The animation tables below still speak the ORIGINAL 48-tall joint space and
## are squashed onto the chibi body at draw time — so feet in a pose sit at OG.
OG = 47
KEYLINE = "#0d0716"
DUST = "#5b5b7a"
DUST_HI = "#b8b8d1"
STAR = "#ffd23f"
STAR_HI = "#fff3b0"


# --------------------------------------------------------------------------- #
# Pose: joints in the old 48-tall space; _shrink() maps them to the chibi body.
# --------------------------------------------------------------------------- #
@dataclass
class Pose:
    head: tuple = (16, 6)
    neck: tuple = (16, 13)
    hip: tuple = (16, 30)
    hand_b: tuple = (11, 29)
    hand_f: tuple = (21, 29)
    foot_b: tuple = (13, OG)
    foot_f: tuple = (19, OG)
    knee_bend: float = 2.0
    elbow_bend: float = 2.0
    lean: float = 0.0
    cape: float = 0.0
    cape_lift: float = 0.0
    crouched: bool = False
    ground: bool = True
    fx: str = ""
    fx_dir: int = 1


def _shrink(p: Pose) -> Pose:
    """Old 48-tall joint space -> 36-tall chibi body (feet 47 -> 35)."""
    def ty(pt):
        return (pt[0], round(pt[1] * 0.73) + 1)
    return replace(p, head=ty(p.head), neck=ty(p.neck), hip=ty(p.hip),
        hand_b=ty(p.hand_b), hand_f=ty(p.hand_f),
        foot_b=ty(p.foot_b), foot_f=ty(p.foot_f),
        knee_bend=p.knee_bend * 0.8, elbow_bend=p.elbow_bend * 0.8)


def joint(a, b, bend):
    mx, my = (a[0] + b[0]) / 2.0, (a[1] + b[1]) / 2.0
    dx, dy = b[0] - a[0], b[1] - a[1]
    length = math.hypot(dx, dy) or 1.0
    return (mx - dy / length * bend, my + dx / length * bend)


# --------------------------------------------------------------------------- #
# Heroes
# --------------------------------------------------------------------------- #
@dataclass
class Hero:
    key: str
    name: str
    dark: str
    mid: str
    light: str
    accent: str
    accent_hi: str
    skin: str
    skin_hi: str
    torso_w: int = 6
    limb: int = 4
    cape_style: str = "none"
    cape_color: str = ""
    head_style: str = ""
    gear: str = ""

    def cape_col(self) -> str:
        return self.cape_color or self.dark


HEROES = [
    # Cyberpunk cowboy: brimmed hat, augmented eye glowing red, long split coat.
    Hero("deadeye", "Deadeye", "#2a0f14", "#5a1e24", "#8a3040", "#e63946", "#ff8080",
         "#d9a066", "#f2cf9e", torso_w=6, limb=4, cape_style="coat",
         cape_color="#3d1620", head_style="cowboy", gear="pistol"),
    # Jade dancer: hair bun with an ornament, long streaming ribbon, clean lines.
    Hero("fei", "Fei", "#0f2a1e", "#1e4a36", "#2f6b4e", "#3ddc84", "#a4f9c8",
         "#e8c39e", "#f7dfc0", torso_w=5, limb=3, cape_style="scarf",
         cape_color="#3ddc84", head_style="bun", gear="none"),
    # Gold engineer: fur crown and heavy shoulders over tech, huge gauntlets.
    Hero("mason", "Mason", "#241a10", "#4a3a20", "#6b5530", "#ffd23f", "#fff3b0",
         "#6b3f2a", "#8a5a3b", torso_w=8, limb=5, cape_style="none",
         head_style="crown", gear="gauntlets"),
    # Gravity valkyrie: crested helm, sleeveless armour, tattooed arms, war cape.
    Hero("cerebelle", "Cerebelle", "#1c1030", "#33244d", "#4a3a66", "#9d4edd", "#c77dff",
         "#8a5a3b", "#a87450", torso_w=6, limb=4, cape_style="cape",
         cape_color="#2a3d63", head_style="crest", gear="tattoos"),
    # Stylish grappler: sleek visor, swept hair, hook at the hip, short scarf.
    Hero("sai", "Sai", "#241019", "#4a2033", "#6b3049", "#ff6ec7", "#ffb3e2",
         "#e8c39e", "#f7dfc0", torso_w=5, limb=3, cape_style="scarf",
         cape_color="#ff6ec7", head_style="visor", gear="hook"),
    # Streetpunk tinkerer: tall spiked hair, goggles pushed up, belt gadgets.
    Hero("slip", "Slip", "#0f2428", "#1e4a50", "#2f6b72", "#2de2e6", "#7df9ff",
         "#b98865", "#d4a37c", torso_w=5, limb=3, cape_style="none",
         head_style="spikes", gear="pack"),
    # Warrior-builder: hard hat, heavy shoulders, wraps and plate mixed.
    Hero("terra", "Terra", "#26160c", "#4a2d18", "#6b4426", "#b5651d", "#e8965a",
         "#a05c3b", "#c07850", torso_w=8, limb=5, cape_style="none",
         head_style="hardhat", gear="gauntlets"),
    # Nerdy gadgeteer: big round glasses, messy hair, satchel of tech.
    Hero("kid", "Kid", "#26150a", "#4a2c12", "#6b431e", "#ff8b2e", "#ffc48a",
         "#f2cf9e", "#f7dfc0", torso_w=5, limb=3, cape_style="none",
         head_style="glasses", gear="pack"),
]


def shade(h: Hero, level: str) -> str:
    return {
        "shadow": mix(h.dark, "#000000", 0.3),
        "dark": mix(h.dark, h.accent, 0.10),
        "mid": mix(h.mid, h.accent, 0.22),
        "light": mix(h.light, h.accent_hi, 0.32),
        "edge": mix(h.light, "#ffffff", 0.35),
    }[level]


def face_skin(h: Hero) -> str:
    return mix(h.skin, h.dark, 0.22)


def limb_keyed(c: Canvas, p0, p1, width: int, col) -> None:
    c.limb(p0, p1, width + 2, KEYLINE)
    c.limb(p0, p1, width, col)


# --------------------------------------------------------------------------- #
# Body parts
# --------------------------------------------------------------------------- #
def draw_cape(c: Canvas, h: Hero, p: Pose) -> None:
    if h.cape_style == "none":
        if h.gear == "pack":   # backpack rides where a cape would
            nx, ny = p.neck
            c.rect(nx - h.torso_w - 3, ny + 2, nx - h.torso_w + 1, ny + 8, KEYLINE)
            c.rect(nx - h.torso_w - 2, ny + 3, nx - h.torso_w, ny + 7, shade(h, "mid"))
            c.put(nx - h.torso_w - 1, ny + 4, h.accent_hi)
        return
    nx, ny = p.neck
    trail = p.cape
    col = h.cape_col()
    if h.cape_style == "scarf":
        y = ny + 3
        tip = (nx - 4 - trail, y - p.cape_lift)
        c.poly([(nx, y - 1), (nx, y + 2), (tip[0], tip[1] + 2), (tip[0], tip[1] - 1)], KEYLINE)
        c.poly([(nx, y), (nx, y + 1), (tip[0], tip[1] + 1), (tip[0], tip[1])], col)
        c.poly([(tip[0], tip[1] - 1), (tip[0] - 3, tip[1] - 1 - p.cape_lift * 0.4),
                (tip[0], tip[1] + 1)], h.accent_hi)
        return
    bottom = min(p.hip[1] + (6 if h.cape_style == "cape" else 10), GROUND - 1)
    pts = [(nx - 1, ny), (nx + 2, ny),
           (nx + 1, bottom - p.cape_lift),
           (nx - 3 - trail, bottom - p.cape_lift * 1.5),
           (nx - 4 - trail, ny + 3)]
    c.poly(pts, col)
    if h.cape_style == "coat":
        c.line((nx - 1, bottom - 2 - p.cape_lift), (nx - 2 - trail, bottom - p.cape_lift * 1.5), KEYLINE)


def draw_torso(c: Canvas, h: Hero, p: Pose) -> None:
    nx, ny = p.neck
    hx, hy = p.hip
    tw = h.torso_w
    sx = nx + p.lean
    c.poly([(sx - tw - 1, ny), (sx + tw + 1, ny),
            (hx + tw - 1, hy + 2), (hx - tw + 1, hy + 2)], KEYLINE)
    c.poly([(sx - tw, ny + 1), (sx + tw, ny + 1),
            (hx + tw - 2, hy + 1), (hx - tw + 2, hy + 1)], shade(h, "mid"))
    # Two planes only — comic shading, not painterly ramps.
    c.poly([(sx - tw, ny + 1), (sx - tw + 2, ny + 1),
            (hx - tw + 3, hy + 1), (hx - tw + 2, hy + 1)], shade(h, "shadow"))
    c.rect(sx + tw - 1, ny + 2, sx + tw - 1, hy - 1, shade(h, "light"))
    # Belt with an accent buckle.
    c.rect(hx - tw + 2, hy, hx + tw - 2, hy + 1, KEYLINE)
    c.rect(hx - 1, hy, hx + 1, hy + 1, h.accent)


def draw_emblem(c: Canvas, h: Hero, p: Pose) -> None:
    if p.crouched:
        return
    sx = p.neck[0] + p.lean
    y = p.neck[1] + 4
    # One bold chest mark each — comic emblems, not gear clutter.
    if h.key == "deadeye":
        c.line((sx - 4, y - 1), (sx + 3, y + 3), h.accent)      # sash
        c.put(sx, y + 1, h.accent_hi)
    elif h.key == "fei":
        c.ellipse(sx, y + 1, 2.4, 2.4, h.accent, filled=False)   # jade ring
        c.put(sx, y + 1, h.accent_hi)
    elif h.key == "mason":
        c.rect(sx - 2, y - 1, sx + 2, y + 2, h.accent)
        c.rect(sx - 2, y - 1, sx + 2, y - 1, h.accent_hi)        # gold plate
    elif h.key == "cerebelle":
        c.ellipse(sx, y + 1, 2.6, 2.6, h.accent, filled=False)
        c.put(sx, y + 1, h.accent_hi)                            # gravity ring
    elif h.key == "sai":
        c.line((sx - 3, y + 2), (sx + 3, y - 1), h.accent)       # slash mark
        c.put(sx + 3, y - 1, h.accent_hi)
    elif h.key == "slip":
        c.rect(sx - 2, y, sx + 2, y, h.accent)
        c.rect(sx - 1, y + 2, sx + 1, y + 2, h.accent_hi)        # circuit dashes
    elif h.key == "terra":
        c.poly([(sx - 3, y + 2), (sx, y - 1), (sx + 3, y + 2)], h.accent)  # peak
    else:
        c.rect(sx - 2, y - 1, sx + 2, y + 2, KEYLINE)
        c.rect(sx - 1, y, sx + 1, y + 1, h.accent_hi)            # kid: screen


def draw_legs(c: Canvas, h: Hero, p: Pose) -> None:
    for foot, level, bend in ((p.foot_b, "shadow", -p.knee_bend),
                              (p.foot_f, "mid", p.knee_bend)):
        col = shade(h, level)
        knee = joint(p.hip, foot, bend)
        limb_keyed(c, p.hip, knee, h.limb, col)
        limb_keyed(c, knee, foot, max(2, h.limb - 1), col)
        fx, fy = int(foot[0]), int(foot[1])
        c.rect(fx - 3, fy - 3, fx + 3, fy, KEYLINE)
        c.rect(fx - 2, fy - 3, fx + 2, fy - 1, shade(h, "dark") if level == "mid" else shade(h, "shadow"))
        c.rect(fx - 2, fy - 3, fx + 2, fy - 3, h.accent)


def draw_arms(c: Canvas, h: Hero, p: Pose, front: bool) -> None:
    sx = p.neck[0] + p.lean
    sy = p.neck[1] + 2
    hand, level, bend = ((p.hand_f, "mid", p.elbow_bend) if front
                         else (p.hand_b, "shadow", -p.elbow_bend))
    sleeveless = (h.gear == "tattoos")
    col = (h.skin if front else mix(h.skin, "#000000", 0.3)) if sleeveless else shade(h, level)
    shoulder = (sx + (h.torso_w - 1) * (1 if front else -1), sy)
    elbow = joint(shoulder, hand, bend)
    w = max(2, h.limb - 1)
    limb_keyed(c, shoulder, elbow, w, col)
    limb_keyed(c, elbow, hand, max(2, w - 1), col)
    if sleeveless and front:
        # Tattoos: accent marks down the visible arm.
        for t in (0.3, 0.55, 0.8):
            mxp = (shoulder[0] + (hand[0] - shoulder[0]) * t,
                   shoulder[1] + (hand[1] - shoulder[1]) * t)
            c.put(int(mxp[0]), int(mxp[1]), h.accent)
    hx, hy = int(hand[0]), int(hand[1])
    if h.gear == "gauntlets":
        c.rect(hx - 3, hy - 3, hx + 3, hy + 2, KEYLINE)
        c.rect(hx - 2, hy - 2, hx + 2, hy + 1, shade(h, "mid") if front else shade(h, "shadow"))
        c.rect(hx - 2, hy - 2, hx + 2, hy - 2, h.accent)
        c.put(hx + 1, hy, h.accent_hi)
    else:
        c.rect(hx - 2, hy - 2, hx + 2, hy + 2, KEYLINE)
        c.rect(hx - 1, hy - 1, hx + 1, hy + 1,
               (h.skin if front else mix(h.skin, "#000000", 0.3)) if sleeveless else shade(h, "dark"))
        c.rect(hx - 1, hy - 2, hx + 1, hy - 2, h.accent)


def draw_head(c: Canvas, h: Hero, p: Pose) -> None:
    """Oversized comic head — roughly 40% of the body. It is also the stomp
    hurtbox, so the accent owns the top of it on every style, no exceptions."""
    cx, cy = int(p.head[0]), int(p.head[1])
    skin = face_skin(h)
    # Big skull: ~15px wide.
    c.ellipse(cx, cy, 7.2, 7.2, KEYLINE)
    c.ellipse(cx, cy, 6.4, 6.4, skin)
    c.rect(cx - 1, cy + 5, cx + 5, cy + 7, KEYLINE)
    c.rect(cx - 1, cy + 5, cx + 4, cy + 6, skin)                 # jaw
    c.rect(cx - 4, cy - 1, cx + 4, cy - 1, mix(skin, "#000000", 0.4))  # brow
    c.rect(cx + 6, cy + 1, cx + 7, cy + 3, KEYLINE)              # nose
    c.put(cx + 6, cy + 1, skin)
    c.put(cx + 6, cy + 2, h.skin_hi)
    c.put(cx + 3, cy + 5, mix(skin, "#000000", 0.5))             # mouth
    # One big comic eye.
    c.rect(cx + 1, cy + 1, cx + 3, cy + 2, "#ffffff")
    c.put(cx + 2, cy + 2, KEYLINE)
    # Back of the skull is never skin.
    back = h.accent if h.head_style in ("bun", "spikes") else shade(h, "dark")
    c.poly([(cx - 6, cy - 3), (cx - 1, cy - 6), (cx - 1, cy + 5), (cx - 5, cy + 4)], back)

    s = h.head_style
    if s == "cowboy":       # brim forward, red augmented eye
        c.rect(cx - 7, cy - 2, cx + 9, cy - 1, KEYLINE)
        c.rect(cx - 6, cy - 2, cx + 8, cy - 2, h.accent)
        c.put(cx + 8, cy - 2, h.accent_hi)
        c.poly([(cx - 5, cy - 3), (cx - 4, cy - 7), (cx + 4, cy - 7), (cx + 5, cy - 3)], KEYLINE)
        c.poly([(cx - 4, cy - 3), (cx - 3, cy - 6), (cx + 3, cy - 6), (cx + 4, cy - 3)], h.accent)
        c.rect(cx - 3, cy - 6, cx + 2, cy - 6, h.accent_hi)
        c.rect(cx + 1, cy + 1, cx + 4, cy + 2, h.accent)          # augmented eye
        c.rect(cx + 2, cy + 1, cx + 4, cy + 1, h.accent_hi)
        c.put(cx + 4, cy + 1, "#ffffff")
    elif s == "bun":        # hair with a top bun + jade pin
        c.ellipse(cx - 1, cy - 5, 5.6, 3.4, h.dark)
        c.ellipse(cx, cy - 8, 2.6, 2.4, KEYLINE)
        c.ellipse(cx, cy - 8, 1.8, 1.7, h.dark)
        c.rect(cx + 1, cy - 9, cx + 3, cy - 8, h.accent)          # ornament
        c.put(cx + 3, cy - 9, h.accent_hi)
        c.rect(cx - 5, cy - 4, cx + 4, cy - 3, h.accent)          # jade band
        c.put(cx - 5, cy - 3, h.accent_hi)
    elif s == "crown":      # fur band, gold trims
        c.rect(cx - 6, cy - 5, cx + 6, cy - 2, KEYLINE)
        c.rect(cx - 5, cy - 5, cx + 5, cy - 3, shade(h, "mid"))
        for i in range(-5, 6, 2):
            c.put(cx + i, cy - 5, h.accent_hi if i % 4 == 1 else h.accent)
        c.rect(cx - 5, cy - 2, cx + 5, cy - 2, h.accent)
    elif s == "crest":      # magneto-style helm with a centre fin
        c.poly([(cx - 6, cy + 1), (cx - 5, cy - 5), (cx + 5, cy - 5), (cx + 6, cy + 1)], KEYLINE)
        c.poly([(cx - 5, cy), (cx - 4, cy - 4), (cx + 4, cy - 4), (cx + 5, cy)], h.accent)
        c.rect(cx - 1, cy - 8, cx + 1, cy - 4, KEYLINE)           # fin
        c.rect(cx, cy - 7, cx, cy - 4, h.accent_hi)
        c.rect(cx - 5, cy, cx - 4, cy + 3, h.accent)              # ear guard
        c.rect(cx + 4, cy, cx + 5, cy + 3, h.accent)
    elif s == "visor":      # sleek band across the eyes, swept hair
        c.poly([(cx - 6, cy - 2), (cx - 2, cy - 7), (cx + 4, cy - 6), (cx + 5, cy - 3)], h.accent)
        c.put(cx + 5, cy - 5, h.accent_hi)
        c.rect(cx - 5, cy + 1, cx + 6, cy + 2, KEYLINE)
        c.rect(cx - 4, cy + 1, cx + 5, cy + 2, h.accent)
        c.rect(cx + 1, cy + 1, cx + 5, cy + 1, h.accent_hi)
        c.put(cx + 5, cy + 1, "#ffffff")
    elif s == "spikes":     # tall aqua spikes + goggles pushed up
        for dx, hgt in ((-4, 4), (-1, 6), (2, 5), (4, 3)):
            c.poly([(cx + dx - 1, cy - 4), (cx + dx, cy - 6 - hgt), (cx + dx + 2, cy - 4)], KEYLINE)
            c.poly([(cx + dx, cy - 4), (cx + dx, cy - 5 - hgt), (cx + dx + 1, cy - 4)], h.accent)
        c.rect(cx - 5, cy - 3, cx + 5, cy - 2, KEYLINE)           # goggle band
        c.rect(cx - 3, cy - 3, cx - 1, cy - 2, h.accent_hi)       # lenses
        c.rect(cx + 1, cy - 3, cx + 3, cy - 2, h.accent_hi)
    elif s == "hardhat":
        c.poly([(cx - 5, cy - 2), (cx - 4, cy - 6), (cx + 4, cy - 6), (cx + 5, cy - 2)], KEYLINE)
        c.poly([(cx - 4, cy - 2), (cx - 3, cy - 5), (cx + 3, cy - 5), (cx + 4, cy - 2)], h.accent)
        c.rect(cx - 3, cy - 5, cx + 2, cy - 5, h.accent_hi)
        c.rect(cx - 6, cy - 2, cx + 8, cy - 1, KEYLINE)
        c.rect(cx - 5, cy - 2, cx + 7, cy - 2, h.accent)
        c.rect(cx + 2, cy - 2, cx + 7, cy - 2, h.accent_hi)
    else:                   # glasses: big round frames + messy fringe
        c.ellipse(cx - 1, cy - 5, 5.8, 3.0, h.dark)
        for dx in (-3, 3):
            c.put(cx + dx, cy - 7, shade(h, "mid"))
        c.ellipse(cx, cy + 1, 2.4, 2.2, KEYLINE, filled=False)
        c.ellipse(cx + 4, cy + 1, 2.2, 2.2, KEYLINE, filled=False)
        c.ellipse(cx, cy + 1, 1.6, 1.4, h.accent_hi)
        c.ellipse(cx + 4, cy + 1, 1.4, 1.4, h.accent_hi)
        c.rect(cx - 6, cy - 3, cx + 5, cy - 3, h.accent)          # frame band


def draw_gear(c: Canvas, h: Hero, p: Pose) -> None:
    hx, hy = p.hand_f
    if h.gear == "pistol":
        c.rect(hx, hy - 1, hx + 5, hy, KEYLINE)
        c.rect(hx + 1, hy - 1, hx + 4, hy - 1, shade(h, "dark"))
        c.put(hx + 4, hy - 1, h.accent_hi)
    elif h.gear == "hook":
        c.rect(hx + 1, hy, hx + 3, hy + 1, KEYLINE)
        c.put(hx + 2, hy, h.accent)
        c.put(hx + 3, hy + 1, h.accent_hi)


def draw_fx(c: Canvas, h: Hero, p: Pose) -> None:
    tag, d = p.fx, p.fx_dir
    if tag == "dust":
        y = GROUND
        for i, x in enumerate((-10, -7, -4)):
            c.rect(16 + x * d, y - i * 2, 16 + x * d + 1, y - i * 2 + 1,
                   DUST if i else DUST_HI)
    elif tag == "streak":
        for y, length in ((p.neck[1] + 1, 11), (p.hip[1] - 1, 8), (p.neck[1] + 5, 6)):
            c.rect(16 - length * d, y, 16 - 3 * d, y, h.accent)
        c.rect(16 - 12 * d, p.neck[1] + 3, 16 - 6 * d, p.neck[1] + 3, h.accent_hi)
    elif tag == "sparks":
        for i, y in enumerate((p.neck[1] + 3, p.hip[1], p.hip[1] + 6)):
            c.put(16 + (7 + i % 2) * d, y, STAR_HI if i == 1 else STAR)
    elif tag == "stars":
        cx, cy = p.head
        for dx, dy, col in ((-8, -5, STAR), (8, -6, STAR_HI), (0, -9, STAR)):
            c.put(cx + dx, cy + dy, col)
            c.put(cx + dx + 1, cy + dy, col)
    elif tag == "boost":
        for foot in (p.foot_b, p.foot_f):
            c.rect(foot[0] - 1, foot[1] + 1, foot[0] + 1, foot[1] + 1, h.accent)


def draw_frame(h: Hero, p: Pose) -> Canvas:
    p = _shrink(p)
    c = Canvas(W, H)
    draw_cape(c, h, p)
    draw_arms(c, h, p, front=False)
    draw_legs(c, h, p)
    draw_torso(c, h, p)
    draw_emblem(c, h, p)
    draw_head(c, h, p)
    draw_arms(c, h, p, front=True)
    draw_gear(c, h, p)
    if p.ground:
        c.shadow_below(min(GROUND, int(max(p.foot_b[1], p.foot_f[1])) + 1), "#00000055")
    c.rim_light(h.accent_hi, falloff=shade(h, "mid"))
    c.outline(KEYLINE)
    draw_fx(c, h, p)
    return c


# --------------------------------------------------------------------------- #
# Animations — pose tables in the old 48-tall space, shrunk at draw time.
# --------------------------------------------------------------------------- #
def anim_idle() -> list[Pose]:
    out = []
    for bob in (0, 0, 1, 1):
        out.append(Pose(
            head=(16, 6 + bob), neck=(16, 13 + bob), hip=(16, 30),
            hand_b=(10, 28 + bob), hand_f=(22, 28 + bob),
            foot_b=(12, OG), foot_f=(20, OG),
            cape=1 + bob, knee_bend=1.5))
    return out


def anim_run() -> list[Pose]:
    """Six-frame cycle: feet ride an ellipse, torso bobs and leans into it."""
    out = []
    for i in range(6):
        ph = i / 6.0 * math.tau
        fx_b, fy_b = math.cos(ph) * 6, math.sin(ph) * 3
        fx_f, fy_f = math.cos(ph + math.pi) * 6, math.sin(ph + math.pi) * 3
        bob = 1 if i in (1, 4) else 0
        out.append(Pose(
            head=(17, 6 + bob), neck=(16, 13 + bob), hip=(16, 30 + bob),
            hand_b=(13 - fx_f * 0.8, 27 + bob), hand_f=(19 - fx_b * 0.8, 27 + bob),
            foot_b=(16 + fx_b, OG - max(0, -fy_b) * 2),
            foot_f=(16 + fx_f, OG - max(0, -fy_f) * 2),
            lean=2, cape=3 + abs(fx_b) * 0.4, cape_lift=2,
            knee_bend=2.5, elbow_bend=2.5,
            fx="dust" if i in (0, 3) else ""))
    return out


def anim_rise() -> list[Pose]:
    return [
        Pose(head=(16, 5), neck=(16, 12), hip=(16, 29),
             hand_b=(10, 24), hand_f=(21, 23), foot_b=(14, 45), foot_f=(19, 43),
             lean=1, cape=4, cape_lift=4, knee_bend=3, ground=False),
        Pose(head=(16, 5), neck=(16, 12), hip=(16, 30),
             hand_b=(10, 22), hand_f=(21, 21), foot_b=(14, 46), foot_f=(18, 44),
             lean=1, cape=5, cape_lift=5, knee_bend=2, ground=False),
    ]


def anim_fall() -> list[Pose]:
    return [
        Pose(head=(16, 6), neck=(16, 13), hip=(16, 30),
             hand_b=(9, 20), hand_f=(23, 19), foot_b=(12, 46), foot_f=(21, 44),
             cape=5, cape_lift=6, knee_bend=3, ground=False),
        Pose(head=(16, 6), neck=(16, 13), hip=(16, 30),
             hand_b=(9, 19), hand_f=(23, 21), foot_b=(11, 45), foot_f=(21, 46),
             cape=6, cape_lift=5, knee_bend=4, ground=False),
    ]


def anim_land() -> list[Pose]:
    """Hard squash then recover — the read that sells weight (STYLE_GUIDE)."""
    return [
        Pose(head=(16, 12), neck=(16, 19), hip=(16, 34),
             hand_b=(7, 34), hand_f=(25, 34), foot_b=(10, OG), foot_f=(22, OG),
             knee_bend=5, elbow_bend=3, cape=2, cape_lift=-2, fx="dust"),
        Pose(head=(16, 9), neck=(16, 16), hip=(16, 32),
             hand_b=(9, 32), hand_f=(23, 32), foot_b=(11, OG), foot_f=(21, OG),
             knee_bend=3, cape=1),
    ]


def anim_dash() -> list[Pose]:
    return [
        Pose(head=(19, 8), neck=(17, 15), hip=(14, 30),
             hand_b=(8, 26), hand_f=(9, 30), foot_b=(9, 42), foot_f=(13, 45),
             lean=3, cape=7, cape_lift=8, knee_bend=3, ground=False, fx="streak"),
        Pose(head=(20, 9), neck=(18, 16), hip=(13, 31),
             hand_b=(7, 27), hand_f=(8, 31), foot_b=(8, 41), foot_f=(12, 44),
             lean=4, cape=8, cape_lift=9, knee_bend=2, ground=False, fx="streak"),
    ]


def anim_skid() -> list[Pose]:
    """Braking out of a redirect: weight back, front foot planted (DESIGN 4.1)."""
    return [
        Pose(head=(13, 7), neck=(14, 14), hip=(16, 31),
             hand_b=(9, 24), hand_f=(21, 26), foot_b=(13, OG), foot_f=(22, OG),
             lean=-3, cape=6, cape_lift=4, knee_bend=4, fx="dust", fx_dir=-1),
        Pose(head=(13, 8), neck=(14, 15), hip=(16, 31),
             hand_b=(8, 25), hand_f=(20, 27), foot_b=(12, OG), foot_f=(23, OG),
             lean=-3, cape=5, cape_lift=3, knee_bend=5, fx="dust", fx_dir=-1),
    ]


def anim_crouch() -> list[Pose]:
    """Bottom half only: the pose has to match the shrunken collision box."""
    return [
        Pose(head=(16, 28), neck=(16, 34), hip=(16, 41),
             hand_b=(10, 41), hand_f=(22, 41), foot_b=(11, OG), foot_f=(21, OG),
             knee_bend=5, elbow_bend=2, cape=2, cape_lift=-3, crouched=True),
        Pose(head=(16, 29), neck=(16, 35), hip=(16, 41),
             hand_b=(10, 42), hand_f=(22, 42), foot_b=(11, OG), foot_f=(21, OG),
             knee_bend=5, elbow_bend=2, cape=2, cape_lift=-3, crouched=True),
    ]


def anim_slide() -> list[Pose]:
    return [
        Pose(head=(19, 28), neck=(17, 34), hip=(12, 42),
             hand_b=(9, 38), hand_f=(23, 36), foot_b=(14, OG), foot_f=(23, 45),
             knee_bend=3, elbow_bend=3, cape=6, cape_lift=-6, crouched=True, fx="dust"),
        Pose(head=(20, 29), neck=(18, 35), hip=(12, 43),
             hand_b=(8, 39), hand_f=(24, 37), foot_b=(13, OG), foot_f=(24, 46),
             knee_bend=2, elbow_bend=3, cape=7, cape_lift=-7, crouched=True, fx="dust"),
    ]


def anim_slide_jump() -> list[Pose]:
    """Low and long — almost horizontal, arms swept back (DESIGN 4.5)."""
    return [
        Pose(head=(20, 16), neck=(18, 22), hip=(12, 32),
             hand_b=(8, 28), hand_f=(9, 24), foot_b=(8, 40), foot_f=(12, 43),
             lean=3, cape=8, cape_lift=8, knee_bend=3, ground=False, fx="streak"),
        Pose(head=(21, 14), neck=(19, 20), hip=(12, 31),
             hand_b=(7, 26), hand_f=(8, 22), foot_b=(7, 38), foot_f=(11, 42),
             lean=4, cape=9, cape_lift=9, knee_bend=2, ground=False),
    ]


def anim_wall_slide() -> list[Pose]:
    """Clinging with the wall on the RIGHT; the sprite flips for the other side."""
    return [
        Pose(head=(18, 7), neck=(17, 14), hip=(15, 30),
             hand_b=(13, 22), hand_f=(23, 18), foot_b=(13, 44), foot_f=(19, 46),
             lean=2, cape=4, cape_lift=1, knee_bend=4, ground=False, fx="sparks"),
        Pose(head=(18, 8), neck=(17, 15), hip=(15, 31),
             hand_b=(13, 23), hand_f=(23, 20), foot_b=(13, 45), foot_f=(19, OG),
             lean=2, cape=3, cape_lift=0, knee_bend=3, ground=False, fx="sparks"),
    ]


def anim_wall_jump() -> list[Pose]:
    """Pushing off: arched away from the wall, trailing leg extended into it."""
    return [
        Pose(head=(14, 6), neck=(15, 13), hip=(17, 29),
             hand_b=(11, 19), hand_f=(22, 17), foot_b=(15, 42), foot_f=(23, 40),
             lean=-2, cape=6, cape_lift=6, knee_bend=4, ground=False),
        Pose(head=(13, 6), neck=(14, 13), hip=(17, 30),
             hand_b=(9, 20), hand_f=(20, 18), foot_b=(14, 44), foot_f=(22, 43),
             lean=-3, cape=7, cape_lift=7, knee_bend=3, ground=False),
    ]


def anim_pole_climb() -> list[Pose]:
    return [
        Pose(head=(16, 6), neck=(16, 13), hip=(16, 30),
             hand_b=(16, 17), hand_f=(17, 22), foot_b=(13, 42), foot_f=(19, 45),
             knee_bend=5, elbow_bend=-1, cape=2, ground=False),
        Pose(head=(16, 7), neck=(16, 14), hip=(16, 31),
             hand_b=(16, 22), hand_f=(17, 17), foot_b=(13, 45), foot_f=(19, 42),
             knee_bend=5, elbow_bend=-1, cape=2, ground=False),
    ]


def anim_stun() -> list[Pose]:
    """Momentum is kept while stunned (DESIGN 3.2) but control is not."""
    return [
        Pose(head=(14, 9), neck=(15, 15), hip=(16, 31),
             hand_b=(9, 33), hand_f=(22, 34), foot_b=(12, OG), foot_f=(21, OG),
             lean=-2, cape=3, knee_bend=4, elbow_bend=-2, fx="stars"),
        Pose(head=(15, 10), neck=(16, 16), hip=(16, 31),
             hand_b=(10, 34), hand_f=(23, 33), foot_b=(11, OG), foot_f=(22, OG),
             lean=-1, cape=2, knee_bend=5, elbow_bend=-2, fx="stars"),
    ]


def anim_cast() -> list[Pose]:
    """Ability wind-up and release. Each hero's prop does the talking."""
    return [
        Pose(head=(16, 6), neck=(16, 13), hip=(16, 30),
             hand_b=(12, 26), hand_f=(24, 24), foot_b=(12, OG), foot_f=(21, OG),
             lean=-1, cape=3, knee_bend=2),
        Pose(head=(17, 6), neck=(17, 13), hip=(16, 30),
             hand_b=(13, 27), hand_f=(26, 22), foot_b=(11, OG), foot_f=(22, OG),
             lean=2, cape=5, cape_lift=2, knee_bend=2, fx="boost"),
    ]


def anim_pop(h: Hero) -> list[Canvas]:
    """Elimination: confetti burst, no gore (DESIGN 3.3)."""
    base = draw_frame(h, Pose(
        head=(16, 6), neck=(16, 13), hip=(16, 30),
        hand_b=(10, 28), hand_f=(22, 28), foot_b=(12, OG), foot_f=(20, OG),
        knee_bend=1.5, ground=False))
    frames: list[Canvas] = []

    squash = Canvas(W, H)
    for y in range(H):
        for x in range(W):
            px = base.px[y][x]
            if px[3]:
                squash.put(x, min(GROUND, int(22 + (y - 22) * 0.7)), px)
    frames.append(squash)

    flash = Canvas(W, H)
    for y in range(H):
        for x in range(W):
            if base.px[y][x][3]:
                edge = not all(base.opaque(x + dx, y + dy)
                               for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)))
                flash.put(x, y - 1, h.accent_hi if edge else "#ffffff")
    frames.append(flash)

    cy = 19
    for step, (radius, count, size) in enumerate(((6, 22, 2), (11, 18, 1), (16, 11, 1))):
        f = Canvas(W, H)
        for i in range(count):
            ang = (i / count) * math.tau + (step * 0.7) + (i % 3) * 0.18
            jitter = 0.75 + ((i * 37) % 10) / 20.0
            x = int(16 + math.cos(ang) * radius * jitter)
            y = int(cy + math.sin(ang) * radius * 0.75 * jitter + step * step)
            col = (h.accent, h.accent_hi, "#fff3b0", shade(h, "light"))[i % 4]
            f.rect(x, y, x + size - 1, y, col)
        if step == 0:
            for i, (dx, dy) in enumerate(((-3, -5), (3, -6), (-4, 2), (4, 3), (0, -8))):
                f.rect(16 + dx, cy + dy, 16 + dx + 1, cy + dy + 1,
                       h.accent if i % 2 else h.accent_hi)
        frames.append(f)
    return frames


ANIMATIONS = {
    "idle": (anim_idle, 6.0, True),
    "run": (anim_run, 14.0, True),
    "rise": (anim_rise, 8.0, False),
    "fall": (anim_fall, 8.0, True),
    "land": (anim_land, 14.0, False),
    "dash": (anim_dash, 16.0, False),
    "skid": (anim_skid, 10.0, True),
    "crouch": (anim_crouch, 4.0, True),
    "slide": (anim_slide, 8.0, True),
    "slide_jump": (anim_slide_jump, 10.0, False),
    "wall_slide": (anim_wall_slide, 6.0, True),
    "wall_jump": (anim_wall_jump, 12.0, False),
    "pole_climb": (anim_pole_climb, 6.0, True),
    "stun": (anim_stun, 5.0, True),
    "cast": (anim_cast, 12.0, False),
}
POP_FPS = 12.0


def build(hero: Hero) -> dict[str, int]:
    counts: dict[str, int] = {}
    for name, (poses, _fps, _loop) in ANIMATIONS.items():
        frames = [draw_frame(hero, p) for p in poses()]
        strip(frames).save(OUT / hero.key / f"{name}.png")
        counts[name] = len(frames)
    pop = anim_pop(hero)
    strip(pop).save(OUT / hero.key / "pop.png")
    counts["pop"] = len(pop)
    return counts


def write_sprite_frames(hero: Hero, counts: dict[str, int]) -> Path:
    """Emit the SpriteFrames resource AnimatedSprite2D consumes; generated with
    the sheets so frame counts can never drift apart."""
    meta = {n: (fps, loop) for n, (_p, fps, loop) in ANIMATIONS.items()}
    meta["pop"] = (POP_FPS, False)
    ext, subs, anims = [], [], []
    for name, count in counts.items():
        ext_id = f"tex_{name}"
        ext.append(f'[ext_resource type="Texture2D" '
                   f'path="res://assets/characters/{hero.key}/{name}.png" id="{ext_id}"]')
        frame_refs = []
        for f in range(count):
            sub_id = f"{name}_{f}"
            subs.append(f'[sub_resource type="AtlasTexture" id="{sub_id}"]\n'
                        f'atlas = ExtResource("{ext_id}")\n'
                        f'region = Rect2({f * W}, 0, {W}, {H})')
            frame_refs.append(f'{{\n"duration": 1.0,\n"texture": SubResource("{sub_id}")\n}}')
        fps, loop = meta[name]
        anims.append('{\n"frames": [%s],\n"loop": %s,\n"name": &"%s",\n"speed": %.1f\n}'
                     % (", ".join(frame_refs), "true" if loop else "false", name, fps))
    body = (f'[gd_resource type="SpriteFrames" load_steps={len(ext) + len(subs) + 1} format=3]\n\n'
            + "\n".join(ext) + "\n\n" + "\n\n".join(subs)
            + "\n\n[resource]\nanimations = [" + ", ".join(anims) + "]\n")
    path = FRAMES_OUT / f"{hero.key}_frames.tres"
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(body, encoding="utf-8", newline="\n")
    return path


def main() -> None:
    for hero in HEROES:
        counts = build(hero)
        write_sprite_frames(hero, counts)
        total = sum(counts.values())
        print(f"{hero.name:10s} {total:3d} frames across {len(counts)} animations")
    print(f"Wrote sheets to {OUT}")
    print(f"Wrote SpriteFrames to {FRAMES_OUT}")
    print("Run `Godot --headless --path . --import` so Godot picks up new PNGs.")


if __name__ == "__main__":
    main()
