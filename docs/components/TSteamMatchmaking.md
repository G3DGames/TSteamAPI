# TSteamMatchmaking and TSteamMatchmakingPlugin (ISteamMatchmaking)

> **Generated** by `tools/gen_docs.py` from `lib/plugins/Steamworks.Plugin.Matchmaking.pas` - do not edit.
> Hand-written text: `tools/doc_extras/Matchmaking.md`. Steam's own descriptions are Valve's
> SDK comments, as in the generated units.

Unit: `Steamworks.Plugin.Matchmaking` - linking it (a `uses` entry, or dropping a `TSteamMatchmaking`) enables the
plug-in. Steam interface: `ISteamMatchmaking` (SDK 1.65).

## Overview

Lobbies: small rooms where players gather before a game (find, create,
join, chat, share key / value data) and the user's favourite game servers.
Every lobby is identified by a `TSteamID`. Most calls answer through events.

### Find or create a lobby

```pascal
procedure TForm1.FindGame;
begin
  // filters apply to the NEXT RequestLobbyList only
  SteamMatchmaking1.Plugin.AddRequestLobbyListStringFilter('mode', 'coop',
    k_ELobbyComparisonEqual);
  SteamMatchmaking1.Plugin.AddRequestLobbyListResultCountFilter(20);
  SteamMatchmaking1.Plugin.RequestLobbyList;       // -> OnLobbyMatchList
end;

procedure TForm1.SteamMatchmaking1LobbyMatchList(Sender: TObject;
  const AData: LobbyMatchList_t);
var
  Lobby: TSteamID;
begin
  if AData.m_nLobbiesMatching = 0 then
    SteamMatchmaking1.Plugin.CreateLobby(k_ELobbyTypePublic, 4)   // -> OnLobbyCreated
  else
  begin
    Lobby := SteamMatchmaking1.Plugin.GetLobbyByIndex(0);
    SteamMatchmaking1.Plugin.JoinLobby(Lobby);                    // -> OnLobbyEnter
  end;
end;

procedure TForm1.SteamMatchmaking1LobbyCreated(Sender: TObject;
  const AData: LobbyCreated_t);
begin
  if AData.m_eResult = k_EResultOK then
    SteamMatchmaking1.Plugin.SetLobbyData(TSteamID.Create(AData.m_ulSteamIDLobby),
      'mode', 'coop');
end;
```

* **`OnLobbyMatchList` fires twice per `RequestLobbyList`**: Steam posts
  `LobbyMatchList_t` both as the call's result and as an ordinary callback
  (seen 2026-11-02, Win64). React to one of them - for example with
  `RequestLobbyListAsync(Handler)`, whose handler gets only the call
  result, or by ignoring a second list that arrives right after the first.
* Lobby ids arrive as `UInt64` in the events (`m_ulSteamIDLobby`); wrap them
  with `TSteamID.Create`.
* `SendLobbyChatMsg` and `GetLobbyChatEntry` take raw buffers (pointer +
  size); `OnLobbyChatMsg` says a message is waiting.
* Leave a lobby with `LeaveLobby` - Steam keeps the user in it otherwise
  until the program ends.
* The server browser (`ISteamMatchmakingServers`) is a separate interface
  that is not bound yet.

## Contents

* [The component: TSteamMatchmaking](#the-component-tsteammatchmaking)
  * [Events (11)](#events)
* [The plug-in: TSteamMatchmakingPlugin](#the-plug-in-tsteammatchmakingplugin)
  * [Methods](#methods)
  * [Async methods](#async-methods)
  * [Properties](#properties)
* [Payload records](#payload-records)

## The component: TSteamMatchmaking

ISteamMatchmaking component: drop it next to a TSteamAPI (linked automatically at run time when the owner has exactly one, otherwise set SteamAPI). Its events are the ISteamMatchmaking callbacks; call the interface through `Plugin`.

| Member | Kind | Description |
|--------|------|-------------|
| `SteamAPI` | published property | The `TSteamAPI` this component belongs to. At run time a component whose owner has exactly one `TSteamAPI` links itself. |
| `Plugin` | public property | The `TSteamMatchmakingPlugin` for calls; `nil` while Steam is not running. |
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
| `OnFavoritesListChanged` | 502 | [`FavoritesListChanged_t`](#favoriteslistchanged_t) | a server was added/removed from the favorites list, you should refresh now. |
| `OnLobbyInvite` | 503 | [`LobbyInvite_t`](#lobbyinvite_t) | Someone has invited you to join a Lobby normally you don't need to do anything with this, since the Steam UI will also display a '<user> has invited you to the lobby, join?' dialog if the user outside a game chooses to join, your game will be launched with the parameter "+connect_lobby <64-bit lobby id>", or with the callback GameLobbyJoinRequested_t if they're already in-game. |
| `OnLobbyEnter` | 504 | [`LobbyEnter_t`](#lobbyenter_t) | Sent on entering a lobby, or on failing to enter m_EChatRoomEnterResponse will be set to k_EChatRoomEnterResponseSuccess on success, or a higher value on failure (see enum EChatRoomEnterResponse). |
| `OnLobbyDataUpdate` | 505 | [`LobbyDataUpdate_t`](#lobbydataupdate_t) | The lobby metadata has changed if m_ulSteamIDMember is the steamID of a lobby member, use GetLobbyMemberData() to access per-user details if m_ulSteamIDMember == m_ulSteamIDLobby, use GetLobbyData() to access lobby metadata. |
| `OnLobbyChatUpdate` | 506 | [`LobbyChatUpdate_t`](#lobbychatupdate_t) | The lobby chat room state has changed this is usually sent when a user has joined or left the lobby. |
| `OnLobbyChatMsg` | 507 | [`LobbyChatMsg_t`](#lobbychatmsg_t) | A chat message for this lobby has been sent use GetLobbyChatEntry( m_iChatID ) to retrieve the contents of this message. |
| `OnLobbyGameCreated` | 509 | [`LobbyGameCreated_t`](#lobbygamecreated_t) | A game created a game for all the members of the lobby to join, as triggered by a SetLobbyGameServer() it's up to the individual clients to take action on this; the usual game behavior is to leave the lobby and connect to the specified game server. |
| `OnLobbyMatchList` | 510 | [`LobbyMatchList_t`](#lobbymatchlist_t) | Number of matching lobbies found iterate the returned lobbies with GetLobbyByIndex(), from values 0 to m_nLobbiesMatching-1. |
| `OnLobbyKicked` | 512 | [`LobbyKicked_t`](#lobbykicked_t) | posted if a user is forcefully removed from a lobby can occur if a user loses connection to Steam. |
| `OnLobbyCreated` | 513 | [`LobbyCreated_t`](#lobbycreated_t) | Result of our request to create a Lobby m_eResult == k_EResultOK on success at this point, the lobby has been joined and is ready for use a LobbyEnter_t callback will also be received (since the local user is joining their own lobby). |
| `OnFavoritesListAccountsUpdated` | 516 | [`FavoritesListAccountsUpdated_t`](#favoriteslistaccountsupdated_t) | Result of our request to create a Lobby m_eResult == k_EResultOK on success at this point, the lobby has been joined and is ready for use a LobbyEnter_t callback will also be received (since the local user is joining their own lobby). |

Handler signature (the IDE generates it when you double-click the event):

```pascal
procedure TForm1.SteamMatchmaking1FavoritesListChanged(Sender: TObject; const AData: FavoritesListChanged_t);
```

## The plug-in: TSteamMatchmakingPlugin

ISteamMatchmaking plug-in. Registered by linking the unit; find it with @code(Steam.FindPlugin(TSteamMatchmakingPlugin)).

Reach it through the component (`SteamMatchmaking1.Plugin`) or the core:

```pascal
P := TSteamMatchmakingPlugin(Steam.FindPlugin(TSteamMatchmakingPlugin));   // Delphi also: Steam.Plugin<TSteamMatchmakingPlugin>
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
| [`GetFavoriteGameCount`](#getfavoritegamecount) | returns the number of favorites servers the user has stored. |
| [`GetFavoriteGame`](#getfavoritegame) | returns the details of the game server iGame is of range [0,GetFavoriteGameCount()) *pnIP, *pnConnPort are filled in the with IP:port of the game server ... |
| [`AddFavoriteGame`](#addfavoritegame) | adds the game server to the local list; updates the time played of the server if it already exists in the list. |
| [`RemoveFavoriteGame`](#removefavoritegame) | removes the game server from the local storage; returns true if one was removed. |
| [`RequestLobbyList`](#requestlobbylist) | Wraps `SteamAPI_ISteamMatchmaking_RequestLobbyList`. Call result: `LobbyMatchList_t` (`LobbyMatchList_t_k_iCallback`). |
| [`AddRequestLobbyListStringFilter`](#addrequestlobbyliststringfilter) | filters for lobbies this needs to be called before RequestLobbyList() to take effect these are cleared on each call to RequestLobbyList(). |
| [`AddRequestLobbyListNumericalFilter`](#addrequestlobbylistnumericalfilter) | numerical comparison. |
| [`AddRequestLobbyListNearValueFilter`](#addrequestlobbylistnearvaluefilter) | returns results closest to the specified value. Multiple near filters can be added, with early filters taking precedence. |
| [`AddRequestLobbyListFilterSlotsAvailable`](#addrequestlobbylistfilterslotsavailable) | returns only lobbies with the specified number of slots available. |
| [`AddRequestLobbyListDistanceFilter`](#addrequestlobbylistdistancefilter) | sets the distance for which we should search for lobbies (based on users IP address to location map on the Steam backed). |
| [`AddRequestLobbyListResultCountFilter`](#addrequestlobbylistresultcountfilter) | sets how many results to return, the lower the count the faster it is to download the lobby results & details to the client. |
| [`AddRequestLobbyListCompatibleMembersFilter`](#addrequestlobbylistcompatiblemembersfilter) | Wraps `SteamAPI_ISteamMatchmaking_AddRequestLobbyListCompatibleMembersFilter`. |
| [`GetLobbyByIndex`](#getlobbybyindex) | returns the CSteamID of a lobby, as retrieved by a RequestLobbyList call should only be called after a LobbyMatchList_t callback is received iLobby is of ... |
| [`CreateLobby`](#createlobby) | Create a lobby on the Steam servers. If private, then the lobby will not be returned by any RequestLobbyList() call; the CSteamID of the lobby will need to ... |
| [`JoinLobby`](#joinlobby) | Joins an existing lobby this is an asynchronous request results will be returned by LobbyEnter_t callback & call result, check m_EChatRoomEnterResponse to ... |
| [`LeaveLobby`](#leavelobby) | Leave a lobby; this will take effect immediately on the client side other users in the lobby will be notified by a LobbyChatUpdate_t callback. |
| [`InviteUserToLobby`](#inviteusertolobby) | Invite another user to the lobby the target user will receive a LobbyInvite_t callback will return true if the invite is successfully sent, whether or not ... |
| [`GetNumLobbyMembers`](#getnumlobbymembers) | returns the number of users in the specified lobby. |
| [`GetLobbyMemberByIndex`](#getlobbymemberbyindex) | returns the CSteamID of a user in the lobby iMember is of range [0,GetNumLobbyMembers()) note that the current user must be in a lobby to retrieve CSteamIDs ... |
| [`GetLobbyData`](#getlobbydata) | Get data associated with this lobby takes a simple key, and returns the string associated with it "" will be returned if no value is set, or if steamIDLobby ... |
| [`SetLobbyData`](#setlobbydata) | Sets a key/value pair in the lobby metadata each user in the lobby will be broadcast this new value, and any new users joining will receive any existing ... |
| [`GetLobbyDataCount`](#getlobbydatacount) | returns the number of metadata keys set on the specified lobby. |
| [`GetLobbyDataByIndex`](#getlobbydatabyindex) | returns a lobby metadata key/values pair by index, of range [0, GetLobbyDataCount()). |
| [`DeleteLobbyData`](#deletelobbydata) | removes a metadata key from the lobby. |
| [`GetLobbyMemberData`](#getlobbymemberdata) | Gets per-user metadata for someone in this lobby. |
| [`SetLobbyMemberData`](#setlobbymemberdata) | Sets per-user metadata (for the local user implicitly). |
| [`SendLobbyChatMsg`](#sendlobbychatmsg) | Broadcasts a chat message to the all the users in the lobby users in the lobby (including the local user) will receive a LobbyChatMsg_t callback returns ... |
| [`GetLobbyChatEntry`](#getlobbychatentry) | Get a chat message as specified in a LobbyChatMsg_t callback iChatID is the LobbyChatMsg_t::m_iChatID value in the callback *pSteamIDUser is filled in with ... |
| [`RequestLobbyData`](#requestlobbydata) | Refreshes metadata for a lobby you're not necessarily in right now you never do this for lobbies you're a member of, only if your this will send down all ... |
| [`SetLobbyGameServer`](#setlobbygameserver) | sets the game server associated with the lobby usually at this point, the users will join the specified game server either the IP/Port or the steamID of the ... |
| [`GetLobbyGameServer`](#getlobbygameserver) | returns the details of a game server set in a lobby - returns false if there is no game server set, or that lobby doesn't exist. |
| [`SetLobbyMemberLimit`](#setlobbymemberlimit) | set the limit on the # of users who can join the lobby. |
| [`GetLobbyMemberLimit`](#getlobbymemberlimit) | returns the current limit on the # of users who can join the lobby; returns 0 if no limit is defined. |
| [`SetLobbyType`](#setlobbytype) | updates which type of lobby it is only lobbies that are k_ELobbyTypePublic or k_ELobbyTypeInvisible, and are set to joinable, will be returned by ... |
| [`SetLobbyJoinable`](#setlobbyjoinable) | sets whether or not a lobby is joinable - defaults to true for a new lobby if set to false, no user can join, even if they are a friend or have been invited. |
| [`GetLobbyOwner`](#getlobbyowner) | returns the current lobby owner you must be a member of the lobby to access this there always one lobby owner - if the current owner leaves, another user ... |
| [`SetLobbyOwner`](#setlobbyowner) | changes who the lobby owner is you must be the lobby owner for this to succeed, and steamIDNewOwner must be in the lobby after completion, the local user ... |
| [`SetLinkedLobby`](#setlinkedlobby) | link two lobbies for the purposes of checking player compatibility you must be the lobby owner of both lobbies. |

#### GetFavoriteGameCount

```pascal
function GetFavoriteGameCount: Integer;
```

returns the number of favorites servers the user has stored.

#### GetFavoriteGame

```pascal
function GetFavoriteGame(iGame: Integer; var pnAppID: AppId_t; var pnIP: UInt32; var pnConnPort: UInt16; var pnQueryPort: UInt16; var punFlags: UInt32; var pRTime32LastPlayedOnServer: UInt32): Boolean;
```

returns the details of the game server iGame is of range [0,GetFavoriteGameCount()) *pnIP, *pnConnPort are filled in the with IP:port of the game server *punFlags specify whether the game server was stored as an explicit favorite or in the history of connections *pRTime32LastPlayedOnServer is filled in the with the Unix time the favorite was added.

#### AddFavoriteGame

```pascal
function AddFavoriteGame(nAppID: AppId_t; nIP: UInt32; nConnPort: UInt16; nQueryPort: UInt16; unFlags: UInt32; rTime32LastPlayedOnServer: UInt32): Integer;
```

adds the game server to the local list; updates the time played of the server if it already exists in the list.

#### RemoveFavoriteGame

```pascal
function RemoveFavoriteGame(nAppID: AppId_t; nIP: UInt32; nConnPort: UInt16; nQueryPort: UInt16; unFlags: UInt32): Boolean;
```

removes the game server from the local storage; returns true if one was removed.

#### RequestLobbyList

```pascal
function RequestLobbyList: SteamAPICall_t;
```

Wraps `SteamAPI_ISteamMatchmaking_RequestLobbyList`. Call result: `LobbyMatchList_t` (`LobbyMatchList_t_k_iCallback`).

#### AddRequestLobbyListStringFilter

```pascal
procedure AddRequestLobbyListStringFilter(const pchKeyToMatch: string; const pchValueToMatch: string; eComparisonType: ELobbyComparison);
```

filters for lobbies this needs to be called before RequestLobbyList() to take effect these are cleared on each call to RequestLobbyList().

#### AddRequestLobbyListNumericalFilter

```pascal
procedure AddRequestLobbyListNumericalFilter(const pchKeyToMatch: string; nValueToMatch: Integer; eComparisonType: ELobbyComparison);
```

numerical comparison.

#### AddRequestLobbyListNearValueFilter

```pascal
procedure AddRequestLobbyListNearValueFilter(const pchKeyToMatch: string; nValueToBeCloseTo: Integer);
```

returns results closest to the specified value. Multiple near filters can be added, with early filters taking precedence.

#### AddRequestLobbyListFilterSlotsAvailable

```pascal
procedure AddRequestLobbyListFilterSlotsAvailable(nSlotsAvailable: Integer);
```

returns only lobbies with the specified number of slots available.

#### AddRequestLobbyListDistanceFilter

```pascal
procedure AddRequestLobbyListDistanceFilter(AELobbyDistanceFilter: ELobbyDistanceFilter);
```

sets the distance for which we should search for lobbies (based on users IP address to location map on the Steam backed).

#### AddRequestLobbyListResultCountFilter

```pascal
procedure AddRequestLobbyListResultCountFilter(cMaxResults: Integer);
```

sets how many results to return, the lower the count the faster it is to download the lobby results & details to the client.

#### AddRequestLobbyListCompatibleMembersFilter

```pascal
procedure AddRequestLobbyListCompatibleMembersFilter(const steamIDLobby: TSteamID);
```

Wraps `SteamAPI_ISteamMatchmaking_AddRequestLobbyListCompatibleMembersFilter`.

#### GetLobbyByIndex

```pascal
function GetLobbyByIndex(iLobby: Integer): TSteamID;
```

returns the CSteamID of a lobby, as retrieved by a RequestLobbyList call should only be called after a LobbyMatchList_t callback is received iLobby is of the range [0, LobbyMatchList_t::m_nLobbiesMatching) the returned CSteamID::IsValid() will be false if iLobby is out of range.

#### CreateLobby

```pascal
function CreateLobby(AELobbyType: ELobbyType; cMaxMembers: Integer): SteamAPICall_t;
```

Create a lobby on the Steam servers. If private, then the lobby will not be returned by any RequestLobbyList() call; the CSteamID of the lobby will need to be communicated via game channels or via InviteUserToLobby() this is an asynchronous request results will be returned by LobbyCreated_t callback and call result; lobby is joined & ready to use at this point a LobbyEnter_t callback will also be received (since the local user is joining their own lobby). Call result: `LobbyCreated_t` (`LobbyCreated_t_k_iCallback`).

#### JoinLobby

```pascal
function JoinLobby(const steamIDLobby: TSteamID): SteamAPICall_t;
```

Joins an existing lobby this is an asynchronous request results will be returned by LobbyEnter_t callback & call result, check m_EChatRoomEnterResponse to see if was successful lobby metadata is available to use immediately on this call completing. Call result: `LobbyEnter_t` (`LobbyEnter_t_k_iCallback`).

#### LeaveLobby

```pascal
procedure LeaveLobby(const steamIDLobby: TSteamID);
```

Leave a lobby; this will take effect immediately on the client side other users in the lobby will be notified by a LobbyChatUpdate_t callback.

#### InviteUserToLobby

```pascal
function InviteUserToLobby(const steamIDLobby: TSteamID; const steamIDInvitee: TSteamID): Boolean;
```

Invite another user to the lobby the target user will receive a LobbyInvite_t callback will return true if the invite is successfully sent, whether or not the target responds returns false if the local user is not connected to the Steam servers if the other user clicks the join link, a GameLobbyJoinRequested_t will be posted if the user is in-game, or if the game isn't running yet the game will be launched with the parameter +connect_lobby <64-bit lobby id>.

#### GetNumLobbyMembers

```pascal
function GetNumLobbyMembers(const steamIDLobby: TSteamID): Integer;
```

returns the number of users in the specified lobby.

#### GetLobbyMemberByIndex

```pascal
function GetLobbyMemberByIndex(const steamIDLobby: TSteamID; iMember: Integer): TSteamID;
```

returns the CSteamID of a user in the lobby iMember is of range [0,GetNumLobbyMembers()) note that the current user must be in a lobby to retrieve CSteamIDs of other users in that lobby.

#### GetLobbyData

```pascal
function GetLobbyData(const steamIDLobby: TSteamID; const pchKey: string): string;
```

Get data associated with this lobby takes a simple key, and returns the string associated with it "" will be returned if no value is set, or if steamIDLobby is invalid.

#### SetLobbyData

```pascal
function SetLobbyData(const steamIDLobby: TSteamID; const pchKey: string; const pchValue: string): Boolean;
```

Sets a key/value pair in the lobby metadata each user in the lobby will be broadcast this new value, and any new users joining will receive any existing data this can be used to set lobby names, map, etc. to reset a key, just set it to "" other users in the lobby will receive notification of the lobby data change via a LobbyDataUpdate_t callback.

#### GetLobbyDataCount

```pascal
function GetLobbyDataCount(const steamIDLobby: TSteamID): Integer;
```

returns the number of metadata keys set on the specified lobby.

#### GetLobbyDataByIndex

```pascal
function GetLobbyDataByIndex(const steamIDLobby: TSteamID; iLobbyData: Integer; pchKey: PAnsiChar; cchKeyBufferSize: Integer; pchValue: PAnsiChar; cchValueBufferSize: Integer): Boolean;
```

returns a lobby metadata key/values pair by index, of range [0, GetLobbyDataCount()).

#### DeleteLobbyData

```pascal
function DeleteLobbyData(const steamIDLobby: TSteamID; const pchKey: string): Boolean;
```

removes a metadata key from the lobby.

#### GetLobbyMemberData

```pascal
function GetLobbyMemberData(const steamIDLobby: TSteamID; const steamIDUser: TSteamID; const pchKey: string): string;
```

Gets per-user metadata for someone in this lobby.

#### SetLobbyMemberData

```pascal
procedure SetLobbyMemberData(const steamIDLobby: TSteamID; const pchKey: string; const pchValue: string);
```

Sets per-user metadata (for the local user implicitly).

#### SendLobbyChatMsg

```pascal
function SendLobbyChatMsg(const steamIDLobby: TSteamID; pvMsgBody: Pointer; cubMsgBody: Integer): Boolean;
```

Broadcasts a chat message to the all the users in the lobby users in the lobby (including the local user) will receive a LobbyChatMsg_t callback returns true if the message is successfully sent pvMsgBody can be binary or text data, up to 4k if pvMsgBody is text, cubMsgBody should be strlen( text ) + 1, to include the null terminator.

#### GetLobbyChatEntry

```pascal
function GetLobbyChatEntry(const steamIDLobby: TSteamID; iChatID: Integer; var pSteamIDUser: TSteamID; pvData: Pointer; cubData: Integer; var peChatEntryType: EChatEntryType): Integer;
```

Get a chat message as specified in a LobbyChatMsg_t callback iChatID is the LobbyChatMsg_t::m_iChatID value in the callback *pSteamIDUser is filled in with the CSteamID of the member *pvData is filled in with the message itself return value is the number of bytes written into the buffer.

#### RequestLobbyData

```pascal
function RequestLobbyData(const steamIDLobby: TSteamID): Boolean;
```

Refreshes metadata for a lobby you're not necessarily in right now you never do this for lobbies you're a member of, only if your this will send down all the metadata associated with a lobby this is an asynchronous call returns false if the local user is not connected to the Steam servers results will be returned by a LobbyDataUpdate_t callback if the specified lobby doesn't exist, LobbyDataUpdate_t::m_bSuccess will be set to false.

#### SetLobbyGameServer

```pascal
procedure SetLobbyGameServer(const steamIDLobby: TSteamID; unGameServerIP: UInt32; unGameServerPort: UInt16; const steamIDGameServer: TSteamID);
```

sets the game server associated with the lobby usually at this point, the users will join the specified game server either the IP/Port or the steamID of the game server has to be valid, depending on how you want the clients to be able to connect.

#### GetLobbyGameServer

```pascal
function GetLobbyGameServer(const steamIDLobby: TSteamID; var punGameServerIP: UInt32; var punGameServerPort: UInt16; var psteamIDGameServer: TSteamID): Boolean;
```

returns the details of a game server set in a lobby - returns false if there is no game server set, or that lobby doesn't exist.

#### SetLobbyMemberLimit

```pascal
function SetLobbyMemberLimit(const steamIDLobby: TSteamID; cMaxMembers: Integer): Boolean;
```

set the limit on the # of users who can join the lobby.

#### GetLobbyMemberLimit

```pascal
function GetLobbyMemberLimit(const steamIDLobby: TSteamID): Integer;
```

returns the current limit on the # of users who can join the lobby; returns 0 if no limit is defined.

#### SetLobbyType

```pascal
function SetLobbyType(const steamIDLobby: TSteamID; AELobbyType: ELobbyType): Boolean;
```

updates which type of lobby it is only lobbies that are k_ELobbyTypePublic or k_ELobbyTypeInvisible, and are set to joinable, will be returned by RequestLobbyList() calls.

#### SetLobbyJoinable

```pascal
function SetLobbyJoinable(const steamIDLobby: TSteamID; bLobbyJoinable: Boolean): Boolean;
```

sets whether or not a lobby is joinable - defaults to true for a new lobby if set to false, no user can join, even if they are a friend or have been invited.

#### GetLobbyOwner

```pascal
function GetLobbyOwner(const steamIDLobby: TSteamID): TSteamID;
```

returns the current lobby owner you must be a member of the lobby to access this there always one lobby owner - if the current owner leaves, another user will become the owner it is possible (bur rare) to join a lobby just as the owner is leaving, thus entering a lobby with self as the owner.

#### SetLobbyOwner

```pascal
function SetLobbyOwner(const steamIDLobby: TSteamID; const steamIDNewOwner: TSteamID): Boolean;
```

changes who the lobby owner is you must be the lobby owner for this to succeed, and steamIDNewOwner must be in the lobby after completion, the local user will no longer be the owner.

#### SetLinkedLobby

```pascal
function SetLinkedLobby(const steamIDLobby: TSteamID; const steamIDLobbyDependent: TSteamID): Boolean;
```

link two lobbies for the purposes of checking player compatibility you must be the lobby owner of both lobbies.

### Async methods

Each `...Async` method starts the call and registers `AHandler` for its result
(`procedure(const AData: TSteamCallbackData; AIOFailure: Boolean) of object`). The
handler runs once, on the delivery thread, with the result record in `AData`
(`AData.CopyTo(Rec, SizeOf(Rec))`); its object owns the registration - call
`Steam.Dispatcher.RemoveOwner(Self)` in that object's destructor. The plain method of
the same name returns the `SteamAPICall_t` instead, and its result reaches the
component's event.

#### RequestLobbyListAsync

```pascal
function RequestLobbyListAsync(AHandler: TSteamCallResultEvent): SteamAPICall_t;
```

Calls `RequestLobbyList` and registers AHandler for its result (`LobbyMatchList_t`). The handler's object owns the registration (remove it with Steam.Dispatcher.RemoveOwner). Returns: (The call handle, or k_uAPICallInvalid when Steam refused the call.)

#### CreateLobbyAsync

```pascal
function CreateLobbyAsync(AELobbyType: ELobbyType; cMaxMembers: Integer; AHandler: TSteamCallResultEvent): SteamAPICall_t;
```

Calls `CreateLobby` and registers AHandler for its result (`LobbyCreated_t`). The handler's object owns the registration (remove it with Steam.Dispatcher.RemoveOwner). Returns: (The call handle, or k_uAPICallInvalid when Steam refused the call.)

#### JoinLobbyAsync

```pascal
function JoinLobbyAsync(const steamIDLobby: TSteamID; AHandler: TSteamCallResultEvent): SteamAPICall_t;
```

Calls `JoinLobby` and registers AHandler for its result (`LobbyEnter_t`). The handler's object owns the registration (remove it with Steam.Dispatcher.RemoveOwner). Returns: (The call handle, or k_uAPICallInvalid when Steam refused the call.)

### Properties

| Property | Description |
|----------|-------------|
| `Handle: Pointer` | The raw ISteamMatchmaking pointer (first argument of every `Flat` export). |
| `Flat: TSteamMatchmakingFlat` | The bound flat exports, for calls the methods do not cover. |

## Payload records

Declared in `Steamworks.SDKTypes` (generated from the SDK headers; layouts verified
against the C headers for Win64, Win32, Linux64 and macOS ARM64).

### FavoritesListChanged_t

Callback id 502 (`FavoritesListChanged_t_k_iCallback`).

| Field | C declaration |
|-------|---------------|
| `m_nIP: UInt32` | C field `uint32 m_nIP`. |
| `m_nQueryPort: UInt32` | C field `uint32 m_nQueryPort`. |
| `m_nConnPort: UInt32` | C field `uint32 m_nConnPort`. |
| `m_nAppID: UInt32` | C field `uint32 m_nAppID`. |
| `m_nFlags: UInt32` | C field `uint32 m_nFlags`. |
| `m_bAdd: Boolean` | C field `bool m_bAdd`. |
| `m_unAccountId: AccountID_t` | C field `AccountID_t m_unAccountId`. |

### LobbyInvite_t

Callback id 503 (`LobbyInvite_t_k_iCallback`).

| Field | C declaration |
|-------|---------------|
| `m_ulSteamIDUser: UInt64` | C field `uint64 m_ulSteamIDUser`. |
| `m_ulSteamIDLobby: UInt64` | C field `uint64 m_ulSteamIDLobby`. |
| `m_ulGameID: UInt64` | C field `uint64 m_ulGameID`. |

### LobbyEnter_t

Callback id 504 (`LobbyEnter_t_k_iCallback`).

| Field | C declaration |
|-------|---------------|
| `m_ulSteamIDLobby: UInt64` | C field `uint64 m_ulSteamIDLobby`. |
| `m_rgfChatPermissions: UInt32` | C field `uint32 m_rgfChatPermissions`. |
| `m_bLocked: Boolean` | C field `bool m_bLocked`. |
| `m_EChatRoomEnterResponse: UInt32` | C field `uint32 m_EChatRoomEnterResponse`. |

### LobbyDataUpdate_t

Callback id 505 (`LobbyDataUpdate_t_k_iCallback`).

| Field | C declaration |
|-------|---------------|
| `m_ulSteamIDLobby: UInt64` | C field `uint64 m_ulSteamIDLobby`. |
| `m_ulSteamIDMember: UInt64` | C field `uint64 m_ulSteamIDMember`. |
| `m_bSuccess: UInt8` | C field `uint8 m_bSuccess`. |

### LobbyChatUpdate_t

Callback id 506 (`LobbyChatUpdate_t_k_iCallback`).

| Field | C declaration |
|-------|---------------|
| `m_ulSteamIDLobby: UInt64` | C field `uint64 m_ulSteamIDLobby`. |
| `m_ulSteamIDUserChanged: UInt64` | C field `uint64 m_ulSteamIDUserChanged`. |
| `m_ulSteamIDMakingChange: UInt64` | C field `uint64 m_ulSteamIDMakingChange`. |
| `m_rgfChatMemberStateChange: UInt32` | C field `uint32 m_rgfChatMemberStateChange`. |

### LobbyChatMsg_t

Callback id 507 (`LobbyChatMsg_t_k_iCallback`).

| Field | C declaration |
|-------|---------------|
| `m_ulSteamIDLobby: UInt64` | C field `uint64 m_ulSteamIDLobby`. |
| `m_ulSteamIDUser: UInt64` | C field `uint64 m_ulSteamIDUser`. |
| `m_eChatEntryType: UInt8` | C field `uint8 m_eChatEntryType`. |
| `m_iChatID: UInt32` | C field `uint32 m_iChatID`. |

### LobbyGameCreated_t

Callback id 509 (`LobbyGameCreated_t_k_iCallback`).

| Field | C declaration |
|-------|---------------|
| `m_ulSteamIDLobby: UInt64` | C field `uint64 m_ulSteamIDLobby`. |
| `m_ulSteamIDGameServer: UInt64` | C field `uint64 m_ulSteamIDGameServer`. |
| `m_unIP: UInt32` | C field `uint32 m_unIP`. |
| `m_usPort: UInt16` | C field `uint16 m_usPort`. |

### LobbyMatchList_t

Callback id 510 (`LobbyMatchList_t_k_iCallback`).

| Field | C declaration |
|-------|---------------|
| `m_nLobbiesMatching: UInt32` | C field `uint32 m_nLobbiesMatching`. |

### LobbyKicked_t

Callback id 512 (`LobbyKicked_t_k_iCallback`).

| Field | C declaration |
|-------|---------------|
| `m_ulSteamIDLobby: UInt64` | C field `uint64 m_ulSteamIDLobby`. |
| `m_ulSteamIDAdmin: UInt64` | C field `uint64 m_ulSteamIDAdmin`. |
| `m_bKickedDueToDisconnect: UInt8` | C field `uint8 m_bKickedDueToDisconnect`. |

### LobbyCreated_t

Callback id 513 (`LobbyCreated_t_k_iCallback`).

| Field | C declaration |
|-------|---------------|
| `m_eResult: EResult` | C field `EResult m_eResult`. |
| `m_ulSteamIDLobby: UInt64` | C field `uint64 m_ulSteamIDLobby`. |

### FavoritesListAccountsUpdated_t

Callback id 516 (`FavoritesListAccountsUpdated_t_k_iCallback`).

| Field | C declaration |
|-------|---------------|
| `m_eResult: EResult` | C field `EResult m_eResult`. |
