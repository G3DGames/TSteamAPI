# TSteamApps and TSteamAppsPlugin (ISteamApps)

> **Generated** by `tools/gen_docs.py` from `lib/plugins/Steamworks.Plugin.Apps.pas` - do not edit.
> Hand-written text: `tools/doc_extras/Apps.md`. Steam's own descriptions are Valve's
> SDK comments, as in the generated units.

Unit: `Steamworks.Plugin.Apps` - linking it (a `uses` entry, or dropping a `TSteamApps`) enables the
plug-in. Steam interface: `ISteamApps` (SDK 1.65).

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

## Contents

* [The component: TSteamApps](#the-component-tsteamapps)
  * [Events (5)](#events)
* [The plug-in: TSteamAppsPlugin](#the-plug-in-tsteamappsplugin)
  * [Methods](#methods)
  * [Async methods](#async-methods)
  * [Properties](#properties)
* [Payload records](#payload-records)

## The component: TSteamApps

ISteamApps component: drop it next to a TSteamAPI (linked automatically at run time when the owner has exactly one, otherwise set SteamAPI). Its events are the ISteamApps callbacks; call the interface through `Plugin`.

| Member | Kind | Description |
|--------|------|-------------|
| `SteamAPI` | published property | The `TSteamAPI` this component belongs to. At run time a component whose owner has exactly one `TSteamAPI` links itself. |
| `Plugin` | public property | The `TSteamAppsPlugin` for calls; `nil` while Steam is not running. |
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
| `OnDlcInstalled` | 1005 | [`DlcInstalled_t`](#dlcinstalled_t) | posted after the user gains ownership of DLC & that DLC is installed. |
| `OnNewUrlLaunchParameters` | 1014 | [`NewUrlLaunchParameters_t`](#newurllaunchparameters_t) | posted after the user gains executes a Steam URL with command line or query parameters such as steam://run/<appid>//-commandline/?param1=value1&param2=value2&param3=value3 etc while the game is already running. The new params can be queried with GetLaunchQueryParam and GetLaunchCommandLine. |
| `OnAppProofOfPurchaseKeyResponse` | 1021 | [`AppProofOfPurchaseKeyResponse_t`](#appproofofpurchasekeyresponse_t) | response to RequestAppProofOfPurchaseKey/RequestAllProofOfPurchaseKeys for supporting third-party CD keys, or other proof-of-purchase systems. |
| `OnFileDetailsResult` | 1023 | [`FileDetailsResult_t`](#filedetailsresult_t) | response to GetFileDetails. |
| `OnTimedTrialStatus` | 1030 | [`TimedTrialStatus_t`](#timedtrialstatus_t) | called for games in Timed Trial mode. |

Handler signature (the IDE generates it when you double-click the event):

```pascal
procedure TForm1.SteamApps1DlcInstalled(Sender: TObject; const AData: DlcInstalled_t);
```

## The plug-in: TSteamAppsPlugin

ISteamApps plug-in. Registered by linking the unit; find it with @code(Steam.FindPlugin(TSteamAppsPlugin)).

Reach it through the component (`SteamApps1.Plugin`) or the core:

```pascal
P := TSteamAppsPlugin(Steam.FindPlugin(TSteamAppsPlugin));   // Delphi also: Steam.Plugin<TSteamAppsPlugin>
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
| [`BIsSubscribed`](#bissubscribed) | Wraps `SteamAPI_ISteamApps_BIsSubscribed`. |
| [`BIsLowViolence`](#bislowviolence) | Wraps `SteamAPI_ISteamApps_BIsLowViolence`. |
| [`BIsCybercafe`](#biscybercafe) | Wraps `SteamAPI_ISteamApps_BIsCybercafe`. |
| [`BIsVACBanned`](#bisvacbanned) | Wraps `SteamAPI_ISteamApps_BIsVACBanned`. |
| [`GetCurrentGameLanguage`](#getcurrentgamelanguage) | Wraps `SteamAPI_ISteamApps_GetCurrentGameLanguage`. |
| [`GetAvailableGameLanguages`](#getavailablegamelanguages) | Wraps `SteamAPI_ISteamApps_GetAvailableGameLanguages`. |
| [`BIsSubscribedApp`](#bissubscribedapp) | only use this member if you need to check ownership of another game related to yours, a demo for example. |
| [`BIsDlcInstalled`](#bisdlcinstalled) | Takes AppID of DLC and checks if the user owns the DLC & if the DLC is installed. |
| [`GetEarliestPurchaseUnixTime`](#getearliestpurchaseunixtime) | returns the Unix time of the purchase of the app. |
| [`BIsSubscribedFromFreeWeekend`](#bissubscribedfromfreeweekend) | Checks if the user is subscribed to the current app through a free weekend This function will return false for users who have a retail or other type of ... |
| [`GetDLCCount`](#getdlccount) | Returns the number of DLC pieces for the running app. |
| [`BGetDLCDataByIndex`](#bgetdlcdatabyindex) | Returns metadata for DLC by index, of range [0, GetDLCCount()]. |
| [`InstallDLC`](#installdlc) | Install/Uninstall control for optional DLC. |
| [`UninstallDLC`](#uninstalldlc) | Wraps `SteamAPI_ISteamApps_UninstallDLC`. |
| [`RequestAppProofOfPurchaseKey`](#requestappproofofpurchasekey) | Request legacy cd-key for yourself or owned DLC. If you are interested in this data then make sure you provide us with a list of valid keys to be ... |
| [`GetCurrentBetaName`](#getcurrentbetaname) | Wraps `SteamAPI_ISteamApps_GetCurrentBetaName`. |
| [`MarkContentCorrupt`](#markcontentcorrupt) | Wraps `SteamAPI_ISteamApps_MarkContentCorrupt`. |
| [`GetInstalledDepots`](#getinstalleddepots) | Wraps `SteamAPI_ISteamApps_GetInstalledDepots`. |
| [`GetAppInstallDir`](#getappinstalldir) | returns current app install folder for AppID, returns folder name length. |
| [`BIsAppInstalled`](#bisappinstalled) | Wraps `SteamAPI_ISteamApps_BIsAppInstalled`. |
| [`GetAppOwner`](#getappowner) | returns the SteamID of the original owner. If this CSteamID is different from ISteamUser::GetSteamID(), the user has a temporary license borrowed via Family ... |
| [`GetLaunchQueryParam`](#getlaunchqueryparam) | Returns the associated launch param if the game is run via steam://run/<appid>//?param1=value1&param2=value2&param3=value3 etc. Parameter names starting ... |
| [`GetDlcDownloadProgress`](#getdlcdownloadprogress) | get download progress for optional DLC. |
| [`GetAppBuildId`](#getappbuildid) | return the buildid of this app, may change at any time based on backend updates to the game. |
| [`RequestAllProofOfPurchaseKeys`](#requestallproofofpurchasekeys) | Request all proof of purchase keys for the calling appid and associated DLC. A series of AppProofOfPurchaseKeyResponse_t callbacks will be sent with ... |
| [`GetFileDetails`](#getfiledetails) | Wraps `SteamAPI_ISteamApps_GetFileDetails`. Call result: `FileDetailsResult_t` (`FileDetailsResult_t_k_iCallback`). |
| [`GetLaunchCommandLine`](#getlaunchcommandline) | Get command line if game was launched via Steam URL, e.g. steam://run/<appid>//<command line>/. This method of passing a connect string (used when joining ... |
| [`BIsSubscribedFromFamilySharing`](#bissubscribedfromfamilysharing) | Check if user borrowed this game via Family Sharing, If true, call GetAppOwner() to get the lender SteamID. |
| [`BIsTimedTrial`](#bistimedtrial) | check if game is a timed trial with limited playtime. |
| [`SetDlcContext`](#setdlccontext) | set current DLC AppID being played (or 0 if none). Allows Steam to track usage of major DLC extensions. |
| [`GetNumBetas`](#getnumbetas) | returns total number of known app branches (including default "public" branch ). nAvailable is number of available betas. |
| [`GetBetaInfo`](#getbetainfo) | return beta branch details, name, description, current BuildID and state flags (EBetaBranchFlags). |
| [`SetActiveBeta`](#setactivebeta) | select this beta branch for this app as active, might need the game to restart so Steam can update to that branch. |
| [`SetGamePerformanceSetting`](#setgameperformancesetting) | game performance settings. |
| [`SetGameRenderResolution`](#setgamerenderresolution) | Wraps `SteamAPI_ISteamApps_SetGameRenderResolution`. |

#### BIsSubscribed

```pascal
function BIsSubscribed: Boolean;
```

Wraps `SteamAPI_ISteamApps_BIsSubscribed`.

#### BIsLowViolence

```pascal
function BIsLowViolence: Boolean;
```

Wraps `SteamAPI_ISteamApps_BIsLowViolence`.

#### BIsCybercafe

```pascal
function BIsCybercafe: Boolean;
```

Wraps `SteamAPI_ISteamApps_BIsCybercafe`.

#### BIsVACBanned

```pascal
function BIsVACBanned: Boolean;
```

Wraps `SteamAPI_ISteamApps_BIsVACBanned`.

#### GetCurrentGameLanguage

```pascal
function GetCurrentGameLanguage: string;
```

Wraps `SteamAPI_ISteamApps_GetCurrentGameLanguage`.

#### GetAvailableGameLanguages

```pascal
function GetAvailableGameLanguages: string;
```

Wraps `SteamAPI_ISteamApps_GetAvailableGameLanguages`.

#### BIsSubscribedApp

```pascal
function BIsSubscribedApp(appID: AppId_t): Boolean;
```

only use this member if you need to check ownership of another game related to yours, a demo for example.

#### BIsDlcInstalled

```pascal
function BIsDlcInstalled(appID: AppId_t): Boolean;
```

Takes AppID of DLC and checks if the user owns the DLC & if the DLC is installed.

#### GetEarliestPurchaseUnixTime

```pascal
function GetEarliestPurchaseUnixTime(nAppID: AppId_t): UInt32;
```

returns the Unix time of the purchase of the app.

#### BIsSubscribedFromFreeWeekend

```pascal
function BIsSubscribedFromFreeWeekend: Boolean;
```

Checks if the user is subscribed to the current app through a free weekend This function will return false for users who have a retail or other type of license Before using, please ask your Valve technical contact how to package and secure your free weekend.

#### GetDLCCount

```pascal
function GetDLCCount: Integer;
```

Returns the number of DLC pieces for the running app.

#### BGetDLCDataByIndex

```pascal
function BGetDLCDataByIndex(iDLC: Integer; var pAppID: AppId_t; var pbAvailable: Boolean; pchName: PAnsiChar; cchNameBufferSize: Integer): Boolean;
```

Returns metadata for DLC by index, of range [0, GetDLCCount()].

#### InstallDLC

```pascal
procedure InstallDLC(nAppID: AppId_t);
```

Install/Uninstall control for optional DLC.

#### UninstallDLC

```pascal
procedure UninstallDLC(nAppID: AppId_t);
```

Wraps `SteamAPI_ISteamApps_UninstallDLC`.

#### RequestAppProofOfPurchaseKey

```pascal
procedure RequestAppProofOfPurchaseKey(nAppID: AppId_t);
```

Request legacy cd-key for yourself or owned DLC. If you are interested in this data then make sure you provide us with a list of valid keys to be distributed to users when they purchase the game, before the game ships. You'll receive an AppProofOfPurchaseKeyResponse_t callback when the key is available (which may be immediately).

#### GetCurrentBetaName

```pascal
function GetCurrentBetaName(pchName: PAnsiChar; cchNameBufferSize: Integer): Boolean;
```

Wraps `SteamAPI_ISteamApps_GetCurrentBetaName`.

#### MarkContentCorrupt

```pascal
function MarkContentCorrupt(bMissingFilesOnly: Boolean): Boolean;
```

Wraps `SteamAPI_ISteamApps_MarkContentCorrupt`.

#### GetInstalledDepots

```pascal
function GetInstalledDepots(appID: AppId_t; pvecDepots: Pointer; cMaxDepots: UInt32): UInt32;
```

Wraps `SteamAPI_ISteamApps_GetInstalledDepots`.

#### GetAppInstallDir

```pascal
function GetAppInstallDir(appID: AppId_t; pchFolder: PAnsiChar; cchFolderBufferSize: UInt32): UInt32;
```

returns current app install folder for AppID, returns folder name length.

#### BIsAppInstalled

```pascal
function BIsAppInstalled(appID: AppId_t): Boolean;
```

Wraps `SteamAPI_ISteamApps_BIsAppInstalled`.

#### GetAppOwner

```pascal
function GetAppOwner: TSteamID;
```

returns the SteamID of the original owner. If this CSteamID is different from ISteamUser::GetSteamID(), the user has a temporary license borrowed via Family Sharing.

#### GetLaunchQueryParam

```pascal
function GetLaunchQueryParam(const pchKey: string): string;
```

Returns the associated launch param if the game is run via steam://run/<appid>//?param1=value1&param2=value2&param3=value3 etc. Parameter names starting with the character '@' are reserved for internal use and will always return and empty string. Parameter names starting with an underscore '_' are reserved for steam features -- they can be queried by the game, but it is advised that you not param names beginning with an underscore for your own features. Check for new launch parameters on callback NewUrlLaunchParameters_t.

#### GetDlcDownloadProgress

```pascal
function GetDlcDownloadProgress(nAppID: AppId_t; var punBytesDownloaded: UInt64; var punBytesTotal: UInt64): Boolean;
```

get download progress for optional DLC.

#### GetAppBuildId

```pascal
function GetAppBuildId: Integer;
```

return the buildid of this app, may change at any time based on backend updates to the game.

#### RequestAllProofOfPurchaseKeys

```pascal
procedure RequestAllProofOfPurchaseKeys;
```

Request all proof of purchase keys for the calling appid and associated DLC. A series of AppProofOfPurchaseKeyResponse_t callbacks will be sent with appropriate appid values, ending with a final callback where the m_nAppId member is k_uAppIdInvalid (zero).

#### GetFileDetails

```pascal
function GetFileDetails(const pszFileName: string): SteamAPICall_t;
```

Wraps `SteamAPI_ISteamApps_GetFileDetails`. Call result: `FileDetailsResult_t` (`FileDetailsResult_t_k_iCallback`).

#### GetLaunchCommandLine

```pascal
function GetLaunchCommandLine(pszCommandLine: PAnsiChar; cubCommandLine: Integer): Integer;
```

Get command line if game was launched via Steam URL, e.g. steam://run/<appid>//<command line>/. This method of passing a connect string (used when joining via rich presence, accepting an invite, etc) is preferable to passing the connect string on the operating system command line, which is a security risk. In order for rich presence joins to go through this path and not be placed on the OS command line, you must set a value in your app's configuration on Steam. Ask Valve for help with this. If game was already running and launched again, the NewUrlLaunchParameters_t will be fired.

#### BIsSubscribedFromFamilySharing

```pascal
function BIsSubscribedFromFamilySharing: Boolean;
```

Check if user borrowed this game via Family Sharing, If true, call GetAppOwner() to get the lender SteamID.

#### BIsTimedTrial

```pascal
function BIsTimedTrial(var punSecondsAllowed: UInt32; var punSecondsPlayed: UInt32): Boolean;
```

check if game is a timed trial with limited playtime.

#### SetDlcContext

```pascal
function SetDlcContext(nAppID: AppId_t): Boolean;
```

set current DLC AppID being played (or 0 if none). Allows Steam to track usage of major DLC extensions.

#### GetNumBetas

```pascal
function GetNumBetas(var pnAvailable: Integer; var pnPrivate: Integer): Integer;
```

returns total number of known app branches (including default "public" branch ). nAvailable is number of available betas.

#### GetBetaInfo

```pascal
function GetBetaInfo(iBetaIndex: Integer; var punFlags: UInt32; var punBuildID: UInt32; pchBetaName: PAnsiChar; cchBetaName: Integer; pchDescription: PAnsiChar; cchDescription: Integer; var punLastUpdated: UInt32): Boolean;
```

return beta branch details, name, description, current BuildID and state flags (EBetaBranchFlags).

#### SetActiveBeta

```pascal
function SetActiveBeta(const pchBetaName: string): Boolean;
```

select this beta branch for this app as active, might need the game to restart so Steam can update to that branch.

#### SetGamePerformanceSetting

```pascal
procedure SetGamePerformanceSetting(setting: EGamePerformanceSetting);
```

game performance settings.

#### SetGameRenderResolution

```pascal
procedure SetGameRenderResolution(unWidth: UInt32; unHeight: UInt32);
```

Wraps `SteamAPI_ISteamApps_SetGameRenderResolution`.

### Async methods

Each `...Async` method starts the call and registers `AHandler` for its result
(`procedure(const AData: TSteamCallbackData; AIOFailure: Boolean) of object`). The
handler runs once, on the delivery thread, with the result record in `AData`
(`AData.CopyTo(Rec, SizeOf(Rec))`); its object owns the registration - call
`Steam.Dispatcher.RemoveOwner(Self)` in that object's destructor. The plain method of
the same name returns the `SteamAPICall_t` instead, and its result reaches the
component's event.

#### GetFileDetailsAsync

```pascal
function GetFileDetailsAsync(const pszFileName: string; AHandler: TSteamCallResultEvent): SteamAPICall_t;
```

Calls `GetFileDetails` and registers AHandler for its result (`FileDetailsResult_t`). The handler's object owns the registration (remove it with Steam.Dispatcher.RemoveOwner). Returns: (The call handle, or k_uAPICallInvalid when Steam refused the call.)

### Properties

| Property | Description |
|----------|-------------|
| `Handle: Pointer` | The raw ISteamApps pointer (first argument of every `Flat` export). |
| `Flat: TSteamAppsFlat` | The bound flat exports, for calls the methods do not cover. |

## Payload records

Declared in `Steamworks.SDKTypes` (generated from the SDK headers; layouts verified
against the C headers for Win64, Win32, Linux64 and macOS ARM64).

### DlcInstalled_t

Callback id 1005 (`DlcInstalled_t_k_iCallback`).

| Field | C declaration |
|-------|---------------|
| `m_nAppID: AppId_t` | C field `AppId_t m_nAppID`. |

### NewUrlLaunchParameters_t

Callback id 1014 (`NewUrlLaunchParameters_t_k_iCallback`).

| Field | C declaration |
|-------|---------------|
| `_dummy: Byte` | Placeholder: the C++ struct is empty (sizeof = 1). |

### AppProofOfPurchaseKeyResponse_t

Callback id 1021 (`AppProofOfPurchaseKeyResponse_t_k_iCallback`).

| Field | C declaration |
|-------|---------------|
| `m_eResult: EResult` | C field `EResult m_eResult`. |
| `m_nAppID: UInt32` | C field `uint32 m_nAppID`. |
| `m_cchKeyLength: UInt32` | C field `uint32 m_cchKeyLength`. |
| `m_rgchKey: array[0..239] of AnsiChar` | C field `char [240] m_rgchKey`. |

### FileDetailsResult_t

Callback id 1023 (`FileDetailsResult_t_k_iCallback`).

| Field | C declaration |
|-------|---------------|
| `m_eResult: EResult` | C field `EResult m_eResult`. |
| `m_ulFileSize: UInt64` | C field `uint64 m_ulFileSize`. |
| `m_FileSHA: array[0..19] of UInt8` | C field `uint8 [20] m_FileSHA`. |
| `m_unFlags: UInt32` | C field `uint32 m_unFlags`. |

### TimedTrialStatus_t

Callback id 1030 (`TimedTrialStatus_t_k_iCallback`).

| Field | C declaration |
|-------|---------------|
| `m_unAppID: AppId_t` | C field `AppId_t m_unAppID`. |
| `m_bIsOffline: Boolean` | C field `bool m_bIsOffline`. |
| `m_unSecondsAllowed: UInt32` | C field `uint32 m_unSecondsAllowed`. |
| `m_unSecondsPlayed: UInt32` | C field `uint32 m_unSecondsPlayed`. |
