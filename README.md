# Steamworks for Delphi (FMX first, then VCL and FPC)

A Pascal binding of the Steamworks SDK **1.65**, built as a small **core**
(the Steam client part every other interface depends on) plus **plug-ins**,
one per Steam interface, so a game links only what it uses.

* Target order: **FMX** (now), **VCL** (next), **Free Pascal / Lazarus** (after).
  `lib/` is framework-free and written to compile with Delphi and FPC 3.2+
  (`{$mode delphi}`); only `fmx/` uses FireMonkey.
* Platforms: Win32, Win64, macOS (x64 / ARM64), Linux64. iOS / Android are
  not supported by Steamworks.
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
dlls/<Platform>/            Steam redistributable per Delphi platform name:
                            Win32, Win64, OSX64, OSXARM64, Linux64
demos/
  SteamDemo/                FMX demo: SteamDemo.dproj + .dpr, sources in src/
  SteamConsole/             console smoke test (no framework; FPC-ready)
tools/
  pasdoc_check.py           PasDoc coverage, ASCII and comment-nesting check
  project_check.py          .dproj BOM / XML / unit-list agreement check
  gen_projects.py           regenerates .dproj / .dpk / .groupproj from one list
```

## Getting started

1. Download `steamworks_sdk_165.zip` from the Steamworks partner site and copy
   the redistributables into `dlls/` (each folder's README.txt says which file).
2. Open `Steamworks.groupproj` in Delphi 13.
3. Build and run **SteamDemo** (or **SteamConsole**) with the Steam client
   running and logged in. Debug builds export `SteamAppId=2275430`, so no
   `steam_appid.txt` is needed. On Windows the post-build event copies the DLL
   next to the executable; on macOS / Linux it is deployed with the app.
4. To use the component at design time, build `SteamworksFMX` and install
   `dclSteamworksFMX` (palette page "Steamworks").

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
