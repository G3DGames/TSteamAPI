# TSteamGameServerStats and TSteamGameServerStatsPlugin (ISteamGameServerStats)

> **Generated** by `tools/gen_docs.py` from `lib/plugins/Steamworks.Plugin.GameServerStats.pas` - do not edit.
> Hand-written text: `tools/doc_extras/GameServerStats.md`. Steam's own descriptions are Valve's
> SDK comments, as in the generated units.

Unit: `Steamworks.Plugin.GameServerStats` - linking it (a `uses` entry, or dropping a `TSteamGameServerStats`) enables the
plug-in. Steam interface: `ISteamGameServerStats` (SDK 1.65).

## Overview

Stats and achievements of the players on a game server
(`ISteamGameServerStats`): the server reads and writes the stats Valve
marks as "set by GS" on the partner site. A game-server component - it
attaches when the game server starts (see TSteamGameServer).

```pascal
// a player joined (authenticated): load his stats
SteamGameServerStats1.Plugin.RequestUserStats(PlayerID);   // -> OnGSStatsReceived

procedure TForm1.SteamGameServerStats1GSStatsReceived(Sender: TObject;
  const AData: GSStatsReceived_t);
var
  Kills: Int32;
begin
  if (AData.m_eResult = k_EResultOK) and
     SteamGameServerStats1.Plugin.GetUserStatInt32(AData.m_steamIDUser, 'kills', Kills) then
    ...
end;
```

`StoreUserStats` sends the changes (`OnGSStatsStored`);
`OnGSStatsUnloaded` comes when Steam drops a player's stats after he
left.

## Contents

* [The component: TSteamGameServerStats](#the-component-tsteamgameserverstats)
  * [Events (3)](#events)
* [The plug-in: TSteamGameServerStatsPlugin](#the-plug-in-tsteamgameserverstatsplugin)
  * [Methods](#methods)
  * [Async methods](#async-methods)
  * [Properties](#properties)
* [Payload records](#payload-records)

## The component: TSteamGameServerStats

ISteamGameServerStats component: drop it next to a TSteamAPI (linked automatically at run time when the owner has exactly one, otherwise set SteamAPI). Its events are the ISteamGameServerStats callbacks; call the interface through `Plugin`.

| Member | Kind | Description |
|--------|------|-------------|
| `SteamAPI` | published property | The `TSteamAPI` this component belongs to. At run time a component whose owner has exactly one `TSteamAPI` links itself. |
| `Plugin` | public property | The `TSteamGameServerStatsPlugin` for calls; `nil` while Steam is not running. |
| `Attached` | public property | `True` while the events are subscribed (Steam running, `SteamAPI` set). |
| `Attach` / `Detach` | public methods | Subscribe / remove the events by hand (normally automatic). |

Events run on the thread chosen by the root's `UpdateMode` / `Delivery` - the main
thread by default (see [GameEngineIntegration.md](../GameEngineIntegration.md)). Each event
checks that Steam's payload size equals the Pascal record's; a mismatch raises
`ESteamworksError` instead of handing over a wrong record. Call results of the same
struct reach the event too (unless an `...Async` call claimed them); failed call results
raise no event and are logged as warnings.

### Events

| Event | Callback | Payload | Description |
|-------|----------|---------|-------------|
| `OnGSStatsUnloaded` | 1108 | [`GSStatsUnloaded_t`](#gsstatsunloaded_t) | Callback indicating that a user's stats have been unloaded. Call RequestUserStats again to access stats for this user. |
| `OnGSStatsReceived` | 1800 | [`GSStatsReceived_t`](#gsstatsreceived_t) | called when the latests stats and achievements have been received from the server. |
| `OnGSStatsStored` | 1801 | [`GSStatsStored_t`](#gsstatsstored_t) | result of a request to store the user stats for a game. |

Handler signature (the IDE generates it when you double-click the event):

```pascal
procedure TForm1.SteamGameServerStats1GSStatsUnloaded(Sender: TObject; const AData: GSStatsUnloaded_t);
```

## The plug-in: TSteamGameServerStatsPlugin

ISteamGameServerStats plug-in. Registered by linking the unit; find it with @code(Steam.FindPlugin(TSteamGameServerStatsPlugin)).

Reach it through the component (`SteamGameServerStats1.Plugin`) or the core:

```pascal
P := TSteamGameServerStatsPlugin(Steam.FindPlugin(TSteamGameServerStatsPlugin));   // Delphi also: Steam.Plugin<TSteamGameServerStatsPlugin>
if P <> nil then ...
```

Every flat export is bound as optional: calling a method whose export the loaded
Steam library lacks raises `ESteamworksError` naming the export (`Assigned(P.Flat.Xxx)`
tells beforehand). Method names follow Valve's flat API (`GetStatInt32`, not the C++
overload `GetStat`); `const char*` parameters are `string`, 64-bit Steam ids `TSteamID`,
single out-values `var`; buffers and NULL-able pointers stay `Pointer`.

### Methods

| Method | Summary |
|--------|---------|
| [`IsGameServer`](#isgameserver) | `True`: a game-server plug-in (created by TSteamworks.StartGameServer). |
| [`RequestUserStats`](#requestuserstats) | downloads stats for the user returns a GSStatsReceived_t callback when completed if the user has no stats, GSStatsReceived_t.m_eResult will be set to ... |
| [`GetUserStatInt32`](#getuserstatint32) | requests stat information for a user, usable after a successful call to RequestUserStats(). |
| [`GetUserStatFloat`](#getuserstatfloat) | requests stat information for a user, usable after a successful call to RequestUserStats(). |
| [`GetUserAchievement`](#getuserachievement) | Wraps `SteamAPI_ISteamGameServerStats_GetUserAchievement`. |
| [`SetUserStatInt32`](#setuserstatint32) | Wraps `SteamAPI_ISteamGameServerStats_SetUserStatInt32`. |
| [`SetUserStatFloat`](#setuserstatfloat) | Wraps `SteamAPI_ISteamGameServerStats_SetUserStatFloat`. |
| [`UpdateUserAvgRateStat`](#updateuseravgratestat) | Wraps `SteamAPI_ISteamGameServerStats_UpdateUserAvgRateStat`. |
| [`SetUserAchievement`](#setuserachievement) | Wraps `SteamAPI_ISteamGameServerStats_SetUserAchievement`. |
| [`ClearUserAchievement`](#clearuserachievement) | Wraps `SteamAPI_ISteamGameServerStats_ClearUserAchievement`. |
| [`StoreUserStats`](#storeuserstats) | Store the current data on the server, will get a GSStatsStored_t callback when set. If the callback has a result of k_EResultInvalidParam, one or more stats ... |

#### IsGameServer

```pascal
class function IsGameServer: Boolean; override;
```

`True`: a game-server plug-in (created by TSteamworks.StartGameServer).

#### RequestUserStats

```pascal
function RequestUserStats(const steamIDUser: TSteamID): SteamAPICall_t;
```

downloads stats for the user returns a GSStatsReceived_t callback when completed if the user has no stats, GSStatsReceived_t.m_eResult will be set to k_EResultFail these stats will only be auto-updated for clients playing on the server. For other users you'll need to call RequestUserStats() again to refresh any data. Call result: `GSStatsReceived_t` (`GSStatsReceived_t_k_iCallback`).

#### GetUserStatInt32

```pascal
function GetUserStatInt32(const steamIDUser: TSteamID; const pchName: string; var pData: Int32): Boolean;
```

requests stat information for a user, usable after a successful call to RequestUserStats().

#### GetUserStatFloat

```pascal
function GetUserStatFloat(const steamIDUser: TSteamID; const pchName: string; var pData: Single): Boolean;
```

requests stat information for a user, usable after a successful call to RequestUserStats().

#### GetUserAchievement

```pascal
function GetUserAchievement(const steamIDUser: TSteamID; const pchName: string; var pbAchieved: Boolean): Boolean;
```

Wraps `SteamAPI_ISteamGameServerStats_GetUserAchievement`.

#### SetUserStatInt32

```pascal
function SetUserStatInt32(const steamIDUser: TSteamID; const pchName: string; nData: Int32): Boolean;
```

Wraps `SteamAPI_ISteamGameServerStats_SetUserStatInt32`.

#### SetUserStatFloat

```pascal
function SetUserStatFloat(const steamIDUser: TSteamID; const pchName: string; fData: Single): Boolean;
```

Wraps `SteamAPI_ISteamGameServerStats_SetUserStatFloat`.

#### UpdateUserAvgRateStat

```pascal
function UpdateUserAvgRateStat(const steamIDUser: TSteamID; const pchName: string; flCountThisSession: Single; dSessionLength: Double): Boolean;
```

Wraps `SteamAPI_ISteamGameServerStats_UpdateUserAvgRateStat`.

#### SetUserAchievement

```pascal
function SetUserAchievement(const steamIDUser: TSteamID; const pchName: string): Boolean;
```

Wraps `SteamAPI_ISteamGameServerStats_SetUserAchievement`.

#### ClearUserAchievement

```pascal
function ClearUserAchievement(const steamIDUser: TSteamID; const pchName: string): Boolean;
```

Wraps `SteamAPI_ISteamGameServerStats_ClearUserAchievement`.

#### StoreUserStats

```pascal
function StoreUserStats(const steamIDUser: TSteamID): SteamAPICall_t;
```

Store the current data on the server, will get a GSStatsStored_t callback when set. If the callback has a result of k_EResultInvalidParam, one or more stats uploaded has been rejected, either because they broke constraints or were out of date. In this case the server sends back updated values. The stats should be re-iterated to keep in sync. Call result: `GSStatsStored_t` (`GSStatsStored_t_k_iCallback`).

### Async methods

Each `...Async` method starts the call and registers `AHandler` for its result
(`procedure(const AData: TSteamCallbackData; AIOFailure: Boolean) of object`). The
handler runs once, on the delivery thread, with the result record in `AData`
(`AData.CopyTo(Rec, SizeOf(Rec))`); its object owns the registration - call
`Steam.Dispatcher.RemoveOwner(Self)` in that object's destructor. The plain method of
the same name returns the `SteamAPICall_t` instead, and its result reaches the
component's event.

#### RequestUserStatsAsync

```pascal
function RequestUserStatsAsync(const steamIDUser: TSteamID; AHandler: TSteamCallResultEvent): SteamAPICall_t;
```

Calls `RequestUserStats` and registers AHandler for its result (`GSStatsReceived_t`). The handler's object owns the registration (remove it with Plugin.Dispatcher.RemoveOwner). Returns: (The call handle, or k_uAPICallInvalid when Steam refused the call.)

#### StoreUserStatsAsync

```pascal
function StoreUserStatsAsync(const steamIDUser: TSteamID; AHandler: TSteamCallResultEvent): SteamAPICall_t;
```

Calls `StoreUserStats` and registers AHandler for its result (`GSStatsStored_t`). The handler's object owns the registration (remove it with Plugin.Dispatcher.RemoveOwner). Returns: (The call handle, or k_uAPICallInvalid when Steam refused the call.)

### Properties

| Property | Description |
|----------|-------------|
| `Handle: Pointer` | The raw ISteamGameServerStats pointer (first argument of every `Flat` export). |
| `Flat: TSteamGameServerStatsFlat` | The bound flat exports, for calls the methods do not cover. |

## Payload records

Declared in `Steamworks.SDKTypes` (generated from the SDK headers; layouts verified
against the C headers for Win64, Win32, Linux64 and macOS ARM64).

### GSStatsUnloaded_t

Callback id 1108 (`GSStatsUnloaded_t_k_iCallback`).

| Field | C declaration |
|-------|---------------|
| `m_steamIDUser: TSteamID` | C field `CSteamID m_steamIDUser`. |

### GSStatsReceived_t

Callback id 1800 (`GSStatsReceived_t_k_iCallback`).

| Field | C declaration |
|-------|---------------|
| `m_eResult: EResult` | C field `EResult m_eResult`. |
| `m_steamIDUser: TSteamID` | C field `CSteamID m_steamIDUser`. |

### GSStatsStored_t

Callback id 1801 (`GSStatsStored_t_k_iCallback`).

| Field | C declaration |
|-------|---------------|
| `m_eResult: EResult` | C field `EResult m_eResult`. |
| `m_steamIDUser: TSteamID` | C field `CSteamID m_steamIDUser`. |
