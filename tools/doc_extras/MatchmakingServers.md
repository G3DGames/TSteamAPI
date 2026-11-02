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
