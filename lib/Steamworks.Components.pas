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

  { How a game server authenticates players and whether it is listed: the
    published form of the SDK's EServerMode (an enum with explicit values
    has no RTTI, so it cannot be a published property). }
  TSteamServerMode = (
    { eServerModeNoAuthentication: no login checks, not in the server list. }
    ssmNoAuthentication,
    { eServerModeAuthentication: Steam authenticates players, listed, no VAC. }
    ssmAuthentication,
    { eServerModeAuthenticationAndSecure: as above plus VAC (Valve's default). }
    ssmAuthenticationAndSecure
  );

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
    { @true for the component of a GAME-SERVER plug-in (generated
      TSteamGameServer... components): it attaches while the game server
      runs and takes its callbacks from the server's dispatcher. }
    class function IsGameServer: Boolean; virtual;
    { Detaches and unlinks. }
    destructor Destroy; override;
    { Subscribes the callbacks if its side (client, or game server for
      @link(IsGameServer)) runs and it is not attached already. }
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
    { > 0 while @link(Open) runs: a failed start is reported by its result. }
    FOpenDepth: Integer;
    { Why the last start failed ('' when it did not, or Steam is relaunching). }
    FFailMessage: string;
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
    { Backing field of @link(UpdateMode). }
    FUpdateMode: TSteamUpdateMode;
    { Backing field of @link(Delivery). }
    FDelivery: TSteamDelivery;
    { @true while the framework timer runs (@link(PumpStart) was called and
      @link(PumpStop) not yet). }
    FPumpRunning: Boolean;
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
    { Backing field of @link(Roles). }
    FRoles: TSteamRoles;
    { Backing field of @link(GameServerIP). }
    FGameServerIP: Cardinal;
    { Backing field of @link(GameServerGamePort). }
    FGameServerGamePort: Word;
    { Backing field of @link(GameServerQueryPort). }
    FGameServerQueryPort: Word;
    { Backing field of @link(GameServerMode). }
    FGameServerMode: TSteamServerMode;
    { Backing field of @link(GameServerVersion). }
    FGameServerVersion: string;
    { Backing field of @link(OnGameServerStarted). }
    FOnGameServerStarted: TNotifyEvent;
    { Backing field of @link(OnGameServerStopped). }
    FOnGameServerStopped: TNotifyEvent;
    { Backing field of @link(OnGameServerFailed). }
    FOnGameServerFailed: TSteamInitFailedEvent;
    { Write accessor of @link(Active). }
    procedure SetActive(const AValue: Boolean);
    { Write accessor of @link(CallbackInterval). }
    procedure SetCallbackInterval(const AValue: Integer);
    { Write accessor of @link(UpdateMode). }
    procedure SetUpdateModeProp(const AValue: TSteamUpdateMode);
    { Write accessor of @link(Delivery). }
    procedure SetDelivery(const AValue: TSteamDelivery);
    { Starts or stops the framework timer to match @link(UpdateMode): it
      runs in @link(sumTimer) mode, and in @link(sumThread) mode only as a
      fallback when the core's worker could not start. }
    procedure UpdatePump;
    { Hands the current mode, delivery and interval to the core. }
    procedure PushUpdateMode;
    { @true on the main (UI) thread. }
    function OnMainThread: Boolean;
    { Ends the application from any thread: directly on the main thread,
      otherwise queued to it (TThread.Queue). }
    procedure SafeTerminate;
    { TThread.Queue target of @link(SafeTerminate). }
    procedure QueuedTerminate;
    { Read accessor of @link(Steam). }
    function GetSteam: TSteamworks;
    { Read accessor of @link(IsRunning). }
    function GetIsRunning: Boolean;
    { Read accessor of @link(IsGameServerRunning). }
    function GetIsGameServerRunning: Boolean;
    { @true while the core runs anything (client and / or game server). }
    function CoreActive: Boolean;
    { Hands this component's settings (AppID, library, modes, game-server
      settings) to the core and hooks its events. }
    procedure ConfigureCore;
    { Hands only the GameServer* settings to the core. }
    procedure PushServerSettings;
    { Core game server started: attach the game-server components, raise
      @link(OnGameServerStarted). }
    procedure CoreGameServerStarted(Sender: TObject);
    { Core game server stopped: detach the game-server components, raise
      @link(OnGameServerStopped). }
    procedure CoreGameServerStopped(Sender: TObject);
    { Starts the game server in the core (settings already pushed).
      @returns(@true when it runs.) }
    function StartServerInCore: Boolean;
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
    { Same as @code(Active := True), but never reports a failed start
      itself (no message box): @returns(@true when Steam is running.) }
    function Open: Boolean;
    { Same as @code(Active := False). Safe to call more than once. }
    procedure Close;
    { Pumps / delivers callbacks now (see TSteamworks.RunCallbacks for what
      that means in each @link(UpdateMode)). The timer calls it in
      @link(sumTimer) mode. }
    procedure RunCallbacks;
    { Same as @link(RunCallbacks); call it once per frame in
      @link(sumManual) mode, or in @link(sumThread) mode with
      @link(sdOnUpdate) delivery. }
    procedure Update;
    { Sets @link(UpdateMode), @link(Delivery) and (when AIntervalMs >= 0)
      @link(CallbackInterval) in one call; applies at once while running.
      Call it from the main thread, never from an event handler.
      @longCode(#
      SteamAPI.SetUpdateMode(sumThread, sdMainThread);  // worker reads, UI thread handles
      #) }
    procedure SetUpdateMode(AMode: TSteamUpdateMode; ADelivery: TSteamDelivery;
      AIntervalMs: Integer = -1);
    { The core singleton; reach plug-ins with @code(Steam.FindPlugin) (or
      @code(Steam.Plugin<T>) in Delphi). }
    property Steam: TSteamworks read GetSteam;
    { @true while Steam (the CLIENT, SteamAPI) is running. }
    property IsRunning: Boolean read GetIsRunning;
    { @true while a game server runs (@link(StartGameServer), or
      @link(Roles) with @link(srGameServer)). }
    property IsGameServerRunning: Boolean read GetIsGameServerRunning;

    { Starts a game server with the GameServer* properties while the client
      runs (a LISTEN server, started when the player chooses to host), or
      on its own when Steam is not active (a DEDICATED server - then Active
      becomes @true too). Its components (TSteamGameServer,
      TSteamGameServerStats, TSteamGameServerUtils, ...) attach; log on with
      TSteamGameServer (LogOnAnonymous). A failure raises
      @link(OnGameServerFailed) when assigned and is logged.
      @returns(@true when the game server runs.) }
    function StartGameServer: Boolean;
    { Shuts the game server down (its components detach); the client keeps
      running. A dedicated server: the same as @link(Close). }
    procedure StopGameServer;

    { Starts / stops Steam. At design time the value is only stored. When
      Steam cannot start and no @link(OnInitFailed) handler is assigned, the
      error (an ESteamworksError with Steam's message) is SHOWN the
      framework's way (ShowHandlerException) - it is not raised, so a failed
      start in FormCreate or in the form file never ends the application.
      Afterwards Active is @false. Use @link(OnInitFailed) to handle it
      yourself, or @link(Open) to get a Boolean and no message. }
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
    { Pump interval in ms: the timer's interval in @link(sumTimer) mode
      (0 = no timer: call @link(Update) yourself), the worker's period in
      @link(sumThread) mode (0 = as fast as possible, 1 ms). }
    property CallbackInterval: Integer read FCallbackInterval write SetCallbackInterval default 33;
    { Who drains Steam's queue: the framework timer (@link(sumTimer),
      default), a worker thread (@link(sumThread)) or your loop calling
      @link(Update) (@link(sumManual)). See GameEngineIntegration.md. }
    property UpdateMode: TSteamUpdateMode read FUpdateMode write SetUpdateModeProp default sumTimer;
    { Where events run in @link(sumThread) mode: the main thread
      (@link(sdMainThread), default), inside your @link(Update) call
      (@link(sdOnUpdate)) or on the worker (@link(sdPumpThread) - your
      handlers must then synchronise; this component's own message boxes
      are replaced by log lines there). }
    property Delivery: TSteamDelivery read FDelivery write SetDelivery default sdMainThread;
    { Forward Steam debug output to @link(OnWarning). }
    property InstallWarningHook: Boolean read FInstallWarningHook write FInstallWarningHook default True;
    { End the application when the Steam client exits. }
    property QuitOnSteamShutdown: Boolean read FQuitOnSteamShutdown write FQuitOnSteamShutdown default False;
    { Shut Steam down (not the app) as soon as the Steam client exits; see
      TSteamworks.ShutdownOnSteamExit. }
    property ShutdownOnSteamExit: Boolean read FShutdownOnSteamExit write FShutdownOnSteamExit default True;
    { What @link(Active) starts: [srClient] (default, a game), [srClient,
      srGameServer] (a listen server from the start) or [srGameServer] (a
      dedicated server, no Steam client needed). A listen server that starts
      later keeps [srClient] and calls @link(StartGameServer). }
    property Roles: TSteamRoles read FRoles write FRoles default [srClient];
    { IP address the game server binds to, host order (0 = any). }
    property GameServerIP: Cardinal read FGameServerIP write FGameServerIP default 0;
    { UDP port of the game's own traffic. }
    property GameServerGamePort: Word read FGameServerGamePort write FGameServerGamePort default 27015;
    { UDP port Steam answers server-browser queries on (A2S ping / players /
      rules); 65535 = STEAMGAMESERVER_QUERY_PORT_SHARED (the game forwards
      them through TSteamGameServer HandleIncomingPacket). }
    property GameServerQueryPort: Word read FGameServerQueryPort write FGameServerQueryPort default 27016;
    { Authentication, listing and VAC mode of the game server. }
    property GameServerMode: TSteamServerMode read FGameServerMode write FGameServerMode
      default ssmAuthenticationAndSecure;
    { Version of the game server ('1.0.0.0'); Steam compares it with the one
      set on the partner site. }
    property GameServerVersion: string read FGameServerVersion write FGameServerVersion;

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
    { Every Steam callback, for diagnostics (client and game server). }
    property OnCallback: TSteamCallbackNotifyEvent read FOnCallback write FOnCallback;
    { The game server started (its components are attached already). }
    property OnGameServerStarted: TNotifyEvent read FOnGameServerStarted write FOnGameServerStarted;
    { The game server was shut down. }
    property OnGameServerStopped: TNotifyEvent read FOnGameServerStopped write FOnGameServerStopped;
    { The game server could not start; AResult is the ESteamAPIInitResult. }
    property OnGameServerFailed: TSteamInitFailedEvent read FOnGameServerFailed write FOnGameServerFailed;
  end;

implementation

uses
  Math, Steamworks.SDKTypes;

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

class function TSteamPluginComponent.IsGameServer: Boolean;
begin
  Result := False;
end;

procedure TSteamPluginComponent.Attach;
begin
  if FAttached or (csDesigning in ComponentState) or (FSteamAPI = nil) then
    Exit;
  if IsGameServer then
  begin
    if not FSteamAPI.IsGameServerRunning then
      Exit;
  end
  else if not FSteamAPI.IsRunning then
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
    TSteamworks.Instance.DispatcherFor(IsGameServer).RemoveOwner(Self);
end;

procedure TSteamPluginComponent.DoAttach;
begin
end;

procedure TSteamPluginComponent.SubscribeCallback(ACallbackID: Integer; AHandler: TSteamCallbackEvent);
begin
  TSteamworks.Instance.DispatcherFor(IsGameServer).Subscribe(ACallbackID, AHandler, True);
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
  FUpdateMode := sumTimer;
  FDelivery := sdMainThread;
  FInstallWarningHook := True;
  FShutdownOnSteamExit := True;
  FInitMode := simAuto;
  FRoles := [srClient];
  FGameServerGamePort := 27015;
  FGameServerQueryPort := 27016;
  FGameServerMode := ssmAuthenticationAndSecure;
  FGameServerVersion := '1.0.0.0';
end;

destructor TCustomSteamAPI.Destroy;
var
  I: Integer;
begin
  if FCounted then
  begin
    if FPumpRunning then
    begin
      PumpStop;
      FPumpRunning := False;
    end;
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
  // A quit queued from a worker thread (SafeTerminate) must not reach a freed object
  if FCounted then
    TThread.RemoveQueuedEvents(nil, QueuedTerminate);
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

function TCustomSteamAPI.GetIsGameServerRunning: Boolean;
begin
  Result := TSteamworks.HasInstance and TSteamworks.Instance.IsGameServerRunning;
end;

function TCustomSteamAPI.CoreActive: Boolean;
begin
  Result := TSteamworks.HasInstance and (TSteamworks.Instance.State = swsRunning);
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
    SetActive(True);   // a failure is shown, never raised (see SetActive)
  FStreamedActive := False;
end;

procedure TCustomSteamAPI.SetActive(const AValue: Boolean);
var
  E: ESteamworksError;
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
  begin
    FFailMessage := '';
    DoActivate;  // sets FActive itself; OnInitialized may already have closed again
    // No silent failure, but no exception either: raised from FormCreate or
    // Loaded it would escape Application.CreateForm and end the program
    // (tested: FMX, Steam not running). Show it the framework's way.
    if (not FActive) and (FFailMessage <> '') and (FOpenDepth = 0) and not Assigned(FOnInitFailed) then
    begin
      E := ESteamworksError.Create(FFailMessage);
      try
        ShowHandlerException(E);
      finally
        E.Free;
      end;
    end;
  end
  else
  begin
    DoDeactivate;
    FActive := False;
  end;
end;

procedure TCustomSteamAPI.SetCallbackInterval(const AValue: Integer);
begin
  FCallbackInterval := Max(0, AValue);
  if (csDesigning in ComponentState) or (csLoading in ComponentState) then
    Exit;
  if FActive then
  begin
    PushUpdateMode;
    if FPumpRunning then
    begin
      PumpStop;          // restart with the new interval
      FPumpRunning := False;
    end;
    UpdatePump;
  end;
end;

procedure TCustomSteamAPI.SetUpdateModeProp(const AValue: TSteamUpdateMode);
begin
  SetUpdateMode(AValue, FDelivery);
end;

procedure TCustomSteamAPI.SetDelivery(const AValue: TSteamDelivery);
begin
  SetUpdateMode(FUpdateMode, AValue);
end;

procedure TCustomSteamAPI.SetUpdateMode(AMode: TSteamUpdateMode; ADelivery: TSteamDelivery;
  AIntervalMs: Integer);
begin
  FUpdateMode := AMode;
  FDelivery := ADelivery;
  if AIntervalMs >= 0 then
    FCallbackInterval := AIntervalMs;
  if (csDesigning in ComponentState) or (csLoading in ComponentState) then
    Exit;
  if FActive then
  begin
    PushUpdateMode;
    if FPumpRunning then
    begin
      PumpStop;
      FPumpRunning := False;
    end;
    UpdatePump;
  end;
end;

procedure TCustomSteamAPI.PushUpdateMode;
begin
  TSteamworks.Instance.SetUpdateMode(FUpdateMode, FDelivery, Max(1, FCallbackInterval));
end;

procedure TCustomSteamAPI.UpdatePump;
var
  Interval: Integer;
  Want: Boolean;
begin
  if csDesigning in ComponentState then
    Exit;
  Interval := FCallbackInterval;
  case FUpdateMode of
    sumTimer:
      Want := FActive and (Interval > 0);
    sumThread:
      begin
        // Fallback only: the worker could not start (FPC without cthreads, ...)
        Want := FActive and CoreActive and not TSteamworks.Instance.Threaded;
        if Interval <= 0 then
          Interval := 16;
      end;
  else
    Want := False;   // sumManual: the program calls Update
  end;
  if Want and not FPumpRunning then
  begin
    PumpStart(Interval);
    FPumpRunning := True;
  end
  else if FPumpRunning and not Want then
  begin
    PumpStop;
    FPumpRunning := False;
  end;
end;

function TCustomSteamAPI.OnMainThread: Boolean;
begin
  Result := TThread.CurrentThread.ThreadID = MainThreadID;
end;

procedure TCustomSteamAPI.SafeTerminate;
begin
  if OnMainThread then
    TerminateApplication
  else
    TThread.Queue(nil, QueuedTerminate);
end;

procedure TCustomSteamAPI.QueuedTerminate;
begin
  TerminateApplication;
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
  S.OnGameServerStarted := CoreGameServerStarted;
  S.OnGameServerStopped := CoreGameServerStopped;
  S.Dispatcher.OnAnyCallback := CoreAnyCallback;
  S.Dispatcher.OnHandlerError := CoreHandlerError;
  S.ServerDispatcher.OnAnyCallback := CoreAnyCallback;
  S.ServerDispatcher.OnHandlerError := CoreHandlerError;
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
  S.OnGameServerStarted := nil;
  S.OnGameServerStopped := nil;
  S.Dispatcher.OnAnyCallback := nil;
  S.Dispatcher.OnHandlerError := nil;
  S.ServerDispatcher.OnAnyCallback := nil;
  S.ServerDispatcher.OnHandlerError := nil;
end;

procedure TCustomSteamAPI.PushServerSettings;
const
  Modes: array[TSteamServerMode] of EServerMode =
    (eServerModeNoAuthentication, eServerModeAuthentication, eServerModeAuthenticationAndSecure);
var
  S: TSteamworks;
begin
  S := TSteamworks.Instance;
  S.GameServerIP := FGameServerIP;
  S.GameServerGamePort := FGameServerGamePort;
  S.GameServerQueryPort := FGameServerQueryPort;
  S.GameServerMode := Modes[FGameServerMode];
  S.GameServerVersion := FGameServerVersion;
end;

procedure TCustomSteamAPI.ConfigureCore;
var
  S: TSteamworks;
begin
  S := TSteamworks.Instance;
  HookCore;
  S.AppID := FAppID;
  S.SetAppIdEnvironment := FSetAppIdEnvironment;
  S.LibraryPath := FLibraryPath;
  S.InitMode := FInitMode;
  S.InstallWarningHook := FInstallWarningHook;
  S.ShutdownOnSteamExit := FShutdownOnSteamExit;
  PushServerSettings;
  // Before Initialize: in sumThread mode the core starts its worker there
  S.SetUpdateMode(FUpdateMode, FDelivery, Max(1, FCallbackInterval));
end;

function TCustomSteamAPI.StartServerInCore: Boolean;
var
  S: TSteamworks;
begin
  S := TSteamworks.Instance;
  Result := S.StartGameServer;   // attaches through CoreGameServerStarted
  if not Result then
  begin
    FFailMessage := Format('The game server did not start (result %d): %s', [Ord(S.LastInitResult), S.LastError]);
    if Assigned(FOnGameServerFailed) then
      FOnGameServerFailed(Self, Ord(S.LastInitResult), S.LastError);
  end;
end;

function TCustomSteamAPI.DoActivate: Boolean;
var
  S: TSteamworks;
  Terminate: Boolean;
begin
  S := TSteamworks.Instance;
  ConfigureCore;
  if FRoles = [] then
  begin
    FFailMessage := 'Roles is empty: nothing to start (srClient and / or srGameServer)';
    if Assigned(FOnInitFailed) then
      FOnInitFailed(Self, Ord(k_ESteamAPIInitResult_FailedGeneric), FFailMessage);
    Exit(False);
  end;

  if (srClient in FRoles) and FRestartIfNecessary and (FAppID <> 0) and S.RestartAppIfNecessary(FAppID) then
  begin
    Terminate := True;
    if Assigned(FOnRestartRequired) then
      FOnRestartRequired(Self, Terminate);
    if Terminate then
      SafeTerminate;
    Exit(False);
  end;

  Result := True;
  if srClient in FRoles then
  begin
    Result := S.Initialize;
    if not Result then
      FFailMessage := Format('Steam did not start (result %d): %s',
        [Ord(S.LastInitResult), S.LastError]);
  end;
  if Result and (srGameServer in FRoles) then
  begin
    Result := StartServerInCore;
    if not Result then
    begin
      if not (srClient in FRoles) then
        FFailMessage := Format('Steam did not start (result %d): %s', [Ord(S.LastInitResult), S.LastError]);
      S.Shutdown;   // all or nothing: the client of a listen server goes too
    end;
  end;
  if Result then
  begin
    FActive := True;
    UpdatePump;
    AttachLinked;
    if Assigned(FOnInitialized) then
      FOnInitialized(Self);
  end
  else if Assigned(FOnInitFailed) then
    FOnInitFailed(Self, Ord(S.LastInitResult), S.LastError);
end;

function TCustomSteamAPI.StartGameServer: Boolean;
begin
  Result := False;
  if csDesigning in ComponentState then
    Exit;
  if IsGameServerRunning then
    Exit(True);
  if not CoreActive then
  begin
    // A dedicated server started on its own
    ConfigureCore;
    Result := StartServerInCore;
    if Result then
    begin
      FActive := True;
      UpdatePump;
    end;
    Exit;
  end;
  // A listen server: the client runs; only the server settings change
  // (the rest of the running core is left alone)
  PushServerSettings;
  Result := StartServerInCore;
  UpdatePump;
end;

procedure TCustomSteamAPI.StopGameServer;
begin
  if TSteamworks.HasInstance then
    TSteamworks.Instance.StopGameServer;   // fires CoreGameServerStopped (+ CoreShutdown if dedicated)
end;

procedure TCustomSteamAPI.CoreGameServerStarted(Sender: TObject);
begin
  AttachLinked;   // only the game-server components attach now
  if Alive and Assigned(FOnGameServerStarted) then
    FOnGameServerStarted(Self);
end;

procedure TCustomSteamAPI.CoreGameServerStopped(Sender: TObject);
var
  I: Integer;
begin
  for I := 0 to FLinked.Count - 1 do
    if FLinked[I].IsGameServer then
      FLinked[I].Detach;
  if Alive and Assigned(FOnGameServerStopped) then
    FOnGameServerStopped(Self);
end;

procedure TCustomSteamAPI.DoDeactivate;
begin
  if FPumpRunning then
  begin
    PumpStop;
    FPumpRunning := False;
  end;
  if TSteamworks.HasInstance then
    TSteamworks.Instance.Shutdown;   // fires CoreShutdown -> OnShutdown
end;

function TCustomSteamAPI.Open: Boolean;
begin
  Inc(FOpenDepth);
  try
    Active := True;
  finally
    Dec(FOpenDepth);
  end;
  Result := FActive;
end;

procedure TCustomSteamAPI.Close;
begin
  Active := False;
end;

procedure TCustomSteamAPI.RunCallbacks;
begin
  if CoreActive then   // client and / or game server
    TSteamworks.Instance.RunCallbacks;
end;

procedure TCustomSteamAPI.Update;
begin
  RunCallbacks;
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
    SafeTerminate;
end;

procedure TCustomSteamAPI.CoreShutdown(Sender: TObject);
begin
  // The timer only runs when events arrive on the main thread, so this is
  // never a framework call from the worker
  if FPumpRunning then
  begin
    PumpStop;
    FPumpRunning := False;
  end;
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
  if OnMainThread then
    ShowHandlerException(E)
  else if TSteamworks.HasInstance then
    // sdPumpThread: no message box from a worker thread; the exception
    // object dies with this handler, so only its text can travel
    TSteamworks.Instance.Log(sllError, Format('Handler for callback %d raised %s: %s',
      [ACallbackID, E.ClassName, E.Message]));
  AHandled := True;
end;

end.
