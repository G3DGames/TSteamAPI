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
