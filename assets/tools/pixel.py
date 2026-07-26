"""Tiny dependency-free pixel canvas for Overstomp's art generators.

Stdlib only — no Pillow. The art pipeline should run on a clean checkout with
nothing but Python, because an asset you cannot regenerate is an asset you
cannot iterate on.

Colors are "#rgb", "#rrggbb", or "#rrggbbaa" strings, or None for "leave alone".
Origin is top-left, +y down, matching the sprite sheets.
"""
from __future__ import annotations

import struct
import zlib
from pathlib import Path

Color = tuple[int, int, int, int]


def rgba(c: str | Color | None) -> Color | None:
    if c is None:
        return None
    if not isinstance(c, str):
        return c
    s = c.lstrip("#")
    if len(s) == 3:
        s = "".join(ch * 2 for ch in s)
    if len(s) == 6:
        s += "ff"
    return (int(s[0:2], 16), int(s[2:4], 16), int(s[4:6], 16), int(s[6:8], 16))


def mix(a: str | Color, b: str | Color, t: float) -> Color:
    """Blend two colors; t=0 is a, t=1 is b. Used for value ramps."""
    ca, cb = rgba(a), rgba(b)
    return tuple(int(round(ca[i] + (cb[i] - ca[i]) * t)) for i in range(4))


class Canvas:
    def __init__(self, w: int, h: int, fill: str | Color | None = None):
        self.w = w
        self.h = h
        base = rgba(fill) if fill else (0, 0, 0, 0)
        self.px: list[list[Color]] = [[base for _ in range(w)] for _ in range(h)]

    #region primitives
    def put(self, x: int, y: int, c: str | Color | None) -> None:
        if c is None:
            return
        x, y = int(x), int(y)
        if 0 <= x < self.w and 0 <= y < self.h:
            col = rgba(c)
            if col[3] == 255:
                self.px[y][x] = col
            elif col[3] > 0:  # simple source-over, enough for soft accents
                dst = self.px[y][x]
                a = col[3] / 255.0
                out_a = col[3] + int(dst[3] * (1 - a))
                self.px[y][x] = (
                    int(col[0] * a + dst[0] * (1 - a)),
                    int(col[1] * a + dst[1] * (1 - a)),
                    int(col[2] * a + dst[2] * (1 - a)),
                    min(255, out_a),
                )

    def get(self, x: int, y: int) -> Color:
        if 0 <= x < self.w and 0 <= y < self.h:
            return self.px[y][x]
        return (0, 0, 0, 0)

    def opaque(self, x: int, y: int) -> bool:
        return self.get(x, y)[3] > 0

    def rect(self, x0: int, y0: int, x1: int, y1: int, c: str | Color | None) -> None:
        """Inclusive on both corners — pixel art counts pixels, not edges."""
        if x1 < x0:
            x0, x1 = x1, x0
        if y1 < y0:
            y0, y1 = y1, y0
        for y in range(int(y0), int(y1) + 1):
            for x in range(int(x0), int(x1) + 1):
                self.put(x, y, c)

    def line(self, p0, p1, c) -> None:
        x0, y0 = int(round(p0[0])), int(round(p0[1]))
        x1, y1 = int(round(p1[0])), int(round(p1[1]))
        dx, dy = abs(x1 - x0), -abs(y1 - y0)
        sx = 1 if x0 < x1 else -1
        sy = 1 if y0 < y1 else -1
        err = dx + dy
        while True:
            self.put(x0, y0, c)
            if x0 == x1 and y0 == y1:
                return
            e2 = 2 * err
            if e2 >= dy:
                err += dy
                x0 += sx
            if e2 <= dx:
                err += dx
                y0 += sy

    def limb(self, p0, p1, width: int, c) -> None:
        """Thick line with a square brush — the workhorse for arms and legs."""
        r0 = (width - 1) // 2
        r1 = width // 2
        x0, y0 = int(round(p0[0])), int(round(p0[1]))
        x1, y1 = int(round(p1[0])), int(round(p1[1]))
        dx, dy = abs(x1 - x0), -abs(y1 - y0)
        sx = 1 if x0 < x1 else -1
        sy = 1 if y0 < y1 else -1
        err = dx + dy
        while True:
            self.rect(x0 - r0, y0 - r0, x0 + r1, y0 + r1, c)
            if x0 == x1 and y0 == y1:
                return
            e2 = 2 * err
            if e2 >= dy:
                err += dy
                x0 += sx
            if e2 <= dx:
                err += dx
                y0 += sy

    def poly(self, points, c) -> None:
        """Scanline fill. Points are (x, y) tuples, implicitly closed."""
        if len(points) < 3:
            return
        ys = [p[1] for p in points]
        for y in range(int(round(min(ys))), int(round(max(ys))) + 1):
            spans = []
            for i in range(len(points)):
                ax, ay = points[i]
                bx, by = points[(i + 1) % len(points)]
                if ay == by:
                    continue
                if min(ay, by) <= y < max(ay, by):
                    t = (y - ay) / (by - ay)
                    spans.append(ax + (bx - ax) * t)
            spans.sort()
            for i in range(0, len(spans) - 1, 2):
                self.rect(int(round(spans[i])), y, int(round(spans[i + 1])), y, c)

    def ellipse(self, cx, cy, rx, ry, c, filled: bool = True) -> None:
        for y in range(int(cy - ry), int(cy + ry) + 1):
            for x in range(int(cx - rx), int(cx + rx) + 1):
                dx = (x - cx) / max(rx, 0.001)
                dy = (y - cy) / max(ry, 0.001)
                d = dx * dx + dy * dy
                if d <= 1.0 and (filled or d >= 0.35):
                    self.put(x, y, c)

    def blit(self, other: "Canvas", ox: int, oy: int) -> None:
        for y in range(other.h):
            for x in range(other.w):
                p = other.px[y][x]
                if p[3] > 0:
                    self.put(x + ox, y + oy, p)
    #endregion

    #region passes
    def rim_light(self, c, from_right: bool = True, rows=None, falloff=None) -> None:
        """Light the first opaque pixel on the key-light side of every row.

        The dusk key light is up-right (STYLE_GUIDE), and this one pass is what
        sells the Arcane read at this size — a silhouette with a bright edge
        stays legible against dark stages during fast movement.

        `falloff` fades the rim toward that color further down the sprite. Without
        it the edge is a uniform bright line from scalp to boot, which reads as an
        outline rather than as light coming from somewhere.
        """
        rows = rows if rows is not None else range(self.h)
        for y in rows:
            xs = range(self.w - 1, -1, -1) if from_right else range(self.w)
            col = c if falloff is None else mix(c, falloff, min(1.0, y / self.h * 0.9))
            for x in xs:
                if self.opaque(x, y):
                    self.put(x, y, col)
                    break

    def outline(self, c) -> None:
        """1px dark keyline around the silhouette, drawn outside existing pixels."""
        edges = []
        for y in range(self.h):
            for x in range(self.w):
                if self.opaque(x, y):
                    continue
                if any(self.opaque(x + dx, y + dy) for dx, dy in
                       ((1, 0), (-1, 0), (0, 1), (0, -1))):
                    edges.append((x, y))
        for x, y in edges:
            self.put(x, y, c)

    def shadow_below(self, y_row: int, c) -> None:
        """Contact shadow under the feet, for grounded poses."""
        xs = [x for x in range(self.w) if self.opaque(x, y_row - 1)]
        if xs:
            self.rect(min(xs), y_row, max(xs), y_row, c)
    #endregion

    def save(self, path: str | Path) -> None:
        path = Path(path)
        path.parent.mkdir(parents=True, exist_ok=True)
        raw = b"".join(
            b"\x00" + bytes(v for p in row for v in p) for row in self.px
        )

        def chunk(tag: bytes, data: bytes) -> bytes:
            return (struct.pack(">I", len(data)) + tag + data
                    + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF))

        png = b"\x89PNG\r\n\x1a\n"
        png += chunk(b"IHDR", struct.pack(">IIBBBBB", self.w, self.h, 8, 6, 0, 0, 0))
        png += chunk(b"IDAT", zlib.compress(raw, 9))
        png += chunk(b"IEND", b"")
        path.write_bytes(png)


def strip(frames: list[Canvas]) -> Canvas:
    """Lay frames left-to-right into one sheet (32px columns, per STYLE_GUIDE)."""
    if not frames:
        raise ValueError("empty strip")
    w, h = frames[0].w, frames[0].h
    sheet = Canvas(w * len(frames), h)
    for i, f in enumerate(frames):
        sheet.blit(f, i * w, 0)
    return sheet
