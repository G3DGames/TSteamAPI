# TSteamUGC and TSteamUGCPlugin (ISteamUGC)

> **Generated** by `tools/gen_docs.py` from `lib/plugins/Steamworks.Plugin.UGC.pas` - do not edit.
> Hand-written text: `tools/doc_extras/UGC.md`. Steam's own descriptions are Valve's
> SDK comments, as in the generated units.

Unit: `Steamworks.Plugin.UGC` - linking it (a `uses` entry, or dropping a `TSteamUGC`) enables the
plug-in. Steam interface: `ISteamUGC` (SDK 1.65).

## Overview

Steam Workshop: querying, creating, updating, subscribing to and installing
user-generated content. Enable the Workshop for the AppID on the partner
site first. Most calls are asynchronous: handle the component events or
pass a handler to the `...Async` method.

### Querying items

A query is created, configured, sent, read page by page and released.

```pascal
procedure TGame.ListPopular;
var
  Q: UGCQueryHandle_t;
begin
  Q := UGC.CreateQueryAllUGCRequestPage(k_EUGCQuery_RankedByVote,
    k_EUGCMatchingUGCType_Items, AppID, AppID, 1);         // page 1, 50 per page
  if Q = k_UGCQueryHandleInvalid then
    Exit;
  UGC.SetReturnLongDescription(Q, False);
  UGC.SendQueryUGCRequestAsync(Q, QueryDone);
end;

procedure TGame.QueryDone(const AData: TSteamCallbackData; AIOFailure: Boolean);
var
  R: SteamUGCQueryCompleted_t;
  D: SteamUGCDetails_t;
  I: UInt32;
begin
  if AIOFailure or not AData.CopyTo(R, SizeOf(R)) then
    Exit;
  try
    if R.m_eResult <> k_EResultOK then
      Exit;
    for I := 0 to Int64(R.m_unNumResultsReturned) - 1 do
      if UGC.GetQueryUGCResult(R.m_handle, I, D) then
        AddItem(D.m_nPublishedFileId, string(UTF8String(PAnsiChar(@D.m_rgchTitle[0]))));
  finally
    UGC.ReleaseQueryUGCRequest(R.m_handle);   // always, even after a failure
  end;
end;
```

* `CreateQueryUserUGCRequest` lists one user's items (published, subscribed,
  favourited ...); `CreateQueryUGCDetailsRequest` fetches known ids;
  `CreateQueryAllUGCRequestCursor` pages with a cursor
  (`m_rgchNextCursor` of the result) instead of page numbers.
* Before sending: `AddRequiredTag`, `AddExcludedTag`, `SetSearchText`,
  `SetReturnMetadata`, `SetReturnChildren`, `SetLanguage`,
  `SetAllowCachedResponse` and the other `Set...` filters.
* Per result: `GetQueryUGCResult` fills `SteamUGCDetails_t`; tags,
  preview URL, metadata and key-value tags come back in buffers you pass
  (`PAnsiChar` + size, as in C).

### Creating and updating an item

```pascal
UGC.CreateItemAsync(AppID, k_EWorkshopFileTypeCommunity, ItemCreated);

procedure TGame.ItemCreated(const AData: TSteamCallbackData; AIOFailure: Boolean);
var
  R: CreateItemResult_t;
  H: UGCUpdateHandle_t;
begin
  if AIOFailure or not AData.CopyTo(R, SizeOf(R)) or (R.m_eResult <> k_EResultOK) then
    Exit;
  if R.m_bUserNeedsToAcceptWorkshopLegalAgreement then
    ShowLegalAgreementHint;                  // the item stays hidden until accepted
  H := UGC.StartItemUpdate(AppID, R.m_nPublishedFileId);
  UGC.SetItemTitle(H, 'My map');
  UGC.SetItemContent(H, ContentFolder);       // absolute folder path
  UGC.SetItemPreview(H, PreviewFile);         // absolute file path
  UGC.SetItemVisibility(H, k_ERemoteStoragePublishedFileVisibilityPublic);
  UGC.SubmitItemUpdateAsync(H, 'First version', ItemSubmitted);
end;
```

`GetItemUpdateProgress(H, Done, Total)` reports the upload while
`SubmitItemUpdate` runs (status `k_EItemUpdateStatus...`).

### Subscribed and installed items

* `GetNumSubscribedItems(False)` and `GetSubscribedItems(@Ids[0], Length(Ids),
  False)` (an `array of PublishedFileId_t`) list the user's subscriptions.
* `GetItemState(Id)` is a bit set (`k_EItemStateSubscribed`,
  `k_EItemStateInstalled`, `k_EItemStateNeedsUpdate`, `k_EItemStateDownloading`
  ...); `GetItemInstallInfo` gives the install folder (in a buffer you pass),
  size and time stamp.
* `DownloadItem(Id, True)` fetches or updates one now; progress through
  `GetItemDownloadInfo`, completion through `OnDownloadItemResult`.
  `OnItemInstalled` fires for items of this app installed while it runs.
* `SubscribeItem` / `UnsubscribeItem`, `SetUserItemVote`,
  `AddItemToFavorites` and the dependency calls are call results like the
  rest.

Game servers reach the Workshop through `BInitWorkshopForGameServer`; the
game-server interfaces themselves come in a later batch.

## Contents

* [The component: TSteamUGC](#the-component-tsteamugc)
  * [Events (19)](#events)
* [The plug-in: TSteamUGCPlugin](#the-plug-in-tsteamugcplugin)
  * [Methods](#methods)
  * [Async methods](#async-methods)
  * [Properties](#properties)
* [Payload records](#payload-records)

## The component: TSteamUGC

ISteamUGC component: drop it next to a TSteamAPI (linked automatically at run time when the owner has exactly one, otherwise set SteamAPI). Its events are the ISteamUGC callbacks; call the interface through `Plugin`.

| Member | Kind | Description |
|--------|------|-------------|
| `SteamAPI` | published property | The `TSteamAPI` this component belongs to. At run time a component whose owner has exactly one `TSteamAPI` links itself. |
| `Plugin` | public property | The `TSteamUGCPlugin` for calls; `nil` while Steam is not running. |
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
| `OnSteamUGCQueryCompleted` | 3401 | [`SteamUGCQueryCompleted_t`](#steamugcquerycompleted_t) | Callback for querying UGC. |
| `OnSteamUGCRequestUGCDetailsResult` | 3402 | [`SteamUGCRequestUGCDetailsResult_t`](#steamugcrequestugcdetailsresult_t) | Callback for requesting details on one piece of UGC. |
| `OnCreateItemResult` | 3403 | [`CreateItemResult_t`](#createitemresult_t) | result for ISteamUGC::CreateItem(). |
| `OnSubmitItemUpdateResult` | 3404 | [`SubmitItemUpdateResult_t`](#submititemupdateresult_t) | result for ISteamUGC::SubmitItemUpdate(). |
| `OnItemInstalled` | 3405 | [`ItemInstalled_t`](#iteminstalled_t) | a Workshop item has been installed or updated. |
| `OnDownloadItemResult` | 3406 | [`DownloadItemResult_t`](#downloaditemresult_t) | result of DownloadItem(), existing item files can be accessed again. |
| `OnUserFavoriteItemsListChanged` | 3407 | [`UserFavoriteItemsListChanged_t`](#userfavoriteitemslistchanged_t) | result of AddItemToFavorites() or RemoveItemFromFavorites(). |
| `OnSetUserItemVoteResult` | 3408 | [`SetUserItemVoteResult_t`](#setuseritemvoteresult_t) | The result of a call to SetUserItemVote(). |
| `OnGetUserItemVoteResult` | 3409 | [`GetUserItemVoteResult_t`](#getuseritemvoteresult_t) | The result of a call to GetUserItemVote(). |
| `OnStartPlaytimeTrackingResult` | 3410 | [`StartPlaytimeTrackingResult_t`](#startplaytimetrackingresult_t) | The result of a call to StartPlaytimeTracking(). |
| `OnStopPlaytimeTrackingResult` | 3411 | [`StopPlaytimeTrackingResult_t`](#stopplaytimetrackingresult_t) | The result of a call to StopPlaytimeTracking(). |
| `OnAddUGCDependencyResult` | 3412 | [`AddUGCDependencyResult_t`](#addugcdependencyresult_t) | The result of a call to AddDependency. |
| `OnRemoveUGCDependencyResult` | 3413 | [`RemoveUGCDependencyResult_t`](#removeugcdependencyresult_t) | The result of a call to RemoveDependency. |
| `OnAddAppDependencyResult` | 3414 | [`AddAppDependencyResult_t`](#addappdependencyresult_t) | The result of a call to AddAppDependency. |
| `OnRemoveAppDependencyResult` | 3415 | [`RemoveAppDependencyResult_t`](#removeappdependencyresult_t) | The result of a call to RemoveAppDependency. |
| `OnGetAppDependenciesResult` | 3416 | [`GetAppDependenciesResult_t`](#getappdependenciesresult_t) | The result of a call to GetAppDependencies. Callback may be called multiple times until all app dependencies have been returned. |
| `OnDeleteItemResult` | 3417 | [`DeleteItemResult_t`](#deleteitemresult_t) | The result of a call to DeleteItem. |
| `OnUserSubscribedItemsListChanged` | 3418 | [`UserSubscribedItemsListChanged_t`](#usersubscribeditemslistchanged_t) | signal that the list of subscribed items changed. |
| `OnWorkshopEULAStatus` | 3420 | [`WorkshopEULAStatus_t`](#workshopeulastatus_t) | Status of the user's acceptable/rejection of the app's specific Workshop EULA. |

Handler signature (the IDE generates it when you double-click the event):

```pascal
procedure TForm1.SteamUGC1SteamUGCQueryCompleted(Sender: TObject; const AData: SteamUGCQueryCompleted_t);
```

## The plug-in: TSteamUGCPlugin

ISteamUGC plug-in. Registered by linking the unit; find it with @code(Steam.FindPlugin(TSteamUGCPlugin)).

Reach it through the component (`SteamUGC1.Plugin`) or the core:

```pascal
P := TSteamUGCPlugin(Steam.FindPlugin(TSteamUGCPlugin));   // Delphi also: Steam.Plugin<TSteamUGCPlugin>
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
| [`CreateQueryUserUGCRequest`](#createqueryuserugcrequest) | Query UGC associated with a user. Creator app id or consumer app id must be valid and be set to the current running app. unPage should start at 1. |
| [`CreateQueryAllUGCRequestPage`](#createqueryallugcrequestpage) | Query for all matching UGC. Creator app id or consumer app id must be valid and be set to the current running app. unPage should start at 1. |
| [`CreateQueryAllUGCRequestCursor`](#createqueryallugcrequestcursor) | Query for all matching UGC. Creator app id or consumer app id must be valid and be set to the current running app. unPage should start at 1. |
| [`CreateQueryUGCDetailsRequest`](#createqueryugcdetailsrequest) | Query for the details of the given published file ids (the RequestUGCDetails call is deprecated and replaced with this). |
| [`SendQueryUGCRequest`](#sendqueryugcrequest) | Send the query to Steam. Call result: `SteamUGCQueryCompleted_t` (`SteamUGCQueryCompleted_t_k_iCallback`). |
| [`GetQueryUGCResult`](#getqueryugcresult) | Retrieve an individual result after receiving the callback for querying UGC. |
| [`GetQueryUGCNumTags`](#getqueryugcnumtags) | Wraps `SteamAPI_ISteamUGC_GetQueryUGCNumTags`. |
| [`GetQueryUGCTag`](#getqueryugctag) | Wraps `SteamAPI_ISteamUGC_GetQueryUGCTag`. |
| [`GetQueryUGCTagDisplayName`](#getqueryugctagdisplayname) | Wraps `SteamAPI_ISteamUGC_GetQueryUGCTagDisplayName`. |
| [`GetQueryUGCPreviewURL`](#getqueryugcpreviewurl) | Wraps `SteamAPI_ISteamUGC_GetQueryUGCPreviewURL`. |
| [`GetQueryUGCMetadata`](#getqueryugcmetadata) | Wraps `SteamAPI_ISteamUGC_GetQueryUGCMetadata`. |
| [`GetQueryUGCChildren`](#getqueryugcchildren) | Wraps `SteamAPI_ISteamUGC_GetQueryUGCChildren`. |
| [`GetQueryUGCStatistic`](#getqueryugcstatistic) | Wraps `SteamAPI_ISteamUGC_GetQueryUGCStatistic`. |
| [`GetQueryUGCNumAdditionalPreviews`](#getqueryugcnumadditionalpreviews) | Wraps `SteamAPI_ISteamUGC_GetQueryUGCNumAdditionalPreviews`. |
| [`GetQueryUGCAdditionalPreview`](#getqueryugcadditionalpreview) | Wraps `SteamAPI_ISteamUGC_GetQueryUGCAdditionalPreview`. |
| [`GetQueryUGCNumKeyValueTags`](#getqueryugcnumkeyvaluetags) | Wraps `SteamAPI_ISteamUGC_GetQueryUGCNumKeyValueTags`. |
| [`GetQueryUGCKeyValueTag`](#getqueryugckeyvaluetag) | Wraps `SteamAPI_ISteamUGC_GetQueryUGCKeyValueTag`. |
| [`GetQueryFirstUGCKeyValueTag`](#getqueryfirstugckeyvaluetag) | Wraps `SteamAPI_ISteamUGC_GetQueryFirstUGCKeyValueTag`. |
| [`GetNumSupportedGameVersions`](#getnumsupportedgameversions) | Some items can specify that they have a version that is valid for a range of game versions (Steam branch). |
| [`GetSupportedGameVersionData`](#getsupportedgameversiondata) | Wraps `SteamAPI_ISteamUGC_GetSupportedGameVersionData`. |
| [`GetQueryUGCContentDescriptors`](#getqueryugccontentdescriptors) | Wraps `SteamAPI_ISteamUGC_GetQueryUGCContentDescriptors`. |
| [`ReleaseQueryUGCRequest`](#releasequeryugcrequest) | Release the request to free up memory, after retrieving results. |
| [`AddRequiredTag`](#addrequiredtag) | Options to set for querying UGC. |
| [`AddRequiredTagGroup`](#addrequiredtaggroup) | Wraps `SteamAPI_ISteamUGC_AddRequiredTagGroup`. |
| [`AddExcludedTag`](#addexcludedtag) | Wraps `SteamAPI_ISteamUGC_AddExcludedTag`. |
| [`SetReturnOnlyIDs`](#setreturnonlyids) | Wraps `SteamAPI_ISteamUGC_SetReturnOnlyIDs`. |
| [`SetReturnKeyValueTags`](#setreturnkeyvaluetags) | Wraps `SteamAPI_ISteamUGC_SetReturnKeyValueTags`. |
| [`SetReturnLongDescription`](#setreturnlongdescription) | Wraps `SteamAPI_ISteamUGC_SetReturnLongDescription`. |
| [`SetReturnMetadata`](#setreturnmetadata) | Wraps `SteamAPI_ISteamUGC_SetReturnMetadata`. |
| [`SetReturnChildren`](#setreturnchildren) | Wraps `SteamAPI_ISteamUGC_SetReturnChildren`. |
| [`SetReturnAdditionalPreviews`](#setreturnadditionalpreviews) | Wraps `SteamAPI_ISteamUGC_SetReturnAdditionalPreviews`. |
| [`SetReturnTotalOnly`](#setreturntotalonly) | Wraps `SteamAPI_ISteamUGC_SetReturnTotalOnly`. |
| [`SetReturnPlaytimeStats`](#setreturnplaytimestats) | Wraps `SteamAPI_ISteamUGC_SetReturnPlaytimeStats`. |
| [`SetLanguage`](#setlanguage) | Wraps `SteamAPI_ISteamUGC_SetLanguage`. |
| [`SetAllowCachedResponse`](#setallowcachedresponse) | Wraps `SteamAPI_ISteamUGC_SetAllowCachedResponse`. |
| [`SetAdminQuery`](#setadminquery) | Wraps `SteamAPI_ISteamUGC_SetAdminQuery`. |
| [`SetCloudFileNameFilter`](#setcloudfilenamefilter) | Options only for querying user UGC. |
| [`SetMatchAnyTag`](#setmatchanytag) | Options only for querying all UGC. |
| [`SetSearchText`](#setsearchtext) | Wraps `SteamAPI_ISteamUGC_SetSearchText`. |
| [`SetRankedByTrendDays`](#setrankedbytrenddays) | Wraps `SteamAPI_ISteamUGC_SetRankedByTrendDays`. |
| [`SetTimeCreatedDateRange`](#settimecreateddaterange) | Wraps `SteamAPI_ISteamUGC_SetTimeCreatedDateRange`. |
| [`SetTimeUpdatedDateRange`](#settimeupdateddaterange) | Wraps `SteamAPI_ISteamUGC_SetTimeUpdatedDateRange`. |
| [`AddRequiredKeyValueTag`](#addrequiredkeyvaluetag) | Wraps `SteamAPI_ISteamUGC_AddRequiredKeyValueTag`. |
| [`RequestUGCDetails`](#requestugcdetails) | DEPRECATED - Use CreateQueryUGCDetailsRequest call above instead! Call result: `SteamUGCRequestUGCDetailsResult_t` ... |
| [`CreateItem`](#createitem) | Steam Workshop Creator API. Call result: `CreateItemResult_t` (`CreateItemResult_t_k_iCallback`). |
| [`StartItemUpdate`](#startitemupdate) | Wraps `SteamAPI_ISteamUGC_StartItemUpdate`. |
| [`SetItemTitle`](#setitemtitle) | Wraps `SteamAPI_ISteamUGC_SetItemTitle`. |
| [`SetItemDescription`](#setitemdescription) | Wraps `SteamAPI_ISteamUGC_SetItemDescription`. |
| [`SetItemUpdateLanguage`](#setitemupdatelanguage) | Wraps `SteamAPI_ISteamUGC_SetItemUpdateLanguage`. |
| [`SetItemMetadata`](#setitemmetadata) | Wraps `SteamAPI_ISteamUGC_SetItemMetadata`. |
| [`SetItemVisibility`](#setitemvisibility) | Wraps `SteamAPI_ISteamUGC_SetItemVisibility`. |
| [`SetItemTags`](#setitemtags) | Wraps `SteamAPI_ISteamUGC_SetItemTags`. |
| [`SetItemContent`](#setitemcontent) | Wraps `SteamAPI_ISteamUGC_SetItemContent`. |
| [`SetItemPreview`](#setitempreview) | Wraps `SteamAPI_ISteamUGC_SetItemPreview`. |
| [`SetAllowLegacyUpload`](#setallowlegacyupload) | Wraps `SteamAPI_ISteamUGC_SetAllowLegacyUpload`. |
| [`RemoveAllItemKeyValueTags`](#removeallitemkeyvaluetags) | Wraps `SteamAPI_ISteamUGC_RemoveAllItemKeyValueTags`. |
| [`RemoveItemKeyValueTags`](#removeitemkeyvaluetags) | Wraps `SteamAPI_ISteamUGC_RemoveItemKeyValueTags`. |
| [`AddItemKeyValueTag`](#additemkeyvaluetag) | Wraps `SteamAPI_ISteamUGC_AddItemKeyValueTag`. |
| [`AddItemPreviewFile`](#additempreviewfile) | Wraps `SteamAPI_ISteamUGC_AddItemPreviewFile`. |
| [`AddItemPreviewVideo`](#additempreviewvideo) | Wraps `SteamAPI_ISteamUGC_AddItemPreviewVideo`. |
| [`UpdateItemPreviewFile`](#updateitempreviewfile) | Wraps `SteamAPI_ISteamUGC_UpdateItemPreviewFile`. |
| [`UpdateItemPreviewVideo`](#updateitempreviewvideo) | Wraps `SteamAPI_ISteamUGC_UpdateItemPreviewVideo`. |
| [`RemoveItemPreview`](#removeitempreview) | Wraps `SteamAPI_ISteamUGC_RemoveItemPreview`. |
| [`AddContentDescriptor`](#addcontentdescriptor) | Wraps `SteamAPI_ISteamUGC_AddContentDescriptor`. |
| [`RemoveContentDescriptor`](#removecontentdescriptor) | Wraps `SteamAPI_ISteamUGC_RemoveContentDescriptor`. |
| [`SetRequiredGameVersions`](#setrequiredgameversions) | Wraps `SteamAPI_ISteamUGC_SetRequiredGameVersions`. |
| [`SubmitItemUpdate`](#submititemupdate) | Wraps `SteamAPI_ISteamUGC_SubmitItemUpdate`. Call result: `SubmitItemUpdateResult_t` (`SubmitItemUpdateResult_t_k_iCallback`). |
| [`GetItemUpdateProgress`](#getitemupdateprogress) | Wraps `SteamAPI_ISteamUGC_GetItemUpdateProgress`. |
| [`SetUserItemVote`](#setuseritemvote) | Steam Workshop Consumer API. Call result: `SetUserItemVoteResult_t` (`SetUserItemVoteResult_t_k_iCallback`). |
| [`GetUserItemVote`](#getuseritemvote) | Wraps `SteamAPI_ISteamUGC_GetUserItemVote`. Call result: `GetUserItemVoteResult_t` (`GetUserItemVoteResult_t_k_iCallback`). |
| [`AddItemToFavorites`](#additemtofavorites) | Wraps `SteamAPI_ISteamUGC_AddItemToFavorites`. Call result: `UserFavoriteItemsListChanged_t` (`UserFavoriteItemsListChanged_t_k_iCallback`). |
| [`RemoveItemFromFavorites`](#removeitemfromfavorites) | Wraps `SteamAPI_ISteamUGC_RemoveItemFromFavorites`. Call result: `UserFavoriteItemsListChanged_t` (`UserFavoriteItemsListChanged_t_k_iCallback`). |
| [`SubscribeItem`](#subscribeitem) | Wraps `SteamAPI_ISteamUGC_SubscribeItem`. Call result: `RemoteStorageSubscribePublishedFileResult_t` ... |
| [`UnsubscribeItem`](#unsubscribeitem) | Wraps `SteamAPI_ISteamUGC_UnsubscribeItem`. Call result: `RemoteStorageUnsubscribePublishedFileResult_t` ... |
| [`GetNumSubscribedItems`](#getnumsubscribeditems) | Wraps `SteamAPI_ISteamUGC_GetNumSubscribedItems`. |
| [`GetSubscribedItems`](#getsubscribeditems) | Wraps `SteamAPI_ISteamUGC_GetSubscribedItems`. |
| [`GetItemState`](#getitemstate) | get EItemState flags about item on this client. |
| [`GetItemInstallInfo`](#getiteminstallinfo) | get info about currently installed content on disc for items that have k_EItemStateInstalled set if k_EItemStateLegacyItem is set, pchFolder contains the ... |
| [`GetItemDownloadInfo`](#getitemdownloadinfo) | get info about pending update for items that have k_EItemStateNeedsUpdate set. punBytesTotal will be valid after download started once. |
| [`DownloadItem`](#downloaditem) | download new or update already installed item. If function returns true, wait for DownloadItemResult_t. If the item is already installed, then files on disk ... |
| [`BInitWorkshopForGameServer`](#binitworkshopforgameserver) | game servers can set a specific workshop folder before issuing any UGC commands. This is helpful if you want to support multiple game servers running out of ... |
| [`SuspendDownloads`](#suspenddownloads) | SuspendDownloads( true ) will suspend all workshop downloads until SuspendDownloads( false ) is called or the game ends. |
| [`StartPlaytimeTracking`](#startplaytimetracking) | usage tracking. Call result: `StartPlaytimeTrackingResult_t` (`StartPlaytimeTrackingResult_t_k_iCallback`). |
| [`StopPlaytimeTracking`](#stopplaytimetracking) | Wraps `SteamAPI_ISteamUGC_StopPlaytimeTracking`. Call result: `StopPlaytimeTrackingResult_t` (`StopPlaytimeTrackingResult_t_k_iCallback`). |
| [`StopPlaytimeTrackingForAllItems`](#stopplaytimetrackingforallitems) | Wraps `SteamAPI_ISteamUGC_StopPlaytimeTrackingForAllItems`. Call result: `StopPlaytimeTrackingResult_t` (`StopPlaytimeTrackingResult_t_k_iCallback`). |
| [`AddDependency`](#adddependency) | parent-child relationship or dependency management. Call result: `AddUGCDependencyResult_t` (`AddUGCDependencyResult_t_k_iCallback`). |
| [`RemoveDependency`](#removedependency) | Wraps `SteamAPI_ISteamUGC_RemoveDependency`. Call result: `RemoveUGCDependencyResult_t` (`RemoveUGCDependencyResult_t_k_iCallback`). |
| [`AddAppDependency`](#addappdependency) | add/remove app dependence/requirements (usually DLC). Call result: `AddAppDependencyResult_t` (`AddAppDependencyResult_t_k_iCallback`). |
| [`RemoveAppDependency`](#removeappdependency) | Wraps `SteamAPI_ISteamUGC_RemoveAppDependency`. Call result: `RemoveAppDependencyResult_t` (`RemoveAppDependencyResult_t_k_iCallback`). |
| [`GetAppDependencies`](#getappdependencies) | request app dependencies. note that whatever callback you register for GetAppDependenciesResult_t may be called multiple times until all app dependencies ... |
| [`DeleteItem`](#deleteitem) | delete the item without prompting the user. Call result: `DeleteItemResult_t` (`DeleteItemResult_t_k_iCallback`). |
| [`ShowWorkshopEULA`](#showworkshopeula) | Show the app's latest Workshop EULA to the user in an overlay window, where they can accept it or not. |
| [`GetWorkshopEULAStatus`](#getworkshopeulastatus) | Retrieve information related to the user's acceptance or not of the app's specific Workshop EULA. Call result: `WorkshopEULAStatus_t` ... |
| [`GetUserContentDescriptorPreferences`](#getusercontentdescriptorpreferences) | Return the user's community content descriptor preferences. |
| [`SetItemsDisabledLocally`](#setitemsdisabledlocally) | Sets whether the item should be disabled locally or not. This means that it will not be returned in GetSubscribedItems() by default. |
| [`SetSubscriptionsLoadOrder`](#setsubscriptionsloadorder) | Set the local load order for these items. If there are any items not in the given list, they will sort by the time subscribed. |
| [`MarkDownloadedItemAsUnused`](#markdownloadeditemasunused) | Tells the client to no longer try to keep the item in its local cache, unless it was subscribed to by other users on this machine. |
| [`GetNumDownloadedItems`](#getnumdownloadeditems) | Returns the number of items actually downloaded locally. |
| [`GetDownloadedItems`](#getdownloadeditems) | Returns the ids of the items downloaded. |

#### CreateQueryUserUGCRequest

```pascal
function CreateQueryUserUGCRequest(unAccountID: AccountID_t; eListType: EUserUGCList; eMatchingUGCType: EUGCMatchingUGCType; eSortOrder: EUserUGCListSortOrder; nCreatorAppID: AppId_t; nConsumerAppID: AppId_t; unPage: UInt32): UGCQueryHandle_t;
```

Query UGC associated with a user. Creator app id or consumer app id must be valid and be set to the current running app. unPage should start at 1.

#### CreateQueryAllUGCRequestPage

```pascal
function CreateQueryAllUGCRequestPage(eQueryType: EUGCQuery; eMatchingeMatchingUGCTypeFileType: EUGCMatchingUGCType; nCreatorAppID: AppId_t; nConsumerAppID: AppId_t; unPage: UInt32): UGCQueryHandle_t;
```

Query for all matching UGC. Creator app id or consumer app id must be valid and be set to the current running app. unPage should start at 1.

#### CreateQueryAllUGCRequestCursor

```pascal
function CreateQueryAllUGCRequestCursor(eQueryType: EUGCQuery; eMatchingeMatchingUGCTypeFileType: EUGCMatchingUGCType; nCreatorAppID: AppId_t; nConsumerAppID: AppId_t; const pchCursor: string): UGCQueryHandle_t;
```

Query for all matching UGC. Creator app id or consumer app id must be valid and be set to the current running app. unPage should start at 1.

#### CreateQueryUGCDetailsRequest

```pascal
function CreateQueryUGCDetailsRequest(pvecPublishedFileID: Pointer; unNumPublishedFileIDs: UInt32): UGCQueryHandle_t;
```

Query for the details of the given published file ids (the RequestUGCDetails call is deprecated and replaced with this).

#### SendQueryUGCRequest

```pascal
function SendQueryUGCRequest(AHandle: UGCQueryHandle_t): SteamAPICall_t;
```

Send the query to Steam. Call result: `SteamUGCQueryCompleted_t` (`SteamUGCQueryCompleted_t_k_iCallback`).

#### GetQueryUGCResult

```pascal
function GetQueryUGCResult(AHandle: UGCQueryHandle_t; index: UInt32; var pDetails: SteamUGCDetails_t): Boolean;
```

Retrieve an individual result after receiving the callback for querying UGC.

#### GetQueryUGCNumTags

```pascal
function GetQueryUGCNumTags(AHandle: UGCQueryHandle_t; index: UInt32): UInt32;
```

Wraps `SteamAPI_ISteamUGC_GetQueryUGCNumTags`.

#### GetQueryUGCTag

```pascal
function GetQueryUGCTag(AHandle: UGCQueryHandle_t; index: UInt32; indexTag: UInt32; pchValue: PAnsiChar; cchValueSize: UInt32): Boolean;
```

Wraps `SteamAPI_ISteamUGC_GetQueryUGCTag`.

#### GetQueryUGCTagDisplayName

```pascal
function GetQueryUGCTagDisplayName(AHandle: UGCQueryHandle_t; index: UInt32; indexTag: UInt32; pchValue: PAnsiChar; cchValueSize: UInt32): Boolean;
```

Wraps `SteamAPI_ISteamUGC_GetQueryUGCTagDisplayName`.

#### GetQueryUGCPreviewURL

```pascal
function GetQueryUGCPreviewURL(AHandle: UGCQueryHandle_t; index: UInt32; pchURL: PAnsiChar; cchURLSize: UInt32): Boolean;
```

Wraps `SteamAPI_ISteamUGC_GetQueryUGCPreviewURL`.

#### GetQueryUGCMetadata

```pascal
function GetQueryUGCMetadata(AHandle: UGCQueryHandle_t; index: UInt32; pchMetadata: PAnsiChar; cchMetadatasize: UInt32): Boolean;
```

Wraps `SteamAPI_ISteamUGC_GetQueryUGCMetadata`.

#### GetQueryUGCChildren

```pascal
function GetQueryUGCChildren(AHandle: UGCQueryHandle_t; index: UInt32; pvecPublishedFileID: Pointer; cMaxEntries: UInt32): Boolean;
```

Wraps `SteamAPI_ISteamUGC_GetQueryUGCChildren`.

#### GetQueryUGCStatistic

```pascal
function GetQueryUGCStatistic(AHandle: UGCQueryHandle_t; index: UInt32; eStatType: EItemStatistic; var pStatValue: UInt64): Boolean;
```

Wraps `SteamAPI_ISteamUGC_GetQueryUGCStatistic`.

#### GetQueryUGCNumAdditionalPreviews

```pascal
function GetQueryUGCNumAdditionalPreviews(AHandle: UGCQueryHandle_t; index: UInt32): UInt32;
```

Wraps `SteamAPI_ISteamUGC_GetQueryUGCNumAdditionalPreviews`.

#### GetQueryUGCAdditionalPreview

```pascal
function GetQueryUGCAdditionalPreview(AHandle: UGCQueryHandle_t; index: UInt32; previewIndex: UInt32; pchURLOrVideoID: PAnsiChar; cchURLSize: UInt32; pchOriginalFileName: PAnsiChar; cchOriginalFileNameSize: UInt32; var pPreviewType: EItemPreviewType): Boolean;
```

Wraps `SteamAPI_ISteamUGC_GetQueryUGCAdditionalPreview`.

#### GetQueryUGCNumKeyValueTags

```pascal
function GetQueryUGCNumKeyValueTags(AHandle: UGCQueryHandle_t; index: UInt32): UInt32;
```

Wraps `SteamAPI_ISteamUGC_GetQueryUGCNumKeyValueTags`.

#### GetQueryUGCKeyValueTag

```pascal
function GetQueryUGCKeyValueTag(AHandle: UGCQueryHandle_t; index: UInt32; keyValueTagIndex: UInt32; pchKey: PAnsiChar; cchKeySize: UInt32; pchValue: PAnsiChar; cchValueSize: UInt32): Boolean;
```

Wraps `SteamAPI_ISteamUGC_GetQueryUGCKeyValueTag`.

#### GetQueryFirstUGCKeyValueTag

```pascal
function GetQueryFirstUGCKeyValueTag(AHandle: UGCQueryHandle_t; index: UInt32; const pchKey: string; pchValue: PAnsiChar; cchValueSize: UInt32): Boolean;
```

Wraps `SteamAPI_ISteamUGC_GetQueryFirstUGCKeyValueTag`.

#### GetNumSupportedGameVersions

```pascal
function GetNumSupportedGameVersions(AHandle: UGCQueryHandle_t; index: UInt32): UInt32;
```

Some items can specify that they have a version that is valid for a range of game versions (Steam branch).

#### GetSupportedGameVersionData

```pascal
function GetSupportedGameVersionData(AHandle: UGCQueryHandle_t; index: UInt32; versionIndex: UInt32; pchGameBranchMin: PAnsiChar; pchGameBranchMax: PAnsiChar; cchGameBranchSize: UInt32): Boolean;
```

Wraps `SteamAPI_ISteamUGC_GetSupportedGameVersionData`.

#### GetQueryUGCContentDescriptors

```pascal
function GetQueryUGCContentDescriptors(AHandle: UGCQueryHandle_t; index: UInt32; pvecDescriptors: Pointer; cMaxEntries: UInt32): UInt32;
```

Wraps `SteamAPI_ISteamUGC_GetQueryUGCContentDescriptors`.

#### ReleaseQueryUGCRequest

```pascal
function ReleaseQueryUGCRequest(AHandle: UGCQueryHandle_t): Boolean;
```

Release the request to free up memory, after retrieving results.

#### AddRequiredTag

```pascal
function AddRequiredTag(AHandle: UGCQueryHandle_t; const pTagName: string): Boolean;
```

Options to set for querying UGC.

#### AddRequiredTagGroup

```pascal
function AddRequiredTagGroup(AHandle: UGCQueryHandle_t; pTagGroups: Pointer): Boolean;
```

Wraps `SteamAPI_ISteamUGC_AddRequiredTagGroup`.

#### AddExcludedTag

```pascal
function AddExcludedTag(AHandle: UGCQueryHandle_t; const pTagName: string): Boolean;
```

Wraps `SteamAPI_ISteamUGC_AddExcludedTag`.

#### SetReturnOnlyIDs

```pascal
function SetReturnOnlyIDs(AHandle: UGCQueryHandle_t; bReturnOnlyIDs: Boolean): Boolean;
```

Wraps `SteamAPI_ISteamUGC_SetReturnOnlyIDs`.

#### SetReturnKeyValueTags

```pascal
function SetReturnKeyValueTags(AHandle: UGCQueryHandle_t; bReturnKeyValueTags: Boolean): Boolean;
```

Wraps `SteamAPI_ISteamUGC_SetReturnKeyValueTags`.

#### SetReturnLongDescription

```pascal
function SetReturnLongDescription(AHandle: UGCQueryHandle_t; bReturnLongDescription: Boolean): Boolean;
```

Wraps `SteamAPI_ISteamUGC_SetReturnLongDescription`.

#### SetReturnMetadata

```pascal
function SetReturnMetadata(AHandle: UGCQueryHandle_t; bReturnMetadata: Boolean): Boolean;
```

Wraps `SteamAPI_ISteamUGC_SetReturnMetadata`.

#### SetReturnChildren

```pascal
function SetReturnChildren(AHandle: UGCQueryHandle_t; bReturnChildren: Boolean): Boolean;
```

Wraps `SteamAPI_ISteamUGC_SetReturnChildren`.

#### SetReturnAdditionalPreviews

```pascal
function SetReturnAdditionalPreviews(AHandle: UGCQueryHandle_t; bReturnAdditionalPreviews: Boolean): Boolean;
```

Wraps `SteamAPI_ISteamUGC_SetReturnAdditionalPreviews`.

#### SetReturnTotalOnly

```pascal
function SetReturnTotalOnly(AHandle: UGCQueryHandle_t; bReturnTotalOnly: Boolean): Boolean;
```

Wraps `SteamAPI_ISteamUGC_SetReturnTotalOnly`.

#### SetReturnPlaytimeStats

```pascal
function SetReturnPlaytimeStats(AHandle: UGCQueryHandle_t; unDays: UInt32): Boolean;
```

Wraps `SteamAPI_ISteamUGC_SetReturnPlaytimeStats`.

#### SetLanguage

```pascal
function SetLanguage(AHandle: UGCQueryHandle_t; const pchLanguage: string): Boolean;
```

Wraps `SteamAPI_ISteamUGC_SetLanguage`.

#### SetAllowCachedResponse

```pascal
function SetAllowCachedResponse(AHandle: UGCQueryHandle_t; unMaxAgeSeconds: UInt32): Boolean;
```

Wraps `SteamAPI_ISteamUGC_SetAllowCachedResponse`.

#### SetAdminQuery

```pascal
function SetAdminQuery(AHandle: UGCUpdateHandle_t; bAdminQuery: Boolean): Boolean;
```

Wraps `SteamAPI_ISteamUGC_SetAdminQuery`.

#### SetCloudFileNameFilter

```pascal
function SetCloudFileNameFilter(AHandle: UGCQueryHandle_t; const pMatchCloudFileName: string): Boolean;
```

Options only for querying user UGC.

#### SetMatchAnyTag

```pascal
function SetMatchAnyTag(AHandle: UGCQueryHandle_t; bMatchAnyTag: Boolean): Boolean;
```

Options only for querying all UGC.

#### SetSearchText

```pascal
function SetSearchText(AHandle: UGCQueryHandle_t; const pSearchText: string): Boolean;
```

Wraps `SteamAPI_ISteamUGC_SetSearchText`.

#### SetRankedByTrendDays

```pascal
function SetRankedByTrendDays(AHandle: UGCQueryHandle_t; unDays: UInt32): Boolean;
```

Wraps `SteamAPI_ISteamUGC_SetRankedByTrendDays`.

#### SetTimeCreatedDateRange

```pascal
function SetTimeCreatedDateRange(AHandle: UGCQueryHandle_t; rtStart: RTime32; rtEnd: RTime32): Boolean;
```

Wraps `SteamAPI_ISteamUGC_SetTimeCreatedDateRange`.

#### SetTimeUpdatedDateRange

```pascal
function SetTimeUpdatedDateRange(AHandle: UGCQueryHandle_t; rtStart: RTime32; rtEnd: RTime32): Boolean;
```

Wraps `SteamAPI_ISteamUGC_SetTimeUpdatedDateRange`.

#### AddRequiredKeyValueTag

```pascal
function AddRequiredKeyValueTag(AHandle: UGCQueryHandle_t; const pKey: string; const pValue: string): Boolean;
```

Wraps `SteamAPI_ISteamUGC_AddRequiredKeyValueTag`.

#### RequestUGCDetails

```pascal
function RequestUGCDetails(nPublishedFileID: PublishedFileId_t; unMaxAgeSeconds: UInt32): SteamAPICall_t;
```

DEPRECATED - Use CreateQueryUGCDetailsRequest call above instead! Call result: `SteamUGCRequestUGCDetailsResult_t` (`SteamUGCRequestUGCDetailsResult_t_k_iCallback`).

#### CreateItem

```pascal
function CreateItem(nConsumerAppId: AppId_t; eFileType: EWorkshopFileType): SteamAPICall_t;
```

Steam Workshop Creator API. Call result: `CreateItemResult_t` (`CreateItemResult_t_k_iCallback`).

#### StartItemUpdate

```pascal
function StartItemUpdate(nConsumerAppId: AppId_t; nPublishedFileID: PublishedFileId_t): UGCUpdateHandle_t;
```

Wraps `SteamAPI_ISteamUGC_StartItemUpdate`.

#### SetItemTitle

```pascal
function SetItemTitle(AHandle: UGCUpdateHandle_t; const pchTitle: string): Boolean;
```

Wraps `SteamAPI_ISteamUGC_SetItemTitle`.

#### SetItemDescription

```pascal
function SetItemDescription(AHandle: UGCUpdateHandle_t; const pchDescription: string): Boolean;
```

Wraps `SteamAPI_ISteamUGC_SetItemDescription`.

#### SetItemUpdateLanguage

```pascal
function SetItemUpdateLanguage(AHandle: UGCUpdateHandle_t; const pchLanguage: string): Boolean;
```

Wraps `SteamAPI_ISteamUGC_SetItemUpdateLanguage`.

#### SetItemMetadata

```pascal
function SetItemMetadata(AHandle: UGCUpdateHandle_t; const pchMetaData: string): Boolean;
```

Wraps `SteamAPI_ISteamUGC_SetItemMetadata`.

#### SetItemVisibility

```pascal
function SetItemVisibility(AHandle: UGCUpdateHandle_t; eVisibility: ERemoteStoragePublishedFileVisibility): Boolean;
```

Wraps `SteamAPI_ISteamUGC_SetItemVisibility`.

#### SetItemTags

```pascal
function SetItemTags(updateHandle: UGCUpdateHandle_t; pTags: Pointer; bAllowAdminTags: Boolean): Boolean;
```

Wraps `SteamAPI_ISteamUGC_SetItemTags`.

#### SetItemContent

```pascal
function SetItemContent(AHandle: UGCUpdateHandle_t; const pszContentFolder: string): Boolean;
```

Wraps `SteamAPI_ISteamUGC_SetItemContent`.

#### SetItemPreview

```pascal
function SetItemPreview(AHandle: UGCUpdateHandle_t; const pszPreviewFile: string): Boolean;
```

Wraps `SteamAPI_ISteamUGC_SetItemPreview`.

#### SetAllowLegacyUpload

```pascal
function SetAllowLegacyUpload(AHandle: UGCUpdateHandle_t; bAllowLegacyUpload: Boolean): Boolean;
```

Wraps `SteamAPI_ISteamUGC_SetAllowLegacyUpload`.

#### RemoveAllItemKeyValueTags

```pascal
function RemoveAllItemKeyValueTags(AHandle: UGCUpdateHandle_t): Boolean;
```

Wraps `SteamAPI_ISteamUGC_RemoveAllItemKeyValueTags`.

#### RemoveItemKeyValueTags

```pascal
function RemoveItemKeyValueTags(AHandle: UGCUpdateHandle_t; const pchKey: string): Boolean;
```

Wraps `SteamAPI_ISteamUGC_RemoveItemKeyValueTags`.

#### AddItemKeyValueTag

```pascal
function AddItemKeyValueTag(AHandle: UGCUpdateHandle_t; const pchKey: string; const pchValue: string): Boolean;
```

Wraps `SteamAPI_ISteamUGC_AddItemKeyValueTag`.

#### AddItemPreviewFile

```pascal
function AddItemPreviewFile(AHandle: UGCUpdateHandle_t; const pszPreviewFile: string; AType: EItemPreviewType): Boolean;
```

Wraps `SteamAPI_ISteamUGC_AddItemPreviewFile`.

#### AddItemPreviewVideo

```pascal
function AddItemPreviewVideo(AHandle: UGCUpdateHandle_t; const pszVideoID: string): Boolean;
```

Wraps `SteamAPI_ISteamUGC_AddItemPreviewVideo`.

#### UpdateItemPreviewFile

```pascal
function UpdateItemPreviewFile(AHandle: UGCUpdateHandle_t; index: UInt32; const pszPreviewFile: string): Boolean;
```

Wraps `SteamAPI_ISteamUGC_UpdateItemPreviewFile`.

#### UpdateItemPreviewVideo

```pascal
function UpdateItemPreviewVideo(AHandle: UGCUpdateHandle_t; index: UInt32; const pszVideoID: string): Boolean;
```

Wraps `SteamAPI_ISteamUGC_UpdateItemPreviewVideo`.

#### RemoveItemPreview

```pascal
function RemoveItemPreview(AHandle: UGCUpdateHandle_t; index: UInt32): Boolean;
```

Wraps `SteamAPI_ISteamUGC_RemoveItemPreview`.

#### AddContentDescriptor

```pascal
function AddContentDescriptor(AHandle: UGCUpdateHandle_t; descid: EUGCContentDescriptorID): Boolean;
```

Wraps `SteamAPI_ISteamUGC_AddContentDescriptor`.

#### RemoveContentDescriptor

```pascal
function RemoveContentDescriptor(AHandle: UGCUpdateHandle_t; descid: EUGCContentDescriptorID): Boolean;
```

Wraps `SteamAPI_ISteamUGC_RemoveContentDescriptor`.

#### SetRequiredGameVersions

```pascal
function SetRequiredGameVersions(AHandle: UGCUpdateHandle_t; const pszGameBranchMin: string; const pszGameBranchMax: string): Boolean;
```

Wraps `SteamAPI_ISteamUGC_SetRequiredGameVersions`.

#### SubmitItemUpdate

```pascal
function SubmitItemUpdate(AHandle: UGCUpdateHandle_t; const pchChangeNote: string): SteamAPICall_t;
```

Wraps `SteamAPI_ISteamUGC_SubmitItemUpdate`. Call result: `SubmitItemUpdateResult_t` (`SubmitItemUpdateResult_t_k_iCallback`).

#### GetItemUpdateProgress

```pascal
function GetItemUpdateProgress(AHandle: UGCUpdateHandle_t; var punBytesProcessed: UInt64; var punBytesTotal: UInt64): EItemUpdateStatus;
```

Wraps `SteamAPI_ISteamUGC_GetItemUpdateProgress`.

#### SetUserItemVote

```pascal
function SetUserItemVote(nPublishedFileID: PublishedFileId_t; bVoteUp: Boolean): SteamAPICall_t;
```

Steam Workshop Consumer API. Call result: `SetUserItemVoteResult_t` (`SetUserItemVoteResult_t_k_iCallback`).

#### GetUserItemVote

```pascal
function GetUserItemVote(nPublishedFileID: PublishedFileId_t): SteamAPICall_t;
```

Wraps `SteamAPI_ISteamUGC_GetUserItemVote`. Call result: `GetUserItemVoteResult_t` (`GetUserItemVoteResult_t_k_iCallback`).

#### AddItemToFavorites

```pascal
function AddItemToFavorites(nAppId: AppId_t; nPublishedFileID: PublishedFileId_t): SteamAPICall_t;
```

Wraps `SteamAPI_ISteamUGC_AddItemToFavorites`. Call result: `UserFavoriteItemsListChanged_t` (`UserFavoriteItemsListChanged_t_k_iCallback`).

#### RemoveItemFromFavorites

```pascal
function RemoveItemFromFavorites(nAppId: AppId_t; nPublishedFileID: PublishedFileId_t): SteamAPICall_t;
```

Wraps `SteamAPI_ISteamUGC_RemoveItemFromFavorites`. Call result: `UserFavoriteItemsListChanged_t` (`UserFavoriteItemsListChanged_t_k_iCallback`).

#### SubscribeItem

```pascal
function SubscribeItem(nPublishedFileID: PublishedFileId_t): SteamAPICall_t;
```

Wraps `SteamAPI_ISteamUGC_SubscribeItem`. Call result: `RemoteStorageSubscribePublishedFileResult_t` (`RemoteStorageSubscribePublishedFileResult_t_k_iCallback`).

#### UnsubscribeItem

```pascal
function UnsubscribeItem(nPublishedFileID: PublishedFileId_t): SteamAPICall_t;
```

Wraps `SteamAPI_ISteamUGC_UnsubscribeItem`. Call result: `RemoteStorageUnsubscribePublishedFileResult_t` (`RemoteStorageUnsubscribePublishedFileResult_t_k_iCallback`).

#### GetNumSubscribedItems

```pascal
function GetNumSubscribedItems(bIncludeLocallyDisabled: Boolean): UInt32;
```

Wraps `SteamAPI_ISteamUGC_GetNumSubscribedItems`.

#### GetSubscribedItems

```pascal
function GetSubscribedItems(pvecPublishedFileID: Pointer; cMaxEntries: UInt32; bIncludeLocallyDisabled: Boolean): UInt32;
```

Wraps `SteamAPI_ISteamUGC_GetSubscribedItems`.

#### GetItemState

```pascal
function GetItemState(nPublishedFileID: PublishedFileId_t): UInt32;
```

get EItemState flags about item on this client.

#### GetItemInstallInfo

```pascal
function GetItemInstallInfo(nPublishedFileID: PublishedFileId_t; var punSizeOnDisk: UInt64; pchFolder: PAnsiChar; cchFolderSize: UInt32; var punTimeStamp: UInt32): Boolean;
```

get info about currently installed content on disc for items that have k_EItemStateInstalled set if k_EItemStateLegacyItem is set, pchFolder contains the path to the legacy file itself (not a folder).

#### GetItemDownloadInfo

```pascal
function GetItemDownloadInfo(nPublishedFileID: PublishedFileId_t; var punBytesDownloaded: UInt64; var punBytesTotal: UInt64): Boolean;
```

get info about pending update for items that have k_EItemStateNeedsUpdate set. punBytesTotal will be valid after download started once.

#### DownloadItem

```pascal
function DownloadItem(nPublishedFileID: PublishedFileId_t; bHighPriority: Boolean): Boolean;
```

download new or update already installed item. If function returns true, wait for DownloadItemResult_t. If the item is already installed, then files on disk should not be used until callback received. If item is not subscribed to, it will be cached for some time. If bHighPriority is set, any other item download will be suspended and this item downloaded ASAP.

#### BInitWorkshopForGameServer

```pascal
function BInitWorkshopForGameServer(unWorkshopDepotID: DepotId_t; const pszFolder: string): Boolean;
```

game servers can set a specific workshop folder before issuing any UGC commands. This is helpful if you want to support multiple game servers running out of the same install folder.

#### SuspendDownloads

```pascal
procedure SuspendDownloads(bSuspend: Boolean);
```

SuspendDownloads( true ) will suspend all workshop downloads until SuspendDownloads( false ) is called or the game ends.

#### StartPlaytimeTracking

```pascal
function StartPlaytimeTracking(pvecPublishedFileID: Pointer; unNumPublishedFileIDs: UInt32): SteamAPICall_t;
```

usage tracking. Call result: `StartPlaytimeTrackingResult_t` (`StartPlaytimeTrackingResult_t_k_iCallback`).

#### StopPlaytimeTracking

```pascal
function StopPlaytimeTracking(pvecPublishedFileID: Pointer; unNumPublishedFileIDs: UInt32): SteamAPICall_t;
```

Wraps `SteamAPI_ISteamUGC_StopPlaytimeTracking`. Call result: `StopPlaytimeTrackingResult_t` (`StopPlaytimeTrackingResult_t_k_iCallback`).

#### StopPlaytimeTrackingForAllItems

```pascal
function StopPlaytimeTrackingForAllItems: SteamAPICall_t;
```

Wraps `SteamAPI_ISteamUGC_StopPlaytimeTrackingForAllItems`. Call result: `StopPlaytimeTrackingResult_t` (`StopPlaytimeTrackingResult_t_k_iCallback`).

#### AddDependency

```pascal
function AddDependency(nParentPublishedFileID: PublishedFileId_t; nChildPublishedFileID: PublishedFileId_t): SteamAPICall_t;
```

parent-child relationship or dependency management. Call result: `AddUGCDependencyResult_t` (`AddUGCDependencyResult_t_k_iCallback`).

#### RemoveDependency

```pascal
function RemoveDependency(nParentPublishedFileID: PublishedFileId_t; nChildPublishedFileID: PublishedFileId_t): SteamAPICall_t;
```

Wraps `SteamAPI_ISteamUGC_RemoveDependency`. Call result: `RemoveUGCDependencyResult_t` (`RemoveUGCDependencyResult_t_k_iCallback`).

#### AddAppDependency

```pascal
function AddAppDependency(nPublishedFileID: PublishedFileId_t; nAppID: AppId_t): SteamAPICall_t;
```

add/remove app dependence/requirements (usually DLC). Call result: `AddAppDependencyResult_t` (`AddAppDependencyResult_t_k_iCallback`).

#### RemoveAppDependency

```pascal
function RemoveAppDependency(nPublishedFileID: PublishedFileId_t; nAppID: AppId_t): SteamAPICall_t;
```

Wraps `SteamAPI_ISteamUGC_RemoveAppDependency`. Call result: `RemoveAppDependencyResult_t` (`RemoveAppDependencyResult_t_k_iCallback`).

#### GetAppDependencies

```pascal
function GetAppDependencies(nPublishedFileID: PublishedFileId_t): SteamAPICall_t;
```

request app dependencies. note that whatever callback you register for GetAppDependenciesResult_t may be called multiple times until all app dependencies have been returned. Call result: `GetAppDependenciesResult_t` (`GetAppDependenciesResult_t_k_iCallback`).

#### DeleteItem

```pascal
function DeleteItem(nPublishedFileID: PublishedFileId_t): SteamAPICall_t;
```

delete the item without prompting the user. Call result: `DeleteItemResult_t` (`DeleteItemResult_t_k_iCallback`).

#### ShowWorkshopEULA

```pascal
function ShowWorkshopEULA: Boolean;
```

Show the app's latest Workshop EULA to the user in an overlay window, where they can accept it or not.

#### GetWorkshopEULAStatus

```pascal
function GetWorkshopEULAStatus: SteamAPICall_t;
```

Retrieve information related to the user's acceptance or not of the app's specific Workshop EULA. Call result: `WorkshopEULAStatus_t` (`WorkshopEULAStatus_t_k_iCallback`).

#### GetUserContentDescriptorPreferences

```pascal
function GetUserContentDescriptorPreferences(pvecDescriptors: Pointer; cMaxEntries: UInt32): UInt32;
```

Return the user's community content descriptor preferences.

#### SetItemsDisabledLocally

```pascal
function SetItemsDisabledLocally(pvecPublishedFileIDs: Pointer; unNumPublishedFileIDs: UInt32; bDisabledLocally: Boolean): Boolean;
```

Sets whether the item should be disabled locally or not. This means that it will not be returned in GetSubscribedItems() by default.

#### SetSubscriptionsLoadOrder

```pascal
function SetSubscriptionsLoadOrder(pvecPublishedFileIDs: Pointer; unNumPublishedFileIDs: UInt32): Boolean;
```

Set the local load order for these items. If there are any items not in the given list, they will sort by the time subscribed.

#### MarkDownloadedItemAsUnused

```pascal
function MarkDownloadedItemAsUnused(nPublishedFileID: PublishedFileId_t): Boolean;
```

Tells the client to no longer try to keep the item in its local cache, unless it was subscribed to by other users on this machine.

#### GetNumDownloadedItems

```pascal
function GetNumDownloadedItems: UInt32;
```

Returns the number of items actually downloaded locally.

#### GetDownloadedItems

```pascal
function GetDownloadedItems(pvecPublishedFileIDs: Pointer; cMaxEntries: UInt32): UInt32;
```

Returns the ids of the items downloaded.

### Async methods

Each `...Async` method starts the call and registers `AHandler` for its result
(`procedure(const AData: TSteamCallbackData; AIOFailure: Boolean) of object`). The
handler runs once, on the delivery thread, with the result record in `AData`
(`AData.CopyTo(Rec, SizeOf(Rec))`); its object owns the registration - call
`Steam.Dispatcher.RemoveOwner(Self)` in that object's destructor. The plain method of
the same name returns the `SteamAPICall_t` instead, and its result reaches the
component's event.

#### SendQueryUGCRequestAsync

```pascal
function SendQueryUGCRequestAsync(AHandle: UGCQueryHandle_t; AHandler: TSteamCallResultEvent): SteamAPICall_t;
```

Calls `SendQueryUGCRequest` and registers AHandler for its result (`SteamUGCQueryCompleted_t`). The handler's object owns the registration (remove it with Steam.Dispatcher.RemoveOwner). Returns: (The call handle, or k_uAPICallInvalid when Steam refused the call.)

#### RequestUGCDetailsAsync

```pascal
function RequestUGCDetailsAsync(nPublishedFileID: PublishedFileId_t; unMaxAgeSeconds: UInt32; AHandler: TSteamCallResultEvent): SteamAPICall_t;
```

Calls `RequestUGCDetails` and registers AHandler for its result (`SteamUGCRequestUGCDetailsResult_t`). The handler's object owns the registration (remove it with Steam.Dispatcher.RemoveOwner). Returns: (The call handle, or k_uAPICallInvalid when Steam refused the call.)

#### CreateItemAsync

```pascal
function CreateItemAsync(nConsumerAppId: AppId_t; eFileType: EWorkshopFileType; AHandler: TSteamCallResultEvent): SteamAPICall_t;
```

Calls `CreateItem` and registers AHandler for its result (`CreateItemResult_t`). The handler's object owns the registration (remove it with Steam.Dispatcher.RemoveOwner). Returns: (The call handle, or k_uAPICallInvalid when Steam refused the call.)

#### SubmitItemUpdateAsync

```pascal
function SubmitItemUpdateAsync(AHandle: UGCUpdateHandle_t; const pchChangeNote: string; AHandler: TSteamCallResultEvent): SteamAPICall_t;
```

Calls `SubmitItemUpdate` and registers AHandler for its result (`SubmitItemUpdateResult_t`). The handler's object owns the registration (remove it with Steam.Dispatcher.RemoveOwner). Returns: (The call handle, or k_uAPICallInvalid when Steam refused the call.)

#### SetUserItemVoteAsync

```pascal
function SetUserItemVoteAsync(nPublishedFileID: PublishedFileId_t; bVoteUp: Boolean; AHandler: TSteamCallResultEvent): SteamAPICall_t;
```

Calls `SetUserItemVote` and registers AHandler for its result (`SetUserItemVoteResult_t`). The handler's object owns the registration (remove it with Steam.Dispatcher.RemoveOwner). Returns: (The call handle, or k_uAPICallInvalid when Steam refused the call.)

#### GetUserItemVoteAsync

```pascal
function GetUserItemVoteAsync(nPublishedFileID: PublishedFileId_t; AHandler: TSteamCallResultEvent): SteamAPICall_t;
```

Calls `GetUserItemVote` and registers AHandler for its result (`GetUserItemVoteResult_t`). The handler's object owns the registration (remove it with Steam.Dispatcher.RemoveOwner). Returns: (The call handle, or k_uAPICallInvalid when Steam refused the call.)

#### AddItemToFavoritesAsync

```pascal
function AddItemToFavoritesAsync(nAppId: AppId_t; nPublishedFileID: PublishedFileId_t; AHandler: TSteamCallResultEvent): SteamAPICall_t;
```

Calls `AddItemToFavorites` and registers AHandler for its result (`UserFavoriteItemsListChanged_t`). The handler's object owns the registration (remove it with Steam.Dispatcher.RemoveOwner). Returns: (The call handle, or k_uAPICallInvalid when Steam refused the call.)

#### RemoveItemFromFavoritesAsync

```pascal
function RemoveItemFromFavoritesAsync(nAppId: AppId_t; nPublishedFileID: PublishedFileId_t; AHandler: TSteamCallResultEvent): SteamAPICall_t;
```

Calls `RemoveItemFromFavorites` and registers AHandler for its result (`UserFavoriteItemsListChanged_t`). The handler's object owns the registration (remove it with Steam.Dispatcher.RemoveOwner). Returns: (The call handle, or k_uAPICallInvalid when Steam refused the call.)

#### SubscribeItemAsync

```pascal
function SubscribeItemAsync(nPublishedFileID: PublishedFileId_t; AHandler: TSteamCallResultEvent): SteamAPICall_t;
```

Calls `SubscribeItem` and registers AHandler for its result (`RemoteStorageSubscribePublishedFileResult_t`). The handler's object owns the registration (remove it with Steam.Dispatcher.RemoveOwner). Returns: (The call handle, or k_uAPICallInvalid when Steam refused the call.)

#### UnsubscribeItemAsync

```pascal
function UnsubscribeItemAsync(nPublishedFileID: PublishedFileId_t; AHandler: TSteamCallResultEvent): SteamAPICall_t;
```

Calls `UnsubscribeItem` and registers AHandler for its result (`RemoteStorageUnsubscribePublishedFileResult_t`). The handler's object owns the registration (remove it with Steam.Dispatcher.RemoveOwner). Returns: (The call handle, or k_uAPICallInvalid when Steam refused the call.)

#### StartPlaytimeTrackingAsync

```pascal
function StartPlaytimeTrackingAsync(pvecPublishedFileID: Pointer; unNumPublishedFileIDs: UInt32; AHandler: TSteamCallResultEvent): SteamAPICall_t;
```

Calls `StartPlaytimeTracking` and registers AHandler for its result (`StartPlaytimeTrackingResult_t`). The handler's object owns the registration (remove it with Steam.Dispatcher.RemoveOwner). Returns: (The call handle, or k_uAPICallInvalid when Steam refused the call.)

#### StopPlaytimeTrackingAsync

```pascal
function StopPlaytimeTrackingAsync(pvecPublishedFileID: Pointer; unNumPublishedFileIDs: UInt32; AHandler: TSteamCallResultEvent): SteamAPICall_t;
```

Calls `StopPlaytimeTracking` and registers AHandler for its result (`StopPlaytimeTrackingResult_t`). The handler's object owns the registration (remove it with Steam.Dispatcher.RemoveOwner). Returns: (The call handle, or k_uAPICallInvalid when Steam refused the call.)

#### StopPlaytimeTrackingForAllItemsAsync

```pascal
function StopPlaytimeTrackingForAllItemsAsync(AHandler: TSteamCallResultEvent): SteamAPICall_t;
```

Calls `StopPlaytimeTrackingForAllItems` and registers AHandler for its result (`StopPlaytimeTrackingResult_t`). The handler's object owns the registration (remove it with Steam.Dispatcher.RemoveOwner). Returns: (The call handle, or k_uAPICallInvalid when Steam refused the call.)

#### AddDependencyAsync

```pascal
function AddDependencyAsync(nParentPublishedFileID: PublishedFileId_t; nChildPublishedFileID: PublishedFileId_t; AHandler: TSteamCallResultEvent): SteamAPICall_t;
```

Calls `AddDependency` and registers AHandler for its result (`AddUGCDependencyResult_t`). The handler's object owns the registration (remove it with Steam.Dispatcher.RemoveOwner). Returns: (The call handle, or k_uAPICallInvalid when Steam refused the call.)

#### RemoveDependencyAsync

```pascal
function RemoveDependencyAsync(nParentPublishedFileID: PublishedFileId_t; nChildPublishedFileID: PublishedFileId_t; AHandler: TSteamCallResultEvent): SteamAPICall_t;
```

Calls `RemoveDependency` and registers AHandler for its result (`RemoveUGCDependencyResult_t`). The handler's object owns the registration (remove it with Steam.Dispatcher.RemoveOwner). Returns: (The call handle, or k_uAPICallInvalid when Steam refused the call.)

#### AddAppDependencyAsync

```pascal
function AddAppDependencyAsync(nPublishedFileID: PublishedFileId_t; nAppID: AppId_t; AHandler: TSteamCallResultEvent): SteamAPICall_t;
```

Calls `AddAppDependency` and registers AHandler for its result (`AddAppDependencyResult_t`). The handler's object owns the registration (remove it with Steam.Dispatcher.RemoveOwner). Returns: (The call handle, or k_uAPICallInvalid when Steam refused the call.)

#### RemoveAppDependencyAsync

```pascal
function RemoveAppDependencyAsync(nPublishedFileID: PublishedFileId_t; nAppID: AppId_t; AHandler: TSteamCallResultEvent): SteamAPICall_t;
```

Calls `RemoveAppDependency` and registers AHandler for its result (`RemoveAppDependencyResult_t`). The handler's object owns the registration (remove it with Steam.Dispatcher.RemoveOwner). Returns: (The call handle, or k_uAPICallInvalid when Steam refused the call.)

#### GetAppDependenciesAsync

```pascal
function GetAppDependenciesAsync(nPublishedFileID: PublishedFileId_t; AHandler: TSteamCallResultEvent): SteamAPICall_t;
```

Calls `GetAppDependencies` and registers AHandler for its result (`GetAppDependenciesResult_t`). The handler's object owns the registration (remove it with Steam.Dispatcher.RemoveOwner). Returns: (The call handle, or k_uAPICallInvalid when Steam refused the call.)

#### DeleteItemAsync

```pascal
function DeleteItemAsync(nPublishedFileID: PublishedFileId_t; AHandler: TSteamCallResultEvent): SteamAPICall_t;
```

Calls `DeleteItem` and registers AHandler for its result (`DeleteItemResult_t`). The handler's object owns the registration (remove it with Steam.Dispatcher.RemoveOwner). Returns: (The call handle, or k_uAPICallInvalid when Steam refused the call.)

#### GetWorkshopEULAStatusAsync

```pascal
function GetWorkshopEULAStatusAsync(AHandler: TSteamCallResultEvent): SteamAPICall_t;
```

Calls `GetWorkshopEULAStatus` and registers AHandler for its result (`WorkshopEULAStatus_t`). The handler's object owns the registration (remove it with Steam.Dispatcher.RemoveOwner). Returns: (The call handle, or k_uAPICallInvalid when Steam refused the call.)

### Properties

| Property | Description |
|----------|-------------|
| `Handle: Pointer` | The raw ISteamUGC pointer (first argument of every `Flat` export). |
| `Flat: TSteamUGCFlat` | The bound flat exports, for calls the methods do not cover. |

## Payload records

Declared in `Steamworks.SDKTypes` (generated from the SDK headers; layouts verified
against the C headers for Win64, Win32, Linux64 and macOS ARM64).

### SteamUGCQueryCompleted_t

Callback id 3401 (`SteamUGCQueryCompleted_t_k_iCallback`).

| Field | C declaration |
|-------|---------------|
| `m_handle: UGCQueryHandle_t` | C field `UGCQueryHandle_t m_handle`. |
| `m_eResult: EResult` | C field `EResult m_eResult`. |
| `m_unNumResultsReturned: UInt32` | C field `uint32 m_unNumResultsReturned`. |
| `m_unTotalMatchingResults: UInt32` | C field `uint32 m_unTotalMatchingResults`. |
| `m_bCachedData: Boolean` | C field `bool m_bCachedData`. |
| `m_rgchNextCursor: array[0..255] of AnsiChar` | C field `char [256] m_rgchNextCursor`. |

### SteamUGCRequestUGCDetailsResult_t

Callback id 3402 (`SteamUGCRequestUGCDetailsResult_t_k_iCallback`).

| Field | C declaration |
|-------|---------------|
| `m_details: SteamUGCDetails_t` | C field `SteamUGCDetails_t m_details`. |
| `m_bCachedData: Boolean` | C field `bool m_bCachedData`. |

### CreateItemResult_t

Callback id 3403 (`CreateItemResult_t_k_iCallback`).

| Field | C declaration |
|-------|---------------|
| `m_eResult: EResult` | C field `EResult m_eResult`. |
| `m_nPublishedFileId: PublishedFileId_t` | C field `PublishedFileId_t m_nPublishedFileId`. |
| `m_bUserNeedsToAcceptWorkshopLegalAgreement: Boolean` | C field `bool m_bUserNeedsToAcceptWorkshopLegalAgreement`. |

### SubmitItemUpdateResult_t

Callback id 3404 (`SubmitItemUpdateResult_t_k_iCallback`).

| Field | C declaration |
|-------|---------------|
| `m_eResult: EResult` | C field `EResult m_eResult`. |
| `m_bUserNeedsToAcceptWorkshopLegalAgreement: Boolean` | C field `bool m_bUserNeedsToAcceptWorkshopLegalAgreement`. |
| `m_nPublishedFileId: PublishedFileId_t` | C field `PublishedFileId_t m_nPublishedFileId`. |

### ItemInstalled_t

Callback id 3405 (`ItemInstalled_t_k_iCallback`).

| Field | C declaration |
|-------|---------------|
| `m_unAppID: AppId_t` | C field `AppId_t m_unAppID`. |
| `m_nPublishedFileId: PublishedFileId_t` | C field `PublishedFileId_t m_nPublishedFileId`. |
| `m_hLegacyContent: UGCHandle_t` | C field `UGCHandle_t m_hLegacyContent`. |
| `m_unManifestID: UInt64` | C field `uint64 m_unManifestID`. |

### DownloadItemResult_t

Callback id 3406 (`DownloadItemResult_t_k_iCallback`).

| Field | C declaration |
|-------|---------------|
| `m_unAppID: AppId_t` | C field `AppId_t m_unAppID`. |
| `m_nPublishedFileId: PublishedFileId_t` | C field `PublishedFileId_t m_nPublishedFileId`. |
| `m_eResult: EResult` | C field `EResult m_eResult`. |

### UserFavoriteItemsListChanged_t

Callback id 3407 (`UserFavoriteItemsListChanged_t_k_iCallback`).

| Field | C declaration |
|-------|---------------|
| `m_nPublishedFileId: PublishedFileId_t` | C field `PublishedFileId_t m_nPublishedFileId`. |
| `m_eResult: EResult` | C field `EResult m_eResult`. |
| `m_bWasAddRequest: Boolean` | C field `bool m_bWasAddRequest`. |

### SetUserItemVoteResult_t

Callback id 3408 (`SetUserItemVoteResult_t_k_iCallback`).

| Field | C declaration |
|-------|---------------|
| `m_nPublishedFileId: PublishedFileId_t` | C field `PublishedFileId_t m_nPublishedFileId`. |
| `m_eResult: EResult` | C field `EResult m_eResult`. |
| `m_bVoteUp: Boolean` | C field `bool m_bVoteUp`. |

### GetUserItemVoteResult_t

Callback id 3409 (`GetUserItemVoteResult_t_k_iCallback`).

| Field | C declaration |
|-------|---------------|
| `m_nPublishedFileId: PublishedFileId_t` | C field `PublishedFileId_t m_nPublishedFileId`. |
| `m_eResult: EResult` | C field `EResult m_eResult`. |
| `m_bVotedUp: Boolean` | C field `bool m_bVotedUp`. |
| `m_bVotedDown: Boolean` | C field `bool m_bVotedDown`. |
| `m_bVoteSkipped: Boolean` | C field `bool m_bVoteSkipped`. |

### StartPlaytimeTrackingResult_t

Callback id 3410 (`StartPlaytimeTrackingResult_t_k_iCallback`).

| Field | C declaration |
|-------|---------------|
| `m_eResult: EResult` | C field `EResult m_eResult`. |

### StopPlaytimeTrackingResult_t

Callback id 3411 (`StopPlaytimeTrackingResult_t_k_iCallback`).

| Field | C declaration |
|-------|---------------|
| `m_eResult: EResult` | C field `EResult m_eResult`. |

### AddUGCDependencyResult_t

Callback id 3412 (`AddUGCDependencyResult_t_k_iCallback`).

| Field | C declaration |
|-------|---------------|
| `m_eResult: EResult` | C field `EResult m_eResult`. |
| `m_nPublishedFileId: PublishedFileId_t` | C field `PublishedFileId_t m_nPublishedFileId`. |
| `m_nChildPublishedFileId: PublishedFileId_t` | C field `PublishedFileId_t m_nChildPublishedFileId`. |

### RemoveUGCDependencyResult_t

Callback id 3413 (`RemoveUGCDependencyResult_t_k_iCallback`).

| Field | C declaration |
|-------|---------------|
| `m_eResult: EResult` | C field `EResult m_eResult`. |
| `m_nPublishedFileId: PublishedFileId_t` | C field `PublishedFileId_t m_nPublishedFileId`. |
| `m_nChildPublishedFileId: PublishedFileId_t` | C field `PublishedFileId_t m_nChildPublishedFileId`. |

### AddAppDependencyResult_t

Callback id 3414 (`AddAppDependencyResult_t_k_iCallback`).

| Field | C declaration |
|-------|---------------|
| `m_eResult: EResult` | C field `EResult m_eResult`. |
| `m_nPublishedFileId: PublishedFileId_t` | C field `PublishedFileId_t m_nPublishedFileId`. |
| `m_nAppID: AppId_t` | C field `AppId_t m_nAppID`. |

### RemoveAppDependencyResult_t

Callback id 3415 (`RemoveAppDependencyResult_t_k_iCallback`).

| Field | C declaration |
|-------|---------------|
| `m_eResult: EResult` | C field `EResult m_eResult`. |
| `m_nPublishedFileId: PublishedFileId_t` | C field `PublishedFileId_t m_nPublishedFileId`. |
| `m_nAppID: AppId_t` | C field `AppId_t m_nAppID`. |

### GetAppDependenciesResult_t

Callback id 3416 (`GetAppDependenciesResult_t_k_iCallback`).

| Field | C declaration |
|-------|---------------|
| `m_eResult: EResult` | C field `EResult m_eResult`. |
| `m_nPublishedFileId: PublishedFileId_t` | C field `PublishedFileId_t m_nPublishedFileId`. |
| `m_rgAppIDs: array[0..31] of AppId_t` | C field `AppId_t [32] m_rgAppIDs`. |
| `m_nNumAppDependencies: UInt32` | C field `uint32 m_nNumAppDependencies`. |
| `m_nTotalNumAppDependencies: UInt32` | C field `uint32 m_nTotalNumAppDependencies`. |

### DeleteItemResult_t

Callback id 3417 (`DeleteItemResult_t_k_iCallback`).

| Field | C declaration |
|-------|---------------|
| `m_eResult: EResult` | C field `EResult m_eResult`. |
| `m_nPublishedFileId: PublishedFileId_t` | C field `PublishedFileId_t m_nPublishedFileId`. |

### UserSubscribedItemsListChanged_t

Callback id 3418 (`UserSubscribedItemsListChanged_t_k_iCallback`).

| Field | C declaration |
|-------|---------------|
| `m_nAppID: AppId_t` | C field `AppId_t m_nAppID`. |

### WorkshopEULAStatus_t

Callback id 3420 (`WorkshopEULAStatus_t_k_iCallback`).

| Field | C declaration |
|-------|---------------|
| `m_eResult: EResult` | C field `EResult m_eResult`. |
| `m_nAppID: AppId_t` | C field `AppId_t m_nAppID`. |
| `m_unVersion: UInt32` | C field `uint32 m_unVersion`. |
| `m_rtAction: RTime32` | C field `RTime32 m_rtAction`. |
| `m_bAccepted: Boolean` | C field `bool m_bAccepted`. |
| `m_bNeedsAction: Boolean` | C field `bool m_bNeedsAction`. |
