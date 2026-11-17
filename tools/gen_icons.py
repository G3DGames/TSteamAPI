#!/usr/bin/env python3
"""Draws the palette icons of every component (docs/ComponentIcons.md).

    python3 tools/gen_icons.py [--preview sheet.png]

Writes design/icons/<Class>.ico (16, 24, 32, 36, 48, 64 and 256 px, 32-bit
with alpha) and its source design/icons/svg/<Class>.svg, plus the server badge
alone (ServerBadge.ico / .svg), and the programs' application icons (task
bar / dock): <project>.ico, and <project>.icns for the FMX projects, next to
each project file (APP_ICONS). Run it only to REDRAW the icons; packaging
the palette icons for the IDEs is tools/gen_icon_res.py, which needs no
third-party module.
This one needs Pillow (pip install pillow) and rsvg-convert (librsvg).
--preview also writes a contact sheet: every icon at 16 / 24 / 48 px on a
light and a dark palette, plus 16 px at 4x, read back from the .ico files.

Shared motif: a rounded tile in a group colour with one white symbol on it.
Game-server components carry a small red rack badge in the bottom-right corner.
All shapes are drawn on a 24-unit grid; the tile fills the whole square so its
edges land on whole pixels at every size, and its corners leave the
bottom-left pixel transparent (Delphi takes that pixel as the transparent
colour when it ignores alpha).

A new component needs a symbol in symbols() (or an entry in SERVER_COPIES)
and a place in ORDER; the script stops if ORDER and the generated component
list (tools/gen_steam_api.py) differ.
"""
import math
import os
import shutil
import subprocess
import sys
import tempfile

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from gen_steam_api import PLUGINS, component_names  # noqa: E402  (no SDK needed)

W = "#FFFFFF"

# Group colours (tile fills). Mid-luminance so the tile reads on light and dark IDE themes.
CORE = "#1E2B42"      # TSteamAPI only, with a gold frame
SYSTEM = "#4C5F7D"    # Utils
IDENT = "#2462C7"     # user, friends, apps, stats, parental
CONTENT = "#D06A12"   # cloud, screenshots, timeline, workshop, music, web, inventory, video
PLAY = "#7442C2"      # input, lobbies, server browser, parties, remote play
NET = "#0E8585"       # networking
NET_OLD = "#6A8484"   # deprecated ISteamNetworking: same family, greyed
SERVER = "#C0352C"    # the game server itself, and the badge
GOLD = "#E9B53C"


def lighten(hex_colour, f):
    h = hex_colour.lstrip("#")
    r, g, b = (int(h[i:i + 2], 16) for i in (0, 2, 4))
    r, g, b = (round(c + (255 - c) * f) for c in (r, g, b))
    return f"#{r:02X}{g:02X}{b:02X}"


def tile(colour, gid):
    return (
        f'<defs><linearGradient id="{gid}" x1="0" y1="0" x2="0" y2="1">'
        f'<stop offset="0" stop-color="{lighten(colour, 0.16)}"/>'
        f'<stop offset="1" stop-color="{colour}"/></linearGradient></defs>'
        f'<rect x="0" y="0" width="24" height="24" rx="4.5" fill="url(#{gid})"/>'
    )


def gear_path(cx, cy, r_out, r_in, teeth, hole):
    pts = []
    step = 2 * math.pi / teeth
    for i in range(teeth):
        a = i * step - math.pi / 2
        for da, r in ((-0.30, r_in), (-0.17, r_out), (0.17, r_out), (0.30, r_in)):
            ang = a + da * step * 1.6
            pts.append((cx + r * math.cos(ang), cy + r * math.sin(ang)))
    d = "M" + " L".join(f"{x:.2f} {y:.2f}" for x, y in pts) + " Z"
    # hole as a second sub-path, drawn with fill-rule evenodd
    d += (f" M{cx + hole:.2f} {cy:.2f} A{hole} {hole} 0 1 0 {cx - hole:.2f} {cy:.2f}"
          f" A{hole} {hole} 0 1 0 {cx + hole:.2f} {cy:.2f} Z")
    return d


def person(cx, top, scale=1.0, fill=W, outline=None, ow=1.4):
    """Head + shoulders. top = y of the top of the head."""
    s = scale
    hr = 3.3 * s
    hy = top + hr
    sy = hy + hr + 0.9 * s
    bottom = sy + 6.4 * s
    sw = 6.6 * s
    body = (f"M{cx - sw:.2f} {bottom:.2f} C{cx - sw:.2f} {sy + 1.4 * s:.2f} {cx - 3.6 * s:.2f} {sy:.2f} {cx:.2f} {sy:.2f} "
            f"C{cx + 3.6 * s:.2f} {sy:.2f} {cx + sw:.2f} {sy + 1.4 * s:.2f} {cx + sw:.2f} {bottom:.2f} Z")
    out = ""
    if outline:
        out += (f'<circle cx="{cx}" cy="{hy:.2f}" r="{hr:.2f}" fill="{outline}" stroke="{outline}" stroke-width="{ow * 2}"/>'
                f'<path d="{body}" fill="{outline}" stroke="{outline}" stroke-width="{ow * 2}" stroke-linejoin="round"/>')
    out += f'<circle cx="{cx}" cy="{hy:.2f}" r="{hr:.2f}" fill="{fill}"/><path d="{body}" fill="{fill}"/>'
    return out


TROPHY = (
    f'<path d="M7.2 4.5 H16.8 V9.6 C16.8 12.9 14.7 14.8 12 14.8 C9.3 14.8 7.2 12.9 7.2 9.6 Z" fill="{W}"/>'
    f'<path d="M7.4 6.4 H4.6 V8.2 C4.6 10.3 5.9 11.6 7.9 11.8 M16.6 6.4 H19.4 V8.2 C19.4 10.3 18.1 11.6 16.1 11.8" '
    f'fill="none" stroke="{W}" stroke-width="1.7"/>'
    f'<rect x="10.8" y="14.3" width="2.4" height="3.2" fill="{W}"/>'
    f'<rect x="7.6" y="17.2" width="8.8" height="2.6" rx="0.8" fill="{W}"/>'
)


def symbols():
    """Class name -> (tile colour, symbol SVG). Symbols may use {T} for the tile colour."""
    s = {}

    # TSteamAPI: a valve handwheel (the "steam / valve" motif), framed in gold.
    spokes = "".join(
        f'<line x1="{12 + 2.2 * math.cos(a):.2f}" y1="{12 + 2.2 * math.sin(a):.2f}" '
        f'x2="{12 + 6.2 * math.cos(a):.2f}" y2="{12 + 6.2 * math.sin(a):.2f}" stroke="{W}" stroke-width="2"/>'
        for a in (math.radians(d) for d in (45, 135, 225, 315)))
    s["TSteamAPI"] = (CORE,
        f'<rect x="1.6" y="1.6" width="20.8" height="20.8" rx="3.3" fill="none" stroke="{GOLD}" stroke-width="1.5"/>'
        f'<circle cx="12" cy="12" r="6.6" fill="none" stroke="{W}" stroke-width="2.3"/>'
        + spokes +
        f'<circle cx="12" cy="12" r="2.4" fill="{GOLD}"/>')

    s["TSteamUtils"] = (SYSTEM,
        f'<path d="{gear_path(12, 12, 8.0, 6.0, 8, 2.6)}" fill="{W}" fill-rule="evenodd"/>')

    s["TSteamUser"] = (IDENT, person(12, 4.0, 1.0))

    s["TSteamFriends"] = (IDENT,
        person(15.3, 4.2, 0.82, fill=lighten(IDENT, 0.55))
        + person(9.6, 6.2, 0.88, outline="{T}", ow=0.9))

    apps = "".join(f'<rect x="{x}" y="{y}" width="6" height="6" rx="1.3" fill="{W}"/>'
                   for x in (4.5, 13.5) for y in (4.5, 13.5))
    s["TSteamApps"] = (IDENT, apps)

    s["TSteamUserStats"] = (IDENT, TROPHY)

    s["TSteamRemoteStorage"] = (CONTENT,
        f'<g fill="{W}"><circle cx="8.4" cy="13.4" r="3.9"/><circle cx="13.6" cy="10.4" r="5.1"/>'
        f'<circle cx="17.6" cy="14.2" r="3.2"/><rect x="5.6" y="13" width="14.4" height="4.4" rx="2.2"/>'
        f'<rect x="8.4" y="12" width="9.2" height="5.4"/></g>'
        f'<path d="M13 16.2 V11.2 M10.8 13.3 L13 11.1 L15.2 13.3" fill="none" stroke="{{T}}" '
        f'stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round"/>')

    s["TSteamScreenshots"] = (CONTENT,
        f'<rect x="8.2" y="5.4" width="4.6" height="3.2" rx="0.8" fill="{W}"/>'
        f'<rect x="3.6" y="7.6" width="16.8" height="11" rx="2" fill="{W}"/>'
        f'<circle cx="12" cy="13.1" r="3.7" fill="{{T}}"/><circle cx="12" cy="13.1" r="1.9" fill="{W}"/>'
        f'<circle cx="17.6" cy="10.1" r="0.9" fill="{{T}}"/>')

    s["TSteamTimeline"] = (CONTENT,
        f'<rect x="3" y="12.9" width="18" height="2.4" rx="1.2" fill="{W}"/>'
        f'<g fill="{W}"><circle cx="6.4" cy="14.1" r="2.5"/><circle cx="17.6" cy="14.1" r="2.5"/>'
        f'<rect x="10.9" y="4.4" width="2.2" height="10.9"/>'
        f'<path d="M8.8 3.8 H15.2 L12 7.4 Z"/></g>')

    s["TSteamUGC"] = (CONTENT,
        f'<path transform="translate(-0.9 -0.6)" fill="{W}" d="M5.5 8.2 H9.6 A2.5 2.5 0 1 1 14.4 8.2 '
        f'H18.5 V12.1 A2.5 2.5 0 1 1 18.5 16.9 V20.6 H5.5 Z"/>')

    s["TSteamInput"] = (PLAY,
        f'<path fill="{W}" d="M7.3 7.6 H16.7 C19.4 7.6 21.2 10.3 21.4 13.8 C21.6 17 20.4 18.9 18.5 18.9 '
        f'C16.9 18.9 16.1 17.4 15.1 16 H8.9 C7.9 17.4 7.1 18.9 5.5 18.9 C3.6 18.9 2.4 17 2.6 13.8 '
        f'C2.8 10.3 4.6 7.6 7.3 7.6 Z"/>'
        f'<path d="M5.6 12.4 H10 M7.8 10.2 V14.6" stroke="{{T}}" stroke-width="1.7"/>'
        f'<circle cx="17.4" cy="10.9" r="1.2" fill="{{T}}"/><circle cx="15.2" cy="13.2" r="1.2" fill="{{T}}"/>')

    s["TSteamMatchmaking"] = (PLAY,
        f'<path fill="{lighten(PLAY, 0.55)}" d="M10 4 H19.4 A1.6 1.6 0 0 1 21 5.6 V11.4 A1.6 1.6 0 0 1 19.4 13 '
        f'H18.4 V15.6 L15.6 13 H10 A1.6 1.6 0 0 1 8.4 11.4 V5.6 A1.6 1.6 0 0 1 10 4 Z"/>'
        f'<path fill="{W}" stroke="{{T}}" stroke-width="1.5" stroke-linejoin="round" '
        f'd="M4.6 8.4 H14 A1.6 1.6 0 0 1 15.6 10 V15.8 A1.6 1.6 0 0 1 14 17.4 H8.4 L5.6 20 V17.4 '
        f'H4.6 A1.6 1.6 0 0 1 3 15.8 V10 A1.6 1.6 0 0 1 4.6 8.4 Z"/>')

    s["TSteamMatchmakingServers"] = (PLAY,
        f'<g fill="{W}"><circle cx="5.4" cy="5.8" r="1.5"/><circle cx="5.4" cy="11" r="1.5"/>'
        f'<circle cx="5.4" cy="16.2" r="1.5"/></g>'
        f'<g stroke="{W}" stroke-width="2.2" stroke-linecap="round"><line x1="8.8" y1="5.8" x2="19" y2="5.8"/>'
        f'<line x1="8.8" y1="11" x2="12" y2="11"/><line x1="8.8" y1="16.2" x2="10.6" y2="16.2"/></g>'
        f'<circle cx="16.2" cy="14.4" r="3.6" fill="none" stroke="{W}" stroke-width="2.2"/>'
        f'<line x1="18.8" y1="17" x2="21" y2="19.2" stroke="{W}" stroke-width="2.8" stroke-linecap="round"/>')

    s["TSteamParties"] = (PLAY,
        f'<rect x="5" y="3.6" width="2.2" height="17" rx="1" fill="{W}"/>'
        f'<path fill="{W}" d="M7 4.6 H19.6 L16.6 8.9 L19.6 13.2 H7 Z"/>')

    s["TSteamMusic"] = (CONTENT,
        f'<g fill="{W}"><ellipse cx="7.6" cy="17.2" rx="2.9" ry="2.2" transform="rotate(-20 7.6 17.2)"/>'
        f'<ellipse cx="16.4" cy="15.2" rx="2.9" ry="2.2" transform="rotate(-20 16.4 15.2)"/>'
        f'<path d="M9.4 16.6 V6.6 L19.2 4.2 V14.6 H17.6 V8.4 L11 10 V16.6 Z"/></g>')

    s["TSteamHTTP"] = (CONTENT,
        f'<g fill="none" stroke="{W}" stroke-width="2"><circle cx="12" cy="12" r="7.6"/>'
        f'<ellipse cx="12" cy="12" rx="3.4" ry="7.6"/><line x1="4.4" y1="12" x2="19.6" y2="12"/></g>')

    s["TSteamHTMLSurface"] = (CONTENT,
        f'<rect x="3.6" y="5" width="16.8" height="14" rx="1.6" fill="none" stroke="{W}" stroke-width="1.8"/>'
        f'<rect x="3.6" y="5" width="16.8" height="4.4" rx="1.6" fill="{W}"/>'
        f'<g fill="{{T}}"><circle cx="6.4" cy="7.2" r="0.85"/><circle cx="8.9" cy="7.2" r="0.85"/></g>'
        f'<g stroke="{W}" stroke-width="1.6" stroke-linecap="round"><line x1="7" y1="12.6" x2="17" y2="12.6"/>'
        f'<line x1="7" y1="15.6" x2="13" y2="15.6"/></g>')

    s["TSteamInventory"] = (CONTENT,
        f'<path fill="{W}" d="M4 10.8 V9.2 C4 6.7 5.9 4.8 8.4 4.8 H15.6 C18.1 4.8 20 6.7 20 9.2 V10.8 Z"/>'
        f'<rect x="4" y="12.2" width="16" height="7.4" rx="1.2" fill="{W}"/>'
        f'<rect x="10.4" y="9.6" width="3.2" height="5" rx="0.7" fill="{{T}}"/>'
        f'<rect x="11.3" y="11.2" width="1.4" height="2" fill="{W}"/>')

    s["TSteamVideo"] = (CONTENT,
        f'<rect x="3" y="6.4" width="13" height="11.2" rx="2" fill="{W}"/>'
        f'<path fill="{W}" d="M17 10.6 L21.2 7.8 V16.2 L17 13.4 Z"/>'
        f'<path d="M7.6 9.2 L12.4 12 L7.6 14.8 Z" fill="{{T}}"/>')

    s["TSteamParentalSettings"] = (IDENT,
        f'<path fill="{W}" d="M12 3.6 L19.2 6.3 V11.6 C19.2 15.8 16.3 18.9 12 20.6 C7.7 18.9 4.8 15.8 4.8 11.6 V6.3 Z"/>'
        f'<circle cx="12" cy="10.6" r="2" fill="{{T}}"/><path d="M11 11 H13 L13.6 15.4 H10.4 Z" fill="{{T}}"/>')

    s["TSteamRemotePlay"] = (PLAY,
        f'<rect x="2.8" y="8.6" width="12.4" height="8.6" rx="1.2" fill="{W}"/>'
        f'<rect x="8.1" y="17" width="1.8" height="1.8" fill="{W}"/>'
        f'<rect x="5.8" y="18.6" width="6.4" height="1.6" rx="0.6" fill="{W}"/>'
        f'<g fill="none" stroke="{W}" stroke-width="2.1" stroke-linecap="round">'
        f'<path d="M16.2 5.6 A3.4 3.4 0 0 1 19.6 9"/><path d="M16.2 2.2 A6.8 6.8 0 0 1 23 9" transform="translate(-1.6 1.2)"/></g>')

    s["TSteamNetworking"] = (NET_OLD,
        f'<line x1="7" y1="17" x2="17" y2="7" stroke="{W}" stroke-width="2.2"/>'
        f'<circle cx="6.4" cy="17.6" r="3" fill="{W}"/><circle cx="17.6" cy="6.4" r="3" fill="{W}"/>')

    s["TSteamNetworkingSockets"] = (NET,
        f'<g transform="rotate(-45 12 12)">'
        f'<rect x="10.9" y="14" width="2.2" height="9" fill="{W}"/>'
        f'<path fill="{W}" d="M6.6 8.6 H17.4 V12.2 C17.4 14.6 15.4 16.4 12 16.4 C8.6 16.4 6.6 14.6 6.6 12.2 Z"/>'
        f'<rect x="8.4" y="2.6" width="2.4" height="6.6" rx="0.7" fill="{W}"/>'
        f'<rect x="13.2" y="2.6" width="2.4" height="6.6" rx="0.7" fill="{W}"/></g>')

    s["TSteamNetworkingMessages"] = (NET,
        f'<rect x="3.4" y="6" width="17.2" height="12" rx="1.4" fill="{W}"/>'
        f'<path d="M4.4 7.2 L12 12.9 L19.6 7.2" fill="none" stroke="{{T}}" stroke-width="1.6" stroke-linejoin="round"/>')

    s["TSteamNetworkingUtils"] = (NET,
        "".join(f'<rect x="{x}" y="{top}" width="3" height="{19.6 - top}" rx="0.8" fill="{W}"/>'
                for x, top in ((3.8, 15), (8.4, 11.4), (13, 7.8), (17.6, 4.2))))

    rack = "".join(
        f'<rect x="4.2" y="{y}" width="15.6" height="4.6" rx="1.1" fill="{W}"/>'
        f'<rect x="6.2" y="{y + 1.5}" width="1.6" height="1.6" fill="{{T}}"/>'
        f'<rect x="9.4" y="{y + 1.5}" width="1.6" height="1.6" fill="{{T}}"/>'
        for y in (3.8, 9.7, 15.6))
    s["TSteamGameServer"] = (SERVER, rack)

    return s


# Server badge: a small red rack with a white rim, bottom-right corner.
BADGE = (
    f'<rect x="13.2" y="13.6" width="10.2" height="9.8" rx="2" fill="{SERVER}" stroke="{W}" stroke-width="1.3"/>'
    f'<g stroke="{W}" stroke-width="1.35" stroke-linecap="round">'
    f'<line x1="15.7" y1="16.9" x2="20.9" y2="16.9"/><line x1="15.7" y1="20.1" x2="20.9" y2="20.1"/></g>'
)

# Game-server copies: client symbol + badge. GameServerStats is the trophy + badge.
SERVER_COPIES = {
    "TSteamGameServerStats": "TSteamUserStats",
    "TSteamGameServerUtils": "TSteamUtils",
    "TSteamGameServerNetworking": "TSteamNetworking",
    "TSteamGameServerNetworkingSockets": "TSteamNetworkingSockets",
    "TSteamGameServerNetworkingMessages": "TSteamNetworkingMessages",
    "TSteamGameServerHTTP": "TSteamHTTP",
    "TSteamGameServerUGC": "TSteamUGC",
    "TSteamGameServerInventory": "TSteamInventory",
}

ORDER = [
    "TSteamAPI", "TSteamUtils", "TSteamUser", "TSteamFriends", "TSteamApps", "TSteamUserStats",
    "TSteamRemoteStorage", "TSteamScreenshots", "TSteamTimeline", "TSteamUGC", "TSteamInput",
    "TSteamMatchmaking", "TSteamMatchmakingServers", "TSteamParties", "TSteamMusic", "TSteamHTTP",
    "TSteamHTMLSurface", "TSteamInventory", "TSteamVideo", "TSteamParentalSettings", "TSteamRemotePlay",
    "TSteamNetworking", "TSteamNetworkingSockets", "TSteamNetworkingMessages", "TSteamNetworkingUtils",
    "TSteamGameServer", "TSteamGameServerStats", "TSteamGameServerUtils", "TSteamGameServerNetworking",
    "TSteamGameServerNetworkingSockets", "TSteamGameServerNetworkingMessages", "TSteamGameServerHTTP",
    "TSteamGameServerUGC", "TSteamGameServerInventory",
]

SIZES = [16, 24, 32, 36, 48, 64, 256]


def svg_doc(body):
    return ('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" width="24" height="24">'
            + body + "</svg>\n")


def build_svgs():
    sym = symbols()
    out = {}
    for name in ORDER:
        badge = name in SERVER_COPIES
        colour, body = sym[SERVER_COPIES.get(name, name)]
        gid = "g" + name
        doc = tile(colour, gid) + body.replace("{T}", colour)
        if badge:
            doc += BADGE
        out[name] = svg_doc(doc)
    # the badge alone, on a transparent canvas, for compositing in the repository
    out["ServerBadge"] = svg_doc(BADGE)
    return out


def write_ico(path, frames):
    """Write an .ico by hand: 32-bit BGRA DIB frames (with AND mask) up to 64 px,
    PNG-compressed for 256 px - the layout Windows' own icons use, and the one every
    resource compiler (brcc32, rc, windres, lazres) reads."""
    import io
    import struct
    blobs = []
    for im in frames:
        w, h = im.size
        if w >= 256:
            buf = io.BytesIO()
            im.save(buf, format="PNG")
            blobs.append(buf.getvalue())
            continue
        header = struct.pack("<IiiHHIIiiII", 40, w, h * 2, 1, 32, 0, 0, 0, 0, 0, 0)
        px = im.load()
        rows = []
        for y in range(h - 1, -1, -1):  # bottom-up
            rows.append(b"".join(struct.pack("BBBB", px[x, y][2], px[x, y][1], px[x, y][0], px[x, y][3])
                                 for x in range(w)))
        stride = ((w + 31) // 32) * 4
        mask_rows = []
        for y in range(h - 1, -1, -1):
            bits = bytearray(stride)
            for x in range(w):
                if px[x, y][3] == 0:
                    bits[x // 8] |= 0x80 >> (x % 8)
            mask_rows.append(bytes(bits))
        blobs.append(header + b"".join(rows) + b"".join(mask_rows))
    out = struct.pack("<HHH", 0, 1, len(frames))
    offset = 6 + 16 * len(frames)
    for im, blob in zip(frames, blobs):
        w, h = im.size
        out += struct.pack("<BBBBHHII", w % 256, h % 256, 0, 0, 1, 32, len(blob), offset)
        offset += len(blob)
    with open(path, "wb") as f:
        f.write(out + b"".join(blobs))


def render(svg_path, size, png_path):
    subprocess.run(["rsvg-convert", "-w", str(size), "-h", str(size), "-o", png_path, svg_path], check=True)


# ---- application icons: the task bar / dock icon of each program -----------
# Same style as the palette icons (a rounded tile, one white symbol), one
# colour per program family; the twins of a program share its icon. Each
# drawing takes "small": the 16 px frame gets a simpler one where the full
# drawing would turn to mush at that size. Owner 2026-11-05: LogReceiver an
# ear; then the demos, the three VirtualGamepads, SteamDemoPad and
# SteamInputDemo.
APP_ICO_SIZES = [16, 24, 32, 48, 64, 256]


def app_tile(top, bottom):
    return (f'<defs><linearGradient id="g" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="{top}"/>'
            f'<stop offset="1" stop-color="{bottom}"/></linearGradient></defs>'
            '<rect x="0" y="0" width="24" height="24" rx="5" fill="url(#g)"/>')


def app_wheel(cx, cy, r, stroke=2.3):
    """The valve handwheel (TSteamAPI's palette motif): the library's hub."""
    spokes = "".join(
        f'<line x1="{cx + 0.36 * r * math.cos(a):.2f}" y1="{cy + 0.36 * r * math.sin(a):.2f}" '
        f'x2="{cx + r * math.cos(a):.2f}" y2="{cy + r * math.sin(a):.2f}" stroke="{W}" '
        f'stroke-width="{stroke * 0.85:.2f}" stroke-linecap="round"/>'
        for a in (math.radians(d) for d in (45, 135, 225, 315)))
    return (f'<circle cx="{cx}" cy="{cy}" r="{r}" fill="none" stroke="{W}" stroke-width="{stroke}"/>' + spokes
            + f'<circle cx="{cx}" cy="{cy}" r="{0.38 * r:.2f}" fill="{GOLD}"/>')


def app_pad(tx, ty, scale, fill, cut):
    """A gamepad (the TSteamInput palette symbol), cut-outs in colour cut."""
    return (f'<g transform="translate({tx} {ty}) scale({scale})">'
            f'<path fill="{fill}" d="M7.3 7.6 H16.7 C19.4 7.6 21.2 10.3 21.4 13.8 C21.6 17 20.4 18.9 18.5 18.9 '
            'C16.9 18.9 16.1 17.4 15.1 16 H8.9 C7.9 17.4 7.1 18.9 5.5 18.9 C3.6 18.9 2.4 17 2.6 13.8 '
            'C2.8 10.3 4.6 7.6 7.3 7.6 Z"/>'
            f'<path d="M5.6 12.4 H10 M7.8 10.2 V14.6" stroke="{cut}" stroke-width="1.7" stroke-linecap="round"/>'
            f'<circle cx="17.4" cy="10.9" r="1.2" fill="{cut}"/><circle cx="15.2" cy="13.2" r="1.2" fill="{cut}"/></g>')


def app_svg(body):
    return '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" width="24" height="24">' + body + "</svg>\n"


APP_NAVY = ("#3A5A8C", "#1E3157")


def ear_svg(small):
    """LogReceiver: a right ear seen from the side - the rim round the top and
    back down to the lobe, the fold inside, the opening facing left, where two
    yellow sound waves come in. At 16 px no waves, the ear centred (with them
    it read as a "3")."""
    waves = not small
    tile = ('<defs><linearGradient id="g" x1="0" y1="0" x2="0" y2="1">'
            '<stop offset="0" stop-color="#7B5CE6"/><stop offset="1" stop-color="#5636C9"/></linearGradient></defs>'
            '<rect x="0" y="0" width="24" height="24" rx="5" fill="url(#g)"/>')
    shift = '' if waves else ' transform="translate(-2.6 0.4)"'
    ear = (f'<g{shift} fill="none" stroke="#FFFFFF" stroke-linecap="round" stroke-linejoin="round">'
           '<path stroke-width="2.3" d="M9.6 9.6 C9.6 6.3 12 4.3 14.6 4.3 C17.6 4.3 19.6 6.6 19.6 9.6 '
           'C19.6 12.4 17.9 13.5 16.9 14.6 C15.9 15.7 16.1 17.2 15.2 18.6 C14.2 20.1 11.9 20.4 10.7 18.9"/>'
           '<path stroke-width="1.9" d="M12.6 10 C12.6 8.5 13.6 7.6 14.7 7.6 C15.9 7.6 16.7 8.6 16.7 9.7 '
           'C16.7 11.1 15.4 11.6 14.8 12.6 C14.4 13.3 14.6 14.3 13.7 14.6"/></g>')
    sound = ('<g fill="none" stroke="#FFD43B" stroke-linecap="round" stroke-width="1.7">'
             '<path d="M6.4 9.4 A3.6 3.6 0 0 1 6.4 14.6"/><path d="M3.6 7.4 A6.6 6.6 0 0 1 3.6 16.6"/></g>'
             if waves else '')
    return ('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" width="24" height="24">'
            + tile + sound + ear + '</svg>\n')


def steamdemo_svg(small):
    """SteamDemo (FMX, VCL, LCL): the valve handwheel on navy."""
    return app_svg(app_tile(*APP_NAVY) + app_wheel(12, 12, 7.2 if small else 6.8))


def steamdemopad_svg(small):
    """SteamDemoPad: SteamDemo driven by a pad - the handwheel with a green
    gamepad badge; at 16 px only the gamepad, on SteamDemo's navy."""
    if small:
        return app_svg(app_tile(*APP_NAVY) + app_pad(0, 0, 1.0, W, APP_NAVY[1]))
    badge = ('<rect x="10.6" y="12.2" width="12.4" height="10.6" rx="3" fill="#2E9E5B" stroke="#FFFFFF" '
             'stroke-width="1.1"/>' + app_pad(10.7, 10.4, 0.52, W, "#2E9E5B"))
    return app_svg(app_tile(*APP_NAVY) + app_wheel(9.4, 9.4, 5.6, stroke=2.1) + badge)


def steaminputdemo_svg(small):
    """SteamInputDemo: Steam Input's actions - a D-pad and the four face
    buttons, on orange."""
    face = "".join(f'<circle cx="{x}" cy="{y}" r="{1.9 if small else 1.75}" fill="{W}"/>'
                   for x, y in ((17, 8.4), (20.2, 12), (17, 15.6), (13.8, 12)))
    cross = '<path fill="#FFFFFF" d="M5.4 7.2 H8.6 V10.4 H11.8 V13.6 H8.6 V16.8 H5.4 V13.6 H2.2 V10.4 H5.4 Z"/>'
    return app_svg(app_tile("#F08A2C", "#C25E0E") + cross + face)


def virtualgamepad_svg(small):
    """The three VirtualGamepads: a gamepad on teal with one button glowing
    (the demos' glow); no glow at 16 px."""
    teal = ("#17A3A8", "#0B6A70")
    glow = ('' if small else '<g transform="translate(0 -1.0)"><circle cx="17.4" cy="10.9" r="3.2" '
            'fill="#7FF3FF" fill-opacity="0.55"/><circle cx="17.4" cy="10.9" r="1.35" fill="#7FF3FF"/></g>')
    return app_svg(app_tile(*teal) + app_pad(0, -0.8 if small else -1.0, 1.0, W, teal[1]) + glow)


# drawing -> the programs that use it: (folder, file name without extension,
# also an .icns for macOS - the FMX projects, which build for macOS).
# The Delphi .dproj names <name>.ico (Icon_MainIcon) and <name>.icns
# (Icns_MainIcns); a Lazarus .lpi takes <name>.ico by its own convention
# (<Icon Value="0"/>).
APP_ICONS = [
    (ear_svg, [("RemoteLogging/LogReceiver", "LogReceiver", True)]),
    (steamdemo_svg, [("demos/SteamDemo", "SteamDemo", True), ("demos/SteamDemoVCL", "SteamDemoVCL", False),
                     ("demos/SteamDemoLCL", "SteamDemoLCL", False)]),
    (steamdemopad_svg, [("demos/SteamDemoPad", "SteamDemoPad", True)]),
    (steaminputdemo_svg, [("demos/SteamInputDemo", "SteamInputDemo", True)]),
    (virtualgamepad_svg, [("demos/VirtualGamepad", "VirtualGamepad", True),
                          ("demos/VirtualGamepadVCL", "VirtualGamepadVCL", False),
                          ("demos/VirtualGamepadLCL", "VirtualGamepadLCL", False)]),
]


def build_app_icons():
    """Every program's .ico (and .icns where it builds for macOS)."""
    for draw, targets in APP_ICONS:
        with tempfile.TemporaryDirectory() as tmp:
            frames = {}
            for size in APP_ICO_SIZES + [128, 512, 1024]:
                svg_path = os.path.join(tmp, f"app{size}.svg")
                with open(svg_path, "w", newline="\n") as f:
                    f.write(draw(size <= 16))
                png = os.path.join(tmp, f"app{size}.png")
                render(svg_path, size, png)
                frames[size] = Image.open(png).convert("RGBA")
            for folder, name, icns in targets:
                out = os.path.join(ROOT, *folder.split("/"))
                write_ico(os.path.join(out, name + ".ico"), [frames[s] for s in APP_ICO_SIZES])
                if icns:
                    # Pillow makes every .icns size from the largest image
                    frames[1024].save(os.path.join(out, name + ".icns"), format="ICNS")
                print("wrote", f"{folder}/{name}.ico" + (" and .icns" if icns else ""))


def ico_frame(path, size):
    im = Image.open(path)
    im.size = (size, size)  # selects the frame of that size
    im.load()
    return im.convert("RGBA")


def preview(icodir, out):
    """Contact sheet of every icon, read back from the .ico files."""
    from PIL import ImageDraw, ImageFont
    try:
        font = ImageFont.truetype("DejaVuSansCondensed.ttf", 13)
        bold = ImageFont.truetype("DejaVuSans-Bold.ttf", 15)
    except OSError:
        font = bold = ImageFont.load_default()
    cols, cell_w, cell_h = 2, 560, 84
    rows = (len(ORDER) + cols - 1) // cols
    themes = (("light", (240, 240, 240), (30, 30, 30)), ("dark", (43, 43, 48), (225, 225, 225)))
    sheet = Image.new("RGBA", (cols * cell_w, 40 + rows * cell_h * 2 + 60), (255, 255, 255, 255))
    d = ImageDraw.Draw(sheet)
    y0 = 10
    for theme, bg, fg in themes:
        d.text((12, y0), f"{theme} theme: 16 / 24 / 48 px as stored, then 16 px at 4x", font=bold,
               fill=(30, 30, 30))
        top = y0 + 26
        d.rectangle([0, top, sheet.width, top + rows * cell_h], fill=bg)
        for i, name in enumerate(ORDER):
            x, y = (i % cols) * cell_w + 12, top + (i // cols) * cell_h + 10
            ico = os.path.join(icodir, name + ".ico")
            px = x
            for size in (16, 24, 48):
                sheet.alpha_composite(ico_frame(ico, size), (px, y + (48 - size) // 2 + 8))
                px += size + 14
            sheet.alpha_composite(ico_frame(ico, 16).resize((64, 64), Image.NEAREST), (px + 6, y))
            d.text((px + 84, y + 24), name, font=font, fill=fg)
        y0 = top + rows * cell_h + 12
    sheet.convert("RGB").save(out)
    print("wrote", out)


def main():
    expected = ["TSteamAPI"] + component_names(list(PLUGINS.values()))
    if sorted(expected) != sorted(ORDER):
        sys.exit("ORDER does not match the generated components:\n  missing: "
                 + ", ".join(sorted(set(expected) - set(ORDER)))
                 + "\n  extra: " + ", ".join(sorted(set(ORDER) - set(expected))))
    if shutil.which("rsvg-convert") is None:
        sys.exit("rsvg-convert not found (librsvg): it renders the SVG sources")
    icodir = os.path.join(ROOT, "design", "icons")
    svgdir = os.path.join(icodir, "svg")
    os.makedirs(svgdir, exist_ok=True)
    with tempfile.TemporaryDirectory() as tmp:
        for name, doc in build_svgs().items():
            svg_path = os.path.join(svgdir, name + ".svg")
            with open(svg_path, "w", newline="\n") as f:
                f.write(doc)
            frames = []
            for size in SIZES:
                png = os.path.join(tmp, f"{name}_{size}.png")
                render(svg_path, size, png)
                frames.append(Image.open(png).convert("RGBA"))
            write_ico(os.path.join(icodir, name + ".ico"), frames)
    print("wrote", len(ORDER), "icons + ServerBadge to design/icons")
    build_app_icons()
    if "--preview" in sys.argv:
        preview(icodir, sys.argv[sys.argv.index("--preview") + 1])


if __name__ == "__main__":
    main()
