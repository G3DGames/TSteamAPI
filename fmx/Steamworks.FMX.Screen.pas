(* @abstract(The display a FireMonkey form is on: its size in units, pixels
  and millimetres, whether Steam runs in Big Picture or on Steam hardware,
  and a suggested scale for the program's controls.)

  FMX knows a display's size in logical units and its scale, not how big
  it is. What makes a control "too small" is how big it looks from where
  the player sits: a 7" handheld at arm's length, a monitor on a desk, a
  TV across the room. @link(SteamScreenInfo) asks the system for the
  physical size and works out @link(TSteamScreenInfo.UiScale) from it:
  @unorderedList(
    @item(Windows: the monitor's EDID (registry), else GetDeviceCaps.)
    @item(macOS: CGDisplayScreenSize (CoreGraphics, loaded at run time).)
    @item(Linux: GDK 3's monitor size (libgdk-3, already loaded by FMX).)
    @item(A Steam Deck's own 1280 x 800 panel: its known size, whatever
      the system says (gamescope reports none or a made-up one).))
  Sizes the system makes up from 96 dots per inch, and EDID's aspect-only
  values (16 x 9 cm), are recognised and not used.

  The suggestion: in Big Picture (desktop Big Picture, and Game Mode on a
  Deck) and on a handheld (a diagonal under
  @link(SCREEN_HANDHELD_INCHES)) the program wants a big-screen
  interface; the viewing distance is taken as
  @link(SCREEN_DISTANCE_PER_DIAGONAL) times the diagonal (within
  @link(SCREEN_MIN_DISTANCE_MM) - @link(SCREEN_MAX_DISTANCE_MM)), and
  UiScale makes one unit look as big from there as 1/96 inch does at
  @link(SCREEN_REF_DISTANCE_MM) (desktop reading distance). Anywhere else
  UiScale is 1: the system's own scaling is the user's choice. A program
  multiplies its control sizes and font sizes by UiScale (and lets the
  user override it).

  @longCode(#
  uses Steamworks.FMX.Screen;

  procedure TMainForm.FormShow(Sender: TObject);
  var
    Info: TSteamScreenInfo;
  begin
    Info := SteamScreenInfo(Self);
    Log(Info.Text);
    if Info.BigUi then
      ApplyBigLayout(Info.UiScale);
  end;
  #)

  Works with or without Steam running (without it, Big Picture and Steam
  hardware are unknown and taken as no). Delphi only (FMX). *)
unit Steamworks.FMX.Screen;

{$I Steamworks.inc}

interface

uses
  System.SysUtils, FMX.Forms, Steamworks.SDKTypes;

const
  { Below this diagonal (inches) a display is a handheld's. }
  SCREEN_HANDHELD_INCHES = 10;
  { From this diagonal (inches) up a display is taken as a TV. }
  SCREEN_TV_INCHES = 30;
  { Desktop reading distance (mm, 28 inches): the distance at which one
    unit should look 1/96 inch big - what desktop systems scale for. }
  SCREEN_REF_DISTANCE_MM = 711;
  { Viewing distance in the big-screen interface: this many diagonals. }
  SCREEN_DISTANCE_PER_DIAGONAL = 1.6;
  { The nearest viewing distance assumed (mm; a handheld at arm's length). }
  SCREEN_MIN_DISTANCE_MM = 400;
  { The farthest viewing distance assumed (mm; a big TV). }
  SCREEN_MAX_DISTANCE_MM = 3000;
  { UiScale in Big Picture when the display's size is unknown. }
  SCREEN_UNKNOWN_BIG_SCALE = 1.5;
  { Smallest UiScale suggested. }
  SCREEN_MIN_UI_SCALE = 0.75;
  { Largest UiScale suggested. }
  SCREEN_MAX_UI_SCALE = 3.0;
  { A Steam Deck's panel, width in mm (between the 7.0" LCD and the 7.4"
    OLED model, which Steam does not tell apart). }
  SCREEN_DECK_WIDTH_MM = 155;
  { A Steam Deck's panel, height in mm. }
  SCREEN_DECK_HEIGHT_MM = 97;
  { A Steam Deck's panel, width in pixels. }
  SCREEN_DECK_PIXEL_WIDTH = 1280;
  { A Steam Deck's panel, height in pixels. }
  SCREEN_DECK_PIXEL_HEIGHT = 800;

type
  { What kind of display it is, by its diagonal. }
  TSteamScreenKind = (
    { Size unknown. }
    sskUnknown,
    { Under SCREEN_HANDHELD_INCHES. }
    sskHandheld,
    { A monitor or a laptop's screen. }
    sskMonitor,
    { SCREEN_TV_INCHES and up. }
    sskTV
  );

  { Where the physical size came from. }
  TSteamScreenSizeSource = (
    { Nowhere: unknown. }
    sssNone,
    { The monitor's EDID (Windows registry). }
    sssEdid,
    { GetDeviceCaps HORZSIZE / VERTSIZE (Windows). }
    sssDeviceCaps,
    { CGDisplayScreenSize (macOS). }
    sssCoreGraphics,
    { gdk_monitor_get_width_mm / height_mm (Linux). }
    sssGdk,
    { A Steam Deck's known panel size. }
    sssSteamDeck
  );

  { The display a form is on (@link(SteamScreenInfo)). }
  TSteamScreenInfo = record
    { Width of the display in FMX units. }
    Width: Single;
    { Height of the display in FMX units. }
    Height: Single;
    { FMX's scale of the display (pixels = units x Scale). }
    Scale: Single;
    { Width in pixels. }
    PixelWidth: Integer;
    { Height in pixels. }
    PixelHeight: Integer;
    { Physical width in mm (0 = unknown). }
    WidthMm: Single;
    { Physical height in mm (0 = unknown). }
    HeightMm: Single;
    { Where WidthMm / HeightMm came from. }
    SizeSource: TSteamScreenSizeSource;
    { What the system said and why it was not used ('' = nothing to add). }
    SizeNote: string;
    { Diagonal in inches (0 = unknown). }
    DiagonalInches: Single;
    { Handheld, monitor or TV, by DiagonalInches. }
    Kind: TSteamScreenKind;
    { Steam runs in Big Picture (desktop Big Picture or Game Mode). }
    BigPicture: Boolean;
    { What Steam hardware this is (k_ESteamHardwareTypeNone: none, or
      Steam not running). }
    SteamHardware: ESteamHardwareType;
    { The program should show its big-screen interface: Big Picture or a
      handheld. }
    BigUi: Boolean;
    { The viewing distance assumed, mm (0 when BigUi is False). }
    DistanceMm: Single;
    { Suggested multiplier for control and font sizes (1 when BigUi is
      False). }
    UiScale: Single;
    { One line for a log: everything above. }
    function Text: string;
  end;

{ Measures the display AForm is on (the main form's when AForm is nil).
  Call it once the form is shown - before, it may not be on its display
  yet - and again when it moves to another display.
  @param(AForm the form)
  @returns(the display's sizes, Steam's state and the suggestion; a
    display FMX does not know gives Width = 0) }
function SteamScreenInfo(AForm: TCommonCustomForm): TSteamScreenInfo;

{ The name of a TSteamScreenKind ('handheld', ...).
  @param(AKind the kind)
  @returns(its name) }
function SteamScreenKindName(AKind: TSteamScreenKind): string;

{ The name of a TSteamScreenSizeSource ('EDID', ...).
  @param(ASource the source)
  @returns(its name) }
function SteamScreenSourceName(ASource: TSteamScreenSizeSource): string;

implementation

uses
  System.Math,
  {$IF Defined(MSWINDOWS)}
  Winapi.Windows, System.Win.Registry, FMX.Platform.Win,
  {$ELSEIF Defined(MACOS) and not Defined(IOS)}
  Posix.Dlfcn,
  {$ELSEIF Defined(LINUX) and not Defined(ANDROID)}
  Posix.Dlfcn,
  {$ENDIF}
  Steamworks.Core, Steamworks.Plugin.Utils;

const
  { Millimetres per inch. }
  MM_PER_INCH = 25.4;
  { The made-up density some systems report a size from (dots per inch). }
  FAKE_DPI = 96;
  { How near (mm) a reported size may be to the 96 dpi one and still be
    taken as made up. }
  FAKE_TOLERANCE_MM = 2;
  { Narrowest believable display (mm). }
  MIN_WIDTH_MM = 60;
  { Smallest believable size of a pixel (mm). }
  MIN_MM_PER_PIXEL = 0.07;
  { Largest believable size of a pixel (mm). }
  MAX_MM_PER_PIXEL = 2.0;

function SteamScreenKindName(AKind: TSteamScreenKind): string;
begin
  case AKind of
    sskHandheld: Result := 'handheld';
    sskMonitor: Result := 'monitor';
    sskTV: Result := 'TV';
  else
    Result := 'unknown';
  end;
end;

function SteamScreenSourceName(ASource: TSteamScreenSizeSource): string;
begin
  case ASource of
    sssEdid: Result := 'EDID';
    sssDeviceCaps: Result := 'GetDeviceCaps';
    sssCoreGraphics: Result := 'CoreGraphics';
    sssGdk: Result := 'GDK';
    sssSteamDeck: Result := 'Steam Deck panel';
  else
    Result := 'none';
  end;
end;

{ The name of a Steam hardware type (a number for one this SDK does not
  know). }
function HardwareName(AType: ESteamHardwareType): string;
begin
  case Ord(AType) of
    Ord(k_ESteamHardwareTypeNone): Result := 'none';
    Ord(k_ESteamHardwareTypeSteamDeck): Result := 'Steam Deck';
    Ord(k_ESteamHardwareTypeSteamMachine): Result := 'Steam Machine';
    Ord(k_ESteamHardwareTypeSteamFrame): Result := 'Steam Frame';
  else
    Result := Format('type %d', [Ord(AType)]);
  end;
end;

{ Yes / no. }
function YesNo(AValue: Boolean): string;
begin
  if AValue then
    Result := 'yes'
  else
    Result := 'no';
end;

function TSteamScreenInfo.Text: string;
var
  Size: string;
begin
  if (WidthMm > 0) and (HeightMm > 0) then
    Size := Format('%.0f x %.0f mm, %.1f" (%s), %s', [WidthMm, HeightMm, DiagonalInches,
      SteamScreenSourceName(SizeSource), SteamScreenKindName(Kind)])
  else
    Size := 'size unknown';
  if SizeNote <> '' then
    Size := Size + ' [' + SizeNote + ']';
  Result := Format('screen: %.0f x %.0f units, scale %.2f (%d x %d px), %s; Big Picture %s, ' +
    'Steam hardware %s', [Width, Height, Scale, PixelWidth, PixelHeight, Size, YesNo(BigPicture),
    HardwareName(SteamHardware)]);
  if BigUi then
  begin
    if DistanceMm > 0 then
      Result := Result + Format(' -> big-screen interface, UI scale %.2f (viewing distance %.0f mm)',
        [UiScale, DistanceMm])
    else
      Result := Result + Format(' -> big-screen interface, UI scale %.2f (size unknown)', [UiScale]);
  end
  else
    Result := Result + ' -> desktop interface, UI scale 1 (the system''s own scaling)';
end;

{ Swaps AW and AH when their orientation differs from the pixels'
  (a rotated display: the system reports the panel's landscape size). }
procedure MatchOrientation(var AW, AH: Single; APixW, APixH: Integer);
var
  T: Single;
begin
  if (AW > AH) <> (APixW > APixH) then
  begin
    T := AW;
    AW := AH;
    AH := T;
  end;
end;

{ True when AW x AH mm is what a system makes up from 96 dpi for APixW x
  APixH pixels (or APixW / AScale units). }
function LooksMadeUp(AW, AH: Single; APixW, APixH: Integer; AScale: Single): Boolean;

  { Near the 96 dpi size of AW x AH pixels. }
  function Near(APW, APH: Single): Boolean;
  begin
    Result := (Abs(AW - APW * MM_PER_INCH / FAKE_DPI) <= FAKE_TOLERANCE_MM) and
      (Abs(AH - APH * MM_PER_INCH / FAKE_DPI) <= FAKE_TOLERANCE_MM);
  end;

begin
  Result := Near(APixW, APixH) or ((AScale > 0) and Near(APixW / AScale, APixH / AScale));
end;

{ Checks a reported size; clears it (and says why in ANote) when it
  cannot be the display's. }
procedure CheckSize(var AW, AH: Single; APixW, APixH: Integer; AScale: Single; ACheckMadeUp: Boolean;
  var ANote: string);
var
  Why: string;
  MmPerPixel: Single;
begin
  if (AW <= 0) or (AH <= 0) then
  begin
    AW := 0;
    AH := 0;
    Exit;
  end;
  MatchOrientation(AW, AH, APixW, APixH);
  Why := '';
  if ((Round(AW) = 160) or (Round(AW) = 1600)) and ((Round(AH) = 90) or (Round(AH) = 100) or
    (Round(AH) = 900) or (Round(AH) = 1000)) then
    Why := 'an aspect ratio, not a size'
  else if (AW < MIN_WIDTH_MM) and (AH < MIN_WIDTH_MM) then
    Why := 'too small'
  else if ACheckMadeUp and LooksMadeUp(AW, AH, APixW, APixH, AScale) then
    Why := 'made up from 96 dpi'
  else if APixW > 0 then
  begin
    MmPerPixel := Max(AW, AH) / Max(APixW, APixH);
    if (MmPerPixel < MIN_MM_PER_PIXEL) or (MmPerPixel > MAX_MM_PER_PIXEL) then
      Why := Format('%.3f mm per pixel', [MmPerPixel]);
  end;
  if Why <> '' then
  begin
    if ANote <> '' then
      ANote := ANote + '; ';
    ANote := ANote + Format('%.0f x %.0f mm ignored: %s', [AW, AH, Why]);
    AW := 0;
    AH := 0;
  end;
end;

{$IF (Defined(MACOS) and not Defined(IOS)) or (Defined(LINUX) and not Defined(ANDROID))}
{ The address of AName in the library ALib (nil when it is not there). }
function Sym(ALib: NativeUInt; const AName: string): Pointer;
begin
  Result := dlsym(ALib, MarshaledAString(UTF8String(AName)));
end;
{$ENDIF}

{$IF Defined(MSWINDOWS)}
const
  { EnumDisplayDevices: DeviceID is the device interface path. }
  EDD_GET_DEVICE_INTERFACE_NAME = $00000001;
  { DISPLAY_DEVICE: the monitor is on. }
  DISPLAY_DEVICE_ACTIVE_FLAG = $00000001;
  { Where Windows keeps a monitor's EDID (then model\instance\...). }
  EDID_KEY = '\SYSTEM\CurrentControlSet\Enum\DISPLAY\';

{ The physical size in an EDID block: the first detailed timing
  descriptor's millimetres, else the basic block's centimetres. }
function EdidSize(const AEdid: TBytes; out AW, AH: Single): Boolean;
begin
  AW := 0;
  AH := 0;
  if Length(AEdid) < 128 then
    Exit(False);
  // a detailed timing descriptor has a pixel clock (bytes 54 - 55)
  if (AEdid[54] <> 0) or (AEdid[55] <> 0) then
  begin
    AW := AEdid[66] or ((AEdid[68] shr 4) shl 8);
    AH := AEdid[67] or ((AEdid[68] and $0F) shl 8);
  end;
  if (AW <= 0) or (AH <= 0) then
  begin
    AW := AEdid[21] * 10;
    AH := AEdid[22] * 10;
  end;
  Result := (AW > 0) and (AH > 0);
end;

{ The EDID of the monitor shown through adapter output ADevice
  ('\\.\DISPLAY1'), from the registry; nil when not found. }
function ReadEdid(const ADevice: string; var ANote: string): TBytes;
var
  DD: TDisplayDevice;
  Index: DWORD;
  Parts: TArray<string>;
  Reg: TRegistry;
  Size: Integer;
begin
  Result := nil;
  Index := 0;
  FillChar(DD, SizeOf(DD), 0);
  DD.cb := SizeOf(DD);
  // the monitors on that output; the first one that is on
  while EnumDisplayDevices(PChar(ADevice), Index, DD, EDD_GET_DEVICE_INTERFACE_NAME) do
  begin
    if (DD.StateFlags and DISPLAY_DEVICE_ACTIVE_FLAG) <> 0 then
      Break;
    Inc(Index);
    FillChar(DD, SizeOf(DD), 0);
    DD.cb := SizeOf(DD);
  end;
  // '\\?\DISPLAY#GSM5B09#5&2a3b4c&0&UID4352#{e6f07b5f-...}'
  Parts := string(DD.DeviceID).Split(['#']);
  if Length(Parts) < 3 then
  begin
    ANote := 'no monitor device for ' + ADevice;
    Exit;
  end;
  Reg := TRegistry.Create(KEY_READ);
  try
    Reg.RootKey := HKEY_LOCAL_MACHINE;
    if Reg.OpenKeyReadOnly(EDID_KEY + Parts[1] + '\' + Parts[2] + '\Device Parameters') and
      Reg.ValueExists('EDID') then
    begin
      Size := Reg.GetDataSize('EDID');
      if Size > 0 then
      begin
        SetLength(Result, Size);
        Reg.ReadBinaryData('EDID', Result[0], Size);
      end;
    end
    else
      ANote := 'no EDID for ' + Parts[1];
  finally
    Reg.Free;
  end;
end;

{ Windows: the size of the monitor AForm is on. }
procedure PlatformSize(AForm: TCommonCustomForm; var AInfo: TSteamScreenInfo);
var
  Wnd: HWND;
  Mon: HMONITOR;
  MI: TMonitorInfoEx;
  W, H: Single;
  DC: HDC;
begin
  Wnd := FormToHWND(AForm);
  if Wnd = 0 then
    Exit;
  Mon := MonitorFromWindow(Wnd, MONITOR_DEFAULTTONEAREST);
  FillChar(MI, SizeOf(MI), 0);
  MI.cbSize := SizeOf(MI);
  if not GetMonitorInfo(Mon, PMonitorInfo(@MI)) then
    Exit;
  // the monitor's own record of its size
  if EdidSize(ReadEdid(MI.szDevice, AInfo.SizeNote), W, H) then
  begin
    CheckSize(W, H, AInfo.PixelWidth, AInfo.PixelHeight, AInfo.Scale, False, AInfo.SizeNote);
    if W > 0 then
    begin
      AInfo.WidthMm := W;
      AInfo.HeightMm := H;
      AInfo.SizeSource := sssEdid;
      Exit;
    end;
  end;
  // what the display driver says (made up from the dpi on some systems)
  DC := CreateDC(nil, MI.szDevice, nil, nil);
  if DC = 0 then
    Exit;
  try
    W := GetDeviceCaps(DC, HORZSIZE);
    H := GetDeviceCaps(DC, VERTSIZE);
  finally
    DeleteDC(DC);
  end;
  CheckSize(W, H, AInfo.PixelWidth, AInfo.PixelHeight, AInfo.Scale, True, AInfo.SizeNote);
  if W > 0 then
  begin
    AInfo.WidthMm := W;
    AInfo.HeightMm := H;
    AInfo.SizeSource := sssDeviceCaps;
  end;
end;

{$ELSEIF Defined(MACOS) and not Defined(IOS)}
type
  { CoreGraphics' CGPoint. }
  TCGPoint = record
    { Across. }
    X: Double;
    { Down (global display space: origin top left of the main display). }
    Y: Double;
  end;

  { CoreGraphics' CGSize. }
  TCGSize = record
    { Width. }
    Width: Double;
    { Height. }
    Height: Double;
  end;

  { CGGetDisplaysWithPoint. }
  TCGGetDisplaysWithPoint = function(APoint: TCGPoint; AMaxDisplays: UInt32; ADisplays: PUInt32;
    ACount: PUInt32): Int32; cdecl;
  { CGDisplayScreenSize. }
  TCGDisplayScreenSize = function(ADisplay: UInt32): TCGSize; cdecl;

const
  { CoreGraphics (in the dyld shared cache: dlopen finds it, there is no
    file). }
  COREGRAPHICS_LIB = '/System/Library/Frameworks/CoreGraphics.framework/CoreGraphics';

{ macOS: the size of the display at the centre of AForm's display. }
procedure PlatformSize(AForm: TCommonCustomForm; var AInfo: TSteamScreenInfo);
var
  Lib: NativeUInt;
  GetDisplays: TCGGetDisplaysWithPoint;
  ScreenSize: TCGDisplayScreenSize;
  P: TCGPoint;
  Id, Count: UInt32;
  S: TCGSize;
  W, H: Single;
  D: TDisplay;
begin
  Lib := dlopen(MarshaledAString(UTF8String(COREGRAPHICS_LIB)), RTLD_LAZY);
  if Lib = 0 then
  begin
    AInfo.SizeNote := 'CoreGraphics not loaded';
    Exit;
  end;
  @GetDisplays := Sym(Lib, 'CGGetDisplaysWithPoint');
  @ScreenSize := Sym(Lib, 'CGDisplayScreenSize');
  if not Assigned(GetDisplays) or not Assigned(ScreenSize) then
  begin
    AInfo.SizeNote := 'CoreGraphics functions missing';
    Exit;
  end;
  D := Screen.DisplayFromForm(AForm);
  P.X := D.BoundsRect.CenterPoint.X;
  P.Y := D.BoundsRect.CenterPoint.Y;
  Id := 0;
  Count := 0;
  if (GetDisplays(P, 1, @Id, @Count) <> 0) or (Count = 0) then
  begin
    AInfo.SizeNote := 'no display at the form''s display centre';
    Exit;
  end;
  S := ScreenSize(Id);
  W := S.Width;
  H := S.Height;
  CheckSize(W, H, AInfo.PixelWidth, AInfo.PixelHeight, AInfo.Scale, False, AInfo.SizeNote);
  if W > 0 then
  begin
    AInfo.WidthMm := W;
    AInfo.HeightMm := H;
    AInfo.SizeSource := sssCoreGraphics;
  end;
end;

{$ELSEIF Defined(LINUX) and not Defined(ANDROID)}
type
  { gdk_display_get_default. }
  TGdkDisplayGetDefault = function: Pointer; cdecl;
  { gdk_display_get_monitor_at_point (GDK 3.22). }
  TGdkDisplayGetMonitorAtPoint = function(ADisplay: Pointer; AX, AY: Integer): Pointer; cdecl;
  { gdk_monitor_get_width_mm / gdk_monitor_get_height_mm. }
  TGdkMonitorGetMm = function(AMonitor: Pointer): Integer; cdecl;

const
  { GDK 3 (FMX on Linux runs on GTK 3, so it is loaded already). }
  GDK_LIB = 'libgdk-3.so.0';

{ Linux: GDK's size of the monitor at the centre of AForm's display. }
procedure PlatformSize(AForm: TCommonCustomForm; var AInfo: TSteamScreenInfo);
var
  Lib: NativeUInt;
  GetDefault: TGdkDisplayGetDefault;
  MonitorAt: TGdkDisplayGetMonitorAtPoint;
  WidthMm, HeightMm: TGdkMonitorGetMm;
  Disp, Mon: Pointer;
  W, H: Single;
  D: TDisplay;
begin
  Lib := dlopen(MarshaledAString(UTF8String(GDK_LIB)), RTLD_LAZY);
  if Lib = 0 then
  begin
    AInfo.SizeNote := GDK_LIB + ' not loaded';
    Exit;
  end;
  @GetDefault := Sym(Lib, 'gdk_display_get_default');
  @MonitorAt := Sym(Lib, 'gdk_display_get_monitor_at_point');
  @WidthMm := Sym(Lib, 'gdk_monitor_get_width_mm');
  @HeightMm := Sym(Lib, 'gdk_monitor_get_height_mm');
  if not Assigned(GetDefault) or not Assigned(MonitorAt) or not Assigned(WidthMm) or
    not Assigned(HeightMm) then
  begin
    AInfo.SizeNote := 'GDK monitor functions missing (GDK older than 3.22)';
    Exit;
  end;
  Disp := GetDefault();
  if Disp = nil then
  begin
    AInfo.SizeNote := 'no GDK display';
    Exit;
  end;
  D := Screen.DisplayFromForm(AForm);
  Mon := MonitorAt(Disp, Round(D.BoundsRect.CenterPoint.X), Round(D.BoundsRect.CenterPoint.Y));
  if Mon = nil then
  begin
    AInfo.SizeNote := 'no GDK monitor at the form''s display centre';
    Exit;
  end;
  W := WidthMm(Mon);
  H := HeightMm(Mon);
  CheckSize(W, H, AInfo.PixelWidth, AInfo.PixelHeight, AInfo.Scale, True, AInfo.SizeNote);
  if W > 0 then
  begin
    AInfo.WidthMm := W;
    AInfo.HeightMm := H;
    AInfo.SizeSource := sssGdk;
  end;
end;

{$ELSE}
{ Other platforms: no physical size. }
procedure PlatformSize(AForm: TCommonCustomForm; var AInfo: TSteamScreenInfo);
begin
  AInfo.SizeNote := 'not measured on this platform';
end;
{$ENDIF}

{ Big Picture and Steam hardware, from ISteamUtils (no, none when Steam is
  not running or the call is missing). }
procedure SteamState(var AInfo: TSteamScreenInfo);
var
  U: TSteamUtilsPlugin;
begin
  AInfo.BigPicture := False;
  AInfo.SteamHardware := k_ESteamHardwareTypeNone;
  if not TSteamworks.HasInstance then
    Exit;
  U := TSteamUtilsPlugin(TSteamworks.Instance.FindPlugin(TSteamUtilsPlugin));
  if (U = nil) or not U.Active then
    Exit;
  try
    AInfo.BigPicture := U.IsSteamInBigPictureMode;
  except
    // older redistributable: unknown, taken as no
    AInfo.BigPicture := False;
  end;
  try
    AInfo.SteamHardware := U.IsRunningOnSteamHardware;
  except
    // older redistributable (SDK before 1.65): unknown, taken as none
    AInfo.SteamHardware := k_ESteamHardwareTypeNone;
  end;
end;

function SteamScreenInfo(AForm: TCommonCustomForm): TSteamScreenInfo;
var
  D: TDisplay;
  Wanted, Actual: Single;
begin
  Result := Default(TSteamScreenInfo);
  Result.Scale := 1;
  Result.UiScale := 1;
  if AForm = nil then
    AForm := Application.MainForm;
  SteamState(Result);
  if (AForm = nil) or (Screen.DisplayCount = 0) then
  begin
    Result.SizeNote := 'no form or no display';
    Exit;
  end;
  D := Screen.DisplayFromForm(AForm);
  Result.Width := D.BoundsRect.Width;
  Result.Height := D.BoundsRect.Height;
  if D.Scale > 0 then
    Result.Scale := D.Scale;
  Result.PixelWidth := Round(Result.Width * Result.Scale);
  Result.PixelHeight := Round(Result.Height * Result.Scale);
  try
    PlatformSize(AForm, Result);
  except
    on E: Exception do
    begin
      Result.WidthMm := 0;
      Result.HeightMm := 0;
      Result.SizeSource := sssNone;
      Result.SizeNote := E.ClassName + ': ' + E.Message;
    end;
  end;
  // a Deck's own panel: its size is known, whatever the system said
  if (Result.SteamHardware = k_ESteamHardwareTypeSteamDeck) and
    (Max(Result.PixelWidth, Result.PixelHeight) = SCREEN_DECK_PIXEL_WIDTH) and
    (Min(Result.PixelWidth, Result.PixelHeight) = SCREEN_DECK_PIXEL_HEIGHT) then
  begin
    if Result.SizeSource <> sssNone then
      Result.SizeNote := Format('%s said %.0f x %.0f mm', [SteamScreenSourceName(Result.SizeSource),
        Result.WidthMm, Result.HeightMm]);
    Result.WidthMm := SCREEN_DECK_WIDTH_MM;
    Result.HeightMm := SCREEN_DECK_HEIGHT_MM;
    MatchOrientation(Result.WidthMm, Result.HeightMm, Result.PixelWidth, Result.PixelHeight);
    Result.SizeSource := sssSteamDeck;
  end;
  if (Result.WidthMm > 0) and (Result.HeightMm > 0) then
  begin
    Result.DiagonalInches := Sqrt(Sqr(Result.WidthMm) + Sqr(Result.HeightMm)) / MM_PER_INCH;
    if Result.DiagonalInches < SCREEN_HANDHELD_INCHES then
      Result.Kind := sskHandheld
    else if Result.DiagonalInches < SCREEN_TV_INCHES then
      Result.Kind := sskMonitor
    else
      Result.Kind := sskTV;
  end;
  Result.BigUi := Result.BigPicture or (Result.Kind = sskHandheld);
  if not Result.BigUi then
    Exit;
  if (Result.WidthMm <= 0) or (Result.Width <= 0) then
  begin
    Result.UiScale := SCREEN_UNKNOWN_BIG_SCALE;
    Exit;
  end;
  // one unit should look as big from DistanceMm as 1/96 inch does from
  // the desktop reading distance
  Result.DistanceMm := EnsureRange(Result.DiagonalInches * MM_PER_INCH * SCREEN_DISTANCE_PER_DIAGONAL,
    SCREEN_MIN_DISTANCE_MM, SCREEN_MAX_DISTANCE_MM);
  Wanted := (MM_PER_INCH / FAKE_DPI) * Result.DistanceMm / SCREEN_REF_DISTANCE_MM;
  Actual := Result.WidthMm / Result.Width;
  Result.UiScale := EnsureRange(Wanted / Actual, SCREEN_MIN_UI_SCALE, SCREEN_MAX_UI_SCALE);
end;

end.
