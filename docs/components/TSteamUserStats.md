# TSteamUserStats and TSteamUserStatsPlugin (ISteamUserStats)

> **Generated** by `tools/gen_docs.py` from `lib/plugins/Steamworks.Plugin.UserStats.pas` - do not edit.
> Hand-written text: `tools/doc_extras/UserStats.md`. Steam's own descriptions are Valve's
> SDK comments, as in the generated units.

Unit: `Steamworks.Plugin.UserStats` - linking it (a `uses` entry, or dropping a `TSteamUserStats`) enables the
plug-in. Steam interface: `ISteamUserStats` (SDK 1.65).

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

## Contents

* [The component: TSteamUserStats](#the-component-tsteamuserstats)
  * [Events (12)](#events)
* [The plug-in: TSteamUserStatsPlugin](#the-plug-in-tsteamuserstatsplugin)
  * [Methods](#methods)
  * [Async methods](#async-methods)
  * [Properties](#properties)
* [Payload records](#payload-records)

## The component: TSteamUserStats

ISteamUserStats component: drop it next to a TSteamAPI (linked automatically at run time when the owner has exactly one, otherwise set SteamAPI). Its events are the ISteamUserStats callbacks; call the interface through `Plugin`.

| Member | Kind | Description |
|--------|------|-------------|
| `SteamAPI` | published property | The `TSteamAPI` this component belongs to. At run time a component whose owner has exactly one `TSteamAPI` links itself. |
| `Plugin` | public property | The `TSteamUserStatsPlugin` for calls; `nil` while Steam is not running. |
| `Attached` | public property | `True` while the events are subscribed (Steam running, `SteamAPI` set). |
| `Attach` / `Detach` | public methods | Subscribe / remove the events by hand (normally automatic). |

Events run on the thread chosen by the root's `UpdateMode` / `Delivery` - the main
thread by default (see [GameEngineIntegration.md](../GameEngineIntegration.md)). Each event
checks that Steam's payload size equals the Pascal record's; a mismatch raises
`ESteamworksError` instead of handing over a wrong record. Call results of the same
struct reach the event too (unless an `...Async` call claimed them); failed call results
raise no event and are logged as warnings.

### Events

| Event | Callback | Payload | Description |
|-------|----------|---------|-------------|
| `OnUserStatsReceived` | 1101 | [`UserStatsReceived_t`](#userstatsreceived_t) | called when the latests stats and achievements have been received from the server. |
| `OnUserStatsStored` | 1102 | [`UserStatsStored_t`](#userstatsstored_t) | result of a request to store the user stats for a game. |
| `OnUserAchievementStored` | 1103 | [`UserAchievementStored_t`](#userachievementstored_t) | result of a request to store the achievements for a game, or an "indicate progress" call. If both m_nCurProgress and m_nMaxProgress are zero, that means the achievement has been fully unlocked. |
| `OnLeaderboardFindResult` | 1104 | [`LeaderboardFindResult_t`](#leaderboardfindresult_t) | call result for finding a leaderboard, returned as a result of FindOrCreateLeaderboard() or FindLeaderboard() use CCallResult<> to map this async result to a member function. |
| `OnLeaderboardScoresDownloaded` | 1105 | [`LeaderboardScoresDownloaded_t`](#leaderboardscoresdownloaded_t) | call result indicating scores for a leaderboard have been downloaded and are ready to be retrieved, returned as a result of DownloadLeaderboardEntries() use CCallResult<> to map this async result to a member function. |
| `OnLeaderboardScoreUploaded` | 1106 | [`LeaderboardScoreUploaded_t`](#leaderboardscoreuploaded_t) | call result indicating scores has been uploaded, returned as a result of UploadLeaderboardScore() use CCallResult<> to map this async result to a member function. |
| `OnNumberOfCurrentPlayers` | 1107 | [`NumberOfCurrentPlayers_t`](#numberofcurrentplayers_t) | see the SDK. |
| `OnUserStatsUnloaded` | 1108 | [`UserStatsUnloaded_t`](#userstatsunloaded_t) | Callback indicating that a user's stats have been unloaded. Call RequestUserStats again to access stats for this user. |
| `OnUserAchievementIconFetched` | 1109 | [`UserAchievementIconFetched_t`](#userachievementiconfetched_t) | Callback indicating that an achievement icon has been fetched. |
| `OnGlobalAchievementPercentagesReady` | 1110 | [`GlobalAchievementPercentagesReady_t`](#globalachievementpercentagesready_t) | Callback indicating that global achievement percentages are fetched. |
| `OnLeaderboardUGCSet` | 1111 | [`LeaderboardUGCSet_t`](#leaderboardugcset_t) | call result indicating UGC has been uploaded, returned as a result of SetLeaderboardUGC(). |
| `OnGlobalStatsReceived` | 1112 | [`GlobalStatsReceived_t`](#globalstatsreceived_t) | callback indicating global stats have been received. Returned as a result of RequestGlobalStats(). |

Handler signature (the IDE generates it when you double-click the event):

```pascal
procedure TForm1.SteamUserStats1UserStatsReceived(Sender: TObject; const AData: UserStatsReceived_t);
```

## The plug-in: TSteamUserStatsPlugin

ISteamUserStats plug-in. Registered by linking the unit; find it with @code(Steam.FindPlugin(TSteamUserStatsPlugin)).

Reach it through the component (`SteamUserStats1.Plugin`) or the core:

```pascal
P := TSteamUserStatsPlugin(Steam.FindPlugin(TSteamUserStatsPlugin));   // Delphi also: Steam.Plugin<TSteamUserStatsPlugin>
if P <> nil then ...
```

Every flat export is bound as optional: calling a method whose export the loaded
Steam library lacks raises `ESteamworksError` naming the export (`Assigned(P.Flat.Xxx)`
tells beforehand). Method names follow Valve's flat API (`GetStatInt32`, not the C++
overload `GetStat`); `const char*` parameters are `string`, 64-bit Steam ids `TSteamID`,
single out-values `var`; buffers and NULL-able pointers stay `Pointer`.

### Methods

| Method | Summary |
|--------|---------|
| [`GetStatInt32`](#getstatint32) | Data accessors. |
| [`GetStatFloat`](#getstatfloat) | Data accessors. |
| [`SetStatInt32`](#setstatint32) | Set / update data. |
| [`SetStatFloat`](#setstatfloat) | Set / update data. |
| [`UpdateAvgRateStat`](#updateavgratestat) | Wraps `SteamAPI_ISteamUserStats_UpdateAvgRateStat`. |
| [`GetAchievement`](#getachievement) | Achievement flag accessors. |
| [`SetAchievement`](#setachievement) | Wraps `SteamAPI_ISteamUserStats_SetAchievement`. |
| [`ClearAchievement`](#clearachievement) | Wraps `SteamAPI_ISteamUserStats_ClearAchievement`. |
| [`GetAchievementAndUnlockTime`](#getachievementandunlocktime) | Get the achievement status, and the time it was unlocked if unlocked. If the return value is true, but the unlock time is zero, that means it was unlocked ... |
| [`StoreStats`](#storestats) | Store the current data on the server, will get a callback when set And one callback for every new achievement If the callback has a result of ... |
| [`GetAchievementIcon`](#getachievementicon) | Gets the icon of the achievement, which is a handle to be used in ISteamUtils::GetImageRGBA(), or 0 if none set. A return value of 0 may indicate we are ... |
| [`GetAchievementDisplayAttribute`](#getachievementdisplayattribute) | Get general attributes for an achievement. Accepts the following keys: - "name" and "desc" for retrieving the localized achievement name and description ... |
| [`IndicateAchievementProgress`](#indicateachievementprogress) | Achievement progress - triggers an AchievementProgress callback, that is all. Calling this w/ N out of N progress will NOT set the achievement, the game ... |
| [`GetNumAchievements`](#getnumachievements) | Used for iterating achievements. In general games should not need these functions because they should have a list of existing achievements compiled into them. |
| [`GetAchievementName`](#getachievementname) | Get achievement name iAchievement in [0,GetNumAchievements). |
| [`RequestUserStats`](#requestuserstats) | downloads stats for the user returns a UserStatsReceived_t received when completed if the other user has no stats, UserStatsReceived_t.m_eResult will be set ... |
| [`GetUserStatInt32`](#getuserstatint32) | requests stat information for a user, usable after a successful call to RequestUserStats(). |
| [`GetUserStatFloat`](#getuserstatfloat) | requests stat information for a user, usable after a successful call to RequestUserStats(). |
| [`GetUserAchievement`](#getuserachievement) | Wraps `SteamAPI_ISteamUserStats_GetUserAchievement`. |
| [`GetUserAchievementAndUnlockTime`](#getuserachievementandunlocktime) | See notes for GetAchievementAndUnlockTime above. |
| [`ResetAllStats`](#resetallstats) | Reset stats. |
| [`FindOrCreateLeaderboard`](#findorcreateleaderboard) | asks the Steam back-end for a leaderboard by name, and will create it if it's not yet This call is asynchronous, with the result returned in ... |
| [`FindLeaderboard`](#findleaderboard) | as above, but won't create the leaderboard if it's not found This call is asynchronous, with the result returned in LeaderboardFindResult_t. Call result: ... |
| [`GetLeaderboardName`](#getleaderboardname) | returns the name of a leaderboard. |
| [`GetLeaderboardEntryCount`](#getleaderboardentrycount) | returns the total number of entries in a leaderboard, as of the last request. |
| [`GetLeaderboardSortMethod`](#getleaderboardsortmethod) | returns the sort method of the leaderboard. |
| [`GetLeaderboardDisplayType`](#getleaderboarddisplaytype) | returns the display type of the leaderboard. |
| [`DownloadLeaderboardEntries`](#downloadleaderboardentries) | Asks the Steam back-end for a set of rows in the leaderboard. This call is asynchronous, with the result returned in LeaderboardScoresDownloaded_t ... |
| [`DownloadLeaderboardEntriesForUsers`](#downloadleaderboardentriesforusers) | as above, but downloads leaderboard entries for an arbitrary set of users - ELeaderboardDataRequest is k_ELeaderboardDataRequestUsers if a user doesn't have ... |
| [`GetDownloadedLeaderboardEntry`](#getdownloadedleaderboardentry) | Returns data about a single leaderboard entry use a for loop from 0 to LeaderboardScoresDownloaded_t::m_cEntryCount to get all the downloaded entries e.g. ... |
| [`UploadLeaderboardScore`](#uploadleaderboardscore) | Uploads a user score to the Steam back-end. This call is asynchronous, with the result returned in LeaderboardScoreUploaded_t Details are extra game-defined ... |
| [`AttachLeaderboardUGC`](#attachleaderboardugc) | Attaches a piece of user generated content the user's entry on a leaderboard. hContent is a handle to a piece of user generated content that was shared ... |
| [`GetNumberOfCurrentPlayers`](#getnumberofcurrentplayers) | Retrieves the number of players currently playing your game (online + offline) This call is asynchronous, with the result returned in ... |
| [`RequestGlobalAchievementPercentages`](#requestglobalachievementpercentages) | Requests that Steam fetch data on the percentage of players who have received each achievement for the game globally. This call is asynchronous, with the ... |
| [`GetMostAchievedAchievementInfo`](#getmostachievedachievementinfo) | Get the info on the most achieved achievement for the game, returns an iterator index you can use to fetch the next most achieved afterwards. Will return -1 ... |
| [`GetNextMostAchievedAchievementInfo`](#getnextmostachievedachievementinfo) | Get the info on the next most achieved achievement for the game. Call this after GetMostAchievedAchievementInfo or another ... |
| [`GetAchievementAchievedPercent`](#getachievementachievedpercent) | Returns the percentage of users who have achieved the specified achievement. |
| [`RequestGlobalStats`](#requestglobalstats) | Requests global stats data, which is available for stats marked as "aggregated". This call is asynchronous, with the results returned in ... |
| [`GetGlobalStatInt64`](#getglobalstatint64) | Gets the lifetime totals for an aggregated stat. |
| [`GetGlobalStatDouble`](#getglobalstatdouble) | Gets the lifetime totals for an aggregated stat. |
| [`GetGlobalStatHistoryInt64`](#getglobalstathistoryint64) | Wraps `SteamAPI_ISteamUserStats_GetGlobalStatHistoryInt64`. |
| [`GetGlobalStatHistoryDouble`](#getglobalstathistorydouble) | Wraps `SteamAPI_ISteamUserStats_GetGlobalStatHistoryDouble`. |
| [`GetAchievementProgressLimitsInt32`](#getachievementprogresslimitsint32) | For achievements that have related Progress stats, use this to query what the bounds of that progress are. You may want this info to selectively call ... |
| [`GetAchievementProgressLimitsFloat`](#getachievementprogresslimitsfloat) | For achievements that have related Progress stats, use this to query what the bounds of that progress are. You may want this info to selectively call ... |

#### GetStatInt32

```pascal
function GetStatInt32(const pchName: string; var pData: Int32): Boolean;
```

Data accessors.

#### GetStatFloat

```pascal
function GetStatFloat(const pchName: string; var pData: Single): Boolean;
```

Data accessors.

#### SetStatInt32

```pascal
function SetStatInt32(const pchName: string; nData: Int32): Boolean;
```

Set / update data.

#### SetStatFloat

```pascal
function SetStatFloat(const pchName: string; fData: Single): Boolean;
```

Set / update data.

#### UpdateAvgRateStat

```pascal
function UpdateAvgRateStat(const pchName: string; flCountThisSession: Single; dSessionLength: Double): Boolean;
```

Wraps `SteamAPI_ISteamUserStats_UpdateAvgRateStat`.

#### GetAchievement

```pascal
function GetAchievement(const pchName: string; var pbAchieved: Boolean): Boolean;
```

Achievement flag accessors.

#### SetAchievement

```pascal
function SetAchievement(const pchName: string): Boolean;
```

Wraps `SteamAPI_ISteamUserStats_SetAchievement`.

#### ClearAchievement

```pascal
function ClearAchievement(const pchName: string): Boolean;
```

Wraps `SteamAPI_ISteamUserStats_ClearAchievement`.

#### GetAchievementAndUnlockTime

```pascal
function GetAchievementAndUnlockTime(const pchName: string; var pbAchieved: Boolean; var punUnlockTime: UInt32): Boolean;
```

Get the achievement status, and the time it was unlocked if unlocked. If the return value is true, but the unlock time is zero, that means it was unlocked before Steam began tracking achievement unlock times (December 2009). Time is seconds since January 1, 1970.

#### StoreStats

```pascal
function StoreStats: Boolean;
```

Store the current data on the server, will get a callback when set And one callback for every new achievement If the callback has a result of k_EResultInvalidParam, one or more stats uploaded has been rejected, either because they broke constraints or were out of date. In this case the server sends back updated values. The stats should be re-iterated to keep in sync.

#### GetAchievementIcon

```pascal
function GetAchievementIcon(const pchName: string): Integer;
```

Gets the icon of the achievement, which is a handle to be used in ISteamUtils::GetImageRGBA(), or 0 if none set. A return value of 0 may indicate we are still fetching data, and you can wait for the UserAchievementIconFetched_t callback which will notify you when the bits are ready. If the callback still returns zero, then there is no image set for the specified achievement.

#### GetAchievementDisplayAttribute

```pascal
function GetAchievementDisplayAttribute(const pchName: string; const pchKey: string): string;
```

Get general attributes for an achievement. Accepts the following keys: - "name" and "desc" for retrieving the localized achievement name and description (returned in UTF8) - "hidden" for retrieving if an achievement is hidden (returns "0" when not hidden, "1" when hidden).

#### IndicateAchievementProgress

```pascal
function IndicateAchievementProgress(const pchName: string; nCurProgress: UInt32; nMaxProgress: UInt32): Boolean;
```

Achievement progress - triggers an AchievementProgress callback, that is all. Calling this w/ N out of N progress will NOT set the achievement, the game must still do that.

#### GetNumAchievements

```pascal
function GetNumAchievements: UInt32;
```

Used for iterating achievements. In general games should not need these functions because they should have a list of existing achievements compiled into them.

#### GetAchievementName

```pascal
function GetAchievementName(iAchievement: UInt32): string;
```

Get achievement name iAchievement in [0,GetNumAchievements).

#### RequestUserStats

```pascal
function RequestUserStats(const steamIDUser: TSteamID): SteamAPICall_t;
```

downloads stats for the user returns a UserStatsReceived_t received when completed if the other user has no stats, UserStatsReceived_t.m_eResult will be set to k_EResultFail these stats won't be auto-updated; you'll need to call RequestUserStats() again to refresh any data. Call result: `UserStatsReceived_t` (`UserStatsReceived_t_k_iCallback`).

#### GetUserStatInt32

```pascal
function GetUserStatInt32(const steamIDUser: TSteamID; const pchName: string; var pData: Int32): Boolean;
```

requests stat information for a user, usable after a successful call to RequestUserStats().

#### GetUserStatFloat

```pascal
function GetUserStatFloat(const steamIDUser: TSteamID; const pchName: string; var pData: Single): Boolean;
```

requests stat information for a user, usable after a successful call to RequestUserStats().

#### GetUserAchievement

```pascal
function GetUserAchievement(const steamIDUser: TSteamID; const pchName: string; var pbAchieved: Boolean): Boolean;
```

Wraps `SteamAPI_ISteamUserStats_GetUserAchievement`.

#### GetUserAchievementAndUnlockTime

```pascal
function GetUserAchievementAndUnlockTime(const steamIDUser: TSteamID; const pchName: string; var pbAchieved: Boolean; var punUnlockTime: UInt32): Boolean;
```

See notes for GetAchievementAndUnlockTime above.

#### ResetAllStats

```pascal
function ResetAllStats(bAchievementsToo: Boolean): Boolean;
```

Reset stats.

#### FindOrCreateLeaderboard

```pascal
function FindOrCreateLeaderboard(const pchLeaderboardName: string; AELeaderboardSortMethod: ELeaderboardSortMethod; AELeaderboardDisplayType: ELeaderboardDisplayType): SteamAPICall_t;
```

asks the Steam back-end for a leaderboard by name, and will create it if it's not yet This call is asynchronous, with the result returned in LeaderboardFindResult_t. Call result: `LeaderboardFindResult_t` (`LeaderboardFindResult_t_k_iCallback`).

#### FindLeaderboard

```pascal
function FindLeaderboard(const pchLeaderboardName: string): SteamAPICall_t;
```

as above, but won't create the leaderboard if it's not found This call is asynchronous, with the result returned in LeaderboardFindResult_t. Call result: `LeaderboardFindResult_t` (`LeaderboardFindResult_t_k_iCallback`).

#### GetLeaderboardName

```pascal
function GetLeaderboardName(hSteamLeaderboard: SteamLeaderboard_t): string;
```

returns the name of a leaderboard.

#### GetLeaderboardEntryCount

```pascal
function GetLeaderboardEntryCount(hSteamLeaderboard: SteamLeaderboard_t): Integer;
```

returns the total number of entries in a leaderboard, as of the last request.

#### GetLeaderboardSortMethod

```pascal
function GetLeaderboardSortMethod(hSteamLeaderboard: SteamLeaderboard_t): ELeaderboardSortMethod;
```

returns the sort method of the leaderboard.

#### GetLeaderboardDisplayType

```pascal
function GetLeaderboardDisplayType(hSteamLeaderboard: SteamLeaderboard_t): ELeaderboardDisplayType;
```

returns the display type of the leaderboard.

#### DownloadLeaderboardEntries

```pascal
function DownloadLeaderboardEntries(hSteamLeaderboard: SteamLeaderboard_t; AELeaderboardDataRequest: ELeaderboardDataRequest; nRangeStart: Integer; nRangeEnd: Integer): SteamAPICall_t;
```

Asks the Steam back-end for a set of rows in the leaderboard. This call is asynchronous, with the result returned in LeaderboardScoresDownloaded_t LeaderboardScoresDownloaded_t will contain a handle to pull the results from GetDownloadedLeaderboardEntries() (below) You can ask for more entries than exist, and it will return as many as do exist. k_ELeaderboardDataRequestGlobal requests rows in the leaderboard from the full table, with nRangeStart & nRangeEnd in the range [1, TotalEntries] k_ELeaderboardDataRequestGlobalAroundUser requests rows around the current user, nRangeStart being negate e.g. DownloadLeaderboardEntries( hLeaderboard, k_ELeaderboardDataRequestGlobalAroundUser, -3, 3 ) will return 7 rows, 3 before the user, 3 after k_ELeaderboardDataRequestFriends requests all the rows for friends of the current user. Call result: `LeaderboardScoresDownloaded_t` (`LeaderboardScoresDownloaded_t_k_iCallback`).

#### DownloadLeaderboardEntriesForUsers

```pascal
function DownloadLeaderboardEntriesForUsers(hSteamLeaderboard: SteamLeaderboard_t; prgUsers: Pointer; cUsers: Integer): SteamAPICall_t;
```

as above, but downloads leaderboard entries for an arbitrary set of users - ELeaderboardDataRequest is k_ELeaderboardDataRequestUsers if a user doesn't have a leaderboard entry, they won't be included in the result a max of 100 users can be downloaded at a time, with only one outstanding call at a time. Call result: `LeaderboardScoresDownloaded_t` (`LeaderboardScoresDownloaded_t_k_iCallback`).

#### GetDownloadedLeaderboardEntry

```pascal
function GetDownloadedLeaderboardEntry(hSteamLeaderboardEntries: SteamLeaderboardEntries_t; index: Integer; var pLeaderboardEntry: LeaderboardEntry_t; pDetails: Pointer; cDetailsMax: Integer): Boolean;
```

Returns data about a single leaderboard entry use a for loop from 0 to LeaderboardScoresDownloaded_t::m_cEntryCount to get all the downloaded entries e.g. void OnLeaderboardScoresDownloaded( LeaderboardScoresDownloaded_t *pLeaderboardScoresDownloaded ) { for ( int index = 0; index < pLeaderboardScoresDownloaded->m_cEntryCount; index++ ) { LeaderboardEntry_t leaderboardEntry; int32 details[3]; // we know this is how many we've stored previously GetDownloadedLeaderboardEntry( pLeaderboardScoresDownloaded->m_hSteamLeaderboardEntries, index, &leaderboardEntry, details, 3 ); assert( leaderboardEntry.m_cDetails == 3 ); ... } once you've accessed all the entries, the data will be free'd, and the SteamLeaderboardEntries_t handle will become invalid.

#### UploadLeaderboardScore

```pascal
function UploadLeaderboardScore(hSteamLeaderboard: SteamLeaderboard_t; AELeaderboardUploadScoreMethod: ELeaderboardUploadScoreMethod; nScore: Int32; pScoreDetails: Pointer; cScoreDetailsCount: Integer): SteamAPICall_t;
```

Uploads a user score to the Steam back-end. This call is asynchronous, with the result returned in LeaderboardScoreUploaded_t Details are extra game-defined information regarding how the user got that score pScoreDetails points to an array of int32's, cScoreDetailsCount is the number of int32's in the list. Call result: `LeaderboardScoreUploaded_t` (`LeaderboardScoreUploaded_t_k_iCallback`).

#### AttachLeaderboardUGC

```pascal
function AttachLeaderboardUGC(hSteamLeaderboard: SteamLeaderboard_t; hUGC: UGCHandle_t): SteamAPICall_t;
```

Attaches a piece of user generated content the user's entry on a leaderboard. hContent is a handle to a piece of user generated content that was shared using ISteamUserRemoteStorage::FileShare(). This call is asynchronous, with the result returned in LeaderboardUGCSet_t. Call result: `LeaderboardUGCSet_t` (`LeaderboardUGCSet_t_k_iCallback`).

#### GetNumberOfCurrentPlayers

```pascal
function GetNumberOfCurrentPlayers: SteamAPICall_t;
```

Retrieves the number of players currently playing your game (online + offline) This call is asynchronous, with the result returned in NumberOfCurrentPlayers_t. Call result: `NumberOfCurrentPlayers_t` (`NumberOfCurrentPlayers_t_k_iCallback`).

#### RequestGlobalAchievementPercentages

```pascal
function RequestGlobalAchievementPercentages: SteamAPICall_t;
```

Requests that Steam fetch data on the percentage of players who have received each achievement for the game globally. This call is asynchronous, with the result returned in GlobalAchievementPercentagesReady_t. Call result: `GlobalAchievementPercentagesReady_t` (`GlobalAchievementPercentagesReady_t_k_iCallback`).

#### GetMostAchievedAchievementInfo

```pascal
function GetMostAchievedAchievementInfo(pchName: PAnsiChar; unNameBufLen: UInt32; var pflPercent: Single; var pbAchieved: Boolean): Integer;
```

Get the info on the most achieved achievement for the game, returns an iterator index you can use to fetch the next most achieved afterwards. Will return -1 if there is no data on achievement percentages (ie, you haven't called RequestGlobalAchievementPercentages and waited on the callback).

#### GetNextMostAchievedAchievementInfo

```pascal
function GetNextMostAchievedAchievementInfo(iIteratorPrevious: Integer; pchName: PAnsiChar; unNameBufLen: UInt32; var pflPercent: Single; var pbAchieved: Boolean): Integer;
```

Get the info on the next most achieved achievement for the game. Call this after GetMostAchievedAchievementInfo or another GetNextMostAchievedAchievementInfo call passing the iterator from the previous call. Returns -1 after the last achievement has been iterated.

#### GetAchievementAchievedPercent

```pascal
function GetAchievementAchievedPercent(const pchName: string; var pflPercent: Single): Boolean;
```

Returns the percentage of users who have achieved the specified achievement.

#### RequestGlobalStats

```pascal
function RequestGlobalStats(nHistoryDays: Integer): SteamAPICall_t;
```

Requests global stats data, which is available for stats marked as "aggregated". This call is asynchronous, with the results returned in GlobalStatsReceived_t. nHistoryDays specifies how many days of day-by-day history to retrieve in addition to the overall totals. The limit is 60. Call result: `GlobalStatsReceived_t` (`GlobalStatsReceived_t_k_iCallback`).

#### GetGlobalStatInt64

```pascal
function GetGlobalStatInt64(const pchStatName: string; var pData: Int64): Boolean;
```

Gets the lifetime totals for an aggregated stat.

#### GetGlobalStatDouble

```pascal
function GetGlobalStatDouble(const pchStatName: string; var pData: Double): Boolean;
```

Gets the lifetime totals for an aggregated stat.

#### GetGlobalStatHistoryInt64

```pascal
function GetGlobalStatHistoryInt64(const pchStatName: string; pData: Pointer; cubData: UInt32): Int32;
```

Wraps `SteamAPI_ISteamUserStats_GetGlobalStatHistoryInt64`.

#### GetGlobalStatHistoryDouble

```pascal
function GetGlobalStatHistoryDouble(const pchStatName: string; pData: Pointer; cubData: UInt32): Int32;
```

Wraps `SteamAPI_ISteamUserStats_GetGlobalStatHistoryDouble`.

#### GetAchievementProgressLimitsInt32

```pascal
function GetAchievementProgressLimitsInt32(const pchName: string; var pnMinProgress: Int32; var pnMaxProgress: Int32): Boolean;
```

For achievements that have related Progress stats, use this to query what the bounds of that progress are. You may want this info to selectively call IndicateAchievementProgress when appropriate milestones of progress have been made, to show a progress notification to the user.

#### GetAchievementProgressLimitsFloat

```pascal
function GetAchievementProgressLimitsFloat(const pchName: string; var pfMinProgress: Single; var pfMaxProgress: Single): Boolean;
```

For achievements that have related Progress stats, use this to query what the bounds of that progress are. You may want this info to selectively call IndicateAchievementProgress when appropriate milestones of progress have been made, to show a progress notification to the user.

### Async methods

Each `...Async` method starts the call and registers `AHandler` for its result
(`procedure(const AData: TSteamCallbackData; AIOFailure: Boolean) of object`). The
handler runs once, on the delivery thread, with the result record in `AData`
(`AData.CopyTo(Rec, SizeOf(Rec))`); its object owns the registration - call
`Steam.Dispatcher.RemoveOwner(Self)` in that object's destructor. The plain method of
the same name returns the `SteamAPICall_t` instead, and its result reaches the
component's event.

#### RequestUserStatsAsync

```pascal
function RequestUserStatsAsync(const steamIDUser: TSteamID; AHandler: TSteamCallResultEvent): SteamAPICall_t;
```

Calls `RequestUserStats` and registers AHandler for its result (`UserStatsReceived_t`). The handler's object owns the registration (remove it with Steam.Dispatcher.RemoveOwner). Returns: (The call handle, or k_uAPICallInvalid when Steam refused the call.)

#### FindOrCreateLeaderboardAsync

```pascal
function FindOrCreateLeaderboardAsync(const pchLeaderboardName: string; AELeaderboardSortMethod: ELeaderboardSortMethod; AELeaderboardDisplayType: ELeaderboardDisplayType; AHandler: TSteamCallResultEvent): SteamAPICall_t;
```

Calls `FindOrCreateLeaderboard` and registers AHandler for its result (`LeaderboardFindResult_t`). The handler's object owns the registration (remove it with Steam.Dispatcher.RemoveOwner). Returns: (The call handle, or k_uAPICallInvalid when Steam refused the call.)

#### FindLeaderboardAsync

```pascal
function FindLeaderboardAsync(const pchLeaderboardName: string; AHandler: TSteamCallResultEvent): SteamAPICall_t;
```

Calls `FindLeaderboard` and registers AHandler for its result (`LeaderboardFindResult_t`). The handler's object owns the registration (remove it with Steam.Dispatcher.RemoveOwner). Returns: (The call handle, or k_uAPICallInvalid when Steam refused the call.)

#### DownloadLeaderboardEntriesAsync

```pascal
function DownloadLeaderboardEntriesAsync(hSteamLeaderboard: SteamLeaderboard_t; AELeaderboardDataRequest: ELeaderboardDataRequest; nRangeStart: Integer; nRangeEnd: Integer; AHandler: TSteamCallResultEvent): SteamAPICall_t;
```

Calls `DownloadLeaderboardEntries` and registers AHandler for its result (`LeaderboardScoresDownloaded_t`). The handler's object owns the registration (remove it with Steam.Dispatcher.RemoveOwner). Returns: (The call handle, or k_uAPICallInvalid when Steam refused the call.)

#### DownloadLeaderboardEntriesForUsersAsync

```pascal
function DownloadLeaderboardEntriesForUsersAsync(hSteamLeaderboard: SteamLeaderboard_t; prgUsers: Pointer; cUsers: Integer; AHandler: TSteamCallResultEvent): SteamAPICall_t;
```

Calls `DownloadLeaderboardEntriesForUsers` and registers AHandler for its result (`LeaderboardScoresDownloaded_t`). The handler's object owns the registration (remove it with Steam.Dispatcher.RemoveOwner). Returns: (The call handle, or k_uAPICallInvalid when Steam refused the call.)

#### UploadLeaderboardScoreAsync

```pascal
function UploadLeaderboardScoreAsync(hSteamLeaderboard: SteamLeaderboard_t; AELeaderboardUploadScoreMethod: ELeaderboardUploadScoreMethod; nScore: Int32; pScoreDetails: Pointer; cScoreDetailsCount: Integer; AHandler: TSteamCallResultEvent): SteamAPICall_t;
```

Calls `UploadLeaderboardScore` and registers AHandler for its result (`LeaderboardScoreUploaded_t`). The handler's object owns the registration (remove it with Steam.Dispatcher.RemoveOwner). Returns: (The call handle, or k_uAPICallInvalid when Steam refused the call.)

#### AttachLeaderboardUGCAsync

```pascal
function AttachLeaderboardUGCAsync(hSteamLeaderboard: SteamLeaderboard_t; hUGC: UGCHandle_t; AHandler: TSteamCallResultEvent): SteamAPICall_t;
```

Calls `AttachLeaderboardUGC` and registers AHandler for its result (`LeaderboardUGCSet_t`). The handler's object owns the registration (remove it with Steam.Dispatcher.RemoveOwner). Returns: (The call handle, or k_uAPICallInvalid when Steam refused the call.)

#### GetNumberOfCurrentPlayersAsync

```pascal
function GetNumberOfCurrentPlayersAsync(AHandler: TSteamCallResultEvent): SteamAPICall_t;
```

Calls `GetNumberOfCurrentPlayers` and registers AHandler for its result (`NumberOfCurrentPlayers_t`). The handler's object owns the registration (remove it with Steam.Dispatcher.RemoveOwner). Returns: (The call handle, or k_uAPICallInvalid when Steam refused the call.)

#### RequestGlobalAchievementPercentagesAsync

```pascal
function RequestGlobalAchievementPercentagesAsync(AHandler: TSteamCallResultEvent): SteamAPICall_t;
```

Calls `RequestGlobalAchievementPercentages` and registers AHandler for its result (`GlobalAchievementPercentagesReady_t`). The handler's object owns the registration (remove it with Steam.Dispatcher.RemoveOwner). Returns: (The call handle, or k_uAPICallInvalid when Steam refused the call.)

#### RequestGlobalStatsAsync

```pascal
function RequestGlobalStatsAsync(nHistoryDays: Integer; AHandler: TSteamCallResultEvent): SteamAPICall_t;
```

Calls `RequestGlobalStats` and registers AHandler for its result (`GlobalStatsReceived_t`). The handler's object owns the registration (remove it with Steam.Dispatcher.RemoveOwner). Returns: (The call handle, or k_uAPICallInvalid when Steam refused the call.)

### Properties

| Property | Description |
|----------|-------------|
| `Handle: Pointer` | The raw ISteamUserStats pointer (first argument of every `Flat` export). |
| `Flat: TSteamUserStatsFlat` | The bound flat exports, for calls the methods do not cover. |

## Payload records

Declared in `Steamworks.SDKTypes` (generated from the SDK headers; layouts verified
against the C headers for Win64, Win32, Linux64 and macOS ARM64).

### UserStatsReceived_t

Callback id 1101 (`UserStatsReceived_t_k_iCallback`).

| Field | C declaration |
|-------|---------------|
| `m_nGameID: UInt64` | C field `uint64 m_nGameID`. |
| `m_eResult: EResult` | C field `EResult m_eResult`. |
| `m_steamIDUser: TSteamID` | C field `CSteamID m_steamIDUser`. |

### UserStatsStored_t

Callback id 1102 (`UserStatsStored_t_k_iCallback`).

| Field | C declaration |
|-------|---------------|
| `m_nGameID: UInt64` | C field `uint64 m_nGameID`. |
| `m_eResult: EResult` | C field `EResult m_eResult`. |

### UserAchievementStored_t

Callback id 1103 (`UserAchievementStored_t_k_iCallback`).

| Field | C declaration |
|-------|---------------|
| `m_nGameID: UInt64` | C field `uint64 m_nGameID`. |
| `m_bGroupAchievement: Boolean` | C field `bool m_bGroupAchievement`. |
| `m_rgchAchievementName: array[0..127] of AnsiChar` | C field `char [128] m_rgchAchievementName`. |
| `m_nCurProgress: UInt32` | C field `uint32 m_nCurProgress`. |
| `m_nMaxProgress: UInt32` | C field `uint32 m_nMaxProgress`. |

### LeaderboardFindResult_t

Callback id 1104 (`LeaderboardFindResult_t_k_iCallback`).

| Field | C declaration |
|-------|---------------|
| `m_hSteamLeaderboard: SteamLeaderboard_t` | C field `SteamLeaderboard_t m_hSteamLeaderboard`. |
| `m_bLeaderboardFound: UInt8` | C field `uint8 m_bLeaderboardFound`. |

### LeaderboardScoresDownloaded_t

Callback id 1105 (`LeaderboardScoresDownloaded_t_k_iCallback`).

| Field | C declaration |
|-------|---------------|
| `m_hSteamLeaderboard: SteamLeaderboard_t` | C field `SteamLeaderboard_t m_hSteamLeaderboard`. |
| `m_hSteamLeaderboardEntries: SteamLeaderboardEntries_t` | C field `SteamLeaderboardEntries_t m_hSteamLeaderboardEntries`. |
| `m_cEntryCount: Integer` | C field `int m_cEntryCount`. |

### LeaderboardScoreUploaded_t

Callback id 1106 (`LeaderboardScoreUploaded_t_k_iCallback`).

| Field | C declaration |
|-------|---------------|
| `m_bSuccess: UInt8` | C field `uint8 m_bSuccess`. |
| `m_hSteamLeaderboard: SteamLeaderboard_t` | C field `SteamLeaderboard_t m_hSteamLeaderboard`. |
| `m_nScore: Int32` | C field `int32 m_nScore`. |
| `m_bScoreChanged: UInt8` | C field `uint8 m_bScoreChanged`. |
| `m_nGlobalRankNew: Integer` | C field `int m_nGlobalRankNew`. |
| `m_nGlobalRankPrevious: Integer` | C field `int m_nGlobalRankPrevious`. |

### NumberOfCurrentPlayers_t

Callback id 1107 (`NumberOfCurrentPlayers_t_k_iCallback`).

| Field | C declaration |
|-------|---------------|
| `m_bSuccess: UInt8` | C field `uint8 m_bSuccess`. |
| `m_cPlayers: Int32` | C field `int32 m_cPlayers`. |

### UserStatsUnloaded_t

Callback id 1108 (`UserStatsUnloaded_t_k_iCallback`).

| Field | C declaration |
|-------|---------------|
| `m_steamIDUser: TSteamID` | C field `CSteamID m_steamIDUser`. |

### UserAchievementIconFetched_t

Callback id 1109 (`UserAchievementIconFetched_t_k_iCallback`).

| Field | C declaration |
|-------|---------------|
| `m_nGameID: CGameID` | C field `CGameID m_nGameID`. |
| `m_rgchAchievementName: array[0..127] of AnsiChar` | C field `char [128] m_rgchAchievementName`. |
| `m_bAchieved: Boolean` | C field `bool m_bAchieved`. |
| `m_nIconHandle: Integer` | C field `int m_nIconHandle`. |

### GlobalAchievementPercentagesReady_t

Callback id 1110 (`GlobalAchievementPercentagesReady_t_k_iCallback`).

| Field | C declaration |
|-------|---------------|
| `m_nGameID: UInt64` | C field `uint64 m_nGameID`. |
| `m_eResult: EResult` | C field `EResult m_eResult`. |

### LeaderboardUGCSet_t

Callback id 1111 (`LeaderboardUGCSet_t_k_iCallback`).

| Field | C declaration |
|-------|---------------|
| `m_eResult: EResult` | C field `EResult m_eResult`. |
| `m_hSteamLeaderboard: SteamLeaderboard_t` | C field `SteamLeaderboard_t m_hSteamLeaderboard`. |

### GlobalStatsReceived_t

Callback id 1112 (`GlobalStatsReceived_t_k_iCallback`).

| Field | C declaration |
|-------|---------------|
| `m_nGameID: UInt64` | C field `uint64 m_nGameID`. |
| `m_eResult: EResult` | C field `EResult m_eResult`. |
