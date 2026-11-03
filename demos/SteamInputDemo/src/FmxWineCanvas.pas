{ @abstract(Windows builds under Wine / Proton: which canvas FMX draws with -
  workaround for an all-white window, and a switch to compare canvases.)

  FMX on Windows draws every form through Direct2D and clips each control
  with D2D layers. Wine's own d2d1.dll (Proton 11.0, owner's ROG Ally,
  2026-11-03) has PushLayer, PopLayer and PushAxisAlignedClip as stubs
  ("fixme:d2d:... stub!" thousands of times in PROTON_LOG), so everything
  FMX draws is thrown away: the window stays white with only the native
  menu bar - the program itself runs normally behind it.

  Using this unit, a Windows build that finds itself under Wine (ntdll
  exports wine_get_version) chooses FMX's canvas in this unit's
  initialization - before Application.Initialize and the first form. The
  environment variable @link(FMX_WINE_CANVAS_ENV) picks it (Steam: Launch
  Options @code(TSAPI_FMX_CANVAS=gpu %command%)):
  @unorderedList(
    @item(@code(gdi) (default) - GDI+, which Wine implements: CONFIRMED to
      draw (SteamInputDemo, VirtualGamepad), but on the CPU, so a
      continuously redrawn 3D view is slow.)
    @item(@code(gpu) - FMX's GPU canvas: draws through the Direct3D 11
      context (under Proton: DXVK / Vulkan). UNTESTED under Proton.)
    @item(@code(d2d) - Direct2D, FMX's normal choice: white window under
      Proton 11.0; for testing a later Wine.)
    @item(@code(none) - this unit changes nothing: FMX (or the program's
      own .dpr, e.g. @code(GlobalUseSkia := True)) decides - a baseline, and
      the way to switch the workaround off.)
    @item(@code(skia) / @code(vulkan) - Skia's raster canvas (CPU) / its
      Vulkan canvas TVkCanvas (GPU; Delphi 13.2 or newer). This unit only
      turns Direct2D off; the switch to Skia is made by the unit
      FmxSkiaCanvas, which only a program with Skia enabled carries
      (VirtualGamepad). Without it the program draws with GDI+.)
  )
  The workaround is only about Direct2D: a renderer that does not use it
  (Skia, FMX's GPU canvas, a later FMX on Vulkan) needs none of this.
  @link(FmxCanvasClassName) names the canvas FMX REALLY uses, whatever was
  asked for - log it once a form exists.
  An unknown value is reported and the default is used. On real Windows,
  and on every other platform, nothing changes. @link(FmxWineCanvasNote)
  says what was decided and @link(FmxWineCanvasName) which canvas, for the
  program's log.

  Four identical copies (demos/SteamInputDemo/src, demos/VirtualGamepad/src,
  demos/SteamDemo/src, RemoteLogging/LogReceiver/src - projects use only
  their own sources); tools/project_check.py reports any difference. }
unit FmxWineCanvas;

interface

type
  { The canvases FMX can draw with on Windows. }
  TFmxWineCanvas = (
    { GDI+ (CPU). }
    fwcGdi,
    { FMX's GPU canvas (Direct3D 11). }
    fwcGpu,
    { Direct2D (FMX's normal choice). }
    fwcD2D,
    { Change nothing: FMX / the program decides. }
    fwcNone,
    { Skia's raster canvas (needs the unit FmxSkiaCanvas). }
    fwcSkia,
    { Skia's Vulkan canvas TVkCanvas (needs the unit FmxSkiaCanvas). }
    fwcVulkan
  );

const
  { Environment variable that picks the canvas under Wine. }
  FMX_WINE_CANVAS_ENV = 'TSAPI_FMX_CANVAS';
  { The values of @link(FMX_WINE_CANVAS_ENV), one per canvas. }
  FMX_WINE_CANVAS_NAMES: array[TFmxWineCanvas] of string = ('gdi', 'gpu', 'd2d', 'none', 'skia', 'vulkan');
  { The canvas used under Wine when @link(FMX_WINE_CANVAS_ENV) is not set. }
  FMX_WINE_CANVAS_DEFAULT = fwcGdi;

{ What this unit decided at start-up, for the program's log.
  @returns('' when the program is not running under Wine (always '' off
    Windows).) }
function FmxWineCanvasNote: string;

{ The canvas chosen under Wine, as named in @link(FMX_WINE_CANVAS_NAMES).
  @returns('' when the program is not running under Wine: FMX then draws
    the way it normally does.) }
function FmxWineCanvasName: string;

{ @true when the program runs under Wine (this unit then chose a canvas). }
function FmxWineCanvasActive: Boolean;

{ The canvas chosen under Wine (@link(FMX_WINE_CANVAS_DEFAULT) when the
  program is not running under Wine). }
function FmxWineCanvasChoice: TFmxWineCanvas;

{ The class of the canvas FMX really draws with (e.g. TCanvasD2D,
  TCanvasGdiPlus, TCanvasGpu, a Skia canvas) - true whatever this unit or
  the program asked for, on every platform. Call it once a form exists.
  @returns(The class name, or why it is not known.) }
function FmxCanvasClassName: string;

implementation

uses
  {$IFDEF MSWINDOWS}Winapi.Windows, System.StrUtils,{$ENDIF}
  System.SysUtils, FMX.Types, FMX.Graphics;

var
  { The decision, kept for @link(FmxWineCanvasNote). }
  Note: string;
  { The canvas name, kept for @link(FmxWineCanvasName). }
  CanvasName: string;
  { Kept for @link(FmxWineCanvasActive). }
  WineActive: Boolean;
  { Kept for @link(FmxWineCanvasChoice). }
  Choice: TFmxWineCanvas = FMX_WINE_CANVAS_DEFAULT;

function FmxWineCanvasNote: string;
begin
  Result := Note;
end;

function FmxWineCanvasName: string;
begin
  Result := CanvasName;
end;

function FmxWineCanvasActive: Boolean;
begin
  Result := WineActive;
end;

function FmxWineCanvasChoice: TFmxWineCanvas;
begin
  Result := Choice;
end;

function FmxCanvasClassName: string;
var
  C: TCanvasClass;
begin
  try
    C := TCanvasManager.DefaultCanvas;
    if C = nil then
      Result := 'none registered'
    else
      Result := C.ClassName;
  except
    on E: Exception do
      Result := 'unknown (' + E.ClassName + ': ' + E.Message + ')';
  end;
end;

{$IFDEF MSWINDOWS}
type
  { Wine's ntdll wine_get_version (cdecl). }
  TWineGetVersion = function: PAnsiChar; cdecl;

{ Picks FMX's canvas when running under Wine (see the unit's description). }
procedure Apply;
var
  GetVersion: TWineGetVersion;
  Version, Wanted, Problem: string;
  C, Chosen: TFmxWineCanvas;
  Found: Boolean;
begin
  @GetVersion := GetProcAddress(GetModuleHandle('ntdll.dll'), 'wine_get_version');
  if not Assigned(GetVersion) then
    Exit;   // real Windows
  Version := string(AnsiString(GetVersion()));
  Chosen := FMX_WINE_CANVAS_DEFAULT;
  Problem := '';
  Wanted := LowerCase(Trim(System.SysUtils.GetEnvironmentVariable(FMX_WINE_CANVAS_ENV)));
  if Wanted <> '' then
  begin
    Found := False;
    for C := Low(TFmxWineCanvas) to High(TFmxWineCanvas) do
      if Wanted = FMX_WINE_CANVAS_NAMES[C] then
      begin
        Chosen := C;
        Found := True;
      end;
    if not Found then
    begin
      Problem := '';
      for C := Low(TFmxWineCanvas) to High(TFmxWineCanvas) do
        Problem := Problem + IfThen(Problem <> '', ', ') + FMX_WINE_CANVAS_NAMES[C];
      Problem := Format('; %s=%s is unknown (use one of: %s)', [FMX_WINE_CANVAS_ENV, Wanted, Problem]);
    end;
  end;
  case Chosen of
    fwcGdi:
      begin
        GlobalUseDirect2D := False;
        GlobalUseGPUCanvas := False;
      end;
    fwcGpu:
      begin
        GlobalUseDirect2D := False;   // GDI+, not Direct2D, if the GPU canvas cannot start
        GlobalUseGPUCanvas := True;
      end;
    fwcD2D:
      begin
        GlobalUseDirect2D := True;
        GlobalUseGPUCanvas := False;
      end;
    fwcNone:
      ;   // FMX and the program's own settings decide
    fwcSkia, fwcVulkan:
      begin
        // FmxSkiaCanvas (if the program has it) switches Skia on; without
        // it GDI+, never the white Direct2D window
        GlobalUseDirect2D := False;
        GlobalUseGPUCanvas := False;
      end;
  end;
  WineActive := True;
  Choice := Chosen;
  CanvasName := FMX_WINE_CANVAS_NAMES[Chosen];
  Note := Format('Wine %s: FMX canvas %s (%s=%s; default %s - Wine''s Direct2D leaves FMX windows white)%s',
    [Version, CanvasName, FMX_WINE_CANVAS_ENV, IfThen(Wanted = '', '(not set)', Wanted),
     FMX_WINE_CANVAS_NAMES[FMX_WINE_CANVAS_DEFAULT], Problem]);
end;

initialization
  Apply;
{$ENDIF}
end.
