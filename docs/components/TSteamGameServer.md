# TSteamGameServer and TSteamGameServerPlugin (ISteamGameServer)

> **Generated** by `tools/gen_docs.py` from `lib/plugins/Steamworks.Plugin.GameServer.pas` - do not edit.
> Hand-written text: `tools/doc_extras/GameServer.md`. Steam's own descriptions are Valve's
> SDK comments, as in the generated units.

Unit: `Steamworks.Plugin.GameServer` - linking it (a `uses` entry, or dropping a `TSteamGameServer`) enables the
plug-in. Steam interface: `ISteamGameServer` (SDK 1.65).

## Overview

The game server (`ISteamGameServer`): a server that logs on to Steam,
appears in the server browser, authenticates its players and answers
server-browser queries (ping, players, rules). It can run in two ways:

* **Listen server** - the game is client AND server in one process (Valve
  allows it): TSteamAPI is active as usual (`Roles = [srClient]`) and the
  game calls `SteamAPI1.StartGameServer` when the player chooses to host,
  `StopGameServer` when hosting ends.
* **Dedicated server** - no Steam client needed: `Roles = [srGameServer]`
  and `Active := True` (or `StartGameServer` with Steam inactive). Ship
  `steam_appid.txt` with the server, or set `SetAppIdEnvironment`.

The server settings are TSteamAPI properties: `GameServerIP` (0 = any),
`GameServerGamePort` (27015), `GameServerQueryPort` (27016; 65535 =
STEAMGAMESERVER_QUERY_PORT_SHARED, the game forwards the queries with
`HandleIncomingPacket` / `GetNextOutgoingPacket`), `GameServerMode`
(`ssmAuthenticationAndSecure` = Valve's default) and `GameServerVersion`.

```pascal
procedure TForm1.btnHostClick(Sender: TObject);
begin
  if not SteamAPI1.StartGameServer then
    Exit;   // OnGameServerFailed / the log say why
  with SteamGameServer1.Plugin do
  begin
    SetModDir('mygame');
    SetProduct('MyGame');
    SetGameDescription('My Game');
    SetDedicatedServer(False);
    LogOnAnonymous;            // answer: OnSteamServersConnected
  end;
end;

procedure TForm1.SteamGameServer1SteamServersConnected(Sender: TObject;
  const AData: SteamServersConnected_t);
begin
  with SteamGameServer1.Plugin do
  begin
    SetServerName('My server');
    SetMapName('map1');
    SetMaxPlayerCount(8);
    SetKeyValue('mode', 'coop');       // a rule (server browser: OnRule)
    SetAdvertiseServerActive(True);    // list it
  end;
end;
```

### Server components

The game server's components attach when it starts and detach when it
stops; their events come from the SERVER's callback pipe, never the
client's (Steam sends ids such as 101-103 and 143 on both pipes):

| Component | Interface |
|-----------|-----------|
| `TSteamGameServer` | ISteamGameServer (this page) |
| `TSteamGameServerStats` | ISteamGameServerStats |
| `TSteamGameServerUtils` | the server's ISteamUtils |
| `TSteamGameServerNetworking` | the server's ISteamNetworking (old P2P) |
| `TSteamGameServerNetworkingSockets` | the server's ISteamNetworkingSockets |
| `TSteamGameServerNetworkingMessages` | the server's ISteamNetworkingMessages |
| `TSteamGameServerHTTP` | the server's ISteamHTTP |
| `TSteamGameServerUGC` | the server's ISteamUGC |
| `TSteamGameServerInventory` | the server's ISteamInventory |

The copies have the same methods and events as the client components
(`TSteamGameServerUtils` is a `TSteamUtils`); in code the plug-ins are
`TSteamGameServerUtilsPlugin` and so on (`Steam.FindPlugin` with the
client class never returns the server's copy).

### Authenticating players

The player asks for a ticket for the server's SteamID (client
`TSteamUser.Plugin.GetAuthSessionTicket` with the server's identity) and
sends it with the game's own messages; the server calls
`BeginAuthSession(ticket, size, playerSteamID)` and gets
`OnValidateAuthTicketResponse` (callback 143 on the server's pipe), then
`EndAuthSession` when the player leaves.

`GetPublicIP` (a by-value return, hand-written for every platform) gives
the address Steam sees after log-on; `PublicIPv4` the IPv4 form in host
order, as the server browser's queries take it.

## Contents

* [The component: TSteamGameServer](#the-component-tsteamgameserver)
  * [Events (14)](#events)
* [The plug-in: TSteamGameServerPlugin](#the-plug-in-tsteamgameserverplugin)
  * [Methods](#methods)
  * [Async methods](#async-methods)
  * [Properties](#properties)
* [Payload records](#payload-records)

## The component: TSteamGameServer

ISteamGameServer component: drop it next to a TSteamAPI (linked automatically at run time when the owner has exactly one, otherwise set SteamAPI). Its events are the ISteamGameServer callbacks; call the interface through `Plugin`.

| Member | Kind | Description |
|--------|------|-------------|
| `SteamAPI` | published property | The `TSteamAPI` this component belongs to. At run time a component whose owner has exactly one `TSteamAPI` links itself. |
| `Plugin` | public property | The `TSteamGameServerPlugin` for calls; `nil` while Steam is not running. |
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
| `OnSteamServersConnected` | 101 | [`SteamServersConnected_t`](#steamserversconnected_t) | Called when an authenticated connection to the Steam back-end has been established. This means the Steam client now has a working connection to the Steam servers. Usually this will have occurred before the game has launched, and should only be seen if the user has dropped connection due to a networking issue or a Steam server update. |
| `OnSteamServerConnectFailure` | 102 | [`SteamServerConnectFailure_t`](#steamserverconnectfailure_t) | called when a connection attempt has failed this will occur periodically if the Steam client is not connected, and has failed in it's retry to establish a connection. |
| `OnSteamServersDisconnected` | 103 | [`SteamServersDisconnected_t`](#steamserversdisconnected_t) | called if the client has lost connection to the Steam servers real-time services will be disabled until a matching SteamServersConnected_t has been posted. |
| `OnGSPolicyResponse` | 115 | [`GSPolicyResponse_t`](#gspolicyresponse_t) | received when the game server requests to be displayed as secure (VAC protected) m_bSecure is true if the game server should display itself as secure to users, false otherwise. |
| `OnValidateAuthTicketResponse` | 143 | [`ValidateAuthTicketResponse_t`](#validateauthticketresponse_t) | callback for BeginAuthSession. |
| `OnGSClientApprove` | 201 | [`GSClientApprove_t`](#gsclientapprove_t) | client has been approved to connect to this game server. |
| `OnGSClientDeny` | 202 | [`GSClientDeny_t`](#gsclientdeny_t) | client has been denied to connection to this game server. |
| `OnGSClientKick` | 203 | [`GSClientKick_t`](#gsclientkick_t) | request the game server should kick the user. |
| `OnGSClientAchievementStatus` | 206 | [`GSClientAchievementStatus_t`](#gsclientachievementstatus_t) | client achievement info. |
| `OnGSGameplayStats` | 207 | [`GSGameplayStats_t`](#gsgameplaystats_t) | GS gameplay stats info. |
| `OnGSClientGroupStatus` | 208 | [`GSClientGroupStatus_t`](#gsclientgroupstatus_t) | send as a reply to RequestUserGroupStatus(). |
| `OnGSReputation` | 209 | [`GSReputation_t`](#gsreputation_t) | Sent as a reply to GetServerReputation(). |
| `OnAssociateWithClanResult` | 210 | [`AssociateWithClanResult_t`](#associatewithclanresult_t) | Sent as a reply to AssociateWithClan(). |
| `OnComputeNewPlayerCompatibilityResult` | 211 | [`ComputeNewPlayerCompatibilityResult_t`](#computenewplayercompatibilityresult_t) | Sent as a reply to ComputeNewPlayerCompatibility(). |

Handler signature (the IDE generates it when you double-click the event):

```pascal
procedure TForm1.SteamGameServer1SteamServersConnected(Sender: TObject; const AData: SteamServersConnected_t);
```

## The plug-in: TSteamGameServerPlugin

ISteamGameServer plug-in. Registered by linking the unit; find it with @code(Steam.FindPlugin(TSteamGameServerPlugin)).

Reach it through the component (`SteamGameServer1.Plugin`) or the core:

```pascal
P := TSteamGameServerPlugin(Steam.FindPlugin(TSteamGameServerPlugin));   // Delphi also: Steam.Plugin<TSteamGameServerPlugin>
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
| [`SetProduct`](#setproduct) | Game product identifier. This is currently used by the master server for version checking purposes. It's a required field, but will eventually will go away, ... |
| [`SetGameDescription`](#setgamedescription) | Description of the game. This is a required field and is displayed in the steam server browser....for now. This is a required field, but it will go away ... |
| [`SetModDir`](#setmoddir) | If your game is a "mod," pass the string that identifies it. The default is an empty string, meaning this application is the original game, not a mod. @see ... |
| [`SetDedicatedServer`](#setdedicatedserver) | Is this is a dedicated server? The default value is false. |
| [`LogOn`](#logon) | Begin process to login to a persistent game server account You need to register for callbacks to determine the result of this operation. @see ... |
| [`LogOnAnonymous`](#logonanonymous) | Login to a generic, anonymous account. Note: in previous versions of the SDK, this was automatically called within SteamGameServer_Init, but this is no ... |
| [`LogOff`](#logoff) | Begin process of logging game server out of steam. |
| [`BLoggedOn`](#bloggedon) | status functions. |
| [`BSecure`](#bsecure) | Wraps `SteamAPI_ISteamGameServer_BSecure`. |
| [`GetSteamID`](#getsteamid) | Wraps `SteamAPI_ISteamGameServer_GetSteamID`. |
| [`WasRestartRequested`](#wasrestartrequested) | Returns true if the master server has requested a restart. Only returns true once per request. |
| [`SetMaxPlayerCount`](#setmaxplayercount) | Max player count that will be reported to server browser and client queries. |
| [`SetBotPlayerCount`](#setbotplayercount) | Number of bots. Default value is zero. |
| [`SetServerName`](#setservername) | Set the name of server as it will appear in the server browser @see k_cbMaxGameServerName. |
| [`SetMapName`](#setmapname) | Set name of map to report in the server browser @see k_cbMaxGameServerMapName. |
| [`SetPasswordProtected`](#setpasswordprotected) | Let people know if your server will require a password. |
| [`SetSpectatorPort`](#setspectatorport) | Spectator server port to advertise. The default value is zero, meaning the service is not used. If your server receives any info requests on the LAN, this ... |
| [`SetSpectatorServerName`](#setspectatorservername) | Name of the spectator server. (Only used if spectator port is nonzero.) @see k_cbMaxGameServerMapName. |
| [`ClearAllKeyValues`](#clearallkeyvalues) | Call this to clear the whole list of key/values that are sent in rules queries. |
| [`SetKeyValue`](#setkeyvalue) | Call this to add/update a key/value pair. |
| [`SetGameTags`](#setgametags) | Sets a string defining the "gametags" for this server, this is optional, but if it is set it allows users to filter in the matchmaking/server-browser ... |
| [`SetGameData`](#setgamedata) | Sets a string defining the "gamedata" for this server, this is optional, but if it is set it allows users to filter in the matchmaking/server-browser ... |
| [`SetRegion`](#setregion) | Region identifier. This is an optional field, the default value is empty, meaning the "world" region. |
| [`SetAdvertiseServerActive`](#setadvertiseserveractive) | Indicate whether you wish to be listed on the master server list and/or respond to server browser / LAN discovery packets. The server starts with this value ... |
| [`GetAuthSessionTicket`](#getauthsessionticket) | Retrieve ticket to be sent to the entity who wishes to authenticate you ( using BeginAuthSession API ). pcbTicket retrieves the length of the actual ticket. ... |
| [`BeginAuthSession`](#beginauthsession) | Authenticate ticket ( from GetAuthSessionTicket ) from entity steamID to be sure it is valid and isnt reused Registers for callbacks if the entity goes ... |
| [`EndAuthSession`](#endauthsession) | Stop tracking started by BeginAuthSession - called when no longer playing game with this entity. |
| [`CancelAuthTicket`](#cancelauthticket) | Cancel auth ticket from GetAuthSessionTicket, called when no longer playing game with the entity you gave the ticket to. |
| [`UserHasLicenseForApp`](#userhaslicenseforapp) | After receiving a user's authentication data, and passing it to SendUserConnectAndAuthenticate, use this function to determine if the user owns downloadable ... |
| [`RequestUserGroupStatus`](#requestusergroupstatus) | Ask if a user in in the specified group, results returns async by GSUserGroupStatus_t returns false if we're not connected to the steam servers and thus ... |
| [`GetGameplayStats`](#getgameplaystats) | these two functions s are deprecated, and will not return results they will be removed in a future version of the SDK. |
| [`GetServerReputation`](#getserverreputation) | Wraps `SteamAPI_ISteamGameServer_GetServerReputation`. Call result: `GSReputation_t` (`GSReputation_t_k_iCallback`). |
| [`HandleIncomingPacket`](#handleincomingpacket) | Call this when a packet that starts with 0xFFFFFFFF comes in. That means it's for us. |
| [`GetNextOutgoingPacket`](#getnextoutgoingpacket) | AFTER calling HandleIncomingPacket for any packets that came in that frame, call this. This gets a packet that the master server updater needs to send out ... |
| [`AssociateWithClan`](#associatewithclan) | associate this game server with this clan for the purposes of computing player compat. Call result: `AssociateWithClanResult_t` ... |
| [`ComputeNewPlayerCompatibility`](#computenewplayercompatibility) | ask if any of the current players dont want to play with this new player - or vice versa. Call result: `ComputeNewPlayerCompatibilityResult_t` ... |
| [`SendUserConnectAndAuthenticate_DEPRECATED`](#senduserconnectandauthenticate_deprecated) | Handles receiving a new connection from a Steam user. This call will ask the Steam servers to validate the users identity, app ownership, and VAC status. If ... |
| [`CreateUnauthenticatedUserConnection`](#createunauthenticateduserconnection) | Creates a fake user (ie, a bot) which will be listed as playing on the server, but skips validation. Return Value: Returns a SteamID for the user to be ... |
| [`SendUserDisconnect_DEPRECATED`](#senduserdisconnect_deprecated) | Should be called whenever a user leaves our game server, this lets Steam internally track which users are currently on which servers for the purposes of ... |
| [`BUpdateUserData`](#bupdateuserdata) | Update the data to be displayed in the server browser and matchmaking interfaces for a user currently connected to the server. For regular users you must ... |
| [`GetPublicIP`](#getpublicip) | The server's public IP address as Steam sees it (after log-on; type k_ESteamIPTypeIPv4 with m_unIPv4 in HOST order, or IPv6). Behind NAT this is the ... |
| [`PublicIPv4`](#publicipv4) | `GetPublicIP` as an IPv4 address in HOST order (what the server browser's StartPing / StartPlayerDetails / StartServerRules take), or 0 when Steam reports ... |

#### IsGameServer

```pascal
class function IsGameServer: Boolean; override;
```

`True`: a game-server plug-in (created by TSteamworks.StartGameServer).

#### SetProduct

```pascal
procedure SetProduct(const pszProduct: string);
```

Game product identifier. This is currently used by the master server for version checking purposes. It's a required field, but will eventually will go away, and the AppID will be used for this purpose.

#### SetGameDescription

```pascal
procedure SetGameDescription(const pszGameDescription: string);
```

Description of the game. This is a required field and is displayed in the steam server browser....for now. This is a required field, but it will go away eventually, as the data should be determined from the AppID.

#### SetModDir

```pascal
procedure SetModDir(const pszModDir: string);
```

If your game is a "mod," pass the string that identifies it. The default is an empty string, meaning this application is the original game, not a mod. @see k_cbMaxGameServerGameDir.

#### SetDedicatedServer

```pascal
procedure SetDedicatedServer(bDedicated: Boolean);
```

Is this is a dedicated server? The default value is false.

#### LogOn

```pascal
procedure LogOn(const pszToken: string);
```

Begin process to login to a persistent game server account You need to register for callbacks to determine the result of this operation. @see SteamServersConnected_t @see SteamServerConnectFailure_t @see SteamServersDisconnected_t.

#### LogOnAnonymous

```pascal
procedure LogOnAnonymous;
```

Login to a generic, anonymous account. Note: in previous versions of the SDK, this was automatically called within SteamGameServer_Init, but this is no longer the case.

#### LogOff

```pascal
procedure LogOff;
```

Begin process of logging game server out of steam.

#### BLoggedOn

```pascal
function BLoggedOn: Boolean;
```

status functions.

#### BSecure

```pascal
function BSecure: Boolean;
```

Wraps `SteamAPI_ISteamGameServer_BSecure`.

#### GetSteamID

```pascal
function GetSteamID: TSteamID;
```

Wraps `SteamAPI_ISteamGameServer_GetSteamID`.

#### WasRestartRequested

```pascal
function WasRestartRequested: Boolean;
```

Returns true if the master server has requested a restart. Only returns true once per request.

#### SetMaxPlayerCount

```pascal
procedure SetMaxPlayerCount(cPlayersMax: Integer);
```

Max player count that will be reported to server browser and client queries.

#### SetBotPlayerCount

```pascal
procedure SetBotPlayerCount(cBotplayers: Integer);
```

Number of bots. Default value is zero.

#### SetServerName

```pascal
procedure SetServerName(const pszServerName: string);
```

Set the name of server as it will appear in the server browser @see k_cbMaxGameServerName.

#### SetMapName

```pascal
procedure SetMapName(const pszMapName: string);
```

Set name of map to report in the server browser @see k_cbMaxGameServerMapName.

#### SetPasswordProtected

```pascal
procedure SetPasswordProtected(bPasswordProtected: Boolean);
```

Let people know if your server will require a password.

#### SetSpectatorPort

```pascal
procedure SetSpectatorPort(unSpectatorPort: UInt16);
```

Spectator server port to advertise. The default value is zero, meaning the service is not used. If your server receives any info requests on the LAN, this is the value that will be placed into the reply for such local queries. This is also the value that will be advertised by the master server. The only exception is if your server is using a FakeIP. Then then the second fake port number (index 1) assigned to your server will be listed on the master server as the spectator port, if you set this value to any nonzero value. This function merely controls the values that are advertised -- it's up to you to configure the server to actually listen on this port and handle any spectator traffic.

#### SetSpectatorServerName

```pascal
procedure SetSpectatorServerName(const pszSpectatorServerName: string);
```

Name of the spectator server. (Only used if spectator port is nonzero.) @see k_cbMaxGameServerMapName.

#### ClearAllKeyValues

```pascal
procedure ClearAllKeyValues;
```

Call this to clear the whole list of key/values that are sent in rules queries.

#### SetKeyValue

```pascal
procedure SetKeyValue(const pKey: string; const pValue: string);
```

Call this to add/update a key/value pair.

#### SetGameTags

```pascal
procedure SetGameTags(const pchGameTags: string);
```

Sets a string defining the "gametags" for this server, this is optional, but if it is set it allows users to filter in the matchmaking/server-browser interfaces based on the value @see k_cbMaxGameServerTags.

#### SetGameData

```pascal
procedure SetGameData(const pchGameData: string);
```

Sets a string defining the "gamedata" for this server, this is optional, but if it is set it allows users to filter in the matchmaking/server-browser interfaces based on the value @see k_cbMaxGameServerGameData.

#### SetRegion

```pascal
procedure SetRegion(const pszRegion: string);
```

Region identifier. This is an optional field, the default value is empty, meaning the "world" region.

#### SetAdvertiseServerActive

```pascal
procedure SetAdvertiseServerActive(bActive: Boolean);
```

Indicate whether you wish to be listed on the master server list and/or respond to server browser / LAN discovery packets. The server starts with this value set to false. You should set all relevant server parameters before enabling advertisement on the server. (This function used to be named EnableHeartbeats, so if you are wondering where that function went, it's right here. It does the same thing as before, the old name was just confusing.).

#### GetAuthSessionTicket

```pascal
function GetAuthSessionTicket(pTicket: Pointer; cbMaxTicket: Integer; var pcbTicket: UInt32; pSnid: Pointer): HAuthTicket;
```

Retrieve ticket to be sent to the entity who wishes to authenticate you ( using BeginAuthSession API ). pcbTicket retrieves the length of the actual ticket. SteamNetworkingIdentity is an optional parameter to hold the public IP address of the entity you are connecting to if an IP address is passed Steam will only allow the ticket to be used by an entity with that IP address.

#### BeginAuthSession

```pascal
function BeginAuthSession(pAuthTicket: Pointer; cbAuthTicket: Integer; const steamID: TSteamID): EBeginAuthSessionResult;
```

Authenticate ticket ( from GetAuthSessionTicket ) from entity steamID to be sure it is valid and isnt reused Registers for callbacks if the entity goes offline or cancels the ticket ( see ValidateAuthTicketResponse_t callback and EAuthSessionResponse ).

#### EndAuthSession

```pascal
procedure EndAuthSession(const steamID: TSteamID);
```

Stop tracking started by BeginAuthSession - called when no longer playing game with this entity.

#### CancelAuthTicket

```pascal
procedure CancelAuthTicket(AHAuthTicket: HAuthTicket);
```

Cancel auth ticket from GetAuthSessionTicket, called when no longer playing game with the entity you gave the ticket to.

#### UserHasLicenseForApp

```pascal
function UserHasLicenseForApp(const steamID: TSteamID; appID: AppId_t): EUserHasLicenseForAppResult;
```

After receiving a user's authentication data, and passing it to SendUserConnectAndAuthenticate, use this function to determine if the user owns downloadable content specified by the provided AppID.

#### RequestUserGroupStatus

```pascal
function RequestUserGroupStatus(const steamIDUser: TSteamID; const steamIDGroup: TSteamID): Boolean;
```

Ask if a user in in the specified group, results returns async by GSUserGroupStatus_t returns false if we're not connected to the steam servers and thus cannot ask.

#### GetGameplayStats

```pascal
procedure GetGameplayStats;
```

these two functions s are deprecated, and will not return results they will be removed in a future version of the SDK.

#### GetServerReputation

```pascal
function GetServerReputation: SteamAPICall_t;
```

Wraps `SteamAPI_ISteamGameServer_GetServerReputation`. Call result: `GSReputation_t` (`GSReputation_t_k_iCallback`).

#### HandleIncomingPacket

```pascal
function HandleIncomingPacket(pData: Pointer; cbData: Integer; srcIP: UInt32; srcPort: UInt16): Boolean;
```

Call this when a packet that starts with 0xFFFFFFFF comes in. That means it's for us.

#### GetNextOutgoingPacket

```pascal
function GetNextOutgoingPacket(pOut: Pointer; cbMaxOut: Integer; var pNetAdr: UInt32; var pPort: UInt16): Integer;
```

AFTER calling HandleIncomingPacket for any packets that came in that frame, call this. This gets a packet that the master server updater needs to send out on UDP. It returns the length of the packet it wants to send, or 0 if there are no more packets to send. Call this each frame until it returns 0.

#### AssociateWithClan

```pascal
function AssociateWithClan(const steamIDClan: TSteamID): SteamAPICall_t;
```

associate this game server with this clan for the purposes of computing player compat. Call result: `AssociateWithClanResult_t` (`AssociateWithClanResult_t_k_iCallback`).

#### ComputeNewPlayerCompatibility

```pascal
function ComputeNewPlayerCompatibility(const steamIDNewPlayer: TSteamID): SteamAPICall_t;
```

ask if any of the current players dont want to play with this new player - or vice versa. Call result: `ComputeNewPlayerCompatibilityResult_t` (`ComputeNewPlayerCompatibilityResult_t_k_iCallback`).

#### SendUserConnectAndAuthenticate_DEPRECATED

```pascal
function SendUserConnectAndAuthenticate_DEPRECATED(unIPClient: UInt32; pvAuthBlob: Pointer; cubAuthBlobSize: UInt32; var pSteamIDUser: TSteamID): Boolean;
```

Handles receiving a new connection from a Steam user. This call will ask the Steam servers to validate the users identity, app ownership, and VAC status. If the Steam servers are off-line, then it will validate the cached ticket itself which will validate app ownership and identity. The AuthBlob here should be acquired on the game client using SteamUser()->InitiateGameConnection() and must then be sent up to the game server for authentication. Return Value: returns true if the users ticket passes basic checks. pSteamIDUser will contain the Steam ID of this user. pSteamIDUser must NOT be NULL If the call succeeds then you should expect a GSClientApprove_t or GSClientDeny_t callback which will tell you whether authentication for the user has succeeded or failed (the steamid in the callback will match the one returned by this call) DEPRECATED! This function will be removed from the SDK in an upcoming version. Please migrate to BeginAuthSession and related functions.

#### CreateUnauthenticatedUserConnection

```pascal
function CreateUnauthenticatedUserConnection: TSteamID;
```

Creates a fake user (ie, a bot) which will be listed as playing on the server, but skips validation. Return Value: Returns a SteamID for the user to be tracked with, you should call EndAuthSession() when this user leaves the server just like you would for a real user.

#### SendUserDisconnect_DEPRECATED

```pascal
procedure SendUserDisconnect_DEPRECATED(const steamIDUser: TSteamID);
```

Should be called whenever a user leaves our game server, this lets Steam internally track which users are currently on which servers for the purposes of preventing a single account being logged into multiple servers, showing who is currently on a server, etc. DEPRECATED! This function will be removed from the SDK in an upcoming version. Please migrate to BeginAuthSession and related functions.

#### BUpdateUserData

```pascal
function BUpdateUserData(const steamIDUser: TSteamID; const pchPlayerName: string; uScore: UInt32): Boolean;
```

Update the data to be displayed in the server browser and matchmaking interfaces for a user currently connected to the server. For regular users you must call this after you receive a GSUserValidationSuccess callback. Return Value: true if successful, false if failure (ie, steamIDUser wasn't for an active player).

#### GetPublicIP

```pascal
function GetPublicIP: SteamIPAddress_t;
```

The server's public IP address as Steam sees it (after log-on; type k_ESteamIPTypeIPv4 with m_unIPv4 in HOST order, or IPv6). Behind NAT this is the router's address.

#### PublicIPv4

```pascal
function PublicIPv4: UInt32;
```

`GetPublicIP` as an IPv4 address in HOST order (what the server browser's StartPing / StartPlayerDetails / StartServerRules take), or 0 when Steam reports none or an IPv6 address.

### Async methods

Each `...Async` method starts the call and registers `AHandler` for its result
(`procedure(const AData: TSteamCallbackData; AIOFailure: Boolean) of object`). The
handler runs once, on the delivery thread, with the result record in `AData`
(`AData.CopyTo(Rec, SizeOf(Rec))`); its object owns the registration - call
`Steam.Dispatcher.RemoveOwner(Self)` in that object's destructor. The plain method of
the same name returns the `SteamAPICall_t` instead, and its result reaches the
component's event.

#### GetServerReputationAsync

```pascal
function GetServerReputationAsync(AHandler: TSteamCallResultEvent): SteamAPICall_t;
```

Calls `GetServerReputation` and registers AHandler for its result (`GSReputation_t`). The handler's object owns the registration (remove it with Plugin.Dispatcher.RemoveOwner). Returns: (The call handle, or k_uAPICallInvalid when Steam refused the call.)

#### AssociateWithClanAsync

```pascal
function AssociateWithClanAsync(const steamIDClan: TSteamID; AHandler: TSteamCallResultEvent): SteamAPICall_t;
```

Calls `AssociateWithClan` and registers AHandler for its result (`AssociateWithClanResult_t`). The handler's object owns the registration (remove it with Plugin.Dispatcher.RemoveOwner). Returns: (The call handle, or k_uAPICallInvalid when Steam refused the call.)

#### ComputeNewPlayerCompatibilityAsync

```pascal
function ComputeNewPlayerCompatibilityAsync(const steamIDNewPlayer: TSteamID; AHandler: TSteamCallResultEvent): SteamAPICall_t;
```

Calls `ComputeNewPlayerCompatibility` and registers AHandler for its result (`ComputeNewPlayerCompatibilityResult_t`). The handler's object owns the registration (remove it with Plugin.Dispatcher.RemoveOwner). Returns: (The call handle, or k_uAPICallInvalid when Steam refused the call.)

### Properties

| Property | Description |
|----------|-------------|
| `Handle: Pointer` | The raw ISteamGameServer pointer (first argument of every `Flat` export). |
| `Flat: TSteamGameServerFlat` | The bound flat exports, for calls the methods do not cover. |

## Payload records

Declared in `Steamworks.SDKTypes` (generated from the SDK headers; layouts verified
against the C headers for Win64, Win32, Linux64 and macOS ARM64).

### SteamServersConnected_t

Callback id 101 (`SteamServersConnected_t_k_iCallback`).

| Field | C declaration |
|-------|---------------|
| `_dummy: Byte` | Placeholder: the C++ struct is empty (sizeof = 1). |

### SteamServerConnectFailure_t

Callback id 102 (`SteamServerConnectFailure_t_k_iCallback`).

| Field | C declaration |
|-------|---------------|
| `m_eResult: EResult` | C field `EResult m_eResult`. |
| `m_bStillRetrying: Boolean` | C field `bool m_bStillRetrying`. |

### SteamServersDisconnected_t

Callback id 103 (`SteamServersDisconnected_t_k_iCallback`).

| Field | C declaration |
|-------|---------------|
| `m_eResult: EResult` | C field `EResult m_eResult`. |

### GSPolicyResponse_t

Callback id 115 (`GSPolicyResponse_t_k_iCallback`).

| Field | C declaration |
|-------|---------------|
| `m_bSecure: UInt8` | C field `uint8 m_bSecure`. |

### ValidateAuthTicketResponse_t

Callback id 143 (`ValidateAuthTicketResponse_t_k_iCallback`).

| Field | C declaration |
|-------|---------------|
| `m_SteamID: TSteamID` | C field `CSteamID m_SteamID`. |
| `m_eAuthSessionResponse: EAuthSessionResponse` | C field `EAuthSessionResponse m_eAuthSessionResponse`. |
| `m_OwnerSteamID: TSteamID` | C field `CSteamID m_OwnerSteamID`. |

### GSClientApprove_t

Callback id 201 (`GSClientApprove_t_k_iCallback`).

| Field | C declaration |
|-------|---------------|
| `m_SteamID: TSteamID` | C field `CSteamID m_SteamID`. |
| `m_OwnerSteamID: TSteamID` | C field `CSteamID m_OwnerSteamID`. |

### GSClientDeny_t

Callback id 202 (`GSClientDeny_t_k_iCallback`).

| Field | C declaration |
|-------|---------------|
| `m_SteamID: TSteamID` | C field `CSteamID m_SteamID`. |
| `m_eDenyReason: EDenyReason` | C field `EDenyReason m_eDenyReason`. |
| `m_rgchOptionalText: array[0..127] of AnsiChar` | C field `char [128] m_rgchOptionalText`. |

### GSClientKick_t

Callback id 203 (`GSClientKick_t_k_iCallback`).

| Field | C declaration |
|-------|---------------|
| `m_SteamID: TSteamID` | C field `CSteamID m_SteamID`. |
| `m_eDenyReason: EDenyReason` | C field `EDenyReason m_eDenyReason`. |

### GSClientAchievementStatus_t

Callback id 206 (`GSClientAchievementStatus_t_k_iCallback`).

| Field | C declaration |
|-------|---------------|
| `m_SteamID: UInt64` | C field `uint64 m_SteamID`. |
| `m_pchAchievement: array[0..127] of AnsiChar` | C field `char [128] m_pchAchievement`. |
| `m_bUnlocked: Boolean` | C field `bool m_bUnlocked`. |

### GSGameplayStats_t

Callback id 207 (`GSGameplayStats_t_k_iCallback`).

| Field | C declaration |
|-------|---------------|
| `m_eResult: EResult` | C field `EResult m_eResult`. |
| `m_nRank: Int32` | C field `int32 m_nRank`. |
| `m_unTotalConnects: UInt32` | C field `uint32 m_unTotalConnects`. |
| `m_unTotalMinutesPlayed: UInt32` | C field `uint32 m_unTotalMinutesPlayed`. |

### GSClientGroupStatus_t

Callback id 208 (`GSClientGroupStatus_t_k_iCallback`).

| Field | C declaration |
|-------|---------------|
| `m_SteamIDUser: TSteamID` | C field `CSteamID m_SteamIDUser`. |
| `m_SteamIDGroup: TSteamID` | C field `CSteamID m_SteamIDGroup`. |
| `m_bMember: Boolean` | C field `bool m_bMember`. |
| `m_bOfficer: Boolean` | C field `bool m_bOfficer`. |

### GSReputation_t

Callback id 209 (`GSReputation_t_k_iCallback`).

| Field | C declaration |
|-------|---------------|
| `m_eResult: EResult` | C field `EResult m_eResult`. |
| `m_unReputationScore: UInt32` | C field `uint32 m_unReputationScore`. |
| `m_bBanned: Boolean` | C field `bool m_bBanned`. |
| `m_unBannedIP: UInt32` | C field `uint32 m_unBannedIP`. |
| `m_usBannedPort: UInt16` | C field `uint16 m_usBannedPort`. |
| `m_ulBannedGameID: UInt64` | C field `uint64 m_ulBannedGameID`. |
| `m_unBanExpires: UInt32` | C field `uint32 m_unBanExpires`. |

### AssociateWithClanResult_t

Callback id 210 (`AssociateWithClanResult_t_k_iCallback`).

| Field | C declaration |
|-------|---------------|
| `m_eResult: EResult` | C field `EResult m_eResult`. |

### ComputeNewPlayerCompatibilityResult_t

Callback id 211 (`ComputeNewPlayerCompatibilityResult_t_k_iCallback`).

| Field | C declaration |
|-------|---------------|
| `m_eResult: EResult` | C field `EResult m_eResult`. |
| `m_cPlayersThatDontLikeCandidate: Integer` | C field `int m_cPlayersThatDontLikeCandidate`. |
| `m_cPlayersThatCandidateDoesntLike: Integer` | C field `int m_cPlayersThatCandidateDoesntLike`. |
| `m_cClanPlayersThatDontLikeCandidate: Integer` | C field `int m_cClanPlayersThatDontLikeCandidate`. |
| `m_SteamIDCandidate: TSteamID` | C field `CSteamID m_SteamIDCandidate`. |
