# Steam Input mapping

How a game's actions reach real buttons with Steam Input, and how to ship
default layouts so they work the moment a player picks up a controller.
For the API itself see [components/TSteamInput.md](components/TSteamInput.md);
`demos/SteamInputDemo` is a complete working example of everything here.

## The chain

```
game code            action manifest           layout (per controller type)        the pad
"Jump" handle  ->    InGame / Button "Jump" -> Jump = A button (XBoxOne_A)      -> bottom face button
```

* The **game** only knows actions ("Jump", "Move") and action sets
  ("InGame", "Menu"). It never reads raw buttons.
* The **action manifest** (a VDF file) declares those actions and names a
  **default layout** for each controller type.
* A **layout** binds actions to the pad's inputs. Steam ships the default
  one from the manifest; players can change it, and community layouts can
  replace it.
* Steam reports where an action is bound as **origins**
  (`k_EInputActionOrigin_XBoxOne_A`, ...), which name a physical input on a
  specific kind of pad - for button prompts, glyphs and (below) 3D models.

## 1. The action manifest

One VDF file, three sections:

```
"Action Manifest"
{
	"configurations"	{ ... }
	"actions"		{ ... }
	"localization"		{ ... }
}
```

`configurations` names the default layout per controller type (section 2),
`actions` the action sets and their actions, `localization` the display
names per language.

**No comments in the file.** A manifest that began with `//` comment lines
did not work (2026-10-31), and neither Valve's sample nor shipped games'
manifests contain any. Keep notes elsewhere.

`demos/SteamInputDemo/src/steam_input_manifest.vdf` is a complete example,
written by `tools/gen_input_mapping.py` (section 2).
The `actions` and `localization` sections use Valve's In-Game Actions
format:

* **Action sets** are objects inside `actions`, each with a unique name and
  a `"title"` (a `#` localisation token). A game activates one set per
  controller at a time (`ActivateActionSet`): typically one for playing,
  one for menus, one for driving, ...
* Inside a set, up to three blocks:
  * `"StickPadGyro"` - two-axis analog actions (sticks, trackpads, gyro).
    Each is an object with `"title"` and `"input_mode"`: `"joystick_move"`
    (deflection from the centre: movement) or `"absolute_mouse"` (cameras,
    cursors - Valve: when in doubt, use this). An `absolute_mouse` action can
    add `"os_mouse" "1"` to move the OS mouse as well.
  * `"AnalogTrigger"` - one-axis analog actions: `"Throttle" "#Action_Throttle"`.
  * `"Button"` - digital actions: `"Jump" "#Action_Jump"`.
* **Action set layers** (a separate top-level `"action_layers"` section in
  the In-Game Actions format) overlay changes on the active set - aiming,
  a modifier held - without switching sets.
* `"localization"` holds one block per Steam language code (`"english"`,
  `"german"`, `"schinese"`, ...) mapping the tokens, without the `#`, to
  text. English is required.

The names in the manifest are what the code looks up:
`GetActionSetHandle('InGame')`, `GetDigitalActionHandle('Jump')`,
`GetAnalogActionHandle('Move')`.

## 2. Default layouts

Without a default layout every action is unbound until the player builds
one - SteamInputDemo's log then shows "NOT BOUND". Ship one layout per
controller type you support, in the manifest's `configurations` section:

```
	"configurations"
	{
		"controller_xboxone"
		{
			"0"
			{
				"path"		"controller_xboxone.vdf"
			}
		}
		"controller_ps5"
		{
			"0"
			{
				"path"		"controller_ps5.vdf"
			}
		}
	}
```

* Keys `"0"`, `"1"`, ... list layouts per type in priority order; `"path"`
  is relative to the manifest file.
* Controller type strings (Valve's list): `controller_xboxone`,
  `controller_xboxelite`, `controller_xbox360`, `controller_ps5`,
  `controller_ps5_edge`, `controller_ps4`, `controller_ps3`,
  `controller_switch_pro`, `controller_switch2_pro`,
  `controller_switch_joycon_pair`, `controller_switch_joycon_left`,
  `controller_switch_joycon_right`, `controller_neptune` (Steam Deck),
  `controller_steamcontroller_gordon` (the 2015 Steam Controller),
  `controller_mobile_touch` (Remote Play touch), `controller_generic`.
  Valve's list does not name the 2026 Steam Controller: Steam calls it
  **`controller_triton`** (an exported layout of it, 2026-10-31;
  `ESteamInputType` `SteamController2026`, origins `SteamController2026_*`).

### The layout file format

Learned from layouts Steam exports (Valve's SpaceWar sample and a shipped
game); text VDF, tabs:

```
"controller_mappings"
{
	"version"		"3"
	"title"		"#title"			// tokens from "localization"
	"description"		"#description"
	"controller_type"		"controller_ps5"
	"actions"		{ ... }			// copies of the manifest's sections
	"localization"		{ ... }
	"group"					// one per physical source per action set
	{
		"id"		"3"
		"mode"		"four_buttons"
		"inputs"
		{
			"button_a"
			{
				"activators"
				{
					"Full_Press"
					{
						"bindings"
						{
							"binding"		"game_action InGame Fire"
						}
					}
				}
			}
		}
	}
	"group"					// an analog action drives a whole source
	{
		"id"		"4"
		"mode"		"joystick_move"
		"inputs"		{ }
		"gameactions"
		{
			"InGame"		"Move"
		}
	}
	"preset"				// one per action set: group -> source
	{
		"id"		"0"
		"name"		"InGame"
		"group_source_bindings"
		{
			"3"		"button_diamond active"
			"4"		"joystick active"
		}
	}
}
```

(The `//` notes are for this page only; real files have none.)

Physical sources and their inputs use the **same names on every pad**, and
they are positional - `button_a` is the bottom face button on Xbox,
PlayStation and Switch alike:

| Source | Group mode (typical) | Inputs |
|---|---|---|
| `button_diamond` | `four_buttons` | `button_a` (bottom), `button_b` (right), `button_x` (left), `button_y` (top) |
| `switch` | `switches` | `left_bumper`, `right_bumper`, `button_escape` (Start / Menu / Options), `button_menu` (Back / View / Create), `button_back_left` / `_right` (+ `_upper`: back grips) |
| `left_trigger`, `right_trigger` | `trigger` | `edge` (full pull), `click`; or `gameactions` for an analog trigger action |
| `joystick`, `right_joystick` | `joystick_move` | `click` (stick press); or `gameactions` for a stick action |
| `dpad` | `dpad` | `dpad_north`, `dpad_south`, `dpad_east`, `dpad_west` |
| `left_trackpad`, `right_trackpad` | `dpad`, `absolute_mouse`, ... | Steam Controller, Steam Deck; `center_trackpad` on PlayStation |
| `gyro` | `gyro_to_mouse` (what Steam writes), `joystick_camera`, ... | pads with motion sensors; no inputs - the whole source drives an action |

Activators other than `Full_Press` exist: `Soft_Press` (triggers; a light
press on trackpads and sticks) and `Double_Press`. Steam's own exports mix
case in input names (`button_a`, `button_B`, `button_X`, `button_y` in one
file): read them case-insensitively; lower case is what we write.

### Generating layouts: tools/gen_input_mapping.py

`tools/gen_input_mapping.py` writes SteamInputDemo's manifest and one
layout per controller type (Xbox One / 360, PS5 / PS4, Switch Pro, Switch 2
Pro, Joy-Con pair, Steam Deck, the 2015 and 2026 Steam Controllers, generic
pads - many "PS4 compatible" pads report themselves as generic) from one
table of sets, actions and `(source, input, action)` bindings. Not
generated: a single Joy-Con (one stick), Xbox Elite, DualSense Edge, PS3.

**The same actions on every pad.** The demo's `InGame` set has one action
per physical control, named by position with the Xbox letters, and every
layout binds all of them - the generator refuses to write a layout that
leaves one out:

| Action | Control | Source / input |
|---|---|---|
| `LeftStick`, `RightStick` | sticks (analog) | `joystick`, `right_joystick` (2015 Steam Controller: `right_trackpad`) |
| `LeftStickClick`, `RightStickClick` | stick presses | `click` of those sources |
| `LeftTrigger`, `RightTrigger` | triggers (analog; digital on Nintendo pads) | `left_trigger`, `right_trigger` |
| `ButtonA` / `B` / `X` / `Y` | bottom / right / left / top face button | `button_diamond`: `button_a` ... `button_y` |
| `LeftBumper`, `RightBumper` | shoulders | `switch`: `left_bumper`, `right_bumper` |
| `DPadUp` / `Down` / `Left` / `Right` | d-pad | `dpad` (2015 Steam Controller: `left_trackpad` as a d-pad) |
| `Start`, `Select` | Start / Menu / Options / +, Select / View / Create / - | `switch`: `button_escape`, `button_menu` |
| `Gyro` *(optional)* | motion sensors, reported as MOUSE MOVEMENT (mode "absolute mouse": tilt the pad, x / y change) | `gyro`, mode `gyro_to_mouse`, always on - every pad that has one. The raw sensors (orientation quaternion, acceleration, rotation speed) are `GetMotionData`, separate from any binding |
| `LeftTrackpad`, `RightTrackpad` + `...Click` *(optional)* | trackpads: finger position (-1..1 like a stick, 0 when not touched) and press | `left_trackpad`, `right_trackpad`, mode `joystick_move` - Steam Deck, 2026 Steam Controller (on the 2015 one the trackpads ARE its right stick and d-pad) |
| `CenterTrackpad` + `CenterTrackpadClick` *(optional)* | PlayStation touchpad: position and press | `center_trackpad` (confirmed on a PS5), mode `joystick_move` - PS4, PS5 |
| `BackLeft`, `BackRight` *(optional)* | lower back paddles - L5 / R5 | `switch`: `button_back_left` / `_right` - Steam Controllers, Steam Deck |
| `BackLeftUpper`, `BackRightUpper` *(optional)* | upper back paddles - L4 / R4 | `switch`: `button_back_left_upper` / `_right_upper` - Steam Deck, 2026 Steam Controller (confirmed on the 2026 pad) |

`Start` together with `RightTrigger` pulled past 0.25 switches to the
`Menu` set (`MenuConfirm` = `ButtonA`, `MenuBack` = `ButtonB`); pressing
both together returns. Combinations are bad design for a game but right for
a tool that tests pads: `Start`, `A` and `B` alone stay ordinary buttons to
watch, and a set switch replaces what the Live state panel shows, so it
must never happen by accident. While the Guide / Xbox button has opened
Steam's overlay or the Xbox Game Bar, Steam reports every action inactive
(`bActive` False) - the demo logs that change. The Guide / PS / Home / Steam button is
reserved by Steam and can never be bound.

SteamInputDemo shows the controller it reads at the top: its type, the
layout file Steam looks for and whether that file is ours, the 3D model,
its motion sensors - and whether Steam actually loaded OUR layout for it.

### Making a layout file with Steam

Steam can also write these files from bindings made in its configurator:

1. Big Picture -> Settings -> System: enable **Developer mode**. In the new
   Developer section enable **Steam Input Layout Dev Mode**.
2. Run the game with the manifest active (section 3) and one controller
   connected; open its controller layout (`ShowBindingPanel`, or the game's
   controller settings in the Steam client) and bind every action of every
   set.
3. Gear icon -> **Export layout**; give it a title and description.
4. Write it to disk - Windows: `start steam://dumpcontrollerconfig?appid=<AppID>`
   (the file appears in the Documents folder); Linux / SteamOS desktop:
   `xdg-open steam://dumpcontrollerconfig?appid=<AppID>` (written to `/tmp`).
5. Copy it next to the manifest and add it to `configurations`.
6. Repeat per controller type.

## 3. Development and shipping

* **Development:** `SetInputActionManifestFilePath(<absolute path>)`
  after `Start` makes Steam use a local manifest instead of the one from
  the game's depots - for builds run outside Steam, or to try changes.
  Valve: the override lasts for the rest of the Steam session.
  SteamInputDemo does this with the manifest copied next to its
  executable.
* **Shipping:** put the manifest and its layout files into the game's depot
  and configure Steam Input for the app on the partner site; the game then
  does not call `SetInputActionManifestFilePath` at all.
* Steam Input must be enabled for the game for Xbox and generic
  controllers to reach it (PlayStation, Switch and Steam controllers
  normally are by default); a player can still switch it off per game.

## 4. Reading actions in code

* Action set and action handles are **0 until Steam has loaded the
  manifest** - look them up again (once a second is plenty) until they are
  not, and again after `OnSteamInputConfigurationLoaded` (a new layout).
* Activate the set on each controller every frame
  (`ActivateActionSet(Pad, Set)`); it takes effect at the next `RunFrame`.
* `GetDigitalActionData` / `GetAnalogActionData` per controller and action:
  `bActive` is False when the action is not in the active set or not bound.
* `DigitalActionOrigins` / `AnalogActionOrigins` (helpers on
  `TSteamInputPlugin`) list the origins an action is bound to; per origin,
  `GetStringForActionOrigin` gives a localised name and
  `GetGlyphPNGForActionOrigin` / `GetGlyphSVGForActionOrigin` the path of
  Steam's image for "press (A)" prompts - always matching the player's pad
  and current layout.

## 5. From origins to physical buttons

Origins are per controller family: the same action bound to "the bottom face
button" reports `XBoxOne_A` on an Xbox pad, `PS5_X` (Cross) on a DualSense,
`SteamController2026_A` on the 2026 Steam Controller. Anything that has to
show the *physical* button - a pad picture, a 3D model - maps origins to
positions, not to letters, because Nintendo uses the same letters in other
places:

| Position | Xbox (`XBoxOne_`) | PlayStation 5 (`PS5_`) | Steam Controller 2026 (`SteamController2026_`) | Switch (`Switch_`) |
|---|---|---|---|---|
| bottom | `A` | `X` (Cross) | `A` | `B` |
| right | `B` | `Circle` | `B` | `A` |
| left | `X` | `Square` | `X` | `Y` |
| top | `Y` | `Triangle` | `Y` | `X` |

**Nintendo pads and Steam's button swap.** Steam has a per-controller
setting that decides how a Nintendo pad's face buttons are read (in the
controller's settings in Steam). Tested on a Switch Pro, 2026-10-31:

| Steam's swap setting | `ButtonA` (`button_a`) is | Origins Steam reports for the buttons |
|---|---|---|
| on | the button LABELLED A (right) - "A = A, B = B" | Switch family (`Switch_A` ... `Switch_Plus`), Switch glyphs |
| off | the BOTTOM button (labelled B) - Xbox positions | **Xbox 360 family** (`XBox360_A` ... `XBox360_Start` / `_Back`, d-pad, bumpers, stick clicks) with Xbox glyphs; sticks, ZL / ZR and gyro stay Switch origins |

Joy-Con pair (2026-10-31, same machine, Steam's **Nintendo layout**
option ON for it): `button_a` was the BOTTOM button, reported with its
real label (`Switch_B`, "B Button"), Switch-family origins throughout -
positional like the Pro with the swap off, but WITHOUT the Xbox 360
origins. The option names differ between the two pads as the owner saw
them ("swap" for the Pro, "Nintendo layout" for the Joy-Cons); what
matters for code is the origin reported.

Single Joy-Con (right, held sideways; 2026-10-31): there is no layout
file of ours for `SwitchJoyConSingle`, yet Steam reported "mapping by 0"
- it ADAPTED the game's default layout to the one Joy-Con and bound only
what it has: the face buttons as `ButtonA` / `B` / `X` / `Y` by position
(origins `Switch_JoyConButton_S` / `E` / `W` / `N`, 250 / 249 / 251 /
248, for which `GetStringForActionOrigin` returns an empty name; glyphs
`shared_buttons_s` ...), the stick as `LeftStick` + `LeftStickClick`, SL /
SR as `LeftBumper` / `RightBumper` (reported as the Switch L / R
origins), + as `Start`. No gyro binding, although motion data comes
through. Odd but harmless: `LeftStick` delivered values while its
origin list was empty. The LEFT Joy-Con alone behaves the same: its four
arrow buttons become the N / E / S / W face buttons, its stick
`LeftStick`, and - (Minus) is `Start` (`Switch_Minus`, 199). Its gyro is "Right JoyCon Gyro Move" (origin 236), for which
Steam has no glyph image in any style.

A third-party pad that emulates an Xbox 360 controller but has its
buttons PRINTED in Nintendo positions (2026-10-31) is read as an Xbox 360
pad: `ButtonA` is the bottom button and Steam shows an "A" glyph for it
although the button there is labelled B. Nothing tells a game about the
printing; the pad presents itself as an Xbox pad. Such pads often have
digital triggers (0 or 1 only). The same kind of pad switched to a
"PS4" mode was reported as `PS4Controller` with PlayStation origins and
glyphs, Gyro and touchpad bound - but it sent no motion data and no
touchpad input: a clone can claim a type whose sensors it does not have.
Treat Gyro / touchpad as present only once they report something.

So on a Switch pad `ButtonA` follows the player's setting, and the
origins can even come from another controller family than the pad's
own type. A picture or model must therefore place a button by the ORIGIN
Steam reports (this table, Xbox 360 rows included), never by the action
or by the pad's type.

Other inputs per family (SDK 1.65 names):

| Input | Xbox | PlayStation 5 | Steam Controller 2026 |
|---|---|---|---|
| shoulders | `LeftBumper`, `RightBumper` | `LeftBumper`, `RightBumper` | `L1`, `R1` |
| triggers, analog / full press | `LeftTrigger_Pull` / `_Click` | `LeftTrigger_Pull` / `_Click` | `L2_SoftPull` / `L2` (two levels) |
| sticks, click | `LeftStick_Move`, `LeftStick_Click` | `LeftStick_Move`, `LeftStick_Click` | `LeftStick_Move`, `L3` |
| d-pad | `DPad_North` ... `DPad_Move` | `DPad_North` ... | `DPad_North` ... `DPad_Move` |
| centre buttons | `View`, `Menu`, `Share` | `Create`, `Option`, `Mute` | `View`, `Menu` |
| extras | `LeftGrip_Upper` / `_Lower` ... (Elite paddles) | `CenterPad_Click`, `LeftPad_Touch` ... (touchpad), gyro | `L4` `L5` `R4` `R5` (back grips), `LeftPad` / `RightPad` (trackpads), `LGrip` / `RGrip` (grip sensors), gyro |

**Reserved by Steam:** the Guide / PS / Steam button and the Steam
Controller's Quick Access ("...") button have no origins - Steam uses them
itself, so a game can never bind them.

### Which picture or model for which pad

`GetInputTypeForHandle(Pad)` gives each pad's type
(`ESteamInputType`); SteamInputDemo logs it. For a game with its own pad
art - such as the CC0 models in `models/` (Xbox One, PS5, Steam Controller;
a Switch model is planned):

| `ESteamInputType` | Model |
|---|---|
| `XBoxOneController`, `XBox360Controller` | Xbox One |
| `PS5Controller` (`PS4Controller` as a close match) | PS5 |
| `SteamController2026` | Steam Controller |
| `SwitchProController`, `Switch2ProController`, `SwitchJoyConPair` | Switch model when available; the Xbox one meanwhile (positions still match - see the table) |
| anything else (`GenericGamepad`, the 2015 Steam Controller, ...) | Xbox One |

### When Steam keeps loading another layout

Steam remembers, per game and per controller type, the layout a player
last chose - a template, a community layout, one of their own. It then
loads that instead of the game's default, and the game sees few or none
of its actions. SteamInputDemo's banner says so ("Steam loaded a
DIFFERENT layout, not ours"; the log shows "mapping by" a SteamID instead
of 0, and every action NOT BOUND). Choosing a template once - for example
to export it - is enough to cause this. To get the game's own layout back
(tested on the 2026 Steam Controller, 2026-10-31):

1. Start the game with the controller connected.
2. Open the game's controller settings: in SteamInputDemo **File -> View
   Controller Settings** (the overlay's binding panel - it worked even
   when the demo was started from the IDE), or in the Steam client the
   controller icon on the game's page in the Library. Choose to load a
   different layout; the **Load new Layout** screen opens.
3. Under **Recommended -> Official Layouts** pick the layout named for
   your controller (ours: "SteamInputDemo - Steam Controller (2026)",
   "... - PlayStation 5 (DualSense)", ...).
4. If the list shows old names or old layouts: exit Steam completely
   (Steam -> Exit) and start it again - a manifest set with
   `SetInputActionManifestFilePath` is kept for the whole Steam session.
5. **Wait a few seconds.** Steam reloads the layout by itself
   (OnSteamInputConfigurationLoaded); the banner should then read "Steam
   loaded OUR default layout (mapping by 0)". Restart the game only if it
   does not. (An earlier note said a restart was always needed - wrong:
   a controller can appear seconds before its layout, and the demo used to
   list every action as NOT BOUND in that gap.)

Adding the game's executable to Steam as a non-Steam game does NOT help:
the game already identifies itself (SteamAppId / steam_appid.txt), and a
non-Steam shortcut is a separate entry with layouts of its own.

## 6. When it does not work

| Symptom | Cause |
|---|---|
| No controller listed | Steam Input is off for this game (Xbox / generic pads), or `RunFrame` has not run yet - controllers appear after the first frames |
| Handles stay 0 | The manifest was not loaded: wrong path (it must be absolute), a VDF syntax error, or Steam Input off for the app |
| Actions "NOT BOUND", `bActive` False | No default layout for this controller type and none chosen yet - add one (section 2) or bind in the layout screen |
| `ShowBindingPanel` returns False | The Steam overlay is not running in this process: edit the layout from the Steam client instead. (On Windows with Delphi 13 it returned True even for a demo started from the IDE - 2026-10-31.) |
| Manifest ignored (handles 0, nothing in the configurator) although the path is right | `//` comments in the manifest (section 1), or a VDF syntax error |
| Some controls work on one pad but not on another, or nothing works | Steam loaded a different layout for that pad (see "When Steam keeps loading another layout" above) - a personal one or a Steam template (the demo's banner says so; the log shows "mapping by" a non-zero id). Reset the pad's layout to the game's default in Steam's controller settings. Also: a pad with Steam Input switched off for it (PlayStation / Switch / generic support settings) reaches the game through no layout at all |
| A middle button (Xbox / Guide, Share) opens the Xbox Game Bar on Windows 11 | Windows' Xbox Game Bar takes those buttons; View and Menu are fine. Turn it off in Settings -> Gaming -> Game Bar to test them - players may have it on |
| Glyphs load (the log names the file) but nothing shows | The **knockout** style is white detail on a transparent background (only Xbox-style coloured face buttons have colour): invisible on a light background. Use **Light** (black on white) on light UIs, Knockout / Dark on dark ones - SteamInputDemo uses Light |
| Every action NOT BOUND, log says "mapping by 0" but "uses Steam Input API False" | Steam Input is off for this pad: Steam passes it to the game as a plain gamepad and loads no game-action layout at all (seen with a pad emulating an Xbox 360 controller, 2026-10-31). Turn Steam Input on for the controller (Steam Settings -> Controller, select the pad) or for the game (Properties -> Controller -> Enable Steam Input). SteamInputDemo's banner says "Steam Input is NOT active for this pad" |
| Layout changes not picked up | Steam keeps a manifest override for the session; `OnSteamInputConfigurationLoaded` reports each new layout - re-read handles and origins then |

Sources: Valve's Steamworks documentation -
[action manifest file](https://partner.steamgames.com/doc/features/steam_controller/action_manifest_file),
[In-Game Actions file](https://partner.steamgames.com/doc/features/steam_controller/iga_file);
origin and type names from the SDK 1.65 headers (`isteaminput.h`).
