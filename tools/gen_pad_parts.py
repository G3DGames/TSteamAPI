#!/usr/bin/env python3
"""Writes PadParts.pas - where each control's part sits on the gamepad models -
into the three VirtualGamepad demos (identical copies).

    python3 tools/gen_pad_parts.py

Standard library only. Reads every models/*.glb and writes the same
PadParts.pas into demos/VirtualGamepad/src, demos/VirtualGamepadLCL/src and
demos/VirtualGamepadVCL/src (tools/project_check.py keeps them identical).
Run it after a model is added or changed: a model the unit does not know, or
a .glb of a different size than the one it was made from, is reported in the
program's log and gets no glow.

For every clip of a model (A_Press, Stick_Left_Up, ...) the unit records the
joint the clip moves and that joint's PART: the vertices the joint carries
(dominant skin weight), with their rest positions worked out exactly as the
GPU skins them (joint world matrix x inverse bind matrix). Each part gets
its centre (middle of their bounding box) and radius (the farthest of its
vertices from that centre), in model space - glTF coordinates, Y up, the
face towards +Z. The programs put a translucent glow sphere there.

Each part also gets a KEY and a MIRROR. Clips with the same key share one
glow sphere (a stick and its click). The D-pad is one joint, but its four
clips get four keys (DPad/Up ...): each arm is the D-pad's vertices beyond a
third of its reach inside a 90-degree wedge, so Up + Right light two arms.
MIRROR is the clip of the left / right twin (L4_Press <-> R4_Press,
Menu_Press <-> View_Press, DPad_Left <-> DPad_Right; empty on the middle
line): the programs glow the twin in the back and top views, where the
pad's left is on the screen's right.

Stray skin weights: a joint may carry pieces of other parts (the Steam
Controller's Profile / View / Menu joints do). Pieces closer than LINK_GAP
count as one group; of mirror-twin clips the generator keeps the two groups
that mirror each other best, otherwise the largest group.

Trackpads have no joint in our models. A model can mark them with an empty
node (glTF "empty") named Trackpad_Left, Trackpad_Right or Trackpad_Center:
its origin is the middle of the pad's surface, its local X and Y axes run
along the surface to the pad's right and top edges (a node scale of the
half-width / half-height, so x, y of -1..1 reach the edges) and its local Z
points out of the surface. docs/VirtualGamepadModels.md is the brief for
model makers. Without markers the programs show trackpad touches in a 2D
inset instead.
"""
import glob
import json
import math
import os
import struct

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MODELS = os.path.join(ROOT, "models")
TARGETS = ["demos/VirtualGamepad/src", "demos/VirtualGamepadLCL/src", "demos/VirtualGamepadVCL/src"]
UNIT = "PadParts.pas"
TRACKPAD_SIDES = ("Left", "Right", "Center")
# smallest movement that counts: translation in model units (button travel
# is ~0.006), rotation in radians (~0.6 degrees; float noise is ~0.0003)
MOVE_EPS_T = 1e-4
MOVE_EPS_R = 0.01
# part pieces: grid cell joining neighbouring vertices (model units); pieces
# at most LINK_GAP apart are one part (a ring button's two arcs are 0.033
# apart, a split button's halves 0.052); left / right twins must mirror each
# other within MIRROR_TOLERANCE
CLUSTER_CELL = 0.012
LINK_GAP = 0.06
MIRROR_TOLERANCE = 0.02

COMP = {5120: ("b", 1), 5121: ("B", 1), 5122: ("h", 2), 5123: ("H", 2), 5125: ("I", 4), 5126: ("f", 4)}
NUM = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4, "MAT4": 16}
IDENTITY = [1.0, 0, 0, 0, 0, 1.0, 0, 0, 0, 0, 1.0, 0, 0, 0, 0, 1.0]


# ---------------------------------------------------------------- glTF --

def load_glb(path):
    data = open(path, "rb").read()
    magic, _, _ = struct.unpack_from("<III", data, 0)
    if magic != 0x46546C67:
        raise SystemExit(f"{path}: not a .glb file")
    json_len = struct.unpack_from("<I", data, 12)[0]
    doc = json.loads(data[20:20 + json_len])
    return doc, data, 20 + json_len + 8


def accessor(doc, data, binoff, index):
    a = doc["accessors"][index]
    bv = doc["bufferViews"][a["bufferView"]]
    fmt, size = COMP[a["componentType"]]
    n = NUM[a["type"]]
    off = binoff + bv.get("byteOffset", 0) + a.get("byteOffset", 0)
    stride = bv.get("byteStride", size * n)
    scale = {"B": 255, "H": 65535, "b": 127, "h": 32767}.get(fmt) if a.get("normalized") else None
    out = []
    for k in range(a["count"]):
        v = struct.unpack_from(f"<{n}{fmt}", data, off + k * stride)
        out.append(tuple(x / scale for x in v) if scale else v)
    return out


def mat_mul(a, b):
    """4x4 product, column-major lists of 16 (glTF order)."""
    return [sum(a[k * 4 + r] * b[c * 4 + k] for k in range(4)) for c in range(4) for r in range(4)]


def mat_point(m, p):
    x, y, z = p
    return tuple(m[r] * x + m[4 + r] * y + m[8 + r] * z + m[12 + r] for r in range(3))


def mat_dir(m, p):
    x, y, z = p
    return tuple(m[r] * x + m[4 + r] * y + m[8 + r] * z for r in range(3))


def node_local(n):
    if "matrix" in n:
        return [float(v) for v in n["matrix"]]
    tx, ty, tz = n.get("translation", [0, 0, 0])
    qx, qy, qz, qw = n.get("rotation", [0, 0, 0, 1])
    sx, sy, sz = n.get("scale", [1, 1, 1])
    r = [1 - 2 * (qy * qy + qz * qz), 2 * (qx * qy + qz * qw), 2 * (qx * qz - qy * qw), 0,
         2 * (qx * qy - qz * qw), 1 - 2 * (qx * qx + qz * qz), 2 * (qy * qz + qx * qw), 0,
         2 * (qx * qz + qy * qw), 2 * (qy * qz - qx * qw), 1 - 2 * (qx * qx + qy * qy), 0,
         0, 0, 0, 1]
    s = [sx, 0, 0, 0, 0, sy, 0, 0, 0, 0, sz, 0, 0, 0, 0, 1]
    t = [1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, tx, ty, tz, 1]
    return mat_mul(t, mat_mul(r, s))


def world_matrices(doc):
    nodes = doc["nodes"]
    parent = {c: i for i, n in enumerate(nodes) for c in n.get("children", [])}
    cache = {}

    def world(i):
        if i not in cache:
            cache[i] = mat_mul(world(parent[i]), node_local(nodes[i])) if i in parent else node_local(nodes[i])
        return cache[i]
    return [world(i) for i in range(len(nodes))]


# ---------------------------------------------------------------- parts --

def clip_joints(doc, data, binoff):
    """{clip name: node index of the joint it moves most} (clips that move nothing are left out)."""
    result = {}
    for anim in doc.get("animations", []):
        best, best_move = None, 0.0
        for ch in anim["channels"]:
            path = ch["target"].get("path")
            if path not in ("translation", "rotation"):
                continue
            values = accessor(doc, data, binoff, anim["samplers"][ch["sampler"]]["output"])
            first = values[0]
            if path == "translation":
                move = max(math.dist(first, v) for v in values)
            else:
                # angle between the first key and the farthest one
                move = max(2 * math.acos(min(1.0, abs(sum(a * b for a, b in zip(first, v))))) for v in values)
            if move < (MOVE_EPS_T if path == "translation" else MOVE_EPS_R):
                continue
            # rotations and translations compared on one scale: a turn of
            # 0.1 rad counts like a push of 0.01 (both clearly a press)
            move = move if path == "translation" else move / 10
            if move > best_move:
                best, best_move = ch["target"]["node"], move
        if best is not None:
            result[anim["name"]] = best
    return result


def joint_vertices(doc, data, binoff, world):
    """{joint node index: [rest positions in model space]} by dominant skin weight."""
    out = {}
    for n in doc["nodes"]:
        if "mesh" not in n or "skin" not in n:
            continue
        skin = doc["skins"][n["skin"]]
        ibm = ([list(m) for m in accessor(doc, data, binoff, skin["inverseBindMatrices"])]
               if "inverseBindMatrices" in skin else [IDENTITY] * len(skin["joints"]))
        mats = [mat_mul(world[j], ibm[k]) for k, j in enumerate(skin["joints"])]
        for prim in doc["meshes"][n["mesh"]]["primitives"]:
            attrs = prim["attributes"]
            if "JOINTS_0" not in attrs or "WEIGHTS_0" not in attrs:
                continue
            pos = accessor(doc, data, binoff, attrs["POSITION"])
            joints = accessor(doc, data, binoff, attrs["JOINTS_0"])
            weights = accessor(doc, data, binoff, attrs["WEIGHTS_0"])
            for p, js, ws in zip(pos, joints, weights):
                skinned = [0.0, 0.0, 0.0]
                for k, w in zip(js, ws):
                    if w:
                        q = mat_point(mats[k], p)
                        skinned = [skinned[i] + w * q[i] for i in range(3)]
                dominant = skin["joints"][js[max(range(len(ws)), key=lambda i: ws[i])]]
                out.setdefault(dominant, []).append(tuple(skinned))
    return out


def bounds(points):
    lo = [min(p[i] for p in points) for i in range(3)]
    hi = [max(p[i] for p in points) for i in range(3)]
    centre = tuple((lo[i] + hi[i]) / 2 for i in range(3))
    return centre, max(math.dist(centre, p) for p in points)


def clusters(points, cell=CLUSTER_CELL):
    """Connected pieces of a point set (points in neighbouring grid cells join)."""
    grid = {}
    for p in points:
        grid.setdefault(tuple(int(math.floor(c / cell)) for c in p), []).append(p)
    seen, out = set(), []
    for start in grid:
        if start in seen:
            continue
        seen.add(start)
        stack, piece = [start], []
        while stack:
            c = stack.pop()
            piece += grid[c]
            for dx in (-1, 0, 1):
                for dy in (-1, 0, 1):
                    for dz in (-1, 0, 1):
                        n = (c[0] + dx, c[1] + dy, c[2] + dz)
                        if n in grid and n not in seen:
                            seen.add(n)
                            stack.append(n)
        out.append(piece)
    return sorted(out, key=len, reverse=True)


def box_gap(a, b):
    """Gap between the bounding boxes of two pieces (0 when they overlap)."""
    alo = [min(p[i] for p in a) for i in range(3)]
    ahi = [max(p[i] for p in a) for i in range(3)]
    blo = [min(p[i] for p in b) for i in range(3)]
    bhi = [max(p[i] for p in b) for i in range(3)]
    return max(max(blo[i] - ahi[i], alo[i] - bhi[i], 0) for i in range(3))


def groups(points):
    """The joint's vertices as groups: connected pieces, joined when they are
    at most LINK_GAP apart - the two arcs of a ring button (the Steam
    Controller's Menu / View), the two halves of a split one (its Profile).
    Largest group first."""
    pieces = clusters(points)
    group_of = list(range(len(pieces)))

    def root(i):
        while group_of[i] != i:
            i = group_of[i]
        return i
    for i in range(len(pieces)):
        for j in range(i + 1, len(pieces)):
            if box_gap(pieces[i], pieces[j]) <= LINK_GAP:
                group_of[root(j)] = root(i)
    joined = {}
    for i, piece in enumerate(pieces):
        joined.setdefault(root(i), []).extend(piece)
    return sorted(joined.values(), key=len, reverse=True)


def mirror(p):
    return (-p[0], p[1], p[2])


def mirror_clip(clip, playstation):
    """The clip of the control in the mirrored position (left <-> right), or
    the clip itself (a control on the centre line)."""
    swaps = [("Left", "Right"), ("L4", "R4"), ("L5", "R5"), ("Menu_", "View_")]
    # the face buttons: left <-> right (Xbox letters X / B; PlayStation
    # Square / Circle - its X_Press is the bottom button, Cross)
    swaps.append(("Square_", "Circle_") if playstation else ("X_", "B_"))
    out = clip
    for a, b in swaps:
        out = out.replace(a, "\x00").replace(b, a).replace("\x00", b)
    return out


def dpad_arm(points, centre, direction):
    """The vertices of one arm of the D-pad: those beyond a third of the
    pad's reach in that direction, inside its 90 degree wedge (x right,
    y up - the face looks towards +Z)."""
    dx, dy = direction
    reach = max(abs((p[0] - centre[0]) * dx + (p[1] - centre[1]) * dy) for p in points)
    arm = []
    for p in points:
        along = (p[0] - centre[0]) * dx + (p[1] - centre[1]) * dy
        across = abs((p[0] - centre[0]) * dy - (p[1] - centre[1]) * dx)
        if along > reach / 3 and along > across:
            arm.append(p)
    return arm


DPAD_ARMS = {"DPad_Up": (0, 1), "DPad_Down": (0, -1), "DPad_Left": (-1, 0), "DPad_Right": (1, 0)}


def read_model(path):
    doc, data, binoff = load_glb(path)
    world = world_matrices(doc)
    names = [n.get("name", f"node{i}") for i, n in enumerate(doc["nodes"])]
    verts = joint_vertices(doc, data, binoff, world)
    model = os.path.basename(path)
    clips = clip_joints(doc, data, binoff)
    playstation = "Circle_Press" in clips
    for clip, joint in list(clips.items()):
        if joint not in verts:
            print(f"note: {model}: clip {clip} moves {names[joint]}, which carries no vertices")
            del clips[clip]
    # the group of vertices each joint's part is. Normally its largest group;
    # for two joints whose clips are left / right twins (Menu / View) the two
    # groups that mirror each other best (the Steam Controller's View joint
    # also carries a dot in the middle of the pad, larger than its ring)
    cand = {j: groups(verts[j]) for j in set(clips.values())}
    chosen = {j: g[0] for j, g in cand.items()}
    for clip, joint in clips.items():
        twin = clips.get(mirror_clip(clip, playstation))
        if twin is None or twin == joint or joint > twin:
            continue
        best = None
        for a in cand[joint]:
            ca = bounds(a)[0]
            for b in cand[twin]:
                d = math.dist(mirror(ca), bounds(b)[0])
                if best is None or d < best[0]:
                    best = (d, a, b)
        if best and best[0] <= MIRROR_TOLERANCE:
            chosen[joint], chosen[twin] = best[1], best[2]
    for joint, group in chosen.items():
        left_out = len(verts[joint]) - len(group)
        if left_out:
            print(f"note: {model}: joint {names[joint]}: {left_out} of its {len(verts[joint])} vertices are "
                  f"elsewhere on the pad (stray skin weights) - left out of its part")
    parts = []
    for clip, joint in sorted(clips.items()):
        group = chosen[joint]
        key = names[joint]
        if clip in DPAD_ARMS:
            # one glow per arm, so Up + Right show as two
            arm = dpad_arm(group, bounds(group)[0], DPAD_ARMS[clip])
            if arm:
                group, key = arm, f"{names[joint]}/{clip[5:]}"
        centre, radius = bounds(group)
        twin = mirror_clip(clip, playstation)
        parts.append((clip, names[joint], key, twin if twin != clip and twin in clips else "", centre, radius))
    pads = []
    for side in TRACKPAD_SIDES:
        for i, name in enumerate(names):
            if name.lower() == f"trackpad_{side.lower()}":
                m = world[i]
                normal = mat_dir(m, (0, 0, 1))
                length = math.sqrt(sum(c * c for c in normal)) or 1.0
                pads.append((side, mat_point(m, (0, 0, 0)), mat_dir(m, (1, 0, 0)), mat_dir(m, (0, 1, 0)),
                             tuple(c / length for c in normal)))
    return os.path.getsize(path), parts, pads


# --------------------------------------------------------------- Pascal --

def num(v):
    s = f"{v:.5f}".rstrip("0").rstrip(".")
    return "0" if s in ("-0", "") else s


def pascal_unit(models):
    parts = [(m, *p) for m, (_, ps, _) in models.items() for p in ps]
    pads = [(m, *p) for m, (_, _, ts) in models.items() for p in ts]
    out = []
    w = out.append
    w("(* @abstract(Where each control's part sits on the gamepad models: the")
    w("  glow and the trackpad dot of VirtualGamepad, VirtualGamepadLCL and")
    w("  VirtualGamepadVCL.)")
    w("")
    w("  GENERATED by tools/gen_pad_parts.py from models/*.glb - do not edit; run")
    w("  it again after a model is added or changed. The same file in all three")
    w("  demos (tools/project_check.py keeps the copies identical).")
    w("")
    w("  Positions are in model space - glTF coordinates, Y up, the face")
    w("  towards +Z - the space the programs' model nodes use, so a sphere made")
    w("  a child of the model at a part's centre sits on that part. *)")
    w("unit PadParts;")
    w("")
    w("{$IFDEF FPC}{$mode delphi}{$H+}{$ENDIF}")
    w("")
    w("interface")
    w("")
    w("type")
    w("  { A model this unit was made from. }")
    w("  TPadModel = record")
    w("    { File name (no folder). }")
    w("    FileName: string;")
    w("    { Its size in bytes when this unit was made (a different size: the")
    w("      file changed, run tools/gen_pad_parts.py again). }")
    w("    FileSize: Int64;")
    w("  end;")
    w("")
    w("  { The part a clip moves: its joint and where the part sits at rest. }")
    w("  TPadPart = record")
    w("    { Model file the part belongs to. }")
    w("    Model: string;")
    w("    { The clip (glTF animation) that moves it. }")
    w("    Clip: string;")
    w("    { The joint (glTF node) carrying it. }")
    w("    Joint: string;")
    w("    { Which part it is: the joint's name, so clips moving one joint share")
    w("      one part (a stick and its click) - except the D-pad, whose arms are")
    w("      parts of their own (DPad/Up, DPad/Right, ...). }")
    w("    Key: string;")
    w("    { The clip of the control in the mirrored position (left / right")
    w("      swapped: Stick_Left_Up - Stick_Right_Up, L4_Press - R4_Press,")
    w("      Menu_Press - View_Press); '' on the centre line. The back and top")
    w("      views glow the mirrored part (owner 2026-11-05). }")
    w("    Mirror: string;")
    w("    { Centre x at rest, model space. }")
    w("    X: Single;")
    w("    { Centre y at rest, model space. }")
    w("    Y: Single;")
    w("    { Centre z at rest, model space. }")
    w("    Z: Single;")
    w("    { Distance from the centre to the part's farthest vertex. }")
    w("    Radius: Single;")
    w("  end;")
    w("")
    w("  { A trackpad marked in a model (empty node Trackpad_Left, _Right or")
    w("    _Center): a touch at x, y (-1..1, y up) sits at O + x * U + y * V. }")
    w("  TPadTrackpad = record")
    w("    { Model file the trackpad belongs to. }")
    w("    Model: string;")
    w("    { Left, Right or Center. }")
    w("    Side: string;")
    for axis, text in (("O", "Middle of the pad's surface"), ("U", "Half-width vector, towards the pad's right edge"),
                       ("V", "Half-height vector, towards the pad's top edge"),
                       ("N", "Unit normal, out of the surface")):
        for c in "XYZ":
            w(f"    {{ {text}: {c.lower()}. }}")
            w(f"    {axis}{c}: Single;")
    w("  end;")
    w("")
    w("const")
    w("  { Number of models in @link(PAD_MODELS). }")
    w(f"  PAD_MODEL_COUNT = {len(models)};")
    w("  { The models this unit was made from. }")
    w(f"  PAD_MODELS: array[0..{max(len(models), 1) - 1}] of TPadModel = (")
    rows = [f"    (FileName: '{m}'; FileSize: {size})" for m, (size, _, _) in models.items()]
    w(",\n".join(rows) + ");")
    w("  { Number of parts in @link(PAD_PARTS). }")
    w(f"  PAD_PART_COUNT = {len(parts)};")
    w("  { Every clip's part, by model. }")
    w(f"  PAD_PARTS: array[0..{max(len(parts), 1) - 1}] of TPadPart = (")
    rows = [f"    (Model: '{m}'; Clip: '{clip}'; Joint: '{joint}'; Key: '{key}'; Mirror: '{twin}';\n"
            f"     X: {num(c[0])}; Y: {num(c[1])}; Z: {num(c[2])}; Radius: {num(r)})"
            for m, clip, joint, key, twin, c, r in parts]
    w(",\n".join(rows) + ");")
    w("  { Number of trackpads in @link(PAD_TRACKPADS) (0: no model marks its")
    w("    trackpads yet - the array then holds one unused entry). }")
    w(f"  PAD_TRACKPAD_COUNT = {len(pads)};")
    w("  { The trackpads the models mark. }")
    w(f"  PAD_TRACKPADS: array[0..{max(len(pads), 1) - 1}] of TPadTrackpad = (")
    if pads:
        rows = []
        for m, side, o, u, v, n in pads:
            vals = "; ".join(f"{a}{c}: {num(vec[i])}" for a, vec in (("O", o), ("U", u), ("V", v), ("N", n))
                             for i, c in enumerate("XYZ"))
            rows.append(f"    (Model: '{m}'; Side: '{side}'; {vals})")
        w(",\n".join(rows) + ");")
    else:
        vals = "; ".join(f"{a}{c}: 0" for a in "OUVN" for c in "XYZ")
        w(f"    (Model: ''; Side: ''; {vals}));")
    w("")
    w("{ Whether this unit knows a model file.")
    w("  @param(AFileName File name (no folder).)")
    w("  @param(ASize Its size in bytes (@link(PadFileSize)).)")
    w("  @returns(1 known, 0 unknown, -1 known but of another size - the file")
    w("    changed since this unit was made.) }")
    w("function PadModelCheck(const AFileName: string; ASize: Int64): Integer;")
    w("")
    w("{ The part clip AClip of model AModel moves.")
    w("  @param(AModel Model file name.)")
    w("  @param(AClip Clip name.)")
    w("  @param(APart The part, when found.)")
    w("  @returns(@false when the model has no such clip here.) }")
    w("function FindPadPart(const AModel, AClip: string; out APart: TPadPart): Boolean;")
    w("")
    w("{ The trackpad ASide of model AModel.")
    w("  @param(AModel Model file name.)")
    w("  @param(ASide Left, Right or Center.)")
    w("  @param(APad The trackpad, when the model marks it.)")
    w("  @returns(@false when the model does not mark that trackpad.) }")
    w("function FindPadTrackpad(const AModel, ASide: string; out APad: TPadTrackpad): Boolean;")
    w("")
    w("{ Size of a file in bytes.")
    w("  @param(APath The file.)")
    w("  @returns(The size, or -1 when it cannot be opened.) }")
    w("function PadFileSize(const APath: string): Int64;")
    w("")
    w("implementation")
    w("")
    w("uses")
    w("  {$IFDEF FPC}SysUtils, Classes{$ELSE}System.SysUtils, System.Classes{$ENDIF};")
    w("")
    w("function PadModelCheck(const AFileName: string; ASize: Int64): Integer;")
    w("var")
    w("  I: Integer;")
    w("begin")
    w("  Result := 0;")
    w("  for I := 0 to PAD_MODEL_COUNT - 1 do")
    w("    if SameText(PAD_MODELS[I].FileName, AFileName) then")
    w("    begin")
    w("      if PAD_MODELS[I].FileSize = ASize then")
    w("        Result := 1")
    w("      else")
    w("        Result := -1;")
    w("      Exit;")
    w("    end;")
    w("end;")
    w("")
    w("function FindPadPart(const AModel, AClip: string; out APart: TPadPart): Boolean;")
    w("var")
    w("  I: Integer;")
    w("begin")
    w("  for I := 0 to PAD_PART_COUNT - 1 do")
    w("    if SameText(PAD_PARTS[I].Model, AModel) and SameText(PAD_PARTS[I].Clip, AClip) then")
    w("    begin")
    w("      APart := PAD_PARTS[I];")
    w("      Exit(True);")
    w("    end;")
    w("  Result := False;")
    w("end;")
    w("")
    w("function FindPadTrackpad(const AModel, ASide: string; out APad: TPadTrackpad): Boolean;")
    w("var")
    w("  I: Integer;")
    w("begin")
    w("  for I := 0 to PAD_TRACKPAD_COUNT - 1 do")
    w("    if SameText(PAD_TRACKPADS[I].Model, AModel) and SameText(PAD_TRACKPADS[I].Side, ASide) then")
    w("    begin")
    w("      APad := PAD_TRACKPADS[I];")
    w("      Exit(True);")
    w("    end;")
    w("  Result := False;")
    w("end;")
    w("")
    w("function PadFileSize(const APath: string): Int64;")
    w("var")
    w("  F: TFileStream;")
    w("begin")
    w("  try")
    w("    F := TFileStream.Create(APath, fmOpenRead or fmShareDenyNone);")
    w("    try")
    w("      Result := F.Size;")
    w("    finally")
    w("      F.Free;")
    w("    end;")
    w("  except")
    w("    Result := -1;")
    w("  end;")
    w("end;")
    w("")
    w("end.")
    return "\r\n".join("\n".join(out).split("\n")) + "\r\n"


def main():
    models = {}
    for path in sorted(glob.glob(os.path.join(MODELS, "*.glb"))):
        size, parts, pads = read_model(path)
        models[os.path.basename(path)] = (size, parts, pads)
        print(f"{os.path.basename(path)}: {len(parts)} clips -> {len({p[2] for p in parts})} parts, "
              f"{len(pads)} trackpad markers")
    text = pascal_unit(models).encode("ascii")
    for target in TARGETS:
        rel = f"{target}/{UNIT}"
        full = os.path.join(ROOT, *rel.split("/"))
        old = open(full, "rb").read() if os.path.exists(full) else None
        if old != text:
            open(full, "wb").write(text)
            print("wrote", rel)
        else:
            print("unchanged", rel)


if __name__ == "__main__":
    main()
