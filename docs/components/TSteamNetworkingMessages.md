# TSteamNetworkingMessages and TSteamNetworkingMessagesPlugin (ISteamNetworkingMessages)

> **Generated** by `tools/gen_docs.py` from `lib/plugins/Steamworks.Plugin.NetworkingMessages.pas` - do not edit.
> Hand-written text: `tools/doc_extras/NetworkingMessages.md`. Steam's own descriptions are Valve's
> SDK comments, as in the generated units.

Unit: `Steamworks.Plugin.NetworkingMessages` - linking it (a `uses` entry, or dropping a `TSteamNetworkingMessages`) enables the
plug-in. Steam interface: `ISteamNetworkingMessages` (SDK 1.65).

## Overview

Message-based peer to peer (`ISteamNetworkingMessages`): send to a Steam
user (a `SteamNetworkingIdentity`), no connection to manage - the
replacement for the old `TSteamNetworking` P2P packets. Uses the Steam
Datagram Relay, so call `TSteamNetworkingUtils.InitRelayNetworkAccess`
early.

```pascal
var
  Peer: SteamNetworkingIdentity;
  Msgs: array[0..15] of PSteamNetworkingMessage_t;
  I, N: Integer;
begin
  FillChar(Peer, SizeOf(Peer), 0);
  Peer.m_eType := k_ESteamNetworkingIdentityType_SteamID;
  Peer.m_cbSize := 8;
  Peer.m_steamID64 := FriendID;
  SteamNetworkingMessages1.Plugin.SendMessageToUser(@Peer, @Data[0], Length(Data),
    k_nSteamNetworkingSend_Reliable, 0);
  // poll every frame
  N := SteamNetworkingMessages1.Plugin.ReceiveMessages(0, Msgs);
  for I := 0 to N - 1 do
  begin
    HandleMessage(Msgs[I]^.m_identityPeer.m_steamID64, Msgs[I]^.m_pData, Msgs[I]^.m_cbSize);
    SteamNetworkingMessages1.Plugin.ReleaseMessage(Msgs[I]);   // always
  end;
end;
```

* `OnSteamNetworkingMessagesSessionRequest`: a user you have not sent to
  yet wants to talk - accept with `AcceptSessionWithUser(@AData.m_identityRemote)`.
* `OnSteamNetworkingMessagesSessionFailed` reports a session that broke;
  `CloseSessionWithUser` / `CloseChannelWithUser` end one.
* `ReceiveMessages` and `ReleaseMessage` are hand-written helpers
  (`tools/plugin_extras/NetworkingMessages.pas.txt`).

## Contents

* [The component: TSteamNetworkingMessages](#the-component-tsteamnetworkingmessages)
  * [Events (2)](#events)
* [The plug-in: TSteamNetworkingMessagesPlugin](#the-plug-in-tsteamnetworkingmessagesplugin)
  * [Methods](#methods)
  * [Async methods](#async-methods)
  * [Properties](#properties)
* [Payload records](#payload-records)

## The component: TSteamNetworkingMessages

ISteamNetworkingMessages component: drop it next to a TSteamAPI (linked automatically at run time when the owner has exactly one, otherwise set SteamAPI). Its events are the ISteamNetworkingMessages callbacks; call the interface through `Plugin`.

| Member | Kind | Description |
|--------|------|-------------|
| `SteamAPI` | published property | The `TSteamAPI` this component belongs to. At run time a component whose owner has exactly one `TSteamAPI` links itself. |
| `Plugin` | public property | The `TSteamNetworkingMessagesPlugin` for calls; `nil` while Steam is not running. |
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
| `OnSteamNetworkingMessagesSessionRequest` | 1251 | [`SteamNetworkingMessagesSessionRequest_t`](#steamnetworkingmessagessessionrequest_t) | Posted when a remote host is sending us a message, and we do not already have a session with them. |
| `OnSteamNetworkingMessagesSessionFailed` | 1252 | [`SteamNetworkingMessagesSessionFailed_t`](#steamnetworkingmessagessessionfailed_t) | Posted when we fail to establish a connection, or we detect that communications have been disrupted it an unusual way. There is no notification when a peer proactively closes the session. ("Closed by peer" is not a concept of UDP-style communications, and SteamNetworkingMessages is primarily intended to make porting UDP code easy.) Remember: callbacks are asynchronous. See notes on SendMessageToUser, and k_nSteamNetworkingSend_AutoRestartBrokenSession in particular. Also, if a session times out due to inactivity, no callbacks will be posted. The only way to detect that this is happening is that querying the session state may return none, connecting, and findingroute again. |

Handler signature (the IDE generates it when you double-click the event):

```pascal
procedure TForm1.SteamNetworkingMessages1SteamNetworkingMessagesSessionRequest(Sender: TObject; const AData: SteamNetworkingMessagesSessionRequest_t);
```

## The plug-in: TSteamNetworkingMessagesPlugin

ISteamNetworkingMessages plug-in. Registered by linking the unit; find it with @code(Steam.FindPlugin(TSteamNetworkingMessagesPlugin)).

Reach it through the component (`SteamNetworkingMessages1.Plugin`) or the core:

```pascal
P := TSteamNetworkingMessagesPlugin(Steam.FindPlugin(TSteamNetworkingMessagesPlugin));   // Delphi also: Steam.Plugin<TSteamNetworkingMessagesPlugin>
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
| [`SendMessageToUser`](#sendmessagetouser) | Sends a message to the specified host. If we don't already have a session with that user, a session is implicitly created. There might be some handshaking ... |
| [`ReceiveMessagesOnChannel`](#receivemessagesonchannel) | Reads the next message that has been sent from another user via SendMessageToUser() on the given channel. Returns number of messages returned into your ... |
| [`AcceptSessionWithUser`](#acceptsessionwithuser) | Call this in response to a SteamNetworkingMessagesSessionRequest_t callback. SteamNetworkingMessagesSessionRequest_t are posted when a user tries to send ... |
| [`CloseSessionWithUser`](#closesessionwithuser) | Call this when you're done talking to a user to immediately free up resources under-the-hood. If the remote user tries to send data to you again, another ... |
| [`CloseChannelWithUser`](#closechannelwithuser) | Call this when you're done talking to a user on a specific channel. Once all open channels to a user have been closed, the open session to the user will be ... |
| [`GetSessionConnectionInfo`](#getsessionconnectioninfo) | Returns information about the latest state of a connection, if any, with the given peer. Primarily intended for debugging purposes, but can also be used to ... |
| [`ReleaseMessage`](#releasemessage) | Gives a message from `ReceiveMessages` (or the raw ReceiveMessagesOnChannel) back to Steam. Call it once for every message, after reading m_pData; `nil` is ... |
| [`ReceiveMessages`](#receivemessages) | Up to Length(AMessages) waiting messages on a local channel, into AMessages from index 0. Returns: (How many were stored.) Release each with `ReleaseMessage`. |

#### SendMessageToUser

```pascal
function SendMessageToUser(identityRemote: Pointer; pubData: Pointer; cubData: UInt32; nSendFlags: Integer; nRemoteChannel: Integer): EResult;
```

Sends a message to the specified host. If we don't already have a session with that user, a session is implicitly created. There might be some handshaking that needs to happen before we can actually begin sending message data. If this handshaking fails and we can't get through, an error will be posted via the callback SteamNetworkingMessagesSessionFailed_t. There is no notification when the operation succeeds. (You should have the peer send a reply for this purpose.) Sending a message to a host will also implicitly accept any incoming connection from that host. nSendFlags is a bitmask of k_nSteamNetworkingSend_xxx options nRemoteChannel is a routing number you can use to help route message to different systems. You'll have to call ReceiveMessagesOnChannel() with the same channel number in order to retrieve the data on the other end. Using different channels to talk to the same user will still use the same underlying connection, saving on resources. If you don't need this feature, use 0. Otherwise, small integers are the most efficient. It is guaranteed that reliable messages to the same host on the same channel will be be received by the remote host (if they are received at all) exactly once, and in the same order that they were sent. NO other order guarantees exist! In particular, unreliable messages may be dropped, received out of order with respect to each other and with respect to reliable data, or may be received multiple times. Messages on different channels are *not* guaranteed to be received in the order they were sent. A note for those familiar with TCP/IP ports, or converting an existing codebase that opened multiple sockets: You might notice that there is only one channel, and with TCP/IP each endpoint has a port number. You can think of the channel number as the *destination* port. If you need each message to also include a "source port" (so the recipient can route the reply), then just put that in your message. That is essentially how UDP works! Returns: - k_EREsultOK on success. - k_EResultNoConnection, if the session has failed or was closed by the peer and k_nSteamNetworkingSend_AutoRestartBrokenSession was not specified. (You can use GetSessionConnectionInfo to get the details.) In order to acknowledge the broken session and start a new one, you must call CloseSessionWithUser, or you may repeat the call with k_nSteamNetworkingSend_AutoRestartBrokenSession. See k_nSteamNetworkingSend_AutoRestartBrokenSession for more details. - See ISteamNetworkingSockets::SendMessageToConnection for more possible return values.

#### ReceiveMessagesOnChannel

```pascal
function ReceiveMessagesOnChannel(nLocalChannel: Integer; ppOutMessages: Pointer; nMaxMessages: Integer): Integer;
```

Reads the next message that has been sent from another user via SendMessageToUser() on the given channel. Returns number of messages returned into your list. (0 if no message are available on that channel.) When you're done with the message object(s), make sure and call SteamNetworkingMessage_t::Release()!

#### AcceptSessionWithUser

```pascal
function AcceptSessionWithUser(identityRemote: Pointer): Boolean;
```

Call this in response to a SteamNetworkingMessagesSessionRequest_t callback. SteamNetworkingMessagesSessionRequest_t are posted when a user tries to send you a message, and you haven't tried to talk to them first. If you don't want to talk to them, just ignore the request. If the user continues to send you messages, SteamNetworkingMessagesSessionRequest_t callbacks will continue to be posted periodically. Returns false if there is no session with the user pending or otherwise. If there is an existing active session, this function will return true, even if it is not pending. Calling SendMessageToUser() will implicitly accepts any pending session request to that user.

#### CloseSessionWithUser

```pascal
function CloseSessionWithUser(identityRemote: Pointer): Boolean;
```

Call this when you're done talking to a user to immediately free up resources under-the-hood. If the remote user tries to send data to you again, another SteamNetworkingMessagesSessionRequest_t callback will be posted. Note that sessions that go unused for a few minutes are automatically timed out.

#### CloseChannelWithUser

```pascal
function CloseChannelWithUser(identityRemote: Pointer; nLocalChannel: Integer): Boolean;
```

Call this when you're done talking to a user on a specific channel. Once all open channels to a user have been closed, the open session to the user will be closed, and any new data from this user will trigger a SteamSteamNetworkingMessagesSessionRequest_t callback.

#### GetSessionConnectionInfo

```pascal
function GetSessionConnectionInfo(identityRemote: Pointer; var pConnectionInfo: SteamNetConnectionInfo_t; var pQuickStatus: SteamNetConnectionRealTimeStatus_t): ESteamNetworkingConnectionState;
```

Returns information about the latest state of a connection, if any, with the given peer. Primarily intended for debugging purposes, but can also be used to get more detailed failure information. (See SendMessageToUser and k_nSteamNetworkingSend_AutoRestartBrokenSession.) Returns the value of SteamNetConnectionInfo_t::m_eState, or k_ESteamNetworkingConnectionState_None if no connection exists with specified peer. You may pass nullptr for either parameter if you do not need the corresponding details. Note that sessions time out after a while, so if a connection fails, or SendMessageToUser returns k_EResultNoConnection, you cannot wait indefinitely to obtain the reason for failure.

#### ReleaseMessage

```pascal
procedure ReleaseMessage(AMessage: PSteamNetworkingMessage_t);
```

Gives a message from `ReceiveMessages` (or the raw ReceiveMessagesOnChannel) back to Steam. Call it once for every message, after reading m_pData; `nil` is ignored.

#### ReceiveMessages

```pascal
function ReceiveMessages(nLocalChannel: Integer; var AMessages: array of PSteamNetworkingMessage_t): Integer;
```

Up to Length(AMessages) waiting messages on a local channel, into AMessages from index 0. Returns: (How many were stored.) Release each with `ReleaseMessage`.

### Async methods

None.

### Properties

| Property | Description |
|----------|-------------|
| `Handle: Pointer` | The raw ISteamNetworkingMessages pointer (first argument of every `Flat` export). |
| `Flat: TSteamNetworkingMessagesFlat` | The bound flat exports, for calls the methods do not cover. |

## Payload records

Declared in `Steamworks.SDKTypes` (generated from the SDK headers; layouts verified
against the C headers for Win64, Win32, Linux64 and macOS ARM64).

### SteamNetworkingMessagesSessionRequest_t

Callback id 1251 (`SteamNetworkingMessagesSessionRequest_t_k_iCallback`).

| Field | C declaration |
|-------|---------------|
| `m_identityRemote: SteamNetworkingIdentity` | C field `SteamNetworkingIdentity m_identityRemote`. |

### SteamNetworkingMessagesSessionFailed_t

Callback id 1252 (`SteamNetworkingMessagesSessionFailed_t_k_iCallback`).

| Field | C declaration |
|-------|---------------|
| `m_info: SteamNetConnectionInfo_t` | C field `SteamNetConnectionInfo_t m_info`. |
