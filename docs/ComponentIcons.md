# Component icons - brief

Palette icons for TSteamAPI and every plug-in component. Icons are
supplied as source images; packaging them for each IDE (Delphi `.dcr` /
`.res`, Lazarus PNG resources in the `.lpk`) is done in the repository, and
the generator (`tools/gen_steam_api.py`) will attach each new plug-in's icon
automatically.

Status: **to do later** (owner, 2026-10-30 - "no point until we're
finished"). 34 components are registered now: TSteamAPI, 24 client
components and 9 game-server components. No more are planned.

## Format

* **One `.ico` per component**, named after the class: `TSteamFriends.ico`.
* **32-bit with alpha** (transparent background).
* **Sizes inside each `.ico`: 16, 24, 32, 36, 48 px** - optionally also
  64 and 256 for the documentation and README.
  * Delphi's palette uses 16 / 24 / 32 for its DPI scales.
  * Lazarus uses 24 (100 %), 36 (150 %) and 48 (200 %).
* **Design for 16 px first**: only a bold silhouette survives at that size.
  Keep one shared motif across the set and vary a single symbol per
  interface.
* **Do not use Valve's Steam logo**: it is Valve's trademark and their
  brand guidelines restrict its use in third-party tools. A generic
  "steam / valve" motif is safer.

## Core and client components (25)

| Class | Interface | Suggested symbol |
|---|---|---|
| `TSteamAPI` | (root - the core) | the base motif, stronger or framed - the hub |
| `TSteamUtils` | ISteamUtils | wrench / gear |
| `TSteamUser` | ISteamUser | single person |
| `TSteamFriends` | ISteamFriends | two people |
| `TSteamApps` | ISteamApps | app tile / box |
| `TSteamUserStats` | ISteamUserStats | trophy (achievements, leaderboards) |
| `TSteamRemoteStorage` | ISteamRemoteStorage | cloud (Steam Cloud saves) |
| `TSteamScreenshots` | ISteamScreenshots | camera |
| `TSteamTimeline` | ISteamTimeline | timeline / markers |
| `TSteamUGC` | ISteamUGC | puzzle piece / workshop |
| `TSteamInput` | ISteamInput | gamepad |
| `TSteamMatchmaking` | ISteamMatchmaking | lobby / group joining |
| `TSteamMatchmakingServers` | ISteamMatchmakingServers | server list |
| `TSteamParties` | ISteamParties | party / group flag |
| `TSteamMusic` | ISteamMusic | music note |
| `TSteamHTTP` | ISteamHTTP | globe |
| `TSteamHTMLSurface` | ISteamHTMLSurface | browser window |
| `TSteamInventory` | ISteamInventory | backpack / chest |
| `TSteamVideo` | ISteamVideo | film / play |
| `TSteamParentalSettings` | ISteamParentalSettings | shield / lock |
| `TSteamRemotePlay` | ISteamRemotePlay | screen + signal |
| `TSteamNetworking` | ISteamNetworking (old P2P, deprecated by Valve) | two linked dots / old cable |
| `TSteamNetworkingSockets` | ISteamNetworkingSockets | plug / socket |
| `TSteamNetworkingMessages` | ISteamNetworkingMessages | envelope |
| `TSteamNetworkingUtils` | ISteamNetworkingUtils | network + wrench |

## Game-server components (9)

Two have their own interface; the other seven are the game server's
copies of client interfaces.

| Class | Interface | Suggested symbol |
|---|---|---|
| `TSteamGameServer` | ISteamGameServer | server rack |
| `TSteamGameServerStats` | ISteamGameServerStats | server + trophy |
| `TSteamGameServerUtils` | the server's ISteamUtils | as TSteamUtils + server badge |
| `TSteamGameServerNetworking` | the server's ISteamNetworking | as TSteamNetworking + server badge |
| `TSteamGameServerNetworkingSockets` | the server's ISteamNetworkingSockets | as TSteamNetworkingSockets + server badge |
| `TSteamGameServerNetworkingMessages` | the server's ISteamNetworkingMessages | as TSteamNetworkingMessages + server badge |
| `TSteamGameServerHTTP` | the server's ISteamHTTP | as TSteamHTTP + server badge |
| `TSteamGameServerUGC` | the server's ISteamUGC | as TSteamUGC + server badge |
| `TSteamGameServerInventory` | the server's ISteamInventory | as TSteamInventory + server badge |

For the seven copies, either supply seven `.ico` files or one **server
badge** (a small rack in a corner, as a transparent `.ico` or PNG at the
same sizes). With a badge, the seven icons are composited from the client
icons in the repository.

`ISteamController` (superseded by ISteamInput) has no component and will
not get one.

## Delivering them

Put the `.ico` files in a zip (any folder layout) and attach it to a
session; they are converted and packaged there. Where they will live in the
repository is decided then.
