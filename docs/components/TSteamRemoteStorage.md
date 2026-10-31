# TSteamRemoteStorage and TSteamRemoteStoragePlugin (ISteamRemoteStorage)

> **Generated** by `tools/gen_docs.py` from `lib/plugins/Steamworks.Plugin.RemoteStorage.pas` - do not edit.
> Hand-written text: `tools/doc_extras/RemoteStorage.md`. Steam's own descriptions are Valve's
> SDK comments, as in the generated units.

Unit: `Steamworks.Plugin.RemoteStorage` - linking it (a `uses` entry, or dropping a `TSteamRemoteStorage`) enables the
plug-in. Steam interface: `ISteamRemoteStorage` (SDK 1.65).

## Overview

Steam Cloud: per-user files that Steam keeps in step across the user's
machines. Enable Steam Cloud for the AppID and set a byte / file quota on
the partner site first; until then writes fail.

### Writing and reading a save

```pascal
var
  RS: TSteamRemoteStoragePlugin;
  Data: TBytes;
  Size: Int32;
begin
  RS := SteamRemoteStorage1.Plugin;
  if (RS = nil) or not RS.IsCloudEnabledForAccount or not RS.IsCloudEnabledForApp then
    Exit;                                       // keep the save local only

  Data := TEncoding.UTF8.GetBytes(SaveText);
  if not RS.FileWrite('save1.json', @Data[0], Length(Data)) then
    ShowMessage('Cloud write failed (quota?)');

  if RS.FileExists('save1.json') then
  begin
    Size := RS.GetFileSize('save1.json');
    SetLength(Data, Size);
    if (Size > 0) and (RS.FileRead('save1.json', @Data[0], Size) = Size) then
      SaveText := TEncoding.UTF8.GetString(Data);
  end;
end;
```

* `FileWrite` / `FileRead` are synchronous and local: Steam uploads the
  change in the background. One write may not exceed 100 MB
  (`k_unMaxCloudFileChunkSize`); for larger files use the stream calls
  `FileWriteStreamOpen` / `FileWriteStreamWriteChunk` /
  `FileWriteStreamClose`.
* Saves made of several files: wrap the writes in `BeginFileWriteBatch` /
  `EndFileWriteBatch` so Steam treats them as one change.
* `GetQuota(Total, Available)`, `GetFileCount`, `GetFileNameAndSize(I, Size)`
  and `GetFileTimestamp` list what is stored; `FileDelete` removes a file
  everywhere, `FileForget` only from the cloud (the local copy stays).
* `OnRemoteStorageLocalFileChange` fires when Steam changed local files while
  the game runs (another machine synced); `GetLocalFileChangeCount` /
  `GetLocalFileChange` list them.

### Asynchronous reads and writes

Valve's `FileWriteAsync` / `FileReadAsync` already end in Async, so the
variant that takes a handler is an **overload** of the same name. A read
completes in two steps: the result says how much was read, then
`FileReadAsyncComplete` copies it into your buffer.

```pascal
procedure TGame.LoadAsync;
begin
  RS.FileReadAsync('save1.json', 0, RS.GetFileSize('save1.json'), SaveRead);
end;

procedure TGame.SaveRead(const AData: TSteamCallbackData; AIOFailure: Boolean);
var
  R: RemoteStorageFileReadAsyncComplete_t;
  Buf: TBytes;
begin
  if AIOFailure or not AData.CopyTo(R, SizeOf(R)) or (R.m_eResult <> k_EResultOK) then
    Exit;
  SetLength(Buf, R.m_cubRead);
  if (R.m_cubRead > 0) and RS.FileReadAsyncComplete(R.m_hFileReadAsync, @Buf[0], R.m_cubRead) then
    ApplySave(Buf);
end;
```

### Workshop calls here are the old API

`PublishWorkshopFile`, `EnumerateUserPublishedFiles`, `SubscribePublishedFile`
and the other publish / enumerate / vote calls of this interface are
Valve's first Workshop API, kept for old games. New code uses
[TSteamUGC](TSteamUGC.md). Their `SteamParamStringArray_t` parameters are
`var` because the C header declares them non-const, so they cannot be
`nil`: for "no tags" pass a zeroed record (`m_ppStrings = nil`,
`m_nNumStrings = 0`), or call the export through `Flat` with `nil`.

## Contents

* [The component: TSteamRemoteStorage](#the-component-tsteamremotestorage)
  * [Events (25)](#events)
* [The plug-in: TSteamRemoteStoragePlugin](#the-plug-in-tsteamremotestorageplugin)
  * [Methods](#methods)
  * [Async methods](#async-methods)
  * [Properties](#properties)
* [Payload records](#payload-records)

## The component: TSteamRemoteStorage

ISteamRemoteStorage component: drop it next to a TSteamAPI (linked automatically at run time when the owner has exactly one, otherwise set SteamAPI). Its events are the ISteamRemoteStorage callbacks; call the interface through `Plugin`.

| Member | Kind | Description |
|--------|------|-------------|
| `SteamAPI` | published property | The `TSteamAPI` this component belongs to. At run time a component whose owner has exactly one `TSteamAPI` links itself. |
| `Plugin` | public property | The `TSteamRemoteStoragePlugin` for calls; `nil` while Steam is not running. |
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
| `OnRemoteStorageFileShareResult` | 1307 | [`RemoteStorageFileShareResult_t`](#remotestoragefileshareresult_t) | The result of a call to FileShare(). |
| `OnRemoteStoragePublishFileResult` | 1309 | [`RemoteStoragePublishFileResult_t`](#remotestoragepublishfileresult_t) | The result of a call to PublishFile(). |
| `OnRemoteStorageDeletePublishedFileResult` | 1311 | [`RemoteStorageDeletePublishedFileResult_t`](#remotestoragedeletepublishedfileresult_t) | The result of a call to DeletePublishedFile(). |
| `OnRemoteStorageEnumerateUserPublishedFilesResult` | 1312 | [`RemoteStorageEnumerateUserPublishedFilesResult_t`](#remotestorageenumerateuserpublishedfilesresult_t) | The result of a call to EnumerateUserPublishedFiles(). |
| `OnRemoteStorageSubscribePublishedFileResult` | 1313 | [`RemoteStorageSubscribePublishedFileResult_t`](#remotestoragesubscribepublishedfileresult_t) | The result of a call to SubscribePublishedFile(). |
| `OnRemoteStorageEnumerateUserSubscribedFilesResult` | 1314 | [`RemoteStorageEnumerateUserSubscribedFilesResult_t`](#remotestorageenumerateusersubscribedfilesresult_t) | The result of a call to EnumerateSubscribePublishedFiles(). |
| `OnRemoteStorageUnsubscribePublishedFileResult` | 1315 | [`RemoteStorageUnsubscribePublishedFileResult_t`](#remotestorageunsubscribepublishedfileresult_t) | The result of a call to UnsubscribePublishedFile(). |
| `OnRemoteStorageUpdatePublishedFileResult` | 1316 | [`RemoteStorageUpdatePublishedFileResult_t`](#remotestorageupdatepublishedfileresult_t) | The result of a call to CommitPublishedFileUpdate(). |
| `OnRemoteStorageDownloadUGCResult` | 1317 | [`RemoteStorageDownloadUGCResult_t`](#remotestoragedownloadugcresult_t) | The result of a call to UGCDownload(). |
| `OnRemoteStorageGetPublishedFileDetailsResult` | 1318 | [`RemoteStorageGetPublishedFileDetailsResult_t`](#remotestoragegetpublishedfiledetailsresult_t) | The result of a call to GetPublishedFileDetails(). |
| `OnRemoteStorageEnumerateWorkshopFilesResult` | 1319 | [`RemoteStorageEnumerateWorkshopFilesResult_t`](#remotestorageenumerateworkshopfilesresult_t) | see the SDK. |
| `OnRemoteStorageGetPublishedItemVoteDetailsResult` | 1320 | [`RemoteStorageGetPublishedItemVoteDetailsResult_t`](#remotestoragegetpublisheditemvotedetailsresult_t) | The result of GetPublishedItemVoteDetails. |
| `OnRemoteStoragePublishedFileSubscribed` | 1321 | [`RemoteStoragePublishedFileSubscribed_t`](#remotestoragepublishedfilesubscribed_t) | User subscribed to a file for the app (from within the app or on the web). |
| `OnRemoteStoragePublishedFileUnsubscribed` | 1322 | [`RemoteStoragePublishedFileUnsubscribed_t`](#remotestoragepublishedfileunsubscribed_t) | User unsubscribed from a file for the app (from within the app or on the web). |
| `OnRemoteStoragePublishedFileDeleted` | 1323 | [`RemoteStoragePublishedFileDeleted_t`](#remotestoragepublishedfiledeleted_t) | Published file that a user owns was deleted (from within the app or the web). |
| `OnRemoteStorageUpdateUserPublishedItemVoteResult` | 1324 | [`RemoteStorageUpdateUserPublishedItemVoteResult_t`](#remotestorageupdateuserpublisheditemvoteresult_t) | The result of a call to UpdateUserPublishedItemVote(). |
| `OnRemoteStorageUserVoteDetails` | 1325 | [`RemoteStorageUserVoteDetails_t`](#remotestorageuservotedetails_t) | The result of a call to GetUserPublishedItemVoteDetails(). |
| `OnRemoteStorageEnumerateUserSharedWorkshopFilesResult` | 1326 | [`RemoteStorageEnumerateUserSharedWorkshopFilesResult_t`](#remotestorageenumerateusersharedworkshopfilesresult_t) | see the SDK. |
| `OnRemoteStorageSetUserPublishedFileActionResult` | 1327 | [`RemoteStorageSetUserPublishedFileActionResult_t`](#remotestoragesetuserpublishedfileactionresult_t) | see the SDK. |
| `OnRemoteStorageEnumeratePublishedFilesByUserActionResult` | 1328 | [`RemoteStorageEnumeratePublishedFilesByUserActionResult_t`](#remotestorageenumeratepublishedfilesbyuseractionresult_t) | see the SDK. |
| `OnRemoteStoragePublishFileProgress` | 1329 | [`RemoteStoragePublishFileProgress_t`](#remotestoragepublishfileprogress_t) | Called periodically while a PublishWorkshopFile is in progress. |
| `OnRemoteStoragePublishedFileUpdated` | 1330 | [`RemoteStoragePublishedFileUpdated_t`](#remotestoragepublishedfileupdated_t) | Called when the content for a published file is updated. |
| `OnRemoteStorageFileWriteAsyncComplete` | 1331 | [`RemoteStorageFileWriteAsyncComplete_t`](#remotestoragefilewriteasynccomplete_t) | Called when a FileWriteAsync completes. |
| `OnRemoteStorageFileReadAsyncComplete` | 1332 | [`RemoteStorageFileReadAsyncComplete_t`](#remotestoragefilereadasynccomplete_t) | Called when a FileReadAsync completes. |
| `OnRemoteStorageLocalFileChange` | 1333 | [`RemoteStorageLocalFileChange_t`](#remotestoragelocalfilechange_t) | one or more files for this app have changed locally after syncing to remote session changes Note: only posted if this happens DURING the local app session. |

Handler signature (the IDE generates it when you double-click the event):

```pascal
procedure TForm1.SteamRemoteStorage1RemoteStorageFileShareResult(Sender: TObject; const AData: RemoteStorageFileShareResult_t);
```

## The plug-in: TSteamRemoteStoragePlugin

ISteamRemoteStorage plug-in. Registered by linking the unit; find it with @code(Steam.FindPlugin(TSteamRemoteStoragePlugin)).

Reach it through the component (`SteamRemoteStorage1.Plugin`) or the core:

```pascal
P := TSteamRemoteStoragePlugin(Steam.FindPlugin(TSteamRemoteStoragePlugin));   // Delphi also: Steam.Plugin<TSteamRemoteStoragePlugin>
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
| [`FileWrite`](#filewrite) | file operations. |
| [`FileRead`](#fileread) | Wraps `SteamAPI_ISteamRemoteStorage_FileRead`. |
| [`FileWriteAsync`](#filewriteasync) | Wraps `SteamAPI_ISteamRemoteStorage_FileWriteAsync`. Call result: `RemoteStorageFileWriteAsyncComplete_t` (`RemoteStorageFileWriteAsyncComplete_t_k_iCallback`). |
| [`FileReadAsync`](#filereadasync) | Wraps `SteamAPI_ISteamRemoteStorage_FileReadAsync`. Call result: `RemoteStorageFileReadAsyncComplete_t` (`RemoteStorageFileReadAsyncComplete_t_k_iCallback`). |
| [`FileReadAsyncComplete`](#filereadasynccomplete) | Wraps `SteamAPI_ISteamRemoteStorage_FileReadAsyncComplete`. |
| [`FileForget`](#fileforget) | Wraps `SteamAPI_ISteamRemoteStorage_FileForget`. |
| [`FileDelete`](#filedelete) | Wraps `SteamAPI_ISteamRemoteStorage_FileDelete`. |
| [`FileShare`](#fileshare) | Wraps `SteamAPI_ISteamRemoteStorage_FileShare`. Call result: `RemoteStorageFileShareResult_t` (`RemoteStorageFileShareResult_t_k_iCallback`). |
| [`SetSyncPlatforms`](#setsyncplatforms) | Wraps `SteamAPI_ISteamRemoteStorage_SetSyncPlatforms`. |
| [`FileWriteStreamOpen`](#filewritestreamopen) | file operations that cause network IO. |
| [`FileWriteStreamWriteChunk`](#filewritestreamwritechunk) | Wraps `SteamAPI_ISteamRemoteStorage_FileWriteStreamWriteChunk`. |
| [`FileWriteStreamClose`](#filewritestreamclose) | Wraps `SteamAPI_ISteamRemoteStorage_FileWriteStreamClose`. |
| [`FileWriteStreamCancel`](#filewritestreamcancel) | Wraps `SteamAPI_ISteamRemoteStorage_FileWriteStreamCancel`. |
| [`FileExists`](#fileexists) | file information. |
| [`FilePersisted`](#filepersisted) | Wraps `SteamAPI_ISteamRemoteStorage_FilePersisted`. |
| [`GetFileSize`](#getfilesize) | Wraps `SteamAPI_ISteamRemoteStorage_GetFileSize`. |
| [`GetFileTimestamp`](#getfiletimestamp) | Wraps `SteamAPI_ISteamRemoteStorage_GetFileTimestamp`. |
| [`GetSyncPlatforms`](#getsyncplatforms) | Wraps `SteamAPI_ISteamRemoteStorage_GetSyncPlatforms`. |
| [`GetFileCount`](#getfilecount) | iteration. |
| [`GetFileNameAndSize`](#getfilenameandsize) | Wraps `SteamAPI_ISteamRemoteStorage_GetFileNameAndSize`. |
| [`GetQuota`](#getquota) | configuration management. |
| [`IsCloudEnabledForAccount`](#iscloudenabledforaccount) | Wraps `SteamAPI_ISteamRemoteStorage_IsCloudEnabledForAccount`. |
| [`IsCloudEnabledForApp`](#iscloudenabledforapp) | Wraps `SteamAPI_ISteamRemoteStorage_IsCloudEnabledForApp`. |
| [`SetCloudEnabledForApp`](#setcloudenabledforapp) | Wraps `SteamAPI_ISteamRemoteStorage_SetCloudEnabledForApp`. |
| [`UGCDownload`](#ugcdownload) | Downloads a UGC file. A priority value of 0 will download the file immediately, otherwise it will wait to download the file until all downloads with a lower ... |
| [`GetUGCDownloadProgress`](#getugcdownloadprogress) | Gets the amount of data downloaded so far for a piece of content. pnBytesExpected can be 0 if function returns false or if the transfer hasn't started yet, ... |
| [`GetUGCDetails`](#getugcdetails) | Gets metadata for a file after it has been downloaded. This is the same metadata given in the RemoteStorageDownloadUGCResult_t call result. |
| [`UGCRead`](#ugcread) | After download, gets the content of the file. Small files can be read all at once by calling this function with an offset of 0 and cubDataToRead equal to ... |
| [`GetCachedUGCCount`](#getcachedugccount) | Functions to iterate through UGC that has finished downloading but has not yet been read via UGCRead(). |
| [`GetCachedUGCHandle`](#getcachedugchandle) | Wraps `SteamAPI_ISteamRemoteStorage_GetCachedUGCHandle`. |
| [`PublishWorkshopFile`](#publishworkshopfile) | publishing UGC. Call result: `RemoteStoragePublishFileProgress_t` (`RemoteStoragePublishFileProgress_t_k_iCallback`). |
| [`CreatePublishedFileUpdateRequest`](#createpublishedfileupdaterequest) | Wraps `SteamAPI_ISteamRemoteStorage_CreatePublishedFileUpdateRequest`. |
| [`UpdatePublishedFileFile`](#updatepublishedfilefile) | Wraps `SteamAPI_ISteamRemoteStorage_UpdatePublishedFileFile`. |
| [`UpdatePublishedFilePreviewFile`](#updatepublishedfilepreviewfile) | Wraps `SteamAPI_ISteamRemoteStorage_UpdatePublishedFilePreviewFile`. |
| [`UpdatePublishedFileTitle`](#updatepublishedfiletitle) | Wraps `SteamAPI_ISteamRemoteStorage_UpdatePublishedFileTitle`. |
| [`UpdatePublishedFileDescription`](#updatepublishedfiledescription) | Wraps `SteamAPI_ISteamRemoteStorage_UpdatePublishedFileDescription`. |
| [`UpdatePublishedFileVisibility`](#updatepublishedfilevisibility) | Wraps `SteamAPI_ISteamRemoteStorage_UpdatePublishedFileVisibility`. |
| [`UpdatePublishedFileTags`](#updatepublishedfiletags) | Wraps `SteamAPI_ISteamRemoteStorage_UpdatePublishedFileTags`. |
| [`CommitPublishedFileUpdate`](#commitpublishedfileupdate) | Wraps `SteamAPI_ISteamRemoteStorage_CommitPublishedFileUpdate`. Call result: `RemoteStorageUpdatePublishedFileResult_t` ... |
| [`GetPublishedFileDetails`](#getpublishedfiledetails) | Gets published file details for the given publishedfileid. If unMaxSecondsOld is greater than 0, cached data may be returned, depending on how long ago it ... |
| [`DeletePublishedFile`](#deletepublishedfile) | Wraps `SteamAPI_ISteamRemoteStorage_DeletePublishedFile`. Call result: `RemoteStorageDeletePublishedFileResult_t` ... |
| [`EnumerateUserPublishedFiles`](#enumerateuserpublishedfiles) | enumerate the files that the current user published with this app. Call result: `RemoteStorageEnumerateUserPublishedFilesResult_t` ... |
| [`SubscribePublishedFile`](#subscribepublishedfile) | Wraps `SteamAPI_ISteamRemoteStorage_SubscribePublishedFile`. Call result: `RemoteStorageSubscribePublishedFileResult_t` ... |
| [`EnumerateUserSubscribedFiles`](#enumerateusersubscribedfiles) | Wraps `SteamAPI_ISteamRemoteStorage_EnumerateUserSubscribedFiles`. Call result: `RemoteStorageEnumerateUserSubscribedFilesResult_t` ... |
| [`UnsubscribePublishedFile`](#unsubscribepublishedfile) | Wraps `SteamAPI_ISteamRemoteStorage_UnsubscribePublishedFile`. Call result: `RemoteStorageUnsubscribePublishedFileResult_t` ... |
| [`UpdatePublishedFileSetChangeDescription`](#updatepublishedfilesetchangedescription) | Wraps `SteamAPI_ISteamRemoteStorage_UpdatePublishedFileSetChangeDescription`. |
| [`GetPublishedItemVoteDetails`](#getpublisheditemvotedetails) | Wraps `SteamAPI_ISteamRemoteStorage_GetPublishedItemVoteDetails`. Call result: `RemoteStorageGetPublishedItemVoteDetailsResult_t` ... |
| [`UpdateUserPublishedItemVote`](#updateuserpublisheditemvote) | Wraps `SteamAPI_ISteamRemoteStorage_UpdateUserPublishedItemVote`. Call result: `RemoteStorageUpdateUserPublishedItemVoteResult_t` ... |
| [`GetUserPublishedItemVoteDetails`](#getuserpublisheditemvotedetails) | Wraps `SteamAPI_ISteamRemoteStorage_GetUserPublishedItemVoteDetails`. Call result: `RemoteStorageGetPublishedItemVoteDetailsResult_t` ... |
| [`EnumerateUserSharedWorkshopFiles`](#enumerateusersharedworkshopfiles) | Wraps `SteamAPI_ISteamRemoteStorage_EnumerateUserSharedWorkshopFiles`. Call result: `RemoteStorageEnumerateUserPublishedFilesResult_t` ... |
| [`PublishVideo`](#publishvideo) | Wraps `SteamAPI_ISteamRemoteStorage_PublishVideo`. Call result: `RemoteStoragePublishFileProgress_t` (`RemoteStoragePublishFileProgress_t_k_iCallback`). |
| [`SetUserPublishedFileAction`](#setuserpublishedfileaction) | Wraps `SteamAPI_ISteamRemoteStorage_SetUserPublishedFileAction`. Call result: `RemoteStorageSetUserPublishedFileActionResult_t` ... |
| [`EnumeratePublishedFilesByUserAction`](#enumeratepublishedfilesbyuseraction) | Wraps `SteamAPI_ISteamRemoteStorage_EnumeratePublishedFilesByUserAction`. Call result: `RemoteStorageEnumeratePublishedFilesByUserActionResult_t` ... |
| [`EnumeratePublishedWorkshopFiles`](#enumeratepublishedworkshopfiles) | this method enumerates the public view of workshop files. Call result: `RemoteStorageEnumerateWorkshopFilesResult_t` ... |
| [`UGCDownloadToLocation`](#ugcdownloadtolocation) | Wraps `SteamAPI_ISteamRemoteStorage_UGCDownloadToLocation`. Call result: `RemoteStorageDownloadUGCResult_t` (`RemoteStorageDownloadUGCResult_t_k_iCallback`). |
| [`GetLocalFileChangeCount`](#getlocalfilechangecount) | Cloud dynamic state change notification. |
| [`GetLocalFileChange`](#getlocalfilechange) | Wraps `SteamAPI_ISteamRemoteStorage_GetLocalFileChange`. |
| [`BeginFileWriteBatch`](#beginfilewritebatch) | Indicate to Steam the beginning / end of a set of local file operations - for example, writing a game save that requires updating two files. |
| [`EndFileWriteBatch`](#endfilewritebatch) | Wraps `SteamAPI_ISteamRemoteStorage_EndFileWriteBatch`. |

#### FileWrite

```pascal
function FileWrite(const pchFile: string; pvData: Pointer; cubData: Int32): Boolean;
```

file operations.

#### FileRead

```pascal
function FileRead(const pchFile: string; pvData: Pointer; cubDataToRead: Int32): Int32;
```

Wraps `SteamAPI_ISteamRemoteStorage_FileRead`.

#### FileWriteAsync

```pascal
function FileWriteAsync(const pchFile: string; pvData: Pointer; cubData: UInt32): SteamAPICall_t; overload;
```

Wraps `SteamAPI_ISteamRemoteStorage_FileWriteAsync`. Call result: `RemoteStorageFileWriteAsyncComplete_t` (`RemoteStorageFileWriteAsyncComplete_t_k_iCallback`).

#### FileReadAsync

```pascal
function FileReadAsync(const pchFile: string; nOffset: UInt32; cubToRead: UInt32): SteamAPICall_t; overload;
```

Wraps `SteamAPI_ISteamRemoteStorage_FileReadAsync`. Call result: `RemoteStorageFileReadAsyncComplete_t` (`RemoteStorageFileReadAsyncComplete_t_k_iCallback`).

#### FileReadAsyncComplete

```pascal
function FileReadAsyncComplete(hReadCall: SteamAPICall_t; pvBuffer: Pointer; cubToRead: UInt32): Boolean;
```

Wraps `SteamAPI_ISteamRemoteStorage_FileReadAsyncComplete`.

#### FileForget

```pascal
function FileForget(const pchFile: string): Boolean;
```

Wraps `SteamAPI_ISteamRemoteStorage_FileForget`.

#### FileDelete

```pascal
function FileDelete(const pchFile: string): Boolean;
```

Wraps `SteamAPI_ISteamRemoteStorage_FileDelete`.

#### FileShare

```pascal
function FileShare(const pchFile: string): SteamAPICall_t;
```

Wraps `SteamAPI_ISteamRemoteStorage_FileShare`. Call result: `RemoteStorageFileShareResult_t` (`RemoteStorageFileShareResult_t_k_iCallback`).

#### SetSyncPlatforms

```pascal
function SetSyncPlatforms(const pchFile: string; AERemoteStoragePlatform: ERemoteStoragePlatform): Boolean;
```

Wraps `SteamAPI_ISteamRemoteStorage_SetSyncPlatforms`.

#### FileWriteStreamOpen

```pascal
function FileWriteStreamOpen(const pchFile: string): UGCFileWriteStreamHandle_t;
```

file operations that cause network IO.

#### FileWriteStreamWriteChunk

```pascal
function FileWriteStreamWriteChunk(writeHandle: UGCFileWriteStreamHandle_t; pvData: Pointer; cubData: Int32): Boolean;
```

Wraps `SteamAPI_ISteamRemoteStorage_FileWriteStreamWriteChunk`.

#### FileWriteStreamClose

```pascal
function FileWriteStreamClose(writeHandle: UGCFileWriteStreamHandle_t): Boolean;
```

Wraps `SteamAPI_ISteamRemoteStorage_FileWriteStreamClose`.

#### FileWriteStreamCancel

```pascal
function FileWriteStreamCancel(writeHandle: UGCFileWriteStreamHandle_t): Boolean;
```

Wraps `SteamAPI_ISteamRemoteStorage_FileWriteStreamCancel`.

#### FileExists

```pascal
function FileExists(const pchFile: string): Boolean;
```

file information.

#### FilePersisted

```pascal
function FilePersisted(const pchFile: string): Boolean;
```

Wraps `SteamAPI_ISteamRemoteStorage_FilePersisted`.

#### GetFileSize

```pascal
function GetFileSize(const pchFile: string): Int32;
```

Wraps `SteamAPI_ISteamRemoteStorage_GetFileSize`.

#### GetFileTimestamp

```pascal
function GetFileTimestamp(const pchFile: string): Int64;
```

Wraps `SteamAPI_ISteamRemoteStorage_GetFileTimestamp`.

#### GetSyncPlatforms

```pascal
function GetSyncPlatforms(const pchFile: string): ERemoteStoragePlatform;
```

Wraps `SteamAPI_ISteamRemoteStorage_GetSyncPlatforms`.

#### GetFileCount

```pascal
function GetFileCount: Int32;
```

iteration.

#### GetFileNameAndSize

```pascal
function GetFileNameAndSize(iFile: Integer; var pnFileSizeInBytes: Int32): string;
```

Wraps `SteamAPI_ISteamRemoteStorage_GetFileNameAndSize`.

#### GetQuota

```pascal
function GetQuota(var pnTotalBytes: UInt64; var puAvailableBytes: UInt64): Boolean;
```

configuration management.

#### IsCloudEnabledForAccount

```pascal
function IsCloudEnabledForAccount: Boolean;
```

Wraps `SteamAPI_ISteamRemoteStorage_IsCloudEnabledForAccount`.

#### IsCloudEnabledForApp

```pascal
function IsCloudEnabledForApp: Boolean;
```

Wraps `SteamAPI_ISteamRemoteStorage_IsCloudEnabledForApp`.

#### SetCloudEnabledForApp

```pascal
procedure SetCloudEnabledForApp(bEnabled: Boolean);
```

Wraps `SteamAPI_ISteamRemoteStorage_SetCloudEnabledForApp`.

#### UGCDownload

```pascal
function UGCDownload(hContent: UGCHandle_t; unPriority: UInt32): SteamAPICall_t;
```

Downloads a UGC file. A priority value of 0 will download the file immediately, otherwise it will wait to download the file until all downloads with a lower priority value are completed. Downloads with equal priority will occur simultaneously. Call result: `RemoteStorageDownloadUGCResult_t` (`RemoteStorageDownloadUGCResult_t_k_iCallback`).

#### GetUGCDownloadProgress

```pascal
function GetUGCDownloadProgress(hContent: UGCHandle_t; var pnBytesDownloaded: Int32; var pnBytesExpected: Int32): Boolean;
```

Gets the amount of data downloaded so far for a piece of content. pnBytesExpected can be 0 if function returns false or if the transfer hasn't started yet, so be careful to check for that before dividing to get a percentage.

#### GetUGCDetails

```pascal
function GetUGCDetails(hContent: UGCHandle_t; var pnAppID: AppId_t; ppchName: Pointer; var pnFileSizeInBytes: Int32; var pSteamIDOwner: TSteamID): Boolean;
```

Gets metadata for a file after it has been downloaded. This is the same metadata given in the RemoteStorageDownloadUGCResult_t call result.

#### UGCRead

```pascal
function UGCRead(hContent: UGCHandle_t; pvData: Pointer; cubDataToRead: Int32; cOffset: UInt32; eAction: EUGCReadAction): Int32;
```

After download, gets the content of the file. Small files can be read all at once by calling this function with an offset of 0 and cubDataToRead equal to the size of the file. Larger files can be read in chunks to reduce memory usage (since both sides of the IPC client and the game itself must allocate enough memory for each chunk). Once the last byte is read, the file is implicitly closed and further calls to UGCRead will fail unless UGCDownload is called again. For especially large files (anything over 100MB) it is a requirement that the file is read in chunks.

#### GetCachedUGCCount

```pascal
function GetCachedUGCCount: Int32;
```

Functions to iterate through UGC that has finished downloading but has not yet been read via UGCRead().

#### GetCachedUGCHandle

```pascal
function GetCachedUGCHandle(iCachedContent: Int32): UGCHandle_t;
```

Wraps `SteamAPI_ISteamRemoteStorage_GetCachedUGCHandle`.

#### PublishWorkshopFile

```pascal
function PublishWorkshopFile(const pchFile: string; const pchPreviewFile: string; nConsumerAppId: AppId_t; const pchTitle: string; const pchDescription: string; eVisibility: ERemoteStoragePublishedFileVisibility; var pTags: SteamParamStringArray_t; AEWorkshopFileType: EWorkshopFileType): SteamAPICall_t;
```

publishing UGC. Call result: `RemoteStoragePublishFileProgress_t` (`RemoteStoragePublishFileProgress_t_k_iCallback`).

#### CreatePublishedFileUpdateRequest

```pascal
function CreatePublishedFileUpdateRequest(unPublishedFileId: PublishedFileId_t): PublishedFileUpdateHandle_t;
```

Wraps `SteamAPI_ISteamRemoteStorage_CreatePublishedFileUpdateRequest`.

#### UpdatePublishedFileFile

```pascal
function UpdatePublishedFileFile(updateHandle: PublishedFileUpdateHandle_t; const pchFile: string): Boolean;
```

Wraps `SteamAPI_ISteamRemoteStorage_UpdatePublishedFileFile`.

#### UpdatePublishedFilePreviewFile

```pascal
function UpdatePublishedFilePreviewFile(updateHandle: PublishedFileUpdateHandle_t; const pchPreviewFile: string): Boolean;
```

Wraps `SteamAPI_ISteamRemoteStorage_UpdatePublishedFilePreviewFile`.

#### UpdatePublishedFileTitle

```pascal
function UpdatePublishedFileTitle(updateHandle: PublishedFileUpdateHandle_t; const pchTitle: string): Boolean;
```

Wraps `SteamAPI_ISteamRemoteStorage_UpdatePublishedFileTitle`.

#### UpdatePublishedFileDescription

```pascal
function UpdatePublishedFileDescription(updateHandle: PublishedFileUpdateHandle_t; const pchDescription: string): Boolean;
```

Wraps `SteamAPI_ISteamRemoteStorage_UpdatePublishedFileDescription`.

#### UpdatePublishedFileVisibility

```pascal
function UpdatePublishedFileVisibility(updateHandle: PublishedFileUpdateHandle_t; eVisibility: ERemoteStoragePublishedFileVisibility): Boolean;
```

Wraps `SteamAPI_ISteamRemoteStorage_UpdatePublishedFileVisibility`.

#### UpdatePublishedFileTags

```pascal
function UpdatePublishedFileTags(updateHandle: PublishedFileUpdateHandle_t; var pTags: SteamParamStringArray_t): Boolean;
```

Wraps `SteamAPI_ISteamRemoteStorage_UpdatePublishedFileTags`.

#### CommitPublishedFileUpdate

```pascal
function CommitPublishedFileUpdate(updateHandle: PublishedFileUpdateHandle_t): SteamAPICall_t;
```

Wraps `SteamAPI_ISteamRemoteStorage_CommitPublishedFileUpdate`. Call result: `RemoteStorageUpdatePublishedFileResult_t` (`RemoteStorageUpdatePublishedFileResult_t_k_iCallback`).

#### GetPublishedFileDetails

```pascal
function GetPublishedFileDetails(unPublishedFileId: PublishedFileId_t; unMaxSecondsOld: UInt32): SteamAPICall_t;
```

Gets published file details for the given publishedfileid. If unMaxSecondsOld is greater than 0, cached data may be returned, depending on how long ago it was cached. A value of 0 will force a refresh. A value of k_WorkshopForceLoadPublishedFileDetailsFromCache will use cached data if it exists, no matter how old it is. Call result: `RemoteStorageGetPublishedFileDetailsResult_t` (`RemoteStorageGetPublishedFileDetailsResult_t_k_iCallback`).

#### DeletePublishedFile

```pascal
function DeletePublishedFile(unPublishedFileId: PublishedFileId_t): SteamAPICall_t;
```

Wraps `SteamAPI_ISteamRemoteStorage_DeletePublishedFile`. Call result: `RemoteStorageDeletePublishedFileResult_t` (`RemoteStorageDeletePublishedFileResult_t_k_iCallback`).

#### EnumerateUserPublishedFiles

```pascal
function EnumerateUserPublishedFiles(unStartIndex: UInt32): SteamAPICall_t;
```

enumerate the files that the current user published with this app. Call result: `RemoteStorageEnumerateUserPublishedFilesResult_t` (`RemoteStorageEnumerateUserPublishedFilesResult_t_k_iCallback`).

#### SubscribePublishedFile

```pascal
function SubscribePublishedFile(unPublishedFileId: PublishedFileId_t): SteamAPICall_t;
```

Wraps `SteamAPI_ISteamRemoteStorage_SubscribePublishedFile`. Call result: `RemoteStorageSubscribePublishedFileResult_t` (`RemoteStorageSubscribePublishedFileResult_t_k_iCallback`).

#### EnumerateUserSubscribedFiles

```pascal
function EnumerateUserSubscribedFiles(unStartIndex: UInt32): SteamAPICall_t;
```

Wraps `SteamAPI_ISteamRemoteStorage_EnumerateUserSubscribedFiles`. Call result: `RemoteStorageEnumerateUserSubscribedFilesResult_t` (`RemoteStorageEnumerateUserSubscribedFilesResult_t_k_iCallback`).

#### UnsubscribePublishedFile

```pascal
function UnsubscribePublishedFile(unPublishedFileId: PublishedFileId_t): SteamAPICall_t;
```

Wraps `SteamAPI_ISteamRemoteStorage_UnsubscribePublishedFile`. Call result: `RemoteStorageUnsubscribePublishedFileResult_t` (`RemoteStorageUnsubscribePublishedFileResult_t_k_iCallback`).

#### UpdatePublishedFileSetChangeDescription

```pascal
function UpdatePublishedFileSetChangeDescription(updateHandle: PublishedFileUpdateHandle_t; const pchChangeDescription: string): Boolean;
```

Wraps `SteamAPI_ISteamRemoteStorage_UpdatePublishedFileSetChangeDescription`.

#### GetPublishedItemVoteDetails

```pascal
function GetPublishedItemVoteDetails(unPublishedFileId: PublishedFileId_t): SteamAPICall_t;
```

Wraps `SteamAPI_ISteamRemoteStorage_GetPublishedItemVoteDetails`. Call result: `RemoteStorageGetPublishedItemVoteDetailsResult_t` (`RemoteStorageGetPublishedItemVoteDetailsResult_t_k_iCallback`).

#### UpdateUserPublishedItemVote

```pascal
function UpdateUserPublishedItemVote(unPublishedFileId: PublishedFileId_t; bVoteUp: Boolean): SteamAPICall_t;
```

Wraps `SteamAPI_ISteamRemoteStorage_UpdateUserPublishedItemVote`. Call result: `RemoteStorageUpdateUserPublishedItemVoteResult_t` (`RemoteStorageUpdateUserPublishedItemVoteResult_t_k_iCallback`).

#### GetUserPublishedItemVoteDetails

```pascal
function GetUserPublishedItemVoteDetails(unPublishedFileId: PublishedFileId_t): SteamAPICall_t;
```

Wraps `SteamAPI_ISteamRemoteStorage_GetUserPublishedItemVoteDetails`. Call result: `RemoteStorageGetPublishedItemVoteDetailsResult_t` (`RemoteStorageGetPublishedItemVoteDetailsResult_t_k_iCallback`).

#### EnumerateUserSharedWorkshopFiles

```pascal
function EnumerateUserSharedWorkshopFiles(const steamId: TSteamID; unStartIndex: UInt32; var pRequiredTags: SteamParamStringArray_t; var pExcludedTags: SteamParamStringArray_t): SteamAPICall_t;
```

Wraps `SteamAPI_ISteamRemoteStorage_EnumerateUserSharedWorkshopFiles`. Call result: `RemoteStorageEnumerateUserPublishedFilesResult_t` (`RemoteStorageEnumerateUserPublishedFilesResult_t_k_iCallback`).

#### PublishVideo

```pascal
function PublishVideo(eVideoProvider: EWorkshopVideoProvider; const pchVideoAccount: string; const pchVideoIdentifier: string; const pchPreviewFile: string; nConsumerAppId: AppId_t; const pchTitle: string; const pchDescription: string; eVisibility: ERemoteStoragePublishedFileVisibility; var pTags: SteamParamStringArray_t): SteamAPICall_t;
```

Wraps `SteamAPI_ISteamRemoteStorage_PublishVideo`. Call result: `RemoteStoragePublishFileProgress_t` (`RemoteStoragePublishFileProgress_t_k_iCallback`).

#### SetUserPublishedFileAction

```pascal
function SetUserPublishedFileAction(unPublishedFileId: PublishedFileId_t; eAction: EWorkshopFileAction): SteamAPICall_t;
```

Wraps `SteamAPI_ISteamRemoteStorage_SetUserPublishedFileAction`. Call result: `RemoteStorageSetUserPublishedFileActionResult_t` (`RemoteStorageSetUserPublishedFileActionResult_t_k_iCallback`).

#### EnumeratePublishedFilesByUserAction

```pascal
function EnumeratePublishedFilesByUserAction(eAction: EWorkshopFileAction; unStartIndex: UInt32): SteamAPICall_t;
```

Wraps `SteamAPI_ISteamRemoteStorage_EnumeratePublishedFilesByUserAction`. Call result: `RemoteStorageEnumeratePublishedFilesByUserActionResult_t` (`RemoteStorageEnumeratePublishedFilesByUserActionResult_t_k_iCallback`).

#### EnumeratePublishedWorkshopFiles

```pascal
function EnumeratePublishedWorkshopFiles(eEnumerationType: EWorkshopEnumerationType; unStartIndex: UInt32; unCount: UInt32; unDays: UInt32; var pTags: SteamParamStringArray_t; var pUserTags: SteamParamStringArray_t): SteamAPICall_t;
```

this method enumerates the public view of workshop files. Call result: `RemoteStorageEnumerateWorkshopFilesResult_t` (`RemoteStorageEnumerateWorkshopFilesResult_t_k_iCallback`).

#### UGCDownloadToLocation

```pascal
function UGCDownloadToLocation(hContent: UGCHandle_t; const pchLocation: string; unPriority: UInt32): SteamAPICall_t;
```

Wraps `SteamAPI_ISteamRemoteStorage_UGCDownloadToLocation`. Call result: `RemoteStorageDownloadUGCResult_t` (`RemoteStorageDownloadUGCResult_t_k_iCallback`).

#### GetLocalFileChangeCount

```pascal
function GetLocalFileChangeCount: Int32;
```

Cloud dynamic state change notification.

#### GetLocalFileChange

```pascal
function GetLocalFileChange(iFile: Integer; var pEChangeType: ERemoteStorageLocalFileChange; var pEFilePathType: ERemoteStorageFilePathType): string;
```

Wraps `SteamAPI_ISteamRemoteStorage_GetLocalFileChange`.

#### BeginFileWriteBatch

```pascal
function BeginFileWriteBatch: Boolean;
```

Indicate to Steam the beginning / end of a set of local file operations - for example, writing a game save that requires updating two files.

#### EndFileWriteBatch

```pascal
function EndFileWriteBatch: Boolean;
```

Wraps `SteamAPI_ISteamRemoteStorage_EndFileWriteBatch`.

### Async methods

Each `...Async` method starts the call and registers `AHandler` for its result
(`procedure(const AData: TSteamCallbackData; AIOFailure: Boolean) of object`). The
handler runs once, on the delivery thread, with the result record in `AData`
(`AData.CopyTo(Rec, SizeOf(Rec))`); its object owns the registration - call
`Steam.Dispatcher.RemoveOwner(Self)` in that object's destructor. The plain method of
the same name returns the `SteamAPICall_t` instead, and its result reaches the
component's event.

Valve's own `FileReadAsync` / `FileWriteAsync` already end in Async:
there the handler variant is an overload of the same name with the extra
`AHandler` parameter.

#### FileWriteAsync

```pascal
function FileWriteAsync(const pchFile: string; pvData: Pointer; cubData: UInt32; AHandler: TSteamCallResultEvent): SteamAPICall_t; overload;
```

Calls `FileWriteAsync` and registers AHandler for its result (`RemoteStorageFileWriteAsyncComplete_t`). The handler's object owns the registration (remove it with Steam.Dispatcher.RemoveOwner). Returns: (The call handle, or k_uAPICallInvalid when Steam refused the call.)

#### FileReadAsync

```pascal
function FileReadAsync(const pchFile: string; nOffset: UInt32; cubToRead: UInt32; AHandler: TSteamCallResultEvent): SteamAPICall_t; overload;
```

Calls `FileReadAsync` and registers AHandler for its result (`RemoteStorageFileReadAsyncComplete_t`). The handler's object owns the registration (remove it with Steam.Dispatcher.RemoveOwner). Returns: (The call handle, or k_uAPICallInvalid when Steam refused the call.)

#### FileShareAsync

```pascal
function FileShareAsync(const pchFile: string; AHandler: TSteamCallResultEvent): SteamAPICall_t;
```

Calls `FileShare` and registers AHandler for its result (`RemoteStorageFileShareResult_t`). The handler's object owns the registration (remove it with Steam.Dispatcher.RemoveOwner). Returns: (The call handle, or k_uAPICallInvalid when Steam refused the call.)

#### UGCDownloadAsync

```pascal
function UGCDownloadAsync(hContent: UGCHandle_t; unPriority: UInt32; AHandler: TSteamCallResultEvent): SteamAPICall_t;
```

Calls `UGCDownload` and registers AHandler for its result (`RemoteStorageDownloadUGCResult_t`). The handler's object owns the registration (remove it with Steam.Dispatcher.RemoveOwner). Returns: (The call handle, or k_uAPICallInvalid when Steam refused the call.)

#### PublishWorkshopFileAsync

```pascal
function PublishWorkshopFileAsync(const pchFile: string; const pchPreviewFile: string; nConsumerAppId: AppId_t; const pchTitle: string; const pchDescription: string; eVisibility: ERemoteStoragePublishedFileVisibility; var pTags: SteamParamStringArray_t; AEWorkshopFileType: EWorkshopFileType; AHandler: TSteamCallResultEvent): SteamAPICall_t;
```

Calls `PublishWorkshopFile` and registers AHandler for its result (`RemoteStoragePublishFileProgress_t`). The handler's object owns the registration (remove it with Steam.Dispatcher.RemoveOwner). Returns: (The call handle, or k_uAPICallInvalid when Steam refused the call.)

#### CommitPublishedFileUpdateAsync

```pascal
function CommitPublishedFileUpdateAsync(updateHandle: PublishedFileUpdateHandle_t; AHandler: TSteamCallResultEvent): SteamAPICall_t;
```

Calls `CommitPublishedFileUpdate` and registers AHandler for its result (`RemoteStorageUpdatePublishedFileResult_t`). The handler's object owns the registration (remove it with Steam.Dispatcher.RemoveOwner). Returns: (The call handle, or k_uAPICallInvalid when Steam refused the call.)

#### GetPublishedFileDetailsAsync

```pascal
function GetPublishedFileDetailsAsync(unPublishedFileId: PublishedFileId_t; unMaxSecondsOld: UInt32; AHandler: TSteamCallResultEvent): SteamAPICall_t;
```

Calls `GetPublishedFileDetails` and registers AHandler for its result (`RemoteStorageGetPublishedFileDetailsResult_t`). The handler's object owns the registration (remove it with Steam.Dispatcher.RemoveOwner). Returns: (The call handle, or k_uAPICallInvalid when Steam refused the call.)

#### DeletePublishedFileAsync

```pascal
function DeletePublishedFileAsync(unPublishedFileId: PublishedFileId_t; AHandler: TSteamCallResultEvent): SteamAPICall_t;
```

Calls `DeletePublishedFile` and registers AHandler for its result (`RemoteStorageDeletePublishedFileResult_t`). The handler's object owns the registration (remove it with Steam.Dispatcher.RemoveOwner). Returns: (The call handle, or k_uAPICallInvalid when Steam refused the call.)

#### EnumerateUserPublishedFilesAsync

```pascal
function EnumerateUserPublishedFilesAsync(unStartIndex: UInt32; AHandler: TSteamCallResultEvent): SteamAPICall_t;
```

Calls `EnumerateUserPublishedFiles` and registers AHandler for its result (`RemoteStorageEnumerateUserPublishedFilesResult_t`). The handler's object owns the registration (remove it with Steam.Dispatcher.RemoveOwner). Returns: (The call handle, or k_uAPICallInvalid when Steam refused the call.)

#### SubscribePublishedFileAsync

```pascal
function SubscribePublishedFileAsync(unPublishedFileId: PublishedFileId_t; AHandler: TSteamCallResultEvent): SteamAPICall_t;
```

Calls `SubscribePublishedFile` and registers AHandler for its result (`RemoteStorageSubscribePublishedFileResult_t`). The handler's object owns the registration (remove it with Steam.Dispatcher.RemoveOwner). Returns: (The call handle, or k_uAPICallInvalid when Steam refused the call.)

#### EnumerateUserSubscribedFilesAsync

```pascal
function EnumerateUserSubscribedFilesAsync(unStartIndex: UInt32; AHandler: TSteamCallResultEvent): SteamAPICall_t;
```

Calls `EnumerateUserSubscribedFiles` and registers AHandler for its result (`RemoteStorageEnumerateUserSubscribedFilesResult_t`). The handler's object owns the registration (remove it with Steam.Dispatcher.RemoveOwner). Returns: (The call handle, or k_uAPICallInvalid when Steam refused the call.)

#### UnsubscribePublishedFileAsync

```pascal
function UnsubscribePublishedFileAsync(unPublishedFileId: PublishedFileId_t; AHandler: TSteamCallResultEvent): SteamAPICall_t;
```

Calls `UnsubscribePublishedFile` and registers AHandler for its result (`RemoteStorageUnsubscribePublishedFileResult_t`). The handler's object owns the registration (remove it with Steam.Dispatcher.RemoveOwner). Returns: (The call handle, or k_uAPICallInvalid when Steam refused the call.)

#### GetPublishedItemVoteDetailsAsync

```pascal
function GetPublishedItemVoteDetailsAsync(unPublishedFileId: PublishedFileId_t; AHandler: TSteamCallResultEvent): SteamAPICall_t;
```

Calls `GetPublishedItemVoteDetails` and registers AHandler for its result (`RemoteStorageGetPublishedItemVoteDetailsResult_t`). The handler's object owns the registration (remove it with Steam.Dispatcher.RemoveOwner). Returns: (The call handle, or k_uAPICallInvalid when Steam refused the call.)

#### UpdateUserPublishedItemVoteAsync

```pascal
function UpdateUserPublishedItemVoteAsync(unPublishedFileId: PublishedFileId_t; bVoteUp: Boolean; AHandler: TSteamCallResultEvent): SteamAPICall_t;
```

Calls `UpdateUserPublishedItemVote` and registers AHandler for its result (`RemoteStorageUpdateUserPublishedItemVoteResult_t`). The handler's object owns the registration (remove it with Steam.Dispatcher.RemoveOwner). Returns: (The call handle, or k_uAPICallInvalid when Steam refused the call.)

#### GetUserPublishedItemVoteDetailsAsync

```pascal
function GetUserPublishedItemVoteDetailsAsync(unPublishedFileId: PublishedFileId_t; AHandler: TSteamCallResultEvent): SteamAPICall_t;
```

Calls `GetUserPublishedItemVoteDetails` and registers AHandler for its result (`RemoteStorageGetPublishedItemVoteDetailsResult_t`). The handler's object owns the registration (remove it with Steam.Dispatcher.RemoveOwner). Returns: (The call handle, or k_uAPICallInvalid when Steam refused the call.)

#### EnumerateUserSharedWorkshopFilesAsync

```pascal
function EnumerateUserSharedWorkshopFilesAsync(const steamId: TSteamID; unStartIndex: UInt32; var pRequiredTags: SteamParamStringArray_t; var pExcludedTags: SteamParamStringArray_t; AHandler: TSteamCallResultEvent): SteamAPICall_t;
```

Calls `EnumerateUserSharedWorkshopFiles` and registers AHandler for its result (`RemoteStorageEnumerateUserPublishedFilesResult_t`). The handler's object owns the registration (remove it with Steam.Dispatcher.RemoveOwner). Returns: (The call handle, or k_uAPICallInvalid when Steam refused the call.)

#### PublishVideoAsync

```pascal
function PublishVideoAsync(eVideoProvider: EWorkshopVideoProvider; const pchVideoAccount: string; const pchVideoIdentifier: string; const pchPreviewFile: string; nConsumerAppId: AppId_t; const pchTitle: string; const pchDescription: string; eVisibility: ERemoteStoragePublishedFileVisibility; var pTags: SteamParamStringArray_t; AHandler: TSteamCallResultEvent): SteamAPICall_t;
```

Calls `PublishVideo` and registers AHandler for its result (`RemoteStoragePublishFileProgress_t`). The handler's object owns the registration (remove it with Steam.Dispatcher.RemoveOwner). Returns: (The call handle, or k_uAPICallInvalid when Steam refused the call.)

#### SetUserPublishedFileActionAsync

```pascal
function SetUserPublishedFileActionAsync(unPublishedFileId: PublishedFileId_t; eAction: EWorkshopFileAction; AHandler: TSteamCallResultEvent): SteamAPICall_t;
```

Calls `SetUserPublishedFileAction` and registers AHandler for its result (`RemoteStorageSetUserPublishedFileActionResult_t`). The handler's object owns the registration (remove it with Steam.Dispatcher.RemoveOwner). Returns: (The call handle, or k_uAPICallInvalid when Steam refused the call.)

#### EnumeratePublishedFilesByUserActionAsync

```pascal
function EnumeratePublishedFilesByUserActionAsync(eAction: EWorkshopFileAction; unStartIndex: UInt32; AHandler: TSteamCallResultEvent): SteamAPICall_t;
```

Calls `EnumeratePublishedFilesByUserAction` and registers AHandler for its result (`RemoteStorageEnumeratePublishedFilesByUserActionResult_t`). The handler's object owns the registration (remove it with Steam.Dispatcher.RemoveOwner). Returns: (The call handle, or k_uAPICallInvalid when Steam refused the call.)

#### EnumeratePublishedWorkshopFilesAsync

```pascal
function EnumeratePublishedWorkshopFilesAsync(eEnumerationType: EWorkshopEnumerationType; unStartIndex: UInt32; unCount: UInt32; unDays: UInt32; var pTags: SteamParamStringArray_t; var pUserTags: SteamParamStringArray_t; AHandler: TSteamCallResultEvent): SteamAPICall_t;
```

Calls `EnumeratePublishedWorkshopFiles` and registers AHandler for its result (`RemoteStorageEnumerateWorkshopFilesResult_t`). The handler's object owns the registration (remove it with Steam.Dispatcher.RemoveOwner). Returns: (The call handle, or k_uAPICallInvalid when Steam refused the call.)

#### UGCDownloadToLocationAsync

```pascal
function UGCDownloadToLocationAsync(hContent: UGCHandle_t; const pchLocation: string; unPriority: UInt32; AHandler: TSteamCallResultEvent): SteamAPICall_t;
```

Calls `UGCDownloadToLocation` and registers AHandler for its result (`RemoteStorageDownloadUGCResult_t`). The handler's object owns the registration (remove it with Steam.Dispatcher.RemoveOwner). Returns: (The call handle, or k_uAPICallInvalid when Steam refused the call.)

### Properties

| Property | Description |
|----------|-------------|
| `Handle: Pointer` | The raw ISteamRemoteStorage pointer (first argument of every `Flat` export). |
| `Flat: TSteamRemoteStorageFlat` | The bound flat exports, for calls the methods do not cover. |

## Payload records

Declared in `Steamworks.SDKTypes` (generated from the SDK headers; layouts verified
against the C headers for Win64, Win32, Linux64 and macOS ARM64).

### RemoteStorageFileShareResult_t

Callback id 1307 (`RemoteStorageFileShareResult_t_k_iCallback`).

| Field | C declaration |
|-------|---------------|
| `m_eResult: EResult` | C field `EResult m_eResult`. |
| `m_hFile: UGCHandle_t` | C field `UGCHandle_t m_hFile`. |
| `m_rgchFilename: array[0..259] of AnsiChar` | C field `char [260] m_rgchFilename`. |

### RemoteStoragePublishFileResult_t

Callback id 1309 (`RemoteStoragePublishFileResult_t_k_iCallback`).

| Field | C declaration |
|-------|---------------|
| `m_eResult: EResult` | C field `EResult m_eResult`. |
| `m_nPublishedFileId: PublishedFileId_t` | C field `PublishedFileId_t m_nPublishedFileId`. |
| `m_bUserNeedsToAcceptWorkshopLegalAgreement: Boolean` | C field `bool m_bUserNeedsToAcceptWorkshopLegalAgreement`. |

### RemoteStorageDeletePublishedFileResult_t

Callback id 1311 (`RemoteStorageDeletePublishedFileResult_t_k_iCallback`).

| Field | C declaration |
|-------|---------------|
| `m_eResult: EResult` | C field `EResult m_eResult`. |
| `m_nPublishedFileId: PublishedFileId_t` | C field `PublishedFileId_t m_nPublishedFileId`. |

### RemoteStorageEnumerateUserPublishedFilesResult_t

Callback id 1312 (`RemoteStorageEnumerateUserPublishedFilesResult_t_k_iCallback`).

| Field | C declaration |
|-------|---------------|
| `m_eResult: EResult` | C field `EResult m_eResult`. |
| `m_nResultsReturned: Int32` | C field `int32 m_nResultsReturned`. |
| `m_nTotalResultCount: Int32` | C field `int32 m_nTotalResultCount`. |
| `m_rgPublishedFileId: array[0..49] of PublishedFileId_t` | C field `PublishedFileId_t [50] m_rgPublishedFileId`. |

### RemoteStorageSubscribePublishedFileResult_t

Callback id 1313 (`RemoteStorageSubscribePublishedFileResult_t_k_iCallback`).

| Field | C declaration |
|-------|---------------|
| `m_eResult: EResult` | C field `EResult m_eResult`. |
| `m_nPublishedFileId: PublishedFileId_t` | C field `PublishedFileId_t m_nPublishedFileId`. |

### RemoteStorageEnumerateUserSubscribedFilesResult_t

Callback id 1314 (`RemoteStorageEnumerateUserSubscribedFilesResult_t_k_iCallback`).

| Field | C declaration |
|-------|---------------|
| `m_eResult: EResult` | C field `EResult m_eResult`. |
| `m_nResultsReturned: Int32` | C field `int32 m_nResultsReturned`. |
| `m_nTotalResultCount: Int32` | C field `int32 m_nTotalResultCount`. |
| `m_rgPublishedFileId: array[0..49] of PublishedFileId_t` | C field `PublishedFileId_t [50] m_rgPublishedFileId`. |
| `m_rgRTimeSubscribed: array[0..49] of UInt32` | C field `uint32 [50] m_rgRTimeSubscribed`. |

### RemoteStorageUnsubscribePublishedFileResult_t

Callback id 1315 (`RemoteStorageUnsubscribePublishedFileResult_t_k_iCallback`).

| Field | C declaration |
|-------|---------------|
| `m_eResult: EResult` | C field `EResult m_eResult`. |
| `m_nPublishedFileId: PublishedFileId_t` | C field `PublishedFileId_t m_nPublishedFileId`. |

### RemoteStorageUpdatePublishedFileResult_t

Callback id 1316 (`RemoteStorageUpdatePublishedFileResult_t_k_iCallback`).

| Field | C declaration |
|-------|---------------|
| `m_eResult: EResult` | C field `EResult m_eResult`. |
| `m_nPublishedFileId: PublishedFileId_t` | C field `PublishedFileId_t m_nPublishedFileId`. |
| `m_bUserNeedsToAcceptWorkshopLegalAgreement: Boolean` | C field `bool m_bUserNeedsToAcceptWorkshopLegalAgreement`. |

### RemoteStorageDownloadUGCResult_t

Callback id 1317 (`RemoteStorageDownloadUGCResult_t_k_iCallback`).

| Field | C declaration |
|-------|---------------|
| `m_eResult: EResult` | C field `EResult m_eResult`. |
| `m_hFile: UGCHandle_t` | C field `UGCHandle_t m_hFile`. |
| `m_nAppID: AppId_t` | C field `AppId_t m_nAppID`. |
| `m_nSizeInBytes: Int32` | C field `int32 m_nSizeInBytes`. |
| `m_pchFileName: array[0..259] of AnsiChar` | C field `char [260] m_pchFileName`. |
| `m_ulSteamIDOwner: UInt64` | C field `uint64 m_ulSteamIDOwner`. |

### RemoteStorageGetPublishedFileDetailsResult_t

Callback id 1318 (`RemoteStorageGetPublishedFileDetailsResult_t_k_iCallback`).

| Field | C declaration |
|-------|---------------|
| `m_eResult: EResult` | C field `EResult m_eResult`. |
| `m_nPublishedFileId: PublishedFileId_t` | C field `PublishedFileId_t m_nPublishedFileId`. |
| `m_nCreatorAppID: AppId_t` | C field `AppId_t m_nCreatorAppID`. |
| `m_nConsumerAppID: AppId_t` | C field `AppId_t m_nConsumerAppID`. |
| `m_rgchTitle: array[0..128] of AnsiChar` | C field `char [129] m_rgchTitle`. |
| `m_rgchDescription: array[0..7999] of AnsiChar` | C field `char [8000] m_rgchDescription`. |
| `m_hFile: UGCHandle_t` | C field `UGCHandle_t m_hFile`. |
| `m_hPreviewFile: UGCHandle_t` | C field `UGCHandle_t m_hPreviewFile`. |
| `m_ulSteamIDOwner: UInt64` | C field `uint64 m_ulSteamIDOwner`. |
| `m_rtimeCreated: UInt32` | C field `uint32 m_rtimeCreated`. |
| `m_rtimeUpdated: UInt32` | C field `uint32 m_rtimeUpdated`. |
| `m_eVisibility: ERemoteStoragePublishedFileVisibility` | C field `ERemoteStoragePublishedFileVisibility m_eVisibility`. |
| `m_bBanned: Boolean` | C field `bool m_bBanned`. |
| `m_rgchTags: array[0..1024] of AnsiChar` | C field `char [1025] m_rgchTags`. |
| `m_bTagsTruncated: Boolean` | C field `bool m_bTagsTruncated`. |
| `m_pchFileName: array[0..259] of AnsiChar` | C field `char [260] m_pchFileName`. |
| `m_nFileSize: Int32` | C field `int32 m_nFileSize`. |
| `m_nPreviewFileSize: Int32` | C field `int32 m_nPreviewFileSize`. |
| `m_rgchURL: array[0..255] of AnsiChar` | C field `char [256] m_rgchURL`. |
| `m_eFileType: EWorkshopFileType` | C field `EWorkshopFileType m_eFileType`. |
| `m_bAcceptedForUse: Boolean` | C field `bool m_bAcceptedForUse`. |

### RemoteStorageEnumerateWorkshopFilesResult_t

Callback id 1319 (`RemoteStorageEnumerateWorkshopFilesResult_t_k_iCallback`).

| Field | C declaration |
|-------|---------------|
| `m_eResult: EResult` | C field `EResult m_eResult`. |
| `m_nResultsReturned: Int32` | C field `int32 m_nResultsReturned`. |
| `m_nTotalResultCount: Int32` | C field `int32 m_nTotalResultCount`. |
| `m_rgPublishedFileId: array[0..49] of PublishedFileId_t` | C field `PublishedFileId_t [50] m_rgPublishedFileId`. |
| `m_rgScore: array[0..49] of Single` | C field `float [50] m_rgScore`. |
| `m_nAppId: AppId_t` | C field `AppId_t m_nAppId`. |
| `m_unStartIndex: UInt32` | C field `uint32 m_unStartIndex`. |

### RemoteStorageGetPublishedItemVoteDetailsResult_t

Callback id 1320 (`RemoteStorageGetPublishedItemVoteDetailsResult_t_k_iCallback`).

| Field | C declaration |
|-------|---------------|
| `m_eResult: EResult` | C field `EResult m_eResult`. |
| `m_unPublishedFileId: PublishedFileId_t` | C field `PublishedFileId_t m_unPublishedFileId`. |
| `m_nVotesFor: Int32` | C field `int32 m_nVotesFor`. |
| `m_nVotesAgainst: Int32` | C field `int32 m_nVotesAgainst`. |
| `m_nReports: Int32` | C field `int32 m_nReports`. |
| `m_fScore: Single` | C field `float m_fScore`. |

### RemoteStoragePublishedFileSubscribed_t

Callback id 1321 (`RemoteStoragePublishedFileSubscribed_t_k_iCallback`).

| Field | C declaration |
|-------|---------------|
| `m_nPublishedFileId: PublishedFileId_t` | C field `PublishedFileId_t m_nPublishedFileId`. |
| `m_nAppID: AppId_t` | C field `AppId_t m_nAppID`. |

### RemoteStoragePublishedFileUnsubscribed_t

Callback id 1322 (`RemoteStoragePublishedFileUnsubscribed_t_k_iCallback`).

| Field | C declaration |
|-------|---------------|
| `m_nPublishedFileId: PublishedFileId_t` | C field `PublishedFileId_t m_nPublishedFileId`. |
| `m_nAppID: AppId_t` | C field `AppId_t m_nAppID`. |

### RemoteStoragePublishedFileDeleted_t

Callback id 1323 (`RemoteStoragePublishedFileDeleted_t_k_iCallback`).

| Field | C declaration |
|-------|---------------|
| `m_nPublishedFileId: PublishedFileId_t` | C field `PublishedFileId_t m_nPublishedFileId`. |
| `m_nAppID: AppId_t` | C field `AppId_t m_nAppID`. |

### RemoteStorageUpdateUserPublishedItemVoteResult_t

Callback id 1324 (`RemoteStorageUpdateUserPublishedItemVoteResult_t_k_iCallback`).

| Field | C declaration |
|-------|---------------|
| `m_eResult: EResult` | C field `EResult m_eResult`. |
| `m_nPublishedFileId: PublishedFileId_t` | C field `PublishedFileId_t m_nPublishedFileId`. |

### RemoteStorageUserVoteDetails_t

Callback id 1325 (`RemoteStorageUserVoteDetails_t_k_iCallback`).

| Field | C declaration |
|-------|---------------|
| `m_eResult: EResult` | C field `EResult m_eResult`. |
| `m_nPublishedFileId: PublishedFileId_t` | C field `PublishedFileId_t m_nPublishedFileId`. |
| `m_eVote: EWorkshopVote` | C field `EWorkshopVote m_eVote`. |

### RemoteStorageEnumerateUserSharedWorkshopFilesResult_t

Callback id 1326 (`RemoteStorageEnumerateUserSharedWorkshopFilesResult_t_k_iCallback`).

| Field | C declaration |
|-------|---------------|
| `m_eResult: EResult` | C field `EResult m_eResult`. |
| `m_nResultsReturned: Int32` | C field `int32 m_nResultsReturned`. |
| `m_nTotalResultCount: Int32` | C field `int32 m_nTotalResultCount`. |
| `m_rgPublishedFileId: array[0..49] of PublishedFileId_t` | C field `PublishedFileId_t [50] m_rgPublishedFileId`. |

### RemoteStorageSetUserPublishedFileActionResult_t

Callback id 1327 (`RemoteStorageSetUserPublishedFileActionResult_t_k_iCallback`).

| Field | C declaration |
|-------|---------------|
| `m_eResult: EResult` | C field `EResult m_eResult`. |
| `m_nPublishedFileId: PublishedFileId_t` | C field `PublishedFileId_t m_nPublishedFileId`. |
| `m_eAction: EWorkshopFileAction` | C field `EWorkshopFileAction m_eAction`. |

### RemoteStorageEnumeratePublishedFilesByUserActionResult_t

Callback id 1328 (`RemoteStorageEnumeratePublishedFilesByUserActionResult_t_k_iCallback`).

| Field | C declaration |
|-------|---------------|
| `m_eResult: EResult` | C field `EResult m_eResult`. |
| `m_eAction: EWorkshopFileAction` | C field `EWorkshopFileAction m_eAction`. |
| `m_nResultsReturned: Int32` | C field `int32 m_nResultsReturned`. |
| `m_nTotalResultCount: Int32` | C field `int32 m_nTotalResultCount`. |
| `m_rgPublishedFileId: array[0..49] of PublishedFileId_t` | C field `PublishedFileId_t [50] m_rgPublishedFileId`. |
| `m_rgRTimeUpdated: array[0..49] of UInt32` | C field `uint32 [50] m_rgRTimeUpdated`. |

### RemoteStoragePublishFileProgress_t

Callback id 1329 (`RemoteStoragePublishFileProgress_t_k_iCallback`).

| Field | C declaration |
|-------|---------------|
| `m_dPercentFile: Double` | C field `double m_dPercentFile`. |
| `m_bPreview: Boolean` | C field `bool m_bPreview`. |

### RemoteStoragePublishedFileUpdated_t

Callback id 1330 (`RemoteStoragePublishedFileUpdated_t_k_iCallback`).

| Field | C declaration |
|-------|---------------|
| `m_nPublishedFileId: PublishedFileId_t` | C field `PublishedFileId_t m_nPublishedFileId`. |
| `m_nAppID: AppId_t` | C field `AppId_t m_nAppID`. |
| `m_ulUnused: UInt64` | C field `uint64 m_ulUnused`. |

### RemoteStorageFileWriteAsyncComplete_t

Callback id 1331 (`RemoteStorageFileWriteAsyncComplete_t_k_iCallback`).

| Field | C declaration |
|-------|---------------|
| `m_eResult: EResult` | C field `EResult m_eResult`. |

### RemoteStorageFileReadAsyncComplete_t

Callback id 1332 (`RemoteStorageFileReadAsyncComplete_t_k_iCallback`).

| Field | C declaration |
|-------|---------------|
| `m_hFileReadAsync: SteamAPICall_t` | C field `SteamAPICall_t m_hFileReadAsync`. |
| `m_eResult: EResult` | C field `EResult m_eResult`. |
| `m_nOffset: UInt32` | C field `uint32 m_nOffset`. |
| `m_cubRead: UInt32` | C field `uint32 m_cubRead`. |

### RemoteStorageLocalFileChange_t

Callback id 1333 (`RemoteStorageLocalFileChange_t_k_iCallback`).

| Field | C declaration |
|-------|---------------|
| `_dummy: Byte` | Placeholder: the C++ struct is empty (sizeof = 1). |
