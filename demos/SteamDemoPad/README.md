# SteamDemoPad (FMX)

The **Big Picture / Steam Deck** variant of SteamDemo, AppID 2275430: driven by the game pad through Steam Input, with a screen the program draws itself (no standard controls), laid out for 1280 x 800 and scaled to the window. Building it is described in the repository [README](../../README.md).

## What it does

* **Steam starts by itself** when the window is up - there is no Start button and no setting. Then Show Info (to the log) and the component test (shared with the SteamDemos, `demos/Shared/SteamComponentTest.pas`) run on their own; the result is on the status bar at the bottom.
* **Pages**, switched with the shoulder buttons (LB / RB) - the line under them names the **controller in use** (the one whose buttons the hint line shows; how many are connected when more than one): **Personal** (you and your friends, with avatars), **Achievements** (A on one unlocks or clears it, after an OK / Cancel confirmation), **Two Users** (A on the first row starts the pair test; run Pair in a SteamDemo or `SteamConsole --pair` on a second PC with another Steam account).
* **D-pad or left stick**: move. **A**: select. **B**: back. **Right stick**: scroll.
* **Start / Menu** (a short press) opens the menu: the **controller row** (only with more than one pad connected, as in VirtualGamepad: Left / Right names another pad, A makes it *the* pad), **Controller Settings** (Steam's layout screen for the pad, in the overlay), **Rumble** (both motors, half a second), **Start Sending to Remote** (see the log below), **Take Screenshot**, **Restart Steam**, **Exit**. Controller Settings, Rumble and the button names on the hint line use the pad chosen in the controller row, else the pad that pressed a button last; every pad still moves through the pages. Items that cannot work right now are greyed. The menu wraps round (Up on the first entry goes to the last), and Up / Down held move one entry every half second. Restart rather than Stop: Steam Input needs Steam, so after a plain Stop the pad could not reach a Start item. While Steam is not running the item reads **Start Steam** (keyboard, mouse or the Deck's touch screen then).
* **The log** goes to a LogReceiver ([RemoteLogging](../../RemoteLogging/README.md)): the program looks for one at start - you must **Accept** it on the receiver, which may take a few attempts - and **Start Sending to Remote** tries again. The menu item follows the connection: **Looking for Remote...** / **Connecting...** (greyed: nothing to do until the receiver answers), **Stop Sending to Remote** only once the receiver has accepted, and back to **Start Sending to Remote** when the search finds nothing, the receiver refuses or does not answer within 2 minutes, or the connection fails or drops (no endless retrying); the status bar says which. Lines from before the connection are sent first. A copy is written next to the executable (`SteamDemoPad.log`, the previous run's as `SteamDemoPad.previous.log`) where that folder is writable, and to stderr on Linux / macOS.
* **Keyboard / mouse / touch** work too: arrows, Enter, Escape, Q / E or Tab (pages), M or F10 (menu); click or tap a page or a row; **right click** opens the menu; mouse wheel scrolls. With **no controller connected** (or Steam not running) the hint line and the keys beside the page row show these keys instead of the pad's buttons. Every hint that does something - menu, select / choose, close / cancel, the page keys - can be **clicked or tapped**, so the menu is always reachable without a pad.
* For an action bound twice, such as Up on the d-pad and the left stick, the shorter-named origin is shown (`GetStringForActionOrigin`).
* **Big Picture:** the window goes full screen while Steam says it is in Big Picture (`IsSteamInBigPictureMode`) - checked once a second, so also when Big Picture is switched on after the start. Steam says so only for a program **Steam launched**: started from Delphi or Explorer it answers "no" (and has no overlay) even with the client in Big Picture. To test a build from your folder through Steam: Steam > Library > the app > Properties > General > Launch Options `"<full path>\SteamDemoPad.exe" %command%` (Steam then starts your executable instead of the installed one - the rest of the command line is ignored by the program); remove the option afterwards.
* The hint line and the page row show **Steam's pictures** of the buttons for the pad in use (`GetGlyphPNGForActionOrigin`, knockout style for the dark background); the name only where Steam has no picture.

**Linux / SteamOS / Proton:** the program carries every FMX fix in `docs/`: `FmxLinuxGtkGlobal` (GTK 3 in Steam Linux Runtime 3.0 - set the app's Linux launch to Runtime 3.0 on the partner site), the ICU launcher `src/SteamDemoPad.sh` (SteamOS: make it the Linux launch command), `FmxWineCanvas` (Proton: GDI+ instead of Direct2D's white window) and `FmxSkiaCanvas`. It has no main menu, so the Linux menu-bar fix is not needed. **Skia is enabled** (Project > Enable Skia, owner 2026-11-04, as a test case): `TSAPI_FMX_CANVAS=skia` or `=vulkan %command%` switches the Proton build to Skia's raster or Vulkan canvas ([docs/Proton.md](../../docs/Proton.md)); `sk4d.dll` / `libsk4d.so` are deployed next to the program. The IDE's `GlobalUseSkia := True;` line is deliberately NOT in the .dpr.

The pad's bindings are the program's **own action manifest**, `steamdemopad_controllers.vdf` (one action set, `Pad`), with a default layout per controller type, `pad_controller_<type>.vdf` - generated by `tools/gen_input_mapping.py` (profile "pad"); never edit them by hand.

This page also says how to **deploy the Windows Release build** - the build that is packaged into a Steam depot. macOS and Linux are deployed by the project's Deployment entries (Project -> Deployment), not covered here.

## 1. Build Release

In the IDE choose the **Release** configuration and the Windows platform you ship (Win64, or Win32), then Build. The executable goes to:

```
demos\SteamDemoPad\Win64\Release\SteamDemoPad.exe
demos\SteamDemoPad\Win32\Release\SteamDemoPad.exe
```

The build copies the Steam library, the action manifest and the eleven controller layouts into the same folder and fails the build if a copy fails (the post-build event is one line, `call "$(PROJECTDIR)\deploy.bat" $(Platform) $(Config)`; `deploy.bat` in the project folder does the copying and names a missing file). `deploy.bat` also works on its own: double-click it (Win64 Release) or run `deploy.bat Win32 Debug`.

## 2. What goes in the depot

The .exe, the Steam library and the action manifest sit **in the depot's root folder**; the controller layouts in a `controllers\` subfolder (the manifest names them `controllers/...`) - the folder the build fills (`deploy.bat`) is exactly this.

| File | Taken from |
|------|------------|
| `SteamDemoPad.exe` | `demos\SteamDemoPad\Win64\Release\` (or `Win32\Release\`) |
| `steam_api64.dll` - Win64 build only | `redistributable_bin\win64\steam_api64.dll` |
| `steam_api.dll` - Win32 build only | `redistributable_bin\steam_api.dll` |
| `steamdemopad_controllers.vdf` | `demos\SteamDemoPad\src\` |
| `sk4d.dll` (Skia; the Win64 or Win32 one) | the IDE deploys it next to the .exe (Enable Skia) |
| `pad_controller_*.vdf` - 11 files: xboxone, xbox360, ps5, ps4, switch_pro, neptune, steamcontroller_gordon, triton, switch2_pro, switch_joycon_pair, generic | `demos\SteamDemoPad\src\controllers\` |

The `pad_` names never clash with SteamInputDemo's `controller_*.vdf`, so both programs can share one depot folder.

## 3. What must NOT go in the depot

* `steam_appid.txt` - never ship it (it would stop Steam's relaunch check).
* `*.rsm`, `*.map`, `*.drc` - debug / map files, if your Release settings produce them.
* `src\SteamDemoPad.sh` - the Linux launcher script; not used on Windows.
* `SteamDemoPad.log`, `SteamDemoPad.previous.log` - written by test runs.

## 4. On Steam

* **Launch option** (partner site, Installation -> General): executable `SteamDemoPad.exe`, operating system Windows, no arguments. With a second launch option for the desktop SteamDemo, Steam asks the player which one to start - Valve advises against making Steam Deck players choose, so this program is meant to be the **default** option (to be settled - see `docs/Launcher.md`).
* Release builds call `RestartIfNecessary` (started outside Steam they ask Steam to relaunch them); Debug builds set the AppID themselves.
* **Steam Input**: the manifest is loaded from the program's folder at run time (`SetInputActionManifestFilePath`, the call Valve provides for games that bundle their configurations in the depot). SteamInputDemo loads a different manifest under the same AppID the same way. **Unverified:** how the partner site's Steam Input settings for the app interact with two bundled manifests for players (it works in development) - see `docs/Launcher.md`, open decision 5.

## Check

The log names the manifest loaded ("SetInputActionManifestFilePath(...): yes"), "action set Pad and 10 actions resolved", the button names on the pad in use, then the start-up results. A pad that does nothing: look for "handles still 0" (manifest not found or not loaded) in the log.
