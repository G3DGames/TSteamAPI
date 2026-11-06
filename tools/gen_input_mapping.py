#!/usr/bin/env python3
"""Writes a Steam Input action manifest and one default layout per
controller type from ONE table of action sets, actions and bindings.

    python3 tools/gen_input_mapping.py

Output (every folder in OUTS - demos/SteamInputDemo/src/,
demos/VirtualGamepad/src/, demos/VirtualGamepadLCL/src/ and
demos/VirtualGamepadVCL/src/, IDENTICAL
files: projects use only their own sources, owner 2026-10-31): MANIFEST_NAME and
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
writes it; always on: "gyro_button" "0" - Steam's default on the Steam Deck
and Steam Controller is "on while the right trackpad is touched", and that
touch then gives no RightTrackpad position) is its own action, Gyro, on every pad with motion
sensors.

This is the core of the planned mapping tool (CLAUDE.md, "PROJECT AIM"):
there the tables come from the user pressing buttons.

PROFILES (2026-11-04): the tables above make the "input" profile (the
Steam Input demos). The "pad" profile is SteamDemoPad's OWN manifest
(owner, 2026-11-04: its own manifest with a different name) -
PAD_MANIFEST_NAME with ONE action set, Pad (menu navigation), and layouts
named pad_controller_<type>.vdf in demos/SteamDemoPad/src only, so a depot
folder shared by several demos never mixes the two sets of files. In the
pad profile an action may be bound from several sources (the D-pad AND the
left stick move the highlight).
"""
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUTS = [os.path.join(ROOT, "demos", d, "src")
        for d in ("SteamInputDemo", "VirtualGamepad", "VirtualGamepadLCL", "VirtualGamepadVCL")]

TITLE = "SteamInputDemo default layout"
# No AppID in the text: the same files serve SteamInputDemo, VirtualGamepad
# and VirtualGamepadLCL, which run under different AppIDs (each program's
# TSteamAPI.AppID is the only place an AppID is kept)
DESCRIPTION = "Default bindings for the TSteamAPI Steam Input test."
# Each layout gets its own title: Steam's layout browser lists every
# official layout of the game together, so identical titles cannot be told
# apart (owner, 2026-10-31). Every type in CONTROLLERS needs a name here.
CONTROLLER_NAMES = {
    "controller_xboxone": "Xbox One / Series",
    "controller_xbox360": "Xbox 360",
    "controller_ps5": "PlayStation 5 (DualSense)",
    "controller_ps4": "PlayStation 4",
    "controller_switch_pro": "Switch Pro",
    "controller_neptune": "Steam Deck",
    "controller_steamcontroller_gordon": "Steam Controller (2015)",
    "controller_triton": "Steam Controller (2026)",
    "controller_switch2_pro": "Switch 2 Pro",
    "controller_switch_joycon_pair": "Joy-Con pair",
    "controller_generic": "generic gamepad",
}

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
        # D-pad up / down: VirtualGamepad's overlay menu moves between its
        # items with these (owner 2026-11-01)
        ("button", "MenuUp", "#Action_MenuUp", None),
        ("button", "MenuDown", "#Action_MenuDown", None),
        # D-pad left / right: the overlay's controller row (several pads)
        ("button", "MenuLeft", "#Action_MenuLeft", None),
        ("button", "MenuRight", "#Action_MenuRight", None),
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
    ("Action_BackLeft", "Left back paddle (lower, L5)"), ("Action_BackRight", "Right back paddle (lower, R5)"),
    ("Action_BackLeftUpper", "Upper left back paddle (L4)"),
    ("Action_BackRightUpper", "Upper right back paddle (R4)"),
    ("Action_MenuConfirm", "Confirm"), ("Action_MenuBack", "Back (with Confirm: back to every control)"),
    ("Action_MenuUp", "Menu: up"), ("Action_MenuDown", "Menu: down"),
    ("Action_MenuLeft", "Menu: left"), ("Action_MenuRight", "Menu: right"),
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
        ("dpad", "dpad_north", "MenuUp"),
        ("dpad", "dpad_south", "MenuDown"),
        ("dpad", "dpad_west", "MenuLeft"),
        ("dpad", "dpad_east", "MenuRight"),
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
# / _right, 4 = also the _upper pair). Back paddle names CONFIRMED on the
# 2026 Steam Controller (owner's log, 2026-10-31): button_back_left /
# _right = L5 / R5 (lower), button_back_left_upper / _right_upper = L4 / R4
# (upper) - Steam Deck naming; the 2015 pad's two grips from a community
# guide.
CONTROLLERS = {
    # Xbox One also carries gyro and the four back-paddle sources: handhelds
    # that report themselves as an Xbox One pad (ROG Ally, owner 2026-11-01:
    # gyro + two paddles shown as L4 / R4 in Steam's Test Device Inputs, but
    # with no source in this layout Steam bound them to face buttons by
    # itself) and the Xbox Elite pads get them; a plain Xbox pad has none of
    # them, so nothing changes there (the actions stay "not bound").
    "controller_xboxone": dict(sources=GYRO, back=4),
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


# --- SteamDemoPad (profile "pad") ---
PAD_OUTS = [os.path.join(ROOT, "demos", "SteamDemoPad", "src")]
PAD_TITLE = "SteamDemoPad default layout"
PAD_DESCRIPTION = "Default bindings of the TSteamAPI Big Picture demo: menu navigation."
# ONE set: the program's pages, list, menu and confirmation are all driven by it
PAD_SETS = [
    ("Pad", "#Set_Pad", [
        ("stick", "PadScroll", "#Action_PadScroll", "joystick_move"),
        ("button", "PadUp", "#Action_PadUp", None),
        ("button", "PadDown", "#Action_PadDown", None),
        ("button", "PadLeft", "#Action_PadLeft", None),
        ("button", "PadRight", "#Action_PadRight", None),
        ("button", "PadSelect", "#Action_PadSelect", None),
        ("button", "PadBack", "#Action_PadBack", None),
        ("button", "PagePrev", "#Action_PagePrev", None),
        ("button", "PageNext", "#Action_PageNext", None),
        ("button", "PadMenu", "#Action_PadMenu", None),
    ]),
]
PAD_LOCALIZATION = {"english": [
    ("Set_Pad", "Menus"),
    ("Action_PadScroll", "Scroll the list"),
    ("Action_PadUp", "Up"), ("Action_PadDown", "Down"),
    ("Action_PadLeft", "Left"), ("Action_PadRight", "Right"),
    ("Action_PadSelect", "Select"), ("Action_PadBack", "Back"),
    ("Action_PagePrev", "Previous page"), ("Action_PageNext", "Next page"),
    ("Action_PadMenu", "Menu"),
]}
PAD_BINDINGS = {
    "Pad": [
        ("right_joystick", None, "PadScroll"),
        ("dpad", "dpad_north", "PadUp"),
        ("dpad", "dpad_south", "PadDown"),
        ("dpad", "dpad_west", "PadLeft"),
        ("dpad", "dpad_east", "PadRight"),
        # the left stick as a second d-pad (group mode "dpad", PAD_MODES)
        ("joystick", "dpad_north", "PadUp"),
        ("joystick", "dpad_south", "PadDown"),
        ("joystick", "dpad_west", "PadLeft"),
        ("joystick", "dpad_east", "PadRight"),
        ("button_diamond", "button_a", "PadSelect"),
        ("button_diamond", "button_b", "PadBack"),
        ("switch", "left_bumper", "PagePrev"),
        ("switch", "right_bumper", "PageNext"),
        ("switch", "button_escape", "PadMenu"),
    ],
}
# the left stick moves the highlight in steps, like the d-pad
PAD_MODES = {"joystick": "dpad"}
# RAISE BY ONE WHENEVER A pad_ LAYOUT'S CONTENT CHANGES (reported back in
# SteamInputConfigurationLoaded_t, as LAYOUT_REVISION for the input profile)
#   1 - 2026-11-04: first version
PAD_LAYOUT_REVISION = 1
# SteamDemoPad's manifest (its MANIFEST_FILE and gen_projects.py's
# PAD_INPUT_FILES must match it)
PAD_MANIFEST_NAME = "steamdemopad_controllers.vdf"


class Profile:
    """One manifest + its layouts: the tables and where they go."""
    def __init__(self, outs, manifest_name, layout_prefix, title, description, program, sets,
                 localization, bindings, optional, modes, revision, multi_source, summary,
                 bound_sources_only=False):
        self.outs, self.manifest_name, self.layout_prefix = outs, manifest_name, layout_prefix
        self.title, self.description, self.program = title, description, program
        self.sets, self.localization, self.bindings = sets, localization, bindings
        self.optional, self.modes, self.revision = optional, modes, revision
        self.multi_source, self.summary = multi_source, summary
        # True: a source no action uses gets no group at all (an unbound
        # gyro group in gyro_to_mouse mode could move the OS mouse pointer)
        self.bound_sources_only = bound_sources_only


PROFILES = {
    "input": Profile(OUTS, "steam_controllers.vdf", "controller_", TITLE, DESCRIPTION, "SteamInputDemo",
                     SETS, LOCALIZATION, BINDINGS, OPTIONAL, {}, 21, False,
                     "TSteamAPI Steam Input test: one action per physical control."),
    "pad": Profile(PAD_OUTS, PAD_MANIFEST_NAME, "pad_controller_", PAD_TITLE, PAD_DESCRIPTION, "SteamDemoPad",
                   PAD_SETS, PAD_LOCALIZATION, PAD_BINDINGS, {}, PAD_MODES, PAD_LAYOUT_REVISION, True,
                   "TSteamAPI Big Picture demo: menu navigation.", bound_sources_only=True),
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


def write_actions(w, pr):
    w.open("actions")
    for name, title, acts in pr.sets:
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


def write_localization(w, pr, title=None, description=None):
    title = pr.title if title is None else title
    description = pr.description if description is None else description
    w.open("localization")
    for lang, items in pr.localization.items():
        w.open(lang)
        w.kv("title", title)
        w.kv("description", description)
        for k, v in items:
            w.kv(k, v)
        w.close()
    w.close()


def manifest(pr):
    w = W()
    w.open("Action Manifest")
    w.open("configurations")
    for ctype in CONTROLLERS:
        w.open(ctype)
        w.open("0")
        w.kv("path", layout_file(pr, ctype))
        w.close()
        w.close()
    w.close()
    write_actions(w, pr)
    write_localization(w, pr)
    w.close()
    return w.text()


# Layout revision written into EVERY layout (minor_revision): Steam reports
# it back in SteamInputConfigurationLoaded_t (m_unMajorRevision /
# m_unMinorRevision), so the demo's log tells which copy Steam really
# loaded. RAISE IT BY ONE WHENEVER A LAYOUT'S CONTENT CHANGES.
#   1 - 2026-11-01: Xbox One layout gains gyro + back paddles (ROG Ally)
#   2 - 2026-11-01: literal per-controller titles (see layout())
#   3 - 2026-11-01: Menu set gains MenuUp / MenuDown on the D-pad
#       (VirtualGamepad's overlay menu)
#   4 - 2026-11-01: Menu set gains MenuLeft / MenuRight on the D-pad
#       (the overlay's controller row)
#  20 - 2026-11-03: no content change - a jump well above any revision an
#       old test used, so Steam replaces a stale stored copy (an AppID
#       reused from an old test kept loading its old layout; owner)
#  21 - 2026-11-06: gyro groups get "gyro_button" "0" (always on): Steam's
#       default on the Deck / Steam Controller switched the gyro on with a
#       right-trackpad touch, and that touch gave no RightTrackpad position
LAYOUT_REVISION = 21
assert PROFILES["input"].revision == LAYOUT_REVISION

# File name of the action manifest (the programs' MANIFEST_FILE and
# gen_projects.py's INPUT_FILES must match it). Was steam_input_manifest.vdf
# until 2026-11-03: renamed so Steam reads it afresh instead of an old
# manifest of that name it kept for an AppID used by an earlier test.
MANIFEST_NAME = "steam_controllers.vdf"
assert PROFILES["input"].manifest_name == MANIFEST_NAME


def layout_file(pr, ctype):
    """File name of the layout of controller type ctype in profile pr
    (controller_xboxone.vdf, pad_controller_xboxone.vdf)."""
    return pr.layout_prefix + ctype[len("controller_"):] + ".vdf"


def layout(pr, ctype):
    cfg = CONTROLLERS[ctype]
    sources, replace, back = cfg["sources"], cfg.get("replace", {}), cfg.get("back", 0)
    # the profile's modes, then the pad's own (a pad's replaced source keeps
    # the mode the pad needs, e.g. the 2015 controller's left trackpad as dpad)
    modes = dict(MODES, **pr.modes)
    modes.update(cfg.get("modes", {}))
    # Title / description are LITERAL text, not "#title" tokens: Steam
    # resolved "#title" from the MANIFEST's localization, so every official
    # layout showed the same manifest title in Steam's layout browser
    # (owner's screenshot 2026-11-01: three identical "SteamInputDemo
    # default layout" entries on a laptop, four on the ROG Ally). The
    # revision is in the title so the browser shows which copy Steam has.
    title = f"{pr.program} - {CONTROLLER_NAMES[ctype]} (r{pr.revision})"
    description = (f"Default layout for the {CONTROLLER_NAMES[ctype]} ({layout_file(pr, ctype)}, revision "
                   f"{pr.revision}) - {pr.summary}")
    w = W()
    w.open("controller_mappings")
    for k, v in (("version", "3"), ("revision", "1"), ("title", title), ("description", description),
                 ("controller_type", ctype), ("major_revision", "0"), ("minor_revision", str(pr.revision)),
                 ("Timestamp", "0")):
        w.kv(k, v)
    write_actions(w, pr)
    write_localization(w, pr, title, description)
    gid = 0
    presets = []
    for set_name, _, _ in pr.sets:
        binds = []
        for s, i, a in pr.bindings.get(set_name, []):
            s = replace.get(s, s)
            need = pr.optional.get(a)
            if isinstance(need, str) and (need not in sources or need in replace.values()):
                continue
            if isinstance(need, int) and back < need:
                continue
            assert s in sources, f"{ctype}: {set_name}.{a} needs source {s}, which this pad lacks"
            binds.append((s, i, a))
        # consistency: every action of the set bound once, apart from the
        # optional ones this pad does not have
        acts = [a for _, a, _, _ in next(x[2] for x in pr.sets if x[0] == set_name)]
        bound = [a for _, _, a in binds]
        for a in acts:
            assert pr.multi_source or bound.count(a) <= 1, f"{ctype}: {a} bound twice"
            assert a in bound or a in pr.optional, f"{ctype}: {set_name}.{a} not bound"
        # never the same input of one source twice (a replaced source can
        # land on one that is bound already)
        keys = [(s, i) for s, i, _ in binds]
        assert len(keys) == len(set(keys)), f"{ctype}: {set_name}: one input bound twice {keys}"
        psrc = []
        for src in sources:
            mine = [(i, a) for s, i, a in binds if s == src]
            if pr.bound_sources_only and not mine:
                continue
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
            # the gyro always on: without "gyro_button" Steam turns it on only
            # while the right trackpad (Steam Controller; Deck: also the right
            # stick) is touched - and a touch that switches the gyro on gives
            # no RightTrackpad position (owner's Steam Deck log 2026-11-06;
            # Steam's own text: "By default, the gyro only sends input to the
            # game when you're touching the Right Joystick or Right
            # Trackpad"). 0 = "Gyro Enable Button - Always On" (GyroNone, the
            # first of Steam's gyro button choices).
            gyro_always = src == "gyro"
            if whole or gyro_always:
                w.open("settings")
                if whole:
                    w.kv("virtual_mode", "1")
                if gyro_always:
                    w.kv("gyro_button", "0")
                w.close()
            if whole:
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


def write(pr, name, text):
    data = text.encode("ascii")
    for out in pr.outs:
        os.makedirs(out, exist_ok=True)
        path = os.path.join(out, name)
        old = open(path, "rb").read() if os.path.exists(path) else None
        if old != data:
            open(path, "wb").write(data)
            print("wrote", os.path.relpath(path, ROOT))
        else:
            print("unchanged", os.path.relpath(path, ROOT))


def main():
    for pr in PROFILES.values():
        write(pr, pr.manifest_name, manifest(pr))
        for ctype in CONTROLLERS:
            write(pr, layout_file(pr, ctype), layout(pr, ctype))


if __name__ == "__main__":
    main()
