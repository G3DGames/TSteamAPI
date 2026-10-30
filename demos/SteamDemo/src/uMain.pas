{ @abstract(Main form of the FMX Steamworks demo.)

  Creates a @code(TSteamworksFMX) in code (no design-time package needed),
  starts and stops Steam on demand and logs everything the core reports, so
  the Debug log can be pasted back as test evidence. }
unit uMain;

interface

uses
  System.SysUtils, System.StrUtils, System.Types, System.UITypes, System.Classes,
  FMX.Types, FMX.Controls, FMX.Forms, FMX.Graphics, FMX.Dialogs, FMX.StdCtrls,
  FMX.Controls.Presentation, FMX.Memo.Types, FMX.ScrollBox, FMX.Memo,
  Steamworks.Types, Steamworks.Callbacks, Steamworks.Core, Steamworks.FMX,
  Steamworks.Plugin.Utils;

const
  { AppID of this project on Steam. }
  APP_ID = 2275430;

type
  { Demo main form. }
  TfrmMain = class(TForm)
    { Toolbar holding the buttons. }
    pnlTop: TPanel;
    { Starts Steam. }
    btnStart: TButton;
    { Logs interface versions and ISteamUtils information. }
    btnInfo: TButton;
    { Shuts Steam down. }
    btnStop: TButton;
    { Copies the log to the clipboard. }
    btnCopy: TButton;
    { Log output. }
    memLog: TMemo;
    { Creates and configures the Steam component. }
    procedure FormCreate(Sender: TObject);
    { Shuts Steam down while the form's controls still exist. }
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
    { Handler of @link(btnStart). }
    procedure btnStartClick(Sender: TObject);
    { Handler of @link(btnInfo). }
    procedure btnInfoClick(Sender: TObject);
    { Handler of @link(btnStop). }
    procedure btnStopClick(Sender: TObject);
    { Handler of @link(btnCopy). }
    procedure btnCopyClick(Sender: TObject);
  private
    { The Steam component (owned by the form). }
    FSteam: TSteamworksFMX;
    { Appends a time-stamped line to @link(memLog). }
    procedure AddLog(const S: string);
    { Core log messages. }
    procedure SteamLog(Sender: TObject; ALevel: TSteamLogLevel; const AMessage: string);
    { Steam started. }
    procedure SteamInitialized(Sender: TObject);
    { Steam failed to start. }
    procedure SteamInitFailed(Sender: TObject; AResult: Integer; const AMessage: string);
    { Steam shut down. }
    procedure SteamShutdown(Sender: TObject);
    { Steam client exiting. }
    procedure SteamClientExit(Sender: TObject);
    { Steam debug output. }
    procedure SteamWarning(Sender: TObject; ASeverity: Integer; const AText: string);
    { Every callback (diagnostics). }
    procedure SteamCallback(Sender: TObject; const AData: TSteamCallbackData);
  end;

var
  { The main form instance. }
  frmMain: TfrmMain;

implementation

{$R *.fmx}

uses
  FMX.Platform, Steamworks.API;

const
  LevelNames: array[TSteamLogLevel] of string = ('debug', 'info', 'warn', 'ERROR');

procedure TfrmMain.FormCreate(Sender: TObject);
begin
  FSteam := TSteamworksFMX.Create(Self);
  FSteam.AppID := APP_ID;
{$IFDEF DEBUG}
  // Development: no steam_appid.txt needed, never relaunch through Steam
  FSteam.SetAppIdEnvironment := True;
  FSteam.RestartIfNecessary := False;
{$ELSE}
  FSteam.RestartIfNecessary := True;
{$ENDIF}
  FSteam.OnLog := SteamLog;
  FSteam.OnInitialized := SteamInitialized;
  FSteam.OnInitFailed := SteamInitFailed;
  FSteam.OnShutdown := SteamShutdown;
  FSteam.OnSteamShutdown := SteamClientExit;
  FSteam.OnWarning := SteamWarning;
  FSteam.OnCallback := SteamCallback;
  AddLog(Format('Steamworks demo, AppID %d, %d plug-in class(es) linked',
    [APP_ID, Length(TSteamworks.RegisteredPlugins)]));
end;

procedure TfrmMain.FormClose(Sender: TObject; var Action: TCloseAction);
begin
  FSteam.Close;
end;

procedure TfrmMain.AddLog(const S: string);
begin
  memLog.Lines.Add(FormatDateTime('hh:nn:ss.zzz', Now) + '  ' + S);
  memLog.GoToTextEnd;
end;

procedure TfrmMain.btnStartClick(Sender: TObject);
begin
  if FSteam.Open then
    AddLog('Open returned True: Steam is running')
  else
    AddLog('Open returned False: Steam did not start');
end;

procedure TfrmMain.btnStopClick(Sender: TObject);
begin
  FSteam.Close;
end;

procedure TfrmMain.btnCopyClick(Sender: TObject);
var
  Svc: IFMXClipboardService;
begin
  if TPlatformServices.Current.SupportsPlatformService(IFMXClipboardService, Svc) then
  begin
    Svc.SetClipboard(memLog.Text);
    AddLog('Log copied to clipboard');
  end;
end;

procedure TfrmMain.btnInfoClick(Sender: TObject);
var
  U: TSteamUtilsPlugin;
  V: string;
begin
  if not FSteam.IsRunning then
  begin
    AddLog('Info: Steam is not running - press Start first');
    Exit;
  end;
  AddLog(Format('Library %s: %d interface versions detected',
    [TSteamAPI.LibraryPath, FSteam.Steam.Versions.Count]));
  for V in FSteam.Steam.Versions.ToArray do
    AddLog('  ' + V);
  if FSteam.Steam.Client <> nil then
    AddLog('ISteamClient ' + FSteam.Steam.Client.Version +
      ', IPC calls since last query: ' + UIntToStr(FSteam.Steam.Client.GetIPCCallCount))
  else
    AddLog('ISteamClient was not created');

  U := FSteam.Steam.Plugin<TSteamUtilsPlugin>;
  if U = nil then
  begin
    AddLog('ISteamUtils plug-in is not active');
    Exit;
  end;
  AddLog(Format('ISteamUtils: AppID %d, country %s, UI language %s',
    [U.AppID, U.IPCountry, U.SteamUILanguage]));
  AddLog('Server time (UTC): ' + DateTimeToStr(U.ServerTime));
  AddLog('Overlay enabled: ' + BoolToStr(U.IsOverlayEnabled, True));
  AddLog('Battery: ' + IntToStr(U.CurrentBatteryPower) + ' (255 = mains power)');
  AddLog('Big Picture: ' + BoolToStr(U.IsSteamInBigPictureMode, True));
  if U.HasSteamHardwareDetection then
    AddLog(Format('Steam hardware type: %d, under Proton: %s',
      [U.SteamHardwareType, BoolToStr(U.IsRunningUnderProton, True)]))
  else
    AddLog('IsRunningOnSteamHardware is not exported (redistributable older than 1.65)');
end;

procedure TfrmMain.SteamLog(Sender: TObject; ALevel: TSteamLogLevel; const AMessage: string);
begin
  AddLog('[' + LevelNames[ALevel] + '] ' + AMessage);
end;

procedure TfrmMain.SteamInitialized(Sender: TObject);
begin
  AddLog(Format('OnInitialized: pipe %d, user %d, %d plug-in(s) active',
    [FSteam.Steam.Pipe, FSteam.Steam.User, FSteam.Steam.PluginCount]));
end;

procedure TfrmMain.SteamInitFailed(Sender: TObject; AResult: Integer; const AMessage: string);
begin
  AddLog(Format('OnInitFailed: result %d (%s): %s',
    [AResult, SteamInitResultToString(ESteamAPIInitResult(AResult)), AMessage]));
end;

procedure TfrmMain.SteamShutdown(Sender: TObject);
begin
  AddLog('OnShutdown: SteamAPI shut down');
end;

procedure TfrmMain.SteamClientExit(Sender: TObject);
begin
  AddLog('OnSteamShutdown: the Steam client is exiting');
end;

procedure TfrmMain.SteamWarning(Sender: TObject; ASeverity: Integer; const AText: string);
begin
  AddLog(Format('Steam debug (severity %d): %s', [ASeverity, AText]));
end;

procedure TfrmMain.SteamCallback(Sender: TObject; const AData: TSteamCallbackData);
begin
  AddLog(Format('Callback %d, %d bytes%s', [AData.CallbackID, AData.Size,
    IfThen(AData.IsCallResult, ', call result', '')]));
end;

end.
