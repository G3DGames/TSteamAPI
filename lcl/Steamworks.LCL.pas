(* @abstract(@link(TSteamAPI) for the LCL (Lazarus / Free Pascal) - the non-visual
  root component that drives Steam.)

  Same name, properties and events as the FMX and VCL TSteamAPI: everything
  except the timer, exception display and application exit lives in the
  framework-free @code(TCustomSteamAPI) (Steamworks.Components). The callback
  timer is the LCL TTimer, so Steam events arrive on the main thread with
  every widgetset (the default UpdateMode, sumTimer; sumThread moves the
  reading to a worker thread and still delivers on the main thread by
  default - the LCL calls CheckSynchronize for it). @link(SteamImageToBitmap) uses TLazIntfImage, so it is
  independent of the widgetset's native pixel format. *)
unit Steamworks.LCL;

{$I Steamworks.inc}

interface

uses
  SysUtils, Classes, ExtCtrls, Graphics,
  Steamworks.Types, Steamworks.Core, Steamworks.Components;

type
  { LCL TSteamAPI: @code(TCustomSteamAPI) with an LCL timer pump. }
  TSteamAPI = class(TCustomSteamAPI)
  private
    { Timer that pumps callbacks on the UI thread. }
    FTimer: TTimer;
    { Timer handler: pumps callbacks. }
    procedure TimerTick(Sender: TObject);
  protected
    { Starts the timer. }
    procedure PumpStart(AIntervalMs: Integer); override;
    { Stops the timer. }
    procedure PumpStop; override;
    { Application.ShowException. }
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

{ Copies a Steam image into a bitmap: an avatar handle from
  TSteamFriendsPlugin.GetSmall/Medium/LargeFriendAvatar or an achievement icon
  from TSteamUserStatsPlugin.GetAchievementIcon (also the handles in
  AvatarImageLoaded_t / UserAchievementIconFetched_t). ABitmap is resized to
  the image (32 bits per pixel, alpha kept).
  @returns(@false when the handle is 0 or -1 (not available / still loading -
    wait for the callback), Steam is not running, or the pixels cannot be
    read; ABitmap is then unchanged.) }
function SteamImageToBitmap(AImage: Integer; ABitmap: TBitmap): Boolean;

implementation

uses
  Forms, GraphType, FPImage, IntfGraphics, Steamworks.Plugin.Utils;

function SteamImageToBitmap(AImage: Integer; ABitmap: TBitmap): Boolean;
var
  U: TSteamUtilsPlugin;
  Pixels: TBytes;
  W, H: UInt32;
  Img: TLazIntfImage;
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
  Img := TLazIntfImage.Create(Integer(W), Integer(H), [riqfRGB, riqfAlpha]);
  try
    Img.CreateData;
    // Steam gives straight RGBA, 8 bits per channel, rows top-down
    P := @Pixels[0];
    for Y := 0 to Integer(H) - 1 do
      for X := 0 to Integer(W) - 1 do
      begin
        Img.Colors[X, Y] := FPColor(P[0] * 257, P[1] * 257, P[2] * 257, P[3] * 257);
        Inc(P, 4);
      end;
    ABitmap.LoadFromIntfImage(Img);
  finally
    Img.Free;
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
  Application.ShowException(E);
end;

procedure TSteamAPI.TerminateApplication;
begin
  Application.Terminate;
end;

end.
