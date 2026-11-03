# SteamDemoLCL (Lazarus / Free Pascal)

The Lazarus twin of SteamDemo: the TSteamAPI root component with TSteamFriends and TSteamUserStats on an LCL form, the shared component test and the two-user pair test. AppID 2275430. Building it is described in the repository [README](../../README.md) ("Building with Free Pascal / Lazarus") and [docs/Install-Lazarus-FPC.md](../../docs/Install-Lazarus-FPC.md).

This page says how to **deploy it on Windows**: which files the program needs and where they sit relative to the executable.

> **Release builds:** the Lazarus project has one build mode, and it compiles with `-dDEBUG` (the program sets the AppID itself and never relaunches through Steam). For a Steam depot add a Release build mode without `-dDEBUG` (Project -> Project Options -> Compiler Options -> Build modes; remove `-dDEBUG` under Custom Options): the program then uses `RestartIfNecessary` like the Delphi demos' Release builds. The files below are the same for both.

## 1. Build

```
demos\SteamDemoLCL\x86_64-win64\SteamDemoLCL.exe     (64-bit Lazarus)
demos\SteamDemoLCL\i386-win32\SteamDemoLCL.exe       (32-bit Lazarus)
```

Unlike the Delphi demos the Lazarus project has **no post-build copy**: copy the files below yourself.

## 2. What goes in the depot

Everything sits **next to the .exe** - no subfolders.

| File | Taken from |
|------|------------|
| `SteamDemoLCL.exe` | the build folder above |
| `steam_api64.dll` - x86_64-win64 build only | `redistributable_bin\win64\steam_api64.dll` |
| `steam_api.dll` - i386-win32 build only | `redistributable_bin\steam_api.dll` |

```
<program folder>\
    SteamDemoLCL.exe
    steam_api64.dll        (64-bit)   - or -   steam_api.dll   (32-bit)
```

* The DLL must match the build: a 64-bit .exe cannot load `steam_api.dll`, a 32-bit .exe cannot load `steam_api64.dll`.
* The DLL is loaded from the .exe's own folder: it must sit right next to it, not in a subfolder.
* Nothing else: the LCL, the library and the plug-ins are compiled into the .exe, and no other DLLs are needed.

## 3. What must NOT be copied

`demos\SteamDemoLCL\lib\` (compiled units: `*.o`, `*.ppu`), `backup\`, `*.lps`, `SteamDemo.log` (written at run time), and `steam_appid.txt`.

## 4. Running it

* **On Steam (Release build mode):** launch option on the partner site: executable `SteamDemoLCL.exe`, operating system Windows. Steam supplies the AppID; double-clicked, the .exe asks Steam to launch AppID 2275430 and closes.
* **Testing the Release folder before uploading:** add, for the test only, a `steam_appid.txt` containing `2275430` next to the .exe (otherwise it hands over to Steam and closes). Delete it before the folder becomes the depot.
* **The default (-dDEBUG) build** runs from any folder with Steam running and logged in to an account that owns AppID 2275430.

Files it writes: `SteamDemo.log` **next to the .exe** (in a Steam install folder: `steamapps\common\<install folder>\`, normally writable). If it cannot be written the program still runs and says "Log file NOT written"; its settings (File > Auto Start Steam) under `%APPDATA%\G3DGames\`.

## Check

The log names the Steam library it loaded (`Library <path>: <n> interface versions detected`). A "could not load" line means the DLL is missing, not next to the .exe or of the wrong bitness.
