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

  iOS has no Steam redistributable. `TSteamLib.RedistributableName` returns
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
  Steamworks.API.pas        TSteamLib: core flat exports; TSteamInterfaceVersions
  Steamworks.Callbacks.pas  TSteamCallbackDispatcher: callbacks + call results
  Steamworks.SteamClient.pas TSteamClientIntf: ISteamClient
  Steamworks.Versions.pas   *_INTERFACE_VERSION fallbacks
  Steamworks.SDKTypes.pas   GENERATED: every SDK typedef, enum, struct, callback struct, constant
  Steamworks.AlignNatural.inc / Steamworks.AlignDefault.inc   record alignment switches (SDKTypes)
  Steamworks.Core.pas       TSteamworks (core singleton), TSteamPlugin (plug-in base)
  Steamworks.Components.pas TCustomSteamAPI (base of every framework's TSteamAPI),
                            TSteamPluginComponent (base of the plug-in components)
  plugins/                  GENERATED, one unit per interface: plug-in class
                            (TSteamFriendsPlugin) + component (TSteamFriends):
    Steamworks.Plugin.Utils.pas      ISteamUtils (+ hand-written extras)
    Steamworks.Plugin.User.pas       ISteamUser
    Steamworks.Plugin.Friends.pas    ISteamFriends
    Steamworks.Plugin.Apps.pas       ISteamApps
    Steamworks.Plugin.UserStats.pas  ISteamUserStats (stats, achievements, leaderboards)
fmx/                        FireMonkey only
  Steamworks.FMX.pas        TSteamAPI for FMX (TTimer pump on the UI thread)
  Steamworks.FMX.Reg.pas    design-time registration of the FMX TSteamAPI
design/
  Steamworks.Reg.pas        GENERATED: registers the plug-in components (all frameworks)
packages/                   Steamworks (runtime: lib + plug-ins + components, no framework),
                            dclSteamworks (design: plug-in components),
                            SteamworksFMX (runtime: FMX TSteamAPI), dclSteamworksFMX (design)
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
  gen_steam_api.py          generates SDKTypes and the plug-ins from the SDK (see below)
  verify_generated.py       checks generated layouts and signatures against the SDK headers
  plugin_extras/            hand-written parts merged into generated plug-ins
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
4. To use the components at design time, for the IDE's platform (Win64 for
   the 64-bit IDE, Win32 for the 32-bit IDE):
   1. **Build** (do not install) the runtime packages `Steamworks`, then
      `SteamworksFMX`. Their `.dcp` / `.bpl` go to Delphi's default `Dcp` /
      `Bpl` folders.
   2. **Install** `dclSteamworks` (the plug-in components: TSteamUtils,
      TSteamUser, TSteamFriends, TSteamApps, TSteamUserStats) and
      `dclSteamworksFMX` (the FMX TSteamAPI). They appear on the "Steamworks"
      palette page.

   Building a design package from the project group builds the runtime
   packages it needs first. Programs that do not use runtime packages need
   none of them - they compile the units directly.

### In your own project

The design packages only give the IDE the components; your project compiles
the units from source, so Delphi must know where they are. Once, for every
platform you build for (a new project starts on Win32; the Library path is
kept per platform): **Tools > Options > Language > Delphi > Library**,
choose the platform under *Selected Platform*, and add the repository's
`lib`, `lib\plugins` and `fmx` folders to the **Library path** (`lib` also
provides `Steamworks.inc`). Without that, the first build stops with
`F2613 Unit 'Steamworks.FMX' not found`. Alternatively add the same folders
to the project's own search path.

At run time the program needs the Steam library for its platform next to the
executable (`steam_api.dll` for Win32, `steam_api64.dll` for Win64; see the
platform table) and must tell Steam its AppID: set
`SetAppIdEnvironment := True` in development builds, or put a
`steam_appid.txt` containing the AppID next to the executable. The demos'
project files do both for you.

Then:

```pascal
uses Steamworks.Core, Steamworks.SDKTypes, Steamworks.FMX, Steamworks.Plugin.Utils,
  Steamworks.Plugin.Friends;

procedure TMainForm.FormCreate(Sender: TObject);
begin
  FSteam := TSteamAPI.Create(Self);
  FSteam.AppID := 2275430;
  {$ifdef DEBUG}
  FSteam.SetAppIdEnvironment := True;   // development only
  {$else}
  FSteam.RestartIfNecessary := True;    // relaunch through Steam if started directly
  {$endif}
  FFriends := TSteamFriends.Create(Self);          // or drop both on the form
  FFriends.SteamAPI := FSteam;                     // automatic when dropped together
  FFriends.OnPersonaStateChange := FriendChanged;  // typed: const AData: PersonaStateChange_t
  if FSteam.Open then
    Caption := FSteam.Steam.Plugin<TSteamUtilsPlugin>.GetSteamUILanguage
      + ' / ' + FFriends.Plugin.GetPersonaName;
end;
```

### Components
Every framework unit declares a `TSteamAPI` with the same properties and
events (FMX now; VCL and LCL next), all built on `TCustomSteamAPI` in
`Steamworks.Components`, which holds the whole lifecycle. Each generated
plug-in unit also declares a component named after the interface -
`TSteamUtils`, `TSteamUser`, `TSteamFriends`, `TSteamApps`, `TSteamUserStats`
- that works with any framework:

* `SteamAPI` links it to the root; at run time a component whose owner has
  exactly one `TSteamAPI` links itself.
* One published, typed event per callback of its interface
  (`OnPersonaStateChange(Sender; const AData: PersonaStateChange_t)`). Events
  are subscribed while Steam runs (`Attached`) and removed when it stops.
  Steam reports each payload's C size; if it differs from the Pascal record,
  the event is not raised and `ESteamworksError` says so (shown through the
  root's exception handling) - a layout mismatch never passes silently.
* Call results reach the component's events too (`TSteamUserStats.
  OnLeaderboardFindResult` after `Plugin.FindLeaderboard(...)`), unless an
  `...Async` call registered its own handler for that call. A call result that
  failed (`IOFailure`) raises no event; it is logged as a warning.
* `Plugin` gives the interface's methods (`FFriends.Plugin.GetPersonaName`);
  it is nil while Steam is not running.
* At design time the IDE adds the units the generated event handlers need
  (`Steamworks.SDKTypes`, `Steamworks.Callbacks`, ...) to the form's uses.
* Do not free `TSteamAPI` inside one of its own or a plug-in component's
  events (they run from its timer); call `Close` there and free it later.

Only the components (and so the plug-ins) you drop or use are linked in.

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
so `TSteamLib.Unload` clears its table before unloading.
Before loading, the core logs the build target and how it runs
(`TSteamLib.PlatformDescription`, e.g. `macOS x64 build, running under
Rosetta 2`; Windows x86/x64 builds report WOW64 or ARM64 emulation).

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
  so close handling must be safe to run twice. `TSteamAPI.Close` is.
* **Console app (SteamConsole):** Steam sends `SteamShutdown_t` (callback 704,
  `OnSteamShutdown`), then `SteamServersDisconnected_t` (103), and ends the
  process about 10 s later if it is still running. SteamConsole shows the
  right response: save, shut down and exit on 704.

Observed with SDK 1.65 on Linux64 (Steam -> Exit while SteamDemo runs):

* **Windowed app:** no close request and the process is NOT ended. Steam sends
  `SteamShutdown_t` (704) **twice**, about 1.5 s apart, and by the second its
  pipe is gone. Every Steam call after that - `SteamAPI_Shutdown` included -
  makes steamclient print `Broken pipe` assertions and write minidumps to
  `/tmp/dumps`.

So the core shuts SteamAPI down on the first 704 (`ShutdownOnSteamExit`,
default on, also on the FMX component), right after `OnSteamShutdown`
returns: Steam calls still work inside that handler, nothing calls into the
dead pipe afterwards, and `OnSteamShutdown` is raised once per session. The
application keeps running; call `Initialize` / `Open` again once Steam is back.

Everywhere: save state in your close / `OnSteamShutdown` handling, and do not
assume a close request comes only once. `QuitOnSteamShutdown` on the FMX
component also quits the application on 704.

### Interface versions
Each flat function is compiled against one interface version, so the version
string must match the redistributable. The core scans the loaded library for
its version literals (`SteamUtils010`, `STEAMAPPS_INTERFACE_VERSION008`, ...)
and resolves every lookup through that; `Steamworks.Versions.pas` holds
fallbacks. The demo's "Show info" lists what was detected.

### Plug-ins
A plug-in is a `TSteamPlugin` descendant registered in its unit's
initialization section; linking the unit enables it. The interface plug-ins
are generated (`tools/gen_steam_api.py`), so they all look alike:

```pascal
uses Steamworks.Types, Steamworks.SDKTypes, Steamworks.Plugin.Friends, Steamworks.Plugin.UserStats;
...
Friends := TSteamFriendsPlugin(Steam.FindPlugin(TSteamFriendsPlugin));
Writeln(Friends.GetPersonaName, ' has ', Friends.GetFriendCount(k_EFriendFlagImmediate), ' friends');
Stats.FindLeaderboardAsync('Highscores', OnLeaderboardFound);   // call result -> handler
Stats.Flat.GetNumAchievements(Stats.Handle);                    // raw export, exact C signature
```

* Methods are named after the flat export (`GetStatInt32`, not the C++
  overload `GetStat`) and keep Valve's parameter names. `const char*` is a
  `string`, returned C strings become `string`, 64-bit Steam ids are
  `TSteamID`, single out-values are `var` parameters; buffers, arrays and
  optional (NULL-able) pointers stay `Pointer` with their count parameter.
* Methods returning a `SteamAPICall_t` whose result struct is known have an
  `...Async(..., AHandler)` version that registers the handler (owned by the
  handler's object - remove with `Steam.Dispatcher.RemoveOwner`).
* Every export is bound as optional. Exports the loaded library lacks are
  logged once at start-up; calling one raises `ESteamworksError` naming it.
  `Assigned(P.Flat.Xxx)` tells whether an export is available.
* Callbacks: subscribe to `<Struct>_k_iCallback` (all in `Steamworks.SDKTypes`)
  and copy the payload into the generated record with `AData.CopyTo`.
* Hand-written additions (events, helpers, deprecated exports) live in
  `tools/plugin_extras/<Name>.pas.txt` and are merged by the generator -
  never edit a generated unit.

Struct rules (the generator applies them; follow them in hand-written code):
include `Steamworks.inc` (packing 8 on Windows, 4 elsewhere, 4-byte enums);
C `bool` is `Boolean`; structs under `#pragma pack(1)` are `packed record`
(this includes `CSteamID` / `TSteamID` and `CGameID`, which are therefore only
byte-aligned inside other structs); structs outside any pack region use C
natural alignment (`Steamworks.AlignNatural.inc`); C++ reference parameters
are pointers; pointer-sized C types (`intp`, `size_t`) are `NativeInt` /
`NativeUInt`.

### Regenerating the binding
The SDK files are a Steamworks partner download and are never committed.
With the SDK's `public/steam` folder (headers and `steam_api.json`):

```
python3 tools/gen_steam_api.py   <sdk>/public/steam
python3 tools/verify_generated.py <sdk>/public/steam
python3 tools/pasdoc_check.py
python3 tools/project_check.py
```

`verify_generated.py` compiles the SDK headers with clang (any OS; no
platform SDKs needed) for Win64, Win32, Linux x86_64 and macOS ARM64 and
compares every generated record's size, alignment and field offsets with the
C layout, and every flat signature with `steam_api_flat.h`. The generator
prints what it could not generate and why (structs containing C unions -
`steam_api.json` lists union members as separate fields - and structs only
forward-declared in the public headers). New interfaces are added to the
`PLUGINS` table in `gen_steam_api.py` and `tools/gen_projects.py`.

## SDK 1.65 notes
* `ISteamUtils::IsRunningOnSteamDeck()` was removed; the Utils plug-in binds it
  only when an older redistributable exports it (wrapper is `deprecated`).
* New in 1.65: `IsRunningOnSteamHardware()` (`ESteamHardwareType`),
  `GetSteamHardwareDefaultConfig()` (`ESteamHardwareDefaultConfig`) and
  `IsRunningUnderProton()`.
* `ISteamGameSearch` and `ISteamMusicRemote` are gone (no header, not in
  `steam_api.json`, no version string in the redistributables).

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
  `isteamclient.h`) done.
* Generated: all SDK types, and plug-ins for Utils, User, Friends, Apps and
  UserStats.
* Next batches: RemoteStorage, UGC, Screenshots, Timeline, Input, HTTP,
  Inventory, Matchmaking, Networking* (needs C union support in the
  generator), HTMLSurface, Video, ParentalSettings, RemotePlay, Music.
* VCL component (`vcl/`), then Lazarus/FPC component and `.lpi` projects.
* Game-server API (`SteamGameServer_*`).
