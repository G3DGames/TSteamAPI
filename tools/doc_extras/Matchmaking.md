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
