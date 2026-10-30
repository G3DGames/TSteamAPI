{ @abstract(Main form of the VCL and LCL Steamworks demos - one source for both.)

  Delphi VCL (demos/SteamDemoVCL) and Lazarus LCL (demos/SteamDemoLCL) share
  their unit names and nearly all the APIs used here, so this unit compiles in
  both; the only difference is which unit declares TSteamAPI and
  SteamImageToBitmap (Steamworks.VCL / Steamworks.LCL). The whole UI is built
  in code (CreateNew), so there is no .dfm / .lfm to keep in step.

  Same behaviour as the FMX SteamDemo: Start / Show info / Stop / Copy log, and
  three tabs - Output (the log, also appended to SteamDemo.log next to the
  executable), Personal (the user's avatar, persona, Steam ids, level, the
  friends list with avatars) and Achievements (icons, unlock state). }
unit uSteamDemoDesktop;

// No Steamworks.inc here: the VCL demo has no path to the library sources
{$ifdef FPC}
  {$mode delphi}{$H+}
{$endif}

interface

uses
  SysUtils, Classes, Controls, Forms, StdCtrls, ComCtrls, ExtCtrls, Graphics,
  {$ifdef FPC}Steamworks.LCL{$else}Steamworks.VCL{$endif},
  Steamworks.Types, Steamworks.SDKTypes, Steamworks.API, Steamworks.Callbacks, Steamworks.Core,
  Steamworks.Components, Steamworks.Plugin.Utils, Steamworks.Plugin.User, Steamworks.Plugin.Friends,
  Steamworks.Plugin.Apps, Steamworks.Plugin.UserStats;

const
  { AppID of this project on Steam. }
  APP_ID = 2275430;

type
  { The demo's main form; create it with Application.CreateForm. }
  TfrmSteamDemo = class(TForm)
  private
    { Start / Show info / Stop / Copy log buttons. }
    FButtons: TPanel;
    { Output / Personal / Achievements. }
    FPages: TPageControl;
    { The log (Output tab). }
    FLog: TMemo;
    { The user's large avatar (Personal tab). }
    FAvatar: TImage;
    { Persona, ids, level, ... (Personal tab). }
    FInfo: TListView;
    { Friends with avatars (Personal tab); Item.Caption = name, SubItems:
      status, level, SteamID; Data unused, the SteamID text identifies it. }
    FFriendsList: TListView;
    { 64 x 64 friend avatars for @link(FFriendsList). }
    FFriendImages: TImageList;
    { Achievements with icons. }
    FAchievements: TListView;
    { 64 x 64 achievement icons for @link(FAchievements). }
    FAchievementImages: TImageList;
    { The Steam root component. }
    FSteam: TSteamAPI;
    { ISteamFriends component (persona changes, avatars). }
    FFriends: TSteamFriends;
    { ISteamUserStats component (stats received, achievement icons). }
    FStats: TSteamUserStats;
    { Log file every line is appended to; '' if it cannot be written. }
    FLogFile: string;
    { Adds a button to @link(FButtons). }
    function AddButton(const ACaption: string; ALeft: Integer; AClick: TNotifyEvent): TButton;
    { Adds a tab to @link(FPages). }
    function AddTab(const ACaption: string): TTabSheet;
    { Adds a report-style list view to AParent. }
    function AddListView(AParent: TWinControl; const AColumns: array of string;
      const AWidths: array of Integer): TListView;
    { Builds the whole UI. }
    procedure CreateControls;
    { Creates the Steam components and hooks their events. }
    procedure CreateSteam;
    { Appends a time-stamped line to the log and the log file. }
    procedure AddLog(const S: string);
    { Adds a Name / Value row to @link(FInfo). }
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

    { Start button. }
    procedure StartClick(Sender: TObject);
    { Show info button. }
    procedure InfoClick(Sender: TObject);
    { Stop button. }
    procedure StopClick(Sender: TObject);
    { Copy log button. }
    procedure CopyClick(Sender: TObject);
    { Shuts Steam down while the controls still exist. }
    procedure FormClose(Sender: TObject; var Action: TCloseAction);

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
    { TSteamFriends.OnPersonaStateChange (304). }
    procedure FriendPersonaChanged(Sender: TObject; const AData: PersonaStateChange_t);
    { TSteamFriends.OnAvatarImageLoaded (334). }
    procedure FriendAvatarLoaded(Sender: TObject; const AData: AvatarImageLoaded_t);
    { TSteamUserStats.OnUserStatsReceived (1101). }
    procedure StatsReceived(Sender: TObject; const AData: UserStatsReceived_t);
    { TSteamUserStats.OnUserAchievementIconFetched (1109). }
    procedure AchievementIconFetched(Sender: TObject; const AData: UserAchievementIconFetched_t);
  public
    { Builds the form in code (no form file). }
    constructor Create(AOwner: TComponent); override;
  end;

var
  { The main form instance. }
  frmSteamDemo: TfrmSteamDemo;

implementation

uses
  {$ifndef FPC}ImgList,{$endif}  // cd32Bit
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

constructor TfrmSteamDemo.Create(AOwner: TComponent);
begin
  inherited CreateNew(AOwner);
  Caption := Format('Steamworks %s Demo - AppID %d (SDK 1.65)',
    [{$ifdef FPC}'LCL'{$else}'VCL'{$endif}, APP_ID]);
  Width := 960;
  Height := 640;
  Position := poScreenCenter;
  OnClose := FormClose;
  FLogFile := ExpandFileName(ExtractFilePath(ParamStr(0))) + 'SteamDemo.log';
  try
    with TFileStream.Create(FLogFile, fmCreate) do
      Free;
  except
    FLogFile := '';
  end;
  CreateControls;
  CreateSteam;
  AddLog(Format('Steamworks %s demo, AppID %d, %d plug-in class(es) linked',
    [{$ifdef FPC}'LCL'{$else}'VCL'{$endif}, APP_ID, Length(TSteamworks.RegisteredPlugins)]));
  if FLogFile <> '' then
    AddLog('Log file: ' + FLogFile)
  else
    AddLog('Log file could not be created; log is on screen only');
end;

function TfrmSteamDemo.AddButton(const ACaption: string; ALeft: Integer; AClick: TNotifyEvent): TButton;
begin
  Result := TButton.Create(Self);
  Result.Parent := FButtons;
  Result.SetBounds(ALeft, 10, 110, 28);
  Result.Caption := ACaption;
  Result.OnClick := AClick;
end;

function TfrmSteamDemo.AddTab(const ACaption: string): TTabSheet;
begin
  Result := TTabSheet.Create(Self);
  Result.PageControl := FPages;
  Result.Caption := ACaption;
end;

function TfrmSteamDemo.AddListView(AParent: TWinControl; const AColumns: array of string;
  const AWidths: array of Integer): TListView;
var
  I: Integer;
  Col: TListColumn;
begin
  Result := TListView.Create(Self);
  Result.Parent := AParent;
  Result.Align := alClient;
  Result.ViewStyle := vsReport;
  Result.ReadOnly := True;
  Result.RowSelect := True;
  for I := 0 to High(AColumns) do
  begin
    Col := Result.Columns.Add;
    Col.Caption := AColumns[I];
    Col.Width := AWidths[I];
  end;
end;

procedure TfrmSteamDemo.CreateControls;
var
  Tab: TTabSheet;
  TopArea: TPanel;
  FriendsCaption: TLabel;
begin
  FButtons := TPanel.Create(Self);
  FButtons.Parent := Self;
  FButtons.Align := alTop;
  FButtons.Height := 48;
  FButtons.BevelOuter := bvNone;
  AddButton('Start Steam', 8, StartClick);
  AddButton('Show info', 126, InfoClick);
  AddButton('Stop Steam', 244, StopClick);
  AddButton('Copy log', 362, CopyClick);

  FPages := TPageControl.Create(Self);
  FPages.Parent := Self;
  FPages.Align := alClient;

  Tab := AddTab('Output');
  FLog := TMemo.Create(Self);
  FLog.Parent := Tab;
  FLog.Align := alClient;
  FLog.ReadOnly := True;
  FLog.ScrollBars := ssBoth;
  FLog.WordWrap := False;

  Tab := AddTab('Personal');
  TopArea := TPanel.Create(Self);
  TopArea.Parent := Tab;
  TopArea.Align := alTop;
  TopArea.Height := 200;
  TopArea.BevelOuter := bvNone;
  FAvatar := TImage.Create(Self);
  FAvatar.Parent := TopArea;
  FAvatar.Align := alLeft;
  FAvatar.Width := 200;
  FAvatar.Center := True;
  FInfo := AddListView(TopArea, ['Item', 'Value'], [160, 400]);
  FriendsCaption := TLabel.Create(Self);
  FriendsCaption.Parent := Tab;
  FriendsCaption.Align := alTop;
  FriendsCaption.Caption := ' Friends';
  FFriendImages := TImageList.Create(Self);
  {$ifndef FPC}FFriendImages.ColorDepth := cd32Bit;{$endif}  // keep alpha
  FFriendImages.Width := 64;
  FFriendImages.Height := 64;
  FFriendsList := AddListView(Tab, ['Name', 'Status', 'Level', 'SteamID'], [260, 140, 60, 160]);
  FFriendsList.SmallImages := FFriendImages;

  Tab := AddTab('Achievements');
  FAchievementImages := TImageList.Create(Self);
  {$ifndef FPC}FAchievementImages.ColorDepth := cd32Bit;{$endif}
  FAchievementImages.Width := 64;
  FAchievementImages.Height := 64;
  FAchievements := AddListView(Tab, ['Achievement', 'Description', 'State'], [220, 400, 200]);
  FAchievements.SmallImages := FAchievementImages;

  FPages.ActivePageIndex := 0;
end;

procedure TfrmSteamDemo.CreateSteam;
begin
  FSteam := TSteamAPI.Create(Self);
  FSteam.AppID := APP_ID;
  {$ifdef DEBUG}
  // Development: no steam_appid.txt needed, never relaunch through Steam
  FSteam.SetAppIdEnvironment := True;
  {$else}
  FSteam.RestartIfNecessary := True;
  {$endif}
  FSteam.OnLog := SteamLog;
  FSteam.OnInitialized := SteamInitialized;
  FSteam.OnInitFailed := SteamInitFailed;
  FSteam.OnShutdown := SteamShutdown;
  FSteam.OnSteamShutdown := SteamClientExit;
  FSteam.OnWarning := SteamWarning;
  FSteam.OnCallback := SteamCallback;
  FFriends := TSteamFriends.Create(Self);
  FFriends.SteamAPI := FSteam;
  FFriends.OnPersonaStateChange := FriendPersonaChanged;
  FFriends.OnAvatarImageLoaded := FriendAvatarLoaded;
  FStats := TSteamUserStats.Create(Self);
  FStats.SteamAPI := FSteam;
  FStats.OnUserStatsReceived := StatsReceived;
  FStats.OnUserAchievementIconFetched := AchievementIconFetched;
end;

procedure TfrmSteamDemo.AddLog(const S: string);
var
  Line: string;
  F: TextFile;
begin
  Line := FormatDateTime('hh:nn:ss.zzz', Now) + '  ' + S;
  FLog.Lines.Add(Line);
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
  Item := FInfo.Items.Add;
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
  Usr := TSteamUserPlugin(FSteam.Steam.FindPlugin(TSteamUserPlugin));
  if Usr <> nil then
    Result := Usr.GetSteamID;
end;

function TfrmSteamDemo.FindFriend(const ASteamID: TSteamID): TListItem;
var
  I: Integer;
  Key: string;
begin
  Key := ASteamID.ToString;
  for I := 0 to FFriendsList.Items.Count - 1 do
    if FFriendsList.Items[I].SubItems[2] = Key then
      Exit(FFriendsList.Items[I]);
  Result := nil;
end;

procedure TfrmSteamDemo.UpdateFriend(AItem: TListItem; const ASteamID: TSteamID);
var
  Fr: TSteamFriendsPlugin;
  Name, Nick: string;
begin
  Fr := FFriends.Plugin;
  if Fr = nil then
    Exit;
  Name := Fr.GetFriendPersonaName(ASteamID);
  Nick := Fr.GetPlayerNickname(ASteamID);
  if Nick <> '' then
    Name := Name + ' (' + Nick + ')';
  AItem.Caption := Name;
  AItem.SubItems[0] := PersonaStateText(Fr.GetFriendPersonaState(ASteamID));
  AItem.SubItems[1] := IntToStr(Fr.GetFriendSteamLevel(ASteamID));
  AItem.ImageIndex := SetListImage(FFriendImages, AItem.ImageIndex, Fr.GetMediumFriendAvatar(ASteamID));
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
  Usr := TSteamUserPlugin(FSteam.Steam.FindPlugin(TSteamUserPlugin));
  U := TSteamUtilsPlugin(FSteam.Steam.FindPlugin(TSteamUtilsPlugin));
  Fr := FFriends.Plugin;
  if (Usr = nil) or (Fr = nil) then
    Exit;
  try
    Me := Usr.GetSteamID;
    FInfo.Items.BeginUpdate;
    try
      FInfo.Items.Clear;
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
      FInfo.Items.EndUpdate;
    end;

    // Own avatar: -1 = Steam is fetching it -> OnAvatarImageLoaded
    H := Fr.GetLargeFriendAvatar(Me);
    if H > 0 then
      SteamImageToBitmap(H, FAvatar.Picture.Bitmap);
    AddLog(Format('Personal: %s (%s), level %d, large avatar handle %d',
      [Fr.GetPersonaName, Me.ToString, Usr.GetPlayerSteamLevel, H]));

    Count := Fr.GetFriendCount(k_EFriendFlagImmediate);
    FFriendsList.Items.BeginUpdate;
    try
      FFriendsList.Items.Clear;
      FFriendImages.Clear;
      for I := 0 to Count - 1 do
      begin
        Friend := Fr.GetFriendByIndex(I, k_EFriendFlagImmediate);
        // Asks Steam for name / avatar if it does not have them yet
        // (answer: PersonaStateChange_t, then AvatarImageLoaded_t)
        Fr.RequestUserInformation(Friend, False);
        Item := FFriendsList.Items.Add;
        Item.ImageIndex := -1;
        Item.SubItems.Add('');
        Item.SubItems.Add('');
        Item.SubItems.Add(Friend.ToString);
        UpdateFriend(Item, Friend);
        AddLog(Format('Friend %d: %s, medium avatar handle %d (-1 = loading, 0 = none)',
          [I, Item.Caption, Fr.GetMediumFriendAvatar(Friend)]));
      end;
    finally
      FFriendsList.Items.EndUpdate;
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
  S := FStats.Plugin;
  if S = nil then
    Exit;
  try
    N := S.GetNumAchievements;
    FAchievements.Items.BeginUpdate;
    try
      FAchievements.Items.Clear;
      FAchievementImages.Clear;
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
        Item := FAchievements.Items.Add;
        Item.Caption := Title;
        if Hidden and not Achieved then
          Item.SubItems.Add('Hidden achievement')
        else
          Item.SubItems.Add(Desc);
        Item.SubItems.Add(State);
        Item.SubItems.Add(AchName);   // API name (not a column): finds the row for the icon callback
        // 0: Steam fetches the icon, then callback 1109
        Item.ImageIndex := SetListImage(FAchievementImages, -1, S.GetAchievementIcon(AchName));
        AddLog(Format('Achievement %d: %s "%s" %s, hidden %s', [I, AchName, Title, State,
          BoolToStr(Hidden, True)]));
      end;
    finally
      FAchievements.Items.EndUpdate;
    end;
  except
    on E: Exception do AddLog('Achievements failed: ' + E.Message);
  end;
end;

procedure TfrmSteamDemo.StartClick(Sender: TObject);
begin
  AddLog('Start pressed');
  if FSteam.Open then
    AddLog('Open returned True: Steam is running')
  else
    AddLog('Open returned False: Steam did not start');
end;

procedure TfrmSteamDemo.InfoClick(Sender: TObject);
var
  U: TSteamUtilsPlugin;
  Apps: TSteamAppsPlugin;
  Versions: TSteamStringArray;
  I: Integer;
begin
  if not FSteam.IsRunning then
  begin
    AddLog('Info: Steam is not running - press Start first');
    Exit;
  end;
  Versions := FSteam.Steam.Versions.ToArray;
  AddLog(Format('Library %s: %d interface versions detected', [TSteamLib.LibraryPath, Length(Versions)]));
  for I := 0 to High(Versions) do
    AddLog('  ' + Versions[I]);
  try
    U := TSteamUtilsPlugin(FSteam.Steam.FindPlugin(TSteamUtilsPlugin));
    if U <> nil then
      AddLog(Format('ISteamUtils: AppID %d, country %s, UI language %s, overlay %s, server time (UTC) %s',
        [U.GetAppID, U.GetIPCountry, U.GetSteamUILanguage, BoolToStr(U.IsOverlayEnabled, True),
         FormatDateTime('yyyy-mm-dd hh:nn:ss', U.ServerTime)]));
    Apps := TSteamAppsPlugin(FSteam.Steam.FindPlugin(TSteamAppsPlugin));
    if Apps <> nil then
      AddLog(Format('ISteamApps: subscribed %s, game language %s, build id %d',
        [BoolToStr(Apps.BIsSubscribed, True), Apps.GetCurrentGameLanguage, Apps.GetAppBuildId]));
  except
    on E: Exception do AddLog('Info failed: ' + E.Message);
  end;
  LoadPersonal;
  LoadAchievements;
end;

procedure TfrmSteamDemo.StopClick(Sender: TObject);
begin
  AddLog('Stop pressed');
  FSteam.Close;
end;

procedure TfrmSteamDemo.CopyClick(Sender: TObject);
begin
  Clipboard.AsText := FLog.Lines.Text;
  AddLog('Log copied to clipboard');
end;

procedure TfrmSteamDemo.FormClose(Sender: TObject; var Action: TCloseAction);
begin
  AddLog(Format('FormClose: window closing (Steam running: %s)', [BoolToStr(FSteam.IsRunning, True)]));
  FSteam.Close;
end;

procedure TfrmSteamDemo.SteamLog(Sender: TObject; ALevel: TSteamLogLevel; const AMessage: string);
begin
  AddLog('[' + LevelNames[ALevel] + '] ' + AMessage);
end;

procedure TfrmSteamDemo.SteamInitialized(Sender: TObject);
begin
  AddLog(Format('OnInitialized: pipe %d, user %d, %d plug-in(s) active',
    [FSteam.Steam.Pipe, FSteam.Steam.User, FSteam.Steam.PluginCount]));
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
    '(the demo keeps running; press Start once Steam is back)', [BoolToStr(FSteam.ShutdownOnSteamExit, True)]));
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
    [Id.ToString, AData.m_nChangeFlags, BoolToStr(FFriends.Attached, True)]));
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
    SteamImageToBitmap(AData.m_iImage, FAvatar.Picture.Bitmap)
  else
  begin
    Item := FindFriend(AData.m_steamID);
    if Item <> nil then
      Item.ImageIndex := SetListImage(FFriendImages, Item.ImageIndex, AData.m_iImage);
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
  for I := 0 to FAchievements.Items.Count - 1 do
  begin
    Item := FAchievements.Items[I];
    if (Item.SubItems.Count > 2) and (Item.SubItems[2] = AchName) then
      Item.ImageIndex := SetListImage(FAchievementImages, Item.ImageIndex, AData.m_nIconHandle);
  end;
end;

end.
