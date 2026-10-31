{ @abstract(Console smoke test for the Steamworks core - no UI framework.)

  Loads the redistributable, initialises Steam for AppID 2275430, prints the
  detected interface versions and ISteamUtils information, pumps callbacks for
  a few seconds (or for the number of seconds given as the first command-line
  parameter, e.g. @code(SteamConsole 60)) and shuts down. Every step is written to the console so the
  output can be pasted back as test evidence.

  The optional second parameter selects how callbacks are pumped (see
  GameEngineIntegration.md); every callback line says which thread ran it:
  @unorderedList(
    @item(@code(manual) (default): the loop calls Steam.Update - main thread.)
    @item(@code(thread): worker thread reads, the loop's Steam.Update
      delivers (sumThread + sdOnUpdate) - main thread.)
    @item(@code(main): worker reads, TThread.Queue hands it to the main
      thread; the loop calls CheckSynchronize (sumThread + sdMainThread) -
      main thread.)
    @item(@code(worker): worker reads and delivers (sumThread +
      sdPumpThread) - worker thread.)
  )
  e.g. @code(SteamConsole 60 thread).

  The same source is intended to build with Free Pascal:
  @longCode(#
  fpc -Mdelphi -Fu../../lib -Fu../../lib/plugins -Fi../../lib -Fusrc SteamConsole.dpr
  #) }
unit uConsoleMain;

// No Steamworks.inc here: the Delphi demo has no path to the library
// sources (it links the packages' DCUs); FPC builds pass -Mdelphi anyway.
{$ifdef FPC}{$mode delphi}{$H+}{$endif}

interface

{ Runs the smoke test. @returns(Process exit code: 0 on success.) }
function RunConsoleDemo: Integer;

implementation

uses
  SysUtils, Classes, SyncObjs, DateUtils, StrUtils,
  Steamworks.Types, Steamworks.SDKTypes, Steamworks.API, Steamworks.Callbacks, Steamworks.Core,
  Steamworks.Plugin.Utils, Steamworks.Plugin.User, Steamworks.Plugin.Friends,
  Steamworks.Plugin.Apps, Steamworks.Plugin.UserStats, Steamworks.Plugin.RemoteStorage,
  Steamworks.Plugin.Screenshots, Steamworks.Plugin.Timeline, Steamworks.Plugin.UGC,
  Steamworks.Plugin.Input;

const
  { AppID of this project on Steam. }
  APP_ID = 2275430;
  { Default time callbacks are pumped, in milliseconds (measured with the clock).
    Override with the first command-line parameter, in seconds. }
  PUMP_MS = 3000;
  { Pump interval, in milliseconds. }
  TICK_MS = 33;
  { Text for each log level. }
  LevelNames: array[TSteamLogLevel] of string = ('debug', 'info', 'warn', 'ERROR');

type
  { Receives core events and writes them to the console. }
  TConsoleSink = class
  public
    { Set when SteamShutdown_t arrives; the pump loop then exits. Written
      by the worker thread in mode @code(worker), hence volatile in spirit:
      the loop only polls it. }
    SteamExiting: Boolean;
    { Core log messages. }
    procedure Log(Sender: TObject; ALevel: TSteamLogLevel; const AMessage: string);
    { Steam debug output. }
    procedure Warning(Sender: TObject; ASeverity: Integer; const AText: string);
    { Every callback. }
    procedure AnyCallback(const AData: TSteamCallbackData);
  end;

var
  { Serialises console output: in mode worker the worker thread writes too,
    and Writeln to the shared console buffer is not thread-safe (unguarded,
    a line was once printed twice). }
  SayLock: TCriticalSection;

procedure Say(const S: string);
begin
  SayLock.Enter;
  try
    Writeln(FormatDateTime('hh:nn:ss.zzz', Now), '  ', S);
    Flush(Output); // keep the evidence even if the process is killed
  finally
    SayLock.Leave;
  end;
end;

procedure TConsoleSink.Log(Sender: TObject; ALevel: TSteamLogLevel; const AMessage: string);
begin
  Say('[' + LevelNames[ALevel] + '] ' + AMessage);
end;

procedure TConsoleSink.Warning(Sender: TObject; ASeverity: Integer; const AText: string);
begin
  Say(Format('Steam debug (severity %d): %s', [ASeverity, AText]));
end;

procedure TConsoleSink.AnyCallback(const AData: TSteamCallbackData);
begin
  if AData.CallbackID = SteamShutdown_t_k_iCallback then
  begin
    Say('SteamShutdown_t received: the Steam client is exiting - shutting down now');
    // What a game should do: save, shut Steam down and quit. Steam terminates
    // a game that is still running about 10 s after this callback.
    SteamExiting := True;
  end;
  Say(Format('Callback %d (%s), %d bytes, on the %s thread',
    [AData.CallbackID, SteamCallbackGroupName(AData.CallbackID), AData.Size,
     IfThen(TThread.CurrentThread.ThreadID = MainThreadID, 'main', 'WORKER')]));
end;

function RunConsoleDemo: Integer;
var
  Sink: TConsoleSink;
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
  I, PumpMs: Integer;
  Started: TDateTime;
  Mode: string;
begin
  Result := 1;
  Sink := TConsoleSink.Create;
  try
    Steam.OnLog := Sink.Log;
    Steam.OnWarning := Sink.Warning;
    Steam.Dispatcher.OnAnyCallback := Sink.AnyCallback;
    Steam.AppID := APP_ID;
    Steam.SetAppIdEnvironment := True;

    Mode := 'manual';
    if ParamCount >= 2 then
      Mode := LowerCase(ParamStr(2));
    if Mode = 'thread' then
      Steam.SetUpdateMode(sumThread, sdOnUpdate, TICK_MS)
    else if Mode = 'main' then
      Steam.SetUpdateMode(sumThread, sdMainThread, TICK_MS)
    else if Mode = 'worker' then
      Steam.SetUpdateMode(sumThread, sdPumpThread, TICK_MS)
    else
    begin
      Mode := 'manual';
      Steam.SetUpdateMode(sumManual, sdMainThread, TICK_MS);
    end;
    Say('Update mode: ' + Mode);

    Say(Format('Steamworks console demo, AppID %d, library %s',
      [APP_ID, TSteamLib.DefaultLibraryName]));
    if not Steam.Initialize then
    begin
      Say(Format('Initialize failed: result %d (%s): %s',
        [Ord(Steam.LastInitResult), SteamInitResultToString(Steam.LastInitResult), Steam.LastError]));
      Exit;
    end;

    Versions := Steam.Versions.ToArray;
    Say(Format('Loaded %s, %d interface versions detected', [TSteamLib.LibraryPath, Length(Versions)]));
    for I := 0 to High(Versions) do
      Say('  ' + Versions[I]);

    U := TSteamUtilsPlugin(Steam.FindPlugin(TSteamUtilsPlugin));
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
      Usr := TSteamUserPlugin(Steam.FindPlugin(TSteamUserPlugin));
      if Usr <> nil then
        Say(Format('ISteamUser: logged on %s, SteamID %s, Steam level %d',
          [BoolToStr(Usr.BLoggedOn, True), Usr.GetSteamID.ToString, Usr.GetPlayerSteamLevel]));
      Fr := TSteamFriendsPlugin(Steam.FindPlugin(TSteamFriendsPlugin));
      if Fr <> nil then
        Say(Format('ISteamFriends: persona "%s", immediate friends %d',
          [Fr.GetPersonaName, Fr.GetFriendCount(k_EFriendFlagImmediate)]));
      Apps := TSteamAppsPlugin(Steam.FindPlugin(TSteamAppsPlugin));
      if Apps <> nil then
        Say(Format('ISteamApps: subscribed %s, game language %s, build id %d',
          [BoolToStr(Apps.BIsSubscribed, True), Apps.GetCurrentGameLanguage, Apps.GetAppBuildId]));
      Stats := TSteamUserStatsPlugin(Steam.FindPlugin(TSteamUserStatsPlugin));
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
      RS := TSteamRemoteStoragePlugin(Steam.FindPlugin(TSteamRemoteStoragePlugin));
      if RS <> nil then
      begin
        QuotaTotal := 0;
        QuotaAvailable := 0;
        RS.GetQuota(QuotaTotal, QuotaAvailable);
        Say(Format('ISteamRemoteStorage: cloud enabled for account %s / app %s, %d files, quota %s of %s bytes free',
          [BoolToStr(RS.IsCloudEnabledForAccount, True), BoolToStr(RS.IsCloudEnabledForApp, True),
           RS.GetFileCount, IntToStr(Int64(QuotaAvailable)), IntToStr(Int64(QuotaTotal))]));
      end;
      Shots := TSteamScreenshotsPlugin(Steam.FindPlugin(TSteamScreenshotsPlugin));
      if Shots <> nil then
        Say('ISteamScreenshots: hooked by the game ' + BoolToStr(Shots.IsScreenshotsHooked, True));
      Tl := TSteamTimelinePlugin(Steam.FindPlugin(TSteamTimelinePlugin));
      if Tl <> nil then
      begin
        // strings, a Single and an enum in one call; only visible in a recording
        TlEvent := Tl.AddInstantaneousTimelineEvent('SteamConsole', 'Smoke test', 'steam_flag',
          0, 0, k_ETimelineEventClipPriority_None);
        Say('ISteamTimeline: instantaneous event added, handle ' + IntToStr(Int64(TlEvent)));
      end;
      Ugc := TSteamUGCPlugin(Steam.FindPlugin(TSteamUGCPlugin));
      if Ugc <> nil then
        Say(Format('ISteamUGC: %d subscribed items (%d incl. locally disabled), %d downloaded',
          [Ugc.GetNumSubscribedItems(False), Ugc.GetNumSubscribedItems(True), Ugc.GetNumDownloadedItems]));
      Inp := TSteamInputPlugin(Steam.FindPlugin(TSteamInputPlugin));
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

    PumpMs := PUMP_MS;
    if (ParamCount >= 1) and (StrToIntDef(ParamStr(1), 0) > 0) then
      PumpMs := StrToIntDef(ParamStr(1), 0) * 1000;
    Say(Format('Pumping callbacks for %d ms (every %d ms, mode %s, worker thread running: %s)',
      [PumpMs, TICK_MS, Mode, BoolToStr(Steam.Threaded, True)]));
    Started := Now;
    while (MilliSecondsBetween(Now, Started) < PumpMs) and not Sink.SteamExiting do
    begin
      Steam.Update;   // = RunCallbacks; in mode worker it has nothing to do
      if Mode = 'main' then
        CheckSynchronize(TICK_MS)   // runs what the worker queued for the main thread
      else
        Sleep(TICK_MS);
    end;
    Say(Format('Pumped for %d ms; %d callbacks dispatched%s',
      [MilliSecondsBetween(Now, Started), Steam.Dispatcher.CallbacksDispatched,
       IfThen(Sink.SteamExiting, ' (stopped early: Steam is exiting)', '')]));

    Steam.Shutdown;
    Result := 0;
  finally
    Steam.OnLog := nil;
    Steam.OnWarning := nil;
    Steam.Dispatcher.OnAnyCallback := nil;
    Sink.Free;
  end;
end;

initialization
  SayLock := TCriticalSection.Create;

finalization
  SayLock.Free;

end.
