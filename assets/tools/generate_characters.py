#!/usr/bin/env python3
"""Generate Overstomp's character sprite sheets.

Every hero is drawn by the same limb rig — hips, shoulders, knees, elbows posed
per frame — wearing a different set of parts. That is the point: DESIGN 5.1 says
heroes share movement, hitboxes, and silhouette *size*, and differ only in
identity, so the art pipeline enforces it structurally instead of by hand.

Two rules the rig will not let you break:
  * 32x48 logical pixels, feet on row 47.
  * The head lives in the top 12px standing (rows 1..12) and in rows 24..30 when
    crouched, always accent-marked. That band IS the stomp hurtbox (DESIGN 3.1),
    so it has to read as "hit here" at gameplay zoom.

Stdlib only. Run from the repo root:
    python assets/tools/generate_characters.py
"""
from __future__ import annotations

import math
from dataclasses import dataclass, field, replace
from pathlib import Path

from pixel import Canvas, mix, strip

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "characters"
FRAMES_OUT = ROOT.parent / "src" / "heroes" / "resources" / "frames"

W, H = 32, 48
GROUND = 47
KEYLINE = "#0d0716"
DUST = "#5b5b7a"
DUST_HI = "#b8b8d1"
STAR = "#ffd23f"
STAR_HI = "#fff3b0"


# --------------------------------------------------------------------------- #
# Pose: joints in sprite space. Elbows and knees are derived unless overridden.
# --------------------------------------------------------------------------- #
@dataclass
class Pose:
    head: tuple = (16, 6)
    neck: tuple = (16, 13)
    hip: tuple = (16, 30)
    hand_b: tuple = (11, 29)      # back arm (drawn behind, shaded down)
    hand_f: tuple = (21, 29)      # front arm
    foot_b: tuple = (13, GROUND)
    foot_f: tuple = (19, GROUND)
    knee_bend: float = 2.0
    elbow_bend: float = 2.0
    lean: float = 0.0             # torso top offset, + is forward (right)
    cape: float = 0.0             # trail length; + trails behind (left)
    cape_lift: float = 0.0        # + lifts the trail toward horizontal
    crouched: bool = False        # picks the short head band + tucked gear
    ground: bool = True
    fx: str = ""
    fx_dir: int = 1


def joint(a, b, bend):
    """Midpoint pushed perpendicular to the limb — the knee or elbow."""
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
    skin: str = "#d95763"
    skin_hi: str = "#f2a65a"
    torso_w: int = 6          # half-width at the shoulders
    limb: int = 3             # limb thickness
    cape_style: str = "none"  # coat | scarf | cape | none
    cape_color: str = ""
    head_style: str = ""
    gear: str = ""

    def cape_col(self) -> str:
        return self.cape_color or self.dark


HEROES = [
    # Sharpshooter vigilante: long split coat, brimmed cowl, visor slit, bolt
    # pistol. Slimmest silhouette; reads by the coat tails.
    Hero("deadeye", "Deadeye", "#1a1030", "#3b2d63", "#5b5b7a", "#ff2e88", "#ff6ec7",
         torso_w=6, limb=3, cape_style="coat", cape_color="#2a1d4a",
         head_style="cowl", gear="pistol"),
    # Jet-boot speedster: finned aero helmet, goggles, streaming scarf, heavy
    # boots with vents. Narrow shoulders, tallest read.
    Hero("skyla", "Skyla", "#14232e", "#2e5a66", "#3f7d85", "#2de2e6", "#7df9ff",
         torso_w=5, limb=3, cape_style="scarf", cape_color="#2de2e6",
         head_style="helmet", gear="boots"),
    # Hard-light constructor: hard hat with a brow lamp, pauldrons, oversized
    # gauntlets. Widest, blockiest silhouette in the roster.
    Hero("mason", "Mason", "#2a1d4a", "#402039", "#6b2d5b", "#ffb454", "#ffe66d",
         torso_w=8, limb=4, cape_style="none",
         head_style="hardhat", gear="gauntlets"),
    # Gravity brawler: deep hood with a halo ring, ring-motif gauntlets, orbiting
    # orb, heavy cape. Broad and low.
    Hero("nova", "Nova", "#1a1030", "#33334d", "#5b5b7a", "#9d4edd", "#c77dff",
         torso_w=7, limb=4, cape_style="cape", cape_color="#2a1d4a",
         head_style="hood", gear="orb"),
]


# --------------------------------------------------------------------------- #
# Body parts
#
# Everything the body is made of is drawn with a 1px keyline around it, not just
# around the outside of the silhouette. At 32x48 a dark suit against a dark stage
# turns into one unreadable blob otherwise: the internal lines are what separate
# the back leg from the front leg while both are in shadow.
# --------------------------------------------------------------------------- #
def shade(h: Hero, level: str) -> str:
    """Five-step suit ramp, each step tinted toward the hero's neon.

    The night palette is narrow enough that an untinted ramp collapses into one
    dark mass at gameplay zoom. Bouncing a little accent through the midtones
    both widens the ramp and makes the suit belong to the hero wearing it.
    """
    return {
        "shadow": mix(h.dark, "#000000", 0.3),
        "dark": mix(h.dark, h.accent, 0.10),
        "mid": mix(h.mid, h.accent, 0.20),
        "light": mix(h.light, h.accent_hi, 0.30),
        "edge": mix(h.light, "#ffffff", 0.35),
    }[level]


def face_skin(h: Hero) -> str:
    """Skin sits in the same dusk key as everything else — raw skin tone at full
    saturation reads as a bright blob and steals attention from the accent."""
    return mix(h.skin, h.dark, 0.3)


def limb_keyed(c: Canvas, p0, p1, width: int, col) -> None:
    """Thick line with its own outline, so limbs stay separate when they cross."""
    c.limb(p0, p1, width + 2, KEYLINE)
    c.limb(p0, p1, width, col)


def draw_cape(c: Canvas, h: Hero, p: Pose) -> None:
    if h.cape_style == "none":
        return
    nx, ny = p.neck
    trail = p.cape
    col = h.cape_col()
    if h.cape_style == "scarf":
        # Streams from the collar, not the chin — at neck height it draws as a
        # plank through the face. It is Skyla's motion tell, so it exaggerates.
        y = ny + 3
        tip = (nx - 4 - trail, y - p.cape_lift)
        c.poly([(nx, y - 1), (nx, y + 2), (tip[0], tip[1] + 2), (tip[0], tip[1] - 1)], KEYLINE)
        c.poly([(nx, y), (nx, y + 1), (tip[0], tip[1] + 1), (tip[0], tip[1])], col)
        c.poly([(tip[0], tip[1] - 1), (tip[0] - 3, tip[1] - 1 - p.cape_lift * 0.4),
                (tip[0], tip[1] + 1)], h.accent_hi)
        return
    bottom = p.hip[1] + (8 if h.cape_style == "cape" else 14)
    bottom = min(bottom, GROUND - 1)
    if p.crouched:
        bottom = min(bottom, GROUND - 1)
    pts = [(nx - 1, ny), (nx + 2, ny),
           (nx + 1, bottom - p.cape_lift),
           (nx - 3 - trail, bottom - p.cape_lift * 1.5),
           (nx - 4 - trail, ny + 4)]
    c.poly(pts, col)
    if h.cape_style == "coat":
        # Split tails: the gap is what makes the coat read as a coat at 32px.
        c.line((nx - 1, bottom - 3 - p.cape_lift), (nx - 2 - trail, bottom - p.cape_lift * 1.5), KEYLINE)


def draw_torso(c: Canvas, h: Hero, p: Pose) -> None:
    nx, ny = p.neck
    hx, hy = p.hip
    tw = h.torso_w
    sx = nx + p.lean
    body = [(sx - tw, ny + 1), (sx + tw, ny + 1),
            (hx + tw - 2, hy + 1), (hx - tw + 2, hy + 1)]
    c.poly([(x + dx, y + dy) for (x, y) in body
            for dx, dy in ((0, 0),)], KEYLINE)      # keyline base
    c.poly([(sx - tw + 1, ny + 1), (sx + tw - 1, ny + 1),
            (hx + tw - 3, hy), (hx - tw + 3, hy)], shade(h, "mid"))
    # Three-plane read: shadow side, lit chest, bright key edge up-right.
    c.poly([(sx - tw + 1, ny + 1), (sx - tw + 3, ny + 1),
            (hx - tw + 4, hy), (hx - tw + 3, hy)], shade(h, "shadow"))
    c.poly([(sx - tw + 3, ny + 2), (sx + tw - 3, ny + 2),
            (sx + tw - 4, ny + 6), (sx - tw + 4, ny + 6)], shade(h, "dark"))
    c.rect(sx + tw - 2, ny + 3, sx + tw - 2, hy - 2, shade(h, "light"))
    # Belt with an accent buckle — the waist line keeps the torso from reading
    # as one long slab.
    c.rect(hx - tw + 2, hy - 1, hx + tw - 2, hy, KEYLINE)
    c.rect(hx - tw + 3, hy - 1, hx + tw - 3, hy - 1, shade(h, "light"))
    c.rect(hx - 1, hy - 1, hx + 1, hy, h.accent)


def draw_shoulders(c: Canvas, h: Hero, p: Pose) -> None:
    """Pauldrons carry most of the build difference between heroes."""
    sx = p.neck[0] + p.lean
    sy = p.neck[1] + 2
    tw = h.torso_w
    if h.key == "mason":        # slabs, the widest read in the roster
        for side, col in ((-1, shade(h, "shadow")), (1, shade(h, "mid"))):
            x = sx + side * (tw - 1)
            c.rect(x - 2, sy - 2, x + 2, sy + 2, KEYLINE)
            c.rect(x - 2, sy - 1, x + 2, sy + 1, col)
            c.rect(x - 2, sy - 1, x + 2, sy - 1, h.accent)
    elif h.key == "nova":       # rounded, heavy
        for side, col in ((-1, shade(h, "shadow")), (1, shade(h, "mid"))):
            x = sx + side * (tw - 1)
            c.ellipse(x, sy, 3.0, 2.6, KEYLINE)
            c.ellipse(x, sy, 2.2, 2.0, col)
            c.put(x, sy - 2, h.accent)
    elif h.key == "deadeye":    # popped coat collar
        c.poly([(sx - tw, sy - 3), (sx - tw + 3, sy - 4), (sx - tw + 3, sy + 1)], KEYLINE)
        c.poly([(sx + tw, sy - 3), (sx + tw - 3, sy - 4), (sx + tw - 3, sy + 1)], KEYLINE)
        c.poly([(sx + tw - 1, sy - 3), (sx + tw - 3, sy - 3), (sx + tw - 3, sy)], h.accent)
    else:                       # skyla: streamlined, no pads, just vents
        c.rect(sx + tw - 3, sy - 2, sx + tw - 2, sy - 1, h.accent)


def draw_emblem(c: Canvas, h: Hero, p: Pose) -> None:
    if p.crouched:
        return
    sx = p.neck[0] + p.lean
    y = p.neck[1] + 6
    if h.key == "deadeye":      # bandolier across the chest
        c.line((sx - 5, y - 2), (sx + 4, y + 4), KEYLINE)
        c.line((sx - 5, y - 1), (sx + 4, y + 5), h.accent)
        for t in (0.25, 0.5, 0.75):
            c.put(sx - 5 + 9 * t, y - 1 + 6 * t, h.accent_hi)
    elif h.key == "skyla":      # chevron over a vent grille
        c.line((sx - 3, y + 1), (sx, y - 1), h.accent)
        c.line((sx, y - 1), (sx + 3, y + 1), h.accent)
        c.put(sx, y, h.accent_hi)
        for i in range(3):
            c.rect(sx - 2, y + 3 + i, sx + 2, y + 3 + i, shade(h, "shadow") if i % 2 else shade(h, "light"))
    elif h.key == "mason":      # brick plate with rivets
        c.rect(sx - 3, y - 2, sx + 3, y + 3, KEYLINE)
        c.rect(sx - 3, y - 1, sx + 3, y + 2, h.accent)
        c.rect(sx - 3, y - 1, sx + 3, y - 1, h.accent_hi)
        c.line((sx, y), (sx, y + 2), KEYLINE)
        c.line((sx - 3, y + 1), (sx + 3, y + 1), KEYLINE)
        c.put(sx - 2, y + 3, h.accent_hi)
        c.put(sx + 2, y + 3, h.accent_hi)
    else:                       # nova: gravity ring
        c.ellipse(sx, y, 3.6, 3.6, KEYLINE, filled=False)
        c.ellipse(sx, y, 3.0, 3.0, h.accent, filled=False)
        c.put(sx, y, h.accent_hi)
        c.put(sx + 3, y - 1, h.accent_hi)


def draw_legs(c: Canvas, h: Hero, p: Pose) -> None:
    for foot, level, bend in ((p.foot_b, "shadow", -p.knee_bend),
                              (p.foot_f, "mid", p.knee_bend)):
        col = shade(h, level)
        knee = joint(p.hip, foot, bend)
        limb_keyed(c, p.hip, knee, h.limb, col)                 # thigh
        limb_keyed(c, knee, foot, max(2, h.limb - 1), col)      # shin
        c.rect(knee[0] - 1, knee[1] - 1, knee[0] + 1, knee[1], shade(h, "dark"))
        # Boot: a real block, not a trim line — it anchors the pose to the floor.
        fx, fy = int(foot[0]), int(foot[1])
        c.rect(fx - 3, fy - 3, fx + 3, fy, KEYLINE)
        c.rect(fx - 2, fy - 3, fx + 2, fy - 1, shade(h, "dark") if level == "mid" else shade(h, "shadow"))
        c.rect(fx - 2, fy - 3, fx + 2, fy - 3, h.accent)
        if h.gear == "boots":   # Skyla's jets: vents down the heel
            c.rect(fx - 2, fy - 2, fx - 2, fy - 1, h.accent_hi)
            c.put(fx + 2, fy - 2, h.accent_hi)


def draw_arms(c: Canvas, h: Hero, p: Pose, front: bool) -> None:
    """Called twice so the back arm can sit behind the torso and the front arm
    in front of it — without that the arms disappear into the chest."""
    sx = p.neck[0] + p.lean
    sy = p.neck[1] + 2
    hand, level, bend = ((p.hand_f, "mid", p.elbow_bend) if front
                         else (p.hand_b, "shadow", -p.elbow_bend))
    col = shade(h, level)
    shoulder = (sx + (h.torso_w - 1) * (1 if front else -1), sy)
    elbow = joint(shoulder, hand, bend)
    w = max(2, h.limb - 1)
    limb_keyed(c, shoulder, elbow, w, col)
    limb_keyed(c, elbow, hand, max(2, w - 1), col)
    hx, hy = int(hand[0]), int(hand[1])
    if h.gear == "gauntlets":   # Mason: the hands ARE the ability
        c.rect(hx - 3, hy - 3, hx + 3, hy + 2, KEYLINE)
        c.rect(hx - 2, hy - 2, hx + 2, hy + 1, shade(h, "mid") if front else shade(h, "shadow"))
        c.rect(hx - 2, hy - 2, hx + 2, hy - 2, h.accent)
        c.put(hx + 1, hy, h.accent_hi)
    else:
        # Gloves, not bare hands: a 3x3 patch of skin tone at this size reads as
        # a bright blob and pulls the eye off the accent.
        glove = shade(h, "dark" if front else "shadow")
        c.rect(hx - 2, hy - 2, hx + 2, hy + 2, KEYLINE)
        c.rect(hx - 1, hy - 1, hx + 1, hy + 1, glove)
        c.rect(hx - 1, hy - 2, hx + 1, hy - 2, h.accent)        # cuff
        c.put(hx + 1, hy, mix(h.skin_hi, glove, 0.4))           # knuckle highlight


def draw_head(c: Canvas, h: Hero, p: Pose) -> None:
    """The stomp hurtbox, and so the most load-bearing 12 pixels on the sprite.

    Built as a skull first and headgear second, never as stacked bands: the
    accent has to own the upper half (that is the "hit here" signal) while the
    lower half stays a readable face, so a player can tell at a glance where the
    kill zone ends. Everything faces +x; the sprite flips for the other way.
    """
    cx, cy = int(p.head[0]), int(p.head[1])
    style = h.head_style
    skin = face_skin(h)
    # Shared skull: 9 wide, 11 tall, jaw pushed forward, brow in shadow. The brow
    # band and the mouth line are what keep the face from reading as one blob.
    c.ellipse(cx, cy, 5.0, 5.6, KEYLINE)
    c.ellipse(cx, cy, 4.2, 4.8, skin)
    c.rect(cx - 1, cy + 3, cx + 4, cy + 5, KEYLINE)
    c.rect(cx - 1, cy + 3, cx + 2, cy + 4, skin)                # jaw
    c.rect(cx - 3, cy - 1, cx + 3, cy - 1, mix(skin, "#000000", 0.45))   # brow shadow
    c.rect(cx + 1, cy + 1, cx + 3, cy + 1, h.skin_hi)           # cheek key light
    c.put(cx + 2, cy + 3, mix(skin, "#000000", 0.5))            # mouth

    if style == "cowl":         # Deadeye: hood over the skull, brim, visor slit
        c.poly([(cx - 5, cy + 1), (cx - 5, cy - 3), (cx - 2, cy - 6),
                (cx + 2, cy - 6), (cx + 5, cy - 3), (cx + 5, cy - 1)], KEYLINE)
        c.poly([(cx - 4, cy), (cx - 4, cy - 3), (cx - 2, cy - 5),
                (cx + 2, cy - 5), (cx + 4, cy - 3), (cx + 4, cy - 1)], h.accent)
        c.poly([(cx - 2, cy - 5), (cx + 2, cy - 5), (cx + 3, cy - 4),
                (cx - 2, cy - 4)], h.accent_hi)
        c.rect(cx - 6, cy - 1, cx + 5, cy - 1, KEYLINE)         # brim
        c.rect(cx - 6, cy - 2, cx + 5, cy - 2, h.accent)
        c.poly([(cx - 6, cy - 2), (cx - 9, cy + 1), (cx - 6, cy)], h.dark)  # swept tail
        c.rect(cx + 1, cy, cx + 4, cy, h.accent_hi)             # visor slit
        c.put(cx + 4, cy, "#ffffff")
    elif style == "helmet":     # Skyla: aero shell, dorsal fin, goggle lenses
        c.ellipse(cx, cy - 1, 5.4, 4.8, KEYLINE)
        c.ellipse(cx, cy - 1, 4.6, 4.0, h.accent)
        c.ellipse(cx + 1, cy - 2, 3.0, 2.2, h.accent_hi)
        c.poly([(cx - 3, cy - 5), (cx - 9, cy - 1), (cx - 4, cy - 1)], KEYLINE)
        c.poly([(cx - 4, cy - 4), (cx - 8, cy - 1), (cx - 4, cy - 1)], h.accent)
        c.rect(cx - 5, cy + 1, cx + 5, cy + 1, KEYLINE)         # goggle band
        c.rect(cx - 4, cy, cx + 4, cy, shade(h, "shadow"))
        c.rect(cx + 1, cy, cx + 3, cy, h.accent_hi)             # lens
        c.put(cx + 3, cy, "#ffffff")
        c.rect(cx - 3, cy, cx - 2, cy, mix(h.accent_hi, h.dark, 0.4))
    elif style == "hardhat":    # Mason: wide brim, brow lamp, heavy jaw
        c.poly([(cx - 5, cy - 1), (cx - 4, cy - 5), (cx + 4, cy - 5),
                (cx + 5, cy - 1)], KEYLINE)
        c.poly([(cx - 4, cy - 1), (cx - 3, cy - 4), (cx + 3, cy - 4),
                (cx + 4, cy - 1)], h.accent)
        c.rect(cx - 3, cy - 4, cx + 2, cy - 4, h.accent_hi)
        c.rect(cx - 7, cy - 1, cx + 6, cy, KEYLINE)             # brim, front-heavy
        c.rect(cx - 6, cy - 1, cx + 6, cy - 1, h.accent)
        c.rect(cx + 2, cy - 1, cx + 6, cy - 1, h.accent_hi)
        c.rect(cx + 3, cy, cx + 5, cy, "#fff3b0")               # brow lamp beam
        c.put(cx + 2, cy + 1, KEYLINE)                          # eyes
        c.put(cx, cy + 1, KEYLINE)
        c.rect(cx - 2, cy + 4, cx + 1, cy + 4, mix(face_skin(h), "#000000", 0.5))  # stubble
    else:                       # Nova: deep hood, halo ring, eyes in the dark
        c.poly([(cx - 6, cy + 4), (cx - 5, cy - 3), (cx - 2, cy - 6),
                (cx + 2, cy - 6), (cx + 5, cy - 3), (cx + 6, cy + 4)], KEYLINE)
        c.poly([(cx - 5, cy + 4), (cx - 4, cy - 3), (cx - 2, cy - 5),
                (cx + 2, cy - 5), (cx + 4, cy - 3), (cx + 5, cy + 4)], shade(h, "dark"))
        c.rect(cx - 3, cy, cx + 4, cy + 4, "#0d0716")           # face in shadow
        c.ellipse(cx, cy - 2, 4.6, 3.0, h.accent, filled=False)  # halo ring
        c.put(cx - 4, cy - 2, h.accent_hi)
        c.put(cx + 4, cy - 2, h.accent_hi)
        c.rect(cx + 1, cy + 1, cx + 2, cy + 1, h.accent_hi)     # eyes
        c.put(cx - 1, cy + 1, h.accent)


def draw_gear(c: Canvas, h: Hero, p: Pose) -> None:
    """The one prop that says which hero this is at a glance."""
    hx, hy = p.hand_f
    if h.gear == "pistol":
        c.rect(hx, hy - 1, hx + 4, hy, h.dark)
        c.rect(hx + 3, hy - 1, hx + 4, hy - 1, h.accent)
        c.rect(hx + 1, hy + 1, hx + 2, hy + 2, h.dark)
    elif h.gear == "orb":
        c.ellipse(hx + 3, hy - 1, 2.6, 2.6, h.accent)
        c.ellipse(hx + 3, hy - 1, 1.2, 1.2, h.accent_hi)
    elif h.gear == "gauntlets":
        c.rect(hx - 2, hy + 2, hx + 2, hy + 2, h.accent_hi)   # emitter glow
    elif h.gear == "boots":
        c.rect(hx - 1, hy - 2, hx + 1, hy - 2, h.accent_hi)   # wrist thruster


def draw_fx(c: Canvas, h: Hero, p: Pose) -> None:
    tag, d = p.fx, p.fx_dir
    if tag == "dust":
        y = GROUND
        for i, x in enumerate((-10, -7, -4)):
            c.rect(16 + x * d, y - i * 2, 16 + x * d + 1, y - i * 2 + 1,
                   DUST if i else DUST_HI)
    elif tag == "streak":
        for y, length in ((p.neck[1] + 2, 11), (p.hip[1] - 2, 8), (p.neck[1] + 7, 6)):
            c.rect(16 - length * d, y, 16 - 3 * d, y, h.accent)
        c.rect(16 - 12 * d, p.neck[1] + 4, 16 - 6 * d, p.neck[1] + 4, h.accent_hi)
    elif tag == "sparks":       # wall friction
        for i, y in enumerate((p.neck[1] + 4, p.hip[1], p.hip[1] + 8)):
            c.put(16 + (7 + i % 2) * d, y, STAR_HI if i == 1 else STAR)
    elif tag == "stars":
        cx, cy = p.head
        for dx, dy, col in ((-7, -4, STAR), (7, -5, STAR_HI), (0, -7, STAR)):
            c.put(cx + dx, cy + dy, col)
            c.put(cx + dx + 1, cy + dy, col)
    elif tag == "boost":        # jet flare under the feet
        for foot in (p.foot_b, p.foot_f):
            c.rect(foot[0] - 1, foot[1] + 1, foot[0] + 1, foot[1] + 1, h.accent)


def draw_frame(h: Hero, p: Pose) -> Canvas:
    c = Canvas(W, H)
    draw_cape(c, h, p)
    draw_arms(c, h, p, front=False)   # back arm behind everything
    draw_legs(c, h, p)
    draw_torso(c, h, p)
    draw_shoulders(c, h, p)
    draw_emblem(c, h, p)
    draw_head(c, h, p)
    draw_arms(c, h, p, front=True)    # front arm over the chest
    draw_gear(c, h, p)
    if p.ground:
        c.shadow_below(min(GROUND, int(max(p.foot_b[1], p.foot_f[1])) + 1), "#00000055")
    c.rim_light(h.accent_hi, falloff=shade(h, "mid"))
    c.outline(KEYLINE)
    draw_fx(c, h, p)
    return c


# --------------------------------------------------------------------------- #
# Animations — one pose list per state the machine can be in (DESIGN 4.6)
# --------------------------------------------------------------------------- #
def anim_idle() -> list[Pose]:
    out = []
    for bob in (0, 0, 1, 1):
        out.append(Pose(
            head=(16, 6 + bob), neck=(16, 13 + bob), hip=(16, 30),
            hand_b=(10, 28 + bob), hand_f=(22, 28 + bob),
            foot_b=(12, GROUND), foot_f=(20, GROUND),
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
            foot_b=(16 + fx_b, GROUND - max(0, -fy_b) * 2),
            foot_f=(16 + fx_f, GROUND - max(0, -fy_f) * 2),
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
             hand_b=(7, 34), hand_f=(25, 34), foot_b=(10, GROUND), foot_f=(22, GROUND),
             knee_bend=5, elbow_bend=3, cape=2, cape_lift=-2, fx="dust"),
        Pose(head=(16, 9), neck=(16, 16), hip=(16, 32),
             hand_b=(9, 32), hand_f=(23, 32), foot_b=(11, GROUND), foot_f=(21, GROUND),
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
             hand_b=(9, 24), hand_f=(21, 26), foot_b=(13, GROUND), foot_f=(22, GROUND),
             lean=-3, cape=6, cape_lift=4, knee_bend=4, fx="dust", fx_dir=-1),
        Pose(head=(13, 8), neck=(14, 15), hip=(16, 31),
             hand_b=(8, 25), hand_f=(20, 27), foot_b=(12, GROUND), foot_f=(23, GROUND),
             lean=-3, cape=5, cape_lift=3, knee_bend=5, fx="dust", fx_dir=-1),
    ]


def anim_crouch() -> list[Pose]:
    """Bottom 24px only: this pose has to match the shrunken body shape, and its
    accent band has to sit in rows 24..30 where the crouched head hurtbox is."""
    return [
        Pose(head=(16, 28), neck=(16, 34), hip=(16, 41),
             hand_b=(10, 41), hand_f=(22, 41), foot_b=(11, GROUND), foot_f=(21, GROUND),
             knee_bend=5, elbow_bend=2, cape=2, cape_lift=-3, crouched=True),
        Pose(head=(16, 29), neck=(16, 35), hip=(16, 41),
             hand_b=(10, 42), hand_f=(22, 42), foot_b=(11, GROUND), foot_f=(21, GROUND),
             knee_bend=5, elbow_bend=2, cape=2, cape_lift=-3, crouched=True),
    ]


def anim_slide() -> list[Pose]:
    return [
        Pose(head=(19, 28), neck=(17, 34), hip=(12, 42),
             hand_b=(9, 38), hand_f=(23, 36), foot_b=(14, GROUND), foot_f=(23, 45),
             knee_bend=3, elbow_bend=3, cape=6, cape_lift=-6, crouched=True, fx="dust"),
        Pose(head=(20, 29), neck=(18, 35), hip=(12, 43),
             hand_b=(8, 39), hand_f=(24, 37), foot_b=(13, GROUND), foot_f=(24, 46),
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
    """Clinging with the wall on the RIGHT; the sprite flips for the other side,
    which is why WallSlide points facing into the wall."""
    return [
        Pose(head=(18, 7), neck=(17, 14), hip=(15, 30),
             hand_b=(13, 22), hand_f=(23, 18), foot_b=(13, 44), foot_f=(19, 46),
             lean=2, cape=4, cape_lift=1, knee_bend=4, ground=False, fx="sparks"),
        Pose(head=(18, 8), neck=(17, 15), hip=(15, 31),
             hand_b=(13, 23), hand_f=(23, 20), foot_b=(13, 45), foot_f=(19, GROUND),
             lean=2, cape=3, cape_lift=0, knee_bend=3, ground=False, fx="sparks"),
    ]


def anim_wall_jump() -> list[Pose]:
    """Pushing off: arched away from the wall, trailing leg still extended into
    it. Chains read as a rhythm, so the shape has to be distinct from rise."""
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
    """Momentum is kept while stunned (DESIGN 3.2) but control is not — the pose
    is limp, never braced."""
    return [
        Pose(head=(14, 9), neck=(15, 15), hip=(16, 31),
             hand_b=(9, 33), hand_f=(22, 34), foot_b=(12, GROUND), foot_f=(21, GROUND),
             lean=-2, cape=3, knee_bend=4, elbow_bend=-2, fx="stars"),
        Pose(head=(15, 10), neck=(16, 16), hip=(16, 31),
             hand_b=(10, 34), hand_f=(23, 33), foot_b=(11, GROUND), foot_f=(22, GROUND),
             lean=-1, cape=2, knee_bend=5, elbow_bend=-2, fx="stars"),
    ]


def anim_cast() -> list[Pose]:
    """Ability wind-up and release (M4). Each hero's prop does the talking."""
    return [
        Pose(head=(16, 6), neck=(16, 13), hip=(16, 30),
             hand_b=(12, 26), hand_f=(24, 24), foot_b=(12, GROUND), foot_f=(21, GROUND),
             lean=-1, cape=3, knee_bend=2),
        Pose(head=(17, 6), neck=(17, 13), hip=(16, 30),
             hand_b=(13, 27), hand_f=(26, 22), foot_b=(11, GROUND), foot_f=(22, GROUND),
             lean=2, cape=5, cape_lift=2, knee_bend=2, fx="boost"),
    ]


def anim_pop(h: Hero) -> list[Canvas]:
    """Elimination: confetti burst, no gore (DESIGN 3.3). Built frame by frame
    rather than posed, because the body stops being a body halfway through."""
    base = draw_frame(h, Pose(
        head=(16, 6), neck=(16, 13), hip=(16, 30),
        hand_b=(10, 28), hand_f=(22, 28), foot_b=(12, GROUND), foot_f=(20, GROUND),
        knee_bend=1.5, ground=False))
    frames: list[Canvas] = []

    squash = Canvas(W, H)                      # 0: gather, knees buckling
    for y in range(H):
        for x in range(W):
            p = base.px[y][x]
            if p[3]:
                squash.put(x, min(GROUND, int(30 + (y - 30) * 0.7)), p)
    frames.append(squash)

    flash = Canvas(W, H)                       # 1: blown-out silhouette
    for y in range(H):
        for x in range(W):
            if base.px[y][x][3]:
                edge = not all(base.opaque(x + dx, y + dy)
                               for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)))
                flash.put(x, y - 1, h.accent_hi if edge else "#ffffff")
    frames.append(flash)

    # Confetti ring. Angles are stepped evenly with a fixed jitter rather than
    # sampled randomly — a small random burst clumps, and a clumped burst reads
    # as debris instead of celebration (DESIGN 3.3: pop, no gore).
    cy = 26
    for step, (radius, count, size) in enumerate(((7, 22, 2), (13, 18, 1), (19, 11, 1))):
        f = Canvas(W, H)
        for i in range(count):
            ang = (i / count) * math.tau + (step * 0.7) + (i % 3) * 0.18
            jitter = 0.75 + ((i * 37) % 10) / 20.0
            x = int(16 + math.cos(ang) * radius * jitter)
            y = int(cy + math.sin(ang) * radius * 0.75 * jitter + step * step)
            col = (h.accent, h.accent_hi, "#fff3b0", shade(h, "light"))[i % 4]
            f.rect(x, y, x + size - 1, y, col)
        if step == 0:                          # shards still leaving the body
            for i, (dx, dy) in enumerate(((-3, -6), (3, -7), (-4, 2), (4, 3), (0, -9))):
                f.rect(16 + dx, cy + dy, 16 + dx + 1, cy + dy + 1,
                       h.accent if i % 2 else h.accent_hi)
        frames.append(f)
    return frames


# name -> (frames, fps, loops). Names are the contract with player.gd's states.
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
    """Emit the SpriteFrames resource that AnimatedSprite2D consumes.

    Generated rather than hand-built so the sheets and the resource can never
    disagree about frame counts — but it is a normal .tres afterwards, editable
    in the editor like any other. Re-running this overwrites hand edits.
    """
    meta = {n: (fps, loop) for n, (_p, fps, loop) in ANIMATIONS.items()}
    meta["pop"] = (POP_FPS, False)
    ext, subs, anims = [], [], []
    for i, (name, count) in enumerate(counts.items()):
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
        print(f"{hero.name:9s} {total:3d} frames across {len(counts)} animations")
    print(f"Wrote sheets to {OUT}")
    print(f"Wrote SpriteFrames to {FRAMES_OUT}")
    print("Run `Godot --headless --path . --import` so Godot picks up new PNGs.")


if __name__ == "__main__":
    main()
