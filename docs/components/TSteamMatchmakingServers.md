# TSteamMatchmakingServers and TSteamMatchmakingServersPlugin (ISteamMatchmakingServers)

> **Generated** by `tools/gen_docs.py` from `lib/plugins/Steamworks.Plugin.MatchmakingServers.pas` - do not edit.
> Hand-written text: `tools/doc_extras/MatchmakingServers.md`. Steam's own descriptions are Valve's
> SDK comments, as in the generated units.

Unit: `Steamworks.Plugin.MatchmakingServers` - linking it (a `uses` entry, or dropping a `TSteamMatchmakingServers`) enables the
plug-in. Steam interface: `ISteamMatchmakingServers` (SDK 1.65).

## Overview

The server browser (`ISteamMatchmakingServers`): lists of game servers
(Internet, LAN, friends, favourites, history, spectator) for your AppID,
and per-server queries - ping, players, rules. Use it for games with
dedicated or listen servers that register with Steam's master servers;
lobbies are `TSteamMatchmaking`.

```pascal
procedure TForm1.btnRefreshClick(Sender: TObject);
begin
  FList := SteamMatchmakingServers1.StartServerList(sltInternet, MyAppID,
    ['notfull', 'secure'], ['', '']);
end;

procedure TForm1.SteamMatchmakingServers1ServerResponded(Sender: TObject;
  ARequest: HServerListRequest; AIndex: Integer; const AServer: gameserveritem_t);
begin
  ListBox1.Items.Add(Format('%s  %s  %d/%d  %d ms', [string(AServer.m_szServerName),
    string(AServer.m_szMap), AServer.m_nPlayers, AServer.m_nMaxPlayers, AServer.m_nPing]));
end;

procedure TForm1.SteamMatchmakingServers1ServerListComplete(Sender: TObject;
  ARequest: HServerListRequest; AResponse: EMatchMakingServerResponse);
begin
  // keep FList to refresh it (Plugin.RefreshQuery) or read it again
  // (Plugin.GetServerCount / GetServerDetails); release it when done:
  SteamMatchmakingServers1.StopServerList(FList);
end;
```

### Requests and their events

| Call | Events | Ends with |
|------|--------|-----------|
| `StartServerList(Kind, AppID, FilterKeys, FilterValues)` | `OnServerResponded` (with the server's `gameserveritem_t`) / `OnServerFailedToRespond` per server | `OnServerListComplete`; the request stays valid (refresh, read) until `StopServerList` |
| `StartPing(IP, QueryPort)` | - | `OnPingResponded` (details, `m_nPing`) or `OnPingFailed` |
| `StartPlayerDetails(IP, QueryPort)` | `OnPlayer` (name, score, seconds played) per player | `OnPlayersComplete` or `OnPlayersFailed` |
| `StartServerRules(IP, QueryPort)` | `OnRule` (name, value) per rule | `OnRulesComplete` or `OnRulesFailed` |

`StopServerList` releases a list (Valve: always release it);
`StopServerQuery` cancels a running ping / players / rules query. After
either, no more events arrive for it. IP addresses are in host order and
the port is the server's QUERY port - both straight from
`gameserveritem_t.m_NetAdr` (`m_unIP`, `m_usQueryPort`).

`StartPing`, `StartPlayerDetails` and `StartServerRules` return a QUERY
ID that the events carry as `AQuery` and `StopServerQuery` takes. It is
the plug-in's own number, unique and never reused, not Steam's
`HServerQuery` handle: Steam reuses its handle numbers, even while answers
for an earlier query with the same number are still arriving, so two
queries at once (a ping of one server, the rules of another) could not
be told apart by Steam's handle.

Filters are name / value pairs (two arrays of the same length; `''` for
filters without a value): `map`, `gamedir`, `dedicated`, `secure`,
`notfull`, `hasplayers`, `noplayers`, `linux`, `gametagsand`,
`gametagsnor`, `gamedataand`, `gamedataor`, `gamedatanor`, `and`, `or`,
`nand`, `nor`, `addr`, `gameaddr`, `white`, `collapse_addr_hash`,
`proxy`, `popularamongfriends` - see the comment in `isteammatchmaking.h`.

### How it works

Valve's interface does not use callbacks here: the caller passes a C++
object whose virtual methods Steam calls (`ISteamMatchmakingServerListResponse`
and the ping / players / rules responses). The plug-in builds these
objects itself - a record whose first field points to a table of Pascal
routines; on 32-bit Windows a three-instruction thunk turns MSVC's
`thiscall` into `stdcall`, everywhere else the object is simply the first
argument. Steam calls them from inside its frame
(`SteamAPI_ManualDispatch_RunFrame`), on whichever thread pumps; the
routines only copy the answer and hand it to
`TSteamCallbackDispatcher.Post`, so the events arrive like every other
callback - on the thread `TSteamAPI.Delivery` names, in order, never
inside Steam's frame. Freeing the component stops its requests.

Without the component, call the plug-in with your own handler:

```pascal
Req := P.StartServerList(sltLAN, MyAppID, [], [], ServerEvent);
// procedure TMyBrowser.ServerEvent(Sender: TObject; const AEvent: TSteamServerEvent;
//   const AText, AValue: string);  - AEvent.Kind says what happened
```

The generated methods with a raw `pRequestServersResponse: Pointer`
(`RequestInternetServerList`, `PingServer`, ...) are still there for a
C++-compatible object of your own; `ServerFriends`
(`ISteamMatchmakingServerFriendsResponse`, undocumented by Valve) has no
wrapper.

## Contents

* [The component: TSteamMatchmakingServers](#the-component-tsteammatchmakingservers)
  * [Events (11)](#events)
* [The plug-in: TSteamMatchmakingServersPlugin](#the-plug-in-tsteammatchmakingserversplugin)
  * [Methods](#methods)
  * [Async methods](#async-methods)
  * [Properties](#properties)
* [Payload records](#payload-records)

## The component: TSteamMatchmakingServers

ISteamMatchmakingServers component: drop it next to a TSteamAPI (linked automatically at run time when the owner has exactly one, otherwise set SteamAPI). Its events are the ISteamMatchmakingServers callbacks; call the interface through `Plugin`.

| Member | Kind | Description |
|--------|------|-------------|
| `SteamAPI` | published property | The `TSteamAPI` this component belongs to. At run time a component whose owner has exactly one `TSteamAPI` links itself. |
| `Plugin` | public property | The `TSteamMatchmakingServersPlugin` for calls; `nil` while Steam is not running. |
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
| `OnServerResponded` | | | A server of a list answered (C++ ServerResponded); AServer = its details. |
| `OnServerFailedToRespond` | | | A server of a list did not answer (C++ ServerFailedToRespond). |
| `OnServerListComplete` | | | The list's refresh has ended (C++ RefreshComplete); the request stays valid until `StopServerList`. |
| `OnPingResponded` | | | A pinged server answered (C++ ISteamMatchmakingPingResponse::ServerResponded). |
| `OnPingFailed` | | | A pinged server did not answer. |
| `OnPlayer` | | | One player of a `StartPlayerDetails` query (C++ AddPlayerToList). |
| `OnPlayersFailed` | | | The players query failed (C++ PlayersFailedToRespond). |
| `OnPlayersComplete` | | | The players query has ended (C++ PlayersRefreshComplete). |
| `OnRule` | | | One rule of a `StartServerRules` query (C++ RulesResponded). |
| `OnRulesFailed` | | | The rules query failed (C++ RulesFailedToRespond). |
| `OnRulesComplete` | | | The rules query has ended (C++ RulesRefreshComplete). |

Handler signature (the IDE generates it when you double-click the event):

```pascal
procedure TForm1.SteamMatchmakingServers1ServerResponded(Sender: TObject; ARequest: HServerListRequest; AIndex: Integer;
    const AServer: gameserveritem_t);
```

## The plug-in: TSteamMatchmakingServersPlugin

ISteamMatchmakingServers plug-in. Registered by linking the unit; find it with @code(Steam.FindPlugin(TSteamMatchmakingServersPlugin)).

Reach it through the component (`SteamMatchmakingServers1.Plugin`) or the core:

```pascal
P := TSteamMatchmakingServersPlugin(Steam.FindPlugin(TSteamMatchmakingServersPlugin));   // Delphi also: Steam.Plugin<TSteamMatchmakingServersPlugin>
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
| [`RequestInternetServerList`](#requestinternetserverlist) | Request a new list of servers of a particular type. These calls each correspond to one of the EMatchMakingType values. Each call allocates a new ... |
| [`RequestLANServerList`](#requestlanserverlist) | Wraps `SteamAPI_ISteamMatchmakingServers_RequestLANServerList`. |
| [`RequestFriendsServerList`](#requestfriendsserverlist) | Wraps `SteamAPI_ISteamMatchmakingServers_RequestFriendsServerList`. |
| [`RequestFavoritesServerList`](#requestfavoritesserverlist) | Wraps `SteamAPI_ISteamMatchmakingServers_RequestFavoritesServerList`. |
| [`RequestHistoryServerList`](#requesthistoryserverlist) | Wraps `SteamAPI_ISteamMatchmakingServers_RequestHistoryServerList`. |
| [`RequestSpectatorServerList`](#requestspectatorserverlist) | Wraps `SteamAPI_ISteamMatchmakingServers_RequestSpectatorServerList`. |
| [`ReleaseRequest`](#releaserequest) | Releases the asynchronous request object and cancels any pending query on it if there's a pending query in progress. RefreshComplete callback is not posted ... |
| [`GetServerDetails`](#getserverdetails) | Get details on a given server in the list, you can get the valid range of index values by calling GetServerCount(). You will also receive index values in ... |
| [`CancelQuery`](#cancelquery) | Cancel an request which is operation on the given list type. You should call this to cancel any in-progress requests before destructing a callback object ... |
| [`RefreshQuery`](#refreshquery) | Ping every server in your list again but don't update the list of servers Query callback installed when the server list was requested will be used again to ... |
| [`IsRefreshing`](#isrefreshing) | Returns true if the list is currently refreshing its server list. |
| [`GetServerCount`](#getservercount) | How many servers in the given list, GetServerDetails above takes 0... GetServerCount() - 1. |
| [`RefreshServer`](#refreshserver) | Refresh a single server inside of a query (rather than all the servers ). |
| [`PingServer`](#pingserver) | Request updated ping time and other details from a single server. |
| [`PlayerDetails`](#playerdetails) | Request the list of players currently playing on a server. |
| [`ServerRules`](#serverrules) | Request the list of rules that the server is running (See ISteamGameServer::SetKeyValue() to set the rules server side). |
| [`ServerFriends`](#serverfriends) | Request the list of friends that have played on this server. |
| [`CancelServerQuery`](#cancelserverquery) | Cancel an outstanding Ping/Players/Rules query from above. You should call this to cancel any in-progress requests before destructing a callback object that ... |
| [`StartServerList`](#startserverlist) | Asks Steam for a server list; the servers arrive one by one through AHandler (sekServerResponded with the details / sekServerFailedToRespond), then ... |
| [`StopServerList`](#stopserverlist) | Releases a request of `StartServerList` (ReleaseRequest): no more events for it. Raw requests (made with the generated methods) are released too. |
| [`StartPing`](#startping) | Pings one server (IP in host order, e.g. gameserveritem_t.m_NetAdr.m_unIP, and its QUERY port); one answer: sekPingResponded with the details or ... |
| [`StartPlayerDetails`](#startplayerdetails) | Asks one server for its players: sekPlayerAdded per player (AText = name), then sekPlayersComplete - or sekPlayersFailedToRespond. Returns: (The query id ... |
| [`StartServerRules`](#startserverrules) | Asks one server for its rules: sekRuleResponded per rule (AText = name, AValue = value), then sekRulesComplete - or sekRulesFailedToRespond. Returns: (The ... |
| [`StopServerQuery`](#stopserverquery) | Stops a ping / players / rules query of StartPing, StartPlayerDetails or StartServerRules (by the query id they returned; CancelServerQuery): no more events ... |
| [`StopOwner`](#stopowner) | Stops every request and query whose handler belongs to AOwner. Called automatically when a TComponent owner is freed. |
| [`ActiveCount`](#activecount) | Requests and queries still running (not ended, not stopped). |

#### RequestInternetServerList

```pascal
function RequestInternetServerList(iApp: AppId_t; ppchFilters: Pointer; nFilters: UInt32; pRequestServersResponse: Pointer): HServerListRequest;
```

Request a new list of servers of a particular type. These calls each correspond to one of the EMatchMakingType values. Each call allocates a new asynchronous request object. Request object must be released by calling ReleaseRequest( hServerListRequest ).

#### RequestLANServerList

```pascal
function RequestLANServerList(iApp: AppId_t; pRequestServersResponse: Pointer): HServerListRequest;
```

Wraps `SteamAPI_ISteamMatchmakingServers_RequestLANServerList`.

#### RequestFriendsServerList

```pascal
function RequestFriendsServerList(iApp: AppId_t; ppchFilters: Pointer; nFilters: UInt32; pRequestServersResponse: Pointer): HServerListRequest;
```

Wraps `SteamAPI_ISteamMatchmakingServers_RequestFriendsServerList`.

#### RequestFavoritesServerList

```pascal
function RequestFavoritesServerList(iApp: AppId_t; ppchFilters: Pointer; nFilters: UInt32; pRequestServersResponse: Pointer): HServerListRequest;
```

Wraps `SteamAPI_ISteamMatchmakingServers_RequestFavoritesServerList`.

#### RequestHistoryServerList

```pascal
function RequestHistoryServerList(iApp: AppId_t; ppchFilters: Pointer; nFilters: UInt32; pRequestServersResponse: Pointer): HServerListRequest;
```

Wraps `SteamAPI_ISteamMatchmakingServers_RequestHistoryServerList`.

#### RequestSpectatorServerList

```pascal
function RequestSpectatorServerList(iApp: AppId_t; ppchFilters: Pointer; nFilters: UInt32; pRequestServersResponse: Pointer): HServerListRequest;
```

Wraps `SteamAPI_ISteamMatchmakingServers_RequestSpectatorServerList`.

#### ReleaseRequest

```pascal
procedure ReleaseRequest(AHServerListRequest: HServerListRequest);
```

Releases the asynchronous request object and cancels any pending query on it if there's a pending query in progress. RefreshComplete callback is not posted when request is released.

#### GetServerDetails

```pascal
function GetServerDetails(hRequest: HServerListRequest; iServer: Integer): Pointer;
```

Get details on a given server in the list, you can get the valid range of index values by calling GetServerCount(). You will also receive index values in ISteamMatchmakingServerListResponse::ServerResponded() callbacks.

#### CancelQuery

```pascal
procedure CancelQuery(hRequest: HServerListRequest);
```

Cancel an request which is operation on the given list type. You should call this to cancel any in-progress requests before destructing a callback object that may have been passed to one of the above list request calls. Not doing so may result in a crash when a callback occurs on the destructed object. Canceling a query does not release the allocated request handle. The request handle must be released using ReleaseRequest( hRequest ).

#### RefreshQuery

```pascal
procedure RefreshQuery(hRequest: HServerListRequest);
```

Ping every server in your list again but don't update the list of servers Query callback installed when the server list was requested will be used again to post notifications and RefreshComplete, so the callback must remain valid until another RefreshComplete is called on it or the request is released with ReleaseRequest( hRequest ).

#### IsRefreshing

```pascal
function IsRefreshing(hRequest: HServerListRequest): Boolean;
```

Returns true if the list is currently refreshing its server list.

#### GetServerCount

```pascal
function GetServerCount(hRequest: HServerListRequest): Integer;
```

How many servers in the given list, GetServerDetails above takes 0... GetServerCount() - 1.

#### RefreshServer

```pascal
procedure RefreshServer(hRequest: HServerListRequest; iServer: Integer);
```

Refresh a single server inside of a query (rather than all the servers ).

#### PingServer

```pascal
function PingServer(unIP: UInt32; usPort: UInt16; pRequestServersResponse: Pointer): HServerQuery;
```

Request updated ping time and other details from a single server.

#### PlayerDetails

```pascal
function PlayerDetails(unIP: UInt32; usPort: UInt16; pRequestServersResponse: Pointer): HServerQuery;
```

Request the list of players currently playing on a server.

#### ServerRules

```pascal
function ServerRules(unIP: UInt32; usPort: UInt16; pRequestServersResponse: Pointer): HServerQuery;
```

Request the list of rules that the server is running (See ISteamGameServer::SetKeyValue() to set the rules server side).

#### ServerFriends

```pascal
function ServerFriends(unIP: UInt32; usPort: UInt16; pRequestServersResponse: Pointer): HServerQuery;
```

Request the list of friends that have played on this server.

#### CancelServerQuery

```pascal
procedure CancelServerQuery(AHServerQuery: HServerQuery);
```

Cancel an outstanding Ping/Players/Rules query from above. You should call this to cancel any in-progress requests before destructing a callback object that may have been passed to one of the above calls to avoid crashing when callbacks occur.

#### StartServerList

```pascal
function StartServerList(AKind: TSteamServerListKind; AApp: AppId_t; const AFilterKeys, AFilterValues: array of string; AHandler: TSteamServerEventHandler): HServerListRequest;
```

Asks Steam for a server list; the servers arrive one by one through AHandler (sekServerResponded with the details / sekServerFailedToRespond), then sekServerListComplete. The request stays usable (RefreshQuery, GetServerDetails, GetServerCount) until `StopServerList`. Parameter `AKind`: (Which list; sltLAN ignores the filters.) Parameter `AApp`: (The game's AppID.) Parameter `AFilterKeys`: (Filter names ("map", "gamedir", "dedicated", "secure", "notfull", "hasplayers", "gametagsand", ... - see isteammatchmaking.h); same length as AFilterValues.) Parameter `AFilterValues`: (Their values ('' for the filters without one).) Parameter `AHandler`: (Receives the answers. When its object is a TComponent, freeing it stops the request.) Returns: (The request handle, `nil` when Steam refused.) Raises: (ESteamworksError when Steam is not running, an export is missing or the two filter arrays differ in length.)

#### StopServerList

```pascal
procedure StopServerList(ARequest: HServerListRequest);
```

Releases a request of `StartServerList` (ReleaseRequest): no more events for it. Raw requests (made with the generated methods) are released too.

#### StartPing

```pascal
function StartPing(AIP: UInt32; AQueryPort: UInt16; AHandler: TSteamServerEventHandler): HServerQuery;
```

Pings one server (IP in host order, e.g. gameserveritem_t.m_NetAdr.m_unIP, and its QUERY port); one answer: sekPingResponded with the details or sekPingFailedToRespond. Returns: (The query id (the plug-in's own, never reused, carried by the events as TSteamServerEvent.Query), or HSERVERQUERY_INVALID when Steam refused.)

#### StartPlayerDetails

```pascal
function StartPlayerDetails(AIP: UInt32; AQueryPort: UInt16; AHandler: TSteamServerEventHandler): HServerQuery;
```

Asks one server for its players: sekPlayerAdded per player (AText = name), then sekPlayersComplete - or sekPlayersFailedToRespond. Returns: (The query id (as for `StartPing`), HSERVERQUERY_INVALID when Steam refused.)

#### StartServerRules

```pascal
function StartServerRules(AIP: UInt32; AQueryPort: UInt16; AHandler: TSteamServerEventHandler): HServerQuery;
```

Asks one server for its rules: sekRuleResponded per rule (AText = name, AValue = value), then sekRulesComplete - or sekRulesFailedToRespond. Returns: (The query id (as for `StartPing`), HSERVERQUERY_INVALID when Steam refused.)

#### StopServerQuery

```pascal
procedure StopServerQuery(AQuery: HServerQuery);
```

Stops a ping / players / rules query of StartPing, StartPlayerDetails or StartServerRules (by the query id they returned; CancelServerQuery): no more events for it. Harmless for a query that has ended. A raw query of the generated PingServer & co. is stopped with the generated CancelServerQuery.

#### StopOwner

```pascal
procedure StopOwner(AOwner: TObject);
```

Stops every request and query whose handler belongs to AOwner. Called automatically when a TComponent owner is freed.

#### ActiveCount

```pascal
function ActiveCount: Integer;
```

Requests and queries still running (not ended, not stopped).

### Async methods

None.

### Properties

| Property | Description |
|----------|-------------|
| `Handle: Pointer` | The raw ISteamMatchmakingServers pointer (first argument of every `Flat` export). |
| `Flat: TSteamMatchmakingServersFlat` | The bound flat exports, for calls the methods do not cover. |

## Payload records

Declared in `Steamworks.SDKTypes` (generated from the SDK headers; layouts verified
against the C headers for Win64, Win32, Linux64, Linux32, LinuxARM64 and macOS ARM64).
