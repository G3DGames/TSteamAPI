(* @abstract(@link(TSteamAPI) for FireMonkey - the non-visual root component that
  drives Steam.)

  Drop one on the main form (or create it in code), set @link(TSteamAPI.AppID)
  and @link(TSteamAPI.Active). It loads the library, optionally relaunches
  through Steam, initialises the core and all linked plug-ins, pumps callbacks
  on the UI thread with an FMX TTimer (so every Steam event arrives on the main
  thread) and attaches the plug-in components (TSteamFriends, TSteamUser, ...)
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
  SysUtils, Classes, FMX.Types, FMX.Graphics,
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
    { Application.HandleException. }
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
    { Pump interval in ms; 0 = no timer (call RunCallbacks yourself). }
    property CallbackInterval;
    { Forward Steam debug output to OnWarning. }
    property InstallWarningHook;
    { End the application when the Steam client exits. }
    property QuitOnSteamShutdown;
    { Shut Steam down (not the app) as soon as the Steam client exits. }
    property ShutdownOnSteamExit;
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

implementation

uses
  UITypes, FMX.Forms, Steamworks.Plugin.Utils;

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
  Application.HandleException(E);
end;

procedure TSteamAPI.TerminateApplication;
begin
  Application.Terminate;
end;

end.
