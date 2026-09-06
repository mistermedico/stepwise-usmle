#!/usr/bin/env python3
"""
Generates every puzzle in nonogram-app/Nonogram/Resources/Levels/.

Approach: each icon is a small silhouette defined once as a *resolution-independent*
predicate over the unit square [0,1]x[0,1] (circles/ellipses/triangles/line-segments,
composed with union/diff/intersect). Rendering the same icon at different grid sizes
(5..20) is just sampling that predicate at more cells - this is what gives us the
5x5 -> 20x20 size progression without hand-drawing a separate bitmap per size.

Before a candidate puzzle is accepted, its row/column clues are run back through a
from-scratch Nonogram solver (constraint propagation + bounded backtracking) to prove
they have EXACTLY ONE solution and that it equals the intended grid. This mirrors
NonogramSolver.swift (see ../Nonogram/Engine/NonogramSolver.swift) - that Swift file
re-verifies the same guarantee at test time from the shipped JSON.
"""
import json
import math
import random
import shutil
from pathlib import Path

RNG_SEED = 42
ROOT = Path(__file__).resolve().parent.parent
LEVELS_DIR = ROOT / "Nonogram" / "Resources" / "Levels"

# ---------------------------------------------------------------------------
# Geometry primitives: each returns a predicate fn(u, v) -> bool over [0,1]^2.
# ---------------------------------------------------------------------------

def circle(cx, cy, r):
    r2 = r * r
    return lambda u, v: (u - cx) ** 2 + (v - cy) ** 2 <= r2


def ellipse(cx, cy, rx, ry):
    return lambda u, v: ((u - cx) / rx) ** 2 + ((v - cy) / ry) ** 2 <= 1


def rect(x0, y0, x1, y1):
    return lambda u, v: x0 <= u <= x1 and y0 <= v <= y1


def ring(cx, cy, r_in, r_out):
    return lambda u, v: r_in ** 2 <= (u - cx) ** 2 + (v - cy) ** 2 <= r_out ** 2


def _sign(p1, p2, p3):
    return (p1[0] - p3[0]) * (p2[1] - p3[1]) - (p2[0] - p3[0]) * (p1[1] - p3[1])


def tri(a, b, c):
    def inside(u, v):
        p = (u, v)
        d1, d2, d3 = _sign(p, a, b), _sign(p, b, c), _sign(p, c, a)
        has_neg = d1 < 0 or d2 < 0 or d3 < 0
        has_pos = d1 > 0 or d2 > 0 or d3 > 0
        return not (has_neg and has_pos)
    return inside


def seg(a, b, thickness):
    ax, ay = a
    bx, by = b
    dx, dy = bx - ax, by - ay
    length2 = dx * dx + dy * dy
    half = thickness / 2

    def inside(u, v):
        if length2 == 0:
            dist = math.hypot(u - ax, v - ay)
        else:
            t = ((u - ax) * dx + (v - ay) * dy) / length2
            t = max(0.0, min(1.0, t))
            cx, cy = ax + t * dx, ay + t * dy
            dist = math.hypot(u - cx, v - cy)
        return dist <= half
    return inside


def union(*preds):
    return lambda u, v: any(p(u, v) for p in preds)


def inter(*preds):
    return lambda u, v: all(p(u, v) for p in preds)


def diff(base, *subtract):
    return lambda u, v: base(u, v) and not any(s(u, v) for s in subtract)


# ---------------------------------------------------------------------------
# Icon registry: name -> (predicate, English title, Hebrew title)
# ---------------------------------------------------------------------------

ICONS = {}
TITLES = {}


def icon(key, en, he, shape):
    ICONS[key] = shape
    TITLES[key] = (en, he)


# --- animals ---------------------------------------------------------------
icon("cat", "Cat", "חתול", union(
    ellipse(.5, .62, .28, .26), circle(.5, .32, .18),
    tri((.34, .22), (.4, .05), (.46, .22)), tri((.54, .22), (.6, .05), (.66, .22)),
    seg((.78, .74), (.93, .55), .05)))
icon("dog", "Dog", "כלב", union(
    ellipse(.52, .62, .3, .24), circle(.28, .38, .16),
    rect(.12, .24, .26, .46), rect(.14, .36, .32, .46),
    seg((.78, .7), (.93, .5), .06)))
icon("fish", "Fish", "דג", union(
    ellipse(.42, .5, .28, .18), tri((.7, .5), (.92, .32), (.92, .68)), circle(.24, .46, .04)))
icon("bird", "Bird", "ציפור", union(
    ellipse(.46, .55, .22, .18), circle(.7, .4, .12), tri((.8, .38), (.94, .42), (.8, .46)),
    tri((.28, .5), (.48, .35), (.48, .65)), seg((.48, .72), (.42, .9), .03), seg((.5, .72), (.58, .9), .03)))
icon("rabbit", "Rabbit", "ארנב", union(
    circle(.5, .68, .22), circle(.5, .4, .16), rect(.38, .05, .46, .32), rect(.54, .05, .62, .32)))
icon("turtle", "Turtle", "צב", union(
    ellipse(.52, .52, .3, .22), circle(.16, .5, .09), tri((.82, .5), (.93, .44), (.93, .56)),
    rect(.28, .72, .4, .84), rect(.62, .72, .74, .84)))
icon("owl", "Owl", "ינשוף", union(
    ellipse(.5, .55, .26, .28), circle(.38, .42, .09), circle(.62, .42, .09),
    tri((.46, .5), (.54, .5), (.5, .6)), tri((.32, .18), (.38, .05), (.42, .2)), tri((.58, .2), (.62, .05), (.68, .18))))
icon("butterfly", "Butterfly", "פרפר", union(
    ellipse(.28, .38, .18, .14), ellipse(.28, .64, .16, .13), ellipse(.72, .38, .18, .14), ellipse(.72, .64, .16, .13),
    rect(.47, .2, .53, .82), seg((.5, .2), (.4, .06), .02), seg((.5, .2), (.6, .06), .02)))
icon("elephant", "Elephant", "פיל", union(
    ellipse(.46, .55, .26, .22), circle(.72, .4, .14), ellipse(.6, .3, .11, .13),
    seg((.83, .42), (.87, .6), .05), seg((.87, .6), (.8, .74), .05),
    rect(.34, .72, .42, .88), rect(.54, .72, .62, .88)))
icon("whale", "Whale", "לוויתן", union(
    ellipse(.45, .52, .32, .18), tri((.75, .52), (.93, .36), (.93, .68)),
    seg((.2, .32), (.2, .14), .04), seg((.2, .32), (.13, .18), .03), seg((.2, .32), (.27, .18), .03)))
icon("snail", "Snail", "חלזון", union(
    ring(.36, .42, .07, .19), circle(.36, .42, .03), ellipse(.62, .68, .24, .1), seg((.8, .6), (.92, .44), .025)))
icon("mouse", "Mouse", "עכבר", union(
    circle(.56, .6, .2), circle(.32, .42, .14), circle(.19, .27, .07), circle(.37, .23, .07), seg((.75, .68), (.92, .82), .03)))
icon("bear", "Bear", "דוב", union(
    ellipse(.5, .62, .26, .22), circle(.5, .32, .16), circle(.35, .16, .07), circle(.65, .16, .07)))
icon("frog", "Frog", "צפרדע", union(
    ellipse(.5, .62, .28, .2), circle(.36, .4, .09), circle(.64, .4, .09), seg((.24, .68), (.08, .84), .05), seg((.76, .68), (.92, .84), .05)))
icon("penguin", "Penguin", "פינגווין", union(
    ellipse(.5, .58, .2, .28), circle(.5, .28, .14), tri((.46, .3), (.54, .3), (.5, .37)),
    tri((.28, .5), (.36, .4), (.36, .62)), tri((.72, .5), (.64, .4), (.64, .62)),
    tri((.4, .86), (.46, .95), (.34, .95)), tri((.6, .86), (.66, .95), (.54, .95))))
icon("fox", "Fox", "שועל", union(
    tri((.5, .15), (.28, .55), (.72, .55)), tri((.32, .05), (.4, .28), (.24, .28)), tri((.68, .05), (.6, .28), (.76, .28)),
    ellipse(.5, .74, .24, .16), tri((.78, .76), (.95, .6), (.95, .88))))

# --- food --------------------------------------------------------------
icon("apple", "Apple", "תפוח", union(circle(.5, .58, .26), tri((.54, .24), (.68, .14), (.6, .32)), rect(.48, .14, .52, .28)))
icon("banana", "Banana", "בננה", union(seg((.24, .72), (.42, .4), .12), seg((.42, .4), (.62, .27), .11), seg((.62, .27), (.8, .3), .09)))
icon("ice_cream", "Ice Cream", "גלידה", union(tri((.4, .55), (.6, .55), (.5, .93)), circle(.5, .4, .2)))
icon("pizza", "Pizza Slice", "פיצה", union(
    tri((.5, .13), (.14, .87), (.86, .87)), circle(.42, .45, .04), circle(.58, .55, .04), circle(.47, .68, .04)))
icon("cupcake", "Cupcake", "קאפקייק", union(rect(.35, .6, .65, .84), ellipse(.5, .44, .23, .18), circle(.5, .26, .05)))
icon("coffee", "Coffee", "קפה", union(rect(.32, .42, .62, .8), ring(.68, .6, .06, .12), seg((.4, .36), (.36, .18), .02), seg((.5, .36), (.5, .16), .02)))
icon("watermelon", "Watermelon", "אבטיח", diff(
    inter(ellipse(.5, .62, .34, .24), rect(0, 0, 1, .64)),
    circle(.4, .55, .03), circle(.5, .6, .03), circle(.6, .55, .03)))
icon("donut", "Donut", "דונאט", diff(circle(.5, .5, .32), circle(.5, .5, .13)))
icon("cherry", "Cherry", "דובדבן", union(circle(.36, .68, .14), circle(.62, .72, .14), seg((.36, .54), (.5, .2), .02), seg((.62, .58), (.5, .2), .02)))
icon("carrot", "Carrot", "גזר", union(tri((.5, .3), (.34, .92), (.66, .92)), seg((.5, .3), (.4, .1), .03), seg((.5, .3), (.5, .06), .03), seg((.5, .3), (.6, .1), .03)))
icon("bread", "Bread", "לחם", union(ellipse(.5, .55, .36, .28), seg((.3, .4), (.3, .68), .02), seg((.5, .34), (.5, .7), .02), seg((.7, .4), (.7, .68), .02)))
icon("egg", "Egg", "ביצה", ellipse(.5, .55, .24, .32))
icon("strawberry", "Strawberry", "תות", diff(
    union(tri((.5, .22), (.22, .88), (.78, .88)), tri((.34, .1), (.5, .24), (.4, .16)), tri((.66, .1), (.5, .24), (.6, .16))),
    circle(.42, .55, .025), circle(.58, .6, .025), circle(.5, .72, .025)))
icon("taco", "Taco", "טאקו", inter(ring(.5, .78, .3, .42), rect(0, 0, 1, .78)))
icon("candy_cane", "Candy Cane", "מקל סוכריות", union(seg((.42, .9), (.42, .35), .1), ring(.55, .3, .1, .18)))
icon("mushroom", "Mushroom", "פטרייה", union(inter(ellipse(.5, .38, .3, .24), rect(0, 0, 1, .4)), rect(.42, .38, .58, .82)))

# --- nature --------------------------------------------------------------
icon("sun", "Sun", "שמש", union(
    circle(.5, .5, .24),
    tri((.42, .26), (.58, .26), (.5, .02)), tri((.42, .74), (.58, .74), (.5, .98)),
    tri((.26, .42), (.26, .58), (.02, .5)), tri((.74, .42), (.74, .58), (.98, .5))))
icon("moon", "Moon", "ירח", diff(circle(.45, .5, .3), circle(.62, .42, .27)))
icon("star", "Star", "כוכב", union(
    tri((.5, .03), (.62, .5), (.38, .5)), tri((.38, .5), (.62, .5), (.5, .97)),
    tri((.03, .5), (.5, .38), (.5, .62)), tri((.5, .38), (.5, .62), (.97, .5))))
icon("cloud", "Cloud", "ענן", union(ellipse(.35, .58, .2, .16), ellipse(.55, .48, .22, .2), ellipse(.72, .58, .16, .14), rect(.3, .58, .78, .74)))
icon("tree", "Tree", "עץ", union(circle(.5, .34, .26), rect(.44, .56, .56, .92)))
icon("flower", "Flower", "פרח", union(
    circle(.5, .3, .13), circle(.3, .5, .13), circle(.7, .5, .13), circle(.5, .7, .13), circle(.5, .5, .1), seg((.5, .78), (.5, .96), .03)))
icon("mountain", "Mountain", "הר", union(tri((.5, .12), (.1, .88), (.9, .88)), tri((.75, .38), (.55, .88), (.95, .88))))
icon("rainbow", "Rainbow", "קשת", diff(
    inter(ring(.5, 1.0, .3, .42), rect(0, 0, 1, 1)),
    rect(0, 0, 1, .55)))
icon("snowflake", "Snowflake", "פתית שלג", union(
    tri((.5, .02), (.6, .42), (.4, .42)), tri((.4, .42), (.6, .42), (.5, .82)),
    tri((.02, .5), (.42, .4), (.42, .6)), tri((.42, .4), (.42, .6), (.82, .5)),
    circle(.5, .5, .1)))
icon("leaf", "Leaf", "עלה", union(ellipse(.5, .5, .18, .38), seg((.5, .12), (.5, .88), .02)))
icon("cactus", "Cactus", "קקטוס", union(rect(.42, .2, .58, .9), rect(.24, .38, .42, .48), seg((.24, .38), (.24, .58), .06), rect(.58, .5, .76, .6), seg((.76, .5), (.76, .7), .06)))
icon("wave", "Wave", "גל", union(
    seg((.05, .55), (.28, .35), .06), seg((.28, .35), (.5, .55), .06), seg((.5, .55), (.72, .35), .06), seg((.72, .35), (.95, .55), .06),
    rect(.05, .55, .95, .68)))
icon("raindrop", "Raindrop", "טיפת גשם", union(tri((.5, .1), (.28, .55), (.72, .55)), circle(.5, .62, .22)))
icon("tulip", "Tulip", "צבעוני", union(
    tri((.32, .5), (.5, .18), (.5, .5)), tri((.68, .5), (.5, .18), (.5, .5)), rect(.42, .3, .58, .5), rect(.47, .5, .53, .92)))
icon("pine_tree", "Pine Tree", "אשוח", union(tri((.5, .06), (.24, .42), (.76, .42)), tri((.5, .3), (.16, .68), (.84, .68)), rect(.45, .68, .55, .92)))
icon("clover", "Clover", "תלתן", union(
    circle(.35, .35, .16), circle(.65, .35, .16), circle(.35, .65, .16), circle(.65, .65, .16), seg((.5, .5), (.5, .92), .03)))

# --- objects --------------------------------------------------------------
icon("heart", "Heart", "לב", union(circle(.35, .38, .18), circle(.65, .38, .18), tri((.15, .42), (.85, .42), (.5, .92))))
icon("house", "House", "בית", union(tri((.5, .1), (.14, .48), (.86, .48)), rect(.2, .48, .8, .88), rect(.44, .64, .58, .88)))
icon("boat", "Boat", "סירה", union(tri((.5, .18), (.5, .62), (.66, .62)), seg((.5, .18), (.5, .62), .02), tri((.12, .62), (.88, .62), (.7, .88)), rect(.28, .62, .72, .68)))
icon("umbrella", "Umbrella", "מטריה", union(inter(circle(.5, .5, .34), rect(0, 0, 1, .5)), rect(.47, .5, .53, .86), tri((.5, .86), (.62, .86), (.56, .94))))
icon("key", "Key", "מפתח", union(ring(.32, .32, .1, .18), rect(.32, .32, .38, .78), rect(.38, .62, .5, .7), rect(.38, .72, .48, .8)))
icon("anchor", "Anchor", "עוגן", union(circle(.5, .18, .08), rect(.47, .22, .53, .78), seg((.22, .78), (.78, .78), .04), tri((.14, .68), (.3, .68), (.22, .84)), tri((.7, .68), (.86, .68), (.78, .84)), seg((.3, .5), (.7, .5), .03)))
icon("gift", "Gift", "מתנה", union(rect(.22, .42, .78, .86), rect(.46, .42, .54, .86), rect(.16, .3, .84, .42), circle(.38, .24, .09), circle(.62, .24, .09)))
icon("balloon", "Balloon", "בלון", union(ellipse(.5, .38, .22, .26), tri((.44, .62), (.56, .62), (.5, .7)), seg((.5, .7), (.5, .95), .02)))
icon("clock", "Clock", "שעון", union(ring(.5, .5, .3, .36), seg((.5, .5), (.5, .28), .03), seg((.5, .5), (.66, .5), .03)))
icon("camera", "Camera", "מצלמה", union(rect(.16, .36, .84, .82), rect(.4, .22, .6, .38), ring(.5, .58, .12, .2)))
icon("lightbulb", "Lightbulb", "נורה", union(circle(.5, .4, .24), rect(.42, .62, .58, .78), seg((.44, .82), (.56, .82), .03)))
icon("kite", "Kite", "עפיפון", union(tri((.5, .08), (.2, .46), (.8, .46)), tri((.2, .46), (.8, .46), (.5, .9)), seg((.5, .9), (.62, 1.0), .015)))
icon("crown", "Crown", "כתר", union(rect(.2, .58, .8, .78), tri((.2, .58), (.32, .58), (.26, .3)), tri((.44, .58), (.56, .58), (.5, .22)), tri((.68, .58), (.8, .58), (.74, .3))))
icon("envelope", "Envelope", "מעטפה", diff(rect(.14, .28, .86, .74), tri((.14, .28), (.86, .28), (.5, .54))))
icon("diamond", "Diamond", "יהלום", union(tri((.5, .14), (.2, .42), (.8, .42)), tri((.2, .42), (.8, .42), (.5, .9))))
icon("candle", "Candle", "נר", union(rect(.4, .34, .6, .88), tri((.45, .16), (.55, .16), (.5, .34))))

random.seed(RNG_SEED)
CATEGORY_ICONS = {
    "animals": ["cat", "dog", "fish", "bird", "rabbit", "turtle", "owl", "butterfly",
                "elephant", "whale", "snail", "mouse", "bear", "frog", "penguin", "fox"],
    "food": ["apple", "banana", "ice_cream", "pizza", "cupcake", "coffee", "watermelon", "donut",
             "cherry", "carrot", "bread", "egg", "strawberry", "taco", "candy_cane", "mushroom"],
    "nature": ["sun", "moon", "star", "cloud", "tree", "flower", "mountain", "rainbow",
               "snowflake", "leaf", "cactus", "wave", "raindrop", "tulip", "pine_tree", "clover"],
    "objects": ["heart", "house", "boat", "umbrella", "key", "anchor", "gift", "balloon",
                "clock", "camera", "lightbulb", "kite", "crown", "envelope", "diamond", "candle"],
}

PALETTE = ["#5B6EF5", "#8B5CF6", "#EC4899", "#F97316", "#10B981", "#06B6D4",
           "#F59E0B", "#EF4444", "#6366F1", "#14B8A6", "#A855F7", "#F43F5E"]

SIZE_TIERS = [(5, 7), (9, 10), (12, 14), (16, 20)]


def render(shape_fn, n):
    grid = []
    for r in range(n):
        v = (r + 0.5) / n
        row = []
        for c in range(n):
            u = (c + 0.5) / n
            row.append(1 if shape_fn(u, v) else 0)
        grid.append(row)
    return grid


def runs(line):
    result = []
    current = 0
    for cell in line:
        if cell:
            current += 1
        elif current > 0:
            result.append(current)
            current = 0
    if current > 0:
        result.append(current)
    return result


def clues_for(grid, n):
    row_clues = [runs(grid[r]) for r in range(n)]
    col_clues = [runs([grid[r][c] for r in range(n)]) for c in range(n)]
    return row_clues, col_clues


# ---------------------------------------------------------------------------
# Solver: constraint propagation + bounded backtracking (equivalent to the
# Swift NonogramSolver algorithm), used purely to VERIFY uniqueness here.
# ---------------------------------------------------------------------------

def _compatible(candidate, known, upto=None):
    limit = len(known) if upto is None else upto
    for i in range(limit):
        if known[i] is not None and known[i] != candidate[i]:
            return False
    return True


def _enumerate_placements(length, blocks, known):
    blocks = [b for b in blocks if b > 0]
    if not blocks:
        empty = [0] * length
        if _compatible(empty, known):
            yield tuple(empty)
        return

    def rec(i, start, current):
        if i == len(blocks):
            candidate = current + [0] * (length - len(current))
            if _compatible(candidate, known):
                yield tuple(candidate)
            return
        remaining_min = sum(blocks[i + 1:]) + len(blocks[i + 1:])
        max_start = length - remaining_min - blocks[i]
        pos = start
        while pos <= max_start:
            candidate = current + [0] * (pos - len(current)) + [1] * blocks[i]
            nxt = pos + blocks[i]
            if nxt < length:
                candidate2 = candidate + [0]
                next_start = nxt + 1
            else:
                candidate2 = candidate
                next_start = nxt
            if _compatible(candidate2, known, upto=len(candidate2)):
                yield from rec(i + 1, next_start, candidate2)
            pos += 1
    yield from rec(0, 0, [])


def _solve_line(length, blocks, known):
    forced = None
    found = False
    for placement in _enumerate_placements(length, blocks, known):
        found = True
        if forced is None:
            forced = list(placement)
        else:
            for i in range(length):
                if forced[i] != -1 and forced[i] != placement[i]:
                    forced[i] = -1
    if not found:
        return None
    return [None if v == -1 else v for v in forced]


def _propagate(grid, n, row_clues, col_clues):
    changed = True
    while changed:
        changed = False
        for r in range(n):
            solved = _solve_line(n, row_clues[r], grid[r])
            if solved is None:
                return False
            if solved != grid[r]:
                grid[r] = solved
                changed = True
        for c in range(n):
            column = [grid[r][c] for r in range(n)]
            solved = _solve_line(n, col_clues[c], column)
            if solved is None:
                return False
            if solved != column:
                for r in range(n):
                    grid[r][c] = solved[r]
                changed = True
    return True


def _first_unknown(grid, n):
    for r in range(n):
        for c in range(n):
            if grid[r][c] is None:
                return r, c
    return None


def solve_unique(n, row_clues, col_clues, limit=2):
    grid = [[None] * n for _ in range(n)]
    if not _propagate(grid, n, row_clues, col_clues):
        return []
    solutions = []

    def search(g):
        if len(solutions) >= limit:
            return
        pos = _first_unknown(g, n)
        if pos is None:
            solutions.append([row[:] for row in g])
            return
        r, c = pos
        for guess in (1, 0):
            attempt = [row[:] for row in g]
            attempt[r][c] = guess
            if _propagate(attempt, n, row_clues, col_clues):
                search(attempt)
            if len(solutions) >= limit:
                return
    search(grid)
    return solutions


def propagation_solves_fully(n, row_clues, col_clues):
    grid = [[None] * n for _ in range(n)]
    if not _propagate(grid, n, row_clues, col_clues):
        return False
    return all(cell is not None for row in grid for cell in row)


# ---------------------------------------------------------------------------
# Puzzle assembly
# ---------------------------------------------------------------------------

def flip_bit(grid, n, r, c):
    grid[r][c] = 1 - grid[r][c]


def try_make_unique(shape_fn, n, max_attempts=40):
    """Renders the icon at size n; if the resulting clues are ambiguous, nudges a
    handful of individual cells (single-pixel toggles) until they resolve to a unique
    solution, or gives up after max_attempts and reports failure."""
    grid = render(shape_fn, n)
    row_clues, col_clues = clues_for(grid, n)
    solutions = solve_unique(n, row_clues, col_clues)
    if len(solutions) == 1 and solutions[0] == grid:
        return grid, row_clues, col_clues

    candidates = [(r, c) for r in range(n) for c in range(n)]
    rng = random.Random(RNG_SEED + n * 1000 + len(candidates))
    rng.shuffle(candidates)

    for r, c in candidates[:max_attempts]:
        trial = [row[:] for row in grid]
        flip_bit(trial, n, r, c)
        filled = sum(sum(row) for row in trial)
        total = n * n
        if not (0.06 * total <= filled <= 0.8 * total):
            continue
        tr, tc = clues_for(trial, n)
        solutions = solve_unique(n, tr, tc)
        if len(solutions) == 1 and solutions[0] == trial:
            return trial, tr, tc
    return None


def classify_difficulty(n, propagation_solved):
    if n <= 8:
        return "easy" if propagation_solved else "medium"
    if n <= 12:
        return "medium" if propagation_solved else "hard"
    if n <= 16:
        return "hard" if propagation_solved else "expert"
    return "expert"


def main():
    if LEVELS_DIR.exists():
        shutil.rmtree(LEVELS_DIR)
    LEVELS_DIR.mkdir(parents=True)

    all_levels_by_category = {cat: [] for cat in CATEGORY_ICONS}
    color_i = 0
    skipped = []

    for category, keys in CATEGORY_ICONS.items():
        cat_dir = LEVELS_DIR / category
        cat_dir.mkdir(parents=True, exist_ok=True)
        for key in keys:
            shape_fn = ICONS[key]
            en_title, he_title = TITLES[key]
            for tier_index, (lo, hi) in enumerate(SIZE_TIERS):
                rng = random.Random(RNG_SEED + hash((key, tier_index)) % 100000)
                n = rng.randint(lo, hi)
                result = try_make_unique(shape_fn, n)
                if result is None:
                    skipped.append((category, key, n))
                    continue
                grid, row_clues, col_clues = result

                total = n * n
                filled = sum(sum(row) for row in grid)
                if not (0.06 * total <= filled <= 0.8 * total):
                    skipped.append((category, key, n))
                    continue

                propagation_ok = propagation_solves_fully(n, row_clues, col_clues)
                difficulty = classify_difficulty(n, propagation_ok)

                level_id = f"{category}_{key}_{n:02d}"
                solution_strings = ["".join(str(v) for v in row) for row in grid]
                color = PALETTE[color_i % len(PALETTE)]
                color_i += 1

                all_levels_by_category[category].append({
                    "id": level_id,
                    "title": {"en": en_title, "he": he_title},
                    "category": category,
                    "difficulty": difficulty,
                    "width": n,
                    "height": n,
                    "solution": solution_strings,
                    "rowClues": row_clues,
                    "colClues": col_clues,
                    "colorHex": color,
                    "order": 0,  # assigned below
                })

    diff_rank = {"easy": 0, "medium": 1, "hard": 2, "expert": 3}
    index_entries = []
    total_count = 0

    for category, levels in all_levels_by_category.items():
        levels.sort(key=lambda lv: (diff_rank[lv["difficulty"]], lv["width"]))
        seen_ids = set()
        for order, level in enumerate(levels):
            level["order"] = order
            assert level["id"] not in seen_ids, f"duplicate id {level['id']}"
            seen_ids.add(level["id"])

            out_path = LEVELS_DIR / category / f"{level['id']}.json"
            with out_path.open("w", encoding="utf-8") as f:
                json.dump(level, f, ensure_ascii=False, indent=2)

            index_entries.append({
                "id": level["id"],
                "category": level["category"],
                "difficulty": level["difficulty"],
                "width": level["width"],
                "height": level["height"],
                "order": level["order"],
            })
            total_count += 1

    with (LEVELS_DIR / "levels_index.json").open("w", encoding="utf-8") as f:
        json.dump({"levels": index_entries}, f, ensure_ascii=False, indent=2)

    # --- Final self-check: re-verify every emitted file from disk ---
    verified = 0
    for category in CATEGORY_ICONS:
        for path in sorted((LEVELS_DIR / category).glob("*.json")):
            with path.open(encoding="utf-8") as f:
                data = json.load(f)
            n = data["width"]
            assert data["height"] == n
            assert len(data["solution"]) == n and all(len(row) == n for row in data["solution"])
            grid = [[int(ch) for ch in row] for row in data["solution"]]
            row_clues, col_clues = clues_for(grid, n)
            assert row_clues == data["rowClues"], f"row clue mismatch in {path.name}"
            assert col_clues == data["colClues"], f"col clue mismatch in {path.name}"
            solutions = solve_unique(n, data["rowClues"], data["colClues"])
            assert len(solutions) == 1, f"NOT UNIQUE: {path.name} has {len(solutions)} solutions"
            assert solutions[0] == grid, f"solver disagrees with stored solution in {path.name}"
            verified += 1

    print(f"Generated and verified {verified} levels (skipped {len(skipped)} unresolved candidates).")
    for category, levels in all_levels_by_category.items():
        sizes = sorted(set(lv["width"] for lv in levels))
        print(f"  {category}: {len(levels)} levels, sizes {sizes}")
    if skipped:
        print("Skipped (icon, size) combos that never resolved to a unique/valid puzzle:")
        for category, key, n in skipped:
            print(f"  - {category}/{key} at {n}x{n}")
    assert total_count >= 200, f"only generated {total_count} levels, need >= 200"
    for category, levels in all_levels_by_category.items():
        assert len(levels) >= 50, f"{category} only has {len(levels)} levels, need >= 50"
    print("All content-integrity checks passed.")


if __name__ == "__main__":
    main()
