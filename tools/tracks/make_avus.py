#!/usr/bin/env python3
"""Generates tools/tracks/src/avus-1959.geojson: the AVUS in Berlin (layout 1951-1967, German GP
1959) - not in bacinger/f1-circuits, so drawn here from its well-known shape (own work):
two long straights of the A115 joined by the fast north curve (Nordkurve, banked in reality) and
a tight south hairpin (Suedkurve) at the end of the east straight, left through two bends.
The real carriageways are only ~40 m apart; for the game they are SEPARATION metres apart (24 m
wide track plus run-off on both).
Orientation and position follow the real road (running NNE-SSW in Berlin-Grunewald).

Usage:  python3 -I tools/tracks/make_avus.py   (then build_track.py avus)
"""

import json
import math
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "tools" / "tracks" / "src" / "avus-1959.geojson"
CENTRE_LAT, CENTRE_LON = 52.476, 13.258
BEARING_DEG = 20.0          # straights run towards NNE
SEPARATION = 300.0          # metres between the straights' centre lines (before the game scale)
NORTH_Y = 4000.0            # end of the straights at the Nordkurve (metres from the south end)
SOUTH_Y = 720.0             # the west straight starts here (after the bends out of the hairpin)
HAIRPIN_Y = 300.0           # the east straight ends in the hairpin here
START_Y = 3300.0            # start/finish line on the west straight, before the Nordkurve


def arc(cx, cy, radius, start_deg, end_deg, step_deg=10.0):
    points = []
    steps = max(int(abs(end_deg - start_deg) / step_deg), 1)
    for k in range(steps + 1):
        a = math.radians(start_deg + (end_deg - start_deg) * k / steps)
        points.append((cx + radius * math.cos(a), cy + radius * math.sin(a)))
    return points


def layout():
    """Clockwise from the start line: north up the west straight, Nordkurve, south down the
    east straight straight into the Suedkurve hairpin (braking in a straight line), then two
    bends on the way out back onto the west straight. x east, y north (metres)."""
    s = SEPARATION
    pts = [(0.0, y) for y in range(int(START_Y), int(NORTH_Y), 100)]
    pts += arc(s / 2, NORTH_Y, s / 2, 180.0, 0.0)[1:]                  # Nordkurve: half circle
    pts += [(s, y) for y in range(int(NORTH_Y) - 100, int(HAIRPIN_Y), -100)]
    pts += arc(s - 70.0, HAIRPIN_Y, 70.0, 0.0, -180.0)                  # Suedkurve hairpin
    pts += [(150.0, HAIRPIN_Y + 90.0), (105.0, HAIRPIN_Y + 190.0), (45.0, HAIRPIN_Y + 290.0), (0.0, SOUTH_Y)]
    pts += [(0.0, y) for y in range(int(SOUTH_Y) + 100, int(START_Y), 100)]
    return pts


def to_lonlat(points):
    b = math.radians(BEARING_DEG)
    k = math.cos(math.radians(CENTRE_LAT))
    cx = sum(p[0] for p in points) / len(points)
    cy = sum(p[1] for p in points) / len(points)
    result = []
    for x, y in points:
        x, y = x - cx, y - cy
        east = x * math.cos(b) + y * math.sin(b)
        north = -x * math.sin(b) + y * math.cos(b)
        result.append([round(CENTRE_LON + east / (111_320.0 * k), 7), round(CENTRE_LAT + north / 110_540.0, 7)])
    result.append(result[0])
    return result


def main():
    coords = to_lonlat(layout())
    data = {"type": "FeatureCollection", "name": "avus-1959", "features": [{"type": "Feature",
            "properties": {"id": "avus-1959", "Location": "Berlin", "Name": "AVUS (1951-1967 layout, own drawing)"},
            "geometry": {"type": "LineString", "coordinates": coords}}]}
    OUT.write_text(json.dumps(data, indent=1) + "\n", encoding="utf-8")
    print(f"{OUT.name}: {len(coords)} points")


if __name__ == "__main__":
    main()
