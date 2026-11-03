# Running the Windows build under Proton

Proton is Valve's Wine-based compatibility layer: on SteamOS and other
Linux systems Steam can run a game's **Windows** build instead of a native
Linux one. This page collects what is specific to running TSteamAPI programs
that way - what works, what needed a fix, how to test, and what is still
open.

Tested on: ROG Ally (AMD Ryzen Z1 Extreme) with SteamOS, Proton 11.0,
Delphi 13 Win64 builds of SteamInputDemo (AppID 2275430) and VirtualGamepad
(AppID 4108310), Desktop Mode and Game Mode (2026-11-03).

## Contents

* [What works unchanged](#what-works-unchanged)
* [FMX: white window - the canvas](#fmx-white-window---the-canvas)
* [Telling Proton from native Linux](#telling-proton-from-native-linux)
* [Big Picture / Game Mode](#big-picture--game-mode)
* [Testing on the device](#testing-on-the-device)
* [Logs and where to find them](#logs-and-where-to-find-them)
* [Open questions](#open-questions)

## What works unchanged

* **The Steam API.** `steam_api64.dll` next to the .exe loads, and
  `SteamAPI_Init` reaches the Steam client through Proton's own bridge
  (the Proton log shows `SteamAPI_Init(): Loaded ...steamclient64.dll OK`).
  Callbacks and Steam Input work as on Windows (SteamInputDemo,
  VirtualGamepad). The Steam overlay has not been checked under Proton yet.
* **Deployment.** The Windows depot is used as it is: the same files next
  to the .exe as on Windows (see each demo's README). Proton maps the
  Steam library folder to a Windows drive, so paths in the log look like
  `S:\steamapps\common\<install folder>\`.
* **Gorilla3D.** Its 3D view picked **OpenGL 4.6** (Mesa, radeonsi) under
  Proton and renders normally.
* **VCL and LCL** programs draw with GDI and their own widget set, so the
  canvas problem below does not affect them (not yet run under Proton).

## FMX: white window - the canvas

**Symptom:** an FMX program's window is all white; only the native menu
bar shows. The program runs normally behind it (Steam starts, the log is
written).

**Cause:** FMX on Windows draws every form through Direct2D and clips each
control with D2D layers. Wine's own `d2d1.dll` (Proton 11.0) has
`PushLayer`, `PopLayer` and `PushAxisAlignedClip` as stubs - the Proton log
reports each of them thousands of times (`fixme:d2d:... stub!`) - so
everything FMX draws is discarded. `PROTON_USE_WINED3D=1` does not help:
Direct2D is Wine's in either case.

**Fix:** under Wine, FMX must not use Direct2D. The demos (SteamDemo,
SteamInputDemo, VirtualGamepad) and LogReceiver use the unit
`FmxWineCanvas`, listed in the .dpr right after `FmxLinuxGtkGlobal`. In its
initialization - before `Application.Initialize` and the first form - a
Windows build that finds itself under Wine (ntdll exports
`wine_get_version`) picks FMX's canvas. The environment variable
`TSAPI_FMX_CANVAS` chooses it, so canvases can be compared on the device
without rebuilding (Steam: Properties -> Launch Options):

| Launch Option | Canvas | Status under Proton 11.0 |
|---|---|---|
| (none) | `gdi`: GDI+ (default) | CONFIRMED: draws correctly, but on the CPU - VirtualGamepad: 14-18 fps at 1920 x 1036 against a target of 60 (ROG Ally, 2026-11-03) |
| `TSAPI_FMX_CANVAS=gpu %command%` | `gpu`: FMX's GPU canvas, through Direct3D 11 (DXVK / Vulkan under Proton) | being measured |
| `TSAPI_FMX_CANVAS=d2d %command%` | `d2d`: Direct2D, FMX's normal choice | CONFIRMED white window (2026-11-03); for testing a later Proton |
| `TSAPI_FMX_CANVAS=none %command%` | `none`: the unit changes nothing - FMX and the program's own .dpr settings decide | baseline; switches the workaround off |
| `TSAPI_FMX_CANVAS=skia %command%` | `skia`: Skia's raster canvas (`TSkRasterCanvas`, CPU + GDI BitBlt) | to measure - VirtualGamepad only (needs Skia) |
| `TSAPI_FMX_CANVAS=vulkan %command%` | `vulkan`: Skia's Vulkan canvas (`TVkCanvas`, GPU; Delphi 13.2+) | to measure - the best candidate: Proton runs Vulkan natively. VirtualGamepad only |

The workaround is only about Direct2D. A renderer that does not use it -
Skia (`GlobalUseSkia := True` in the .dpr; it needs `sk4d.dll` deployed),
FMX's GPU canvas, a later FMX that draws through Vulkan - needs none of
this, so the unit never touches `GlobalUseSkia`, and `none` leaves
everything to the program. Which canvas is best can change with FMX and
with Proton: the log records the Wine version with every decision, and
this page records what was measured on which device.

An unknown value is reported in the log and the default is used. The
variable's NAME must be exact (`TSAPI_FMX_CANVAS` - a missing underscore
means the program never sees it: the log then says `(not set)`), and
`%command%` must come last, or Steam passes the text as a program argument
instead of setting the variable. The
programs log the decision near the top, e.g.

```
Wine 11.0: FMX canvas gdi (TSAPI_FMX_CANVAS=(not set); default gdi - Wine's Direct2D leaves FMX windows white)
```

then, on every platform, the canvas FMX REALLY draws with - whatever was
asked for:

```
FMX canvas in use: TCanvasGdiPlus
```

and VirtualGamepad logs its frame rate every 5 s, with the canvas and the
viewport size, so the canvases can be compared by number (the numbers here
are only an example of the format):

```
Frame rate: 58.9 fps (mean of 50 frame times; target 60, fixed rate True; canvas TCanvasGpu (TSAPI_FMX_CANVAS=gpu); viewport 1920 x 1048)
```

**Skia (`skia`, `vulkan`).** Only a program with Skia enabled can use
them: VirtualGamepad has a second unit, `FmxSkiaCanvas`, listed right after
`FmxWineCanvas`, whose initialization sets `GlobalUseSkia` and
`GlobalUseSkiaRasterWhenAvailable` (False = `TVkCanvas`). Gorilla3D's docs
(v1.5, Core / Skia) require exactly that place - set later, `GlobalUseSkia`
has no effect. To set it up: Project > Enable Skia (the IDE then deploys
`sk4d.dll` / `libsk4d.so`), and REMOVE the `GlobalUseSkia := True;` line the
IDE writes into the .dpr. Skia canvases repaint the whole form; Gorilla3D
1.5.1+ merges those repaints into its frames, and VirtualGamepad logs
`Gorilla3D: whole-form repaint handling ...` to show it. In a program
without `FmxSkiaCanvas`, `skia` / `vulkan` fall back to GDI+.

**In your own FMX program:** copy `FmxWineCanvas.pas` and list it first in
the .dpr's uses, after `FMX.Forms`. (Planned: the same choice built into
`Steamworks.FMX`, with the best canvas as the default, once the
measurements are in - see [Open questions](#open-questions).)

The choice cannot be a `TSteamAPI` property: FMX picks its canvas when the
first form is created, and the component is created with the form - too
late. It has to happen in a unit's initialization or in the .dpr before
`Application.Initialize`.

## Telling Proton from native Linux

`TSteamLib.PlatformDescription` (logged at start-up and shown in every
demo's window title) names Wine and Proton when a Windows build runs under
them, with the host system behind them - e.g. `Windows x64 build on Proton
... (Wine 11.0) on SteamOS ...`. `TSteamLib.RunningOS` gives the same
without the build target. Steam itself offers `ISteamUtils::IsRunningUnderProton()`
(SDK 1.65; `TSteamUtilsPlugin`).

Which build Steam runs is chosen per app on the device: Properties ->
Compatibility -> "Force the use of a specific Steam Play compatibility
tool". When an app has a native Linux depot too, Steam runs that unless
Proton is forced - check this first when a test does not behave as
expected. (The native Linux build has its own SteamOS issues and fixes:
[fmx-steamos-icu-bug-fix.md](fmx-steamos-icu-bug-fix.md),
[fmx-steamos-gtk3-bug-fix.md](fmx-steamos-gtk3-bug-fix.md).)

## Big Picture / Game Mode

Game Mode is always full screen, and the display has no fixed size
(1280 x 800 on a Steam Deck, 1920 x 1080 on the ROG Ally, up to 4K on a
Steam Machine). `TSteamAPI` asks Steam whether it runs in Big Picture and
maximises its form there (`BigPictureWindow`, default `bpwMaximized`) - see
[components/TSteamAPI.md](components/TSteamAPI.md#big-picture-and-game-mode).
The log line it writes names the display size it got - under Proton
expected to be gamescope's output, i.e. the panel's resolution (not yet
confirmed). Game
Mode shows one window only, and there is no keyboard or mouse unless they
are opened, so test with the pad.

## Testing on the device

1. **SSH into the device** (SteamOS ships the server switched off): in
   Desktop Mode open Konsole, `passwd` (the `deck` user has no password),
   then `sudo systemctl enable --now sshd`; find the address with
   `ip -4 addr show`, connect with `ssh deck@<address>` (SFTP / scp work
   the same way).
2. **Run the real app, not a loose copy:** copy the build into the app's
   install folder (`~/.local/share/Steam/steamapps/common/<install folder>/`),
   keeping the original .exe under another name. Started from Steam it
   then has its real AppID, Proton and Game Mode. A Debug build works here
   too (it sets the same AppID itself).
3. **Force Proton** for the app (Properties -> Compatibility).
4. **Launch Options** for the run - one or more, before `%command%`:

   | Option | Use |
   |---|---|
   | `PROTON_LOG=1` | Wine's and DXVK's own messages to `~/steam-<AppID>.log` |
   | `PROTON_USE_WINED3D=1` | Wine's Direct3D -> OpenGL instead of DXVK (Direct3D -> Vulkan) |
   | `TSAPI_FMX_CANVAS=gdi` / `gpu` / `d2d` | FMX's canvas (above) |

   Example: `PROTON_LOG=1 TSAPI_FMX_CANVAS=gpu %command%`.
5. Try another Proton version (Experimental, GE-Proton) only after the
   logs point away from the program.

## Logs and where to find them

| Log | Where |
|---|---|
| The program's own log (`<Program>.log`) | Next to the .exe, in the install folder |
| Proton's log (with `PROTON_LOG=1`) | `~/steam-<AppID>.log` |

Copy them to a PC with `scp deck@<address>:~/steam-<AppID>.log .`, or the
program's log with its full path (quoted when the install folder has
spaces). In a Proton log, the lines worth a search: `fixme:d2d` (the canvas
problem), `err:`, `Graphics Backend` (Gorilla3D's choice), `steam_api64`
(the DLL loaded) and `SteamAPI_Init`.

## Open questions

* **Canvas speed:** whether `gpu` draws under Proton and how fast, against
  `gdi` - VirtualGamepad's frame-rate lines will tell. The faster working
  one becomes the default.
* **Building it into the library:** the choice moves from the copied unit
  into `Steamworks.FMX` (every FMX program using `TSteamAPI` gets it), with
  a setting a program can change in its .dpr and the environment variable
  above to override both. Needs a package rebuild.
* **Motion froze the 3D view** (VirtualGamepad, GDI+, every controller -
  the Ally's own pad and a PS5 DualSense; 2026-11-03): the model's transform
  was written on every 16 ms poll while a frame took ~55 ms, and drawing
  stopped until motion was switched off. Fixed in zip Motion1: written at
  most once per measured frame time - TO CONFIRM on the Ally.
* **GPU canvas** (`TSAPI_FMX_CANVAS=gpu`): access violation at start
  (2026-11-03) - not investigated.
* **For SteamOS, the native Linux build** (OpenGL for FMX and Gorilla3D,
  no Proton) is expected to be the fast option - to measure.
* **VCL and LCL Windows builds** have not been run under Proton yet
  (VirtualGamepadLCL next: LCL draws with GDI, Castle Game Engine with
  OpenGL - neither uses Direct2D).
* **Skia** (`GlobalUseSkia`) under Proton: worth one measured run.
* **The Steam overlay** (Shift+Tab, screenshots through it) under Proton.
* **Display size in Game Mode:** the `Big Picture:` log line should report
  the panel's resolution.
