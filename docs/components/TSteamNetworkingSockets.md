# TSteamNetworkingSockets and TSteamNetworkingSocketsPlugin (ISteamNetworkingSockets)

> **Generated** by `tools/gen_docs.py` from `lib/plugins/Steamworks.Plugin.NetworkingSockets.pas` - do not edit.
> Hand-written text: `tools/doc_extras/NetworkingSockets.md`. Steam's own descriptions are Valve's
> SDK comments, as in the generated units.

Unit: `Steamworks.Plugin.NetworkingSockets` - linking it (a `uses` entry, or dropping a `TSteamNetworkingSockets`) enables the
plug-in. Steam interface: `ISteamNetworkingSockets` (SDK 1.65).

**Game-server copy:** `TSteamGameServerNetworkingSockets` (plug-in `TSteamGameServerNetworkingSocketsPlugin`) in the same unit - the
game server's own `ISteamNetworkingSockets`, with every method and event on this page. It attaches
while the game server runs and gets its events from the server's callback pipe
(see [TSteamGameServer](TSteamGameServer.md#server-components)).

## Overview

Connection-oriented networking (`ISteamNetworkingSockets`, Valve's
GameNetworkingSockets): reliable and unreliable messages over connections,
by IP address or peer to peer through the Steam Datagram Relay (SDR). The
connection state arrives in `OnSteamNetConnectionStatusChangedCallback`.

```pascal
var
  C1, C2: HSteamNetConnection;
  MsgNo: Int64;
  Msgs: array[0..15] of PSteamNetworkingMessage_t;
  I, N: Integer;
begin
  // Two connected ends in this process (no network): handy for testing
  SteamNetworkingSockets1.Plugin.CreateSocketPair(C1, C2, False, nil, nil);
  SteamNetworkingSockets1.Plugin.SendMessageToConnection(C1, @Data[0], Length(Data),
    k_nSteamNetworkingSend_Reliable, MsgNo);
  N := SteamNetworkingSockets1.Plugin.ReceiveMessages(C2, Msgs);
  for I := 0 to N - 1 do
  begin
    HandleMessage(Msgs[I]^.m_pData, Msgs[I]^.m_cbSize);
    SteamNetworkingSockets1.Plugin.ReleaseMessage(Msgs[I]);   // always
  end;
  SteamNetworkingSockets1.Plugin.CloseConnection(C1, 0, 'done', False);
  SteamNetworkingSockets1.Plugin.CloseConnection(C2, 0, '', False);
end;
```

* `ReceiveMessages` / `ReceiveMessagesOnGroup` and `ReleaseMessage` are
  hand-written helpers (`tools/plugin_extras/NetworkingSockets.pas.txt`):
  every received message must be released (`SteamNetworkingMessage_t`
  Release, bound from `SteamAPI_SteamNetworkingMessage_t_Release`).
* `SteamNetworkingIdentity`, `SteamNetworkingIPAddr` and
  `SteamNetworkingConfigValue_t` contain C unions; they are hand-written
  variant records (`tools/sdk_extras/`) whose field offsets
  `tools/verify_generated.py` checks against the C headers on every target.
  Fill an identity with `m_eType := k_ESteamNetworkingIdentityType_SteamID`,
  `m_cbSize := 8`, `m_steamID64 := ...`.
* Peer to peer: `CreateListenSocketP2P` / `ConnectP2P` (needs
  `TSteamNetworkingUtils.InitRelayNetworkAccess` first); by IP:
  `CreateListenSocketIP` / `ConnectByIPAddress`. Accept incoming
  connections in the status callback with `AcceptConnection`.
* Many methods still take raw pointers (identity / address records,
  message arrays); pass `@Record`.

## Contents

* [The component: TSteamNetworkingSockets](#the-component-tsteamnetworkingsockets)
  * [Events (3)](#events)
* [The plug-in: TSteamNetworkingSocketsPlugin](#the-plug-in-tsteamnetworkingsocketsplugin)
  * [Methods](#methods)
  * [Async methods](#async-methods)
  * [Properties](#properties)
* [Payload records](#payload-records)

## The component: TSteamNetworkingSockets

ISteamNetworkingSockets component: drop it next to a TSteamAPI (linked automatically at run time when the owner has exactly one, otherwise set SteamAPI). Its events are the ISteamNetworkingSockets callbacks; call the interface through `Plugin`.

| Member | Kind | Description |
|--------|------|-------------|
| `SteamAPI` | published property | The `TSteamAPI` this component belongs to. At run time a component whose owner has exactly one `TSteamAPI` links itself. |
| `Plugin` | public property | The `TSteamNetworkingSocketsPlugin` for calls; `nil` while Steam is not running. |
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
| `OnSteamNetConnectionStatusChangedCallback` | 1221 | [`SteamNetConnectionStatusChangedCallback_t`](#steamnetconnectionstatuschangedcallback_t) | This callback is posted whenever a connection is created, destroyed, or changes state. The m_info field will contain a complete description of the connection at the time the change occurred and the callback was posted. In particular, m_eState will have the new connection state. You will usually need to listen for this callback to know when: - A new connection arrives on a listen socket. m_info.m_hListenSocket will be set, m_eOldState = k_ESteamNetworkingConnectionState_None, and m_info.m_eState = k_ESteamNetworkingConnectionState_Connecting. See ISteamNetworkigSockets::AcceptConnection. - A connection you initiated has been accepted by the remote host. m_eOldState = k_ESteamNetworkingConnectionState_Connecting, and m_info.m_eState = k_ESteamNetworkingConnectionState_Connected. Some connections might transition to k_ESteamNetworkingConnectionState_FindingRoute first. - A connection has been actively rejected or closed by the remote host. m_eOldState = k_ESteamNetworkingConnectionState_Connecting or k_ESteamNetworkingConnectionState_Connected, and m_info.m_eState = k_ESteamNetworkingConnectionState_ClosedByPeer. m_info.m_eEndReason and m_info.m_szEndDebug will have for more details. NOTE: upon receiving this callback, you must still destroy the connection using ISteamNetworkingSockets::CloseConnection to free up local resources. (The details passed to the function are not used in this case, since the connection is already closed.) - A problem was detected with the connection, and it has been closed by the local host. The most common failure is timeout, but other configuration or authentication failures can cause this. m_eOldState = k_ESteamNetworkingConnectionState_Connecting or k_ESteamNetworkingConnectionState_Connected, and m_info.m_eState = k_ESteamNetworkingConnectionState_ProblemDetectedLocally. m_info.m_eEndReason and m_info.m_szEndDebug will have for more details. NOTE: upon receiving this callback, you must still destroy the connection using ISteamNetworkingSockets::CloseConnection to free up local resources. (The details passed to the function are not used in this case, since the connection is already closed.) Remember that callbacks are posted to a queue, and networking connections can change at any time. It is possible that the connection has already changed state by the time you process this callback. Also note that callbacks will be posted when connections are created and destroyed by your own API calls. |
| `OnSteamNetAuthenticationStatus` | 1222 | [`SteamNetAuthenticationStatus_t`](#steamnetauthenticationstatus_t) | A struct used to describe our readiness to participate in authenticated, encrypted communication. In order to do this we need: - The list of trusted CA certificates that might be relevant for this app. - A valid certificate issued by a CA. This callback is posted whenever the state of our readiness changes. |
| `OnSteamNetworkingFakeIPResult` | 1223 | [`SteamNetworkingFakeIPResult_t`](#steamnetworkingfakeipresult_t) | A struct used to describe a "fake IP" we have been assigned to use as an identifier. This callback is posted when ISteamNetworkingSoockets::BeginAsyncRequestFakeIP completes. See also ISteamNetworkingSockets::GetFakeIP. |

Handler signature (the IDE generates it when you double-click the event):

```pascal
procedure TForm1.SteamNetworkingSockets1SteamNetConnectionStatusChangedCallback(Sender: TObject; const AData: SteamNetConnectionStatusChangedCallback_t);
```

## The plug-in: TSteamNetworkingSocketsPlugin

ISteamNetworkingSockets plug-in. Registered by linking the unit; find it with @code(Steam.FindPlugin(TSteamNetworkingSocketsPlugin)).

Reach it through the component (`SteamNetworkingSockets1.Plugin`) or the core:

```pascal
P := TSteamNetworkingSocketsPlugin(Steam.FindPlugin(TSteamNetworkingSocketsPlugin));   // Delphi also: Steam.Plugin<TSteamNetworkingSocketsPlugin>
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
| [`CreateListenSocketIP`](#createlistensocketip) | Creates a "server" socket that listens for clients to connect to by calling ConnectByIPAddress, over ordinary UDP (IPv4 or IPv6) You must select a specific ... |
| [`ConnectByIPAddress`](#connectbyipaddress) | Creates a connection and begins talking to a "server" over UDP at the given IPv4 or IPv6 address. The remote host must be listening with a matching call to ... |
| [`CreateListenSocketP2P`](#createlistensocketp2p) | Like CreateListenSocketIP, but clients will connect using ConnectP2P. nLocalVirtualPort specifies how clients can connect to this socket using ConnectP2P. ... |
| [`ConnectP2P`](#connectp2p) | Begin connecting to a peer that is identified using a platform-specific identifier. This uses the default rendezvous service, which depends on the platform ... |
| [`AcceptConnection`](#acceptconnection) | Accept an incoming connection that has been received on a listen socket. When a connection attempt is received (perhaps after a few basic handshake packets ... |
| [`CloseConnection`](#closeconnection) | Disconnects from the remote host and invalidates the connection handle. Any unread data on the connection is discarded. nReason is an application defined ... |
| [`CloseListenSocket`](#closelistensocket) | Destroy a listen socket. All the connections that were accepting on the listen socket are closed ungracefully. |
| [`SetConnectionUserData`](#setconnectionuserdata) | Set connection user data. the data is returned in the following places - You can query it using GetConnectionUserData. - The SteamNetworkingmessage_t ... |
| [`GetConnectionUserData`](#getconnectionuserdata) | Fetch connection user data. Returns -1 if handle is invalid or if you haven't set any userdata on the connection. |
| [`SetConnectionName`](#setconnectionname) | Set a name for the connection, used mostly for debugging. |
| [`GetConnectionName`](#getconnectionname) | Fetch connection name. Returns false if handle is invalid. |
| [`SendMessageToConnection`](#sendmessagetoconnection) | Send a message to the remote host on the specified connection. nSendFlags determines the delivery guarantees that will be provided, when data should be ... |
| [`SendMessages`](#sendmessages) | Send one or more messages without copying the message payload. This is the most efficient way to send messages. To use this function, you must first ... |
| [`FlushMessagesOnConnection`](#flushmessagesonconnection) | Flush any messages waiting on the Nagle timer and send them at the next transmission opportunity (often that means right now). If Nagle is enabled (it's on ... |
| [`ReceiveMessagesOnConnection`](#receivemessagesonconnection) | Fetch the next available message(s) from the connection, if any. Returns the number of messages returned into your array, up to nMaxMessages. If the ... |
| [`GetConnectionInfo`](#getconnectioninfo) | Returns basic information about the high-level state of the connection. |
| [`GetConnectionRealTimeStatus`](#getconnectionrealtimestatus) | Returns a small set of information about the real-time state of the connection and the queue status of each lane. - pStatus may be NULL if the information ... |
| [`GetDetailedConnectionStatus`](#getdetailedconnectionstatus) | Returns detailed connection stats in text format. Useful for dumping to a log, etc. Returns: -1 failure (bad connection handle) 0 OK, your buffer was filled ... |
| [`GetListenSocketAddress`](#getlistensocketaddress) | Returns local IP and port that a listen socket created using CreateListenSocketIP is bound to. An IPv6 address of ::0 means "any IPv4 or IPv6" An IPv6 ... |
| [`CreateSocketPair`](#createsocketpair) | Create a pair of connections that are talking to each other, e.g. a loopback connection. This is very useful for testing, or so that your client/server code ... |
| [`ConfigureConnectionLanes`](#configureconnectionlanes) | Configure multiple outbound messages streams ("lanes") on a connection, and control head-of-line blocking between them. Messages within a given lane are ... |
| [`GetIdentity`](#getidentity) | Get the identity assigned to this interface. E.g. on Steam, this is the user's SteamID, or for the gameserver interface, the SteamID assigned to the ... |
| [`InitAuthentication`](#initauthentication) | Indicate our desire to be ready participate in authenticated communications. If we are currently not ready, then steps will be taken to obtain the necessary ... |
| [`GetAuthenticationStatus`](#getauthenticationstatus) | Query our readiness to participate in authenticated communications. A SteamNetAuthenticationStatus_t callback is posted any time this status changes, but ... |
| [`CreatePollGroup`](#createpollgroup) | Create a new poll group. You should destroy the poll group when you are done using DestroyPollGroup. |
| [`DestroyPollGroup`](#destroypollgroup) | Destroy a poll group created with CreatePollGroup(). If there are any connections in the poll group, they are removed from the group, and left in a state ... |
| [`SetConnectionPollGroup`](#setconnectionpollgroup) | Assign a connection to a poll group. Note that a connection may only belong to a single poll group. Adding a connection to a poll group implicitly removes ... |
| [`ReceiveMessagesOnPollGroup`](#receivemessagesonpollgroup) | Same as ReceiveMessagesOnConnection, but will return the next messages available on any connection in the poll group. Examine ... |
| [`ReceivedRelayAuthTicket`](#receivedrelayauthticket) | Call this when you receive a ticket from your backend / matchmaking system. Puts the ticket into a persistent cache, and optionally returns the parsed ... |
| [`FindRelayAuthTicketForServer`](#findrelayauthticketforserver) | Search cache for a ticket to talk to the server on the specified virtual port. If found, returns the number of seconds until the ticket expires, and ... |
| [`ConnectToHostedDedicatedServer`](#connecttohosteddedicatedserver) | Client call to connect to a server hosted in a Valve data center, on the specified virtual port. You must have placed a ticket for this server into the ... |
| [`GetHostedDedicatedServerPort`](#gethosteddedicatedserverport) | Returns the value of the SDR_LISTEN_PORT environment variable. This is the UDP server your server will be listening on. This will configured automatically ... |
| [`GetHostedDedicatedServerPOPID`](#gethosteddedicatedserverpopid) | Returns 0 if SDR_LISTEN_PORT is not set. Otherwise, returns the data center the server is running in. This will be k_SteamDatagramPOPID_dev in ... |
| [`GetHostedDedicatedServerAddress`](#gethosteddedicatedserveraddress) | Return info about the hosted server. This contains the PoPID of the server, and opaque routing information that can be used by the relays to send traffic to ... |
| [`CreateHostedDedicatedServerListenSocket`](#createhosteddedicatedserverlistensocket) | Create a listen socket on the specified virtual port. The physical UDP port to use will be determined by the SDR_LISTEN_PORT environment variable. If a UDP ... |
| [`GetGameCoordinatorServerLogin`](#getgamecoordinatorserverlogin) | Generate an authentication blob that can be used to securely login with your backend, using SteamDatagram_ParseHostedServerLogin. (See ... |
| [`ConnectP2PCustomSignaling`](#connectp2pcustomsignaling) | Create a P2P "client" connection that does signaling over a custom rendezvous/signaling channel. pSignaling points to a new object that you create just for ... |
| [`ReceivedP2PCustomSignal`](#receivedp2pcustomsignal) | Called when custom signaling has received a message. When your signaling channel receives a message, it should save off whatever routing information was in ... |
| [`GetCertificateRequest`](#getcertificaterequest) | Get blob that describes a certificate request. You can send this to your game coordinator. Upon entry, *pcbBlob should contain the size of the buffer. On ... |
| [`SetCertificate`](#setcertificate) | Set the certificate. The certificate blob should be the output of SteamDatagram_CreateCert. |
| [`ResetIdentity`](#resetidentity) | Reset the identity associated with this instance. Any open connections are closed. Any previous certificates, etc are discarded. You can pass a specific ... |
| [`RunCallbacks`](#runcallbacks) | Invoke all callback functions queued for this interface. See k_ESteamNetworkingConfig_Callback_ConnectionStatusChanged, etc You don't need to call this if ... |
| [`BeginAsyncRequestFakeIP`](#beginasyncrequestfakeip) | Begin asynchronous process of allocating a fake IPv4 address that other peers can use to contact us via P2P. IP addresses returned by this function are ... |
| [`GetFakeIP`](#getfakeip) | Return info about the FakeIP and port(s) that we have been assigned, if any. idxFirstPort is currently reserved and must be zero. Make sure and check ... |
| [`CreateListenSocketP2PFakeIP`](#createlistensocketp2pfakeip) | Create a listen socket that will listen for P2P connections sent to our FakeIP. A peer can initiate connections to this listen socket by calling ... |
| [`GetRemoteFakeIPForConnection`](#getremotefakeipforconnection) | If the connection was initiated using the "FakeIP" system, then we we can get an IP address for the remote host. If the remote host had a global FakeIP at ... |
| [`CreateFakeUDPPort`](#createfakeudpport) | Get an interface that can be used like a UDP port to send/receive datagrams to a FakeIP address. This is intended to make it easy to port existing UDP-based ... |
| [`ReleaseMessage`](#releasemessage) | Gives a message from `ReceiveMessages` / `ReceiveMessagesOnGroup` (or the raw ReceiveMessages... methods) back to Steam. Call it once for every message, ... |
| [`ReceiveMessages`](#receivemessages) | Up to Length(AMessages) waiting messages of a connection, into AMessages from index 0. Returns: (How many were stored, 0 when none, -1 for an invalid ... |
| [`ReceiveMessagesOnGroup`](#receivemessagesongroup) | `ReceiveMessages` for every connection of a poll group. |

#### CreateListenSocketIP

```pascal
function CreateListenSocketIP(localAddress: Pointer; nOptions: Integer; pOptions: Pointer): HSteamListenSocket;
```

Creates a "server" socket that listens for clients to connect to by calling ConnectByIPAddress, over ordinary UDP (IPv4 or IPv6) You must select a specific local port to listen on and set it the port field of the local address. Usually you will set the IP portion of the address to zero (SteamNetworkingIPAddr::Clear()). This means that you will not bind to any particular local interface (i.e. the same as INADDR_ANY in plain socket code). Furthermore, if possible the socket will be bound in "dual stack" mode, which means that it can accept both IPv4 and IPv6 client connections. If you really do wish to bind a particular interface, then set the local address to the appropriate IPv4 or IPv6 IP. If you need to set any initial config options, pass them here. See SteamNetworkingConfigValue_t for more about why this is preferable to setting the options "immediately" after creation. When a client attempts to connect, a SteamNetConnectionStatusChangedCallback_t will be posted. The connection will be in the connecting state.

#### ConnectByIPAddress

```pascal
function ConnectByIPAddress(address: Pointer; nOptions: Integer; pOptions: Pointer): HSteamNetConnection;
```

Creates a connection and begins talking to a "server" over UDP at the given IPv4 or IPv6 address. The remote host must be listening with a matching call to CreateListenSocketIP on the specified port. A SteamNetConnectionStatusChangedCallback_t callback will be triggered when we start connecting, and then another one on either timeout or successful connection. If the server does not have any identity configured, then their network address will be the only identity in use. Or, the network host may provide a platform-specific identity with or without a valid certificate to authenticate that identity. (These details will be contained in the SteamNetConnectionStatusChangedCallback_t.) It's up to your application to decide whether to allow the connection. By default, all connections will get basic encryption sufficient to prevent casual eavesdropping. But note that without certificates (or a shared secret distributed through some other out-of-band mechanism), you don't have any way of knowing who is actually on the other end, and thus are vulnerable to man-in-the-middle attacks. If you need to set any initial config options, pass them here. See SteamNetworkingConfigValue_t for more about why this is preferable to setting the options "immediately" after creation.

#### CreateListenSocketP2P

```pascal
function CreateListenSocketP2P(nLocalVirtualPort: Integer; nOptions: Integer; pOptions: Pointer): HSteamListenSocket;
```

Like CreateListenSocketIP, but clients will connect using ConnectP2P. nLocalVirtualPort specifies how clients can connect to this socket using ConnectP2P. It's very common for applications to only have one listening socket; in that case, use zero. If you need to open multiple listen sockets and have clients be able to connect to one or the other, then nLocalVirtualPort should be a small integer (<1000) unique to each listen socket you create. If you use this, you probably want to call ISteamNetworkingUtils::InitRelayNetworkAccess() when your app initializes. If you are listening on a dedicated servers in known data center, then you can listen using this function instead of CreateHostedDedicatedServerListenSocket, to allow clients to connect without a ticket. Any user that owns the app and is signed into Steam will be able to attempt to connect to your server. Also, a connection attempt may require the client to be connected to Steam, which is one more moving part that may fail. When tickets are used, then once a ticket is obtained, a client can connect to your server even if they got disconnected from Steam or Steam is offline. If you need to set any initial config options, pass them here. See SteamNetworkingConfigValue_t for more about why this is preferable to setting the options "immediately" after creation.

#### ConnectP2P

```pascal
function ConnectP2P(identityRemote: Pointer; nRemoteVirtualPort: Integer; nOptions: Integer; pOptions: Pointer): HSteamNetConnection;
```

Begin connecting to a peer that is identified using a platform-specific identifier. This uses the default rendezvous service, which depends on the platform and library configuration. (E.g. on Steam, it goes through the steam backend.) If you need to set any initial config options, pass them here. See SteamNetworkingConfigValue_t for more about why this is preferable to setting the options "immediately" after creation. To use your own signaling service, see: - ConnectP2PCustomSignaling - k_ESteamNetworkingConfig_Callback_CreateConnectionSignaling.

#### AcceptConnection

```pascal
function AcceptConnection(hConn: HSteamNetConnection): EResult;
```

Accept an incoming connection that has been received on a listen socket. When a connection attempt is received (perhaps after a few basic handshake packets have been exchanged to prevent trivial spoofing), a connection interface object is created in the k_ESteamNetworkingConnectionState_Connecting state and a SteamNetConnectionStatusChangedCallback_t is posted. At this point, your application MUST either accept or close the connection. (It may not ignore it.) Accepting the connection will transition it either into the connected state, or the finding route state, depending on the connection type. You should take action within a second or two, because accepting the connection is what actually sends the reply notifying the client that they are connected. If you delay taking action, from the client's perspective it is the same as the network being unresponsive, and the client may timeout the connection attempt. In other words, the client cannot distinguish between a delay caused by network problems and a delay caused by the application. This means that if your application goes for more than a few seconds without processing callbacks (for example, while loading a map), then there is a chance that a client may attempt to connect in that interval and fail due to timeout. If the application does not respond to the connection attempt in a timely manner, and we stop receiving communication from the client, the connection attempt will be timed out locally, transitioning the connection to the k_ESteamNetworkingConnectionState_ProblemDetectedLocally state. The client may also close the connection before it is accepted, and a transition to the k_ESteamNetworkingConnectionState_ClosedByPeer is also possible depending the exact sequence of events. Returns k_EResultInvalidParam if the handle is invalid. Returns k_EResultInvalidState if the connection is not in the appropriate state. (Remember that the connection state could change in between the time that the notification being posted to the queue and when it is received by the application.) A note about connection configuration options. If you need to set any configuration options that are common to all connections accepted through a particular listen socket, consider setting the options on the listen socket, since such options are inherited automatically. If you really do need to set options that are connection specific, it is safe to set them on the connection before accepting the connection.

#### CloseConnection

```pascal
function CloseConnection(hPeer: HSteamNetConnection; nReason: Integer; const pszDebug: string; bEnableLinger: Boolean): Boolean;
```

Disconnects from the remote host and invalidates the connection handle. Any unread data on the connection is discarded. nReason is an application defined code that will be received on the other end and recorded (when possible) in backend analytics. The value should come from a restricted range. (See ESteamNetConnectionEnd.) If you don't need to communicate any information to the remote host, and do not want analytics to be able to distinguish "normal" connection terminations from "exceptional" ones, You may pass zero, in which case the generic value of k_ESteamNetConnectionEnd_App_Generic will be used. pszDebug is an optional human-readable diagnostic string that will be received by the remote host and recorded (when possible) in backend analytics. If you wish to put the socket into a "linger" state, where an attempt is made to flush any remaining sent data, use bEnableLinger=true. Otherwise reliable data is not flushed. If the connection has already ended and you are just freeing up the connection interface, the reason code, debug string, and linger flag are ignored.

#### CloseListenSocket

```pascal
function CloseListenSocket(hSocket: HSteamListenSocket): Boolean;
```

Destroy a listen socket. All the connections that were accepting on the listen socket are closed ungracefully.

#### SetConnectionUserData

```pascal
function SetConnectionUserData(hPeer: HSteamNetConnection; nUserData: Int64): Boolean;
```

Set connection user data. the data is returned in the following places - You can query it using GetConnectionUserData. - The SteamNetworkingmessage_t structure. - The SteamNetConnectionInfo_t structure. (Which is a member of SteamNetConnectionStatusChangedCallback_t -- but see WARNINGS below!!!!) Do you need to set this atomically when the connection is created? See k_ESteamNetworkingConfig_ConnectionUserData. WARNING: Be *very careful* when using the value provided in callbacks structs. Callbacks are queued, and the value that you will receive in your callback is the userdata that was effective at the time the callback was queued. There are subtle race conditions that can happen if you don't understand this! If any incoming messages for this connection are queued, the userdata field is updated, so that when when you receive messages (e.g. with ReceiveMessagesOnConnection), they will always have the very latest userdata. So the tricky race conditions that can happen with callbacks do not apply to retrieving messages. Returns false if the handle is invalid.

#### GetConnectionUserData

```pascal
function GetConnectionUserData(hPeer: HSteamNetConnection): Int64;
```

Fetch connection user data. Returns -1 if handle is invalid or if you haven't set any userdata on the connection.

#### SetConnectionName

```pascal
procedure SetConnectionName(hPeer: HSteamNetConnection; const pszName: string);
```

Set a name for the connection, used mostly for debugging.

#### GetConnectionName

```pascal
function GetConnectionName(hPeer: HSteamNetConnection; pszName: PAnsiChar; nMaxLen: Integer): Boolean;
```

Fetch connection name. Returns false if handle is invalid.

#### SendMessageToConnection

```pascal
function SendMessageToConnection(hConn: HSteamNetConnection; pData: Pointer; cbData: UInt32; nSendFlags: Integer; var pOutMessageNumber: Int64): EResult;
```

Send a message to the remote host on the specified connection. nSendFlags determines the delivery guarantees that will be provided, when data should be buffered, etc. E.g. k_nSteamNetworkingSend_Unreliable Note that the semantics we use for messages are not precisely the same as the semantics of a standard "stream" socket. (SOCK_STREAM) For an ordinary stream socket, the boundaries between chunks are not considered relevant, and the sizes of the chunks of data written will not necessarily match up to the sizes of the chunks that are returned by the reads on the other end. The remote host might read a partial chunk, or chunks might be coalesced. For the message semantics used here, however, the sizes WILL match. Each send call will match a successful read call on the remote host one-for-one. If you are porting existing stream-oriented code to the semantics of reliable messages, your code should work the same, since reliable message semantics are more strict than stream semantics. The only caveat is related to performance: there is per-message overhead to retain the message sizes, and so if your code sends many small chunks of data, performance will suffer. Any code based on stream sockets that does not write excessively small chunks will work without any changes. The pOutMessageNumber is an optional pointer to receive the message number assigned to the message, if sending was successful. Returns: - k_EResultInvalidParam: invalid connection handle, or the individual message is too big. (See k_cbMaxSteamNetworkingSocketsMessageSizeSend) - k_EResultInvalidState: connection is in an invalid state - k_EResultNoConnection: connection has ended - k_EResultIgnored: You used k_nSteamNetworkingSend_NoDelay, and the message was dropped because we were not ready to send it. - k_EResultLimitExceeded: there was already too much data queued to be sent. (See k_ESteamNetworkingConfig_SendBufferSize).

#### SendMessages

```pascal
procedure SendMessages(nMessages: Integer; pMessages: Pointer; var pOutMessageNumberOrResult: Int64; bDeleteFailedMessages: Boolean);
```

Send one or more messages without copying the message payload. This is the most efficient way to send messages. To use this function, you must first allocate a message object using ISteamNetworkingUtils::AllocateMessage. (Do not declare one on the stack or allocate your own.) You should fill in the message payload. You can either let it allocate the buffer for you and then fill in the payload, or if you already have a buffer allocated, you can just point m_pData at your buffer and set the callback to the appropriate function to free it. Note that if you use your own buffer, it MUST remain valid until the callback is executed. And also note that your callback can be invoked at any time from any thread (perhaps even before SendMessages returns!), so it MUST be fast and threadsafe. You MUST also fill in: - m_conn - the handle of the connection to send the message to - m_nFlags - bitmask of k_nSteamNetworkingSend_xxx flags. - m_idxLane - the lane to send the message on. AllocateMessage will set this to zero, so you can ignore this if you are not using multiple lanes. All other fields are currently reserved and should not be modified. pOutMessageNumberOrResult is an optional array that will receive, for each message, the message number that was assigned to the message if sending was successful. If sending failed, then a negative EResult value is placed into the array. For example, the array will hold -k_EResultInvalidState if the connection was in an invalid state. See ISteamNetworkingSockets::SendMessageToConnection for possible failure codes. Once a message fails to send on a connection, any further messages in the array going to the same connection will not be attempted. The pOutMessageNumberOrResult for such message will always be set to 0. (Note that 0 is never used as a message number.) bDeleteFailedMessages determines what happens to messages that fail to send: - false: Your pointer array will be modified, and the pointers to messages that were successfully queued will be replaced with nullptr. The library has taken ownership and you must not access them. They will be released by the library when they are no longer needed. Any messages that were not queued (either failed to send, or were not attempted because an earlier message for the same connection failed) will be left in place. You can release these messages or try to send them later. - true: The caller's pointer array is not modified, and the library assumes ownership of all messages. Messages that fail or are not attempted due to earlier failure on the same connection will be released immediately.

#### FlushMessagesOnConnection

```pascal
function FlushMessagesOnConnection(hConn: HSteamNetConnection): EResult;
```

Flush any messages waiting on the Nagle timer and send them at the next transmission opportunity (often that means right now). If Nagle is enabled (it's on by default) then when calling SendMessageToConnection the message will be buffered, up to the Nagle time before being sent, to merge small messages into the same packet. (See k_ESteamNetworkingConfig_NagleTime) Returns: k_EResultInvalidParam: invalid connection handle k_EResultInvalidState: connection is in an invalid state k_EResultNoConnection: connection has ended k_EResultIgnored: We weren't (yet) connected, so this operation has no effect.

#### ReceiveMessagesOnConnection

```pascal
function ReceiveMessagesOnConnection(hConn: HSteamNetConnection; ppOutMessages: Pointer; nMaxMessages: Integer): Integer;
```

Fetch the next available message(s) from the connection, if any. Returns the number of messages returned into your array, up to nMaxMessages. If the connection handle is invalid, -1 is returned. The order of the messages returned in the array is relevant. Reliable messages will be received in the order they were sent (and with the same sizes --- see SendMessageToConnection for on this subtle difference from a stream socket). Unreliable messages may be dropped, or delivered out of order with respect to each other or with respect to reliable messages. The same unreliable message may be received multiple times. If any messages are returned, you MUST call SteamNetworkingMessage_t::Release() on each of them free up resources after you are done. It is safe to keep the object alive for a little while (put it into some queue, etc), and you may call Release() from any thread.

#### GetConnectionInfo

```pascal
function GetConnectionInfo(hConn: HSteamNetConnection; var pInfo: SteamNetConnectionInfo_t): Boolean;
```

Returns basic information about the high-level state of the connection.

#### GetConnectionRealTimeStatus

```pascal
function GetConnectionRealTimeStatus(hConn: HSteamNetConnection; var pStatus: SteamNetConnectionRealTimeStatus_t; nLanes: Integer; pLanes: Pointer): EResult;
```

Returns a small set of information about the real-time state of the connection and the queue status of each lane. - pStatus may be NULL if the information is not desired. (E.g. you are only interested in the lane information.) - On entry, nLanes specifies the length of the pLanes array. This may be 0 if you do not wish to receive any lane data. It's OK for this to be smaller than the total number of configured lanes. - pLanes points to an array that will receive lane-specific info. It can be NULL if this is not needed. Return value: - k_EResultNoConnection - connection handle is invalid or connection has been closed. - k_EResultInvalidParam - nLanes is bad.

#### GetDetailedConnectionStatus

```pascal
function GetDetailedConnectionStatus(hConn: HSteamNetConnection; pszBuf: PAnsiChar; cbBuf: Integer): Integer;
```

Returns detailed connection stats in text format. Useful for dumping to a log, etc. Returns: -1 failure (bad connection handle) 0 OK, your buffer was filled in and '\0'-terminated >0 Your buffer was either nullptr, or it was too small and the text got truncated. Try again with a buffer of at least N bytes.

#### GetListenSocketAddress

```pascal
function GetListenSocketAddress(hSocket: HSteamListenSocket; var address: SteamNetworkingIPAddr): Boolean;
```

Returns local IP and port that a listen socket created using CreateListenSocketIP is bound to. An IPv6 address of ::0 means "any IPv4 or IPv6" An IPv6 address of ::ffff:0000:0000 means "any IPv4".

#### CreateSocketPair

```pascal
function CreateSocketPair(var pOutConnection1: HSteamNetConnection; var pOutConnection2: HSteamNetConnection; bUseNetworkLoopback: Boolean; pPeerIdentity1: Pointer; pPeerIdentity2: Pointer): Boolean;
```

Create a pair of connections that are talking to each other, e.g. a loopback connection. This is very useful for testing, or so that your client/server code can work the same even when you are running a local "server". The two connections will immediately be placed into the connected state, and no callbacks will be posted immediately. After this, if you close either connection, the other connection will receive a callback, exactly as if they were communicating over the network. You must close *both* sides in order to fully clean up the resources! By default, internal buffers are used, completely bypassing the network, the chopping up of messages into packets, encryption, copying the payload, etc. This means that loopback packets, by default, will not simulate lag or loss. Passing true for bUseNetworkLoopback will cause the socket pair to send packets through the local network loopback device (127.0.0.1) on ephemeral ports. Fake lag and loss are supported in this case, and CPU time is expended to encrypt and decrypt. If you wish to assign a specific identity to either connection, you may pass a particular identity. Otherwise, if you pass nullptr, the respective connection will assume a generic "localhost" identity. If you use real network loopback, this might be translated to the actual bound loopback port. Otherwise, the port will be zero. NOTE: For historical reasons, each identity refers to the *remote* identity that the corresponding connection will observe in connection state callbacks and GetConnectionInfo: - pPeerIdentity1: remote identity observed by connection 1, local identity of connection 2 - pPeerIdentity2: remote identity observed by connection 2, local identity of connection 1.

#### ConfigureConnectionLanes

```pascal
function ConfigureConnectionLanes(hConn: HSteamNetConnection; nNumLanes: Integer; pLanePriorities: Pointer; pLaneWeights: Pointer): EResult;
```

Configure multiple outbound messages streams ("lanes") on a connection, and control head-of-line blocking between them. Messages within a given lane are always sent in the order they are queued, but messages from different lanes may be sent out of order. Each lane has its own message number sequence. The first message sent on each lane will be assigned the number 1. Each lane has a "priority". Lanes with higher numeric values will only be processed when all lanes with lower number values are empty. The magnitudes of the priority values are not relevant, only their sort order. Each lane also is assigned a weight, which controls the approximate proportion of the bandwidth that will be consumed by the lane, relative to other lanes of the same priority. (This is assuming the lane stays busy. An idle lane does not build up "credits" to be be spent once a message is queued.) This value is only meaningful as a proportion, relative to other lanes with the same priority. For lanes with different priorities, the strict priority order will prevail, and their weights relative to each other are not relevant. Thus, if a lane has a unique priority value, the weight value for that lane is not relevant. Example: 3 lanes, with priorities [ 0, 10, 10 ] and weights [ (NA), 20, 5 ]. Messages sent on the first will always be sent first, before messages in the other two lanes. Its weight value is irrelevant, since there are no other lanes with priority=0. The other two lanes will share bandwidth, with the second and third lanes sharing bandwidth using a ratio of approximately 4:1. (The weights [ NA, 4, 1 ] would be equivalent.) Notes: - At the time of this writing, some code has performance cost that is linear in the number of lanes, so keep the number of lanes to an absolute minimum. 3 or so is fine; >8 is a lot. The max number of lanes on Steam is 255, which is a very large number and not recommended! If you are compiling this library from source, see STEAMNETWORKINGSOCKETS_MAX_LANES.) - Lane priority values may be any int. Their absolute value is not relevant, only the order matters. - Weights must be positive, and due to implementation details, they are restricted to 16-bit values. The absolute magnitudes don't matter, just the proportions. - Messages sent on a lane index other than 0 have a small overhead on the wire, so for maximum wire efficiency, lane 0 should be the "most common" lane, regardless of priorities or weights. - A connection has a single lane by default. Calling this function with nNumLanes=1 is legal, but pointless, since the priority and weight values are irrelevant in that case. - You may reconfigure connection lanes at any time, however reducing the number of lanes is not allowed. - Reconfiguring lanes might restart any bandwidth sharing balancing. Usually you will call this function once, near the start of the connection, perhaps after exchanging a few messages. - To assign all lanes the same priority, you may use pLanePriorities=NULL. - If you wish all lanes with the same priority to share bandwidth equally (or if no two lanes have the same priority value, and thus weight values are irrelevant), you may use pLaneWeights=NULL - Priorities and weights determine the order that messages are SENT on the wire. There are NO GUARANTEES on the order that messages are RECEIVED! Due to packet loss, out-of-order delivery, and subtle details of packet serialization, messages might still be received slightly out-of-order! The *only* strong guarantee is that *reliable* messages on the *same lane* will be delivered in the order they are sent. - Each host configures the lanes for the packets they send; the lanes for the flow in one direction are completely unrelated to the lanes in the opposite direction. Return value: - k_EResultNoConnection - bad hConn - k_EResultInvalidParam - Invalid number of lanes, bad weights, or you tried to reduce the number of lanes - k_EResultInvalidState - Connection is already dead, etc See also: SteamNetworkingMessage_t::m_idxLane.

#### GetIdentity

```pascal
function GetIdentity(var pIdentity: SteamNetworkingIdentity): Boolean;
```

Get the identity assigned to this interface. E.g. on Steam, this is the user's SteamID, or for the gameserver interface, the SteamID assigned to the gameserver. Returns false and sets the result to an invalid identity if we don't know our identity yet. (E.g. GameServer has not logged in. On Steam, the user will know their SteamID even if they are not signed into Steam.).

#### InitAuthentication

```pascal
function InitAuthentication: ESteamNetworkingAvailability;
```

Indicate our desire to be ready participate in authenticated communications. If we are currently not ready, then steps will be taken to obtain the necessary certificates. (This includes a certificate for us, as well as any CA certificates needed to authenticate peers.) You can call this at program init time if you know that you are going to be making authenticated connections, so that we will be ready immediately when those connections are attempted. (Note that essentially all connections require authentication, with the exception of ordinary UDP connections with authentication disabled using k_ESteamNetworkingConfig_IP_AllowWithoutAuth.) If you don't call this function, we will wait until a feature is utilized that that necessitates these resources. You can also call this function to force a retry, if failure has occurred. Once we make an attempt and fail, we will not automatically retry. In this respect, the behavior of the system after trying and failing is the same as before the first attempt: attempting authenticated communication or calling this function will call the system to attempt to acquire the necessary resources. You can use GetAuthenticationStatus or listen for SteamNetAuthenticationStatus_t to monitor the status. Returns the current value that would be returned from GetAuthenticationStatus.

#### GetAuthenticationStatus

```pascal
function GetAuthenticationStatus(var pDetails: SteamNetAuthenticationStatus_t): ESteamNetworkingAvailability;
```

Query our readiness to participate in authenticated communications. A SteamNetAuthenticationStatus_t callback is posted any time this status changes, but you can use this function to query it at any time. The value of SteamNetAuthenticationStatus_t::m_eAvail is returned. If you only want this high level status, you can pass NULL for pDetails. If you want further details, pass non-NULL to receive them.

#### CreatePollGroup

```pascal
function CreatePollGroup: HSteamNetPollGroup;
```

Create a new poll group. You should destroy the poll group when you are done using DestroyPollGroup.

#### DestroyPollGroup

```pascal
function DestroyPollGroup(hPollGroup: HSteamNetPollGroup): Boolean;
```

Destroy a poll group created with CreatePollGroup(). If there are any connections in the poll group, they are removed from the group, and left in a state where they are not part of any poll group. Returns false if passed an invalid poll group handle.

#### SetConnectionPollGroup

```pascal
function SetConnectionPollGroup(hConn: HSteamNetConnection; hPollGroup: HSteamNetPollGroup): Boolean;
```

Assign a connection to a poll group. Note that a connection may only belong to a single poll group. Adding a connection to a poll group implicitly removes it from any other poll group it is in. You can pass k_HSteamNetPollGroup_Invalid to remove a connection from its current poll group without adding it to a new poll group. If there are received messages currently pending on the connection, an attempt is made to add them to the queue of messages for the poll group in approximately the order that would have applied if the connection was already part of the poll group at the time that the messages were received. Returns false if the connection handle is invalid, or if the poll group handle is invalid (and not k_HSteamNetPollGroup_Invalid).

#### ReceiveMessagesOnPollGroup

```pascal
function ReceiveMessagesOnPollGroup(hPollGroup: HSteamNetPollGroup; ppOutMessages: Pointer; nMaxMessages: Integer): Integer;
```

Same as ReceiveMessagesOnConnection, but will return the next messages available on any connection in the poll group. Examine SteamNetworkingMessage_t::m_conn to know which connection. (SteamNetworkingMessage_t::m_nConnUserData might also be useful.) Delivery order of messages among different connections will usually match the order that the last packet was received which completed the message. But this is not a strong guarantee, especially for packets received right as a connection is being assigned to poll group. Delivery order of messages on the same connection is well defined and the same guarantees are present as mentioned in ReceiveMessagesOnConnection. (But the messages are not grouped by connection, so they will not necessarily appear consecutively in the list; they may be interleaved with messages for other connections.).

#### ReceivedRelayAuthTicket

```pascal
function ReceivedRelayAuthTicket(pvTicket: Pointer; cbTicket: Integer; pOutParsedTicket: Pointer): Boolean;
```

Call this when you receive a ticket from your backend / matchmaking system. Puts the ticket into a persistent cache, and optionally returns the parsed ticket. See stamdatagram_ticketgen.h for more details.

#### FindRelayAuthTicketForServer

```pascal
function FindRelayAuthTicketForServer(identityGameServer: Pointer; nRemoteVirtualPort: Integer; pOutParsedTicket: Pointer): Integer;
```

Search cache for a ticket to talk to the server on the specified virtual port. If found, returns the number of seconds until the ticket expires, and optionally the complete cracked ticket. Returns 0 if we don't have a ticket. Typically this is useful just to confirm that you have a ticket, before you call ConnectToHostedDedicatedServer to connect to the server.

#### ConnectToHostedDedicatedServer

```pascal
function ConnectToHostedDedicatedServer(identityTarget: Pointer; nRemoteVirtualPort: Integer; nOptions: Integer; pOptions: Pointer): HSteamNetConnection;
```

Client call to connect to a server hosted in a Valve data center, on the specified virtual port. You must have placed a ticket for this server into the cache, or else this connect attempt will fail! If you are not issuing your own tickets, then to connect to a dedicated server via SDR in auto-ticket mode, use ConnectP2P. (The server must be configured to allow this type of connection by listening using CreateListenSocketP2P.) You may wonder why tickets are stored in a cache, instead of simply being passed as an argument here. The reason is to make reconnection to a gameserver robust, even if the client computer loses connection to Steam or the central backend, or the app is restarted or crashes, etc. If you use this, you probably want to call ISteamNetworkingUtils::InitRelayNetworkAccess() when your app initializes If you need to set any initial config options, pass them here. See SteamNetworkingConfigValue_t for more about why this is preferable to setting the options "immediately" after creation.

#### GetHostedDedicatedServerPort

```pascal
function GetHostedDedicatedServerPort: UInt16;
```

Returns the value of the SDR_LISTEN_PORT environment variable. This is the UDP server your server will be listening on. This will configured automatically for you in production environments. In development, you'll need to set it yourself. See https://partner.steamgames.com/doc/api/ISteamNetworkingSockets for more information on how to configure dev environments.

#### GetHostedDedicatedServerPOPID

```pascal
function GetHostedDedicatedServerPOPID: SteamNetworkingPOPID;
```

Returns 0 if SDR_LISTEN_PORT is not set. Otherwise, returns the data center the server is running in. This will be k_SteamDatagramPOPID_dev in non-production environment.

#### GetHostedDedicatedServerAddress

```pascal
function GetHostedDedicatedServerAddress(pRouting: Pointer): EResult;
```

Return info about the hosted server. This contains the PoPID of the server, and opaque routing information that can be used by the relays to send traffic to your server. You will need to send this information to your backend, and put it in tickets, so that the relays will know how to forward traffic from clients to your server. See SteamDatagramRelayAuthTicket for more info. Also, note that the routing information is contained in SteamDatagramGameCoordinatorServerLogin, so if possible, it's preferred to use GetGameCoordinatorServerLogin to send this info to your game coordinator service, and also login securely at the same time. On a successful exit, k_EResultOK is returned Unsuccessful exit: - Something other than k_EResultOK is returned. - k_EResultInvalidState: We are not configured to listen for SDR (SDR_LISTEN_SOCKET is not set.) - k_EResultPending: we do not (yet) have the authentication information needed. (See GetAuthenticationStatus.) If you use environment variables to pre-fetch the network config, this data should always be available immediately. - A non-localized diagnostic debug message will be placed in m_data that describes the cause of the failure. NOTE: The returned blob is not encrypted. Send it to your backend, but don't directly share it with clients.

#### CreateHostedDedicatedServerListenSocket

```pascal
function CreateHostedDedicatedServerListenSocket(nLocalVirtualPort: Integer; nOptions: Integer; pOptions: Pointer): HSteamListenSocket;
```

Create a listen socket on the specified virtual port. The physical UDP port to use will be determined by the SDR_LISTEN_PORT environment variable. If a UDP port is not configured, this call will fail. This call MUST be made through the SteamGameServerNetworkingSockets() interface. This function should be used when you are using the ticket generator library to issue your own tickets. Clients connecting to the server on this virtual port will need a ticket, and they must connect using ConnectToHostedDedicatedServer. If you need to set any initial config options, pass them here. See SteamNetworkingConfigValue_t for more about why this is preferable to setting the options "immediately" after creation.

#### GetGameCoordinatorServerLogin

```pascal
function GetGameCoordinatorServerLogin(pLoginInfo: Pointer; var pcbSignedBlob: Integer; pBlob: Pointer): EResult;
```

Generate an authentication blob that can be used to securely login with your backend, using SteamDatagram_ParseHostedServerLogin. (See steamdatagram_gamecoordinator.h) Before calling the function: - Populate the app data in pLoginInfo (m_cbAppData and m_appData). You can leave all other fields uninitialized. - *pcbSignedBlob contains the size of the buffer at pBlob. (It should be at least k_cbMaxSteamDatagramGameCoordinatorServerLoginSerialized.) On a successful exit: - k_EResultOK is returned - All of the remaining fields of pLoginInfo will be filled out. - *pcbSignedBlob contains the size of the serialized blob that has been placed into pBlob. Unsuccessful exit: - Something other than k_EResultOK is returned. - k_EResultNotLoggedOn: you are not logged in (yet) - See GetHostedDedicatedServerAddress for more potential failure return values. - A non-localized diagnostic debug message will be placed in pBlob that describes the cause of the failure. This works by signing the contents of the SteamDatagramGameCoordinatorServerLogin with the cert that is issued to this server. In dev environments, it's OK if you do not have a cert. (You will need to enable insecure dev login in SteamDatagram_ParseHostedServerLogin.) Otherwise, you will need a signed cert. NOTE: The routing blob returned here is not encrypted. Send it to your backend and don't share it directly with clients.

#### ConnectP2PCustomSignaling

```pascal
function ConnectP2PCustomSignaling(pSignaling: Pointer; pPeerIdentity: Pointer; nRemoteVirtualPort: Integer; nOptions: Integer; pOptions: Pointer): HSteamNetConnection;
```

Create a P2P "client" connection that does signaling over a custom rendezvous/signaling channel. pSignaling points to a new object that you create just for this connection. It must stay valid until Release() is called. Once you pass the object to this function, it assumes ownership. Release() will be called from within the function call if the call fails. Furthermore, until Release() is called, you should be prepared for methods to be invoked on your object from any thread! You need to make sure your object is threadsafe! Furthermore, you should make sure that dispatching the methods is done as quickly as possible. This function will immediately construct a connection in the "connecting" state. Soon after (perhaps before this function returns, perhaps in another thread), the connection will begin sending signaling messages by calling ISteamNetworkingConnectionSignaling::SendSignal. When the remote peer accepts the connection (See ISteamNetworkingSignalingRecvContext::OnConnectRequest), it will begin sending signaling messages. When these messages are received, you can pass them to the connection using ReceivedP2PCustomSignal. If you know the identity of the peer that you expect to be on the other end, you can pass their identity to improve debug output or just detect bugs. If you don't know their identity yet, you can pass NULL, and their identity will be established in the connection handshake. If you use this, you probably want to call ISteamNetworkingUtils::InitRelayNetworkAccess() when your app initializes If you need to set any initial config options, pass them here. See SteamNetworkingConfigValue_t for more about why this is preferable to setting the options "immediately" after creation.

#### ReceivedP2PCustomSignal

```pascal
function ReceivedP2PCustomSignal(pMsg: Pointer; cbMsg: Integer; pContext: Pointer): Boolean;
```

Called when custom signaling has received a message. When your signaling channel receives a message, it should save off whatever routing information was in the envelope into the context object, and then pass the payload to this function. A few different things can happen next, depending on the message: - If the signal is associated with existing connection, it is dealt with immediately. If any replies need to be sent, they will be dispatched using the ISteamNetworkingConnectionSignaling associated with the connection. - If the message represents a connection request (and the request is not redundant for an existing connection), a new connection will be created, and ReceivedConnectRequest will be called on your context object to determine how to proceed. - Otherwise, the message is for a connection that does not exist (anymore). In this case, we *may* call SendRejectionReply on your context object. In any case, we will not save off pContext or access it after this function returns. Returns true if the message was parsed and dispatched without anything unusual or suspicious happening. Returns false if there was some problem with the message that prevented ordinary handling. (Debug output will usually have more information.) If you expect to be using relayed connections, then you probably want to call ISteamNetworkingUtils::InitRelayNetworkAccess() when your app initializes.

#### GetCertificateRequest

```pascal
function GetCertificateRequest(var pcbBlob: Integer; pBlob: Pointer; var errMsg: SteamNetworkingErrMsg): Boolean;
```

Get blob that describes a certificate request. You can send this to your game coordinator. Upon entry, *pcbBlob should contain the size of the buffer. On successful exit, it will return the number of bytes that were populated. You can pass pBlob=NULL to query for the required size. (512 bytes is a conservative estimate.) Pass this blob to your game coordinator and call SteamDatagram_CreateCert.

#### SetCertificate

```pascal
function SetCertificate(pCertificate: Pointer; cbCertificate: Integer; var errMsg: SteamNetworkingErrMsg): Boolean;
```

Set the certificate. The certificate blob should be the output of SteamDatagram_CreateCert.

#### ResetIdentity

```pascal
procedure ResetIdentity(pIdentity: Pointer);
```

Reset the identity associated with this instance. Any open connections are closed. Any previous certificates, etc are discarded. You can pass a specific identity that you want to use, or you can pass NULL, in which case the identity will be invalid until you set it using SetCertificate NOTE: This function is not actually supported on Steam! It is included for use on other platforms where the active user can sign out and a new user can sign in.

#### RunCallbacks

```pascal
procedure RunCallbacks;
```

Invoke all callback functions queued for this interface. See k_ESteamNetworkingConfig_Callback_ConnectionStatusChanged, etc You don't need to call this if you are using Steam's callback dispatch mechanism (SteamAPI_RunCallbacks and SteamGameserver_RunCallbacks).

#### BeginAsyncRequestFakeIP

```pascal
function BeginAsyncRequestFakeIP(nNumPorts: Integer): Boolean;
```

Begin asynchronous process of allocating a fake IPv4 address that other peers can use to contact us via P2P. IP addresses returned by this function are globally unique for a given appid. nNumPorts is the numbers of ports you wish to reserve. This is useful for the same reason that listening on multiple UDP ports is useful for different types of traffic. Because these allocations come from a global namespace, there is a relatively strict limit on the maximum number of ports you may request. (At the time of this writing, the limit is 4.) The port assignments are *not* guaranteed to have any particular order or relationship! Do *not* assume they are contiguous, even though that may often occur in practice. Returns false if a request was already in progress, true if a new request was started. A SteamNetworkingFakeIPResult_t will be posted when the request completes. For gameservers, you *must* call this after initializing the SDK but before beginning login. Steam needs to know in advance that FakeIP will be used. Everywhere your public IP would normally appear (such as the server browser) will be replaced by the FakeIP, and the fake port at index 0. The request is actually queued until the logon completes, so you must not wait until the allocation completes before logging in. Except for trivial failures that can be detected locally (e.g. invalid parameter), a SteamNetworkingFakeIPResult_t callback (whether success or failure) will not be posted until after we have logged in. Furthermore, it is assumed that FakeIP allocation is essential for your application to function, and so failure will not be reported until *several* retries have been attempted. This process may last several minutes. It is *highly* recommended to treat failure as fatal. To communicate using a connection-oriented (TCP-style) API: - Server creates a listen socket using CreateListenSocketP2PFakeIP - Client connects using ConnectByIPAddress, passing in the FakeIP address. - The connection will behave mostly like a P2P connection. The identities that appear in SteamNetConnectionInfo_t will be the FakeIP identity until we know the real identity. Then it will be the real identity. If the SteamNetConnectionInfo_t::m_addrRemote is valid, it will be a real IPv4 address of a NAT-punched connection. Otherwise, it will not be valid. To communicate using an ad-hoc sendto/recv from (UDP-style) API, use CreateFakeUDPPort.

#### GetFakeIP

```pascal
procedure GetFakeIP(idxFirstPort: Integer; var pInfo: SteamNetworkingFakeIPResult_t);
```

Return info about the FakeIP and port(s) that we have been assigned, if any. idxFirstPort is currently reserved and must be zero. Make sure and check SteamNetworkingFakeIPResult_t::m_eResult.

#### CreateListenSocketP2PFakeIP

```pascal
function CreateListenSocketP2PFakeIP(idxFakePort: Integer; nOptions: Integer; pOptions: Pointer): HSteamListenSocket;
```

Create a listen socket that will listen for P2P connections sent to our FakeIP. A peer can initiate connections to this listen socket by calling ConnectByIPAddress. idxFakePort refers to the *index* of the fake port requested, not the actual port number. For example, pass 0 to refer to the first port in the reservation. You must call this only after calling BeginAsyncRequestFakeIP. However, you do not need to wait for the request to complete before creating the listen socket.

#### GetRemoteFakeIPForConnection

```pascal
function GetRemoteFakeIPForConnection(hConn: HSteamNetConnection; var pOutAddr: SteamNetworkingIPAddr): EResult;
```

If the connection was initiated using the "FakeIP" system, then we we can get an IP address for the remote host. If the remote host had a global FakeIP at the time the connection was established, this function will return that global IP. Otherwise, a FakeIP that is unique locally will be allocated from the local FakeIP address space, and that will be returned. The allocation of local FakeIPs attempts to assign addresses in a consistent manner. If multiple connections are made to the same remote host, they *probably* will return the same FakeIP. However, since the namespace is limited, this cannot be guaranteed. On failure, returns: - k_EResultInvalidParam: invalid connection handle - k_EResultIPNotFound: This connection wasn't made using FakeIP system.

#### CreateFakeUDPPort

```pascal
function CreateFakeUDPPort(idxFakeServerPort: Integer): Pointer;
```

Get an interface that can be used like a UDP port to send/receive datagrams to a FakeIP address. This is intended to make it easy to port existing UDP-based code to take advantage of SDR. idxFakeServerPort refers to the *index* of the port allocated using BeginAsyncRequestFakeIP and is used to create "server" ports. You may call this before the allocation has completed. However, any attempts to send packets will fail until the allocation has succeeded. When the peer receives packets sent from this interface, the from address of the packet will be the globally-unique FakeIP. If you call this function multiple times and pass the same (nonnegative) fake port index, the same object will be returned, and this object is not reference counted. To create a "client" port (e.g. the equivalent of an ephemeral UDP port) pass -1. In this case, a distinct object will be returned for each call. When the peer receives packets sent from this interface, the peer will assign a FakeIP from its own locally-controlled namespace.

#### ReleaseMessage

```pascal
procedure ReleaseMessage(AMessage: PSteamNetworkingMessage_t);
```

Gives a message from `ReceiveMessages` / `ReceiveMessagesOnGroup` (or the raw ReceiveMessages... methods) back to Steam. Call it once for every message, after reading m_pData; `nil` is ignored.

#### ReceiveMessages

```pascal
function ReceiveMessages(hConn: HSteamNetConnection; var AMessages: array of PSteamNetworkingMessage_t): Integer;
```

Up to Length(AMessages) waiting messages of a connection, into AMessages from index 0. Returns: (How many were stored, 0 when none, -1 for an invalid connection handle.) Release each with `ReleaseMessage`.

#### ReceiveMessagesOnGroup

```pascal
function ReceiveMessagesOnGroup(hPollGroup: HSteamNetPollGroup; var AMessages: array of PSteamNetworkingMessage_t): Integer;
```

`ReceiveMessages` for every connection of a poll group.

### Async methods

None.

### Properties

| Property | Description |
|----------|-------------|
| `Handle: Pointer` | The raw ISteamNetworkingSockets pointer (first argument of every `Flat` export). |
| `Flat: TSteamNetworkingSocketsFlat` | The bound flat exports, for calls the methods do not cover. |

## Payload records

Declared in `Steamworks.SDKTypes` (generated from the SDK headers; layouts verified
against the C headers for Win64, Win32, Linux64 and macOS ARM64).

### SteamNetConnectionStatusChangedCallback_t

Callback id 1221 (`SteamNetConnectionStatusChangedCallback_t_k_iCallback`).

| Field | C declaration |
|-------|---------------|
| `m_hConn: HSteamNetConnection` | C field `HSteamNetConnection m_hConn`. |
| `m_info: SteamNetConnectionInfo_t` | C field `SteamNetConnectionInfo_t m_info`. |
| `m_eOldState: ESteamNetworkingConnectionState` | C field `ESteamNetworkingConnectionState m_eOldState`. |

### SteamNetAuthenticationStatus_t

Callback id 1222 (`SteamNetAuthenticationStatus_t_k_iCallback`).

| Field | C declaration |
|-------|---------------|
| `m_eAvail: ESteamNetworkingAvailability` | C field `ESteamNetworkingAvailability m_eAvail`. |
| `m_debugMsg: array[0..255] of AnsiChar` | C field `char [256] m_debugMsg`. |

### SteamNetworkingFakeIPResult_t

Callback id 1223 (`SteamNetworkingFakeIPResult_t_k_iCallback`).

| Field | C declaration |
|-------|---------------|
| `m_eResult: EResult` | C field `EResult m_eResult`. |
| `m_identity: SteamNetworkingIdentity` | C field `SteamNetworkingIdentity m_identity`. |
| `m_unIP: UInt32` | C field `uint32 m_unIP`. |
| `m_unPorts: array[0..7] of UInt16` | C field `uint16 [8] m_unPorts`. |
