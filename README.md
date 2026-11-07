# Steamworks for Pascal

A Pascal binding of the Steamworks SDK **1.65**, built as a small **core**
(the Steam client part every other interface depends on) plus **plug-ins**,
one per Steam interface, so a game links only what it uses.

* Frameworks: **FMX**, **VCL** and **Free Pascal / Lazarus (LCL)** - all
  three are done and tested on Win64.
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
  480 "Spacewar" also works). VirtualGamepad has its own AppID, **4108310**;
  VirtualGamepadLCL uses 480. Each program keeps its AppID in one place,
  its `TSteamAPI.AppID` (form file), and shows it from there.

**Documentation:** [docs/](docs/README.md) -
[Install (Delphi)](docs/Install-Delphi.md),
[Install (Lazarus / FPC)](docs/Install-Lazarus-FPC.md),
[Game engine integration](docs/GameEngineIntegration.md) (timer, worker
thread or your own loop; CGE, Gorilla3D, Skia4Delphi, ...),
[Steam Input mapping](docs/SteamInputMapping.md) (action manifests, default
layouts, origins to physical buttons)
and [one page per component / plug-in](docs/components/README.md).
The full API reference (every unit, class and member) is generated with
PasDoc - see [Generating the API reference](#generating-the-api-reference-pasdoc).

## Licence

MIT - see [LICENSE](LICENSE). It covers everything in this repository
except:

* `models/` - the 3D gamepad models are CC0 1.0 (public domain
  dedication), see [models/LICENSE](models/LICENSE).
* `demos/VirtualGamepad/src/Gorilla.Animation.Parallel.pas` - written for
  this project by Gorilla3D's author and included with his permission; it
  is his code and NOT under this project's MIT licence unless he says so.
* The Steamworks SDK is not in this repository: each developer copies
  Valve's redistributables into `redistributable_bin/` under Valve's own
  Steamworks SDK licence. Steam, Xbox and PlayStation are trademarks of
  their owners; this project is not affiliated with Valve, Microsoft or
  Sony.

## Repository layout

```
LICENSE                     MIT (exceptions: README "Licence")
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
    Steamworks.Plugin.Matchmaking.pas    ISteamMatchmaking (lobbies, favourite servers)
    Steamworks.Plugin.Parties.pas        ISteamParties (party beacons)
    Steamworks.Plugin.Music.pas          ISteamMusic (the Steam music player)
    Steamworks.Plugin.HTTP.pas           ISteamHTTP (HTTP requests through Steam)
    Steamworks.Plugin.HTMLSurface.pas    ISteamHTMLSurface (off-screen web browser)
    Steamworks.Plugin.Inventory.pas      ISteamInventory (Steam Inventory items)
    Steamworks.Plugin.Video.pas          ISteamVideo (broadcasting, video apps)
    Steamworks.Plugin.ParentalSettings.pas  ISteamParentalSettings (Family View)
    Steamworks.Plugin.RemotePlay.pas     ISteamRemotePlay (Remote Play / Together)
    Steamworks.Plugin.Networking.pas     ISteamNetworking (old P2P packets, deprecated)
    Steamworks.Plugin.NetworkingSockets.pas  ISteamNetworkingSockets (connections)
    Steamworks.Plugin.NetworkingMessages.pas ISteamNetworkingMessages (P2P messages)
    Steamworks.Plugin.NetworkingUtils.pas    ISteamNetworkingUtils (relay network, ping)
    Steamworks.Plugin.MatchmakingServers.pas ISteamMatchmakingServers (server browser)
    Steamworks.Plugin.GameServer.pas         ISteamGameServer (listen / dedicated server)
    Steamworks.Plugin.GameServerStats.pas    ISteamGameServerStats (players' stats)
                            (the server copies TSteamGameServerUtils,
                            ...Networking, ...NetworkingSockets,
                            ...NetworkingMessages, ...HTTP, ...UGC,
                            ...Inventory live in the client units)
fmx/                        FireMonkey only
  Steamworks.FMX.pas        TSteamAPI for FMX (TTimer pump on the UI thread),
                            SteamImageToBitmap, SteamFormToRGB (screenshots)
  Steamworks.FMX.Reg.pas    design-time registration of the FMX TSteamAPI
  Steamworks.FMX.Reg.dcr    GENERATED (gen_icon_res.py): its palette icon
vcl/                        VCL only (Delphi, Windows)
  Steamworks.VCL.pas        TSteamAPI for VCL (VCL TTimer), SteamImageToBitmap,
                            SteamFormToRGB (screenshots)
  Steamworks.VCL.Reg.pas    design-time registration of the VCL TSteamAPI
  Steamworks.VCL.Reg.dcr    GENERATED (gen_icon_res.py): its palette icon
lcl/                        LCL only (Lazarus / Free Pascal)
  Steamworks.LCL.pas        TSteamAPI for LCL (LCL TTimer), SteamImageToBitmap,
                            SteamFormToRGB (screenshots)
  Steamworks.LCL.Reg.pas    GENERATED (gen_steam_api.py, needs no SDK): registers the LCL
                            TSteamAPI and the plug-in components for Lazarus
  Steamworks.LCL.Reg.res    GENERATED (gen_icon_res.py): their palette icons (PNG)
design/
  Steamworks.Reg.pas        GENERATED: registers the plug-in components (all frameworks)
  Steamworks.Reg.dcr        GENERATED (gen_icon_res.py): their palette icons (bitmaps)
  icons/                    the palette icons' source: <Class>.ico (16-256 px) for all 34
                            components, ServerBadge.ico, svg/ - see docs/ComponentIcons.md
packages/                   Steamworks (runtime: lib + plug-ins + components, no framework),
                            dclSteamworks (design: plug-in components),
                            SteamworksFMX (runtime: FMX TSteamAPI), dclSteamworksFMX (design),
                            SteamworksVCL (runtime: VCL TSteamAPI), dclSteamworksVCL (design);
                            SteamworksLCL.lpk (Lazarus package: lib + plug-ins + lcl,
                            run and design time)
redistributable_bin/        copy of sdk/redistributable_bin from the SDK
                            (git-ignored except its README.md)
demos/
  SteamDemo/                FMX demo: SteamDemo.dproj + .dpr, form in src/ (uMain.pas / .fmx)
  SteamDemoPad/             Big Picture / Steam Deck variant of SteamDemo (FMX): pad-driven
                            through its own Steam Input manifest (steamdemopad_controllers.vdf,
                            pad_controller_*.vdf - generated), screen drawn by the program,
                            Steam starts by itself, log to a LogReceiver
  SteamDemoVCL/             VCL demo (Delphi project), form in src/ (uMain.pas / .dfm)
  SteamDemoLCL/             LCL demo (Lazarus .lpi / .lpr), form in src/ (uMain.pas / .lfm)
                            - all three: TSteamAPI, TSteamFriends, TSteamUserStats dropped on the form,
                              File menu (Auto Start Steam, Take Screenshot, Copy Log,
                              Send log to receiver, Exit) and
                              the Components tab (base test of 30 more plug-in components)
  Shared/                   used by all three SteamDemo programs (FMX, VCL, LCL):
    SteamComponentTest.pas  the component test (Delphi + FPC, no UI; creates its own
                            30 components: 21 client + 9 game-server)
    SteamPairTest.pas       the two-user pair test (Two users tab)
    DemoRemoteLog.pas       File > Send log to receiver (RemoteLog.Sender under Delphi,
                            RemoteLog.SenderFPC under FPC; optional, see RemoteLogging/)
  SteamConsole/             console program (no framework): smoke test, the shared
                            component / pair tests (--test / --pair) and a dedicated
                            game server (--server); SteamConsole.dproj for Delphi,
                            SteamConsoleFPC.lpi / .lpr for plain Free Pascal (same src/)
  SteamInputDemo/           Steam Input test (FMX): action manifest in src/, the
                            connected controller identified at the top, live
                            digital / analog / motion values, bindings; opens
                            Steam by itself; File menu: View Controller
                            Settings, Rumble, Send log to receiver (optional,
                            see RemoteLogging/; also DPadUp + Y + LeftBumper
                            together on the pad, for SteamOS), Exit
  VirtualGamepad/           3D gamepad visualiser (FMX + Gorilla3D 1.5.4, in
                            progress): the model of the connected pad (Xbox,
                            PS5 or Steam Controller from models/, by Steam's
                            type), turned by the pad's motion sensors once
                            switched on (off at start), mouse orbits the
                            camera; hold Start for the overlay menu (Menu
                            action set: D-pad, A, B) - with several pads a
                            controller row (D-pad left / right, A shows
                            that pad), Return to App, View (D-pad
                            left / right: Front / Back / Top, A shows
                            it), Enable / Disable Highlights, Enable /
                            Disable Motion (greyed out without
                            motion sensors), Controller Settings (Steam's
                            binding panel - Big Picture has no window
                            menu), Steam Hardware (greyed out unless
                            Steam reports Steam hardware: a panel over
                            the menu with what Steam and the program
                            know about it, OK / A / B closes it), Start /
                            Stop Remote
                            Logging, Exit (each choice closes it); a
                            one-line banner, the rest is the 3D view (no
                            log panel: log file + remote logging); same
                            manifest and layouts
                            as SteamInputDemo. Every button, stick and trigger
                            moves on the model, any number at once, through
                            TGorillaParallelAnimator (unit
                            src/Gorilla.Animation.Parallel.pas, written for this
                            project by Gorilla3D's author and included with his
                            permission until a Gorilla3D release carries it).
                            The camera is Sprite3D's orbit camera
                            (src/Sprite3DCamera.pas, an unchanged copy from
                            github.com/peardox/Sprite3D): it frames the pad
                            exactly; drag orbits, wheel zooms, right-click
                            resets.
                            Data next to the executable (Windows, Linux) or in
                            the bundle's Contents/Resources (macOS - codesign
                            rejects data files in Contents/MacOS); the log
                            says "Deployment OK" or what is missing.
                            Gorilla3D on Linux: X11 only, OpenGL 4.3+, needs
                            libsk4d.so; on macOS: Intel x64 (Apple silicon not
                            native yet, per Gorilla3D's docs)
  VirtualGamepadLCL/        the same visualiser for Lazarus / Free Pascal with
                            Castle Game Engine (LCL form + TCastleControl;
                            .lpi / .lpr, sources in src/), AppID 480 (Spacewar
                            - not for Steam): same manifest, layouts and
                            models, same overlay menu (controller row, Return
                            to App, Enable / Disable Motion, Controller
                            Settings, Start / Stop Remote Logging, Exit;
                            remote logging also from
                            File > Send log to receiver, through
                            RemoteLogging/src/RemoteLog.SenderFPC.pas - the
                            Free Pascal sender, FPC's Sockets unit).
                            src/PadAnimator.pas plays any number of the
                            model's clips at once on its joints (needs a
                            Castle Game Engine from November 2025 or later -
                            joints moved from code, GPU skinning).
  VirtualGamepadVCL/        the same visualiser for Delphi's VCL (Windows) with
                            Castle Game Engine (Vcl.CastleControl), AppID
                            4108310 like VirtualGamepad: a port of
                            VirtualGamepadLCL - same manifest, layouts, models,
                            overlay menu (incl. Controller Settings) and the
                            SAME src/PadAnimator.pas (it compiles with FPC and
                            Delphi; Delphi takes fpjson from Castle's
                            src/compatibility/delphi-only/fcl-json). Remote
                            logging through RemoteLog.Sender; the post-build
                            event copies the DLL, .vdf files and models; logs
                            Castle's frame rate every 5 s
  (every demo)              README.md next to the .dproj / .lpi: deploying its
                            Windows Release build (Steam depot layout); the
                            .dproj opens it as the project's welcome page
RemoteLogging/              OPTIONAL, nothing to do with Steam: LogReceiver app +
                            RemoteLog.Sender unit to stream a program's log to a
                            desk machine (e.g. from a Steam Deck); see its README
models/                     CC0 3D gamepad models (glTF .glb, rigged, one clip per
                            input): XBoxOne_Animated, PS5_Animated,
                            SteamController_Animated; LICENSE (CC0, credits)
docs/                       user documentation (Markdown) - the index is docs/README.md:
  Install-Delphi.md, Install-Lazarus-FPC.md, GameEngineIntegration.md,
  SteamInputMapping.md, Proton.md, TestSetup.md (+ test-setup/), Launcher.md,
  ComponentIcons.md, the fmx-*-bug*.md / gorilla-opengl-bug.md reports
  components/               TSteamAPI.md + README.md (hand-written),
                            TSteam<Name>.md: GENERATED by tools/gen_docs.py
tools/
  pasdoc_check.py           PasDoc coverage, ASCII and comment-nesting check
  pasdoc.bat                PasDoc API reference: docs/html/delphi (FMX + VCL), docs/html/fpc (LCL),
                            docs/chm/delphi, docs/chm/fpc (HTML Help, compiled with hhc.exe)
  pasdoc.sh                 Linux / macOS: the FPC part only - docs/html/fpc (sh tools/pasdoc.sh)
                            Both need pasdoc: https://github.com/pasdoc/pasdoc/releases/
  gen_docs.py               generates docs/components/TSteam<Name>.md from the plug-in units
  gen_input_mapping.py      writes the Steam Input manifest and default layouts to all four
                            input demos (SteamInputDemo, VirtualGamepad, VirtualGamepadLCL,
                            VirtualGamepadVCL)
  doc_extras/               hand-written overview text merged into those pages
  sdk_extras/               hand-written variant records for the SDK's C unions, copied
                            into Steamworks.SDKTypes by gen_steam_api.py
  check_redist.py           validates all seven redistributables (type, CPU, SDK level)
  project_check.py          .dproj BOM / XML / unit-list agreement check
  gen_projects.py           creates missing .dproj / .dpk / .groupproj (IDE-saved files win)
  gen_steam_api.py          generates SDKTypes and the plug-ins from the SDK (see below)
  gen_icon_res.py           packages design/icons into the four palette-icon resource files
                            (.dcr for Delphi, .res for Lazarus); standard library only
  gen_icons.py              redraws design/icons and the programs' task bar icons
                            (<project>.ico / .icns beside each project; needs Pillow and
                            rsvg-convert)
  gen_pad_parts.py          writes PadParts.pas (where each control's part sits on the
                            models: the glow) into the three VirtualGamepad demos; run it
                            after a model in models/ is added or changed
  verify_generated.py       checks generated layouts and signatures against the SDK headers
  LayoutProbe/              GENERATED console program (verify_generated.py --probe): prints
                            the record layout a compiler really produced (--compare checks it)
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
   `steam_appid.txt` is needed. On Windows the post-build event (`deploy.bat` in the project folder) copies the DLL
   next to the executable and fails the build if it is missing; on macOS / Linux it is deployed with the app.
   SteamDemo's buttons are enabled only when they make sense (**Start
   Steam** while Steam is stopped; **Show info**, **Stop Steam** and **Test
   components** while it runs). Its **File** menu has **Auto Start Steam**
   (on / off, remembered per user in the OS's settings folder:
   `%APPDATA%\G3DGames\SteamDemo\SteamDemo.ini` on Windows,
   `~/Library/Application Support/G3DGames/SteamDemo` on macOS,
   `~/.config/G3DGames/SteamDemo` on Linux), **Take Screenshot** (a picture
   of the window to your Steam screenshots; needs no Steam overlay),
   **Copy Log**, **Send log to receiver** and **Exit**. **Send log to
   receiver** is optional and has nothing to do with Steam: it streams the
   log to a LogReceiver on another machine on the network
   ([RemoteLogging/README.md](RemoteLogging/README.md) explains LogReceiver);
   the item reads *Connecting...* (greyed) until the receiver accepts, then
   *Stop sending log*, and goes back to *Send* if the connection fails.
   After **Start Steam**, **Test components** runs the base test of the
   plug-in components the demos' forms do not use (TSteamUtils,
   TSteamUser, TSteamApps, TSteamRemoteStorage, TSteamScreenshots,
   TSteamTimeline, TSteamUGC, TSteamMatchmaking, TSteamParties,
   TSteamMusic, TSteamHTTP, TSteamHTMLSurface, TSteamInventory,
   TSteamVideo, TSteamParentalSettings, TSteamRemotePlay, TSteamNetworking,
   TSteamNetworkingSockets, TSteamNetworkingMessages, TSteamNetworkingUtils,
   TSteamMatchmakingServers, and the game server's TSteamGameServer,
   TSteamGameServerStats, TSteamGameServerUtils, ...Networking,
   ...NetworkingSockets, ...NetworkingMessages, ...HTTP, ...UGC,
   ...Inventory - 30). All three demos share it
   (demos/Shared/SteamComponentTest.pas creates the components in code);
   the test checks it is attached, makes its synchronous calls and waits up
   to 20 s for one or more callbacks / call results through its events. The
   **Components** tab shows PASS / FAIL per component, the log has the
   details. A component passes when its answers arrive, whatever result
   code Steam puts in them (Steam Cloud or Workshop being off for the app
   is a Steam setting). Side effects: a small Steam Cloud file is written
   and deleted, a timeline event / game phase is recorded, and a socket
   pair inside the program sends itself one message. The server-browser
   test reads a LAN list for this app and the Internet list of AppID 730
   (Counter-Strike 2: many public servers), releases it after 5 servers
   and asks the first one with a direct address for its ping, players and
   rules - read-only queries any server browser makes. Servers behind
   Steam's relay network report a fake IP (169.254.x.x) that these
   queries cannot reach, so they are skipped. The test
   writes no screenshot (it only switches the screenshot hook on and off);
   use File > Take Screenshot for that. The game-server rows start a
   LISTEN server in the demo (ports 27115 / 27116), log it on anonymously,
   query it through the server browser at 127.0.0.1 (its rules must come
   back - the RulesResponded path no public server answered), let it
   validate the user's own auth ticket, and stop it again; the server is
   listed in Steam's server browser while the test runs.
   Two tests grow by themselves once the partner site is set up
   ([docs/TestSetup.md](docs/TestSetup.md)): when GetAllItems answers OK
   (Inventory Service on) the Inventory test also runs GenerateItems (one
   Test Gem), ConsumeItem (that Gem), AddPromoItem (the Test Token, granted
   once per account) and TriggerItemDrop; when GetWorkshopEULAStatus
   answers OK (Workshop set up) the UGC test creates a private Workshop
   item, uploads a title and a one-file folder and DELETES the item again.
   Until then their rows say "skipped".
   **Pair test (2 users)** (Two users tab) needs a second Steam account on
   a second PC running the same demo (any of the three): press it on both
   machines. The copies find each other through a lobby and test the
   lobby itself (data, member data, chat), persona and rich presence,
   auth session tickets, NetworkingMessages, NetworkingSockets P2P and
   the old P2P packets, and a game server (the host starts a listen
   server, the guest's ticket is validated by it); each machine shows its
   own verdicts, and both
   close once each has told the other (DONE) that it is finished. Set-up:
   [docs/TestSetup.md](docs/TestSetup.md).
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
      TSteamInput, TSteamMatchmaking, TSteamParties, TSteamMusic, TSteamHTTP,
      TSteamHTMLSurface, TSteamInventory, TSteamVideo,
      TSteamParentalSettings, TSteamRemotePlay, TSteamNetworking,
      TSteamNetworkingSockets, TSteamNetworkingMessages,
      TSteamNetworkingUtils, TSteamMatchmakingServers, TSteamGameServer,
      TSteamGameServerStats and the seven server copies) and
      `dclSteamworksFMX` (the FMX TSteamAPI) and / or `dclSteamworksVCL`
      (the VCL TSteamAPI). They appear on the "Steamworks"
      palette page, each with its own icon (docs/ComponentIcons.md).

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
events (FMX, VCL and LCL - all three tested on Win64), all built on `TCustomSteamAPI` in
`Steamworks.Components`, which holds the whole lifecycle. Each generated
plug-in unit also declares a component named after the interface -
`TSteamUtils`, `TSteamUser`, `TSteamFriends`, `TSteamApps`, `TSteamUserStats`,
`TSteamRemoteStorage`, `TSteamScreenshots`, `TSteamTimeline`, `TSteamUGC`, `TSteamInput`,
`TSteamMatchmaking`, `TSteamParties`, `TSteamMusic`, `TSteamHTTP`, `TSteamHTMLSurface`,
`TSteamInventory`, `TSteamVideo`, `TSteamParentalSettings`, `TSteamRemotePlay`,
`TSteamNetworking`, `TSteamNetworkingSockets`, `TSteamNetworkingMessages`,
`TSteamNetworkingUtils`, `TSteamMatchmakingServers`, `TSteamGameServer`,
`TSteamGameServerStats` (+ the game server's copies `TSteamGameServerUtils`,
`...Networking`, `...NetworkingSockets`, `...NetworkingMessages`, `...HTTP`,
`...UGC`, `...Inventory`) - that works with any framework:

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
Before loading, the core logs the build target, the system it really runs
on with its version and build number, and how it runs
(`TSteamLib.PlatformDescription`, e.g. `macOS x64 build on macOS 15.1 build
24B83, running under Rosetta 2`). `TSteamLib.RunningOS` names Wine and Proton
when a Windows build runs under them, with the host system behind them (so a
SteamOS player's Proton run and a native Linux run can be told apart), and
the host plus Steam's runtime container for a Linux build started by Steam.
Every demo appends the description to its main window's caption;
LogReceiver, which uses no Steam unit, appends the RTL's `TOSVersion.ToString`.

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

The generator also packages the palette icons (`tools/gen_icon_res.py`) and
reports, as a NOTE, any component that has no icon in `design/icons` yet - a
new plug-in needs one drawn (docs/ComponentIcons.md, "Rebuilding them").

`verify_generated.py` compiles the SDK headers with clang (any OS; no
platform SDKs needed) for Win64, Win32, Linux x86_64, macOS ARM64 and the
FPC-only targets Linux32 (i686) and LinuxARM64 (aarch64), and
compares every generated record's size, alignment and field offsets with the
C layout, and every flat signature with `steam_api_flat.h`. The generator
prints what it could not generate and why (structs only forward-declared
in the public headers, functions taking a struct by value). Structs with a
C union (`steam_api.json` lists only one union member) are hand-written
Pascal variant records in `tools/sdk_extras/<Struct>.pas.txt`; the
generator copies them into `Steamworks.SDKTypes` and the verifier checks
every field offset by name against the C headers.

Those checks model Delphi's record rules. FPC aligns a record-typed field
by the nested record's size rather than its alignment (a packed 8-byte
`TSteamID` lands on an 8-byte boundary), so under FPC the generated
records are `packed` with explicit `_fpcpad` byte fields where C has
padding, per target class (Win64, Win32, 64-bit Unix, Linux32). To measure
what a compiler really produces, build and run the generated probe, then
compare its output with the C layout of the same target:

```
python3 tools/verify_generated.py <sdk>/public/steam --probe tools/LayoutProbe/LayoutProbe.dpr
fpc -Mdelphi -Fulib -Filib -FUtools/LayoutProbe -FEtools/LayoutProbe tools/LayoutProbe/LayoutProbe.dpr
tools/LayoutProbe/LayoutProbe > probe.txt
python3 tools/verify_generated.py <sdk>/public/steam --compare probe.txt x86_64-pc-windows-msvc
```

New interfaces are added to the
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

> **TriggerScreenshot (and F12) does nothing.**
> Both are carried out by the Steam overlay. In a program started from the
> IDE (or with the in-game overlay off) the overlay is usually not in the
> process - `TSteamUtils.Plugin.IsOverlayEnabled` returns `False` - and then
> no screenshot is taken and no `OnScreenshotRequested` arrives, without
> any error (observed 2026-11-02, Win64, started from the IDE).
> `WriteScreenshot` needs no overlay: capture the frame yourself and write
> it - with `SteamFormToRGB` (Steamworks.FMX / .VCL / .LCL), as the
> SteamDemos' File > Take Screenshot does.

> **On macOS, HookScreenshots does not take.**
> `IsScreenshotsHooked` stays `False` after `HookScreenshots(True)` on the
> macOS Steam client - seen 2026-11-02 on macOS ARM64 with both FPC (LCL)
> and Delphi (FMX), overlay off; on Windows the hook takes with the
> overlay off too. The component test reports it as information on macOS.
> `WriteScreenshot` is not affected.

> **macOS: "Send log to receiver" finds no LogReceiver from a Lazarus
> build.** The Delphi .app on the same Mac finds it at once, and the
> receiver's announcements do reach the Mac (`nc -u -l 47811` shows
> them), so it is the FPC listener (RemoteLog.SenderFPC), cause unknown -
> PARKED (2026-11-02, owner: remote logging is for the Steam Deck and the
> Windows tablet, where it works). The FPC build logs what its socket saw
> after each empty search. Started from Terminal as a bare executable, an
> LCL program gets no menu bar on macOS: run it from Lazarus or as an
> .app (`open SteamDemoLCL.app`).

> **An FMX program's Windows build is all white under Proton / Wine.**
> Only the native menu bar shows; the program runs normally behind it.
> Wine's Direct2D (d2d1.dll) has PushLayer / PopLayer /
> PushAxisAlignedClip as stubs (Proton 11.0, ROG Ally, 2026-11-03 -
> `PROTON_LOG=1` shows them thousands of times), and FMX clips every
> control with them. SteamDemo, SteamInputDemo, VirtualGamepad and
> LogReceiver use the unit `FmxWineCanvas`: under Wine it sets
> `GlobalUseDirect2D := False` before the first form, so FMX draws with
> GDI+; the demos log the decision. CONFIRMED 2026-11-03 on the ROG Ally
> (SteamOS, Proton 11.0, Desktop Mode): SteamInputDemo and VirtualGamepad
> (Gorilla3D's 3D view included) draw normally; Game Mode not yet checked. Copy that unit into your own FMX
> programs (first in the .dpr's uses, after FMX.Forms). The environment
> variable `TSAPI_FMX_CANVAS` = `gdi` (default) / `gpu` / `d2d` picks the
> canvas for testing (Steam: Launch Options `TSAPI_FMX_CANVAS=gpu
> %command%`). Everything about Proton: [docs/Proton.md](docs/Proton.md).

> **FMX menus on Linux show only first letters ("F" for "File").**
> That is FMX's native GTK menu bar on Linux, not this library. SteamDemo,
> SteamInputDemo, VirtualGamepad and LogReceiver replace their TMainMenu
> with an FMX TMenuBar at start-up
> (unit `FmxLinuxMenu`, `ReplaceMainMenu`, first thing in `OnCreate`); copy
> that unit into your own FMX programs. Do not simply move the menu items to a
> TMenuBar and free the TMainMenu - that crashes in libgobject or floods the
> terminal with GTK-CRITICAL warnings (the unit explains why).

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

> **A new AppID shows an old or wrong controller layout.**
> Steam keeps the controller layout per AppID, per account, and it
> remembers it after the program that used the AppID is gone. If an AppID
> was used before by another program or an older manifest (seen
> 2026-11-03, when VirtualGamepad moved to its own AppID 4108310), Steam
> loads that saved layout instead of the one from your manifest. The
> input demos' banner / log says "a DIFFERENT layout" instead of
> "mapping by 0" at the current revision. Fix: Steam in **developer mode**
> (Settings -> Interface -> Enable Steam developer mode), then the game's
> controller settings -> **Reset Controller Layout**, which drops the
> saved layout and reloads the default from the manifest. If the old one
> still comes back, restart the Steam client (it caches layouts much as it
> caches achievement icons) and reset again.

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
  VCL demo (buttons enabled by state, File menu, tabs Output, Personal,
  Achievements, Components), with the Steam root and the Friends / UserStats
  components in `src/uMain.lfm`; **Test components** runs
  `demos/Shared/SteamComponentTest.pas` (30 components, created by that
  unit - the same tests as the FMX SteamDemo). To open that form in the designer, install
  `packages/SteamworksLCL.lpk` first (docs/Install-Lazarus-FPC.md); before
  that, if Lazarus offers to remove unknown classes, choose Cancel.
* **VirtualGamepadLCL** (Castle Game Engine): register Castle Game Engine's
  Lazarus packages (`castle_engine_base`, `castle_engine_lcl`; Castle's
  "Lazarus" page) and `packages/SteamworksLCL.lpk`, open
  `demos/VirtualGamepadLCL/VirtualGamepadLCL.lpi` and build. The executable
  goes to `demos/VirtualGamepadLCL/<cpu>-<os>/`; copy the Steam library
  there as for SteamDemoLCL. Run from there it finds the manifest and
  layouts in `../src/` and the models in the repository's `models/`; a
  deployed copy needs them next to the executable. AppID 480 (Valve's
  Spacewar), never relaunched through Steam.
* **VirtualGamepadVCL** (Castle Game Engine, Delphi): Castle Game Engine
  for Delphi must be on the IDE's library path, including its
  `src\compatibility\delphi-only\fcl-json` folder (`PadAnimator` uses
  `fpjson` from there; the demo's own README.md says the same). Then
  build `demos/VirtualGamepadVCL/VirtualGamepadVCL.dproj` from the
  project group (Win64 or Win32; the build copies the DLL,
  the .vdf files and the models next to the executable). AppID 4108310,
  like VirtualGamepad.
* **SteamConsoleFPC** (the Free Pascal twin of SteamConsole, plain FPC, no
  LCL or package): open `demos/SteamConsole/SteamConsoleFPC.lpi` in Lazarus
  and build, or from a terminal

```
cd demos/SteamConsole
lazbuild SteamConsoleFPC.lpi
```

  or without Lazarus

```
cd demos/SteamConsole
fpc -Mdelphi -Fu../../lib -Fu../../lib/plugins -Fi../../lib -Fusrc -Fu../Shared SteamConsoleFPC.lpr
```

  then copy the Steam library next to the executable
  (`<cpu>-<os>/SteamConsoleFPC` from lazbuild, `SteamConsoleFPC` beside the
  .lpr from fpc). `SteamConsoleFPC --help` lists the switches.

FPC / Lazarus build output (`*.o`, `*.ppu`, `lib/<cpu>-<os>/`, `backup/`,
`*.lps`, extensionless demo executables, ...) is ignored by `.gitignore`.

## Generating the API reference (PasDoc)

Every unit, type and member of the library has a PasDoc comment, so a
complete API reference can be generated from the sources. It is not in the
repository: generate it locally (the output folders are git-ignored).

**1. Install PasDoc** from <https://github.com/pasdoc/pasdoc/releases/>:
download the archive for your OS, unpack it and put its `bin` folder on
the `PATH` (or set the `PASDOC` environment variable to the full path of
the pasdoc executable). Tested with PasDoc 1.0.5. Both scripts check for
PasDoc first and point to that page if it is missing.

**2. Run the script for your OS** (from any folder - it switches to the
repository root itself):

| OS | Command | Generates |
|---|---|---|
| Windows | `tools\pasdoc.bat` | `docs\html\delphi`, `docs\html\fpc`, `docs\chm\delphi`, `docs\chm\fpc` |
| Linux / macOS | `sh tools/pasdoc.sh` | `docs/html/fpc` |

Open `index.html` in an HTML folder, or the `TSteamAPI.chm` file in a
`chm` folder (Windows Help viewer). Each script deletes its output folders
first, so nothing is left over from an earlier run, and ends with a
summary line (exit code 0 = success; `pasdoc.bat` returns the number of
failed steps).

**Two views of the same library:**

* **Delphi** (`delphi` folders): `Steamworks.FMX` and `Steamworks.VCL` plus
  `lib/` and `lib/plugins/`, as Delphi compiles them - including the
  overloads that take anonymous methods (`reference to`).
* **Free Pascal / Lazarus** (`fpc` folders): `Steamworks.LCL` plus `lib/`
  and `lib/plugins/`, as FPC 3.2.2 compiles them - without those overloads.

Both describe the Win64 build (PasDoc defines no platform symbols itself,
so the scripts choose one); the platform-specific parts are internal, so
the public API is the same on every platform. The `.Reg` units
(design-time registration) are left out.

**The .chm files (Windows only)** need Microsoft HTML Help Workshop's
compiler, `hhc.exe`. `pasdoc.bat` looks for it in the Workshop's default
folder (`%ProgramFiles(x86)%\HTML Help Workshop`); set `HHC` to its full path
if it is elsewhere. Without it the HTML Help projects (`.hhp`) are still
written, but not compiled, and the script says so.

To write PasDoc comments for your own changes, see the rules in
`CLAUDE.md` ("Source rules"); `python3 tools/pasdoc_check.py` reports
any undocumented item. The Markdown pages in `docs/components/` are a
separate, shorter guide (written by hand or by `tools/gen_docs.py`).

## Checks before delivery
```
python3 tools/pasdoc_check.py
python3 tools/project_check.py
python3 tools/gen_docs.py        # regenerates docs/components/TSteam<Name>.md
python3 tools/gen_icon_res.py    # palette icons: design/icons -> .dcr / .res (unchanged = fine)
python3 tools/gen_input_mapping.py  # Steam Input manifest + layouts (all four input demos:
                                    # SteamInputDemo, VirtualGamepad, VirtualGamepadLCL, VirtualGamepadVCL)
```

## Status / next steps
* Core (`steam_api.h`, `steam_api_common.h`, `steam_api_internal.h`,
  `isteamclient.h`) done.
* Generated: all SDK types, and plug-ins for Utils, User, Friends, Apps and
  UserStats, RemoteStorage, Screenshots, Timeline and UGC (tested, Win64),
  Input (with a hand-written by-value shim; tested on Win64 (FMX, VCL,
  LCL) with the input demos and every pad the owner has, and on Linux64
  with SteamInputDemo), with one documentation page each
  (docs/components/).
* Update modes (timer / worker thread / manual) - tested on Win64 with
  Delphi 13 and FPC 3.2.2.
* Components for FMX, VCL and LCL (Lazarus package) - tested on Win64.
* Batch 2a (2026-11-02, tested on Win64): Matchmaking, Parties, Music,
  HTTP, HTMLSurface, Inventory, Video, ParentalSettings, RemotePlay - one
  page each and a SteamDemo test. Not bound: `ISteamParties.
  GetBeaconLocationData` (struct by value - needs a per-platform shim).
* Batch 2b (2026-11-02, tested on Win64 with Delphi 13 (FMX, VCL) and
  FPC 3.2.2 (LCL)): Networking, NetworkingSockets,
  NetworkingMessages, NetworkingUtils, with C union support (hand-written
  variant records: SteamNetworkingIdentity, SteamNetworkingIPAddr,
  SteamNetworkingConfigValue_t, SteamInputActionEvent_t,
  RemotePlayInput_t) - one page each and a SteamDemo test. Not bound:
  `ISteamNetworking.CreateListenSocket` / `CreateConnectionSocket`
  (deprecated `SteamIPAddress_t` by value).
* Batch 2c (2026-11-02, tested on Win64 (FMX, VCL, LCL) and Win32 (FMX,
  VCL - the thunks)): MatchmakingServers, the server
  browser. Its answers come through C++ response objects, which the
  plug-in builds itself (Pascal vtables; on Win32 a thunk turns MSVC's
  thiscall into stdcall) and turns into ordinary events delivered like
  callbacks (`TSteamCallbackDispatcher.Post`). Not wrapped:
  `ServerFriends` (undocumented; the raw method stays).
* Game-server batch (2026-11-02, tested on Win64 (FMX, VCL, LCL): the
  component test's 30 rows and the two-user pair test): ISteamGameServer,
  ISteamGameServerStats and the server copies of Utils, Networking,
  NetworkingSockets, NetworkingMessages, HTTP, UGC and Inventory. The
  core runs a game server next to the client (a listen server,
  `TSteamAPI.StartGameServer`) or alone (a dedicated server, `Roles =
  [srGameServer]`), with its own pipe and callback dispatcher. The demos
  test the listen server (component test + pair test); the dedicated
  server is SteamConsole's `--server` (2026-11-04, tested on Win64 with
  the Steam client closed: logged on, VAC secure, listed in the client's
  server browser, clean stop - see
  [demos/SteamConsole/README.md](demos/SteamConsole/README.md)).
  ISteamController is not bound: Valve deprecated it in favour of
  ISteamInput.

### To do at the end of the project
* **Front-end launcher** for the demos under one AppID (SteamDemo,
  SteamInputDemo, VirtualGamepad and Exit): plan and open decisions in
  [docs/Launcher.md](docs/Launcher.md). Not started on purpose - it comes
  last, once the demos it launches are finished.
