# TSteamParentalSettings and TSteamParentalSettingsPlugin (ISteamParentalSettings)

> **Generated** by `tools/gen_docs.py` from `lib/plugins/Steamworks.Plugin.ParentalSettings.pas` - do not edit.
> Hand-written text: `tools/doc_extras/ParentalSettings.md`. Steam's own descriptions are Valve's
> SDK comments, as in the generated units.

Unit: `Steamworks.Plugin.ParentalSettings` - linking it (a `uses` entry, or dropping a `TSteamParentalSettings`) enables the
plug-in. Steam interface: `ISteamParentalSettings` (SDK 1.65).

## Overview

Steam Family View: whether the account is under parental control and which
features or apps are blocked, so the game can hide what the user may not
use.

```pascal
with SteamParentalSettings1.Plugin do
  if BIsParentalLockEnabled and BIsFeatureBlocked(k_EFeatureStore) then
    HideStoreButton;
```

* `BIsParentalLockLocked` - locked now (unlocked with the PIN);
  `BIsAppBlocked` / `BIsAppInBlockList` for an app, `BIsFeatureBlocked` /
  `BIsFeatureInBlockList` for a feature (`k_EFeatureStore`,
  `k_EFeatureCommunity`, `k_EFeatureFriends`, ...).
* `OnSteamParentalSettingsChanged` fires when the settings change.

## Contents

* [The component: TSteamParentalSettings](#the-component-tsteamparentalsettings)
  * [Events (1)](#events)
* [The plug-in: TSteamParentalSettingsPlugin](#the-plug-in-tsteamparentalsettingsplugin)
  * [Methods](#methods)
  * [Async methods](#async-methods)
  * [Properties](#properties)
* [Payload records](#payload-records)

## The component: TSteamParentalSettings

ISteamParentalSettings component: drop it next to a TSteamAPI (linked automatically at run time when the owner has exactly one, otherwise set SteamAPI). Its events are the ISteamParentalSettings callbacks; call the interface through `Plugin`.

| Member | Kind | Description |
|--------|------|-------------|
| `SteamAPI` | published property | The `TSteamAPI` this component belongs to. At run time a component whose owner has exactly one `TSteamAPI` links itself. |
| `Plugin` | public property | The `TSteamParentalSettingsPlugin` for calls; `nil` while Steam is not running. |
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
| `OnSteamParentalSettingsChanged` | 5001 | [`SteamParentalSettingsChanged_t`](#steamparentalsettingschanged_t) | Callback for querying UGC. |

Handler signature (the IDE generates it when you double-click the event):

```pascal
procedure TForm1.SteamParentalSettings1SteamParentalSettingsChanged(Sender: TObject; const AData: SteamParentalSettingsChanged_t);
```

## The plug-in: TSteamParentalSettingsPlugin

ISteamParentalSettings plug-in. Registered by linking the unit; find it with @code(Steam.FindPlugin(TSteamParentalSettingsPlugin)).

Reach it through the component (`SteamParentalSettings1.Plugin`) or the core:

```pascal
P := TSteamParentalSettingsPlugin(Steam.FindPlugin(TSteamParentalSettingsPlugin));   // Delphi also: Steam.Plugin<TSteamParentalSettingsPlugin>
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
| [`BIsParentalLockEnabled`](#bisparentallockenabled) | Wraps `SteamAPI_ISteamParentalSettings_BIsParentalLockEnabled`. |
| [`BIsParentalLockLocked`](#bisparentallocklocked) | Wraps `SteamAPI_ISteamParentalSettings_BIsParentalLockLocked`. |
| [`BIsAppBlocked`](#bisappblocked) | Wraps `SteamAPI_ISteamParentalSettings_BIsAppBlocked`. |
| [`BIsAppInBlockList`](#bisappinblocklist) | Wraps `SteamAPI_ISteamParentalSettings_BIsAppInBlockList`. |
| [`BIsFeatureBlocked`](#bisfeatureblocked) | Wraps `SteamAPI_ISteamParentalSettings_BIsFeatureBlocked`. |
| [`BIsFeatureInBlockList`](#bisfeatureinblocklist) | Wraps `SteamAPI_ISteamParentalSettings_BIsFeatureInBlockList`. |

#### BIsParentalLockEnabled

```pascal
function BIsParentalLockEnabled: Boolean;
```

Wraps `SteamAPI_ISteamParentalSettings_BIsParentalLockEnabled`.

#### BIsParentalLockLocked

```pascal
function BIsParentalLockLocked: Boolean;
```

Wraps `SteamAPI_ISteamParentalSettings_BIsParentalLockLocked`.

#### BIsAppBlocked

```pascal
function BIsAppBlocked(nAppID: AppId_t): Boolean;
```

Wraps `SteamAPI_ISteamParentalSettings_BIsAppBlocked`.

#### BIsAppInBlockList

```pascal
function BIsAppInBlockList(nAppID: AppId_t): Boolean;
```

Wraps `SteamAPI_ISteamParentalSettings_BIsAppInBlockList`.

#### BIsFeatureBlocked

```pascal
function BIsFeatureBlocked(eFeature: EParentalFeature): Boolean;
```

Wraps `SteamAPI_ISteamParentalSettings_BIsFeatureBlocked`.

#### BIsFeatureInBlockList

```pascal
function BIsFeatureInBlockList(eFeature: EParentalFeature): Boolean;
```

Wraps `SteamAPI_ISteamParentalSettings_BIsFeatureInBlockList`.

### Async methods

None.

### Properties

| Property | Description |
|----------|-------------|
| `Handle: Pointer` | The raw ISteamParentalSettings pointer (first argument of every `Flat` export). |
| `Flat: TSteamParentalSettingsFlat` | The bound flat exports, for calls the methods do not cover. |

## Payload records

Declared in `Steamworks.SDKTypes` (generated from the SDK headers; layouts verified
against the C headers for Win64, Win32, Linux64 and macOS ARM64).

### SteamParentalSettingsChanged_t

Callback id 5001 (`SteamParentalSettingsChanged_t_k_iCallback`).

| Field | C declaration |
|-------|---------------|
| `_dummy: Byte` | Placeholder: the C++ struct is empty (sizeof = 1). |
