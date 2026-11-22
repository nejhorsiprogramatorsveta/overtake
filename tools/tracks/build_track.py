#!/usr/bin/env python3
"""Builds the game's track files from real circuit shapes (dev tool, not shipped).

Source: GeoJSON centre lines from https://github.com/bacinger/f1-circuits (MIT), stored in
tools/tracks/src/. Settings per track live in tools/tracks/tracks.json:
  scale        shrinks the real layout so a lap takes the target time (PLAN.md B)
  width        asphalt width in metres (wide on purpose, for overtaking)
  reverse      flip the driving direction if the source runs backwards
  start_shift  moves the start/finish line along the lap (metres, after scaling)
  widen_hairpins  open hairpins too tight for the scale by spreading their legs (widen_min_gap:
               closest allowed distance to another part of the lap, metres)
  min_radius   accept tighter corners than MIN_RADIUS (e.g. a spiral that cannot be widened)
  pit_outside  put the pit lane on the outside of the lap (default: inside)
  pit_entry, pit_exit  where the pit lane leaves / rejoins the track, as a share of the lap
               (0..1 from the start line; scale-independent), e.g. like the real circuit

Output: data/tracks/<id>.json with the closed centre line in metres (x east, y south = Godot's
y-down, north-up camera), resampled every STEP metres; point 0 is the start/finish line; plus
the racing line as a lateral offset per point (K1999: smooth arcs of the largest radius).

Usage:  python3 -I tools/tracks/build_track.py [track_id ...] [--preview DIR]
"""

import json
import math
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SRC_DIR = ROOT / "tools" / "tracks" / "src"
CONFIG = ROOT / "tools" / "tracks" / "tracks.json"
OUT_DIR = ROOT / "data" / "tracks"
STEP = 4.0             # final spacing of centre-line points (m)
DENSE_STEP = 1.0       # spacing used while smoothing (m)
SMOOTH_PASSES = 6      # light global smoothing: removes GPS kinks
MIN_RADIUS = 17.0      # tighter corners are opened up locally (inner asphalt edge must not fold)
EARTH_M_PER_DEG_LAT = 110_540.0
EARTH_M_PER_DEG_LON = 111_320.0


def load_lonlat(path):
    data = json.loads(path.read_text(encoding="utf-8"))
    coords = data["features"][0]["geometry"]["coordinates"]
    if coords[0] == coords[-1]:
        coords = coords[:-1]
    return coords


def project(coords):
    lat0 = sum(c[1] for c in coords) / len(coords)
    lon0 = sum(c[0] for c in coords) / len(coords)
    k = math.cos(math.radians(lat0))
    return [((lon - lon0) * EARTH_M_PER_DEG_LON * k, -(lat - lat0) * EARTH_M_PER_DEG_LAT) for lon, lat in coords]


def catmull_rom_closed(points, samples_per_segment=16):
    """Centripetal Catmull-Rom through all points of a closed loop."""
    n = len(points)
    out = []
    for i in range(n):
        p0, p1, p2, p3 = points[i - 1], points[i], points[(i + 1) % n], points[(i + 2) % n]

        def tj(ti, a, b):
            return ti + max(math.dist(a, b), 1e-6) ** 0.5

        t0 = 0.0
        t1 = tj(t0, p0, p1)
        t2 = tj(t1, p1, p2)
        t3 = tj(t2, p2, p3)
        for s in range(samples_per_segment):
            t = t1 + (t2 - t1) * s / samples_per_segment
            a1 = _lerp_t(p0, p1, t0, t1, t)
            a2 = _lerp_t(p1, p2, t1, t2, t)
            a3 = _lerp_t(p2, p3, t2, t3, t)
            b1 = _lerp_t(a1, a2, t0, t2, t)
            b2 = _lerp_t(a2, a3, t1, t3, t)
            out.append(_lerp_t(b1, b2, t1, t2, t))
    return out


def _lerp_t(a, b, ta, tb, t):
    w = (t - ta) / (tb - ta)
    return (a[0] + (b[0] - a[0]) * w, a[1] + (b[1] - a[1]) * w)


def resample_closed(points, step):
    """Equal spacing along a closed polyline."""
    n = len(points)
    lengths = [math.dist(points[i], points[(i + 1) % n]) for i in range(n)]
    total = sum(lengths)
    count = max(8, round(total / step))
    spacing = total / count
    out = []
    seg, seg_pos = 0, 0.0
    for k in range(count):
        target = k * spacing
        while seg_pos + lengths[seg] < target:
            seg_pos += lengths[seg]
            seg = (seg + 1) % n
        w = (target - seg_pos) / lengths[seg] if lengths[seg] > 0 else 0.0
        a, b = points[seg], points[(seg + 1) % n]
        out.append((a[0] + (b[0] - a[0]) * w, a[1] + (b[1] - a[1]) * w))
    return out


def smooth(points, passes, mask=None):
    n = len(points)
    for _ in range(passes):
        new = []
        for i in range(n):
            if mask is not None and not mask[i]:
                new.append(points[i])
                continue
            a, b, c = points[i - 1], points[i], points[(i + 1) % n]
            new.append(((a[0] + 2 * b[0] + c[0]) / 4, (a[1] + 2 * b[1] + c[1]) / 4))
        points = new
    return points


def radius_at(points, i, span):
    """Radius of the circle through points i-span, i, i+span (inf on a straight)."""
    n = len(points)
    a, b, c = points[(i - span) % n], points[i], points[(i + span) % n]
    ab, bc, ca = math.dist(a, b), math.dist(b, c), math.dist(c, a)
    cross = abs((b[0] - a[0]) * (c[1] - a[1]) - (b[1] - a[1]) * (c[0] - a[0]))
    return math.inf if cross < 1e-9 else ab * bc * ca / (2 * cross)


def open_tight_corners(points, min_radius, span):
    """Smooths only the too-tight parts until every radius (measured over 2*span points) is >= min_radius."""
    n = len(points)
    for _ in range(3000):
        tight = [radius_at(points, i, span) < min_radius for i in range(n)]
        if not any(tight):
            return points
        reach = span * 2
        grown = [any(tight[(i + k) % n] for k in range(-reach, reach + 1)) for i in range(n)]
        points = smooth(points, 1, grown)
    print("  WARNING: could not open all tight corners")
    return points


def widen_hairpins(points, min_radius, span, step, min_gap):
    """Opens hairpins that smoothing cannot (it only shortens them): the region around the
    tightest point is shifted towards the outside of the bend with a smooth fall-off, so the
    two legs spread and the arc grows. A shift that would bring the track closer than min_gap
    metres to another part of itself (e.g. inside a spiral) is not used; that corner stays."""
    skipped = []
    for _ in range(300):
        n = len(points)
        radii = [radius_at(points, i, span) for i in range(n)]
        candidates = [i for i in range(n) if radii[i] < min_radius
                      and all(min((i - s) % n, (s - i) % n) > 40 for s in skipped)]
        if not candidates:
            return points
        i0 = min(candidates, key=lambda i: radii[i])
        r = radii[i0]
        a, p, c = points[(i0 - span) % n], points[i0], points[(i0 + span) % n]
        turn = (p[0] - a[0]) * (c[1] - a[1]) - (p[1] - a[1]) * (c[0] - a[0])
        side = -1.0 if turn > 0 else 1.0  # away from the centre of the bend
        shift = min((min_radius + 1.0 - r) * 0.5 + 0.5, 4.0)
        window = int((r * 4 + 40) / step)
        moved = list(points)
        for k in range(-window, window + 1):
            j = (i0 + k) % n
            weight = 0.5 * (1 + math.cos(math.pi * k / window))
            prev, nxt = points[j - 1], points[(j + 1) % n]
            tx, ty = nxt[0] - prev[0], nxt[1] - prev[1]
            length = math.hypot(tx, ty) or 1.0
            moved[j] = (points[j][0] - ty / length * side * shift * weight,
                        points[j][1] + tx / length * side * shift * weight)
        if _local_clearance(moved, i0 - window, i0 + window, 120) < min_gap:
            skipped.append(i0)
            continue
        points = resample_closed(moved, step)
    return points


def _local_clearance(points, lo, hi, skip_m):
    """Closest distance from points lo..hi to parts of the lap more than skip_m points away."""
    n = len(points)
    best = math.inf
    for k in range(lo, hi + 1, 2):
        p = points[k % n]
        for j in range(0, n, 2):
            if min((j - k) % n, (k - j) % n) > skip_m:
                best = min(best, math.dist(p, points[j]))
    return best


def signed_area(points):
    return sum(points[i - 1][0] * points[i][1] - points[i][0] * points[i - 1][1] for i in range(len(points))) / 2


def min_clearance(points, skip_m):
    """Smallest distance between two parts of the lap that are more than skip_m apart along it."""
    n = len(points)
    skip = int(skip_m / STEP)
    best = math.inf
    for i in range(0, n, 2):
        for j in range(i + skip, min(n, n + i - skip), 2):
            best = min(best, math.dist(points[i], points[j]))
    return best


def build(track_id, cfg):
    pts = project(load_lonlat(SRC_DIR / cfg["source"]))
    if cfg.get("reverse"):
        pts.reverse()
    pts = [(x * cfg["scale"], y * cfg["scale"]) for x, y in pts]
    pts = resample_closed(catmull_rom_closed(pts), DENSE_STEP)
    pts = smooth(pts, SMOOTH_PASSES)
    if cfg.get("widen_hairpins"):
        pts = widen_hairpins(pts, MIN_RADIUS, round(8.0 / DENSE_STEP), DENSE_STEP, cfg.get("widen_min_gap", 30.0))
    pts = open_tight_corners(pts, cfg.get("min_radius", MIN_RADIUS), round(8.0 / DENSE_STEP))
    pts = resample_closed(pts, STEP)
    shift = round(cfg.get("start_shift", 0.0) / STEP)
    pts = pts[shift:] + pts[:shift]
    # Centre the layout on the origin.
    cx = sum(p[0] for p in pts) / len(pts)
    cy = sum(p[1] for p in pts) / len(pts)
    pts = [(x - cx, y - cy) for x, y in pts]
    length = sum(math.dist(pts[i], pts[(i + 1) % len(pts)]) for i in range(len(pts)))
    n = len(pts)
    track = {
        "id": track_id,
        "name_key": cfg["name_key"],
        "source": "bacinger/f1-circuits " + cfg["source"] + " (MIT)",
        "scale": cfg["scale"],
        "width": cfg["width"],
        "length": round(length, 1),
        "sectors": [n // 3, 2 * n // 3],
        "pit_entry": cfg.get("pit_entry", -1.0),
        "pit_exit": cfg.get("pit_exit", -1.0),
        "pit_outside": cfg.get("pit_outside", False),
        "points": [[round(x, 2), round(y, 2)] for x, y in pts],
        "racing_line": [round(v, 2) for v in racing_line(pts, cfg["width"] * 0.5)],
    }
    stats = {
        "points": n,
        "length_m": round(length),
        "min_radius_m": round(min(radius_at(pts, i, 2) for i in range(n)), 1),
        "clockwise": signed_area(pts) > 0,  # y points down, so positive area = clockwise on screen
        "min_clearance_m": round(min_clearance(pts, 120.0), 1),
    }
    return track, stats


def racing_line(pts, half_width, margin=2.0):
    """Racing line as lateral offsets (right = +) from the centre line: the K1999 method
    (Remi Coulom): every point is moved sideways so that the curvature through it equals the
    distance-weighted average of its neighbours' curvatures, within the track edges (minus
    margin). The result is a line of smooth, near-constant-radius arcs - outside, apex, outside -
    with the largest possible radius in every corner. Coarse to fine: every 64th point first,
    the points in between are filled by interpolating the curvature, then every 32nd, ... 1."""
    n = len(pts)
    normals = []
    for i in range(n):
        ax, ay = pts[i - 1]
        bx, by = pts[(i + 1) % n]
        tx, ty = bx - ax, by - ay
        length = math.hypot(tx, ty) or 1.0
        normals.append((-ty / length, tx / length))
    limit = half_width - margin
    lane = [0.0] * n

    def pos(i):
        return (pts[i][0] + normals[i][0] * lane[i], pts[i][1] + normals[i][1] * lane[i])

    def adjust(prev, i, nxt, target):
        # Put point i on the chord prev-next, then move it sideways to reach the target curvature.
        p, r = pos(prev), pos(nxt)
        c, nv = pts[i], normals[i]
        dx, dy = r[0] - p[0], r[1] - p[1]
        den = nv[0] * dy - nv[1] * dx
        if abs(den) > 1e-9:
            lane[i] = ((p[0] - c[0]) * dy - (p[1] - c[1]) * dx) / den
        q = pos(i)
        eps = 0.01
        slope = curvature_through(p, (q[0] + nv[0] * eps, q[1] + nv[1] * eps), r) / eps
        if abs(slope) > 1e-9:
            lane[i] += target / slope
        lane[i] = max(-limit, min(limit, lane[i]))

    def fill(lo, hi, a, span, ra, rb):
        if hi - lo <= 1:
            return
        mid = lo + (hi - lo) // 2
        adjust(lo % n, mid % n, hi % n, ra + (rb - ra) * (mid - a) / span)
        fill(lo, mid, a, span, ra, rb)
        fill(mid, hi, a, span, ra, rb)

    step = 64
    while step >= 1:
        idx = list(range(0, n, step))
        m = len(idx)
        for _ in range(int(100 * math.sqrt(step))):
            for k in range(m):
                i, prev, nxt = idx[k], idx[(k - 1) % m], idx[(k + 1) % m]
                r0 = curvature_through(pos(idx[(k - 2) % m]), pos(prev), pos(i))
                r1 = curvature_through(pos(i), pos(nxt), pos(idx[(k + 2) % m]))
                lp, ln = math.dist(pos(prev), pos(i)), math.dist(pos(i), pos(nxt))
                adjust(prev, i, nxt, (ln * r0 + lp * r1) / (ln + lp))
        if step > 1:
            for k in range(m):
                a, b = idx[k], idx[(k + 1) % m]
                span = (b - a) % n
                ra = curvature_through(pos(idx[(k - 1) % m]), pos(a), pos(b))
                rb = curvature_through(pos(a), pos(b), pos(idx[(k + 2) % m]))
                fill(a, a + span, a, span, ra, rb)
        step //= 2
    return lane


def curvature_through(p, q, r):
    """Signed curvature (1/m) of the circle through p, q, r; positive = right-hand turn (y down)."""
    x1, y1 = r[0] - q[0], r[1] - q[1]
    x2, y2 = p[0] - q[0], p[1] - q[1]
    x3, y3 = r[0] - p[0], r[1] - p[1]
    product = math.sqrt((x1 * x1 + y1 * y1) * (x2 * x2 + y2 * y2) * (x3 * x3 + y3 * y3))
    return 2.0 * (x1 * y2 - x2 * y1) / product if product > 1e-12 else 0.0


def preview(track, path):
    from PIL import Image, ImageDraw
    pts = track["points"]
    xs, ys = [p[0] for p in pts], [p[1] for p in pts]
    margin = 60
    size = 900
    k = (size - 2 * margin) / max(max(xs) - min(xs), max(ys) - min(ys))
    tp = [((x - min(xs)) * k + margin, (y - min(ys)) * k + margin) for x, y in pts]
    img = Image.new("RGB", (size, size), (40, 90, 40))
    draw = ImageDraw.Draw(img)
    draw.line(tp + [tp[0]], fill=(60, 60, 66), width=max(2, int(track["width"] * k)), joint="curve")
    draw.line(tp + [tp[0]], fill=(230, 230, 230), width=1)
    rl = []
    for i, (x, y) in enumerate(pts):
        a, b = pts[i - 1], pts[(i + 1) % len(pts)]
        tx, ty = b[0] - a[0], b[1] - a[1]
        length = math.hypot(tx, ty) or 1.0
        off = track["racing_line"][i]
        rl.append(((x - ty / length * off - min(xs)) * k + margin, (y + tx / length * off - min(ys)) * k + margin))
    draw.line(rl + [rl[0]], fill=(255, 220, 0), width=2)
    for idx, color in [(0, (255, 255, 255))] + [(s, (255, 200, 0)) for s in track["sectors"]]:
        x, y = tp[idx]
        draw.ellipse((x - 7, y - 7, x + 7, y + 7), fill=color)
    x0, y0 = tp[0]
    x1, y1 = tp[6]
    draw.line((x0, y0, x1, y1), fill=(220, 30, 30), width=5)  # driving direction from the start
    img.save(path)


def main(argv):
    preview_dir = None
    if "--preview" in argv:
        i = argv.index("--preview")
        preview_dir = Path(argv[i + 1])
        argv = argv[:i] + argv[i + 2:]
    config = json.loads(CONFIG.read_text(encoding="utf-8"))
    ids = argv or list(config)
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    for track_id in ids:
        track, stats = build(track_id, config[track_id])
        (OUT_DIR / f"{track_id}.json").write_text(json.dumps(track, separators=(",", ":")) + "\n", encoding="utf-8")
        print(track_id, stats)
        if stats["min_clearance_m"] < track["width"] + 10:
            print(f"  WARNING: two parts of {track_id} are only {stats['min_clearance_m']} m apart")
        if preview_dir:
            preview(track, preview_dir / f"{track_id}.png")


if __name__ == "__main__":
    main(sys.argv[1:])
