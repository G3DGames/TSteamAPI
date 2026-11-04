{ @abstract(SteamConsole - the library from a console, no UI framework: a
  smoke test, the demos' component and pair tests, and a dedicated game
  server.)

  The same source builds with Delphi (SteamConsole.dproj) and with plain
  Free Pascal (SteamConsoleFPC.lpi, no LCL). Steam is opened through a
  TCustomSteamAPI created in code (@link(TConsoleSteamAPI)), like the
  TSteamAPI on a demo's form. Every step is written to the console with a
  time stamp, so the output can be pasted back as test evidence.

  Command line (switches in any order; @code(SteamConsole --help) prints it):
  @longCode(#
  SteamConsole [seconds] [mode] [--test] [--pair] [--server]
               [--port <game port>] [--query-port <query port>]
  #)
  @unorderedList(
    @item(No switch: the smoke test - opens Steam, logs what the main
      plug-ins report, pumps callbacks for @italic(seconds) (default 3) and closes.)
    @item(@code(--test): the component test of the demos (every plug-in
      component, demos/Shared/SteamComponentTest.pas). Ends when every row has its
      verdict.)
    @item(@code(--pair): the pair test (demos/Shared/SteamPairTest.pas): run
      it on two PCs with two Steam accounts, or against a GUI demo's Pair
      button. Ends when the pair test does.)
    @item(@code(--server) alone: a DEDICATED game server - no Steam client
      needed (Roles = [srGameServer]); logs on anonymously, is listed in the
      server browser and answers its queries, until Enter, Ctrl+C or the
      @italic(seconds) given. With @code(--test) / @code(--pair): a LISTEN
      server (client and server in this process) that the tests use as it
      is (they never stop a server they did not start); the program then
      also stays up until Enter / Ctrl+C.)
    @item(@italic(seconds): smoke test - how long callbacks are pumped;
      tests and server - a time limit (default: none).)
    @item(@italic(mode) - how callbacks are pumped (see
      GameEngineIntegration.md); every callback line says which thread ran
      it: @code(manual) (default; the loop calls Update), @code(thread)
      (worker reads, the loop's Update delivers), @code(main) (worker reads,
      TThread.Queue hands it to the main thread, the loop runs
      CheckSynchronize), @code(worker) (worker reads and delivers - smoke
      test only: the tests and the server need their events on the main
      thread).)
  )
  Exit code: 0 = done (every test row PASS), 1 = Steam (or the game server)
  did not start, 2 = command line error or an exception, 3 = a test row did
  not pass. }
unit uConsoleMain;

// No Steamworks.inc here: the Delphi demo has no path to the library
// sources (it links the packages' DCUs); FPC builds use -Mdelphi anyway.
{$ifdef FPC}{$mode delphi}{$H+}{$endif}

interface

const
  { Exit code: done, every test row passed. }
  EXIT_OK = 0;
  { Exit code: Steam (or the game server) did not start. }
  EXIT_STEAM = 1;
  { Exit code: command line error or an exception (also the .dpr's / .lpr's). }
  EXIT_USAGE = 2;
  { Exit code: a test row did not pass. }
  EXIT_TEST_FAILED = 3;

{ Parses the command line and runs what it asks for.
  @returns(Process exit code, see the unit description.) }
function RunConsoleDemo: Integer;

implementation

uses
  SysUtils, Classes, SyncObjs, StrUtils,
  Steamworks.Types, Steamworks.SDKTypes, Steamworks.API, Steamworks.Callbacks, Steamworks.Core,
  Steamworks.Components,
  Steamworks.Plugin.Utils, Steamworks.Plugin.User, Steamworks.Plugin.Friends,
  Steamworks.Plugin.Apps, Steamworks.Plugin.UserStats, Steamworks.Plugin.RemoteStorage,
  Steamworks.Plugin.Screenshots, Steamworks.Plugin.Timeline, Steamworks.Plugin.UGC,
  Steamworks.Plugin.Input, Steamworks.Plugin.GameServer,
  SteamComponentTest, SteamPairTest, uConsoleStop;

const
  { AppID of this project on Steam. }
  APP_ID = 2275430;
  { Smoke test: default time callbacks are pumped, in milliseconds.
    Override with the seconds argument. }
  PUMP_MS = 3000;
  { Pump interval of the loop (and the worker), in milliseconds. }
  TICK_MS = 33;
  { The tests' Tick is called this often, in milliseconds ("about once a
    second", as the demos' timers do). }
  TEST_TICK_MS = 1000;
  { The game server logs a status line this often, in milliseconds. }
  STATUS_MS = 60000;
  { Game server: mod folder (SetModDir; Steam needs one for the browser). }
  SERVER_MOD_DIR = 'tsteamapi';
  { Game server: product (SetProduct). }
  SERVER_PRODUCT = 'TSteamAPI';
  { Game server: map shown in the server browser. }
  SERVER_MAP = 'console';
  { Game server: player slots advertised. }
  SERVER_MAX_PLAYERS = 4;
  { Game server: rule (SetKeyValue) saying which kind of server this is. }
  SERVER_KIND_KEY = 'tsapi_kind';
  { Highest UDP port number (--port, --query-port). }
  MAX_PORT = 65535;
  { Text for each log level. }
  LevelNames: array[TSteamLogLevel] of string = ('debug', 'info', 'warn', 'ERROR');

type
  { What the command line asked for. }
  TConsoleOptions = record
    { Seconds given (0 = none). }
    Seconds: Integer;
    { Update mode name: manual, thread, main or worker. }
    Mode: string;
    { --test: the component test. }
    DoTest: Boolean;
    { --pair: the pair test. }
    DoPair: Boolean;
    { --server: a game server (dedicated alone, listen with a test). }
    DoServer: Boolean;
    { --port (0 = the component's default). }
    GamePort: Integer;
    { --query-port (0 = the component's default). }
    QueryPort: Integer;
    { --help. }
    Help: Boolean;
  end;

  { The console's TSteamAPI: TCustomSteamAPI with the framework parts a
    console has (see Steamworks.Components). The console loop calls Update
    every @link(TICK_MS), so no timer is needed for the pump. }
  TConsoleSteamAPI = class(TCustomSteamAPI)
  protected
    { Nothing to start: the console loop calls Update every tick. }
    procedure PumpStart(AIntervalMs: Integer); override;
    { Nothing to stop (see PumpStart). }
    procedure PumpStop; override;
    { Writes the exception to the console. }
    procedure ShowHandlerException(E: Exception); override;
    { Asks the console loop to stop (QuitOnSteamShutdown, a restart). }
    procedure TerminateApplication; override;
    { A console has no window: nothing is changed. }
    function ApplyBigPictureWindow(AMode: TSteamBigPictureWindow): string; override;
  public
    { A console knows no display: @false, zeros and scale 1. }
    function DisplaySize(out AWidth, AHeight: Integer; out AScale: Single): Boolean; override;
  end;

  { Runs one console session: owns the root, the game server component
    and the tests, and receives their events. }
  TConsoleRunner = class(TComponent)
  private
    { What the command line asked for. }
    FOpt: TConsoleOptions;
    { The root (Roles from the options). }
    SteamAPI1: TConsoleSteamAPI;
    { The game server component (only with --server). }
    SteamGameServer1: TSteamGameServer;
    { The component test (only with --test). }
    FTest: TSteamComponentTest;
    { The pair test (only with --pair). }
    FPair: TSteamPairTest;
    { Every callback gets a line (smoke test and server); during the tests
      only their own lines are written. }
    FShowCallbacks: Boolean;
    { Set when SteamShutdown_t (704) arrives on the client's pipe; the loop
      then ends. Written by the worker thread in mode worker, only polled. }
    FSteamExiting: Boolean;
    { This program's name (the executable's), e.g. SteamConsoleFPC. }
    FProgramName: string;
    { Steam log lines. }
    procedure SteamLog(Sender: TObject; ALevel: TSteamLogLevel; const AMessage: string);
    { Steam debug output. }
    procedure SteamWarning(Sender: TObject; ASeverity: Integer; const AText: string);
    { Every callback of the client and the server pipe. }
    procedure SteamCallback(Sender: TObject; const AData: TSteamCallbackData);
    { Steam (or the dedicated server) did not start. }
    procedure SteamInitFailed(Sender: TObject; AResult: Integer; const AMessage: string);
    { The listen server did not start. }
    procedure SteamServerFailed(Sender: TObject; AResult: Integer; const AMessage: string);
    { SteamShutdown_t on the client's pipe: the Steam client is exiting. }
    procedure SteamExit(Sender: TObject);
    { The core shut down (Close, Steam exit, the dedicated server stopped):
      the tests are ended without cleanup. }
    procedure SteamShutdown(Sender: TObject);
    { SteamServersConnected_t (101) on the server's pipe: logged on. }
    procedure GSConnected(Sender: TObject; const AData: SteamServersConnected_t);
    { SteamServerConnectFailure_t (102) on the server's pipe. }
    procedure GSConnectFailure(Sender: TObject; const AData: SteamServerConnectFailure_t);
    { SteamServersDisconnected_t (103) on the server's pipe. }
    procedure GSDisconnected(Sender: TObject; const AData: SteamServersDisconnected_t);
    { GSPolicyResponse_t (115): VAC secure or not. }
    procedure GSPolicy(Sender: TObject; const AData: GSPolicyResponse_t);
    { A test's log line. }
    procedure TestLog(const AText: string);
    { A component test row changed: verdicts are written. }
    procedure TestRow(AIndex: Integer; const AText: string);
    { A pair test row changed: verdicts are written. }
    procedure PairRow(AIndex: Integer; const AText: string);
    { Creates the root, the server component and the tests from the options. }
    procedure CreateComponents;
    { The smoke test's report of the main plug-ins. }
    procedure SmokeReport;
    { The game server's product data and LogOnAnonymous. }
    procedure ServerLogOn;
    { Server name, map, slots, rule and advertising, once logged on. }
    procedure ServerAdvertise;
    { One status line of the game server. }
    procedure ServerStatus(AUpMs: UInt64);
    { Stops advertising and logs the server off (before Close). }
    procedure ServerLogOff;
    { Writes the rows of a finished test and counts the passes.
      @returns(@true when every row passed.) }
    function Summary: Boolean;
    { What the program does, as one line. }
    function JobText: string;
  public
    { Takes the parsed options. }
    constructor Create(AOwner: TComponent; const AOptions: TConsoleOptions); reintroduce;
    { Opens Steam, runs the job, closes Steam. @returns(The exit code.) }
    function Run: Integer;
  end;

var
  { Serialises console output: in mode worker the worker thread writes too,
    and Writeln to the shared console buffer is not thread-safe (unguarded,
    a line was once printed twice). }
  SayLock: TCriticalSection;

{ Writes one time-stamped line and flushes it (the evidence survives a kill). }
procedure Say(const S: string);
begin
  SayLock.Enter;
  try
    try
      Writeln(FormatDateTime('hh:nn:ss.zzz', Now), '  ', S);
      Flush(Output);
    except
      // console gone (window closing, broken pipe): the shutdown carries on
      on EInOutError do ;
    end;
  finally
    SayLock.Leave;
  end;
end;

{ "yes" / "no". (Delphi's BoolToStr has no texts parameters - FPC's has.) }
function YesNo(AValue: Boolean): string;
begin
  if AValue then
    Result := 'yes'
  else
    Result := 'no';
end;

{ An IPv4 address in host order as a.b.c.d. }
function IPText(AIP: UInt32): string;
begin
  Result := Format('%d.%d.%d.%d', [(AIP shr 24) and $FF, (AIP shr 16) and $FF, (AIP shr 8) and $FF, AIP and $FF]);
end;

{ The compiler that built this program, for the log. }
function CompilerText: string;
begin
{$ifdef FPC}
  Result := 'FPC ' + {$I %FPCVERSION%};
{$else}
  Result := Format('Delphi (compiler %d.%d)', [Trunc(CompilerVersion), Round(Frac(CompilerVersion) * 10)]);
{$endif}
end;

{ The command-line help. }
procedure ShowUsage(const AProgram: string);
begin
  Writeln('Usage: ', AProgram, ' [seconds] [mode] [--test] [--pair] [--server] [--port <n>] [--query-port <n>]');
  Writeln('  (no switch)   smoke test: open Steam, report the main plug-ins, pump callbacks for');
  Writeln(Format('                [seconds] (default %d), close', [PUMP_MS div 1000]));
  Writeln('  --test        the component test of the demos (', CT_COUNT, ' components)');
  Writeln('  --pair        the pair test (a second copy with another Steam account)');
  Writeln('  --server      alone: a dedicated game server (no Steam client needed) until Enter /');
  Writeln('                Ctrl+C; with --test / --pair: a listen server the tests use');
  Writeln('  --port, --query-port   the game server''s ports');
  Writeln('  seconds       smoke test: pump time; tests / server: time limit');
  Writeln('  mode          manual (default), thread, main, worker (worker: smoke test only)');
  Writeln(Format('Exit code: %d done, %d Steam did not start, %d command line / exception, %d a test failed',
    [EXIT_OK, EXIT_STEAM, EXIT_USAGE, EXIT_TEST_FAILED]));
end;

{ Parses the command line into AOpt. @returns('' or the error text.) }
function ParseOptions(out AOpt: TConsoleOptions): string;
var
  I, N: Integer;
  A, L: string;

  function PortArg(const AName: string; out APort: Integer): string;
  begin
    Result := '';
    APort := 0;
    if I >= ParamCount then
      Exit(AName + ' needs a port number');
    Inc(I);
    APort := StrToIntDef(ParamStr(I), 0);
    if (APort < 1) or (APort > MAX_PORT) then
      Result := Format('%s %s: not a port number (1-%d)', [AName, ParamStr(I), MAX_PORT]);
  end;

begin
  Result := '';
  AOpt.Seconds := 0;
  AOpt.Mode := '';
  AOpt.DoTest := False;
  AOpt.DoPair := False;
  AOpt.DoServer := False;
  AOpt.GamePort := 0;
  AOpt.QueryPort := 0;
  AOpt.Help := False;
  I := 1;
  while (I <= ParamCount) and (Result = '') do
  begin
    A := ParamStr(I);
    L := LowerCase(A);
    if L = '--test' then
      AOpt.DoTest := True
    else if L = '--pair' then
      AOpt.DoPair := True
    else if L = '--server' then
      AOpt.DoServer := True
    else if L = '--port' then
      Result := PortArg('--port', AOpt.GamePort)
    else if L = '--query-port' then
      Result := PortArg('--query-port', AOpt.QueryPort)
    else if (L = '--help') or (L = '-h') or (L = '/?') then
      AOpt.Help := True
    else if StartsStr('-', L) then
      Result := 'unknown switch ' + A
    else if (L = 'manual') or (L = 'thread') or (L = 'main') or (L = 'worker') then
    begin
      if AOpt.Mode <> '' then
        Result := Format('two update modes: %s and %s', [AOpt.Mode, L])
      else
        AOpt.Mode := L;
    end
    else
    begin
      N := StrToIntDef(A, 0);
      if N <= 0 then
        Result := Format('%s is neither a number of seconds nor an update mode', [A])
      else if AOpt.Seconds <> 0 then
        Result := Format('two numbers of seconds: %d and %d', [AOpt.Seconds, N])
      else
        AOpt.Seconds := N;
    end;
    Inc(I);
  end;
  if AOpt.Mode = '' then
    AOpt.Mode := 'manual';
  if (Result = '') and (AOpt.Mode = 'worker') and (AOpt.DoTest or AOpt.DoPair or AOpt.DoServer) then
    Result := 'mode worker runs event handlers on the worker thread: use it for the smoke test only ' +
      '(--test, --pair and --server need manual, thread or main)';
  if (Result = '') and ((AOpt.GamePort <> 0) or (AOpt.QueryPort <> 0)) and not AOpt.DoServer then
    Result := '--port / --query-port set the game server''s ports: add --server';
end;

{ TConsoleSteamAPI }

procedure TConsoleSteamAPI.PumpStart(AIntervalMs: Integer);
begin
end;

procedure TConsoleSteamAPI.PumpStop;
begin
end;

procedure TConsoleSteamAPI.ShowHandlerException(E: Exception);
begin
  Say(Format('[ERROR] %s: %s', [E.ClassName, E.Message]));
end;

procedure TConsoleSteamAPI.TerminateApplication;
begin
  RequestStop(STOP_PROGRAM);
end;

function TConsoleSteamAPI.ApplyBigPictureWindow(AMode: TSteamBigPictureWindow): string;
begin
  Result := 'a console has no window to change';
end;

function TConsoleSteamAPI.DisplaySize(out AWidth, AHeight: Integer; out AScale: Single): Boolean;
begin
  AWidth := 0;
  AHeight := 0;
  AScale := 1;
  Result := False;
end;

{ TConsoleRunner }

constructor TConsoleRunner.Create(AOwner: TComponent; const AOptions: TConsoleOptions);
begin
  inherited Create(AOwner);
  FOpt := AOptions;
  FProgramName := ChangeFileExt(ExtractFileName(ParamStr(0)), '');
  FShowCallbacks := not (FOpt.DoTest or FOpt.DoPair);
end;

function TConsoleRunner.JobText: string;
begin
  if not (FOpt.DoTest or FOpt.DoPair or FOpt.DoServer) then
    Exit('smoke test');
  Result := '';
  if FOpt.DoTest then
    Result := 'component test';
  if FOpt.DoPair then
    Result := Result + IfThen(Result <> '', ' + ', '') + 'pair test';
  if FOpt.DoServer then
  begin
    if FOpt.DoTest or FOpt.DoPair then
      Result := Result + ' + listen server'
    else
      Result := 'dedicated game server';
  end;
end;

procedure TConsoleRunner.CreateComponents;
begin
  SteamAPI1 := TConsoleSteamAPI.Create(Self);
  SteamAPI1.AppID := APP_ID;
  // Every build: a console started by hand has no steam_appid.txt, and
  // SteamGameServer_Init reads the AppID from the same environment
  SteamAPI1.SetAppIdEnvironment := True;
  SteamAPI1.BigPictureWindow := bpwNone;
  if FOpt.DoServer and not (FOpt.DoTest or FOpt.DoPair) then
    SteamAPI1.Roles := [srGameServer]
  else if FOpt.DoServer then
    SteamAPI1.Roles := [srClient, srGameServer]
  else
    SteamAPI1.Roles := [srClient];
  if FOpt.GamePort <> 0 then
    SteamAPI1.GameServerGamePort := FOpt.GamePort;
  if FOpt.QueryPort <> 0 then
    SteamAPI1.GameServerQueryPort := FOpt.QueryPort;
  if FOpt.Mode = 'thread' then
    SteamAPI1.SetUpdateMode(sumThread, sdOnUpdate, TICK_MS)
  else if FOpt.Mode = 'main' then
    SteamAPI1.SetUpdateMode(sumThread, sdMainThread, TICK_MS)
  else if FOpt.Mode = 'worker' then
    SteamAPI1.SetUpdateMode(sumThread, sdPumpThread, TICK_MS)
  else
    SteamAPI1.SetUpdateMode(sumManual, sdMainThread, TICK_MS);
  SteamAPI1.OnLog := SteamLog;
  SteamAPI1.OnWarning := SteamWarning;
  SteamAPI1.OnCallback := SteamCallback;
  SteamAPI1.OnInitFailed := SteamInitFailed;
  SteamAPI1.OnGameServerFailed := SteamServerFailed;
  SteamAPI1.OnSteamShutdown := SteamExit;
  SteamAPI1.OnShutdown := SteamShutdown;

  if FOpt.DoServer then
  begin
    SteamGameServer1 := TSteamGameServer.Create(Self);
    SteamGameServer1.SteamAPI := SteamAPI1;
    SteamGameServer1.OnSteamServersConnected := GSConnected;
    SteamGameServer1.OnSteamServerConnectFailure := GSConnectFailure;
    SteamGameServer1.OnSteamServersDisconnected := GSDisconnected;
    SteamGameServer1.OnGSPolicyResponse := GSPolicy;
  end;
  if FOpt.DoTest then
  begin
    FTest := TSteamComponentTest.Create(Self, SteamAPI1);
    FTest.OnLog := TestLog;
    FTest.OnRowChanged := TestRow;
  end;
  if FOpt.DoPair then
  begin
    FPair := TSteamPairTest.Create(Self, SteamAPI1);
    FPair.AppName := FProgramName;
    FPair.OnLog := TestLog;
    FPair.OnRowChanged := PairRow;
  end;
end;

procedure TConsoleRunner.SteamLog(Sender: TObject; ALevel: TSteamLogLevel; const AMessage: string);
begin
  Say('[' + LevelNames[ALevel] + '] ' + AMessage);
end;

procedure TConsoleRunner.SteamWarning(Sender: TObject; ASeverity: Integer; const AText: string);
begin
  Say(Format('Steam debug (severity %d): %s', [ASeverity, AText]));
end;

procedure TConsoleRunner.SteamCallback(Sender: TObject; const AData: TSteamCallbackData);
begin
  if (AData.CallbackID = SteamShutdown_t_k_iCallback) and not SteamAPI1.IsRunning then
    // The core reacts to 704 on the CLIENT's pipe only; a dedicated server
    // carries on (it does not need the client) - see README
    Say(Format('SteamShutdown_t (%d) on the game server''s pipe: the server keeps running ' +
      '(stop it with Enter / Ctrl+C)', [SteamShutdown_t_k_iCallback]));
  if FShowCallbacks then
    Say(Format('Callback %d (%s), %d bytes, on the %s thread',
      [AData.CallbackID, SteamCallbackGroupName(AData.CallbackID), AData.Size,
       IfThen(TThread.CurrentThread.ThreadID = MainThreadID, 'main', 'WORKER')]));
end;

procedure TConsoleRunner.SteamInitFailed(Sender: TObject; AResult: Integer; const AMessage: string);
begin
  Say(Format('Initialize failed: result %d (%s): %s',
    [AResult, SteamInitResultToString(ESteamAPIInitResult(AResult)), AMessage]));
end;

procedure TConsoleRunner.SteamServerFailed(Sender: TObject; AResult: Integer; const AMessage: string);
begin
  Say(Format('Game server did not start: result %d: %s', [AResult, AMessage]));
end;

procedure TConsoleRunner.SteamExit(Sender: TObject);
begin
  // What a game should do: save, shut Steam down and quit. Steam ends a
  // game that is still running about 10 s after this callback.
  Say(Format('SteamShutdown_t (%d): the Steam client is exiting - stopping now', [SteamShutdown_t_k_iCallback]));
  FSteamExiting := True;
end;

procedure TConsoleRunner.SteamShutdown(Sender: TObject);
begin
  Say('Steam shut down');
  if (FTest <> nil) and FTest.Running then
    FTest.Finish('Steam shut down while the component test was running (no cleanup possible)');
  if (FPair <> nil) and FPair.Running then
    FPair.Finish('Steam shut down while the pair test was running (no cleanup possible)');
end;

procedure TConsoleRunner.GSConnected(Sender: TObject; const AData: SteamServersConnected_t);
begin
  Say(Format('Game server: logged on (SteamServersConnected_t, %d)', [SteamServersConnected_t_k_iCallback]));
  ServerAdvertise;
end;

procedure TConsoleRunner.GSConnectFailure(Sender: TObject; const AData: SteamServerConnectFailure_t);
begin
  Say(Format('Game server: log-on FAILED (SteamServerConnectFailure_t, %d): result %d, Steam still retrying: %s',
    [SteamServerConnectFailure_t_k_iCallback, Ord(AData.m_eResult), YesNo(AData.m_bStillRetrying)]));
end;

procedure TConsoleRunner.GSDisconnected(Sender: TObject; const AData: SteamServersDisconnected_t);
begin
  Say(Format('Game server: disconnected from Steam (SteamServersDisconnected_t, %d): result %d',
    [SteamServersDisconnected_t_k_iCallback, Ord(AData.m_eResult)]));
end;

procedure TConsoleRunner.GSPolicy(Sender: TObject; const AData: GSPolicyResponse_t);
begin
  Say(Format('Game server: policy response (GSPolicyResponse_t, %d): VAC secure %s',
    [GSPolicyResponse_t_k_iCallback, YesNo(AData.m_bSecure <> 0)]));
end;

procedure TConsoleRunner.TestLog(const AText: string);
begin
  Say(AText);
end;

procedure TConsoleRunner.TestRow(AIndex: Integer; const AText: string);
begin
  if StartsStr('PASS', AText) or StartsStr('FAIL', AText) then
    Say(Format('[component test] %s: %s', [TestNames[AIndex], AText]));
end;

procedure TConsoleRunner.PairRow(AIndex: Integer; const AText: string);
begin
  if StartsStr('PASS', AText) or StartsStr('FAIL', AText) then
    Say(Format('[pair test] %s: %s', [PairTestNames[AIndex], AText]));
end;

procedure TConsoleRunner.SmokeReport;
var
  S: TSteamworks;
  U: TSteamUtilsPlugin;
  Usr: TSteamUserPlugin;
  Fr: TSteamFriendsPlugin;
  Apps: TSteamAppsPlugin;
  Stats: TSteamUserStatsPlugin;
  RS: TSteamRemoteStoragePlugin;
  Shots: TSteamScreenshotsPlugin;
  Tl: TSteamTimelinePlugin;
  Ugc: TSteamUGCPlugin;
  QuotaTotal, QuotaAvailable: UInt64;
  TlEvent: TimelineEventHandle_t;
  Inp: TSteamInputPlugin;
  Pads: TSteamInputHandleArray;
  Pad: InputHandle_t;
  Dig: InputDigitalActionData_t;
  Ana: InputAnalogActionData_t;
  Mot: InputMotionData_t;
  Achieved: Boolean;
  UnlockTime: UInt32;
  V: string;
  Versions: TSteamStringArray;
  I: Integer;
begin
  S := SteamAPI1.Steam;
  Versions := S.Versions.ToArray;
  Say(Format('Loaded %s, %d interface versions detected', [TSteamLib.LibraryPath, Length(Versions)]));
  for I := 0 to High(Versions) do
    Say('  ' + Versions[I]);

  U := TSteamUtilsPlugin(S.FindPlugin(TSteamUtilsPlugin));
  if U <> nil then
  begin
    V := U.GetSteamUILanguage;
    Say(Format('ISteamUtils: AppID %d, country %s, language %s, overlay %s',
      [U.GetAppID, U.GetIPCountry, V, BoolToStr(U.IsOverlayEnabled, True)]));
    Say('Server time (UTC): ' + FormatDateTime('yyyy-mm-dd hh:nn:ss', U.ServerTime));
  end
  else
    Say('ISteamUtils plug-in is not active');

  // Generated plug-ins raise ESteamworksError when the loaded library lacks
  // an export; report it and carry on.
  try
    Usr := TSteamUserPlugin(S.FindPlugin(TSteamUserPlugin));
    if Usr <> nil then
      Say(Format('ISteamUser: logged on %s, SteamID %s, Steam level %d',
        [BoolToStr(Usr.BLoggedOn, True), Usr.GetSteamID.ToString, Usr.GetPlayerSteamLevel]));
    Fr := TSteamFriendsPlugin(S.FindPlugin(TSteamFriendsPlugin));
    if Fr <> nil then
      Say(Format('ISteamFriends: persona "%s", immediate friends %d',
        [Fr.GetPersonaName, Fr.GetFriendCount(k_EFriendFlagImmediate)]));
    Apps := TSteamAppsPlugin(S.FindPlugin(TSteamAppsPlugin));
    if Apps <> nil then
      Say(Format('ISteamApps: subscribed %s, game language %s, build id %d',
        [BoolToStr(Apps.BIsSubscribed, True), Apps.GetCurrentGameLanguage, Apps.GetAppBuildId]));
    Stats := TSteamUserStatsPlugin(S.FindPlugin(TSteamUserStatsPlugin));
    if Stats <> nil then
    begin
      Say(Format('ISteamUserStats: %d achievements defined', [Stats.GetNumAchievements]));
      for I := 0 to Integer(Stats.GetNumAchievements) - 1 do
      begin
        V := Stats.GetAchievementName(UInt32(I));
        Achieved := False;
        UnlockTime := 0;
        Stats.GetAchievementAndUnlockTime(V, Achieved, UnlockTime);
        if Achieved then
          Say(Format('  %s "%s": unlocked %s', [V, Stats.GetAchievementDisplayAttribute(V, 'name'),
            FormatDateTime('yyyy-mm-dd hh:nn', SteamTimeToLocal(UnlockTime))]))
        else
          Say(Format('  %s "%s": locked', [V, Stats.GetAchievementDisplayAttribute(V, 'name')]));
      end;
    end;
    RS := TSteamRemoteStoragePlugin(S.FindPlugin(TSteamRemoteStoragePlugin));
    if RS <> nil then
    begin
      QuotaTotal := 0;
      QuotaAvailable := 0;
      RS.GetQuota(QuotaTotal, QuotaAvailable);
      Say(Format('ISteamRemoteStorage: cloud enabled for account %s / app %s, %d files, quota %s of %s bytes free',
        [BoolToStr(RS.IsCloudEnabledForAccount, True), BoolToStr(RS.IsCloudEnabledForApp, True),
         RS.GetFileCount, IntToStr(Int64(QuotaAvailable)), IntToStr(Int64(QuotaTotal))]));
    end;
    Shots := TSteamScreenshotsPlugin(S.FindPlugin(TSteamScreenshotsPlugin));
    if Shots <> nil then
      Say('ISteamScreenshots: hooked by the game ' + BoolToStr(Shots.IsScreenshotsHooked, True));
    Tl := TSteamTimelinePlugin(S.FindPlugin(TSteamTimelinePlugin));
    if Tl <> nil then
    begin
      // strings, a Single and an enum in one call; only visible in a recording
      TlEvent := Tl.AddInstantaneousTimelineEvent(FProgramName, 'Smoke test', 'steam_flag',
        0, 0, k_ETimelineEventClipPriority_None);
      Say('ISteamTimeline: instantaneous event added, handle ' + IntToStr(Int64(TlEvent)));
    end;
    Ugc := TSteamUGCPlugin(S.FindPlugin(TSteamUGCPlugin));
    if Ugc <> nil then
      Say(Format('ISteamUGC: %d subscribed items (%d incl. locally disabled), %d downloaded',
        [Ugc.GetNumSubscribedItems(False), Ugc.GetNumSubscribedItems(True), Ugc.GetNumDownloadedItems]));
    Inp := TSteamInputPlugin(S.FindPlugin(TSteamInputPlugin));
    if (Inp <> nil) and Inp.Start(True) then
    begin
      // The three by-value exports (hand-written ABI shim), called once
      // with action handle 0: Steam returns zeros, a wrong declaration
      // would crash or corrupt the stack here. The plug-in calls Shutdown.
      Inp.RunFrame(False);
      Pads := Inp.ConnectedControllers;
      Pad := 0;
      if Length(Pads) > 0 then
        Pad := Pads[0];
      Dig := Inp.GetDigitalActionData(Pad, 0);
      Ana := Inp.GetAnalogActionData(Pad, 0);
      Mot := Inp.GetMotionData(Pad);
      Say(Format('ISteamInput: %d controller(s); shim calls returned digital %s/%s, analog %.2f/%.2f/%s, motion quat w %.2f',
        [Length(Pads), BoolToStr(Dig.bState, True), BoolToStr(Dig.bActive, True), Ana.x, Ana.y,
         BoolToStr(Ana.bActive, True), Mot.rotQuatW]));
    end
    else
      Say('ISteamInput: not started');
  except
    on E: Exception do
      Say('Plug-in call failed: ' + E.ClassName + ': ' + E.Message);
  end;
end;

procedure TConsoleRunner.ServerLogOn;
var
  G: TSteamGameServerPlugin;
  Dedicated: Boolean;
begin
  G := SteamGameServer1.Plugin;
  if G = nil then
  begin
    Say('Game server: the TSteamGameServer plug-in is not active - no log-on');
    Exit;
  end;
  Dedicated := not SteamAPI1.IsRunning;
  try
    G.SetModDir(SERVER_MOD_DIR);
    G.SetProduct(SERVER_PRODUCT);
    G.SetGameDescription(Format('%s %s server', [SERVER_PRODUCT, IfThen(Dedicated, 'dedicated', 'listen')]));
    G.SetDedicatedServer(Dedicated);
    G.LogOnAnonymous;
    Say(Format('Game server (%s, game port %d, query port %d, version %s): LogOnAnonymous sent - waiting for ' +
      'SteamServersConnected_t (%d)', [IfThen(Dedicated, 'dedicated', 'listen'), SteamAPI1.Steam.GameServerGamePort,
      SteamAPI1.Steam.GameServerQueryPort, SteamAPI1.GameServerVersion, SteamServersConnected_t_k_iCallback]));
  except
    on E: Exception do
      Say('Game server: log-on calls FAILED: ' + E.ClassName + ': ' + E.Message);
  end;
end;

procedure TConsoleRunner.ServerAdvertise;
var
  G: TSteamGameServerPlugin;
  Kind: string;
begin
  G := SteamGameServer1.Plugin;
  if G = nil then
    Exit;
  try
    if SteamAPI1.IsRunning then
      Kind := Format('listen server (%s)', [FProgramName])
    else
      Kind := Format('dedicated server (%s)', [FProgramName]);
    G.SetServerName(Format('%s %s', [SERVER_PRODUCT, Kind]));
    G.SetMapName(SERVER_MAP);
    G.SetMaxPlayerCount(SERVER_MAX_PLAYERS);
    G.SetKeyValue(SERVER_KIND_KEY, Kind);
    G.SetAdvertiseServerActive(True);
    Say(Format('Game server: SteamID %s, secure %s, public IP %s; name "%s %s", map %s, %d slots, rule %s set, ' +
      'advertised - the server browser lists it, Steam answers its queries on port %d',
      [G.GetSteamID.ToString, YesNo(G.BSecure), IPText(G.PublicIPv4), SERVER_PRODUCT, Kind, SERVER_MAP,
       SERVER_MAX_PLAYERS, SERVER_KIND_KEY, SteamAPI1.Steam.GameServerQueryPort]));
  except
    on E: Exception do
      Say('Game server: advertising calls FAILED: ' + E.ClassName + ': ' + E.Message);
  end;
end;

procedure TConsoleRunner.ServerStatus(AUpMs: UInt64);
var
  G: TSteamGameServerPlugin;
begin
  G := SteamGameServer1.Plugin;
  if G = nil then
    Exit;
  try
    Say(Format('Game server: up %d s; logged on %s, secure %s, public IP %s; %d server callbacks so far',
      [Int64(AUpMs div 1000), YesNo(G.BLoggedOn), YesNo(G.BSecure), IPText(G.PublicIPv4),
       SteamAPI1.Steam.ServerDispatcher.CallbacksDispatched]));
  except
    on E: Exception do
      Say('Game server: status calls FAILED: ' + E.ClassName + ': ' + E.Message);
  end;
end;

procedure TConsoleRunner.ServerLogOff;
var
  G: TSteamGameServerPlugin;
begin
  if (SteamGameServer1 = nil) or not SteamAPI1.IsGameServerRunning then
    Exit;
  G := SteamGameServer1.Plugin;
  if G = nil then
    Exit;
  try
    G.SetAdvertiseServerActive(False);
    G.LogOff;
    Say('Game server: advertising off, LogOff sent');
  except
    on E: Exception do
      Say('Game server: log-off calls FAILED: ' + E.ClassName + ': ' + E.Message);
  end;
end;

function TConsoleRunner.Summary: Boolean;
var
  I, Passed: Integer;
  T: string;
begin
  Result := True;
  if FTest <> nil then
  begin
    Passed := 0;
    for I := 0 to CT_COUNT - 1 do
    begin
      T := FTest.RowText[I];
      if StartsStr('PASS', T) then
        Inc(Passed);
      Say(Format('  %-36s %s', [TestNames[I], T]));
    end;
    Say(Format('Component test: %d of %d PASS', [Passed, CT_COUNT]));
    Result := Result and (Passed = CT_COUNT);
  end;
  if FPair <> nil then
  begin
    Passed := 0;
    for I := 0 to PT_COUNT - 1 do
    begin
      T := FPair.RowText[I];
      if StartsStr('PASS', T) then
        Inc(Passed);
      Say(Format('  %-36s %s', [PairTestNames[I], T]));
    end;
    Say(Format('Pair test: %d of %d PASS', [Passed, PT_COUNT]));
    Result := Result and (Passed = PT_COUNT);
  end;
end;

function TConsoleRunner.Run: Integer;
var
  Started, LastTick, LastStatus, NowT, LimitMs: UInt64;
  Testing, Why: string;
  Smoke: Boolean;
begin
  Result := EXIT_OK;
  Smoke := not (FOpt.DoTest or FOpt.DoPair or FOpt.DoServer);
  CreateComponents;
  if FOpt.DoServer and (SteamAPI1.GameServerGamePort = SteamAPI1.GameServerQueryPort) then
  begin
    // A shared port needs the game to answer the queries itself
    // (HandleIncomingPacket), which this console does not
    Say(Format('Command line error: game port and query port are both %d - give them different ports ' +
      '(--port, --query-port)', [SteamAPI1.GameServerGamePort]));
    Exit(EXIT_USAGE);
  end;
  Say(Format('%s: %s, AppID %d, %s, library %s, update mode %s',
    [FProgramName, JobText, APP_ID, CompilerText, TSteamLib.DefaultLibraryName, FOpt.Mode]));
  StartStopWatch(True);
  Say('Press Enter or Ctrl+C to stop');

  if not SteamAPI1.Open then
  begin
    // OnInitFailed (and OnGameServerFailed) have said why; a listen server
    // that fails takes the client with it (all or nothing)
    if FOpt.DoServer then
      Say('The game server needs steamclient from a Steam client installation or SteamCMD - see README');
    Exit(EXIT_STEAM);
  end;

  if Smoke then
    SmokeReport;
  if FOpt.DoServer then
    ServerLogOn;   // Open succeeded, so the server runs (all or nothing)
  if FTest <> nil then
    FTest.Start;
  if FPair <> nil then
    FPair.Start;

  LimitMs := UInt64(FOpt.Seconds) * 1000;
  if Smoke and (LimitMs = 0) then
    LimitMs := PUMP_MS;
  if Smoke then
    Say(Format('Pumping callbacks for %d ms (every %d ms, mode %s, worker thread running: %s)',
      [Int64(LimitMs), TICK_MS, FOpt.Mode, BoolToStr(SteamAPI1.Steam.Threaded, True)]))
  else if LimitMs > 0 then
    Say(Format('Time limit: %d s', [FOpt.Seconds]));

  Started := TestTicks;
  LastTick := Started;
  LastStatus := Started;
  Why := '';
  repeat
    SteamAPI1.Update;   // = RunCallbacks; in mode worker it has nothing to do
    // Waits up to TICK_MS and runs what threads queued for the main thread
    // (mode main; TThread.ForceQueue / Queue of the core and the tests)
    CheckSynchronize(TICK_MS);
    NowT := TestTicks;
    if TicksSince(NowT, LastTick) >= TEST_TICK_MS then
    begin
      LastTick := NowT;
      if (FTest <> nil) and FTest.Running then
        FTest.Tick;
      if (FPair <> nil) and FPair.Running then
        FPair.Tick;
    end;
    if (SteamGameServer1 <> nil) and (TicksSince(NowT, LastStatus) >= STATUS_MS) then
    begin
      LastStatus := NowT;
      ServerStatus(TicksSince(NowT, Started));
    end;

    Testing := '';
    if (FTest <> nil) and FTest.Running then
      Testing := 'component test';
    if (FPair <> nil) and FPair.Running then
      Testing := 'pair test';
    if StopRequested then
      Why := 'stop requested: ' + StopReasonText
    else if FSteamExiting then
      Why := 'the Steam client is exiting'
    else if not (SteamAPI1.IsRunning or SteamAPI1.IsGameServerRunning) then
      Why := 'Steam is no longer running'
    else if (LimitMs > 0) and (TicksSince(NowT, Started) >= LimitMs) then
      Why := Format('%d ms are up', [Int64(LimitMs)])
    else if not Smoke and not FOpt.DoServer and (Testing = '') then
      Why := 'the tests have finished';
  until Why <> '';
  Say(Format('Stopping after %d ms: %s; %d client callbacks, %d server callbacks dispatched',
    [Int64(TicksSince(TestTicks, Started)), Why, SteamAPI1.Steam.Dispatcher.CallbacksDispatched,
     SteamAPI1.Steam.ServerDispatcher.CallbacksDispatched]));

  // Cleanup needs Steam: the tests first, then the server, then Close
  if (FTest <> nil) and FTest.Running then
    FTest.Finish(Why);
  if (FPair <> nil) and FPair.Running then
    FPair.Finish(Why);
  ServerLogOff;
  if not Summary then
    Result := EXIT_TEST_FAILED;
  SteamAPI1.Close;
  Say(Format('Done (exit code %d)', [Result]));
end;

function RunConsoleDemo: Integer;
var
  Opt: TConsoleOptions;
  Err: string;
  Runner: TConsoleRunner;
begin
  Err := ParseOptions(Opt);
  if Err <> '' then
  begin
    Writeln('Command line error: ', Err);
    ShowUsage(ChangeFileExt(ExtractFileName(ParamStr(0)), ''));
    Exit(EXIT_USAGE);
  end;
  if Opt.Help then
  begin
    ShowUsage(ChangeFileExt(ExtractFileName(ParamStr(0)), ''));
    Exit(EXIT_OK);
  end;
  Runner := TConsoleRunner.Create(nil, Opt);
  try
    Result := Runner.Run;
  finally
    Runner.Free;   // frees the tests and the root (Steam shut down if still open)
    StopWatchDone; // a Windows close handler may now let the process end
  end;
end;

initialization
  SayLock := TCriticalSection.Create;

finalization
  SayLock.Free;

end.
