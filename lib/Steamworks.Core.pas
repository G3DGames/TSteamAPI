(* @abstract(The Steam client core (@link(TSteamworks)) and the plug-in base
  class (@link(TSteamPlugin)).)

  @link(TSteamworks) owns the process-wide Steam session: loading the
  redistributable, SteamAPI initialisation, the pipe and user handles,
  ISteamClient, the callback pump and interface lookup. It is independent of
  any UI framework; Steamworks.FMX (and later VCL / LCL units) only add a timer
  and component wrapper.

  @bold(Plug-in model.) Every other Steam interface (ISteamUser,
  ISteamFriends, ISteamUserStats, ...) is a @link(TSteamPlugin) descendant in
  its own unit, registered in that unit's initialization section:

  @longCode(#
  initialization
    TSteamworks.RegisterPlugin(TSteamFriendsPlugin);
  finalization
    TSteamworks.UnregisterPlugin(TSteamFriendsPlugin);
  #)

  Linking the unit enables the interface; leaving it out keeps it, and its
  exports, out of the program. After @link(TSteamworks.Initialize) succeeds,
  registered plug-ins and their dependencies are initialised in dependency
  order and finalised in reverse order by @link(TSteamworks.Shutdown).

  Minimal use without any component:
  @longCode(#
  uses Steamworks.Core, Steamworks.Plugin.Utils;

  begin
    Steam.AppID := 2275430;
    Steam.SetAppIdEnvironment := True;     // development builds
    if Steam.RestartAppIfNecessary then
      Halt;                                // Steam relaunches the game
    if not Steam.Initialize then
      Writeln(Steam.LastError)
    else
    begin
      Writeln(Steam.FindPlugin(TSteamUtilsPlugin) <> nil);
      // game loop: call Steam.Update (= RunCallbacks) every frame
      Steam.Shutdown;
    end;
  end.
  #)

  @bold(Updating.) @link(TSteamworks.UpdateMode) chooses who drains Steam's
  queue: a framework timer (the components' default), your own loop
  (@link(sumManual)), or a worker thread (@link(sumThread)) whose results
  are delivered on the main thread, inside your Update call, or on the
  worker itself (@link(TSteamworks.Delivery)). GameEngineIntegration.md
  explains every combination. FPC on Linux / macOS: a worker thread needs
  @code(cthreads) as the first unit of the program. *)
unit Steamworks.Core;

{$I Steamworks.inc}

interface

uses
  SysUtils, Classes, SyncObjs, Generics.Collections,
  Steamworks.Types, Steamworks.SDKTypes, Steamworks.API, Steamworks.Callbacks, Steamworks.SteamClient,
  Steamworks.Versions;

type
  TSteamworks = class;
  TSteamPlugin = class;
  { Class reference used for registration and lookup. }
  TSteamPluginClass = class of TSteamPlugin;
  { Dynamic array of plug-in classes (portable replacement for TArray<>). }
  TSteamPluginClassArray = array of TSteamPluginClass;

  { Lifecycle state of @link(TSteamworks). }
  TSteamworksState = (
    { Library not loaded. }
    swsIdle,
    { Library loaded, SteamAPI not initialised. }
    swsLibraryLoaded,
    { SteamAPI and / or a game server initialised; callbacks flow. }
    swsRunning
  );

  { What a session runs: the Steam client API (@code(SteamAPI_Init)) and /
    or a game server (@code(SteamGameServer_Init)). Both together = a
    listen server (Valve allows it); @link(srGameServer) alone = a
    dedicated server, which needs no Steam client. }
  TSteamRole = (
    { The Steam client API: the logged-on user's interfaces. }
    srClient,
    { A game server: the ISteamGameServer* interfaces, its own pipe and
      user, its own callbacks (@link(TSteamworks.ServerDispatcher)). }
    srGameServer
  );
  { Set of @link(TSteamRole). }
  TSteamRoles = set of TSteamRole;

  { How SteamAPI is initialised. }
  TSteamInitMode = (
    { SteamAPI_InitFlat when exported (SDK 1.59+), otherwise legacy SteamAPI_Init. }
    simAuto,
    { SteamAPI_InitFlat - Valve's entry point for non-C++ code. }
    simFlat,
    { SteamInternal_SteamAPI_Init with only the interface versions the linked
      plug-ins declare (@link(TSteamPlugin.InterfaceVersions)). }
    simVersioned,
    { SteamAPI_Init / SteamAPI_InitSafe from pre-1.59 redistributables. }
    simLegacy
  );

  { Who drains Steam's callback queue. See GameEngineIntegration.md. }
  TSteamUpdateMode = (
    { A framework timer calls RunCallbacks on the UI thread (the TSteamAPI
      components' default). For the core alone this is the same as
      @link(sumManual): something else must call
      @link(TSteamworks.RunCallbacks). }
    sumTimer,
    { A worker thread owned by the core drains the queue every
      @link(TSteamworks.PumpInterval) ms; @link(TSteamworks.Delivery) says
      where the handlers run. Steam's I/O never stalls a frame. }
    sumThread,
    { Your loop calls @link(TSteamworks.Update) (or RunCallbacks) - every
      frame of a game loop, for example. Handlers run inside that call. }
    sumManual
  );

  { Where handlers run when @link(TSteamworks.UpdateMode) is
    @link(sumThread). Ignored otherwise (handlers then run on the thread that
    calls RunCallbacks / Update). }
  TSteamDelivery = (
    { The worker hands each batch to the main thread with TThread.Queue.
      Needs a main loop that calls CheckSynchronize: FMX, VCL and LCL do;
      a console program or a custom loop must call it itself. }
    sdMainThread,
    { Handlers run inside @link(TSteamworks.Update), on whichever thread calls
      it - the game thread, at the point in the frame you choose. Needs
      nothing from the host. Recommended for game engines. }
    sdOnUpdate,
    { Handlers run on the worker thread itself, as soon as the callback is
      read. Lowest latency; every handler must do its own synchronisation and
      must never touch UI or engine objects directly. }
    sdPumpThread
  );

  { Severity passed to @link(TSteamLogEvent). }
  TSteamLogLevel = (sllDebug, sllInfo, sllWarning, sllError);

  { Diagnostic messages from the core and plug-ins. }
  TSteamLogEvent = procedure(Sender: TObject; ALevel: TSteamLogLevel; const AMessage: string) of object;
  { Steam client debug output (only when the game runs with -debug_steamapi).
    ASeverity: 0 = message, 1 = warning. }
  TSteamWarningEvent = procedure(Sender: TObject; ASeverity: Integer; const AText: string) of object;

  { Base class of every Steamworks interface plug-in.

    Override @link(DoInitialize) to acquire the interface and bind its flat
    exports; subscriptions made through @link(Subscribe) or
    @link(AwaitCallResult) are removed automatically on finalisation.
    See Plugins/Steamworks.Plugin.Utils.pas for a complete example.

    @longCode(#
    type
      TSteamFriendsPlugin = class(TSteamPlugin)
      private
        FIntf: Pointer;
        F_GetPersonaName: function(self: Pointer): PAnsiChar; cdecl;
        procedure PersonaChanged(const AData: TSteamCallbackData);
      protected
        function DoInitialize: Boolean; override;
      end;

    function TSteamFriendsPlugin.DoInitialize: Boolean;
    begin
      FIntf := AcquireUserInterface(STEAMFRIENDS_INTERFACE_VERSION, 'SteamFriends');
      Result := (FIntf <> nil) and
        Bind(F_GetPersonaName, 'SteamAPI_ISteamFriends_GetPersonaName');
      if Result then
        Subscribe(304, PersonaChanged);  // PersonaStateChange_t
    end;
    #) }
  TSteamPlugin = class
  private
    { Core this plug-in belongs to. }
    FSteam: TSteamworks;
    { @true between successful initialisation and finalisation. }
    FActive: Boolean;
    { Called by the core: runs @link(DoInitialize) safely. @returns(@true on success.) }
    function Initialize(ASteam: TSteamworks): Boolean;
    { Called by the core: runs @link(DoFinalize) and removes subscriptions. }
    procedure Finalize;
  protected
    { Acquire interfaces, bind exports and subscribe here.
      @returns(@false if the plug-in cannot work; it is then skipped
        (or initialisation fails when @link(IsRequired)).) }
    function DoInitialize: Boolean; virtual; abstract;

    { Release resources. Subscriptions and pending call results are removed
      automatically afterwards. }
    procedure DoFinalize; virtual;

    { Binds a flat export into a procedural variable.
      @param(AProc  Procedural variable (untyped).)
      @param(AExportName  e.g. @code('SteamAPI_ISteamFriends_GetPersonaName').)
      @param(ARequired  When @true a missing export is logged as an error and
        @false is returned; when @false it leaves AProc @nil and returns @true.)
      @returns(@false only for a missing required export.) }
    function Bind(var AProc; const AExportName: string; ARequired: Boolean = True): Boolean;

    { Pointer to a user-level interface; see @link(TSteamworks.AcquireUserInterface).
      Logs an error when it cannot be obtained. }
    function AcquireUserInterface(const AFallbackVersion: string; const AAccessorBase: string = ''): Pointer;

    { Subscribes a method of this plug-in to a callback id (on
      @link(Dispatcher): the game server's for a @link(IsGameServer) plug-in). }
    function Subscribe(ACallbackID: Integer; AHandler: TSteamCallbackEvent;
      AIncludeCallResults: Boolean = False): TSteamSubscription;
    { Registers a method of this plug-in for one async call result. }
    function AwaitCallResult(ACall: SteamAPICall_t; AExpectedCallbackID: Integer;
      AHandler: TSteamCallResultEvent): Boolean;
    { Removes one subscription. }
    procedure Unsubscribe(var AToken: TSteamSubscription);

    { Writes to @link(TSteamworks.OnLog), prefixed with @link(PluginName). }
    procedure Log(ALevel: TSteamLogLevel; const AMessage: string);
    { Formatting overload of @link(Log). }
    procedure LogFmt(ALevel: TSteamLogLevel; const AFmt: string; const AArgs: array of const);
  public
    { Plug-ins are created by @link(TSteamworks); do not create them yourself. }
    constructor Create; virtual;
    { Releases everything this object owns. }
    destructor Destroy; override;

    { Display name; defaults to the class name. }
    class function PluginName: string; virtual;
    { Plug-ins that must be initialised (successfully) before this one. }
    class function Dependencies: TSteamPluginClassArray; virtual;
    { When @true a failed initialisation makes @link(TSteamworks.Initialize) fail. }
    class function IsRequired: Boolean; virtual;
    { @true for a GAME-SERVER plug-in: it is created by
      @link(TSteamworks.StartGameServer) and freed by
      @link(TSteamworks.StopGameServer), takes its interface from the game
      server (@code(SteamAPI_SteamGameServer...) accessors) and its callbacks
      from the server's pipe. Default @false (a client plug-in). }
    class function IsGameServer: Boolean; virtual;
    { The dispatcher of this plug-in's side: @link(TSteamworks.Dispatcher)
      (client) or @link(TSteamworks.ServerDispatcher) (@link(IsGameServer)).
      Pass handlers of this plug-in's async calls here (AwaitCallResult,
      RemoveOwner). }
    function Dispatcher: TSteamCallbackDispatcher;
    { Interface versions this plug-in uses, resolved through AVersions.
      Only consulted for @link(simVersioned) initialisation, where Steam
      refuses to start if the client is too old for any of them.
      @longCode(#
      class function TSteamUtilsPlugin.InterfaceVersions(AVersions: TSteamInterfaceVersions): TSteamStringArray;
      begin
        SetLength(Result, 1);
        Result[0] := AVersions.Resolve(STEAMUTILS_INTERFACE_VERSION);
      end;
      #) }
    class function InterfaceVersions(AVersions: TSteamInterfaceVersions): TSteamStringArray; virtual;

    { The core this plug-in belongs to. }
    property Steam: TSteamworks read FSteam;
    { @true between successful initialisation and finalisation. }
    property Active: Boolean read FActive;
  end;

  { The process-wide Steam core. There is exactly one; use the @link(Steam)
    function or @link(TSteamworks.Instance). Callback handlers and the
    events raised from them fire on the thread that calls @link(RunCallbacks)
    / @link(Update) - unless @link(UpdateMode) is @link(sumThread), when
    @link(Delivery) decides (main thread, the thread calling Update, or the
    worker). Initialize / Shutdown events fire on the calling thread. }
  TSteamworks = class
  private
    { @true once the constructor completed (guards Destroy after a failed Create). }
    FConstructed: Boolean;
    { Backing field of @link(State). }
    FState: TSteamworksState;
    { Backing field of @link(AppID). }
    FAppID: AppId_t;
    { Backing field of @link(SetAppIdEnvironment). }
    FSetAppIdEnvironment: Boolean;
    { Backing field of @link(LibraryPath). }
    FLibraryPath: string;
    { Backing field of @link(InitMode). }
    FInitMode: TSteamInitMode;
    { Backing field of @link(Pipe). }
    FPipe: HSteamPipe;
    { Backing field of @link(User). }
    FUser: HSteamUser;
    { Backing field of @link(LastInitResult). }
    FLastInitResult: ESteamAPIInitResult;
    { Backing field of @link(LastError). }
    FLastError: string;
    { Backing field of @link(Dispatcher). }
    FDispatcher: TSteamCallbackDispatcher;
    { Backing field of @link(ServerDispatcher). }
    FServerDispatcher: TSteamCallbackDispatcher;
    { @true while SteamAPI (the client) is initialised. }
    FClientUp: Boolean;
    { @true while the game server is initialised. }
    FServerUp: Boolean;
    { SteamAPI_ManualDispatch_Init was called in this session (once, for the
      first of client / server; reset when both are down). }
    FManualDispatch: Boolean;
    { Backing field of @link(ServerPipe). }
    FServerPipe: HSteamPipe;
    { Backing field of @link(ServerUser). }
    FServerUser: HSteamUser;
    { Backing field of @link(GameServerIP). }
    FServerIP: UInt32;
    { Backing field of @link(GameServerGamePort). }
    FServerGamePort: Word;
    { Backing field of @link(GameServerQueryPort). }
    FServerQueryPort: Word;
    { Backing field of @link(GameServerMode). }
    FServerMode: EServerMode;
    { Backing field of @link(GameServerVersion). }
    FServerVersion: string;
    { @true when @link(StopGameServer) was called from a handler. }
    FServerStopPending: Boolean;
    { @true while a failed @link(StartGameServer) is rolled back: no
      OnGameServerStopped / OnShutdown for what never started. }
    FRollingBack: Boolean;
    { Backing field of @link(OnGameServerStarted). }
    FOnGameServerStarted: TNotifyEvent;
    { Backing field of @link(OnGameServerStopped). }
    FOnGameServerStopped: TNotifyEvent;
    { Backing field of @link(Versions). }
    FVersions: TSteamInterfaceVersions;
    { Backing field of @link(Client). }
    FClient: TSteamClientIntf;
    { Active plug-ins, in initialisation order (owned). }
    FPlugins: TObjectList<TSteamPlugin>;
    { Classes added with @link(IncludePlugin). }
    FIncluded: TList<TSteamPluginClass>;
    { Classes removed with @link(ExcludePlugin). }
    FExcluded: TList<TSteamPluginClass>;
    { Backing field of @link(UseRegisteredPlugins). }
    FUseRegisteredPlugins: Boolean;
    { Backing field of @link(InstallWarningHook). }
    FInstallWarningHook: Boolean;
    { @true when @link(Shutdown) was called during a pump. }
    FShutdownPending: Boolean;
    { Backing field of @link(ShutdownOnSteamExit). }
    FShutdownOnSteamExit: Boolean;
    { @true once SteamShutdown_t has been handled in this session (Steam may
      send it twice); reset by @link(Initialize). }
    FSteamExitSeen: Boolean;
    { Subscription to SteamShutdown_t. }
    FShutdownSub: TSteamSubscription;
    { Guards @link(FWarnings) (the warning hook may run on any thread). }
    FWarningLock: SyncObjs.TCriticalSection;
    { Warnings queued by the hook; Objects[] holds the severity. }
    FWarnings: TStringList;
    { Backing field of @link(UpdateMode). }
    FUpdateMode: TSteamUpdateMode;
    { Backing field of @link(Delivery). }
    FDelivery: TSteamDelivery;
    { Backing field of @link(PumpInterval). }
    FPumpInterval: Integer;
    { The worker thread (a TSteamPumpThread) while @link(Threaded); @nil otherwise. }
    FPumpThread: TThread;
    { A worker that ended itself (Shutdown from an sdPumpThread handler) and
      still has to be freed by another thread. Guarded by @link(FThreadLock). }
    FDeadThread: TThread;
    { Guards @link(FMainQueued), @link(FDeadThread) and @link(FThreadErrors). }
    FThreadLock: SyncObjs.TCriticalSection;
    { @true while a main-thread delivery is queued with TThread.Queue. }
    FMainQueued: Boolean;
    { @true while @link(StopPumpThread) waits for the worker: TThread.WaitFor
      runs queued main-thread work meanwhile, and @link(RunCallbacks) must not
      start reading Steam's queue while the worker may still be reading it. }
    FWorkerStopping: Boolean;
    { Set by the worker when it read SteamShutdown_t and ShutdownOnSteamExit
      is on: it stops calling into Steam until shutdown. }
    FThreadSteamExit: Boolean;
    { Errors caught on the worker thread, reported by the next delivery. }
    FThreadErrors: TStringList;
    { Serialises @link(DoShutdown): with sdPumpThread delivery the worker and
      the main thread may both shut down at once; the second finds nothing
      to do. Never held while waiting for the worker. }
    FShutdownLock: SyncObjs.TCriticalSection;
    { Backing field of @link(OnLog). }
    FOnLog: TSteamLogEvent;
    { Backing field of @link(OnWarning). }
    FOnWarning: TSteamWarningEvent;
    { Backing field of @link(OnSteamShutdown). }
    FOnSteamShutdown: TNotifyEvent;
    { Backing field of @link(OnInitialized). }
    FOnInitialized: TNotifyEvent;
    { Backing field of @link(OnShutdown). }
    FOnShutdown: TNotifyEvent;
    { Read accessor of @link(IsRunning). }
    function GetIsRunning: Boolean;
    { Read accessor of @link(PluginCount). }
    function GetPluginCount: Integer;
    { Read accessor of @link(Plugins). }
    function GetPlugin(AIndex: Integer): TSteamPlugin;
    { Plug-in classes to create, dependencies first. }
    function BuildPluginOrder: TSteamPluginClassArray;
    { Runs the SteamAPI initialisation selected by @link(InitMode). }
    function InitializeSteamAPI: Boolean;
    { Creates and initialises the client plug-ins (AGameServer @false) or the
      game-server ones. @returns(@false if a required one failed.) }
    function InitializePlugins(AGameServer: Boolean): Boolean;
    { Finalises and frees the client (AGameServer @false) or game-server
      plug-ins, in reverse order. }
    procedure FinalizePlugins(AGameServer: Boolean);
    { The NUL-separated, double-NUL terminated interface list Steam checks
      at initialisation (client or game-server plug-ins). }
    function CheckVersionList(AGameServer: Boolean): AnsiString;
    { Runs SteamInternal_GameServer_Init(_V2) with the GameServer*
      settings. @returns(@false on failure; see @link(LastError).) }
    function InitializeGameServerAPI: Boolean;
    { Creates the ISteamClient wrapper (and the warning hook) if there is none. }
    procedure CreateClientIntf;
    { The client part of @link(DoShutdownLocked): plug-ins, SteamAPI_Shutdown. }
    procedure ShutdownClientLocked;
    { Removes the warning hook and frees the ISteamClient wrapper; called
      BEFORE the last SteamAPI_Shutdown / SteamGameServer_Shutdown (after it
      steamclient is unloaded and ISteamClient calls crash). }
    procedure ReleaseClientIntf;
    { The game-server part of the shutdown: plug-ins, SteamGameServer_Shutdown,
      @link(OnGameServerStopped). Caller holds @link(FShutdownLock). }
    procedure StopGameServerLocked;
    { @true while a handler of either dispatcher runs on this thread. }
    function InAnyHandler: Boolean;
    { Pumps (reads and delivers) both pipes that are up. }
    procedure PumpAll;
    { Delivers what the worker queued for both dispatchers. }
    procedure DeliverAllQueued;
    { Finalises and frees the live plug-ins of exactly AClass. }
    procedure FinalizePluginsOfClass(AClass: TSteamPluginClass);
    { Exports SteamAppId / SteamGameId when @link(SetAppIdEnvironment) is set. }
    procedure ApplyAppIdEnvironment;
    { Performs the shutdown (never during a pump): stops the worker, then
      runs @link(DoShutdownLocked) under @link(FShutdownLock). }
    procedure DoShutdown;
    { The shutdown itself; caller holds @link(FShutdownLock) and Steam runs. }
    procedure DoShutdownLocked;
    { Records @link(LastError) and logs it. }
    procedure SetFailure(const AMessage: string);
    { Handler of SteamShutdown_t; raises @link(OnSteamShutdown). }
    procedure HandleSteamShutdown(const AData: TSteamCallbackData);
    { Receives @link(TSteamDynLib) warnings and logs them. }
    procedure LibraryWarning(Sender: TObject; const AMessage: string);
    { Delivers queued warnings to @link(OnWarning) on the pump thread. }
    procedure DrainWarnings;
    { Logs the errors the worker thread caught since the last call. }
    procedure DrainThreadErrors;
    { Read accessor of @link(Threaded). }
    function GetThreaded: Boolean;
    { Write accessor of @link(UpdateMode). }
    procedure SetUpdateModeValue(const AValue: TSteamUpdateMode);
    { Write accessor of @link(Delivery). }
    procedure SetDelivery(const AValue: TSteamDelivery);
    { Write accessor of @link(PumpInterval). }
    procedure SetPumpInterval(const AValue: Integer);
    { Starts the worker if running in @link(sumThread) mode and none runs.
      A failure (FPC without cthreads, ...) is logged and leaves the core
      pumping from RunCallbacks. }
    procedure StartPumpThread;
    { Stops the worker and waits for it; from the worker itself only asks it
      to end (another thread frees it later). Removes a queued main-thread
      delivery. Queued copies stay (see @link(DoShutdown)). }
    procedure StopPumpThread;
    { Frees a worker that ended itself, unless called on that worker. }
    procedure ReapDeadThread;
    { Starts the worker for the (new) mode while running, or delivers what an
      old worker left queued. The old worker is already stopped. }
    procedure ApplyUpdateMode;
    { One worker iteration (runs on the worker thread). }
    procedure ThreadTick;
    { Queues @link(MainThreadDeliver) with TThread.Queue unless one is queued. }
    procedure ScheduleMainDelivery;
    { Runs on the main thread (TThread.Queue): delivers the queued callbacks. }
    procedure MainThreadDeliver;
    { Records an error caught on the worker thread. }
    procedure AddThreadError(const AMessage: string);
    { SteamAPI_ReleaseCurrentThreadMemory, only while Steam runs - checked
      under @link(FShutdownLock), so never after another thread's
      SteamAPI_Shutdown. }
    procedure ReleaseThreadMemoryIfRunning;
  public
    { Use @link(Instance) instead. Raises if an instance already exists. }
    constructor Create;
    { Releases everything this object owns. }
    destructor Destroy; override;

    { The singleton, created on first use and freed at program exit.
      @raises(ESteamworksError if called after unit finalisation.) }
    class function Instance: TSteamworks;
    { @true if the singleton exists (safe during finalisation). }
    class function HasInstance: Boolean;

    { Registers a plug-in class - call from the plug-in unit's initialization. }
    class procedure RegisterPlugin(AClass: TSteamPluginClass);
    { Unregisters a plug-in class, finalising a live instance first. Call
      from the plug-in unit's finalization (essential for runtime packages). }
    class procedure UnregisterPlugin(AClass: TSteamPluginClass);
    { All registered plug-in classes. }
    class function RegisteredPlugins: TSteamPluginClassArray;

    { Use AClass even when @link(UseRegisteredPlugins) is @false. Call before
      @link(Initialize). }
    procedure IncludePlugin(AClass: TSteamPluginClass);
    { Skip a registered plug-in (unless another plug-in depends on it). Call
      before @link(Initialize). }
    procedure ExcludePlugin(AClass: TSteamPluginClass);

    { Loads the redistributable and scans its interface versions.
      @link(Initialize) does this automatically.
      @returns(@false on failure; see @link(LastError).) }
    function LoadLibrary: Boolean;

    { Asks Steam whether the game must be relaunched through the Steam client.
      Call before @link(Initialize); if it returns @true, exit immediately.
      @param(AAppID  0 = use @link(AppID).)
      @returns(@true if Steam is relaunching the game.) }
    function RestartAppIfNecessary(AAppID: AppId_t = 0): Boolean;

    { Initialises SteamAPI, manual dispatch, ISteamClient and all plug-ins.
      @returns(@true on success; otherwise see @link(LastInitResult) and
        @link(LastError).) }
    function Initialize: Boolean;

    { Finalises plug-ins and shuts SteamAPI down - and the game server if one
      runs. Safe at any time, including from a callback handler (it then
      completes after the current callback). }
    procedure Shutdown;

    { Starts a game server with @link(GameServerIP), @link(GameServerGamePort),
      @link(GameServerQueryPort), @link(GameServerMode) and
      @link(GameServerVersion): SteamGameServer_Init, then every
      @link(TSteamPlugin.IsGameServer) plug-in. Works with the client
      running (a listen server) or without it (a dedicated server - no Steam
      client needed; set @link(AppID) / @link(SetAppIdEnvironment) or ship
      steam_appid.txt). Then log on with the GameServer plug-in
      (LogOnAnonymous or LogOn) - Steam answers with SteamServersConnected_t
      on the SERVER's dispatcher. Call it from the main / game thread.
      @returns(@true on success (or when already running); otherwise see
        @link(LastInitResult) and @link(LastError).) }
    function StartGameServer: Boolean;

    { Finalises the game-server plug-ins and shuts the game server down
      (SteamGameServer_Shutdown); the client keeps running. Without a client
      this is the same as @link(Shutdown). Safe from a handler (completes
      after the current callback). }
    procedure StopGameServer;

    { The dispatcher of one side: @link(ServerDispatcher) when AGameServer,
      else @link(Dispatcher). }
    function DispatcherFor(AGameServer: Boolean): TSteamCallbackDispatcher;

    { Delivers pending callbacks and queued warnings on the calling thread.
      @unorderedList(
        @item(No worker running (@link(sumTimer), @link(sumManual), or a
          worker that could not start): drains Steam's queue and delivers
          everything. Call it regularly - every frame or every 15-50 ms -
          and always from the SAME thread.)
        @item(@link(sumThread) with @link(sdOnUpdate): delivers what the
          worker has read. Call it once per frame from your game thread.)
        @item(@link(sumThread) with @link(sdMainThread): delivers now when
          called on the main thread (otherwise does nothing - the queued
          main-thread delivery will).)
        @item(@link(sumThread) with @link(sdPumpThread): nothing to do.)
      ) }
    procedure RunCallbacks;

    { Same as @link(RunCallbacks): the name a game loop expects
      (@code(Steam.Update) once per frame). }
    procedure Update;

    { Sets @link(UpdateMode), @link(Delivery) and (when AIntervalMs >= 0)
      @link(PumpInterval) in one call; applies at once if Steam is running.
      Call it from the main / game thread, never from a handler.
      @longCode(#
      Steam.SetUpdateMode(sumThread, sdOnUpdate);   // engine: call Steam.Update per frame
      #) }
    procedure SetUpdateMode(AMode: TSteamUpdateMode; ADelivery: TSteamDelivery;
      AIntervalMs: Integer = -1);

    { Number of callbacks the worker has read but not yet delivered. }
    function QueuedCallbackCount: Integer;

    { @true if a Steam client is running. Loads the library if needed. }
    function IsSteamRunning: Boolean;

    { Frees Steam's per-thread memory. Call from worker threads that used
      Steam, before they exit. }
    procedure ReleaseCurrentThreadMemory;

    { Windows only: comment included in Steam's minidumps. }
    procedure SetMiniDumpComment(const AComment: string);

    { Version to use for an interface: AFallbackVersion's family looked up in
      the loaded library (see @link(TSteamInterfaceVersions.Resolve)). }
    function ResolveVersion(const AFallbackVersion: string): string;

    { Pointer to a user-level interface (requires @link(IsRunning)).
      Tried in order: the flat accessor @code(SteamAPI_<AAccessorBase>_v<NNN>),
      SteamInternal_FindOrCreateUserInterface, ISteamClient::GetISteamGenericInterface.
      @param(AFallbackVersion  SDK version string, e.g. STEAMFRIENDS_INTERFACE_VERSION.)
      @param(AAccessorBase  Accessor name part, e.g. @code('SteamFriends'); optional.)
      @returns(@nil if the interface is unavailable.) }
    function AcquireUserInterface(const AFallbackVersion: string; const AAccessorBase: string = ''): Pointer;

    { Game-server counterpart of @link(AcquireUserInterface) (requires
      @link(IsGameServerRunning)): the flat accessor
      @code(SteamAPI_<AAccessorBase>_v<NNN>) (e.g. @code('SteamGameServerUtils')),
      then SteamInternal_FindOrCreateGameServerInterface with the SERVER's
      user, then ISteamClient::GetISteamGenericInterface. }
    function AcquireGameServerInterface(const AFallbackVersion: string; const AAccessorBase: string = ''): Pointer;

    { Address of any export of the loaded library, or @nil. }
    function GetProc(const AExportName: string): Pointer;

    { The live plug-in of class AClass (or a descendant), or @nil.
      @longCode(#
      Utils := TSteamUtilsPlugin(Steam.FindPlugin(TSteamUtilsPlugin));
      #) }
    function FindPlugin(AClass: TSteamPluginClass): TSteamPlugin;
    {$ifndef FPC}
    { Typed form of @link(FindPlugin): @code(Steam.Plugin<TSteamUtilsPlugin>) (Delphi only). }
    function Plugin<T: TSteamPlugin>: T;
    {$endif}
    { @true if a plug-in of AClass is active. }
    function HasPlugin(AClass: TSteamPluginClass): Boolean;
    { Number of active plug-ins. }
    property PluginCount: Integer read GetPluginCount;
    { Active plug-ins in initialisation order. }
    property Plugins[AIndex: Integer]: TSteamPlugin read GetPlugin;

    { Raises @link(OnLog). }
    procedure Log(ALevel: TSteamLogLevel; const AMessage: string);

    { Your Steam AppID (used by @link(RestartAppIfNecessary) and
      @link(SetAppIdEnvironment)). }
    property AppID: AppId_t read FAppID write FAppID;
    { Export SteamAppId / SteamGameId before loading Steam, so development
      builds run without steam_appid.txt. Do not use in release builds. }
    property SetAppIdEnvironment: Boolean read FSetAppIdEnvironment write FSetAppIdEnvironment;
    { Explicit redistributable file; '' = default name and search. }
    property LibraryPath: string read FLibraryPath write FLibraryPath;
    { Initialisation entry point; default @link(simAuto). }
    property InitMode: TSteamInitMode read FInitMode write FInitMode;
    { Create every plug-in whose unit is linked (default @true). }
    property UseRegisteredPlugins: Boolean read FUseRegisteredPlugins write FUseRegisteredPlugins;
    { Route ISteamClient debug output to @link(OnWarning) (default @true). }
    property InstallWarningHook: Boolean read FInstallWarningHook write FInstallWarningHook;
    { Shut SteamAPI down when the Steam client exits (SteamShutdown_t, 704),
      right after @link(OnSteamShutdown) returns (default @true). Observed on
      Linux (SDK 1.65): Steam sends 704 twice, does not end the process, and
      about 1.5 s later its pipe is gone - every later call, SteamAPI_Shutdown
      included, then asserts inside steamclient and writes minidumps. Shutting
      down on the first 704 avoids that. Set @false only to keep using Steam
      until the process ends. }
    property ShutdownOnSteamExit: Boolean read FShutdownOnSteamExit write FShutdownOnSteamExit;

    { Who drains Steam's callback queue (default @link(sumTimer), which for
      the core means "someone calls RunCallbacks"). Changing it while Steam
      runs restarts the worker as needed. }
    property UpdateMode: TSteamUpdateMode read FUpdateMode write SetUpdateModeValue;
    { Where handlers run in @link(sumThread) mode (default @link(sdMainThread)). }
    property Delivery: TSteamDelivery read FDelivery write SetDelivery;
    { Worker period in ms (default 33, minimum 1). The worker also wakes
      early when shutting down. }
    property PumpInterval: Integer read FPumpInterval write SetPumpInterval;
    { @true while the worker thread runs. @false in @link(sumThread) mode
      means it could not start (see the log) and RunCallbacks pumps instead. }
    property Threaded: Boolean read GetThreaded;

    { Current lifecycle state (@link(swsRunning) while the client and / or a
      game server runs). }
    property State: TSteamworksState read FState;
    { @true while SteamAPI (the CLIENT) is initialised. A dedicated game
      server alone leaves it @false - see @link(IsGameServerRunning). }
    property IsRunning: Boolean read GetIsRunning;
    { @true while a game server runs (@link(StartGameServer)). }
    property IsGameServerRunning: Boolean read FServerUp;
    { The roles running now. }
    function Roles: TSteamRoles;
    { Global pipe handle (0 when not running). }
    property Pipe: HSteamPipe read FPipe;
    { Global user handle (0 when not running). }
    property User: HSteamUser read FUser;
    { Result of the last initialisation attempt. }
    property LastInitResult: ESteamAPIInitResult read FLastInitResult;
    { Text of the last failure (Steam's own diagnostic when available). }
    property LastError: string read FLastError;
    { Callback dispatcher of the client (SteamAPI's pipe). }
    property Dispatcher: TSteamCallbackDispatcher read FDispatcher;
    { Callback dispatcher of the game server (its own pipe: callback ids such
      as 101-103 or 143 arrive on both pipes, so the two are kept apart). }
    property ServerDispatcher: TSteamCallbackDispatcher read FServerDispatcher;
    { Game-server pipe handle (0 when no server runs). }
    property ServerPipe: HSteamPipe read FServerPipe;
    { Game-server user handle (0 when no server runs). }
    property ServerUser: HSteamUser read FServerUser;
    { IP address the game server binds to, host order (0 = any, default). }
    property GameServerIP: UInt32 read FServerIP write FServerIP;
    { UDP port of the game's own traffic (default 27015). }
    property GameServerGamePort: Word read FServerGamePort write FServerGamePort;
    { UDP port Steam answers server-browser queries on (default 27016;
      $FFFF = STEAMGAMESERVER_QUERY_PORT_SHARED: the game forwards them). }
    property GameServerQueryPort: Word read FServerQueryPort write FServerQueryPort;
    { Authentication / VAC / listing mode (default
      eServerModeAuthenticationAndSecure). }
    property GameServerMode: EServerMode read FServerMode write FServerMode;
    { Version string of the server ('1.0.0.0' by default): Steam compares it
      to the one on the partner site and reports outdated servers. }
    property GameServerVersion: string read FServerVersion write FServerVersion;
    { Interface versions detected in the loaded library. }
    property Versions: TSteamInterfaceVersions read FVersions;
    { ISteamClient wrapper; @nil until running or if it could not be created. }
    property Client: TSteamClientIntf read FClient;

    { Diagnostic messages. }
    property OnLog: TSteamLogEvent read FOnLog write FOnLog;
    { Steam client debug output (launch with -debug_steamapi). }
    property OnWarning: TSteamWarningEvent read FOnWarning write FOnWarning;
    { SteamShutdown_t (704): the Steam client is exiting - save and quit.
      Raised once per session even if Steam sends 704 again. With
      @link(ShutdownOnSteamExit) SteamAPI shuts down when the handler returns
      (Steam calls such as Cloud saves still work inside the handler). }
    property OnSteamShutdown: TNotifyEvent read FOnSteamShutdown write FOnSteamShutdown;
    { After a successful @link(Initialize). }
    property OnInitialized: TNotifyEvent read FOnInitialized write FOnInitialized;
    { After SteamAPI has been shut down. }
    property OnShutdown: TNotifyEvent read FOnShutdown write FOnShutdown;
    { After a successful @link(StartGameServer) (its plug-ins are up). }
    property OnGameServerStarted: TNotifyEvent read FOnGameServerStarted write FOnGameServerStarted;
    { After the game server has been shut down. }
    property OnGameServerStopped: TNotifyEvent read FOnGameServerStopped write FOnGameServerStopped;
  end;

{ Shorthand for @link(TSteamworks.Instance). }
function Steam: TSteamworks;

implementation

{$if defined(MSWINDOWS)}
uses
  Windows{$ifndef FPC}, TypInfo{$endif};
{$elseif not defined(FPC)}
uses
  Posix.Stdlib, TypInfo;
{$else}
function setenv(name, value: PAnsiChar; overwrite: Integer): Integer; cdecl; external 'c';
{$endif}

var
  GInstance: TSteamworks = nil;
  GRegistry: TList<TSteamPluginClass> = nil;
  GFinalized: Boolean = False;

function Steam: TSteamworks;
begin
  Result := TSteamworks.Instance;
end;

{ Name of a TSteamDelivery value, for log lines. }
function DeliveryName(ADelivery: TSteamDelivery): string;
begin
  case ADelivery of
    sdMainThread: Result := 'sdMainThread';
    sdOnUpdate:   Result := 'sdOnUpdate';
  else
    Result := 'sdPumpThread';
  end;
end;

{ Steam may call this from any thread. Queue the text; RunCallbacks delivers
  it on the pump thread. Never call into user code from here. }
procedure SteamWarningHook(nSeverity: Integer; pchDebugText: PAnsiChar); cdecl;
var
  Text: string;
begin
  if (GInstance = nil) or (GInstance.FWarnings = nil) then
    Exit;
  if pchDebugText <> nil then
    // Steam ends its text with a line break (seen on Linux, SDK 1.65):
    // strip it so each warning is one log line.
    Text := TrimRight(string(UTF8String(pchDebugText)))
  else
    Text := '';
  GInstance.FWarningLock.Enter;
  try
    GInstance.FWarnings.AddObject(Text, TObject(NativeInt(nSeverity)));
  finally
    GInstance.FWarningLock.Leave;
  end;
end;

type
  { The core's worker (@link(sumThread)): calls TSteamworks.ThreadTick every
    PumpInterval ms until terminated. Runs no user code itself except in
    @link(sdPumpThread) mode, where the handlers run inside ThreadTick. }
  TSteamPumpThread = class(TThread)
  private
    { The core that owns this thread. }
    FOwner: TSteamworks;
    { Auto-reset event: wakes the thread early (shutdown, interval change). }
    FWake: SyncObjs.TEvent;
    { Ticks between SteamAPI_ReleaseCurrentThreadMemory calls (about 1 s). }
    FReleaseEvery: Integer;
  protected
    { The pump loop. }
    procedure Execute; override;
  public
    { Creates and starts the thread for AOwner. }
    constructor Create(AOwner: TSteamworks);
    { Ends the loop, waits for it, frees the event. }
    destructor Destroy; override;
    { Wakes the thread before its interval elapses. }
    procedure Wake;
  end;

constructor TSteamPumpThread.Create(AOwner: TSteamworks);
begin
  FOwner := AOwner;
  FWake := SyncObjs.TEvent.Create(nil, False, False, '');
  FReleaseEvery := 1000 div AOwner.FPumpInterval;
  if FReleaseEvery < 1 then
    FReleaseEvery := 1;
  FreeOnTerminate := False;
  inherited Create(False);
end;

destructor TSteamPumpThread.Destroy;
begin
  Terminate;
  if FWake <> nil then
    FWake.SetEvent;
  inherited Destroy;   // waits for Execute to end
  FreeAndNil(FWake);
end;

procedure TSteamPumpThread.Wake;
begin
  if FWake <> nil then
    FWake.SetEvent;
end;

procedure TSteamPumpThread.Execute;
var
  Ticks: Integer;
begin
  {$ifndef FPC}
  NameThreadForDebugging('Steamworks pump');
  {$endif}
  Ticks := 0;
  while not Terminated do
  begin
    FOwner.ThreadTick;
    Inc(Ticks);
    // Valve: threads that call Steam should release its per-thread memory
    // now and then (SteamAPI_RunCallbacks does it for the main thread)
    if Ticks >= FReleaseEvery then
    begin
      Ticks := 0;
      FOwner.ReleaseThreadMemoryIfRunning;
    end;
    if not Terminated then
      FWake.WaitFor(Cardinal(FOwner.FPumpInterval));
  end;
  FOwner.ReleaseThreadMemoryIfRunning;
end;

{ TSteamPlugin }

constructor TSteamPlugin.Create;
begin
  inherited Create;
end;

destructor TSteamPlugin.Destroy;
begin
  if FActive then
    Finalize;
  inherited;
end;

class function TSteamPlugin.PluginName: string;
begin
  Result := ClassName;
end;

class function TSteamPlugin.Dependencies: TSteamPluginClassArray;
begin
  Result := nil;
end;

class function TSteamPlugin.IsRequired: Boolean;
begin
  Result := False;
end;

class function TSteamPlugin.InterfaceVersions(AVersions: TSteamInterfaceVersions): TSteamStringArray;
begin
  Result := nil;
end;

class function TSteamPlugin.IsGameServer: Boolean;
begin
  Result := False;
end;

function TSteamPlugin.Dispatcher: TSteamCallbackDispatcher;
begin
  if FSteam = nil then
    Result := nil
  else
    Result := FSteam.DispatcherFor(IsGameServer);
end;

function TSteamPlugin.Initialize(ASteam: TSteamworks): Boolean;
begin
  FSteam := ASteam;
  try
    Result := DoInitialize;
  except
    on E: Exception do
    begin
      LogFmt(sllError, 'Exception during initialisation: %s', [E.Message]);
      Result := False;
    end;
  end;
  FActive := Result;
  if not Result then
    Finalize; // drop anything partially registered
end;

procedure TSteamPlugin.Finalize;
var
  D: TSteamCallbackDispatcher;
begin
  try
    if FActive then
      DoFinalize;
  except
    on E: Exception do
      LogFmt(sllError, 'Exception during finalisation: %s', [E.Message]);
  end;
  D := Dispatcher;
  if D <> nil then
    D.RemoveOwner(Self);
  FActive := False;
end;

procedure TSteamPlugin.DoFinalize;
begin
end;

function TSteamPlugin.Bind(var AProc; const AExportName: string; ARequired: Boolean): Boolean;
begin
  Result := TSteamLib.Bind(AProc, AExportName, False);
  if not Result then
  begin
    if ARequired then
      LogFmt(sllError, 'Required export %s not found', [AExportName])
    else
      LogFmt(sllDebug, 'Optional export %s not found', [AExportName]);
    Result := not ARequired;
  end;
end;

function TSteamPlugin.AcquireUserInterface(const AFallbackVersion, AAccessorBase: string): Pointer;
var
  Base: string;
begin
  if IsGameServer then
  begin
    // The server's copy of an interface: SteamAPI_SteamUtils_v011 ->
    // SteamAPI_SteamGameServerUtils_v011 (ISteamGameServer itself is
    // already called SteamGameServer...)
    Base := AAccessorBase;
    if (Base <> '') and (Copy(Base, 1, 15) <> 'SteamGameServer') and (Copy(Base, 1, 5) = 'Steam') then
      Base := 'SteamGameServer' + Copy(Base, 6, MaxInt);
    Result := FSteam.AcquireGameServerInterface(AFallbackVersion, Base);
  end
  else
    Result := FSteam.AcquireUserInterface(AFallbackVersion, AAccessorBase);
  if Result = nil then
    LogFmt(sllError, 'Could not acquire interface %s', [FSteam.ResolveVersion(AFallbackVersion)]);
end;

function TSteamPlugin.Subscribe(ACallbackID: Integer; AHandler: TSteamCallbackEvent;
  AIncludeCallResults: Boolean): TSteamSubscription;
begin
  Result := Dispatcher.Subscribe(ACallbackID, AHandler, AIncludeCallResults);
end;

function TSteamPlugin.AwaitCallResult(ACall: SteamAPICall_t; AExpectedCallbackID: Integer;
  AHandler: TSteamCallResultEvent): Boolean;
begin
  Result := Dispatcher.AwaitCallResult(ACall, AExpectedCallbackID, AHandler);
end;

procedure TSteamPlugin.Unsubscribe(var AToken: TSteamSubscription);
begin
  Dispatcher.Unsubscribe(AToken);
end;

procedure TSteamPlugin.Log(ALevel: TSteamLogLevel; const AMessage: string);
begin
  if Assigned(FSteam) then
    FSteam.Log(ALevel, '[' + PluginName + '] ' + AMessage);
end;

procedure TSteamPlugin.LogFmt(ALevel: TSteamLogLevel; const AFmt: string; const AArgs: array of const);
begin
  Log(ALevel, Format(AFmt, AArgs));
end;

{ TSteamworks }

class function TSteamworks.Instance: TSteamworks;
begin
  if GInstance = nil then
  begin
    if GFinalized then
      raise ESteamworksError.Create('TSteamworks used after finalization');
    GInstance := TSteamworks.Create;
  end;
  Result := GInstance;
end;

class function TSteamworks.HasInstance: Boolean;
begin
  Result := GInstance <> nil;
end;

class procedure TSteamworks.RegisterPlugin(AClass: TSteamPluginClass);
begin
  if GRegistry = nil then
    GRegistry := TList<TSteamPluginClass>.Create;
  if (AClass <> nil) and not GRegistry.Contains(AClass) then
    GRegistry.Add(AClass);
end;

class procedure TSteamworks.UnregisterPlugin(AClass: TSteamPluginClass);
begin
  if GInstance <> nil then
    GInstance.FinalizePluginsOfClass(AClass);
  if GRegistry <> nil then
    GRegistry.Remove(AClass);
end;

class function TSteamworks.RegisteredPlugins: TSteamPluginClassArray;
var
  I: Integer;
begin
  if GRegistry = nil then
    Result := nil
  else
  begin
    SetLength(Result, GRegistry.Count);
    for I := 0 to GRegistry.Count - 1 do
      Result[I] := GRegistry[I];
  end;
end;

constructor TSteamworks.Create;
begin
  if GInstance <> nil then
    raise ESteamworksError.Create('TSteamworks is a singleton - use TSteamworks.Instance');
  inherited Create;
  FDispatcher := TSteamCallbackDispatcher.Create;
  FServerDispatcher := TSteamCallbackDispatcher.Create;
  FVersions := TSteamInterfaceVersions.Create;
  FPlugins := TObjectList<TSteamPlugin>.Create(True);
  FIncluded := TList<TSteamPluginClass>.Create;
  FExcluded := TList<TSteamPluginClass>.Create;
  // Qualified: under FPC the Windows unit (used below on Windows) declares
  // TCriticalSection = TRTLCriticalSection, a record, which hides SyncObjs'.
  FWarningLock := SyncObjs.TCriticalSection.Create;
  FWarnings := TStringList.Create;
  FThreadLock := SyncObjs.TCriticalSection.Create;
  FThreadErrors := TStringList.Create;
  FShutdownLock := SyncObjs.TCriticalSection.Create;
  FUpdateMode := sumTimer;
  FDelivery := sdMainThread;
  FPumpInterval := 33;
  FUseRegisteredPlugins := True;
  FInstallWarningHook := True;
  FShutdownOnSteamExit := True;
  FInitMode := simAuto;
  FServerGamePort := 27015;
  FServerQueryPort := 27016;
  FServerMode := eServerModeAuthenticationAndSecure;
  FServerVersion := '1.0.0.0';
  FState := swsIdle;
  FLastInitResult := k_ESteamAPIInitResult_FailedGeneric;
  FConstructed := True;
end;

destructor TSteamworks.Destroy;
begin
  if not FConstructed then
  begin
    // Create raised (second instance): touch nothing shared
    inherited;
    Exit;
  end;
  // Events may point at objects that are already gone during finalisation
  FOnLog := nil;
  FOnWarning := nil;
  FOnSteamShutdown := nil;
  FOnInitialized := nil;
  FOnShutdown := nil;
  FOnGameServerStarted := nil;
  FOnGameServerStopped := nil;
  if FState = swsRunning then
    DoShutdown;
  StopPumpThread;   // normally done by DoShutdown already
  ReapDeadThread;
  if TSteamLib.IsLoaded then
    TSteamLib.Unload;
  FreeAndNil(FClient);
  FreeAndNil(FWarnings);
  FreeAndNil(FWarningLock);
  FreeAndNil(FThreadErrors);
  FreeAndNil(FThreadLock);
  FreeAndNil(FShutdownLock);
  FExcluded.Free;
  FIncluded.Free;
  FPlugins.Free;
  FVersions.Free;
  FDispatcher.Free;
  FServerDispatcher.Free;
  if GInstance = Self then
    GInstance := nil;
  inherited;
end;

procedure TSteamworks.Log(ALevel: TSteamLogLevel; const AMessage: string);
begin
  if Assigned(FOnLog) then
    FOnLog(Self, ALevel, AMessage);
end;

procedure TSteamworks.SetFailure(const AMessage: string);
begin
  FLastError := AMessage;
  Log(sllError, AMessage);
end;

procedure TSteamworks.LibraryWarning(Sender: TObject; const AMessage: string);
begin
  Log(sllWarning, AMessage);
end;

function TSteamworks.GetIsRunning: Boolean;
begin
  Result := FClientUp;
end;

function TSteamworks.Roles: TSteamRoles;
begin
  Result := [];
  if FClientUp then
    Include(Result, srClient);
  if FServerUp then
    Include(Result, srGameServer);
end;

function TSteamworks.DispatcherFor(AGameServer: Boolean): TSteamCallbackDispatcher;
begin
  if AGameServer then
    Result := FServerDispatcher
  else
    Result := FDispatcher;
end;

function TSteamworks.InAnyHandler: Boolean;
begin
  Result := FDispatcher.InHandlerOnCurrentThread or FServerDispatcher.InHandlerOnCurrentThread;
end;

procedure TSteamworks.PumpAll;
begin
  if FClientUp then
    FDispatcher.Pump(FPipe);
  // Not after a client handler asked for a shutdown (it runs next)
  if FServerUp and not FShutdownPending and not FServerStopPending then
    FServerDispatcher.Pump(FServerPipe);
end;

procedure TSteamworks.DeliverAllQueued;
begin
  FDispatcher.DeliverQueued;
  if not FShutdownPending and not FServerStopPending then
    FServerDispatcher.DeliverQueued;
end;

function TSteamworks.GetPluginCount: Integer;
begin
  Result := FPlugins.Count;
end;

function TSteamworks.GetPlugin(AIndex: Integer): TSteamPlugin;
begin
  Result := FPlugins[AIndex];
end;

procedure TSteamworks.IncludePlugin(AClass: TSteamPluginClass);
begin
  if (AClass <> nil) and not FIncluded.Contains(AClass) then
    FIncluded.Add(AClass);
  FExcluded.Remove(AClass);
end;

procedure TSteamworks.ExcludePlugin(AClass: TSteamPluginClass);
begin
  if (AClass <> nil) and not FExcluded.Contains(AClass) then
    FExcluded.Add(AClass);
  FIncluded.Remove(AClass);
end;

procedure TSteamworks.ApplyAppIdEnvironment;
var
  S: string;
begin
  if (not FSetAppIdEnvironment) or (FAppID = 0) then
    Exit;
  S := IntToStr(FAppID);
  {$if defined(MSWINDOWS)}
  SetEnvironmentVariable('SteamAppId', PChar(S));
  SetEnvironmentVariable('SteamGameId', PChar(S));
  {$elseif not defined(FPC)}
  setenv(MarshaledAString(UTF8String('SteamAppId')), MarshaledAString(UTF8String(S)), 1);
  setenv(MarshaledAString(UTF8String('SteamGameId')), MarshaledAString(UTF8String(S)), 1);
  {$else}
  setenv(PAnsiChar('SteamAppId'), PAnsiChar(AnsiString(S)), 1);
  setenv(PAnsiChar('SteamGameId'), PAnsiChar(AnsiString(S)), 1);
  {$endif}
  Log(sllDebug, 'SteamAppId environment set to ' + S);
end;

function TSteamworks.LoadLibrary: Boolean;
begin
  if TSteamLib.IsLoaded then
  begin
    if FState = swsIdle then
      FState := swsLibraryLoaded;
    Exit(True);
  end;
  Log(sllInfo, 'Platform: ' + TSteamLib.PlatformDescription);
  // Before the library loads: its C runtime may snapshot the environment
  ApplyAppIdEnvironment;
  try
    TSteamLib.OnWarning := LibraryWarning;
    TSteamLib.Load(FLibraryPath);
    FVersions.Clear;
    if FVersions.ScanFile(TSteamLib.LibraryPath) then
      Log(sllDebug, Format('Loaded %s; %d interface versions detected',
        [TSteamLib.LibraryPath, FVersions.Count]))
    else
      Log(sllWarning, 'Could not scan the Steam library for interface versions; using built-in defaults');
    if TSteamLib.SDKGeneration = '1.65+' then
      Log(sllInfo, 'Steam redistributable is from SDK 1.65 or newer')
    else
      Log(sllWarning, Format('Steam redistributable %s is from SDK %s; this library targets 1.65 - ' +
        'copy redistributable_bin from the 1.65 SDK and run tools/check_redist.py',
        [TSteamLib.LibraryPath, TSteamLib.SDKGeneration]));
    FState := swsLibraryLoaded;
    Result := True;
  except
    on E: Exception do
    begin
      if TSteamLib.RedistributableName <> '' then
        SetFailure(E.Message + sLineBreak + 'This build needs redistributable_bin/' +
          TSteamLib.RedistributableName + ' from the Steamworks SDK 1.65 next to the executable')
      else
        SetFailure(E.Message);
      Result := False;
    end;
  end;
end;

function TSteamworks.RestartAppIfNecessary(AAppID: AppId_t): Boolean;
var
  ID: AppId_t;
begin
  ID := AAppID;
  if ID = 0 then
    ID := FAppID;
  if (ID = 0) or not LoadLibrary then
    Exit(False);
  Result := TSteamLib.SteamAPI_RestartAppIfNecessary(ID);
  if Result then
    Log(sllInfo, 'Steam requested a relaunch through the Steam client');
end;

function TSteamworks.IsSteamRunning: Boolean;
begin
  Result := LoadLibrary and Assigned(TSteamLib.SteamAPI_IsSteamRunning) and
            TSteamLib.SteamAPI_IsSteamRunning();
end;

procedure TSteamworks.ReleaseCurrentThreadMemory;
begin
  if TSteamLib.IsLoaded and Assigned(TSteamLib.SteamAPI_ReleaseCurrentThreadMemory) then
    TSteamLib.SteamAPI_ReleaseCurrentThreadMemory();
end;

procedure TSteamworks.SetMiniDumpComment(const AComment: string);
var
  S: AnsiString;
begin
  if TSteamLib.IsLoaded and Assigned(TSteamLib.SteamAPI_SetMiniDumpComment) then
  begin
    S := AnsiString(AComment);
    TSteamLib.SteamAPI_SetMiniDumpComment(PAnsiChar(S));
  end;
end;

function TSteamworks.ResolveVersion(const AFallbackVersion: string): string;
begin
  Result := FVersions.Resolve(AFallbackVersion);
end;

function TSteamworks.GetProc(const AExportName: string): Pointer;
begin
  Result := TSteamLib.GetProc(AExportName);
end;

type
  TSteamFlatAccessor = function: Pointer; cdecl;

function TSteamworks.AcquireUserInterface(const AFallbackVersion, AAccessorBase: string): Pointer;
var
  Ver: string;
  Acc: TSteamFlatAccessor;
  A: AnsiString;
begin
  Result := nil;
  if not FClientUp then
    Exit;
  Ver := ResolveVersion(AFallbackVersion);
  // 1) the flat accessor compiled into the redistributable for this version
  if AAccessorBase <> '' then
  begin
    Acc := TSteamFlatAccessor(GetProc('SteamAPI_' + AAccessorBase + '_v' + TSteamInterfaceVersions.NumberOf(Ver)));
    if Assigned(Acc) then
      Result := Acc();
    if Result <> nil then
      Exit;
  end;
  // 2) the factory the C++ accessors use
  A := AnsiString(Ver);
  if Assigned(TSteamLib.SteamInternal_FindOrCreateUserInterface) then
    Result := TSteamLib.SteamInternal_FindOrCreateUserInterface(FUser, PAnsiChar(A));
  // 3) ISteamClient generic getter
  if (Result = nil) and (FClient <> nil) then
    Result := FClient.GetGenericInterface(FUser, FPipe, Ver);
end;

function TSteamworks.AcquireGameServerInterface(const AFallbackVersion, AAccessorBase: string): Pointer;
var
  Ver: string;
  Acc: TSteamFlatAccessor;
  A: AnsiString;
begin
  Result := nil;
  if not FServerUp then
    Exit;
  Ver := ResolveVersion(AFallbackVersion);
  if AAccessorBase <> '' then
  begin
    Acc := TSteamFlatAccessor(GetProc('SteamAPI_' + AAccessorBase + '_v' + TSteamInterfaceVersions.NumberOf(Ver)));
    if Assigned(Acc) then
      Result := Acc();
    if Result <> nil then
      Exit;
  end;
  // The SERVER's user (this passed the client's before 2026-11-02; unused
  // until the game-server batch, so it never mattered)
  A := AnsiString(Ver);
  if Assigned(TSteamLib.SteamInternal_FindOrCreateGameServerInterface) then
    Result := TSteamLib.SteamInternal_FindOrCreateGameServerInterface(FServerUser, PAnsiChar(A));
  if (Result = nil) and (FClient <> nil) then
    Result := FClient.GetGenericInterface(FServerUser, FServerPipe, Ver);
end;

function TSteamworks.BuildPluginOrder: TSteamPluginClassArray;
var
  Ordered, Visiting, Roots: TList<TSteamPluginClass>;

  procedure Visit(C: TSteamPluginClass);
  var
    Deps: TSteamPluginClassArray;
    I: Integer;
  begin
    if Ordered.Contains(C) then
      Exit;
    if Visiting.Contains(C) then
      raise ESteamworksError.CreateFmt('Circular plug-in dependency involving %s', [C.PluginName]);
    Visiting.Add(C);
    Deps := C.Dependencies;
    for I := 0 to High(Deps) do
    begin
      if FExcluded.Contains(Deps[I]) then
        Log(sllWarning, Format('%s is excluded but required by %s - including it',
          [Deps[I].PluginName, C.PluginName]));
      Visit(Deps[I]);
    end;
    Visiting.Remove(C);
    Ordered.Add(C);
  end;

var
  I: Integer;
begin
  Ordered := TList<TSteamPluginClass>.Create;
  Visiting := TList<TSteamPluginClass>.Create;
  Roots := TList<TSteamPluginClass>.Create;
  try
    if FUseRegisteredPlugins and (GRegistry <> nil) then
      for I := 0 to GRegistry.Count - 1 do
        if not FExcluded.Contains(GRegistry[I]) then
          Roots.Add(GRegistry[I]);
    for I := 0 to FIncluded.Count - 1 do
      if not Roots.Contains(FIncluded[I]) then
        Roots.Add(FIncluded[I]);
    for I := 0 to Roots.Count - 1 do
      Visit(Roots[I]);
    Result := nil;   // FPC: initialise before SetLength (warning 5093)
    SetLength(Result, Ordered.Count);
    for I := 0 to Ordered.Count - 1 do
      Result[I] := Ordered[I];
  finally
    Roots.Free;
    Visiting.Free;
    Ordered.Free;
  end;
end;

function TSteamworks.CheckVersionList(AGameServer: Boolean): AnsiString;
var
  Order: TSteamPluginClassArray;
  Vers: TSteamStringArray;
  List: TStringList;
  I, J: Integer;
begin
  // NUL-separated, double-NUL terminated (as SteamAPI_InitEx /
  // SteamGameServer_InitEx build it)
  List := TStringList.Create;
  try
    List.Sorted := True;
    List.Duplicates := dupIgnore;
    List.Add(ResolveVersion(STEAMUTILS_INTERFACE_VERSION));
    List.Add(ResolveVersion(STEAMNETWORKINGUTILS_INTERFACE_VERSION));
    Order := BuildPluginOrder;
    for I := 0 to High(Order) do
    begin
      if Order[I].IsGameServer <> AGameServer then
        Continue;
      Vers := Order[I].InterfaceVersions(FVersions);
      for J := 0 to High(Vers) do
        if Vers[J] <> '' then
          List.Add(Vers[J]);
    end;
    Result := '';
    for I := 0 to List.Count - 1 do
      Result := Result + AnsiString(List[I]) + AnsiChar(#0);
    Result := Result + AnsiChar(#0);
  finally
    List.Free;
  end;
end;

function TSteamworks.InitializeGameServerAPI: Boolean;
var
  Err: TSteamErrMsg;
  Check, Ver: AnsiString;
  Msg: string;
begin
  FillChar(Err, SizeOf(Err), 0);
  FLastInitResult := k_ESteamAPIInitResult_FailedGeneric;
  Ver := AnsiString(UTF8String(FServerVersion));
  if Assigned(TSteamLib.SteamInternal_GameServer_Init_V2) then
  begin
    Check := CheckVersionList(True);
    FLastInitResult := TSteamLib.SteamInternal_GameServer_Init_V2(FServerIP, FServerGamePort, FServerQueryPort,
      Ord(FServerMode), PAnsiChar(Ver), PAnsiChar(Check), @Err);
  end
  else if Assigned(TSteamLib.SteamInternal_GameServer_Init) then
  begin
    if TSteamLib.SteamInternal_GameServer_Init(FServerIP, 0, FServerGamePort, FServerQueryPort,
      Ord(FServerMode), PAnsiChar(Ver)) then
      FLastInitResult := k_ESteamAPIInitResult_OK;
  end
  else
  begin
    SetFailure('This redistributable exports no SteamInternal_GameServer_Init(_V2): no game-server API');
    Exit(False);
  end;
  Result := FLastInitResult = k_ESteamAPIInitResult_OK;
  if not Result then
  begin
    Msg := Trim(string(UTF8String(PAnsiChar(@Err[0]))));
    if Msg = '' then
      Msg := SteamInitResultToString(FLastInitResult);
    SetFailure(Format('Game server initialisation failed (game port %d, query port %d): %s',
      [FServerGamePort, FServerQueryPort, Msg]));
  end;
end;

function TSteamworks.InitializeSteamAPI: Boolean;
var
  Err: TSteamErrMsg;
  Mode: TSteamInitMode;
  Check: AnsiString;
  Msg: string;
begin
  FillChar(Err, SizeOf(Err), 0);
  FLastInitResult := k_ESteamAPIInitResult_FailedGeneric;

  Mode := FInitMode;
  if Mode = simAuto then
  begin
    if Assigned(TSteamLib.SteamAPI_InitFlat) then
      Mode := simFlat
    else if Assigned(TSteamLib.SteamInternal_SteamAPI_Init) then
      Mode := simVersioned
    else
      Mode := simLegacy;
  end;

  case Mode of
    simFlat:
      begin
        if not Assigned(TSteamLib.SteamAPI_InitFlat) then
        begin
          SetFailure('SteamAPI_InitFlat is not exported by this redistributable');
          Exit(False);
        end;
        FLastInitResult := TSteamLib.SteamAPI_InitFlat(@Err);
      end;

    simVersioned:
      begin
        if not Assigned(TSteamLib.SteamInternal_SteamAPI_Init) then
        begin
          SetFailure('SteamInternal_SteamAPI_Init is not exported by this redistributable');
          Exit(False);
        end;
        Check := CheckVersionList(False);
        FLastInitResult := TSteamLib.SteamInternal_SteamAPI_Init(PAnsiChar(Check), @Err);
      end;

    simLegacy:
      begin
        if Assigned(TSteamLib.SteamAPI_Init) then
        begin
          if TSteamLib.SteamAPI_Init() then
            FLastInitResult := k_ESteamAPIInitResult_OK;
        end
        else if Assigned(TSteamLib.SteamAPI_InitSafe) then
        begin
          if TSteamLib.SteamAPI_InitSafe() then
            FLastInitResult := k_ESteamAPIInitResult_OK;
        end
        else
        begin
          SetFailure('No legacy SteamAPI_Init export in this redistributable');
          Exit(False);
        end;
      end;
  end;

  Result := FLastInitResult = k_ESteamAPIInitResult_OK;
  if not Result then
  begin
    Msg := Trim(string(UTF8String(PAnsiChar(@Err[0]))));
    if Msg = '' then
      Msg := SteamInitResultToString(FLastInitResult);
    SetFailure('SteamAPI initialisation failed: ' + Msg);
  end;
end;

function TSteamworks.InitializePlugins(AGameServer: Boolean): Boolean;
var
  Order, Deps: TSteamPluginClassArray;
  I, J: Integer;
  C: TSteamPluginClass;
  P: TSteamPlugin;
  DepsOk: Boolean;
begin
  Result := True;
  Order := BuildPluginOrder;
  for I := 0 to High(Order) do
  begin
    C := Order[I];
    if C.IsGameServer <> AGameServer then
      Continue;   // the other side's: created with it
    // Skip plug-ins whose dependencies did not come up
    DepsOk := True;
    Deps := C.Dependencies;
    for J := 0 to High(Deps) do
      if FindPlugin(Deps[J]) = nil then
        DepsOk := False;
    P := nil;
    if DepsOk then
    begin
      P := C.Create;
      if P.Initialize(Self) then
      begin
        FPlugins.Add(P);
        Log(sllInfo, 'Plug-in ' + C.PluginName + ' initialised');
        Continue;
      end;
    end;
    P.Free;
    if C.IsRequired then
    begin
      SetFailure('Required plug-in ' + C.PluginName + ' failed to initialise');
      Exit(False);
    end;
    if DepsOk then
      Log(sllWarning, 'Plug-in ' + C.PluginName + ' failed to initialise and was skipped')
    else
      Log(sllWarning, 'Plug-in ' + C.PluginName + ' skipped: a dependency is unavailable');
  end;
end;

procedure TSteamworks.FinalizePlugins(AGameServer: Boolean);
var
  I: Integer;
begin
  for I := FPlugins.Count - 1 downto 0 do
    if FPlugins[I].IsGameServer = AGameServer then
      FPlugins[I].Finalize;
  for I := FPlugins.Count - 1 downto 0 do
    if FPlugins[I].IsGameServer = AGameServer then
      FPlugins.Delete(I);   // frees it
end;

procedure TSteamworks.FinalizePluginsOfClass(AClass: TSteamPluginClass);
var
  I, J: Integer;
  Deps: TSteamPluginClassArray;
  Dependent: Boolean;
begin
  // Dependents first (they were initialised later), then AClass itself
  for I := FPlugins.Count - 1 downto 0 do
  begin
    if I >= FPlugins.Count then
      Continue;
    Deps := TSteamPluginClass(FPlugins[I].ClassType).Dependencies;
    Dependent := False;
    for J := 0 to High(Deps) do
      if Deps[J] = AClass then
        Dependent := True;
    if Dependent then
    begin
      Log(sllWarning, Format('Finalising %s because %s is being unregistered',
        [FPlugins[I].PluginName, AClass.PluginName]));
      FinalizePluginsOfClass(TSteamPluginClass(FPlugins[I].ClassType));
    end;
  end;
  for I := FPlugins.Count - 1 downto 0 do
    if FPlugins[I].ClassType = AClass then
    begin
      FPlugins[I].Finalize;
      FPlugins.Delete(I); // frees it
    end;
end;

procedure TSteamworks.HandleSteamShutdown(const AData: TSteamCallbackData);
begin
  if FSteamExitSeen then
  begin
    Log(sllDebug, 'SteamShutdown_t (704) received again - ignored');
    Exit;
  end;
  FSteamExitSeen := True;
  if FShutdownOnSteamExit then
    Log(sllInfo, 'Steam client is shutting down (SteamShutdown_t, 704); ' +
      'SteamAPI shuts down after OnSteamShutdown (ShutdownOnSteamExit)')
  else
    Log(sllInfo, 'Steam client is shutting down (SteamShutdown_t, 704); ' +
      'SteamAPI stays up (ShutdownOnSteamExit is off)');
  try
    if Assigned(FOnSteamShutdown) then
      FOnSteamShutdown(Self);
  finally
    if FShutdownOnSteamExit then
      Shutdown; // inside the pump: deferred until this callback has finished
  end;
end;

procedure TSteamworks.CreateClientIntf;
var
  ClientPtr: Pointer;
  ClientVer: AnsiString;
begin
  if FClient <> nil then
    Exit;
  ClientVer := AnsiString(ResolveVersion(STEAMCLIENT_INTERFACE_VERSION));
  ClientPtr := TSteamLib.SteamInternal_CreateInterface(PAnsiChar(ClientVer));
  if ClientPtr <> nil then
  begin
    FClient := TSteamClientIntf.Create(ClientPtr, string(ClientVer));
    if FInstallWarningHook then
    begin
      // Steam may call the hook from its own threads: make the memory
      // manager / RTL thread-safe before it can happen.
      IsMultiThread := True;
      FClient.SetWarningMessageHook(SteamWarningHook);
    end;
  end
  else
    Log(sllWarning, 'Could not create ' + string(ClientVer) + '; ISteamClient features unavailable');
end;

function TSteamworks.Initialize: Boolean;
var
  WasActive: Boolean;
begin
  if FClientUp then
  begin
    FShutdownPending := False; // a pending shutdown was superseded
    Exit(True);
  end;
  if InAnyHandler then
  begin
    SetFailure('Initialize cannot be called from a callback handler while a game server runs');
    Exit(False);
  end;
  FLastError := '';
  if not LoadLibrary then
    Exit(False);
  // A game server already runs (dedicated first, client added): the worker
  // must not read the server pipe while the client comes up
  WasActive := FState = swsRunning;
  if WasActive then
    StopPumpThread;

  Result := False;
  try
    if not InitializeSteamAPI then
    begin
      if WasActive then
        ApplyUpdateMode;
      Exit;
    end;

    // Steam is up from here; any failure must shut it down again.
    if not FManualDispatch then
    begin
      TSteamLib.SteamAPI_ManualDispatch_Init();
      FManualDispatch := True;
    end;
    FPipe := TSteamLib.SteamAPI_GetHSteamPipe();
    FUser := TSteamLib.SteamAPI_GetHSteamUser();
    FClientUp := True;
    FState := swsRunning;
    FShutdownPending := False;
    FSteamExitSeen := False;
    Log(sllInfo, Format('SteamAPI initialised (pipe %d, user %d)', [FPipe, FUser]));

    CreateClientIntf;

    FShutdownSub := FDispatcher.Subscribe(SteamShutdown_t_k_iCallback, HandleSteamShutdown);

    if not InitializePlugins(False) then
    begin
      FLastInitResult := k_ESteamAPIInitResult_FailedGeneric;
      if FServerUp then
      begin
        // keep the game server that ran before: only the client goes
        FShutdownLock.Enter;
        try
          ShutdownClientLocked;
        finally
          FShutdownLock.Leave;
        end;
        ApplyUpdateMode;
      end
      else
        DoShutdown;
      Exit;
    end;

    // Last: every plug-in has subscribed before the first callback is read
    if FUpdateMode = sumThread then
      StartPumpThread;

    Result := True;
    if Assigned(FOnInitialized) then
      FOnInitialized(Self);
  except
    on E: Exception do
    begin
      FLastInitResult := k_ESteamAPIInitResult_FailedGeneric;
      SetFailure('Initialisation error: ' + E.Message);
      if FClientUp and FServerUp then
      begin
        // keep the game server that ran before: only the client goes
        StopPumpThread;
        FShutdownLock.Enter;
        try
          ShutdownClientLocked;
        finally
          FShutdownLock.Leave;
        end;
        ApplyUpdateMode;
      end
      else if FClientUp then
        DoShutdown
      else if WasActive then
        ApplyUpdateMode;
      Result := False;
    end;
  end;
end;

function TSteamworks.StartGameServer: Boolean;
var
  WasActive: Boolean;
  Kind: string;
begin
  if FServerUp then
  begin
    FServerStopPending := False;   // a pending stop was superseded
    Exit(True);
  end;
  if InAnyHandler then
  begin
    SetFailure('StartGameServer cannot be called from a callback handler');
    Exit(False);
  end;
  FLastError := '';
  if not LoadLibrary then
    Exit(False);
  if not (Assigned(TSteamLib.SteamGameServer_GetHSteamPipe) and Assigned(TSteamLib.SteamGameServer_GetHSteamUser) and
    Assigned(TSteamLib.SteamGameServer_Shutdown)) then
  begin
    SetFailure('This redistributable has no SteamGameServer_GetHSteamPipe / _GetHSteamUser / _Shutdown');
    Exit(False);
  end;
  WasActive := FState = swsRunning;
  // The worker must not read a pipe while the server comes up
  if WasActive then
    StopPumpThread;
  Result := False;
  try
    if not InitializeGameServerAPI then
    begin
      if WasActive then
        ApplyUpdateMode;
      Exit;
    end;
    if not FManualDispatch then
    begin
      TSteamLib.SteamAPI_ManualDispatch_Init();
      FManualDispatch := True;
    end;
    FServerPipe := TSteamLib.SteamGameServer_GetHSteamPipe();
    FServerUser := TSteamLib.SteamGameServer_GetHSteamUser();
    FServerUp := True;
    FServerStopPending := False;
    if not WasActive then
    begin
      FShutdownPending := False;
      FState := swsRunning;
    end;
    if FClientUp then
      Kind := 'listen server: the client runs too'
    else
      Kind := 'dedicated: no client';
    Log(sllInfo, Format('Game server initialised (pipe %d, user %d; game port %d, query port %d, mode %d, ' +
      'version "%s"; %s)', [FServerPipe, FServerUser, FServerGamePort, FServerQueryPort, Ord(FServerMode),
      FServerVersion, Kind]));
    CreateClientIntf;
    if not InitializePlugins(True) then
    begin
      FLastInitResult := k_ESteamAPIInitResult_FailedGeneric;
      FRollingBack := True;
      try
        FShutdownLock.Enter;
        try
          StopGameServerLocked;
        finally
          FShutdownLock.Leave;
        end;
        if not FClientUp then
          DoShutdown
        else
          ApplyUpdateMode;
      finally
        FRollingBack := False;
      end;
      Exit;
    end;
    // Last: every plug-in has subscribed before the first callback is read
    ApplyUpdateMode;
    Result := True;
    if Assigned(FOnGameServerStarted) then
      FOnGameServerStarted(Self);
  except
    on E: Exception do
    begin
      FLastInitResult := k_ESteamAPIInitResult_FailedGeneric;
      SetFailure('Game server initialisation error: ' + E.Message);
      FRollingBack := True;
      try
        if FServerUp then
        begin
          FShutdownLock.Enter;
          try
            StopGameServerLocked;
          finally
            FShutdownLock.Leave;
          end;
        end;
        if not FClientUp and (FState = swsRunning) then
          DoShutdown
        else if FClientUp then
          ApplyUpdateMode;
      finally
        FRollingBack := False;
      end;
      Result := False;
    end;
  end;
end;

procedure TSteamworks.StopGameServer;
begin
  if not FServerUp then
    Exit;
  if not FClientUp then
  begin
    Shutdown;   // a dedicated server: everything
    Exit;
  end;
  if InAnyHandler then
  begin
    // Inside a callback handler: finish the current callback first
    FServerStopPending := True;
    FServerDispatcher.RequestStop;
    Exit;
  end;
  FServerStopPending := False;
  StopPumpThread;
  FShutdownLock.Enter;
  try
    if FServerUp then
      StopGameServerLocked;
  finally
    FShutdownLock.Leave;
  end;
  ApplyUpdateMode;   // the client's worker again
end;

procedure TSteamworks.StopGameServerLocked;
begin
  if not FServerUp then
    Exit;
  FServerDispatcher.ClearQueue;
  FinalizePlugins(True);
  FServerDispatcher.Clear;
  // The last part of Steam going: ISteamClient (warning hook) first - after
  // the shutdown steamclient is unloaded and the call would crash
  if not FClientUp then
    ReleaseClientIntf;
  if Assigned(TSteamLib.SteamGameServer_Shutdown) then
    TSteamLib.SteamGameServer_Shutdown();
  FServerUp := False;
  FServerStopPending := False;
  FServerPipe := 0;
  FServerUser := 0;
  if FRollingBack then
    Log(sllInfo, 'Game server shut down again (its start failed)')
  else
  begin
    Log(sllInfo, 'Game server shut down');
    if Assigned(FOnGameServerStopped) then
      FOnGameServerStopped(Self);
  end;
end;

procedure TSteamworks.DoShutdown;
begin
  if FState <> swsRunning then
    Exit;
  // The worker must not touch the pipe once SteamAPI_Shutdown has run.
  // Stopped OUTSIDE FShutdownLock: the worker may itself be on its way into
  // DoShutdown (sdPumpThread), and we must not wait for it while holding
  // the lock it needs.
  StopPumpThread;
  FShutdownLock.Enter;
  try
    // Whoever got here second finds Steam already shut down
    if FState <> swsRunning then
      Exit;
    FShutdownPending := False;
    DoShutdownLocked;
  finally
    FShutdownLock.Leave;
  end;
end;

procedure TSteamworks.ReleaseClientIntf;
begin
  if FClient <> nil then
    FClient.SetWarningMessageHook(nil);
  FreeAndNil(FClient);
end;

procedure TSteamworks.ShutdownClientLocked;
begin
  if not FClientUp then
    Exit;
  FDispatcher.ClearQueue;
  FinalizePlugins(False);
  FDispatcher.Unsubscribe(FShutdownSub);
  FDispatcher.Clear;
  // The last part of Steam going: ISteamClient (warning hook) first - after
  // SteamAPI_Shutdown steamclient is unloaded and the call would crash
  // (owner's GS1 build, 18:53: access violation in steam_api64 on close)
  if not FServerUp then
    ReleaseClientIntf;
  TSteamLib.SteamAPI_Shutdown();
  FClientUp := False;
  FPipe := 0;
  FUser := 0;
end;

procedure TSteamworks.DoShutdownLocked;
var
  What: string;
begin
  if FClientUp and FServerUp then
    What := 'SteamAPI and the game server shut down'
  else if FServerUp then
    What := 'Game server (dedicated) shut down - Steam stopped'
  else
    What := 'SteamAPI shut down';
  // The game server first (a listen server's server lives inside the
  // client's process; Valve's samples shut it down first too)
  StopGameServerLocked;
  ShutdownClientLocked;
  ReleaseClientIntf;   // normally done already, before the last Steam shutdown
  FManualDispatch := False;
  FState := swsLibraryLoaded;
  FWarningLock.Enter;
  try
    FWarnings.Clear;
  finally
    FWarningLock.Leave;
  end;
  if FRollingBack then
    What := 'Steam stopped again (the dedicated game server did not start)';
  Log(sllInfo, What);
  if Assigned(FOnShutdown) and not FRollingBack then
    FOnShutdown(Self);
end;

procedure TSteamworks.Shutdown;
begin
  if FState <> swsRunning then
    Exit;
  if InAnyHandler then
  begin
    // Inside a callback handler: finish the current callback first
    FShutdownPending := True;
    FDispatcher.RequestStop;
    FServerDispatcher.RequestStop;
    Exit;
  end;
  DoShutdown;
end;

procedure TSteamworks.DrainWarnings;
var
  Pending: TStringList;
  I: Integer;
begin
  if FWarnings.Count = 0 then  // unsynchronised peek is fine; re-checked under lock
    Exit;
  Pending := TStringList.Create;
  try
    FWarningLock.Enter;
    try
      Pending.Assign(FWarnings);
      FWarnings.Clear;
    finally
      FWarningLock.Leave;
    end;
    if Assigned(FOnWarning) then
      for I := 0 to Pending.Count - 1 do
        FOnWarning(Self, Integer(NativeInt(Pending.Objects[I])), Pending[I]);
  finally
    Pending.Free;
  end;
end;

procedure TSteamworks.RunCallbacks;
begin
  if FWorkerStopping then
    Exit;   // inside StopPumpThread's wait (see FWorkerStopping)
  ReapDeadThread;
  if FState <> swsRunning then
    Exit;
  try
    if FPumpThread = nil then
    begin
      // Timer / manual pumping (or a worker that could not start)
      PumpAll;
      DrainWarnings;
    end
    else if (FDelivery = sdOnUpdate) or
            ((FDelivery = sdMainThread) and (TThread.CurrentThread.ThreadID = MainThreadID)) then
    begin
      DeliverAllQueued;
      DrainWarnings;
      DrainThreadErrors;
    end;
    // sdPumpThread: the worker delivers everything itself
  finally
    // Never from inside a handler (a re-entrant call): the outer call does
    // it; and with sdPumpThread the worker that was asked finishes it itself
    if not InAnyHandler and not ((FPumpThread <> nil) and (FDelivery = sdPumpThread)) then
    begin
      if FShutdownPending then
        DoShutdown
      else if FServerStopPending then
        StopGameServer;
    end;
  end;
end;

procedure TSteamworks.Update;
begin
  RunCallbacks;
end;

function TSteamworks.QueuedCallbackCount: Integer;
begin
  Result := FDispatcher.QueuedCount + FServerDispatcher.QueuedCount;
end;

function TSteamworks.GetThreaded: Boolean;
begin
  Result := FPumpThread <> nil;
end;

procedure TSteamworks.SetUpdateMode(AMode: TSteamUpdateMode; ADelivery: TSteamDelivery;
  AIntervalMs: Integer);
var
  Changed: Boolean;
begin
  if AIntervalMs >= 0 then
    FPumpInterval := AIntervalMs;
  if FPumpInterval < 1 then
    FPumpInterval := 1;
  Changed := (AMode <> FUpdateMode) or (ADelivery <> FDelivery);
  if not Changed then
  begin
    if FPumpThread <> nil then
      TSteamPumpThread(FPumpThread).Wake;   // new interval applies at once
    Exit;
  end;
  // The running worker reads FDelivery: stop it BEFORE the value changes,
  // and hand over what it read under the old rules
  if FPumpThread <> nil then
  begin
    StopPumpThread;
    if (FDelivery <> sdPumpThread) and not InAnyHandler then
      DeliverAllQueued;
  end;
  FUpdateMode := AMode;
  FDelivery := ADelivery;
  ApplyUpdateMode;
end;

procedure TSteamworks.SetUpdateModeValue(const AValue: TSteamUpdateMode);
begin
  SetUpdateMode(AValue, FDelivery);
end;

procedure TSteamworks.SetDelivery(const AValue: TSteamDelivery);
begin
  SetUpdateMode(FUpdateMode, AValue);
end;

procedure TSteamworks.SetPumpInterval(const AValue: Integer);
begin
  FPumpInterval := AValue;
  if FPumpInterval < 1 then
    FPumpInterval := 1;
  if FPumpThread <> nil then
    TSteamPumpThread(FPumpThread).Wake;   // picks the new interval up at once
end;

procedure TSteamworks.ApplyUpdateMode;
begin
  if FState <> swsRunning then
    Exit;   // Initialize starts the worker when needed
  if FUpdateMode = sumThread then
    StartPumpThread
  else if QueuedCallbackCount > 0 then
    DeliverAllQueued;   // nothing else would deliver them now
end;

procedure TSteamworks.StartPumpThread;
begin
  ReapDeadThread;
  if (FPumpThread <> nil) or (FState <> swsRunning) or FWorkerStopping then
    Exit;
  FThreadSteamExit := False;
  FMainQueued := False;
  try
    FPumpThread := TSteamPumpThread.Create(Self);
    Log(sllInfo, Format('Callback worker thread started (every %d ms, delivery %s)',
      [FPumpInterval, DeliveryName(FDelivery)]));
    // What the previous worker read but nobody delivered yet (a restart
    // around StartGameServer / StopGameServer removed its queued delivery)
    if (FDelivery = sdMainThread) and (QueuedCallbackCount > 0) then
      ScheduleMainDelivery;
  except
    on E: Exception do
    begin
      FPumpThread := nil;
      Log(sllError, 'Could not start the callback worker thread (' + E.Message + '); ' +
        'callbacks are pumped by RunCallbacks / Update instead. With FPC on Linux or ' +
        'macOS, add cthreads as the FIRST unit of the program''s uses clause.');
    end;
  end;
end;

procedure TSteamworks.StopPumpThread;
var
  T, OldDead: TThread;
  OnWorker: Boolean;
begin
  if FPumpThread = nil then   // unsynchronised peek; taken under the lock
    Exit;
  // Exactly one caller (main thread or the worker itself) takes ownership,
  // and a worker that stops itself is recorded as dead in the SAME critical
  // section - no moment where neither field holds it.
  FThreadLock.Enter;
  try
    T := FPumpThread;
    FPumpThread := nil;
    OnWorker := (T <> nil) and (T.ThreadID = TThread.CurrentThread.ThreadID);
    OldDead := nil;
    if OnWorker then
    begin
      OldDead := FDeadThread;   // an earlier self-stopped worker: freed below
      FDeadThread := T;
    end;
  finally
    FThreadLock.Leave;
  end;
  if (OldDead <> nil) and (OldDead.ThreadID <> TThread.CurrentThread.ThreadID) then
    OldDead.Free;
  if (T = nil) or OnWorker then
  begin
    // On the worker (Shutdown from an sdPumpThread handler): it cannot wait
    // for itself. Let the loop end; another thread frees it (ReapDeadThread).
    if T <> nil then
    begin
      T.Terminate;
      Log(sllDebug, 'Callback worker thread ending (stopped from one of its own handlers)');
    end;
    Exit;
  end;
  // A main-thread delivery queued earlier must not run any more; and while
  // we wait, WaitFor runs other queued main-thread work, which must not
  // start reading Steam's queue next to the still-running worker.
  TThread.RemoveQueuedEvents(nil, MainThreadDeliver);
  FWorkerStopping := True;
  try
    T.Free;   // Terminate + wake + wait (TSteamPumpThread.Destroy)
  finally
    FWorkerStopping := False;
  end;
  TThread.RemoveQueuedEvents(nil, MainThreadDeliver);   // queued during the wait
  FThreadLock.Enter;
  try
    FMainQueued := False;
  finally
    FThreadLock.Leave;
  end;
  Log(sllDebug, 'Callback worker thread stopped');
end;

procedure TSteamworks.ReapDeadThread;
var
  T: TThread;
begin
  if FDeadThread = nil then   // unsynchronised peek; re-checked under lock
    Exit;
  FThreadLock.Enter;
  try
    T := FDeadThread;
    if (T <> nil) and (T.ThreadID = TThread.CurrentThread.ThreadID) then
      Exit;   // still on that thread: someone else frees it
    FDeadThread := nil;
  finally
    FThreadLock.Leave;
  end;
  T.Free;
end;

procedure TSteamworks.ReleaseThreadMemoryIfRunning;
begin
  FShutdownLock.Enter;
  try
    if FState = swsRunning then
      ReleaseCurrentThreadMemory;
  finally
    FShutdownLock.Leave;
  end;
end;

procedure TSteamworks.AddThreadError(const AMessage: string);
begin
  FThreadLock.Enter;
  try
    if FThreadErrors.Count < 100 then   // do not grow without bound
      FThreadErrors.Add(AMessage);
  finally
    FThreadLock.Leave;
  end;
end;

procedure TSteamworks.DrainThreadErrors;
var
  Pending: TStringList;
  I: Integer;
begin
  if FThreadErrors.Count = 0 then  // unsynchronised peek; re-checked under lock
    Exit;
  Pending := TStringList.Create;
  try
    FThreadLock.Enter;
    try
      Pending.Assign(FThreadErrors);
      FThreadErrors.Clear;
    finally
      FThreadLock.Leave;
    end;
    for I := 0 to Pending.Count - 1 do
      Log(sllError, 'Callback worker thread: ' + Pending[I]);
  finally
    Pending.Free;
  end;
end;

procedure TSteamworks.ThreadTick;
var
  Count: Integer;
  SawExit, ServerExit: Boolean;
begin
  if (FState <> swsRunning) or FThreadSteamExit then
    Exit;
  try
    if FDelivery = sdPumpThread then
    begin
      // Everything happens here, on the worker
      try
        PumpAll;
        DrainWarnings;
        DrainThreadErrors;
      finally
        if FShutdownPending then
          DoShutdown   // stops this thread too (it ends after this tick)
        else if FServerStopPending then
        begin
          // This worker is the only reader in sdPumpThread mode: stop the
          // server here, without stopping / restarting the thread (a
          // restart from the worker could race with a Shutdown waiting for it)
          FShutdownLock.Enter;
          try
            if FServerUp then
              StopGameServerLocked;
          finally
            FShutdownLock.Leave;
          end;
        end;
      end;
    end
    else
    begin
      Count := 0;
      SawExit := False;
      if FClientUp then
        Count := FDispatcher.PumpToQueue(FPipe, SawExit);
      if FServerUp then
        Count := Count + FServerDispatcher.PumpToQueue(FServerPipe, ServerExit);
      // After 704 Steam's pipe goes away (Linux: ~1.5 s later); the delivery
      // thread shuts down on 704, so stop calling into Steam now.
      if SawExit and FShutdownOnSteamExit then
        FThreadSteamExit := True;
      if (FDelivery = sdMainThread) and
         ((Count > 0) or (FWarnings.Count > 0) or (FThreadErrors.Count > 0)) then
        ScheduleMainDelivery;
    end;
  except
    // Never let an exception end the worker silently
    on E: Exception do
      AddThreadError(E.ClassName + ': ' + E.Message);
  end;
end;

procedure TSteamworks.ScheduleMainDelivery;
begin
  FThreadLock.Enter;
  try
    if FMainQueued then
      Exit;
    FMainQueued := True;
  finally
    FThreadLock.Leave;
  end;
  TThread.Queue(nil, MainThreadDeliver);
end;

procedure TSteamworks.MainThreadDeliver;
begin
  FThreadLock.Enter;
  try
    FMainQueued := False;   // first: callbacks read from now on queue a new run
  finally
    FThreadLock.Leave;
  end;
  // Queued by a worker that may be gone (mode change, shutdown): only a live
  // worker's queue is delivered here, never a direct read of Steam's queue
  if (FPumpThread <> nil) and (FDelivery = sdMainThread) then
    RunCallbacks;
end;

function TSteamworks.FindPlugin(AClass: TSteamPluginClass): TSteamPlugin;
var
  I: Integer;
begin
  // The class itself first, then a descendant OF THE SAME SIDE: the game
  // server's copies descend from the client classes
  // (TSteamGameServerUtilsPlugin = class(TSteamUtilsPlugin)) and must never
  // answer for them
  for I := 0 to FPlugins.Count - 1 do
    if FPlugins[I].ClassType = AClass then
      Exit(FPlugins[I]);
  for I := 0 to FPlugins.Count - 1 do
    if FPlugins[I].InheritsFrom(AClass) and (FPlugins[I].IsGameServer = AClass.IsGameServer) then
      Exit(FPlugins[I]);
  Result := nil;
end;

{$ifndef FPC}
function TSteamworks.Plugin<T>: T;
begin
  // The same rules as FindPlugin (server copies descend from client classes)
  Result := T(FindPlugin(TSteamPluginClass(GetTypeData(TypeInfo(T))^.ClassType)));
end;
{$endif}

function TSteamworks.HasPlugin(AClass: TSteamPluginClass): Boolean;
begin
  Result := FindPlugin(AClass) <> nil;
end;

initialization

finalization
  GFinalized := True;   // first: no new instance may be created from here on
  FreeAndNil(GInstance);
  FreeAndNil(GRegistry);

end.
