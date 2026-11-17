# VirtualGamepad: views, glow, trackpads - and what a new pad model needs

The three VirtualGamepad demos (FMX + Gorilla3D, Lazarus + Castle Game
Engine, VCL + Castle Game Engine) show the same things the same way. This
page says what they show, and what a new model (the Steam Deck and Switch
models being commissioned) must contain for all of it to work.

## What the demos show

### Views

There are three views. They are camera positions relative to the front view:

| View | Azimuth | Inclination | Shows |
|---|---|---|---|
| Front | 0 | 0 | the face, as the player sees it |
| Back | 180 | 0 | the back: the paddles (L4 / L5 / R4 / R5) |
| Top | 180 | 90 | the top edge from above: bumpers and triggers; the face is towards the top of the screen |

The overlay menu (hold Start for 0.8 s) has one row for them, "View: Front".
Left / right on the D-pad change the view it names, as on the controller
row; A shows it. A mouse click on the row shows the next view. The View menu
(Show Front / Show Back / Show Top) does the same with the mouse.

The overlay menu wraps round: down on the last item goes to the first, up
on the first to the last. Up / down held move again every 0.5 s, as in
SteamDemoPad.

VirtualGamepad moves its orbit camera to those angles (Sprite3DCamera
`Azimuth` / `PolarAngle`). A drag turns on from there, and a right-click
goes back to the chosen view. The Castle twins turn the model the other way
instead, which gives the same picture, and View > Reset view goes back to it.
The model never turns by itself.

### Gyro, Motion and skyboxes

The overlay menu has three rows for this (owner 2026-11-07):

* **Enable / Disable Gyro** - the model turns as the pad turns (the pad's
  orientation when it is switched on is the front view; View > Recenter
  motion takes the current one). Pads with motion sensors only.
* **Enable / Disable Motion** - the gyro, and the model also MOVES with the
  pad: lift it and the model goes up, push it right and it goes right. Only
  for pads with an accelerometer (the row is greyed otherwise). An
  accelerometer measures changes of speed, not a position, so this is a
  feel of the movement, not tracking: the model moves while the pad is
  pushed and drifts back to the middle when it is still, and never further
  than about a third of its size (it stays in view). Gravity is taken out
  by a slow average, so a slow tilt does not move it. With Motion on the
  Motion shows its own view, "Motion" (the top view turned round by
  azimuth 180, then inclination 180 more; back to the view before when
  Motion ends). Turning ROUND (on a chair, the pad held still in the
  hands) does not turn the model: the turn about "up" goes to the skybox,
  which turns the other way, as the room seems to. Tilting the whole pad
  up / down tilts the skybox (its inclination) and the model; twisting the
  pad turns the model. "Up" comes from the accelerometer (gravity) turned by the
  orientation; the log shows the axis found ("Motion: the sensors' up axis
  is ..."). The cost: twisting the pad flat (about up) also counts as
  turning round. With only the Gyro on, the model follows every turn. Which accelerometer axis is "right", "up" and "towards
  you" differs between pads: the log names the axis that reacts to a push
  ("Motion: accelerometer axis X reacted"), and MOTION_SRC / MOTION_SIGN
  in the three uMain.pas map them.
* **Skybox: None / Grid / Sky / Stars** - left / right choose, A shows it.
  Sky is shown at start (if it is there).
  The skyboxes are folders in `images/skyboxes/` (six faces each, see its
  README); the Grid, Sky and Stars ones are generated test images
  (`tools/gen_skyboxes.py`). A new folder there is a new skybox.

### Glow

Every control that is in use glows: a faint translucent cyan sphere (25 %
opacity), drawn unlit, round the part it moves. It shows on black plastic as
well as on white. It glows fully while the control is held or moved, then fades out over 0.7 s.
So a press on a control with little travel, like a paddle or a shoulder
button, still shows clearly. A stick glows while it is off centre, a trigger
while it is pulled. Several controls can glow at once.

The D-pad glows per arm: Up + Right lights the up and the right arm.

The overlay menu's **Disable Highlights** / **Enable Highlights** item turns
the glow off and on (on at start). The yellow touch dots and the 2D trackpad
squares stay either way.

**Back and top views: left and right swapped.** Seen from behind or from
above, the pad's left side is on the right of the screen. So that the glow
shows on the side of the player's hand, these views glow the mirror-image
part: a press of L4 glows R4's paddle, which is on the screen's left there,
the left stick glows the right stick, Menu glows View, D-pad left glows
D-pad right. Parts on the middle line (A, Y, Guide, D-pad up / down) glow
as they are. The front view needs no swap. A trackpad marked on the model is
swapped the same way; the 2D trackpad squares are not. The paddles, triggers
and bumpers also MOVE swapped in these views (L4 plays R4's clip), so the
part that moves is the part that glows; the sticks and buttons on the face
move as they are.

Where each part is comes from `PadParts.pas`. `tools/gen_pad_parts.py`
generates it from `models/*.glb` (see "After a model is delivered").

### Trackpads

* A click on a trackpad makes it glow, like any other control.
* A touch puts a **yellow dot** where the finger is. The trackpads are bound
  as touch positions (x, y from -1 to 1), so the dot follows the finger.
* On a model that marks its trackpads (see below), glow and dot are on the
  model's surface. On a model that does not (all three current models), each
  trackpad appears as a 2D square at the bottom of the view once it is first
  used: left, right, and the PlayStation touchpad in the middle.

### The log

Buttons are logged as before ("ButtonA pressed" / "released"). The analog
controls are logged as being in use, without their values:

* `Left stick: horizontal motion`, `Left stick: vertical motion` (once per
  use), `Left stick: back at rest`
* `Right trigger: activated`, `Right trigger: released`
* `Left trackpad: touched`, `Left trackpad: touch ended`
* `Gyro: motion`, `Gyro: still`

A button still held when the overlay menu closes (the A that chose an item)
is not reported as a new press.

The start of the log says what glows on the model loaded, for example "Glow:
19 parts of SteamController_Animated.glb glow while used and fade out after;
the model marks no trackpad (touches show at the bottom of the view)".

## What a new model needs

These are the conventions of the three current models (by Quaternius, CC0).
A model that follows them works in all three demos without code changes,
apart from choosing it for its controller type (last section).

### File

* glTF binary (`.glb`), one file per pad, named `<Pad>_Animated.glb` (for
  example `SteamDeck_Animated.glb`, `SwitchPro_Animated.glb`).
* Y up, the face (the side the player looks at) towards **+Z**, the pad's
  left on -X: the player's view looks down -Z. Real-world size in metres is
  fine (the current models are about 0.94 wide); the programs scale to fit.
* Skinned meshes are fine (the current ones are skinned to one armature),
  as are plain node meshes.
* CC0, like `models/LICENSE`, so it can go in the repository.

### One joint and one clip per control

Each control is moved by its **own joint** (bone or node), and each clip
moves **one** joint. Clips go rest, peak, rest: the programs play up to the
peak and hold it while the control is held. The peak must not push the part
into the body: on the Steam Controller model DPad_Up's full 5 degrees sinks
the up arm into the top edge, so the programs stop it half way
(DPAD_UP_PEAK). Linear or step keys, not cubic
spline. Clip names, as in the current models (the PlayStation model uses
`X_Press` / `Circle_Press` / `Square_Press` / `Triangle_Press` for the face
buttons instead):

| Control | Clip(s) |
|---|---|
| Face buttons (bottom, right, left, top) | `A_Press`, `B_Press`, `X_Press`, `Y_Press` |
| Bumpers | `Shoulder_Left_Press`, `Shoulder_Right_Press` |
| Triggers | `Trigger_Left_Press_Full` (and `_Soft`), `Trigger_Right_Press_Full` |
| Sticks | `Stick_Left_Up` / `_Down` / `_Left` / `_Right` / `_Press`, the same for `Stick_Right` |
| D-pad | `DPad_Up`, `DPad_Down`, `DPad_Left`, `DPad_Right` (one joint; the generator splits its mesh into four arms for the glow) |
| Menu / View (Start / Select) | `Menu_Press`, `View_Press` |
| Back paddles: lower, upper | `L5_Press` / `R5_Press`, `L4_Press` / `R4_Press` |
| Guide / Profile | `Guide_Press`, `Profile_Press` |

**Clean skin weights**: a joint should carry only its own part's vertices.
On the Steam Controller model, the `Profile`, `View` and `Menu` joints also
carry vertices from other parts of the pad. The generator leaves such stray
pieces out of a part and says so: it keeps the pieces that lie together,
and of two mirror-twin controls (Menu and View) the pair of pieces that
mirror each other. A clean model needs no guessing.

**Left / right twins** are found by name: `Left` / `Right`, `L4` / `R4`,
`L5` / `R5`, `Menu_` / `View_`, `X_` / `B_` (`Square_` / `Circle_` on
PlayStation). Keep to these names, and the back and top views swap the glow
correctly.

### Trackpads (Steam Deck, Steam Controller, PlayStation touchpad)

Mark each trackpad with an **empty** node (glTF node with no mesh):

| Node name | Trackpad |
|---|---|
| `Trackpad_Left` | left trackpad |
| `Trackpad_Right` | right trackpad |
| `Trackpad_Center` | PlayStation touchpad |

* Its **origin** is the middle of the trackpad's surface.
* Its local **X** axis points to the pad's right edge and **Y** to its top
  edge. Scale the node to the pad's half-width and half-height, so that
  x, y of -1..1 reach the edges.
* Its local **Z** points out of the surface.

A click clip for a trackpad (for example `Trackpad_Left_Press`) is welcome
but optional: the demos glow the whole trackpad on a click.

## After a model is delivered

1. Put it in `models/` and run `python3 tools/gen_pad_parts.py`. That writes
   `PadParts.pas` into all three demos. Check its output: every clip should
   map to the joint it should move, and the trackpads should be found.
2. Choose it for its controller types in `ModelFileFor` (all three
   `uMain.pas` files) and add it to `MODEL_FILES` there and in
   `tools/gen_projects.py`. The post-build copies and Deployment entries
   then include it.
3. Update the table in [SteamInputMapping.md](SteamInputMapping.md) ("Which
   picture or model for which pad") and `models/LICENSE`.

A model the unit does not know gets no glow, and the log says so. A `.glb`
that differs in size from the one `PadParts.pas` was made from still glows,
but the log warns that the glow may be in the wrong place.
