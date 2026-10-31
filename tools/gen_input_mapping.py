#!/usr/bin/env python3
"""Writes a Steam Input action manifest and one default layout per
controller type from ONE table of action sets, actions and bindings.

    python3 tools/gen_input_mapping.py

Output (demos/SteamInputDemo/src/): steam_input_manifest.vdf and
controller_<type>.vdf for every type in CONTROLLERS. Never edit those
files by hand: change the tables here and run the script again.

The format follows layouts exported by Steam (dev mode, "Export layout",
steam://dumpcontrollerconfig) and Valve's SpaceWar sample:

* manifest: "Action Manifest" { configurations, actions, localization } -
  NO comments (a manifest that started with // comment lines did not work),
  tabs, CRLF;
* layout: "controller_mappings" { version 3, title / description tokens,
  controller_type, revisions, the manifest's actions + localization again,
  then "group" blocks (id, mode, inputs with activators -> bindings
  "game_action <set> <action>", or "gameactions" { <set> <action> } for an
  analog action on the whole group) and one "preset" per action set
  mapping group ids to physical sources ("joystick active", ...).

Physical sources (the same names on every pad family, positional like the
3D models: button_a is the BOTTOM face button on Xbox, PlayStation and
Switch alike): joystick / right_joystick (sticks), button_diamond (face
buttons button_a .. button_y), left_trigger / right_trigger (inputs edge =
full pull, click), switch (inputs left_bumper, right_bumper, button_escape
= Start / Menu / Options, button_menu = Back / View / Create,
button_back_left / _right = back grips), dpad, left_trackpad /
right_trackpad (Steam Controller, Steam Deck), gyro.

This is the core of the planned mapping tool (CLAUDE.md, "PROJECT AIM"):
there the tables come from the user pressing buttons.
"""
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "demos", "SteamInputDemo", "src")

TITLE = "SteamInputDemo default layout"
DESCRIPTION = "Default bindings for the TSteamAPI Steam Input test (AppID 2275430)."

# Action sets: name -> (title token, [(kind, action, title token, input_mode)])
# kind: "stick" (StickPadGyro), "trigger" (AnalogTrigger), "button" (Button)
SETS = [
    ("InGame", "#Set_InGame", [
        ("stick", "Move", "#Action_Move", "joystick_move"),
        ("stick", "Camera", "#Action_Camera", "absolute_mouse"),
        ("trigger", "Throttle", "#Action_Throttle", None),
        ("button", "Fire", "#Action_Fire", None),
        ("button", "Jump", "#Action_Jump", None),
        ("button", "Menu", "#Action_Menu", None),
    ]),
    ("Menu", "#Set_Menu", [
        ("button", "Select", "#Action_Select", None),
        ("button", "Back", "#Action_Back", None),
    ]),
]

LOCALIZATION = {"english": [
    ("Set_InGame", "In game"), ("Set_Menu", "Menu"),
    ("Action_Move", "Move"), ("Action_Camera", "Camera"), ("Action_Throttle", "Throttle"),
    ("Action_Fire", "Fire"), ("Action_Jump", "Jump"), ("Action_Menu", "Open menu"),
    ("Action_Select", "Select"), ("Action_Back", "Back to game"),
]}

# Default bindings per set: (source, input or None, action). input None =
# the whole source drives an analog action ("gameactions").
# "camera_source" is replaced per controller (no right stick on the 2015
# Steam Controller: its right trackpad).
BINDINGS = {
    "InGame": [
        ("joystick", None, "Move"),
        ("camera_source", None, "Camera"),
        ("right_trigger", None, "Throttle"),
        ("button_diamond", "button_a", "Fire"),
        ("button_diamond", "button_b", "Jump"),
        ("switch", "button_escape", "Menu"),
    ],
    "Menu": [
        ("button_diamond", "button_a", "Select"),
        ("button_diamond", "button_b", "Back"),
    ],
}

# Group mode of each source when a layout is generated
MODES = {"joystick": "joystick_move", "right_joystick": "joystick_move", "button_diamond": "four_buttons",
         "left_trigger": "trigger", "right_trigger": "trigger", "switch": "switches", "dpad": "dpad",
         "left_trackpad": "dpad", "right_trackpad": "absolute_mouse"}
STANDARD = ["switch", "button_diamond", "left_trigger", "right_trigger", "joystick", "right_joystick", "dpad"]
# controller type -> (sources present, source used for "camera_source")
CONTROLLERS = {
    "controller_xboxone": (STANDARD, "right_joystick"),
    "controller_xbox360": (STANDARD, "right_joystick"),
    "controller_ps5": (STANDARD, "right_joystick"),
    "controller_ps4": (STANDARD, "right_joystick"),
    "controller_switch_pro": (STANDARD, "right_joystick"),
    "controller_neptune": (STANDARD, "right_joystick"),
    "controller_steamcontroller_gordon": (["switch", "button_diamond", "left_trigger", "right_trigger",
                                          "joystick", "left_trackpad", "right_trackpad"], "right_trackpad"),
}


class W:
    """VDF writer: tabs, "key"<tab><tab>"value", CRLF."""
    def __init__(self):
        self.lines, self.depth = [], 0

    def kv(self, k, v):
        self.lines.append("\t" * self.depth + f'"{k}"\t\t"{v}"')

    def open(self, k):
        self.lines.append("\t" * self.depth + f'"{k}"')
        self.lines.append("\t" * self.depth + "{")
        self.depth += 1

    def close(self):
        self.depth -= 1
        self.lines.append("\t" * self.depth + "}")

    def text(self):
        assert self.depth == 0
        return "\r\n".join(self.lines) + "\r\n"


def write_actions(w):
    w.open("actions")
    for name, title, acts in SETS:
        w.open(name)
        w.kv("title", title)
        for kind, block in (("stick", "StickPadGyro"), ("trigger", "AnalogTrigger"), ("button", "Button")):
            items = [a for a in acts if a[0] == kind]
            if not items:
                continue
            w.open(block)
            for _, act, atitle, mode in items:
                if kind == "stick":
                    w.open(act)
                    w.kv("title", atitle)
                    w.kv("input_mode", mode)
                    w.close()
                else:
                    w.kv(act, atitle)
            w.close()
        w.close()
    w.close()


def write_localization(w):
    w.open("localization")
    for lang, items in LOCALIZATION.items():
        w.open(lang)
        w.kv("title", TITLE)
        w.kv("description", DESCRIPTION)
        for k, v in items:
            w.kv(k, v)
        w.close()
    w.close()


def manifest():
    w = W()
    w.open("Action Manifest")
    w.open("configurations")
    for ctype in CONTROLLERS:
        w.open(ctype)
        w.open("0")
        w.kv("path", ctype + ".vdf")
        w.close()
        w.close()
    w.close()
    write_actions(w)
    write_localization(w)
    w.close()
    return w.text()


def layout(ctype):
    sources, camera = CONTROLLERS[ctype]
    w = W()
    w.open("controller_mappings")
    for k, v in (("version", "3"), ("revision", "1"), ("title", "#title"), ("description", "#description"),
                 ("controller_type", ctype), ("major_revision", "0"), ("minor_revision", "0"),
                 ("Timestamp", "0")):
        w.kv(k, v)
    write_actions(w)
    write_localization(w)
    gid = 0
    presets = []
    for set_name, _, _ in SETS:
        binds = [(camera if s == "camera_source" else s, i, a) for s, i, a in BINDINGS.get(set_name, [])]
        unknown = [s for s, _, _ in binds if s not in sources]
        assert not unknown, f"{ctype}: {set_name} binds missing source(s) {unknown}"
        psrc = []
        for src in sources:
            mine = [(i, a) for s, i, a in binds if s == src]
            w.open("group")
            w.kv("id", str(gid))
            w.kv("mode", MODES[src])
            w.open("inputs")
            for inp, act in mine:
                if inp is None:
                    continue
                w.open(inp)
                w.open("activators")
                w.open("Full_Press")
                w.open("bindings")
                w.kv("binding", f"game_action {set_name} {act}")
                w.close()
                w.close()
                w.close()
                w.close()
            w.close()
            whole = [a for i, a in mine if i is None]
            if whole:
                w.open("settings")
                w.kv("virtual_mode", "1")
                w.close()
                w.open("gameactions")
                w.kv(set_name, whole[0])
                w.close()
            w.close()
            psrc.append((gid, src))
            gid += 1
        presets.append((set_name, psrc))
    for pid, (set_name, psrc) in enumerate(presets):
        w.open("preset")
        w.kv("id", str(pid))
        w.kv("name", set_name)
        w.open("group_source_bindings")
        for g, src in psrc:
            w.kv(str(g), f"{src} active")
        w.close()
        w.close()
    w.open("settings")
    w.close()
    w.close()
    return w.text()


def write(name, text):
    path = os.path.join(OUT, name)
    data = text.encode("ascii")
    old = open(path, "rb").read() if os.path.exists(path) else None
    if old != data:
        open(path, "wb").write(data)
        print("wrote", os.path.relpath(path, ROOT))
    else:
        print("unchanged", os.path.relpath(path, ROOT))


def main():
    write("steam_input_manifest.vdf", manifest())
    for ctype in CONTROLLERS:
        write(ctype + ".vdf", layout(ctype))


if __name__ == "__main__":
    main()
