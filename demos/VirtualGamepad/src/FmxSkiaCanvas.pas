{ @abstract(Windows build under Wine / Proton: Skia's canvases for FMX -
  raster (CPU) or Vulkan (GPU) - when TSAPI_FMX_CANVAS asks for them.)

  Companion of FmxWineCanvas, for programs that have Skia enabled (Project
  > Enable Skia; VirtualGamepad). FmxWineCanvas reads TSAPI_FMX_CANVAS and,
  for @code(skia) or @code(vulkan), turns Direct2D off; this unit's
  initialization - which runs right after it (list it directly after
  FmxWineCanvas in the .dpr), before Application.Initialize and the first
  form - then switches FMX to Skia:
  @unorderedList(
    @item(@code(skia): GlobalUseSkia, GlobalUseSkiaRasterWhenAvailable =
      @true - TSkRasterCanvas, drawn on the CPU and copied with GDI BitBlt.)
    @item(@code(vulkan): GlobalUseSkia, GlobalUseSkiaRasterWhenAvailable =
      @false - TVkCanvas, drawn on the GPU through Vulkan (Delphi 13.2 or
      newer). Proton runs Vulkan natively, so this is the canvas most
      likely to draw a full-screen 3D view at speed there.)
  )
  Gorilla3D's documentation (v1.5, Core / Skia) asks for exactly this
  place: GlobalUseSkia has no effect - and raises in Debug builds - once
  FMX's canvas service has started. Skia canvases repaint the whole form
  on every change; Gorilla3D 1.5.1+ merges those repaints into its frames.

  The IDE's "Enable Skia" also writes @code(GlobalUseSkia := True;) into
  the .dpr: REMOVE that line, so Skia is only used when asked for here.
  Skia's library (sk4d.dll / libsk4d.so) is deployed by the IDE.

  Not under Wine, and on every platform but Windows, nothing changes.
  @link(FmxSkiaCanvasNote) says what was done, for the program's log. }
unit FmxSkiaCanvas;

interface

{ What this unit did at start-up, for the program's log.
  @returns('' when it did nothing (not under Wine, or neither skia nor
    vulkan was asked for).) }
function FmxSkiaCanvasNote: string;

implementation

{$IFDEF MSWINDOWS}
uses
  System.SysUtils, FMX.Skia, FmxWineCanvas;
{$ENDIF}

var
  { The decision, kept for @link(FmxSkiaCanvasNote). }
  Note: string;

function FmxSkiaCanvasNote: string;
begin
  Result := Note;
end;

{$IFDEF MSWINDOWS}
{ Switches FMX to Skia when FmxWineCanvas chose skia or vulkan. }
procedure Apply;
var
  C: TFmxWineCanvas;
begin
  if not FmxWineCanvasActive then
    Exit;
  C := FmxWineCanvasChoice;
  if not (C in [fwcSkia, fwcVulkan]) then
    Exit;
  GlobalUseSkia := True;
  GlobalUseSkiaRasterWhenAvailable := C = fwcSkia;
  Note := Format('Skia on for %s=%s: GlobalUseSkia True, GlobalUseSkiaRasterWhenAvailable %s',
    [FMX_WINE_CANVAS_ENV, FMX_WINE_CANVAS_NAMES[C], BoolToStr(GlobalUseSkiaRasterWhenAvailable, True)]);
end;

initialization
  Apply;
{$ENDIF}
end.
