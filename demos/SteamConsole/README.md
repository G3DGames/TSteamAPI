# SteamConsole

A console program with no framework: it opens Steam, logs what ten plug-ins report and pumps callbacks for a while. AppID 2275430. Usage: `SteamConsole [seconds] [mode]` - seconds of callback pumping (default 3), update mode `manual` (default), `thread`, `main` or `worker` (see [docs/GameEngineIntegration.md](../../docs/GameEngineIntegration.md)). Building it is described in the repository [README](../../README.md).

This page says how to **deploy the Windows Release build** - the build that is packaged into a Steam depot: which files go in the depot and where they sit relative to the executable. macOS and Linux are deployed by the project's Deployment entries (Project -> Deployment), not covered here.

## 1. Build Release

In the IDE choose the **Release** configuration and the Windows platform you ship (Win64, or Win32), then Build. The executable goes to:

```
demos\SteamConsole\Win64\Release\SteamConsole.exe
demos\SteamConsole\Win32\Release\SteamConsole.exe
```

The post-build event copies the Steam library into the same folder and fails the build if a copy fails. So after a successful Release build that folder holds every file the depot needs - plus a few it must not contain (section 3).

## 2. What goes in the depot

Everything sits **in the depot's root folder, next to the .exe** - no subfolders.

| File | Taken from |
|------|------------|
| `SteamConsole.exe` | `demos\SteamConsole\Win64\Release\` (or `Win32\Release\`) |
| `steam_api64.dll` - Win64 build only | `redistributable_bin\win64\steam_api64.dll` |
| `steam_api.dll` - Win32 build only | `redistributable_bin\steam_api.dll` |

```
<depot root>\
    SteamConsole.exe
    steam_api64.dll        (Win64 build)   - or -   steam_api.dll   (Win32 build)
```

* The DLL must match the build: a Win64 .exe cannot load `steam_api.dll`, a Win32 .exe cannot load `steam_api64.dll`. Shipping both bitnesses means two folders (or depots), each with its own .exe and DLL.
* The DLL is loaded from the .exe's own folder: it must sit right next to it, not in a subfolder.
* Nothing else: the RTL, the library and the plug-ins are compiled into the .exe (no .bpl runtime packages), and no other DLLs are needed.

## 3. What must NOT go in the depot

* `steam_appid.txt` - never ship it (it would stop Steam's relaunch check, section 4).
* `*.rsm`, `*.map`, `*.drc` - debug / map files, if your Release settings produce them.
* `src\SteamConsole.sh` - the Linux launcher script; not used on Windows.

## 4. On Steam

* **Launch option** (partner site, Installation -> General): executable `SteamConsole.exe`, operating system Windows, no arguments, working folder empty (the depot root).
* SteamConsole sets the AppID itself in every build (`SetAppIdEnvironment`) and does not use `RestartIfNecessary`, so it runs the same started by Steam or from a Command Prompt in the installed folder (`SteamConsole 60`, `SteamConsole 60 thread`).

## 5. Testing the Release folder before uploading

Copy the depot files into an empty folder, open a Command Prompt there and run `SteamConsole`, with the Steam client running and logged in to an account that owns AppID 2275430.

## Check

The output names the Steam library it loaded and the number of interface versions found. A "could not load" line means the DLL is missing, not next to the .exe or of the wrong bitness. It writes no files.
