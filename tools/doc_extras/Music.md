## Overview

The Steam music player (the user's soundtracks): read its state and
control it from the game.

```pascal
with SteamMusic1.Plugin do
  if BIsEnabled then
  begin
    Log(Format('playing %s, volume %.2f', [BoolToStr(BIsPlaying, True), GetVolume]));
    SetVolume(0.5);
    Pause;
  end;
```

* `Play`, `Pause`, `PlayPrevious`, `PlayNext`, `SetVolume` (0.0 - 1.0).
* `OnPlaybackStatusHasChanged` and `OnVolumeHasChanged` report changes
  made in Steam.
* The player belongs to the user: change it only when the user asks.
