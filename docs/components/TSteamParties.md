# TSteamParties and TSteamPartiesPlugin (ISteamParties)

> **Generated** by `tools/gen_docs.py` from `lib/plugins/Steamworks.Plugin.Parties.pas` - do not edit.
> Hand-written text: `tools/doc_extras/Parties.md`. Steam's own descriptions are Valve's
> SDK comments, as in the generated units.

Unit: `Steamworks.Plugin.Parties` - linking it (a `uses` entry, or dropping a `TSteamParties`) enables the
plug-in. Steam interface: `ISteamParties` (SDK 1.65).

## Overview

Steam's party system for a game that puts players together outside the
game itself: a player creates a *beacon* (open slots + a connect string),
others find it and join, and the beacon owner is told about each
reservation.

```pascal
var
  N: UInt32;
begin
  if SteamParties1.Plugin.GetNumAvailableBeaconLocations(N) then
    Log(Format('%d beacon locations, %d active beacons',
      [N, SteamParties1.Plugin.GetNumActiveBeacons]));
end;
```

* `CreateBeacon` (-> `OnCreateBeaconCallback`), `JoinParty` (->
  `OnJoinPartyCallback`), `OnReservationNotificationCallback` on the owner's
  side, then `OnReservationCompleted` and `DestroyBeacon`.
* **Not bound:** `GetBeaconLocationData` - it takes a
  `SteamPartyBeaconLocation_t` *by value*, which needs a per-platform shim
  (Win64 passes it by reference, x86-64 Linux / macOS in registers).
* `GetBeaconDetails` returns its metadata in a raw `PAnsiChar` buffer.

## Contents

* [The component: TSteamParties](#the-component-tsteamparties)
  * [Events (6)](#events)
* [The plug-in: TSteamPartiesPlugin](#the-plug-in-tsteampartiesplugin)
  * [Methods](#methods)
  * [Async methods](#async-methods)
  * [Properties](#properties)
* [Payload records](#payload-records)

## The component: TSteamParties

ISteamParties component: drop it next to a TSteamAPI (linked automatically at run time when the owner has exactly one, otherwise set SteamAPI). Its events are the ISteamParties callbacks; call the interface through `Plugin`.

| Member | Kind | Description |
|--------|------|-------------|
| `SteamAPI` | published property | The `TSteamAPI` this component belongs to. At run time a component whose owner has exactly one `TSteamAPI` links itself. |
| `Plugin` | public property | The `TSteamPartiesPlugin` for calls; `nil` while Steam is not running. |
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
| `OnJoinPartyCallback` | 5301 | [`JoinPartyCallback_t`](#joinpartycallback_t) | Steam has responded to the user request to join a party via the given Beacon ID. If successful, the connect string contains game-specific instructions to connect to the game with that party. |
| `OnCreateBeaconCallback` | 5302 | [`CreateBeaconCallback_t`](#createbeaconcallback_t) | Response to CreateBeacon request. If successful, the beacon ID is provided. |
| `OnReservationNotificationCallback` | 5303 | [`ReservationNotificationCallback_t`](#reservationnotificationcallback_t) | Someone has used the beacon to join your party - they are in-flight now and we've reserved one of the open slots for them. You should confirm when they join your party by calling OnReservationCompleted(). Otherwise, Steam may timeout their reservation eventually. |
| `OnChangeNumOpenSlotsCallback` | 5304 | [`ChangeNumOpenSlotsCallback_t`](#changenumopenslotscallback_t) | Response to ChangeNumOpenSlots call. |
| `OnAvailableBeaconLocationsUpdated` | 5305 | [`AvailableBeaconLocationsUpdated_t`](#availablebeaconlocationsupdated_t) | The list of possible Party beacon locations has changed. |
| `OnActiveBeaconsUpdated` | 5306 | [`ActiveBeaconsUpdated_t`](#activebeaconsupdated_t) | The list of active beacons may have changed. |

Handler signature (the IDE generates it when you double-click the event):

```pascal
procedure TForm1.SteamParties1JoinPartyCallback(Sender: TObject; const AData: JoinPartyCallback_t);
```

## The plug-in: TSteamPartiesPlugin

ISteamParties plug-in. Registered by linking the unit; find it with @code(Steam.FindPlugin(TSteamPartiesPlugin)).

Reach it through the component (`SteamParties1.Plugin`) or the core:

```pascal
P := TSteamPartiesPlugin(Steam.FindPlugin(TSteamPartiesPlugin));   // Delphi also: Steam.Plugin<TSteamPartiesPlugin>
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
| [`GetNumActiveBeacons`](#getnumactivebeacons) | Enumerate any active beacons for parties you may wish to join. |
| [`GetBeaconByIndex`](#getbeaconbyindex) | Wraps `SteamAPI_ISteamParties_GetBeaconByIndex`. |
| [`GetBeaconDetails`](#getbeacondetails) | Wraps `SteamAPI_ISteamParties_GetBeaconDetails`. |
| [`JoinParty`](#joinparty) | Join an open party. Steam will reserve one beacon slot for your SteamID, and return the necessary JoinGame string for you to use to connect. Call result: ... |
| [`GetNumAvailableBeaconLocations`](#getnumavailablebeaconlocations) | Get a list of possible beacon locations. |
| [`GetAvailableBeaconLocations`](#getavailablebeaconlocations) | Wraps `SteamAPI_ISteamParties_GetAvailableBeaconLocations`. |
| [`CreateBeacon`](#createbeacon) | Create a new party beacon and activate it in the selected location. unOpenSlots is the maximum number of users that Steam will send to you. When people ... |
| [`OnReservationCompleted`](#onreservationcompleted) | Call this function when a user that had a reservation (see callback below) has successfully joined your party. Steam will manage the remaining open slots ... |
| [`CancelReservation`](#cancelreservation) | To cancel a reservation (due to timeout or user input), call this. Steam will open a new reservation slot. Note: The user may already be in-flight to your ... |
| [`ChangeNumOpenSlots`](#changenumopenslots) | Change the number of open beacon reservation slots. Call this if, for example, someone without a reservation joins your party (eg a friend, or via your own ... |
| [`DestroyBeacon`](#destroybeacon) | Turn off the beacon. |

#### GetNumActiveBeacons

```pascal
function GetNumActiveBeacons: UInt32;
```

Enumerate any active beacons for parties you may wish to join.

#### GetBeaconByIndex

```pascal
function GetBeaconByIndex(unIndex: UInt32): PartyBeaconID_t;
```

Wraps `SteamAPI_ISteamParties_GetBeaconByIndex`.

#### GetBeaconDetails

```pascal
function GetBeaconDetails(ulBeaconID: PartyBeaconID_t; var pSteamIDBeaconOwner: TSteamID; var pLocation: SteamPartyBeaconLocation_t; pchMetadata: PAnsiChar; cchMetadata: Integer): Boolean;
```

Wraps `SteamAPI_ISteamParties_GetBeaconDetails`.

#### JoinParty

```pascal
function JoinParty(ulBeaconID: PartyBeaconID_t): SteamAPICall_t;
```

Join an open party. Steam will reserve one beacon slot for your SteamID, and return the necessary JoinGame string for you to use to connect. Call result: `JoinPartyCallback_t` (`JoinPartyCallback_t_k_iCallback`).

#### GetNumAvailableBeaconLocations

```pascal
function GetNumAvailableBeaconLocations(var puNumLocations: UInt32): Boolean;
```

Get a list of possible beacon locations.

#### GetAvailableBeaconLocations

```pascal
function GetAvailableBeaconLocations(pLocationList: Pointer; uMaxNumLocations: UInt32): Boolean;
```

Wraps `SteamAPI_ISteamParties_GetAvailableBeaconLocations`.

#### CreateBeacon

```pascal
function CreateBeacon(unOpenSlots: UInt32; var pBeaconLocation: SteamPartyBeaconLocation_t; const pchConnectString: string; const pchMetadata: string): SteamAPICall_t;
```

Create a new party beacon and activate it in the selected location. unOpenSlots is the maximum number of users that Steam will send to you. When people begin responding to your beacon, Steam will send you PartyReservationCallback_t callbacks to let you know who is on the way. Call result: `CreateBeaconCallback_t` (`CreateBeaconCallback_t_k_iCallback`).

#### OnReservationCompleted

```pascal
procedure OnReservationCompleted(ulBeacon: PartyBeaconID_t; const steamIDUser: TSteamID);
```

Call this function when a user that had a reservation (see callback below) has successfully joined your party. Steam will manage the remaining open slots automatically.

#### CancelReservation

```pascal
procedure CancelReservation(ulBeacon: PartyBeaconID_t; const steamIDUser: TSteamID);
```

To cancel a reservation (due to timeout or user input), call this. Steam will open a new reservation slot. Note: The user may already be in-flight to your game, so it's possible they will still connect and try to join your party.

#### ChangeNumOpenSlots

```pascal
function ChangeNumOpenSlots(ulBeacon: PartyBeaconID_t; unOpenSlots: UInt32): SteamAPICall_t;
```

Change the number of open beacon reservation slots. Call this if, for example, someone without a reservation joins your party (eg a friend, or via your own matchmaking system). Call result: `ChangeNumOpenSlotsCallback_t` (`ChangeNumOpenSlotsCallback_t_k_iCallback`).

#### DestroyBeacon

```pascal
function DestroyBeacon(ulBeacon: PartyBeaconID_t): Boolean;
```

Turn off the beacon.

### Async methods

Each `...Async` method starts the call and registers `AHandler` for its result
(`procedure(const AData: TSteamCallbackData; AIOFailure: Boolean) of object`). The
handler runs once, on the delivery thread, with the result record in `AData`
(`AData.CopyTo(Rec, SizeOf(Rec))`); its object owns the registration - call
`Steam.Dispatcher.RemoveOwner(Self)` in that object's destructor. The plain method of
the same name returns the `SteamAPICall_t` instead, and its result reaches the
component's event.

#### JoinPartyAsync

```pascal
function JoinPartyAsync(ulBeaconID: PartyBeaconID_t; AHandler: TSteamCallResultEvent): SteamAPICall_t;
```

Calls `JoinParty` and registers AHandler for its result (`JoinPartyCallback_t`). The handler's object owns the registration (remove it with Plugin.Dispatcher.RemoveOwner). Returns: (The call handle, or k_uAPICallInvalid when Steam refused the call.)

#### CreateBeaconAsync

```pascal
function CreateBeaconAsync(unOpenSlots: UInt32; var pBeaconLocation: SteamPartyBeaconLocation_t; const pchConnectString: string; const pchMetadata: string; AHandler: TSteamCallResultEvent): SteamAPICall_t;
```

Calls `CreateBeacon` and registers AHandler for its result (`CreateBeaconCallback_t`). The handler's object owns the registration (remove it with Plugin.Dispatcher.RemoveOwner). Returns: (The call handle, or k_uAPICallInvalid when Steam refused the call.)

#### ChangeNumOpenSlotsAsync

```pascal
function ChangeNumOpenSlotsAsync(ulBeacon: PartyBeaconID_t; unOpenSlots: UInt32; AHandler: TSteamCallResultEvent): SteamAPICall_t;
```

Calls `ChangeNumOpenSlots` and registers AHandler for its result (`ChangeNumOpenSlotsCallback_t`). The handler's object owns the registration (remove it with Plugin.Dispatcher.RemoveOwner). Returns: (The call handle, or k_uAPICallInvalid when Steam refused the call.)

### Properties

| Property | Description |
|----------|-------------|
| `Handle: Pointer` | The raw ISteamParties pointer (first argument of every `Flat` export). |
| `Flat: TSteamPartiesFlat` | The bound flat exports, for calls the methods do not cover. |

## Payload records

Declared in `Steamworks.SDKTypes` (generated from the SDK headers; layouts verified
against the C headers for Win64, Win32, Linux64 and macOS ARM64).

### JoinPartyCallback_t

Callback id 5301 (`JoinPartyCallback_t_k_iCallback`).

| Field | C declaration |
|-------|---------------|
| `m_eResult: EResult` | C field `EResult m_eResult`. |
| `m_ulBeaconID: PartyBeaconID_t` | C field `PartyBeaconID_t m_ulBeaconID`. |
| `m_SteamIDBeaconOwner: TSteamID` | C field `CSteamID m_SteamIDBeaconOwner`. |
| `m_rgchConnectString: array[0..255] of AnsiChar` | C field `char [256] m_rgchConnectString`. |

### CreateBeaconCallback_t

Callback id 5302 (`CreateBeaconCallback_t_k_iCallback`).

| Field | C declaration |
|-------|---------------|
| `m_eResult: EResult` | C field `EResult m_eResult`. |
| `m_ulBeaconID: PartyBeaconID_t` | C field `PartyBeaconID_t m_ulBeaconID`. |

### ReservationNotificationCallback_t

Callback id 5303 (`ReservationNotificationCallback_t_k_iCallback`).

| Field | C declaration |
|-------|---------------|
| `m_ulBeaconID: PartyBeaconID_t` | C field `PartyBeaconID_t m_ulBeaconID`. |
| `m_steamIDJoiner: TSteamID` | C field `CSteamID m_steamIDJoiner`. |

### ChangeNumOpenSlotsCallback_t

Callback id 5304 (`ChangeNumOpenSlotsCallback_t_k_iCallback`).

| Field | C declaration |
|-------|---------------|
| `m_eResult: EResult` | C field `EResult m_eResult`. |

### AvailableBeaconLocationsUpdated_t

Callback id 5305 (`AvailableBeaconLocationsUpdated_t_k_iCallback`).

| Field | C declaration |
|-------|---------------|
| `_dummy: Byte` | Placeholder: the C++ struct is empty (sizeof = 1). |

### ActiveBeaconsUpdated_t

Callback id 5306 (`ActiveBeaconsUpdated_t_k_iCallback`).

| Field | C declaration |
|-------|---------------|
| `_dummy: Byte` | Placeholder: the C++ struct is empty (sizeof = 1). |
