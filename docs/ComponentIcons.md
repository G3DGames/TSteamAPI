# Component icons - brief

Palette icons for TSteamAPI and every plug-in component. Icons are
supplied as source images; packaging them for each IDE (Delphi `.dcr` /
`.res`, Lazarus PNG resources in the `.lpk`) is done in the repository, and
the generator (`tools/gen_steam_api.py`) will attach each new plug-in's icon
automatically.

Status: **to do later** (owner, 2026-10-30 - "no point until we're
finished"). 11 needed now, 15 more planned.

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

## Needed now (current components)

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

## Planned

Roughly the order they will be generated. The names follow the
generator's `TSteam<Interface>` pattern; a few may change when they are
generated - this file is updated if so.

| Class | Interface | Suggested symbol |
|---|---|---|
| `TSteamHTTP` | ISteamHTTP | globe |
| `TSteamInventory` | ISteamInventory | backpack / chest |
| `TSteamMatchmaking` | ISteamMatchmaking | lobby / group joining |
| `TSteamMatchmakingServers` | ISteamMatchmakingServers | server list |
| `TSteamNetworkingSockets` | ISteamNetworkingSockets | plug / socket |
| `TSteamNetworkingMessages` | ISteamNetworkingMessages | envelope |
| `TSteamNetworkingUtils` | ISteamNetworkingUtils | network + wrench |
| `TSteamParties` | ISteamParties | party / group flag |
| `TSteamRemotePlay` | ISteamRemotePlay | screen + signal |
| `TSteamHTMLSurface` | ISteamHTMLSurface | browser window |
| `TSteamVideo` | ISteamVideo | film / play |
| `TSteamMusic` | ISteamMusic | music note |
| `TSteamParentalSettings` | ISteamParentalSettings | shield / lock |
| `TSteamGameServer` | ISteamGameServer | server rack |
| `TSteamGameServerStats` | ISteamGameServerStats | server + trophy |

`ISteamController` and `ISteamNetworking` are superseded by Input and
NetworkingSockets and will probably get no component - skip them unless
this changes.

## Delivering them

Put the `.ico` files in a zip (any folder layout) and attach it to a
session; they are converted and packaged there. Where they will live in the
repository is decided then.
