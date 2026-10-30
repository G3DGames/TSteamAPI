(* @abstract(@link(TSteamworksFMX) - non-visual FireMonkey component that drives
  the Steam core.)

  Drop one on the main form (or create it in code), set
  @link(TSteamworksFMX.AppID) and @link(TSteamworksFMX.Active). It loads the
  library, optionally relaunches through Steam, initialises the core and all
  linked plug-ins, and pumps callbacks on the UI thread with an FMX TTimer, so
  every Steam event arrives on the main thread.

  Only one instance may exist, because Steam is process-global.

  @longCode(#
  procedure TMainForm.FormCreate(Sender: TObject);
  begin
    FSteam := TSteamworksFMX.Create(Self);
    FSteam.AppID := 2275430;
    {$ifdef DEBUG}
    FSteam.SetAppIdEnvironment := True;   // no steam_appid.txt needed
    {$else}
    FSteam.RestartIfNecessary := True;
    {$endif}
    FSteam.OnInitFailed := SteamInitFailed;
    FSteam.Active := True;
  end;
  #)

  The core (Steamworks.Core) is framework-independent; VCL and LCL
  equivalents of this unit only need a different timer and Application. *)
unit Steamworks.FMX;

{$I Steamworks.inc}

interface

uses
  SysUtils, Classes, FMX.Types,
  Steamworks.Types, Steamworks.API, Steamworks.Callbacks, Steamworks.Core;

type
  { Initialisation failed. AResult is the ESteamAPIInitResult value as an
    Integer (published events need RTTI-capable parameter types). }
  TSteamInitFailedEvent = procedure(Sender: TObject; AResult: Integer;
    const AMessage: string) of object;
  { Steam is relaunching the game through the client. Leave ATerminate @true
    (the default) to call Application.Terminate. }
  TSteamRestartEvent = procedure(Sender: TObject; var ATerminate: Boolean) of object;
  { Any Steam callback, for diagnostics. }
  TSteamCallbackNotifyEvent = procedure(Sender: TObject; const AData: TSteamCallbackData) of object;

  { FireMonkey component wrapper for @code(TSteamworks). }
  [ComponentPlatformsAttribute(pidWin32 or pidWin64 or pidOSX64 or pidOSXArm64 or pidLinux64 or pidAndroidArm64)]
  TSteamworksFMX = class(TComponent)
  private
    { Timer that pumps callbacks on the UI thread. }
    FTimer: TTimer;
    { @true if this run-time instance holds the single-instance slot. }
    FCounted: Boolean;
    { Backing field of @link(Active). }
    FActive: Boolean;
    { Active value read from the form file, applied in @link(Loaded). }
    FStreamedActive: Boolean;
    { Backing field of @link(AppID). }
    FAppID: Cardinal;
    { Backing field of @link(RestartIfNecessary). }
    FRestartIfNecessary: Boolean;
    { Backing field of @link(SetAppIdEnvironment). }
    FSetAppIdEnvironment: Boolean;
    { Backing field of @link(LibraryPath). }
    FLibraryPath: string;
    { Backing field of @link(InitMode). }
    FInitMode: TSteamInitMode;
    { Backing field of @link(CallbackInterval). }
    FCallbackInterval: Integer;
    { Backing field of @link(InstallWarningHook). }
    FInstallWarningHook: Boolean;
    { Backing field of @link(QuitOnSteamShutdown). }
    FQuitOnSteamShutdown: Boolean;
    { Backing field of @link(OnInitialized). }
    FOnInitialized: TNotifyEvent;
    { Backing field of @link(OnInitFailed). }
    FOnInitFailed: TSteamInitFailedEvent;
    { Backing field of @link(OnShutdown). }
    FOnShutdown: TNotifyEvent;
    { Backing field of @link(OnSteamShutdown). }
    FOnSteamShutdown: TNotifyEvent;
    { Backing field of @link(OnRestartRequired). }
    FOnRestartRequired: TSteamRestartEvent;
    { Backing field of @link(OnLog). }
    FOnLog: TSteamLogEvent;
    { Backing field of @link(OnWarning). }
    FOnWarning: TSteamWarningEvent;
    { Backing field of @link(OnCallback). }
    FOnCallback: TSteamCallbackNotifyEvent;
    { Write accessor of @link(Active). }
    procedure SetActive(const AValue: Boolean);
    { Write accessor of @link(CallbackInterval). }
    procedure SetCallbackInterval(const AValue: Integer);
    { Read accessor of @link(Steam). }
    function GetSteam: TSteamworks;
    { Read accessor of @link(IsRunning). }
    function GetIsRunning: Boolean;
    { @true unless the component is being destroyed (events must not fire then). }
    function Alive: Boolean;
    { Timer handler: pumps callbacks. }
    procedure TimerTick(Sender: TObject);
    { Points the core events at this component. }
    procedure HookCore;
    { Detaches this component from the core events. }
    procedure UnhookCore;
    { Forwards core log messages to @link(OnLog). }
    procedure CoreLog(Sender: TObject; ALevel: TSteamLogLevel; const AMessage: string);
    { Forwards Steam warnings to @link(OnWarning). }
    procedure CoreWarning(Sender: TObject; ASeverity: Integer; const AText: string);
    { Forwards SteamShutdown_t; terminates the app if @link(QuitOnSteamShutdown). }
    procedure CoreSteamShutdown(Sender: TObject);
    { Core shut down: stop the timer and raise @link(OnShutdown). }
    procedure CoreShutdown(Sender: TObject);
    { Forwards every callback to @link(OnCallback). }
    procedure CoreAnyCallback(const AData: TSteamCallbackData);
    { Shows handler exceptions through Application.HandleException and keeps pumping. }
    procedure CoreHandlerError(Sender: TObject; E: Exception; ACallbackID: Integer; var AHandled: Boolean);
  protected
    { Applies a streamed Active value (starts Steam at run time only). }
    procedure Loaded; override;
    { Configures and starts the core. @returns(@true when Steam is running.) }
    function DoActivate: Boolean; virtual;
    { Stops the timer and shuts the core down. }
    procedure DoDeactivate; virtual;
  public
    { @raises(ESteamworksError if another TSteamworksFMX exists at run time.) }
    constructor Create(AOwner: TComponent); override;
    { Releases everything this object owns. }
    destructor Destroy; override;
    { Same as @code(Active := True), returning the outcome. }
    function Open: Boolean;
    { Same as @code(Active := False). }
    procedure Close;
    { Pumps callbacks now, in addition to the timer. }
    procedure RunCallbacks;
    { The core singleton; reach plug-ins with @code(Steam.Plugin<T>). }
    property Steam: TSteamworks read GetSteam;
    { @true while Steam is running. }
    property IsRunning: Boolean read GetIsRunning;
  published
    { Starts / stops Steam. At design time the value is only stored. }
    property Active: Boolean read FActive write SetActive default False;
    { Your Steam AppID. }
    property AppID: Cardinal read FAppID write FAppID default 0;
    { Call SteamAPI_RestartAppIfNecessary first (recommended for release builds). }
    property RestartIfNecessary: Boolean read FRestartIfNecessary write FRestartIfNecessary default False;
    { Export SteamAppId so development builds need no steam_appid.txt. }
    property SetAppIdEnvironment: Boolean read FSetAppIdEnvironment write FSetAppIdEnvironment default False;
    { Explicit redistributable path; empty = default. }
    property LibraryPath: string read FLibraryPath write FLibraryPath;
    { Initialisation entry point. }
    property InitMode: TSteamInitMode read FInitMode write FInitMode default simAuto;
    { Pump interval in ms; 0 = no timer (call @link(RunCallbacks) yourself). }
    property CallbackInterval: Integer read FCallbackInterval write SetCallbackInterval default 33;
    { Forward Steam debug output to @link(OnWarning). }
    property InstallWarningHook: Boolean read FInstallWarningHook write FInstallWarningHook default True;
    { Terminate the application when the Steam client exits. }
    property QuitOnSteamShutdown: Boolean read FQuitOnSteamShutdown write FQuitOnSteamShutdown default False;

    { Steam started successfully. }
    property OnInitialized: TNotifyEvent read FOnInitialized write FOnInitialized;
    { Steam could not start; see the message. }
    property OnInitFailed: TSteamInitFailedEvent read FOnInitFailed write FOnInitFailed;
    { Steam was shut down. }
    property OnShutdown: TNotifyEvent read FOnShutdown write FOnShutdown;
    { The Steam client is exiting - save and quit. }
    property OnSteamShutdown: TNotifyEvent read FOnSteamShutdown write FOnSteamShutdown;
    { Steam is relaunching the game through the client. }
    property OnRestartRequired: TSteamRestartEvent read FOnRestartRequired write FOnRestartRequired;
    { Diagnostic messages from the core and plug-ins. }
    property OnLog: TSteamLogEvent read FOnLog write FOnLog;
    { Steam client debug output (launch with -debug_steamapi). }
    property OnWarning: TSteamWarningEvent read FOnWarning write FOnWarning;
    { Every Steam callback, for diagnostics. }
    property OnCallback: TSteamCallbackNotifyEvent read FOnCallback write FOnCallback;
  end;

implementation

uses
  Math, FMX.Forms;

var
  GComponentCount: Integer = 0;

{ TSteamworksFMX }

constructor TSteamworksFMX.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  // csDesigning is known only after inherited Create (set from the owner)
  if not (csDesigning in ComponentState) then
  begin
    if GComponentCount > 0 then
      raise ESteamworksError.Create('Only one TSteamworksFMX component may exist per application');
    Inc(GComponentCount);
    FCounted := True;
  end;
  FCallbackInterval := 33;
  FInstallWarningHook := True;
  FInitMode := simAuto;
  FTimer := TTimer.Create(nil);
  FTimer.Enabled := False;
  FTimer.Interval := FCallbackInterval;
  FTimer.OnTimer := TimerTick;
end;

destructor TSteamworksFMX.Destroy;
begin
  if FTimer <> nil then
    FTimer.Enabled := False;
  if FCounted then
  begin
    // The owner's controls may already be gone: detach events first
    UnhookCore;
    if FActive and TSteamworks.HasInstance then
      TSteamworks.Instance.Shutdown;
    FActive := False;
    Dec(GComponentCount);
  end;
  FTimer.Free;
  inherited;
end;

function TSteamworksFMX.Alive: Boolean;
begin
  Result := not (csDestroying in ComponentState);
end;

function TSteamworksFMX.GetSteam: TSteamworks;
begin
  Result := TSteamworks.Instance;
end;

function TSteamworksFMX.GetIsRunning: Boolean;
begin
  Result := TSteamworks.HasInstance and TSteamworks.Instance.IsRunning;
end;

procedure TSteamworksFMX.Loaded;
begin
  inherited;
  if csDesigning in ComponentState then
    FActive := FStreamedActive
  else if FStreamedActive then
    SetActive(True);
  FStreamedActive := False;
end;

procedure TSteamworksFMX.SetActive(const AValue: Boolean);
begin
  if csLoading in ComponentState then
  begin
    FStreamedActive := AValue;
    Exit;
  end;
  if csDesigning in ComponentState then
  begin
    FActive := AValue; // never touch Steam inside the IDE
    Exit;
  end;
  if AValue = FActive then
    Exit;
  if AValue then
    FActive := DoActivate
  else
  begin
    DoDeactivate;
    FActive := False;
  end;
end;

procedure TSteamworksFMX.SetCallbackInterval(const AValue: Integer);
begin
  FCallbackInterval := Max(0, AValue);
  if FCallbackInterval > 0 then
    FTimer.Interval := FCallbackInterval;
  FTimer.Enabled := FActive and (FCallbackInterval > 0) and not (csDesigning in ComponentState);
end;

procedure TSteamworksFMX.HookCore;
var
  S: TSteamworks;
begin
  S := TSteamworks.Instance;
  S.OnLog := CoreLog;
  S.OnWarning := CoreWarning;
  S.OnSteamShutdown := CoreSteamShutdown;
  S.OnShutdown := CoreShutdown;
  S.Dispatcher.OnAnyCallback := CoreAnyCallback;
  S.Dispatcher.OnHandlerError := CoreHandlerError;
end;

procedure TSteamworksFMX.UnhookCore;
var
  S: TSteamworks;
begin
  if not TSteamworks.HasInstance then
    Exit;
  S := TSteamworks.Instance;
  S.OnLog := nil;
  S.OnWarning := nil;
  S.OnSteamShutdown := nil;
  S.OnShutdown := nil;
  S.Dispatcher.OnAnyCallback := nil;
  S.Dispatcher.OnHandlerError := nil;
end;

function TSteamworksFMX.DoActivate: Boolean;
var
  S: TSteamworks;
  Terminate: Boolean;
begin
  S := TSteamworks.Instance;
  HookCore;
  S.AppID := FAppID;
  S.SetAppIdEnvironment := FSetAppIdEnvironment;
  S.LibraryPath := FLibraryPath;
  S.InitMode := FInitMode;
  S.InstallWarningHook := FInstallWarningHook;

  if FRestartIfNecessary and (FAppID <> 0) and S.RestartAppIfNecessary(FAppID) then
  begin
    Terminate := True;
    if Assigned(FOnRestartRequired) then
      FOnRestartRequired(Self, Terminate);
    if Terminate then
      Application.Terminate;
    Exit(False);
  end;

  Result := S.Initialize;
  if Result then
  begin
    FActive := True;
    FTimer.Interval := Max(1, FCallbackInterval);
    FTimer.Enabled := FCallbackInterval > 0;
    if Assigned(FOnInitialized) then
      FOnInitialized(Self);
  end
  else if Assigned(FOnInitFailed) then
    FOnInitFailed(Self, Ord(S.LastInitResult), S.LastError);
end;

procedure TSteamworksFMX.DoDeactivate;
begin
  FTimer.Enabled := False;
  if TSteamworks.HasInstance then
    TSteamworks.Instance.Shutdown;   // fires CoreShutdown -> OnShutdown
end;

function TSteamworksFMX.Open: Boolean;
begin
  Active := True;
  Result := FActive;
end;

procedure TSteamworksFMX.Close;
begin
  Active := False;
end;

procedure TSteamworksFMX.RunCallbacks;
begin
  if GetIsRunning then
    TSteamworks.Instance.RunCallbacks;
end;

procedure TSteamworksFMX.TimerTick(Sender: TObject);
begin
  RunCallbacks;
end;

procedure TSteamworksFMX.CoreLog(Sender: TObject; ALevel: TSteamLogLevel; const AMessage: string);
begin
  if Alive and Assigned(FOnLog) then
    FOnLog(Self, ALevel, AMessage);
end;

procedure TSteamworksFMX.CoreWarning(Sender: TObject; ASeverity: Integer; const AText: string);
begin
  if Alive and Assigned(FOnWarning) then
    FOnWarning(Self, ASeverity, AText);
end;

procedure TSteamworksFMX.CoreSteamShutdown(Sender: TObject);
begin
  if not Alive then
    Exit;
  if Assigned(FOnSteamShutdown) then
    FOnSteamShutdown(Self);
  if FQuitOnSteamShutdown then
    Application.Terminate;
end;

procedure TSteamworksFMX.CoreShutdown(Sender: TObject);
begin
  FTimer.Enabled := False;
  FActive := False;
  if Alive and Assigned(FOnShutdown) then
    FOnShutdown(Self);
end;

procedure TSteamworksFMX.CoreAnyCallback(const AData: TSteamCallbackData);
begin
  if Alive and Assigned(FOnCallback) then
    FOnCallback(Self, AData);
end;

procedure TSteamworksFMX.CoreHandlerError(Sender: TObject; E: Exception; ACallbackID: Integer;
  var AHandled: Boolean);
begin
  // Show it the FMX way and keep pumping
  Application.HandleException(E);
  AHandled := True;
end;

end.
