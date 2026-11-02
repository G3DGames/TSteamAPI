## Overview

Steam Broadcasting and video apps: whether the user is broadcasting the
game, and the stream URL / 360-video (OPF) settings of a video app.

```pascal
var
  Viewers: Integer;
begin
  if SteamVideo1.Plugin.IsBroadcasting(Viewers) then
    Log(Format('broadcasting to %d viewers', [Viewers]));
end;
```

* `OnBroadcastUploadStart` / `OnBroadcastUploadStop` report a broadcast
  starting or ending.
* `GetVideoURL` -> `OnGetVideoURLResult`, `GetOPFSettings` ->
  `OnGetOPFSettingsResult` (then `GetOPFStringForApp`, raw buffer) are for
  video apps; a game gets an error result.
