# VirtualGamepad (FMX + Gorilla3D)

3D gamepad visualiser: shows the model of the connected controller in Gorilla3D 1.5.4, animated from Steam Input, with the Steam Input overlay menu. AppID 4108310. Building it is described in the repository [README](../../README.md) ("Repository layout" and "Getting started").

This page says how to **deploy the Windows Release build** - the build that is packaged into a Steam depot: which files go in the depot and where they sit relative to the executable. macOS and Linux are deployed by the project's Deployment entries (Project -> Deployment), not covered here.

## 1. Build Release

In the IDE choose the **Release** configuration and the Windows platform you ship (Win64, or Win32), then Build. The executable goes to:

```
demos\VirtualGamepad\Win64\Release\VirtualGamepad.exe
demos\VirtualGamepad\Win32\Release\VirtualGamepad.exe
```

The post-build event copies the Steam library, the action manifest, the eleven controller layouts and the three models into the same folder and fails the build if a copy fails. The IDE's Deployment adds `sk4d.dll` (section 2). So after a successful Release build that folder holds every file the depot needs - plus a few it must not contain (section 3).

## 2. What goes in the depot

Everything sits **in the depot's root folder, next to the .exe** - no subfolders (the models too: not in a `models\` subfolder).

| File | Taken from |
|------|------------|
| `VirtualGamepad.exe` | `demos\VirtualGamepad\Win64\Release\` (or `Win32\Release\`) |
| `steam_api64.dll` - Win64 build only | `redistributable_bin\win64\steam_api64.dll` |
| `steam_api.dll` - Win32 build only | `redistributable_bin\steam_api.dll` |
| `sk4d.dll` (Skia4Delphi, used by FMX's Skia canvas) | Delphi's `bin64\sk4d.dll` (Win64) or `bin\sk4d.dll` (Win32); the IDE's Deployment (Project -> Deployment, class Skia) puts it next to the .exe - the post-build event does not copy it |
| `steam_controllers.vdf` | `demos\VirtualGamepad\src\` |
| `controller_*.vdf` - 11 files, listed below | `demos\VirtualGamepad\src\` |
| `XBoxOne_Animated.glb` | `models\` (repository root) |
| `PS5_Animated.glb` | `models\` (repository root) |
| `SteamController_Animated.glb` | `models\` (repository root) |

```
<depot root>\
    VirtualGamepad.exe
    steam_api64.dll        (Win64 build)   - or -   steam_api.dll   (Win32 build)
    sk4d.dll               (from Delphi's bin64\ for Win64, bin\ for Win32)
    steam_controllers.vdf
    controller_generic.vdf
    controller_neptune.vdf
    controller_ps4.vdf
    controller_ps5.vdf
    controller_steamcontroller_gordon.vdf
    controller_switch2_pro.vdf
    controller_switch_joycon_pair.vdf
    controller_switch_pro.vdf
    controller_triton.vdf
    controller_xbox360.vdf
    controller_xboxone.vdf
    XBoxOne_Animated.glb
    PS5_Animated.glb
    SteamController_Animated.glb
```

* The DLL must match the build: a Win64 .exe cannot load `steam_api.dll`, a Win32 .exe cannot load `steam_api64.dll`. Shipping both bitnesses means two folders (or depots), each with its own .exe and DLL.
* The DLL is loaded from the .exe's own folder: it must sit right next to it, not in a subfolder.
* The program reads the manifest from its own folder (in Release builds too - it calls `SetInputActionManifestFilePath` with that path) and the layouts from the manifest's folder: keep them together, next to the .exe. The fallback to the repository's `src\` and `models\` folders only works inside the repository, never in an installed copy.
* The .vdf files are GENERATED (tools/gen_input_mapping.py); ship the ones from `src\`, never hand-edited copies.
* `sk4d.dll` is the one file the post-build event does not copy: it comes through the IDE's Deployment (the project's Skia entries, `$(BDS)\bin64\sk4d.dll` for Win64 and `$(BDS)\bin\sk4d.dll` for Win32), so build with Deployment enabled, or copy it from Delphi's folder by hand - the matching bitness, next to the .exe.
* Nothing else: FMX, Gorilla3D, the library and the plug-ins are compiled into the .exe (no .bpl runtime packages). Gorilla3D needs extra DLLs on Windows only for physics (Jolt) or audio (FMOD), which this demo does not use.

## 3. What must NOT go in the depot

* `steam_appid.txt` - never ship it (it would stop Steam's relaunch check, section 4).
* `VirtualGamepad.log` - written at run time.
* `*.rsm`, `*.map`, `*.drc` - debug / map files, if your Release settings produce them.
* `src\VirtualGamepad.sh` - the Linux launcher script; not used on Windows.

## 4. On Steam

* **Launch option** (partner site, Installation -> General): executable `VirtualGamepad.exe`, operating system Windows, no arguments, working folder empty (the depot root).
* The Release build has `RestartIfNecessary` on and does **not** set the AppID itself. Started by Steam, Steam supplies the AppID. Started by double-clicking the .exe, it asks Steam to launch AppID 4108310 and closes at once - Steam then starts the installed copy through the launch option above.
* Steam Input: set the game's Steam Input configuration on the partner site. If you point it at the action manifest in the install folder, the name is `steam_controllers.vdf` at the depot root. Xbox and generic controllers reach Steam Input only when it is enabled for the game (README, "Known issues").
* Files it writes: `VirtualGamepad.log` **next to the .exe**, i.e. in the Steam install folder (`steamapps\common\<install folder>\`), which is normally writable. If it cannot be written the program still runs and says "Log file NOT written" in its log.

## 5. Testing the Release folder before uploading

Copy exactly the depot files (section 2) into an empty folder and add, **for this test only**, a `steam_appid.txt` containing `4108310` - without it the double-clicked .exe hands over to Steam and closes (section 4). Start it with the Steam client running and logged in to an account that owns AppID 4108310. Delete `steam_appid.txt` before the folder becomes the depot.

(Debug builds set the AppID themselves and never relaunch through Steam, so they run from anywhere without `steam_appid.txt`; they are for development, not for the depot.)

## What it shows

Views (front, back, top), the glow on controls in use, trackpad touches and
the "in use" log lines are the same in all three VirtualGamepad demos: see
[docs/VirtualGamepadModels.md](../../docs/VirtualGamepadModels.md). The part
positions are compiled in (`src/PadParts.pas`), so no extra file is deployed.

## Check

At start the log prints `Data folder: <folder>` (must be the .exe's folder) and then either `Deployment OK: manifest, 11 layouts, 3 models` or `Deployment INCOMPLETE: ... missing: <files>`, naming exactly what is missing from the depot.
