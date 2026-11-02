## Overview

Steam Remote Play: the game streamed to another device, and Remote Play
Together (friends joining a local multiplayer game over the internet).

```pascal
var
  I: Integer;
  S: RemotePlaySessionID_t;
begin
  for I := 0 to Integer(SteamRemotePlay1.Plugin.GetSessionCount) - 1 do
  begin
    S := SteamRemotePlay1.Plugin.GetSessionID(I);
    Log(Format('%s on "%s"', [SteamRemotePlay1.Plugin.GetSessionSteamID(S).ToString,
      SteamRemotePlay1.Plugin.GetSessionClientName(S)]));
  end;
end;
```

* `OnSteamRemotePlaySessionConnected` / `...Disconnected` report sessions;
  `GetSessionClientFormFactor` and `BGetSessionClientResolution` describe
  the device (adapt the UI to a phone or TV).
* `BSendRemotePlayTogetherInvite` invites a friend;
  `ShowRemotePlayTogetherUI` opens Steam's invite UI.
* `GetInput` (mouse / keyboard events of Remote Play Together guests, after
  `BEnableRemotePlayTogetherDirectInput`) fills a raw array of
  `RemotePlayInput_t` - a C union not yet declared in Pascal, so the
  parameter is a plain `Pointer` for now; `CreateMouseCursor` takes a raw
  pixel buffer.
