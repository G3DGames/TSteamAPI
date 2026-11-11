# User Manual (Provisional)

> **Provisional.** This manual describes TSteamAPI - the Pascal binding of
> the Steamworks SDK **1.65** - as it stands in this repository. Names,
> defaults and behaviour are taken from the sources (`lib/`, `fmx/`,
> `vcl/`, `lcl/`) and from the per-component reference pages in
> [components/](components/README.md). Where this manual and the source
> disagree, the source wins; please report the difference.
>
> Every example uses **AppID 480 ("Spacewar")**, Valve's public test
> application, which every Steam account can use. Replace 480 with your own
> AppID before you ship anything (see [Appendix B](#appendix-b-spacewar-appid-480-as-a-test-bed)).

## Contents

**Part I - Foundations**

1. [How to read this manual](#1-how-to-read-this-manual)
2. [Before you start](#2-before-you-start)
3. [Installing the library](#3-installing-the-library)
4. [Core concepts](#4-core-concepts)
5. [TSteamAPI - the root component](#5-tsteamapi---the-root-component)
6. [TSteamUtils - client utilities](#6-tsteamutils---client-utilities)
7. [TSteamUser - the logged-on user](#7-tsteamuser---the-logged-on-user)

**Part II - The most-used Steam features**

8. [TSteamUserStats - achievements, stats and leaderboards](#8-tsteamuserstats---achievements-stats-and-leaderboards)
9. [TSteamRemoteStorage - Steam Cloud saves](#9-tsteamremotestorage---steam-cloud-saves)
10. [TSteamFriends - friends, avatars, overlay, rich presence](#10-tsteamfriends---friends-avatars-overlay-rich-presence)
11. [TSteamApps - ownership, DLC, language, betas](#11-tsteamapps---ownership-dlc-language-betas)
12. [TSteamMatchmaking - lobbies](#12-tsteammatchmaking---lobbies)
13. [Networking](#13-networking)
14. [TSteamUGC - Steam Workshop](#14-tsteamugc---steam-workshop)
15. [TSteamInput - controllers](#15-tsteaminput---controllers)
16. [TSteamScreenshots - the screenshot library](#16-tsteamscreenshots---the-screenshot-library)
17. [TSteamTimeline - game recording markers](#17-tsteamtimeline---game-recording-markers)

**Part III - Further features**

18. [TSteamInventory - Steam Inventory items](#18-tsteaminventory---steam-inventory-items)
19. [TSteamRemotePlay - Remote Play and Remote Play Together](#19-tsteamremoteplay---remote-play-and-remote-play-together)
20. [TSteamParties - party beacons](#20-tsteamparties---party-beacons)
21. [TSteamHTTP - HTTP through the Steam client](#21-tsteamhttp---http-through-the-steam-client)
22. [TSteamHTMLSurface - an off-screen browser](#22-tsteamhtmlsurface---an-off-screen-browser)
23. [TSteamMusic - the Steam music player](#23-tsteammusic---the-steam-music-player)
24. [TSteamVideo - broadcasting state](#24-tsteamvideo---broadcasting-state)
25. [TSteamParentalSettings - Family View](#25-tsteamparentalsettings---family-view)
26. [TSteamNetworking - the old P2P API (deprecated)](#26-tsteamnetworking---the-old-p2p-api-deprecated)

**Part IV - Game servers**

27. [Running a game server with TSteamAPI](#27-running-a-game-server-with-tsteamapi)
28. [TSteamGameServer](#28-tsteamgameserver)
29. [TSteamGameServerStats](#29-tsteamgameserverstats)
30. [The game server's copies of client interfaces](#30-the-game-servers-copies-of-client-interfaces)
31. [TSteamMatchmakingServers - the server browser](#31-tsteammatchmakingservers---the-server-browser)

**Part V - Reference**

32. [Update modes and threads](#32-update-modes-and-threads)
33. [Errors, logging and diagnostics](#33-errors-logging-and-diagnostics)
34. [Shipping checklist](#34-shipping-checklist)
35. [Troubleshooting](#35-troubleshooting)

**Appendices**

* [Appendix A: Component, unit and interface index](#appendix-a-component-unit-and-interface-index)
* [Appendix B: Spacewar (AppID 480) as a test bed](#appendix-b-spacewar-appid-480-as-a-test-bed)

---

# Part I - Foundations

## 1. How to read this manual

### 1.1 Order

The chapters are ordered so that **everything a chapter relies on has
already been described**:

* Part I explains the pieces every other chapter uses: the core concepts
  (types, events, call results), the root component `TSteamAPI`, and the two
  plug-ins most others lean on - `TSteamUtils` (images, overlay state,
  language) and `TSteamUser` (the player's SteamID, authentication tickets).
* Part II covers the features games use most, most popular first, each
  after the chapters it builds on. For example, avatars in
  [TSteamFriends](#10-tsteamfriends---friends-avatars-overlay-rich-presence)
  use the image helpers of chapter 5 and 6; lobbies in
  [TSteamMatchmaking](#12-tsteammatchmaking---lobbies) use the Friends
  overlay; the [networking chapter](#13-networking) introduces
  `TSteamNetworkingUtils` and the shared networking records before the two
  interfaces that send data.
* Part III covers the remaining client interfaces.
* Part IV covers game servers. It comes after Part II because a game server
  authenticates players with the tickets of chapter 7, keeps their stats
  like chapter 8, and talks to them with the interfaces of chapter 13; the
  server browser (chapter 31) comes last because it lists those servers.
* Part V collects reference material and troubleshooting.

The generated pages in [components/](components/README.md) list **every**
method, event and payload record with Valve's own descriptions. This manual
explains how to use them; look there for the complete list.

### 1.2 Conventions used in the examples

* Unless a heading says otherwise, examples are **Delphi FireMonkey (FMX)**
  form code. VCL and Lazarus (LCL) code is the same apart from the framework
  unit (`Steamworks.VCL` / `Steamworks.LCL` instead of `Steamworks.FMX`) and
  the framework's own controls.
* Components dropped on a form keep the IDE's default names: `SteamAPI1`,
  `SteamUserStats1`, `SteamFriends1`, ... An event handler named
  `SteamFriends1AvatarImageLoaded` is the handler of
  `SteamFriends1.OnAvatarImageLoaded`.
* Each component chapter opens with the component's palette icon, as it
  appears on the IDE's **Steamworks** palette page
  ([ComponentIcons.md](ComponentIcons.md)).
* `Log(...)` is a one-line helper of the example form, not part of the
  library:

  ```pascal
  procedure TForm1.Log(const S: string);
  begin
    Memo1.Lines.Add(S);
  end;
  ```

* `SteamText(...)` converts a C string from a Steam record (an
  `array of AnsiChar` or a `PAnsiChar`) to a Pascal `string`. It is also a
  helper of the examples:

  ```pascal
  function SteamText(P: PAnsiChar): string;
  begin
    Result := string(UTF8String(P));   // Steam strings are UTF-8
  end;
  // usage with a fixed array field:  SteamText(@AData.m_rgchAchievementName[0])
  ```

* Examples that use `TBytes`, `TEncoding` or `Format` need `SysUtils` (or
  `System.SysUtils`) in the `uses` clause.
* The AppID is **480** throughout. It is set **once** - in `SteamAPI1.AppID`
  (Object Inspector, or one assignment in code) - and every other call
  reads it back from there (`SteamAPI1.AppID`), as the repository's source
  rules require: a stored value is never typed a second time.
* Spacewar's own names (stats, achievements, leaderboards, an inventory
  generator) are Valve's configuration of that app
  ([Appendix B](#appendix-b-spacewar-appid-480-as-a-test-bed)). The examples
  use them through named constants, declared once in the example form's
  unit:

  ```pascal
  const
    // Spacewar (AppID 480) - Valve's configuration, see Appendix B
    STAT_NUM_GAMES         = 'NumGames';
    STAT_NUM_WINS          = 'NumWins';
    STAT_NUM_LOSSES        = 'NumLosses';
    STAT_FEET_TRAVELED     = 'FeetTraveled';
    STAT_MAX_FEET_TRAVELED = 'MaxFeetTraveled';
    STAT_AVERAGE_SPEED     = 'AverageSpeed';
    ACH_WIN_ONE_GAME       = 'ACH_WIN_ONE_GAME';
    ACH_WIN_100_GAMES      = 'ACH_WIN_100_GAMES';
    WINS_FOR_100_GAMES     = 100;          // the achievement's threshold
    PROGRESS_STEP          = 10;           // show a progress pop-up every 10 wins
    LB_QUICKEST_WIN        = 'Quickest Win';
    LB_FEET_TRAVELED       = 'Feet Traveled';
    SPACEWAR_DROP_GENERATOR = 10;          // Valve's sample: timed drop list
    // URL patterns, filled with SteamAPI1.AppID
    COMMUNITY_APP_URL      = 'https://steamcommunity.com/app/%d';
    STORE_APP_URL          = 'https://store.steampowered.com/app/%d/';
  ```

---

## 2. Before you start

### 2.1 What you need

| Item | Notes |
|------|-------|
| A Pascal compiler | **Delphi 13** (the reference; FMX and VCL) or **Free Pascal 3.2.2** with Lazarus (LCL). Earlier Delphi versions from 11.0 are planned but not yet tested. |
| The Steamworks SDK 1.65 | `steamworks_sdk_165.zip`, from the Steamworks partner site. You only need the redistributable libraries from it (`sdk/redistributable_bin`). |
| The Steam client | Installed, running and **logged in** on the machine where the game runs. |
| An AppID | Your own, or **480** (Spacewar) for experiments. |

### 2.2 Supported platforms

| Platform | Delphi target | FPC target | Steam library (from `redistributable_bin/`) |
|----------|---------------|------------|---------------------------------------------|
| Windows 32-bit | Win32 | i386-win32 | `steam_api.dll` |
| Windows 64-bit | Win64 | x86_64-win64 | `win64/steam_api64.dll` |
| macOS Intel | OSX64 | x86_64-darwin | `osx/libsteam_api.dylib` |
| macOS ARM | OSXARM64 | aarch64-darwin | `osx/libsteam_api.dylib` |
| Linux x86_64 | Linux64 | x86_64-linux | `linux64/libsteam_api.so` |
| Linux i386 | - | i386-linux | `linux32/libsteam_api.so` (may be dropped) |
| Linux ARM64 | - | aarch64-linux | `linuxarm64/libsteam_api.so` |
| Android ARM64 | Android64 | aarch64-android | `androidarm64/libsteam_api.so` |

iOS has no Steam redistributable. The program needs the Steam library for
its platform **next to the executable** (inside the bundle on macOS).
`TSteamLib.RedistributableName` returns the file name the running build
needs, and every load error names it.

### 2.3 Telling Steam which game is running

Steam must know the AppID before it initialises. There are three ways:

| Way | When to use |
|-----|-------------|
| `TSteamAPI.SetAppIdEnvironment := True` (with `AppID := 480`) | **Development.** The component sets the `SteamAppId` / `SteamGameId` environment variables before loading Steam. No file needed. |
| A file `steam_appid.txt` containing `480` next to the executable | Development, or a dedicated game server. |
| Nothing - Steam supplies it | **Release builds started by Steam.** Set `RestartIfNecessary := True` so a copy started outside Steam is relaunched through it. |

Never ship `steam_appid.txt` or `SetAppIdEnvironment` in a release build,
and never combine `RestartIfNecessary` with AppID 480: Spacewar is not your
game, so Steam would try to launch Spacewar instead.

---

## 3. Installing the library

Full, step-by-step instructions, including every warning that looks
alarming but is harmless, are in [Install-Delphi.md](Install-Delphi.md) and
[Install-Lazarus-FPC.md](Install-Lazarus-FPC.md). The short version:

### 3.1 Delphi

1. Copy the **contents** of the SDK's `sdk/redistributable_bin` into the
   repository's `redistributable_bin/` and check it:
   `python3 tools/check_redist.py`.
2. Open `Steamworks.groupproj`.
3. For each target platform, **Build** the runtime packages `Steamworks`
   and then `SteamworksFMX` and / or `SteamworksVCL`. Their compiled units
   go to Delphi's `Dcp` folder, which is on the default library path, so
   your projects need no search paths.
4. For the IDE's own platform (Win32 for the 32-bit IDE), **Install** the
   design packages `dclSteamworks` (all plug-in components) and
   `dclSteamworksFMX` and / or `dclSteamworksVCL` (the framework's
   `TSteamAPI`). The components appear on the **Steamworks** palette page.

After changing library sources, rebuild the runtime packages before the
programs that use them.

### 3.2 Lazarus / Free Pascal

1. Same step 1 as for Delphi.
2. **Package > Open Package File**, choose `packages/SteamworksLCL.lpk`,
   **Compile**, then **Use > Install**.
3. Copy the Steam library next to your executable **by hand** (Lazarus has
   no deployment step for it).
4. On Linux and macOS make `cthreads` the first unit of the program:

   ```pascal
   program MyGame;
   uses
     {$ifdef UNIX} cthreads, {$endif}
     Interfaces, Forms, uMain;
   ```

5. A form that handles typed events also needs `Steamworks.SDKTypes` (and
   `Steamworks.Callbacks` for `OnCallback`) in its `uses`; Lazarus does
   not add them for you, Delphi does.

### 3.3 Getting the Steam library next to the executable (Delphi)

* **Windows:** a post-build event per platform, for example (Win64):
  `copy /Y "<repository>\redistributable_bin\win64\steam_api64.dll" "$(OUTPUTDIR)"`.
  Or copy it once by hand into `Win64\Debug\` / `Win64\Release\`.
* **macOS, Linux, Android:** Project > Deployment > Add Files:

  | Platform | Library | Remote path |
  |----------|---------|-------------|
  | OSX64 / OSXARM64 | `osx/libsteam_api.dylib` | `Contents\MacOS\` |
  | Linux64 | `linux64/libsteam_api.so` | `.\` |
  | Android64 | `androidarm64/libsteam_api.so` | `library\lib\arm64-v8a\` |

### 3.4 A first test

Build and run the **SteamDemo** project (or **SteamConsole**) with the Steam
client running. If the log shows the Steam language and your persona name,
everything is in place.

---

## 4. Core concepts

This chapter explains the ideas every later chapter uses. Read it once;
afterwards each component chapter only shows what is specific to it.

### 4.1 Core, plug-ins and components

The library is a small **core** plus one **plug-in** per Steam interface:

```
TSteamAPI (FMX / VCL / LCL)           the root component you drop on a form
  -> TCustomSteamAPI                  framework-free life cycle (Steamworks.Components)
     -> TSteamworks  (Steam)          the core singleton (Steamworks.Core)
          -> TSteamLib                the loaded Steam library and its flat exports
          -> TSteamCallbackDispatcher callbacks and call results
          -> TSteam<Name>Plugin ...   one per linked interface (lib/plugins)

TSteam<Name>  (TSteamFriends, ...)    plug-in components: typed events + .Plugin
```

Each interface unit `Steamworks.Plugin.<Name>` declares two classes:

* **`TSteam<Name>Plugin`** - the interface's methods. Usable from any code:
  console programs, game loops, any framework, Delphi or FPC.
* **`TSteam<Name>`** - a non-visual component. Its published events are the
  interface's callbacks, typed with the SDK's records, and its `Plugin`
  property gives the methods.

**Only what you link is compiled in.** Dropping a `TSteamFriends`, or
naming `Steamworks.Plugin.Friends` in a `uses` clause, registers the Friends
plug-in. Interfaces you never reference are not linked.

### 4.2 The plug-in component pattern

Every plug-in component in this manual has the same four members:

| Member | Kind | Meaning |
|--------|------|---------|
| `SteamAPI` | published property | The `TSteamAPI` it belongs to. At run time a component whose owner holds **exactly one** `TSteamAPI` links itself, so dropping both on a form is enough. |
| `Plugin` | public property | The `TSteam<Name>Plugin` with the methods. **`nil` while Steam is not running.** |
| `Attached` | public property | `True` while its events are subscribed (Steam running and `SteamAPI` set). |
| `Attach` / `Detach` | public methods | Subscribe / unsubscribe by hand; normally automatic. |

Events become live when Steam starts and are removed when it stops. The
usual place for start-up calls is therefore `TSteamAPI.OnInitialized`:

```pascal
procedure TForm1.SteamAPI1Initialized(Sender: TObject);
begin
  Log('Hello, ' + SteamFriends1.Plugin.GetPersonaName);
end;
```

Reaching a plug-in without a component:

```pascal
uses Steamworks.Core, Steamworks.Plugin.Friends;

var
  F: TSteamFriendsPlugin;
begin
  F := TSteamFriendsPlugin(Steam.FindPlugin(TSteamFriendsPlugin));  // Delphi and FPC
  // Delphi only:  F := Steam.Plugin<TSteamFriendsPlugin>;
  if F <> nil then
    Writeln(F.GetPersonaName);
end;
```

### 4.3 Types you will meet everywhere

| Type | Unit | Meaning |
|------|------|---------|
| `TSteamID` | `Steamworks.Types` | A 64-bit Steam id (user, lobby, group, game server). A packed record with `Value: UInt64`, `TSteamID.Create(UInt64)`, implicit conversion to and from `UInt64`, `=` / `<>`, `IsValid`, `AccountID`, `AccountType`, `Universe` and `ToString` (the decimal 64-bit number). |
| `AppId_t` | `Steamworks.Types` | `UInt32` application id (480 for Spacewar). |
| `SteamAPICall_t` | `Steamworks.Types` | `UInt64` handle of an asynchronous call; `k_uAPICallInvalid` (0) means the call was not made. |
| `HAuthTicket`, `AccountID_t`, `RTime32`, ... | `Steamworks.Types` | Steam's integer handles and times. |
| `EResult` and every other `E...` enum, every `..._t` record | `Steamworks.SDKTypes` | Generated from the SDK. Enum values keep Valve's names (`k_EResultOK`). Flag enums (`EFriendFlags`, `EItemState`, `EPersonaChange`, ...) are `Integer` types with constants, so they combine with `or` / `and`. |

Conventions of the generated methods:

* Names follow Valve's **flat API** (`GetStatInt32`, not the C++ overload
  `GetStat`) and keep Valve's parameter names.
* `const char*` parameters are `string`; returned C strings become `string`.
* Single out-values are `var` parameters
  (`GetAchievement(Name, var Achieved)`).
* Buffers, arrays and optional (NULL-able) pointers stay `Pointer` with a
  count - pass `@Buffer[0]` and the length, or `nil`.
* Steam ids inside **records** often arrive as `UInt64` (fields named
  `m_ul...`); wrap them with `TSteamID.Create(...)`.

### 4.4 Three ways Steam answers

**1. Synchronous calls.** Most methods return at once from Steam's local
state:

```pascal
Log(SteamUtils1.Plugin.GetSteamUILanguage);      // e.g. 'english'
```

**2. Callbacks (component events).** Steam posts notifications - a friend
came online, the overlay opened, an achievement was stored. Each becomes a
published event of the component, with the SDK record as payload:

```pascal
procedure TForm1.SteamFriends1GameOverlayActivated(Sender: TObject;
  const AData: GameOverlayActivated_t);
begin
  FPaused := AData.m_bActive <> 0;    // pause a single-player game
end;
```

Double-click the event in the Object Inspector and the IDE writes the
handler with the right record type.

**3. Call results.** Methods that return `SteamAPICall_t` start an
asynchronous request. The answer arrives later in one of two ways:

* **through the component's event of the same record**, if it has one
  (`FindLeaderboard` answers through `OnLeaderboardFindResult`); or
* **through a handler you pass** to the `...Async` variant of the method.
  The handler receives only the answer to *that* call:

```pascal
procedure TForm1.btnPlayersClick(Sender: TObject);
begin
  SteamUserStats1.Plugin.GetNumberOfCurrentPlayersAsync(PlayersCounted);
end;

procedure TForm1.PlayersCounted(const AData: TSteamCallbackData; AIOFailure: Boolean);
var
  R: NumberOfCurrentPlayers_t;
begin
  if AIOFailure or not AData.CopyTo(R, SizeOf(R)) then
    Exit;                                     // Steam could not answer
  if R.m_bSuccess <> 0 then
    Log(Format('%d people are playing Spacewar right now', [R.m_cPlayers]));
end;
```

Rules for call results:

* The handler type is `TSteamCallResultEvent =
  procedure(const AData: TSteamCallbackData; AIOFailure: Boolean) of object`.
* `AData.CopyTo(Record, SizeOf(Record))` copies the payload into the SDK
  record and returns `False` when the sizes differ. Delphi (and FPC 3.3.1+)
  also has `AData.AsRecord<T>`.
* `AIOFailure = True` means Steam could not deliver the answer (network
  failure, Steam gone). Always check it.
* A call result handled by an `...Async` handler does **not** also raise
  the component event. A failed call result raises no event at all; it is
  logged as a warning.
* The handler's **object owns** the registration. If that object can be
  freed before the answer arrives, remove its registrations in its
  destructor: `Steam.Dispatcher.RemoveOwner(Self)`.

### 4.5 The dispatcher - callbacks without components

Code that does not use components subscribes to callbacks directly. Each
SDK record has a constant `<Record>_k_iCallback` with its id:

```pascal
uses Steamworks.Core, Steamworks.Callbacks, Steamworks.SDKTypes;

procedure TGame.Start;
begin
  Steam.Dispatcher.Subscribe(LowBatteryPower_t_k_iCallback, LowBattery);
end;

procedure TGame.LowBattery(const AData: TSteamCallbackData);
var
  Ev: LowBatteryPower_t;
begin
  if AData.CopyTo(Ev, SizeOf(Ev)) then
    ShowWarning(Format('%d minutes of battery left', [Ev.m_nMinutesBatteryLeft]));
end;

destructor TGame.Destroy;
begin
  if TSteamworks.HasInstance then
    Steam.Dispatcher.RemoveOwner(Self);       // drop every subscription of this object
  inherited;
end;
```

| Dispatcher method | Use |
|-------------------|-----|
| `Subscribe(ID, Handler, IncludeCallResults = False): TSteamSubscription` | Receive every callback with that id. |
| `AwaitCallResult(Call, ExpectedID, Handler): Boolean` | Receive the result of one `SteamAPICall_t` (what the `...Async` methods do for you). |
| `Unsubscribe(var Token)`, `UnsubscribeAll(ID)`, `RemoveOwner(Obj)` | Remove subscriptions. |
| `CancelCallResult(Call)`, `IsCallResultPending(Call)` | Manage a pending call result. |
| `SubscribeTyped<T>(ID, Proc)` / `AwaitCallResultTyped<T>(...)` | Anonymous-method variants with the record already copied (Delphi, FPC 3.3.1+). |
| `OnAnyCallback`, `OnHandlerError` | Diagnostics: every callback, and exceptions raised by handlers. |

Anonymous-method form (Delphi):

```pascal
Steam.Dispatcher.SubscribeTyped<GameOverlayActivated_t>(GameOverlayActivated_t_k_iCallback,
  procedure(const D: GameOverlayActivated_t)
  begin
    FPaused := D.m_bActive <> 0;
  end, Self);                                  // Self = owner, for RemoveOwner
```

Game-server callbacks have their own dispatcher, `Steam.ServerDispatcher`
(see [chapter 27](#27-running-a-game-server-with-tsteamapi)).

### 4.6 Raw access: `Plugin.Flat`

Every plug-in exposes `Flat`, a record with every flat export of its
interface in its exact C signature, and `Handle`, the interface pointer
that is the first argument. Use it for anything the generated methods do
not cover - for example passing C `NULL` where the method takes a
`string`:

```pascal
P := SteamScreenshots1.Plugin;
P.Flat.AddScreenshotToLibrary(P.Handle, PAnsiChar(UTF8String(FileName)), nil, W, H);
```

Every export is bound as **optional**: if the loaded Steam library lacks
one, calling the method raises `ESteamworksError` naming it.
`Assigned(P.Flat.Xxx)` tells beforehand; the missing exports are logged
once at start-up.

### 4.7 Strings, buffers and times

* **Strings:** methods take and return `string`. Records carry C strings as
  `array of AnsiChar` - convert with `SteamText(@R.m_rgchName[0])`.
* **Buffers:** a method such as `GetAppInstallDir(AppID, pchFolder,
  cchFolderBufferSize)` fills a buffer you pass:

  ```pascal
  var
    Buf: array[0..1023] of AnsiChar;
  begin
    if SteamApps1.Plugin.GetAppInstallDir(SteamAPI1.AppID, @Buf[0], SizeOf(Buf)) > 0 then
      Log('Installed in ' + SteamText(@Buf[0]));
  end;
  ```

* **Times:** Steam times are Unix seconds in UTC. `SteamTimeToLocal`
  (`Steamworks.Types`) converts one to local `TDateTime`, with the summer /
  winter offset that applied on that date. Prefer it to
  `UnixToDateTime(T, False)`, which on FPC 3.2 applies today's offset.

### 4.8 Images

Avatars and achievement icons are **integer image handles**:

| Handle | Meaning |
|--------|---------|
| > 0 | Ready - convert it. |
| -1 | Steam is still downloading it; an event brings the real handle (`TSteamFriends.OnAvatarImageLoaded`). |
| 0 | None (or, for achievement icons, "not loaded yet" - see [chapter 8](#86-achievement-icons)). |

Two converters exist; both appear later in this order:

* `SteamImageToBitmap(Handle, Bitmap)` in the framework unit
  (`Steamworks.FMX` / `.VCL` / `.LCL`) - see [5.9](#59-images-and-screenshots-steamimagetobitmap-steamformtorgb).
* `TSteamUtilsPlugin.GetImageRGBABytes(Handle, W, H)` - raw RGBA bytes, for
  game engines - see [chapter 6](#6-tsteamutils---client-utilities).

### 4.9 Errors

* All library errors are `ESteamworksError`.
* A **payload size mismatch** - Steam's record size differs from the Pascal
  record - raises `ESteamworksError` instead of handing over a wrong
  record. A layout bug never passes silently.
* An exception in **your** event handler never blocks Steam's queue: it is
  shown (main thread) or logged (worker thread), and callbacks keep
  flowing.
* Calling a method whose export is missing raises `ESteamworksError` naming
  the export.

More in [chapter 33](#33-errors-logging-and-diagnostics).

---

## 5. TSteamAPI - the root component

<img src="../design/icons/svg/TSteamAPI.svg" width="48" height="48" alt="TSteamAPI palette icon">

`TSteamAPI` loads the Steam library, optionally relaunches the game through
Steam, initialises SteamAPI and every linked plug-in, keeps callbacks
flowing, and shuts it all down again. **Every other component depends on
it.**

| Framework | Unit | Delphi packages | Timer |
|-----------|------|-----------------|-------|
| FireMonkey | `Steamworks.FMX` | `SteamworksFMX` / `dclSteamworksFMX` | FMX `TTimer` |
| VCL | `Steamworks.VCL` | `SteamworksVCL` / `dclSteamworksVCL` | VCL `TTimer` |
| LCL | `Steamworks.LCL` | `SteamworksLCL.lpk` | LCL `TTimer` |

All three have the same name, properties and events. They differ only in
the timer, how an exception is shown and how the application is ended;
everything else lives in `TCustomSteamAPI` (`Steamworks.Components`).

**One per application.** Steam is process-wide: a second `TSteamAPI` at
run time raises `ESteamworksError` (several on different forms at design
time are fine).

### 5.1 Quick start at design time

1. Drop a `TSteamAPI` on the main form.
2. Set `AppID` to `480`.
3. Drop the plug-in components you need - for example `TSteamFriends` and
   `TSteamUserStats`. They link themselves to `SteamAPI1` at run time.
4. In `FormCreate`, set the development-only options, then start Steam:

```pascal
procedure TForm1.FormCreate(Sender: TObject);
begin
  {$ifdef DEBUG}
  SteamAPI1.SetAppIdEnvironment := True;   // development: no steam_appid.txt
  {$else}
  SteamAPI1.RestartIfNecessary := True;    // release: relaunch through Steam
  {$endif}
  SteamAPI1.Active := True;                // or SteamAPI1.Open
end;

procedure TForm1.SteamAPI1Initialized(Sender: TObject);
begin
  Log('Steam is running as ' + SteamFriends1.Plugin.GetPersonaName);
end;

procedure TForm1.SteamAPI1InitFailed(Sender: TObject; AResult: Integer;
  const AMessage: string);
begin
  Log(Format('Steam did not start (%d): %s', [AResult, AMessage]));
end;
```

> With AppID 480 leave `RestartIfNecessary` off in **every** build; it is
> shown here as the pattern for your own AppID.

### 5.2 Quick start in code

```pascal
uses
  Steamworks.Types, Steamworks.Core, Steamworks.SDKTypes, Steamworks.FMX,
  Steamworks.Plugin.Utils, Steamworks.Plugin.Friends;

type
  TForm1 = class(TForm)
  private
    FSteam: TSteamAPI;
    FFriends: TSteamFriends;
    procedure FriendChanged(Sender: TObject; const AData: PersonaStateChange_t);
  end;

procedure TForm1.FormCreate(Sender: TObject);
begin
  FSteam := TSteamAPI.Create(Self);
  FSteam.AppID := 480;
  FSteam.SetAppIdEnvironment := True;

  FFriends := TSteamFriends.Create(Self);
  FFriends.SteamAPI := FSteam;                     // automatic for dropped components
  FFriends.OnPersonaStateChange := FriendChanged;

  if FSteam.Open then                              // no message box on failure
    Caption := FSteam.Steam.Plugin<TSteamUtilsPlugin>.GetSteamUILanguage
      + ' / ' + FFriends.Plugin.GetPersonaName
  else
    Caption := 'Steam: ' + FSteam.Steam.LastError;
end;

procedure TForm1.FriendChanged(Sender: TObject; const AData: PersonaStateChange_t);
begin
  Log(FFriends.Plugin.GetFriendPersonaName(TSteamID.Create(AData.m_ulSteamID))
    + ' changed');
end;
```

### 5.3 Properties

| Property | Type, default | Meaning |
|----------|---------------|---------|
| `Active` | `Boolean`, `False` | Starts / stops Steam. At design time only stored. A failed start leaves it `False`. |
| `AppID` | `Cardinal`, 0 | The AppID (480). Used by `RestartIfNecessary` and `SetAppIdEnvironment`. |
| `SetAppIdEnvironment` | `Boolean`, `False` | Sets `SteamAppId` / `SteamGameId` before loading Steam. Development and dedicated servers only. |
| `RestartIfNecessary` | `Boolean`, `False` | Calls `SteamAPI_RestartAppIfNecessary` first; a copy started outside Steam is relaunched through Steam (`OnRestartRequired`) and ends. For release builds of your own AppID. |
| `LibraryPath` | `string`, '' | Full path of the Steam library. Empty: the platform's file name, searched next to the executable (and in the macOS bundle) first. |
| `InitMode` | `TSteamInitMode`, `simAuto` | `simAuto` (flat init when available), `simFlat`, `simVersioned` (only the interface versions the linked plug-ins need), `simLegacy` (pre-1.59 libraries). |
| `UpdateMode` | `TSteamUpdateMode`, `sumTimer` | Who reads Steam's callback queue: the framework timer, a worker thread (`sumThread`) or your own loop (`sumManual`). See [chapter 32](#32-update-modes-and-threads). |
| `Delivery` | `TSteamDelivery`, `sdMainThread` | With `sumThread`: where events run - main thread, inside `Update` (`sdOnUpdate`) or on the worker (`sdPumpThread`). |
| `CallbackInterval` | `Integer`, 33 | Timer interval in ms (`sumTimer`; 0 = no timer), or the worker's period (`sumThread`; 0 = 1 ms). |
| `InstallWarningHook` | `Boolean`, `True` | Routes Steam's debug text to `OnWarning` (Steam only produces it with the `-debug_steamapi` launch option). |
| `ShutdownOnSteamExit` | `Boolean`, `True` | Shuts SteamAPI (not the program) down as soon as the Steam client exits, right after `OnSteamShutdown`. |
| `QuitOnSteamShutdown` | `Boolean`, `False` | Also ends the application when the Steam client exits. |
| `BigPictureWindow` | `TSteamBigPictureWindow`, `bpwMaximized` | What happens to the form in Big Picture / Game Mode: `bpwMaximized`, `bpwFullScreen` or `bpwNone`. |
| `Roles` | `TSteamRoles`, `[srClient]` | What `Active` starts: a game (`[srClient]`), a listen server from the start (`[srClient, srGameServer]`) or a dedicated server (`[srGameServer]`). See Part IV. |
| `GameServerIP`, `GameServerGamePort` (27015), `GameServerQueryPort` (27016), `GameServerMode`, `GameServerVersion` | | Game-server settings, see [chapter 27](#27-running-a-game-server-with-tsteamapi). |
| `Steam` | `TSteamworks`, public, read-only | The core singleton: `FindPlugin`, `Dispatcher`, `LastError`, `Versions`, ... |
| `IsRunning` | `Boolean`, public, read-only | `True` while the Steam client API is initialised. |
| `IsGameServerRunning` | `Boolean`, public, read-only | `True` while a game server runs. |
| `InBigPicture` | `Boolean`, public, read-only | Steam reported Big Picture / Game Mode when it started. |

### 5.4 Events

| Event | Signature | When |
|-------|-----------|------|
| `OnInitialized` | `TNotifyEvent` | Steam started; plug-in components are attached. **Put start-up calls here.** |
| `OnInitFailed` | `(Sender; AResult: Integer; const AMessage: string)` | Steam could not start. `AResult` is the `ESteamAPIInitResult` (2 = Steam client not running). Assigning it suppresses the automatic message box. |
| `OnShutdown` | `TNotifyEvent` | SteamAPI was shut down. |
| `OnSteamShutdown` | `TNotifyEvent` | The Steam client is exiting (callback 704). **Save now** - Steam calls still work inside this handler. Raised once per session. |
| `OnRestartRequired` | `(Sender; var ATerminate: Boolean)` | With `RestartIfNecessary`: Steam is relaunching the game; leave `ATerminate = True` to end this copy. |
| `OnLog` | `(Sender; ALevel: TSteamLogLevel; const AMessage: string)` | Diagnostic messages, `sllDebug` .. `sllError`. Log them. |
| `OnWarning` | `(Sender; ASeverity: Integer; const AText: string)` | Steam's own debug output (0 = message, 1 = warning). |
| `OnCallback` | `(Sender; const AData: TSteamCallbackData)` | Every callback and call result, before the components see it - for diagnostics. |
| `OnGameServerStarted` / `OnGameServerStopped` / `OnGameServerFailed` | | Game-server life cycle, see Part IV. |

### 5.5 Methods

| Method | Meaning |
|--------|---------|
| `Open: Boolean` | `Active := True` without any message box; returns whether Steam runs. |
| `Close` | `Active := False`. Safe to call twice and from an event handler. |
| `Update` / `RunCallbacks` | Read / deliver callbacks now. Call every frame with `UpdateMode = sumManual`, or with `sumThread` + `sdOnUpdate`. |
| `SetUpdateMode(Mode, Delivery, IntervalMs = -1)` | Change update mode, delivery and interval in one call; applies at once while running. Main thread only, never from an event handler. |
| `StartGameServer: Boolean` / `StopGameServer` | Start / stop a game server (Part IV). |
| `DisplaySize(out W, H; out Scale): Boolean` | Size of the display the form is on (pixels in VCL / LCL; logical units in FMX, times `Scale` for pixels). |

### 5.6 Life cycle

`Active := True` (or `Open`):

1. Pushes the settings to the core (`Steam`).
2. With `RestartIfNecessary`: asks Steam; if Steam relaunches the game,
   `OnRestartRequired` fires and the program ends.
3. Loads the Steam library and initialises SteamAPI.
4. Initialises every linked plug-in.
5. Starts the timer (`sumTimer`) or worker (`sumThread`).
6. Attaches the plug-in components - their events become live.
7. Asks Steam about Big Picture and applies `BigPictureWindow`.
8. Raises `OnInitialized`.

`Active := False`, `Close` or destroying the form reverses this and raises
`OnShutdown`. After a shutdown - including one caused by the Steam client
exiting - `Open` starts Steam again.

**Do not free `TSteamAPI` inside one of its own (or a plug-in
component's) events.** Call `Close` there and free it later.

### 5.7 Example: a robust start with logging and retry

```pascal
procedure TForm1.FormCreate(Sender: TObject);
begin
  SteamAPI1.AppID := 480;
  SteamAPI1.SetAppIdEnvironment := True;
  SteamAPI1.OnLog := SteamLog;
  StartSteam;
end;

procedure TForm1.StartSteam;
begin
  if not SteamAPI1.Open then
  begin
    Log('Steam not available: ' + SteamAPI1.Steam.LastError);
    tmRetry.Enabled := True;            // a TTimer, e.g. every 5 s
  end;
end;

procedure TForm1.tmRetryTimer(Sender: TObject);
begin
  tmRetry.Enabled := False;
  StartSteam;
end;

procedure TForm1.SteamLog(Sender: TObject; ALevel: TSteamLogLevel;
  const AMessage: string);
const
  Names: array[TSteamLogLevel] of string = ('debug', 'info', 'WARN', 'ERROR');
begin
  Log(Format('[%s] %s', [Names[ALevel], AMessage]));
end;

procedure TForm1.SteamAPI1SteamShutdown(Sender: TObject);
begin
  SaveGame;                              // Steam is going away - save now
  Log('Steam client exited; will retry later');
  tmRetry.Enabled := True;
end;
```

### 5.8 Example: no components at all (console or engine loop)

The core singleton `Steam` (`Steamworks.Core`) does everything the
component does:

```pascal
program SpacewarConsole;
{$APPTYPE CONSOLE}
uses
  {$ifdef UNIX} cthreads, {$endif}
  SysUtils, Steamworks.Core, Steamworks.Plugin.Utils, Steamworks.Plugin.Friends;

var
  Utils: TSteamUtilsPlugin;
  I: Integer;
begin
  Steam.AppID := 480;
  Steam.SetAppIdEnvironment := True;
  if not Steam.Initialize then
  begin
    Writeln('Steam did not start: ', Steam.LastError);
    Halt(1);
  end;
  try
    Utils := TSteamUtilsPlugin(Steam.FindPlugin(TSteamUtilsPlugin));
    Writeln('AppID ', Utils.GetAppID, ', language ', Utils.GetSteamUILanguage);
    Writeln('Hello ', TSteamFriendsPlugin(Steam.FindPlugin(TSteamFriendsPlugin)).GetPersonaName);
    for I := 1 to 100 do               // pump callbacks for ~3 s
    begin
      Steam.Update;                    // = Steam.RunCallbacks
      Sleep(33);
    end;
  finally
    Steam.Shutdown;
  end;
end.
```

For a game loop, `Steam.SetUpdateMode(sumThread, sdOnUpdate)` before
`Initialize` moves Steam's I/O to a worker thread while your handlers still
run inside `Steam.Update` on the game thread ([chapter 32](#32-update-modes-and-threads)).

### 5.9 Images and screenshots: SteamImageToBitmap, SteamFormToRGB

Each framework unit (`Steamworks.FMX`, `.VCL`, `.LCL`) adds three
functions for its own `TBitmap` and form classes:

```pascal
function SteamImageToBitmap(AImage: Integer; ABitmap: TBitmap): Boolean;
function SteamFormToRGB(AForm: TCustomForm; out AWidth, AHeight: Integer): TBytes;
function SteamBitmapToRGB(ABitmap: TBitmap): TBytes;
```

* `SteamImageToBitmap` copies a Steam image handle (avatar, achievement
  icon) into a bitmap. It returns `False` for 0 (none) and -1 (still
  loading). Used in chapters 8 and 10.
* `SteamFormToRGB` paints the form's client area into packed 24-bit RGB,
  rows top-down - exactly what `TSteamScreenshotsPlugin.WriteScreenshot`
  takes. It is how a game writes a screenshot **without the Steam overlay**
  (chapter 16).
* `SteamBitmapToRGB` does the same for a bitmap you rendered yourself (a 3D
  viewport, a render target).

```pascal
procedure TForm1.ShowMyAvatar;
var
  H: Integer;
begin
  H := SteamFriends1.Plugin.GetLargeFriendAvatar(SteamUser1.Plugin.GetSteamID);
  if not SteamImageToBitmap(H, imgAvatar.Bitmap) then
    Log('avatar not ready yet (handle ' + IntToStr(H) + ')');
end;
```

### 5.10 Big Picture, Game Mode and the Steam Deck

In Big Picture (desktop) or Game Mode (Steam Deck, SteamOS handhelds,
Steam Machine) a game is shown full screen at the display's size - 1280 x
800 on a Steam Deck, up to 4K elsewhere. As Steam starts, `TSteamAPI` asks
Steam whether it runs in Big Picture and applies `BigPictureWindow` to its
form (the owner, or the application's main form): `bpwMaximized` (default)
fills the display, `bpwFullScreen` also removes the border, `bpwNone`
leaves the window alone. `InBigPicture` keeps the answer and `DisplaySize`
reports the display for your own layout code:

```pascal
procedure TForm1.SteamAPI1Initialized(Sender: TObject);
var
  W, H: Integer;
  Scale: Single;
begin
  if SteamAPI1.InBigPicture and SteamAPI1.DisplaySize(W, H, Scale) then
    Log(Format('Big Picture on a %d x %d display (scale %.2f)', [W, H, Scale]));
end;
```

### 5.11 When the Steam client exits

* **Windows, windowed program:** Steam asks the window to close (often
  **twice**) and sends no 704 first. Make `FormClose` safe to run twice;
  `TSteamAPI.Close` is.
* **Console programs, Linux, macOS:** Steam sends `SteamShutdown_t` (704) -
  `OnSteamShutdown`. On Linux Steam's pipe disappears soon after, so
  `ShutdownOnSteamExit` (default on) shuts SteamAPI down immediately after
  your handler returns. The program keeps running; call `Open` again once
  Steam is back.

Save your game in `OnSteamShutdown` **and** in your normal close path.

---

## 6. TSteamUtils - client utilities

<img src="../design/icons/svg/TSteamUtils.svg" width="48" height="48" alt="TSteamUtils palette icon">

Unit `Steamworks.Plugin.Utils`, interface `ISteamUtils`. Available whenever
SteamAPI runs, so it is the safest first test that Steam works. Later
chapters use it for **image pixels**, the **overlay state**, the **Steam
language** and **gamepad text input**.

### 6.1 Everyday calls

```pascal
procedure TForm1.SteamAPI1Initialized(Sender: TObject);
var
  U: TSteamUtilsPlugin;
begin
  U := SteamUtils1.Plugin;
  Log(Format('AppID %d', [U.GetAppID]));                         // 480
  Log('Steam language: ' + U.GetSteamUILanguage);                // e.g. english
  Log('Country (from IP): ' + U.GetIPCountry);                   // e.g. GB
  Log('Server time (UTC): ' + DateTimeToStr(U.ServerTime));
  Log('Overlay available: ' + BoolToStr(U.IsOverlayEnabled, True));
  Log('Big Picture: ' + BoolToStr(U.IsSteamInBigPictureMode, True));
  Log('Under Proton: ' + BoolToStr(U.IsRunningUnderProton, True));
  case U.IsRunningOnSteamHardware of
    k_ESteamHardwareTypeSteamDeck:    Log('Running on a Steam Deck');
    k_ESteamHardwareTypeSteamMachine: Log('Running on a Steam Machine');
  end;
  if U.GetCurrentBatteryPower <> 255 then                        // 255 = mains power
    Log(Format('Battery: %d %%', [U.GetCurrentBatteryPower]));
end;
```

| Method | Returns |
|--------|---------|
| `GetAppID` | The AppID Steam thinks is running. |
| `GetSteamUILanguage` | The Steam client's language. For your game's text use `TSteamApps.GetCurrentGameLanguage` ([chapter 11](#11-tsteamapps---ownership-dlc-language-betas)). |
| `GetServerRealTime` / `ServerTime` | Steam's server time: Unix seconds / `TDateTime` (UTC). Not affected by the user's clock. |
| `GetIPCountry` | Two-letter country of the user's IP address. |
| `IsOverlayEnabled` | Whether the overlay is in this process. **False for a program started from the IDE**; affects screenshots, store, binding panel. |
| `IsSteamInBigPictureMode`, `IsSteamRunningInVR`, `IsRunningUnderProton`, `IsSteamChinaLauncher` | Environment checks. |
| `IsRunningOnSteamHardware` | `ESteamHardwareType` (SDK 1.65; replaces the removed `IsRunningOnSteamDeck`, which is kept `deprecated`). |
| `GetCurrentBatteryPower` | 0..100, or 255 on mains power. |
| `SetOverlayNotificationPosition`, `SetOverlayNotificationInset` | Where Steam's pop-ups (achievement unlocked, ...) appear. |

```pascal
// achievement pop-ups at the bottom right, 20 px from the edges
SteamUtils1.Plugin.SetOverlayNotificationPosition(k_EPositionBottomRight);
SteamUtils1.Plugin.SetOverlayNotificationInset(20, 20);
```

### 6.2 Image pixels for engines

`GetImageRGBABytes(Image, out Width, Height): TBytes` returns straight RGBA,
4 bytes per pixel, rows top-down, or `nil` while the image is not
available. It is what `SteamImageToBitmap` uses; call it directly to upload
an avatar to a texture:

```pascal
var
  W, H: UInt32;
  Pixels: TBytes;
begin
  Pixels := SteamUtils1.Plugin.GetImageRGBABytes(AvatarHandle, W, H);
  if Pixels <> nil then
    MyTexture.Upload(@Pixels[0], W, H, pfRGBA8);    // your engine's call
end;
```

### 6.3 Gamepad text input (Steam Deck, Big Picture)

```pascal
procedure TForm1.btnNameClick(Sender: TObject);
begin
  if not SteamUtils1.Plugin.ShowGamepadTextInput(k_EGamepadTextInputModeNormal,
       k_EGamepadTextInputLineModeSingleLine, 'Pilot name', 32, edtName.Text) then
    edtName.SetFocus;                    // not in Big Picture: use the normal keyboard
end;

procedure TForm1.SteamUtils1GamepadTextInputDismissed(Sender: TObject;
  const AData: GamepadTextInputDismissed_t);
var
  Len: UInt32;
  Buf: TBytes;
begin
  if not AData.m_bSubmitted then
    Exit;                                // cancelled
  Len := SteamUtils1.Plugin.GetEnteredGamepadTextLength;
  SetLength(Buf, Len + 1);
  if SteamUtils1.Plugin.GetEnteredGamepadTextInput(@Buf[0], Len + 1) then
    edtName.Text := SteamText(@Buf[0]);
end;
```

`ShowFloatingGamepadTextInput(Mode, X, Y, W, H)` is the lighter variant: it
shows the keyboard while typing goes into your own edit field at that
rectangle; `OnFloatingGamepadTextInputDismissed` reports it closed.

### 6.4 Events

| Event | Payload | When |
|-------|---------|------|
| `OnIPCountry` | `IPCountry_t` | The user's IP country changed. |
| `OnLowBatteryPower` | `LowBatteryPower_t` (`m_nMinutesBatteryLeft`) | The battery is running low. |
| `OnGamepadTextInputDismissed` | `GamepadTextInputDismissed_t` | The big-picture keyboard closed. |
| `OnFloatingGamepadTextInputDismissed` | - | The floating keyboard closed. |
| `OnAppResumingFromSuspend` | - | The Steam Deck woke from sleep - resynchronise timers, reconnect. |
| `OnCheckFileSignature` | `CheckFileSignature_t` | Result of `CheckFileSignature`. |
| `OnFilterTextDictionaryChanged` | `FilterTextDictionaryChanged_t` | The text-filter dictionary changed. |

The plug-in itself also has `OnLowBattery` and `OnIPCountryChanged`
(plain method pointers) for code that does not use the component.

### 6.5 Text filtering

```pascal
var
  Buf: array[0..1023] of AnsiChar;
begin
  SteamUtils1.Plugin.InitFilterText(0);
  SteamUtils1.Plugin.FilterText(k_ETextFilteringContextChat, SenderID,
    ChatLine, @Buf[0], SizeOf(Buf));
  ShowChat(SteamText(@Buf[0]));          // profanity replaced per the user's settings
end;
```

---

## 7. TSteamUser - the logged-on user

<img src="../design/icons/svg/TSteamUser.svg" width="48" height="48" alt="TSteamUser palette icon">

Unit `Steamworks.Plugin.User`, interface `ISteamUser`. Gives the player's
**SteamID**, logon state and Steam level, and the **authentication
tickets** that game servers ([chapter 28](#28-tsteamgameserver)) and your
own backend use. Many later chapters need `GetSteamID`.

### 7.1 Who is playing

```pascal
procedure TForm1.SteamAPI1Initialized(Sender: TObject);
var
  U: TSteamUserPlugin;
  Me: TSteamID;
begin
  U := SteamUser1.Plugin;
  Me := U.GetSteamID;
  Log(Format('SteamID %s (account %d), level %d, logged on: %s',
    [Me.ToString, Me.AccountID, U.GetPlayerSteamLevel, BoolToStr(U.BLoggedOn, True)]));
end;
```

`BLoggedOn` is `False` while Steam runs in offline mode; most interfaces
then still work from cached data. The events report changes:

```pascal
procedure TForm1.SteamUser1SteamServersDisconnected(Sender: TObject;
  const AData: SteamServersDisconnected_t);
begin
  lblOnline.Text := 'Offline - progress will sync later';
end;

procedure TForm1.SteamUser1SteamServersConnected(Sender: TObject;
  const AData: SteamServersConnected_t);
begin
  lblOnline.Text := 'Online';
end;
```

### 7.2 Authentication for a Web API backend

Your own web server can verify who the player is. Ask Steam for a ticket,
send it to the server, and let the server check it with Valve's Web API
(`ISteamUserAuth/AuthenticateUserTicket`, with the same identity string):

```pascal
procedure TForm1.btnLoginClick(Sender: TObject);
begin
  FTicket := SteamUser1.Plugin.GetAuthTicketForWebApi('spacewar-backend');
end;

procedure TForm1.SteamUser1GetTicketForWebApiResponse(Sender: TObject;
  const AData: GetTicketForWebApiResponse_t);
var
  Hex: string;
  I: Integer;
begin
  if (AData.m_hAuthTicket <> FTicket) or (AData.m_eResult <> k_EResultOK) then
    Exit;
  Hex := '';
  for I := 0 to AData.m_cubTicket - 1 do
    Hex := Hex + IntToHex(AData.m_rgubTicket[I], 2);
  PostToMyServer('/login', Hex);                 // your HTTP code (or TSteamHTTP, chapter 21)
end;
```

Call `CancelAuthTicket(FTicket)` when the player logs out.

### 7.3 Authentication between peers or with a game server

A session ticket proves your identity to another player or a game server:

```pascal
// the player (client side)
var
  Ticket: TBytes;
  Size: UInt32;
begin
  SetLength(Ticket, 1024);
  FTicketHandle := SteamUser1.Plugin.GetAuthSessionTicket(@Ticket[0], Length(Ticket),
    Size, nil);                                  // nil: any recipient
  SetLength(Ticket, Size);
  SendToHost(Ticket);                            // your game's own message
end;

// the receiver (another player, or a game server's BeginAuthSession - chapter 28)
procedure TForm1.TicketArrived(const Ticket: TBytes; const From: TSteamID);
begin
  if SteamUser1.Plugin.BeginAuthSession(@Ticket[0], Length(Ticket), From)
     <> k_EBeginAuthSessionResultOK then
    Kick(From);
end;

procedure TForm1.SteamUser1ValidateAuthTicketResponse(Sender: TObject;
  const AData: ValidateAuthTicketResponse_t);
begin
  if AData.m_eAuthSessionResponse = k_EAuthSessionResponseOK then
    Log(AData.m_SteamID.ToString + ' is genuine')
  else
    Kick(AData.m_SteamID);
end;
```

Both sides end with `EndAuthSession(SteamID)` (receiver) and
`CancelAuthTicket(Handle)` (sender). `OnGetAuthSessionTicketResponse`
confirms the ticket is ready to be checked.

**Encrypted app tickets** - for backends that hold Valve's decryption key:

```pascal
SteamUser1.Plugin.RequestEncryptedAppTicketAsync(nil, 0, AppTicketReady);

procedure TForm1.AppTicketReady(const AData: TSteamCallbackData; AIOFailure: Boolean);
var
  R: EncryptedAppTicketResponse_t;
  Buf: TBytes;
  Size: UInt32;
begin
  if AIOFailure or not AData.CopyTo(R, SizeOf(R)) or (R.m_eResult <> k_EResultOK) then
    Exit;
  SetLength(Buf, 1024);
  if SteamUser1.Plugin.GetEncryptedAppTicket(@Buf[0], Length(Buf), Size) then
  begin
    SetLength(Buf, Size);
    SendToBackend(Buf);
  end;
end;
```

### 7.4 Other calls

* `GetUserDataFolder(Buffer, Size)` - Steam's per-user folder for this
  game. Prefer Steam Cloud ([chapter 9](#9-tsteamremotestorage---steam-cloud-saves)) for saves.
* `UserHasLicenseForApp(SteamID, AppID)` - after `BeginAuthSession`, whether
  that user owns an app (for example a DLC).
* `GetGameBadgeLevel`, `BIsPhoneVerified`, `BIsTwoFactorEnabled`,
  `GetMarketEligibilityAsync`, `GetDurationControlAsync` - account
  information.
* Voice chat: `StartVoiceRecording`, `GetAvailableVoice`, `GetVoice`,
  `DecompressVoice`, `GetVoiceOptimalSampleRate`, `StopVoiceRecording`.

### 7.5 Events

| Event | When |
|-------|------|
| `OnSteamServersConnected` / `OnSteamServersDisconnected` / `OnSteamServerConnectFailure` | Connection to Steam's servers changed. |
| `OnGetAuthSessionTicketResponse` | A session ticket is ready. |
| `OnGetTicketForWebApiResponse` | A Web API ticket is ready (contains the ticket bytes). |
| `OnValidateAuthTicketResponse` | Result of `BeginAuthSession` on this side. |
| `OnEncryptedAppTicketResponse` | Result of `RequestEncryptedAppTicket`. |
| `OnMicroTxnAuthorizationResponse` | The user answered an in-game purchase dialog. |
| `OnLicensesUpdated`, `OnClientGameServerDeny`, `OnIPCFailure`, `OnGameWebCallback`, `OnStoreAuthURLResponse`, `OnMarketEligibilityResponse`, `OnDurationControl` | See [components/TSteamUser.md](components/TSteamUser.md). |

---

# Part II - The most-used Steam features

## 8. TSteamUserStats - achievements, stats and leaderboards

<img src="../design/icons/svg/TSteamUserStats.svg" width="48" height="48" alt="TSteamUserStats palette icon">

Unit `Steamworks.Plugin.UserStats`, interface `ISteamUserStats`. Builds on:
[call results](#44-three-ways-steam-answers) (leaderboards),
[images](#59-images-and-screenshots-steamimagetobitmap-steamformtorgb)
(icons), [TSteamUser](#7-tsteamuser---the-logged-on-user) (SteamIDs).

Since SDK 1.61 Steam loads the current user's stats and achievements by
itself at start-up: there is no `RequestCurrentStats` any more, and reading
works as soon as Steam runs.

**Spacewar (480)** defines these, which the examples use:

| Kind | API names |
|------|-----------|
| Stats (int) | `NumGames`, `NumWins`, `NumLosses` |
| Stats (float) | `FeetTraveled`, `MaxFeetTraveled` |
| Stat (average rate) | `AverageSpeed` |
| Achievements | `ACH_WIN_ONE_GAME`, `ACH_WIN_100_GAMES`, `ACH_TRAVEL_FAR_ACCUM`, `ACH_TRAVEL_FAR_SINGLE` |
| Leaderboards | `Quickest Win`, `Feet Traveled` |

The list in [8.2](#82-listing-every-achievement) prints whatever the app
really defines - run it first to see Spacewar's current set.

### 8.1 Unlocking an achievement

```pascal
procedure TForm1.PlayerWonFirstGame;
var
  Stats: TSteamUserStatsPlugin;
  Done: Boolean;
begin
  Stats := SteamUserStats1.Plugin;
  if (Stats <> nil) and Stats.GetAchievement(ACH_WIN_ONE_GAME, Done) and not Done then
  begin
    Stats.SetAchievement(ACH_WIN_ONE_GAME);     // changes the local copy only
    Stats.StoreStats;                           // uploads; Steam shows the pop-up
  end;
end;

procedure TForm1.SteamUserStats1UserAchievementStored(Sender: TObject;
  const AData: UserAchievementStored_t);
begin
  if (AData.m_nCurProgress = 0) and (AData.m_nMaxProgress = 0) then
    Log('Unlocked: ' + SteamText(@AData.m_rgchAchievementName[0]))
  else
    Log(Format('Progress %s: %d / %d', [SteamText(@AData.m_rgchAchievementName[0]),
      AData.m_nCurProgress, AData.m_nMaxProgress]));
end;

procedure TForm1.SteamUserStats1UserStatsStored(Sender: TObject;
  const AData: UserStatsStored_t);
begin
  if AData.m_eResult <> k_EResultOK then
    Log('StoreStats failed: ' + IntToStr(Ord(AData.m_eResult)));
end;
```

* `SetAchievement`, `SetStatInt32`, `SetStatFloat` change the **local**
  copy; nothing reaches Steam until `StoreStats`.
* Call `StoreStats` after a batch of changes (end of a match, a level),
  not after every change - Steam rate-limits it.
* `StoreStats` answers with `OnUserStatsStored`; each newly unlocked
  achievement also raises `OnUserAchievementStored`.

### 8.2 Listing every achievement

```pascal
procedure TForm1.ListAchievements;
var
  Stats: TSteamUserStatsPlugin;
  I: UInt32;
  Api, Name, Desc: string;
  Done, Hidden: Boolean;
  When: UInt32;
begin
  Stats := SteamUserStats1.Plugin;
  for I := 0 to Int64(Stats.GetNumAchievements) - 1 do
  begin
    Api := Stats.GetAchievementName(I);
    Name := Stats.GetAchievementDisplayAttribute(Api, 'name');     // localised
    Desc := Stats.GetAchievementDisplayAttribute(Api, 'desc');
    Hidden := Stats.GetAchievementDisplayAttribute(Api, 'hidden') = '1';
    Stats.GetAchievementAndUnlockTime(Api, Done, When);
    if Done then
      Log(Format('[x] %s - %s (unlocked %s)', [Name, Desc,
        DateTimeToStr(SteamTimeToLocal(When))]))
    else if Hidden then
      Log(Format('[ ] %s - (hidden)', [Name]))
    else
      Log(Format('[ ] %s - %s', [Name, Desc]));
  end;
end;
```

### 8.3 Stats

```pascal
procedure TForm1.MatchEnded(AWon: Boolean; AFeet: Single; ASeconds: Double);
var
  Stats: TSteamUserStatsPlugin;
  Games, Wins: Int32;
  TotalFeet, MaxFeet: Single;
begin
  Stats := SteamUserStats1.Plugin;
  Stats.GetStatInt32(STAT_NUM_GAMES, Games);
  Stats.SetStatInt32(STAT_NUM_GAMES, Games + 1);
  if AWon then
  begin
    Stats.GetStatInt32(STAT_NUM_WINS, Wins);
    Inc(Wins);
    Stats.SetStatInt32(STAT_NUM_WINS, Wins);
    if Wins = 1 then
      Stats.SetAchievement(ACH_WIN_ONE_GAME);
    if Wins >= WINS_FOR_100_GAMES then
      Stats.SetAchievement(ACH_WIN_100_GAMES)
    else if Wins mod PROGRESS_STEP = 0 then
      Stats.IndicateAchievementProgress(ACH_WIN_100_GAMES, Wins, WINS_FOR_100_GAMES);  // pop-up
  end
  else
  begin
    Stats.GetStatInt32(STAT_NUM_LOSSES, Games);
    Stats.SetStatInt32(STAT_NUM_LOSSES, Games + 1);
  end;

  Stats.GetStatFloat(STAT_FEET_TRAVELED, TotalFeet);
  Stats.SetStatFloat(STAT_FEET_TRAVELED, TotalFeet + AFeet);
  Stats.GetStatFloat(STAT_MAX_FEET_TRAVELED, MaxFeet);
  if AFeet > MaxFeet then
    Stats.SetStatFloat(STAT_MAX_FEET_TRAVELED, AFeet);

  // an AVGRATE stat: count this session, and how long the session was
  Stats.UpdateAvgRateStat(STAT_AVERAGE_SPEED, AFeet, ASeconds);

  Stats.StoreStats;                                 // one upload for everything
end;
```

* A stat's type (INT, FLOAT, AVGRATE) is set on the partner site; use the
  matching `...Int32` / `...Float` call or the call fails (returns
  `False`).
* Achievements tied to a stat on the partner site (for example
  `ACH_TRAVEL_FAR_ACCUM` to `FeetTraveled`) unlock by themselves when the
  stat crosses the threshold and `StoreStats` runs.
* `GetAchievementProgressLimitsInt32` / `...Float` read the min / max of a
  progress-linked achievement.

### 8.4 Leaderboards

All leaderboard calls are asynchronous: find the board, then upload or
download. Either handle the component events or pass a handler to the
`...Async` method. This example keeps the board handles once found:

```pascal
type
  TForm1 = class(TForm)
  private
    FQuickestWin: SteamLeaderboard_t;
    FPendingTime: Int32;
    procedure BoardFound(const AData: TSteamCallbackData; AIOFailure: Boolean);
    procedure TimeUploaded(const AData: TSteamCallbackData; AIOFailure: Boolean);
    procedure EntriesDownloaded(const AData: TSteamCallbackData; AIOFailure: Boolean);
  end;

procedure TForm1.SteamAPI1Initialized(Sender: TObject);
begin
  SteamUserStats1.Plugin.FindLeaderboardAsync(LB_QUICKEST_WIN, BoardFound);
end;

procedure TForm1.BoardFound(const AData: TSteamCallbackData; AIOFailure: Boolean);
var
  R: LeaderboardFindResult_t;
begin
  if AIOFailure or not AData.CopyTo(R, SizeOf(R)) or (R.m_bLeaderboardFound = 0) then
  begin
    Log('Leaderboard not found');
    Exit;
  end;
  FQuickestWin := R.m_hSteamLeaderboard;
  Log(Format('%s: %d entries', [SteamUserStats1.Plugin.GetLeaderboardName(FQuickestWin),
    SteamUserStats1.Plugin.GetLeaderboardEntryCount(FQuickestWin)]));
end;

// Upload: keep the best (here: lowest) time
procedure TForm1.SubmitWinTime(ASeconds: Int32);
begin
  if FQuickestWin = 0 then
    Exit;
  SteamUserStats1.Plugin.UploadLeaderboardScoreAsync(FQuickestWin,
    k_ELeaderboardUploadScoreMethodKeepBest, ASeconds, nil, 0, TimeUploaded);
end;

procedure TForm1.TimeUploaded(const AData: TSteamCallbackData; AIOFailure: Boolean);
var
  R: LeaderboardScoreUploaded_t;
begin
  if AIOFailure or not AData.CopyTo(R, SizeOf(R)) or (R.m_bSuccess = 0) then
    Exit;
  if R.m_bScoreChanged <> 0 then
    Log(Format('New best: %d s, rank %d (was %d)',
      [R.m_nScore, R.m_nGlobalRankNew, R.m_nGlobalRankPrevious]))
  else
    Log('Not better than your best time');
end;

// Download: the ten entries around the player
procedure TForm1.btnShowBoardClick(Sender: TObject);
begin
  SteamUserStats1.Plugin.DownloadLeaderboardEntriesAsync(FQuickestWin,
    k_ELeaderboardDataRequestGlobalAroundUser, -4, 5, EntriesDownloaded);
end;

procedure TForm1.EntriesDownloaded(const AData: TSteamCallbackData; AIOFailure: Boolean);
var
  R: LeaderboardScoresDownloaded_t;
  E: LeaderboardEntry_t;
  I: Integer;
begin
  if AIOFailure or not AData.CopyTo(R, SizeOf(R)) then
    Exit;
  lbBoard.Items.Clear;
  for I := 0 to R.m_cEntryCount - 1 do
    if SteamUserStats1.Plugin.GetDownloadedLeaderboardEntry(R.m_hSteamLeaderboardEntries,
         I, E, nil, 0) then
      lbBoard.Items.Add(Format('#%d  %s  %d s', [E.m_nGlobalRank,
        SteamFriends1.Plugin.GetFriendPersonaName(E.m_steamIDUser), E.m_nScore]));
end;
```

* Request kinds: `k_ELeaderboardDataRequestGlobal` (ranks `Start..End`),
  `k_ELeaderboardDataRequestGlobalAroundUser` (offsets around the player),
  `k_ELeaderboardDataRequestFriends` (all friends; range ignored).
  `DownloadLeaderboardEntriesForUsers` takes an array of `TSteamID`.
* Downloaded entries stay valid only until the next download of that board.
* Names of players who are not friends may arrive later: call
  `TSteamFriends.RequestUserInformation(Id, True)` and refresh on
  `OnPersonaStateChange` ([chapter 10](#10-tsteamfriends---friends-avatars-overlay-rich-presence)).
* `FindOrCreateLeaderboard(Name, SortMethod, DisplayType)` creates a board
  that does not exist yet - for example
  `FindOrCreateLeaderboardAsync('Manual Test', k_ELeaderboardSortMethodDescending,
  k_ELeaderboardDisplayTypeNumeric, BoardFound)`. On 480 every developer
  shares the boards; use a name unique to you.
* Up to 64 extra `Int32` "details" per entry: pass `@Details[0], Count` to
  `UploadLeaderboardScore` and read them back with
  `GetDownloadedLeaderboardEntry(..., @Details[0], Length(Details))`.
* `AttachLeaderboardUGC` attaches a Steam Cloud file shared with
  `TSteamRemoteStorage.FileShare` (a replay) to the player's entry.

### 8.5 Other users and global data

```pascal
// a friend's stats, e.g. for a comparison screen
SteamUserStats1.Plugin.RequestUserStats(FriendID);              // -> OnUserStatsReceived

procedure TForm1.SteamUserStats1UserStatsReceived(Sender: TObject;
  const AData: UserStatsReceived_t);
var
  Wins: Int32;
begin
  if (AData.m_eResult = k_EResultOK) and
     SteamUserStats1.Plugin.GetUserStatInt32(AData.m_steamIDUser, STAT_NUM_WINS, Wins) then
    Log(Format('%s has %d wins', [AData.m_steamIDUser.ToString, Wins]));
end;

// how rare each achievement is
SteamUserStats1.Plugin.RequestGlobalAchievementPercentages;     // -> OnGlobalAchievementPercentagesReady

procedure TForm1.SteamUserStats1GlobalAchievementPercentagesReady(Sender: TObject;
  const AData: GlobalAchievementPercentagesReady_t);
var
  Pct: Single;
begin
  if SteamUserStats1.Plugin.GetAchievementAchievedPercent(ACH_WIN_ONE_GAME, Pct) then
    Log(Format('%.1f %% of players won a game', [Pct]));
end;
```

`RequestGlobalStats(Days)` and `GetGlobalStatInt64` / `GetGlobalStatDouble`
read global aggregated stats (they must be marked "aggregated" on the
partner site). `GetNumberOfCurrentPlayers` needs no setup - see the call
result example in [4.4](#44-three-ways-steam-answers).

### 8.6 Achievement icons

```pascal
procedure TForm1.ShowIcon(const AApiName: string);
var
  H: Integer;
begin
  H := SteamUserStats1.Plugin.GetAchievementIcon(AApiName);
  if H > 0 then
    SteamImageToBitmap(H, imgIcon.Bitmap);
  // 0: not loaded yet (OnUserAchievementIconFetched follows) OR no icon at all
end;

procedure TForm1.SteamUserStats1UserAchievementIconFetched(Sender: TObject;
  const AData: UserAchievementIconFetched_t);
begin
  if AData.m_nIconHandle > 0 then
    SteamImageToBitmap(AData.m_nIconHandle, imgIcon.Bitmap);
end;
```

After changing icons on the partner site: publish, then **restart the Steam
client** - it caches achievement data, including "no icon".

### 8.7 Resetting while testing

```pascal
SteamUserStats1.Plugin.ClearAchievement(ACH_WIN_ONE_GAME);     // one achievement
SteamUserStats1.Plugin.ResetAllStats(True);                     // everything, achievements too
SteamUserStats1.Plugin.StoreStats;
```

These change your account's Spacewar progress only. Never ship them in a
user-reachable path.

### 8.8 Events

| Event | When |
|-------|------|
| `OnUserStatsReceived` | Stats of a user (`RequestUserStats`) arrived. |
| `OnUserStatsStored` | `StoreStats` finished (`m_eResult`). |
| `OnUserAchievementStored` | An achievement was unlocked or progress indicated. |
| `OnLeaderboardFindResult` | `FindLeaderboard` / `FindOrCreateLeaderboard` answered. |
| `OnLeaderboardScoreUploaded` | `UploadLeaderboardScore` answered. |
| `OnLeaderboardScoresDownloaded` | `DownloadLeaderboardEntries...` answered. |
| `OnLeaderboardUGCSet` | `AttachLeaderboardUGC` answered. |
| `OnNumberOfCurrentPlayers` | `GetNumberOfCurrentPlayers` answered. |
| `OnGlobalAchievementPercentagesReady` / `OnGlobalStatsReceived` | Global data loaded. |
| `OnUserAchievementIconFetched` | An icon handle is ready. |
| `OnUserStatsUnloaded` | Another user's stats were dropped; request them again. |

---

## 9. TSteamRemoteStorage - Steam Cloud saves

<img src="../design/icons/svg/TSteamRemoteStorage.svg" width="48" height="48" alt="TSteamRemoteStorage palette icon">

Unit `Steamworks.Plugin.RemoteStorage`, interface `ISteamRemoteStorage`.
Per-user files that Steam keeps in step across the user's machines. Steam
Cloud must be enabled for the AppID, with a byte / file quota, on the
partner site; until then writes fail. For Spacewar the quota is Valve's -
`GetQuota` tells you how much room there is.

### 9.1 Is the Cloud available?

```pascal
function TForm1.CloudReady: Boolean;
var
  Total, Avail: UInt64;
begin
  Result := (SteamRemoteStorage1.Plugin <> nil)
    and SteamRemoteStorage1.Plugin.IsCloudEnabledForAccount   // user setting
    and SteamRemoteStorage1.Plugin.IsCloudEnabledForApp;      // per-game user setting
  if Result and SteamRemoteStorage1.Plugin.GetQuota(Total, Avail) then
    Log(Format('Cloud: %d of %d bytes free', [Int64(Avail), Int64(Total)]));
end;
```

### 9.2 Writing and reading a save

```pascal
procedure TForm1.SaveToCloud(const AJson: string);
var
  Data: TBytes;
begin
  if not CloudReady then
    Exit;                                         // keep the local save only
  Data := TEncoding.UTF8.GetBytes(AJson);
  if not SteamRemoteStorage1.Plugin.FileWrite('spacewar_manual.json', @Data[0], Length(Data)) then
    Log('Cloud write failed (quota? Cloud off for the app?)');
end;

function TForm1.LoadFromCloud: string;
var
  RS: TSteamRemoteStoragePlugin;
  Data: TBytes;
  Size: Int32;
begin
  Result := '';
  RS := SteamRemoteStorage1.Plugin;
  if not RS.FileExists('spacewar_manual.json') then
    Exit;
  Size := RS.GetFileSize('spacewar_manual.json');
  SetLength(Data, Size);
  if (Size > 0) and (RS.FileRead('spacewar_manual.json', @Data[0], Size) = Size) then
    Result := TEncoding.UTF8.GetString(Data);
end;
```

* `FileWrite` / `FileRead` are synchronous and local; Steam uploads in the
  background. One write may not exceed 100 MB; for larger files use
  `FileWriteStreamOpen` / `FileWriteStreamWriteChunk` /
  `FileWriteStreamClose`.
* A save made of several files: wrap the writes in
  `BeginFileWriteBatch` / `EndFileWriteBatch` so Steam treats them as one
  change.
* `FileDelete` removes a file everywhere; `FileForget` only from the cloud
  (the local copy stays).
* File names are per app and per user; there are no folders, but a name may
  contain `/`.

### 9.3 Listing the files

```pascal
procedure TForm1.ListCloudFiles;
var
  RS: TSteamRemoteStoragePlugin;
  I: Integer;
  Size: Int32;
  Name: string;
begin
  RS := SteamRemoteStorage1.Plugin;
  for I := 0 to RS.GetFileCount - 1 do
  begin
    Name := RS.GetFileNameAndSize(I, Size);
    Log(Format('%-30s %8d bytes  %s  persisted: %s', [Name, Size,
      DateTimeToStr(SteamTimeToLocal(RS.GetFileTimestamp(Name))),
      BoolToStr(RS.FilePersisted(Name), True)]));
  end;
end;
```

### 9.4 Asynchronous reads and writes

Valve's `FileWriteAsync` / `FileReadAsync` already end in "Async", so the
variants that take a handler are **overloads** of the same names. A read
completes in two steps: the result says how much was read, then
`FileReadAsyncComplete` copies it into your buffer.

```pascal
procedure TForm1.LoadAsync;
var
  RS: TSteamRemoteStoragePlugin;
begin
  RS := SteamRemoteStorage1.Plugin;
  RS.FileReadAsync('spacewar_manual.json', 0, RS.GetFileSize('spacewar_manual.json'), SaveRead);
end;

procedure TForm1.SaveRead(const AData: TSteamCallbackData; AIOFailure: Boolean);
var
  R: RemoteStorageFileReadAsyncComplete_t;
  Buf: TBytes;
begin
  if AIOFailure or not AData.CopyTo(R, SizeOf(R)) or (R.m_eResult <> k_EResultOK) then
    Exit;
  SetLength(Buf, R.m_cubRead);
  if (R.m_cubRead > 0) and
     SteamRemoteStorage1.Plugin.FileReadAsyncComplete(R.m_hFileReadAsync, @Buf[0], R.m_cubRead) then
    ApplySave(TEncoding.UTF8.GetString(Buf));
end;

procedure TForm1.SaveAsync(const AJson: string);
var
  Data: TBytes;
begin
  Data := TEncoding.UTF8.GetBytes(AJson);         // Steam copies it during the call
  SteamRemoteStorage1.Plugin.FileWriteAsync('spacewar_manual.json', @Data[0], Length(Data),
    SaveWritten);
end;

procedure TForm1.SaveWritten(const AData: TSteamCallbackData; AIOFailure: Boolean);
var
  R: RemoteStorageFileWriteAsyncComplete_t;
begin
  if (not AIOFailure) and AData.CopyTo(R, SizeOf(R)) and (R.m_eResult = k_EResultOK) then
    Log('Saved to Steam Cloud');
end;
```

### 9.5 Files changed by another machine

When Steam syncs files while the game runs (the player also plays on
another PC), `OnRemoteStorageLocalFileChange` fires:

```pascal
procedure TForm1.SteamRemoteStorage1RemoteStorageLocalFileChange(Sender: TObject;
  const AData: RemoteStorageLocalFileChange_t);
var
  I: Integer;
  Change: ERemoteStorageLocalFileChange;
  PathType: ERemoteStorageFilePathType;
  Name: string;
begin
  for I := 0 to SteamRemoteStorage1.Plugin.GetLocalFileChangeCount - 1 do
  begin
    Name := SteamRemoteStorage1.Plugin.GetLocalFileChange(I, Change, PathType);
    Log('Cloud changed: ' + Name);
  end;
  ApplySave(LoadFromCloud);
end;
```

### 9.6 Sharing a file (for leaderboards)

`FileShareAsync(Name, Handler)` returns, in `RemoteStorageFileShareResult_t`,
a `UGCHandle_t` that `TSteamUserStats.AttachLeaderboardUGC` attaches to a
leaderboard entry (a replay, a ghost car). Others download it with
`UGCDownload` and `UGCRead`.

### 9.7 The old Workshop calls

`PublishWorkshopFile`, `EnumerateUserPublishedFiles`,
`SubscribePublishedFile` and the other publish / enumerate / vote calls of
this interface are Valve's first Workshop API, kept for old games. New code
uses [TSteamUGC](#14-tsteamugc---steam-workshop). Their
`SteamParamStringArray_t` parameters are `var`; for "no tags" pass a zeroed
record.

### 9.8 Events

The component has 25 events. The ones a save system uses:

| Event | When |
|-------|------|
| `OnRemoteStorageFileWriteAsyncComplete` | `FileWriteAsync` finished. |
| `OnRemoteStorageFileReadAsyncComplete` | `FileReadAsync` finished. |
| `OnRemoteStorageLocalFileChange` | Steam changed local files while running. |
| `OnRemoteStorageFileShareResult` | `FileShare` finished. |
| `OnRemoteStorageDownloadUGCResult` | `UGCDownload` finished. |

The other events belong to the old Workshop API; see
[components/TSteamRemoteStorage.md](components/TSteamRemoteStorage.md).

---

## 10. TSteamFriends - friends, avatars, overlay, rich presence

<img src="../design/icons/svg/TSteamFriends.svg" width="48" height="48" alt="TSteamFriends palette icon">

Unit `Steamworks.Plugin.Friends`, interface `ISteamFriends`. Builds on:
[images](#59-images-and-screenshots-steamimagetobitmap-steamformtorgb),
[TSteamUtils](#6-tsteamutils---client-utilities) (`IsOverlayEnabled`),
[TSteamUser](#7-tsteamuser---the-logged-on-user) (`GetSteamID`).

### 10.1 Persona and friends list

```pascal
procedure TForm1.FillFriends;
var
  F: TSteamFriendsPlugin;
  I: Integer;
  Id: TSteamID;
  Info: FriendGameInfo_t;
  State: string;
begin
  F := SteamFriends1.Plugin;
  Caption := 'Spacewar - ' + F.GetPersonaName;
  lbFriends.Items.Clear;
  for I := 0 to F.GetFriendCount(k_EFriendFlagImmediate) - 1 do
  begin
    Id := F.GetFriendByIndex(I, k_EFriendFlagImmediate);    // same flags as GetFriendCount
    if F.GetFriendGamePlayed(Id, Info) then
      State := 'in game'
    else if F.GetFriendPersonaState(Id) = k_EPersonaStateOffline then
      State := 'offline'
    else
      State := 'online';
    lbFriends.Items.Add(Format('%s (%s, level %d)',
      [F.GetFriendPersonaName(Id), State, F.GetFriendSteamLevel(Id)]));
  end;
end;

procedure TForm1.SteamFriends1PersonaStateChange(Sender: TObject;
  const AData: PersonaStateChange_t);
begin
  // m_nChangeFlags says what changed (k_EPersonaChangeName, ...Status, ...Avatar, ...)
  if AData.m_nChangeFlags and (k_EPersonaChangeName or k_EPersonaChangeStatus) <> 0 then
    FillFriends;
  if AData.m_nChangeFlags and k_EPersonaChangeAvatar <> 0 then
    UpdateAvatar(TSteamID.Create(AData.m_ulSteamID));
end;
```

* Persona names are UTF-8 in Steam and arrive as `string`.
* `OnPersonaStateChange` also fires for your own SteamID at start-up.
* `RequestUserInformation(SteamID, False)` fetches name **and** avatar of a
  user who is not a friend (a leaderboard entry, a lobby member);
  `OnPersonaStateChange` follows. It returns `False` when the data is
  already there.
* `GetPlayerNickname` is the nickname *you* gave that player.
* Groups: `GetFriendsGroupCount`, `GetFriendsGroupName`; clans:
  `GetClanCount`, `GetClanName`, `GetClanTag`.

### 10.2 Avatars

```pascal
procedure TForm1.UpdateAvatar(const AId: TSteamID);
var
  H: Integer;
begin
  H := SteamFriends1.Plugin.GetMediumFriendAvatar(AId);   // 64 px; Small 32, Large 184
  case H of
    -1: ;                                  // downloading - OnAvatarImageLoaded follows
     0: imgAvatar.Bitmap.Clear(TAlphaColors.Null);        // no avatar set
  else
    SteamImageToBitmap(H, imgAvatar.Bitmap);
  end;
end;

procedure TForm1.SteamFriends1AvatarImageLoaded(Sender: TObject;
  const AData: AvatarImageLoaded_t);
begin
  if AData.m_steamID = SteamUser1.Plugin.GetSteamID then
    SteamImageToBitmap(AData.m_iImage, imgAvatar.Bitmap);
end;
```

### 10.3 The Steam overlay

```pascal
// pages
SteamFriends1.Plugin.ActivateGameOverlay('Friends');       // also Community, Players,
                                                           // Settings, OfficialGameGroup,
                                                           // Stats, Achievements
// a user's profile / chat / trade
SteamFriends1.Plugin.ActivateGameOverlayToUser('steamid', FriendID);
SteamFriends1.Plugin.ActivateGameOverlayToUser('chat', FriendID);
// a web page in the overlay browser
SteamFriends1.Plugin.ActivateGameOverlayToWebPage(
  Format(COMMUNITY_APP_URL, [SteamAPI1.AppID]), k_EActivateGameOverlayToWebPageMode_Default);
// the store page (your DLC's AppID in a real game)
SteamFriends1.Plugin.ActivateGameOverlayToStore(SteamAPI1.AppID, k_EOverlayToStoreFlag_None);
```

The overlay appears only when the game was started by Steam (or with the
overlay injected) and renders with a supported graphics API. Check first:

```pascal
if not SteamUtils1.Plugin.IsOverlayEnabled then
  OpenURL(Format(COMMUNITY_APP_URL, [SteamAPI1.AppID]))   // your own fallback
else
  SteamFriends1.Plugin.ActivateGameOverlayToWebPage(Format(COMMUNITY_APP_URL, [SteamAPI1.AppID]),
    k_EActivateGameOverlayToWebPageMode_Default);
```

Pause a single-player game while the overlay is open:

```pascal
procedure TForm1.SteamFriends1GameOverlayActivated(Sender: TObject;
  const AData: GameOverlayActivated_t);
begin
  GamePaused := AData.m_bActive <> 0;
end;
```

### 10.4 Rich presence and "Join game"

Rich presence is the text friends see under your name, and the `connect`
key makes **Join game** possible:

```pascal
procedure TForm1.EnteredArena(const AArena: string; const AServerAddr: string);
begin
  SteamFriends1.Plugin.SetRichPresence('status', 'Fighting in ' + AArena);
  SteamFriends1.Plugin.SetRichPresence('connect', '+connect ' + AServerAddr);
end;

procedure TForm1.BackToMenu;
begin
  SteamFriends1.Plugin.ClearRichPresence;
end;

// A friend chose "Join game" (from the Steam friends list, while this game runs):
procedure TForm1.SteamFriends1GameRichPresenceJoinRequested(Sender: TObject;
  const AData: GameRichPresenceJoinRequested_t);
begin
  ConnectTo(SteamText(@AData.m_rgchConnect[0]));    // '+connect 1.2.3.4:27015'
end;
```

* If the game was **not** running, Steam starts it with the connect string
  on the command line - parse `ParamStr` at start-up too.
* `steam_display` with localisation tokens (set up on the partner site)
  controls the formatted text in the friends list; on 480 the tokens are
  Valve's, so use `status` for experiments.
* `GetFriendRichPresence(FriendID, 'status')` reads a friend's value;
  `RequestFriendRichPresence` refreshes it (`OnFriendRichPresenceUpdate`).
* `InviteUserToGame(FriendID, '+connect ...')` sends an invite with a
  connect string.

### 10.5 Lobby invites through Friends

When a friend invites the player to a lobby
([chapter 12](#12-tsteammatchmaking---lobbies)) and the player accepts in
the Steam UI, `OnGameLobbyJoinRequested` fires:

```pascal
procedure TForm1.SteamFriends1GameLobbyJoinRequested(Sender: TObject;
  const AData: GameLobbyJoinRequested_t);
begin
  SteamMatchmaking1.Plugin.JoinLobby(AData.m_steamIDLobby);   // -> OnLobbyEnter
end;
```

`ActivateGameOverlayInviteDialog(LobbyID)` opens Steam's own invite dialog
for a lobby you are in.

### 10.6 Events

| Event | When |
|-------|------|
| `OnPersonaStateChange` | A user's name, status, avatar or game changed. |
| `OnAvatarImageLoaded` | A requested avatar finished downloading. |
| `OnGameOverlayActivated` | The overlay opened / closed. |
| `OnGameRichPresenceJoinRequested` | A friend chose "Join game". |
| `OnGameLobbyJoinRequested` | The player accepted a lobby invite. |
| `OnGameServerChangeRequested` | The player chose a server to join in the Steam UI. |
| `OnFriendRichPresenceUpdate` | A friend's rich presence changed. |
| `OnClanOfficerListResponse`, `OnDownloadClanActivityCountsResult`, `OnJoinClanChatRoomCompletionResult`, `OnGameConnectedClanChatMsg`, `OnGameConnectedChatJoin`, `OnGameConnectedChatLeave`, `OnGameConnectedFriendChatMsg` | Groups and chats. |
| `OnFriendsGetFollowerCount`, `OnFriendsIsFollowing`, `OnFriendsEnumerateFollowingList` | Followers. |
| `OnUnreadChatMessagesChanged`, `OnOverlayBrowserProtocolNavigation`, `OnEquippedProfileItemsChanged`, `OnEquippedProfileItems` | Miscellaneous. |

---

## 11. TSteamApps - ownership, DLC, language, betas

<img src="../design/icons/svg/TSteamApps.svg" width="48" height="48" alt="TSteamApps palette icon">

Unit `Steamworks.Plugin.Apps`, interface `ISteamApps`.

### 11.1 Ownership and DLC

```pascal
procedure TForm1.CheckOwnership;
var
  A: TSteamAppsPlugin;
  I: Integer;
  DlcID: AppId_t;
  Available: Boolean;
  Name: array[0..255] of AnsiChar;
begin
  A := SteamApps1.Plugin;
  if not A.BIsSubscribed then
    Log('Not owned (should not happen when started through Steam)');
  if A.BIsSubscribedFromFamilySharing then
    Log('Borrowed through Family Sharing from ' + A.GetAppOwner.ToString);

  for I := 0 to A.GetDLCCount - 1 do
    if A.BGetDLCDataByIndex(I, DlcID, Available, @Name[0], SizeOf(Name)) then
      Log(Format('DLC %d "%s": %s', [DlcID, SteamText(@Name[0]),
        IfThen(A.BIsDlcInstalled(DlcID), 'installed', 'not installed')]));
end;

procedure TForm1.SteamApps1DlcInstalled(Sender: TObject; const AData: DlcInstalled_t);
begin
  Log(Format('DLC %d finished installing - enabling it', [AData.m_nAppID]));
  EnableExpansion(AData.m_nAppID);
end;
```

(`IfThen` for strings is in `System.StrUtils` / `StrUtils`.)

* `BIsDlcInstalled(AppID)` is the check to use in the game: `True` only
  when the DLC is owned **and** installed.
* `InstallDLC` / `UninstallDLC` ask Steam to (un)install one;
  `GetDlcDownloadProgress` reports the download.
* `BIsSubscribedFromFreeWeekend`, `BIsTimedTrial(Allowed, Played)`,
  `BIsLowViolence`, `BIsVACBanned`, `BIsCybercafe` refine how the game is
  owned. `OnTimedTrialStatus` reports trial time changes.
* `BIsSubscribedApp(OtherAppID)` / `BIsAppInstalled(OtherAppID)` check
  other apps (a prequel bonus).

### 11.2 Language

```pascal
procedure TForm1.SteamAPI1Initialized(Sender: TObject);
var
  Lang: string;
begin
  Lang := SteamApps1.Plugin.GetCurrentGameLanguage;    // 'english', 'german', 'schinese', ...
  LoadTranslations(Lang);
  Log('Supported: ' + SteamApps1.Plugin.GetAvailableGameLanguages);  // comma-separated
end;
```

`GetCurrentGameLanguage` is the language chosen for **this game** in Steam -
use it for your text. `TSteamUtils.GetSteamUILanguage` is the client's
language.

### 11.3 Launch parameters

```pascal
// steam://run/480//?map=arena2   or   steam://run/480//-windowed
procedure TForm1.ReadLaunchParameters;
var
  Buf: array[0..1023] of AnsiChar;
  Map: string;
begin
  Map := SteamApps1.Plugin.GetLaunchQueryParam('map');
  if Map <> '' then
    StartOnMap(Map);
  if SteamApps1.Plugin.GetLaunchCommandLine(@Buf[0], SizeOf(Buf)) > 0 then
    Log('Command line through Steam: ' + SteamText(@Buf[0]));
end;

// the game was "launched" again while running (another steam://run link)
procedure TForm1.SteamApps1NewUrlLaunchParameters(Sender: TObject;
  const AData: NewUrlLaunchParameters_t);
begin
  ReadLaunchParameters;
end;
```

### 11.4 Install folder, build, betas

```pascal
var
  Buf: array[0..1023] of AnsiChar;
  Avail, Priv: Integer;
begin
  if SteamApps1.Plugin.GetAppInstallDir(SteamAPI1.AppID, @Buf[0], SizeOf(Buf)) > 0 then
    Log('Installed in ' + SteamText(@Buf[0]));
  Log(Format('Build %d', [SteamApps1.Plugin.GetAppBuildId]));
  if SteamApps1.Plugin.GetCurrentBetaName(@Buf[0], SizeOf(Buf)) then
    Log('Beta branch: ' + SteamText(@Buf[0]));
  Log(Format('%d betas (%d available, %d private)',
    [SteamApps1.Plugin.GetNumBetas(Avail, Priv), Avail, Priv]));
end;
```

`GetBetaInfo` / `SetActiveBeta` list and switch branches;
`MarkContentCorrupt(False)` asks Steam to verify the files on the next
launch. `GetAppInstallDir` for 480 only answers if Spacewar is installed;
for your own AppID it is the game's folder.

### 11.5 Events

| Event | When |
|-------|------|
| `OnDlcInstalled` | A DLC finished installing while the game runs. |
| `OnNewUrlLaunchParameters` | New launch parameters arrived while running. |
| `OnTimedTrialStatus` | Trial time changed. |
| `OnFileDetailsResult` | `GetFileDetails` answered (size / hash of a game file). |
| `OnAppProofOfPurchaseKeyResponse` | A CD key request answered. |

---

## 12. TSteamMatchmaking - lobbies

<img src="../design/icons/svg/TSteamMatchmaking.svg" width="48" height="48" alt="TSteamMatchmaking palette icon">

Unit `Steamworks.Plugin.Matchmaking`, interface `ISteamMatchmaking`. Lobbies
are rooms where players gather before a game: find, create, join, chat and
share key / value data. Every lobby is a `TSteamID`. Builds on:
[TSteamFriends](#10-tsteamfriends---friends-avatars-overlay-rich-presence)
(invites, names).

> **On AppID 480 you share the lobby list with every developer testing
> Spacewar.** Always tag your lobbies with a key nobody else uses and
> filter on it, as below.

### 12.1 Find or create a lobby

```pascal
const
  LOBBY_TAG = 'tsapi_manual';            // unique to you on AppID 480

procedure TForm1.btnQuickMatchClick(Sender: TObject);
var
  MM: TSteamMatchmakingPlugin;
begin
  MM := SteamMatchmaking1.Plugin;
  // filters apply to the NEXT RequestLobbyList only
  MM.AddRequestLobbyListStringFilter(LOBBY_TAG, '1', k_ELobbyComparisonEqual);
  MM.AddRequestLobbyListStringFilter('mode', 'coop', k_ELobbyComparisonEqual);
  MM.AddRequestLobbyListFilterSlotsAvailable(1);
  MM.AddRequestLobbyListDistanceFilter(k_ELobbyDistanceFilterWorldwide);
  MM.AddRequestLobbyListResultCountFilter(20);
  MM.RequestLobbyListAsync(LobbiesListed);           // the handler gets the list once
end;

procedure TForm1.LobbiesListed(const AData: TSteamCallbackData; AIOFailure: Boolean);
var
  R: LobbyMatchList_t;
begin
  if AIOFailure or not AData.CopyTo(R, SizeOf(R)) then
    Exit;
  if R.m_nLobbiesMatching = 0 then
    SteamMatchmaking1.Plugin.CreateLobby(k_ELobbyTypePublic, 4)        // -> OnLobbyCreated
  else
    SteamMatchmaking1.Plugin.JoinLobby(SteamMatchmaking1.Plugin.GetLobbyByIndex(0)); // -> OnLobbyEnter
end;

procedure TForm1.SteamMatchmaking1LobbyCreated(Sender: TObject;
  const AData: LobbyCreated_t);
var
  Lobby: TSteamID;
begin
  if AData.m_eResult <> k_EResultOK then
    Exit;
  Lobby := TSteamID.Create(AData.m_ulSteamIDLobby);
  SteamMatchmaking1.Plugin.SetLobbyData(Lobby, LOBBY_TAG, '1');
  SteamMatchmaking1.Plugin.SetLobbyData(Lobby, 'mode', 'coop');
  SteamMatchmaking1.Plugin.SetLobbyData(Lobby, 'map', 'arena1');
end;

procedure TForm1.SteamMatchmaking1LobbyEnter(Sender: TObject; const AData: LobbyEnter_t);
var
  MM: TSteamMatchmakingPlugin;
  I: Integer;
begin
  FLobby := TSteamID.Create(AData.m_ulSteamIDLobby);
  MM := SteamMatchmaking1.Plugin;
  Log(Format('In lobby %s, owner %s, map %s', [FLobby.ToString,
    SteamFriends1.Plugin.GetFriendPersonaName(MM.GetLobbyOwner(FLobby)),
    MM.GetLobbyData(FLobby, 'map')]));
  for I := 0 to MM.GetNumLobbyMembers(FLobby) - 1 do
    Log('  member: ' + SteamFriends1.Plugin.GetFriendPersonaName(
      MM.GetLobbyMemberByIndex(FLobby, I)));
end;
```

* **`OnLobbyMatchList` fires twice per plain `RequestLobbyList`**: Steam
  posts `LobbyMatchList_t` both as the call result and as an ordinary
  callback. Use `RequestLobbyListAsync` (as above), whose handler gets it
  once, or ignore the second list.
* The creator of a lobby gets `OnLobbyCreated` **and** `OnLobbyEnter`.
* Lobby ids arrive as `UInt64` in the events; wrap them with
  `TSteamID.Create`.
* Lobby types: `k_ELobbyTypePublic`, `k_ELobbyTypeFriendsOnly`,
  `k_ELobbyTypePrivate` (invite only), `k_ELobbyTypeInvisible`.
* Other filters: `AddRequestLobbyListNumericalFilter`,
  `AddRequestLobbyListNearValueFilter` (sort by closeness, e.g. skill).

### 12.2 Members and chat

```pascal
procedure TForm1.SteamMatchmaking1LobbyChatUpdate(Sender: TObject;
  const AData: LobbyChatUpdate_t);
var
  Who: string;
begin
  Who := SteamFriends1.Plugin.GetFriendPersonaName(TSteamID.Create(AData.m_ulSteamIDUserChanged));
  if AData.m_rgfChatMemberStateChange and k_EChatMemberStateChangeEntered <> 0 then
    Log(Who + ' joined')
  else
    Log(Who + ' left');                  // left, disconnected, kicked or banned
end;

procedure TForm1.SendChat(const AText: string);
var
  Data: TBytes;
begin
  Data := TEncoding.UTF8.GetBytes(AText + #0);
  SteamMatchmaking1.Plugin.SendLobbyChatMsg(FLobby, @Data[0], Length(Data));
end;

procedure TForm1.SteamMatchmaking1LobbyChatMsg(Sender: TObject; const AData: LobbyChatMsg_t);
var
  From: TSteamID;
  Buf: array[0..4095] of AnsiChar;
  Kind: EChatEntryType;
  Len: Integer;
begin
  Len := SteamMatchmaking1.Plugin.GetLobbyChatEntry(TSteamID.Create(AData.m_ulSteamIDLobby),
    AData.m_iChatID, From, @Buf[0], SizeOf(Buf), Kind);
  if (Len > 0) and (Kind = k_EChatEntryTypeChatMsg) then
    Log(SteamFriends1.Plugin.GetFriendPersonaName(From) + ': ' + SteamText(@Buf[0]));
end;
```

Lobby chat messages are raw bytes; the example sends UTF-8 text with a
closing zero. You can send any binary game data the same way (up to 4 KB).

### 12.3 Lobby and member data

```pascal
// owner: change lobby data (everyone gets OnLobbyDataUpdate)
SteamMatchmaking1.Plugin.SetLobbyData(FLobby, 'map', 'arena2');
// every member: own data, e.g. ready state / chosen ship
SteamMatchmaking1.Plugin.SetLobbyMemberData(FLobby, 'ready', '1');

procedure TForm1.SteamMatchmaking1LobbyDataUpdate(Sender: TObject;
  const AData: LobbyDataUpdate_t);
var
  Member: TSteamID;
begin
  Member := TSteamID.Create(AData.m_ulSteamIDMember);
  if AData.m_ulSteamIDMember = AData.m_ulSteamIDLobby then
    Log('Lobby data changed: map = ' + SteamMatchmaking1.Plugin.GetLobbyData(FLobby, 'map'))
  else
    Log(Format('%s ready: %s', [SteamFriends1.Plugin.GetFriendPersonaName(Member),
      SteamMatchmaking1.Plugin.GetLobbyMemberData(FLobby, Member, 'ready')]));
end;
```

* Only the owner can set lobby data, change the type, member limit or
  joinability (`SetLobbyType`, `SetLobbyMemberLimit`, `SetLobbyJoinable`),
  or hand over ownership (`SetLobbyOwner`).
* `GetLobbyDataCount` / `GetLobbyDataByIndex` enumerate all keys.
* `RequestLobbyData(LobbyID)` loads the data of a lobby you are not in
  (for a lobby browser).

### 12.4 Starting the game

When everybody is ready, the owner announces the game server (or its own
SteamID for peer-to-peer):

```pascal
// owner
SteamMatchmaking1.Plugin.SetLobbyGameServer(FLobby, 0, 0, SteamUser1.Plugin.GetSteamID);

// everyone, including the owner
procedure TForm1.SteamMatchmaking1LobbyGameCreated(Sender: TObject;
  const AData: LobbyGameCreated_t);
begin
  StartPeerToPeerGame(TSteamID.Create(AData.m_ulSteamIDGameServer));  // chapter 13
end;
```

For a dedicated server pass its IP and port (and its SteamID). Players
receive `OnLobbyGameCreated` and connect.

### 12.5 Invites and leaving

```pascal
SteamFriends1.Plugin.ActivateGameOverlayInviteDialog(FLobby);   // Steam's invite UI
SteamMatchmaking1.Plugin.InviteUserToLobby(FLobby, FriendID);   // direct invite
...
SteamMatchmaking1.Plugin.LeaveLobby(FLobby);                    // always leave
```

An invited player who accepts in Steam gets
`TSteamFriends.OnGameLobbyJoinRequested` ([10.5](#105-lobby-invites-through-friends));
a player in the game gets `OnLobbyInvite` here. Leave lobbies with
`LeaveLobby` - otherwise Steam keeps the user in them until the program
ends.

### 12.6 Favourite servers

`GetFavoriteGameCount`, `GetFavoriteGame`, `AddFavoriteGame`,
`RemoveFavoriteGame` manage the user's favourite and history game servers
(used together with the [server browser](#31-tsteammatchmakingservers---the-server-browser)).

### 12.7 Events

| Event | When |
|-------|------|
| `OnLobbyMatchList` | `RequestLobbyList` answered (twice - see above). |
| `OnLobbyCreated` | `CreateLobby` answered. |
| `OnLobbyEnter` | You entered a lobby (created or joined). |
| `OnLobbyChatUpdate` | A member joined / left. |
| `OnLobbyChatMsg` | A chat message is waiting. |
| `OnLobbyDataUpdate` | Lobby or member data changed. |
| `OnLobbyGameCreated` | The owner set the game server. |
| `OnLobbyInvite` | Someone invited you (while in game). |
| `OnLobbyKicked` | You were removed from a lobby. |
| `OnFavoritesListChanged`, `OnFavoritesListAccountsUpdated` | Favourite servers changed. |

---

## 13. Networking

Steam offers three networking interfaces. This chapter describes the
shared pieces first, then the two modern interfaces. The deprecated old
P2P API is in [chapter 26](#26-tsteamnetworking---the-old-p2p-api-deprecated).

| Interface | Component | Use it for |
|-----------|-----------|------------|
| ISteamNetworkingUtils | `TSteamNetworkingUtils` | Relay network start-up and status, ping data, settings. **Needed by the other two.** |
| ISteamNetworkingMessages | `TSteamNetworkingMessages` | Messages to a Steam user, no connection to manage. Simplest P2P. |
| ISteamNetworkingSockets | `TSteamNetworkingSockets` | Connections: P2P through Steam's relay or by IP, with listen sockets, poll groups, lanes. |

### 13.1 Shared records

Both data interfaces identify peers with `SteamNetworkingIdentity` and hand
over received data as `SteamNetworkingMessage_t`. Both contain C unions and
are hand-written variant records whose field offsets are verified against
the C headers on every platform.

A helper used in the rest of this chapter (not part of the library):

```pascal
function SteamIdentity(const AId: TSteamID): SteamNetworkingIdentity;
begin
  FillChar(Result, SizeOf(Result), 0);
  Result.m_eType := k_ESteamNetworkingIdentityType_SteamID;
  Result.m_cbSize := 8;
  Result.m_steamID64 := AId.Value;
end;
```

Most methods take an identity or address as a `Pointer`: pass `@Identity`.

A received message (`PSteamNetworkingMessage_t`) carries `m_pData` /
`m_cbSize` (the payload), `m_identityPeer` (the sender), `m_conn` (the
connection, sockets only), `m_nChannel` and `m_usecTimeReceived`. **Every
received message must be released** with the plug-in's `ReleaseMessage`.

Send flags (constants): `k_nSteamNetworkingSend_Unreliable`,
`k_nSteamNetworkingSend_Reliable`, `k_nSteamNetworkingSend_NoNagle`,
`k_nSteamNetworkingSend_NoDelay` and their combinations.

### 13.2 TSteamNetworkingUtils - relay network, ping, settings

<img src="../design/icons/svg/TSteamNetworkingUtils.svg" width="48" height="48" alt="TSteamNetworkingUtils palette icon">

Unit `Steamworks.Plugin.NetworkingUtils`. Start the Steam Datagram Relay
(SDR) **early** - it takes a few seconds to measure pings:

```pascal
procedure TForm1.SteamAPI1Initialized(Sender: TObject);
begin
  SteamNetworkingUtils1.Plugin.InitRelayNetworkAccess;
end;

procedure TForm1.SteamNetworkingUtils1SteamRelayNetworkStatus(Sender: TObject;
  const AData: SteamRelayNetworkStatus_t);
begin
  case AData.m_eAvail of
    k_ESteamNetworkingAvailability_Current:
      Log('Relay network ready');
    k_ESteamNetworkingAvailability_Waiting, k_ESteamNetworkingAvailability_Attempting:
      Log('Relay network starting...');
  else
    Log('Relay network: ' + SteamText(@AData.m_debugMsg[0]));
  end;
end;
```

Ping data for matchmaking - compare two players' locations without
pinging each other:

```pascal
var
  Here, There: SteamNetworkPingLocation_t;
  Buf: array[0..1023] of AnsiChar;
begin
  if SteamNetworkingUtils1.Plugin.GetLocalPingLocation(Here) < 0 then
    Exit;                                          // not measured yet
  SteamNetworkingUtils1.Plugin.ConvertPingLocationToString(@Here, @Buf[0], SizeOf(Buf));
  // put SteamText(@Buf[0]) into your lobby member data; the other player ...
  if SteamNetworkingUtils1.Plugin.ParsePingLocationString(TheirString, There) then
    Log(Format('Estimated ping: %d ms',
      [SteamNetworkingUtils1.Plugin.EstimatePingTimeFromLocalHost(@There)]));
end;
```

Testing under bad network conditions (fake lag and loss, all connections):

```pascal
with SteamNetworkingUtils1.Plugin do
begin
  SetGlobalConfigValueInt32(k_ESteamNetworkingConfig_FakePacketLag_Send, 150);   // ms
  SetGlobalConfigValueFloat(k_ESteamNetworkingConfig_FakePacketLoss_Send, 5.0);  // percent
end;
```

Other calls: `GetLocalTimestamp` (the clock messages are stamped with, in
microseconds), `GetPingToDataCenter`, `GetPOPCount` / `GetPOPList`,
`SteamNetworkingIdentity_ToString` / `..._ParseString`,
`SteamNetworkingIPAddr_ToString` / `..._ParseString`,
`SetDebugOutputFunction`.

### 13.3 TSteamNetworkingMessages - messages to a user

<img src="../design/icons/svg/TSteamNetworkingMessages.svg" width="48" height="48" alt="TSteamNetworkingMessages palette icon">

Unit `Steamworks.Plugin.NetworkingMessages`. Send to a Steam user; Steam
opens the session, punches through NAT or relays as needed.

```pascal
// send (any time; the first message opens the session)
procedure TForm1.SendTo(const APeer: TSteamID; const AText: string);
var
  Peer: SteamNetworkingIdentity;
  Data: TBytes;
  R: EResult;
begin
  Peer := SteamIdentity(APeer);
  Data := TEncoding.UTF8.GetBytes(AText);
  R := SteamNetworkingMessages1.Plugin.SendMessageToUser(@Peer, @Data[0], Length(Data),
    k_nSteamNetworkingSend_Reliable, 0);              // channel 0
  if R <> k_EResultOK then
    Log('Send failed: ' + IntToStr(Ord(R)));
end;

// receive (every frame, or from a 16-33 ms timer)
procedure TForm1.tmNetTimer(Sender: TObject);
var
  Msgs: array[0..31] of PSteamNetworkingMessage_t;
  I, N: Integer;
  Text: UTF8String;
begin
  N := SteamNetworkingMessages1.Plugin.ReceiveMessages(0, Msgs);   // channel 0
  for I := 0 to N - 1 do
  begin
    SetString(Text, PAnsiChar(Msgs[I]^.m_pData), Msgs[I]^.m_cbSize);
    Log(Format('%s says %s', [SteamFriends1.Plugin.GetFriendPersonaName(
      TSteamID.Create(Msgs[I]^.m_identityPeer.m_steamID64)), string(Text)]));
    SteamNetworkingMessages1.Plugin.ReleaseMessage(Msgs[I]);       // always
  end;
end;

// someone you have not messaged yet wants to talk
procedure TForm1.SteamNetworkingMessages1SteamNetworkingMessagesSessionRequest(
  Sender: TObject; const AData: SteamNetworkingMessagesSessionRequest_t);
begin
  if IsInMyLobby(TSteamID.Create(AData.m_identityRemote.m_steamID64)) then
    SteamNetworkingMessages1.Plugin.AcceptSessionWithUser(@AData.m_identityRemote);
end;

procedure TForm1.SteamNetworkingMessages1SteamNetworkingMessagesSessionFailed(
  Sender: TObject; const AData: SteamNetworkingMessagesSessionFailed_t);
begin
  Log('Session failed: ' + SteamText(@AData.m_info.m_szEndDebug[0]));
end;
```

* `ReceiveMessages(Channel, Array)` and `ReleaseMessage` are hand-written
  helpers; `ReceiveMessagesOnChannel` is the raw export.
* `CloseSessionWithUser(@Peer)` / `CloseChannelWithUser(@Peer, Channel)`
  end a session.
* `GetSessionConnectionInfo(@Peer, Info, Status)` gives the state, ping and
  quality of a session.

**Example: lobby plus messages.** A complete small multiplayer set-up for
480 uses [chapter 12](#12-tsteammatchmaking---lobbies) to gather players
and messages to talk:

```pascal
procedure TForm1.SteamMatchmaking1LobbyEnter(Sender: TObject; const AData: LobbyEnter_t);
var
  I: Integer;
  Member: TSteamID;
begin
  FLobby := TSteamID.Create(AData.m_ulSteamIDLobby);
  for I := 0 to SteamMatchmaking1.Plugin.GetNumLobbyMembers(FLobby) - 1 do
  begin
    Member := SteamMatchmaking1.Plugin.GetLobbyMemberByIndex(FLobby, I);
    if Member <> SteamUser1.Plugin.GetSteamID then
      SendTo(Member, 'hello from ' + SteamFriends1.Plugin.GetPersonaName);
  end;
end;
```

### 13.4 TSteamNetworkingSockets - connections

<img src="../design/icons/svg/TSteamNetworkingSockets.svg" width="48" height="48" alt="TSteamNetworkingSockets palette icon">

Unit `Steamworks.Plugin.NetworkingSockets`. Valve's GameNetworkingSockets:
reliable and unreliable messages over connections, peer to peer through the
relay (`CreateListenSocketP2P` / `ConnectP2P`) or by IP
(`CreateListenSocketIP` / `ConnectByIPAddress`). Connection state changes
arrive in `OnSteamNetConnectionStatusChangedCallback`.

**A first test without a network** - two connected ends in one process:

```pascal
procedure TForm1.btnLoopbackClick(Sender: TObject);
var
  C1, C2: HSteamNetConnection;
  MsgNo: Int64;
  Data: TBytes;
  Msgs: array[0..15] of PSteamNetworkingMessage_t;
  I, N: Integer;
  S: TSteamNetworkingSocketsPlugin;
begin
  S := SteamNetworkingSockets1.Plugin;
  if not S.CreateSocketPair(C1, C2, False, nil, nil) then
    Exit;
  Data := TEncoding.UTF8.GetBytes('ping');
  S.SendMessageToConnection(C1, @Data[0], Length(Data), k_nSteamNetworkingSend_Reliable, MsgNo);
  N := S.ReceiveMessages(C2, Msgs);
  for I := 0 to N - 1 do
  begin
    Log(Format('C2 received %d bytes', [Msgs[I]^.m_cbSize]));
    S.ReleaseMessage(Msgs[I]);
  end;
  S.CloseConnection(C1, 0, 'done', False);
  S.CloseConnection(C2, 0, '', False);
end;
```

**Peer to peer, host and client.** The relay network must be initialised
([13.2](#132-tsteamnetworkingutils---relay-network-ping-settings)).

```pascal
// ----- host -----
procedure TForm1.HostGame;
begin
  FListen := SteamNetworkingSockets1.Plugin.CreateListenSocketP2P(0, 0, nil);  // virtual port 0
  FGroup := SteamNetworkingSockets1.Plugin.CreatePollGroup;   // receive from all clients at once
end;

// ----- client -----
procedure TForm1.JoinGame(const AHost: TSteamID);
var
  Host: SteamNetworkingIdentity;
begin
  Host := SteamIdentity(AHost);
  FConn := SteamNetworkingSockets1.Plugin.ConnectP2P(@Host, 0, 0, nil);
end;

// ----- both: connection state -----
procedure TForm1.SteamNetworkingSockets1SteamNetConnectionStatusChangedCallback(
  Sender: TObject; const AData: SteamNetConnectionStatusChangedCallback_t);
var
  S: TSteamNetworkingSocketsPlugin;
begin
  S := SteamNetworkingSockets1.Plugin;
  case AData.m_info.m_eState of
    k_ESteamNetworkingConnectionState_Connecting:
      if AData.m_info.m_hListenSocket <> 0 then         // incoming, on the host
      begin
        if S.AcceptConnection(AData.m_hConn) = k_EResultOK then
          S.SetConnectionPollGroup(AData.m_hConn, FGroup)
        else
          S.CloseConnection(AData.m_hConn, 0, 'accept failed', False);
      end;
    k_ESteamNetworkingConnectionState_Connected:
      Log('Connected to ' + IntToStr(AData.m_info.m_identityRemote.m_steamID64));
    k_ESteamNetworkingConnectionState_ClosedByPeer,
    k_ESteamNetworkingConnectionState_ProblemDetectedLocally:
      begin
        Log('Connection ended: ' + SteamText(@AData.m_info.m_szEndDebug[0]));
        S.CloseConnection(AData.m_hConn, 0, '', False);   // always free the handle
      end;
  end;
end;

// ----- host: receive from every client (timer / frame) -----
procedure TForm1.HostFrame;
var
  Msgs: array[0..63] of PSteamNetworkingMessage_t;
  I, N: Integer;
  MsgNo: Int64;
begin
  N := SteamNetworkingSockets1.Plugin.ReceiveMessagesOnGroup(FGroup, Msgs);
  for I := 0 to N - 1 do
  begin
    // echo back to the sender's connection
    SteamNetworkingSockets1.Plugin.SendMessageToConnection(Msgs[I]^.m_conn,
      Msgs[I]^.m_pData, Msgs[I]^.m_cbSize, k_nSteamNetworkingSend_Unreliable, MsgNo);
    SteamNetworkingSockets1.Plugin.ReleaseMessage(Msgs[I]);
  end;
end;
```

* `ReceiveMessages(Conn, Array)`, `ReceiveMessagesOnGroup(Group, Array)` and
  `ReleaseMessage` are hand-written helpers.
* By IP: fill a `SteamNetworkingIPAddr` (for example with
  `TSteamNetworkingUtils.Plugin.SteamNetworkingIPAddr_ParseString(Addr,
  '192.168.1.10:27020')`), then `CreateListenSocketIP(@Addr, 0, nil)` on the
  server and `ConnectByIPAddress(@Addr, 0, nil)` on the client.
* `GetConnectionRealTimeStatus` gives ping, quality and queue sizes;
  `GetDetailedConnectionStatus` a printable report.
* `CloseListenSocket`, `DestroyPollGroup` when hosting ends.
* Game servers use the server copy `TSteamGameServerNetworkingSockets`
  ([chapter 30](#30-the-game-servers-copies-of-client-interfaces)).

| Event | When |
|-------|------|
| `OnSteamNetConnectionStatusChangedCallback` | A connection changed state. |
| `OnSteamNetAuthenticationStatus` | Authentication with Steam (certificates) changed. |
| `OnSteamNetworkingFakeIPResult` | `BeginAsyncRequestFakeIP` answered. |

---

## 14. TSteamUGC - Steam Workshop

<img src="../design/icons/svg/TSteamUGC.svg" width="48" height="48" alt="TSteamUGC palette icon">

Unit `Steamworks.Plugin.UGC`, interface `ISteamUGC`. Query, create, update,
subscribe to and install user-generated content. The Workshop must be
enabled for the AppID on the partner site (it is for 480: Spacewar has a
public test Workshop). Most calls are asynchronous; examples use the
`...Async` handlers. Builds on [TSteamUser](#7-tsteamuser---the-logged-on-user)
(account id).

### 14.1 Querying items

A query is created, configured, sent, read and **released**:

```pascal
procedure TForm1.ListPopular;
var
  Q: UGCQueryHandle_t;
begin
  Q := SteamUGC1.Plugin.CreateQueryAllUGCRequestPage(k_EUGCQuery_RankedByVote,
    k_EUGCMatchingUGCType_Items, SteamAPI1.AppID, SteamAPI1.AppID, 1);   // creator, consumer, page
  if Q = k_UGCQueryHandleInvalid then
    Exit;
  SteamUGC1.Plugin.SetReturnLongDescription(Q, False);
  SteamUGC1.Plugin.SetAllowCachedResponse(Q, 60);
  SteamUGC1.Plugin.SendQueryUGCRequestAsync(Q, QueryDone);
end;

procedure TForm1.QueryDone(const AData: TSteamCallbackData; AIOFailure: Boolean);
var
  R: SteamUGCQueryCompleted_t;
  D: SteamUGCDetails_t;
  I: UInt32;
begin
  if AIOFailure or not AData.CopyTo(R, SizeOf(R)) then
    Exit;
  try
    if R.m_eResult <> k_EResultOK then
      Exit;
    Log(Format('%d of %d items', [R.m_unNumResultsReturned, R.m_unTotalMatchingResults]));
    for I := 0 to Int64(R.m_unNumResultsReturned) - 1 do
      if SteamUGC1.Plugin.GetQueryUGCResult(R.m_handle, I, D) then
        Log(Format('%d  %s', [Int64(D.m_nPublishedFileId), SteamText(@D.m_rgchTitle[0])]));
  finally
    SteamUGC1.Plugin.ReleaseQueryUGCRequest(R.m_handle);   // always, even after a failure
  end;
end;
```

* `CreateQueryUserUGCRequest(AccountID, List, Type, Sort, CreatorApp,
  ConsumerApp, Page)` lists one user's items - published, subscribed,
  favourited, ...:

  ```pascal
  Q := SteamUGC1.Plugin.CreateQueryUserUGCRequest(SteamUser1.Plugin.GetSteamID.AccountID,
    k_EUserUGCList_Subscribed, k_EUGCMatchingUGCType_Items,
    k_EUserUGCListSortOrder_SubscriptionDateDesc, SteamAPI1.AppID, SteamAPI1.AppID, 1);
  ```

* `CreateQueryUGCDetailsRequest(@Ids[0], Count)` fetches known item ids;
  `CreateQueryAllUGCRequestCursor` pages with a cursor
  (`m_rgchNextCursor`) instead of page numbers.
* Filters before sending: `AddRequiredTag`, `AddExcludedTag`,
  `SetMatchAnyTag`, `SetSearchText`, `SetLanguage`, `SetRankedByTrendDays`,
  `AddRequiredKeyValueTag`, `SetReturnMetadata`, `SetReturnKeyValueTags`,
  `SetReturnChildren`, `SetReturnAdditionalPreviews`, `SetReturnOnlyIDs`,
  `SetReturnTotalOnly`.
* Per result: `GetQueryUGCResult` (title, description, owner, votes, ...),
  `GetQueryUGCPreviewURL`, `GetQueryUGCMetadata`, `GetQueryUGCTag`,
  `GetQueryUGCKeyValueTag`, `GetQueryUGCStatistic` - strings come back in
  buffers you pass.

### 14.2 Creating and updating an item

```pascal
procedure TForm1.btnPublishClick(Sender: TObject);
begin
  SteamUGC1.Plugin.CreateItemAsync(SteamAPI1.AppID, k_EWorkshopFileTypeCommunity, ItemCreated);
end;

procedure TForm1.ItemCreated(const AData: TSteamCallbackData; AIOFailure: Boolean);
var
  R: CreateItemResult_t;
  MapFolder: string;
begin
  MapFolder := ExtractFilePath(ParamStr(0)) + 'maps' + PathDelim + 'arena3';
  if AIOFailure or not AData.CopyTo(R, SizeOf(R)) or (R.m_eResult <> k_EResultOK) then
  begin
    Log('CreateItem failed');
    Exit;
  end;
  if R.m_bUserNeedsToAcceptWorkshopLegalAgreement then
    Log('Accept the Workshop agreement - the item stays hidden until then');
  FItem := R.m_nPublishedFileId;
  FUpdate := SteamUGC1.Plugin.StartItemUpdate(SteamAPI1.AppID, FItem);
  SteamUGC1.Plugin.SetItemTitle(FUpdate, 'TSteamAPI manual test map');
  SteamUGC1.Plugin.SetItemDescription(FUpdate, 'Uploaded by the user manual example.');
  SteamUGC1.Plugin.SetItemContent(FUpdate, MapFolder);           // absolute FOLDER
  SteamUGC1.Plugin.SetItemPreview(FUpdate, MapFolder + '.png');  // absolute FILE
  SteamUGC1.Plugin.AddItemKeyValueTag(FUpdate, 'players', '4');
  SteamUGC1.Plugin.SetItemVisibility(FUpdate, k_ERemoteStoragePublishedFileVisibilityPrivate);
  SteamUGC1.Plugin.SubmitItemUpdateAsync(FUpdate, 'First version', ItemSubmitted);
  tmUpload.Enabled := True;                                                  // progress
end;

procedure TForm1.tmUploadTimer(Sender: TObject);
var
  Done, Total: UInt64;
begin
  case SteamUGC1.Plugin.GetItemUpdateProgress(FUpdate, Done, Total) of
    k_EItemUpdateStatusPreparingContent: lblUpload.Text := 'Preparing...';
    k_EItemUpdateStatusUploadingContent:
      if Total > 0 then
        lblUpload.Text := Format('Uploading %d %%', [Int64(Done * 100 div Total)]);
    k_EItemUpdateStatusCommittingChanges: lblUpload.Text := 'Committing...';
  end;
end;

procedure TForm1.ItemSubmitted(const AData: TSteamCallbackData; AIOFailure: Boolean);
var
  R: SubmitItemUpdateResult_t;
begin
  tmUpload.Enabled := False;
  if (not AIOFailure) and AData.CopyTo(R, SizeOf(R)) and (R.m_eResult = k_EResultOK) then
    SteamFriends1.Plugin.ActivateGameOverlayToWebPage(
      'steam://url/CommunityFilePage/' + IntToStr(R.m_nPublishedFileId),
      k_EActivateGameOverlayToWebPageMode_Default);
end;
```

* On 480 publish test items as **private** and delete them afterwards:
  `SteamUGC1.Plugin.DeleteItemAsync(FItem, Handler)`.
* `GetWorkshopEULAStatusAsync` tells whether the user accepted the
  Workshop agreement; `ShowWorkshopEULA` shows it.
* Further update calls: `SetItemMetadata`, `SetItemUpdateLanguage`,
  `AddItemPreviewFile` / `AddItemPreviewVideo`, `RemoveItemPreview`,
  `AddContentDescriptor`, `SetRequiredGameVersions`; dependencies:
  `AddDependency`, `AddAppDependency`.

### 14.3 Subscribed and installed items

```pascal
procedure TForm1.LoadInstalledMaps;
var
  Ids: array of PublishedFileId_t;
  N, I, State, Stamp: UInt32;
  Size: UInt64;
  Folder: array[0..1023] of AnsiChar;
begin
  N := SteamUGC1.Plugin.GetNumSubscribedItems(False);
  SetLength(Ids, N);
  if N = 0 then
    Exit;
  N := SteamUGC1.Plugin.GetSubscribedItems(@Ids[0], N, False);
  for I := 0 to N - 1 do
  begin
    State := SteamUGC1.Plugin.GetItemState(Ids[I]);
    if (State and k_EItemStateInstalled <> 0) and
       SteamUGC1.Plugin.GetItemInstallInfo(Ids[I], Size, @Folder[0], SizeOf(Folder), Stamp) then
      AddMapFolder(SteamText(@Folder[0]))
    else if State and k_EItemStateNeedsUpdate <> 0 then
      SteamUGC1.Plugin.DownloadItem(Ids[I], True);           // -> OnDownloadItemResult
  end;
end;

procedure TForm1.SteamUGC1ItemInstalled(Sender: TObject; const AData: ItemInstalled_t);
begin
  if AData.m_unAppID = SteamAPI1.AppID then
    LoadInstalledMaps;                                        // a subscription finished installing
end;
```

* `GetItemState` is a bit set: `k_EItemStateSubscribed`,
  `k_EItemStateInstalled`, `k_EItemStateNeedsUpdate`,
  `k_EItemStateDownloading`, `k_EItemStateDownloadPending`, ...
* `GetItemDownloadInfo(Id, Done, Total)` reports a running download.
* `SubscribeItemAsync` / `UnsubscribeItemAsync`, `SetUserItemVoteAsync`,
  `AddItemToFavoritesAsync` work like the other call results.
* `StartPlaytimeTracking(@Ids[0], N)` / `StopPlaytimeTracking...` tell
  Steam which items are in use (Workshop statistics).
* Dedicated servers download items with `BInitWorkshopForGameServer` on
  the server copy `TSteamGameServerUGC` ([chapter 30](#30-the-game-servers-copies-of-client-interfaces)).

### 14.4 Events

| Event | When |
|-------|------|
| `OnSteamUGCQueryCompleted` | A query answered. |
| `OnSteamUGCRequestUGCDetailsResult` | `RequestUGCDetails` answered. |
| `OnCreateItemResult` / `OnSubmitItemUpdateResult` / `OnDeleteItemResult` | Publishing steps. |
| `OnItemInstalled` | An item of this app was installed or updated while running. |
| `OnDownloadItemResult` | `DownloadItem` finished. |
| `OnUserSubscribedItemsListChanged`, `OnUserFavoriteItemsListChanged` | The user's lists changed. |
| `OnSetUserItemVoteResult`, `OnGetUserItemVoteResult` | Votes. |
| `OnStartPlaytimeTrackingResult`, `OnStopPlaytimeTrackingResult` | Playtime tracking. |
| `OnAddUGCDependencyResult`, `OnRemoveUGCDependencyResult`, `OnAddAppDependencyResult`, `OnRemoveAppDependencyResult`, `OnGetAppDependenciesResult` | Dependencies. |
| `OnWorkshopEULAStatus` | `GetWorkshopEULAStatus` answered. |

---

## 15. TSteamInput - controllers

<img src="../design/icons/svg/TSteamInput.svg" width="48" height="48" alt="TSteamInput palette icon">

Unit `Steamworks.Plugin.Input`, interface `ISteamInput`. One API for every
controller Steam supports (Xbox, PlayStation, Switch, Steam Deck, Steam
Controller, generic pads). The game declares **actions** ("Jump", "Move")
grouped in **action sets** in an *action manifest*; the player binds
buttons to them in Steam, and the game reads actions, never raw buttons.

[SteamInputMapping.md](SteamInputMapping.md) explains manifests and default
layouts in depth; `demos/SteamInputDemo` is a complete working program. The
examples below use the demo's manifest
(`demos/SteamInputDemo/src/steam_controllers.vdf`), whose action set
`InGame` contains, among others, the analog action `LeftStick`, the
trigger `RightTrigger` and the buttons `ButtonA` .. `ButtonY`, and whose set
`Menu` contains `MenuConfirm` / `MenuBack`. The VirtualGamepadLCL demo runs
the same manifest under AppID 480.

### 15.1 Starting

```pascal
procedure TForm1.SteamAPI1Initialized(Sender: TObject);
var
  P: TSteamInputPlugin;
begin
  P := SteamInput1.Plugin;
  P.Start(True);                 // Init; True = the game calls RunFrame itself
  P.EnableDeviceCallbacks;       // OnSteamInputDeviceConnected / ...Disconnected
  // development only: a manifest next to the executable instead of the depot's
  P.SetInputActionManifestFilePath(ExtractFilePath(ParamStr(0)) + 'steam_controllers.vdf');
  tmInput.Interval := 16;        // read input at ~60 Hz
  tmInput.Enabled := True;
end;
```

* Use `Start` / `Stop`, not the raw `Init` / `Shutdown`: the plug-in then
  calls `Shutdown` itself before Steam stops.
* `Start(False)` lets the callback pump call `RunFrame`; `Start(True)` plus
  `RunFrame` in your loop keeps every ISteamInput call on one thread.
* A shipped game puts the manifest in its depot and selects it on the
  partner site; `SetInputActionManifestFilePath` is for development (and
  for 480, which is not your app).
* Xbox and generic controllers reach Steam Input only when it is enabled
  for the game: Steam > Library > the game's Properties > Controller.

### 15.2 Reading actions every frame

```pascal
type
  TForm1 = class(TForm)
  private
    FInGame, FMenu: InputActionSetHandle_t;
    FMove: InputAnalogActionHandle_t;
    FFire: InputAnalogActionHandle_t;
    FJump, FConfirm: InputDigitalActionHandle_t;
  end;

procedure TForm1.tmInputTimer(Sender: TObject);
var
  P: TSteamInputPlugin;
  Pads: TSteamInputHandleArray;
  Jump: InputDigitalActionData_t;
  Move, Fire: InputAnalogActionData_t;
begin
  P := SteamInput1.Plugin;
  if (P = nil) or not P.Started then
    Exit;
  P.RunFrame(False);                                   // with Start(True)
  Pads := P.ConnectedControllers;
  if Length(Pads) = 0 then
    Exit;
  if FInGame = 0 then                                  // 0 until Steam has loaded the manifest
  begin
    FInGame := P.GetActionSetHandle('InGame');
    FMenu := P.GetActionSetHandle('Menu');
    FMove := P.GetAnalogActionHandle('LeftStick');
    FFire := P.GetAnalogActionHandle('RightTrigger');
    FJump := P.GetDigitalActionHandle('ButtonA');
    FConfirm := P.GetDigitalActionHandle('MenuConfirm');
    if FInGame = 0 then
      Exit;                                            // try again next frame
  end;

  P.ActivateActionSet(Pads[0], FInGame);
  Move := P.GetAnalogActionData(Pads[0], FMove);       // x, y in -1..1
  Fire := P.GetAnalogActionData(Pads[0], FFire);       // x in 0..1
  Jump := P.GetDigitalActionData(Pads[0], FJump);

  Ship.Steer(Move.x, Move.y);
  if Fire.x > 0.5 then
    Ship.Fire;
  if Jump.bState then
    Ship.Boost;
end;
```

* `bActive` is `False` when the action is not in the active set or not
  bound.
* `GetMotionData(Pad)` gives gyro / accelerometer data (`rotQuat...`,
  `posAccel...`, `rotVel...`) of controllers that have them.
* Action set layers add actions on top of the active set:
  `ActivateActionSetLayer`, `DeactivateActionSetLayer`,
  `DeactivateAllActionSetLayers`.
* `GetDigitalActionData`, `GetAnalogActionData` and `GetMotionData` return
  a struct **by value** in C; they are hand-written per platform and not in
  `Flat`.

### 15.3 Button prompts ("Press A")

```pascal
procedure TForm1.ShowJumpPrompt(APad: InputHandle_t);
var
  Origins: TSteamInputOriginArray;
begin
  Origins := SteamInput1.Plugin.DigitalActionOrigins(APad, FInGame, FJump);
  if Length(Origins) = 0 then
  begin
    lblPrompt.Text := 'Jump: not bound';
    Exit;
  end;
  lblPrompt.Text := 'Press ' + SteamInput1.Plugin.GetStringForActionOrigin(Origins[0]);
  imgPrompt.Bitmap.LoadFromFile(SteamInput1.Plugin.GetGlyphPNGForActionOrigin(
    Origins[0], k_ESteamInputGlyphSize_Medium, 0));   // a PNG path in the Steam folder
end;
```

`AnalogActionOrigins` does the same for analog actions;
`GetGlyphSVGForActionOrigin` returns an SVG path.

### 15.4 Controllers, bindings, rumble, LEDs

```pascal
procedure TForm1.SteamInput1SteamInputDeviceConnected(Sender: TObject;
  const AData: SteamInputDeviceConnected_t);
var
  Pad: InputHandle_t;
begin
  Pad := AData.m_ulConnectedDeviceHandle;
  case SteamInput1.Plugin.GetInputTypeForHandle(Pad) of
    k_ESteamInputType_PS4Controller, k_ESteamInputType_PS5Controller:
      begin
        Log('PlayStation controller');
        SteamInput1.Plugin.SetLEDColor(Pad, 0, 128, 255, 0);   // light bar blue
      end;
    k_ESteamInputType_SteamDeckController:
      Log('Steam Deck controls');
  else
    Log('Controller connected');
  end;
  SteamInput1.Plugin.TriggerVibration(Pad, 20000, 20000);      // short rumble ...
  tmStopRumble.Enabled := True;                                // ... stopped with (0, 0)
end;

procedure TForm1.btnBindingsClick(Sender: TObject);
var
  Pads: TSteamInputHandleArray;
begin
  Pads := SteamInput1.Plugin.ConnectedControllers;
  if (Length(Pads) > 0) and not SteamInput1.Plugin.ShowBindingPanel(Pads[0]) then
    Log('Binding panel needs the Steam overlay (start the game through Steam)');
end;
```

* `TriggerVibration(Pad, Left, Right)` takes 0..65535; send `0, 0` to stop.
  `TriggerVibrationExtended` adds trigger motors (Xbox One);
  `TriggerSimpleHapticEvent` for haptic controllers.
* `GetControllerForGamepadIndex` / `GetGamepadIndexForController` map
  Steam Input handles to XInput slots.
* `EnableActionEventCallbacks` pushes action changes to a C callback
  instead of polling (untested so far; polling works).

| Event | When |
|-------|------|
| `OnSteamInputDeviceConnected` / `OnSteamInputDeviceDisconnected` | After `EnableDeviceCallbacks`. |
| `OnSteamInputConfigurationLoaded` | Steam loaded a configuration for a controller - look up action handles again. |
| `OnSteamInputGamepadSlotChange` | A controller moved to another gamepad slot. |

---

## 16. TSteamScreenshots - the screenshot library

<img src="../design/icons/svg/TSteamScreenshots.svg" width="48" height="48" alt="TSteamScreenshots palette icon">

Unit `Steamworks.Plugin.Screenshots`, interface `ISteamScreenshots`. By
default the overlay takes screenshots itself when the user presses the
hotkey (F12) and the game needs nothing from this interface. Use it to
take screenshots from game code, to supply the image yourself (without the
HUD) or to tag them. Builds on
[`SteamFormToRGB`](#59-images-and-screenshots-steamimagetobitmap-steamformtorgb) and
[TSteamUtils](#6-tsteamutils---client-utilities) (`IsOverlayEnabled`).

### 16.1 A screenshot that always works

`TriggerScreenshot` and F12 need the overlay in the process, which a
program started from the IDE does not have. Writing the pixels yourself
always works:

```pascal
procedure TForm1.mnuScreenshotClick(Sender: TObject);
var
  RGB: TBytes;
  W, H: Integer;
  Shot: ScreenshotHandle;
begin
  RGB := SteamFormToRGB(Self, W, H);                  // packed 24-bit RGB, top row first
  if RGB = nil then
    Exit;
  Shot := SteamScreenshots1.Plugin.WriteScreenshot(@RGB[0], Length(RGB), W, H);
  SteamScreenshots1.Plugin.SetLocation(Shot, 'Spacewar - Arena 1');
end;

procedure TForm1.SteamScreenshots1ScreenshotReady(Sender: TObject;
  const AData: ScreenshotReady_t);
begin
  if AData.m_eResult = k_EResultOK then
    Log('Screenshot saved to the Steam library');
end;
```

### 16.2 Answering the hotkey yourself

```pascal
procedure TForm1.SteamAPI1Initialized(Sender: TObject);
begin
  SteamScreenshots1.Plugin.HookScreenshots(True);   // F12 -> OnScreenshotRequested
end;

procedure TForm1.SteamScreenshots1ScreenshotRequested(Sender: TObject;
  const AData: ScreenshotRequested_t);
var
  RGB: TBytes;
  W, H: Integer;
begin
  HideHUD;
  try
    RGB := SteamFormToRGB(Self, W, H);
  finally
    ShowHUD;
  end;
  if RGB <> nil then
    SteamScreenshots1.Plugin.WriteScreenshot(@RGB[0], Length(RGB), W, H);
end;
```

* While hooked, Steam takes **no** screenshot of its own - answer every
  request. `IsScreenshotsHooked` tells the state. (On the macOS Steam
  client the hook has been seen not to take; `WriteScreenshot` is not
  affected.)
* `WriteScreenshot` takes 24-bit RGB without alpha; convert RGBA first. For
  a 3D viewport or render target use `SteamBitmapToRGB` on its bitmap.
* `AddScreenshotToLibrary(File, Thumbnail, W, H)` adds a JPEG, TGA or PNG
  from disk; to let Steam make the thumbnail, call
  `P.Flat.AddScreenshotToLibrary(P.Handle, PAnsiChar(UTF8String(FileName)), nil, W, H)`.
* Tags: `SetLocation`, `TagUser(Shot, FriendID)` (a friend in the
  picture), `TagPublishedFile(Shot, ItemID)` (a Workshop item shown).
* `AddVRScreenshotToLibrary` for VR titles.

| Event | When |
|-------|------|
| `OnScreenshotReady` | A screenshot was written (`m_hLocal`, `m_eResult`). |
| `OnScreenshotRequested` | The user pressed the hotkey while hooked. |

---

## 17. TSteamTimeline - game recording markers

<img src="../design/icons/svg/TSteamTimeline.svg" width="48" height="48" alt="TSteamTimeline palette icon">

Unit `Steamworks.Plugin.Timeline`, interface `ISteamTimeline`. Markers on
the timeline the user sees when Steam records gameplay in the background
or the user saves a clip. Everything here is a hint: calls are cheap and
safe when recording is off.

```pascal
procedure TForm1.MatchStarted(const AMatchId: string);
begin
  with SteamTimeline1.Plugin do
  begin
    SetTimelineGameMode(k_ETimelineGameMode_Playing);   // also Menus, LoadingScreen, Staging
    StartGamePhase;                                     // one match = one phase
    SetGamePhaseID(AMatchId);
    SetTimelineTooltip('Arena 1 - 2 players', 0);
  end;
end;

procedure TForm1.EnemyDestroyed;
begin
  // title, description, icon, priority, offset (s), clip priority
  SteamTimeline1.Plugin.AddInstantaneousTimelineEvent('Kill', 'Destroyed the enemy ship',
    'steam_starburst', 0, 0, k_ETimelineEventClipPriority_Standard);
end;

procedure TForm1.BossFightStarted;
begin
  FBoss := SteamTimeline1.Plugin.StartRangeTimelineEvent('Boss', 'The Warden',
    'steam_flag', 0, 0, k_ETimelineEventClipPriority_Featured);
end;

procedure TForm1.BossFightEnded;
begin
  SteamTimeline1.Plugin.EndRangeTimelineEvent(FBoss, 0);
end;

procedure TForm1.MatchEnded(AWon: Boolean; const AScore: string);
begin
  with SteamTimeline1.Plugin do
  begin
    if AWon then
      AddGamePhaseTag('Victory', 'steam_heart', 'Result', 100)
    else
      AddGamePhaseTag('Defeat', 'steam_flag', 'Result', 100);
    SetGamePhaseAttribute('Score', AScore, 50);
    EndGamePhase;
    ClearTimelineTooltip(0);
    SetTimelineGameMode(k_ETimelineGameMode_Menus);
  end;
end;
```

* Icons are your own timeline icons (uploaded on the partner site) or
  Steam's built-in `steam_...` icons. Text should be in the language
  `TSteamUtils.GetSteamUILanguage` returns.
* Time offsets are seconds relative to now; negative values mark something
  that already happened (`AddRangeTimelineEvent(..., -30, 30, ...)` for "the
  last 30 seconds").
* `UpdateRangeTimelineEvent`, `RemoveTimelineEvent` change or remove
  events.
* After the match: `DoesGamePhaseRecordingExistAsync(MatchId, Handler)`
  (or `DoesEventRecordingExist`) tells whether Steam has video for it; if
  so `OpenOverlayToGamePhase(MatchId)` / `OpenOverlayToTimelineEvent(Ev)`
  show it.

```pascal
SteamTimeline1.Plugin.DoesEventRecordingExistAsync(FBoss, RecordingChecked);

procedure TForm1.RecordingChecked(const AData: TSteamCallbackData; AIOFailure: Boolean);
var
  R: SteamTimelineEventRecordingExists_t;
begin
  if (not AIOFailure) and AData.CopyTo(R, SizeOf(R)) and R.m_bRecordingExists then
    btnWatchBoss.Visible := True;          // OpenOverlayToTimelineEvent(FBoss)
end;
```

| Event | When |
|-------|------|
| `OnSteamTimelineEventRecordingExists` | `DoesEventRecordingExist` answered. |
| `OnSteamTimelineGamePhaseRecordingExists` | `DoesGamePhaseRecordingExist` answered. |

---

# Part III - Further features

## 18. TSteamInventory - Steam Inventory items

<img src="../design/icons/svg/TSteamInventory.svg" width="48" height="48" alt="TSteamInventory palette icon">

Unit `Steamworks.Plugin.Inventory`, interface `ISteamInventory`. Items the
user owns in this game (cosmetics, drops, purchases), defined on the
partner site. Every request returns a **result handle**;
`OnSteamInventoryResultReady` says when it is ready, and **every result
must be destroyed**.

Spacewar has an inventory configuration of its own (Valve's sample defines
a timed drop generator, id 10, and a handful of ship items around ids
100 - 121). Run [18.2](#182-item-definitions) to see what the app
currently defines.

### 18.1 Listing the player's items

```pascal
procedure TForm1.LoadItems;
begin
  if not SteamInventory1.Plugin.GetAllItems(FAllItems) then   // -> OnSteamInventoryResultReady
    Log('GetAllItems failed (Inventory Service off for the app?)');
end;

procedure TForm1.SteamInventory1SteamInventoryResultReady(Sender: TObject;
  const AData: SteamInventoryResultReady_t);
var
  Inv: TSteamInventoryPlugin;
  Count, I: UInt32;
  Items: array of SteamItemDetails_t;
begin
  Inv := SteamInventory1.Plugin;
  try
    if AData.m_result <> k_EResultOK then
    begin
      Log('Inventory result: ' + IntToStr(Ord(AData.m_result)));
      Exit;
    end;
    Count := 0;
    Inv.GetResultItems(AData.m_handle, nil, Count);           // size first
    SetLength(Items, Count);
    if Count > 0 then
      Inv.GetResultItems(AData.m_handle, @Items[0], Count);
    for I := 0 to Int64(Count) - 1 do
      Log(Format('item %d: definition %d x%d', [Int64(Items[I].m_itemId),
        Items[I].m_iDefinition, Items[I].m_unQuantity]));
  finally
    Inv.DestroyResult(AData.m_handle);                        // always
  end;
end;
```

* Many methods take raw arrays (pointer + count): pass `nil` first to get
  the size, as above.
* `GetResultItemProperty(Result, Index, Name, Buffer, Size)` reads dynamic
  properties of one item.
* The same event answers every request (`GetAllItems`, `TriggerItemDrop`,
  `ConsumeItem`, ...); compare `AData.m_handle` with the handle each call
  returned if you need to tell them apart.

### 18.2 Item definitions

```pascal
procedure TForm1.SteamAPI1Initialized(Sender: TObject);
begin
  SteamInventory1.Plugin.LoadItemDefinitions;        // -> OnSteamInventoryDefinitionUpdate
end;

procedure TForm1.SteamInventory1SteamInventoryDefinitionUpdate(Sender: TObject;
  const AData: SteamInventoryDefinitionUpdate_t);
var
  Inv: TSteamInventoryPlugin;
  Count, Size: UInt32;
  Defs: array of SteamItemDef_t;
  I: Integer;
  Name: array[0..255] of AnsiChar;
begin
  Inv := SteamInventory1.Plugin;
  Count := 0;
  Inv.GetItemDefinitionIDs(nil, Count);
  SetLength(Defs, Count);
  if (Count = 0) or not Inv.GetItemDefinitionIDs(@Defs[0], Count) then
    Exit;
  for I := 0 to High(Defs) do
  begin
    Size := SizeOf(Name);
    if Inv.GetItemDefinitionProperty(Defs[I], 'name', @Name[0], Size) then
      Log(Format('definition %d: %s', [Defs[I], SteamText(@Name[0])]));
  end;
end;
```

### 18.3 Drops, consuming, promotions, purchases

```pascal
var
  R: SteamInventoryResult_t;
begin
  // playtime drop: the generator decides whether something drops (rate-limited by Steam)
  SteamInventory1.Plugin.TriggerItemDrop(R, SPACEWAR_DROP_GENERATOR);
  // use up one unit of an item instance
  SteamInventory1.Plugin.ConsumeItem(R, ItemInstanceID, 1);
  // grant a promo item the user is eligible for
  SteamInventory1.Plugin.AddPromoItem(R, PromoDefinition);
  // each call answers in OnSteamInventoryResultReady - destroy R there
end;
```

* `ExchangeItems` crafts (destroy some, generate others) per the recipes on
  the partner site; `TransferItemQuantity` splits / stacks.
* `StartPurchaseAsync(@Defs[0], @Quantities[0], N, Handler)` opens Steam's
  checkout; `RequestPricesAsync` + `GetItemPrice` show prices in the
  user's currency.
* `GenerateItems` (development only) grants items directly - it works only
  for the app's own developers, not on 480.
* Results can be checked on a game server: `SerializeResult` on the client,
  `DeserializeResult` + `CheckResultSteamID` on the server copy
  `TSteamGameServerInventory`.
* Dynamic properties: `StartUpdateProperties`, `SetPropertyString` /
  `...Bool` / `...Int64` / `...Float`, `SubmitUpdateProperties`.

| Event | When |
|-------|------|
| `OnSteamInventoryResultReady` | A result handle is ready. |
| `OnSteamInventoryFullUpdate` | A result that contains the full inventory is ready. |
| `OnSteamInventoryDefinitionUpdate` | Item definitions loaded or changed. |
| `OnSteamInventoryEligiblePromoItemDefIDs` | `RequestEligiblePromoItemDefinitionsIDs` answered. |
| `OnSteamInventoryStartPurchaseResult` | `StartPurchase` answered. |
| `OnSteamInventoryRequestPricesResult` | `RequestPrices` answered. |

---

## 19. TSteamRemotePlay - Remote Play and Remote Play Together

<img src="../design/icons/svg/TSteamRemotePlay.svg" width="48" height="48" alt="TSteamRemotePlay palette icon">

Unit `Steamworks.Plugin.RemotePlay`, interface `ISteamRemotePlay`. The game
streamed to another device, and Remote Play Together (friends joining a
local multiplayer game over the internet).

```pascal
procedure TForm1.SteamRemotePlay1SteamRemotePlaySessionConnected(Sender: TObject;
  const AData: SteamRemotePlaySessionConnected_t);
var
  RP: TSteamRemotePlayPlugin;
  W, H: Integer;
begin
  RP := SteamRemotePlay1.Plugin;
  Log(Format('%s joined on "%s"', [
    SteamFriends1.Plugin.GetFriendPersonaName(RP.GetSessionSteamID(AData.m_unSessionID)),
    RP.GetSessionClientName(AData.m_unSessionID)]));
  if RP.BGetSessionClientResolution(AData.m_unSessionID, W, H) then
    Log(Format('  screen %d x %d', [W, H]));
  case RP.GetSessionClientFormFactor(AData.m_unSessionID) of
    k_ESteamDeviceFormFactorPhone: UseLargeUI;     // adapt to a phone
    k_ESteamDeviceFormFactorTV:    UseTenFootUI;   // or a TV
  end;
end;

procedure TForm1.btnInviteClick(Sender: TObject);
begin
  if not SteamRemotePlay1.Plugin.ShowRemotePlayTogetherUI then   // Steam's invite UI
    SteamRemotePlay1.Plugin.BSendRemotePlayTogetherInvite(FriendID);
end;
```

* `GetSessionCount` / `GetSessionID(I)` list active sessions;
  `BSessionRemotePlayTogether` tells whether a session is a Together guest.
* Guests' avatars: `GetSmall/Medium/LargeSessionAvatar` (handles, as in
  [4.8](#48-images)), `OnSteamRemotePlaySessionAvatarLoaded`.
* Direct input from guests: `BEnableRemotePlayTogetherDirectInput`, then
  poll `GetInput(@Events[0], Length(Events))` (an array of
  `RemotePlayInput_t`; `m_eType` says which member is valid). Mouse cursor:
  `SetMouseVisibility`, `SetMousePosition`, `CreateMouseCursor`,
  `SetMouseCursor`.

| Event | When |
|-------|------|
| `OnSteamRemotePlaySessionConnected` / `...Disconnected` | A session started / ended. |
| `OnSteamRemotePlayTogetherGuestInvite` | An invite link was created for a guest. |
| `OnSteamRemotePlaySessionAvatarLoaded` | A guest's avatar is ready. |

---

## 20. TSteamParties - party beacons

<img src="../design/icons/svg/TSteamParties.svg" width="48" height="48" alt="TSteamParties palette icon">

Unit `Steamworks.Plugin.Parties`, interface `ISteamParties`. For games that
put players together outside the game: a player creates a **beacon** (open
slots plus a connect string) in a location, others find it and join, and
the beacon owner is told about each reservation.

```pascal
procedure TForm1.ShowBeacons;
var
  P: TSteamPartiesPlugin;
  N, I: UInt32;
  Owner: TSteamID;
  Loc: SteamPartyBeaconLocation_t;
  Meta: array[0..1023] of AnsiChar;
  Id: PartyBeaconID_t;
begin
  P := SteamParties1.Plugin;
  if P.GetNumAvailableBeaconLocations(N) then
    Log(Format('%d beacon locations', [N]));
  for I := 0 to Int64(P.GetNumActiveBeacons) - 1 do
  begin
    Id := P.GetBeaconByIndex(I);
    if P.GetBeaconDetails(Id, Owner, Loc, @Meta[0], SizeOf(Meta)) then
      Log(Format('beacon of %s: %s', [Owner.ToString, SteamText(@Meta[0])]));
  end;
end;

// joining one: the answer carries the connect string
procedure TForm1.SteamParties1JoinPartyCallback(Sender: TObject;
  const AData: JoinPartyCallback_t);
begin
  if AData.m_eResult = k_EResultOK then
    ConnectTo(SteamText(@AData.m_rgchConnectString[0]));
end;

// owner side: someone reserved a slot
procedure TForm1.SteamParties1ReservationNotificationCallback(Sender: TObject;
  const AData: ReservationNotificationCallback_t);
begin
  ExpectPlayer(AData.m_steamIDJoiner);
  // when he has really arrived:
  SteamParties1.Plugin.OnReservationCompleted(AData.m_ulBeaconID, AData.m_steamIDJoiner);
end;
```

* `CreateBeacon(Slots, Location, Connect, Metadata)` (location from
  `GetAvailableBeaconLocations`) -> `OnCreateBeaconCallback`;
  `ChangeNumOpenSlots`, `CancelReservation`, `DestroyBeacon`.
* **Not bound:** `GetBeaconLocationData` - it takes a
  `SteamPartyBeaconLocation_t` *by value*, which needs a per-platform shim.

| Event | When |
|-------|------|
| `OnCreateBeaconCallback` | `CreateBeacon` answered. |
| `OnJoinPartyCallback` | `JoinParty` answered (connect string). |
| `OnReservationNotificationCallback` | Someone reserved a slot of your beacon. |
| `OnChangeNumOpenSlotsCallback` | `ChangeNumOpenSlots` answered. |
| `OnAvailableBeaconLocationsUpdated`, `OnActiveBeaconsUpdated` | Lists changed. |

---

## 21. TSteamHTTP - HTTP through the Steam client

<img src="../design/icons/svg/TSteamHTTP.svg" width="48" height="48" alt="TSteamHTTP palette icon">

Unit `Steamworks.Plugin.HTTP`, interface `ISteamHTTP`. HTTP requests made
by the Steam client: no HTTP library of your own, and the request works
wherever Steam does. Create, set up, send, read the answer in
`OnHTTPRequestCompleted`, **release**.

```pascal
procedure TForm1.btnServerInfoClick(Sender: TObject);
var
  Req: HTTPRequestHandle;
  Call: SteamAPICall_t;
begin
  Req := SteamHTTP1.Plugin.CreateHTTPRequest(k_EHTTPMethodGET,
    'https://api.steampowered.com/ISteamWebAPIUtil/GetServerInfo/v1/');
  SteamHTTP1.Plugin.SetHTTPRequestHeaderValue(Req, 'Accept', 'application/json');
  SteamHTTP1.Plugin.SetHTTPRequestContextValue(Req, 1);      // comes back as m_ulContextValue
  SteamHTTP1.Plugin.SetHTTPRequestAbsoluteTimeoutMS(Req, 10000);
  if not SteamHTTP1.Plugin.SendHTTPRequest(Req, Call) then  // -> OnHTTPRequestCompleted
    SteamHTTP1.Plugin.ReleaseHTTPRequest(Req);
end;

procedure TForm1.SteamHTTP1HTTPRequestCompleted(Sender: TObject;
  const AData: HTTPRequestCompleted_t);
var
  Size: UInt32;
  Body: TBytes;
begin
  try
    if not AData.m_bRequestSuccessful then
    begin
      Log('No answer (network / timeout)');
      Exit;
    end;
    Log(Format('HTTP status %d', [Ord(AData.m_eStatusCode)]));
    if SteamHTTP1.Plugin.GetHTTPResponseBodySize(AData.m_hRequest, Size) and (Size > 0) then
    begin
      SetLength(Body, Size);
      if SteamHTTP1.Plugin.GetHTTPResponseBodyData(AData.m_hRequest, @Body[0], Size) then
        Log(TEncoding.UTF8.GetString(Body));    // {"servertime":..., "servertimestring":...}
    end;
  finally
    SteamHTTP1.Plugin.ReleaseHTTPRequest(AData.m_hRequest);  // always
  end;
end;
```

A POST with a JSON body:

```pascal
Req := SteamHTTP1.Plugin.CreateHTTPRequest(k_EHTTPMethodPOST, 'https://example.com/api/score');
Body := TEncoding.UTF8.GetBytes('{"score": 1234}');
SteamHTTP1.Plugin.SetHTTPRequestRawPostBody(Req, 'application/json', @Body[0], Length(Body));
SteamHTTP1.Plugin.SendHTTPRequest(Req, Call);
```

* `m_eStatusCode` is the HTTP status (`k_EHTTPStatusCode200OK`, ...);
  `m_bRequestSuccessful = False` means no answer came at all.
* Form fields: `SetHTTPRequestGetOrPostParameter`. Cookies:
  `CreateCookieContainer`, `SetCookie`, `SetHTTPRequestCookieContainer`.
* Large downloads: `SendHTTPRequestAndStreamResponse`, then
  `OnHTTPRequestDataReceived` and `GetHTTPStreamingResponseBodyData`.
* Game servers use `TSteamGameServerHTTP` ([chapter 30](#30-the-game-servers-copies-of-client-interfaces)).

| Event | When |
|-------|------|
| `OnHTTPRequestCompleted` | The request finished (or failed). |
| `OnHTTPRequestHeadersReceived` | Headers arrived (streaming). |
| `OnHTTPRequestDataReceived` | A chunk arrived (streaming). |

---

## 22. TSteamHTMLSurface - an off-screen browser

<img src="../design/icons/svg/TSteamHTMLSurface.svg" width="48" height="48" alt="TSteamHTMLSurface palette icon">

Unit `Steamworks.Plugin.HTMLSurface`, interface `ISteamHTMLSurface`. A
Chromium browser inside the Steam client that renders **off-screen** into
pixel buffers for the game to draw - store pages, news, sign-in pages. The
game owns drawing and input.

```pascal
procedure TForm1.OpenBrowser;
begin
  SteamHTMLSurface1.Plugin.Init;
  SteamHTMLSurface1.Plugin.CreateBrowser('', '');              // -> OnHTML_BrowserReady
end;

procedure TForm1.SteamHTMLSurface1HTML_BrowserReady(Sender: TObject;
  const AData: HTML_BrowserReady_t);
begin
  FBrowser := AData.unBrowserHandle;
  SteamHTMLSurface1.Plugin.SetSize(FBrowser, 1024, 768);
  SteamHTMLSurface1.Plugin.LoadURL(FBrowser, Format(STORE_APP_URL, [SteamAPI1.AppID]), '');
end;

procedure TForm1.SteamHTMLSurface1HTML_NeedsPaint(Sender: TObject;
  const AData: HTML_NeedsPaint_t);
begin
  // AData.pBGRA: unWide x unTall pixels, BGRA - valid ONLY inside this event
  CopyToTexture(AData.pBGRA, AData.unWide, AData.unTall);
end;

// Valve requires these to be answered, or the page waits:
procedure TForm1.SteamHTMLSurface1HTML_StartRequest(Sender: TObject;
  const AData: HTML_StartRequest_t);
begin
  SteamHTMLSurface1.Plugin.AllowStartRequest(AData.unBrowserHandle, True);
end;

procedure TForm1.SteamHTMLSurface1HTML_JSAlert(Sender: TObject; const AData: HTML_JSAlert_t);
begin
  ShowMessage(SteamText(AData.pchMessage));
  SteamHTMLSurface1.Plugin.JSDialogResponse(AData.unBrowserHandle, True);
end;

// input: forward your control's mouse and keys
procedure TForm1.BrowserViewMouseMove(Sender: TObject; Shift: TShiftState; X, Y: Single);
begin
  SteamHTMLSurface1.Plugin.MouseMove(FBrowser, Round(X), Round(Y));
end;

procedure TForm1.BrowserViewMouseDown(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Single);
begin
  SteamHTMLSurface1.Plugin.MouseDown(FBrowser, eHTMLMouseButton_Left);
end;

procedure TForm1.CloseBrowser;
begin
  SteamHTMLSurface1.Plugin.RemoveBrowser(FBrowser);
  SteamHTMLSurface1.Plugin.Shutdown;
end;
```

* Handle `OnHTML_StartRequest` (`AllowStartRequest`), `OnHTML_JSAlert` /
  `OnHTML_JSConfirm` (`JSDialogResponse`) and `OnHTML_FileOpenDialog`
  (`FileLoadDialogResponse`) - the page waits until they are answered.
* Keys: `KeyDown`, `KeyUp`, `KeyChar` with modifier bit flags
  (`k_eHTMLKeyModifier_CtrlDown or k_eHTMLKeyModifier_ShiftDown`);
  `SetKeyFocus`, `MouseWheel`, `MouseUp`, `MouseDoubleClick`.
* Navigation: `GoBack`, `GoForward`, `Reload`, `StopLoad`,
  `ExecuteJavascript`, `Find`, `SetPageScaleFactor`, `SetDPIScalingFactor`.

The component has 23 events (`OnHTML_URLChanged`,
`OnHTML_FinishedRequest`, `OnHTML_ChangedTitle`, `OnHTML_NewWindow`,
`OnHTML_SetCursor`, tool tips, scroll bars, ...); see
[components/TSteamHTMLSurface.md](components/TSteamHTMLSurface.md).

---

## 23. TSteamMusic - the Steam music player

<img src="../design/icons/svg/TSteamMusic.svg" width="48" height="48" alt="TSteamMusic palette icon">

Unit `Steamworks.Plugin.Music`, interface `ISteamMusic`. The user's Steam
music player (soundtracks): read its state, control it.

```pascal
procedure TForm1.SteamAPI1Initialized(Sender: TObject);
begin
  with SteamMusic1.Plugin do
    if BIsEnabled then
      Log(Format('Steam music: playing %s, volume %.2f',
        [BoolToStr(BIsPlaying, True), GetVolume]));
end;

// lower the user's music while a cut-scene speaks
procedure TForm1.CutsceneStarted;
begin
  FOldVolume := SteamMusic1.Plugin.GetVolume;
  SteamMusic1.Plugin.SetVolume(0.2);
end;

procedure TForm1.SteamMusic1VolumeHasChanged(Sender: TObject;
  const AData: VolumeHasChanged_t);
begin
  Log(Format('Music volume now %.2f', [AData.m_flNewVolume]));
end;
```

`Play`, `Pause`, `PlayPrevious`, `PlayNext`, `SetVolume` (0.0 - 1.0),
`GetPlaybackStatus`. Events: `OnPlaybackStatusHasChanged`,
`OnVolumeHasChanged`. The player belongs to the user - change it only when
the user asks or briefly, as above.

---

## 24. TSteamVideo - broadcasting state

<img src="../design/icons/svg/TSteamVideo.svg" width="48" height="48" alt="TSteamVideo palette icon">

Unit `Steamworks.Plugin.Video`, interface `ISteamVideo`. Whether the user is
broadcasting the game, and stream settings of video apps.

```pascal
procedure TForm1.SteamVideo1BroadcastUploadStart(Sender: TObject;
  const AData: BroadcastUploadStart_t);
var
  Viewers: Integer;
begin
  if SteamVideo1.Plugin.IsBroadcasting(Viewers) then
    Log(Format('Broadcasting to %d viewers - hiding the room code', [Viewers]));
  lblRoomCode.Visible := False;           // streamer mode
end;

procedure TForm1.SteamVideo1BroadcastUploadStop(Sender: TObject;
  const AData: BroadcastUploadStop_t);
begin
  lblRoomCode.Visible := True;
end;
```

`GetVideoURL` -> `OnGetVideoURLResult` and `GetOPFSettings` ->
`OnGetOPFSettingsResult` (then `GetOPFStringForApp`) are for video apps; a
game gets an error result.

---

## 25. TSteamParentalSettings - Family View

<img src="../design/icons/svg/TSteamParentalSettings.svg" width="48" height="48" alt="TSteamParentalSettings palette icon">

Unit `Steamworks.Plugin.ParentalSettings`, interface
`ISteamParentalSettings`. Whether the account is under parental control
and what is blocked, so the game can hide what the user may not use.

```pascal
procedure TForm1.ApplyParentalSettings;
begin
  with SteamParentalSettings1.Plugin do
  begin
    btnStore.Visible := not (BIsParentalLockEnabled and BIsFeatureBlocked(k_EFeatureStore));
    btnCommunity.Visible := not BIsFeatureBlocked(k_EFeatureCommunity);
    pnlChat.Visible := not BIsFeatureBlocked(k_EFeatureFriends);
  end;
end;

procedure TForm1.SteamParentalSettings1SteamParentalSettingsChanged(Sender: TObject;
  const AData: SteamParentalSettingsChanged_t);
begin
  ApplyParentalSettings;                 // the parent unlocked / changed something
end;
```

`BIsParentalLockLocked` (locked now; unlocked with the PIN),
`BIsAppBlocked` / `BIsAppInBlockList` (an app),
`BIsFeatureBlocked` / `BIsFeatureInBlockList` (a feature).

---

## 26. TSteamNetworking - the old P2P API (deprecated)

<img src="../design/icons/svg/TSteamNetworking.svg" width="48" height="48" alt="TSteamNetworking palette icon">

Unit `Steamworks.Plugin.Networking`, interface `ISteamNetworking`. Packets
to another Steam user by SteamID, relayed when needed. **Valve has
deprecated it**; new code should use `TSteamNetworkingMessages` (the same
idea, [13.3](#133-tsteamnetworkingmessages---messages-to-a-user)) or
`TSteamNetworkingSockets` ([13.4](#134-tsteamnetworkingsockets---connections)).
It is bound because existing games still use it.

```pascal
// send: the first packet to a user also opens the session
procedure TForm1.SendPacket(const ATo: TSteamID; const AData: TBytes);
begin
  SteamNetworking1.Plugin.SendP2PPacket(ATo, @AData[0], Length(AData), k_EP2PSendReliable, 0);
end;

// receive: poll every frame
procedure TForm1.tmP2PTimer(Sender: TObject);
var
  Size, Got: UInt32;
  From: TSteamID;
  Buf: TBytes;
begin
  while SteamNetworking1.Plugin.IsP2PPacketAvailable(Size, 0) do
  begin
    SetLength(Buf, Size);
    if SteamNetworking1.Plugin.ReadP2PPacket(@Buf[0], Size, Got, From, 0) then
      HandlePacket(From, Copy(Buf, 0, Got));
  end;
end;

// another user wants to talk to you
procedure TForm1.SteamNetworking1P2PSessionRequest(Sender: TObject;
  const AData: P2PSessionRequest_t);
begin
  if IsInMyLobby(AData.m_steamIDRemote) then
    SteamNetworking1.Plugin.AcceptP2PSessionWithUser(AData.m_steamIDRemote);
end;
```

* `OnP2PSessionConnectFail` reports a failed session;
  `CloseP2PSessionWithUser` ends one; `GetP2PSessionState` describes it.
* The even older socket part: `CreateListenSocket` and
  `CreateConnectionSocket` are **not bound** (they take the deprecated
  `SteamIPAddress_t` by value); the rest of it is.
* Game servers: `TSteamGameServerNetworking`.

---

# Part IV - Game servers

A game server logs on to Steam, appears in the server browser, verifies
its players' tickets and answers server-browser queries. This part builds
on [TSteamAPI](#5-tsteamapi---the-root-component) (the game-server
properties), [TSteamUser](#7-tsteamuser---the-logged-on-user) (tickets),
[TSteamUserStats](#8-tsteamuserstats---achievements-stats-and-leaderboards)
(stats) and [networking](#13-networking).

## 27. Running a game server with TSteamAPI

One `TSteamAPI` runs the client, a game server, or both:

| Kind | Settings | Starting |
|------|----------|----------|
| **Listen server** (the game is client and server in one process) | `Roles = [srClient]` | `Active := True` as usual; `SteamAPI1.StartGameServer` when the player hosts, `StopGameServer` when hosting ends. |
| **Listen server from the start** | `Roles = [srClient, srGameServer]` | `Active := True`. |
| **Dedicated server** (no Steam client needed) | `Roles = [srGameServer]` | `Active := True` (or `StartGameServer` while inactive). Give it the AppID with `steam_appid.txt` (or `SetAppIdEnvironment` while developing). |

The server settings are `TSteamAPI` properties, read when the server
starts:

| Property | Default | Meaning |
|----------|---------|---------|
| `GameServerIP` | 0 | IP to bind to, host order (0 = any). |
| `GameServerGamePort` | 27015 | UDP port of the game's own traffic. |
| `GameServerQueryPort` | 27016 | UDP port Steam answers server-browser queries on. 65535 = shared with the game port: the game forwards queries with `HandleIncomingPacket` / `GetNextOutgoingPacket`. |
| `GameServerMode` | `ssmAuthenticationAndSecure` | `ssmNoAuthentication`, `ssmAuthentication`, `ssmAuthenticationAndSecure` (VAC). |
| `GameServerVersion` | `'1.0.0.0'` | Compared with the version on the partner site. |

Events: `OnGameServerStarted` (server components attached),
`OnGameServerStopped`, `OnGameServerFailed(Sender, AResult, AMessage)` (for
example the port is taken). `IsGameServerRunning` tells the state.
`Close` / `Active := False` shuts down whatever runs, the server first.

The server has its **own** Steam pipe and callbacks; the core keeps them
apart (ids such as 101-103 and 143 arrive on both pipes). In code without
components, server callbacks go through `Steam.ServerDispatcher`
(`Steam.DispatcherFor(True)`).

## 28. TSteamGameServer

<img src="../design/icons/svg/TSteamGameServer.svg" width="48" height="48" alt="TSteamGameServer palette icon">

Unit `Steamworks.Plugin.GameServer`, interface `ISteamGameServer`. Attaches
when the game server starts.

### 28.1 Hosting a listen server

```pascal
procedure TForm1.btnHostClick(Sender: TObject);
begin
  // GameServerGamePort / GameServerQueryPort: set in the Object Inspector
  if not SteamAPI1.StartGameServer then
    Exit;                                    // OnGameServerFailed / the log say why
  with SteamGameServer1.Plugin do
  begin
    SetModDir('spacewar');                   // Spacewar's values; use your own game's
    SetProduct('SteamworksExample');
    SetGameDescription('Steamworks Example');
    SetDedicatedServer(False);
    LogOnAnonymous;                          // -> OnSteamServersConnected
  end;
end;

procedure TForm1.SteamGameServer1SteamServersConnected(Sender: TObject;
  const AData: SteamServersConnected_t);
begin
  with SteamGameServer1.Plugin do
  begin
    Log(Format('Server logged on as %s, public IP %s', [GetSteamID.ToString,
      IPToStr(PublicIPv4)]));
    SetServerName('TSteamAPI manual server');
    SetMapName('arena1');
    SetMaxPlayerCount(8);
    SetPasswordProtected(False);
    SetGameTags('coop,manual');
    SetKeyValue('mode', 'coop');             // a rule (server browser: OnRule)
    SetAdvertiseServerActive(True);          // list it in the server browser
  end;
end;

procedure TForm1.SteamGameServer1SteamServerConnectFailure(Sender: TObject;
  const AData: SteamServerConnectFailure_t);
begin
  Log(Format('Server log-on failed (%d), retrying: %s',
    [Ord(AData.m_eResult), BoolToStr(AData.m_bStillRetrying, True)]));
end;

procedure TForm1.SteamGameServer1GSPolicyResponse(Sender: TObject;
  const AData: GSPolicyResponse_t);
begin
  Log('VAC secure: ' + BoolToStr(AData.m_bSecure <> 0, True));
end;

procedure TForm1.btnStopHostClick(Sender: TObject);
begin
  SteamGameServer1.Plugin.SetAdvertiseServerActive(False);
  SteamGameServer1.Plugin.LogOff;
  SteamAPI1.StopGameServer;                  // the client keeps running
end;
```

(`IPToStr` is your own helper turning a host-order `UInt32` into
`a.b.c.d`.)

* `LogOn(Token)` logs on with a persistent game server account (a token
  from Steam's game server account management) instead of anonymously; the
  server then keeps its SteamID and reputation.
* `SetBotPlayerCount`, `SetSpectatorPort`, `SetRegion`, `SetGameData`,
  `ClearAllKeyValues` describe the server further.
* `WasRestartRequested` - Steam says a newer server version exists
  (compare `GameServerVersion`).

### 28.2 Authenticating players

The player gets a session ticket ([7.3](#73-authentication-between-peers-or-with-a-game-server))
and sends it with the game's own messages; the server checks it:

```pascal
procedure TForm1.PlayerTicketArrived(const APlayer: TSteamID; const ATicket: TBytes);
begin
  case SteamGameServer1.Plugin.BeginAuthSession(@ATicket[0], Length(ATicket), APlayer) of
    k_EBeginAuthSessionResultOK:
      Log('Checking ' + APlayer.ToString + '...');      // -> OnValidateAuthTicketResponse
  else
    KickPlayer(APlayer, 'invalid ticket');
  end;
end;

procedure TForm1.SteamGameServer1ValidateAuthTicketResponse(Sender: TObject;
  const AData: ValidateAuthTicketResponse_t);
begin
  if AData.m_eAuthSessionResponse = k_EAuthSessionResponseOK then
  begin
    AdmitPlayer(AData.m_SteamID);
    SteamGameServer1.Plugin.BUpdateUserData(AData.m_SteamID, PlayerName(AData.m_SteamID), 0);
    SteamGameServerStats1.Plugin.RequestUserStats(AData.m_SteamID);   // chapter 29
  end
  else
    KickPlayer(AData.m_SteamID, 'authentication failed');
end;

procedure TForm1.PlayerLeft(const APlayer: TSteamID);
begin
  SteamGameServer1.Plugin.EndAuthSession(APlayer);                    // always
end;
```

* `BUpdateUserData(Player, Name, Score)` keeps the player list the server
  browser shows up to date.
* `UserHasLicenseForApp(Player, DlcAppID)` - after `BeginAuthSession` -
  whether the player owns a DLC.
* `OnGSClientApprove`, `OnGSClientDeny`, `OnGSClientKick` report Steam's
  own decisions (VAC, licences); kick on deny / kick.
* The server's own ticket (for peer verification the other way round):
  `GetAuthSessionTicket`.

### 28.3 Shared query port

With `GameServerQueryPort = 65535` the game owns the single UDP socket and
forwards Steam's query packets:

```pascal
// for every UDP packet your socket received that is not game traffic:
SteamGameServer1.Plugin.HandleIncomingPacket(@Packet[0], Len, FromIP, FromPort);

// every frame: send what Steam wants to send
var
  Out: array[0..1599] of Byte;
  IP: UInt32;
  Port: UInt16;
  N: Integer;
begin
  repeat
    N := SteamGameServer1.Plugin.GetNextOutgoingPacket(@Out[0], SizeOf(Out), IP, Port);
    if N > 0 then
      MySocket.SendTo(@Out[0], N, IP, Port);
  until N <= 0;
end;
```

### 28.4 Events

| Event | When |
|-------|------|
| `OnSteamServersConnected` / `OnSteamServerConnectFailure` / `OnSteamServersDisconnected` | The server's connection to Steam. |
| `OnGSPolicyResponse` | VAC status after log-on. |
| `OnValidateAuthTicketResponse` | Result of `BeginAuthSession`. |
| `OnGSClientApprove` / `OnGSClientDeny` / `OnGSClientKick` | Steam's decisions about a player. |
| `OnGSClientAchievementStatus`, `OnGSGameplayStats`, `OnGSClientGroupStatus`, `OnGSReputation` | Further server information. |
| `OnAssociateWithClanResult`, `OnComputeNewPlayerCompatibilityResult` | Call results. |

## 29. TSteamGameServerStats

<img src="../design/icons/svg/TSteamGameServerStats.svg" width="48" height="48" alt="TSteamGameServerStats palette icon">

Unit `Steamworks.Plugin.GameServerStats`, interface `ISteamGameServerStats`.
The server reads and writes the stats and achievements of its players -
those marked "set by game server" on the partner site. It works like
[TSteamUserStats](#8-tsteamuserstats---achievements-stats-and-leaderboards)
with an explicit player SteamID.

```pascal
procedure TForm1.SteamGameServerStats1GSStatsReceived(Sender: TObject;
  const AData: GSStatsReceived_t);
var
  Wins: Int32;
begin
  if (AData.m_eResult = k_EResultOK) and
     SteamGameServerStats1.Plugin.GetUserStatInt32(AData.m_steamIDUser, STAT_NUM_WINS, Wins) then
    Log(Format('%s has %d wins', [AData.m_steamIDUser.ToString, Wins]));
end;

procedure TForm1.MatchWonBy(const APlayer: TSteamID);
var
  Wins: Int32;
begin
  with SteamGameServerStats1.Plugin do
    if GetUserStatInt32(APlayer, STAT_NUM_WINS, Wins) then
    begin
      SetUserStatInt32(APlayer, STAT_NUM_WINS, Wins + 1);
      SetUserAchievement(APlayer, ACH_WIN_ONE_GAME);
      StoreUserStats(APlayer);                      // -> OnGSStatsStored
    end;
end;
```

`OnGSStatsUnloaded` comes when Steam drops a player's stats after he left.
Whether Spacewar's stats accept writes from a game server is Valve's
setting; with your own AppID mark them on the partner site.

## 30. The game server's copies of client interfaces

The game server has its own instance of seven client interfaces. Their
components have the **same methods and events** as the client components
(each is a descendant: `TSteamGameServerUtils` is a `TSteamUtils`), attach
when the server starts, and receive events only from the server's pipe:

| Icon | Component | Plug-in class | Like | Typical server use |
|------|-----------|---------------|------|--------------------|
| <img src="../design/icons/svg/TSteamGameServerUtils.svg" width="32" height="32" alt="TSteamGameServerUtils palette icon"> | `TSteamGameServerUtils` | `TSteamGameServerUtilsPlugin` | [TSteamUtils](#6-tsteamutils---client-utilities) | Server time, the server's AppID. |
| <img src="../design/icons/svg/TSteamGameServerNetworking.svg" width="32" height="32" alt="TSteamGameServerNetworking palette icon"> | `TSteamGameServerNetworking` | `TSteamGameServerNetworkingPlugin` | [TSteamNetworking](#26-tsteamnetworking---the-old-p2p-api-deprecated) | Old P2P packets to players. |
| <img src="../design/icons/svg/TSteamGameServerNetworkingSockets.svg" width="32" height="32" alt="TSteamGameServerNetworkingSockets palette icon"> | `TSteamGameServerNetworkingSockets` | `TSteamGameServerNetworkingSocketsPlugin` | [TSteamNetworkingSockets](#134-tsteamnetworkingsockets---connections) | Listen sockets players connect to. |
| <img src="../design/icons/svg/TSteamGameServerNetworkingMessages.svg" width="32" height="32" alt="TSteamGameServerNetworkingMessages palette icon"> | `TSteamGameServerNetworkingMessages` | `TSteamGameServerNetworkingMessagesPlugin` | [TSteamNetworkingMessages](#133-tsteamnetworkingmessages---messages-to-a-user) | Messages to players. |
| <img src="../design/icons/svg/TSteamGameServerHTTP.svg" width="32" height="32" alt="TSteamGameServerHTTP palette icon"> | `TSteamGameServerHTTP` | `TSteamGameServerHTTPPlugin` | [TSteamHTTP](#21-tsteamhttp---http-through-the-steam-client) | HTTP from the server. |
| <img src="../design/icons/svg/TSteamGameServerUGC.svg" width="32" height="32" alt="TSteamGameServerUGC palette icon"> | `TSteamGameServerUGC` | `TSteamGameServerUGCPlugin` | [TSteamUGC](#14-tsteamugc---steam-workshop) | Workshop items a dedicated server downloads. |
| <img src="../design/icons/svg/TSteamGameServerInventory.svg" width="32" height="32" alt="TSteamGameServerInventory palette icon"> | `TSteamGameServerInventory` | `TSteamGameServerInventoryPlugin` | [TSteamInventory](#18-tsteaminventory---steam-inventory-items) | Checking and granting players' items. |

`Steam.FindPlugin(TSteamNetworkingSocketsPlugin)` never returns the
server's copy; ask for `TSteamGameServerNetworkingSocketsPlugin`.

Example - a dedicated server accepting socket connections by IP:

```pascal
procedure TForm1.SteamAPI1GameServerStarted(Sender: TObject);
var
  Addr: SteamNetworkingIPAddr;
begin
  FillChar(Addr, SizeOf(Addr), 0);                // all zero = any address
  Addr.m_port := GAME_SOCKET_PORT;                // your own constant
  FListen := SteamGameServerNetworkingSockets1.Plugin.CreateListenSocketIP(@Addr, 0, nil);
end;

procedure TForm1.SteamGameServerNetworkingSockets1SteamNetConnectionStatusChangedCallback(
  Sender: TObject; const AData: SteamNetConnectionStatusChangedCallback_t);
begin
  if (AData.m_info.m_eState = k_ESteamNetworkingConnectionState_Connecting) and
     (AData.m_info.m_hListenSocket = FListen) then
    SteamGameServerNetworkingSockets1.Plugin.AcceptConnection(AData.m_hConn);
end;
```

Example - a dedicated server keeping Workshop maps up to date:

```pascal
SteamGameServerUGC1.Plugin.BInitWorkshopForGameServer(WorkshopDepotID,
  ExtractFilePath(ParamStr(0)) + 'workshop');
SteamGameServerUGC1.Plugin.DownloadItem(MapItemID, True);     // -> OnDownloadItemResult
```

## 31. TSteamMatchmakingServers - the server browser

<img src="../design/icons/svg/TSteamMatchmakingServers.svg" width="48" height="48" alt="TSteamMatchmakingServers palette icon">

Unit `Steamworks.Plugin.MatchmakingServers`, interface
`ISteamMatchmakingServers`. Lists of game servers (Internet, LAN, friends,
favourites, history, spectator) for an AppID, and per-server queries -
ping, players, rules. It finds the servers of chapters 27 - 30. (Lobbies
are [TSteamMatchmaking](#12-tsteammatchmaking---lobbies).)

Valve's interface uses C++ response objects instead of callbacks; the
plug-in builds them itself and turns every answer into an ordinary event,
delivered on the thread `TSteamAPI.Delivery` names, never inside Steam's
frame.

### 31.1 Listing servers

```pascal
procedure TForm1.btnRefreshClick(Sender: TObject);
begin
  lbServers.Items.Clear;
  FServers.Clear;                                    // TList<gameserveritem_t> (Generics.Collections)
  FList := SteamMatchmakingServers1.StartServerList(sltInternet, SteamAPI1.AppID,
    ['notfull', 'secure'], ['', '']);              // filter keys / values, same length
end;

procedure TForm1.SteamMatchmakingServers1ServerResponded(Sender: TObject;
  ARequest: HServerListRequest; AIndex: Integer; const AServer: gameserveritem_t);
begin
  FServers.Add(AServer);
  lbServers.Items.Add(Format('%s  %s  %d/%d  %d ms', [string(AServer.m_szServerName),
    string(AServer.m_szMap), AServer.m_nPlayers, AServer.m_nMaxPlayers, AServer.m_nPing]));
end;

procedure TForm1.SteamMatchmakingServers1ServerListComplete(Sender: TObject;
  ARequest: HServerListRequest; AResponse: EMatchMakingServerResponse);
begin
  Log(Format('%d servers', [SteamMatchmakingServers1.Plugin.GetServerCount(ARequest)]));
  // keep FList to refresh it (Plugin.RefreshQuery) or read it again
  // (Plugin.GetServerCount / GetServerDetails); release it when done:
  SteamMatchmakingServers1.StopServerList(FList);
end;
```

* Kinds: `sltInternet`, `sltLAN` (ignores filters), `sltFriends`,
  `sltFavorites`, `sltHistory`, `sltSpectator`.
* Filters are name / value pairs: `map`, `gamedir`, `dedicated`, `secure`,
  `notfull`, `hasplayers`, `noplayers`, `linux`, `gametagsand`,
  `gametagsnor`, `gamedataand`, `gamedataor`, `gamedatanor`, `and`, `or`,
  `nand`, `nor`, `addr`, `gameaddr`, `white`, `collapse_addr_hash`,
  `proxy`, `popularamongfriends` (`''` for filters without a value).
* `StopServerList` releases a list - always release it. After it, no more
  events arrive for that request.
* Servers behind Steam's relay network report a fake IP (169.254.x.x)
  that per-server queries cannot reach.

### 31.2 Querying one server

```pascal
procedure TForm1.lbServersDblClick(Sender: TObject);
var
  S: gameserveritem_t;
begin
  S := FServers[lbServers.ItemIndex];               // kept from OnServerResponded
  // IP in host order and the QUERY port, straight from m_NetAdr:
  FPing := SteamMatchmakingServers1.StartPing(S.m_NetAdr.m_unIP, S.m_NetAdr.m_usQueryPort);
  FPlayers := SteamMatchmakingServers1.StartPlayerDetails(S.m_NetAdr.m_unIP, S.m_NetAdr.m_usQueryPort);
  FRules := SteamMatchmakingServers1.StartServerRules(S.m_NetAdr.m_unIP, S.m_NetAdr.m_usQueryPort);
end;

procedure TForm1.SteamMatchmakingServers1PingResponded(Sender: TObject;
  AQuery: HServerQuery; const AServer: gameserveritem_t);
begin
  Log(Format('ping %d ms', [AServer.m_nPing]));
end;

procedure TForm1.SteamMatchmakingServers1Player(Sender: TObject; AQuery: HServerQuery;
  const AName: string; AScore: Integer; ATimePlayed: Single);
begin
  Log(Format('  %s  score %d  %.0f s', [AName, AScore, ATimePlayed]));
end;

procedure TForm1.SteamMatchmakingServers1Rule(Sender: TObject; AQuery: HServerQuery;
  const ARule, AValue: string);
begin
  Log(Format('  rule %s = %s', [ARule, AValue]));
end;

procedure TForm1.SteamMatchmakingServers1RulesComplete(Sender: TObject; AQuery: HServerQuery);
begin
  Log('rules complete');
end;
```

| Call | Events | Ends with |
|------|--------|-----------|
| `StartServerList(Kind, AppID, Keys, Values)` | `OnServerResponded` / `OnServerFailedToRespond` per server | `OnServerListComplete`; valid until `StopServerList` |
| `StartPing(IP, QueryPort)` | - | `OnPingResponded` or `OnPingFailed` |
| `StartPlayerDetails(IP, QueryPort)` | `OnPlayer` per player | `OnPlayersComplete` or `OnPlayersFailed` |
| `StartServerRules(IP, QueryPort)` | `OnRule` per rule | `OnRulesComplete` or `OnRulesFailed` |

`StartPing`, `StartPlayerDetails` and `StartServerRules` return a query id
(the events' `AQuery`) that `StopServerQuery` cancels. It is the plug-in's
own number, never reused - not Steam's handle, whose numbers Steam reuses.
Freeing the component stops its requests.

Testing your own listen server ([28.1](#281-hosting-a-listen-server)) from
the same program: `StartServerRules($7F000001, SteamAPI1.GameServerQueryPort)`
(127.0.0.1 and the query port) must return the `mode` rule set with `SetKeyValue`.

Without the component, give the plug-in a handler of type
`TSteamServerEventHandler`; `AEvent.Kind` (`sekServerResponded`,
`sekPingResponded`, `sekPlayerAdded`, `sekRuleResponded`, ...) says what
happened:

```pascal
Req := P.StartServerList(sltLAN, SteamAPI1.AppID, [], [], ServerEvent);
```

---

# Part V - Reference

## 32. Update modes and threads

Steam queues callbacks; something must read the queue regularly. Who reads
it, and where your handlers run, is configurable. The full guide, with
recipes for FMX, VCL, LCL, Castle Game Engine, Gorilla3D, Skia4Delphi and
custom loops, is [GameEngineIntegration.md](GameEngineIntegration.md).

| `UpdateMode` | Who reads | Use |
|--------------|-----------|-----|
| `sumTimer` (default) | The framework timer, every `CallbackInterval` ms, on the main thread. | Ordinary form applications. |
| `sumManual` | Your loop calls `Update` (= `RunCallbacks`). | Game loops, console programs. |
| `sumThread` | A worker thread, every `CallbackInterval` ms. | Games that want Steam I/O off the game thread. |

| `Delivery` (with `sumThread`) | Where handlers run |
|-------------------------------|--------------------|
| `sdMainThread` (default) | The main thread (queued). Handler code needs no change. |
| `sdOnUpdate` | Inside your `Update` call, on your game thread. |
| `sdPumpThread` | On the worker. **Handlers must not touch UI or engine objects.** |

```pascal
// a game loop that owns the frame
SteamAPI1.SetUpdateMode(sumThread, sdOnUpdate, 16);
...
procedure TGame.Frame;
begin
  SteamAPI1.Update;           // handlers run here, on the game thread
  SteamInput1.Plugin.RunFrame(False);
  UpdateWorld;
  Render;
end;
```

Rules (details in GameEngineIntegration.md, section 5):

1. Steam **calls** are allowed from any thread; only reading the queue is
   single-threaded, and the library guarantees that.
2. With `sdPumpThread`, hand data to the UI with `TThread.Queue`, never
   `TThread.Synchronize` (it can deadlock during shutdown). This includes
   `TSteamAPI`'s own `OnLog`, `OnWarning`, `OnCallback`, `OnSteamShutdown`
   and `OnShutdown`.
3. Call `Active :=`, `Open`, `Close`, `SetUpdateMode` from the delivery
   thread (main thread, or your game thread with `sdOnUpdate`), and
   `SetUpdateMode` never from a handler.
4. Objects that subscribed must call `Steam.Dispatcher.RemoveOwner(Self)`
   in their destructor.
5. FPC on Linux / macOS: `cthreads` first in the program's `uses`, or no
   worker can start (the library then falls back to reading in `Update`).
6. Keep handlers short.

Choosing the interval: 33 ms (default, about 30 reads per second) is
plenty; 16 ms matches a 60 Hz frame; 100 ms is Valve's minimum
recommendation.

## 33. Errors, logging and diagnostics

| Situation | What happens | What to do |
|-----------|--------------|------------|
| Steam does not start | Without `OnInitFailed`: `Active := True` shows the error in a message box and leaves `Active = False`; it never raises. `Open` returns `False` silently. | Assign `OnInitFailed` or use `Open`; read `Steam.LastError`. Result 2 = the Steam client is not running. |
| A handler raises | The exception is shown (main thread) or logged (worker); callbacks keep flowing. | Fix the handler. |
| Payload size mismatch | `ESteamworksError` - the event is not raised with a wrong record. | Report it: the binding and the loaded Steam library disagree. |
| Missing export | Logged once at start-up; calling the method raises `ESteamworksError` naming it. | Use the SDK 1.65 redistributable; check `Assigned(Plugin.Flat.Xxx)`. |
| Failed call result | No event; logged as a warning. In an `...Async` handler `AIOFailure = True`. | Always check `AIOFailure`. |

Logging every step costs nothing and answers most questions:

```pascal
SteamAPI1.OnLog := SteamLog;          // see 5.7
SteamAPI1.OnWarning := SteamWarning;  // Steam's own text, with -debug_steamapi
SteamAPI1.OnCallback := SteamCallback;

procedure TForm1.SteamCallback(Sender: TObject; const AData: TSteamCallbackData);
begin
  Log(Format('callback %d (%s) %d bytes%s', [AData.CallbackID,
    SteamCallbackGroupName(AData.CallbackID), AData.Size,
    IfThen(AData.IsCallResult, ' [call result]', '')]));   // IfThen: StrUtils
end;
```

The core logs the platform it runs on (including Wine / Proton and Steam's
Linux runtime), the Steam library it loaded, the interface versions it
detected and every export missing from the library.

## 34. Shipping checklist

* Replace **480** with your own AppID everywhere (the `AppID` property, any
  `steam://` links, server browser and Workshop calls).
* Turn **off** `SetAppIdEnvironment`, and do not ship `steam_appid.txt`
  (dedicated servers excepted).
* Turn **on** `RestartIfNecessary` so a copy started outside Steam is
  relaunched through it.
* Ship the Steam library for each platform next to the executable (inside
  the bundle on macOS). It may be redistributed with your game under the
  Steamworks agreement.
* Put the Steam Input action manifest in the depot and select it on the
  partner site; remove `SetInputActionManifestFilePath`.
* Configure on the partner site what the game uses: stats and
  achievements, leaderboards, Steam Cloud quota, Workshop, Inventory item
  definitions, rich presence localisation, timeline icons - and publish.
* Remove test calls (`ResetAllStats`, `ClearAchievement`, `GenerateItems`).

## 35. Troubleshooting

| Symptom | Cause and fix |
|---------|---------------|
| "Steam did not start", result 2 | The Steam client is not running or not logged in. |
| "This build needs ... steam_api64.dll ... next to the executable" | Copy the library for that platform next to the executable ([3.3](#33-getting-the-steam-library-next-to-the-executable-delphi)). |
| `F2613 Unit 'Steamworks.Types' not found` | The runtime packages were not built for the target platform (a new project starts on Win32). Build `Steamworks` and `SteamworksFMX` / `SteamworksVCL` for it. |
| A plug-in component's `Plugin` is `nil` | Steam is not running yet; make calls in `OnInitialized` or later. |
| Events never fire | `SteamAPI` not set and the owner holds no / several `TSteamAPI`; or `UpdateMode = sumManual` and nobody calls `Update`. |
| `OnLobbyMatchList` fires twice | Steam posts it as call result and callback - use `RequestLobbyListAsync` ([12.1](#121-find-or-create-a-lobby)). |
| Lobbies of strangers on 480 | Everybody tests on 480 - filter on a key of your own. |
| Achievement icon is 0 | Not loaded yet (wait for `OnUserAchievementIconFetched`) or no icon; after changing icons on the partner site, publish and restart the Steam client. |
| `TriggerScreenshot` / F12 do nothing | No overlay in the process (started from the IDE). Use `SteamFormToRGB` + `WriteScreenshot` ([16.1](#161-a-screenshot-that-always-works)). |
| The overlay, store page or binding panel does not appear | Same cause - check `TSteamUtils.Plugin.IsOverlayEnabled`; start the game from Steam. |
| No controller in Steam Input / actions stay 0 | Enable Steam Input for the game in the Steam client (Xbox / generic pads); handles are 0 until the manifest loads; the manifest must not contain `//` comments. See [SteamInputMapping.md](SteamInputMapping.md). |
| Cloud writes fail | Cloud off for the account or the app, or quota full - `IsCloudEnabledForAccount`, `IsCloudEnabledForApp`, `GetQuota`. |
| Steam > Exit closes the window twice (Windows) | Normal; make `FormClose` tolerate it. |
| Crash reports / "Broken pipe" after Steam exits (Linux) | Keep `ShutdownOnSteamExit` on (default). |
| FMX window all white under Proton | See README "Known issues" and [Proton.md](Proton.md) (`FmxWineCanvas`). |
| "Optional export SteamAPI_ISteamUtils_IsRunningOnSteamDeck not found" | A debug line: SDK 1.65 removed that function. |

More: README, "Known issues (that are not really issues)";
[Install-Delphi.md](Install-Delphi.md) and
[Install-Lazarus-FPC.md](Install-Lazarus-FPC.md), "Things that look wrong
but are not".

---

# Appendices

## Appendix A: Component, unit and interface index

| Icon | Component | Unit | Steam interface | Chapter |
|------|-----------|------|-----------------|---------|
| <img src="../design/icons/svg/TSteamAPI.svg" width="24" height="24" alt="TSteamAPI palette icon"> | `TSteamAPI` | `Steamworks.FMX` / `.VCL` / `.LCL` | (core: SteamAPI, ISteamClient) | [5](#5-tsteamapi---the-root-component) |
| <img src="../design/icons/svg/TSteamUtils.svg" width="24" height="24" alt="TSteamUtils palette icon"> | `TSteamUtils` | `Steamworks.Plugin.Utils` | ISteamUtils | [6](#6-tsteamutils---client-utilities) |
| <img src="../design/icons/svg/TSteamUser.svg" width="24" height="24" alt="TSteamUser palette icon"> | `TSteamUser` | `Steamworks.Plugin.User` | ISteamUser | [7](#7-tsteamuser---the-logged-on-user) |
| <img src="../design/icons/svg/TSteamUserStats.svg" width="24" height="24" alt="TSteamUserStats palette icon"> | `TSteamUserStats` | `Steamworks.Plugin.UserStats` | ISteamUserStats | [8](#8-tsteamuserstats---achievements-stats-and-leaderboards) |
| <img src="../design/icons/svg/TSteamRemoteStorage.svg" width="24" height="24" alt="TSteamRemoteStorage palette icon"> | `TSteamRemoteStorage` | `Steamworks.Plugin.RemoteStorage` | ISteamRemoteStorage | [9](#9-tsteamremotestorage---steam-cloud-saves) |
| <img src="../design/icons/svg/TSteamFriends.svg" width="24" height="24" alt="TSteamFriends palette icon"> | `TSteamFriends` | `Steamworks.Plugin.Friends` | ISteamFriends | [10](#10-tsteamfriends---friends-avatars-overlay-rich-presence) |
| <img src="../design/icons/svg/TSteamApps.svg" width="24" height="24" alt="TSteamApps palette icon"> | `TSteamApps` | `Steamworks.Plugin.Apps` | ISteamApps | [11](#11-tsteamapps---ownership-dlc-language-betas) |
| <img src="../design/icons/svg/TSteamMatchmaking.svg" width="24" height="24" alt="TSteamMatchmaking palette icon"> | `TSteamMatchmaking` | `Steamworks.Plugin.Matchmaking` | ISteamMatchmaking | [12](#12-tsteammatchmaking---lobbies) |
| <img src="../design/icons/svg/TSteamNetworkingUtils.svg" width="24" height="24" alt="TSteamNetworkingUtils palette icon"> | `TSteamNetworkingUtils` | `Steamworks.Plugin.NetworkingUtils` | ISteamNetworkingUtils | [13.2](#132-tsteamnetworkingutils---relay-network-ping-settings) |
| <img src="../design/icons/svg/TSteamNetworkingMessages.svg" width="24" height="24" alt="TSteamNetworkingMessages palette icon"> | `TSteamNetworkingMessages` | `Steamworks.Plugin.NetworkingMessages` | ISteamNetworkingMessages | [13.3](#133-tsteamnetworkingmessages---messages-to-a-user) |
| <img src="../design/icons/svg/TSteamNetworkingSockets.svg" width="24" height="24" alt="TSteamNetworkingSockets palette icon"> | `TSteamNetworkingSockets` | `Steamworks.Plugin.NetworkingSockets` | ISteamNetworkingSockets | [13.4](#134-tsteamnetworkingsockets---connections) |
| <img src="../design/icons/svg/TSteamUGC.svg" width="24" height="24" alt="TSteamUGC palette icon"> | `TSteamUGC` | `Steamworks.Plugin.UGC` | ISteamUGC | [14](#14-tsteamugc---steam-workshop) |
| <img src="../design/icons/svg/TSteamInput.svg" width="24" height="24" alt="TSteamInput palette icon"> | `TSteamInput` | `Steamworks.Plugin.Input` | ISteamInput | [15](#15-tsteaminput---controllers) |
| <img src="../design/icons/svg/TSteamScreenshots.svg" width="24" height="24" alt="TSteamScreenshots palette icon"> | `TSteamScreenshots` | `Steamworks.Plugin.Screenshots` | ISteamScreenshots | [16](#16-tsteamscreenshots---the-screenshot-library) |
| <img src="../design/icons/svg/TSteamTimeline.svg" width="24" height="24" alt="TSteamTimeline palette icon"> | `TSteamTimeline` | `Steamworks.Plugin.Timeline` | ISteamTimeline | [17](#17-tsteamtimeline---game-recording-markers) |
| <img src="../design/icons/svg/TSteamInventory.svg" width="24" height="24" alt="TSteamInventory palette icon"> | `TSteamInventory` | `Steamworks.Plugin.Inventory` | ISteamInventory | [18](#18-tsteaminventory---steam-inventory-items) |
| <img src="../design/icons/svg/TSteamRemotePlay.svg" width="24" height="24" alt="TSteamRemotePlay palette icon"> | `TSteamRemotePlay` | `Steamworks.Plugin.RemotePlay` | ISteamRemotePlay | [19](#19-tsteamremoteplay---remote-play-and-remote-play-together) |
| <img src="../design/icons/svg/TSteamParties.svg" width="24" height="24" alt="TSteamParties palette icon"> | `TSteamParties` | `Steamworks.Plugin.Parties` | ISteamParties | [20](#20-tsteamparties---party-beacons) |
| <img src="../design/icons/svg/TSteamHTTP.svg" width="24" height="24" alt="TSteamHTTP palette icon"> | `TSteamHTTP` | `Steamworks.Plugin.HTTP` | ISteamHTTP | [21](#21-tsteamhttp---http-through-the-steam-client) |
| <img src="../design/icons/svg/TSteamHTMLSurface.svg" width="24" height="24" alt="TSteamHTMLSurface palette icon"> | `TSteamHTMLSurface` | `Steamworks.Plugin.HTMLSurface` | ISteamHTMLSurface | [22](#22-tsteamhtmlsurface---an-off-screen-browser) |
| <img src="../design/icons/svg/TSteamMusic.svg" width="24" height="24" alt="TSteamMusic palette icon"> | `TSteamMusic` | `Steamworks.Plugin.Music` | ISteamMusic | [23](#23-tsteammusic---the-steam-music-player) |
| <img src="../design/icons/svg/TSteamVideo.svg" width="24" height="24" alt="TSteamVideo palette icon"> | `TSteamVideo` | `Steamworks.Plugin.Video` | ISteamVideo | [24](#24-tsteamvideo---broadcasting-state) |
| <img src="../design/icons/svg/TSteamParentalSettings.svg" width="24" height="24" alt="TSteamParentalSettings palette icon"> | `TSteamParentalSettings` | `Steamworks.Plugin.ParentalSettings` | ISteamParentalSettings | [25](#25-tsteamparentalsettings---family-view) |
| <img src="../design/icons/svg/TSteamNetworking.svg" width="24" height="24" alt="TSteamNetworking palette icon"> | `TSteamNetworking` | `Steamworks.Plugin.Networking` | ISteamNetworking (deprecated) | [26](#26-tsteamnetworking---the-old-p2p-api-deprecated) |
| <img src="../design/icons/svg/TSteamGameServer.svg" width="24" height="24" alt="TSteamGameServer palette icon"> | `TSteamGameServer` | `Steamworks.Plugin.GameServer` | ISteamGameServer | [28](#28-tsteamgameserver) |
| <img src="../design/icons/svg/TSteamGameServerStats.svg" width="24" height="24" alt="TSteamGameServerStats palette icon"> | `TSteamGameServerStats` | `Steamworks.Plugin.GameServerStats` | ISteamGameServerStats | [29](#29-tsteamgameserverstats) |
| <img src="../design/icons/svg/ServerBadge.svg" width="24" height="24" alt="Server badge"> | `TSteamGameServerUtils`, `...Networking`, `...NetworkingSockets`, `...NetworkingMessages`, `...HTTP`, `...UGC`, `...Inventory` | the matching client unit | the server's copy | [30](#30-the-game-servers-copies-of-client-interfaces) |
| <img src="../design/icons/svg/TSteamMatchmakingServers.svg" width="24" height="24" alt="TSteamMatchmakingServers palette icon"> | `TSteamMatchmakingServers` | `Steamworks.Plugin.MatchmakingServers` | ISteamMatchmakingServers | [31](#31-tsteammatchmakingservers---the-server-browser) |

Not bound: `ISteamController` (deprecated by Valve - use `TSteamInput`);
`ISteamGameSearch` and `ISteamMusicRemote` (removed from SDK 1.65).

Core units you may `use` directly:

| Unit | Contents |
|------|----------|
| `Steamworks.Types` | `TSteamID`, basic handle types, `SteamTimeToLocal`, `SteamCallbackGroupName`. |
| `Steamworks.SDKTypes` | Every SDK enum, record and `..._k_iCallback` constant (generated). |
| `Steamworks.Callbacks` | `TSteamCallbackData`, `TSteamCallbackDispatcher`, handler types. |
| `Steamworks.Core` | `TSteamworks` and the `Steam` singleton, `TSteamPlugin`, update modes, log levels. |
| `Steamworks.Components` | `TCustomSteamAPI`, `TSteamPluginComponent`, server modes. |
| `Steamworks.API` | `TSteamLib` - the loaded library and its flat exports. |

## Appendix B: Spacewar (AppID 480) as a test bed

Spacewar is the Steamworks example game. Valve configured AppID 480 so that
every account owns it and every developer can test against it. That makes
it ideal for trying this manual's examples - with some care.

**Setting it up in a program:**

```pascal
SteamAPI1.AppID := 480;
SteamAPI1.SetAppIdEnvironment := True;   // or steam_appid.txt containing 480
SteamAPI1.RestartIfNecessary := False;   // never with 480
SteamAPI1.Active := True;
```

While the program runs, the Steam client shows you as playing "Spacewar".

**What Valve has configured** (as used in this manual; Valve may change
it - list it at run time to be sure):

| Feature | Configuration |
|---------|---------------|
| Stats | `NumGames`, `NumWins`, `NumLosses` (int); `FeetTraveled`, `MaxFeetTraveled` (float); `AverageSpeed` (average rate). |
| Achievements | `ACH_WIN_ONE_GAME`, `ACH_WIN_100_GAMES`, `ACH_TRAVEL_FAR_ACCUM`, `ACH_TRAVEL_FAR_SINGLE` - list them with [8.2](#82-listing-every-achievement). |
| Leaderboards | `Quickest Win`, `Feet Traveled`. |
| Inventory | Valve's sample item definitions (a timed drop generator and ship items) - list them with [18.2](#182-item-definitions). |
| Workshop | Enabled; publicly shared with all developers. |
| Game server | Spacewar's own server uses mod dir `spacewar`, product `SteamworksExample`. |

**Things to keep in mind:**

* Everything on 480 is **shared with every developer**: lobbies (filter on
  a key of your own), leaderboards (create boards with unique names),
  Workshop items (publish privately, delete afterwards), servers in the
  server browser.
* Achievements and stats you set are real for your account's Spacewar
  progress; reset them with `ResetAllStats(True)` + `StoreStats`.
* Partner-site settings of 480 (Cloud quota, rich presence tokens, Steam
  Input configuration, timeline icons) are Valve's; you cannot change them.
  Use `status` for rich presence and `SetInputActionManifestFilePath` for
  Steam Input.
* `GenerateItems` and other developer-only calls fail on 480.
* `GetAppInstallDir(480)` answers only if Spacewar itself is installed.
* The repository's own project AppID is **2275430**; VirtualGamepad uses
  **4108310**, VirtualGamepadLCL uses **480**.

When you move to your own AppID, replace 480, follow the
[shipping checklist](#34-shipping-checklist), and set up on the partner
site whatever features you used here.
