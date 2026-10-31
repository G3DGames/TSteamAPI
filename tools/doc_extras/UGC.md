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
