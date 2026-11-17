## Overview

The logged-on user: SteamID, logon state, Steam level, authentication
tickets, encrypted app tickets, voice and store / market helpers.

### Who is playing

```pascal
var
  U: TSteamUserPlugin;
begin
  U := SteamUser1.Plugin;
  if U.BLoggedOn then
    Log(Format('SteamID %s, level %d', [U.GetSteamID.ToString, U.GetPlayerSteamLevel]));
end;
```

`BLoggedOn` is `False` while Steam runs offline; most other interfaces then
still work from cached data. `OnSteamServersDisconnected` /
`OnSteamServersConnected` report changes.

### Authentication

* **Web API backend:** `GetAuthTicketForWebApi('your-identity')` -
  the ticket arrives in `OnGetTicketForWebApiResponse`; send it to your
  server, which validates it with Valve's Web API
  (`ISteamUserAuth/AuthenticateUserTicket`).
* **Peer / game server:** `GetAuthSessionTicket` (fills a buffer you pass;
  `OnGetAuthSessionTicketResponse` confirms), the other side calls
  `BeginAuthSession`; both end with `EndAuthSession` / `CancelAuthTicket`.
  The receiver gets `OnValidateAuthTicketResponse`.
* **Encrypted app tickets:** `RequestEncryptedAppTicketAsync`, then
  `GetEncryptedAppTicket` in the handler.

Tickets are binary buffers: these methods take `Pointer` + size, exactly as
in the SDK.

### Other

`GetUserDataFolder` (a buffer method) gives Steam's per-user folder for this
game - prefer Steam Cloud (ISteamRemoteStorage, a later plug-in) for saves.
Voice: `StartVoiceRecording`, `GetAvailableVoice`, `GetVoice`,
`DecompressVoice`, `StopVoiceRecording`.
