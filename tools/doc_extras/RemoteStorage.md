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
