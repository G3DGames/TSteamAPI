# TSteamMusic and TSteamMusicPlugin (ISteamMusic)

> **Generated** by `tools/gen_docs.py` from `lib/plugins/Steamworks.Plugin.Music.pas` - do not edit.
> Hand-written text: `tools/doc_extras/Music.md`. Steam's own descriptions are Valve's
> SDK comments, as in the generated units.

Unit: `Steamworks.Plugin.Music` - linking it (a `uses` entry, or dropping a `TSteamMusic`) enables the
plug-in. Steam interface: `ISteamMusic` (SDK 1.65).

## Overview

The Steam music player (the user's soundtracks): read its state and
control it from the game.

```pascal
with SteamMusic1.Plugin do
  if BIsEnabled then
  begin
    Log(Format('playing %s, volume %.2f', [BoolToStr(BIsPlaying, True), GetVolume]));
    SetVolume(0.5);
    Pause;
  end;
```

* `Play`, `Pause`, `PlayPrevious`, `PlayNext`, `SetVolume` (0.0 - 1.0).
* `OnPlaybackStatusHasChanged` and `OnVolumeHasChanged` report changes
  made in Steam.
* The player belongs to the user: change it only when the user asks.

## Contents

* [The component: TSteamMusic](#the-component-tsteammusic)
  * [Events (2)](#events)
* [The plug-in: TSteamMusicPlugin](#the-plug-in-tsteammusicplugin)
  * [Methods](#methods)
  * [Async methods](#async-methods)
  * [Properties](#properties)
* [Payload records](#payload-records)

## The component: TSteamMusic

ISteamMusic component: drop it next to a TSteamAPI (linked automatically at run time when the owner has exactly one, otherwise set SteamAPI). Its events are the ISteamMusic callbacks; call the interface through `Plugin`.

| Member | Kind | Description |
|--------|------|-------------|
| `SteamAPI` | published property | The `TSteamAPI` this component belongs to. At run time a component whose owner has exactly one `TSteamAPI` links itself. |
| `Plugin` | public property | The `TSteamMusicPlugin` for calls; `nil` while Steam is not running. |
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
| `OnPlaybackStatusHasChanged` | 4001 | [`PlaybackStatusHasChanged_t`](#playbackstatushaschanged_t) | see the SDK. |
| `OnVolumeHasChanged` | 4002 | [`VolumeHasChanged_t`](#volumehaschanged_t) | see the SDK. |

Handler signature (the IDE generates it when you double-click the event):

```pascal
procedure TForm1.SteamMusic1PlaybackStatusHasChanged(Sender: TObject; const AData: PlaybackStatusHasChanged_t);
```

## The plug-in: TSteamMusicPlugin

ISteamMusic plug-in. Registered by linking the unit; find it with @code(Steam.FindPlugin(TSteamMusicPlugin)).

Reach it through the component (`SteamMusic1.Plugin`) or the core:

```pascal
P := TSteamMusicPlugin(Steam.FindPlugin(TSteamMusicPlugin));   // Delphi also: Steam.Plugin<TSteamMusicPlugin>
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
| [`BIsEnabled`](#bisenabled) | Wraps `SteamAPI_ISteamMusic_BIsEnabled`. |
| [`BIsPlaying`](#bisplaying) | Wraps `SteamAPI_ISteamMusic_BIsPlaying`. |
| [`GetPlaybackStatus`](#getplaybackstatus) | Wraps `SteamAPI_ISteamMusic_GetPlaybackStatus`. |
| [`Play`](#play) | Wraps `SteamAPI_ISteamMusic_Play`. |
| [`Pause`](#pause) | Wraps `SteamAPI_ISteamMusic_Pause`. |
| [`PlayPrevious`](#playprevious) | Wraps `SteamAPI_ISteamMusic_PlayPrevious`. |
| [`PlayNext`](#playnext) | Wraps `SteamAPI_ISteamMusic_PlayNext`. |
| [`SetVolume`](#setvolume) | volume is between 0.0 and 1.0. |
| [`GetVolume`](#getvolume) | Wraps `SteamAPI_ISteamMusic_GetVolume`. |

#### BIsEnabled

```pascal
function BIsEnabled: Boolean;
```

Wraps `SteamAPI_ISteamMusic_BIsEnabled`.

#### BIsPlaying

```pascal
function BIsPlaying: Boolean;
```

Wraps `SteamAPI_ISteamMusic_BIsPlaying`.

#### GetPlaybackStatus

```pascal
function GetPlaybackStatus: AudioPlayback_Status;
```

Wraps `SteamAPI_ISteamMusic_GetPlaybackStatus`.

#### Play

```pascal
procedure Play;
```

Wraps `SteamAPI_ISteamMusic_Play`.

#### Pause

```pascal
procedure Pause;
```

Wraps `SteamAPI_ISteamMusic_Pause`.

#### PlayPrevious

```pascal
procedure PlayPrevious;
```

Wraps `SteamAPI_ISteamMusic_PlayPrevious`.

#### PlayNext

```pascal
procedure PlayNext;
```

Wraps `SteamAPI_ISteamMusic_PlayNext`.

#### SetVolume

```pascal
procedure SetVolume(flVolume: Single);
```

volume is between 0.0 and 1.0.

#### GetVolume

```pascal
function GetVolume: Single;
```

Wraps `SteamAPI_ISteamMusic_GetVolume`.

### Async methods

None.

### Properties

| Property | Description |
|----------|-------------|
| `Handle: Pointer` | The raw ISteamMusic pointer (first argument of every `Flat` export). |
| `Flat: TSteamMusicFlat` | The bound flat exports, for calls the methods do not cover. |

## Payload records

Declared in `Steamworks.SDKTypes` (generated from the SDK headers; layouts verified
against the C headers for Win64, Win32, Linux64, Linux32, LinuxARM64 and macOS ARM64).

### PlaybackStatusHasChanged_t

Callback id 4001 (`PlaybackStatusHasChanged_t_k_iCallback`).

| Field | C declaration |
|-------|---------------|
| `_dummy: Byte` | Placeholder: the C++ struct is empty (sizeof = 1). |

### VolumeHasChanged_t

Callback id 4002 (`VolumeHasChanged_t_k_iCallback`).

| Field | C declaration |
|-------|---------------|
| `m_flNewVolume: Single` | C field `float m_flNewVolume`. |
