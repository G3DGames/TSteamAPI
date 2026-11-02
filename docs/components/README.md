# Components and plug-ins

Every Steam interface is one unit in `lib/plugins/`, holding two classes:

* the **plug-in** (`TSteamFriendsPlugin`): the interface's methods, usable
  from any code, any framework, Delphi or FPC;
* the **component** (`TSteamFriends`): drop it on a form (Delphi) or create
  it in code; its published events are the interface's callbacks, typed
  with the SDK's records, and `Plugin` gives the methods.

The root component, `TSteamAPI`, runs Steam itself; the plug-in components
link to it.

| Page | Interface | Typical use |
|------|-----------|-------------|
| [TSteamAPI](TSteamAPI.md) | (the core) | Start / stop Steam, AppID, update mode, logging - **start here** |
| [TSteamUtils](TSteamUtils.md) | ISteamUtils | Steam language, server time, overlay state, images, gamepad text input |
| [TSteamUser](TSteamUser.md) | ISteamUser | SteamID, logon state, Steam level, auth tickets |
| [TSteamFriends](TSteamFriends.md) | ISteamFriends | Persona, friends, avatars, overlay dialogs, rich presence |
| [TSteamApps](TSteamApps.md) | ISteamApps | Ownership, DLC, game language, launch parameters, betas |
| [TSteamUserStats](TSteamUserStats.md) | ISteamUserStats | Stats, achievements (and icons), leaderboards |
| [TSteamRemoteStorage](TSteamRemoteStorage.md) | ISteamRemoteStorage | Steam Cloud saves (files synced across machines) |
| [TSteamScreenshots](TSteamScreenshots.md) | ISteamScreenshots | Taking, supplying and tagging screenshots |
| [TSteamTimeline](TSteamTimeline.md) | ISteamTimeline | Game recording: events, game phases, game mode |
| [TSteamUGC](TSteamUGC.md) | ISteamUGC | Workshop: query, create, update, subscribe, install |
| [TSteamInput](TSteamInput.md) | ISteamInput | Controllers: action sets, digital / analog / motion data, rumble |
| [TSteamMatchmaking](TSteamMatchmaking.md) | ISteamMatchmaking | Lobbies: find, create, join, chat, lobby data; favourite servers |
| [TSteamParties](TSteamParties.md) | ISteamParties | Party beacons: open slots others can join |
| [TSteamMusic](TSteamMusic.md) | ISteamMusic | The Steam music player: state, play / pause, volume |
| [TSteamHTTP](TSteamHTTP.md) | ISteamHTTP | HTTP requests through the Steam client |
| [TSteamHTMLSurface](TSteamHTMLSurface.md) | ISteamHTMLSurface | Off-screen web browser rendered into the game |
| [TSteamInventory](TSteamInventory.md) | ISteamInventory | Steam Inventory items: list, drop, consume, purchase |
| [TSteamVideo](TSteamVideo.md) | ISteamVideo | Broadcasting state; video-app URLs |
| [TSteamParentalSettings](TSteamParentalSettings.md) | ISteamParentalSettings | Family View: blocked features and apps |
| [TSteamRemotePlay](TSteamRemotePlay.md) | ISteamRemotePlay | Remote Play sessions, Remote Play Together |
| [TSteamNetworking](TSteamNetworking.md) | ISteamNetworking | Old P2P packets by SteamID (deprecated by Valve) |
| [TSteamNetworkingSockets](TSteamNetworkingSockets.md) | ISteamNetworkingSockets | Connections: by IP or P2P over the relay network |
| [TSteamNetworkingMessages](TSteamNetworkingMessages.md) | ISteamNetworkingMessages | P2P messages to a Steam user, no connection to manage |
| [TSteamNetworkingUtils](TSteamNetworkingUtils.md) | ISteamNetworkingUtils | Relay network status, ping locations, clock, settings |

Still to come: the server browser
(MatchmakingServers), later the game-server API. ISteamController is not
bound (deprecated by Valve; use TSteamInput).

## How these pages are made

The interface pages (`TSteamUtils.md`, `TSteamUGC.md`, ...) are
**generated** from the generated units by `tools/gen_docs.py` - every
method, property, event and payload record is listed, with Valve's SDK
comments. The overview text at the top of each page comes from
`tools/doc_extras/<Name>.md`. Edit those, or the script, then run

```
python3 tools/gen_docs.py
```

`TSteamAPI.md` and this page are written by hand.

The same declarations also carry PasDoc comments, for the HTML / CHM API
reference built with PasDoc.

## Common to every plug-in component

* **Linking.** `SteamAPI` names the root; at run time a component whose
  owner has exactly one `TSteamAPI` links itself.
* **Events** are live (`Attached`) while Steam runs and removed when it
  stops. They run where the root's `UpdateMode` / `Delivery` put them - the
  main thread by default.
* **Payload check.** Before raising an event the component compares Steam's
  payload size with the Pascal record's; a mismatch raises
  `ESteamworksError` - a layout bug never passes silently.
* **Call results** (replies to async calls) whose struct matches an event
  raise that event too, unless an `...Async` call registered its own
  handler for that call. Failed call results raise no event; they are
  logged as warnings.
* **Missing exports.** Every export is bound as optional. A method whose
  export the loaded Steam library lacks raises `ESteamworksError` naming
  it; the exports missing at start-up are logged once.
* **Raw access.** `Plugin.Flat` holds every export with its exact C
  signature (first argument `Plugin.Handle`) for anything the methods do
  not cover.
