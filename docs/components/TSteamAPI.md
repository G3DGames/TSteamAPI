# TSteamAPI - the root component

The non-visual component that runs Steam for your program: it loads the
Steam library, optionally relaunches the game through Steam, initialises
SteamAPI and every linked plug-in, keeps callbacks flowing, and shuts it all
down again.

| Framework | Unit | Package (Delphi) | Timer used |
|-----------|------|------------------|------------|
| FireMonkey | `Steamworks.FMX` | `SteamworksFMX` / `dclSteamworksFMX` | FMX `TTimer` |
| VCL | `Steamworks.VCL` | `SteamworksVCL` / `dclSteamworksVCL` | VCL `TTimer` |
| LCL (Lazarus) | `Steamworks.LCL` | `SteamworksLCL.lpk` (run + design time) | LCL `TTimer` |

All three are the same class name with the same properties and events; they
differ only in the timer, how an exception is shown, and how the
application is ended. Everything else lives in the framework-free base
`TCustomSteamAPI` (`Steamworks.Components`), so it behaves identically
everywhere.

**One per application.** Steam is process-wide, so a second `TSteamAPI` at
run time raises `ESteamworksError`. (Several on different forms at design
time is fine.)

## Contents

* [Quick start](#quick-start)
* [Properties](#properties)
* [Events](#events)
* [Methods](#methods)
* [Life cycle](#life-cycle)
* [Plug-in components](#plug-in-components)
* [Images: SteamImageToBitmap](#images-steamimagetobitmap)
* [Errors](#errors)
* [Threads](#threads)

## Quick start

At design time: drop a `TSteamAPI` and, for example, a `TSteamFriends` on
the main form, set `AppID`, set `Active` to `True`. Or in code:

```pascal
uses Steamworks.Core, Steamworks.SDKTypes, Steamworks.FMX,  // or .VCL / .LCL
  Steamworks.Plugin.Friends;

procedure TMainForm.FormCreate(Sender: TObject);
begin
  FSteam := TSteamAPI.Create(Self);
  FSteam.AppID := 2275430;                   // your AppID
  {$ifdef DEBUG}
  FSteam.SetAppIdEnvironment := True;        // development: no steam_appid.txt
  {$else}
  FSteam.RestartIfNecessary := True;         // release: relaunch through Steam
  {$endif}
  FSteam.OnInitFailed := SteamInitFailed;
  FFriends := TSteamFriends.Create(Self);
  FFriends.SteamAPI := FSteam;
  FFriends.OnPersonaStateChange := FriendChanged;
  FSteam.Active := True;
end;
```

## Properties

All published (Object Inspector) unless noted.

| Property | Type / default | Meaning |
|----------|----------------|---------|
| `Active` | `Boolean`, `False` | Starts / stops Steam. At design time only stored. A failed start leaves it `False` (see [Errors](#errors)). |
| `AppID` | `Cardinal`, 0 | Your Steam AppID. Needed by `RestartIfNecessary` and `SetAppIdEnvironment`. |
| `SetAppIdEnvironment` | `Boolean`, `False` | Sets the `SteamAppId` / `SteamGameId` environment variables before loading Steam, so a development build needs no `steam_appid.txt`. **Never in release builds** - Steam supplies the AppID when it starts the game. |
| `RestartIfNecessary` | `Boolean`, `False` | Calls `SteamAPI_RestartAppIfNecessary` first: a game started outside Steam is relaunched through Steam and this copy ends (`OnRestartRequired`). Recommended for release builds. |
| `LibraryPath` | `string`, '' | Full path of the Steam library; empty = the platform's file name, searched next to the executable (and in the macOS bundle) first. |
| `InitMode` | `TSteamInitMode`, `simAuto` | How SteamAPI is initialised: `simAuto` (flat init when available), `simFlat`, `simVersioned` (only the interface versions the linked plug-ins use), `simLegacy` (pre-1.59 libraries). |
| `UpdateMode` | `TSteamUpdateMode`, `sumTimer` | Who reads Steam's callback queue: the framework timer (`sumTimer`), a worker thread (`sumThread`) or your own loop calling `Update` (`sumManual`). See [GameEngineIntegration.md](../GameEngineIntegration.md). |
| `Delivery` | `TSteamDelivery`, `sdMainThread` | With `sumThread`: where events run - main thread (`sdMainThread`), inside `Update` (`sdOnUpdate`) or on the worker (`sdPumpThread`). |
| `CallbackInterval` | `Integer`, 33 | Timer interval in ms (`sumTimer`; 0 = no timer) or worker period (`sumThread`; 0 = 1 ms). |
| `InstallWarningHook` | `Boolean`, `True` | Routes Steam's debug output to `OnWarning` (Steam only produces it when the game runs with `-debug_steamapi`). |
| `ShutdownOnSteamExit` | `Boolean`, `True` | Shuts SteamAPI down (not the app) as soon as the Steam client exits, right after `OnSteamShutdown`. Avoids crashes inside Steam on Linux / macOS. |
| `QuitOnSteamShutdown` | `Boolean`, `False` | Also ends the application when the Steam client exits. |
| `Steam` | `TSteamworks` (public, read-only) | The core singleton: plug-ins (`Steam.FindPlugin`), versions, dispatcher. |
| `IsRunning` | `Boolean` (public, read-only) | `True` while SteamAPI is initialised. |

## Events

| Event | Signature | When |
|-------|-----------|------|
| `OnInitialized` | `TNotifyEvent` | Steam started; plug-in components are attached already. |
| `OnInitFailed` | `procedure(Sender: TObject; AResult: Integer; const AMessage: string)` | Steam could not start. `AResult` is the `ESteamAPIInitResult` value (2 = Steam not running), `AMessage` Steam's own text. Assigning it suppresses the automatic message box. |
| `OnShutdown` | `TNotifyEvent` | SteamAPI was shut down (by `Close`, `Active := False`, destruction, or `ShutdownOnSteamExit`). |
| `OnSteamShutdown` | `TNotifyEvent` | The Steam client is exiting (callback 704). Save now; Steam calls still work inside this handler. Raised once per session. |
| `OnRestartRequired` | `procedure(Sender: TObject; var ATerminate: Boolean)` | `RestartIfNecessary`: Steam is relaunching the game. Leave `ATerminate` `True` to end this copy. |
| `OnLog` | `procedure(Sender: TObject; ALevel: TSteamLogLevel; const AMessage: string)` | Diagnostic messages from the core and plug-ins (`sllDebug` .. `sllError`). Log them - they say exactly what happened. |
| `OnWarning` | `procedure(Sender: TObject; ASeverity: Integer; const AText: string)` | Steam's debug output (0 = message, 1 = warning). |
| `OnCallback` | `procedure(Sender: TObject; const AData: TSteamCallbackData)` | Every callback and call result, before the plug-in components get it - for diagnostics. |

## Methods

| Method | Meaning |
|--------|---------|
| `Open: Boolean` | `Active := True` without any message box; returns whether Steam runs. |
| `Close` | `Active := False`. Safe to call more than once and from an event handler. |
| `Update` / `RunCallbacks` | Reads and / or delivers callbacks now (what exactly depends on `UpdateMode`). Call per frame in `sumManual`, or in `sumThread` + `sdOnUpdate`. |
| `SetUpdateMode(Mode, Delivery, IntervalMs = -1)` | Sets `UpdateMode`, `Delivery` and (when >= 0) `CallbackInterval` in one call; applies at once while running. Main thread only, never from an event handler. |

## Life cycle

`Active := True` (or `Open`):

1. Pushes the settings to the core (`Steam`).
2. With `RestartIfNecessary`: asks Steam; if it relaunches the game,
   `OnRestartRequired` fires and the application ends.
3. Loads the Steam library (logs the platform, the file and its SDK
   generation) and initialises SteamAPI.
4. Initialises every linked plug-in, in dependency order.
5. Starts the timer (`sumTimer`) or the worker (`sumThread`).
6. Attaches the plug-in components (their events become live).
7. `OnInitialized`.

`Active := False` / `Close` / destroying the form reverses it: stops the
timer / worker, detaches the components, finalises the plug-ins,
`SteamAPI_Shutdown`, `OnShutdown`. After a shutdown (including one caused
by the Steam client exiting) `Open` starts Steam again.

Do not free the `TSteamAPI` inside one of its own (or a plug-in component's)
events - call `Close` there and free it later.

## Plug-in components

`TSteamUtils`, `TSteamUser`, `TSteamFriends`, `TSteamApps`,
`TSteamUserStats` (more as the binding grows) each wrap one Steam interface.
Link them through their `SteamAPI` property; at run time a component whose
owner holds exactly one `TSteamAPI` links itself. Only the plug-ins you
drop or `use` are linked into the program. See [README.md](README.md).

## Images: SteamImageToBitmap

Each framework unit has

```pascal
function SteamImageToBitmap(AImage: Integer; ABitmap: TBitmap): Boolean;
```

for its own `TBitmap`. `AImage` is a Steam image handle (avatar or
achievement icon). It returns `False` for 0 (none) and -1 (still loading -
wait for `TSteamFriends.OnAvatarImageLoaded` /
`TSteamUserStats.OnUserAchievementIconFetched`).

## Errors

* **Steam does not start.** With no `OnInitFailed` handler, `Active := True`
  shows an `ESteamworksError` with Steam's message the framework's way (a
  message box) and leaves `Active` `False`. It is **never raised**, so a
  failed start in `FormCreate` or from the form file does not end the
  program. Assign `OnInitFailed`, or use `Open`, to handle it quietly.
* **An event handler raises.** The exception is shown (main thread) or
  logged (worker thread with `sdPumpThread`), and callbacks keep flowing.
* **Payload size mismatch.** A plug-in component event whose record does
  not match Steam's payload size raises `ESteamworksError` instead of
  handing over a wrong record.

## Threads

With the default `UpdateMode = sumTimer` every event runs on the main
thread. With `sumThread` the reading moves to a worker; `Delivery` decides
where events run. With `sdPumpThread`, **this component's own events**
(`OnLog`, `OnWarning`, `OnCallback`, `OnSteamShutdown`, `OnShutdown`) fire on
the worker too; only its message boxes and the application exit are moved to
the main thread. Read [GameEngineIntegration.md](../GameEngineIntegration.md)
before choosing `sdPumpThread`.
