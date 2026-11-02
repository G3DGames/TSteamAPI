(* @abstract(@link(TSteamAPI) for FireMonkey - the non-visual root component that
  drives Steam.)

  Drop one on the main form (or create it in code), set @link(TSteamAPI.AppID)
  and @link(TSteamAPI.Active). It loads the library, optionally relaunches
  through Steam, initialises the core and all linked plug-ins, pumps callbacks
  (by default on the UI thread with an FMX TTimer, so every Steam event
  arrives on the main thread; UpdateMode selects a worker thread or your own
  loop instead) and attaches the plug-in components (TSteamFriends, TSteamUser, ...)
  linked to it. Everything except the timer, exception display and application
  exit lives in the framework-free @code(TCustomSteamAPI)
  (Steamworks.Components); the VCL and LCL units declare a TSteamAPI of the
  same name and behaviour.

  Only one instance may exist, because Steam is process-global.

  @longCode(#
  procedure TMainForm.FormCreate(Sender: TObject);
  begin
    FSteam := TSteamAPI.Create(Self);
    FSteam.AppID := 2275430;
    {$ifdef DEBUG}
    FSteam.SetAppIdEnvironment := True;   // no steam_appid.txt needed
    {$else}
    FSteam.RestartIfNecessary := True;
    {$endif}
    FSteam.OnInitFailed := SteamInitFailed;
    FFriends := TSteamFriends.Create(Self);
    FFriends.SteamAPI := FSteam;
    FFriends.OnPersonaStateChange := FriendChanged;
    FSteam.Active := True;
  end;
  #) *)
unit Steamworks.FMX;

{$I Steamworks.inc}

interface

uses
  SysUtils, Classes, FMX.Types, FMX.Graphics, FMX.Forms,
  Steamworks.Types, Steamworks.Core, Steamworks.Components;

type
  { FireMonkey TSteamAPI: @code(TCustomSteamAPI) with an FMX timer pump. }
  [ComponentPlatformsAttribute(STEAM_COMPONENT_PLATFORMS)]
  TSteamAPI = class(TCustomSteamAPI)
  private
    { Timer that pumps callbacks on the UI thread. }
    FTimer: TTimer;
    { Timer handler: pumps callbacks. }
    procedure TimerTick(Sender: TObject);
  protected
    { Starts the FMX timer. }
    procedure PumpStart(AIntervalMs: Integer); override;
    { Stops the FMX timer. }
    procedure PumpStop; override;
    { Application.ShowException (Application.HandleException would show
      ExceptObject, which is nil outside an except block). }
    procedure ShowHandlerException(E: Exception); override;
    { Application.Terminate. }
    procedure TerminateApplication; override;
  public
    { Creates the (disabled) timer. }
    constructor Create(AOwner: TComponent); override;
    { Stops and frees the timer, then shuts Steam down (inherited). }
    destructor Destroy; override;
  published
    { Starts / stops Steam. At design time the value is only stored. }
    property Active;
    { Your Steam AppID. }
    property AppID;
    { Call SteamAPI_RestartAppIfNecessary first (recommended for release builds). }
    property RestartIfNecessary;
    { Export SteamAppId so development builds need no steam_appid.txt. }
    property SetAppIdEnvironment;
    { Explicit redistributable path; empty = default. }
    property LibraryPath;
    { Initialisation entry point. }
    property InitMode;
    { Timer interval (sumTimer) or worker period (sumThread) in ms; with
      sumTimer, 0 = no timer (call Update yourself). }
    property CallbackInterval;
    { Who drains Steam's queue: the timer (sumTimer, default), a worker
      thread (sumThread) or your own loop calling Update (sumManual). }
    property UpdateMode;
    { Where events run in sumThread mode: main thread (default), inside
      Update, or on the worker. }
    property Delivery;
    { Forward Steam debug output to OnWarning. }
    property InstallWarningHook;
    { End the application when the Steam client exits. }
    property QuitOnSteamShutdown;
    { Shut Steam down (not the app) as soon as the Steam client exits. }
    property ShutdownOnSteamExit;
    { What Active starts: [srClient] (a game, default), [srClient,
      srGameServer] (a listen server) or [srGameServer] (a dedicated server). }
    property Roles;
    { IP address the game server binds to, host order (0 = any). }
    property GameServerIP;
    { UDP port of the game server's own traffic (27015). }
    property GameServerGamePort;
    { UDP port Steam answers server-browser queries on (27016; 65535 = shared). }
    property GameServerQueryPort;
    { Authentication / listing / VAC mode of the game server. }
    property GameServerMode;
    { Version of the game server ('1.0.0.0'). }
    property GameServerVersion;
    { Steam started successfully (plug-in components are attached already). }
    property OnInitialized;
    { Steam could not start; see the message. }
    property OnInitFailed;
    { Steam was shut down. }
    property OnShutdown;
    { The Steam client is exiting - save and quit. }
    property OnSteamShutdown;
    { Steam is relaunching the game through the client. }
    property OnRestartRequired;
    { Diagnostic messages from the core and plug-ins. }
    property OnLog;
    { Steam client debug output (launch with -debug_steamapi). }
    property OnWarning;
    { Every Steam callback, for diagnostics. }
    property OnCallback;
    { The game server started (its components are attached already). }
    property OnGameServerStarted;
    { The game server was shut down. }
    property OnGameServerStopped;
    { The game server could not start; see the message. }
    property OnGameServerFailed;
  end;

{ Copies a Steam image into an FMX bitmap: an avatar handle from
  TSteamFriendsPlugin.GetSmall/Medium/LargeFriendAvatar or an achievement icon
  from TSteamUserStatsPlugin.GetAchievementIcon (also the handles in
  AvatarImageLoaded_t / UserAchievementIconFetched_t). ABitmap is resized to
  the image.
  @returns(@false when the handle is 0 or -1 (not available / still loading -
    wait for the callback), Steam is not running, or the pixels cannot be
    read; ABitmap is then unchanged - except when the bitmap cannot be mapped
    for writing, after it was already resized.) }
function SteamImageToBitmap(AImage: Integer; ABitmap: TBitmap): Boolean;

(* Converts an FMX bitmap to the pixel format ISteamScreenshots.WriteScreenshot
  takes: packed 24-bit RGB, 3 bytes per pixel, rows top-down, no padding, no
  alpha (alpha is dropped, so the bitmap should be opaque).
  @returns(Width * Height * 3 bytes; @nil when ABitmap is @nil, empty or
    cannot be mapped for reading.) *)
function SteamBitmapToRGB(ABitmap: TBitmap): TBytes;

(* Takes a screenshot of a form for Steam: paints the form's client area into
  an offscreen bitmap at the window's scale (its physical pixels on a high-DPI
  screen) on an opaque white background and returns it as
  @link(SteamBitmapToRGB) does. Call it on the main thread. Hand the result to
  WriteScreenshot - from @code(TSteamScreenshots.OnScreenshotRequested)
  (while hooked) or whenever the game wants a screenshot. Unlike
  TriggerScreenshot this needs no Steam overlay in the process.
  @longCode(#
  RGB := SteamFormToRGB(Self, W, H);
  if RGB <> nil then
    SteamScreenshots1.Plugin.WriteScreenshot(@RGB[0], Length(RGB), W, H);
  #)
  What the form paints is what is captured: controls drawn natively by the
  platform (ControlType = Platform) and the contents of 3D viewports may be
  missing - capture those from their own render target instead. A form with
  Transparency = True may come out black where it paints nothing (alpha is
  dropped).
  @param(AForm The form to capture.)
  @param(AWidth Width of the image in pixels (0 on failure).)
  @param(AHeight Height of the image in pixels (0 on failure).)
  @returns(The RGB bytes, @nil when AForm is @nil, has no client area or the
    bitmap cannot be painted or read.) *)
function SteamFormToRGB(AForm: TCustomForm; out AWidth, AHeight: Integer): TBytes;

implementation

uses
  UITypes, Steamworks.Plugin.Utils;

function SteamImageToBitmap(AImage: Integer; ABitmap: TBitmap): Boolean;
var
  U: TSteamUtilsPlugin;
  Pixels: TBytes;
  W, H: UInt32;
  Data: TBitmapData;
  X, Y: Integer;
  P: PByte;
begin
  Result := False;
  if (AImage <= 0) or (ABitmap = nil) or not TSteamworks.HasInstance then
    Exit;
  U := TSteamUtilsPlugin(TSteamworks.Instance.FindPlugin(TSteamUtilsPlugin));
  if U = nil then
    Exit;
  Pixels := U.GetImageRGBABytes(AImage, W, H);
  if Pixels = nil then
    Exit;
  ABitmap.SetSize(Integer(W), Integer(H));
  if not ABitmap.Map(TMapAccess.Write, Data) then
    Exit;
  try
    // Steam gives straight RGBA, 4 bytes per pixel, rows top-down; SetPixel
    // converts to whatever pixel format the bitmap uses on this platform.
    P := @Pixels[0];
    for Y := 0 to Integer(H) - 1 do
      for X := 0 to Integer(W) - 1 do
      begin
        Data.SetPixel(X, Y, (TAlphaColor(P[3]) shl 24) or (TAlphaColor(P[0]) shl 16) or
          (TAlphaColor(P[1]) shl 8) or TAlphaColor(P[2]));
        Inc(P, 4);
      end;
  finally
    ABitmap.Unmap(Data);
  end;
  Result := True;
end;

function SteamBitmapToRGB(ABitmap: TBitmap): TBytes;
var
  Data: TBitmapData;
  X, Y: Integer;
  C: TAlphaColor;
  P: PByte;
begin
  Result := nil;
  if (ABitmap = nil) or ABitmap.IsEmpty then
    Exit;
  if not ABitmap.Map(TMapAccess.Read, Data) then
    Exit;
  try
    SetLength(Result, ABitmap.Width * ABitmap.Height * 3);
    P := @Result[0];
    // GetPixel returns $AARRGGBB whatever the platform's pixel format is
    // (BGRA on Windows); Steam wants R, G, B in that byte order
    for Y := 0 to ABitmap.Height - 1 do
      for X := 0 to ABitmap.Width - 1 do
      begin
        C := Data.GetPixel(X, Y);
        P[0] := Byte(C shr 16);
        P[1] := Byte(C shr 8);
        P[2] := Byte(C);
        Inc(P, 3);
      end;
  finally
    ABitmap.Unmap(Data);
  end;
end;

function SteamFormToRGB(AForm: TCustomForm; out AWidth, AHeight: Integer): TBytes;
var
  Bmp: TBitmap;
  Scale: Single;
  W, H: Integer;
begin
  Result := nil;
  AWidth := 0;
  AHeight := 0;
  if AForm = nil then
    Exit;
  Scale := 1;
  if AForm.Handle <> nil then
    Scale := AForm.Handle.Scale;
  if Scale <= 0 then
    Scale := 1;
  W := Round(AForm.ClientWidth * Scale);
  H := Round(AForm.ClientHeight * Scale);
  if (W <= 0) or (H <= 0) then
    Exit;
  Bmp := TBitmap.Create(W, H);
  try
    // Logical coordinates -> physical pixels, as on screen
    Bmp.BitmapScale := Scale;
    if not Bmp.Canvas.BeginScene then
      Exit;
    try
      Bmp.Canvas.Clear(TAlphaColors.White);
      AForm.PaintTo(Bmp.Canvas);
    finally
      Bmp.Canvas.EndScene;
    end;
    Result := SteamBitmapToRGB(Bmp);
    if Result <> nil then
    begin
      AWidth := Bmp.Width;
      AHeight := Bmp.Height;
    end;
  finally
    Bmp.Free;
  end;
end;

{ TSteamAPI }

constructor TSteamAPI.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FTimer := TTimer.Create(nil);
  FTimer.Enabled := False;
  FTimer.OnTimer := TimerTick;
end;

destructor TSteamAPI.Destroy;
begin
  PumpStop;
  inherited;          // may call PumpStop again: FTimer is still valid here
  FreeAndNil(FTimer);
end;

procedure TSteamAPI.TimerTick(Sender: TObject);
begin
  RunCallbacks;
end;

procedure TSteamAPI.PumpStart(AIntervalMs: Integer);
begin
  if FTimer = nil then
    Exit;
  FTimer.Interval := AIntervalMs;
  FTimer.Enabled := True;
end;

procedure TSteamAPI.PumpStop;
begin
  if FTimer <> nil then
    FTimer.Enabled := False;
end;

procedure TSteamAPI.ShowHandlerException(E: Exception);
begin
  Application.ShowException(E);
end;

procedure TSteamAPI.TerminateApplication;
begin
  Application.Terminate;
end;

end.
