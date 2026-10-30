{ @abstract(Main form of the FMX Steamworks demo.)

  Everything is on the form (uMain.fmx): the @code(TSteamAPI) root, the
  @code(TSteamFriends) / @code(TSteamUserStats) plug-in components with their
  events wired in the form file, and the UI. Open it in the IDE with the
  design packages installed (dclSteamworks, dclSteamworksFMX) to see them;
  only the Debug-only settings are made in FormCreate. Three tabs: Output (the
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
    { Tabs: Output (the log), Personal, Achievements. }
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
  private
    { Log file every line is appended to; '' if it cannot be written. }
    FLogFile: string;
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
  System.IOUtils, System.DateUtils, FMX.Platform, Steamworks.API;

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
  AddLog(Format('Steamworks demo, AppID %d, %d plug-in class(es) linked',
    [SteamAPI1.AppID, Length(TSteamworks.RegisteredPlugins)]));
  if FLogFile <> '' then
    AddLog('Log file: ' + FLogFile)
  else
    AddLog('Log file could not be created; log is on screen only');
  AddLog(Format('Update mode (from the form): %s, delivery %s, interval %d ms',
    [UpdateModeText(SteamAPI1.UpdateMode), DeliveryText(SteamAPI1.Delivery),
     SteamAPI1.CallbackInterval]));
end;

procedure TfrmMain.FormClose(Sender: TObject; var Action: TCloseAction);
begin
  AddLog(Format('FormClose: window closing (Steam running: %s)', [BoolToStr(SteamAPI1.IsRunning, True)]));
  SteamAPI1.Close;
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
  if SteamAPI1.Open then
    AddLog('Open returned True: Steam is running')
  else
    AddLog('Open returned False: Steam did not start');
end;

procedure TfrmMain.btnStopClick(Sender: TObject);
begin
  AddLog('Stop pressed');
  SteamAPI1.Close;
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
end;

procedure TfrmMain.SteamLog(Sender: TObject; ALevel: TSteamLogLevel; const AMessage: string);
begin
  AddLog('[' + LevelNames[ALevel] + '] ' + AMessage);
end;

procedure TfrmMain.SteamInitialized(Sender: TObject);
begin
  AddLog(Format('OnInitialized: pipe %d, user %d, %d plug-in(s) active',
    [SteamAPI1.Steam.Pipe, SteamAPI1.Steam.User, SteamAPI1.Steam.PluginCount]));
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
end;

procedure TfrmMain.SteamShutdown(Sender: TObject);
begin
  AddLog('OnShutdown: SteamAPI shut down');
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

end.
