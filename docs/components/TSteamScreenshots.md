# TSteamScreenshots and TSteamScreenshotsPlugin (ISteamScreenshots)

> **Generated** by `tools/gen_docs.py` from `lib/plugins/Steamworks.Plugin.Screenshots.pas` - do not edit.
> Hand-written text: `tools/doc_extras/Screenshots.md`. Steam's own descriptions are Valve's
> SDK comments, as in the generated units.

Unit: `Steamworks.Plugin.Screenshots` - linking it (a `uses` entry, or dropping a `TSteamScreenshots`) enables the
plug-in. Steam interface: `ISteamScreenshots` (SDK 1.65).

## Overview

The Steam screenshot library. By default the overlay takes screenshots
itself when the user presses the hotkey (F12) and the game needs nothing
from this interface. Use it to take screenshots from game code, to supply
the image yourself (for example without the HUD), or to tag them.

### Letting the game take the screenshot

```pascal
procedure TForm1.SteamAPI1Initialized(Sender: TObject);
begin
  SteamScreenshots1.Plugin.HookScreenshots(True);  // hotkey -> OnScreenshotRequested
end;

procedure TForm1.SteamScreenshots1ScreenshotRequested(Sender: TObject;
  const AData: ScreenshotRequested_t);
var
  RGB: TBytes;            // Width * Height * 3 bytes, R G B, no alpha
  H: ScreenshotHandle;
begin
  RGB := RenderFrameWithoutHud(FWidth, FHeight);
  H := SteamScreenshots1.Plugin.WriteScreenshot(@RGB[0], Length(RGB), FWidth, FHeight);
  SteamScreenshots1.Plugin.SetLocation(H, CurrentLevelName);
end;

procedure TForm1.SteamScreenshots1ScreenshotReady(Sender: TObject;
  const AData: ScreenshotReady_t);
begin
  if AData.m_eResult = k_EResultOK then
    Log('Screenshot saved');
end;
```

* While hooked, Steam takes **no** screenshot of its own: the game must answer
  every `OnScreenshotRequested` with `WriteScreenshot` or
  `AddScreenshotToLibrary`. `IsScreenshotsHooked` tells the current state.
* `WriteScreenshot` takes raw 24-bit RGB (no alpha, top row first). An RGBA
  frame has to be converted first.
* `AddScreenshotToLibrary` adds a JPEG, TGA or PNG file from disk. A
  thumbnail, if given, must be 200 pixels wide with the same aspect ratio.
  The method's `string` parameters cannot pass C `NULL`: to let Steam make the
  thumbnail, call the export directly,
  `P.Flat.AddScreenshotToLibrary(P.Handle, PAnsiChar(UTF8String(FileName)), nil, W, H)`.
* `TriggerScreenshot` takes one from code (or raises `OnScreenshotRequested`
  while hooked).
* Tags: `SetLocation`, `TagUser` (a friend in the picture), `TagPublishedFile`
  (a Workshop item shown); handles are valid for the life of the process.

## Contents

* [The component: TSteamScreenshots](#the-component-tsteamscreenshots)
  * [Events (2)](#events)
* [The plug-in: TSteamScreenshotsPlugin](#the-plug-in-tsteamscreenshotsplugin)
  * [Methods](#methods)
  * [Async methods](#async-methods)
  * [Properties](#properties)
* [Payload records](#payload-records)

## The component: TSteamScreenshots

ISteamScreenshots component: drop it next to a TSteamAPI (linked automatically at run time when the owner has exactly one, otherwise set SteamAPI). Its events are the ISteamScreenshots callbacks; call the interface through `Plugin`.

| Member | Kind | Description |
|--------|------|-------------|
| `SteamAPI` | published property | The `TSteamAPI` this component belongs to. At run time a component whose owner has exactly one `TSteamAPI` links itself. |
| `Plugin` | public property | The `TSteamScreenshotsPlugin` for calls; `nil` while Steam is not running. |
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
| `OnScreenshotReady` | 2301 | [`ScreenshotReady_t`](#screenshotready_t) | Screenshot successfully written or otherwise added to the library and can now be tagged. |
| `OnScreenshotRequested` | 2302 | [`ScreenshotRequested_t`](#screenshotrequested_t) | Screenshot has been requested by the user. Only sent if HookScreenshots() has been called, in which case Steam will not take the screenshot itself. |

Handler signature (the IDE generates it when you double-click the event):

```pascal
procedure TForm1.SteamScreenshots1ScreenshotReady(Sender: TObject; const AData: ScreenshotReady_t);
```

## The plug-in: TSteamScreenshotsPlugin

ISteamScreenshots plug-in. Registered by linking the unit; find it with @code(Steam.FindPlugin(TSteamScreenshotsPlugin)).

Reach it through the component (`SteamScreenshots1.Plugin`) or the core:

```pascal
P := TSteamScreenshotsPlugin(Steam.FindPlugin(TSteamScreenshotsPlugin));   // Delphi also: Steam.Plugin<TSteamScreenshotsPlugin>
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
| [`WriteScreenshot`](#writescreenshot) | Writes a screenshot to the user's screenshot library given the raw image data, which must be in RGB format. The return value is a handle that is valid for ... |
| [`AddScreenshotToLibrary`](#addscreenshottolibrary) | Adds a screenshot to the user's screenshot library from disk. If a thumbnail is provided, it must be 200 pixels wide and the same aspect ratio as the ... |
| [`TriggerScreenshot`](#triggerscreenshot) | Causes the Steam overlay to take a screenshot. If screenshots are being hooked by the game then a ScreenshotRequested_t callback is sent back to the game ... |
| [`HookScreenshots`](#hookscreenshots) | Toggles whether the overlay handles screenshots when the user presses the screenshot hotkey, or the game handles them. If the game is hooking screenshots, ... |
| [`SetLocation`](#setlocation) | Sets metadata about a screenshot's location (for example, the name of the map). |
| [`TagUser`](#taguser) | Tags a user as being visible in the screenshot. |
| [`TagPublishedFile`](#tagpublishedfile) | Tags a published file as being visible in the screenshot. |
| [`IsScreenshotsHooked`](#isscreenshotshooked) | Returns true if the app has hooked the screenshot. |
| [`AddVRScreenshotToLibrary`](#addvrscreenshottolibrary) | Adds a VR screenshot to the user's screenshot library from disk in the supported type. pchFilename should be the normal 2D image used in the library view ... |

#### WriteScreenshot

```pascal
function WriteScreenshot(pubRGB: Pointer; cubRGB: UInt32; nWidth: Integer; nHeight: Integer): ScreenshotHandle;
```

Writes a screenshot to the user's screenshot library given the raw image data, which must be in RGB format. The return value is a handle that is valid for the duration of the game process and can be used to apply tags.

#### AddScreenshotToLibrary

```pascal
function AddScreenshotToLibrary(const pchFilename: string; const pchThumbnailFilename: string; nWidth: Integer; nHeight: Integer): ScreenshotHandle;
```

Adds a screenshot to the user's screenshot library from disk. If a thumbnail is provided, it must be 200 pixels wide and the same aspect ratio as the screenshot, otherwise a thumbnail will be generated if the user uploads the screenshot. The screenshots must be in either JPEG or TGA format. The return value is a handle that is valid for the duration of the game process and can be used to apply tags. JPEG, TGA, and PNG formats are supported.

#### TriggerScreenshot

```pascal
procedure TriggerScreenshot;
```

Causes the Steam overlay to take a screenshot. If screenshots are being hooked by the game then a ScreenshotRequested_t callback is sent back to the game instead.

#### HookScreenshots

```pascal
procedure HookScreenshots(bHook: Boolean);
```

Toggles whether the overlay handles screenshots when the user presses the screenshot hotkey, or the game handles them. If the game is hooking screenshots, then the ScreenshotRequested_t callback will be sent if the user presses the hotkey, and the game is expected to call WriteScreenshot or AddScreenshotToLibrary in response.

#### SetLocation

```pascal
function SetLocation(hScreenshot: ScreenshotHandle; const pchLocation: string): Boolean;
```

Sets metadata about a screenshot's location (for example, the name of the map).

#### TagUser

```pascal
function TagUser(hScreenshot: ScreenshotHandle; const steamID: TSteamID): Boolean;
```

Tags a user as being visible in the screenshot.

#### TagPublishedFile

```pascal
function TagPublishedFile(hScreenshot: ScreenshotHandle; unPublishedFileID: PublishedFileId_t): Boolean;
```

Tags a published file as being visible in the screenshot.

#### IsScreenshotsHooked

```pascal
function IsScreenshotsHooked: Boolean;
```

Returns true if the app has hooked the screenshot.

#### AddVRScreenshotToLibrary

```pascal
function AddVRScreenshotToLibrary(eType: EVRScreenshotType; const pchFilename: string; const pchVRFilename: string): ScreenshotHandle;
```

Adds a VR screenshot to the user's screenshot library from disk in the supported type. pchFilename should be the normal 2D image used in the library view pchVRFilename should contain the image that matches the correct type The return value is a handle that is valid for the duration of the game process and can be used to apply tags. JPEG, TGA, and PNG formats are supported.

### Async methods

None.

### Properties

| Property | Description |
|----------|-------------|
| `Handle: Pointer` | The raw ISteamScreenshots pointer (first argument of every `Flat` export). |
| `Flat: TSteamScreenshotsFlat` | The bound flat exports, for calls the methods do not cover. |

## Payload records

Declared in `Steamworks.SDKTypes` (generated from the SDK headers; layouts verified
against the C headers for Win64, Win32, Linux64 and macOS ARM64).

### ScreenshotReady_t

Callback id 2301 (`ScreenshotReady_t_k_iCallback`).

| Field | C declaration |
|-------|---------------|
| `m_hLocal: ScreenshotHandle` | C field `ScreenshotHandle m_hLocal`. |
| `m_eResult: EResult` | C field `EResult m_eResult`. |

### ScreenshotRequested_t

Callback id 2302 (`ScreenshotRequested_t_k_iCallback`).

| Field | C declaration |
|-------|---------------|
| `_dummy: Byte` | Placeholder: the C++ struct is empty (sizeof = 1). |
