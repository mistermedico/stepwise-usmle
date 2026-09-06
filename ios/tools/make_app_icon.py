#!/usr/bin/env python3
"""Renders the Strainwave app icon.

Deliberately dependency-free: the icon is drawn from signed-distance fields and
encoded with `zlib` alone, so it can be regenerated on any machine (and in CI)
without Pillow, a design tool, or a binary checked into the repository.

    python3 ios/tools/make_app_icon.py

Writes a 1024x1024 opaque PNG into the asset catalog. App Store icons must not
carry an alpha channel, so the output is RGB.
"""

import math
import os
import struct
import zlib

SIZE = 1024
OUTPUT = os.path.join(
    os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
    "Strainwave", "Sources", "Resources", "Assets.xcassets",
    "AppIcon.appiconset", "icon-1024.png",
)

# Palette, matching Theme.Palette in the app.
BACKGROUND_TOP = (0x14, 0x1D, 0x2B)
BACKGROUND_BOTTOM = (0x0B, 0x11, 0x1A)
CORE = (0xCB, 0x50, 0xEE)
CORE_INNER = (0xE0, 0x80, 0xFF)
ARM = (0xD8, 0x6B, 0xF0)
GLOW = (0xB0, 0x2F, 0xD6)


def clamp(value, low=0.0, high=1.0):
    return max(low, min(high, value))


def smoothstep(edge0, edge1, x):
    if edge0 == edge1:
        return 0.0 if x < edge0 else 1.0
    t = clamp((x - edge0) / (edge1 - edge0))
    return t * t * (3 - 2 * t)


def mix(a, b, t):
    return tuple(a[i] + (b[i] - a[i]) * t for i in range(3))


def hexagon_distance(px, py, radius):
    """Signed distance to a flat-top-free (pointy-top) regular hexagon."""
    # Fold into one sextant, then measure against a single edge.
    angle = math.atan2(py, px) + math.pi / 2
    sector = math.pi / 3
    folded = abs(((angle % sector) + sector) % sector - sector / 2)
    length = math.hypot(px, py)
    return length * math.cos(folded) - radius * math.cos(sector / 2)


def segment_distance(px, py, ax, ay, bx, by):
    """Distance from a point to a line segment."""
    vx, vy = bx - ax, by - ay
    wx, wy = px - ax, py - ay
    denominator = vx * vx + vy * vy
    t = 0.0 if denominator == 0 else clamp((wx * vx + wy * vy) / denominator)
    return math.hypot(wx - vx * t, wy - vy * t)


def build_arms():
    """Six arms: alternating spikes and lobes, echoing the in-app glyph."""
    arms = []
    for index in range(6):
        angle = index * math.pi / 3 - math.pi / 2 + math.pi / 6
        inner = 0.185
        outer = 0.315 if index % 2 == 0 else 0.285
        arms.append({
            "ax": math.cos(angle) * inner,
            "ay": math.sin(angle) * inner,
            "bx": math.cos(angle) * outer,
            "by": math.sin(angle) * outer,
            "width": 0.019,
            "lobe": None if index % 2 == 0 else (
                math.cos(angle) * outer, math.sin(angle) * outer, 0.038
            ),
            "tip": (
                (math.cos(angle) * (outer + 0.055), math.sin(angle) * (outer + 0.055))
                if index % 2 == 0 else None
            ),
        })
    return arms


def render():
    arms = build_arms()
    core_radius = 0.178
    rows = []
    aa = 1.6 / SIZE  # roughly one and a half pixels of feathering

    for y in range(SIZE):
        row = bytearray()
        ny = (y + 0.5) / SIZE - 0.5
        vertical = (y + 0.5) / SIZE
        for x in range(SIZE):
            nx = (x + 0.5) / SIZE - 0.5

            colour = mix(BACKGROUND_TOP, BACKGROUND_BOTTOM, vertical)

            # Soft halo behind everything.
            halo = math.hypot(nx, ny)
            colour = mix(colour, GLOW, 0.22 * (1 - smoothstep(0.10, 0.44, halo)))

            # Arms.
            coverage = 0.0
            for arm in arms:
                distance = segment_distance(nx, ny, arm["ax"], arm["ay"], arm["bx"], arm["by"])
                coverage = max(coverage, 1 - smoothstep(arm["width"], arm["width"] + aa, distance))
                if arm["lobe"]:
                    lx, ly, lr = arm["lobe"]
                    lobe = math.hypot(nx - lx, ny - ly)
                    coverage = max(coverage, 1 - smoothstep(lr, lr + aa, lobe))
                if arm["tip"]:
                    tx, ty = arm["tip"]
                    spike = segment_distance(nx, ny, arm["bx"], arm["by"], tx, ty)
                    taper = 0.014 * (1 - smoothstep(0.0, 0.06, math.hypot(nx - arm["bx"], ny - arm["by"])))
                    coverage = max(coverage, 1 - smoothstep(taper, taper + aa, spike))
            colour = mix(colour, ARM, coverage)

            # Core hexagon, drawn last so arms tuck underneath it.
            core = hexagon_distance(nx, ny, core_radius)
            colour = mix(colour, CORE, 1 - smoothstep(0.0, aa, core))

            inner = hexagon_distance(nx, ny, core_radius * 0.52)
            colour = mix(colour, CORE_INNER, 0.85 * (1 - smoothstep(0.0, aa, inner)))

            row += bytes(int(round(clamp(channel, 0, 255))) for channel in colour)
        rows.append(bytes(row))
    return rows


def write_png(path, rows):
    raw = b"".join(b"\x00" + row for row in rows)

    def chunk(tag, payload):
        data = tag + payload
        return struct.pack(">I", len(payload)) + data + struct.pack(">I", zlib.crc32(data))

    header = struct.pack(">IIBBBBB", SIZE, SIZE, 8, 2, 0, 0, 0)  # 8-bit RGB, no alpha
    png = (
        b"\x89PNG\r\n\x1a\n"
        + chunk(b"IHDR", header)
        + chunk(b"IDAT", zlib.compress(raw, 9))
        + chunk(b"IEND", b"")
    )
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "wb") as handle:
        handle.write(png)


if __name__ == "__main__":
    write_png(OUTPUT, render())
    print("wrote", OUTPUT, os.path.getsize(OUTPUT), "bytes")
