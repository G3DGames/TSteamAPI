#!/usr/bin/env python3
"""Draws the TEST skyboxes of the VirtualGamepad demos (owner 2026-11-07:
generated for testing, real art later) into images/skyboxes/<Name>/:

    python3 tools/gen_skyboxes.py images/skyboxes

One folder per skybox (its name is the folder's), six 512 x 512 cube faces
px / nx / py / ny / pz / nz (+X right, +Y up, +Z front, X3D Background
order). Grid: a coloured wall per face with a marker shape (shows which
face is where, and the turning); Sky: gradient, horizon, clouds, a sun in
front; Stars: stars and a band. Generated, CC0. A new skybox is just a new
folder with the same six files - the programs list the folders.
"""
import os, sys, math, random
from PIL import Image, ImageDraw, ImageFilter
OUT = sys.argv[1]
S = 512
FACES = ("px", "nx", "py", "ny", "pz", "nz")

def save(name, face, im):
    d = os.path.join(OUT, name); os.makedirs(d, exist_ok=True)
    im.save(os.path.join(d, face + ".png"), optimize=True)

# 1. Grid room: each wall its own colour, a grid, a marker shape in the middle
TINT = {"px": (200, 70, 70), "nx": (70, 170, 90), "py": (90, 120, 210), "ny": (120, 110, 100),
        "pz": (200, 170, 60), "nz": (150, 80, 180)}
MARK = {"px": "circle", "nx": "square", "py": "plus", "ny": "ring", "pz": "triangle", "nz": "diamond"}
for f in FACES:
    base = tuple(int(c * 0.35) for c in TINT[f])
    im = Image.new("RGB", (S, S), base); dr = ImageDraw.Draw(im)
    for i in range(0, S + 1, S // 8):
        dr.line([(i, 0), (i, S)], fill=TINT[f], width=3); dr.line([(0, i), (S, i)], fill=TINT[f], width=3)
    c, r = S // 2, S // 8; col = (240, 240, 240)
    m = MARK[f]
    if m == "circle": dr.ellipse([c - r, c - r, c + r, c + r], fill=col)
    elif m == "ring": dr.ellipse([c - r, c - r, c + r, c + r], outline=col, width=14)
    elif m == "square": dr.rectangle([c - r, c - r, c + r, c + r], fill=col)
    elif m == "plus": dr.rectangle([c - r, c - r // 4, c + r, c + r // 4], fill=col); dr.rectangle([c - r // 4, c - r, c + r // 4, c + r], fill=col)
    elif m == "triangle": dr.polygon([(c, c - r), (c + r, c + r), (c - r, c + r)], fill=col)
    else: dr.polygon([(c, c - r), (c + r, c), (c, c + r), (c - r, c)], fill=col)
    save("Grid", f, im)

# 2. Sky: blue gradient to a light horizon, brown ground, a few clouds, a sun on +Z
def sky_col(t):   # t: -1 bottom .. 1 top (elevation sine)
    if t >= 0:
        top, hor = (40, 90, 190), (190, 215, 240)
        k = t ** 0.6
        return tuple(int(hor[i] + (top[i] - hor[i]) * k) for i in range(3))
    gnd, hor = (70, 55, 40), (150, 135, 110)
    k = (-t) ** 0.5
    return tuple(int(hor[i] + (gnd[i] - hor[i]) * k) for i in range(3))

def face_dir(f, u, v):   # u, v in -1..1 (u right, v up on the image)
    return {"px": (1, v, -u), "nx": (-1, v, u), "py": (u, 1, -v), "ny": (u, -1, v),
            "pz": (u, v, 1), "nz": (-u, v, -1)}[f]

random.seed(7)
clouds = [(random.uniform(0, 2 * math.pi), random.uniform(0.15, 0.6), random.uniform(0.08, 0.18)) for _ in range(14)]
for f in FACES:
    im = Image.new("RGB", (S, S)); px = im.load()
    for y in range(S):
        for x in range(S):
            u = (x + 0.5) / S * 2 - 1; v = 1 - (y + 0.5) / S * 2
            dx, dy, dz = face_dir(f, u, v); n = math.sqrt(dx * dx + dy * dy + dz * dz)
            dx, dy, dz = dx / n, dy / n, dz / n
            c = list(sky_col(dy))
            if dy > 0:
                az = math.atan2(dx, dz)
                for a0, el, w in clouds:
                    d = math.hypot((az - a0 + math.pi) % (2 * math.pi) - math.pi, (math.asin(dy) - el) * 2)
                    if d < w:
                        k = 1 - d / w; c = [int(c[i] + (250 - c[i]) * k * 0.8) for i in range(3)]
                sun = math.acos(max(-1, min(1, dx * 0 + dy * 0.34 + dz * 0.94)))
                if sun < 0.09: c = [255, 250, 220]
                elif sun < 0.3: k = (0.3 - sun) / 0.21; c = [int(c[i] + (255 - c[i]) * k * 0.6) for i in range(3)]
            px[x, y] = tuple(c)
    save("Sky", f, im)

# 3. Stars: black, stars, a coloured band (a "milky way") across the sky
random.seed(11)
stars = []
for _ in range(2200):
    z = random.uniform(-1, 1); a = random.uniform(0, 2 * math.pi); r = math.sqrt(1 - z * z)
    stars.append((r * math.cos(a), z, r * math.sin(a), random.random()))
for f in FACES:
    im = Image.new("RGB", (S, S), (3, 4, 10)); px = im.load()
    for y in range(0, S, 2):
        for x in range(0, S, 2):
            u = (x + 1) / S * 2 - 1; v = 1 - (y + 1) / S * 2
            dx, dy, dz = face_dir(f, u, v); n = math.sqrt(dx * dx + dy * dy + dz * dz)
            band = abs((dx * 0.3 + dy * 0.8 + dz * 0.5) / n)
            if band < 0.25:
                k = (0.25 - band) / 0.25
                col = (int(3 + 40 * k), int(4 + 20 * k), int(10 + 70 * k))
                for ox in (0, 1):
                    for oy in (0, 1): px[x + ox, y + oy] = col
    dr = ImageDraw.Draw(im)
    for sx, sy, sz, b in stars:
        d = {"px": (sx, sy, sz, 0), "nx": (-sx, sy, -sz, 0), "py": (sy, sx, sz, 1), "ny": (-sy, sx, -sz, 1),
             "pz": (sz, sy, -sx, 2), "nz": (-sz, sy, sx, 2)}[f]
        m = d[0]
        if m <= 0: continue
        # project onto the face (same mapping as face_dir, inverted)
        dx, dy, dz = sx, sy, sz
        if f == "px": u, v = -dz / dx, dy / dx
        elif f == "nx": u, v = dz / -dx, dy / -dx
        elif f == "py": u, v = dx / dy, -dz / dy
        elif f == "ny": u, v = dx / -dy, dz / -dy
        elif f == "pz": u, v = dx / dz, dy / dz
        else: u, v = -dx / -dz, dy / -dz
        if abs(u) > 1 or abs(v) > 1: continue
        X = (u + 1) / 2 * S; Y = (1 - v) / 2 * S
        lum = int(140 + 115 * b); r = 1.6 if b > 0.93 else 0.7
        dr.ellipse([X - r, Y - r, X + r, Y + r], fill=(lum, lum, min(255, lum + 20)))
    save("Stars", f, im)
print("wrote", OUT)
