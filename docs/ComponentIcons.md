# Component icons

Palette icons for TSteamAPI and every plug-in component - 34 in all:
TSteamAPI, 24 client components and 9 game-server components.

Status: **done** (2026-11-05). They appear on the "Steamworks" palette page
once the design-time packages are rebuilt and reinstalled (Delphi:
dclSteamworks, dclSteamworksFMX, dclSteamworksVCL; Lazarus:
SteamworksLCL.lpk).

## Where they live

| Path | What |
|---|---|
| `design/icons/<Class>.ico` | The source: one `.ico` per class, 32-bit with alpha, 16, 24, 32, 36, 48, 64 and 256 px. |
| `design/icons/ServerBadge.ico` | The server badge alone (transparent), for anyone drawing a new server icon by hand. |
| `design/icons/svg/<Class>.svg` | What the `.ico` files are rendered from. |
| `design/Steamworks.Reg.dcr` | Delphi: the 33 plug-in components, linked by `design/Steamworks.Reg.pas` (dclSteamworks). |
| `fmx/Steamworks.FMX.Reg.dcr` | Delphi: the FMX TSteamAPI, linked by `fmx/Steamworks.FMX.Reg.pas` (dclSteamworksFMX). |
| `vcl/Steamworks.VCL.Reg.dcr` | Delphi: the VCL TSteamAPI, linked by `vcl/Steamworks.VCL.Reg.pas` (dclSteamworksVCL). |
| `lcl/Steamworks.LCL.Reg.res` | Lazarus: all 34, linked by `lcl/Steamworks.LCL.Reg.pas` (SteamworksLCL.lpk). |

Each registration unit links its file with `{$R ...}`; Delphi and FPC both
look for it next to the unit, so the packages need no extra paths. Only the
design-time code links them: the runtime packages and your programs carry no
icons.

## How each IDE finds them

* **Delphi**: a BITMAP resource named after the class in capitals -
  `TSTEAMFRIENDS` (24 px), `TSTEAMFRIENDS16` and `TSTEAMFRIENDS32` - the three
  sizes the palette uses at its DPI scales. The bitmaps are 32-bit with alpha.
  Their transparent pixels are magenta with alpha 0 and the bottom-left pixel
  is always one of them, so an IDE that ignores alpha still finds the
  transparent colour in the bottom-left corner, where Delphi looks for it.
* **Lazarus**: an RCDATA PNG named after the class - `TSTEAMFRIENDS` (24 px),
  `TSTEAMFRIENDS_150` (36 px) and `TSTEAMFRIENDS_200` (48 px). These are the
  names the palette asks for (`ide/componentpalette.pas`, `IDEImagesIntf`) and
  the layout of Lazarus' own component icons (e.g. the customdrawn package's
  `paletteimg.res`).

## Rebuilding them

* **After adding a plug-in or a server copy** to `tools/gen_steam_api.py`:
  draw its icon (below), then `python3 tools/gen_icon_res.py`. The generator
  also packages the icons at the end of every run and reports a component
  without an icon as a NOTE; `gen_icon_res.py` on its own stops with the list
  of missing icons or sizes.
* **Packaging only** (`python3 tools/gen_icon_res.py`) needs nothing but
  Python. It rewrites a file only when its bytes change.
* **Redrawing** (`python3 tools/gen_icons.py [--preview sheet.png]`) needs
  Pillow and rsvg-convert. Each symbol is a few lines of SVG in `symbols()`;
  a server copy is just an entry in `SERVER_COPIES`. The script stops if its
  list of classes differs from the generator's. `--preview` writes a contact
  sheet of every icon at 16 / 24 / 48 px on a light and a dark palette.
* An `.ico` drawn in any other tool works too, if it has the sizes above and
  its frames are 32-bit bitmaps or 8-bit RGB(A) PNGs.

## Design

* **Shared motif:** a rounded tile in a group colour with one white symbol.
  The tile fills the square, so its edges land on whole pixels at every size.
* **Designed for 16 px first:** every symbol was checked at 16 px and
  simplified where it turned to mush.
* **Group colours:** core (dark navy with a gold frame), system (slate),
  identity (blue), content (orange), play (purple), networking (teal), game
  server (red). The deprecated ISteamNetworking has a greyed teal tile.
* **No Valve logo:** TSteamAPI is a valve handwheel - a generic
  "steam / valve" motif - framed in gold as the hub.
* **Server badge:** a small red rack with a white rim, bottom-right, on every
  game-server component except TSteamGameServer itself (whose symbol is the
  rack).

### Core and client components (25)

| Class | Interface | Symbol |
|---|---|---|
| `TSteamAPI` | (root - the core) | valve handwheel, gold frame |
| `TSteamUtils` | ISteamUtils | gear |
| `TSteamUser` | ISteamUser | single person |
| `TSteamFriends` | ISteamFriends | two people |
| `TSteamApps` | ISteamApps | app tiles |
| `TSteamUserStats` | ISteamUserStats | trophy |
| `TSteamRemoteStorage` | ISteamRemoteStorage | cloud with an up arrow |
| `TSteamScreenshots` | ISteamScreenshots | camera |
| `TSteamTimeline` | ISteamTimeline | track with markers and a playhead |
| `TSteamUGC` | ISteamUGC | puzzle piece |
| `TSteamInput` | ISteamInput | gamepad |
| `TSteamMatchmaking` | ISteamMatchmaking | two speech bubbles (lobby chat) |
| `TSteamMatchmakingServers` | ISteamMatchmakingServers | list + magnifier |
| `TSteamParties` | ISteamParties | flag |
| `TSteamMusic` | ISteamMusic | music notes |
| `TSteamHTTP` | ISteamHTTP | globe |
| `TSteamHTMLSurface` | ISteamHTMLSurface | browser window |
| `TSteamInventory` | ISteamInventory | chest |
| `TSteamVideo` | ISteamVideo | video camera with a play mark |
| `TSteamParentalSettings` | ISteamParentalSettings | shield with a keyhole |
| `TSteamRemotePlay` | ISteamRemotePlay | screen + signal |
| `TSteamNetworking` | ISteamNetworking (old P2P, deprecated by Valve) | two linked dots, greyed tile |
| `TSteamNetworkingSockets` | ISteamNetworkingSockets | plug |
| `TSteamNetworkingMessages` | ISteamNetworkingMessages | envelope |
| `TSteamNetworkingUtils` | ISteamNetworkingUtils | signal bars (relay network, ping) |

### Game-server components (9)

| Class | Interface | Symbol |
|---|---|---|
| `TSteamGameServer` | ISteamGameServer | server rack, red tile |
| `TSteamGameServerStats` | ISteamGameServerStats | trophy + server badge |
| `TSteamGameServerUtils` | the server's ISteamUtils | as TSteamUtils + server badge |
| `TSteamGameServerNetworking` | the server's ISteamNetworking | as TSteamNetworking + server badge |
| `TSteamGameServerNetworkingSockets` | the server's ISteamNetworkingSockets | as TSteamNetworkingSockets + server badge |
| `TSteamGameServerNetworkingMessages` | the server's ISteamNetworkingMessages | as TSteamNetworkingMessages + server badge |
| `TSteamGameServerHTTP` | the server's ISteamHTTP | as TSteamHTTP + server badge |
| `TSteamGameServerUGC` | the server's ISteamUGC | as TSteamUGC + server badge |
| `TSteamGameServerInventory` | the server's ISteamInventory | as TSteamInventory + server badge |

Where these differ from the original brief's suggestions: NetworkingUtils
(network + wrench) - two symbols do not survive 16 px; Matchmaking (lobby /
group joining) - "two people" is already TSteamFriends; MatchmakingServers
(server list) - a plain list looked like the TSteamGameServer rack; Video
(film / play) - film sprockets turned to noise at 16 px.

`ISteamController` (superseded by ISteamInput) has no component and no icon.

## Licence

Drawn for this project (tools/gen_icons.py); no third-party artwork. MIT,
like the rest of the repository.
