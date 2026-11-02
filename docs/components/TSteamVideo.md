# TSteamVideo and TSteamVideoPlugin (ISteamVideo)

> **Generated** by `tools/gen_docs.py` from `lib/plugins/Steamworks.Plugin.Video.pas` - do not edit.
> Hand-written text: `tools/doc_extras/Video.md`. Steam's own descriptions are Valve's
> SDK comments, as in the generated units.

Unit: `Steamworks.Plugin.Video` - linking it (a `uses` entry, or dropping a `TSteamVideo`) enables the
plug-in. Steam interface: `ISteamVideo` (SDK 1.65).

## Overview

Steam Broadcasting and video apps: whether the user is broadcasting the
game, and the stream URL / 360-video (OPF) settings of a video app.

```pascal
var
  Viewers: Integer;
begin
  if SteamVideo1.Plugin.IsBroadcasting(Viewers) then
    Log(Format('broadcasting to %d viewers', [Viewers]));
end;
```

* `OnBroadcastUploadStart` / `OnBroadcastUploadStop` report a broadcast
  starting or ending.
* `GetVideoURL` -> `OnGetVideoURLResult`, `GetOPFSettings` ->
  `OnGetOPFSettingsResult` (then `GetOPFStringForApp`, raw buffer) are for
  video apps; a game gets an error result.

## Contents

* [The component: TSteamVideo](#the-component-tsteamvideo)
  * [Events (4)](#events)
* [The plug-in: TSteamVideoPlugin](#the-plug-in-tsteamvideoplugin)
  * [Methods](#methods)
  * [Async methods](#async-methods)
  * [Properties](#properties)
* [Payload records](#payload-records)

## The component: TSteamVideo

ISteamVideo component: drop it next to a TSteamAPI (linked automatically at run time when the owner has exactly one, otherwise set SteamAPI). Its events are the ISteamVideo callbacks; call the interface through `Plugin`.

| Member | Kind | Description |
|--------|------|-------------|
| `SteamAPI` | published property | The `TSteamAPI` this component belongs to. At run time a component whose owner has exactly one `TSteamAPI` links itself. |
| `Plugin` | public property | The `TSteamVideoPlugin` for calls; `nil` while Steam is not running. |
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
| `OnBroadcastUploadStart` | 4604 | [`BroadcastUploadStart_t`](#broadcastuploadstart_t) | see the SDK. |
| `OnBroadcastUploadStop` | 4605 | [`BroadcastUploadStop_t`](#broadcastuploadstop_t) | see the SDK. |
| `OnGetVideoURLResult` | 4611 | [`GetVideoURLResult_t`](#getvideourlresult_t) | see the SDK. |
| `OnGetOPFSettingsResult` | 4624 | [`GetOPFSettingsResult_t`](#getopfsettingsresult_t) | see the SDK. |

Handler signature (the IDE generates it when you double-click the event):

```pascal
procedure TForm1.SteamVideo1BroadcastUploadStart(Sender: TObject; const AData: BroadcastUploadStart_t);
```

## The plug-in: TSteamVideoPlugin

ISteamVideo plug-in. Registered by linking the unit; find it with @code(Steam.FindPlugin(TSteamVideoPlugin)).

Reach it through the component (`SteamVideo1.Plugin`) or the core:

```pascal
P := TSteamVideoPlugin(Steam.FindPlugin(TSteamVideoPlugin));   // Delphi also: Steam.Plugin<TSteamVideoPlugin>
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
| [`GetVideoURL`](#getvideourl) | Get a URL suitable for streaming the given Video app ID's video. |
| [`IsBroadcasting`](#isbroadcasting) | returns true if user is uploading a live broadcast. |
| [`GetOPFSettings`](#getopfsettings) | Get the OPF Details for 360 Video Playback. |
| [`GetOPFStringForApp`](#getopfstringforapp) | Wraps `SteamAPI_ISteamVideo_GetOPFStringForApp`. |

#### GetVideoURL

```pascal
procedure GetVideoURL(unVideoAppID: AppId_t);
```

Get a URL suitable for streaming the given Video app ID's video.

#### IsBroadcasting

```pascal
function IsBroadcasting(var pnNumViewers: Integer): Boolean;
```

returns true if user is uploading a live broadcast.

#### GetOPFSettings

```pascal
procedure GetOPFSettings(unVideoAppID: AppId_t);
```

Get the OPF Details for 360 Video Playback.

#### GetOPFStringForApp

```pascal
function GetOPFStringForApp(unVideoAppID: AppId_t; pchBuffer: PAnsiChar; var pnBufferSize: Int32): Boolean;
```

Wraps `SteamAPI_ISteamVideo_GetOPFStringForApp`.

### Async methods

None.

### Properties

| Property | Description |
|----------|-------------|
| `Handle: Pointer` | The raw ISteamVideo pointer (first argument of every `Flat` export). |
| `Flat: TSteamVideoFlat` | The bound flat exports, for calls the methods do not cover. |

## Payload records

Declared in `Steamworks.SDKTypes` (generated from the SDK headers; layouts verified
against the C headers for Win64, Win32, Linux64 and macOS ARM64).

### BroadcastUploadStart_t

Callback id 4604 (`BroadcastUploadStart_t_k_iCallback`).

| Field | C declaration |
|-------|---------------|
| `m_bIsRTMP: Boolean` | C field `bool m_bIsRTMP`. |

### BroadcastUploadStop_t

Callback id 4605 (`BroadcastUploadStop_t_k_iCallback`).

| Field | C declaration |
|-------|---------------|
| `m_eResult: EBroadcastUploadResult` | C field `EBroadcastUploadResult m_eResult`. |

### GetVideoURLResult_t

Callback id 4611 (`GetVideoURLResult_t_k_iCallback`).

| Field | C declaration |
|-------|---------------|
| `m_eResult: EResult` | C field `EResult m_eResult`. |
| `m_unVideoAppID: AppId_t` | C field `AppId_t m_unVideoAppID`. |
| `m_rgchURL: array[0..255] of AnsiChar` | C field `char [256] m_rgchURL`. |

### GetOPFSettingsResult_t

Callback id 4624 (`GetOPFSettingsResult_t_k_iCallback`).

| Field | C declaration |
|-------|---------------|
| `m_eResult: EResult` | C field `EResult m_eResult`. |
| `m_unVideoAppID: AppId_t` | C field `AppId_t m_unVideoAppID`. |
