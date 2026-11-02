# TSteamHTMLSurface and TSteamHTMLSurfacePlugin (ISteamHTMLSurface)

> **Generated** by `tools/gen_docs.py` from `lib/plugins/Steamworks.Plugin.HTMLSurface.pas` - do not edit.
> Hand-written text: `tools/doc_extras/HTMLSurface.md`. Steam's own descriptions are Valve's
> SDK comments, as in the generated units.

Unit: `Steamworks.Plugin.HTMLSurface` - linking it (a `uses` entry, or dropping a `TSteamHTMLSurface`) enables the
plug-in. Steam interface: `ISteamHTMLSurface` (SDK 1.65).

## Overview

A web browser (Chromium in the Steam client) that renders off-screen into
pixel buffers for the game to draw - in-game store pages, news, sign-in
pages. The game owns the drawing and the input:

```pascal
procedure TForm1.OpenBrowser;
begin
  SteamHTMLSurface1.Plugin.Init;
  SteamHTMLSurface1.Plugin.CreateBrowser('', '');    // -> OnHTML_BrowserReady
end;

procedure TForm1.SteamHTMLSurface1HTML_BrowserReady(Sender: TObject;
  const AData: HTML_BrowserReady_t);
begin
  FBrowser := AData.unBrowserHandle;
  SteamHTMLSurface1.Plugin.SetSize(FBrowser, 1024, 768);
  SteamHTMLSurface1.Plugin.LoadURL(FBrowser, 'https://store.steampowered.com/', '');
end;

procedure TForm1.SteamHTMLSurface1HTML_NeedsPaint(Sender: TObject;
  const AData: HTML_NeedsPaint_t);
begin
  // AData.pBGRA: unWide x unTall pixels, BGRA, valid only inside this event
  CopyToTexture(AData.pBGRA, AData.unWide, AData.unTall);
end;
```

* **Valve requires handlers** for `OnHTML_StartRequest` (answer with
  `AllowStartRequest`), `OnHTML_JSAlert` / `OnHTML_JSConfirm` (answer with
  `JSDialogResponse`) and `OnHTML_FileOpenDialog` (answer with
  `FileLoadDialogResponse`) - a page waits until they are answered.
* Input goes in with `MouseMove`, `MouseDown`, `MouseUp`, `MouseWheel`,
  `KeyDown`, `KeyUp`, `KeyChar` and `SetKeyFocus`. Key modifiers are bit
  flags: `k_eHTMLKeyModifier_CtrlDown or k_eHTMLKeyModifier_ShiftDown`.
* Finish with `RemoveBrowser` for each browser, then `Shutdown`.

## Contents

* [The component: TSteamHTMLSurface](#the-component-tsteamhtmlsurface)
  * [Events (23)](#events)
* [The plug-in: TSteamHTMLSurfacePlugin](#the-plug-in-tsteamhtmlsurfaceplugin)
  * [Methods](#methods)
  * [Async methods](#async-methods)
  * [Properties](#properties)
* [Payload records](#payload-records)

## The component: TSteamHTMLSurface

ISteamHTMLSurface component: drop it next to a TSteamAPI (linked automatically at run time when the owner has exactly one, otherwise set SteamAPI). Its events are the ISteamHTMLSurface callbacks; call the interface through `Plugin`.

| Member | Kind | Description |
|--------|------|-------------|
| `SteamAPI` | published property | The `TSteamAPI` this component belongs to. At run time a component whose owner has exactly one `TSteamAPI` links itself. |
| `Plugin` | public property | The `TSteamHTMLSurfacePlugin` for calls; `nil` while Steam is not running. |
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
| `OnHTML_BrowserReady` | 4501 | [`HTML_BrowserReady_t`](#html_browserready_t) | The browser is ready for use. |
| `OnHTML_NeedsPaint` | 4502 | [`HTML_NeedsPaint_t`](#html_needspaint_t) | the browser has a pending paint. |
| `OnHTML_StartRequest` | 4503 | [`HTML_StartRequest_t`](#html_startrequest_t) | The browser wanted to navigate to a new page NOTE - you MUST call AllowStartRequest in response to this callback. |
| `OnHTML_CloseBrowser` | 4504 | [`HTML_CloseBrowser_t`](#html_closebrowser_t) | The browser has been requested to close due to user interaction (usually from a javascript window.close() call). |
| `OnHTML_URLChanged` | 4505 | [`HTML_URLChanged_t`](#html_urlchanged_t) | the browser is navigating to a new url. |
| `OnHTML_FinishedRequest` | 4506 | [`HTML_FinishedRequest_t`](#html_finishedrequest_t) | A page is finished loading. |
| `OnHTML_OpenLinkInNewTab` | 4507 | [`HTML_OpenLinkInNewTab_t`](#html_openlinkinnewtab_t) | a request to load this url in a new tab. |
| `OnHTML_ChangedTitle` | 4508 | [`HTML_ChangedTitle_t`](#html_changedtitle_t) | the page has a new title now. |
| `OnHTML_SearchResults` | 4509 | [`HTML_SearchResults_t`](#html_searchresults_t) | results from a search. |
| `OnHTML_CanGoBackAndForward` | 4510 | [`HTML_CanGoBackAndForward_t`](#html_cangobackandforward_t) | page history status changed on the ability to go backwards and forward. |
| `OnHTML_HorizontalScroll` | 4511 | [`HTML_HorizontalScroll_t`](#html_horizontalscroll_t) | details on the visibility and size of the horizontal scrollbar. |
| `OnHTML_VerticalScroll` | 4512 | [`HTML_VerticalScroll_t`](#html_verticalscroll_t) | details on the visibility and size of the vertical scrollbar. |
| `OnHTML_LinkAtPosition` | 4513 | [`HTML_LinkAtPosition_t`](#html_linkatposition_t) | response to GetLinkAtPosition call. |
| `OnHTML_JSAlert` | 4514 | [`HTML_JSAlert_t`](#html_jsalert_t) | show a Javascript alert dialog, call JSDialogResponse when the user dismisses this dialog (or right away to ignore it). |
| `OnHTML_JSConfirm` | 4515 | [`HTML_JSConfirm_t`](#html_jsconfirm_t) | show a Javascript confirmation dialog, call JSDialogResponse when the user dismisses this dialog (or right away to ignore it). |
| `OnHTML_FileOpenDialog` | 4516 | [`HTML_FileOpenDialog_t`](#html_fileopendialog_t) | when received show a file open dialog then call FileLoadDialogResponse with the file(s) the user selected. |
| `OnHTML_NewWindow` | 4521 | [`HTML_NewWindow_t`](#html_newwindow_t) | a new html window is being created. IMPORTANT NOTE: at this time, the API does not allow you to acknowledge or render the contents of this new window, so the new window is always destroyed immediately. The URL and other parameters of the new window are passed here to give your application the opportunity to call CreateBrowser and set up a new browser in response to the attempted popup, if you wish to do so. |
| `OnHTML_SetCursor` | 4522 | [`HTML_SetCursor_t`](#html_setcursor_t) | change the cursor to display. |
| `OnHTML_StatusText` | 4523 | [`HTML_StatusText_t`](#html_statustext_t) | informational message from the browser. |
| `OnHTML_ShowToolTip` | 4524 | [`HTML_ShowToolTip_t`](#html_showtooltip_t) | show a tooltip. |
| `OnHTML_UpdateToolTip` | 4525 | [`HTML_UpdateToolTip_t`](#html_updatetooltip_t) | update the text of an existing tooltip. |
| `OnHTML_HideToolTip` | 4526 | [`HTML_HideToolTip_t`](#html_hidetooltip_t) | hide the tooltip you are showing. |
| `OnHTML_BrowserRestarted` | 4527 | [`HTML_BrowserRestarted_t`](#html_browserrestarted_t) | The browser has restarted due to an internal failure, use this new handle value. |

Handler signature (the IDE generates it when you double-click the event):

```pascal
procedure TForm1.SteamHTMLSurface1HTML_BrowserReady(Sender: TObject; const AData: HTML_BrowserReady_t);
```

## The plug-in: TSteamHTMLSurfacePlugin

ISteamHTMLSurface plug-in. Registered by linking the unit; find it with @code(Steam.FindPlugin(TSteamHTMLSurfacePlugin)).

Reach it through the component (`SteamHTMLSurface1.Plugin`) or the core:

```pascal
P := TSteamHTMLSurfacePlugin(Steam.FindPlugin(TSteamHTMLSurfacePlugin));   // Delphi also: Steam.Plugin<TSteamHTMLSurfacePlugin>
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
| [`Init`](#init) | Must call init and shutdown when starting/ending use of the interface. |
| [`Shutdown`](#shutdown) | Wraps `SteamAPI_ISteamHTMLSurface_Shutdown`. |
| [`CreateBrowser`](#createbrowser) | Create a browser object for display of a html page, when creation is complete the call handle will return a HTML_BrowserReady_t callback for the ... |
| [`RemoveBrowser`](#removebrowser) | Call this when you are done with a html surface, this lets us free the resources being used by it. |
| [`LoadURL`](#loadurl) | Navigate to this URL, results in a HTML_StartRequest_t as the request commences. |
| [`SetSize`](#setsize) | Tells the surface the size in pixels to display the surface. |
| [`StopLoad`](#stopload) | Stop the load of the current html page. |
| [`Reload`](#reload) | Reload (most likely from local cache) the current page. |
| [`GoBack`](#goback) | navigate back in the page history. |
| [`GoForward`](#goforward) | navigate forward in the page history. |
| [`AddHeader`](#addheader) | add this header to any url requests from this browser. |
| [`ExecuteJavascript`](#executejavascript) | run this javascript script in the currently loaded page. |
| [`MouseUp`](#mouseup) | Mouse click and mouse movement commands. |
| [`MouseDown`](#mousedown) | Wraps `SteamAPI_ISteamHTMLSurface_MouseDown`. |
| [`MouseDoubleClick`](#mousedoubleclick) | Wraps `SteamAPI_ISteamHTMLSurface_MouseDoubleClick`. |
| [`MouseMove`](#mousemove) | x and y are relative to the HTML bounds. |
| [`MouseWheel`](#mousewheel) | nDelta is pixels of scroll. |
| [`KeyDown`](#keydown) | keyboard interactions, native keycode is the virtual key code value from your OS, system key flags the key to not be sent as a typed character as well as a ... |
| [`KeyUp`](#keyup) | Wraps `SteamAPI_ISteamHTMLSurface_KeyUp`. |
| [`KeyChar`](#keychar) | cUnicodeChar is the unicode character point for this keypress (and potentially multiple chars per press). |
| [`SetHorizontalScroll`](#sethorizontalscroll) | programmatically scroll this many pixels on the page. |
| [`SetVerticalScroll`](#setverticalscroll) | Wraps `SteamAPI_ISteamHTMLSurface_SetVerticalScroll`. |
| [`SetKeyFocus`](#setkeyfocus) | tell the html control if it has key focus currently, controls showing the I-beam cursor in text controls amongst other things. |
| [`ViewSource`](#viewsource) | open the current pages html code in the local editor of choice, used for debugging. |
| [`CopyToClipboard`](#copytoclipboard) | copy the currently selected text on the html page to the local clipboard. |
| [`PasteFromClipboard`](#pastefromclipboard) | paste from the local clipboard to the current html page. |
| [`Find`](#find) | find this string in the browser, if bCurrentlyInFind is true then instead cycle to the next matching element. |
| [`StopFind`](#stopfind) | cancel a currently running find. |
| [`GetLinkAtPosition`](#getlinkatposition) | return details about the link at position x,y on the current page. |
| [`SetCookie`](#setcookie) | set a webcookie for the hostname in question. |
| [`SetPageScaleFactor`](#setpagescalefactor) | Zoom the current page by flZoom ( from 0.0 to 2.0, so to zoom to 120% use 1.2 ), zooming around point X,Y in the page (use 0,0 if you don't care). |
| [`SetBackgroundMode`](#setbackgroundmode) | Enable/disable low-resource background mode, where javascript and repaint timers are throttled, resources are more aggressively purged from memory, and ... |
| [`SetDPIScalingFactor`](#setdpiscalingfactor) | Scale the output display space by this factor, this is useful when displaying content on high dpi devices. Specifies the ratio between physical and logical ... |
| [`OpenDeveloperTools`](#opendevelopertools) | Open HTML/JS developer tools. |
| [`AllowStartRequest`](#allowstartrequest) | You MUST call this in response to a HTML_StartRequest_t callback Set bAllowed to true to allow this navigation, false to cancel it and stay on the current ... |
| [`JSDialogResponse`](#jsdialogresponse) | You MUST call this in response to a HTML_JSAlert_t or HTML_JSConfirm_t callback Set bResult to true for the OK option of a confirm, use false otherwise. |
| [`FileLoadDialogResponse`](#fileloaddialogresponse) | You MUST call this in response to a HTML_FileOpenDialog_t callback. |

#### Init

```pascal
function Init: Boolean;
```

Must call init and shutdown when starting/ending use of the interface.

#### Shutdown

```pascal
function Shutdown: Boolean;
```

Wraps `SteamAPI_ISteamHTMLSurface_Shutdown`.

#### CreateBrowser

```pascal
function CreateBrowser(const pchUserAgent: string; const pchUserCSS: string): SteamAPICall_t;
```

Create a browser object for display of a html page, when creation is complete the call handle will return a HTML_BrowserReady_t callback for the HHTMLBrowser of your new browser. The user agent string is a substring to be added to the general user agent string so you can identify your client on web servers. The userCSS string lets you apply a CSS style sheet to every displayed page, leave null if you do not require this functionality. YOU MUST HAVE IMPLEMENTED HANDLERS FOR HTML_BrowserReady_t, HTML_StartRequest_t, HTML_JSAlert_t, HTML_JSConfirm_t, and HTML_FileOpenDialog_t! See the CALLBACKS section of this interface (AllowStartRequest, etc) for more details. If you do not implement these callback handlers, the browser may appear to hang instead of navigating to new pages or triggering javascript popups. Call result: `HTML_BrowserReady_t` (`HTML_BrowserReady_t_k_iCallback`).

#### RemoveBrowser

```pascal
procedure RemoveBrowser(unBrowserHandle: HHTMLBrowser);
```

Call this when you are done with a html surface, this lets us free the resources being used by it.

#### LoadURL

```pascal
procedure LoadURL(unBrowserHandle: HHTMLBrowser; const pchURL: string; const pchPostData: string);
```

Navigate to this URL, results in a HTML_StartRequest_t as the request commences.

#### SetSize

```pascal
procedure SetSize(unBrowserHandle: HHTMLBrowser; unWidth: UInt32; unHeight: UInt32);
```

Tells the surface the size in pixels to display the surface.

#### StopLoad

```pascal
procedure StopLoad(unBrowserHandle: HHTMLBrowser);
```

Stop the load of the current html page.

#### Reload

```pascal
procedure Reload(unBrowserHandle: HHTMLBrowser);
```

Reload (most likely from local cache) the current page.

#### GoBack

```pascal
procedure GoBack(unBrowserHandle: HHTMLBrowser);
```

navigate back in the page history.

#### GoForward

```pascal
procedure GoForward(unBrowserHandle: HHTMLBrowser);
```

navigate forward in the page history.

#### AddHeader

```pascal
procedure AddHeader(unBrowserHandle: HHTMLBrowser; const pchKey: string; const pchValue: string);
```

add this header to any url requests from this browser.

#### ExecuteJavascript

```pascal
procedure ExecuteJavascript(unBrowserHandle: HHTMLBrowser; const pchScript: string);
```

run this javascript script in the currently loaded page.

#### MouseUp

```pascal
procedure MouseUp(unBrowserHandle: HHTMLBrowser; eMouseButton: EHTMLMouseButton);
```

Mouse click and mouse movement commands.

#### MouseDown

```pascal
procedure MouseDown(unBrowserHandle: HHTMLBrowser; eMouseButton: EHTMLMouseButton);
```

Wraps `SteamAPI_ISteamHTMLSurface_MouseDown`.

#### MouseDoubleClick

```pascal
procedure MouseDoubleClick(unBrowserHandle: HHTMLBrowser; eMouseButton: EHTMLMouseButton);
```

Wraps `SteamAPI_ISteamHTMLSurface_MouseDoubleClick`.

#### MouseMove

```pascal
procedure MouseMove(unBrowserHandle: HHTMLBrowser; x: Integer; y: Integer);
```

x and y are relative to the HTML bounds.

#### MouseWheel

```pascal
procedure MouseWheel(unBrowserHandle: HHTMLBrowser; nDelta: Int32);
```

nDelta is pixels of scroll.

#### KeyDown

```pascal
procedure KeyDown(unBrowserHandle: HHTMLBrowser; nNativeKeyCode: UInt32; AEHTMLKeyModifiers: EHTMLKeyModifiers; bIsSystemKey: Boolean);
```

keyboard interactions, native keycode is the virtual key code value from your OS, system key flags the key to not be sent as a typed character as well as a key down.

#### KeyUp

```pascal
procedure KeyUp(unBrowserHandle: HHTMLBrowser; nNativeKeyCode: UInt32; AEHTMLKeyModifiers: EHTMLKeyModifiers);
```

Wraps `SteamAPI_ISteamHTMLSurface_KeyUp`.

#### KeyChar

```pascal
procedure KeyChar(unBrowserHandle: HHTMLBrowser; cUnicodeChar: UInt32; AEHTMLKeyModifiers: EHTMLKeyModifiers);
```

cUnicodeChar is the unicode character point for this keypress (and potentially multiple chars per press).

#### SetHorizontalScroll

```pascal
procedure SetHorizontalScroll(unBrowserHandle: HHTMLBrowser; nAbsolutePixelScroll: UInt32);
```

programmatically scroll this many pixels on the page.

#### SetVerticalScroll

```pascal
procedure SetVerticalScroll(unBrowserHandle: HHTMLBrowser; nAbsolutePixelScroll: UInt32);
```

Wraps `SteamAPI_ISteamHTMLSurface_SetVerticalScroll`.

#### SetKeyFocus

```pascal
procedure SetKeyFocus(unBrowserHandle: HHTMLBrowser; bHasKeyFocus: Boolean);
```

tell the html control if it has key focus currently, controls showing the I-beam cursor in text controls amongst other things.

#### ViewSource

```pascal
procedure ViewSource(unBrowserHandle: HHTMLBrowser);
```

open the current pages html code in the local editor of choice, used for debugging.

#### CopyToClipboard

```pascal
procedure CopyToClipboard(unBrowserHandle: HHTMLBrowser);
```

copy the currently selected text on the html page to the local clipboard.

#### PasteFromClipboard

```pascal
procedure PasteFromClipboard(unBrowserHandle: HHTMLBrowser);
```

paste from the local clipboard to the current html page.

#### Find

```pascal
procedure Find(unBrowserHandle: HHTMLBrowser; const pchSearchStr: string; bCurrentlyInFind: Boolean; bReverse: Boolean);
```

find this string in the browser, if bCurrentlyInFind is true then instead cycle to the next matching element.

#### StopFind

```pascal
procedure StopFind(unBrowserHandle: HHTMLBrowser);
```

cancel a currently running find.

#### GetLinkAtPosition

```pascal
procedure GetLinkAtPosition(unBrowserHandle: HHTMLBrowser; x: Integer; y: Integer);
```

return details about the link at position x,y on the current page.

#### SetCookie

```pascal
procedure SetCookie(const pchHostname: string; const pchKey: string; const pchValue: string; const pchPath: string; nExpires: RTime32; bSecure: Boolean; bHTTPOnly: Boolean);
```

set a webcookie for the hostname in question.

#### SetPageScaleFactor

```pascal
procedure SetPageScaleFactor(unBrowserHandle: HHTMLBrowser; flZoom: Single; nPointX: Integer; nPointY: Integer);
```

Zoom the current page by flZoom ( from 0.0 to 2.0, so to zoom to 120% use 1.2 ), zooming around point X,Y in the page (use 0,0 if you don't care).

#### SetBackgroundMode

```pascal
procedure SetBackgroundMode(unBrowserHandle: HHTMLBrowser; bBackgroundMode: Boolean);
```

Enable/disable low-resource background mode, where javascript and repaint timers are throttled, resources are more aggressively purged from memory, and audio/video elements are paused. When background mode is enabled, all HTML5 video and audio objects will execute ".pause()" and gain the property "._steam_background_paused = 1". When background mode is disabled, any video or audio objects with that property will resume with ".play()".

#### SetDPIScalingFactor

```pascal
procedure SetDPIScalingFactor(unBrowserHandle: HHTMLBrowser; flDPIScaling: Single);
```

Scale the output display space by this factor, this is useful when displaying content on high dpi devices. Specifies the ratio between physical and logical pixels.

#### OpenDeveloperTools

```pascal
procedure OpenDeveloperTools(unBrowserHandle: HHTMLBrowser);
```

Open HTML/JS developer tools.

#### AllowStartRequest

```pascal
procedure AllowStartRequest(unBrowserHandle: HHTMLBrowser; bAllowed: Boolean);
```

You MUST call this in response to a HTML_StartRequest_t callback Set bAllowed to true to allow this navigation, false to cancel it and stay on the current page. You can use this feature to limit the valid pages allowed in your HTML surface.

#### JSDialogResponse

```pascal
procedure JSDialogResponse(unBrowserHandle: HHTMLBrowser; bResult: Boolean);
```

You MUST call this in response to a HTML_JSAlert_t or HTML_JSConfirm_t callback Set bResult to true for the OK option of a confirm, use false otherwise.

#### FileLoadDialogResponse

```pascal
procedure FileLoadDialogResponse(unBrowserHandle: HHTMLBrowser; pchSelectedFiles: Pointer);
```

You MUST call this in response to a HTML_FileOpenDialog_t callback.

### Async methods

Each `...Async` method starts the call and registers `AHandler` for its result
(`procedure(const AData: TSteamCallbackData; AIOFailure: Boolean) of object`). The
handler runs once, on the delivery thread, with the result record in `AData`
(`AData.CopyTo(Rec, SizeOf(Rec))`); its object owns the registration - call
`Steam.Dispatcher.RemoveOwner(Self)` in that object's destructor. The plain method of
the same name returns the `SteamAPICall_t` instead, and its result reaches the
component's event.

#### CreateBrowserAsync

```pascal
function CreateBrowserAsync(const pchUserAgent: string; const pchUserCSS: string; AHandler: TSteamCallResultEvent): SteamAPICall_t;
```

Calls `CreateBrowser` and registers AHandler for its result (`HTML_BrowserReady_t`). The handler's object owns the registration (remove it with Steam.Dispatcher.RemoveOwner). Returns: (The call handle, or k_uAPICallInvalid when Steam refused the call.)

### Properties

| Property | Description |
|----------|-------------|
| `Handle: Pointer` | The raw ISteamHTMLSurface pointer (first argument of every `Flat` export). |
| `Flat: TSteamHTMLSurfaceFlat` | The bound flat exports, for calls the methods do not cover. |

## Payload records

Declared in `Steamworks.SDKTypes` (generated from the SDK headers; layouts verified
against the C headers for Win64, Win32, Linux64 and macOS ARM64).

### HTML_BrowserReady_t

Callback id 4501 (`HTML_BrowserReady_t_k_iCallback`).

| Field | C declaration |
|-------|---------------|
| `unBrowserHandle: HHTMLBrowser` | C field `HHTMLBrowser unBrowserHandle`. |

### HTML_NeedsPaint_t

Callback id 4502 (`HTML_NeedsPaint_t_k_iCallback`).

| Field | C declaration |
|-------|---------------|
| `unBrowserHandle: HHTMLBrowser` | C field `HHTMLBrowser unBrowserHandle`. |
| `pBGRA: PAnsiChar` | C field `const char * pBGRA`. |
| `unWide: UInt32` | C field `uint32 unWide`. |
| `unTall: UInt32` | C field `uint32 unTall`. |
| `unUpdateX: UInt32` | C field `uint32 unUpdateX`. |
| `unUpdateY: UInt32` | C field `uint32 unUpdateY`. |
| `unUpdateWide: UInt32` | C field `uint32 unUpdateWide`. |
| `unUpdateTall: UInt32` | C field `uint32 unUpdateTall`. |
| `unScrollX: UInt32` | C field `uint32 unScrollX`. |
| `unScrollY: UInt32` | C field `uint32 unScrollY`. |
| `flPageScale: Single` | C field `float flPageScale`. |
| `unPageSerial: UInt32` | C field `uint32 unPageSerial`. |

### HTML_StartRequest_t

Callback id 4503 (`HTML_StartRequest_t_k_iCallback`).

| Field | C declaration |
|-------|---------------|
| `unBrowserHandle: HHTMLBrowser` | C field `HHTMLBrowser unBrowserHandle`. |
| `pchURL: PAnsiChar` | C field `const char * pchURL`. |
| `pchTarget: PAnsiChar` | C field `const char * pchTarget`. |
| `pchPostData: PAnsiChar` | C field `const char * pchPostData`. |
| `bIsRedirect: Boolean` | C field `bool bIsRedirect`. |

### HTML_CloseBrowser_t

Callback id 4504 (`HTML_CloseBrowser_t_k_iCallback`).

| Field | C declaration |
|-------|---------------|
| `unBrowserHandle: HHTMLBrowser` | C field `HHTMLBrowser unBrowserHandle`. |

### HTML_URLChanged_t

Callback id 4505 (`HTML_URLChanged_t_k_iCallback`).

| Field | C declaration |
|-------|---------------|
| `unBrowserHandle: HHTMLBrowser` | C field `HHTMLBrowser unBrowserHandle`. |
| `pchURL: PAnsiChar` | C field `const char * pchURL`. |
| `pchPostData: PAnsiChar` | C field `const char * pchPostData`. |
| `bIsRedirect: Boolean` | C field `bool bIsRedirect`. |
| `pchPageTitle: PAnsiChar` | C field `const char * pchPageTitle`. |
| `bNewNavigation: Boolean` | C field `bool bNewNavigation`. |

### HTML_FinishedRequest_t

Callback id 4506 (`HTML_FinishedRequest_t_k_iCallback`).

| Field | C declaration |
|-------|---------------|
| `unBrowserHandle: HHTMLBrowser` | C field `HHTMLBrowser unBrowserHandle`. |
| `pchURL: PAnsiChar` | C field `const char * pchURL`. |
| `pchPageTitle: PAnsiChar` | C field `const char * pchPageTitle`. |

### HTML_OpenLinkInNewTab_t

Callback id 4507 (`HTML_OpenLinkInNewTab_t_k_iCallback`).

| Field | C declaration |
|-------|---------------|
| `unBrowserHandle: HHTMLBrowser` | C field `HHTMLBrowser unBrowserHandle`. |
| `pchURL: PAnsiChar` | C field `const char * pchURL`. |

### HTML_ChangedTitle_t

Callback id 4508 (`HTML_ChangedTitle_t_k_iCallback`).

| Field | C declaration |
|-------|---------------|
| `unBrowserHandle: HHTMLBrowser` | C field `HHTMLBrowser unBrowserHandle`. |
| `pchTitle: PAnsiChar` | C field `const char * pchTitle`. |

### HTML_SearchResults_t

Callback id 4509 (`HTML_SearchResults_t_k_iCallback`).

| Field | C declaration |
|-------|---------------|
| `unBrowserHandle: HHTMLBrowser` | C field `HHTMLBrowser unBrowserHandle`. |
| `unResults: UInt32` | C field `uint32 unResults`. |
| `unCurrentMatch: UInt32` | C field `uint32 unCurrentMatch`. |

### HTML_CanGoBackAndForward_t

Callback id 4510 (`HTML_CanGoBackAndForward_t_k_iCallback`).

| Field | C declaration |
|-------|---------------|
| `unBrowserHandle: HHTMLBrowser` | C field `HHTMLBrowser unBrowserHandle`. |
| `bCanGoBack: Boolean` | C field `bool bCanGoBack`. |
| `bCanGoForward: Boolean` | C field `bool bCanGoForward`. |

### HTML_HorizontalScroll_t

Callback id 4511 (`HTML_HorizontalScroll_t_k_iCallback`).

| Field | C declaration |
|-------|---------------|
| `unBrowserHandle: HHTMLBrowser` | C field `HHTMLBrowser unBrowserHandle`. |
| `unScrollMax: UInt32` | C field `uint32 unScrollMax`. |
| `unScrollCurrent: UInt32` | C field `uint32 unScrollCurrent`. |
| `flPageScale: Single` | C field `float flPageScale`. |
| `bVisible: Boolean` | C field `bool bVisible`. |
| `unPageSize: UInt32` | C field `uint32 unPageSize`. |

### HTML_VerticalScroll_t

Callback id 4512 (`HTML_VerticalScroll_t_k_iCallback`).

| Field | C declaration |
|-------|---------------|
| `unBrowserHandle: HHTMLBrowser` | C field `HHTMLBrowser unBrowserHandle`. |
| `unScrollMax: UInt32` | C field `uint32 unScrollMax`. |
| `unScrollCurrent: UInt32` | C field `uint32 unScrollCurrent`. |
| `flPageScale: Single` | C field `float flPageScale`. |
| `bVisible: Boolean` | C field `bool bVisible`. |
| `unPageSize: UInt32` | C field `uint32 unPageSize`. |

### HTML_LinkAtPosition_t

Callback id 4513 (`HTML_LinkAtPosition_t_k_iCallback`).

| Field | C declaration |
|-------|---------------|
| `unBrowserHandle: HHTMLBrowser` | C field `HHTMLBrowser unBrowserHandle`. |
| `x: UInt32` | C field `uint32 x`. |
| `y: UInt32` | C field `uint32 y`. |
| `pchURL: PAnsiChar` | C field `const char * pchURL`. |
| `bInput: Boolean` | C field `bool bInput`. |
| `bLiveLink: Boolean` | C field `bool bLiveLink`. |

### HTML_JSAlert_t

Callback id 4514 (`HTML_JSAlert_t_k_iCallback`).

| Field | C declaration |
|-------|---------------|
| `unBrowserHandle: HHTMLBrowser` | C field `HHTMLBrowser unBrowserHandle`. |
| `pchMessage: PAnsiChar` | C field `const char * pchMessage`. |

### HTML_JSConfirm_t

Callback id 4515 (`HTML_JSConfirm_t_k_iCallback`).

| Field | C declaration |
|-------|---------------|
| `unBrowserHandle: HHTMLBrowser` | C field `HHTMLBrowser unBrowserHandle`. |
| `pchMessage: PAnsiChar` | C field `const char * pchMessage`. |

### HTML_FileOpenDialog_t

Callback id 4516 (`HTML_FileOpenDialog_t_k_iCallback`).

| Field | C declaration |
|-------|---------------|
| `unBrowserHandle: HHTMLBrowser` | C field `HHTMLBrowser unBrowserHandle`. |
| `pchTitle: PAnsiChar` | C field `const char * pchTitle`. |
| `pchInitialFile: PAnsiChar` | C field `const char * pchInitialFile`. |

### HTML_NewWindow_t

Callback id 4521 (`HTML_NewWindow_t_k_iCallback`).

| Field | C declaration |
|-------|---------------|
| `unBrowserHandle: HHTMLBrowser` | C field `HHTMLBrowser unBrowserHandle`. |
| `pchURL: PAnsiChar` | C field `const char * pchURL`. |
| `unX: UInt32` | C field `uint32 unX`. |
| `unY: UInt32` | C field `uint32 unY`. |
| `unWide: UInt32` | C field `uint32 unWide`. |
| `unTall: UInt32` | C field `uint32 unTall`. |
| `unNewWindow_BrowserHandle_IGNORE: HHTMLBrowser` | C field `HHTMLBrowser unNewWindow_BrowserHandle_IGNORE`. |

### HTML_SetCursor_t

Callback id 4522 (`HTML_SetCursor_t_k_iCallback`).

| Field | C declaration |
|-------|---------------|
| `unBrowserHandle: HHTMLBrowser` | C field `HHTMLBrowser unBrowserHandle`. |
| `eMouseCursor: UInt32` | C field `uint32 eMouseCursor`. |

### HTML_StatusText_t

Callback id 4523 (`HTML_StatusText_t_k_iCallback`).

| Field | C declaration |
|-------|---------------|
| `unBrowserHandle: HHTMLBrowser` | C field `HHTMLBrowser unBrowserHandle`. |
| `pchMsg: PAnsiChar` | C field `const char * pchMsg`. |

### HTML_ShowToolTip_t

Callback id 4524 (`HTML_ShowToolTip_t_k_iCallback`).

| Field | C declaration |
|-------|---------------|
| `unBrowserHandle: HHTMLBrowser` | C field `HHTMLBrowser unBrowserHandle`. |
| `pchMsg: PAnsiChar` | C field `const char * pchMsg`. |

### HTML_UpdateToolTip_t

Callback id 4525 (`HTML_UpdateToolTip_t_k_iCallback`).

| Field | C declaration |
|-------|---------------|
| `unBrowserHandle: HHTMLBrowser` | C field `HHTMLBrowser unBrowserHandle`. |
| `pchMsg: PAnsiChar` | C field `const char * pchMsg`. |

### HTML_HideToolTip_t

Callback id 4526 (`HTML_HideToolTip_t_k_iCallback`).

| Field | C declaration |
|-------|---------------|
| `unBrowserHandle: HHTMLBrowser` | C field `HHTMLBrowser unBrowserHandle`. |

### HTML_BrowserRestarted_t

Callback id 4527 (`HTML_BrowserRestarted_t_k_iCallback`).

| Field | C declaration |
|-------|---------------|
| `unBrowserHandle: HHTMLBrowser` | C field `HHTMLBrowser unBrowserHandle`. |
| `unOldBrowserHandle: HHTMLBrowser` | C field `HHTMLBrowser unOldBrowserHandle`. |
