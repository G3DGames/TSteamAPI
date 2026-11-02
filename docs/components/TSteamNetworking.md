# TSteamNetworking and TSteamNetworkingPlugin (ISteamNetworking)

> **Generated** by `tools/gen_docs.py` from `lib/plugins/Steamworks.Plugin.Networking.pas` - do not edit.
> Hand-written text: `tools/doc_extras/Networking.md`. Steam's own descriptions are Valve's
> SDK comments, as in the generated units.

Unit: `Steamworks.Plugin.Networking` - linking it (a `uses` entry, or dropping a `TSteamNetworking`) enables the
plug-in. Steam interface: `ISteamNetworking` (SDK 1.65).

## Overview

The OLD peer-to-peer API (`ISteamNetworking`): packets to another Steam
user by SteamID, relayed by Steam when no direct route exists. Valve has
deprecated it; new code should use `TSteamNetworkingMessages` (the same
idea, message based) or `TSteamNetworkingSockets` (connections). It is
bound because existing games still use it.

```pascal
var
  Size, Got: UInt32;
  From: TSteamID;
  Buf: TBytes;
begin
  // send: the first packet to a user also opens the session
  SteamNetworking1.Plugin.SendP2PPacket(Friend, @Data[0], Length(Data), k_EP2PSendReliable, 0);
  // receive (poll every frame)
  while SteamNetworking1.Plugin.IsP2PPacketAvailable(Size, 0) do
  begin
    SetLength(Buf, Size);
    if SteamNetworking1.Plugin.ReadP2PPacket(@Buf[0], Size, Got, From, 0) then
      HandlePacket(From, Copy(Buf, 0, Got));
  end;
end;
```

* `OnP2PSessionRequest`: another user wants to talk to you - call
  `AcceptP2PSessionWithUser(AData.m_steamIDRemote)` to accept.
* `OnP2PSessionConnectFail` reports a session that failed;
  `CloseP2PSessionWithUser` ends one.
* `CreateListenSocket` and `CreateConnectionSocket` (the even older
  socket part) are NOT bound: they take the deprecated `SteamIPAddress_t`
  by value, which the generator does not lower. The rest of that socket
  part is bound.

## Contents

* [The component: TSteamNetworking](#the-component-tsteamnetworking)
  * [Events (3)](#events)
* [The plug-in: TSteamNetworkingPlugin](#the-plug-in-tsteamnetworkingplugin)
  * [Methods](#methods)
  * [Async methods](#async-methods)
  * [Properties](#properties)
* [Payload records](#payload-records)

## The component: TSteamNetworking

ISteamNetworking component: drop it next to a TSteamAPI (linked automatically at run time when the owner has exactly one, otherwise set SteamAPI). Its events are the ISteamNetworking callbacks; call the interface through `Plugin`.

| Member | Kind | Description |
|--------|------|-------------|
| `SteamAPI` | published property | The `TSteamAPI` this component belongs to. At run time a component whose owner has exactly one `TSteamAPI` links itself. |
| `Plugin` | public property | The `TSteamNetworkingPlugin` for calls; `nil` while Steam is not running. |
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
| `OnSocketStatusCallback` | 1201 | [`SocketStatusCallback_t`](#socketstatuscallback_t) | callback notification - status of a socket has changed used as part of the CreateListenSocket() / CreateP2PConnectionSocket(). |
| `OnP2PSessionRequest` | 1202 | [`P2PSessionRequest_t`](#p2psessionrequest_t) | callback notification - a user wants to talk to us over the P2P channel via the SendP2PPacket() API in response, a call to AcceptP2PPacketsFromUser() needs to be made, if you want to talk with them. |
| `OnP2PSessionConnectFail` | 1203 | [`P2PSessionConnectFail_t`](#p2psessionconnectfail_t) | callback notification - packets can't get through to the specified user via the SendP2PPacket() API all packets queued packets unsent at this point will be dropped further attempts to send will retry making the connection (but will be dropped if we fail again). |

Handler signature (the IDE generates it when you double-click the event):

```pascal
procedure TForm1.SteamNetworking1SocketStatusCallback(Sender: TObject; const AData: SocketStatusCallback_t);
```

## The plug-in: TSteamNetworkingPlugin

ISteamNetworking plug-in. Registered by linking the unit; find it with @code(Steam.FindPlugin(TSteamNetworkingPlugin)).

Reach it through the component (`SteamNetworking1.Plugin`) or the core:

```pascal
P := TSteamNetworkingPlugin(Steam.FindPlugin(TSteamNetworkingPlugin));   // Delphi also: Steam.Plugin<TSteamNetworkingPlugin>
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
| [`SendP2PPacket`](#sendp2ppacket) | Sends a P2P packet to the specified user UDP-like, unreliable and a max packet size of 1200 bytes the first packet send may be delayed as the NAT-traversal ... |
| [`IsP2PPacketAvailable`](#isp2ppacketavailable) | returns true if any data is available for read, and the amount of data that will need to be read. |
| [`ReadP2PPacket`](#readp2ppacket) | reads in a packet that has been sent from another user via SendP2PPacket() returns the size of the message and the steamID of the user who sent it in the ... |
| [`AcceptP2PSessionWithUser`](#acceptp2psessionwithuser) | AcceptP2PSessionWithUser() should only be called in response to a P2PSessionRequest_t callback P2PSessionRequest_t will be posted if another user tries to ... |
| [`CloseP2PSessionWithUser`](#closep2psessionwithuser) | call CloseP2PSessionWithUser() when you're done talking to a user, will free up resources under-the-hood if the remote user tries to send data to you again, ... |
| [`CloseP2PChannelWithUser`](#closep2pchannelwithuser) | call CloseP2PChannelWithUser() when you're done talking to a user on a specific channel. Once all channels open channels to a user have been closed, the ... |
| [`GetP2PSessionState`](#getp2psessionstate) | fills out P2PSessionState_t structure with details about the underlying connection to the user should only needed for debugging purposes returns false if no ... |
| [`AllowP2PPacketRelay`](#allowp2ppacketrelay) | Allow P2P connections to fall back to being relayed through the Steam servers if a direct connection or NAT-traversal cannot be established. Only applies to ... |
| [`CreateP2PConnectionSocket`](#createp2pconnectionsocket) | creates a socket and begin connection to a remote destination can connect via a known steamID (client or game server), or directly to an IP on success will ... |
| [`DestroySocket`](#destroysocket) | disconnects the connection to the socket, if any, and invalidates the handle any unread data on the socket will be thrown away if bNotifyRemoteEnd is set, ... |
| [`DestroyListenSocket`](#destroylistensocket) | destroying a listen socket will automatically kill all the regular sockets generated from it. |
| [`SendDataOnSocket`](#senddataonsocket) | sending data must be a handle to a connected socket data is all sent via UDP, and thus send sizes are limited to 1200 bytes; after this, many routers will ... |
| [`IsDataAvailableOnSocket`](#isdataavailableonsocket) | receiving data returns false if there is no data remaining fills out *pcubMsgSize with the size of the next message, in bytes. |
| [`RetrieveDataFromSocket`](#retrievedatafromsocket) | fills in pubDest with the contents of the message messages are always complete, of the same size as was sent (i.e. packetized, not streaming) if ... |
| [`IsDataAvailable`](#isdataavailable) | checks for data from any socket that has been connected off this listen socket returns false if there is no data remaining fills out *pcubMsgSize with the ... |
| [`RetrieveData`](#retrievedata) | retrieves data from any socket that has been connected off this listen socket fills in pubDest with the contents of the message messages are always ... |
| [`GetSocketInfo`](#getsocketinfo) | returns information about the specified socket, filling out the contents of the pointers. |
| [`GetListenSocketInfo`](#getlistensocketinfo) | returns which local port the listen socket is bound to *pnIP and *pnPort will be 0 if the socket is set to listen for P2P connections only. |
| [`GetSocketConnectionType`](#getsocketconnectiontype) | returns true to describe how the socket ended up connecting. |
| [`GetMaxPacketSize`](#getmaxpacketsize) | max packet size, in bytes. |

#### SendP2PPacket

```pascal
function SendP2PPacket(const steamIDRemote: TSteamID; pubData: Pointer; cubData: UInt32; eP2PSendType: EP2PSend; nChannel: Integer): Boolean;
```

Sends a P2P packet to the specified user UDP-like, unreliable and a max packet size of 1200 bytes the first packet send may be delayed as the NAT-traversal code runs if we can't get through to the user, an error will be posted via the callback P2PSessionConnectFail_t see EP2PSend enum above for the descriptions of the different ways of sending packets nChannel is a routing number you can use to help route message to different systems - you'll have to call ReadP2PPacket() with the same channel number in order to retrieve the data on the other end using different channels to talk to the same user will still use the same underlying p2p connection, saving on resources.

#### IsP2PPacketAvailable

```pascal
function IsP2PPacketAvailable(var pcubMsgSize: UInt32; nChannel: Integer): Boolean;
```

returns true if any data is available for read, and the amount of data that will need to be read.

#### ReadP2PPacket

```pascal
function ReadP2PPacket(pubDest: Pointer; cubDest: UInt32; var pcubMsgSize: UInt32; var psteamIDRemote: TSteamID; nChannel: Integer): Boolean;
```

reads in a packet that has been sent from another user via SendP2PPacket() returns the size of the message and the steamID of the user who sent it in the last two parameters if the buffer passed in is too small, the message will be truncated this call is not blocking, and will return false if no data is available.

#### AcceptP2PSessionWithUser

```pascal
function AcceptP2PSessionWithUser(const steamIDRemote: TSteamID): Boolean;
```

AcceptP2PSessionWithUser() should only be called in response to a P2PSessionRequest_t callback P2PSessionRequest_t will be posted if another user tries to send you a packet that you haven't talked to yet if you don't want to talk to the user, just ignore the request if the user continues to send you packets, another P2PSessionRequest_t will be posted periodically this may be called multiple times for a single user (if you've called SendP2PPacket() on the other user, this implicitly accepts the session request).

#### CloseP2PSessionWithUser

```pascal
function CloseP2PSessionWithUser(const steamIDRemote: TSteamID): Boolean;
```

call CloseP2PSessionWithUser() when you're done talking to a user, will free up resources under-the-hood if the remote user tries to send data to you again, another P2PSessionRequest_t callback will be posted.

#### CloseP2PChannelWithUser

```pascal
function CloseP2PChannelWithUser(const steamIDRemote: TSteamID; nChannel: Integer): Boolean;
```

call CloseP2PChannelWithUser() when you're done talking to a user on a specific channel. Once all channels open channels to a user have been closed, the open session to the user will be closed and new data from this user will trigger a P2PSessionRequest_t callback.

#### GetP2PSessionState

```pascal
function GetP2PSessionState(const steamIDRemote: TSteamID; var pConnectionState: P2PSessionState_t): Boolean;
```

fills out P2PSessionState_t structure with details about the underlying connection to the user should only needed for debugging purposes returns false if no connection exists to the specified user.

#### AllowP2PPacketRelay

```pascal
function AllowP2PPacketRelay(bAllow: Boolean): Boolean;
```

Allow P2P connections to fall back to being relayed through the Steam servers if a direct connection or NAT-traversal cannot be established. Only applies to connections created after setting this value, or to existing connections that need to automatically reconnect after this value is set. P2P packet relay is allowed by default NOTE: This function is deprecated and may be removed in a future version of the SDK. For security purposes, we may decide to relay the traffic to certain peers, even if you pass false to this function, to prevent revealing the client's IP address top another peer.

#### CreateP2PConnectionSocket

```pascal
function CreateP2PConnectionSocket(const steamIDTarget: TSteamID; nVirtualPort: Integer; nTimeoutSec: Integer; bAllowUseOfPacketRelay: Boolean): SNetSocket_t;
```

creates a socket and begin connection to a remote destination can connect via a known steamID (client or game server), or directly to an IP on success will trigger a SocketStatusCallback_t callback on failure or timeout will trigger a SocketStatusCallback_t callback with a failure code in m_eSNetSocketState.

#### DestroySocket

```pascal
function DestroySocket(hSocket: SNetSocket_t; bNotifyRemoteEnd: Boolean): Boolean;
```

disconnects the connection to the socket, if any, and invalidates the handle any unread data on the socket will be thrown away if bNotifyRemoteEnd is set, socket will not be completely destroyed until the remote end acknowledges the disconnect.

#### DestroyListenSocket

```pascal
function DestroyListenSocket(hSocket: SNetListenSocket_t; bNotifyRemoteEnd: Boolean): Boolean;
```

destroying a listen socket will automatically kill all the regular sockets generated from it.

#### SendDataOnSocket

```pascal
function SendDataOnSocket(hSocket: SNetSocket_t; pubData: Pointer; cubData: UInt32; bReliable: Boolean): Boolean;
```

sending data must be a handle to a connected socket data is all sent via UDP, and thus send sizes are limited to 1200 bytes; after this, many routers will start dropping packets use the reliable flag with caution; although the resend rate is pretty aggressive, it can still cause stalls in receiving data (like TCP).

#### IsDataAvailableOnSocket

```pascal
function IsDataAvailableOnSocket(hSocket: SNetSocket_t; var pcubMsgSize: UInt32): Boolean;
```

receiving data returns false if there is no data remaining fills out *pcubMsgSize with the size of the next message, in bytes.

#### RetrieveDataFromSocket

```pascal
function RetrieveDataFromSocket(hSocket: SNetSocket_t; pubDest: Pointer; cubDest: UInt32; var pcubMsgSize: UInt32): Boolean;
```

fills in pubDest with the contents of the message messages are always complete, of the same size as was sent (i.e. packetized, not streaming) if *pcubMsgSize < cubDest, only partial data is written returns false if no data is available.

#### IsDataAvailable

```pascal
function IsDataAvailable(hListenSocket: SNetListenSocket_t; var pcubMsgSize: UInt32; var phSocket: SNetSocket_t): Boolean;
```

checks for data from any socket that has been connected off this listen socket returns false if there is no data remaining fills out *pcubMsgSize with the size of the next message, in bytes fills out *phSocket with the socket that data is available on.

#### RetrieveData

```pascal
function RetrieveData(hListenSocket: SNetListenSocket_t; pubDest: Pointer; cubDest: UInt32; var pcubMsgSize: UInt32; var phSocket: SNetSocket_t): Boolean;
```

retrieves data from any socket that has been connected off this listen socket fills in pubDest with the contents of the message messages are always complete, of the same size as was sent (i.e. packetized, not streaming) if *pcubMsgSize < cubDest, only partial data is written returns false if no data is available fills out *phSocket with the socket that data is available on.

#### GetSocketInfo

```pascal
function GetSocketInfo(hSocket: SNetSocket_t; var pSteamIDRemote: TSteamID; var peSocketStatus: Integer; var punIPRemote: SteamIPAddress_t; var punPortRemote: UInt16): Boolean;
```

returns information about the specified socket, filling out the contents of the pointers.

#### GetListenSocketInfo

```pascal
function GetListenSocketInfo(hListenSocket: SNetListenSocket_t; var pnIP: SteamIPAddress_t; var pnPort: UInt16): Boolean;
```

returns which local port the listen socket is bound to *pnIP and *pnPort will be 0 if the socket is set to listen for P2P connections only.

#### GetSocketConnectionType

```pascal
function GetSocketConnectionType(hSocket: SNetSocket_t): ESNetSocketConnectionType;
```

returns true to describe how the socket ended up connecting.

#### GetMaxPacketSize

```pascal
function GetMaxPacketSize(hSocket: SNetSocket_t): Integer;
```

max packet size, in bytes.

### Async methods

None.

### Properties

| Property | Description |
|----------|-------------|
| `Handle: Pointer` | The raw ISteamNetworking pointer (first argument of every `Flat` export). |
| `Flat: TSteamNetworkingFlat` | The bound flat exports, for calls the methods do not cover. |

## Payload records

Declared in `Steamworks.SDKTypes` (generated from the SDK headers; layouts verified
against the C headers for Win64, Win32, Linux64 and macOS ARM64).

### SocketStatusCallback_t

Callback id 1201 (`SocketStatusCallback_t_k_iCallback`).

| Field | C declaration |
|-------|---------------|
| `m_hSocket: SNetSocket_t` | C field `SNetSocket_t m_hSocket`. |
| `m_hListenSocket: SNetListenSocket_t` | C field `SNetListenSocket_t m_hListenSocket`. |
| `m_steamIDRemote: TSteamID` | C field `CSteamID m_steamIDRemote`. |
| `m_eSNetSocketState: Integer` | C field `int m_eSNetSocketState`. |

### P2PSessionRequest_t

Callback id 1202 (`P2PSessionRequest_t_k_iCallback`).

| Field | C declaration |
|-------|---------------|
| `m_steamIDRemote: TSteamID` | C field `CSteamID m_steamIDRemote`. |

### P2PSessionConnectFail_t

Callback id 1203 (`P2PSessionConnectFail_t_k_iCallback`).

| Field | C declaration |
|-------|---------------|
| `m_steamIDRemote: TSteamID` | C field `CSteamID m_steamIDRemote`. |
| `m_eP2PSessionError: UInt8` | C field `uint8 m_eP2PSessionError`. |
