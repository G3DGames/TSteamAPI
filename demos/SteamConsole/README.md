# SteamConsole

A console program with no framework, AppID 2275430. It opens Steam through a `TCustomSteamAPI` created in code (the same lifecycle as the `TSteamAPI` on a demo's form) and writes every step to the console with a time stamp, so the output can be pasted back as test evidence. Two projects build the same sources: **SteamConsole.dproj** (Delphi) and **SteamConsoleFPC.lpi** / `.lpr` (plain Free Pascal 3.2.2 - no LCL, no package; see the [Lazarus / FPC guide](../../docs/Install-Lazarus-FPC.md)). Building with Delphi is described in the repository [README](../../README.md).

## What it does

```
SteamConsole [seconds] [mode] [--test] [--pair] [--server] [--port <n>] [--query-port <n>]
```

`SteamConsole --help` prints this list. Switches can come in any order.

| Command | What runs | Ends |
|---------|-----------|------|
| `SteamConsole` / `SteamConsole 60` | Smoke test: what ten plug-ins report (interface versions, ISteamUtils, user, friends, apps, achievements, cloud, screenshots, timeline, UGC, the Steam Input shim), then callbacks are pumped | after *seconds* (default 3) |
| `SteamConsole --test` | The demos' component test (30 components, `demos/Shared/SteamComponentTest.pas`; it starts its own listen server for the 9 game-server rows) | when every row has its verdict |
| `SteamConsole --pair` | The demos' pair test (`demos/Shared/SteamPairTest.pas`): start it on a second PC with another Steam account - SteamConsole or any SteamDemo's **Pair** button | when the pair test ends |
| `SteamConsole --server` | A **dedicated** game server (`Roles = [srGameServer]`): no Steam client needed; logs on anonymously, is listed in the server browser, Steam answers its queries on the query port | Enter, Ctrl+C, or after *seconds* |
| `SteamConsole --server --test` (and / or `--pair`) | A **listen** server (client + server in this process) that the tests use as it is - the server path a game's own server takes when a test did not start it | Enter, Ctrl+C, or after *seconds* |

* **mode** - how callbacks are pumped (see [GameEngineIntegration.md](../../docs/GameEngineIntegration.md)); every callback line says which thread ran it: `manual` (default), `thread`, `main`, `worker`. `worker` is for the smoke test only: the tests and the server need their events on the main thread.
* **seconds** - smoke test: how long callbacks are pumped; tests and server: a time limit (default none).
* **--port / --query-port** - the game server's UDP ports (default 27015 / 27016; only with `--server`). They must differ: on a shared port the game would have to answer the queries itself.
* **A listen server that does not start** takes the client with it (the component's all-or-nothing start): the program reports why and ends with exit code 1.
* **Stopping**: Enter or Ctrl+C at any time; the program then finishes a running test (its cleanup needs Steam), stops advertising and logs the server off, and shuts Steam down. A second Ctrl+C ends it at once. Closing the console window, logging off and SIGTERM / SIGHUP (Linux, macOS) stop it the same way. When the input is not a console (redirected, or started by Steam) only the signals stop it.
* **Exit code**: 0 done (every test row PASS), 1 Steam - or the game server - did not start, 2 command line error or exception, 3 a test row did not pass.
* **Steam client exit**: on `SteamShutdown_t` (704) on the client's pipe SteamConsole stops at once, as a game should. A dedicated server has no client; a 704 on the server's own pipe is logged and the server keeps running.

### The dedicated server

Run it with the Steam client **closed** to test the dedicated path (with the client running it works too, but proves less). The AppID reaches Steam through the `SteamAppId` environment variable SteamConsole sets itself, so no `steam_appid.txt` is needed.

* Steam's game-server API loads `steamclient` from a Steam installation. A PC with the Steam client installed has it - **tested on Win64 with the client closed** (2026-11-04): the server logged on within a second, was VAC secure and was listed in the client's server browser. According to Valve's documentation a machine without the client needs SteamCMD (which installs it), or on Windows `steamclient64.dll`, `tier0_s64.dll` and `vstdlib_s64.dll` (32-bit: `steamclient.dll`, `tier0_s.dll`, `vstdlib_s.dll`) from a SteamCMD folder next to the executable; on Linux `~/.steam/sdk64/steamclient.so` - **not yet tested**. If the server does not start, the log line says what Steam answered.
* The game port and the query port must be reachable over UDP for other PCs to see it (a firewall prompt may appear on the first run). Look for the server in the Steam client: View > Game Servers > LAN (same network) or Internet / Favourites (add `<public IP>:<query port>`).
* The log shows: the server initialised (dedicated: no client), LogOnAnonymous, `SteamServersConnected_t` (101) on the server's pipe, its SteamID and public IP, VAC secure (`GSPolicyResponse_t`, 115 - it arrives a moment after 101, so the 101 line still says "secure no"), then a status line every minute.

## Windows Release deployment (Steam depot)

This part says how to **deploy the Windows Release build** - the build that is packaged into a Steam depot: which files go in the depot and where they sit relative to the executable. macOS and Linux are deployed by the project's Deployment entries (Project -> Deployment), not covered here.

### 1. Build Release

In the IDE choose the **Release** configuration and the Windows platform you ship (Win64, or Win32), then Build. The executable goes to:

```
demos\SteamConsole\Win64\Release\SteamConsole.exe
demos\SteamConsole\Win32\Release\SteamConsole.exe
```

The build copies the Steam library into the same folder and fails the build if a copy fails (the post-build event is one line, `call "$(PROJECTDIR)\deploy.bat" $(Platform) $(Config)`; `deploy.bat` in the project folder does the copying and names a missing file). `deploy.bat` also works on its own: double-click it (Win64 Release) or run `deploy.bat Win32 Debug`. So after a successful Release build that folder holds every file the depot needs - plus a few it must not contain (section 3).

### 2. What goes in the depot

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
* Nothing else: the RTL, the library, the plug-ins and the shared tests are compiled into the .exe (no .bpl runtime packages), and no other DLLs are needed for the smoke test and the tests. The dedicated server needs `steamclient` (above), which is not part of this depot.

### 3. What must NOT go in the depot

* `steam_appid.txt` - never ship it (it would stop Steam's relaunch check, section 4).
* `*.rsm`, `*.map`, `*.drc` - debug / map files, if your Release settings produce them.
* `src\SteamConsole.sh` - the Linux launcher script; not used on Windows.

### 4. On Steam

* **Launch option** (partner site, Installation -> General): executable `SteamConsole.exe`, operating system Windows, arguments as wanted (none = the smoke test; `--test` for the component test), working folder empty (the depot root).
* SteamConsole sets the AppID itself in every build (`SetAppIdEnvironment`) and does not use `RestartIfNecessary`, so it runs the same started by Steam or from a Command Prompt in the installed folder (`SteamConsole 60`, `SteamConsole --test`, `SteamConsole --server`).

### 5. Testing the Release folder before uploading

Copy the depot files into an empty folder, open a Command Prompt there and run `SteamConsole`, with the Steam client running and logged in to an account that owns AppID 2275430.

## Check

**Saving the output to a file:** `SteamConsole --test > test.log 2>&1` from a Command Prompt (or PowerShell 7). Windows PowerShell 5.1 wraps every line a native program writes to stderr - Steam writes `Setting breakpad minidump AppID = ...` there - in a red `NativeCommandError` block; that block is PowerShell's, not an error of the program.

The output names the Steam library it loaded and the number of interface versions found. A "could not load" line means the DLL is missing, not next to the .exe or of the wrong bitness. The smoke test and the server write no files; `--test` writes and deletes one Steam Cloud file and (when the Workshop is set up) a Workshop item, as the GUI demos' component test does.
