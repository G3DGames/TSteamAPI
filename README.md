# Steamworks for Delphi (FMX first, then VCL and FPC)

A Pascal binding of the Steamworks SDK **1.65**, built as a small **core**
(the Steam client part every other interface depends on) plus **plug-ins**,
one per Steam interface, so a game links only what it uses.

* Target order: **FMX** (now), **VCL** (next), **Free Pascal / Lazarus** (after).
  `lib/` is framework-free and written to compile with Delphi and FPC 3.2+
  (`{$mode delphi}`); only `fmx/` uses FireMonkey.
* Platforms - everything Valve ships a redistributable for:

  | Platform        | Delphi target | FPC target      | redistributable_bin/            |
  |-----------------|---------------|-----------------|---------------------------------|
  | Windows 32-bit  | Win32         | i386-win32      | `steam_api.dll`                 |
  | Windows 64-bit  | Win64         | x86_64-win64    | `win64/steam_api64.dll`         |
  | macOS Intel     | OSX64         | x86_64-darwin   | `osx/libsteam_api.dylib`        |
  | macOS ARM       | OSXARM64      | aarch64-darwin  | `osx/libsteam_api.dylib`        |
  | Linux x86_64    | Linux64       | x86_64-linux    | `linux64/libsteam_api.so`       |
  | Linux i386      | -             | i386-linux      | `linux32/libsteam_api.so` (may be dropped) |
  | Linux ARM64     | -             | aarch64-linux   | `linuxarm64/libsteam_api.so`    |
  | Android ARM64   | Android64     | aarch64-android | `androidarm64/libsteam_api.so`  |

  iOS has no Steam redistributable. `TSteamAPI.RedistributableName` returns
  the file the running build needs, and load errors name it.
* Project AppID: **2275430** (owned by the project; Valve's public test app
  480 "Spacewar" also works).

## Repository layout

```
Steamworks.groupproj        project group: demos + packages
lib/                        framework-free library (Delphi + FPC)
  Steamworks.inc            compiler / packing settings - include in every unit
  Steamworks.Types.pas      handles, CSteamID, ESteamAPIInitResult, CallbackMsg_t ...
  Steamworks.DynLib.pas     TSteamDynLib: cross-platform library loading
  Steamworks.API.pas        TSteamAPI: core flat exports; TSteamInterfaceVersions
  Steamworks.Callbacks.pas  TSteamCallbackDispatcher: callbacks + call results
  Steamworks.SteamClient.pas TSteamClientIntf: ISteamClient
  Steamworks.Versions.pas   *_INTERFACE_VERSION fallbacks
  Steamworks.Core.pas       TSteamworks (core singleton), TSteamPlugin (plug-in base)
  plugins/
    Steamworks.Plugin.Utils.pas   ISteamUtils - reference plug-in / template
fmx/                        FireMonkey only
  Steamworks.FMX.pas        TSteamworksFMX component (TTimer pump on the UI thread)
  Steamworks.FMX.Reg.pas    design-time registration
packages/                   SteamworksFMX (runtime), dclSteamworksFMX (design time)
redistributable_bin/        copy of sdk/redistributable_bin from the SDK
                            (git-ignored except its README.md)
demos/
  SteamDemo/                FMX demo: SteamDemo.dproj + .dpr, sources in src/
  SteamConsole/             console smoke test (no framework; FPC-ready)
tools/
  pasdoc_check.py           PasDoc coverage, ASCII and comment-nesting check
  check_redist.py           validates all seven redistributables (type, CPU, SDK level)
  project_check.py          .dproj BOM / XML / unit-list agreement check
  gen_projects.py           creates missing .dproj / .dpk / .groupproj (IDE-saved files win)
```

## Getting started

1. Download `steamworks_sdk_165.zip` from the Steamworks partner site and copy
   the contents of `sdk/redistributable_bin` into `redistributable_bin/`.
   Check the result with `python3 tools/check_redist.py` (see
   `redistributable_bin/README.md`).
2. Open `Steamworks.groupproj` in Delphi 13.
3. Build and run **SteamDemo** (or **SteamConsole**; `SteamConsole 60` pumps
   callbacks for 60 s instead of 3) with the Steam client
   running and logged in. Debug builds export `SteamAppId=2275430`, so no
   `steam_appid.txt` is needed. On Windows the post-build event copies the DLL
   next to the executable and fails the build if it is missing; on macOS / Linux it is deployed with the app.
4. To use the component at design time:
   1. **Build** (do not install) `SteamworksFMX` for the IDE's platform:
      Win64 for the 64-bit IDE, Win32 for the 32-bit IDE. It is runtime-only;
      its `.dcp` / `.bpl` go to Delphi's default `Dcp` / `Bpl` folders.
   2. **Install** `dclSteamworksFMX` (same platform). The component appears on
      the "Steamworks" palette page.

   Building `dclSteamworksFMX` from the project group builds `SteamworksFMX`
   first. Programs that do not use runtime packages need neither package -
   they compile the units directly.

### In your own project

Add `lib`, `lib/plugins` and (for FMX) `fmx` to the search path and include
path, then:

```pascal
uses Steamworks.Core, Steamworks.FMX, Steamworks.Plugin.Utils;

procedure TMainForm.FormCreate(Sender: TObject);
begin
  FSteam := TSteamworksFMX.Create(Self);
  FSteam.AppID := 2275430;
  {$ifdef DEBUG}
  FSteam.SetAppIdEnvironment := True;   // development only
  {$else}
  FSteam.RestartIfNecessary := True;    // relaunch through Steam if started directly
  {$endif}
  if FSteam.Open then
    Caption := FSteam.Steam.Plugin<TSteamUtilsPlugin>.SteamUILanguage;
end;
```

Without any component (console, game loop, VCL, FPC):

```pascal
Steam.AppID := 2275430;
if Steam.RestartAppIfNecessary then Halt;
if Steam.Initialize then
begin
  // every frame / 15-50 ms, always from the same thread:
  Steam.RunCallbacks;
  ...
  Steam.Shutdown;
end
else
  Writeln(Steam.LastError);
```

## Design

### Library loading (`TSteamDynLib`)
Modelled on Castle Game Engine's `TDynLib` (one object per library, selectable
policy for missing symbols, `Load` that raises or returns nil) with fixes:
it searches the executable folder and the macOS bundle (`Contents/MacOS`,
`Contents/Frameworks`) before the OS path, reports every path tried with the
OS error, raises warnings through an event instead of a logging framework, and
takes symbol names as `string`. Bound pointers dangle once a library is freed,
so `TSteamAPI.Unload` clears its table before unloading.

### Initialisation (`TSteamworks.InitMode`)
* `simAuto` (default): `SteamAPI_InitFlat` when exported (SDK 1.59+), else legacy init.
* `simFlat`: `SteamAPI_InitFlat`, Valve's entry point for non-C++ code.
* `simVersioned`: `SteamInternal_SteamAPI_Init` with only the interface
  versions the linked plug-ins declare.
* `simLegacy`: `SteamAPI_Init` from pre-1.59 redistributables.

`LastInitResult` / `LastError` carry Steam's own diagnostic text on failure.

### Callbacks
Manual dispatch (`SteamAPI_ManualDispatch_*`) replaces the C++ `CCallback` /
`CCallResult` templates. `RunCallbacks` drains the queue and delivers each
payload on the calling thread. CGE's Steam unit uses the same approach, noting
that `SteamAPI_RunCallbacks` crashed on Linux x86_64.

The portable API uses method pointers, which FPC 3.2 supports:

```pascal
procedure TGame.LowBattery(const AData: TSteamCallbackData);
var Ev: LowBatteryPower_t;
begin
  if AData.CopyTo(Ev, SizeOf(Ev)) then
    ShowWarning(Ev.m_nMinutesBatteryLeft);
end;
...
Steam.Dispatcher.Subscribe(LowBatteryPower_t_k_iCallback, LowBattery);
Steam.Dispatcher.AwaitCallResult(Call, 1107, NumberOfPlayersReceived);
...
Steam.Dispatcher.RemoveOwner(Self);   // in the destructor
```

With compilers that support anonymous methods (`STEAMWORKS_ANONYMOUS_METHODS`:
Delphi, FPC 3.3.1+) typed closures are available too:
`Steam.Dispatcher.SubscribeTyped<LowBatteryPower_t>(702, procedure(const D: LowBatteryPower_t) ...)`
and `AwaitCallResultTyped<T>`. `Steam.Plugin<T>` is Delphi-only; `Steam.FindPlugin(TClass)`
works everywhere.

A handler that raises never wedges the queue (`FreeLastCallback` always runs);
the exception goes to `OnHandlerError` (the FMX component shows it with
`Application.HandleException`). `Shutdown` from inside a handler is deferred
until that callback finishes. Steam's warning hook may fire on any thread, so
warnings are queued and delivered from `RunCallbacks`.

### When the Steam client exits
Observed with SDK 1.65 on Windows (Steam -> Exit while a demo runs):

* **Windowed app (SteamDemo):** Steam asks the window to close at once - no
  `SteamShutdown_t` arrives first. The form's normal close path runs and
  SteamAPI shuts down cleanly. The close request arrived **twice** (probably
  one per top-level window: FMX's hidden application window and the form),
  so close handling must be safe to run twice. `TSteamworksFMX.Close` is.
* **Console app (SteamConsole):** Steam sends `SteamShutdown_t` (callback 704,
  `OnSteamShutdown`), then `SteamServersDisconnected_t` (103), and ends the
  process about 10 s later if it is still running. SteamConsole shows the
  right response: save, shut down and exit on 704.

Either way: save state in your close / `OnSteamShutdown` handling, and do not
assume it runs only once. `QuitOnSteamShutdown` on the FMX component quits on
704 automatically.

### Interface versions
Each flat function is compiled against one interface version, so the version
string must match the redistributable. The core scans the loaded library for
its version literals (`SteamUtils010`, `STEAMAPPS_INTERFACE_VERSION008`, ...)
and resolves every lookup through that; `Steamworks.Versions.pas` holds
fallbacks. The demo's "Show info" lists what was detected.

### Plug-ins
A plug-in is a `TSteamPlugin` descendant registered in its unit's
initialization section; linking the unit enables it. See
`lib/plugins/Steamworks.Plugin.Utils.pas` for the full pattern:
`AcquireUserInterface`, `Bind` (required / optional exports), `Subscribe`,
`AwaitCallResult`, `Dependencies`, `IsRequired`, `InterfaceVersions`.
Struct rules: include `Steamworks.inc` (packing 8 on Windows, 4 elsewhere,
4-byte enums); C `bool` is `Boolean`; structs under `#pragma pack(1)` are
`packed record`; C++ reference parameters are pointers.

## SDK 1.65 notes
* `ISteamUtils::IsRunningOnSteamDeck()` was removed; the Utils plug-in binds it
  only when an older redistributable exports it (wrapper is `deprecated`).
* `IsRunningOnSteamHardware()` (returned as a raw integer) and
  `IsRunningUnderProton()` are optional exports.
* `GetSteamHardwareDefaultConfig()` is not wrapped yet (needs the 1.65 header struct).

## Building with Free Pascal (planned)
`lib/` and the console demo are written for FPC 3.2 `{$mode delphi}`:

```
cd demos/SteamConsole
fpc -Fu../../lib -Fu../../lib/plugins -Fi../../lib -Fusrc SteamConsole.dpr
```

FPC / Lazarus build output (`*.o`, `*.ppu`, `lib/<cpu>-<os>/`, `backup/`,
`*.lps`, extensionless demo executables, ...) is ignored by `.gitignore`.

## Checks before delivery
```
python3 tools/pasdoc_check.py
python3 tools/project_check.py
```

## Status / next steps
* Core (`steam_api.h`, `steam_api_common.h`, `steam_api_internal.h`,
  `isteamclient.h`) and ISteamUtils done.
* Remaining interface plug-ins (User, Friends, UserStats, Apps, RemoteStorage,
  UGC, Input, Networking*, Matchmaking, Inventory, Timeline, ...). The SDK's
  `public/steam/steam_api.json` describes every flat function, struct, enum and
  callback; generating plug-in units from it is the practical route to full
  coverage and to future SDK updates.
* VCL component (`vcl/`), then Lazarus/FPC component and `.lpi` projects.
* Game-server API (`SteamGameServer_*`).
