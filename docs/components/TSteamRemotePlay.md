# TSteamRemotePlay and TSteamRemotePlayPlugin (ISteamRemotePlay)

> **Generated** by `tools/gen_docs.py` from `lib/plugins/Steamworks.Plugin.RemotePlay.pas` - do not edit.
> Hand-written text: `tools/doc_extras/RemotePlay.md`. Steam's own descriptions are Valve's
> SDK comments, as in the generated units.

Unit: `Steamworks.Plugin.RemotePlay` - linking it (a `uses` entry, or dropping a `TSteamRemotePlay`) enables the
plug-in. Steam interface: `ISteamRemotePlay` (SDK 1.65).

## Overview

Steam Remote Play: the game streamed to another device, and Remote Play
Together (friends joining a local multiplayer game over the internet).

```pascal
var
  I: Integer;
  S: RemotePlaySessionID_t;
begin
  for I := 0 to Integer(SteamRemotePlay1.Plugin.GetSessionCount) - 1 do
  begin
    S := SteamRemotePlay1.Plugin.GetSessionID(I);
    Log(Format('%s on "%s"', [SteamRemotePlay1.Plugin.GetSessionSteamID(S).ToString,
      SteamRemotePlay1.Plugin.GetSessionClientName(S)]));
  end;
end;
```

* `OnSteamRemotePlaySessionConnected` / `...Disconnected` report sessions;
  `GetSessionClientFormFactor` and `BGetSessionClientResolution` describe
  the device (adapt the UI to a phone or TV).
* `BSendRemotePlayTogetherInvite` invites a friend;
  `ShowRemotePlayTogetherUI` opens Steam's invite UI.
* `GetInput` (mouse / keyboard events of Remote Play Together guests, after
  `BEnableRemotePlayTogetherDirectInput`) fills an array of
  `RemotePlayInput_t` (a variant record: `m_eType` says which member is
  valid). The parameter is a plain `Pointer`: pass `@Events[0]` and
  `Length(Events)`; the result is the number filled. `CreateMouseCursor`
  takes a raw pixel buffer.

## Contents

* [The component: TSteamRemotePlay](#the-component-tsteamremoteplay)
  * [Events (4)](#events)
* [The plug-in: TSteamRemotePlayPlugin](#the-plug-in-tsteamremoteplayplugin)
  * [Methods](#methods)
  * [Async methods](#async-methods)
  * [Properties](#properties)
* [Payload records](#payload-records)

## The component: TSteamRemotePlay

ISteamRemotePlay component: drop it next to a TSteamAPI (linked automatically at run time when the owner has exactly one, otherwise set SteamAPI). Its events are the ISteamRemotePlay callbacks; call the interface through `Plugin`.

| Member | Kind | Description |
|--------|------|-------------|
| `SteamAPI` | published property | The `TSteamAPI` this component belongs to. At run time a component whose owner has exactly one `TSteamAPI` links itself. |
| `Plugin` | public property | The `TSteamRemotePlayPlugin` for calls; `nil` while Steam is not running. |
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
| `OnSteamRemotePlaySessionConnected` | 5701 | [`SteamRemotePlaySessionConnected_t`](#steamremoteplaysessionconnected_t) | see the SDK. |
| `OnSteamRemotePlaySessionDisconnected` | 5702 | [`SteamRemotePlaySessionDisconnected_t`](#steamremoteplaysessiondisconnected_t) | see the SDK. |
| `OnSteamRemotePlayTogetherGuestInvite` | 5703 | [`SteamRemotePlayTogetherGuestInvite_t`](#steamremoteplaytogetherguestinvite_t) | see the SDK. |
| `OnSteamRemotePlaySessionAvatarLoaded` | 5704 | [`SteamRemotePlaySessionAvatarLoaded_t`](#steamremoteplaysessionavatarloaded_t) | see the SDK. |

Handler signature (the IDE generates it when you double-click the event):

```pascal
procedure TForm1.SteamRemotePlay1SteamRemotePlaySessionConnected(Sender: TObject; const AData: SteamRemotePlaySessionConnected_t);
```

## The plug-in: TSteamRemotePlayPlugin

ISteamRemotePlay plug-in. Registered by linking the unit; find it with @code(Steam.FindPlugin(TSteamRemotePlayPlugin)).

Reach it through the component (`SteamRemotePlay1.Plugin`) or the core:

```pascal
P := TSteamRemotePlayPlugin(Steam.FindPlugin(TSteamRemotePlayPlugin));   // Delphi also: Steam.Plugin<TSteamRemotePlayPlugin>
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
| [`GetSessionCount`](#getsessioncount) | Get the number of currently connected Steam Remote Play sessions. |
| [`GetSessionID`](#getsessionid) | Get the currently connected Steam Remote Play session ID at the specified index. Returns zero if index is out of bounds. |
| [`BSessionRemotePlayTogether`](#bsessionremoteplaytogether) | Return true if the session has joined using a Remote Play Together invitation. |
| [`GetSessionSteamID`](#getsessionsteamid) | Get the SteamID of the connected user. |
| [`GetSessionGuestID`](#getsessionguestid) | Get the guest ID of the connected user if they are a Remote Play Together guest This returns 0 if the sessionID isn't valid or the session isn't a Remote ... |
| [`GetSmallSessionAvatar`](#getsmallsessionavatar) | gets the small (32x32) avatar of the connected user, which is a handle to be used in ISteamUtils::GetImageRGBA(), or 0 if the sessionID isn't valid returns ... |
| [`GetMediumSessionAvatar`](#getmediumsessionavatar) | gets the medium (64x64) avatar of the connected user, which is a handle to be used in ISteamUtils::GetImageRGBA(), or 0 if the sessionID isn't valid returns ... |
| [`GetLargeSessionAvatar`](#getlargesessionavatar) | gets the large (184x184) avatar of the connected user, which is a handle to be used in ISteamUtils::GetImageRGBA(), or 0 if the sessionID isn't valid ... |
| [`GetSessionClientName`](#getsessionclientname) | Get the name of the session client device This returns NULL if the sessionID is not valid. |
| [`GetSessionClientFormFactor`](#getsessionclientformfactor) | Get the form factor of the session client device. |
| [`BGetSessionClientResolution`](#bgetsessionclientresolution) | Get the resolution, in pixels, of the session client device This is set to 0x0 if the resolution is not available. |
| [`ShowRemotePlayTogetherUI`](#showremoteplaytogetherui) | Show the Remote Play Together UI in the game overlay This returns false if your game is not configured for Remote Play Together. |
| [`BSendRemotePlayTogetherInvite`](#bsendremoteplaytogetherinvite) | Invite a friend to Remote Play Together, or create a guest invite if steamIDFriend is CSteamID() This returns false if the invite can't be sent or your game ... |
| [`BEnableRemotePlayTogetherDirectInput`](#benableremoteplaytogetherdirectinput) | Make mouse and keyboard input for Remote Play Together sessions available via GetInput() instead of being merged with local input. |
| [`DisableRemotePlayTogetherDirectInput`](#disableremoteplaytogetherdirectinput) | Merge Remote Play Together mouse and keyboard input with local input. |
| [`GetInput`](#getinput) | Get input events from Remote Play Together sessions This is available after calling BEnableRemotePlayTogetherDirectInput() pInput is an array of input ... |
| [`SetMouseVisibility`](#setmousevisibility) | Set the mouse cursor visibility for a remote player This is available after calling BEnableRemotePlayTogetherDirectInput(). |
| [`SetMousePosition`](#setmouseposition) | Set the mouse cursor position for a remote player This is available after calling BEnableRemotePlayTogetherDirectInput() This is used to warp the cursor to ... |
| [`CreateMouseCursor`](#createmousecursor) | Create a cursor that can be used with SetMouseCursor() This is available after calling BEnableRemotePlayTogetherDirectInput() Parameters: nWidth - The width ... |
| [`SetMouseCursor`](#setmousecursor) | Set the mouse cursor for a remote player This is available after calling BEnableRemotePlayTogetherDirectInput() The cursor ID is a value returned by ... |

#### GetSessionCount

```pascal
function GetSessionCount: UInt32;
```

Get the number of currently connected Steam Remote Play sessions.

#### GetSessionID

```pascal
function GetSessionID(iSessionIndex: Integer): RemotePlaySessionID_t;
```

Get the currently connected Steam Remote Play session ID at the specified index. Returns zero if index is out of bounds.

#### BSessionRemotePlayTogether

```pascal
function BSessionRemotePlayTogether(unSessionID: RemotePlaySessionID_t): Boolean;
```

Return true if the session has joined using a Remote Play Together invitation.

#### GetSessionSteamID

```pascal
function GetSessionSteamID(unSessionID: RemotePlaySessionID_t): TSteamID;
```

Get the SteamID of the connected user.

#### GetSessionGuestID

```pascal
function GetSessionGuestID(unSessionID: RemotePlaySessionID_t): UInt32;
```

Get the guest ID of the connected user if they are a Remote Play Together guest This returns 0 if the sessionID isn't valid or the session isn't a Remote Play Together guest.

#### GetSmallSessionAvatar

```pascal
function GetSmallSessionAvatar(unSessionID: RemotePlaySessionID_t): Integer;
```

gets the small (32x32) avatar of the connected user, which is a handle to be used in ISteamUtils::GetImageRGBA(), or 0 if the sessionID isn't valid returns -1 if this image has yet to be loaded, in this case wait for a SteamRemotePlaySessionAvatarLoaded_t callback and then call this again.

#### GetMediumSessionAvatar

```pascal
function GetMediumSessionAvatar(unSessionID: RemotePlaySessionID_t): Integer;
```

gets the medium (64x64) avatar of the connected user, which is a handle to be used in ISteamUtils::GetImageRGBA(), or 0 if the sessionID isn't valid returns -1 if this image has yet to be loaded, in this case wait for a SteamRemotePlaySessionAvatarLoaded_t callback and then call this again.

#### GetLargeSessionAvatar

```pascal
function GetLargeSessionAvatar(unSessionID: RemotePlaySessionID_t): Integer;
```

gets the large (184x184) avatar of the connected user, which is a handle to be used in ISteamUtils::GetImageRGBA(), or 0 if the sessionID isn't valid returns -1 if this image has yet to be loaded, in this case wait for a SteamRemotePlaySessionAvatarLoaded_t callback and then call this again.

#### GetSessionClientName

```pascal
function GetSessionClientName(unSessionID: RemotePlaySessionID_t): string;
```

Get the name of the session client device This returns NULL if the sessionID is not valid.

#### GetSessionClientFormFactor

```pascal
function GetSessionClientFormFactor(unSessionID: RemotePlaySessionID_t): ESteamDeviceFormFactor;
```

Get the form factor of the session client device.

#### BGetSessionClientResolution

```pascal
function BGetSessionClientResolution(unSessionID: RemotePlaySessionID_t; var pnResolutionX: Integer; var pnResolutionY: Integer): Boolean;
```

Get the resolution, in pixels, of the session client device This is set to 0x0 if the resolution is not available.

#### ShowRemotePlayTogetherUI

```pascal
function ShowRemotePlayTogetherUI: Boolean;
```

Show the Remote Play Together UI in the game overlay This returns false if your game is not configured for Remote Play Together.

#### BSendRemotePlayTogetherInvite

```pascal
function BSendRemotePlayTogetherInvite(const steamIDFriend: TSteamID): Boolean;
```

Invite a friend to Remote Play Together, or create a guest invite if steamIDFriend is CSteamID() This returns false if the invite can't be sent or your game is not configured for Remote Play Together.

#### BEnableRemotePlayTogetherDirectInput

```pascal
function BEnableRemotePlayTogetherDirectInput: Boolean;
```

Make mouse and keyboard input for Remote Play Together sessions available via GetInput() instead of being merged with local input.

#### DisableRemotePlayTogetherDirectInput

```pascal
procedure DisableRemotePlayTogetherDirectInput;
```

Merge Remote Play Together mouse and keyboard input with local input.

#### GetInput

```pascal
function GetInput(pInput: Pointer; unMaxEvents: UInt32): UInt32;
```

Get input events from Remote Play Together sessions This is available after calling BEnableRemotePlayTogetherDirectInput() pInput is an array of input events that will be filled in by this function, up to unMaxEvents. This returns the number of events copied to pInput, or the number of events available if pInput is nullptr.

#### SetMouseVisibility

```pascal
procedure SetMouseVisibility(unSessionID: RemotePlaySessionID_t; bVisible: Boolean);
```

Set the mouse cursor visibility for a remote player This is available after calling BEnableRemotePlayTogetherDirectInput().

#### SetMousePosition

```pascal
procedure SetMousePosition(unSessionID: RemotePlaySessionID_t; flNormalizedX: Single; flNormalizedY: Single);
```

Set the mouse cursor position for a remote player This is available after calling BEnableRemotePlayTogetherDirectInput() This is used to warp the cursor to a specific location and isn't needed during normal event processing. The position is normalized relative to the window, where 0,0 is the upper left, and 1,1 is the lower right.

#### CreateMouseCursor

```pascal
function CreateMouseCursor(nWidth: Integer; nHeight: Integer; nHotX: Integer; nHotY: Integer; pBGRA: Pointer; nPitch: Integer): RemotePlayCursorID_t;
```

Create a cursor that can be used with SetMouseCursor() This is available after calling BEnableRemotePlayTogetherDirectInput() Parameters: nWidth - The width of the cursor, in pixels nHeight - The height of the cursor, in pixels nHotX - The X coordinate of the cursor hot spot in pixels, offset from the left of the cursor nHotY - The Y coordinate of the cursor hot spot in pixels, offset from the top of the cursor pBGRA - A pointer to the cursor pixels, with 8-bit color channels in red, green, blue, alpha order nPitch - The distance between pixel rows in bytes, defaults to nWidth * 4.

#### SetMouseCursor

```pascal
procedure SetMouseCursor(unSessionID: RemotePlaySessionID_t; unCursorID: RemotePlayCursorID_t);
```

Set the mouse cursor for a remote player This is available after calling BEnableRemotePlayTogetherDirectInput() The cursor ID is a value returned by CreateMouseCursor().

### Async methods

None.

### Properties

| Property | Description |
|----------|-------------|
| `Handle: Pointer` | The raw ISteamRemotePlay pointer (first argument of every `Flat` export). |
| `Flat: TSteamRemotePlayFlat` | The bound flat exports, for calls the methods do not cover. |

## Payload records

Declared in `Steamworks.SDKTypes` (generated from the SDK headers; layouts verified
against the C headers for Win64, Win32, Linux64 and macOS ARM64).

### SteamRemotePlaySessionConnected_t

Callback id 5701 (`SteamRemotePlaySessionConnected_t_k_iCallback`).

| Field | C declaration |
|-------|---------------|
| `m_unSessionID: RemotePlaySessionID_t` | C field `RemotePlaySessionID_t m_unSessionID`. |

### SteamRemotePlaySessionDisconnected_t

Callback id 5702 (`SteamRemotePlaySessionDisconnected_t_k_iCallback`).

| Field | C declaration |
|-------|---------------|
| `m_unSessionID: RemotePlaySessionID_t` | C field `RemotePlaySessionID_t m_unSessionID`. |

### SteamRemotePlayTogetherGuestInvite_t

Callback id 5703 (`SteamRemotePlayTogetherGuestInvite_t_k_iCallback`).

| Field | C declaration |
|-------|---------------|
| `m_szConnectURL: array[0..1023] of AnsiChar` | C field `char [1024] m_szConnectURL`. |

### SteamRemotePlaySessionAvatarLoaded_t

Callback id 5704 (`SteamRemotePlaySessionAvatarLoaded_t_k_iCallback`).

| Field | C declaration |
|-------|---------------|
| `m_unSessionID: RemotePlaySessionID_t` | C field `RemotePlaySessionID_t m_unSessionID`. |
| `m_iImage: Integer` | C field `int m_iImage`. |
| `m_iWide: Integer` | C field `int m_iWide`. |
| `m_iTall: Integer` | C field `int m_iTall`. |
