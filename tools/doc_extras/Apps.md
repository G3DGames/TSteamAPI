## Overview

Ownership and installation of this game, its DLC and betas, language,
launch parameters and build id.

### Ownership and DLC

```pascal
var
  A: TSteamAppsPlugin;
begin
  A := SteamApps1.Plugin;
  if not A.BIsSubscribed then
    Exit;                                  // not owned (should not happen through Steam)
  if A.BIsDlcInstalled(1234560) then       // your DLC's AppID
    EnableExpansion;
end;
```

* `BIsDlcInstalled(AppID)` is the check to use in game; it is `True` only
  when the DLC is owned **and** installed. `OnDlcInstalled` fires when a DLC
  finishes installing while the game runs.
* `GetDLCCount` / `BGetDLCDataByIndex` list the DLC (the name comes back in
  a buffer you pass).
* `BIsSubscribedFromFamilySharing`, `BIsSubscribedFromFreeWeekend`,
  `BIsTimedTrial` refine how the game is owned.

### Language

`GetCurrentGameLanguage` is the language the user chose for **this game**
in Steam (e.g. `english`, `german`, `schinese`) - use it for your text.
`TSteamUtilsPlugin.GetSteamUILanguage` is the Steam client's own language.
`GetAvailableGameLanguages` lists the languages the game supports.

### Launch parameters

`GetLaunchQueryParam(Key)` reads `steam://run/<appid>//?key=value` style
parameters; `GetLaunchCommandLine` (buffer) the command line passed through
Steam. `OnNewUrlLaunchParameters` fires when the game is "launched" again
while already running.

### Install, build, betas

`GetAppInstallDir` (buffer), `GetAppBuildId`, `GetCurrentBetaName` (buffer),
`GetNumBetas` / `GetBetaInfo` / `SetActiveBeta`, `MarkContentCorrupt` (asks
Steam to verify the files on next launch).
