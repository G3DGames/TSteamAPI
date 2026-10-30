{ @abstract(Console smoke test for the Steamworks core - no UI framework.)

  Loads the redistributable, initialises Steam for AppID 2275430, prints the
  detected interface versions and ISteamUtils information, pumps callbacks for
  a few seconds and shuts down. Every step is written to the console so the
  output can be pasted back as test evidence.

  The same source is intended to build with Free Pascal:
  @longCode(#
  fpc -Mdelphi -Fu../../lib -Fu../../lib/plugins -Fi../../lib -Fusrc SteamConsole.dpr
  #) }
unit uConsoleMain;

{$I Steamworks.inc}

interface

{ Runs the smoke test. @returns(Process exit code: 0 on success.) }
function RunConsoleDemo: Integer;

implementation

uses
  SysUtils, Classes,
  Steamworks.Types, Steamworks.API, Steamworks.Callbacks, Steamworks.Core,
  Steamworks.Plugin.Utils;

const
  { AppID of this project on Steam. }
  APP_ID = 2275430;
  { How long callbacks are pumped, in milliseconds. }
  PUMP_MS = 3000;
  { Pump interval, in milliseconds. }
  TICK_MS = 33;
  { Text for each log level. }
  LevelNames: array[TSteamLogLevel] of string = ('debug', 'info', 'warn', 'ERROR');

type
  { Receives core events and writes them to the console. }
  TConsoleSink = class
  public
    { Core log messages. }
    procedure Log(Sender: TObject; ALevel: TSteamLogLevel; const AMessage: string);
    { Steam debug output. }
    procedure Warning(Sender: TObject; ASeverity: Integer; const AText: string);
    { Every callback. }
    procedure AnyCallback(const AData: TSteamCallbackData);
  end;

procedure Say(const S: string);
begin
  Writeln(FormatDateTime('hh:nn:ss.zzz', Now), '  ', S);
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
  Say(Format('Callback %d, %d bytes', [AData.CallbackID, AData.Size]));
end;

function RunConsoleDemo: Integer;
var
  Sink: TConsoleSink;
  U: TSteamUtilsPlugin;
  V: string;
  Versions: TSteamStringArray;
  I, Elapsed: Integer;
begin
  Result := 1;
  Sink := TConsoleSink.Create;
  try
    Steam.OnLog := Sink.Log;
    Steam.OnWarning := Sink.Warning;
    Steam.Dispatcher.OnAnyCallback := Sink.AnyCallback;
    Steam.AppID := APP_ID;
    Steam.SetAppIdEnvironment := True;

    Say(Format('Steamworks console demo, AppID %d, library %s',
      [APP_ID, TSteamAPI.DefaultLibraryName]));
    if not Steam.Initialize then
    begin
      Say(Format('Initialize failed: result %d (%s): %s',
        [Ord(Steam.LastInitResult), SteamInitResultToString(Steam.LastInitResult), Steam.LastError]));
      Exit;
    end;

    Versions := Steam.Versions.ToArray;
    Say(Format('Loaded %s, %d interface versions detected', [TSteamAPI.LibraryPath, Length(Versions)]));
    for I := 0 to High(Versions) do
      Say('  ' + Versions[I]);

    U := TSteamUtilsPlugin(Steam.FindPlugin(TSteamUtilsPlugin));
    if U <> nil then
    begin
      V := U.SteamUILanguage;
      Say(Format('ISteamUtils: AppID %d, country %s, language %s, overlay %s',
        [U.AppID, U.IPCountry, V, BoolToStr(U.IsOverlayEnabled, True)]));
      Say('Server time (UTC): ' + DateTimeToStr(U.ServerTime));
    end
    else
      Say('ISteamUtils plug-in is not active');

    Say(Format('Pumping callbacks for %d ms', [PUMP_MS]));
    Elapsed := 0;
    while Elapsed < PUMP_MS do
    begin
      Steam.RunCallbacks;
      Sleep(TICK_MS);
      Inc(Elapsed, TICK_MS);
    end;
    Say(Format('%d callbacks dispatched', [Steam.Dispatcher.CallbacksDispatched]));

    Steam.Shutdown;
    Result := 0;
  finally
    Steam.OnLog := nil;
    Steam.OnWarning := nil;
    Steam.Dispatcher.OnAnyCallback := nil;
    Sink.Free;
  end;
end;

end.
