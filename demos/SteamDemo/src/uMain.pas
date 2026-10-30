{ @abstract(Main form of the FMX Steamworks demo.)

  Creates a @code(TSteamAPI) and a @code(TSteamFriends) component in code (no
  design-time package needed),
  starts and stops Steam on demand and logs everything the core reports, so
  the Debug log can be pasted back as test evidence. Every log line is also
  appended to SteamDemo.log (next to the executable; the documents folder on
  Android) as it is written, so the log survives if the process is killed. }
unit uMain;

interface

uses
  System.SysUtils, System.StrUtils, System.Types, System.UITypes, System.Classes,
  FMX.Types, FMX.Controls, FMX.Forms, FMX.Graphics, FMX.Dialogs, FMX.StdCtrls,
  FMX.Controls.Presentation, FMX.Memo.Types, FMX.ScrollBox, FMX.Memo,
  Steamworks.Types, Steamworks.SDKTypes, Steamworks.Callbacks, Steamworks.Core, Steamworks.Components,
  Steamworks.FMX,
  Steamworks.Plugin.Utils, Steamworks.Plugin.User, Steamworks.Plugin.Friends,
  Steamworks.Plugin.Apps, Steamworks.Plugin.UserStats;

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
    { The Steam root component (owned by the form). }
    FSteam: TSteamAPI;
    { ISteamFriends component linked to @link(FSteam); its
      OnPersonaStateChange shows the typed callback events. }
    FFriends: TSteamFriends;
    { Log file every line is appended to; '' if it cannot be written. }
    FLogFile: string;
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
    { TSteamFriends.OnPersonaStateChange (callback 304). }
    procedure FriendPersonaChanged(Sender: TObject; const AData: PersonaStateChange_t);
  end;

var
  { The main form instance. }
  frmMain: TfrmMain;

implementation

{$R *.fmx}

uses
  System.IOUtils, FMX.Platform, Steamworks.API;

const
  LevelNames: array[TSteamLogLevel] of string = ('debug', 'info', 'warn', 'ERROR');

procedure TfrmMain.FormCreate(Sender: TObject);
begin
{$IFDEF ANDROID}
  FLogFile := TPath.Combine(TPath.GetDocumentsPath, 'SteamDemo.log');
{$ELSE}
  FLogFile := TPath.Combine(ExpandFileName(ExtractFilePath(ParamStr(0))), 'SteamDemo.log');
{$ENDIF}
  try
    TFile.WriteAllText(FLogFile, '');
  except
    FLogFile := '';
  end;
  FSteam := TSteamAPI.Create(Self);
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
  // A plug-in component: linked to the root, attached while Steam runs
  FFriends := TSteamFriends.Create(Self);
  FFriends.SteamAPI := FSteam;
  FFriends.OnPersonaStateChange := FriendPersonaChanged;
  AddLog(Format('Steamworks demo, AppID %d, %d plug-in class(es) linked',
    [APP_ID, Length(TSteamworks.RegisteredPlugins)]));
  if FLogFile <> '' then
    AddLog('Log file: ' + FLogFile)
  else
    AddLog('Log file could not be created; log is on screen only');
end;

procedure TfrmMain.FormClose(Sender: TObject; var Action: TCloseAction);
begin
  AddLog(Format('FormClose: window closing (Steam running: %s)', [BoolToStr(FSteam.IsRunning, True)]));
  FSteam.Close;
end;

procedure TfrmMain.AddLog(const S: string);
var
  Line: string;
begin
  Line := FormatDateTime('hh:nn:ss.zzz', Now) + '  ' + S;
  memLog.Lines.Add(Line);
  memLog.GoToTextEnd;
  if FLogFile <> '' then
  try
    // Open, append, close per line: nothing is lost if the process is killed
    TFile.AppendAllText(FLogFile, Line + sLineBreak);
  except
    FLogFile := '';
  end;
end;

procedure TfrmMain.btnStartClick(Sender: TObject);
begin
  AddLog('Start pressed');
  if FSteam.Open then
    AddLog('Open returned True: Steam is running')
  else
    AddLog('Open returned False: Steam did not start');
end;

procedure TfrmMain.btnStopClick(Sender: TObject);
begin
  AddLog('Stop pressed');
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
  Usr: TSteamUserPlugin;
  Fr: TSteamFriendsPlugin;
  Apps: TSteamAppsPlugin;
  Stats: TSteamUserStatsPlugin;
  Id: TSteamID;
  V: string;
begin
  if not FSteam.IsRunning then
  begin
    AddLog('Info: Steam is not running - press Start first');
    Exit;
  end;
  AddLog(Format('Library %s: %d interface versions detected',
    [TSteamLib.LibraryPath, FSteam.Steam.Versions.Count]));
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
  // Each block logs its own failure (a plug-in method raises ESteamworksError
  // when the loaded library lacks its export) and the next block still runs.
  try
    AddLog(Format('ISteamUtils: AppID %d, country %s, UI language %s',
      [U.GetAppID, U.GetIPCountry, U.GetSteamUILanguage]));
    AddLog('Server time (UTC): ' + FormatDateTime('yyyy-mm-dd hh:nn:ss', U.ServerTime));
    AddLog('Overlay enabled: ' + BoolToStr(U.IsOverlayEnabled, True));
    AddLog('Battery: ' + IntToStr(U.GetCurrentBatteryPower) + ' (255 = mains power)');
    AddLog('Big Picture: ' + BoolToStr(U.IsSteamInBigPictureMode, True));
    if Assigned(U.Flat.IsRunningOnSteamHardware) then
      AddLog(Format('Steam hardware type: %d, under Proton: %s',
        [Ord(U.IsRunningOnSteamHardware), BoolToStr(U.IsRunningUnderProton, True)]))
    else
      AddLog('IsRunningOnSteamHardware is not exported (redistributable older than 1.65)');
  except
    on E: Exception do AddLog('ISteamUtils failed: ' + E.Message);
  end;

  Usr := FSteam.Steam.Plugin<TSteamUserPlugin>;
  if Usr = nil then
    AddLog('ISteamUser plug-in is not active')
  else
  try
    Id := Usr.GetSteamID;
    AddLog(Format('ISteamUser: logged on %s, SteamID %s (account %d, valid %s), Steam level %d',
      [BoolToStr(Usr.BLoggedOn, True), Id.ToString, Id.AccountID, BoolToStr(Id.IsValid, True),
       Usr.GetPlayerSteamLevel]));
  except
    on E: Exception do AddLog('ISteamUser failed: ' + E.Message);
  end;

  Fr := FSteam.Steam.Plugin<TSteamFriendsPlugin>;
  if Fr = nil then
    AddLog('ISteamFriends plug-in is not active')
  else
  try
    AddLog(Format('ISteamFriends: persona "%s", state %d, immediate friends %d',
      [Fr.GetPersonaName, Ord(Fr.GetPersonaState), Fr.GetFriendCount(k_EFriendFlagImmediate)]));
  except
    on E: Exception do AddLog('ISteamFriends failed: ' + E.Message);
  end;

  Apps := FSteam.Steam.Plugin<TSteamAppsPlugin>;
  if Apps = nil then
    AddLog('ISteamApps plug-in is not active')
  else
  try
    AddLog(Format('ISteamApps: subscribed %s, game language %s, build id %d, owner %s',
      [BoolToStr(Apps.BIsSubscribed, True), Apps.GetCurrentGameLanguage, Apps.GetAppBuildId,
       Apps.GetAppOwner.ToString]));
  except
    on E: Exception do AddLog('ISteamApps failed: ' + E.Message);
  end;

  Stats := FSteam.Steam.Plugin<TSteamUserStatsPlugin>;
  if Stats = nil then
    AddLog('ISteamUserStats plug-in is not active')
  else
  try
    AddLog(Format('ISteamUserStats: %d achievements defined for this app',
      [Stats.GetNumAchievements]));
  except
    on E: Exception do AddLog('ISteamUserStats failed: ' + E.Message);
  end;
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
  AddLog(Format('OnSteamShutdown: the Steam client is exiting; SteamAPI shuts down next: %s ' +
    '(the demo keeps running; press Start once Steam is back)', [BoolToStr(FSteam.ShutdownOnSteamExit, True)]));
end;

procedure TfrmMain.SteamWarning(Sender: TObject; ASeverity: Integer; const AText: string);
begin
  AddLog(Format('Steam debug (severity %d): %s', [ASeverity, AText]));
end;

procedure TfrmMain.SteamCallback(Sender: TObject; const AData: TSteamCallbackData);
begin
  AddLog(Format('Callback %d (%s), %d bytes%s', [AData.CallbackID,
    SteamCallbackGroupName(AData.CallbackID), AData.Size,
    IfThen(AData.IsCallResult, ', call result', '')]));
end;

procedure TfrmMain.FriendPersonaChanged(Sender: TObject; const AData: PersonaStateChange_t);
begin
  AddLog(Format('TSteamFriends.OnPersonaStateChange: SteamID %s, change flags $%x (attached %s)',
    [TSteamID.Create(AData.m_ulSteamID).ToString, AData.m_nChangeFlags,
     BoolToStr(FFriends.Attached, True)]));
end;

end.
