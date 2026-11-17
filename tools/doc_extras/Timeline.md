## Overview

Steam game recording: markers on the timeline the user sees when Steam
records gameplay in the background or the user saves a clip. Everything
here is a hint; calls are cheap and safe when recording is off.

### Game mode, events and phases

```pascal
var
  T: TSteamTimelinePlugin;
  Boss: TimelineEventHandle_t;
begin
  T := SteamTimeline1.Plugin;

  T.SetTimelineGameMode(k_ETimelineGameMode_Playing);   // Menus, LoadingScreen, Staging ...

  // a moment: title, description, icon, priority, offset (s), clip priority
  T.AddInstantaneousTimelineEvent('Level up', 'Reached level 10', 'steam_starburst',
    0, 0, k_ETimelineEventClipPriority_Standard);

  // a span: start now, end when the fight is over
  Boss := T.StartRangeTimelineEvent('Boss fight', 'The Warden', 'steam_flag',
    0, 0, k_ETimelineEventClipPriority_Featured);
  ...
  T.EndRangeTimelineEvent(Boss, 0);

  // a phase: one match / chapter / run, with tags and attributes
  T.StartGamePhase;
  T.SetGamePhaseID(MatchId);
  T.AddGamePhaseTag('Victory', 'steam_heart', 'Result', 100);
  T.SetGamePhaseAttribute('Score', '12 / 3', 50);
  T.EndGamePhase;
end;
```

* Icons are your own timeline icons (uploaded on the partner site) or
  Steam's built-in `steam_...` ones (the header's examples use `steam_heart`,
  `steam_flag`, `steam_starburst`; the partner documentation lists the
  rest). Text should be in the language `GetSteamUILanguage` (TSteamUtils)
  returns.
* Time offsets are seconds relative to now; negative values mark something
  that already happened.
* `SetTimelineTooltip` describes the current state (shown for the stretch
  of timeline until it changes); `ClearTimelineTooltip` removes it.
* `DoesEventRecordingExist` / `DoesGamePhaseRecordingExist` answer through
  `OnSteamTimelineEventRecordingExists` /
  `OnSteamTimelineGamePhaseRecordingExists` (or their `...Async` handler);
  if a recording exists, `OpenOverlayToTimelineEvent` /
  `OpenOverlayToGamePhase` show it.
