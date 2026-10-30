(* @abstract(Framework-independent component layer: @link(TCustomSteamAPI), the
  base of the TSteamAPI component every framework unit (Steamworks.FMX, later
  Steamworks.VCL and Steamworks.LCL) declares, and @link(TSteamPluginComponent),
  the base of the generated plug-in components (TSteamFriends, TSteamUser, ...).)

  Only RTL units are used (Classes), so this unit is part of the framework-free
  runtime package and compiles with FPC. A framework unit adds just the callback
  timer, exception display and application exit:
  @longCode(#
  TSteamAPI = class(TCustomSteamAPI)
  protected
    procedure PumpStart(AIntervalMs: Integer); override;
    procedure PumpStop; override;
    procedure ShowHandlerException(E: Exception); override;
    procedure TerminateApplication; override;
  end;
  #)
  Plug-in components link to the root through their SteamAPI property (set
  automatically at run time when the owner holds exactly one TSteamAPI). Their
  events are subscribed while Steam runs and removed when it stops. *)
unit Steamworks.Components;

{$I Steamworks.inc}

interface

uses
  SysUtils, Classes, Generics.Collections,
  Steamworks.Types, Steamworks.API, Steamworks.Callbacks, Steamworks.Core;

{$ifndef FPC}
const
  { Platforms of the Steamworks components (ComponentPlatformsAttribute):
    every platform Valve ships a redistributable for that Delphi targets. }
  STEAM_COMPONENT_PLATFORMS = pidWin32 or pidWin64 or pidOSX64 or pidOSXArm64 or pidLinux64 or pidAndroidArm64;
{$endif}

type
  TCustomSteamAPI = class;

  { Initialisation failed. AResult is the ESteamAPIInitResult value as an
    Integer (published events need RTTI-capable parameter types). }
  TSteamInitFailedEvent = procedure(Sender: TObject; AResult: Integer;
    const AMessage: string) of object;
  { Steam is relaunching the game through the client. Leave ATerminate @true
    (the default) to end the application. }
  TSteamRestartEvent = procedure(Sender: TObject; var ATerminate: Boolean) of object;
  { Any Steam callback, for diagnostics. }
  TSteamCallbackNotifyEvent = procedure(Sender: TObject; const AData: TSteamCallbackData) of object;

  { Base of the generated plug-in components. Link it to a TSteamAPI through
    @link(SteamAPI); while Steam runs it is attached (its callback events are
    subscribed), otherwise detached. }
  TSteamPluginComponent = class(TComponent)
  private
    { Backing field of @link(SteamAPI). }
    FSteamAPI: TCustomSteamAPI;
    { @true while the callback subscriptions are in place. }
    FAttached: Boolean;
    { Write accessor of @link(SteamAPI). }
    procedure SetSteamAPI(const AValue: TCustomSteamAPI);
  protected
    { Called by the root when Steam is running: subscribe callbacks here
      (generated). The default does nothing. }
    procedure DoAttach; virtual;
    { Subscribes a callback for this component (removed on detach). Call
      results with this id are delivered too, unless a handler registered for
      that particular call (an ...Async method) claims them. }
    procedure SubscribeCallback(ACallbackID: Integer; AHandler: TSteamCallbackEvent);
    { Checks a payload before an event is raised.
      @returns(@false for a call result that failed (IOFailure): logged as a
        warning, no event.)
      @raises(ESteamworksError when the payload size differs from the Pascal
        record's - a layout mismatch must never pass silently.) }
    function PayloadOK(const AData: TSteamCallbackData; ARecordSize: Integer;
      const AStructName: string): Boolean;
    { Clears @link(SteamAPI) when the linked root is destroyed. }
    procedure Notification(AComponent: TComponent; AOperation: TOperation); override;
    { At run time links to the owner's only TSteamAPI when @link(SteamAPI) is
      unset. }
    procedure Loaded; override;
    { The linked root, published by each descendant. }
    property SteamAPI: TCustomSteamAPI read FSteamAPI write SetSteamAPI;
  public
    { Detaches and unlinks. }
    destructor Destroy; override;
    { Subscribes the callbacks if Steam runs and not already attached. }
    procedure Attach;
    { Removes the callback subscriptions. }
    procedure Detach;
    { @true while the callback events can fire. }
    property Attached: Boolean read FAttached;
  end;

  { Framework-independent base of the TSteamAPI component. Owns the Steam
    lifecycle (load, optional relaunch, initialise, pump, shut down), forwards
    core events and attaches the linked plug-in components. Only one instance
    may exist at run time, because Steam is process-global. Do not free it
    from inside one of its own (or a plug-in component's) events - they run
    from its timer; call Close there and free it later. }
  TCustomSteamAPI = class(TComponent)
  private
    { Plug-in components linked to this root. }
    FLinked: TList<TSteamPluginComponent>;
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
    { Backing field of @link(ShutdownOnSteamExit). }
    FShutdownOnSteamExit: Boolean;
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
    { Points the core events at this component. }
    procedure HookCore;
    { Detaches this component from the core events. }
    procedure UnhookCore;
    { Attaches every linked plug-in component. }
    procedure AttachLinked;
    { Detaches every linked plug-in component. }
    procedure DetachLinked;
    { Forwards core log messages to @link(OnLog). }
    procedure CoreLog(Sender: TObject; ALevel: TSteamLogLevel; const AMessage: string);
    { Forwards Steam warnings to @link(OnWarning). }
    procedure CoreWarning(Sender: TObject; ASeverity: Integer; const AText: string);
    { Forwards SteamShutdown_t; ends the application if @link(QuitOnSteamShutdown). }
    procedure CoreSteamShutdown(Sender: TObject);
    { Core shut down: stop pumping, detach plug-in components, raise @link(OnShutdown). }
    procedure CoreShutdown(Sender: TObject);
    { Forwards every callback to @link(OnCallback). }
    procedure CoreAnyCallback(const AData: TSteamCallbackData);
    { Shows handler exceptions (@link(ShowHandlerException)) and keeps pumping. }
    procedure CoreHandlerError(Sender: TObject; E: Exception; ACallbackID: Integer; var AHandled: Boolean);
  protected
    { Starts calling @link(RunCallbacks) every AIntervalMs on the UI thread. }
    procedure PumpStart(AIntervalMs: Integer); virtual; abstract;
    { Stops the callback pump. }
    procedure PumpStop; virtual; abstract;
    { Shows an exception raised by a callback handler (the framework's way). }
    procedure ShowHandlerException(E: Exception); virtual; abstract;
    { Ends the application (relaunch through Steam, QuitOnSteamShutdown). }
    procedure TerminateApplication; virtual; abstract;
    { Applies a streamed Active value (starts Steam at run time only). }
    procedure Loaded; override;
    { Configures and starts the core. @returns(@true when Steam is running.) }
    function DoActivate: Boolean; virtual;
    { Stops pumping and shuts the core down. }
    procedure DoDeactivate; virtual;
    { Called by TSteamPluginComponent.SteamAPI. }
    procedure LinkComponent(AComponent: TSteamPluginComponent);
    { Called by TSteamPluginComponent.SteamAPI and its destructor. }
    procedure UnlinkComponent(AComponent: TSteamPluginComponent);
  public
    { @raises(ESteamworksError if another TSteamAPI exists at run time.) }
    constructor Create(AOwner: TComponent); override;
    { Shuts Steam down if this instance started it, and releases everything. }
    destructor Destroy; override;
    { Same as @code(Active := True), returning the outcome. }
    function Open: Boolean;
    { Same as @code(Active := False). Safe to call more than once. }
    procedure Close;
    { Pumps callbacks now, in addition to the timer. }
    procedure RunCallbacks;
    { The core singleton; reach plug-ins with @code(Steam.FindPlugin) (or
      @code(Steam.Plugin<T>) in Delphi). }
    property Steam: TSteamworks read GetSteam;
    { @true while Steam is running. }
    property IsRunning: Boolean read GetIsRunning;

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
    { End the application when the Steam client exits. }
    property QuitOnSteamShutdown: Boolean read FQuitOnSteamShutdown write FQuitOnSteamShutdown default False;
    { Shut Steam down (not the app) as soon as the Steam client exits; see
      TSteamworks.ShutdownOnSteamExit. }
    property ShutdownOnSteamExit: Boolean read FShutdownOnSteamExit write FShutdownOnSteamExit default True;

    { Steam started successfully (plug-in components are attached already). }
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
  Math;

var
  GComponentCount: Integer = 0;

{ TSteamPluginComponent }

destructor TSteamPluginComponent.Destroy;
begin
  Detach;
  SteamAPI := nil;
  inherited;
end;

procedure TSteamPluginComponent.SetSteamAPI(const AValue: TCustomSteamAPI);
begin
  if AValue = FSteamAPI then
    Exit;
  Detach;
  if FSteamAPI <> nil then
  begin
    FSteamAPI.UnlinkComponent(Self);
    FSteamAPI.RemoveFreeNotification(Self);
  end;
  FSteamAPI := AValue;
  if FSteamAPI <> nil then
  begin
    FSteamAPI.FreeNotification(Self);
    FSteamAPI.LinkComponent(Self);
    Attach;
  end;
end;

procedure TSteamPluginComponent.Notification(AComponent: TComponent; AOperation: TOperation);
begin
  inherited;
  if (AOperation = opRemove) and (AComponent = FSteamAPI) then
  begin
    // opRemove also comes when the root only changes owner: unlink both ways
    Detach;
    FSteamAPI.UnlinkComponent(Self);
    FSteamAPI := nil;
  end;
end;

procedure TSteamPluginComponent.Loaded;
var
  I: Integer;
  Found: TCustomSteamAPI;
begin
  inherited;
  if (FSteamAPI <> nil) or (csDesigning in ComponentState) or (Owner = nil) then
    Exit;
  Found := nil;
  for I := 0 to Owner.ComponentCount - 1 do
    if Owner.Components[I] is TCustomSteamAPI then
    begin
      if Found <> nil then
        Exit; // more than one: the user must choose
      Found := TCustomSteamAPI(Owner.Components[I]);
    end;
  if Found <> nil then
    SteamAPI := Found;
end;

procedure TSteamPluginComponent.Attach;
begin
  if FAttached or (csDesigning in ComponentState) or (FSteamAPI = nil) or not FSteamAPI.IsRunning then
    Exit;
  FAttached := True;
  DoAttach;
end;

procedure TSteamPluginComponent.Detach;
begin
  if not FAttached then
    Exit;
  FAttached := False;
  if TSteamworks.HasInstance then
    TSteamworks.Instance.Dispatcher.RemoveOwner(Self);
end;

procedure TSteamPluginComponent.DoAttach;
begin
end;

procedure TSteamPluginComponent.SubscribeCallback(ACallbackID: Integer; AHandler: TSteamCallbackEvent);
begin
  TSteamworks.Instance.Dispatcher.Subscribe(ACallbackID, AHandler, True);
end;

function TSteamPluginComponent.PayloadOK(const AData: TSteamCallbackData; ARecordSize: Integer;
  const AStructName: string): Boolean;
begin
  if AData.IsCallResult and AData.IOFailure then
  begin
    if TSteamworks.HasInstance then
      TSteamworks.Instance.Log(sllWarning, Format('%s %s (call result %d, call %d): Steam reported an IO failure - ' +
        'event not raised', [ClassName, AStructName, AData.CallbackID, AData.APICall]));
    Exit(False);
  end;
  if (AData.Data = nil) or (AData.Size <> ARecordSize) then
    raise ESteamworksError.CreateFmt('%s (callback %d): Steam delivered %d bytes, the Pascal record has %d - ' +
      'layout mismatch, event not raised', [AStructName, AData.CallbackID, AData.Size, ARecordSize]);
  Result := True;
end;

{ TCustomSteamAPI }

constructor TCustomSteamAPI.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  // csDesigning is known only after inherited Create (set from the owner)
  if not (csDesigning in ComponentState) then
  begin
    if GComponentCount > 0 then
      raise ESteamworksError.Create('Only one TSteamAPI component may exist per application');
    Inc(GComponentCount);
    FCounted := True;
  end;
  FLinked := TList<TSteamPluginComponent>.Create;
  FCallbackInterval := 33;
  FInstallWarningHook := True;
  FShutdownOnSteamExit := True;
  FInitMode := simAuto;
end;

destructor TCustomSteamAPI.Destroy;
var
  I: Integer;
begin
  if FCounted then
  begin
    PumpStop;
    DetachLinked;
    // The owner's controls may already be gone: detach events first
    UnhookCore;
    if FActive and TSteamworks.HasInstance then
      TSteamworks.Instance.Shutdown;
    FActive := False;
    Dec(GComponentCount);
  end;
  if FLinked <> nil then
    for I := FLinked.Count - 1 downto 0 do
      FLinked[I].FSteamAPI := nil;
  FLinked.Free;
  inherited;
end;

function TCustomSteamAPI.Alive: Boolean;
begin
  Result := not (csDestroying in ComponentState);
end;

function TCustomSteamAPI.GetSteam: TSteamworks;
begin
  Result := TSteamworks.Instance;
end;

function TCustomSteamAPI.GetIsRunning: Boolean;
begin
  Result := TSteamworks.HasInstance and TSteamworks.Instance.IsRunning;
end;

procedure TCustomSteamAPI.LinkComponent(AComponent: TSteamPluginComponent);
begin
  if not FLinked.Contains(AComponent) then
    FLinked.Add(AComponent);
end;

procedure TCustomSteamAPI.UnlinkComponent(AComponent: TSteamPluginComponent);
begin
  FLinked.Remove(AComponent);
end;

procedure TCustomSteamAPI.AttachLinked;
var
  I: Integer;
begin
  for I := 0 to FLinked.Count - 1 do
    FLinked[I].Attach;
end;

procedure TCustomSteamAPI.DetachLinked;
var
  I: Integer;
begin
  for I := 0 to FLinked.Count - 1 do
    FLinked[I].Detach;
end;

procedure TCustomSteamAPI.Loaded;
begin
  inherited;
  if csDesigning in ComponentState then
    FActive := FStreamedActive
  else if FStreamedActive then
    SetActive(True);
  FStreamedActive := False;
end;

procedure TCustomSteamAPI.SetActive(const AValue: Boolean);
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
    DoActivate   // sets FActive itself; OnInitialized may already have closed again
  else
  begin
    DoDeactivate;
    FActive := False;
  end;
end;

procedure TCustomSteamAPI.SetCallbackInterval(const AValue: Integer);
begin
  FCallbackInterval := Max(0, AValue);
  if csDesigning in ComponentState then
    Exit;
  if FActive and (FCallbackInterval > 0) then
    PumpStart(FCallbackInterval)
  else
    PumpStop;
end;

procedure TCustomSteamAPI.HookCore;
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

procedure TCustomSteamAPI.UnhookCore;
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

function TCustomSteamAPI.DoActivate: Boolean;
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
  S.ShutdownOnSteamExit := FShutdownOnSteamExit;

  if FRestartIfNecessary and (FAppID <> 0) and S.RestartAppIfNecessary(FAppID) then
  begin
    Terminate := True;
    if Assigned(FOnRestartRequired) then
      FOnRestartRequired(Self, Terminate);
    if Terminate then
      TerminateApplication;
    Exit(False);
  end;

  Result := S.Initialize;
  if Result then
  begin
    FActive := True;
    if FCallbackInterval > 0 then
      PumpStart(FCallbackInterval);
    AttachLinked;
    if Assigned(FOnInitialized) then
      FOnInitialized(Self);
  end
  else if Assigned(FOnInitFailed) then
    FOnInitFailed(Self, Ord(S.LastInitResult), S.LastError);
end;

procedure TCustomSteamAPI.DoDeactivate;
begin
  PumpStop;
  if TSteamworks.HasInstance then
    TSteamworks.Instance.Shutdown;   // fires CoreShutdown -> OnShutdown
end;

function TCustomSteamAPI.Open: Boolean;
begin
  Active := True;
  Result := FActive;
end;

procedure TCustomSteamAPI.Close;
begin
  Active := False;
end;

procedure TCustomSteamAPI.RunCallbacks;
begin
  if GetIsRunning then
    TSteamworks.Instance.RunCallbacks;
end;

procedure TCustomSteamAPI.CoreLog(Sender: TObject; ALevel: TSteamLogLevel; const AMessage: string);
begin
  if Alive and Assigned(FOnLog) then
    FOnLog(Self, ALevel, AMessage);
end;

procedure TCustomSteamAPI.CoreWarning(Sender: TObject; ASeverity: Integer; const AText: string);
begin
  if Alive and Assigned(FOnWarning) then
    FOnWarning(Self, ASeverity, AText);
end;

procedure TCustomSteamAPI.CoreSteamShutdown(Sender: TObject);
begin
  if not Alive then
    Exit;
  if Assigned(FOnSteamShutdown) then
    FOnSteamShutdown(Self);
  if FQuitOnSteamShutdown then
    TerminateApplication;
end;

procedure TCustomSteamAPI.CoreShutdown(Sender: TObject);
begin
  PumpStop;
  DetachLinked;
  FActive := False;
  if Alive and Assigned(FOnShutdown) then
    FOnShutdown(Self);
end;

procedure TCustomSteamAPI.CoreAnyCallback(const AData: TSteamCallbackData);
begin
  if Alive and Assigned(FOnCallback) then
    FOnCallback(Self, AData);
end;

procedure TCustomSteamAPI.CoreHandlerError(Sender: TObject; E: Exception; ACallbackID: Integer;
  var AHandled: Boolean);
begin
  ShowHandlerException(E);
  AHandled := True;
end;

end.
