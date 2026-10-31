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

Every pad gets the same bindings (one InGame action per physical
control, see SETS); layout() refuses to write a layout in which a
non-optional action is unbound. The gyro (mode gyro_to_mouse, as Steam
writes it; always on) is its own action, Gyro, on every pad with motion
sensors.

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
#
# InGame has ONE ACTION PER PHYSICAL CONTROL, named by position with the
# Xbox letters (ButtonA = the bottom face button on every pad: Xbox A,
# PlayStation Cross, Nintendo B), so every pad reports the same actions for
# the same place on the pad (owner, 2026-10-31: consistency across pads is
# extremely important). The Guide / PS / Home / Steam button is reserved by
# Steam and cannot be bound.
SETS = [
    ("InGame", "#Set_InGame", [
        ("stick", "LeftStick", "#Action_LeftStick", "joystick_move"),
        ("stick", "RightStick", "#Action_RightStick", "joystick_move"),
        ("stick", "Gyro", "#Action_Gyro", "absolute_mouse"),
        ("stick", "LeftTrackpad", "#Action_LeftTrackpad", "joystick_move"),
        ("stick", "RightTrackpad", "#Action_RightTrackpad", "joystick_move"),
        ("stick", "CenterTrackpad", "#Action_CenterTrackpad", "joystick_move"),
        ("trigger", "LeftTrigger", "#Action_LeftTrigger", None),
        ("trigger", "RightTrigger", "#Action_RightTrigger", None),
        ("button", "ButtonA", "#Action_ButtonA", None),
        ("button", "ButtonB", "#Action_ButtonB", None),
        ("button", "ButtonX", "#Action_ButtonX", None),
        ("button", "ButtonY", "#Action_ButtonY", None),
        ("button", "LeftBumper", "#Action_LeftBumper", None),
        ("button", "RightBumper", "#Action_RightBumper", None),
        ("button", "LeftStickClick", "#Action_LeftStickClick", None),
        ("button", "RightStickClick", "#Action_RightStickClick", None),
        ("button", "DPadUp", "#Action_DPadUp", None),
        ("button", "DPadDown", "#Action_DPadDown", None),
        ("button", "DPadLeft", "#Action_DPadLeft", None),
        ("button", "DPadRight", "#Action_DPadRight", None),
        ("button", "Start", "#Action_Start", None),
        ("button", "Select", "#Action_Select", None),
        ("button", "BackLeft", "#Action_BackLeft", None),
        ("button", "BackRight", "#Action_BackRight", None),
        ("button", "BackLeftUpper", "#Action_BackLeftUpper", None),
        ("button", "BackRightUpper", "#Action_BackRightUpper", None),
        ("button", "LeftTrackpadClick", "#Action_LeftTrackpadClick", None),
        ("button", "RightTrackpadClick", "#Action_RightTrackpadClick", None),
        ("button", "CenterTrackpadClick", "#Action_CenterTrackpadClick", None),
    ]),
    ("Menu", "#Set_Menu", [
        ("button", "MenuConfirm", "#Action_MenuConfirm", None),
        ("button", "MenuBack", "#Action_MenuBack", None),
    ]),
]

LOCALIZATION = {"english": [
    ("Set_InGame", "Every control"), ("Set_Menu", "Menu"),
    ("Action_LeftStick", "Left stick"), ("Action_RightStick", "Right stick"),
    ("Action_Gyro", "Gyro (motion sensors, reported as mouse movement)"),
    ("Action_LeftTrackpad", "Left trackpad"), ("Action_RightTrackpad", "Right trackpad"),
    ("Action_CenterTrackpad", "Touchpad (PlayStation)"),
    ("Action_LeftTrackpadClick", "Left trackpad press"), ("Action_RightTrackpadClick", "Right trackpad press"),
    ("Action_CenterTrackpadClick", "Touchpad press (PlayStation)"),
    ("Action_LeftTrigger", "Left trigger"), ("Action_RightTrigger", "Right trigger"),
    ("Action_ButtonA", "Bottom face button (A / Cross / Nintendo B)"),
    ("Action_ButtonB", "Right face button (B / Circle / Nintendo A)"),
    ("Action_ButtonX", "Left face button (X / Square / Nintendo Y)"),
    ("Action_ButtonY", "Top face button (Y / Triangle / Nintendo X)"),
    ("Action_LeftBumper", "Left shoulder"), ("Action_RightBumper", "Right shoulder"),
    ("Action_LeftStickClick", "Left stick press"), ("Action_RightStickClick", "Right stick press"),
    ("Action_DPadUp", "D-pad up"), ("Action_DPadDown", "D-pad down"),
    ("Action_DPadLeft", "D-pad left"), ("Action_DPadRight", "D-pad right"),
    ("Action_Start", "Start / Menu / Options (with the right trigger: menu set)"),
    ("Action_Select", "Select / View / Create"),
    ("Action_BackLeft", "Left back paddle"), ("Action_BackRight", "Right back paddle"),
    ("Action_BackLeftUpper", "Upper left back paddle"), ("Action_BackRightUpper", "Upper right back paddle"),
    ("Action_MenuConfirm", "Confirm"), ("Action_MenuBack", "Back (with Confirm: back to every control)"),
]}

# Default bindings per set: (source, input or None, action). input None =
# the whole source drives an analog action ("gameactions"). Sources are the
# names a pad with two sticks and a d-pad uses; a controller's "replace"
# maps them to what it has instead (the 2015 Steam Controller: right
# trackpad for the right stick, left trackpad for the d-pad).
BINDINGS = {
    "InGame": [
        ("joystick", None, "LeftStick"),
        ("right_joystick", None, "RightStick"),
        ("gyro", None, "Gyro"),
        ("left_trigger", None, "LeftTrigger"),
        ("right_trigger", None, "RightTrigger"),
        ("button_diamond", "button_a", "ButtonA"),
        ("button_diamond", "button_b", "ButtonB"),
        ("button_diamond", "button_x", "ButtonX"),
        ("button_diamond", "button_y", "ButtonY"),
        ("switch", "left_bumper", "LeftBumper"),
        ("switch", "right_bumper", "RightBumper"),
        ("joystick", "click", "LeftStickClick"),
        ("right_joystick", "click", "RightStickClick"),
        ("dpad", "dpad_north", "DPadUp"),
        ("dpad", "dpad_south", "DPadDown"),
        ("dpad", "dpad_west", "DPadLeft"),
        ("dpad", "dpad_east", "DPadRight"),
        ("switch", "button_escape", "Start"),
        ("switch", "button_menu", "Select"),
        ("switch", "button_back_left", "BackLeft"),
        ("switch", "button_back_right", "BackRight"),
        ("switch", "button_back_left_upper", "BackLeftUpper"),
        ("switch", "button_back_right_upper", "BackRightUpper"),
        ("left_trackpad", None, "LeftTrackpad"),
        ("left_trackpad", "click", "LeftTrackpadClick"),
        ("right_trackpad", None, "RightTrackpad"),
        ("right_trackpad", "click", "RightTrackpadClick"),
        ("center_trackpad", None, "CenterTrackpad"),
        ("center_trackpad", "click", "CenterTrackpadClick"),
    ],
    "Menu": [
        ("button_diamond", "button_a", "MenuConfirm"),
        ("button_diamond", "button_b", "MenuBack"),
    ],
}

# Actions that only some pads have: the source they need, or the number of
# back paddles. Every OTHER action must be bound on every controller below -
# layout() checks it, so no pad silently lacks a control. A trackpad that
# stands in for a missing stick / d-pad ("replace", 2015 Steam Controller)
# is not ALSO bound as a trackpad.
OPTIONAL = {"Gyro": "gyro", "BackLeft": 2, "BackRight": 2, "BackLeftUpper": 4, "BackRightUpper": 4,
            "LeftTrackpad": "left_trackpad", "LeftTrackpadClick": "left_trackpad",
            "RightTrackpad": "right_trackpad", "RightTrackpadClick": "right_trackpad",
            "CenterTrackpad": "center_trackpad", "CenterTrackpadClick": "center_trackpad"}

# Group mode of each source when a layout is generated
MODES = {"joystick": "joystick_move", "right_joystick": "joystick_move", "button_diamond": "four_buttons",
         "left_trigger": "trigger", "right_trigger": "trigger", "switch": "switches", "dpad": "dpad",
         "left_trackpad": "joystick_move", "right_trackpad": "joystick_move",
         "center_trackpad": "joystick_move", "gyro": "gyro_to_mouse"}
STANDARD = ["switch", "button_diamond", "left_trigger", "right_trigger", "joystick", "right_joystick", "dpad"]
GYRO = STANDARD + ["gyro"]
TWO_PADS = GYRO + ["left_trackpad", "right_trackpad"]
# PlayStation touchpad: source name center_trackpad (confirmed on a PS5, 2026-10-31)
PLAYSTATION = GYRO + ["center_trackpad"]
# controller type -> sources present, optional "replace" (source -> source
# used instead) and "back" (number of back paddles: 0, 2 = button_back_left
# / _right, 4 = also the _upper pair). Back paddle names: 2015 Steam
# Controller from a community guide; Steam Deck / 2026 Steam Controller
# _upper pair UNCONFIRMED (no export with paddles bound yet).
CONTROLLERS = {
    "controller_xboxone": dict(sources=STANDARD),
    "controller_xbox360": dict(sources=STANDARD),
    "controller_ps5": dict(sources=PLAYSTATION),
    "controller_ps4": dict(sources=PLAYSTATION),
    "controller_switch_pro": dict(sources=GYRO),
    "controller_neptune": dict(sources=TWO_PADS, back=4),
    "controller_steamcontroller_gordon": dict(
        sources=["switch", "button_diamond", "left_trigger", "right_trigger", "joystick",
                 "left_trackpad", "right_trackpad", "gyro"],
        replace={"right_joystick": "right_trackpad", "dpad": "left_trackpad"}, back=2,
        modes={"left_trackpad": "dpad"}),
    # the 2026 Steam Controller (type string from the owner's export,
    # 2026-10-31; not in Valve's documented list): sticks, d-pad AND two
    # trackpads, like the Steam Deck.
    "controller_triton": dict(sources=TWO_PADS, back=4),
    # A single Joy-Con (controller_switch_joycon_left / _right) has one
    # stick and no standard source set - not generated. Generic pads (many
    # "PS4 compatible" ones report GenericGamepad) get no gyro.
    "controller_switch2_pro": dict(sources=GYRO),
    "controller_switch_joycon_pair": dict(sources=GYRO),
    "controller_generic": dict(sources=STANDARD),
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
    cfg = CONTROLLERS[ctype]
    sources, replace, back = cfg["sources"], cfg.get("replace", {}), cfg.get("back", 0)
    modes = dict(MODES, **cfg.get("modes", {}))
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
        binds = []
        for s, i, a in BINDINGS.get(set_name, []):
            s = replace.get(s, s)
            need = OPTIONAL.get(a)
            if isinstance(need, str) and (need not in sources or need in replace.values()):
                continue
            if isinstance(need, int) and back < need:
                continue
            assert s in sources, f"{ctype}: {set_name}.{a} needs source {s}, which this pad lacks"
            binds.append((s, i, a))
        # consistency: every action of the set bound once, apart from the
        # optional ones this pad does not have
        acts = [a for _, a, _, _ in next(x[2] for x in SETS if x[0] == set_name)]
        bound = [a for _, _, a in binds]
        for a in acts:
            assert bound.count(a) <= 1, f"{ctype}: {a} bound twice"
            assert a in bound or a in OPTIONAL, f"{ctype}: {set_name}.{a} not bound"
        psrc = []
        for src in sources:
            mine = [(i, a) for s, i, a in binds if s == src]
            w.open("group")
            w.kv("id", str(gid))
            w.kv("mode", modes[src])
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
            assert len(whole) <= 1, f"{ctype}: {src} drives two analog actions {whole}"
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
