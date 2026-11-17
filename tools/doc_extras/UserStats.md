## Overview

Stats, achievements and leaderboards. Since SDK 1.61 Steam loads the current
user's stats and achievements by itself at start-up - there is no
`RequestCurrentStats` any more; reading works as soon as Steam is running.

### Achievements

```pascal
var
  Stats: TSteamUserStatsPlugin;
  Done: Boolean;
begin
  Stats := SteamUserStats1.Plugin;              // or Steam.FindPlugin(...)
  if (Stats <> nil) and Stats.GetAchievement('ACH_WIN_ONE_GAME', Done) and not Done then
  begin
    Stats.SetAchievement('ACH_WIN_ONE_GAME');   // changes the local copy only
    Stats.StoreStats;                           // uploads; Steam shows the pop-up
  end;
end;
```

* `SetAchievement` / `SetStatInt32` / `SetStatFloat` change the **local**
  copy; nothing reaches Steam until `StoreStats`. Call `StoreStats` after a
  batch of changes (end of a level), not after every change - Steam
  rate-limits it.
* `StoreStats` completes with `OnUserStatsStored` (`m_eResult = k_EResultOK`
  on success); each unlocked achievement also raises
  `OnUserAchievementStored`.
* Progress pop-ups: `IndicateAchievementProgress(Name, Current, Max)`.
* Names, descriptions, hidden flag: `GetAchievementDisplayAttribute(Name,
  'name' | 'desc' | 'hidden')`. Iterate with `GetNumAchievements` /
  `GetAchievementName(I)`.
* Unlock times are Unix seconds (UTC): `GetAchievementAndUnlockTime`, then
  `SteamTimeToLocal` (Steamworks.Types) - see the README.
* `ClearAchievement` and `ResetAllStats` are for testing.

### Achievement icons

`GetAchievementIcon(Name)` returns an image handle. **0** means "not loaded
yet" (Steam fetches it and raises `OnUserAchievementIconFetched` with the
real handle) **or** "this achievement has no icon" (the event then also says
0). Turn a handle into a bitmap with `SteamImageToBitmap` (Steamworks.FMX /
.VCL / .LCL) or `TSteamUtilsPlugin.GetImageRGBABytes`. After changing icons
on the partner site: publish, then restart the Steam client (it caches
them).

### Leaderboards

All leaderboard calls are asynchronous. Either handle the component events
(`OnLeaderboardFindResult`, `OnLeaderboardScoreUploaded`,
`OnLeaderboardScoresDownloaded`) or pass a handler to the `...Async` method:

```pascal
procedure TGame.SubmitScore(AScore: Integer);
begin
  FPendingScore := AScore;
  Stats.FindLeaderboardAsync('Highscores', BoardFound);
end;

procedure TGame.BoardFound(const AData: TSteamCallbackData; AIOFailure: Boolean);
var
  R: LeaderboardFindResult_t;
begin
  if AIOFailure or not AData.CopyTo(R, SizeOf(R)) or (R.m_bLeaderboardFound = 0) then
    Exit;
  Stats.UploadLeaderboardScoreAsync(R.m_hSteamLeaderboard,
    k_ELeaderboardUploadScoreMethodKeepBest, FPendingScore, nil, 0, ScoreUploaded);
end;

procedure TGame.ScoreUploaded(const AData: TSteamCallbackData; AIOFailure: Boolean);
var
  R: LeaderboardScoreUploaded_t;
begin
  if (not AIOFailure) and AData.CopyTo(R, SizeOf(R)) and (R.m_bSuccess <> 0) then
    ShowRank(R.m_nGlobalRankNew);
end;
```

Downloaded entries (`DownloadLeaderboardEntriesAsync`, then
`GetDownloadedLeaderboardEntry` for each index) stay valid only until the next
download of that board.

### Other users and global data

`RequestUserStats(SteamID)` (event `OnUserStatsReceived`) loads another
user's stats for `GetUserStatInt32` / `GetUserAchievement`;
`RequestGlobalAchievementPercentages` and `RequestGlobalStats` load global
data. `GetNumberOfCurrentPlayers` works without any setup.
