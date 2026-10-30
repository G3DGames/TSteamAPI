{ @abstract(Main form of the FMX Steamworks demo.)

  Creates a @code(TSteamAPI) and the @code(TSteamFriends) / @code(TSteamUserStats)
  components in code (no design-time package needed). Three tabs: Output (the
  log), Personal (the user's avatar, persona, Steam ids, level, country and the
  friends list with avatars) and Achievements (icons, unlock state). It
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
  FMX.Layouts, FMX.Objects, FMX.ListBox, FMX.TabControl,
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
    { ISteamUserStats component: stats received, achievement icons fetched. }
    FStats: TSteamUserStats;
    { Tabs: Output (the log), Personal, Achievements. }
    FTabs: TTabControl;
    { The user's large avatar (Personal tab). }
    FAvatar: TImage;
    { The user's persona, Steam ids, level, ... (Personal tab). }
    FInfo: TListBox;
    { The user's friends with their avatars (Personal tab); each item's
      TagString is the friend's SteamID. }
    FFriendsList: TListBox;
    { The app's achievements; each item's TagString is the API name. }
    FAchievements: TListBox;
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
    { TSteamFriends.OnAvatarImageLoaded (callback 334): a requested avatar arrived. }
    procedure FriendAvatarLoaded(Sender: TObject; const AData: AvatarImageLoaded_t);
    { TSteamUserStats.OnUserStatsReceived (callback 1101): refresh the list. }
    procedure StatsReceived(Sender: TObject; const AData: UserStatsReceived_t);
    { TSteamUserStats.OnUserAchievementIconFetched (callback 1109). }
    procedure AchievementIconFetched(Sender: TObject; const AData: UserAchievementIconFetched_t);
    { Creates the tabs and moves the log into the Output tab. }
    procedure CreateTabs;
    { Adds a tab with the given title. }
    function AddTab(const ATitle: string): TTabItem;
    { Adds a Text / Detail row to @link(FInfo). }
    procedure AddInfo(const AName, AValue: string);
    { Fills the Personal tab: avatar, persona, ids, friends. }
    procedure LoadPersonal;
    { Puts an avatar into the friend item of ASteamID, if listed. }
    procedure ShowFriendAvatar(const ASteamID: TSteamID; AImage: Integer);
    { Fills @link(FAchievements) from ISteamUserStats. }
    procedure LoadAchievements;
  end;

var
  { The main form instance. }
  frmMain: TfrmMain;

implementation

{$R *.fmx}

uses
  System.IOUtils, System.DateUtils, FMX.Platform, Steamworks.API;

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
  FFriends.OnAvatarImageLoaded := FriendAvatarLoaded;
  FStats := TSteamUserStats.Create(Self);
  FStats.SteamAPI := FSteam;
  FStats.OnUserStatsReceived := StatsReceived;
  FStats.OnUserAchievementIconFetched := AchievementIconFetched;
  CreateTabs;
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

function TfrmMain.AddTab(const ATitle: string): TTabItem;
begin
  Result := TTabItem.Create(FTabs);
  Result.Text := ATitle;
  FTabs.AddObject(Result);
end;

procedure TfrmMain.CreateTabs;
var
  Tab: TTabItem;
  TopArea: TLayout;
  FriendsCaption: TLabel;
begin
  FTabs := TTabControl.Create(Self);
  FTabs.Parent := Self;
  FTabs.Align := TAlignLayout.Client;

  // Output: the existing log memo
  Tab := AddTab('Output');
  memLog.Parent := Tab;
  memLog.Align := TAlignLayout.Client;

  // Personal: avatar + details on top, friends below
  Tab := AddTab('Personal');
  TopArea := TLayout.Create(Self);
  TopArea.Parent := Tab;
  TopArea.Align := TAlignLayout.Top;
  TopArea.Height := 200;
  FAvatar := TImage.Create(Self);
  FAvatar.Parent := TopArea;
  FAvatar.Align := TAlignLayout.Left;
  FAvatar.Width := 184;
  FAvatar.Margins.Rect := TRectF.Create(8, 8, 8, 8);
  FInfo := TListBox.Create(Self);
  FInfo.Parent := TopArea;
  FInfo.Align := TAlignLayout.Client;
  FInfo.DefaultItemStyles.ItemStyle := 'listboxitemrightdetail';
  FriendsCaption := TLabel.Create(Self);
  FriendsCaption.Parent := Tab;
  FriendsCaption.Align := TAlignLayout.Top;
  FriendsCaption.Margins.Rect := TRectF.Create(8, 4, 8, 4);
  FriendsCaption.Text := 'Friends';
  FFriendsList := TListBox.Create(Self);
  FFriendsList.Parent := Tab;
  FFriendsList.Align := TAlignLayout.Client;
  FFriendsList.ItemHeight := 56;
  FFriendsList.DefaultItemStyles.ItemStyle := 'listboxitembottomdetail';

  // Achievements
  Tab := AddTab('Achievements');
  FAchievements := TListBox.Create(Self);
  FAchievements.Parent := Tab;
  FAchievements.Align := TAlignLayout.Client;
  FAchievements.ItemHeight := 72;
  FAchievements.DefaultItemStyles.ItemStyle := 'listboxitembottomdetail';

  FTabs.TabIndex := 0;
end;

procedure TfrmMain.AddInfo(const AName, AValue: string);
var
  Item: TListBoxItem;
begin
  Item := TListBoxItem.Create(FInfo);
  Item.Parent := FInfo;
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
  Usr := FSteam.Steam.Plugin<TSteamUserPlugin>;
  Fr := FFriends.Plugin;
  U := FSteam.Steam.Plugin<TSteamUtilsPlugin>;
  if (Usr = nil) or (Fr = nil) then
    Exit;
  try
    Me := Usr.GetSteamID;
    FInfo.BeginUpdate;
    try
      FInfo.Clear;
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
      FInfo.EndUpdate;
    end;

    // Own avatar: -1 = Steam is fetching it -> OnAvatarImageLoaded
    H := Fr.GetLargeFriendAvatar(Me);
    if H > 0 then
      SteamImageToBitmap(H, FAvatar.Bitmap);
    AddLog(Format('Personal: %s (%s), level %d, large avatar handle %d',
      [Fr.GetPersonaName, Me.ToString, Usr.GetPlayerSteamLevel, H]));

    Count := Fr.GetFriendCount(k_EFriendFlagImmediate);
    FFriendsList.BeginUpdate;
    try
      FFriendsList.Clear;
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
        Item := TListBoxItem.Create(FFriendsList);
        Item.Parent := FFriendsList;
        Item.TagString := Friend.ToString;
        Item.ItemData.Text := FriendName;
        Item.ItemData.Detail := Format('%s, level %d, %s', [PersonaStateText(Fr.GetFriendPersonaState(Friend)),
          Fr.GetFriendSteamLevel(Friend), Friend.ToString]);
        H := Fr.GetMediumFriendAvatar(Friend);
        if H > 0 then
          SteamImageToBitmap(H, Item.ItemData.Bitmap);
      end;
    finally
      FFriendsList.EndUpdate;
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
  for I := 0 to FFriendsList.Count - 1 do
    if FFriendsList.ListItems[I].TagString = Key then
      SteamImageToBitmap(AImage, FFriendsList.ListItems[I].ItemData.Bitmap);
end;

procedure TfrmMain.FriendAvatarLoaded(Sender: TObject; const AData: AvatarImageLoaded_t);
var
  Usr: TSteamUserPlugin;
begin
  AddLog(Format('TSteamFriends.OnAvatarImageLoaded: SteamID %s, image %d, %dx%d',
    [AData.m_steamID.ToString, AData.m_iImage, AData.m_iWide, AData.m_iTall]));
  Usr := FSteam.Steam.Plugin<TSteamUserPlugin>;
  // Large (184 px) avatar of the user -> the Personal tab's picture; medium
  // ones -> the friends list
  if (Usr <> nil) and (AData.m_steamID = Usr.GetSteamID) and (AData.m_iWide >= 184) then
    SteamImageToBitmap(AData.m_iImage, FAvatar.Bitmap)
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
  S := FStats.Plugin;
  if S = nil then
    Exit;
  try
    N := S.GetNumAchievements;
    FAchievements.BeginUpdate;
    try
      FAchievements.Clear;
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
          State := 'unlocked ' + FormatDateTime('yyyy-mm-dd hh:nn', UnixToDateTime(UnlockTime, False))
        else
          State := 'locked';
        Item := TListBoxItem.Create(FAchievements);
        Item.Parent := FAchievements;
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
      FAchievements.EndUpdate;
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
  Usr := FSteam.Steam.Plugin<TSteamUserPlugin>;
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
  for I := 0 to FAchievements.Count - 1 do
    if FAchievements.ListItems[I].TagString = AchName then
      SteamImageToBitmap(AData.m_nIconHandle, FAchievements.ListItems[I].ItemData.Bitmap);
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
var
  Fr: TSteamFriendsPlugin;
  Id: TSteamID;
  I, H: Integer;
begin
  // Keep the friends list current (names and avatars arrive after
  // RequestUserInformation)
  Fr := FFriends.Plugin;
  Id := TSteamID.Create(AData.m_ulSteamID);
  if Fr <> nil then
    for I := 0 to FFriendsList.Count - 1 do
      if FFriendsList.ListItems[I].TagString = Id.ToString then
      begin
        FFriendsList.ListItems[I].ItemData.Text := Fr.GetFriendPersonaName(Id);
        FFriendsList.ListItems[I].ItemData.Detail := Format('%s, level %d, %s',
          [PersonaStateText(Fr.GetFriendPersonaState(Id)), Fr.GetFriendSteamLevel(Id), Id.ToString]);
        H := Fr.GetMediumFriendAvatar(Id);
        if H > 0 then
          SteamImageToBitmap(H, FFriendsList.ListItems[I].ItemData.Bitmap);
      end;
  AddLog(Format('TSteamFriends.OnPersonaStateChange: SteamID %s, change flags $%x (attached %s)',
    [TSteamID.Create(AData.m_ulSteamID).ToString, AData.m_nChangeFlags,
     BoolToStr(FFriends.Attached, True)]));
end;

end.
