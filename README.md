# Steamworks for Delphi (FMX first, then VCL and FPC)

A Pascal binding of the Steamworks SDK **1.65**, built as a small **core**
(the Steam client part every other interface depends on) plus **plug-ins**,
one per Steam interface, so a game links only what it uses.

* Target order: **FMX** (now), **VCL** (next), **Free Pascal / Lazarus** (after).
  `lib/` is framework-free and written to compile with Delphi (13
  recommended; earlier versions will be tested later, no guarantee yet) and FPC 3.2.2
  (`{$mode delphi}`; the FPC version Castle Game Engine uses); `fmx/`,
  `vcl/` and `lcl/` hold the framework-specific units.
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

**Documentation:** [docs/](docs/README.md) -
[Install (Delphi)](docs/Install-Delphi.md),
[Install (Lazarus / FPC)](docs/Install-Lazarus-FPC.md),
[Game engine integration](docs/GameEngineIntegration.md) (timer, worker
thread or your own loop; CGE, Gorilla3D, Skia4Delphi, PasVulkan, ...),
[Steam Input mapping](docs/SteamInputMapping.md) (action manifests, default
layouts, origins to physical buttons)
and [one page per component / plug-in](docs/components/README.md).

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
    Steamworks.Plugin.RemoteStorage.pas  ISteamRemoteStorage (Steam Cloud files)
    Steamworks.Plugin.Screenshots.pas    ISteamScreenshots
    Steamworks.Plugin.Timeline.pas       ISteamTimeline (game recording markers)
    Steamworks.Plugin.UGC.pas            ISteamUGC (Workshop)
    Steamworks.Plugin.Input.pas          ISteamInput (controllers; three methods
                                         hand-written per platform - by-value structs)
fmx/                        FireMonkey only
  Steamworks.FMX.pas        TSteamAPI for FMX (TTimer pump on the UI thread)
  Steamworks.FMX.Reg.pas    design-time registration of the FMX TSteamAPI
vcl/                        VCL only (Delphi, Windows)
  Steamworks.VCL.pas        TSteamAPI for VCL (VCL TTimer), SteamImageToBitmap
  Steamworks.VCL.Reg.pas    design-time registration of the VCL TSteamAPI
lcl/                        LCL only (Lazarus / Free Pascal)
  Steamworks.LCL.pas        TSteamAPI for LCL (LCL TTimer), SteamImageToBitmap
design/
  Steamworks.Reg.pas        GENERATED: registers the plug-in components (all frameworks)
packages/                   Steamworks (runtime: lib + plug-ins + components, no framework),
                            dclSteamworks (design: plug-in components),
                            SteamworksFMX (runtime: FMX TSteamAPI), dclSteamworksFMX (design),
                            SteamworksVCL (runtime: VCL TSteamAPI), dclSteamworksVCL (design)
redistributable_bin/        copy of sdk/redistributable_bin from the SDK
                            (git-ignored except its README.md)
demos/
  SteamDemo/                FMX demo: SteamDemo.dproj + .dpr, form in src/ (uMain.pas / .fmx)
  SteamDemoVCL/             VCL demo (Delphi project), form in src/ (uMain.pas / .dfm)
  SteamDemoLCL/             LCL demo (Lazarus .lpi / .lpr), form in src/ (uMain.pas / .lfm)
                            - all three: TSteamAPI, TSteamFriends, TSteamUserStats dropped on the form
  SteamConsole/             console smoke test (no framework; FPC-ready)
  SteamInputDemo/           Steam Input test (FMX): action manifest in src/, the
                            connected controller identified at the top, live
                            digital / analog / motion values, bindings; opens
                            Steam by itself; File menu: View Controller
                            Settings, Rumble, Send log to receiver (optional,
                            see RemoteLogging/; also DPadUp + Y + LeftBumper
                            together on the pad, for SteamOS), Exit
RemoteLogging/              OPTIONAL, nothing to do with Steam: LogReceiver app +
                            RemoteLog.Sender unit to stream a program's log to a
                            desk machine (e.g. from a Steam Deck); see its README
models/                     CC0 3D gamepad models (glTF .glb, rigged, one clip per
                            input): XBoxOne_Animated, PS5_Animated,
                            SteamController_Animated; LICENSE (CC0, credits)
docs/                       user documentation (Markdown)
  Install-Delphi.md, Install-Lazarus-FPC.md, GameEngineIntegration.md,
  SteamInputMapping.md
  components/               TSteamAPI.md + README.md (hand-written),
                            TSteam<Name>.md: GENERATED by tools/gen_docs.py
tools/
  pasdoc_check.py           PasDoc coverage, ASCII and comment-nesting check
  gen_docs.py               generates docs/components/TSteam<Name>.md from the plug-in units
  gen_input_mapping.py      writes SteamInputDemo's Steam Input manifest and default layouts
  doc_extras/               hand-written overview text merged into those pages
  check_redist.py           validates all seven redistributables (type, CPU, SDK level)
  project_check.py          .dproj BOM / XML / unit-list agreement check
  gen_projects.py           creates missing .dproj / .dpk / .groupproj (IDE-saved files win)
  gen_steam_api.py          generates SDKTypes and the plug-ins from the SDK (see below)
  verify_generated.py       checks generated layouts and signatures against the SDK headers
  plugin_extras/            hand-written parts merged into generated plug-ins
```

## Getting started

Step by step, with every alarming-looking message explained:
[docs/Install-Delphi.md](docs/Install-Delphi.md) and
[docs/Install-Lazarus-FPC.md](docs/Install-Lazarus-FPC.md). In short:

1. Download `steamworks_sdk_165.zip` from the Steamworks partner site and copy
   the contents of `sdk/redistributable_bin` into `redistributable_bin/`.
   Check the result with `python3 tools/check_redist.py` (see
   `redistributable_bin/README.md`).
2. Open `Steamworks.groupproj` in Delphi 13. For each platform you build
   for, build the runtime packages `Steamworks` and `SteamworksFMX` first
   (**Build All** does: the group lists the applications first, then the
   runtime and design packages, but builds in dependency order): the demos - like
   your own projects - link the units those packages compile into Delphi's
   `Dcp` folder (step 4) and have no path to the library sources. After
   changing library sources, rebuild the packages before the demos.
3. Build and run **SteamDemo** (or **SteamConsole**; `SteamConsole 60` pumps
   callbacks for 60 s instead of 3) with the Steam client
   running and logged in. Debug builds export `SteamAppId=2275430`, so no
   `steam_appid.txt` is needed. On Windows the post-build event copies the DLL
   next to the executable and fails the build if it is missing; on macOS / Linux it is deployed with the app.
4. To use the components at design time, for the IDE's platform (Win64 for
   the 64-bit IDE, Win32 for the 32-bit IDE):
   1. **Build** (do not install) the runtime packages `Steamworks`, then
      `SteamworksFMX` and / or `SteamworksVCL`. Their `.dcp` / `.bpl` go to Delphi's default `Dcp` /
      `Bpl` folders, and their compiled units (`.dcu`) go to the same `Dcp`
      folder (`$(BDSCOMMONDIR)\Dcp` for Win32, `$(BDSCOMMONDIR)\Dcp\<platform>`
      otherwise), which is on the IDE's default Library path - so your own
      projects need no extra paths. Build them once for every platform you
      target (Win32, Win64, ...); the last configuration built (Debug or
      Release) is the one your projects link.
   2. **Install** `dclSteamworks` (the plug-in components: TSteamUtils,
      TSteamUser, TSteamFriends, TSteamApps, TSteamUserStats,
      TSteamRemoteStorage, TSteamScreenshots, TSteamTimeline, TSteamUGC,
      TSteamInput) and
      `dclSteamworksFMX` (the FMX TSteamAPI) and / or `dclSteamworksVCL`
      (the VCL TSteamAPI). They appear on the "Steamworks"
      palette page.

   Building a design package from the project group builds the runtime
   packages it needs first. Programs that do not use runtime packages need
   none of them - they compile the units directly.

### In your own project

Your project links the units the runtime packages compiled into Delphi's
`Dcp` folder (see Getting started, step 4), so after building `Steamworks`
and `SteamworksFMX` for a platform nothing else is needed for it. If a build
stops with `F2613 Unit 'Steamworks.FMX' not found`, the packages have not
been built for that platform yet (a new project starts on Win32). To compile
the library from source instead (or to step into it while debugging), add
the repository's `lib`, `lib\plugins` and `fmx` folders to the project's
search path or to **Tools > Options > Language > Delphi > Library** (Library
path or Browsing path) for that platform.

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
`TSteamUtils`, `TSteamUser`, `TSteamFriends`, `TSteamApps`, `TSteamUserStats`,
`TSteamRemoteStorage`, `TSteamScreenshots`, `TSteamTimeline`, `TSteamUGC`, `TSteamInput` - that works with any framework:

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
* Steam images (avatars, achievement icons) are integer handles; in FMX,
  `SteamImageToBitmap(Handle, Bitmap)` (Steamworks.FMX) copies one into a
  `TBitmap`. A handle of -1 means Steam is still loading it - wait for
  `TSteamFriends.OnAvatarImageLoaded` / `TSteamUserStats.OnUserAchievementIconFetched`.
  SteamDemo shows the user's avatar and the app's achievements this way.
* Steam times (achievement unlock times, ...) are Unix seconds in UTC;
  `SteamTimeToLocal` (Steamworks.Types) converts one to local time with the
  offset that applied on that date. Prefer it to `UnixToDateTime(T, False)`,
  which on FPC 3.2 applies today's offset (summer dates read in winter come
  out an hour out).
* When Steam cannot start and no `OnInitFailed` handler is assigned,
  `Active := True` shows the error (an `ESteamworksError` with Steam's own
  message) in the framework's message box and leaves `Active` False - it
  does not raise, so a failed start in `FormCreate` or in the form file never
  ends the program. Assign `OnInitFailed` to handle it yourself, or call
  `Open`, which returns False and shows nothing.
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
  Steam.Update;            // = Steam.RunCallbacks
  ...
  Steam.Shutdown;
end
else
  Writeln(Steam.LastError);
```

For games, `Steam.SetUpdateMode(sumThread, sdOnUpdate)` before `Initialize`
moves Steam's I/O to a worker thread while your handlers still run inside
`Steam.Update`, on your game thread. See
[docs/GameEngineIntegration.md](docs/GameEngineIntegration.md).

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
`CCallResult` templates. CGE's Steam unit uses the same approach, noting
that `SteamAPI_RunCallbacks` crashed on Linux x86_64.

`TSteamworks.UpdateMode` decides who drains the queue:

* `sumTimer` (the components' default): the framework timer calls
  `RunCallbacks` on the UI thread, which drains the queue and delivers each
  payload there.
* `sumManual`: your loop calls `Steam.Update` (= `RunCallbacks`).
* `sumThread`: a worker thread drains the queue every `PumpInterval` ms,
  copying each payload and fetching each call result, and `Delivery` hands
  the copies to the main thread (`sdMainThread`, via `TThread.Queue`), to
  your `Update` call (`sdOnUpdate`) or delivers them on the worker
  (`sdPumpThread`).

Subscriptions are locked, so they are safe from any thread; handlers run
outside the lock. Full details and engine recipes:
[docs/GameEngineIntegration.md](docs/GameEngineIntegration.md).

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
the exception goes to `OnHandlerError` (the components show it with
`Application.ShowException` on the main thread, and log it when it happened
on a worker thread). `Shutdown` from inside a handler is deferred
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

## Known issues (that are not really issues)
Things that look like bugs in the library or the demos but are Steam's, or
Windows', normal behaviour. Each says why and what to do.

> **SteamInputDemo lists no controller, or every action stays 0.**
> Xbox and generic controllers only reach Steam Input when it is enabled for
> the game in the Steam client (Library -> the game's Properties ->
> Controller). The demo ships default layouts for Xbox, PlayStation,
> Switch Pro / Switch 2 Pro / Joy-Con pair, Steam Deck, both Steam
> Controllers and generic pads (written by tools/gen_input_mapping.py); a
> pad without one (e.g. a single Joy-Con) is unbound until a layout is
> chosen in the game's controller layout in the Steam client. The banner at the top says
> whether Steam loaded OUR layout for the pad, and the log says which
> actions are "NOT BOUND". If it says "a DIFFERENT layout", Steam is
> loading a layout the player chose earlier (even a template picked once
> to export it): pick the game's official layout again (File -> View
> Controller Settings in SteamInputDemo), restart Steam if the list is
> stale, then wait a few seconds for Steam to reload it - step by step in
> docs/SteamInputMapping.md, "When Steam keeps loading another layout".

> **On Windows 11 some middle buttons of a pad open the Xbox Game Bar
> instead of reaching the game.** The Xbox (Guide) button and the small
> middle Share / options button trigger Windows' Xbox Game Bar, which makes
> them hard to test; View and Menu (left and right) are not affected.
> Turn the Game Bar off in Windows Settings -> Gaming -> Game Bar if you
> need those buttons - but remember your players may have it on (and may
> want it). The Guide button can never be bound anyway: Steam reserves it.

> **Achievement icon is 0 / an image you uploaded never appears.**
> `GetAchievementIcon` returns 0 both while Steam is still fetching the icon
> (then `OnUserAchievementIconFetched` brings the real handle) and when the
> achievement has no icon at all - the callback then says 0 too, and the
> Steam client shows its own default starburst, which our code cannot get.
> After adding or changing icons on the partner site (App Admin ->
> Stats & Achievements): **publish** the change, then **restart the Steam
> client** - it caches achievement data, including "no icon", until it
> restarts. Without the restart the old answer comes back however often you
> ask.

> **SteamDemoVCL looks like Windows 95 and its text is slightly soft.**
> Deliberately left like this, because every new VCL project made the same
> way will hit it. A program without an application manifest gets no visual
> themes, and one that is not DPI-aware is enlarged as a bitmap by Windows on
> a scaled display. Fix in your project: Project -> Options -> Application ->
> Manifest (All configurations, each Windows platform): tick **Enable
> runtime themes**, and pick a **DPI awareness**. With *Per Monitor v2* the
> text is sharp, but a form built in code with fixed pixel sizes (like the
> demo's) then appears small - scale its sizes (VCL: `ScaleValue`; LCL:
> `Scale96ToForm`). Forms designed in the IDE are scaled for you.

> **Steam -> Exit closes the window twice on Windows, never on Linux/macOS.**
> On Windows Steam sends a close request per top-level window (FormClose
> runs twice - make it tolerate that); on Linux and macOS it sends callback
> 704 (`SteamShutdown_t`) and leaves the process running. With
> `ShutdownOnSteamExit` (default on) the library shuts Steam down cleanly in
> every case; see [When the Steam client exits](#when-the-steam-client-exits).

> **`F2613 Unit 'Steamworks.Types' not found` in a new project (dcc32).**
> A new project starts on **Win32**, but the 64-bit IDE only needs - and so
> you may only have built - the Win64 packages. Your project links the DCUs
> the runtime packages wrote to Delphi's `Dcp` folder for that platform, so
> select Win32 as the target platform of `Steamworks` and `SteamworksFMX`
> (or `SteamworksVCL`) in the Projects window and **Build** them (no install
> needed), once per platform you target. The editor's Structure panel may
> meanwhile show `F2063 Could not compile used unit ...`: that is Error
> Insight saying the same thing.

> **"Optional export SteamAPI_ISteamUtils_IsRunningOnSteamDeck not found".**
> A debug line, not an error: SDK 1.65 removed that function (see SDK 1.65
> notes).

## Building with Free Pascal / Lazarus
`lib/`, `lcl/` and the console demo are written for FPC 3.2 `{$mode delphi}`
(the reference install is Lazarus 4.8 / FPC 3.2.2).

* **SteamDemoLCL:** open `demos/SteamDemoLCL/SteamDemoLCL.lpi` in Lazarus and
  build. It requires the Lazarus package `packages/SteamworksLCL.lpk` (open
  or install it once), which compiles the library, and passes `-dDEBUG`, so it
  sets the AppID itself. The executable goes to
  `demos/SteamDemoLCL/<cpu>-<os>/` (e.g. `x86_64-win64/`); copy the Steam
  library for that platform from `redistributable_bin` next to it
  (`win64/steam_api64.dll` on Windows 64-bit). It has the same form as the
  VCL demo (Output, Personal, Achievements), with the Steam components in
  `src/uMain.lfm`. To open that form in the designer, install
  `packages/SteamworksLCL.lpk` first (docs/Install-Lazarus-FPC.md); before
  that, if Lazarus offers to remove unknown classes, choose Cancel.
* **SteamConsole:**

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
python3 tools/gen_docs.py        # regenerates docs/components/TSteam<Name>.md
python3 tools/gen_input_mapping.py  # SteamInputDemo's manifest + default layouts
```

## Status / next steps
* Core (`steam_api.h`, `steam_api_common.h`, `steam_api_internal.h`,
  `isteamclient.h`) done.
* Generated: all SDK types, and plug-ins for Utils, User, Friends, Apps and
  UserStats, RemoteStorage, Screenshots, Timeline and UGC (tested, Win64),
  Input (with a hand-written by-value shim and SteamInputDemo; not yet
  compiled), with one documentation page each (docs/components/).
* Update modes (timer / worker thread / manual) - tested on Win64 with
  Delphi 13 and FPC 3.2.2.
* Components for FMX, VCL and LCL (Lazarus package) - tested on Win64.
* Next batches: HTTP, Inventory, Matchmaking, Parties, Networking*
  (needs C union support in the generator), HTMLSurface, Video,
  ParentalSettings, RemotePlay, Music.
* Game-server API (`SteamGameServer_*`).
