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
