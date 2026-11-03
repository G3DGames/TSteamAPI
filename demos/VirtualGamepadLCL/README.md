# VirtualGamepadLCL (Lazarus / Free Pascal + Castle Game Engine)

The Lazarus twin of VirtualGamepad: the 3D model of the connected controller in Castle Game Engine (LCL form + TCastleControl), animated from Steam Input, with the same overlay menu. AppID **480** (Valve's Spacewar). Building it is described in the repository [README](../../README.md) ("Building with Free Pascal / Lazarus").

This page says how to **deploy it on Windows**: which files the program needs and where they sit relative to the executable.

> **Not packaged for Steam.** This demo uses AppID 480 (Valve's Spacewar test app), so there is no Steam depot for it. The layout below is for copying it to another Windows machine (a Steam Deck running Windows, a tablet, ...).

## 1. Build

```
demos\VirtualGamepadLCL\x86_64-win64\VirtualGamepadLCL.exe     (64-bit Lazarus)
demos\VirtualGamepadLCL\i386-win32\VirtualGamepadLCL.exe       (32-bit Lazarus)
```

Unlike the Delphi demos the Lazarus project has **no post-build copy**: copy the files below yourself.

## 2. What goes in the program folder

Everything sits **next to the .exe** - no subfolders (the models too: not in a `models\` subfolder).

| File | Taken from |
|------|------------|
| `VirtualGamepadLCL.exe` | the build folder above |
| `steam_api64.dll` - x86_64-win64 build only | `redistributable_bin\win64\steam_api64.dll` |
| `steam_api.dll` - i386-win32 build only | `redistributable_bin\steam_api.dll` |
| `steam_input_manifest.vdf` | `demos\VirtualGamepadLCL\src\` |
| `controller_*.vdf` - 11 files, listed below | `demos\VirtualGamepadLCL\src\` |
| `XBoxOne_Animated.glb` | `models\` (repository root) |
| `PS5_Animated.glb` | `models\` (repository root) |
| `SteamController_Animated.glb` | `models\` (repository root) |

```
<program folder>\
    VirtualGamepadLCL.exe
    steam_api64.dll        (64-bit)   - or -   steam_api.dll   (32-bit)
    steam_input_manifest.vdf
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

* The DLL must match the build: a 64-bit .exe cannot load `steam_api.dll`, a 32-bit .exe cannot load `steam_api64.dll`.
* The DLL is loaded from the .exe's own folder: it must sit right next to it, not in a subfolder.
* All data is read from the .exe's folder. Only when a file is not there does the program fall back to the repository (`..\src\` for the manifest, `..\..\..\models\` for the models) - which is why a run from Lazarus works without copying and a deployed copy does not.
* The .vdf files are GENERATED (tools/gen_input_mapping.py) and identical to the Delphi VirtualGamepad's; ship the ones from `src\`.
* Castle Game Engine, the LCL, the library and the plug-ins are compiled into the .exe. The demo plays no sound and loads no font files, so it needs none of Castle Game Engine's optional Windows DLLs. Should a run report one missing, take it from Castle Game Engine's `tools\build-tool\data\external_libraries\x86_64-win64\` (or `i386-win32\`) and put it next to the .exe.

## 3. What must NOT be copied

`demos\VirtualGamepadLCL\lib\` (compiled units: `*.o`, `*.ppu`), `backup\`, `*.lps`, `VirtualGamepadLCL.log` (written at run time), and `steam_appid.txt`.

## 4. Running it

The Steam client must be running and logged in; AppID 480 is available to every account. The program sets the AppID itself and never relaunches through Steam: double-click it from any folder.

Files it writes: `VirtualGamepadLCL.log` **next to the .exe**: choose a folder you can write to. If it cannot be written the program still runs and says "Log file NOT written".

## Check

At start the log prints either `Deployment OK: manifest, 11 layouts, 3 models` or what is missing, naming exactly what to copy.
