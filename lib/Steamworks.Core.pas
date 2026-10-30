{ @abstract(The Steam client core (@link(TSteamworks)) and the plug-in base
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
      // game loop: call Steam.RunCallbacks every frame
      Steam.Shutdown;
    end;
  end.
  #) }
unit Steamworks.Core;

{$I Steamworks.inc}

interface

uses
  SysUtils, Classes, SyncObjs, Generics.Collections,
  Steamworks.Types, Steamworks.API, Steamworks.Callbacks, Steamworks.SteamClient,
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
    { SteamAPI initialised; callbacks flow. }
    swsRunning
  );

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

    { Subscribes a method of this plug-in to a callback id. }
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
    function or @link(TSteamworks.Instance). All events fire on the thread that
    calls @link(RunCallbacks). }
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
    { Creates and initialises plug-ins. @returns(@false if a required one failed.) }
    function InitializePlugins: Boolean;
    { Finalises and frees all plug-ins in reverse order. }
    procedure FinalizePlugins;
    { Finalises and frees the live plug-ins of exactly AClass. }
    procedure FinalizePluginsOfClass(AClass: TSteamPluginClass);
    { Exports SteamAppId / SteamGameId when @link(SetAppIdEnvironment) is set. }
    procedure ApplyAppIdEnvironment;
    { Performs the shutdown (never during a pump). }
    procedure DoShutdown;
    { Records @link(LastError) and logs it. }
    procedure SetFailure(const AMessage: string);
    { Handler of SteamShutdown_t; raises @link(OnSteamShutdown). }
    procedure HandleSteamShutdown(const AData: TSteamCallbackData);
    { Receives @link(TSteamDynLib) warnings and logs them. }
    procedure LibraryWarning(Sender: TObject; const AMessage: string);
    { Delivers queued warnings to @link(OnWarning) on the pump thread. }
    procedure DrainWarnings;
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

    { Finalises plug-ins and shuts SteamAPI down. Safe at any time, including
      from a callback handler (it then completes after the current callback). }
    procedure Shutdown;

    { Delivers pending callbacks and queued warnings. Call regularly
      (every frame or every 15-50 ms) from ONE thread. }
    procedure RunCallbacks;

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

    { Game-server counterpart of @link(AcquireUserInterface). }
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

    { Current lifecycle state. }
    property State: TSteamworksState read FState;
    { @true while SteamAPI is initialised. }
    property IsRunning: Boolean read GetIsRunning;
    { Global pipe handle (0 when not running). }
    property Pipe: HSteamPipe read FPipe;
    { Global user handle (0 when not running). }
    property User: HSteamUser read FUser;
    { Result of the last initialisation attempt. }
    property LastInitResult: ESteamAPIInitResult read FLastInitResult;
    { Text of the last failure (Steam's own diagnostic when available). }
    property LastError: string read FLastError;
    { Callback dispatcher. }
    property Dispatcher: TSteamCallbackDispatcher read FDispatcher;
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
  end;

{ Shorthand for @link(TSteamworks.Instance). }
function Steam: TSteamworks;

implementation

{$if defined(MSWINDOWS)}
uses
  Windows;
{$elseif not defined(FPC)}
uses
  Posix.Stdlib;
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
begin
  try
    if FActive then
      DoFinalize;
  except
    on E: Exception do
      LogFmt(sllError, 'Exception during finalisation: %s', [E.Message]);
  end;
  if Assigned(FSteam) and Assigned(FSteam.Dispatcher) then
    FSteam.Dispatcher.RemoveOwner(Self);
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
begin
  Result := FSteam.AcquireUserInterface(AFallbackVersion, AAccessorBase);
  if Result = nil then
    LogFmt(sllError, 'Could not acquire interface %s', [FSteam.ResolveVersion(AFallbackVersion)]);
end;

function TSteamPlugin.Subscribe(ACallbackID: Integer; AHandler: TSteamCallbackEvent;
  AIncludeCallResults: Boolean): TSteamSubscription;
begin
  Result := FSteam.Dispatcher.Subscribe(ACallbackID, AHandler, AIncludeCallResults);
end;

function TSteamPlugin.AwaitCallResult(ACall: SteamAPICall_t; AExpectedCallbackID: Integer;
  AHandler: TSteamCallResultEvent): Boolean;
begin
  Result := FSteam.Dispatcher.AwaitCallResult(ACall, AExpectedCallbackID, AHandler);
end;

procedure TSteamPlugin.Unsubscribe(var AToken: TSteamSubscription);
begin
  FSteam.Dispatcher.Unsubscribe(AToken);
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
  FVersions := TSteamInterfaceVersions.Create;
  FPlugins := TObjectList<TSteamPlugin>.Create(True);
  FIncluded := TList<TSteamPluginClass>.Create;
  FExcluded := TList<TSteamPluginClass>.Create;
  // Qualified: under FPC the Windows unit (used below on Windows) declares
  // TCriticalSection = TRTLCriticalSection, a record, which hides SyncObjs'.
  FWarningLock := SyncObjs.TCriticalSection.Create;
  FWarnings := TStringList.Create;
  FUseRegisteredPlugins := True;
  FInstallWarningHook := True;
  FShutdownOnSteamExit := True;
  FInitMode := simAuto;
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
  if FState = swsRunning then
    DoShutdown;
  if TSteamLib.IsLoaded then
    TSteamLib.Unload;
  FreeAndNil(FClient);
  FreeAndNil(FWarnings);
  FreeAndNil(FWarningLock);
  FExcluded.Free;
  FIncluded.Free;
  FPlugins.Free;
  FVersions.Free;
  FDispatcher.Free;
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
  Result := FState = swsRunning;
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
  if FState <> swsRunning then
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
  if FState <> swsRunning then
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
  A := AnsiString(Ver);
  if Assigned(TSteamLib.SteamInternal_FindOrCreateGameServerInterface) then
    Result := TSteamLib.SteamInternal_FindOrCreateGameServerInterface(FUser, PAnsiChar(A));
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

function TSteamworks.InitializeSteamAPI: Boolean;
var
  Err: TSteamErrMsg;
  Mode: TSteamInitMode;
  Check: AnsiString;
  Order: TSteamPluginClassArray;
  Vers: TSteamStringArray;
  List: TStringList;
  I, J: Integer;
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
        // NUL-separated, double-NUL terminated (as SteamAPI_InitEx builds it)
        List := TStringList.Create;
        try
          List.Sorted := True;
          List.Duplicates := dupIgnore;
          List.Add(ResolveVersion(STEAMUTILS_INTERFACE_VERSION));
          List.Add(ResolveVersion(STEAMNETWORKINGUTILS_INTERFACE_VERSION));
          Order := BuildPluginOrder;
          for I := 0 to High(Order) do
          begin
            Vers := Order[I].InterfaceVersions(FVersions);
            for J := 0 to High(Vers) do
              if Vers[J] <> '' then
                List.Add(Vers[J]);
          end;
          Check := '';
          for I := 0 to List.Count - 1 do
            Check := Check + AnsiString(List[I]) + AnsiChar(#0);
          Check := Check + AnsiChar(#0);
        finally
          List.Free;
        end;
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

function TSteamworks.InitializePlugins: Boolean;
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

procedure TSteamworks.FinalizePlugins;
var
  I: Integer;
begin
  for I := FPlugins.Count - 1 downto 0 do
    FPlugins[I].Finalize;
  FPlugins.Clear;
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

function TSteamworks.Initialize: Boolean;
var
  ClientPtr: Pointer;
  ClientVer: AnsiString;
begin
  if FState = swsRunning then
  begin
    FShutdownPending := False; // a pending shutdown was superseded
    Exit(True);
  end;
  FLastError := '';
  if not LoadLibrary then
    Exit(False);

  Result := False;
  try
    if not InitializeSteamAPI then
      Exit;

    // Steam is up from here; any failure must shut it down again.
    TSteamLib.SteamAPI_ManualDispatch_Init();
    FPipe := TSteamLib.SteamAPI_GetHSteamPipe();
    FUser := TSteamLib.SteamAPI_GetHSteamUser();
    FState := swsRunning;
    FShutdownPending := False;
    FSteamExitSeen := False;
    Log(sllInfo, Format('SteamAPI initialised (pipe %d, user %d)', [FPipe, FUser]));

    ClientVer := AnsiString(ResolveVersion(STEAMCLIENT_INTERFACE_VERSION));
    ClientPtr := TSteamLib.SteamInternal_CreateInterface(PAnsiChar(ClientVer));
    FreeAndNil(FClient);
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

    FShutdownSub := FDispatcher.Subscribe(SteamShutdown_t_k_iCallback, HandleSteamShutdown);

    if not InitializePlugins then
    begin
      FLastInitResult := k_ESteamAPIInitResult_FailedGeneric;
      DoShutdown;
      Exit;
    end;

    Result := True;
    if Assigned(FOnInitialized) then
      FOnInitialized(Self);
  except
    on E: Exception do
    begin
      FLastInitResult := k_ESteamAPIInitResult_FailedGeneric;
      SetFailure('Initialisation error: ' + E.Message);
      if FState = swsRunning then
        DoShutdown;
      Result := False;
    end;
  end;
end;

procedure TSteamworks.DoShutdown;
begin
  if FState <> swsRunning then
    Exit;
  FShutdownPending := False;
  FinalizePlugins;
  FDispatcher.Unsubscribe(FShutdownSub);
  FDispatcher.Clear;
  if FClient <> nil then
    FClient.SetWarningMessageHook(nil);
  FreeAndNil(FClient);
  TSteamLib.SteamAPI_Shutdown();
  FPipe := 0;
  FUser := 0;
  FState := swsLibraryLoaded;
  FWarningLock.Enter;
  try
    FWarnings.Clear;
  finally
    FWarningLock.Leave;
  end;
  Log(sllInfo, 'SteamAPI shut down');
  if Assigned(FOnShutdown) then
    FOnShutdown(Self);
end;

procedure TSteamworks.Shutdown;
begin
  if FState <> swsRunning then
    Exit;
  if FDispatcher.Pumping then
  begin
    // Inside a callback handler: finish the current callback first
    FShutdownPending := True;
    FDispatcher.RequestStop;
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
  if FState <> swsRunning then
    Exit;
  try
    FDispatcher.Pump(FPipe);
    DrainWarnings;
  finally
    if FShutdownPending then
      DoShutdown;
  end;
end;

function TSteamworks.FindPlugin(AClass: TSteamPluginClass): TSteamPlugin;
var
  I: Integer;
begin
  for I := 0 to FPlugins.Count - 1 do
    if FPlugins[I].InheritsFrom(AClass) then
      Exit(FPlugins[I]);
  Result := nil;
end;

{$ifndef FPC}
function TSteamworks.Plugin<T>: T;
var
  I: Integer;
begin
  for I := 0 to FPlugins.Count - 1 do
    if FPlugins[I] is T then
      Exit(T(FPlugins[I]));
  Result := Default(T);
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
