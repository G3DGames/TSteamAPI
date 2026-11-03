# SteamDemoVCL (VCL)

The VCL twin of SteamDemo: the TSteamAPI root component with TSteamFriends and TSteamUserStats on a VCL form, the shared component test and the two-user pair test. AppID 2275430. Building it is described in the repository [README](../../README.md) ("Getting started") and [docs/Install-Delphi.md](../../docs/Install-Delphi.md).

This page says how to **deploy the Windows Release build** - the build that is packaged into a Steam depot: which files go in the depot and where they sit relative to the executable. macOS and Linux are deployed by the project's Deployment entries (Project -> Deployment), not covered here.

## 1. Build Release

In the IDE choose the **Release** configuration and the Windows platform you ship (Win64, or Win32), then Build. The executable goes to:

```
demos\SteamDemoVCL\Win64\Release\SteamDemoVCL.exe
demos\SteamDemoVCL\Win32\Release\SteamDemoVCL.exe
```

The post-build event copies the Steam library into the same folder and fails the build if a copy fails. So after a successful Release build that folder holds every file the depot needs - plus a few it must not contain (section 3).

## 2. What goes in the depot

Everything sits **in the depot's root folder, next to the .exe** - no subfolders.

| File | Taken from |
|------|------------|
| `SteamDemoVCL.exe` | `demos\SteamDemoVCL\Win64\Release\` (or `Win32\Release\`) |
| `steam_api64.dll` - Win64 build only | `redistributable_bin\win64\steam_api64.dll` |
| `steam_api.dll` - Win32 build only | `redistributable_bin\steam_api.dll` |

```
<depot root>\
    SteamDemoVCL.exe
    steam_api64.dll        (Win64 build)   - or -   steam_api.dll   (Win32 build)
```

* The DLL must match the build: a Win64 .exe cannot load `steam_api.dll`, a Win32 .exe cannot load `steam_api64.dll`. Shipping both bitnesses means two folders (or depots), each with its own .exe and DLL.
* The DLL is loaded from the .exe's own folder: it must sit right next to it, not in a subfolder.
* The window looks unthemed and slightly soft on a scaled display: that is the missing application manifest, left so on purpose (README, "Known issues"). Once enabled it is compiled into the .exe - there is no separate manifest file to ship.
* Nothing else: the VCL, the library and the plug-ins are compiled into the .exe (no .bpl runtime packages), and no other DLLs are needed.

## 3. What must NOT go in the depot

* `steam_appid.txt` - never ship it (it would stop Steam's relaunch check, section 4).
* `SteamDemo.log` - written at run time.
* `*.rsm`, `*.map`, `*.drc` - debug / map files, if your Release settings produce them.

## 4. On Steam

* **Launch option** (partner site, Installation -> General): executable `SteamDemoVCL.exe`, operating system Windows, no arguments, working folder empty (the depot root).
* The Release build has `RestartIfNecessary` on and does **not** set the AppID itself. Started by Steam, Steam supplies the AppID. Started by double-clicking the .exe, it asks Steam to launch AppID 2275430 and closes at once - Steam then starts the installed copy through the launch option above.
* Files it writes: `SteamDemo.log` **next to the .exe**, i.e. in the Steam install folder (`steamapps\common\<install folder>\`), which is normally writable. If it cannot be written the program still runs and says "Log file NOT written" in its log; its settings (File > Auto Start Steam) under `%APPDATA%\G3DGames\`.

## 5. Testing the Release folder before uploading

Copy exactly the depot files (section 2) into an empty folder and add, **for this test only**, a `steam_appid.txt` containing `2275430` - without it the double-clicked .exe hands over to Steam and closes (section 4). Start it with the Steam client running and logged in to an account that owns AppID 2275430. Delete `steam_appid.txt` before the folder becomes the depot.

(Debug builds set the AppID themselves and never relaunch through Steam, so they run from anywhere without `steam_appid.txt`; they are for development, not for the depot.)

## Check

The log names the Steam library it loaded and its SDK level (1.65). A "could not load" line means the DLL is missing, not next to the .exe or of the wrong bitness.
