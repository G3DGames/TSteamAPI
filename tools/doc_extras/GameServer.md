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
