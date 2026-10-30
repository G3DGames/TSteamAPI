{ @abstract(Main form of the LCL Steamworks demo.)

  Everything is on the form (uMain.lfm): the @code(TSteamAPI) root, the
  @code(TSteamFriends) / @code(TSteamUserStats) plug-in components with their
  events wired in the form file, and the UI. Only the Debug-only settings
  are made in FormCreate.

  @bold(Lazarus designer:) install packages/SteamworksLCL.lpk before opening
  uMain.lfm, so the IDE knows TSteamAPI, TSteamFriends and TSteamUserStats.
  Without it, if Lazarus offers to remove unknown classes, choose Cancel -
  otherwise the components are deleted from the form. The project requires
  the package too: it compiles the library through it.

  Start / Show info / Stop / Copy log, and three tabs - Output (the log, also
  appended to SteamDemo.log next to the executable), Personal (the user's
  avatar, persona, Steam ids, level, the friends list with avatars) and
  Achievements (icons, unlock state). }
unit uMain;

// No Steamworks.inc here: the demo has no path to the library sources
{$mode delphi}{$H+}

interface

uses
  SysUtils, Classes, Controls, Forms, StdCtrls, ComCtrls, ExtCtrls, Graphics,
  Steamworks.LCL,
  Steamworks.Types, Steamworks.SDKTypes, Steamworks.API, Steamworks.Callbacks, Steamworks.Core,
  Steamworks.Components, Steamworks.Plugin.Utils, Steamworks.Plugin.User, Steamworks.Plugin.Friends,
  Steamworks.Plugin.Apps, Steamworks.Plugin.UserStats;

type
  { The demo's main form (uMain.lfm). }
  TfrmSteamDemo = class(TForm)
    { Holds the Start / Show info / Stop / Copy log buttons. }
    pnlButtons: TPanel;
    { Starts Steam. }
    btnStart: TButton;
    { Logs versions and interface information, reloads the tabs. }
    btnInfo: TButton;
    { Shuts Steam down. }
    btnStop: TButton;
    { Copies the log to the clipboard. }
    btnCopy: TButton;
    { Output / Personal / Achievements. }
    pgcMain: TPageControl;
    { Output tab. }
    tsOutput: TTabSheet;
    { The log. }
    memLog: TMemo;
    { Personal tab. }
    tsPersonal: TTabSheet;
    { Top of the Personal tab: avatar and details. }
    pnlPersonalTop: TPanel;
    { The user's large avatar. }
    imgAvatar: TImage;
    { Persona, ids, level, ... }
    lvInfo: TListView;
    { Caption above the friends list. }
    lblFriends: TLabel;
    { Friends with avatars; Item.Caption = name, SubItems: status, level,
      SteamID (the SteamID text identifies the row). }
    lvFriends: TListView;
    { Achievements tab. }
    tsAchievements: TTabSheet;
    { Achievements with icons; SubItems: description, state, API name. }
    lvAchievements: TListView;
    { 64 x 64 friend avatars for @link(lvFriends). }
    ilFriends: TImageList;
    { 64 x 64 achievement icons for @link(lvAchievements). }
    ilAchievements: TImageList;
    { The Steam root component. Active is False in the form: the Start button
      opens Steam. }
    SteamAPI1: TSteamAPI;
    { ISteamFriends component (persona changes, avatars). }
    SteamFriends1: TSteamFriends;
    { ISteamUserStats component (stats received, achievement icons). }
    SteamUserStats1: TSteamUserStats;
    { Debug-only settings and the log file. }
    procedure FormCreate(Sender: TObject);
    { Shuts Steam down while the controls still exist. }
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
    { Start button. }
    procedure btnStartClick(Sender: TObject);
    { Show info button. }
    procedure btnInfoClick(Sender: TObject);
    { Stop button. }
    procedure btnStopClick(Sender: TObject);
    { Copy log button. }
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
    { SteamFriends1.OnPersonaStateChange (304). }
    procedure FriendPersonaChanged(Sender: TObject; const AData: PersonaStateChange_t);
    { SteamFriends1.OnAvatarImageLoaded (334). }
    procedure FriendAvatarLoaded(Sender: TObject; const AData: AvatarImageLoaded_t);
    { SteamUserStats1.OnUserStatsReceived (1101). }
    procedure StatsReceived(Sender: TObject; const AData: UserStatsReceived_t);
    { SteamUserStats1.OnUserAchievementIconFetched (1109). }
    procedure AchievementIconFetched(Sender: TObject; const AData: UserAchievementIconFetched_t);
  private
    { Log file every line is appended to; '' if it cannot be written. }
    FLogFile: string;
    { Appends a time-stamped line to the log and the log file. }
    procedure AddLog(const S: string);
    { Adds a Name / Value row to @link(lvInfo). }
    procedure AddInfo(const AName, AValue: string);
    { Puts a Steam image into AList (scaled to its size); returns the image
      index, or AIndex unchanged when the image is not available. }
    function SetListImage(AList: TImageList; AIndex, AImage: Integer): Integer;
    { Fills the Personal tab. }
    procedure LoadPersonal;
    { Fills the Achievements tab. }
    procedure LoadAchievements;
    { The friends-list item of ASteamID, or @nil. }
    function FindFriend(const ASteamID: TSteamID): TListItem;
    { Writes a friend's name / status / level / avatar into AItem. }
    procedure UpdateFriend(AItem: TListItem; const ASteamID: TSteamID);
    { The user's SteamID (invalid when Steam is not running). }
    function MySteamID: TSteamID;
  end;

var
  { The main form instance. }
  frmSteamDemo: TfrmSteamDemo;

implementation

{$R *.lfm}

uses
  Clipbrd;

const
  LevelNames: array[TSteamLogLevel] of string = ('debug', 'info', 'warn', 'ERROR');

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

{ TfrmSteamDemo }

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

procedure TfrmSteamDemo.FormCreate(Sender: TObject);
begin
  FLogFile := ExpandFileName(ExtractFilePath(ParamStr(0))) + 'SteamDemo.log';
  try
    with TFileStream.Create(FLogFile, fmCreate) do
      Free;
  except
    FLogFile := '';
  end;
  // AppID, UpdateMode, events and the plug-in links are set in the form file.
  // A form file cannot depend on the build configuration, so this is here:
  {$ifdef DEBUG}
  // Development: no steam_appid.txt needed, never relaunch through Steam
  SteamAPI1.SetAppIdEnvironment := True;
  SteamAPI1.RestartIfNecessary := False;
  {$else}
  SteamAPI1.RestartIfNecessary := True;
  {$endif}
  pgcMain.ActivePage := tsOutput;
  AddLog(Format('Steamworks LCL demo, AppID %d, %d plug-in class(es) linked',
    [SteamAPI1.AppID, Length(TSteamworks.RegisteredPlugins)]));
  if FLogFile <> '' then
    AddLog('Log file: ' + FLogFile)
  else
    AddLog('Log file could not be created; log is on screen only');
  AddLog(Format('Update mode (from the form): %s, delivery %s, interval %d ms',
    [UpdateModeText(SteamAPI1.UpdateMode), DeliveryText(SteamAPI1.Delivery),
     SteamAPI1.CallbackInterval]));
end;

procedure TfrmSteamDemo.AddLog(const S: string);
var
  Line: string;
  F: TextFile;
begin
  Line := FormatDateTime('hh:nn:ss.zzz', Now) + '  ' + S;
  memLog.Lines.Add(Line);
  if FLogFile = '' then
    Exit;
  try
    // Open, append, close per line: nothing is lost if the process is killed
    AssignFile(F, FLogFile);
    Append(F);
    try
      Writeln(F, Line);
    finally
      CloseFile(F);
    end;
  except
    FLogFile := '';
  end;
end;

procedure TfrmSteamDemo.AddInfo(const AName, AValue: string);
var
  Item: TListItem;
begin
  Item := lvInfo.Items.Add;
  Item.Caption := AName;
  Item.SubItems.Add(AValue);
end;

function TfrmSteamDemo.SetListImage(AList: TImageList; AIndex, AImage: Integer): Integer;
var
  Bmp, Scaled: TBitmap;
begin
  Result := AIndex;
  Bmp := TBitmap.Create;
  try
    if not SteamImageToBitmap(AImage, Bmp) then
      Exit;
    Scaled := Bmp;
    if (Bmp.Width <> AList.Width) or (Bmp.Height <> AList.Height) then
    begin
      Scaled := TBitmap.Create;
      Scaled.PixelFormat := pf32bit;
      Scaled.SetSize(AList.Width, AList.Height);
      Scaled.Canvas.StretchDraw(Rect(0, 0, AList.Width, AList.Height), Bmp);
    end;
    try
      if (AIndex >= 0) and (AIndex < AList.Count) then
        AList.Replace(AIndex, Scaled, nil)
      else
        Result := AList.Add(Scaled, nil);
    finally
      if Scaled <> Bmp then
        Scaled.Free;
    end;
  finally
    Bmp.Free;
  end;
end;

function TfrmSteamDemo.MySteamID: TSteamID;
var
  Usr: TSteamUserPlugin;
begin
  Result := TSteamID.Create(0);
  Usr := TSteamUserPlugin(SteamAPI1.Steam.FindPlugin(TSteamUserPlugin));
  if Usr <> nil then
    Result := Usr.GetSteamID;
end;

function TfrmSteamDemo.FindFriend(const ASteamID: TSteamID): TListItem;
var
  I: Integer;
  Key: string;
begin
  Key := ASteamID.ToString;
  for I := 0 to lvFriends.Items.Count - 1 do
    if lvFriends.Items[I].SubItems[2] = Key then
      Exit(lvFriends.Items[I]);
  Result := nil;
end;

procedure TfrmSteamDemo.UpdateFriend(AItem: TListItem; const ASteamID: TSteamID);
var
  Fr: TSteamFriendsPlugin;
  Name, Nick: string;
begin
  Fr := SteamFriends1.Plugin;
  if Fr = nil then
    Exit;
  Name := Fr.GetFriendPersonaName(ASteamID);
  Nick := Fr.GetPlayerNickname(ASteamID);
  if Nick <> '' then
    Name := Name + ' (' + Nick + ')';
  AItem.Caption := Name;
  AItem.SubItems[0] := PersonaStateText(Fr.GetFriendPersonaState(ASteamID));
  AItem.SubItems[1] := IntToStr(Fr.GetFriendSteamLevel(ASteamID));
  AItem.ImageIndex := SetListImage(ilFriends, AItem.ImageIndex, Fr.GetMediumFriendAvatar(ASteamID));
end;

procedure TfrmSteamDemo.LoadPersonal;
var
  Usr: TSteamUserPlugin;
  Fr: TSteamFriendsPlugin;
  U: TSteamUtilsPlugin;
  Me, Friend: TSteamID;
  I, Count, H: Integer;
  Item: TListItem;
begin
  Usr := TSteamUserPlugin(SteamAPI1.Steam.FindPlugin(TSteamUserPlugin));
  U := TSteamUtilsPlugin(SteamAPI1.Steam.FindPlugin(TSteamUtilsPlugin));
  Fr := SteamFriends1.Plugin;
  if (Usr = nil) or (Fr = nil) then
    Exit;
  try
    Me := Usr.GetSteamID;
    lvInfo.Items.BeginUpdate;
    try
      lvInfo.Items.Clear;
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
      lvInfo.Items.EndUpdate;
    end;

    // Own avatar: -1 = Steam is fetching it -> OnAvatarImageLoaded
    H := Fr.GetLargeFriendAvatar(Me);
    if H > 0 then
      SteamImageToBitmap(H, imgAvatar.Picture.Bitmap);
    AddLog(Format('Personal: %s (%s), level %d, large avatar handle %d',
      [Fr.GetPersonaName, Me.ToString, Usr.GetPlayerSteamLevel, H]));

    Count := Fr.GetFriendCount(k_EFriendFlagImmediate);
    lvFriends.Items.BeginUpdate;
    try
      lvFriends.Items.Clear;
      ilFriends.Clear;
      for I := 0 to Count - 1 do
      begin
        Friend := Fr.GetFriendByIndex(I, k_EFriendFlagImmediate);
        // Asks Steam for name / avatar if it does not have them yet
        // (answer: PersonaStateChange_t, then AvatarImageLoaded_t)
        Fr.RequestUserInformation(Friend, False);
        Item := lvFriends.Items.Add;
        Item.ImageIndex := -1;
        Item.SubItems.Add('');
        Item.SubItems.Add('');
        Item.SubItems.Add(Friend.ToString);
        UpdateFriend(Item, Friend);
        AddLog(Format('Friend %d: %s, medium avatar handle %d (-1 = loading, 0 = none)',
          [I, Item.Caption, Fr.GetMediumFriendAvatar(Friend)]));
      end;
    finally
      lvFriends.Items.EndUpdate;
    end;
    AddLog(Format('Personal: %d immediate friend(s) listed', [Count]));
  except
    on E: Exception do AddLog('Personal failed: ' + E.Message);
  end;
end;

procedure TfrmSteamDemo.LoadAchievements;
var
  S: TSteamUserStatsPlugin;
  I: Integer;
  N, UnlockTime: UInt32;
  AchName, Title, Desc, State: string;
  Achieved, Hidden: Boolean;
  Item: TListItem;
begin
  S := SteamUserStats1.Plugin;
  if S = nil then
    Exit;
  try
    N := S.GetNumAchievements;
    lvAchievements.Items.BeginUpdate;
    try
      lvAchievements.Items.Clear;
      ilAchievements.Clear;
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
        Item := lvAchievements.Items.Add;
        Item.Caption := Title;
        if Hidden and not Achieved then
          Item.SubItems.Add('Hidden achievement')
        else
          Item.SubItems.Add(Desc);
        Item.SubItems.Add(State);
        Item.SubItems.Add(AchName);   // API name (not a column): finds the row for the icon callback
        // 0: Steam fetches the icon, then callback 1109
        Item.ImageIndex := SetListImage(ilAchievements, -1, S.GetAchievementIcon(AchName));
        AddLog(Format('Achievement %d: %s "%s" %s, hidden %s', [I, AchName, Title, State,
          BoolToStr(Hidden, True)]));
      end;
    finally
      lvAchievements.Items.EndUpdate;
    end;
  except
    on E: Exception do AddLog('Achievements failed: ' + E.Message);
  end;
end;

procedure TfrmSteamDemo.btnStartClick(Sender: TObject);
begin
  AddLog('Start pressed');
  if SteamAPI1.Open then
    AddLog('Open returned True: Steam is running')
  else
    AddLog('Open returned False: Steam did not start');
end;

procedure TfrmSteamDemo.btnInfoClick(Sender: TObject);
var
  U: TSteamUtilsPlugin;
  Apps: TSteamAppsPlugin;
  Versions: TSteamStringArray;
  I: Integer;
begin
  if not SteamAPI1.IsRunning then
  begin
    AddLog('Info: Steam is not running - press Start first');
    Exit;
  end;
  Versions := SteamAPI1.Steam.Versions.ToArray;
  AddLog(Format('Library %s: %d interface versions detected', [TSteamLib.LibraryPath, Length(Versions)]));
  for I := 0 to High(Versions) do
    AddLog('  ' + Versions[I]);
  try
    U := TSteamUtilsPlugin(SteamAPI1.Steam.FindPlugin(TSteamUtilsPlugin));
    if U <> nil then
      AddLog(Format('ISteamUtils: AppID %d, country %s, UI language %s, overlay %s, server time (UTC) %s',
        [U.GetAppID, U.GetIPCountry, U.GetSteamUILanguage, BoolToStr(U.IsOverlayEnabled, True),
         FormatDateTime('yyyy-mm-dd hh:nn:ss', U.ServerTime)]));
    Apps := TSteamAppsPlugin(SteamAPI1.Steam.FindPlugin(TSteamAppsPlugin));
    if Apps <> nil then
      AddLog(Format('ISteamApps: subscribed %s, game language %s, build id %d',
        [BoolToStr(Apps.BIsSubscribed, True), Apps.GetCurrentGameLanguage, Apps.GetAppBuildId]));
  except
    on E: Exception do AddLog('Info failed: ' + E.Message);
  end;
  LoadPersonal;
  LoadAchievements;
end;

procedure TfrmSteamDemo.btnStopClick(Sender: TObject);
begin
  AddLog('Stop pressed');
  SteamAPI1.Close;
end;

procedure TfrmSteamDemo.btnCopyClick(Sender: TObject);
begin
  Clipboard.AsText := memLog.Lines.Text;
  AddLog('Log copied to clipboard');
end;

procedure TfrmSteamDemo.FormClose(Sender: TObject; var Action: TCloseAction);
begin
  AddLog(Format('FormClose: window closing (Steam running: %s)', [BoolToStr(SteamAPI1.IsRunning, True)]));
  SteamAPI1.Close;
end;

procedure TfrmSteamDemo.SteamLog(Sender: TObject; ALevel: TSteamLogLevel; const AMessage: string);
begin
  AddLog('[' + LevelNames[ALevel] + '] ' + AMessage);
end;

procedure TfrmSteamDemo.SteamInitialized(Sender: TObject);
begin
  AddLog(Format('OnInitialized: pipe %d, user %d, %d plug-in(s) active',
    [SteamAPI1.Steam.Pipe, SteamAPI1.Steam.User, SteamAPI1.Steam.PluginCount]));
  LoadPersonal;
  LoadAchievements;
end;

procedure TfrmSteamDemo.SteamInitFailed(Sender: TObject; AResult: Integer; const AMessage: string);
begin
  AddLog(Format('OnInitFailed: result %d: %s', [AResult, AMessage]));
end;

procedure TfrmSteamDemo.SteamShutdown(Sender: TObject);
begin
  AddLog('OnShutdown: SteamAPI shut down');
end;

procedure TfrmSteamDemo.SteamClientExit(Sender: TObject);
begin
  AddLog(Format('OnSteamShutdown: the Steam client is exiting; SteamAPI shuts down next: %s ' +
    '(the demo keeps running; press Start once Steam is back)', [BoolToStr(SteamAPI1.ShutdownOnSteamExit, True)]));
end;

procedure TfrmSteamDemo.SteamWarning(Sender: TObject; ASeverity: Integer; const AText: string);
begin
  AddLog(Format('Steam debug (severity %d): %s', [ASeverity, AText]));
end;

procedure TfrmSteamDemo.SteamCallback(Sender: TObject; const AData: TSteamCallbackData);
var
  Kind: string;
begin
  if AData.IsCallResult then
    Kind := ', call result'
  else
    Kind := '';
  AddLog(Format('Callback %d (%s), %d bytes%s', [AData.CallbackID,
    SteamCallbackGroupName(AData.CallbackID), AData.Size, Kind]));
end;

procedure TfrmSteamDemo.FriendPersonaChanged(Sender: TObject; const AData: PersonaStateChange_t);
var
  Id: TSteamID;
  Item: TListItem;
begin
  Id := TSteamID.Create(AData.m_ulSteamID);
  AddLog(Format('TSteamFriends.OnPersonaStateChange: SteamID %s, change flags $%x (attached %s)',
    [Id.ToString, AData.m_nChangeFlags, BoolToStr(SteamFriends1.Attached, True)]));
  Item := FindFriend(Id);
  if Item <> nil then
    UpdateFriend(Item, Id);
end;

procedure TfrmSteamDemo.FriendAvatarLoaded(Sender: TObject; const AData: AvatarImageLoaded_t);
var
  Item: TListItem;
begin
  AddLog(Format('TSteamFriends.OnAvatarImageLoaded: SteamID %s, image %d, %dx%d',
    [AData.m_steamID.ToString, AData.m_iImage, AData.m_iWide, AData.m_iTall]));
  // Large (184 px) avatar of the user -> the picture; medium ones -> the list
  if (AData.m_steamID = MySteamID) and (AData.m_iWide >= 184) then
    SteamImageToBitmap(AData.m_iImage, imgAvatar.Picture.Bitmap)
  else
  begin
    Item := FindFriend(AData.m_steamID);
    if Item <> nil then
      Item.ImageIndex := SetListImage(ilFriends, Item.ImageIndex, AData.m_iImage);
  end;
end;

procedure TfrmSteamDemo.StatsReceived(Sender: TObject; const AData: UserStatsReceived_t);
begin
  AddLog(Format('TSteamUserStats.OnUserStatsReceived: SteamID %s, result %d',
    [AData.m_steamIDUser.ToString, Ord(AData.m_eResult)]));
  if (AData.m_eResult = k_EResultOK) and (AData.m_steamIDUser = MySteamID) then
    LoadAchievements;
end;

procedure TfrmSteamDemo.AchievementIconFetched(Sender: TObject; const AData: UserAchievementIconFetched_t);
var
  AchName: string;
  I: Integer;
  Item: TListItem;
begin
  AchName := string(UTF8String(PAnsiChar(@AData.m_rgchAchievementName[0])));
  AddLog(Format('TSteamUserStats.OnUserAchievementIconFetched: %s, achieved %s, icon %d',
    [AchName, BoolToStr(AData.m_bAchieved, True), AData.m_nIconHandle]));
  for I := 0 to lvAchievements.Items.Count - 1 do
  begin
    Item := lvAchievements.Items[I];
    if (Item.SubItems.Count > 2) and (Item.SubItems[2] = AchName) then
      Item.ImageIndex := SetListImage(ilAchievements, Item.ImageIndex, AData.m_nIconHandle);
  end;
end;

end.
