{ @abstract(Main form of the FMX Steamworks demo.)

  Everything is on the form (uMain.fmx): the @code(TSteamAPI) root, the
  @code(TSteamFriends) / @code(TSteamUserStats) plug-in components with their
  events wired in the form file, and the UI. Open it in the IDE with the
  design packages installed (dclSteamworks, dclSteamworksFMX) to see them;
  only the Debug-only settings are made in FormCreate. Five tabs: Output (the
  log), Personal (the user's avatar, persona, Steam ids, level, country and the
  friends list with avatars), Achievements (icons, unlock state), Components
  (the base test of the other plug-in components - Utils, User, Apps,
  RemoteStorage, Screenshots, Timeline, UGC, Matchmaking, Parties, Music,
  HTTP, HTMLSurface, Inventory, Video, ParentalSettings, RemotePlay,
  Networking, NetworkingSockets, NetworkingMessages, NetworkingUtils,
  MatchmakingServers: demos/Shared/SteamComponentTest.pas, the same test as
  SteamDemoVCL's / SteamDemoLCL's; that unit creates the components itself;
  Test components runs it, see btnTestClick) and Two users
  (demos/Shared/SteamPairTest.pas, Pair test). It
  starts and stops Steam on demand and logs everything the core reports, so
  the Debug log can be pasted back as test evidence. The buttons are enabled
  only when they make sense (Start while Steam is stopped, the others while
  it runs). File menu: Auto Start Steam (on / off, saved per user - see
  SettingsFolder), Take Screenshot (this window to Steam), Copy Log, Send log to receiver
  (optional, nothing to do with Steam: streams the log to a LogReceiver,
  demos/Shared/DemoRemoteLog.pas), Exit; on Linux FmxLinuxMenu swaps the menu for
  FMX's own menu bar. Every log line is also
  appended to SteamDemo.log (next to the executable; the documents folder on
  Android) as it is written, so the log survives if the process is killed. }
unit uMain;

interface

uses
  // Winapi.Windows FIRST of all units (interface, not implementation: a unit
  // listed later wins on a shared name - FMX.Graphics' TBitmap, SysUtils'
  // DeleteFile - and implementation units come after all of these):
  // SysUtils' RenameFile is inlined only with it (H2443)
  {$IFDEF MSWINDOWS}Winapi.Windows,{$ENDIF}
  System.SysUtils, System.StrUtils, System.Types, System.UITypes, System.Classes,
  System.Generics.Collections,
  FMX.Types, FMX.Controls, FMX.Forms, FMX.Graphics, FMX.Dialogs, FMX.StdCtrls,
  FMX.Controls.Presentation, FMX.Memo.Types, FMX.ScrollBox, FMX.Memo,
  FMX.Layouts, FMX.Objects, FMX.ListBox, FMX.TabControl, FMX.Menus,
  Steamworks.Types, Steamworks.SDKTypes, Steamworks.Callbacks, Steamworks.Core, Steamworks.Components,
  Steamworks.FMX,
  Steamworks.Plugin.Utils, Steamworks.Plugin.User, Steamworks.Plugin.Friends,
  Steamworks.Plugin.Apps, Steamworks.Plugin.UserStats, Steamworks.Plugin.RemoteStorage,
  Steamworks.Plugin.Screenshots, Steamworks.Plugin.Timeline, Steamworks.Plugin.UGC,
  SteamComponentTest, SteamPairTest,
  // optional remote logging (File > Send log to receiver; nothing to do
  // with Steam - RemoteLogging/README.md)
  DemoRemoteLog;

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
    { Runs the component test (Components tab). }
    btnTest: TButton;
    { Runs the two-user test (Two users tab; press it on both machines). }
    btnPair: TButton;
    { Main menu (only the File menu). On Linux FormCreate replaces it with
      FMX's own menu bar (FmxLinuxMenu) and this field becomes @nil; the
      item fields below then point at the copies. }
    MainMenu1: TMainMenu;
    { The File menu. }
    mnuFile: TMenuItem;
    { Auto Start Steam: on / off (the state is in the text, which every
      platform's menu shows). }
    mnuAutoStart: TMenuItem;
    { Writes a screenshot of this window to Steam (enabled while Steam runs). }
    mnuTakeScreenshot: TMenuItem;
    { Copies the log to the clipboard. }
    mnuCopyLog: TMenuItem;
    { Send log to receiver / Stop sending log (@link(FRemote); the state is
      in the text). }
    mnuRemoteLog: TMenuItem;
    { Separator above Exit. }
    mnuSep1: TMenuItem;
    { Closes the program. }
    mnuExit: TMenuItem;
    { Starts Steam once the window is up when Auto Start Steam is on
      (enabled by FormCreate, disables itself). }
    tmAutoStart: TTimer;
    { Tabs: Output (the log), Personal, Achievements, Components. }
    tabMain: TTabControl;
    { Output tab. }
    tiOutput: TTabItem;
    { Log output. }
    memLog: TMemo;
    { Personal tab. }
    tiPersonal: TTabItem;
    { Top of the Personal tab: avatar and details. }
    layPersonalTop: TLayout;
    { The user's large avatar. }
    imgAvatar: TImage;
    { The user's persona, Steam ids, level, ... }
    lbInfo: TListBox;
    { Caption above the friends list. }
    lblFriends: TLabel;
    { The user's friends with their avatars; each item's TagString is the
      friend's SteamID. }
    lbFriends: TListBox;
    { Achievements tab. }
    tiAchievements: TTabItem;
    { The app's achievements; each item's TagString is the API name. }
    lbAchievements: TListBox;
    { Components tab. }
    tiComponents: TTabItem;
    { One row per tested component: its name and PASS / FAIL / waiting with
      details (item I = CT_ constant I of SteamComponentTest). }
    lbComponents: TListBox;
    { Two users tab. }
    tiPair: TTabItem;
    { One row per two-user test (item I = PT_ constant I). }
    lbPair: TListBox;
    { Ticks the two-user test once a second while it runs. }
    tmPair: TTimer;
    { Ticks the component test once a second (overdue answers); enabled
      only while the test runs. }
    tmTests: TTimer;
    { The Steam root component. Active is False in the form: the Start button
      opens Steam. }
    SteamAPI1: TSteamAPI;
    { ISteamFriends component linked to @link(SteamAPI1); its typed events
      show persona changes and loaded avatars. }
    SteamFriends1: TSteamFriends;
    { ISteamUserStats component: stats received, achievement icons fetched. }
    SteamUserStats1: TSteamUserStats;
    { Debug-only settings and the log file. }
    procedure FormCreate(Sender: TObject);
    { Stops the timers. }
    procedure FormDestroy(Sender: TObject);
    { Shuts Steam down while the form's controls still exist. }
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
    { Handler of @link(btnStart). }
    procedure btnStartClick(Sender: TObject);
    { Handler of @link(btnInfo). }
    procedure btnInfoClick(Sender: TObject);
    { Handler of @link(btnStop). }
    procedure btnStopClick(Sender: TObject);
    { File > Auto Start Steam: toggles and saves the setting. }
    procedure mnuAutoStartClick(Sender: TObject);
    { File > Take Screenshot: this window to the user's Steam screenshots. }
    procedure mnuTakeScreenshotClick(Sender: TObject);
    { File > Copy Log: the log to the clipboard. }
    procedure mnuCopyLogClick(Sender: TObject);
    { File > Send log to receiver: starts / stops sending the log to a
      LogReceiver (@link(FRemote)). }
    procedure mnuRemoteLogClick(Sender: TObject);
    { File > Exit. }
    procedure mnuExitClick(Sender: TObject);
    { Handler of @link(tmAutoStart): starts Steam once. }
    procedure tmAutoStartTimer(Sender: TObject);
    { SteamAPI1.OnLog: core log messages. }
    procedure SteamLog(Sender: TObject; ALevel: TSteamLogLevel; const AMessage: string);
    { SteamAPI1.OnInitialized: Steam started. }
    procedure SteamInitialized(Sender: TObject);
    { SteamAPI1.OnInitFailed: Steam failed to start. }
    procedure SteamInitFailed(Sender: TObject; AResult: Integer; const AMessage: string);
    { SteamAPI1.OnShutdown: Steam shut down. }
    procedure SteamShutdown(Sender: TObject);
    { SteamAPI1.OnSteamShutdown: the Steam client is exiting. }
    procedure SteamClientExit(Sender: TObject);
    { SteamAPI1.OnWarning: Steam debug output. }
    procedure SteamWarning(Sender: TObject; ASeverity: Integer; const AText: string);
    { SteamAPI1.OnCallback: every callback (diagnostics). }
    procedure SteamCallback(Sender: TObject; const AData: TSteamCallbackData);
    { SteamFriends1.OnPersonaStateChange (callback 304). }
    procedure FriendPersonaChanged(Sender: TObject; const AData: PersonaStateChange_t);
    { SteamFriends1.OnAvatarImageLoaded (callback 334): a requested avatar arrived. }
    procedure FriendAvatarLoaded(Sender: TObject; const AData: AvatarImageLoaded_t);
    { SteamUserStats1.OnUserStatsReceived (callback 1101): refresh the list. }
    procedure StatsReceived(Sender: TObject; const AData: UserStatsReceived_t);
    { SteamUserStats1.OnUserAchievementIconFetched (callback 1109). }
    procedure AchievementIconFetched(Sender: TObject; const AData: UserAchievementIconFetched_t);
    { Handler of @link(btnTest): runs the component test (reads, actions and
      one or more callbacks / call results per component). }
    procedure btnTestClick(Sender: TObject);
    { Handler of @link(tmTests): reports overdue answers, ends the test. }
    procedure tmTestsTimer(Sender: TObject);
    { Pair test button. }
    procedure btnPairClick(Sender: TObject);
    { Handler of @link(tmPair). }
    procedure tmPairTimer(Sender: TObject);
  private
    { Log file every line is appended to; '' if it cannot be written. }
    FLogFile: string;
    { Auto Start Steam setting (File menu), saved in @link(FSettingsFile). }
    FAutoStart: Boolean;
    { The per-user settings file (SteamDemo.ini in SettingsFolder). }
    FSettingsFile: string;
    { TThread.GetTickCount when FormCreate ran: the auto start logs how long
      after it the window's message loop let its timer fire. }
    FCreateTicks: Cardinal;
    { The two-user test (demos/Shared/SteamPairTest.pas; creates its own six
      components). }
    FPair: TSteamPairTest;
    { The component test (demos/Shared/SteamComponentTest.pas; creates its
      own plug-in components). }
    FTest: TSteamComponentTest;
    { File > Send log to receiver (demos/Shared/DemoRemoteLog.pas; optional,
      nothing to do with Steam); every log line goes to it. }
    FRemote: TDemoRemoteLog;
    { FRemote.OnChanged: shows its state in @link(mnuRemoteLog)'s text. }
    procedure RemoteLogChanged(Sender: TObject);
    { Starts Steam (Start button or Auto Start Steam) and logs AWhy. }
    procedure StartSteam(const AWhy: string);
    { Enables the buttons that make sense now: Start while Steam is not
      running, Show info / Stop / Test components (and File > Take
      Screenshot) while it is. }
    procedure UpdateControls;
    { Shows the Auto Start Steam state in its menu item's text. }
    procedure UpdateAutoStartText;
    { Reads @link(FAutoStart) from the settings file (off when there is
      none or it cannot be read; the reason is logged). }
    procedure LoadSettings;
    { Writes @link(FAutoStart) to the settings file, creating its folder. }
    procedure SaveSettings;
    { Fills @link(lbComponents) with one row per tested component (names
      and texts from the component test). }
    procedure FillTestList;
    { Fills @link(lbPair) with one row per two-user test. }
    procedure FillPairList;
    { FPair.OnRowChanged. }
    procedure PairRow(AIndex: Integer; const AText: string);
    { FPair.OnFinished: stops @link(tmPair). }
    procedure PairFinished(Sender: TObject);
    { FTest.OnRowChanged. }
    procedure TestRow(AIndex: Integer; const AText: string);
    { FTest.OnFinished: stops @link(tmTests). }
    procedure TestFinished(Sender: TObject);
    { FTest.OnScreenshotRequested: writes this window. }
    procedure TestScreenshotRequested(Sender: TObject);
    { Captures this window with SteamFormToRGB (Steamworks.FMX), writes it
      with WriteScreenshot and logs it (File > Take Screenshot, and a
      request while screenshots are hooked - FTest.OnScreenshotRequested).
      @returns(The screenshot handle, 0 when the capture failed or Steam
        refused it.) }
    function WriteFormScreenshot(AShots: TSteamScreenshotsPlugin): ScreenshotHandle;
    { Appends a time-stamped line to @link(memLog). }
    procedure AddLog(const S: string);
    { Adds a Text / Detail row to @link(lbInfo). }
    procedure AddInfo(const AName, AValue: string);
    { Fills the Personal tab: avatar, persona, ids, friends. }
    procedure LoadPersonal;
    { Puts an avatar into the friend item of ASteamID, if listed. }
    procedure ShowFriendAvatar(const ASteamID: TSteamID; AImage: Integer);
    { Fills @link(lbAchievements) from ISteamUserStats. }
    procedure LoadAchievements;
  end;

var
  { The main form instance. }
  frmMain: TfrmMain;

implementation

{$R *.fmx}

uses
  System.IOUtils, System.DateUtils, System.IniFiles, FMX.Platform, Steamworks.API,
  Steamworks.Versions, FmxLinuxMenu, FmxWineCanvas;

const
  { Vendor folder of the settings (under the OS's per-user settings folder). }
  SETTINGS_VENDOR = 'G3DGames';
  { The program's folder inside it, and the settings file's base name. }
  SETTINGS_APP = 'SteamDemo';

{ The OS's usual per-user folder for this program's settings:
  Windows %APPDATA%\G3DGames\SteamDemo (roaming AppData), macOS
  ~/Library/Application Support/G3DGames/SteamDemo, Linux
  $XDG_CONFIG_HOME/G3DGames/SteamDemo (default ~/.config/...), Android the
  app's private documents folder. Never next to the executable: that folder
  is read-only for a game installed by Steam (and inside Steam's Linux
  runtime). The folder may not exist yet. }
function SettingsFolder: string;
{$IF defined(LINUX) and not defined(ANDROID)}
var
  Config: string;
{$ENDIF}
begin
{$IF defined(ANDROID)}
  Result := TPath.GetDocumentsPath;
{$ELSEIF defined(MSWINDOWS)}
  Result := TPath.Combine(TPath.Combine(TPath.GetHomePath, SETTINGS_VENDOR), SETTINGS_APP);
{$ELSEIF defined(MACOS)}
  Result := TPath.Combine(TPath.Combine(TPath.Combine(TPath.GetHomePath,
    'Library/Application Support'), SETTINGS_VENDOR), SETTINGS_APP);
{$ELSE}
  Config := GetEnvironmentVariable('XDG_CONFIG_HOME');
  if Config = '' then
    Config := TPath.Combine(TPath.GetHomePath, '.config');
  Result := TPath.Combine(TPath.Combine(Config, SETTINGS_VENDOR), SETTINGS_APP);
{$ENDIF}
end;

const
  LevelNames: array[TSteamLogLevel] of string = ('debug', 'info', 'warn', 'ERROR');

function UpdateModeText(AMode: TSteamUpdateMode): string;
begin
  case AMode of
    sumTimer:  Result := 'sumTimer';
    sumThread: Result := 'sumThread';
  else
    Result := 'sumManual';
  end;
end;

function DeliveryText(ADelivery: TSteamDelivery): string;
begin
  case ADelivery of
    sdMainThread: Result := 'sdMainThread';
    sdOnUpdate:   Result := 'sdOnUpdate';
  else
    Result := 'sdPumpThread';
  end;
end;

procedure TfrmMain.FormCreate(Sender: TObject);
var
  LogFileError: string;
begin
{$IFDEF ANDROID}
  FLogFile := TPath.Combine(TPath.GetDocumentsPath, 'SteamDemo.log');
{$ELSE}
  FLogFile := TPath.Combine(ExpandFileName(ExtractFilePath(ParamStr(0))), 'SteamDemo.log');
{$ENDIF}
  LogFileError := '';
  // the previous run's log stays as SteamDemo.previous.log (a restart
  // must not wipe the log of a test run on a second machine)
  if FileExists(FLogFile) then
  begin
    System.SysUtils.DeleteFile(ChangeFileExt(FLogFile, '.previous.log'));
    RenameFile(FLogFile, ChangeFileExt(FLogFile, '.previous.log'));
  end;
  try
    TFile.WriteAllText(FLogFile, '');
  except
    on E: Exception do
    begin
      // say why (in Steam's Linux runtime the game folder is not writable)
      LogFileError := FLogFile + ': ' + E.Message;
      FLogFile := '';
    end;
  end;
  if LogFileError <> '' then
    AddLog('Log file could not be created (' + LogFileError + '); logging to the window'
      {$IFDEF POSIX} + ' and stderr'{$ENDIF} + ' only');
  FCreateTicks := TThread.GetTickCount;
  AddLog('FormCreate started');
  // Linux: FMX's menu bar instead of GTK's, which shows only first letters
  // (FmxLinuxMenu). After the log (a crash in it still leaves a line), and
  // before anything else touches a menu item.
  ReplaceMainMenu(Self, MainMenu1);
  AddLog('Main menu ready (on Linux: replaced by FMX''s own menu bar)');
  // Which build runs on which system (native or Proton / Wine on SteamOS,
  // Rosetta 2 on macOS, Steam's Linux runtime container ...)
  // Title from the live values: SteamAPI1.AppID (set in the form file) and
  // the SDK level this library targets - never typed into the caption
  Caption := Format('%s - AppID %d (SDK %s) - %s', [Caption, SteamAPI1.AppID,
    STEAMWORKS_SDK_VERSION, TSteamLib.PlatformDescription]);
  // Under Wine / Proton: which canvas FMX draws with (FmxWineCanvas)
  if FmxWineCanvasNote <> '' then
    AddLog(FmxWineCanvasNote);
  // The canvas FMX really draws with, on every platform (FmxWineCanvas)
  AddLog('FMX canvas in use: ' + FmxCanvasClassName);
  // AppID, UpdateMode, events and the plug-in links are set in uMain.fmx.
  // A form file cannot depend on the build configuration, so this is here:
{$IFDEF DEBUG}
  // Development: no steam_appid.txt needed, never relaunch through Steam
  SteamAPI1.SetAppIdEnvironment := True;
  SteamAPI1.RestartIfNecessary := False;
{$ELSE}
  SteamAPI1.RestartIfNecessary := True;
{$ENDIF}
  tabMain.TabIndex := 0;
  FTest := TSteamComponentTest.Create(Self, SteamAPI1);
  FTest.OnLog := AddLog;
  FTest.OnRowChanged := TestRow;
  FTest.OnFinished := TestFinished;
  FTest.OnScreenshotRequested := TestScreenshotRequested;
  FillTestList;
  FPair := TSteamPairTest.Create(Self, SteamAPI1);
  FPair.AppName := 'SteamDemo (FMX)';
  FPair.OnLog := AddLog;
  FPair.OnRowChanged := PairRow;
  FPair.OnFinished := PairFinished;
  FillPairList;
  // after ReplaceMainMenu: RemoteLogChanged uses mnuRemoteLog
  FRemote := TDemoRemoteLog.Create(Self, 'SteamDemo', TSteamLib.PlatformDescription);
  FRemote.OnLog := AddLog;
  FRemote.OnChanged := RemoteLogChanged;
  AddLog(Format('Steamworks demo, AppID %d, %d plug-in class(es) linked',
    [SteamAPI1.AppID, Length(TSteamworks.RegisteredPlugins)]));
  if FLogFile <> '' then
    AddLog('Log file: ' + FLogFile)
  else
    AddLog('Log file could not be created; log is on screen only');
  AddLog(Format('Update mode (from the form): %s, delivery %s, interval %d ms',
    [UpdateModeText(SteamAPI1.UpdateMode), DeliveryText(SteamAPI1.Delivery),
     SteamAPI1.CallbackInterval]));
  LoadSettings;
  UpdateAutoStartText;
  UpdateControls;
  if FAutoStart then
  begin
    // Once the window is up, not from inside FormCreate
    AddLog('Auto Start Steam is on: Steam starts when the window is up');
    tmAutoStart.Enabled := True;
  end;
end;

procedure TfrmMain.FormClose(Sender: TObject; var Action: TCloseAction);
begin
  AddLog(Format('FormClose: window closing (Steam running: %s)', [BoolToStr(SteamAPI1.IsRunning, True)]));
  // Closed within the first 100 ms: Auto Start must not open Steam again
  tmAutoStart.Enabled := False;
  tmTests.Enabled := False;
  if FTest.Running then
    FTest.Finish('window closing');
  tmPair.Enabled := False;
  if FPair.Running then
    FPair.Finish('window closing');
  SteamAPI1.Close;
  // last: the lines above still reach the receiver
  FRemote.Shutdown;
end;

procedure TfrmMain.FormDestroy(Sender: TObject);
begin
  tmAutoStart.Enabled := False;
  tmTests.Enabled := False;
  tmPair.Enabled := False;
end;

procedure TfrmMain.AddLog(const S: string);
var
  Line: string;
begin
  Line := FormatDateTime('hh:nn:ss.zzz', Now) + '  ' + S;
{$IFDEF POSIX}
  // Every line on stderr too, FIRST and flushed: inside Steam's Linux
  // runtime the game folder is read-only, so the log file cannot be
  // written there - stderr is what the launch options capture
  WriteLn(ErrOutput, Line);
  Flush(ErrOutput);
{$ENDIF}
  memLog.Lines.Add(Line);
  memLog.GoToTextEnd;
  if FLogFile <> '' then
  try
    // Open, append, close per line: nothing is lost if the process is killed
    TFile.AppendAllText(FLogFile, Line + sLineBreak);
  except
    FLogFile := '';
  end;
  // the same line to a LogReceiver while sending (a no-op otherwise)
  if FRemote <> nil then
    FRemote.Send(Line);
end;

procedure TfrmMain.RemoteLogChanged(Sender: TObject);
begin
  if mnuRemoteLog <> nil then
  begin
    mnuRemoteLog.Text := FRemote.MenuText;
    // greyed while searching / connecting: the click would do nothing
    mnuRemoteLog.Enabled := not FRemote.Busy;
  end;
end;

procedure TfrmMain.StartSteam(const AWhy: string);
begin
  AddLog(AWhy);
  if SteamAPI1.IsRunning then
  begin
    AddLog('Steam is already running');
    UpdateControls;
    Exit;
  end;
  // No second press while Open runs
  btnStart.Enabled := False;
  try
    if SteamAPI1.Open then
      AddLog('Open returned True: Steam is running')
    else
      AddLog('Open returned False: Steam did not start');
  finally
    UpdateControls;
  end;
end;

procedure TfrmMain.btnStartClick(Sender: TObject);
begin
  StartSteam('Start pressed');
end;

procedure TfrmMain.tmAutoStartTimer(Sender: TObject);
begin
  tmAutoStart.Enabled := False;
  StartSteam(Format('Auto Start Steam: starting Steam (%d ms after FormCreate; the timer is %d ms)',
    [Integer(TThread.GetTickCount - FCreateTicks), tmAutoStart.Interval]));
end;

procedure TfrmMain.UpdateControls;
var
  Running: Boolean;
begin
  Running := SteamAPI1.IsRunning;
  btnStart.Enabled := not Running;
  btnInfo.Enabled := Running;
  btnStop.Enabled := Running;
  btnTest.Enabled := Running;
  btnPair.Enabled := Running;
  if mnuTakeScreenshot <> nil then
    mnuTakeScreenshot.Enabled := Running;
end;

procedure TfrmMain.UpdateAutoStartText;
begin
  if mnuAutoStart = nil then
    Exit;
  if FAutoStart then
    mnuAutoStart.Text := 'Auto Start Steam: on'
  else
    mnuAutoStart.Text := 'Auto Start Steam: off';
end;

procedure TfrmMain.LoadSettings;
var
  Ini: TMemIniFile;
begin
  FAutoStart := False;
  FSettingsFile := '';
  try
    FSettingsFile := TPath.Combine(SettingsFolder, SETTINGS_APP + '.ini');
    if not TFile.Exists(FSettingsFile) then
    begin
      AddLog('Settings: ' + FSettingsFile + ' does not exist yet - defaults used (Auto Start Steam off)');
      Exit;
    end;
    Ini := TMemIniFile.Create(FSettingsFile, TEncoding.UTF8);
    try
      FAutoStart := Ini.ReadBool('Steam', 'AutoStart', False);
    finally
      Ini.Free;
    end;
    AddLog('Settings read from ' + FSettingsFile + ': Auto Start Steam ' + IfThen(FAutoStart, 'on', 'off'));
  except
    on E: Exception do
      AddLog('Settings could not be read (' + FSettingsFile + '): ' + E.Message + ' - defaults used');
  end;
end;

procedure TfrmMain.SaveSettings;
var
  Ini: TMemIniFile;
begin
  if FSettingsFile = '' then
  begin
    AddLog('Settings NOT saved: no settings folder could be determined');
    Exit;
  end;
  try
    ForceDirectories(ExtractFilePath(FSettingsFile));
    Ini := TMemIniFile.Create(FSettingsFile, TEncoding.UTF8);
    try
      Ini.WriteBool('Steam', 'AutoStart', FAutoStart);
      Ini.UpdateFile;
    finally
      Ini.Free;
    end;
    AddLog('Settings saved to ' + FSettingsFile);
  except
    on E: Exception do
      AddLog('Settings NOT saved (' + FSettingsFile + '): ' + E.Message);
  end;
end;

procedure TfrmMain.mnuAutoStartClick(Sender: TObject);
begin
  FAutoStart := not FAutoStart;
  UpdateAutoStartText;
  AddLog('File > Auto Start Steam: ' + IfThen(FAutoStart,
    'on - Steam starts by itself the next time the program starts', 'off'));
  SaveSettings;
end;

procedure TfrmMain.mnuExitClick(Sender: TObject);
begin
  AddLog('File > Exit');
  Close;
end;

procedure TfrmMain.btnStopClick(Sender: TObject);
begin
  AddLog('Stop pressed');
  // Before Close: the test's cleanup needs Steam (OnShutdown is too late)
  if FTest.Running then
    FTest.Finish('Stop pressed');
  if FPair.Running then
    FPair.Finish('Stop pressed');
  SteamAPI1.Close;
  UpdateControls;
end;

procedure TfrmMain.mnuCopyLogClick(Sender: TObject);
var
  Svc: IFMXClipboardService;
begin
  if TPlatformServices.Current.SupportsPlatformService(IFMXClipboardService, Svc) then
  begin
    Svc.SetClipboard(memLog.Text);
    AddLog('Log copied to clipboard');
  end;
end;

procedure TfrmMain.mnuRemoteLogClick(Sender: TObject);
begin
  FRemote.Toggle(memLog.Lines);
end;

procedure TfrmMain.btnInfoClick(Sender: TObject);
var
  U: TSteamUtilsPlugin;
  RS: TSteamRemoteStoragePlugin;
  Shots: TSteamScreenshotsPlugin;
  Tl: TSteamTimelinePlugin;
  Ugc: TSteamUGCPlugin;
  QuotaTotal, QuotaAvailable: UInt64;
  TlEvent: TimelineEventHandle_t;
  Usr: TSteamUserPlugin;
  Fr: TSteamFriendsPlugin;
  Apps: TSteamAppsPlugin;
  Stats: TSteamUserStatsPlugin;
  Id: TSteamID;
  V: string;
begin
  if not SteamAPI1.IsRunning then
  begin
    AddLog('Info: Steam is not running - press Start first');
    Exit;
  end;
  AddLog(Format('Library %s: %d interface versions detected',
    [TSteamLib.LibraryPath, SteamAPI1.Steam.Versions.Count]));
  for V in SteamAPI1.Steam.Versions.ToArray do
    AddLog('  ' + V);
  if SteamAPI1.Steam.Client <> nil then
    AddLog('ISteamClient ' + SteamAPI1.Steam.Client.Version +
      ', IPC calls since last query: ' + UIntToStr(SteamAPI1.Steam.Client.GetIPCCallCount))
  else
    AddLog('ISteamClient was not created');

  U := SteamAPI1.Steam.Plugin<TSteamUtilsPlugin>;
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

  Usr := SteamAPI1.Steam.Plugin<TSteamUserPlugin>;
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

  Fr := SteamAPI1.Steam.Plugin<TSteamFriendsPlugin>;
  if Fr = nil then
    AddLog('ISteamFriends plug-in is not active')
  else
  try
    AddLog(Format('ISteamFriends: persona "%s", state %d, immediate friends %d',
      [Fr.GetPersonaName, Ord(Fr.GetPersonaState), Fr.GetFriendCount(k_EFriendFlagImmediate)]));
  except
    on E: Exception do AddLog('ISteamFriends failed: ' + E.Message);
  end;

  Apps := SteamAPI1.Steam.Plugin<TSteamAppsPlugin>;
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

  Stats := SteamAPI1.Steam.Plugin<TSteamUserStatsPlugin>;
  if Stats = nil then
    AddLog('ISteamUserStats plug-in is not active')
  else
  try
    AddLog(Format('ISteamUserStats: %d achievements defined for this app',
      [Stats.GetNumAchievements]));
  except
    on E: Exception do AddLog('ISteamUserStats failed: ' + E.Message);
  end;
  // Plug-ins added 2026-10-30 (fifth session): one line each, as in SteamConsole
  try
    RS := TSteamRemoteStoragePlugin(SteamAPI1.Steam.FindPlugin(TSteamRemoteStoragePlugin));
    if RS <> nil then
    begin
      QuotaTotal := 0;
      QuotaAvailable := 0;
      RS.GetQuota(QuotaTotal, QuotaAvailable);
      AddLog(Format('ISteamRemoteStorage: cloud enabled for account %s / app %s, %d files, quota %s of %s bytes free',
        [BoolToStr(RS.IsCloudEnabledForAccount, True), BoolToStr(RS.IsCloudEnabledForApp, True),
         RS.GetFileCount, IntToStr(Int64(QuotaAvailable)), IntToStr(Int64(QuotaTotal))]));
    end;
  except
    on E: Exception do AddLog('ISteamRemoteStorage failed: ' + E.Message);
  end;
  try
    Shots := TSteamScreenshotsPlugin(SteamAPI1.Steam.FindPlugin(TSteamScreenshotsPlugin));
    if Shots <> nil then
      AddLog('ISteamScreenshots: hooked by the game ' + BoolToStr(Shots.IsScreenshotsHooked, True));
  except
    on E: Exception do AddLog('ISteamScreenshots failed: ' + E.Message);
  end;
  try
    Tl := TSteamTimelinePlugin(SteamAPI1.Steam.FindPlugin(TSteamTimelinePlugin));
    if Tl <> nil then
    begin
      // strings, a Single and an enum in one call; only visible in a recording
      TlEvent := Tl.AddInstantaneousTimelineEvent('Show info', 'Demo test', 'steam_flag',
        0, 0, k_ETimelineEventClipPriority_None);
      AddLog('ISteamTimeline: instantaneous event added, handle ' + IntToStr(Int64(TlEvent)));
    end;
  except
    on E: Exception do AddLog('ISteamTimeline failed: ' + E.Message);
  end;
  try
    Ugc := TSteamUGCPlugin(SteamAPI1.Steam.FindPlugin(TSteamUGCPlugin));
    if Ugc <> nil then
      AddLog(Format('ISteamUGC: %d subscribed items (%d incl. locally disabled), %d downloaded',
        [Ugc.GetNumSubscribedItems(False), Ugc.GetNumSubscribedItems(True), Ugc.GetNumDownloadedItems]));
  except
    on E: Exception do AddLog('ISteamUGC failed: ' + E.Message);
  end;
end;

procedure TfrmMain.SteamLog(Sender: TObject; ALevel: TSteamLogLevel; const AMessage: string);
begin
  AddLog('[' + LevelNames[ALevel] + '] ' + AMessage);
end;

procedure TfrmMain.SteamInitialized(Sender: TObject);
begin
  AddLog(Format('OnInitialized: pipe %d, user %d, %d plug-in(s) active',
    [SteamAPI1.Steam.Pipe, SteamAPI1.Steam.User, SteamAPI1.Steam.PluginCount]));
  UpdateControls;
  LoadPersonal;
  LoadAchievements;
end;

function PersonaStateText(AState: EPersonaState): string;
begin
  case Ord(AState) of
    0: Result := 'offline';
    1: Result := 'online';
    2: Result := 'busy';
    3: Result := 'away';
    4: Result := 'snooze';
    5: Result := 'looking to trade';
    6: Result := 'looking to play';
    7: Result := 'invisible';
  else
    Result := 'state ' + IntToStr(Ord(AState));
  end;
end;

procedure TfrmMain.AddInfo(const AName, AValue: string);
var
  Item: TListBoxItem;
begin
  Item := TListBoxItem.Create(lbInfo);
  Item.Parent := lbInfo;
  Item.ItemData.Text := AName;
  Item.ItemData.Detail := AValue;
end;

procedure TfrmMain.LoadPersonal;
var
  Usr: TSteamUserPlugin;
  Fr: TSteamFriendsPlugin;
  U: TSteamUtilsPlugin;
  Me, Friend: TSteamID;
  I, Count, H: Integer;
  Nick, FriendName: string;
  Item: TListBoxItem;
begin
  Usr := SteamAPI1.Steam.Plugin<TSteamUserPlugin>;
  Fr := SteamFriends1.Plugin;
  U := SteamAPI1.Steam.Plugin<TSteamUtilsPlugin>;
  if (Usr = nil) or (Fr = nil) then
    Exit;
  try
    Me := Usr.GetSteamID;
    lbInfo.BeginUpdate;
    try
      lbInfo.Clear;
      AddInfo('Persona name', Fr.GetPersonaName);
      AddInfo('Status', PersonaStateText(Fr.GetPersonaState));
      AddInfo('SteamID', Me.ToString);
      AddInfo('SteamID3', Format('[U:1:%d]', [Me.AccountID]));
      AddInfo('Account id', IntToStr(Me.AccountID));
      AddInfo('Steam level', IntToStr(Usr.GetPlayerSteamLevel));
      AddInfo('Logged on', BoolToStr(Usr.BLoggedOn, True));
      if U <> nil then
      begin
        AddInfo('Country (by IP)', U.GetIPCountry);
        AddInfo('Steam UI language', U.GetSteamUILanguage);
      end;
    finally
      lbInfo.EndUpdate;
    end;

    // Own avatar: -1 = Steam is fetching it -> OnAvatarImageLoaded
    H := Fr.GetLargeFriendAvatar(Me);
    if H > 0 then
      SteamImageToBitmap(H, imgAvatar.Bitmap);
    AddLog(Format('Personal: %s (%s), level %d, large avatar handle %d',
      [Fr.GetPersonaName, Me.ToString, Usr.GetPlayerSteamLevel, H]));

    Count := Fr.GetFriendCount(k_EFriendFlagImmediate);
    lbFriends.BeginUpdate;
    try
      lbFriends.Clear;
      for I := 0 to Count - 1 do
      begin
        Friend := Fr.GetFriendByIndex(I, k_EFriendFlagImmediate);
        // Asks Steam for name / avatar if it does not have them yet
        // (answer: PersonaStateChange_t, then AvatarImageLoaded_t)
        Fr.RequestUserInformation(Friend, False);
        FriendName := Fr.GetFriendPersonaName(Friend);
        Nick := Fr.GetPlayerNickname(Friend);
        if Nick <> '' then
          FriendName := FriendName + ' (' + Nick + ')';
        Item := TListBoxItem.Create(lbFriends);
        Item.Parent := lbFriends;
        Item.TagString := Friend.ToString;
        Item.ItemData.Text := FriendName;
        Item.ItemData.Detail := Format('%s, level %d, %s', [PersonaStateText(Fr.GetFriendPersonaState(Friend)),
          Fr.GetFriendSteamLevel(Friend), Friend.ToString]);
        H := Fr.GetMediumFriendAvatar(Friend);
        if H > 0 then
          SteamImageToBitmap(H, Item.ItemData.Bitmap);
        AddLog(Format('Friend %d: %s, medium avatar handle %d (-1 = loading, 0 = none)',
          [I, FriendName, H]));
      end;
    finally
      lbFriends.EndUpdate;
    end;
    AddLog(Format('Personal: %d immediate friend(s) listed', [Count]));
  except
    on E: Exception do AddLog('Personal failed: ' + E.Message);
  end;
end;

procedure TfrmMain.ShowFriendAvatar(const ASteamID: TSteamID; AImage: Integer);
var
  I: Integer;
  Key: string;
begin
  Key := ASteamID.ToString;
  for I := 0 to lbFriends.Count - 1 do
    if lbFriends.ListItems[I].TagString = Key then
      SteamImageToBitmap(AImage, lbFriends.ListItems[I].ItemData.Bitmap);
end;

procedure TfrmMain.FriendAvatarLoaded(Sender: TObject; const AData: AvatarImageLoaded_t);
var
  Usr: TSteamUserPlugin;
begin
  AddLog(Format('TSteamFriends.OnAvatarImageLoaded: SteamID %s, image %d, %dx%d',
    [AData.m_steamID.ToString, AData.m_iImage, AData.m_iWide, AData.m_iTall]));
  Usr := SteamAPI1.Steam.Plugin<TSteamUserPlugin>;
  // Large (184 px) avatar of the user -> the Personal tab's picture; medium
  // ones -> the friends list
  if (Usr <> nil) and (AData.m_steamID = Usr.GetSteamID) and (AData.m_iWide >= 184) then
    SteamImageToBitmap(AData.m_iImage, imgAvatar.Bitmap)
  else
    ShowFriendAvatar(AData.m_steamID, AData.m_iImage);
end;

procedure TfrmMain.LoadAchievements;
var
  S: TSteamUserStatsPlugin;
  I, Icon: Integer;
  N, UnlockTime: UInt32;
  AchName, Title, Desc, State: string;
  Achieved, Hidden: Boolean;
  Item: TListBoxItem;
begin
  S := SteamUserStats1.Plugin;
  if S = nil then
    Exit;
  try
    N := S.GetNumAchievements;
    lbAchievements.BeginUpdate;
    try
      lbAchievements.Clear;
      for I := 0 to Integer(N) - 1 do
      begin
        AchName := S.GetAchievementName(UInt32(I));
        Achieved := False;
        UnlockTime := 0;
        S.GetAchievementAndUnlockTime(AchName, Achieved, UnlockTime);
        Title := S.GetAchievementDisplayAttribute(AchName, 'name');
        Desc := S.GetAchievementDisplayAttribute(AchName, 'desc');
        Hidden := S.GetAchievementDisplayAttribute(AchName, 'hidden') = '1';
        if Achieved then
          State := 'unlocked ' + FormatDateTime('yyyy-mm-dd hh:nn', SteamTimeToLocal(UnlockTime))
        else
          State := 'locked';
        Item := TListBoxItem.Create(lbAchievements);
        Item.Parent := lbAchievements;
        Item.TagString := AchName;
        Item.ItemData.Text := Title;
        if Hidden and not Achieved then
          Item.ItemData.Detail := 'Hidden achievement - ' + State
        else
          Item.ItemData.Detail := Desc + ' - ' + State;
        Icon := S.GetAchievementIcon(AchName);   // 0: Steam fetches it, then callback 1109
        if Icon > 0 then
          SteamImageToBitmap(Icon, Item.ItemData.Bitmap);
        AddLog(Format('Achievement %d: %s "%s" %s, hidden %s, icon %d', [I, AchName, Title, State,
          BoolToStr(Hidden, True), Icon]));
      end;
    finally
      lbAchievements.EndUpdate;
    end;
  except
    on E: Exception do AddLog('Achievements failed: ' + E.Message);
  end;
end;

procedure TfrmMain.StatsReceived(Sender: TObject; const AData: UserStatsReceived_t);
var
  Usr: TSteamUserPlugin;
begin
  AddLog(Format('TSteamUserStats.OnUserStatsReceived: SteamID %s, result %d',
    [AData.m_steamIDUser.ToString, Ord(AData.m_eResult)]));
  Usr := SteamAPI1.Steam.Plugin<TSteamUserPlugin>;
  if (AData.m_eResult = k_EResultOK) and (Usr <> nil) and (AData.m_steamIDUser = Usr.GetSteamID) then
    LoadAchievements;
end;

procedure TfrmMain.AchievementIconFetched(Sender: TObject; const AData: UserAchievementIconFetched_t);
var
  AchName: string;
  I: Integer;
begin
  AchName := string(UTF8String(PAnsiChar(@AData.m_rgchAchievementName[0])));
  AddLog(Format('TSteamUserStats.OnUserAchievementIconFetched: %s, achieved %s, icon %d',
    [AchName, BoolToStr(AData.m_bAchieved, True), AData.m_nIconHandle]));
  for I := 0 to lbAchievements.Count - 1 do
    if lbAchievements.ListItems[I].TagString = AchName then
      SteamImageToBitmap(AData.m_nIconHandle, lbAchievements.ListItems[I].ItemData.Bitmap);
end;

procedure TfrmMain.SteamInitFailed(Sender: TObject; AResult: Integer; const AMessage: string);
begin
  AddLog(Format('OnInitFailed: result %d (%s): %s',
    [AResult, SteamInitResultToString(ESteamAPIInitResult(AResult)), AMessage]));
  UpdateControls;
end;

procedure TfrmMain.SteamShutdown(Sender: TObject);
begin
  AddLog('OnShutdown: SteamAPI shut down');
  // Only reached with the test running when Steam went away by itself
  // (client exit): SteamAPI is already shut down, so no cleanup is possible
  if FTest.Running then
    FTest.Finish('Steam shut down while the component test was running (no cleanup possible)');
  if FPair.Running then
    FPair.Finish('Steam shut down while the pair test was running (no cleanup possible)');
  // Also after a Steam client exit: Start becomes possible again
  UpdateControls;
end;

procedure TfrmMain.SteamClientExit(Sender: TObject);
begin
  AddLog(Format('OnSteamShutdown: the Steam client is exiting; SteamAPI shuts down next: %s ' +
    '(the demo keeps running; press Start once Steam is back)', [BoolToStr(SteamAPI1.ShutdownOnSteamExit, True)]));
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
var
  Fr: TSteamFriendsPlugin;
  Id: TSteamID;
  I, H: Integer;
begin
  // Keep the friends list current (names and avatars arrive after
  // RequestUserInformation)
  Fr := SteamFriends1.Plugin;
  Id := TSteamID.Create(AData.m_ulSteamID);
  if Fr <> nil then
    for I := 0 to lbFriends.Count - 1 do
      if lbFriends.ListItems[I].TagString = Id.ToString then
      begin
        lbFriends.ListItems[I].ItemData.Text := Fr.GetFriendPersonaName(Id);
        lbFriends.ListItems[I].ItemData.Detail := Format('%s, level %d, %s',
          [PersonaStateText(Fr.GetFriendPersonaState(Id)), Fr.GetFriendSteamLevel(Id), Id.ToString]);
        H := Fr.GetMediumFriendAvatar(Id);
        if H > 0 then
          SteamImageToBitmap(H, lbFriends.ListItems[I].ItemData.Bitmap);
      end;
  AddLog(Format('TSteamFriends.OnPersonaStateChange: SteamID %s, change flags $%x (attached %s)',
    [TSteamID.Create(AData.m_ulSteamID).ToString, AData.m_nChangeFlags,
     BoolToStr(SteamFriends1.Attached, True)]));
end;

{ ---------------------------------------------------------------------------
  Component test (Components tab, Test components button)

  The test itself is demos/Shared/SteamComponentTest.pas (TSteamComponentTest,
  shared with SteamDemoVCL / SteamDemoLCL): it creates its own plug-in
  components, linked to SteamAPI1, and reports through OnLog / OnRowChanged.
  This form shows its rows, ticks it from tmTests and finishes it before
  Steam is closed (its cleanup needs Steam).
  --------------------------------------------------------------------------- }

procedure TfrmMain.FillTestList;
var
  I: Integer;
  Item: TListBoxItem;
begin
  lbComponents.BeginUpdate;
  try
    lbComponents.Clear;
    for I := 0 to CT_COUNT - 1 do
    begin
      Item := TListBoxItem.Create(lbComponents);
      Item.Parent := lbComponents;
      Item.ItemData.Text := TestNames[I];
      Item.ItemData.Detail := FTest.RowText[I];
    end;
  finally
    lbComponents.EndUpdate;
  end;
end;

procedure TfrmMain.TestRow(AIndex: Integer; const AText: string);
begin
  if (AIndex >= 0) and (AIndex < lbComponents.Count) then
    lbComponents.ListItems[AIndex].ItemData.Detail := AText;
end;

procedure TfrmMain.TestFinished(Sender: TObject);
begin
  tmTests.Enabled := False;
end;

procedure TfrmMain.btnTestClick(Sender: TObject);
begin
  AddLog('Test components pressed');
  // Without Steam, Start only logs "press Start first" (the tab stays)
  if SteamAPI1.IsRunning then
    tabMain.ActiveTab := tiComponents;
  FTest.Start;
  tmTests.Enabled := FTest.Running;
end;

procedure TfrmMain.FillPairList;
var
  I: Integer;
  Item: TListBoxItem;
begin
  lbPair.BeginUpdate;
  try
    lbPair.Clear;
    for I := 0 to PT_COUNT - 1 do
    begin
      Item := TListBoxItem.Create(lbPair);
      Item.Parent := lbPair;
      Item.ItemData.Text := PairTestNames[I];
      Item.ItemData.Detail := FPair.RowText[I];
    end;
  finally
    lbPair.EndUpdate;
  end;
end;

procedure TfrmMain.PairRow(AIndex: Integer; const AText: string);
begin
  if (AIndex >= 0) and (AIndex < lbPair.Count) then
    lbPair.ListItems[AIndex].ItemData.Detail := AText;
end;

procedure TfrmMain.PairFinished(Sender: TObject);
begin
  tmPair.Enabled := False;
end;

procedure TfrmMain.btnPairClick(Sender: TObject);
begin
  AddLog('Pair test pressed');
  tabMain.ActiveTab := tiPair;
  FPair.Start;
  tmPair.Enabled := FPair.Running;
end;

procedure TfrmMain.tmPairTimer(Sender: TObject);
begin
  FPair.Tick;
end;

procedure TfrmMain.tmTestsTimer(Sender: TObject);
begin
  if not FTest.Running then
  begin
    tmTests.Enabled := False;
    Exit;
  end;
  FTest.Tick;
end;

{ --- File > Take Screenshot --- }

function TfrmMain.WriteFormScreenshot(AShots: TSteamScreenshotsPlugin): ScreenshotHandle;
var
  RGB: TBytes;
  W, H: Integer;
begin
  Result := 0;
  // The demo's own window, as Steamworks.FMX paints it for Steam
  RGB := SteamFormToRGB(Self, W, H);
  if RGB = nil then
  begin
    AddLog('Screenshot: SteamFormToRGB returned nothing - window not captured');
    Exit;
  end;
  Result := AShots.WriteScreenshot(@RGB[0], Length(RGB), W, H);
  AddLog(Format('Screenshot: window captured %dx%d (%d bytes RGB), WriteScreenshot -> handle %d (0 = failed)',
    [W, H, Length(RGB), Result]));
end;

procedure TfrmMain.mnuTakeScreenshotClick(Sender: TObject);
var
  S: TSteamScreenshotsPlugin;
begin
  AddLog('File > Take Screenshot');
  // The component test's TSteamScreenshots (created by FTest): its
  // OnScreenshotReady tags every picture this program writes
  S := FTest.Screenshots;
  if (S = nil) or not SteamAPI1.IsRunning then
  begin
    AddLog('Screenshot: Steam is not running - press Start first');
    Exit;
  end;
  try
    // WriteScreenshot needs no overlay (TriggerScreenshot does); Steam
    // answers with OnScreenshotReady, which the component test's
    // TSteamScreenshots handles (SetLocation tags the picture)
    if WriteFormScreenshot(S) <> 0 then
      AddLog(Format('Screenshot: waiting for OnScreenshotReady (callback %d)', [ScreenshotReady_t_k_iCallback]));
  except
    on E: Exception do AddLog('Screenshot FAILED: ' + E.Message);
  end;
end;

procedure TfrmMain.TestScreenshotRequested(Sender: TObject);
begin
  // Only while screenshots are hooked (the test unhooks them at once): then
  // Steam takes none itself and every request must be answered
  if FTest.Screenshots <> nil then
  try
    WriteFormScreenshot(FTest.Screenshots);
  except
    on E: Exception do AddLog('Screenshot FAILED: ' + E.Message);
  end;
end;

end.
