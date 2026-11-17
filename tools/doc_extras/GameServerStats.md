## Overview

Stats and achievements of the players on a game server
(`ISteamGameServerStats`): the server reads and writes the stats Valve
marks as "set by GS" on the partner site. A game-server component - it
attaches when the game server starts (see TSteamGameServer).

```pascal
// a player joined (authenticated): load his stats
SteamGameServerStats1.Plugin.RequestUserStats(PlayerID);   // -> OnGSStatsReceived

procedure TForm1.SteamGameServerStats1GSStatsReceived(Sender: TObject;
  const AData: GSStatsReceived_t);
var
  Kills: Int32;
begin
  if (AData.m_eResult = k_EResultOK) and
     SteamGameServerStats1.Plugin.GetUserStatInt32(AData.m_steamIDUser, 'kills', Kills) then
    ...
end;
```

`StoreUserStats` sends the changes (`OnGSStatsStored`);
`OnGSStatsUnloaded` comes when Steam drops a player's stats after he
left.
