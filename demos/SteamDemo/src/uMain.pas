{ @abstract(Main form of the FMX Steamworks demo.)

  Everything is on the form (uMain.fmx): the @code(TSteamAPI) root, the
  @code(TSteamFriends) / @code(TSteamUserStats) plug-in components with their
  events wired in the form file, and the UI. Open it in the IDE with the
  design packages installed (dclSteamworks, dclSteamworksFMX) to see them;
  only the Debug-only settings are made in FormCreate. Four tabs: Output (the
  log), Personal (the user's avatar, persona, Steam ids, level, country and the
  friends list with avatars), Achievements (icons, unlock state) and
  Components (the base test of the other 21 plug-in components - Utils,
  User, Apps, RemoteStorage, Screenshots, Timeline, UGC, Matchmaking,
  Parties, Music, HTTP, HTMLSurface, Inventory, Video, ParentalSettings,
  RemotePlay, Networking, NetworkingSockets, NetworkingMessages,
  NetworkingUtils, MatchmakingServers - dropped on the form with their events wired; Test components
  runs it, see btnTestClick). It
  starts and stops Steam on demand and logs everything the core reports, so
  the Debug log can be pasted back as test evidence. The buttons are enabled
  only when they make sense (Start while Steam is stopped, the others while
  it runs). File menu: Auto Start Steam (on / off, saved per user - see
  SettingsFolder), Take Screenshot (this window to Steam), Copy Log, Exit; on Linux FmxLinuxMenu swaps the menu for
  FMX's own menu bar. Every log line is also
  appended to SteamDemo.log (next to the executable; the documents folder on
  Android) as it is written, so the log survives if the process is killed. }
unit uMain;

interface

uses
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
  Steamworks.Plugin.Matchmaking, Steamworks.Plugin.Parties, Steamworks.Plugin.Music,
  Steamworks.Plugin.HTTP, Steamworks.Plugin.HTMLSurface, Steamworks.Plugin.Inventory,
  Steamworks.Plugin.Video, Steamworks.Plugin.ParentalSettings, Steamworks.Plugin.RemotePlay,
  Steamworks.Plugin.Networking, Steamworks.Plugin.NetworkingSockets,
  Steamworks.Plugin.NetworkingMessages, Steamworks.Plugin.NetworkingUtils,
  Steamworks.Plugin.MatchmakingServers;

const
  { AppID of this project on Steam. }
  APP_ID = 2275430;
  { Component test: index of TSteamUtils in @code(TfrmMain.FTests). }
  CT_UTILS = 0;
  { Component test: index of TSteamUser. }
  CT_USER = 1;
  { Component test: index of TSteamApps. }
  CT_APPS = 2;
  { Component test: index of TSteamRemoteStorage. }
  CT_STORAGE = 3;
  { Component test: index of TSteamScreenshots. }
  CT_SHOTS = 4;
  { Component test: index of TSteamTimeline. }
  CT_TIMELINE = 5;
  { Component test: index of TSteamUGC. }
  CT_UGC = 6;
  { Component test: index of TSteamMatchmaking (batch 2a from here on). }
  CT_MATCHMAKING = 7;
  { Component test: index of TSteamParties. }
  CT_PARTIES = 8;
  { Component test: index of TSteamMusic. }
  CT_MUSIC = 9;
  { Component test: index of TSteamHTTP. }
  CT_HTTP = 10;
  { Component test: index of TSteamHTMLSurface. }
  CT_HTML = 11;
  { Component test: index of TSteamInventory. }
  CT_INVENTORY = 12;
  { Component test: index of TSteamVideo. }
  CT_VIDEO = 13;
  { Component test: index of TSteamParentalSettings. }
  CT_PARENTAL = 14;
  { Component test: index of TSteamRemotePlay. }
  CT_REMOTEPLAY = 15;
  { Component test: index of TSteamNetworking. }
  CT_NETWORKING = 16;
  { Component test: index of TSteamNetworkingSockets. }
  CT_NETSOCKETS = 17;
  { Component test: index of TSteamNetworkingMessages. }
  CT_NETMESSAGES = 18;
  { Component test: index of TSteamNetworkingUtils. }
  CT_NETUTILS = 19;
  { Component test: index of TSteamMatchmakingServers. }
  CT_SERVERS = 20;
  { Number of components the component test covers. }
  CT_COUNT = 21;
  { AppID whose Internet server list the MatchmakingServers test reads: a
    game with many public servers (Counter-Strike 2), so ServerResponded
    and the ping / players / rules queries meet a real server. Read-only. }
  TEST_SERVER_APP = 730;
  { The MatchmakingServers test releases the Internet list once this many
    servers answered and one of them has a direct address... }
  TEST_SERVER_MAX = 5;
  { ... or after this many, whatever their addresses. Many big servers sit
    behind Steam's relay network and report a FAKE IP (169.254.x.x, see
    ISteamNetworkingFakeIP): ping / players / rules cannot reach those
    (first run, 2026-11-02: all three failed), so the test queries the
    first server with a direct address. }
  TEST_SERVER_LIMIT = 50;
  { URL the HTTP test fetches: Steam's own Web API server-info call (no key
    needed, small JSON answer). }
  TEST_HTTP_URL = 'https://api.steampowered.com/ISteamWebAPIUtil/GetServerInfo/v1/';
  { A requested callback / call result that has not arrived after this many
    milliseconds is reported as NO ANSWER and the component fails. }
  TEST_TIMEOUT_MS = 20000;
  { Steam Cloud file the RemoteStorage test writes, reads back and deletes. }
  TEST_CLOUD_FILE = 'steamdemo_component_test.txt';

type
  { State of one component in the component test (see
    @code(TfrmMain.btnTestClick)). }
  TComponentTestState = record
    { The test ran for this component. }
    Ran: Boolean;
    { The component was attached (its callback events subscribed). }
    Attached: Boolean;
    { Every synchronous call (reads and actions) returned without an exception. }
    ReadsOK: Boolean;
    { Callbacks / call results requested. }
    Sent: Integer;
    { Requested callbacks / call results that arrived through the component's events. }
    Arrived: Integer;
    { Requests that never answered (timeout or no call handle), comma separated. }
    Missing: string;
    { Extra information shown in the Components tab (result codes, ...). }
    Note: string;
  end;

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
    { Runs the base test of the 16 plug-in components on the Components tab. }
    btnTest: TButton;
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
      details. Item I belongs to FTests[I]. }
    lbComponents: TListBox;
    { Checks the component test once a second for answers that are overdue
      (@link(TEST_TIMEOUT_MS)); enabled only while the test runs. }
    tmTests: TTimer;
    { The Steam root component. Active is False in the form: the Start button
      opens Steam. }
    SteamAPI1: TSteamAPI;
    { ISteamFriends component linked to @link(SteamAPI1); its typed events
      show persona changes and loaded avatars. }
    SteamFriends1: TSteamFriends;
    { ISteamUserStats component: stats received, achievement icons fetched. }
    SteamUserStats1: TSteamUserStats;
    { ISteamUtils component (component test): CheckFileSignature result, IP
      country and low-battery events. }
    SteamUtils1: TSteamUtils;
    { ISteamUser component (component test): auth ticket, duration control,
      Steam server connection events. }
    SteamUser1: TSteamUser;
    { ISteamApps component (component test): file details, DLC installed,
      URL launch parameters, timed trial. }
    SteamApps1: TSteamApps;
    { ISteamRemoteStorage component (component test): asynchronous write /
      read of @link(TEST_CLOUD_FILE), local file changes. }
    SteamRemoteStorage1: TSteamRemoteStorage;
    { ISteamScreenshots component: hook on / off in the component test;
      File > Take Screenshot writes one, OnScreenshotReady tags it. }
    SteamScreenshots1: TSteamScreenshots;
    { ISteamTimeline component (component test): event and game phase
      recording queries. }
    SteamTimeline1: TSteamTimeline;
    { ISteamUGC component (component test): Workshop query, EULA status,
      subscription and install events. }
    SteamUGC1: TSteamUGC;
    { ISteamMatchmaking component (component test): lobby list request. }
    SteamMatchmaking1: TSteamMatchmaking;
    { ISteamParties component (component test): beacon counts (reads only). }
    SteamParties1: TSteamParties;
    { ISteamMusic component (component test): Steam music player state (reads only). }
    SteamMusic1: TSteamMusic;
    { ISteamHTTP component (component test): one GET request. }
    SteamHTTP1: TSteamHTTP;
    { ISteamHTMLSurface component (component test): browser created and removed. }
    SteamHTMLSurface1: TSteamHTMLSurface;
    { ISteamInventory component (component test): GetAllItems result. }
    SteamInventory1: TSteamInventory;
    { ISteamVideo component (component test): broadcasting state, OPF settings. }
    SteamVideo1: TSteamVideo;
    { ISteamParentalSettings component (component test): lock / block state (reads only). }
    SteamParentalSettings1: TSteamParentalSettings;
    { ISteamRemotePlay component (component test): session count (reads only). }
    SteamRemotePlay1: TSteamRemotePlay;
    { ISteamNetworking component (component test): P2P packet check (reads only). }
    SteamNetworking1: TSteamNetworking;
    { ISteamNetworkingSockets component (component test): a socket pair, one
      message, closed. }
    SteamNetworkingSockets1: TSteamNetworkingSockets;
    { ISteamNetworkingMessages component (component test): channel 0 polled (reads only). }
    SteamNetworkingMessages1: TSteamNetworkingMessages;
    { ISteamNetworkingUtils component (component test): timestamp, relay status. }
    SteamNetworkingUtils1: TSteamNetworkingUtils;
    { ISteamMatchmakingServers component (component test): LAN and Internet
      server lists, ping / players / rules of one server. }
    SteamMatchmakingServers1: TSteamMatchmakingServers;
    { Debug-only settings and the log file. }
    procedure FormCreate(Sender: TObject);
    { Frees the component test's pending list. }
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
    { SteamUtils1.OnCheckFileSignature (call result 705). }
    procedure UtilsCheckFileSignature(Sender: TObject; const AData: CheckFileSignature_t);
    { SteamUtils1.OnIPCountry (callback 701; not requested by the test). }
    procedure UtilsIPCountry(Sender: TObject; const AData: IPCountry_t);
    { SteamUtils1.OnLowBatteryPower (callback 702; not requested by the test). }
    procedure UtilsLowBattery(Sender: TObject; const AData: LowBatteryPower_t);
    { SteamUser1.OnGetAuthSessionTicketResponse (callback 163): the ticket
      is cancelled again. }
    procedure UserAuthTicketResponse(Sender: TObject; const AData: GetAuthSessionTicketResponse_t);
    { SteamUser1.OnDurationControl (call result 167). }
    procedure UserDurationControl(Sender: TObject; const AData: DurationControl_t);
    { SteamUser1.OnSteamServersConnected (callback 101; not requested by the test). }
    procedure UserServersConnected(Sender: TObject; const AData: SteamServersConnected_t);
    { SteamUser1.OnSteamServersDisconnected (callback 103; not requested by the test). }
    procedure UserServersDisconnected(Sender: TObject; const AData: SteamServersDisconnected_t);
    { SteamUser1.OnSteamServerConnectFailure (callback 102; not requested by the test). }
    procedure UserServerConnectFailure(Sender: TObject; const AData: SteamServerConnectFailure_t);
    { SteamApps1.OnFileDetailsResult (call result 1023). }
    procedure AppsFileDetails(Sender: TObject; const AData: FileDetailsResult_t);
    { SteamApps1.OnDlcInstalled (callback 1005; not requested by the test). }
    procedure AppsDlcInstalled(Sender: TObject; const AData: DlcInstalled_t);
    { SteamApps1.OnNewUrlLaunchParameters (callback 1014; not requested by the test). }
    procedure AppsNewUrlLaunchParameters(Sender: TObject; const AData: NewUrlLaunchParameters_t);
    { SteamApps1.OnTimedTrialStatus (callback 1030; not requested by the test). }
    procedure AppsTimedTrialStatus(Sender: TObject; const AData: TimedTrialStatus_t);
    { SteamRemoteStorage1.OnRemoteStorageFileWriteAsyncComplete (call result
      1331): on success the file is read back asynchronously. }
    procedure StorageWriteComplete(Sender: TObject; const AData: RemoteStorageFileWriteAsyncComplete_t);
    { SteamRemoteStorage1.OnRemoteStorageFileReadAsyncComplete (call result
      1332): the data is fetched, compared and the file deleted. }
    procedure StorageReadComplete(Sender: TObject; const AData: RemoteStorageFileReadAsyncComplete_t);
    { SteamRemoteStorage1.OnRemoteStorageLocalFileChange (callback 1333; not
      requested by the test). }
    procedure StorageLocalFileChange(Sender: TObject; const AData: RemoteStorageLocalFileChange_t);
    { SteamScreenshots1.OnScreenshotRequested (callback 2302): writes the
      test picture with WriteScreenshot. }
    procedure ScreenshotRequested(Sender: TObject; const AData: ScreenshotRequested_t);
    { SteamScreenshots1.OnScreenshotReady (callback 2301): tags the picture
      with a location. }
    procedure ScreenshotReady(Sender: TObject; const AData: ScreenshotReady_t);
    { SteamTimeline1.OnSteamTimelineEventRecordingExists (call result 6002). }
    procedure TimelineEventRecordingExists(Sender: TObject; const AData: SteamTimelineEventRecordingExists_t);
    { SteamTimeline1.OnSteamTimelineGamePhaseRecordingExists (call result 6001). }
    procedure TimelinePhaseRecordingExists(Sender: TObject; const AData: SteamTimelineGamePhaseRecordingExists_t);
    { SteamUGC1.OnSteamUGCQueryCompleted (call result 3401): logs up to three
      items and releases the query. }
    procedure UGCQueryCompleted(Sender: TObject; const AData: SteamUGCQueryCompleted_t);
    { SteamUGC1.OnWorkshopEULAStatus (call result 3420). }
    procedure UGCWorkshopEULAStatus(Sender: TObject; const AData: WorkshopEULAStatus_t);
    { SteamUGC1.OnUserSubscribedItemsListChanged (callback 3418; not requested by the test). }
    procedure UGCSubscribedListChanged(Sender: TObject; const AData: UserSubscribedItemsListChanged_t);
    { SteamUGC1.OnItemInstalled (callback 3405; not requested by the test). }
    procedure UGCItemInstalled(Sender: TObject; const AData: ItemInstalled_t);
    { SteamMatchmaking1.OnLobbyMatchList (call result 510). }
    procedure MatchmakingLobbyMatchList(Sender: TObject; const AData: LobbyMatchList_t);
    { SteamHTTP1.OnHTTPRequestCompleted (call result 2101): status, body
      size and the start of the body; the request is released. }
    procedure HTTPRequestCompleted(Sender: TObject; const AData: HTTPRequestCompleted_t);
    { SteamHTMLSurface1.OnHTML_BrowserReady (call result 4501): the browser
      is removed again. }
    procedure HTMLBrowserReady(Sender: TObject; const AData: HTML_BrowserReady_t);
    { SteamInventory1.OnSteamInventoryResultReady (callback 4700): item
      count; the result is destroyed. }
    procedure InventoryResultReady(Sender: TObject; const AData: SteamInventoryResultReady_t);
    { SteamVideo1.OnGetOPFSettingsResult (callback 4624). }
    procedure VideoOPFSettingsResult(Sender: TObject; const AData: GetOPFSettingsResult_t);
    { SteamNetworkingSockets1.OnSteamNetConnectionStatusChangedCallback
      (callback 1221): the far side of the test socket pair closing. }
    procedure NetConnectionStatusChanged(Sender: TObject; const AData: SteamNetConnectionStatusChangedCallback_t);
    { SteamNetworkingUtils1.OnSteamRelayNetworkStatus (callback 1281): logged only. }
    procedure RelayNetworkStatus(Sender: TObject; const AData: SteamRelayNetworkStatus_t);
    { SteamMatchmakingServers1.OnServerResponded: a server of a test list answered. }
    procedure ServersResponded(Sender: TObject; ARequest: HServerListRequest; AIndex: Integer;
      const AServer: gameserveritem_t);
    { SteamMatchmakingServers1.OnServerFailedToRespond: counted. }
    procedure ServersFailed(Sender: TObject; ARequest: HServerListRequest; AIndex: Integer);
    { SteamMatchmakingServers1.OnServerListComplete: a test list has ended. }
    procedure ServerListComplete(Sender: TObject; ARequest: HServerListRequest;
      AResponse: EMatchMakingServerResponse);
    { SteamMatchmakingServers1.OnPingResponded. }
    procedure PingResponded(Sender: TObject; AQuery: HServerQuery; const AServer: gameserveritem_t);
    { SteamMatchmakingServers1.OnPingFailed. }
    procedure PingFailed(Sender: TObject; AQuery: HServerQuery);
    { SteamMatchmakingServers1.OnPlayer: counted, the first three logged. }
    procedure ServerPlayer(Sender: TObject; AQuery: HServerQuery; const AName: string;
      AScore: Integer; ATimePlayed: Single);
    { SteamMatchmakingServers1.OnPlayersFailed. }
    procedure PlayersFailed(Sender: TObject; AQuery: HServerQuery);
    { SteamMatchmakingServers1.OnPlayersComplete. }
    procedure PlayersComplete(Sender: TObject; AQuery: HServerQuery);
    { SteamMatchmakingServers1.OnRule: counted, the first three logged. }
    procedure ServerRule(Sender: TObject; AQuery: HServerQuery; const ARule, AValue: string);
    { SteamMatchmakingServers1.OnRulesFailed. }
    procedure RulesFailed(Sender: TObject; AQuery: HServerQuery);
    { SteamMatchmakingServers1.OnRulesComplete. }
    procedure RulesComplete(Sender: TObject; AQuery: HServerQuery);
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
    { Component test state, indexed by the CT_ constants. }
    FTests: array[0..CT_COUNT - 1] of TComponentTestState;
    { Requests awaiting an answer: key '<CT index>:<name>', value the
      TThread.GetTickCount at which it was sent. }
    FPending: TDictionary<string, Cardinal>;
    { @true from Test components until every answer arrived or timed out. }
    FTestsRunning: Boolean;
    { Auth ticket the User test asked for; cancelled when its answer arrives
      or the test ends (0 = none). }
    FAuthTicket: HAuthTicket;
    { Workshop query the UGC test sent; released when it completes or the
      test ends (k_UGCQueryHandleInvalid = none). }
    FUGCQuery: UGCQueryHandle_t;
    { Bytes the RemoteStorage test wrote, compared with what is read back. }
    FCloudData: TBytes;
    { Game phase id the Timeline test used (unique per run). }
    FPhaseID: string;
    { HTTP request the HTTP test sent; released when it completes or the
      test ends (0 = none). }
    FHTTPRequest: HTTPRequestHandle;
    { @true while ISteamHTMLSurface is initialised by the HTMLSurface test
      (Shutdown when the test ends). }
    FHTMLInit: Boolean;
    { Inventory result of the Inventory test; destroyed when it is ready or
      the test ends (k_SteamInventoryResultInvalid = none). }
    FInvResult: SteamInventoryResult_t;
    { The NetworkingSockets test's socket pair; closed when the test is done
      or ends (k_HSteamNetConnection_Invalid = none). }
    FSockConn1, FSockConn2: HSteamNetConnection;
    { The MatchmakingServers test's Internet and LAN lists (@nil = none). }
    FServerList, FLANList: HServerListRequest;
    { Its ping / players / rules queries (HSERVERQUERY_INVALID = none). }
    FPingQuery, FPlayersQuery, FRulesQuery: HServerQuery;
    { Servers of the Internet list that answered / did not answer. }
    FServersSeen, FServersFailed: Integer;
    { Servers that answered with a relay fake IP (169.254.x.x). }
    FServersFake: Integer;
    { The first server that answered (the one queried). }
    FHaveServer: Boolean;
    { Its IP (host order) and query port. }
    FFirstIP: UInt32;
    { See FFirstIP. }
    FFirstQueryPort: UInt16;
    { Its name. }
    FFirstName: string;
    { Players / rules reported by the queries. }
    FPlayerCount, FRuleCount: Integer;
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
    { Fills @link(lbComponents) with one row per tested component. }
    procedure FillTestList;
    { Shows FTests[AIndex] in its @link(lbComponents) row. }
    procedure UpdateTestRow(AIndex: Integer);
    { Starts the test of one component: logs it, records whether it is
      attached. @returns(@false (test FAILED) when its plug-in is not active.) }
    function BeginTest(AIndex: Integer; AComponent: TSteamPluginComponent; APlugin: TObject): Boolean;
    { Records a failed synchronous call of component AIndex. }
    procedure ReadFailed(AIndex: Integer; const AWhat: string; E: Exception);
    { Registers an awaited callback (not a call result). }
    procedure Expect(AIndex: Integer; const AName: string);
    { Registers an awaited call result; an invalid handle (Steam refused the
      call) is recorded as missing at once. }
    procedure ExpectCall(AIndex: Integer; const AName: string; ACall: SteamAPICall_t);
    { Marks an awaited answer as arrived. @returns(@false when the test was
      not waiting for it - the event came on its own; the caller logs that.) }
    function Answered(AIndex: Integer; const AName: string): Boolean;
    { Ends the test once nothing is pending. }
    procedure CheckTestsDone;
    { Ends the test: cleans up (cancels the auth ticket,
      releases the query), logs a verdict per component. AReason is logged
      when not ''. }
    procedure FinishTests(const AReason: string);
    { TSteamUtils: reads + CheckFileSignature. }
    procedure TestUtils;
    { TSteamUser: reads + GetAuthSessionTicket + GetDurationControl. }
    procedure TestUser;
    { TSteamApps: reads + GetFileDetails. }
    procedure TestApps;
    { TSteamRemoteStorage: reads + FileWriteAsync (then FileReadAsync). }
    procedure TestRemoteStorage;
    { TSteamScreenshots: HookScreenshots on / off and IsScreenshotsHooked -
      no picture (File > Take Screenshot writes one on demand). }
    procedure TestScreenshots;
    { TSteamTimeline: game mode, tooltip, game phase, event + the two
      recording queries. }
    procedure TestTimeline;
    { TSteamUGC: reads + a Workshop query + GetWorkshopEULAStatus. }
    procedure TestUGC;
    { TSteamMatchmaking: favourites count + RequestLobbyList. }
    procedure TestMatchmaking;
    { TSteamParties: beacon counts (reads only). }
    procedure TestParties;
    { TSteamMusic: player state (reads only). }
    procedure TestMusic;
    { TSteamHTTP: one GET of @link(TEST_HTTP_URL). }
    procedure TestHTTP;
    { TSteamHTMLSurface: Init + CreateBrowser (browser removed when ready). }
    procedure TestHTMLSurface;
    { TSteamInventory: LoadItemDefinitions + GetAllItems. }
    procedure TestInventory;
    { TSteamVideo: IsBroadcasting + GetOPFSettings. }
    procedure TestVideo;
    { TSteamParentalSettings: lock and block state (reads only). }
    procedure TestParentalSettings;
    { TSteamRemotePlay: session count (reads only). }
    procedure TestRemotePlay;
    { TSteamNetworking: IsP2PPacketAvailable (reads only). }
    procedure TestNetworking;
    { TSteamNetworkingSockets: GetIdentity, CreateSocketPair, one message
      sent and received, connection 1 closed (connection 2 answers). }
    procedure TestNetworkingSockets;
    { TSteamNetworkingMessages: channel 0 polled (reads only). }
    procedure TestNetworkingMessages;
    { TSteamNetworkingUtils: local timestamp, relay network status. }
    procedure TestNetworkingUtils;
    { Closes whatever is left of the socket pair (both sides). }
    procedure CloseSocketPair(const AWhy: string);
    { TSteamMatchmakingServers: a LAN list, an Internet list of
      TEST_SERVER_APP, then ping / players / rules of its first server. }
    procedure TestMatchmakingServers;
    { Releases the MatchmakingServers test's lists and stops its queries. }
    procedure StopServerRequests(const AWhy: string);
    { Adds S to the MatchmakingServers row. }
    procedure AddServerNote(const S: string);
    { Registers a started server-browser request (AOk) or records it as refused. }
    procedure ServerRequestStarted(const AName, AWhat: string; AOk: Boolean);
    { The Internet list has answered enough: releases it and queries its first server. }
    procedure EndInternetList(const AHow: string);
    { Captures this window with SteamFormToRGB (Steamworks.FMX), writes it
      with WriteScreenshot and logs it (File > Take Screenshot, and a
      request while screenshots are hooked).
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
  FmxLinuxMenu;

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
  Caption := Caption + ' - ' + TSteamLib.PlatformDescription;
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
  FPending := TDictionary<string, Cardinal>.Create;
  FUGCQuery := k_UGCQueryHandleInvalid;
  FInvResult := k_SteamInventoryResultInvalid;
  FSockConn1 := k_HSteamNetConnection_Invalid;
  FSockConn2 := k_HSteamNetConnection_Invalid;
  FPingQuery := HSERVERQUERY_INVALID;
  FPlayersQuery := HSERVERQUERY_INVALID;
  FRulesQuery := HSERVERQUERY_INVALID;
  FillTestList;
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
  if FTestsRunning then
    FinishTests('window closing');
  SteamAPI1.Close;
end;

procedure TfrmMain.FormDestroy(Sender: TObject);
begin
  tmAutoStart.Enabled := False;
  tmTests.Enabled := False;
  FreeAndNil(FPending);
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
  if FTestsRunning then
    FinishTests('Stop pressed');
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
  if FTestsRunning then
    FinishTests('Steam shut down while the component test was running (no cleanup possible)');
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

  The base test of the 16 plug-in components that no other demo uses as
  components: each is dropped on the form, linked to SteamAPI1 and has
  its events wired in uMain.fmx. Per component the test checks that it is
  attached, makes its synchronous calls through the component's Plugin
  property (an exception = reads FAILED), and requests callbacks / call
  results that must arrive through the component's events within
  TEST_TIMEOUT_MS (Screenshots requests none: see TestScreenshots). A
  component PASSES when it is attached, every call returned and every
  requested answer arrived - whatever result code Steam put in it (Steam
  Cloud or Workshop being off for the app is a Steam setting, not a
  component fault; the codes are logged and shown).
  Side effects: TEST_CLOUD_FILE is written and deleted again; a timeline
  event and game phase are recorded (only visible if background recording
  is on) and the timeline game mode is left at Menus for the rest of the
  session. No screenshot is written (File > Take Screenshot does that, on
  demand). Cleanup (cancel the auth ticket, release the Workshop query,
  delete the cloud file) needs Steam: Stop and closing the window run it
  first; after a Steam client exit it is impossible (and unneeded).
  --------------------------------------------------------------------------- }

const
  { Row titles of the Components tab, indexed by the CT_ constants. }
  TestNames: array[0..CT_COUNT - 1] of string = ('TSteamUtils', 'TSteamUser',
    'TSteamApps', 'TSteamRemoteStorage', 'TSteamScreenshots', 'TSteamTimeline', 'TSteamUGC',
    'TSteamMatchmaking', 'TSteamParties', 'TSteamMusic', 'TSteamHTTP', 'TSteamHTMLSurface',
    'TSteamInventory', 'TSteamVideo', 'TSteamParentalSettings', 'TSteamRemotePlay',
    'TSteamNetworking', 'TSteamNetworkingSockets', 'TSteamNetworkingMessages', 'TSteamNetworkingUtils',
    'TSteamMatchmakingServers');

{ A NUL-terminated UTF-8 buffer from Steam as a string. }
function SteamText(P: PAnsiChar): string;
begin
  Result := string(UTF8String(P));
end;

{ The EResult number with the names the test meets most often. }
function ResultText(AResult: EResult): string;
begin
  case Ord(AResult) of
    1: Result := 'OK';
    2: Result := 'Fail';
    8: Result := 'InvalidParam';
    9: Result := 'FileNotFound';
    15: Result := 'AccessDenied';
    16: Result := 'Timeout';
  else
    Result := 'result';
  end;
  Result := Format('%d (%s)', [Ord(AResult), Result]);
end;

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
      Item.ItemData.Detail := 'not run - press Test components (Steam must be started)';
    end;
  finally
    lbComponents.EndUpdate;
  end;
end;

procedure TfrmMain.UpdateTestRow(AIndex: Integer);
var
  T: TComponentTestState;
  Verdict, S: string;
begin
  T := FTests[AIndex];
  if not T.Ran then
    Exit;
  if (not T.Attached) or (not T.ReadsOK) or (T.Missing <> '') then
    Verdict := 'FAIL'
  else if T.Arrived < T.Sent then
    Verdict := 'waiting'
  else
    Verdict := 'PASS';
  S := Format('%s - attached %s, calls %s, answers %d of %d',
    [Verdict, BoolToStr(T.Attached, True), IfThen(T.ReadsOK, 'OK', 'FAILED'), T.Arrived, T.Sent]);
  if T.Missing <> '' then
    S := S + '; NO ANSWER: ' + T.Missing;
  if T.Note <> '' then
    S := S + '; ' + T.Note;
  if AIndex < lbComponents.Count then
    lbComponents.ListItems[AIndex].ItemData.Detail := S;
end;

function TfrmMain.BeginTest(AIndex: Integer; AComponent: TSteamPluginComponent; APlugin: TObject): Boolean;
begin
  FTests[AIndex].Ran := True;
  FTests[AIndex].Attached := AComponent.Attached;
  FTests[AIndex].ReadsOK := True;
  Result := APlugin <> nil;
  // Attached is only True when the component is linked to a running
  // TSteamAPI (SteamAPI in the form file) and its events are subscribed
  AddLog(Format('Test %s: component %s, attached %s, plug-in active %s',
    [TestNames[AIndex], AComponent.Name, BoolToStr(AComponent.Attached, True), BoolToStr(Result, True)]));
  if not Result then
  begin
    FTests[AIndex].ReadsOK := False;
    FTests[AIndex].Note := 'plug-in not active';
  end;
end;

procedure TfrmMain.ReadFailed(AIndex: Integer; const AWhat: string; E: Exception);
begin
  FTests[AIndex].ReadsOK := False;
  AddLog(Format('Test %s: %s FAILED: %s: %s', [TestNames[AIndex], AWhat, E.ClassName, E.Message]));
end;

procedure TfrmMain.Expect(AIndex: Integer; const AName: string);
begin
  Inc(FTests[AIndex].Sent);
  FPending.AddOrSetValue(IntToStr(AIndex) + ':' + AName, TThread.GetTickCount);
end;

procedure TfrmMain.ExpectCall(AIndex: Integer; const AName: string; ACall: SteamAPICall_t);
begin
  if ACall = k_uAPICallInvalid then
  begin
    Inc(FTests[AIndex].Sent);
    if FTests[AIndex].Missing <> '' then
      FTests[AIndex].Missing := FTests[AIndex].Missing + ', ';
    FTests[AIndex].Missing := FTests[AIndex].Missing + AName + ' (no call handle)';
    AddLog(Format('Test %s: %s returned k_uAPICallInvalid - Steam refused the call',
      [TestNames[AIndex], AName]));
  end
  else
  begin
    AddLog(Format('Test %s: %s sent, call %s - waiting for its result',
      [TestNames[AIndex], AName, UIntToStr(ACall)]));
    Expect(AIndex, AName);
  end;
end;

function TfrmMain.Answered(AIndex: Integer; const AName: string): Boolean;
var
  Key: string;
  Sent: Cardinal;
begin
  Key := IntToStr(AIndex) + ':' + AName;
  Result := FTestsRunning and (FPending <> nil) and FPending.TryGetValue(Key, Sent);
  if not Result then
    Exit;
  FPending.Remove(Key);
  Inc(FTests[AIndex].Arrived);
  AddLog(Format('Test %s: %s answered after %d ms', [TestNames[AIndex], AName,
    Integer(TThread.GetTickCount - Sent)]));
end;

procedure TfrmMain.CheckTestsDone;
var
  I: Integer;
begin
  for I := 0 to CT_COUNT - 1 do
    UpdateTestRow(I);
  if FTestsRunning and (FPending.Count = 0) then
    FinishTests('');
end;

procedure TfrmMain.FinishTests(const AReason: string);
var
  I, Passed: Integer;
  Key: string;
begin
  if not FTestsRunning then
    Exit;
  FTestsRunning := False;
  tmTests.Enabled := False;
  if AReason <> '' then
    AddLog('Component test stopped: ' + AReason);
  // Whatever is still pending counts as not answered
  for Key in FPending.Keys.ToArray do
  begin
    I := StrToIntDef(Copy(Key, 1, Pos(':', Key) - 1), -1);
    if (I >= 0) and (I < CT_COUNT) then
    begin
      if FTests[I].Missing <> '' then
        FTests[I].Missing := FTests[I].Missing + ', ';
      FTests[I].Missing := FTests[I].Missing + Copy(Key, Pos(':', Key) + 1, MaxInt);
    end;
  end;
  FPending.Clear;
  // Clean up (only possible while Steam runs)
  if SteamAPI1.IsRunning then
  begin
    try
      if (FAuthTicket <> k_HAuthTicketInvalid) and (SteamUser1.Plugin <> nil) then
      begin
        SteamUser1.Plugin.CancelAuthTicket(FAuthTicket);
        AddLog('Test cleanup: auth ticket ' + UIntToStr(FAuthTicket) + ' cancelled (it never answered)');
      end;
      if (FUGCQuery <> k_UGCQueryHandleInvalid) and (SteamUGC1.Plugin <> nil) then
      begin
        AddLog('Test cleanup: ReleaseQueryUGCRequest (query never completed): ' +
          BoolToStr(SteamUGC1.Plugin.ReleaseQueryUGCRequest(FUGCQuery), True));
      end;
      // Normally deleted after the read-back; not if that never happened
      if (SteamRemoteStorage1.Plugin <> nil) and SteamRemoteStorage1.Plugin.FileExists(TEST_CLOUD_FILE) then
        AddLog('Test cleanup: ' + TEST_CLOUD_FILE + ' still there, FileDelete ' +
          BoolToStr(SteamRemoteStorage1.Plugin.FileDelete(TEST_CLOUD_FILE), True));
      if (FHTTPRequest <> 0) and (SteamHTTP1.Plugin <> nil) then
        AddLog('Test cleanup: ReleaseHTTPRequest (request never completed): ' +
          BoolToStr(SteamHTTP1.Plugin.ReleaseHTTPRequest(FHTTPRequest), True));
      if (FInvResult <> k_SteamInventoryResultInvalid) and (SteamInventory1.Plugin <> nil) then
      begin
        SteamInventory1.Plugin.DestroyResult(FInvResult);
        AddLog('Test cleanup: inventory result ' + IntToStr(FInvResult) + ' destroyed (never ready)');
      end;
      if FHTMLInit and (SteamHTMLSurface1.Plugin <> nil) then
        AddLog('Test cleanup: ISteamHTMLSurface.Shutdown ' +
          BoolToStr(SteamHTMLSurface1.Plugin.Shutdown, True));
      CloseSocketPair('Test cleanup');
      StopServerRequests('Test cleanup');
    except
      on E: Exception do AddLog('Test cleanup failed: ' + E.Message);
    end;
  end;
  FAuthTicket := k_HAuthTicketInvalid;
  FUGCQuery := k_UGCQueryHandleInvalid;
  FHTTPRequest := 0;
  FHTMLInit := False;
  FInvResult := k_SteamInventoryResultInvalid;
  FSockConn1 := k_HSteamNetConnection_Invalid;
  FSockConn2 := k_HSteamNetConnection_Invalid;
  FServerList := nil;
  FLANList := nil;
  FPingQuery := HSERVERQUERY_INVALID;
  FPlayersQuery := HSERVERQUERY_INVALID;
  FRulesQuery := HSERVERQUERY_INVALID;
  Passed := 0;
  for I := 0 to CT_COUNT - 1 do
  begin
    UpdateTestRow(I);
    if FTests[I].Ran and FTests[I].Attached and FTests[I].ReadsOK and (FTests[I].Missing = '') and
      (FTests[I].Arrived = FTests[I].Sent) then
      Inc(Passed);
    if FTests[I].Ran and (I < lbComponents.Count) then
      AddLog(Format('Test result %s: %s', [TestNames[I], lbComponents.ListItems[I].ItemData.Detail]));
  end;
  AddLog(Format('Component test finished: %d of %d components PASS', [Passed, CT_COUNT]));
end;

procedure TfrmMain.btnTestClick(Sender: TObject);
var
  I: Integer;
begin
  AddLog('Test components pressed');
  if not SteamAPI1.IsRunning then
  begin
    AddLog('Test components: Steam is not running - press Start first');
    Exit;
  end;
  if FTestsRunning then
    FinishTests('restarted by Test components');
  for I := 0 to CT_COUNT - 1 do
    FTests[I] := Default(TComponentTestState);
  FPending.Clear;
  FillTestList;
  FTestsRunning := True;
  tabMain.ActiveTab := tiComponents;
  AddLog(Format('Component test started: %d components, answers expected within %d ms',
    [CT_COUNT, TEST_TIMEOUT_MS]));
  TestUtils;
  TestUser;
  TestApps;
  TestRemoteStorage;
  TestScreenshots;
  TestTimeline;
  TestUGC;
  TestMatchmaking;
  TestParties;
  TestMusic;
  TestHTTP;
  TestHTMLSurface;
  TestInventory;
  TestVideo;
  TestParentalSettings;
  TestRemotePlay;
  TestNetworking;
  TestNetworkingSockets;
  TestNetworkingMessages;
  TestNetworkingUtils;
  TestMatchmakingServers;
  tmTests.Enabled := True;
  CheckTestsDone;
end;

procedure TfrmMain.tmTestsTimer(Sender: TObject);
var
  Key: string;
  Sent, NowTicks: Cardinal;
  I: Integer;
begin
  if not FTestsRunning then
  begin
    tmTests.Enabled := False;
    Exit;
  end;
  NowTicks := TThread.GetTickCount;
  for Key in FPending.Keys.ToArray do
    if FPending.TryGetValue(Key, Sent) and (NowTicks - Sent >= TEST_TIMEOUT_MS) then
    begin
      FPending.Remove(Key);
      I := StrToIntDef(Copy(Key, 1, Pos(':', Key) - 1), -1);
      if (I < 0) or (I >= CT_COUNT) then
        Continue;
      if FTests[I].Missing <> '' then
        FTests[I].Missing := FTests[I].Missing + ', ';
      FTests[I].Missing := FTests[I].Missing + Copy(Key, Pos(':', Key) + 1, MaxInt);
      AddLog(Format('Test %s: NO ANSWER to %s within %d ms',
        [TestNames[I], Copy(Key, Pos(':', Key) + 1, MaxInt), TEST_TIMEOUT_MS]));
    end;
  CheckTestsDone;
end;

{ --- TSteamUtils --- }

procedure TfrmMain.TestUtils;
var
  U: TSteamUtilsPlugin;
  Exe: string;
begin
  U := SteamUtils1.Plugin;
  if not BeginTest(CT_UTILS, SteamUtils1, U) then
    Exit;
  try
    AddLog(Format('Test TSteamUtils: universe %d, seconds since app active %d, since computer active %d, ' +
      'server real time %s UTC, IPC calls %d, China launcher %s, VR streaming %s',
      [Ord(U.GetConnectedUniverse), U.GetSecondsSinceAppActive, U.GetSecondsSinceComputerActive,
       FormatDateTime('yyyy-mm-dd hh:nn:ss', UnixToDateTime(Int64(U.GetServerRealTime), True)),
       U.GetIPCCallCount, BoolToStr(U.IsSteamChinaLauncher, True),
       BoolToStr(U.IsVRHeadsetStreamingEnabled, True)]));
  except
    on E: Exception do ReadFailed(CT_UTILS, 'reads', E);
  end;
  try
    // Our own executable: not part of a signed depot, so a "no signatures"
    // or "not found" answer is expected - what counts is that it arrives
    Exe := ExpandFileName(ParamStr(0));
    ExpectCall(CT_UTILS, 'CheckFileSignature', U.CheckFileSignature(Exe));
  except
    on E: Exception do ReadFailed(CT_UTILS, 'CheckFileSignature', E);
  end;
end;

procedure TfrmMain.UtilsCheckFileSignature(Sender: TObject; const AData: CheckFileSignature_t);
const
  Names: array[0..4] of string = ('invalid signature', 'valid signature', 'file not found',
    'no signatures for this app', 'no signatures for this file');
var
  S: string;
begin
  if (Ord(AData.m_eCheckFileSignature) >= 0) and (Ord(AData.m_eCheckFileSignature) <= 4) then
    S := Names[Ord(AData.m_eCheckFileSignature)]
  else
    S := 'unknown';
  AddLog(Format('TSteamUtils.OnCheckFileSignature: %d (%s)', [Ord(AData.m_eCheckFileSignature), S]));
  if Answered(CT_UTILS, 'CheckFileSignature') then
  begin
    FTests[CT_UTILS].Note := 'signature check: ' + S;
    CheckTestsDone;
  end;
end;

procedure TfrmMain.UtilsIPCountry(Sender: TObject; const AData: IPCountry_t);
begin
  AddLog('TSteamUtils.OnIPCountry: the IP country changed (not requested by the test)');
end;

procedure TfrmMain.UtilsLowBattery(Sender: TObject; const AData: LowBatteryPower_t);
begin
  AddLog(Format('TSteamUtils.OnLowBatteryPower: %d minutes left (not requested by the test)',
    [AData.m_nMinutesBatteryLeft]));
end;

{ --- TSteamUser --- }

procedure TfrmMain.TestUser;
var
  U: TSteamUserPlugin;
  Folder: array[0..1023] of AnsiChar;
  Ticket: array[0..2047] of Byte;
  TicketSize: UInt32;
  FolderText: string;
begin
  U := SteamUser1.Plugin;
  if not BeginTest(CT_USER, SteamUser1, U) then
    Exit;
  try
    FillChar(Folder, SizeOf(Folder), 0);
    if U.GetUserDataFolder(@Folder[0], SizeOf(Folder)) then
      FolderText := 'returned'   // a local path: kept out of the log
    else
      FolderText := 'FALSE';
    AddLog(Format('Test TSteamUser: logged on %s, SteamID %s, behind NAT %s, phone verified %s, ' +
      'two-factor %s, GetUserDataFolder %s',
      [BoolToStr(U.BLoggedOn, True), U.GetSteamID.ToString, BoolToStr(U.BIsBehindNAT, True),
       BoolToStr(U.BIsPhoneVerified, True), BoolToStr(U.BIsTwoFactorEnabled, True), FolderText]));
  except
    on E: Exception do ReadFailed(CT_USER, 'reads', E);
  end;
  try
    TicketSize := 0;
    FAuthTicket := U.GetAuthSessionTicket(@Ticket[0], SizeOf(Ticket), TicketSize, nil);
    if FAuthTicket = k_HAuthTicketInvalid then
    begin
      Inc(FTests[CT_USER].Sent);
      if FTests[CT_USER].Missing <> '' then
        FTests[CT_USER].Missing := FTests[CT_USER].Missing + ', ';
      FTests[CT_USER].Missing := FTests[CT_USER].Missing + 'GetAuthSessionTicket (invalid ticket)';
      AddLog('Test TSteamUser: GetAuthSessionTicket returned k_HAuthTicketInvalid');
    end
    else
    begin
      AddLog(Format('Test TSteamUser: GetAuthSessionTicket handle %s, %d bytes - waiting for callback 163',
        [UIntToStr(FAuthTicket), TicketSize]));
      Expect(CT_USER, 'GetAuthSessionTicket');
    end;
  except
    on E: Exception do ReadFailed(CT_USER, 'GetAuthSessionTicket', E);
  end;
  try
    ExpectCall(CT_USER, 'GetDurationControl', U.GetDurationControl);
  except
    on E: Exception do ReadFailed(CT_USER, 'GetDurationControl', E);
  end;
end;

procedure TfrmMain.UserAuthTicketResponse(Sender: TObject; const AData: GetAuthSessionTicketResponse_t);
begin
  AddLog(Format('TSteamUser.OnGetAuthSessionTicketResponse: ticket %s, result %s',
    [UIntToStr(AData.m_hAuthTicket), ResultText(AData.m_eResult)]));
  if (AData.m_hAuthTicket = FAuthTicket) and (FAuthTicket <> k_HAuthTicketInvalid) and
    Answered(CT_USER, 'GetAuthSessionTicket') then
  begin
    // A real game would send the ticket to its server; the test only needs
    // the answer, so the ticket is given back at once
    if SteamUser1.Plugin <> nil then
    begin
      SteamUser1.Plugin.CancelAuthTicket(FAuthTicket);
      AddLog('Test TSteamUser: auth ticket ' + UIntToStr(FAuthTicket) + ' cancelled');
    end;
    FAuthTicket := k_HAuthTicketInvalid;
    FTests[CT_USER].Note := 'ticket ' + ResultText(AData.m_eResult);
    CheckTestsDone;
  end;
end;

procedure TfrmMain.UserDurationControl(Sender: TObject; const AData: DurationControl_t);
begin
  AddLog(Format('TSteamUser.OnDurationControl: result %s, app %d, applicable %s, ' +
    'last 5 h %d s, today %d s, remaining %d s, progress %d, notification %d',
    [ResultText(AData.m_eResult), AData.m_appid, BoolToStr(AData.m_bApplicable, True),
     AData.m_csecsLast5h, AData.m_csecsToday, AData.m_csecsRemaining,
     Ord(AData.m_progress), Ord(AData.m_notification)]));
  if Answered(CT_USER, 'GetDurationControl') then
    CheckTestsDone;
end;

procedure TfrmMain.UserServersConnected(Sender: TObject; const AData: SteamServersConnected_t);
begin
  AddLog('TSteamUser.OnSteamServersConnected (not requested by the test)');
end;

procedure TfrmMain.UserServersDisconnected(Sender: TObject; const AData: SteamServersDisconnected_t);
begin
  AddLog('TSteamUser.OnSteamServersDisconnected: result ' + ResultText(AData.m_eResult) +
    ' (not requested by the test)');
end;

procedure TfrmMain.UserServerConnectFailure(Sender: TObject; const AData: SteamServerConnectFailure_t);
begin
  AddLog(Format('TSteamUser.OnSteamServerConnectFailure: result %s, still retrying %s (not requested by the test)',
    [ResultText(AData.m_eResult), BoolToStr(AData.m_bStillRetrying, True)]));
end;

{ --- TSteamApps --- }

procedure TfrmMain.TestApps;
var
  A: TSteamAppsPlugin;
  Beta: array[0..255] of AnsiChar;
  CmdLine: array[0..1023] of AnsiChar;
  Allowed, Played: UInt32;
  BetasAvailable, BetasPrivate, BetaCount, CmdLen: Integer;
  Purchased: UInt32;
  PurchasedText: string;
  HasBeta, Trial: Boolean;
begin
  A := SteamApps1.Plugin;
  if not BeginTest(CT_APPS, SteamApps1, A) then
    Exit;
  try
    FillChar(Beta, SizeOf(Beta), 0);
    FillChar(CmdLine, SizeOf(CmdLine), 0);
    HasBeta := A.GetCurrentBetaName(@Beta[0], SizeOf(Beta));
    CmdLen := A.GetLaunchCommandLine(@CmdLine[0], SizeOf(CmdLine));
    Allowed := 0;
    Played := 0;
    Trial := A.BIsTimedTrial(Allowed, Played);
    BetasAvailable := 0;
    BetasPrivate := 0;
    BetaCount := A.GetNumBetas(BetasAvailable, BetasPrivate);
    Purchased := A.GetEarliestPurchaseUnixTime(APP_ID);
    if Purchased = 0 then
      PurchasedText := 'none'
    else
      PurchasedText := FormatDateTime('yyyy-mm-dd hh:nn', UnixToDateTime(Int64(Purchased), True)) + ' UTC';
    AddLog(Format('Test TSteamApps: low violence %s, cybercafe %s, VAC banned %s, free weekend %s, ' +
      'DLC %d, app installed %s, earliest purchase %s, beta %s, betas %d (%d available, %d private), ' +
      'timed trial %s (%d of %d s), launch command line %d characters (GetLaunchCommandLine returned %d)',
      [BoolToStr(A.BIsLowViolence, True), BoolToStr(A.BIsCybercafe, True),
       BoolToStr(A.BIsVACBanned, True), BoolToStr(A.BIsSubscribedFromFreeWeekend, True),
       A.GetDLCCount, BoolToStr(A.BIsAppInstalled(APP_ID), True), PurchasedText,
       IfThen(HasBeta, '"' + SteamText(@Beta[0]) + '"', 'none'), BetaCount, BetasAvailable, BetasPrivate,
       BoolToStr(Trial, True), Played, Allowed, Length(SteamText(@CmdLine[0])), CmdLen]));
  except
    on E: Exception do ReadFailed(CT_APPS, 'reads', E);
  end;
  try
    // A name relative to the app's install folder; a development build is
    // not in a depot, so FileNotFound is the expected answer
    ExpectCall(CT_APPS, 'GetFileDetails', A.GetFileDetails(ExtractFileName(ParamStr(0))));
  except
    on E: Exception do ReadFailed(CT_APPS, 'GetFileDetails', E);
  end;
end;

procedure TfrmMain.AppsFileDetails(Sender: TObject; const AData: FileDetailsResult_t);
begin
  AddLog(Format('TSteamApps.OnFileDetailsResult: result %s, size %s, flags $%x',
    [ResultText(AData.m_eResult), UIntToStr(AData.m_ulFileSize), AData.m_unFlags]));
  if Answered(CT_APPS, 'GetFileDetails') then
  begin
    FTests[CT_APPS].Note := 'file details ' + ResultText(AData.m_eResult);
    CheckTestsDone;
  end;
end;

procedure TfrmMain.AppsDlcInstalled(Sender: TObject; const AData: DlcInstalled_t);
begin
  AddLog(Format('TSteamApps.OnDlcInstalled: app %d (not requested by the test)', [AData.m_nAppID]));
end;

procedure TfrmMain.AppsNewUrlLaunchParameters(Sender: TObject; const AData: NewUrlLaunchParameters_t);
begin
  AddLog('TSteamApps.OnNewUrlLaunchParameters (not requested by the test)');
end;

procedure TfrmMain.AppsTimedTrialStatus(Sender: TObject; const AData: TimedTrialStatus_t);
begin
  AddLog(Format('TSteamApps.OnTimedTrialStatus: app %d, offline %s, %d of %d s (not requested by the test)',
    [AData.m_unAppID, BoolToStr(AData.m_bIsOffline, True), AData.m_unSecondsPlayed, AData.m_unSecondsAllowed]));
end;

{ --- TSteamRemoteStorage --- }

procedure TfrmMain.TestRemoteStorage;
var
  R: TSteamRemoteStoragePlugin;
  CloudForApp: Boolean;
  Call: SteamAPICall_t;
begin
  R := SteamRemoteStorage1.Plugin;
  if not BeginTest(CT_STORAGE, SteamRemoteStorage1, R) then
    Exit;
  CloudForApp := True;
  try
    CloudForApp := R.IsCloudEnabledForApp;
    AddLog(Format('Test TSteamRemoteStorage: cloud for account %s, for app %s, %d files, %s exists %s',
      [BoolToStr(R.IsCloudEnabledForAccount, True), BoolToStr(CloudForApp, True),
       R.GetFileCount, TEST_CLOUD_FILE, BoolToStr(R.FileExists(TEST_CLOUD_FILE), True)]));
    if not CloudForApp then
    begin
      // Owner's request (2026-11-02): the client shows no per-game Cloud
      // switch for this app, so the demo turns it on itself. Valve means
      // SetCloudEnabledForApp for a player's choice in the game's options;
      // a game must not do this silently. If it stays False, Steam treats
      // Cloud as off for the APP (configuration), not for this user.
      R.SetCloudEnabledForApp(True);
      CloudForApp := R.IsCloudEnabledForApp;
      AddLog('Test TSteamRemoteStorage: SetCloudEnabledForApp(True) called, cloud for app now ' +
        BoolToStr(CloudForApp, True) + IfThen(CloudForApp, '',
        ' - Steam keeps Cloud off for the app itself (its published configuration), not for this user'));
      FTests[CT_STORAGE].Note := 'cloud for app was off, SetCloudEnabledForApp(True) -> ' +
        BoolToStr(CloudForApp, True);
    end;
  except
    on E: Exception do ReadFailed(CT_STORAGE, 'reads / SetCloudEnabledForApp', E);
  end;
  try
    FCloudData := TEncoding.UTF8.GetBytes('SteamDemo component test ' +
      FormatDateTime('yyyy-mm-dd hh:nn:ss.zzz', Now));
    Call := R.FileWriteAsync(TEST_CLOUD_FILE, @FCloudData[0], Length(FCloudData));
    if (Call = k_uAPICallInvalid) and not CloudForApp then
    begin
      // A Steam setting, not a component fault: not counted
      if FTests[CT_STORAGE].Note <> '' then
        FTests[CT_STORAGE].Note := FTests[CT_STORAGE].Note + ', ';
      FTests[CT_STORAGE].Note := FTests[CT_STORAGE].Note +
        'write refused: Steam Cloud is off for the app, async write / read not tested';
      AddLog('Test TSteamRemoteStorage: FileWriteAsync returned k_uAPICallInvalid - Steam Cloud is off ' +
        'for the app, so the async write / read cannot be tested');
    end
    else
      ExpectCall(CT_STORAGE, 'FileWriteAsync', Call);
  except
    on E: Exception do ReadFailed(CT_STORAGE, 'FileWriteAsync', E);
  end;
end;

procedure TfrmMain.StorageWriteComplete(Sender: TObject; const AData: RemoteStorageFileWriteAsyncComplete_t);
var
  R: TSteamRemoteStoragePlugin;
begin
  AddLog('TSteamRemoteStorage.OnRemoteStorageFileWriteAsyncComplete: result ' + ResultText(AData.m_eResult));
  if not Answered(CT_STORAGE, 'FileWriteAsync') then
    Exit;
  if FTests[CT_STORAGE].Note <> '' then
    FTests[CT_STORAGE].Note := FTests[CT_STORAGE].Note + ', ';
  FTests[CT_STORAGE].Note := FTests[CT_STORAGE].Note + 'write ' + ResultText(AData.m_eResult);
  R := SteamRemoteStorage1.Plugin;
  if (AData.m_eResult = k_EResultOK) and (R <> nil) then
  try
    ExpectCall(CT_STORAGE, 'FileReadAsync', R.FileReadAsync(TEST_CLOUD_FILE, 0, Length(FCloudData)));
  except
    on E: Exception do ReadFailed(CT_STORAGE, 'FileReadAsync', E);
  end
  else
    FTests[CT_STORAGE].Note := FTests[CT_STORAGE].Note +
      ', read-back skipped (is Steam Cloud enabled for the app on the partner site?)';
  CheckTestsDone;
end;

procedure TfrmMain.StorageReadComplete(Sender: TObject; const AData: RemoteStorageFileReadAsyncComplete_t);
var
  R: TSteamRemoteStoragePlugin;
  Buf: TBytes;
  Fetched, Same: Boolean;
  SyncRead: Int32;
begin
  AddLog(Format('TSteamRemoteStorage.OnRemoteStorageFileReadAsyncComplete: call %s, result %s, offset %d, %d bytes',
    [UIntToStr(AData.m_hFileReadAsync), ResultText(AData.m_eResult), AData.m_nOffset, AData.m_cubRead]));
  if not Answered(CT_STORAGE, 'FileReadAsync') then
    Exit;
  R := SteamRemoteStorage1.Plugin;
  if R <> nil then
  try
    Same := False;
    Fetched := False;
    if (AData.m_eResult = k_EResultOK) and (AData.m_cubRead > 0) then
    begin
      // Valve: fetch the data while handling this result. In thread mode
      // the pump thread has already released the call result before this
      // handler runs on the main thread - if Steam frees the buffer with it,
      // Fetched is False although the component works (UNVERIFIED)
      SetLength(Buf, AData.m_cubRead);
      Fetched := R.FileReadAsyncComplete(AData.m_hFileReadAsync, @Buf[0], AData.m_cubRead);
      if Fetched then
        Same := (Length(Buf) = Length(FCloudData)) and CompareMem(@Buf[0], @FCloudData[0], Length(Buf))
      else
      begin
        // Tell "fetch refused" from "file wrong": read it synchronously
        SetLength(Buf, Length(FCloudData));
        SyncRead := R.FileRead(TEST_CLOUD_FILE, @Buf[0], Length(Buf));
        AddLog(Format('Test TSteamRemoteStorage: FileReadAsyncComplete returned False ' +
          '(update mode %s); synchronous FileRead got %d of %d bytes, identical %s',
          [UpdateModeText(SteamAPI1.UpdateMode), SyncRead, Length(FCloudData),
           BoolToStr((SyncRead = Length(FCloudData)) and CompareMem(@Buf[0], @FCloudData[0], Length(Buf)), True)]));
      end;
    end;
    AddLog(Format('Test TSteamRemoteStorage: FileReadAsyncComplete %s, data identical to what was written %s',
      [BoolToStr(Fetched, True), BoolToStr(Same, True)]));
    AddLog('Test TSteamRemoteStorage: FileDelete(' + TEST_CLOUD_FILE + ') ' +
      BoolToStr(R.FileDelete(TEST_CLOUD_FILE), True));
    FTests[CT_STORAGE].Note := FTests[CT_STORAGE].Note + ', read ' + ResultText(AData.m_eResult);
    if not Fetched then
      FTests[CT_STORAGE].Note := FTests[CT_STORAGE].Note +
        ', FileReadAsyncComplete FALSE (data not fetched - see log)'
    else
      FTests[CT_STORAGE].Note := FTests[CT_STORAGE].Note + ', data ' + IfThen(Same, 'identical', 'DIFFERENT');
    if not Same then
      FTests[CT_STORAGE].ReadsOK := False;
  except
    on E: Exception do ReadFailed(CT_STORAGE, 'FileReadAsyncComplete / FileDelete', E);
  end;
  CheckTestsDone;
end;

procedure TfrmMain.StorageLocalFileChange(Sender: TObject; const AData: RemoteStorageLocalFileChange_t);
begin
  AddLog('TSteamRemoteStorage.OnRemoteStorageLocalFileChange (not requested by the test)');
end;

{ --- TSteamScreenshots --- }

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
  S := SteamScreenshots1.Plugin;
  if (S = nil) or not SteamAPI1.IsRunning then
  begin
    AddLog('Screenshot: Steam is not running - press Start first');
    Exit;
  end;
  try
    // WriteScreenshot needs no overlay (TriggerScreenshot does); Steam
    // answers with OnScreenshotReady, which tags the picture
    if WriteFormScreenshot(S) <> 0 then
      AddLog('Screenshot: waiting for OnScreenshotReady (callback 2301)');
  except
    on E: Exception do AddLog('Screenshot FAILED: ' + E.Message);
  end;
end;

procedure TfrmMain.TestScreenshots;
var
  S: TSteamScreenshotsPlugin;
  Before, Hooked, Unhooked: Boolean;
begin
  S := SteamScreenshots1.Plugin;
  if not BeginTest(CT_SHOTS, SteamScreenshots1, S) then
    Exit;
  // No picture here: every run would add one to the user's screenshots
  // (owner, 2026-11-02) - File > Take Screenshot writes one on demand and
  // exercises WriteScreenshot / OnScreenshotReady / SetLocation. The test
  // switches the hook on and off and checks that Steam reports each state.
  try
    Before := S.IsScreenshotsHooked;
    S.HookScreenshots(True);
    Hooked := S.IsScreenshotsHooked;
    S.HookScreenshots(False);
    Unhooked := S.IsScreenshotsHooked;
    AddLog(Format('Test TSteamScreenshots: hooked before %s, after HookScreenshots(True) %s, ' +
      'after HookScreenshots(False) %s', [BoolToStr(Before, True), BoolToStr(Hooked, True),
      BoolToStr(Unhooked, True)]));
    if not Hooked or Unhooked then
    begin
      FTests[CT_SHOTS].ReadsOK := False;
      FTests[CT_SHOTS].Note := 'hook state did NOT follow HookScreenshots';
    end
    else
      FTests[CT_SHOTS].Note := 'hook on / off OK; File > Take Screenshot tests writing one';
  except
    on E: Exception do ReadFailed(CT_SHOTS, 'HookScreenshots / IsScreenshotsHooked', E);
  end;
end;

procedure TfrmMain.ScreenshotRequested(Sender: TObject; const AData: ScreenshotRequested_t);
var
  S: TSteamScreenshotsPlugin;
begin
  // Only while screenshots are hooked (the demo never leaves them hooked):
  // then Steam takes none itself and every request must be answered
  AddLog('TSteamScreenshots.OnScreenshotRequested');
  S := SteamScreenshots1.Plugin;
  if S <> nil then
  try
    WriteFormScreenshot(S);
  except
    on E: Exception do AddLog('Screenshot FAILED: ' + E.Message);
  end;
end;

procedure TfrmMain.ScreenshotReady(Sender: TObject; const AData: ScreenshotReady_t);
var
  S: TSteamScreenshotsPlugin;
begin
  AddLog(Format('TSteamScreenshots.OnScreenshotReady: handle %d, result %s',
    [AData.m_hLocal, ResultText(AData.m_eResult)]));
  S := SteamScreenshots1.Plugin;
  if (S <> nil) and (AData.m_eResult = k_EResultOK) then
  try
    AddLog('Screenshot: SetLocation ' + BoolToStr(S.SetLocation(AData.m_hLocal, 'SteamDemo'), True));
  except
    on E: Exception do AddLog('Screenshot: SetLocation FAILED: ' + E.Message);
  end;
end;

{ --- TSteamTimeline --- }

procedure TfrmMain.TestTimeline;
var
  T: TSteamTimelinePlugin;
  Ev: TimelineEventHandle_t;
begin
  T := SteamTimeline1.Plugin;
  if not BeginTest(CT_TIMELINE, SteamTimeline1, T) then
    Exit;
  FPhaseID := 'steamdemo-test-' + FormatDateTime('yyyymmdd-hhnnss', Now);
  Ev := 0;
  try
    T.SetTimelineGameMode(k_ETimelineGameMode_Playing);
    T.SetTimelineTooltip('SteamDemo component test', 0);
    T.StartGamePhase;
    T.SetGamePhaseID(FPhaseID);
    Ev := T.AddInstantaneousTimelineEvent('Component test', 'TSteamTimeline base test', 'steam_flag',
      0, 0, k_ETimelineEventClipPriority_None);
    T.ClearTimelineTooltip(0);
    T.EndGamePhase;
    T.SetTimelineGameMode(k_ETimelineGameMode_Menus);
    AddLog(Format('Test TSteamTimeline: game mode Playing, tooltip, game phase "%s" started / ended, ' +
      'event handle %s, tooltip cleared, game mode Menus', [FPhaseID, UIntToStr(Ev)]));
  except
    on E: Exception do ReadFailed(CT_TIMELINE, 'timeline calls', E);
  end;
  try
    // Without background recording both answers say "no recording" - they
    // must still arrive
    ExpectCall(CT_TIMELINE, 'DoesEventRecordingExist', T.DoesEventRecordingExist(Ev));
    ExpectCall(CT_TIMELINE, 'DoesGamePhaseRecordingExist', T.DoesGamePhaseRecordingExist(FPhaseID));
  except
    on E: Exception do ReadFailed(CT_TIMELINE, 'recording queries', E);
  end;
end;

procedure TfrmMain.TimelineEventRecordingExists(Sender: TObject; const AData: SteamTimelineEventRecordingExists_t);
begin
  AddLog(Format('TSteamTimeline.OnSteamTimelineEventRecordingExists: event %s, recording exists %s',
    [UIntToStr(AData.m_ulEventID), BoolToStr(AData.m_bRecordingExists, True)]));
  if Answered(CT_TIMELINE, 'DoesEventRecordingExist') then
    CheckTestsDone;
end;

procedure TfrmMain.TimelinePhaseRecordingExists(Sender: TObject; const AData: SteamTimelineGamePhaseRecordingExists_t);
begin
  AddLog(Format('TSteamTimeline.OnSteamTimelineGamePhaseRecordingExists: phase "%s", recorded %s ms, ' +
    'longest clip %s ms, %d clips, %d screenshots',
    [SteamText(@AData.m_rgchPhaseID[0]), UIntToStr(AData.m_ulRecordingMS), UIntToStr(AData.m_ulLongestClipMS),
     AData.m_unClipCount, AData.m_unScreenshotCount]));
  if Answered(CT_TIMELINE, 'DoesGamePhaseRecordingExist') then
    CheckTestsDone;
end;

{ --- TSteamUGC --- }

procedure TfrmMain.TestUGC;
var
  G: TSteamUGCPlugin;
begin
  G := SteamUGC1.Plugin;
  if not BeginTest(CT_UGC, SteamUGC1, G) then
    Exit;
  try
    // GetNumSubscribedItems takes a Boolean: the narrow-argument case
    AddLog(Format('Test TSteamUGC: %d subscribed items (%d incl. locally disabled), %d downloaded',
      [G.GetNumSubscribedItems(False), G.GetNumSubscribedItems(True), G.GetNumDownloadedItems]));
  except
    on E: Exception do ReadFailed(CT_UGC, 'reads', E);
  end;
  try
    FUGCQuery := G.CreateQueryAllUGCRequestPage(k_EUGCQuery_RankedByPublicationDate,
      k_EUGCMatchingUGCType_Items, APP_ID, APP_ID, 1);
    if FUGCQuery = k_UGCQueryHandleInvalid then
    begin
      Inc(FTests[CT_UGC].Sent);
      if FTests[CT_UGC].Missing <> '' then
        FTests[CT_UGC].Missing := FTests[CT_UGC].Missing + ', ';
      FTests[CT_UGC].Missing := FTests[CT_UGC].Missing + 'CreateQueryAllUGCRequestPage (invalid handle)';
      AddLog('Test TSteamUGC: CreateQueryAllUGCRequestPage returned k_UGCQueryHandleInvalid');
    end
    else
    begin
      AddLog('Test TSteamUGC: query handle ' + UIntToStr(FUGCQuery) + ' created');
      ExpectCall(CT_UGC, 'SendQueryUGCRequest', G.SendQueryUGCRequest(FUGCQuery));
    end;
  except
    on E: Exception do ReadFailed(CT_UGC, 'Workshop query', E);
  end;
  try
    ExpectCall(CT_UGC, 'GetWorkshopEULAStatus', G.GetWorkshopEULAStatus);
  except
    on E: Exception do ReadFailed(CT_UGC, 'GetWorkshopEULAStatus', E);
  end;
end;

procedure TfrmMain.UGCQueryCompleted(Sender: TObject; const AData: SteamUGCQueryCompleted_t);
var
  G: TSteamUGCPlugin;
  Details: SteamUGCDetails_t;
  I: Integer;
begin
  AddLog(Format('TSteamUGC.OnSteamUGCQueryCompleted: query %s, result %s, %d returned, %d matching, cached %s',
    [UIntToStr(AData.m_handle), ResultText(AData.m_eResult), AData.m_unNumResultsReturned,
     AData.m_unTotalMatchingResults, BoolToStr(AData.m_bCachedData, True)]));
  if not Answered(CT_UGC, 'SendQueryUGCRequest') then
    Exit;
  // appended: the EULA status may have arrived first (VCL run 16:35)
  if FTests[CT_UGC].Note <> '' then
    FTests[CT_UGC].Note := FTests[CT_UGC].Note + ', ';
  FTests[CT_UGC].Note := FTests[CT_UGC].Note +
    Format('query %s, %d items', [ResultText(AData.m_eResult), AData.m_unTotalMatchingResults]);
  G := SteamUGC1.Plugin;
  if G <> nil then
  try
    if AData.m_eResult = k_EResultOK then
      for I := 0 to Integer(AData.m_unNumResultsReturned) - 1 do
      begin
        if I >= 3 then
          Break;
        Details := Default(SteamUGCDetails_t);
        if G.GetQueryUGCResult(AData.m_handle, UInt32(I), Details) then
          AddLog(Format('Test TSteamUGC: item %d: id %s, "%s"',
            [I, UIntToStr(Details.m_nPublishedFileId), SteamText(@Details.m_rgchTitle[0])]));
      end;
    AddLog('Test TSteamUGC: ReleaseQueryUGCRequest ' +
      BoolToStr(G.ReleaseQueryUGCRequest(AData.m_handle), True));
    FUGCQuery := k_UGCQueryHandleInvalid;
  except
    on E: Exception do ReadFailed(CT_UGC, 'GetQueryUGCResult / ReleaseQueryUGCRequest', E);
  end;
  CheckTestsDone;
end;

procedure TfrmMain.UGCWorkshopEULAStatus(Sender: TObject; const AData: WorkshopEULAStatus_t);
begin
  // The other fields are only filled in when the result is OK (first run:
  // InvalidParam - Workshop not set up for the app - with a garbage version)
  if AData.m_eResult = k_EResultOK then
    AddLog(Format('TSteamUGC.OnWorkshopEULAStatus: result %s, app %d, version %s, accepted %s, needs action %s',
      [ResultText(AData.m_eResult), AData.m_nAppID, UIntToStr(AData.m_unVersion), BoolToStr(AData.m_bAccepted, True),
       BoolToStr(AData.m_bNeedsAction, True)]))
  else
    AddLog(Format('TSteamUGC.OnWorkshopEULAStatus: result %s, app %d (no EULA data: is the Workshop ' +
      'set up for the app?)', [ResultText(AData.m_eResult), AData.m_nAppID]));
  if FTests[CT_UGC].Note <> '' then
    FTests[CT_UGC].Note := FTests[CT_UGC].Note + ', ';
  FTests[CT_UGC].Note := FTests[CT_UGC].Note + 'EULA status ' + ResultText(AData.m_eResult);
  if Answered(CT_UGC, 'GetWorkshopEULAStatus') then
    CheckTestsDone;
end;

procedure TfrmMain.UGCSubscribedListChanged(Sender: TObject; const AData: UserSubscribedItemsListChanged_t);
begin
  AddLog(Format('TSteamUGC.OnUserSubscribedItemsListChanged: app %d (not requested by the test)', [AData.m_nAppID]));
end;

procedure TfrmMain.UGCItemInstalled(Sender: TObject; const AData: ItemInstalled_t);
begin
  AddLog(Format('TSteamUGC.OnItemInstalled: app %d, item %s (not requested by the test)',
    [AData.m_unAppID, UIntToStr(AData.m_nPublishedFileId)]));
end;


{ --- Batch 2a: TSteamMatchmaking ... TSteamRemotePlay --- }

procedure TfrmMain.TestMatchmaking;
var
  M: TSteamMatchmakingPlugin;
begin
  M := SteamMatchmaking1.Plugin;
  if not BeginTest(CT_MATCHMAKING, SteamMatchmaking1, M) then
    Exit;
  try
    AddLog(Format('Test TSteamMatchmaking: %d favourite / history game servers', [M.GetFavoriteGameCount]));
    // Any lobbies of this app, at most one: the answer is what counts
    M.AddRequestLobbyListResultCountFilter(1);
    ExpectCall(CT_MATCHMAKING, 'RequestLobbyList', M.RequestLobbyList);
  except
    on E: Exception do ReadFailed(CT_MATCHMAKING, 'Matchmaking calls', E);
  end;
end;

procedure TfrmMain.MatchmakingLobbyMatchList(Sender: TObject; const AData: LobbyMatchList_t);
begin
  AddLog(Format('TSteamMatchmaking.OnLobbyMatchList: %d lobbies matching', [AData.m_nLobbiesMatching]));
  if Answered(CT_MATCHMAKING, 'RequestLobbyList') then
  begin
    FTests[CT_MATCHMAKING].Note := Format('%d lobbies', [AData.m_nLobbiesMatching]);
    CheckTestsDone;
  end;
end;

procedure TfrmMain.TestParties;
var
  P: TSteamPartiesPlugin;
  Locations: UInt32;
  HasLocations: Boolean;
begin
  P := SteamParties1.Plugin;
  if not BeginTest(CT_PARTIES, SteamParties1, P) then
    Exit;
  try
    Locations := 0;
    HasLocations := P.GetNumAvailableBeaconLocations(Locations);
    AddLog(Format('Test TSteamParties: %d active beacons, beacon locations %s (%d)',
      [P.GetNumActiveBeacons, BoolToStr(HasLocations, True), Locations]));
    FTests[CT_PARTIES].Note := 'reads only (a beacon would be a real party)';
  except
    on E: Exception do ReadFailed(CT_PARTIES, 'Parties reads', E);
  end;
end;

procedure TfrmMain.TestMusic;
var
  M: TSteamMusicPlugin;
begin
  M := SteamMusic1.Plugin;
  if not BeginTest(CT_MUSIC, SteamMusic1, M) then
    Exit;
  try
    AddLog(Format('Test TSteamMusic: enabled %s, playing %s, playback status %d, volume %.2f',
      [BoolToStr(M.BIsEnabled, True), BoolToStr(M.BIsPlaying, True), Ord(M.GetPlaybackStatus),
       M.GetVolume]));
    FTests[CT_MUSIC].Note := 'reads only (the music player is the user''s)';
  except
    on E: Exception do ReadFailed(CT_MUSIC, 'Music reads', E);
  end;
end;

procedure TfrmMain.TestHTTP;
var
  H: TSteamHTTPPlugin;
  Call: SteamAPICall_t;
begin
  H := SteamHTTP1.Plugin;
  if not BeginTest(CT_HTTP, SteamHTTP1, H) then
    Exit;
  try
    FHTTPRequest := H.CreateHTTPRequest(k_EHTTPMethodGET, TEST_HTTP_URL);
    if FHTTPRequest = 0 then
    begin
      FTests[CT_HTTP].ReadsOK := False;
      FTests[CT_HTTP].Note := 'CreateHTTPRequest returned 0';
      AddLog('Test TSteamHTTP: CreateHTTPRequest returned 0 (invalid handle)');
      Exit;
    end;
    Call := k_uAPICallInvalid;
    if not H.SendHTTPRequest(FHTTPRequest, Call) then
      AddLog('Test TSteamHTTP: SendHTTPRequest returned False');
    AddLog('Test TSteamHTTP: GET ' + TEST_HTTP_URL + ', request ' + UIntToStr(FHTTPRequest));
    ExpectCall(CT_HTTP, 'SendHTTPRequest', Call);
  except
    on E: Exception do ReadFailed(CT_HTTP, 'HTTP calls', E);
  end;
end;

procedure TfrmMain.HTTPRequestCompleted(Sender: TObject; const AData: HTTPRequestCompleted_t);
var
  H: TSteamHTTPPlugin;
  Body: TBytes;
  Size: UInt32;
  ShowBytes: Integer;
  Start: string;
begin
  AddLog(Format('TSteamHTTP.OnHTTPRequestCompleted: request %s, successful %s, HTTP status %d, %d bytes',
    [UIntToStr(AData.m_hRequest), BoolToStr(AData.m_bRequestSuccessful, True), Ord(AData.m_eStatusCode),
     AData.m_unBodySize]));
  if (AData.m_hRequest <> FHTTPRequest) or not Answered(CT_HTTP, 'SendHTTPRequest') then
    Exit;
  FTests[CT_HTTP].Note := Format('HTTP %d, %d bytes', [Ord(AData.m_eStatusCode), AData.m_unBodySize]);
  H := SteamHTTP1.Plugin;
  if H <> nil then
  try
    Size := 0;
    if AData.m_bRequestSuccessful and H.GetHTTPResponseBodySize(FHTTPRequest, Size) and (Size > 0) then
    begin
      SetLength(Body, Size);
      if H.GetHTTPResponseBodyData(FHTTPRequest, @Body[0], Size) then
      begin
        // The start of Steam's JSON answer, on one line
        // (no System.Math here: its IfThen would hide System.StrUtils')
        ShowBytes := Integer(Size);
        if ShowBytes > 80 then
          ShowBytes := 80;
        Start := TEncoding.UTF8.GetString(Body, 0, ShowBytes);
        Start := StringReplace(StringReplace(Start, #13, ' ', [rfReplaceAll]), #10, ' ', [rfReplaceAll]);
        AddLog('Test TSteamHTTP: body starts: ' + Start);
      end;
    end;
    AddLog('Test TSteamHTTP: ReleaseHTTPRequest ' + BoolToStr(H.ReleaseHTTPRequest(FHTTPRequest), True));
    FHTTPRequest := 0;
  except
    on E: Exception do ReadFailed(CT_HTTP, 'HTTP response', E);
  end;
  CheckTestsDone;
end;

procedure TfrmMain.TestHTMLSurface;
var
  H: TSteamHTMLSurfacePlugin;
begin
  H := SteamHTMLSurface1.Plugin;
  if not BeginTest(CT_HTML, SteamHTMLSurface1, H) then
    Exit;
  try
    FHTMLInit := H.Init;
    AddLog('Test TSteamHTMLSurface: Init ' + BoolToStr(FHTMLInit, True));
    if not FHTMLInit then
    begin
      FTests[CT_HTML].ReadsOK := False;
      FTests[CT_HTML].Note := 'Init returned False';
      Exit;
    end;
    // No URL is loaded: the browser is removed as soon as it is ready, so
    // none of the page callbacks Valve requires handlers for can come
    ExpectCall(CT_HTML, 'CreateBrowser', H.CreateBrowser('', ''));
  except
    on E: Exception do ReadFailed(CT_HTML, 'HTMLSurface calls', E);
  end;
end;

procedure TfrmMain.HTMLBrowserReady(Sender: TObject; const AData: HTML_BrowserReady_t);
begin
  AddLog(Format('TSteamHTMLSurface.OnHTML_BrowserReady: browser %d', [AData.unBrowserHandle]));
  if not Answered(CT_HTML, 'CreateBrowser') then
    Exit;
  FTests[CT_HTML].Note := Format('browser %d created and removed', [AData.unBrowserHandle]);
  if (SteamHTMLSurface1.Plugin <> nil) and (AData.unBrowserHandle <> INVALID_HTMLBROWSER) then
  try
    SteamHTMLSurface1.Plugin.RemoveBrowser(AData.unBrowserHandle);
    AddLog(Format('Test TSteamHTMLSurface: browser %d removed', [AData.unBrowserHandle]));
  except
    on E: Exception do ReadFailed(CT_HTML, 'RemoveBrowser', E);
  end;
  CheckTestsDone;
end;

procedure TfrmMain.TestInventory;
var
  I: TSteamInventoryPlugin;
begin
  I := SteamInventory1.Plugin;
  if not BeginTest(CT_INVENTORY, SteamInventory1, I) then
    Exit;
  try
    AddLog('Test TSteamInventory: LoadItemDefinitions ' + BoolToStr(I.LoadItemDefinitions, True));
    FInvResult := k_SteamInventoryResultInvalid;
    if I.GetAllItems(FInvResult) then
    begin
      AddLog('Test TSteamInventory: GetAllItems, result handle ' + IntToStr(FInvResult) +
        ' - waiting for callback 4700');
      Expect(CT_INVENTORY, 'GetAllItems');
    end
    else
    begin
      Inc(FTests[CT_INVENTORY].Sent);
      FTests[CT_INVENTORY].Missing := 'GetAllItems (returned False)';
      AddLog('Test TSteamInventory: GetAllItems returned False');
    end;
  except
    on E: Exception do ReadFailed(CT_INVENTORY, 'Inventory calls', E);
  end;
end;

procedure TfrmMain.InventoryResultReady(Sender: TObject; const AData: SteamInventoryResultReady_t);
var
  I: TSteamInventoryPlugin;
  Count: UInt32;
begin
  AddLog(Format('TSteamInventory.OnSteamInventoryResultReady: result %d, %s',
    [AData.m_handle, ResultText(AData.m_result)]));
  if (AData.m_handle <> FInvResult) or not Answered(CT_INVENTORY, 'GetAllItems') then
    Exit;
  FTests[CT_INVENTORY].Note := 'result ' + ResultText(AData.m_result);
  I := SteamInventory1.Plugin;
  if I <> nil then
  try
    // nil array: only the item count
    Count := 0;
    if I.GetResultItems(FInvResult, nil, Count) then
      AddLog(Format('Test TSteamInventory: %d items', [Count]));
    I.DestroyResult(FInvResult);
    AddLog('Test TSteamInventory: result destroyed');
    FInvResult := k_SteamInventoryResultInvalid;
  except
    on E: Exception do ReadFailed(CT_INVENTORY, 'GetResultItems / DestroyResult', E);
  end;
  CheckTestsDone;
end;

procedure TfrmMain.TestVideo;
var
  V: TSteamVideoPlugin;
  Viewers: Integer;
  Broadcasting: Boolean;
begin
  V := SteamVideo1.Plugin;
  if not BeginTest(CT_VIDEO, SteamVideo1, V) then
    Exit;
  try
    Viewers := 0;
    Broadcasting := V.IsBroadcasting(Viewers);
    AddLog(Format('Test TSteamVideo: broadcasting %s, %d viewers', [BoolToStr(Broadcasting, True), Viewers]));
    // OPF (360 video) settings of this app: it has none, the answer counts
    V.GetOPFSettings(APP_ID);
    AddLog('Test TSteamVideo: GetOPFSettings - waiting for callback 4624 (UNVERIFIED that Steam ' +
      'answers for an app without 360 video; NO ANSWER here would be that, not a component fault)');
    Expect(CT_VIDEO, 'GetOPFSettings');
  except
    on E: Exception do ReadFailed(CT_VIDEO, 'Video calls', E);
  end;
end;

procedure TfrmMain.VideoOPFSettingsResult(Sender: TObject; const AData: GetOPFSettingsResult_t);
begin
  AddLog(Format('TSteamVideo.OnGetOPFSettingsResult: result %s, video app %d',
    [ResultText(AData.m_eResult), AData.m_unVideoAppID]));
  if Answered(CT_VIDEO, 'GetOPFSettings') then
  begin
    FTests[CT_VIDEO].Note := 'OPF settings ' + ResultText(AData.m_eResult);
    CheckTestsDone;
  end;
end;

procedure TfrmMain.TestParentalSettings;
var
  P: TSteamParentalSettingsPlugin;
begin
  P := SteamParentalSettings1.Plugin;
  if not BeginTest(CT_PARENTAL, SteamParentalSettings1, P) then
    Exit;
  try
    AddLog(Format('Test TSteamParentalSettings: lock enabled %s, locked %s, this app blocked %s / in block list %s, ' +
      'store blocked %s', [BoolToStr(P.BIsParentalLockEnabled, True), BoolToStr(P.BIsParentalLockLocked, True),
      BoolToStr(P.BIsAppBlocked(APP_ID), True), BoolToStr(P.BIsAppInBlockList(APP_ID), True),
      BoolToStr(P.BIsFeatureBlocked(k_EFeatureStore), True)]));
    FTests[CT_PARENTAL].Note := 'reads only';
  except
    on E: Exception do ReadFailed(CT_PARENTAL, 'ParentalSettings reads', E);
  end;
end;

procedure TfrmMain.TestRemotePlay;
var
  R: TSteamRemotePlayPlugin;
begin
  R := SteamRemotePlay1.Plugin;
  if not BeginTest(CT_REMOTEPLAY, SteamRemotePlay1, R) then
    Exit;
  try
    AddLog(Format('Test TSteamRemotePlay: %d Remote Play sessions', [R.GetSessionCount]));
    FTests[CT_REMOTEPLAY].Note := 'reads only (a session needs a second device)';
  except
    on E: Exception do ReadFailed(CT_REMOTEPLAY, 'RemotePlay reads', E);
  end;
end;

{ --- Batch 2b: TSteamNetworking ... TSteamNetworkingUtils --- }

procedure TfrmMain.TestNetworking;
var
  N: TSteamNetworkingPlugin;
  Size: UInt32;
  State: P2PSessionState_t;
  Me: TSteamID;
begin
  N := SteamNetworking1.Plugin;
  if not BeginTest(CT_NETWORKING, SteamNetworking1, N) then
    Exit;
  try
    // Nobody sends this app P2P packets: both answer False
    Size := 0;
    FillChar(State, SizeOf(State), 0);
    Me := TSteamID.Create(0);
    if SteamUser1.Plugin <> nil then
      Me := SteamUser1.Plugin.GetSteamID;
    AddLog(Format('Test TSteamNetworking: P2P packet waiting on channel 0 %s, ' +
      'session with ourselves %s (deprecated interface, reads only)',
      [BoolToStr(N.IsP2PPacketAvailable(Size, 0), True),
       BoolToStr(N.GetP2PSessionState(Me, State), True)]));
    FTests[CT_NETWORKING].Note := 'reads only (P2P needs a second user)';
  except
    on E: Exception do ReadFailed(CT_NETWORKING, 'Networking reads', E);
  end;
end;

procedure TfrmMain.TestNetworkingSockets;
const
  TEST_TEXT = 'TSteamAPI socket pair test';
var
  S: TSteamNetworkingSocketsPlugin;
  Ident: SteamNetworkingIdentity;
  Info: SteamNetConnectionInfo_t;
  Data: TBytes;
  MsgNo: Int64;
  Res: EResult;
  Msgs: array[0..3] of PSteamNetworkingMessage_t;
  Count, I: Integer;
  Got: TBytes;
  Same: Boolean;
  Me: UInt64;
begin
  S := SteamNetworkingSockets1.Plugin;
  if not BeginTest(CT_NETSOCKETS, SteamNetworkingSockets1, S) then
    Exit;
  // Our identity: a SteamNetworkingIdentity (C union) read back - the type
  // and the 64-bit id prove the variant record lines up
  try
    FillChar(Ident, SizeOf(Ident), 0);
    Me := 0;
    if SteamUser1.Plugin <> nil then
      Me := SteamUser1.Plugin.GetSteamID;
    if S.GetIdentity(Ident) then
    begin
      Same := (Ident.m_eType = k_ESteamNetworkingIdentityType_SteamID) and
        (Ident.m_steamID64 = Me);
      AddLog(Format('Test TSteamNetworkingSockets: identity type %d, SteamID %s - %s the logged-on user',
        [Ord(Ident.m_eType), UIntToStr(Ident.m_steamID64), IfThen(Same, 'same as', 'DIFFERENT FROM')]));
      if not Same then
        FTests[CT_NETSOCKETS].ReadsOK := False;
    end
    else
      AddLog('Test TSteamNetworkingSockets: GetIdentity False (identity not known yet)');
  except
    on E: Exception do ReadFailed(CT_NETSOCKETS, 'GetIdentity', E);
  end;
  // A socket pair in this process (internal buffers, no network), one
  // reliable message from 1 to 2
  try
    FSockConn1 := k_HSteamNetConnection_Invalid;
    FSockConn2 := k_HSteamNetConnection_Invalid;
    if not S.CreateSocketPair(FSockConn1, FSockConn2, False, nil, nil) then
    begin
      AddLog('Test TSteamNetworkingSockets: CreateSocketPair FAILED');
      FTests[CT_NETSOCKETS].ReadsOK := False;
      FTests[CT_NETSOCKETS].Note := 'CreateSocketPair failed';
      Exit;
    end;
    FillChar(Info, SizeOf(Info), 0);
    if S.GetConnectionInfo(FSockConn1, Info) then
      AddLog(Format('Test TSteamNetworkingSockets: socket pair %u / %u, connection 1 state %d ' +
        '(3 = connected), remote identity type %d', [FSockConn1, FSockConn2, Ord(Info.m_eState),
        Ord(Info.m_identityRemote.m_eType)]));
    Data := TEncoding.UTF8.GetBytes(TEST_TEXT);
    MsgNo := 0;
    Res := S.SendMessageToConnection(FSockConn1, @Data[0], Length(Data), k_nSteamNetworkingSend_Reliable, MsgNo);
    AddLog(Format('Test TSteamNetworkingSockets: sent %d bytes on connection 1: %s, message number %d',
      [Length(Data), ResultText(Res), MsgNo]));
    FillChar(Msgs, SizeOf(Msgs), 0);
    Count := S.ReceiveMessages(FSockConn2, Msgs);
    Same := False;
    for I := 0 to Count - 1 do
    begin
      SetLength(Got, Msgs[I]^.m_cbSize);
      if Length(Got) > 0 then
        Move(Msgs[I]^.m_pData^, Got[0], Length(Got));
      Same := Same or ((Msgs[I]^.m_conn = FSockConn2) and (Length(Got) = Length(Data)) and
        CompareMem(@Got[0], @Data[0], Length(Data)));
      AddLog(Format('Test TSteamNetworkingSockets: received on connection %u: %d bytes, message number %d, "%s"',
        [Msgs[I]^.m_conn, Msgs[I]^.m_cbSize, Msgs[I]^.m_nMessageNumber, TEncoding.UTF8.GetString(Got)]));
      S.ReleaseMessage(Msgs[I]);
    end;
    if (Res <> k_EResultOK) or not Same then
    begin
      FTests[CT_NETSOCKETS].ReadsOK := False;
      FTests[CT_NETSOCKETS].Note := Format('send %s, %d received, data %s',
        [ResultText(Res), Count, IfThen(Same, 'identical', 'NOT RECEIVED / DIFFERENT')]);
    end
    else
      FTests[CT_NETSOCKETS].Note := 'message sent and received';
    // Closing side 1 tells side 2 (callback 1221, ClosedByPeer); side 2 is
    // closed in NetConnectionStatusChanged
    AddLog('Test TSteamNetworkingSockets: CloseConnection(1) ' + BoolToStr(S.CloseConnection(FSockConn1,
      k_ESteamNetConnectionEnd_App_Generic, 'component test done', False), True));
    FSockConn1 := k_HSteamNetConnection_Invalid;
    Expect(CT_NETSOCKETS, 'ConnectionStatusChanged (closed by peer)');
  except
    on E: Exception do ReadFailed(CT_NETSOCKETS, 'socket pair', E);
  end;
end;

procedure TfrmMain.NetConnectionStatusChanged(Sender: TObject; const AData: SteamNetConnectionStatusChangedCallback_t);
begin
  AddLog(Format('TSteamNetworkingSockets.OnSteamNetConnectionStatusChangedCallback: connection %u, ' +
    'state %d -> %d, end reason %d, "%s"', [AData.m_hConn, Ord(AData.m_eOldState), Ord(AData.m_info.m_eState),
    AData.m_info.m_eEndReason, SteamText(@AData.m_info.m_szEndDebug[0])]));
  if (AData.m_hConn <> FSockConn2) or (FSockConn2 = k_HSteamNetConnection_Invalid) or
    (AData.m_info.m_eState <> k_ESteamNetworkingConnectionState_ClosedByPeer) then
    Exit;
  CloseSocketPair('Test TSteamNetworkingSockets');
  if Answered(CT_NETSOCKETS, 'ConnectionStatusChanged (closed by peer)') then
  begin
    FTests[CT_NETSOCKETS].Note := FTests[CT_NETSOCKETS].Note + ', close seen by the peer';
    CheckTestsDone;
  end;
end;

procedure TfrmMain.CloseSocketPair(const AWhy: string);
var
  S: TSteamNetworkingSocketsPlugin;
begin
  S := SteamNetworkingSockets1.Plugin;
  if S <> nil then
  begin
    if FSockConn1 <> k_HSteamNetConnection_Invalid then
      AddLog(AWhy + ': CloseConnection(1) ' + BoolToStr(S.CloseConnection(FSockConn1, 0, '', False), True));
    if FSockConn2 <> k_HSteamNetConnection_Invalid then
      AddLog(AWhy + ': CloseConnection(2) ' + BoolToStr(S.CloseConnection(FSockConn2, 0, '', False), True));
  end;
  FSockConn1 := k_HSteamNetConnection_Invalid;
  FSockConn2 := k_HSteamNetConnection_Invalid;
end;

procedure TfrmMain.TestNetworkingMessages;
var
  M: TSteamNetworkingMessagesPlugin;
  Msgs: array[0..3] of PSteamNetworkingMessage_t;
  Count, I: Integer;
begin
  M := SteamNetworkingMessages1.Plugin;
  if not BeginTest(CT_NETMESSAGES, SteamNetworkingMessages1, M) then
    Exit;
  try
    // Nobody sends this app messages: 0 expected (any that arrive are released)
    FillChar(Msgs, SizeOf(Msgs), 0);
    Count := M.ReceiveMessages(0, Msgs);
    for I := 0 to Count - 1 do
      M.ReleaseMessage(Msgs[I]);
    AddLog(Format('Test TSteamNetworkingMessages: %d messages waiting on channel 0', [Count]));
    FTests[CT_NETMESSAGES].Note := 'reads only (messages need a second user)';
  except
    on E: Exception do ReadFailed(CT_NETMESSAGES, 'NetworkingMessages reads', E);
  end;
end;

procedure TfrmMain.TestNetworkingUtils;
var
  U: TSteamNetworkingUtilsPlugin;
  T1, T2: SteamNetworkingMicroseconds;
  Status: SteamRelayNetworkStatus_t;
  Avail: ESteamNetworkingAvailability;
begin
  U := SteamNetworkingUtils1.Plugin;
  if not BeginTest(CT_NETUTILS, SteamNetworkingUtils1, U) then
    Exit;
  try
    T1 := U.GetLocalTimestamp;
    T2 := U.GetLocalTimestamp;
    AddLog(Format('Test TSteamNetworkingUtils: local timestamp %d us, then %d us', [T1, T2]));
    if (T1 <= 0) or (T2 < T1) then
    begin
      FTests[CT_NETUTILS].ReadsOK := False;
      FTests[CT_NETUTILS].Note := 'timestamp not increasing';
      Exit;
    end;
    // Starts the relay network (SDR) in the background; progress comes as
    // callback 1281 (logged by RelayNetworkStatus, not waited for)
    U.InitRelayNetworkAccess;
    FillChar(Status, SizeOf(Status), 0);
    Avail := U.GetRelayNetworkStatus(Status);
    AddLog(Format('Test TSteamNetworkingUtils: relay network availability %d (100 = current), ' +
      'network config %d, any relay %d, "%s"', [Ord(Avail), Ord(Status.m_eAvailNetworkConfig),
      Ord(Status.m_eAvailAnyRelay), SteamText(@Status.m_debugMsg[0])]));
    FTests[CT_NETUTILS].Note := Format('relay availability %d', [Ord(Avail)]);
  except
    on E: Exception do ReadFailed(CT_NETUTILS, 'NetworkingUtils calls', E);
  end;
end;

procedure TfrmMain.RelayNetworkStatus(Sender: TObject; const AData: SteamRelayNetworkStatus_t);
begin
  AddLog(Format('TSteamNetworkingUtils.OnSteamRelayNetworkStatus: availability %d, network config %d, ' +
    'any relay %d, "%s"', [Ord(AData.m_eAvail), Ord(AData.m_eAvailNetworkConfig), Ord(AData.m_eAvailAnyRelay),
    SteamText(@AData.m_debugMsg[0])]));
end;

{ --- TSteamMatchmakingServers --- }

{ How a server-list refresh ended. }
function ServerResponseText(AResponse: EMatchMakingServerResponse): string;
begin
  case Ord(AResponse) of
    0: Result := 'servers responded';
    1: Result := 'servers failed to respond';
    2: Result := 'no servers listed on the master server';
  else
    Result := 'response ' + IntToStr(Ord(AResponse));
  end;
end;

{ An IPv4 address in host order as a.b.c.d. }
function IPv4Text(AIP: UInt32): string;
begin
  Result := Format('%d.%d.%d.%d', [(AIP shr 24) and 255, (AIP shr 16) and 255, (AIP shr 8) and 255, AIP and 255]);
end;

procedure TfrmMain.AddServerNote(const S: string);
begin
  if FTests[CT_SERVERS].Note <> '' then
    FTests[CT_SERVERS].Note := FTests[CT_SERVERS].Note + ', ';
  FTests[CT_SERVERS].Note := FTests[CT_SERVERS].Note + S;
end;

procedure TfrmMain.ServerRequestStarted(const AName, AWhat: string; AOk: Boolean);
begin
  if AOk then
  begin
    AddLog(Format('Test TSteamMatchmakingServers: %s started - waiting for its answers', [AWhat]));
    Expect(CT_SERVERS, AName);
  end
  else
  begin
    Inc(FTests[CT_SERVERS].Sent);
    if FTests[CT_SERVERS].Missing <> '' then
      FTests[CT_SERVERS].Missing := FTests[CT_SERVERS].Missing + ', ';
    FTests[CT_SERVERS].Missing := FTests[CT_SERVERS].Missing + AName + ' (refused)';
    AddLog(Format('Test TSteamMatchmakingServers: %s REFUSED by Steam (no request / query handle)', [AWhat]));
  end;
end;

procedure TfrmMain.TestMatchmakingServers;
var
  P: TSteamMatchmakingServersPlugin;
begin
  P := SteamMatchmakingServers1.Plugin;
  if not BeginTest(CT_SERVERS, SteamMatchmakingServers1, P) then
    Exit;
  FServersSeen := 0;
  FServersFailed := 0;
  FServersFake := 0;
  FHaveServer := False;
  FPlayerCount := 0;
  FRuleCount := 0;
  try
    // LAN: no master server, ends by itself within seconds - proves the
    // list response object (RefreshComplete through its vtable)
    FLANList := SteamMatchmakingServers1.StartServerList(sltLAN, SteamAPI1.AppID);
    ServerRequestStarted('LANList', 'LAN list for this app', FLANList <> nil);
    // Internet: a game with many public servers (read-only queries), so
    // ServerResponded and the ping / players / rules queries get a real
    // server to talk to
    FServerList := SteamMatchmakingServers1.StartServerList(sltInternet, TEST_SERVER_APP,
      ['hasplayers', 'secure'], ['1', '1']);   // values as in Valve's SpaceWar sample
    ServerRequestStarted('InternetList', Format('Internet list for AppID %d (hasplayers, secure; ' +
      'released after %d servers incl. one with a direct address, or %d)', [TEST_SERVER_APP, TEST_SERVER_MAX,
      TEST_SERVER_LIMIT]), FServerList <> nil);
  except
    on E: Exception do ReadFailed(CT_SERVERS, 'StartServerList', E);
  end;
end;

procedure TfrmMain.EndInternetList(const AHow: string);
begin
  if not Answered(CT_SERVERS, 'InternetList') then
    Exit;
  AddServerNote(Format('Internet list (AppID %d) %s: %d answered (%d with a relay fake IP), %d failed',
    [TEST_SERVER_APP, AHow, FServersSeen, FServersFake, FServersFailed]));
  try
    SteamMatchmakingServers1.StopServerList(FServerList);
    AddLog('Test TSteamMatchmakingServers: Internet list released (StopServerList)');
  except
    on E: Exception do ReadFailed(CT_SERVERS, 'StopServerList', E);
  end;
  FServerList := nil;
  if not FHaveServer then
  begin
    AddServerNote('no server with a direct address answered - ping / players / rules not tested');
    Exit;
  end;
  AddLog(Format('Test TSteamMatchmakingServers: querying "%s" (%s, query port %d): ping, players, rules',
    [FFirstName, IPv4Text(FFirstIP), FFirstQueryPort]));
  try
    FPingQuery := SteamMatchmakingServers1.StartPing(FFirstIP, FFirstQueryPort);
    ServerRequestStarted('Ping', Format('StartPing (query %d)', [FPingQuery]), FPingQuery <> HSERVERQUERY_INVALID);
    FPlayersQuery := SteamMatchmakingServers1.StartPlayerDetails(FFirstIP, FFirstQueryPort);
    ServerRequestStarted('Players', Format('StartPlayerDetails (query %d)', [FPlayersQuery]),
      FPlayersQuery <> HSERVERQUERY_INVALID);
    FRulesQuery := SteamMatchmakingServers1.StartServerRules(FFirstIP, FFirstQueryPort);
    ServerRequestStarted('Rules', Format('StartServerRules (query %d)', [FRulesQuery]),
      FRulesQuery <> HSERVERQUERY_INVALID);
  except
    on E: Exception do ReadFailed(CT_SERVERS, 'StartPing / StartPlayerDetails / StartServerRules', E);
  end;
end;

procedure TfrmMain.ServersResponded(Sender: TObject; ARequest: HServerListRequest; AIndex: Integer;
  const AServer: gameserveritem_t);
var
  Fake: Boolean;
begin
  if (ARequest = nil) or (ARequest <> FServerList) then
  begin
    AddLog(Format('TSteamMatchmakingServers.OnServerResponded: server %d of another list, "%s"',
      [AIndex, SteamText(@AServer.m_szServerName[0])]));
    Exit;
  end;
  Inc(FServersSeen);
  Fake := (AServer.m_NetAdr.m_unIP shr 16) = $A9FE;   // 169.254.0.0/16
  if Fake then
    Inc(FServersFake);
  // the first few, and the one that will be queried
  if (FServersSeen <= TEST_SERVER_MAX) or not (Fake or FHaveServer) then
    AddLog(Format('TSteamMatchmakingServers.OnServerResponded: server %d "%s", map %s, %d/%d players, ' +
      '%d ms, %s port %d (query port %d)%s', [AIndex, SteamText(@AServer.m_szServerName[0]),
      SteamText(@AServer.m_szMap[0]), AServer.m_nPlayers, AServer.m_nMaxPlayers, AServer.m_nPing,
      IPv4Text(AServer.m_NetAdr.m_unIP), AServer.m_NetAdr.m_usConnectionPort, AServer.m_NetAdr.m_usQueryPort,
      IfThen(Fake, ' - relay fake IP', '')]));
  if not (FHaveServer or Fake) then
  begin
    FHaveServer := True;
    FFirstIP := AServer.m_NetAdr.m_unIP;
    FFirstQueryPort := AServer.m_NetAdr.m_usQueryPort;
    FFirstName := SteamText(@AServer.m_szServerName[0]);
  end;
  if (FHaveServer and (FServersSeen >= TEST_SERVER_MAX)) or (FServersSeen >= TEST_SERVER_LIMIT) then
    EndInternetList(Format('released after %d servers', [FServersSeen]));
end;

procedure TfrmMain.ServersFailed(Sender: TObject; ARequest: HServerListRequest; AIndex: Integer);
begin
  if (ARequest <> nil) and (ARequest = FServerList) then
    Inc(FServersFailed);
end;

procedure TfrmMain.ServerListComplete(Sender: TObject; ARequest: HServerListRequest;
  AResponse: EMatchMakingServerResponse);
var
  Count: Integer;
begin
  Count := -1;
  try
    if SteamMatchmakingServers1.Plugin <> nil then
      Count := SteamMatchmakingServers1.Plugin.GetServerCount(ARequest);
  except
    on E: Exception do ReadFailed(CT_SERVERS, 'GetServerCount', E);
  end;
  AddLog(Format('TSteamMatchmakingServers.OnServerListComplete: %s, %d servers in the list',
    [ServerResponseText(AResponse), Count]));
  if (ARequest <> nil) and (ARequest = FLANList) then
  begin
    if Answered(CT_SERVERS, 'LANList') then
      AddServerNote(Format('LAN list: %s (%d)', [ServerResponseText(AResponse), Count]));
    try
      SteamMatchmakingServers1.StopServerList(FLANList);
    except
      on E: Exception do ReadFailed(CT_SERVERS, 'StopServerList', E);
    end;
    FLANList := nil;
  end
  else if (ARequest <> nil) and (ARequest = FServerList) then
    EndInternetList('complete (' + ServerResponseText(AResponse) + ')');
end;

procedure TfrmMain.PingResponded(Sender: TObject; AQuery: HServerQuery; const AServer: gameserveritem_t);
begin
  AddLog(Format('TSteamMatchmakingServers.OnPingResponded: query %d, "%s", %d ms',
    [AQuery, SteamText(@AServer.m_szServerName[0]), AServer.m_nPing]));
  if (AQuery = FPingQuery) and Answered(CT_SERVERS, 'Ping') then
    AddServerNote(Format('ping %d ms', [AServer.m_nPing]));
end;

procedure TfrmMain.PingFailed(Sender: TObject; AQuery: HServerQuery);
begin
  AddLog(Format('TSteamMatchmakingServers.OnPingFailed: query %d', [AQuery]));
  if (AQuery = FPingQuery) and Answered(CT_SERVERS, 'Ping') then
    AddServerNote('ping: no answer from the server');
end;

procedure TfrmMain.ServerPlayer(Sender: TObject; AQuery: HServerQuery; const AName: string;
  AScore: Integer; ATimePlayed: Single);
begin
  if AQuery <> FPlayersQuery then
    Exit;
  Inc(FPlayerCount);
  if FPlayerCount <= 3 then
    AddLog(Format('TSteamMatchmakingServers.OnPlayer: query %d, "%s", score %d, %.0f s',
      [AQuery, AName, AScore, ATimePlayed]));
end;

procedure TfrmMain.PlayersFailed(Sender: TObject; AQuery: HServerQuery);
begin
  AddLog(Format('TSteamMatchmakingServers.OnPlayersFailed: query %d', [AQuery]));
  if (AQuery = FPlayersQuery) and Answered(CT_SERVERS, 'Players') then
    AddServerNote('players: no answer from the server');
end;

procedure TfrmMain.PlayersComplete(Sender: TObject; AQuery: HServerQuery);
begin
  AddLog(Format('TSteamMatchmakingServers.OnPlayersComplete: query %d, %d players', [AQuery, FPlayerCount]));
  if (AQuery = FPlayersQuery) and Answered(CT_SERVERS, 'Players') then
    AddServerNote(Format('%d players', [FPlayerCount]));
end;

procedure TfrmMain.ServerRule(Sender: TObject; AQuery: HServerQuery; const ARule, AValue: string);
begin
  if AQuery <> FRulesQuery then
    Exit;
  Inc(FRuleCount);
  if FRuleCount <= 3 then
    AddLog(Format('TSteamMatchmakingServers.OnRule: query %d, %s = "%s"', [AQuery, ARule, AValue]));
end;

procedure TfrmMain.RulesFailed(Sender: TObject; AQuery: HServerQuery);
begin
  AddLog(Format('TSteamMatchmakingServers.OnRulesFailed: query %d', [AQuery]));
  if (AQuery = FRulesQuery) and Answered(CT_SERVERS, 'Rules') then
    AddServerNote('rules: no answer from the server');
end;

procedure TfrmMain.RulesComplete(Sender: TObject; AQuery: HServerQuery);
begin
  AddLog(Format('TSteamMatchmakingServers.OnRulesComplete: query %d, %d rules', [AQuery, FRuleCount]));
  if (AQuery = FRulesQuery) and Answered(CT_SERVERS, 'Rules') then
    AddServerNote(Format('%d rules', [FRuleCount]));
end;

procedure TfrmMain.StopServerRequests(const AWhy: string);
var
  P: TSteamMatchmakingServersPlugin;
begin
  P := SteamMatchmakingServers1.Plugin;
  if P <> nil then
  begin
    if FServerList <> nil then
    begin
      P.StopServerList(FServerList);
      AddLog(AWhy + ': Internet server list released');
    end;
    if FLANList <> nil then
    begin
      P.StopServerList(FLANList);
      AddLog(AWhy + ': LAN server list released');
    end;
    // harmless for queries that have ended
    if FPingQuery <> HSERVERQUERY_INVALID then
      P.StopServerQuery(FPingQuery);
    if FPlayersQuery <> HSERVERQUERY_INVALID then
      P.StopServerQuery(FPlayersQuery);
    if FRulesQuery <> HSERVERQUERY_INVALID then
      P.StopServerQuery(FRulesQuery);
  end;
  FServerList := nil;
  FLANList := nil;
  FPingQuery := HSERVERQUERY_INVALID;
  FPlayersQuery := HSERVERQUERY_INVALID;
  FRulesQuery := HSERVERQUERY_INVALID;
end;

end.
