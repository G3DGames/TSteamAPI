{ @abstract(The base test of 30 plug-in components, for all three demos
  (SteamDemo FMX, SteamDemoVCL, SteamDemoLCL): no UI, compiles with Delphi
  and FPC.)

  @link(TSteamComponentTest) creates the components itself (owned by it,
  linked to the TSteamAPI given to its constructor, events wired in code),
  so a form only creates it, calls @link(TSteamComponentTest.Start) from a
  button, @link(TSteamComponentTest.Tick) from a 1 s timer, and shows
  @link(TSteamComponentTest.OnRowChanged) in a list. (Until 2026-11-02 the
  FMX demo had its own copy with the components on its form.)

  The last nine rows are the GAME SERVER's components: the test starts a
  listen server in this process (TSteamAPI.StartGameServer, ports
  @link(TEST_GS_GAME_PORT) / @link(TEST_GS_QUERY_PORT); one that runs
  already is used as it is), logs it on anonymously, queries it through
  the server browser at 127.0.0.1 (rules - @link(TEST_GS_RULE) must come
  back -, ping, players), lets it validate the logged-on user's ticket, and
  stops it again at the end.

  Per component the test checks that it is attached, makes its synchronous
  calls through the component's Plugin property (an exception = calls
  FAILED), and requests callbacks / call results that must arrive through
  the component's events within @link(TEST_TIMEOUT_MS). A component PASSES
  when it is attached, every call returned and every requested answer
  arrived - whatever result code Steam put in it (Steam Cloud or Workshop
  being off for the app is a Steam setting, not a component fault).
  Side effects: @link(TEST_CLOUD_FILE) is written and deleted again; a
  timeline event and game phase are recorded and the timeline game mode is
  left at Menus; a socket pair inside the program sends itself one message;
  the listen server is listed (advertised) while the test runs.
  No screenshot is written (the demos' File > Take Screenshot does that).
  Cleanup needs Steam: call @link(TSteamComponentTest.Finish) BEFORE
  closing Steam.

  Also here: @link(DemoSettingsFolder), the per-user settings folder the
  demos keep their Auto Start Steam setting in. }
unit SteamComponentTest;

{$ifdef FPC}
  {$mode delphi}{$H+}
{$endif}

interface

uses
  SysUtils, Classes, StrUtils,
  Steamworks.Types, Steamworks.SDKTypes, Steamworks.Callbacks, Steamworks.Core, Steamworks.Components,
  Steamworks.Plugin.Utils, Steamworks.Plugin.User, Steamworks.Plugin.Apps,
  Steamworks.Plugin.RemoteStorage, Steamworks.Plugin.Screenshots, Steamworks.Plugin.Timeline,
  Steamworks.Plugin.UGC, Steamworks.Plugin.Matchmaking, Steamworks.Plugin.Parties,
  Steamworks.Plugin.Music, Steamworks.Plugin.HTTP, Steamworks.Plugin.HTMLSurface,
  Steamworks.Plugin.Inventory, Steamworks.Plugin.Video, Steamworks.Plugin.ParentalSettings,
  Steamworks.Plugin.RemotePlay, Steamworks.Plugin.Networking, Steamworks.Plugin.NetworkingSockets,
  Steamworks.Plugin.NetworkingMessages, Steamworks.Plugin.NetworkingUtils,
  Steamworks.Plugin.MatchmakingServers, Steamworks.Plugin.GameServer, Steamworks.Plugin.GameServerStats;

const
  { Component test: index of TSteamUtils. }
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
  { Component test: index of TSteamMatchmaking. }
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
  { Component test: index of TSteamGameServer (the test starts a LISTEN
    server in this process unless one runs already). }
  CT_GAMESERVER = 21;
  { Component test: index of TSteamGameServerStats. }
  CT_GSSTATS = 22;
  { Component test: index of TSteamGameServerUtils (the server's copy). }
  CT_GSUTILS = 23;
  { Component test: index of TSteamGameServerNetworking. }
  CT_GSNETWORKING = 24;
  { Component test: index of TSteamGameServerNetworkingSockets. }
  CT_GSSOCKETS = 25;
  { Component test: index of TSteamGameServerNetworkingMessages. }
  CT_GSMESSAGES = 26;
  { Component test: index of TSteamGameServerHTTP. }
  CT_GSHTTP = 27;
  { Component test: index of TSteamGameServerUGC. }
  CT_GSUGC = 28;
  { Component test: index of TSteamGameServerInventory. }
  CT_GSINVENTORY = 29;
  { Number of components the component test covers. }
  CT_COUNT = 30;
  { Game port of the listen server the test starts (not the default 27015,
    so a game server of the demo's own - the pair test - is never in the way). }
  TEST_GS_GAME_PORT = 27115;
  { Query port of that server: Steam answers server-browser queries there
    itself, so the test's own MatchmakingServers queries reach it. }
  TEST_GS_QUERY_PORT = 27116;
  { Rule (SetKeyValue) the test's server sets and its rules query must see:
    the RulesResponded path that no Counter-Strike 2 server answers. }
  TEST_GS_RULE = 'tsapi_test';
  { 127.0.0.1 in host order: the test queries its own server. }
  TEST_GS_LOCALHOST = $7F000001;
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
  { Item definition of docs/test-setup/itemdefs_2275430.json: the promo
    item "TSteamAPI Test Token" (AddPromoItem). The extended Inventory test
    runs only when GetAllItems answers OK, i.e. once the Inventory Service
    is enabled for the app (docs/TestSetup.md). }
  TEST_ITEM_PROMO = 100;
  { Item definition "TSteamAPI Test Gem" (GenerateItems, then ConsumeItem). }
  TEST_ITEM_GEM = 101;
  { Item definition of the playtime generator that drops a Test Gem
    (TriggerItemDrop). }
  TEST_ITEM_DROP = 10;
  { Extended Inventory step: GenerateItems (index of @code(FInvSteps)). }
  INV_GENERATE = 0;
  { Extended Inventory step: ConsumeItem of the generated Test Gem. }
  INV_CONSUME = 1;
  { Extended Inventory step: AddPromoItem. }
  INV_PROMO = 2;
  { Extended Inventory step: TriggerItemDrop. }
  INV_DROP = 3;
  { Names of the extended Inventory steps (they are also the answer names). }
  InvStepNames: array[INV_GENERATE..INV_DROP] of string =
    ('GenerateItems', 'ConsumeItem', 'AddPromoItem', 'TriggerItemDrop');
  { Title of the Workshop item the extended UGC test creates and deletes
    again. The test runs only when GetWorkshopEULAStatus answers OK (the
    Workshop is set up for the app, docs/TestSetup.md). }
  TEST_UGC_TITLE = 'TSteamAPI component test item (deleted again by the test)';
  { Sub-folder of the settings folder the extended UGC test uploads as the
    item's content (one small file), removed after the upload. }
  TEST_UGC_FOLDER = 'WorkshopTest';
  { The one file in @link(TEST_UGC_FOLDER). }
  TEST_UGC_FILE = 'readme.txt';
  { Steam Cloud file the RemoteStorage test writes, reads back and deletes. }
  TEST_CLOUD_FILE = 'steamdemo_component_test.txt';
  { Row titles, indexed by the CT_ constants. }
  TestNames: array[0..CT_COUNT - 1] of string = ('TSteamUtils', 'TSteamUser',
    'TSteamApps', 'TSteamRemoteStorage', 'TSteamScreenshots', 'TSteamTimeline', 'TSteamUGC',
    'TSteamMatchmaking', 'TSteamParties', 'TSteamMusic', 'TSteamHTTP', 'TSteamHTMLSurface',
    'TSteamInventory', 'TSteamVideo', 'TSteamParentalSettings', 'TSteamRemotePlay',
    'TSteamNetworking', 'TSteamNetworkingSockets', 'TSteamNetworkingMessages', 'TSteamNetworkingUtils',
    'TSteamMatchmakingServers', 'TSteamGameServer', 'TSteamGameServerStats', 'TSteamGameServerUtils',
    'TSteamGameServerNetworking', 'TSteamGameServerNetworkingSockets', 'TSteamGameServerNetworkingMessages',
    'TSteamGameServerHTTP', 'TSteamGameServerUGC', 'TSteamGameServerInventory');

type
  { State of one component in the test. }
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
    { Extra information shown in the row (result codes, ...). }
    Note: string;
  end;

  { A line for the log. }
  TComponentTestLogEvent = procedure(const AText: string) of object;
  { Row AIndex (a CT_ constant) has new text. }
  TComponentTestRowEvent = procedure(AIndex: Integer; const AText: string) of object;

  { One awaited answer: key '<CT index>:<name>' and when it was requested. }
  TComponentTestPending = record
    { '<CT index>:<name>'. }
    Key: string;
    { @link(TestTicks) when it was requested. }
    Sent: UInt64;
  end;

  { The component test (see the unit description). }
  TSteamComponentTest = class(TComponent)
  private
    { The root the components are linked to. }
    SteamAPI1: TCustomSteamAPI;
    { The tested components, created and owned by the test. }
    SteamUtils1: TSteamUtils;
    { See SteamUtils1. }
    SteamUser1: TSteamUser;
    { See SteamUtils1. }
    SteamApps1: TSteamApps;
    { See SteamUtils1. }
    SteamRemoteStorage1: TSteamRemoteStorage;
    { See SteamUtils1. }
    SteamScreenshots1: TSteamScreenshots;
    { See SteamUtils1. }
    SteamTimeline1: TSteamTimeline;
    { See SteamUtils1. }
    SteamUGC1: TSteamUGC;
    { See SteamUtils1. }
    SteamMatchmaking1: TSteamMatchmaking;
    { See SteamUtils1. }
    SteamParties1: TSteamParties;
    { See SteamUtils1. }
    SteamMusic1: TSteamMusic;
    { See SteamUtils1. }
    SteamHTTP1: TSteamHTTP;
    { See SteamUtils1. }
    SteamHTMLSurface1: TSteamHTMLSurface;
    { See SteamUtils1. }
    SteamInventory1: TSteamInventory;
    { See SteamUtils1. }
    SteamVideo1: TSteamVideo;
    { See SteamUtils1. }
    SteamParentalSettings1: TSteamParentalSettings;
    { See SteamUtils1. }
    SteamRemotePlay1: TSteamRemotePlay;
    { See SteamUtils1. }
    SteamNetworking1: TSteamNetworking;
    { See SteamUtils1. }
    SteamNetworkingSockets1: TSteamNetworkingSockets;
    { See SteamUtils1. }
    SteamNetworkingMessages1: TSteamNetworkingMessages;
    { See SteamUtils1. }
    SteamNetworkingUtils1: TSteamNetworkingUtils;
    { See SteamUtils1. }
    SteamMatchmakingServers1: TSteamMatchmakingServers;
    { The game server's components (attach when the server starts). }
    SteamGameServer1: TSteamGameServer;
    { See SteamGameServer1. }
    SteamGameServerStats1: TSteamGameServerStats;
    { See SteamGameServer1. }
    SteamGSUtils1: TSteamGameServerUtils;
    { See SteamGameServer1. }
    SteamGSNetworking1: TSteamGameServerNetworking;
    { See SteamGameServer1. }
    SteamGSSockets1: TSteamGameServerNetworkingSockets;
    { See SteamGameServer1. }
    SteamGSMessages1: TSteamGameServerNetworkingMessages;
    { See SteamGameServer1. }
    SteamGSHTTP1: TSteamGameServerHTTP;
    { See SteamGameServer1. }
    SteamGSUGC1: TSteamGameServerUGC;
    { See SteamGameServer1. }
    SteamGSInventory1: TSteamGameServerInventory;
    { Backing field of @link(OnLog). }
    FOnLog: TComponentTestLogEvent;
    { Backing field of @link(OnRowChanged). }
    FOnRowChanged: TComponentTestRowEvent;
    { Backing field of @link(OnScreenshotRequested). }
    FOnScreenshotRequested: TNotifyEvent;
    { Backing field of @link(OnFinished). }
    FOnFinished: TNotifyEvent;
    { The app id (SteamAPI1.AppID when the test starts). }
    FAppID: Cardinal;
    { State per component, indexed by the CT_ constants. }
    FTests: array[0..CT_COUNT - 1] of TComponentTestState;
    { Row texts, indexed by the CT_ constants. }
    FRows: array[0..CT_COUNT - 1] of string;
    { Requests awaiting an answer. }
    FPending: array of TComponentTestPending;
    { @true from Start until every answer arrived or timed out. }
    FTestsRunning: Boolean;
    { TestTicks when the running test started. }
    FStartTicks: UInt64;
    { Auth ticket the User test asked for (0 = none). }
    FAuthTicket: HAuthTicket;
    { Workshop query the UGC test sent (k_UGCQueryHandleInvalid = none). }
    FUGCQuery: UGCQueryHandle_t;
    { Bytes the RemoteStorage test wrote, compared with what is read back. }
    FCloudData: TBytes;
    { Game phase id the Timeline test used (unique per run). }
    FPhaseID: string;
    { HTTP request the HTTP test sent (0 = none). }
    FHTTPRequest: HTTPRequestHandle;
    { @true while ISteamHTMLSurface is initialised by the HTMLSurface test. }
    FHTMLInit: Boolean;
    { Inventory result of the Inventory test (k_SteamInventoryResultInvalid = none). }
    FInvResult: SteamInventoryResult_t;
    { Results of the extended Inventory steps (@link(InvStepNames));
      destroyed when ready or when the test ends
      (k_SteamInventoryResultInvalid = none). }
    FInvSteps: array[INV_GENERATE..INV_DROP] of SteamInventoryResult_t;
    { Workshop item the extended UGC test created (0 = none); deleted by the
      test, or by the cleanup when the test ends first. }
    FUGCItem: PublishedFileId_t;
    { Content folder the extended UGC test uploaded ('' = none). }
    FUGCFolder: string;
    { The NetworkingSockets test's socket pair (k_HSteamNetConnection_Invalid = none). }
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
    { @true when this test started the game server (it logs it on and sets
      its name / map; a server it found running only gets the test's rule). }
    FServerStartedByTest: Boolean;
    { @true while this test counts in @link(DemoGameServerUsers). }
    FUsingServer: Boolean;
    { Query port of the game server being tested. }
    FGSQueryPort: UInt16;
    { The test's queries of its own server (HSERVERQUERY_INVALID = none). }
    FGSPingQuery, FGSPlayersQuery, FGSRulesQuery: HServerQuery;
    { Rules the own-server query reported. }
    FGSRuleCount: Integer;
    { @true when @link(TEST_GS_RULE) was among them. }
    FGSRuleSeen: Boolean;
    { The user's ticket for the game server (k_HAuthTicketInvalid = none). }
    FGSTicket: HAuthTicket;
    { The ticket bytes (FGSTicketSize used). }
    FGSTicketData: TBytes;
    { See FGSTicketData. }
    FGSTicketSize: UInt32;
    { The server began an auth session for the user (EndAuthSession due). }
    FGSAuthBegun: Boolean;
    { The server HTTP test's request (0 = none). }
    FGSHTTPRequest: HTTPRequestHandle;
    { The server UGC test's query (k_UGCQueryHandleInvalid = none). }
    FGSUGCQuery: UGCQueryHandle_t;
    { Read accessor of @link(RowText). }
    function GetRowText(AIndex: Integer): string;
    { Read accessor of @link(Screenshots). }
    function GetScreenshots: TSteamScreenshotsPlugin;
    { Sends a line to @link(OnLog). }
    procedure AddLog(const S: string);
    { Index of AKey in FPending, -1 when not there. }
    function PendingIndex(const AKey: string): Integer;
    { Removes FPending[AIndex]. }
    procedure PendingDelete(AIndex: Integer);
    { Adds the request in FPending[AIndex] to its component's Missing list. }
    procedure PendingToMissing(AIndex: Integer);
    { Shows FTests[AIndex] in its row (OnRowChanged). }
    procedure UpdateTestRow(AIndex: Integer);
    { Starts the test of one component. @returns(@false when its plug-in is not active.) }
    function BeginTest(AIndex: Integer; AComponent: TSteamPluginComponent; APlugin: TObject): Boolean;
    { Records a failed synchronous call of component AIndex. }
    procedure ReadFailed(AIndex: Integer; const AWhat: string; E: Exception);
    { Appends AText to the note of test row AIndex. }
    procedure AddNote(AIndex: Integer; const AText: string);
    { Extended Inventory test, started when GetAllItems answered OK:
      GenerateItems (a Test Gem), AddPromoItem (the Test Token) and
      TriggerItemDrop; ConsumeItem follows when the generated Gem arrives. }
    procedure TestInventoryExtended;
    { Books one extended Inventory step that was just sent; AOK is what the
      call returned. }
    procedure InventoryStepSent(AStep: Integer; AOK: Boolean);
    { Logs the items of an extended step's result and returns them as a
      short text; AGem receives the instance of the first Test Gem in it
      (k_SteamItemInstanceIDInvalid = none). }
    function InventoryItemsText(AHandle: SteamInventoryResult_t; out AGem: SteamItemInstanceID_t): string;
    { Extended Workshop test, started when GetWorkshopEULAStatus answered
      OK: CreateItem; the item is uploaded (title, private, content folder)
      when it exists and deleted after the upload. }
    procedure TestUGCExtended;
    { Sends DeleteItem for @code(FUGCItem) (no-op without an item). }
    procedure DeleteUGCItem;
    { Removes @code(FUGCFolder) and its file (no-op without one). }
    procedure RemoveUGCFolder;
    { Registers an awaited callback (not a call result). }
    procedure Expect(AIndex: Integer; const AName: string);
    { Registers an awaited call result; an invalid handle is recorded as missing at once. }
    procedure ExpectCall(AIndex: Integer; const AName: string; ACall: SteamAPICall_t);
    { Marks an awaited answer as arrived. @returns(@false when the test was not waiting for it.) }
    function Answered(AIndex: Integer; const AName: string): Boolean;
    { Ends the test once nothing is pending. }
    procedure CheckTestsDone;
    { Closes whatever is left of the socket pair (both sides). }
    procedure CloseSocketPair(const AWhy: string);
    { Releases the MatchmakingServers test's lists and stops its queries. }
    procedure StopServerRequests(const AWhy: string);
    { Adds S to the MatchmakingServers row. }
    procedure AddServerNote(const S: string);
    { A query of the Internet server answered: forgets its handle (Steam
      reuses query numbers) and adds ANote to the row. }
    procedure ForgetQuery(var AQuery: HServerQuery; const ANote: string);
    { Registers a started server-browser request (AOk) or records it as refused. }
    procedure ServerRequestStarted(const AName, AWhat: string; AOk: Boolean);
    { The Internet list has answered enough: releases it and queries its first server. }
    procedure EndInternetList(const AHow: string);
    { TSteamUtils: reads + CheckFileSignature. }
    procedure TestUtils;
    { TSteamUser: reads + GetAuthSessionTicket + GetDurationControl. }
    procedure TestUser;
    { TSteamApps: reads + GetFileDetails. }
    procedure TestApps;
    { TSteamRemoteStorage: reads + FileWriteAsync (then FileReadAsync). }
    procedure TestRemoteStorage;
    { TSteamScreenshots: HookScreenshots on / off (no picture). }
    procedure TestScreenshots;
    { TSteamTimeline: game mode, tooltip, game phase, event + two recording queries. }
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
    { Starts the listen server (unless one runs) and every game-server row. }
    procedure TestGameServers;
    { TSteamGameServer: LogOnAnonymous; then rules / ping / players of the
      own server and an auth session (see @link(GSLoggedOn)). }
    procedure TestGameServer;
    { TSteamGameServerStats: RequestUserStats once the server is logged on. }
    procedure TestGSStats;
    { The server's TSteamGameServerUtils: reads. }
    procedure TestGSUtils;
    { The server's TSteamGameServerNetworking: reads. }
    procedure TestGSNetworking;
    { The server's TSteamGameServerNetworkingSockets: GetIdentity after log-on. }
    procedure TestGSSockets;
    { The server's TSteamGameServerNetworkingMessages: reads. }
    procedure TestGSMessages;
    { The server's TSteamGameServerHTTP: one GET. }
    procedure TestGSHTTP;
    { The server's TSteamGameServerUGC: a Workshop query after log-on. }
    procedure TestGSUGC;
    { The server's TSteamGameServerInventory: LoadItemDefinitions. }
    procedure TestGSInventory;
    { The server is logged on: server-browser data, the own-server queries,
      the auth ticket and the rows that waited for the log-on. }
    procedure GSLoggedOn;
    { The log-on failed: the rows waiting for it are answered with that. }
    procedure GSLogOnFailed(const AWhy: string);
    { Stops the own-server queries, the auth session and the server's
      requests; stops the server if the test started it. }
    procedure GameServerCleanup;
    { TSteamVideo: IsBroadcasting + GetOPFSettings. }
    procedure TestVideo;
    { TSteamParentalSettings: lock and block state (reads only). }
    procedure TestParentalSettings;
    { TSteamRemotePlay: session count (reads only). }
    procedure TestRemotePlay;
    { TSteamNetworking: IsP2PPacketAvailable (reads only). }
    procedure TestNetworking;
    { TSteamNetworkingSockets: GetIdentity, a socket pair, one message, closed. }
    procedure TestNetworkingSockets;
    { TSteamNetworkingMessages: channel 0 polled (reads only). }
    procedure TestNetworkingMessages;
    { TSteamNetworkingUtils: local timestamp, relay network status. }
    procedure TestNetworkingUtils;
    { See TestUtils. }
    procedure TestMatchmakingServers;
    { Event handlers of the components (wired in the constructor). }
    procedure UtilsCheckFileSignature(Sender: TObject; const AData: CheckFileSignature_t);
    { See UtilsCheckFileSignature. }
    procedure UtilsIPCountry(Sender: TObject; const AData: IPCountry_t);
    { See UtilsCheckFileSignature. }
    procedure UtilsLowBattery(Sender: TObject; const AData: LowBatteryPower_t);
    { See UtilsCheckFileSignature. }
    procedure UserAuthTicketResponse(Sender: TObject; const AData: GetAuthSessionTicketResponse_t);
    { See UtilsCheckFileSignature. }
    procedure UserDurationControl(Sender: TObject; const AData: DurationControl_t);
    { See UtilsCheckFileSignature. }
    procedure UserServersConnected(Sender: TObject; const AData: SteamServersConnected_t);
    { See UtilsCheckFileSignature. }
    procedure UserServersDisconnected(Sender: TObject; const AData: SteamServersDisconnected_t);
    { See UtilsCheckFileSignature. }
    procedure UserServerConnectFailure(Sender: TObject; const AData: SteamServerConnectFailure_t);
    { See UtilsCheckFileSignature. }
    procedure AppsFileDetails(Sender: TObject; const AData: FileDetailsResult_t);
    { See UtilsCheckFileSignature. }
    procedure AppsDlcInstalled(Sender: TObject; const AData: DlcInstalled_t);
    { See UtilsCheckFileSignature. }
    procedure AppsNewUrlLaunchParameters(Sender: TObject; const AData: NewUrlLaunchParameters_t);
    { See UtilsCheckFileSignature. }
    procedure AppsTimedTrialStatus(Sender: TObject; const AData: TimedTrialStatus_t);
    { See UtilsCheckFileSignature. }
    procedure StorageWriteComplete(Sender: TObject; const AData: RemoteStorageFileWriteAsyncComplete_t);
    { See UtilsCheckFileSignature. }
    procedure StorageReadComplete(Sender: TObject; const AData: RemoteStorageFileReadAsyncComplete_t);
    { See UtilsCheckFileSignature. }
    procedure StorageLocalFileChange(Sender: TObject; const AData: RemoteStorageLocalFileChange_t);
    { Passes the request on to @link(OnScreenshotRequested). }
    procedure ScreenshotRequested(Sender: TObject; const AData: ScreenshotRequested_t);
    { Tags a written screenshot with a location. }
    procedure ScreenshotReady(Sender: TObject; const AData: ScreenshotReady_t);
    { See UtilsCheckFileSignature. }
    procedure TimelineEventRecordingExists(Sender: TObject; const AData: SteamTimelineEventRecordingExists_t);
    { See UtilsCheckFileSignature. }
    procedure TimelinePhaseRecordingExists(Sender: TObject; const AData: SteamTimelineGamePhaseRecordingExists_t);
    { See UtilsCheckFileSignature. }
    procedure UGCQueryCompleted(Sender: TObject; const AData: SteamUGCQueryCompleted_t);
    { See UtilsCheckFileSignature. }
    procedure UGCWorkshopEULAStatus(Sender: TObject; const AData: WorkshopEULAStatus_t);
    { SteamUGC1.OnCreateItemResult (call result 3403): the extended UGC
      test uploads the new item. }
    procedure UGCCreateItemResult(Sender: TObject; const AData: CreateItemResult_t);
    { SteamUGC1.OnSubmitItemUpdateResult (call result 3404): the extended
      UGC test deletes the item again. }
    procedure UGCSubmitItemUpdateResult(Sender: TObject; const AData: SubmitItemUpdateResult_t);
    { SteamUGC1.OnDeleteItemResult (call result 3417): end of the extended
      UGC test. }
    procedure UGCDeleteItemResult(Sender: TObject; const AData: DeleteItemResult_t);
    { See UtilsCheckFileSignature. }
    procedure UGCSubscribedListChanged(Sender: TObject; const AData: UserSubscribedItemsListChanged_t);
    { See UtilsCheckFileSignature. }
    procedure UGCItemInstalled(Sender: TObject; const AData: ItemInstalled_t);
    { See UtilsCheckFileSignature. }
    procedure MatchmakingLobbyMatchList(Sender: TObject; const AData: LobbyMatchList_t);
    { See UtilsCheckFileSignature. }
    procedure HTTPRequestCompleted(Sender: TObject; const AData: HTTPRequestCompleted_t);
    { See UtilsCheckFileSignature. }
    procedure HTMLBrowserReady(Sender: TObject; const AData: HTML_BrowserReady_t);
    { See UtilsCheckFileSignature. }
    procedure InventoryResultReady(Sender: TObject; const AData: SteamInventoryResultReady_t);
    { SteamGameServer1.OnSteamServersConnected (101, server pipe). }
    procedure GSServersConnected(Sender: TObject; const AData: SteamServersConnected_t);
    { SteamGameServer1.OnSteamServerConnectFailure (102, server pipe). }
    procedure GSConnectFailure(Sender: TObject; const AData: SteamServerConnectFailure_t);
    { SteamGameServer1.OnSteamServersDisconnected (103, server pipe). }
    procedure GSDisconnected(Sender: TObject; const AData: SteamServersDisconnected_t);
    { SteamGameServer1.OnGSPolicyResponse (115): VAC status. }
    procedure GSPolicy(Sender: TObject; const AData: GSPolicyResponse_t);
    { SteamGameServer1.OnValidateAuthTicketResponse (143, server pipe). }
    procedure GSAuthValidated(Sender: TObject; const AData: ValidateAuthTicketResponse_t);
    { SteamGameServerStats1.OnGSStatsReceived (1800). }
    procedure GSStatsReceived(Sender: TObject; const AData: GSStatsReceived_t);
    { SteamGSHTTP1.OnHTTPRequestCompleted (2101, server pipe). }
    procedure GSHTTPCompleted(Sender: TObject; const AData: HTTPRequestCompleted_t);
    { SteamGSUGC1.OnSteamUGCQueryCompleted (3401, server pipe). }
    procedure GSUGCQueryCompleted(Sender: TObject; const AData: SteamUGCQueryCompleted_t);
    { See UtilsCheckFileSignature. }
    procedure VideoOPFSettingsResult(Sender: TObject; const AData: GetOPFSettingsResult_t);
    { See UtilsCheckFileSignature. }
    procedure NetConnectionStatusChanged(Sender: TObject; const AData: SteamNetConnectionStatusChangedCallback_t);
    { See UtilsCheckFileSignature. }
    procedure RelayNetworkStatus(Sender: TObject; const AData: SteamRelayNetworkStatus_t);
    { See UtilsCheckFileSignature. }
    procedure ServersResponded(Sender: TObject; ARequest: HServerListRequest; AIndex: Integer;
      const AServer: gameserveritem_t);
    { See UtilsCheckFileSignature. }
    procedure ServersFailed(Sender: TObject; ARequest: HServerListRequest; AIndex: Integer);
    { See UtilsCheckFileSignature. }
    procedure ServerListComplete(Sender: TObject; ARequest: HServerListRequest;
      AResponse: EMatchMakingServerResponse);
    { See UtilsCheckFileSignature. }
    procedure PingResponded(Sender: TObject; AQuery: HServerQuery; const AServer: gameserveritem_t);
    { See UtilsCheckFileSignature. }
    procedure PingFailed(Sender: TObject; AQuery: HServerQuery);
    { See UtilsCheckFileSignature. }
    procedure ServerPlayer(Sender: TObject; AQuery: HServerQuery; const AName: string;
      AScore: Integer; ATimePlayed: Single);
    { See UtilsCheckFileSignature. }
    procedure PlayersFailed(Sender: TObject; AQuery: HServerQuery);
    { See UtilsCheckFileSignature. }
    procedure PlayersComplete(Sender: TObject; AQuery: HServerQuery);
    { See UtilsCheckFileSignature. }
    procedure ServerRule(Sender: TObject; AQuery: HServerQuery; const ARule, AValue: string);
    { See UtilsCheckFileSignature. }
    procedure RulesFailed(Sender: TObject; AQuery: HServerQuery);
    { See UtilsCheckFileSignature. }
    procedure RulesComplete(Sender: TObject; AQuery: HServerQuery);
  public
    { Creates the 30 components (21 client + 9 game-server ones), owned by the test and linked to ASteamAPI. }
    constructor Create(AOwner: TComponent; ASteamAPI: TCustomSteamAPI); reintroduce;
    { Runs the test (Steam must be running); a running test is finished first. }
    procedure Start;
    { Call about once a second: reports overdue answers, ends the test. }
    procedure Tick;
    { Ends the test now: cleans up (only while Steam runs), logs a verdict
      per component. AReason is logged when not ''. Call it before Steam is
      closed. }
    procedure Finish(const AReason: string);
    { @true while the test waits for answers. }
    property Running: Boolean read FTestsRunning;
    { Text of row AIndex (a CT_ constant): 'not run ...', or the verdict. }
    property RowText[AIndex: Integer]: string read GetRowText;
    { The Screenshots plug-in (@nil while Steam is not running), for a
      form's own screenshot. }
    property Screenshots: TSteamScreenshotsPlugin read GetScreenshots;
    { Every log line of the test. }
    property OnLog: TComponentTestLogEvent read FOnLog write FOnLog;
    { A row changed. }
    property OnRowChanged: TComponentTestRowEvent read FOnRowChanged write FOnRowChanged;
    { Steam asks for a screenshot (only while screenshots are hooked): the
      form writes one (it knows how to capture itself). }
    property OnScreenshotRequested: TNotifyEvent read FOnScreenshotRequested write FOnScreenshotRequested;
    { The test ended (every answer arrived, timed out, or Finish). }
    property OnFinished: TNotifyEvent read FOnFinished write FOnFinished;
  end;

var
  { How many of the demos' tests use the process's one game server now
    (the component test and the pair test may share it): the LAST one to
    finish logs it off and stops it. }
  DemoGameServerUsers: Integer = 0;

{ The OS's usual per-user folder for a demo's settings: Windows
  %APPDATA%\G3DGames\<AApp>, macOS ~/Library/Application Support/G3DGames/<AApp>,
  Linux $XDG_CONFIG_HOME/G3DGames/<AApp> (default ~/.config/...). Never next
  to the executable: that folder is read-only for a game installed by Steam.
  The folder may not exist yet. '' when the base folder is unknown. }
function DemoSettingsFolder(const AApp: string): string;

{ The time-stamp source of the test, in milliseconds. }
function TestTicks: UInt64;

{ The name of a TSteamUpdateMode value. }
function UpdateModeText(AMode: TSteamUpdateMode): string;

implementation

{ --- helpers --- }

function TestTicks: UInt64;
begin
{$ifdef FPC}
  Result := GetTickCount64;
{$else}
  Result := TThread.GetTickCount64;
{$endif}
end;

function DemoSettingsFolder(const AApp: string): string;
var
  Base: string;
begin
{$if defined(MSWINDOWS)}
  Base := GetEnvironmentVariable('APPDATA');
{$elseif defined(DARWIN) or defined(MACOS)}
  Base := GetEnvironmentVariable('HOME');
  if Base <> '' then
    Base := IncludeTrailingPathDelimiter(Base) + 'Library/Application Support';
{$else}
  Base := GetEnvironmentVariable('XDG_CONFIG_HOME');
  if Base = '' then
  begin
    Base := GetEnvironmentVariable('HOME');
    if Base <> '' then
      Base := IncludeTrailingPathDelimiter(Base) + '.config';
  end;
{$endif}
  if Base = '' then
    Exit('');
  Result := IncludeTrailingPathDelimiter(IncludeTrailingPathDelimiter(Base) + 'G3DGames') + AApp;
end;

function UpdateModeText(AMode: TSteamUpdateMode): string;
begin
  case AMode of
    sumTimer:  Result := 'sumTimer';
    sumThread: Result := 'sumThread';
  else
    Result := 'sumManual';
  end;
end;

{ A NUL-terminated UTF-8 buffer from Steam as a string. }
function SteamText(P: PAnsiChar): string;
begin
  Result := string(UTF8String(P));
end;

{ An unsigned 64-bit number as text (both compilers). }
function U64Str(AValue: UInt64): string;
begin
{$ifdef FPC}
  Result := IntToStr(AValue);
{$else}
  Result := UIntToStr(AValue);
{$endif}
end;

{ Unix seconds (UTC) as a TDateTime, still UTC. }
function UnixUTC(ASeconds: Int64): TDateTime;
begin
  Result := UnixDateDelta + ASeconds / SecsPerDay;
end;

{ The UTF-8 bytes of a string (no terminating NUL). }
function Utf8Bytes(const S: string): TBytes;
var
  U: UTF8String;
begin
  U := UTF8String(S);
  SetLength(Result, Length(U));
  if Length(U) > 0 then
    Move(U[1], Result[0], Length(U));
end;

{ The first ACount bytes of B as UTF-8 text. }
function Utf8Text(const B: TBytes; ACount: Integer): string;
var
  U: UTF8String;
begin
  if ACount > Length(B) then
    ACount := Length(B);
  if ACount <= 0 then
    Exit('');
  SetLength(U, ACount);
  Move(B[0], U[1], ACount);
  Result := string(U);
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

{ --- TSteamComponentTest: lifecycle and bookkeeping --- }

constructor TSteamComponentTest.Create(AOwner: TComponent; ASteamAPI: TCustomSteamAPI);
var
  I: Integer;
begin
  inherited Create(AOwner);
  SteamAPI1 := ASteamAPI;
  FUGCQuery := k_UGCQueryHandleInvalid;
  FInvResult := k_SteamInventoryResultInvalid;
  for I := INV_GENERATE to INV_DROP do
    FInvSteps[I] := k_SteamInventoryResultInvalid;
  FSockConn1 := k_HSteamNetConnection_Invalid;
  FSockConn2 := k_HSteamNetConnection_Invalid;
  FPingQuery := HSERVERQUERY_INVALID;
  FPlayersQuery := HSERVERQUERY_INVALID;
  FRulesQuery := HSERVERQUERY_INVALID;
  FGSPingQuery := HSERVERQUERY_INVALID;
  FGSPlayersQuery := HSERVERQUERY_INVALID;
  FGSRulesQuery := HSERVERQUERY_INVALID;
  FGSTicket := k_HAuthTicketInvalid;
  FGSUGCQuery := k_UGCQueryHandleInvalid;
  for I := 0 to CT_COUNT - 1 do
    FRows[I] := 'not run - press Test components (Steam must be started)';
  // Each: create, wire the events, link (SteamAPI last: it attaches the
  // component when Steam already runs)
  SteamUtils1 := TSteamUtils.Create(Self);
  SteamUtils1.Name := 'SteamUtils1';
  SteamUtils1.OnCheckFileSignature := UtilsCheckFileSignature;
  SteamUtils1.OnIPCountry := UtilsIPCountry;
  SteamUtils1.OnLowBatteryPower := UtilsLowBattery;
  SteamUtils1.SteamAPI := ASteamAPI;
  SteamUser1 := TSteamUser.Create(Self);
  SteamUser1.Name := 'SteamUser1';
  SteamUser1.OnGetAuthSessionTicketResponse := UserAuthTicketResponse;
  SteamUser1.OnDurationControl := UserDurationControl;
  SteamUser1.OnSteamServersConnected := UserServersConnected;
  SteamUser1.OnSteamServersDisconnected := UserServersDisconnected;
  SteamUser1.OnSteamServerConnectFailure := UserServerConnectFailure;
  SteamUser1.SteamAPI := ASteamAPI;
  SteamApps1 := TSteamApps.Create(Self);
  SteamApps1.Name := 'SteamApps1';
  SteamApps1.OnFileDetailsResult := AppsFileDetails;
  SteamApps1.OnDlcInstalled := AppsDlcInstalled;
  SteamApps1.OnNewUrlLaunchParameters := AppsNewUrlLaunchParameters;
  SteamApps1.OnTimedTrialStatus := AppsTimedTrialStatus;
  SteamApps1.SteamAPI := ASteamAPI;
  SteamRemoteStorage1 := TSteamRemoteStorage.Create(Self);
  SteamRemoteStorage1.Name := 'SteamRemoteStorage1';
  SteamRemoteStorage1.OnRemoteStorageFileWriteAsyncComplete := StorageWriteComplete;
  SteamRemoteStorage1.OnRemoteStorageFileReadAsyncComplete := StorageReadComplete;
  SteamRemoteStorage1.OnRemoteStorageLocalFileChange := StorageLocalFileChange;
  SteamRemoteStorage1.SteamAPI := ASteamAPI;
  SteamScreenshots1 := TSteamScreenshots.Create(Self);
  SteamScreenshots1.Name := 'SteamScreenshots1';
  SteamScreenshots1.OnScreenshotRequested := ScreenshotRequested;
  SteamScreenshots1.OnScreenshotReady := ScreenshotReady;
  SteamScreenshots1.SteamAPI := ASteamAPI;
  SteamTimeline1 := TSteamTimeline.Create(Self);
  SteamTimeline1.Name := 'SteamTimeline1';
  SteamTimeline1.OnSteamTimelineEventRecordingExists := TimelineEventRecordingExists;
  SteamTimeline1.OnSteamTimelineGamePhaseRecordingExists := TimelinePhaseRecordingExists;
  SteamTimeline1.SteamAPI := ASteamAPI;
  SteamUGC1 := TSteamUGC.Create(Self);
  SteamUGC1.Name := 'SteamUGC1';
  SteamUGC1.OnSteamUGCQueryCompleted := UGCQueryCompleted;
  SteamUGC1.OnWorkshopEULAStatus := UGCWorkshopEULAStatus;
  SteamUGC1.OnCreateItemResult := UGCCreateItemResult;
  SteamUGC1.OnSubmitItemUpdateResult := UGCSubmitItemUpdateResult;
  SteamUGC1.OnDeleteItemResult := UGCDeleteItemResult;
  SteamUGC1.OnUserSubscribedItemsListChanged := UGCSubscribedListChanged;
  SteamUGC1.OnItemInstalled := UGCItemInstalled;
  SteamUGC1.SteamAPI := ASteamAPI;
  SteamMatchmaking1 := TSteamMatchmaking.Create(Self);
  SteamMatchmaking1.Name := 'SteamMatchmaking1';
  SteamMatchmaking1.OnLobbyMatchList := MatchmakingLobbyMatchList;
  SteamMatchmaking1.SteamAPI := ASteamAPI;
  SteamParties1 := TSteamParties.Create(Self);
  SteamParties1.Name := 'SteamParties1';
  SteamParties1.SteamAPI := ASteamAPI;
  SteamMusic1 := TSteamMusic.Create(Self);
  SteamMusic1.Name := 'SteamMusic1';
  SteamMusic1.SteamAPI := ASteamAPI;
  SteamHTTP1 := TSteamHTTP.Create(Self);
  SteamHTTP1.Name := 'SteamHTTP1';
  SteamHTTP1.OnHTTPRequestCompleted := HTTPRequestCompleted;
  SteamHTTP1.SteamAPI := ASteamAPI;
  SteamHTMLSurface1 := TSteamHTMLSurface.Create(Self);
  SteamHTMLSurface1.Name := 'SteamHTMLSurface1';
  SteamHTMLSurface1.OnHTML_BrowserReady := HTMLBrowserReady;
  SteamHTMLSurface1.SteamAPI := ASteamAPI;
  SteamInventory1 := TSteamInventory.Create(Self);
  SteamInventory1.Name := 'SteamInventory1';
  SteamInventory1.OnSteamInventoryResultReady := InventoryResultReady;
  SteamInventory1.SteamAPI := ASteamAPI;
  SteamVideo1 := TSteamVideo.Create(Self);
  SteamVideo1.Name := 'SteamVideo1';
  SteamVideo1.OnGetOPFSettingsResult := VideoOPFSettingsResult;
  SteamVideo1.SteamAPI := ASteamAPI;
  SteamParentalSettings1 := TSteamParentalSettings.Create(Self);
  SteamParentalSettings1.Name := 'SteamParentalSettings1';
  SteamParentalSettings1.SteamAPI := ASteamAPI;
  SteamRemotePlay1 := TSteamRemotePlay.Create(Self);
  SteamRemotePlay1.Name := 'SteamRemotePlay1';
  SteamRemotePlay1.SteamAPI := ASteamAPI;
  SteamNetworking1 := TSteamNetworking.Create(Self);
  SteamNetworking1.Name := 'SteamNetworking1';
  SteamNetworking1.SteamAPI := ASteamAPI;
  SteamNetworkingSockets1 := TSteamNetworkingSockets.Create(Self);
  SteamNetworkingSockets1.Name := 'SteamNetworkingSockets1';
  SteamNetworkingSockets1.OnSteamNetConnectionStatusChangedCallback := NetConnectionStatusChanged;
  SteamNetworkingSockets1.SteamAPI := ASteamAPI;
  SteamNetworkingMessages1 := TSteamNetworkingMessages.Create(Self);
  SteamNetworkingMessages1.Name := 'SteamNetworkingMessages1';
  SteamNetworkingMessages1.SteamAPI := ASteamAPI;
  SteamNetworkingUtils1 := TSteamNetworkingUtils.Create(Self);
  SteamNetworkingUtils1.Name := 'SteamNetworkingUtils1';
  SteamNetworkingUtils1.OnSteamRelayNetworkStatus := RelayNetworkStatus;
  SteamNetworkingUtils1.SteamAPI := ASteamAPI;
  SteamMatchmakingServers1 := TSteamMatchmakingServers.Create(Self);
  SteamMatchmakingServers1.Name := 'SteamMatchmakingServers1';
  SteamMatchmakingServers1.OnServerResponded := ServersResponded;
  SteamMatchmakingServers1.OnServerFailedToRespond := ServersFailed;
  SteamMatchmakingServers1.OnServerListComplete := ServerListComplete;
  SteamMatchmakingServers1.OnPingResponded := PingResponded;
  SteamMatchmakingServers1.OnPingFailed := PingFailed;
  SteamMatchmakingServers1.OnPlayer := ServerPlayer;
  SteamMatchmakingServers1.OnPlayersFailed := PlayersFailed;
  SteamMatchmakingServers1.OnPlayersComplete := PlayersComplete;
  SteamMatchmakingServers1.OnRule := ServerRule;
  SteamMatchmakingServers1.OnRulesFailed := RulesFailed;
  SteamMatchmakingServers1.OnRulesComplete := RulesComplete;
  SteamMatchmakingServers1.SteamAPI := ASteamAPI;
  // The game server's components: they attach when a game server starts
  SteamGameServer1 := TSteamGameServer.Create(Self);
  SteamGameServer1.Name := 'SteamGameServer1';
  SteamGameServer1.OnSteamServersConnected := GSServersConnected;
  SteamGameServer1.OnSteamServerConnectFailure := GSConnectFailure;
  SteamGameServer1.OnSteamServersDisconnected := GSDisconnected;
  SteamGameServer1.OnGSPolicyResponse := GSPolicy;
  SteamGameServer1.OnValidateAuthTicketResponse := GSAuthValidated;
  SteamGameServer1.SteamAPI := ASteamAPI;
  SteamGameServerStats1 := TSteamGameServerStats.Create(Self);
  SteamGameServerStats1.Name := 'SteamGameServerStats1';
  SteamGameServerStats1.OnGSStatsReceived := GSStatsReceived;
  SteamGameServerStats1.SteamAPI := ASteamAPI;
  SteamGSUtils1 := TSteamGameServerUtils.Create(Self);
  SteamGSUtils1.Name := 'SteamGSUtils1';
  SteamGSUtils1.SteamAPI := ASteamAPI;
  SteamGSNetworking1 := TSteamGameServerNetworking.Create(Self);
  SteamGSNetworking1.Name := 'SteamGSNetworking1';
  SteamGSNetworking1.SteamAPI := ASteamAPI;
  SteamGSSockets1 := TSteamGameServerNetworkingSockets.Create(Self);
  SteamGSSockets1.Name := 'SteamGSSockets1';
  SteamGSSockets1.SteamAPI := ASteamAPI;
  SteamGSMessages1 := TSteamGameServerNetworkingMessages.Create(Self);
  SteamGSMessages1.Name := 'SteamGSMessages1';
  SteamGSMessages1.SteamAPI := ASteamAPI;
  SteamGSHTTP1 := TSteamGameServerHTTP.Create(Self);
  SteamGSHTTP1.Name := 'SteamGSHTTP1';
  SteamGSHTTP1.OnHTTPRequestCompleted := GSHTTPCompleted;
  SteamGSHTTP1.SteamAPI := ASteamAPI;
  SteamGSUGC1 := TSteamGameServerUGC.Create(Self);
  SteamGSUGC1.Name := 'SteamGSUGC1';
  SteamGSUGC1.OnSteamUGCQueryCompleted := GSUGCQueryCompleted;
  SteamGSUGC1.SteamAPI := ASteamAPI;
  SteamGSInventory1 := TSteamGameServerInventory.Create(Self);
  SteamGSInventory1.Name := 'SteamGSInventory1';
  SteamGSInventory1.SteamAPI := ASteamAPI;
end;

function TSteamComponentTest.GetRowText(AIndex: Integer): string;
begin
  if (AIndex >= 0) and (AIndex < CT_COUNT) then
    Result := FRows[AIndex]
  else
    Result := '';
end;

function TSteamComponentTest.GetScreenshots: TSteamScreenshotsPlugin;
begin
  Result := SteamScreenshots1.Plugin;
end;

procedure TSteamComponentTest.AddLog(const S: string);
begin
  if Assigned(FOnLog) then
    FOnLog(S);
end;

function TSteamComponentTest.PendingIndex(const AKey: string): Integer;
var
  I: Integer;
begin
  for I := 0 to High(FPending) do
    if FPending[I].Key = AKey then
      Exit(I);
  Result := -1;
end;

procedure TSteamComponentTest.PendingDelete(AIndex: Integer);
var
  I: Integer;
begin
  for I := AIndex to High(FPending) - 1 do
    FPending[I] := FPending[I + 1];
  SetLength(FPending, Length(FPending) - 1);
end;

procedure TSteamComponentTest.PendingToMissing(AIndex: Integer);
var
  Key: string;
  I: Integer;
begin
  Key := FPending[AIndex].Key;
  I := StrToIntDef(Copy(Key, 1, Pos(':', Key) - 1), -1);
  if (I < 0) or (I >= CT_COUNT) then
    Exit;
  if FTests[I].Missing <> '' then
    FTests[I].Missing := FTests[I].Missing + ', ';
  FTests[I].Missing := FTests[I].Missing + Copy(Key, Pos(':', Key) + 1, MaxInt);
end;

procedure TSteamComponentTest.UpdateTestRow(AIndex: Integer);
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
  if S = FRows[AIndex] then
    Exit;
  FRows[AIndex] := S;
  if Assigned(FOnRowChanged) then
    FOnRowChanged(AIndex, S);
end;

procedure TSteamComponentTest.Expect(AIndex: Integer; const AName: string);
var
  Key: string;
  I: Integer;
begin
  Inc(FTests[AIndex].Sent);
  Key := IntToStr(AIndex) + ':' + AName;
  I := PendingIndex(Key);
  if I < 0 then
  begin
    I := Length(FPending);
    SetLength(FPending, I + 1);
    FPending[I].Key := Key;
  end;
  FPending[I].Sent := TestTicks;
end;

function TSteamComponentTest.Answered(AIndex: Integer; const AName: string): Boolean;
var
  I: Integer;
  Sent: UInt64;
begin
  Result := False;
  if not FTestsRunning then
    Exit;
  I := PendingIndex(IntToStr(AIndex) + ':' + AName);
  if I < 0 then
    Exit;
  Sent := FPending[I].Sent;
  PendingDelete(I);
  Inc(FTests[AIndex].Arrived);
  AddLog(Format('Test %s: %s answered after %d ms', [TestNames[AIndex], AName,
    Int64(TestTicks - Sent)]));
  Result := True;
end;

procedure TSteamComponentTest.CheckTestsDone;
var
  I: Integer;
begin
  for I := 0 to CT_COUNT - 1 do
    UpdateTestRow(I);
  if FTestsRunning and (Length(FPending) = 0) then
    Finish('');
end;

procedure TSteamComponentTest.Finish(const AReason: string);
var
  I, Passed: Integer;
begin
  if not FTestsRunning then
    Exit;
  FTestsRunning := False;
  if AReason <> '' then
    AddLog('Component test stopped: ' + AReason);
  // Whatever is still pending counts as not answered
  for I := 0 to High(FPending) do
    PendingToMissing(I);
  SetLength(FPending, 0);
  // Clean up (only possible while Steam runs)
  if SteamAPI1.IsRunning then
  begin
    try
      if (FAuthTicket <> k_HAuthTicketInvalid) and (SteamUser1.Plugin <> nil) then
      begin
        SteamUser1.Plugin.CancelAuthTicket(FAuthTicket);
        AddLog('Test cleanup: auth ticket ' + U64Str(FAuthTicket) + ' cancelled (it never answered)');
      end;
      if (FUGCQuery <> k_UGCQueryHandleInvalid) and (SteamUGC1.Plugin <> nil) then
        AddLog('Test cleanup: ReleaseQueryUGCRequest (query never completed): ' +
          BoolToStr(SteamUGC1.Plugin.ReleaseQueryUGCRequest(FUGCQuery), True));
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
      if SteamInventory1.Plugin <> nil then
        for I := INV_GENERATE to INV_DROP do
          if FInvSteps[I] <> k_SteamInventoryResultInvalid then
          begin
            SteamInventory1.Plugin.DestroyResult(FInvSteps[I]);
            AddLog(Format('Test cleanup: %s result %d destroyed (never ready)', [InvStepNames[I], FInvSteps[I]]));
          end;
      if (FUGCItem <> 0) and (SteamUGC1.Plugin <> nil) then
        AddLog(Format('Test cleanup: Workshop item %s still there, DeleteItem sent (call %s)',
          [U64Str(FUGCItem), U64Str(SteamUGC1.Plugin.DeleteItem(FUGCItem))]));
      if FHTMLInit and (SteamHTMLSurface1.Plugin <> nil) then
        AddLog('Test cleanup: ISteamHTMLSurface.Shutdown ' +
          BoolToStr(SteamHTMLSurface1.Plugin.Shutdown, True));
      CloseSocketPair('Test cleanup');
      StopServerRequests('Test cleanup');
      GameServerCleanup;
    except
      on E: Exception do AddLog('Test cleanup failed: ' + E.Message);
    end;
  end;
  FAuthTicket := k_HAuthTicketInvalid;
  FUGCQuery := k_UGCQueryHandleInvalid;
  FHTTPRequest := 0;
  FHTMLInit := False;
  FInvResult := k_SteamInventoryResultInvalid;
  for I := INV_GENERATE to INV_DROP do
    FInvSteps[I] := k_SteamInventoryResultInvalid;
  FUGCItem := 0;
  RemoveUGCFolder;   // no Steam call: also when Steam has gone
  FSockConn1 := k_HSteamNetConnection_Invalid;
  FSockConn2 := k_HSteamNetConnection_Invalid;
  FServerList := nil;
  FLANList := nil;
  FPingQuery := HSERVERQUERY_INVALID;
  FPlayersQuery := HSERVERQUERY_INVALID;
  FRulesQuery := HSERVERQUERY_INVALID;
  FGSPingQuery := HSERVERQUERY_INVALID;
  FGSPlayersQuery := HSERVERQUERY_INVALID;
  FGSRulesQuery := HSERVERQUERY_INVALID;
  FGSTicket := k_HAuthTicketInvalid;
  FGSAuthBegun := False;
  FGSHTTPRequest := 0;
  FGSUGCQuery := k_UGCQueryHandleInvalid;
  FServerStartedByTest := False;
  Passed := 0;
  for I := 0 to CT_COUNT - 1 do
  begin
    UpdateTestRow(I);
    if FTests[I].Ran and FTests[I].Attached and FTests[I].ReadsOK and (FTests[I].Missing = '') and
      (FTests[I].Arrived = FTests[I].Sent) then
      Inc(Passed);
    if FTests[I].Ran then
      AddLog(Format('Test result %s: %s', [TestNames[I], FRows[I]]));
  end;
  AddLog(Format('Component test finished: %d of %d components PASS', [Passed, CT_COUNT]));
  if Assigned(FOnFinished) then
    FOnFinished(Self);
end;

procedure TSteamComponentTest.Start;
var
  I: Integer;
begin
  if not SteamAPI1.IsRunning then
  begin
    AddLog('Test components: Steam is not running - press Start first');
    Exit;
  end;
  // A second press while the test runs is ignored: restarting cut the
  // answers still on their way and failed their rows (owner's 19:24 run on
  // a slow tablet: three presses, two runs reported FAILs that were only
  // the restart)
  if FTestsRunning then
  begin
    AddLog(Format('Test components: already running (started %.1f s ago) - press ignored; ' +
      'every row has its verdict within %d s', [(TestTicks - FStartTicks) / 1000, TEST_TIMEOUT_MS div 1000]));
    Exit;
  end;
  FAppID := SteamAPI1.AppID;
  for I := 0 to CT_COUNT - 1 do
  begin
    FTests[I].Ran := False;
    FTests[I].Attached := False;
    FTests[I].ReadsOK := False;
    FTests[I].Sent := 0;
    FTests[I].Arrived := 0;
    FTests[I].Missing := '';
    FTests[I].Note := '';
    FRows[I] := 'running ...';
    if Assigned(FOnRowChanged) then
      FOnRowChanged(I, FRows[I]);
  end;
  SetLength(FPending, 0);
  FTestsRunning := True;
  FStartTicks := TestTicks;
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
  TestGameServers;
  CheckTestsDone;
end;

procedure TSteamComponentTest.Tick;
var
  I: Integer;
  NowTicks: UInt64;
  Key: string;
begin
  if not FTestsRunning then
    Exit;
  NowTicks := TestTicks;
  for I := High(FPending) downto 0 do
    // (NowTicks > Sent first: UInt64, a later Sent must not wrap to a time-out)
    if (NowTicks > FPending[I].Sent) and (NowTicks - FPending[I].Sent >= TEST_TIMEOUT_MS) then
    begin
      Key := FPending[I].Key;
      PendingToMissing(I);
      PendingDelete(I);
      AddLog(Format('Test %s: NO ANSWER to %s within %d ms',
        [TestNames[StrToIntDef(Copy(Key, 1, Pos(':', Key) - 1), 0)], Copy(Key, Pos(':', Key) + 1, MaxInt),
         TEST_TIMEOUT_MS]));
    end;
  CheckTestsDone;
end;

procedure TSteamComponentTest.ScreenshotRequested(Sender: TObject; const AData: ScreenshotRequested_t);
begin
  // Only while screenshots are hooked (the test unhooks them at once): then
  // Steam takes none itself and every request must be answered
  AddLog('TSteamScreenshots.OnScreenshotRequested');
  if Assigned(FOnScreenshotRequested) then
    FOnScreenshotRequested(Self);
end;

{ --- the tests --- }

function TSteamComponentTest.BeginTest(AIndex: Integer; AComponent: TSteamPluginComponent; APlugin: TObject): Boolean;
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

procedure TSteamComponentTest.AddNote(AIndex: Integer; const AText: string);
begin
  if FTests[AIndex].Note <> '' then
    FTests[AIndex].Note := FTests[AIndex].Note + ', ';
  FTests[AIndex].Note := FTests[AIndex].Note + AText;
end;

procedure TSteamComponentTest.ReadFailed(AIndex: Integer; const AWhat: string; E: Exception);
begin
  FTests[AIndex].ReadsOK := False;
  AddLog(Format('Test %s: %s FAILED: %s: %s', [TestNames[AIndex], AWhat, E.ClassName, E.Message]));
end;

procedure TSteamComponentTest.ExpectCall(AIndex: Integer; const AName: string; ACall: SteamAPICall_t);
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
      [TestNames[AIndex], AName, U64Str(ACall)]));
    Expect(AIndex, AName);
  end;
end;

{ --- TSteamUtils --- }

procedure TSteamComponentTest.TestUtils;
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
       FormatDateTime('yyyy-mm-dd hh:nn:ss', UnixUTC(Int64(U.GetServerRealTime))),
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

procedure TSteamComponentTest.UtilsCheckFileSignature(Sender: TObject; const AData: CheckFileSignature_t);
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

procedure TSteamComponentTest.UtilsIPCountry(Sender: TObject; const AData: IPCountry_t);
begin
  AddLog('TSteamUtils.OnIPCountry: the IP country changed (not requested by the test)');
end;

procedure TSteamComponentTest.UtilsLowBattery(Sender: TObject; const AData: LowBatteryPower_t);
begin
  AddLog(Format('TSteamUtils.OnLowBatteryPower: %d minutes left (not requested by the test)',
    [AData.m_nMinutesBatteryLeft]));
end;

{ --- TSteamUser --- }

procedure TSteamComponentTest.TestUser;
var
  U: TSteamUserPlugin;
  Folder: array[0..1023] of AnsiChar;
  Ticket: array[0..2047] of Byte;
  TicketSize: UInt32;
  FolderText: string;
  Me: TSteamID;
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
    Me := U.GetSteamID;
    AddLog(Format('Test TSteamUser: logged on %s, SteamID %s, behind NAT %s, phone verified %s, ' +
      'two-factor %s, GetUserDataFolder %s',
      [BoolToStr(U.BLoggedOn, True), Me.ToString, BoolToStr(U.BIsBehindNAT, True),
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
        [U64Str(FAuthTicket), TicketSize]));
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

procedure TSteamComponentTest.UserAuthTicketResponse(Sender: TObject; const AData: GetAuthSessionTicketResponse_t);
var
  G: TSteamGameServerPlugin;
  Res: EBeginAuthSessionResult;
  Me: TSteamID;
begin
  AddLog(Format('TSteamUser.OnGetAuthSessionTicketResponse: ticket %s, result %s',
    [U64Str(AData.m_hAuthTicket), ResultText(AData.m_eResult)]));
  // The ticket for our own game server: the server begins a session with it
  if (FGSTicket <> k_HAuthTicketInvalid) and (AData.m_hAuthTicket = FGSTicket) then
  begin
    if not Answered(CT_GAMESERVER, 'GetAuthSessionTicket (for the server)') then
      Exit;
    G := SteamGameServer1.Plugin;
    if (AData.m_eResult <> k_EResultOK) or (G = nil) or (SteamUser1.Plugin = nil) then
    begin
      AddNote(CT_GAMESERVER, 'ticket for the server ' + ResultText(AData.m_eResult));
      CheckTestsDone;
      Exit;
    end;
    try
      Me := SteamUser1.Plugin.GetSteamID;
      Res := G.BeginAuthSession(@FGSTicketData[0], Integer(FGSTicketSize), Me);
      AddLog(Format('Test TSteamGameServer: BeginAuthSession(our ticket, %d bytes, %s) -> %d (0 = OK)',
        [FGSTicketSize, U64Str(Me.Value), Ord(Res)]));
      if Res = k_EBeginAuthSessionResultOK then
      begin
        FGSAuthBegun := True;
        Expect(CT_GAMESERVER, 'ValidateAuthTicketResponse');
      end
      else
        AddNote(CT_GAMESERVER, Format('BeginAuthSession %d', [Ord(Res)]));
    except
      on E: Exception do ReadFailed(CT_GAMESERVER, 'BeginAuthSession', E);
    end;
    CheckTestsDone;
    Exit;
  end;
  if (AData.m_hAuthTicket = FAuthTicket) and (FAuthTicket <> k_HAuthTicketInvalid) and
    Answered(CT_USER, 'GetAuthSessionTicket') then
  begin
    // A real game would send the ticket to its server; the test only needs
    // the answer, so the ticket is given back at once
    if SteamUser1.Plugin <> nil then
    begin
      SteamUser1.Plugin.CancelAuthTicket(FAuthTicket);
      AddLog('Test TSteamUser: auth ticket ' + U64Str(FAuthTicket) + ' cancelled');
    end;
    FAuthTicket := k_HAuthTicketInvalid;
    FTests[CT_USER].Note := 'ticket ' + ResultText(AData.m_eResult);
    CheckTestsDone;
  end;
end;

procedure TSteamComponentTest.UserDurationControl(Sender: TObject; const AData: DurationControl_t);
begin
  AddLog(Format('TSteamUser.OnDurationControl: result %s, app %d, applicable %s, ' +
    'last 5 h %d s, today %d s, remaining %d s, progress %d, notification %d',
    [ResultText(AData.m_eResult), AData.m_appid, BoolToStr(AData.m_bApplicable, True),
     AData.m_csecsLast5h, AData.m_csecsToday, AData.m_csecsRemaining,
     Ord(AData.m_progress), Ord(AData.m_notification)]));
  if Answered(CT_USER, 'GetDurationControl') then
    CheckTestsDone;
end;

procedure TSteamComponentTest.UserServersConnected(Sender: TObject; const AData: SteamServersConnected_t);
begin
  AddLog('TSteamUser.OnSteamServersConnected (not requested by the test)');
end;

procedure TSteamComponentTest.UserServersDisconnected(Sender: TObject; const AData: SteamServersDisconnected_t);
begin
  AddLog('TSteamUser.OnSteamServersDisconnected: result ' + ResultText(AData.m_eResult) +
    ' (not requested by the test)');
end;

procedure TSteamComponentTest.UserServerConnectFailure(Sender: TObject; const AData: SteamServerConnectFailure_t);
begin
  AddLog(Format('TSteamUser.OnSteamServerConnectFailure: result %s, still retrying %s (not requested by the test)',
    [ResultText(AData.m_eResult), BoolToStr(AData.m_bStillRetrying, True)]));
end;

{ --- TSteamApps --- }

procedure TSteamComponentTest.TestApps;
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
    Purchased := A.GetEarliestPurchaseUnixTime(FAppID);
    if Purchased = 0 then
      PurchasedText := 'none'
    else
      PurchasedText := FormatDateTime('yyyy-mm-dd hh:nn', UnixUTC(Int64(Purchased))) + ' UTC';
    AddLog(Format('Test TSteamApps: low violence %s, cybercafe %s, VAC banned %s, free weekend %s, ' +
      'DLC %d, app installed %s, earliest purchase %s, beta %s, betas %d (%d available, %d private), ' +
      'timed trial %s (%d of %d s), launch command line %d characters (GetLaunchCommandLine returned %d)',
      [BoolToStr(A.BIsLowViolence, True), BoolToStr(A.BIsCybercafe, True),
       BoolToStr(A.BIsVACBanned, True), BoolToStr(A.BIsSubscribedFromFreeWeekend, True),
       A.GetDLCCount, BoolToStr(A.BIsAppInstalled(FAppID), True), PurchasedText,
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

procedure TSteamComponentTest.AppsFileDetails(Sender: TObject; const AData: FileDetailsResult_t);
begin
  AddLog(Format('TSteamApps.OnFileDetailsResult: result %s, size %s, flags $%x',
    [ResultText(AData.m_eResult), U64Str(AData.m_ulFileSize), AData.m_unFlags]));
  if Answered(CT_APPS, 'GetFileDetails') then
  begin
    FTests[CT_APPS].Note := 'file details ' + ResultText(AData.m_eResult);
    CheckTestsDone;
  end;
end;

procedure TSteamComponentTest.AppsDlcInstalled(Sender: TObject; const AData: DlcInstalled_t);
begin
  AddLog(Format('TSteamApps.OnDlcInstalled: app %d (not requested by the test)', [AData.m_nAppID]));
end;

procedure TSteamComponentTest.AppsNewUrlLaunchParameters(Sender: TObject; const AData: NewUrlLaunchParameters_t);
begin
  AddLog('TSteamApps.OnNewUrlLaunchParameters (not requested by the test)');
end;

procedure TSteamComponentTest.AppsTimedTrialStatus(Sender: TObject; const AData: TimedTrialStatus_t);
begin
  AddLog(Format('TSteamApps.OnTimedTrialStatus: app %d, offline %s, %d of %d s (not requested by the test)',
    [AData.m_unAppID, BoolToStr(AData.m_bIsOffline, True), AData.m_unSecondsPlayed, AData.m_unSecondsAllowed]));
end;

{ --- TSteamRemoteStorage --- }

procedure TSteamComponentTest.TestRemoteStorage;
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
    FCloudData := Utf8Bytes('SteamDemo component test ' +
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

procedure TSteamComponentTest.StorageWriteComplete(Sender: TObject; const AData: RemoteStorageFileWriteAsyncComplete_t);
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

procedure TSteamComponentTest.StorageReadComplete(Sender: TObject; const AData: RemoteStorageFileReadAsyncComplete_t);
var
  R: TSteamRemoteStoragePlugin;
  Buf: TBytes;
  Fetched, Same: Boolean;
  SyncRead: Int32;
begin
  AddLog(Format('TSteamRemoteStorage.OnRemoteStorageFileReadAsyncComplete: call %s, result %s, offset %d, %d bytes',
    [U64Str(AData.m_hFileReadAsync), ResultText(AData.m_eResult), AData.m_nOffset, AData.m_cubRead]));
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

procedure TSteamComponentTest.StorageLocalFileChange(Sender: TObject; const AData: RemoteStorageLocalFileChange_t);
begin
  AddLog('TSteamRemoteStorage.OnRemoteStorageLocalFileChange (not requested by the test)');
end;

{ --- TSteamScreenshots --- }

procedure TSteamComponentTest.TestScreenshots;
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
{$if defined(DARWIN) or defined(MACOS)}
    if not Hooked and not Unhooked and not Before then
      // macOS ARM64 (2026-11-02): the Mac Steam client never takes the hook
      // (IsScreenshotsHooked stays False) - the same with FPC (LCL) and
      // Delphi (FMX), overlay off; on Windows it takes with the overlay off
      // too. A Steam-client limit, not the binding: informational
      FTests[CT_SHOTS].Note := 'hook not taken - the macOS Steam client keeps it off (seen with FPC and ' +
        'Delphi; informational); File > Take Screenshot tests writing one'
    else
{$endif}
    if not Hooked or Unhooked then
    begin
      // Elsewhere a hook that does not follow is a failure; the overlay
      // state in the note helps tell why (a run started from Steam has it)
      FTests[CT_SHOTS].ReadsOK := False;
      FTests[CT_SHOTS].Note := 'hook state did NOT follow HookScreenshots (overlay ' +
        IfThen((SteamUtils1.Plugin <> nil) and SteamUtils1.Plugin.IsOverlayEnabled, 'on', 'off') +
        ' - try a run started from Steam)';
    end
    else
      FTests[CT_SHOTS].Note := 'hook on / off OK; File > Take Screenshot tests writing one';
  except
    on E: Exception do ReadFailed(CT_SHOTS, 'HookScreenshots / IsScreenshotsHooked', E);
  end;
end;

procedure TSteamComponentTest.ScreenshotReady(Sender: TObject; const AData: ScreenshotReady_t);
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

procedure TSteamComponentTest.TestTimeline;
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
      'event handle %s, tooltip cleared, game mode Menus', [FPhaseID, U64Str(Ev)]));
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

procedure TSteamComponentTest.TimelineEventRecordingExists(Sender: TObject; const AData: SteamTimelineEventRecordingExists_t);
begin
  AddLog(Format('TSteamTimeline.OnSteamTimelineEventRecordingExists: event %s, recording exists %s',
    [U64Str(AData.m_ulEventID), BoolToStr(AData.m_bRecordingExists, True)]));
  if Answered(CT_TIMELINE, 'DoesEventRecordingExist') then
    CheckTestsDone;
end;

procedure TSteamComponentTest.TimelinePhaseRecordingExists(Sender: TObject; const AData: SteamTimelineGamePhaseRecordingExists_t);
begin
  AddLog(Format('TSteamTimeline.OnSteamTimelineGamePhaseRecordingExists: phase "%s", recorded %s ms, ' +
    'longest clip %s ms, %d clips, %d screenshots',
    [SteamText(@AData.m_rgchPhaseID[0]), U64Str(AData.m_ulRecordingMS), U64Str(AData.m_ulLongestClipMS),
     AData.m_unClipCount, AData.m_unScreenshotCount]));
  if Answered(CT_TIMELINE, 'DoesGamePhaseRecordingExist') then
    CheckTestsDone;
end;

{ --- TSteamUGC --- }

procedure TSteamComponentTest.TestUGC;
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
      k_EUGCMatchingUGCType_Items, FAppID, FAppID, 1);
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
      AddLog('Test TSteamUGC: query handle ' + U64Str(FUGCQuery) + ' created');
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

procedure TSteamComponentTest.UGCQueryCompleted(Sender: TObject; const AData: SteamUGCQueryCompleted_t);
var
  G: TSteamUGCPlugin;
  Details: SteamUGCDetails_t;
  I: Integer;
begin
  AddLog(Format('TSteamUGC.OnSteamUGCQueryCompleted: query %s, result %s, %d returned, %d matching, cached %s',
    [U64Str(AData.m_handle), ResultText(AData.m_eResult), AData.m_unNumResultsReturned,
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
        FillChar(Details, SizeOf(Details), 0);
        if G.GetQueryUGCResult(AData.m_handle, UInt32(I), Details) then
          AddLog(Format('Test TSteamUGC: item %d: id %s, "%s"',
            [I, U64Str(Details.m_nPublishedFileId), SteamText(@Details.m_rgchTitle[0])]));
      end;
    AddLog('Test TSteamUGC: ReleaseQueryUGCRequest ' +
      BoolToStr(G.ReleaseQueryUGCRequest(AData.m_handle), True));
    FUGCQuery := k_UGCQueryHandleInvalid;
  except
    on E: Exception do ReadFailed(CT_UGC, 'GetQueryUGCResult / ReleaseQueryUGCRequest', E);
  end;
  CheckTestsDone;
end;

procedure TSteamComponentTest.UGCWorkshopEULAStatus(Sender: TObject; const AData: WorkshopEULAStatus_t);
begin
  // The other fields are only filled in when the result is OK (first run:
  // InvalidParam - Workshop not set up for the app - with a garbage version)
  if AData.m_eResult = k_EResultOK then
    AddLog(Format('TSteamUGC.OnWorkshopEULAStatus: result %s, app %d, version %s, accepted %s, needs action %s',
      [ResultText(AData.m_eResult), AData.m_nAppID, U64Str(AData.m_unVersion), BoolToStr(AData.m_bAccepted, True),
       BoolToStr(AData.m_bNeedsAction, True)]))
  else
    AddLog(Format('TSteamUGC.OnWorkshopEULAStatus: result %s, app %d (no EULA data: is the Workshop ' +
      'set up for the app?)', [ResultText(AData.m_eResult), AData.m_nAppID]));
  if not Answered(CT_UGC, 'GetWorkshopEULAStatus') then
    Exit;
  AddNote(CT_UGC, 'EULA status ' + ResultText(AData.m_eResult));
  if AData.m_eResult = k_EResultOK then
    TestUGCExtended
  else
    AddNote(CT_UGC, 'Workshop item test skipped (Workshop not set up? docs/TestSetup.md)');
  CheckTestsDone;
end;

procedure TSteamComponentTest.TestUGCExtended;
var
  G: TSteamUGCPlugin;
begin
  G := SteamUGC1.Plugin;
  if G = nil then
    Exit;
  AddLog('Test TSteamUGC: the Workshop answers - extended test: CreateItem, upload, DeleteItem');
  try
    ExpectCall(CT_UGC, 'CreateItem', G.CreateItem(FAppID, k_EWorkshopFileTypeCommunity));
  except
    on E: Exception do ReadFailed(CT_UGC, 'CreateItem', E);
  end;
end;

procedure TSteamComponentTest.UGCCreateItemResult(Sender: TObject; const AData: CreateItemResult_t);
var
  G: TSteamUGCPlugin;
  Update: UGCUpdateHandle_t;
  Lines: TStringList;
  Base: string;
  OK: Boolean;
begin
  AddLog(Format('TSteamUGC.OnCreateItemResult: result %s, item %s, user needs to accept the Workshop ' +
    'legal agreement %s', [ResultText(AData.m_eResult), U64Str(AData.m_nPublishedFileId),
    BoolToStr(AData.m_bUserNeedsToAcceptWorkshopLegalAgreement, True)]));
  if not Answered(CT_UGC, 'CreateItem') then
  begin
    // too late (the test timed out or ended): never leave the item behind
    if (AData.m_eResult = k_EResultOK) and (AData.m_nPublishedFileId <> 0) and
      (AData.m_nPublishedFileId <> FUGCItem) and (SteamUGC1.Plugin <> nil) then
      AddLog(Format('Test TSteamUGC: late item %s - DeleteItem sent (call %s)', [U64Str(AData.m_nPublishedFileId),
        U64Str(SteamUGC1.Plugin.DeleteItem(AData.m_nPublishedFileId))]));
    Exit;
  end;
  AddNote(CT_UGC, 'CreateItem ' + ResultText(AData.m_eResult));
  if AData.m_bUserNeedsToAcceptWorkshopLegalAgreement then
    AddNote(CT_UGC, 'legal agreement not accepted (the item stays hidden)');
  G := SteamUGC1.Plugin;
  if (AData.m_eResult <> k_EResultOK) or (G = nil) then
  begin
    CheckTestsDone;
    Exit;
  end;
  FUGCItem := AData.m_nPublishedFileId;
  try
    OK := False;
    Base := DemoSettingsFolder('SteamDemo');
    if Base = '' then
    begin
      AddLog('Test TSteamUGC: no settings folder for the content - not uploaded');
      AddNote(CT_UGC, 'no settings folder - item not uploaded');
    end
    else
    begin
      FUGCFolder := ExpandFileName(IncludeTrailingPathDelimiter(Base) + TEST_UGC_FOLDER);
      ForceDirectories(FUGCFolder);
      Lines := TStringList.Create;
      try
        Lines.Add('TSteamAPI component test upload - the test deletes the item again.');
        Lines.SaveToFile(IncludeTrailingPathDelimiter(FUGCFolder) + TEST_UGC_FILE);
      finally
        Lines.Free;
      end;
      Update := G.StartItemUpdate(FAppID, FUGCItem);
      OK := Update <> k_UGCUpdateHandleInvalid;
      if OK then
        AddLog('Test TSteamUGC: StartItemUpdate, update handle ' + U64Str(Update))
      else
        AddLog('Test TSteamUGC: StartItemUpdate returned k_UGCUpdateHandleInvalid');
      if OK then
      begin
        OK := G.SetItemTitle(Update, TEST_UGC_TITLE);
        AddLog('Test TSteamUGC: SetItemTitle ' + BoolToStr(OK, True));
      end;
      if OK then
      begin
        OK := G.SetItemVisibility(Update, k_ERemoteStoragePublishedFileVisibilityPrivate);
        AddLog('Test TSteamUGC: SetItemVisibility (private) ' + BoolToStr(OK, True));
      end;
      if OK then
      begin
        OK := G.SetItemContent(Update, FUGCFolder);
        AddLog('Test TSteamUGC: SetItemContent (' + FUGCFolder + ') ' + BoolToStr(OK, True));
      end;
      if OK then
        ExpectCall(CT_UGC, 'SubmitItemUpdate', G.SubmitItemUpdate(Update, 'TSteamAPI component test upload'));
    end;
    if not OK then
    begin
      if Base <> '' then
        FTests[CT_UGC].ReadsOK := False;
      RemoveUGCFolder;
      DeleteUGCItem;
    end;
  except
    on E: Exception do
    begin
      ReadFailed(CT_UGC, 'item update', E);
      RemoveUGCFolder;
      DeleteUGCItem;
    end;
  end;
  CheckTestsDone;
end;

procedure TSteamComponentTest.UGCSubmitItemUpdateResult(Sender: TObject; const AData: SubmitItemUpdateResult_t);
begin
  AddLog(Format('TSteamUGC.OnSubmitItemUpdateResult: result %s, item %s, user needs to accept the Workshop ' +
    'legal agreement %s', [ResultText(AData.m_eResult), U64Str(AData.m_nPublishedFileId),
    BoolToStr(AData.m_bUserNeedsToAcceptWorkshopLegalAgreement, True)]));
  if not Answered(CT_UGC, 'SubmitItemUpdate') then
    Exit;
  AddNote(CT_UGC, 'SubmitItemUpdate ' + ResultText(AData.m_eResult));
  RemoveUGCFolder;
  DeleteUGCItem;
  CheckTestsDone;
end;

procedure TSteamComponentTest.UGCDeleteItemResult(Sender: TObject; const AData: DeleteItemResult_t);
begin
  AddLog(Format('TSteamUGC.OnDeleteItemResult: result %s, item %s',
    [ResultText(AData.m_eResult), U64Str(AData.m_nPublishedFileId)]));
  if not Answered(CT_UGC, 'DeleteItem') then
    Exit;
  AddNote(CT_UGC, 'DeleteItem ' + ResultText(AData.m_eResult));
  if AData.m_eResult = k_EResultOK then
    FUGCItem := 0;
  CheckTestsDone;
end;

procedure TSteamComponentTest.DeleteUGCItem;
begin
  if (FUGCItem = 0) or (SteamUGC1.Plugin = nil) then
    Exit;
  try
    ExpectCall(CT_UGC, 'DeleteItem', SteamUGC1.Plugin.DeleteItem(FUGCItem));
  except
    on E: Exception do ReadFailed(CT_UGC, 'DeleteItem', E);
  end;
end;

procedure TSteamComponentTest.RemoveUGCFolder;
var
  F: string;
begin
  if FUGCFolder = '' then
    Exit;
  F := IncludeTrailingPathDelimiter(FUGCFolder) + TEST_UGC_FILE;
  AddLog(Format('Test TSteamUGC: content folder removed (file %s, folder %s)',
    [BoolToStr(not FileExists(F) or DeleteFile(F), True), BoolToStr(RemoveDir(FUGCFolder), True)]));
  FUGCFolder := '';
end;

procedure TSteamComponentTest.UGCSubscribedListChanged(Sender: TObject; const AData: UserSubscribedItemsListChanged_t);
begin
  AddLog(Format('TSteamUGC.OnUserSubscribedItemsListChanged: app %d (not requested by the test)', [AData.m_nAppID]));
end;

procedure TSteamComponentTest.UGCItemInstalled(Sender: TObject; const AData: ItemInstalled_t);
begin
  AddLog(Format('TSteamUGC.OnItemInstalled: app %d, item %s (not requested by the test)',
    [AData.m_unAppID, U64Str(AData.m_nPublishedFileId)]));
end;


{ --- Batch 2a: TSteamMatchmaking ... TSteamRemotePlay --- }

procedure TSteamComponentTest.TestMatchmaking;
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

procedure TSteamComponentTest.MatchmakingLobbyMatchList(Sender: TObject; const AData: LobbyMatchList_t);
begin
  AddLog(Format('TSteamMatchmaking.OnLobbyMatchList: %d lobbies matching', [AData.m_nLobbiesMatching]));
  if Answered(CT_MATCHMAKING, 'RequestLobbyList') then
  begin
    FTests[CT_MATCHMAKING].Note := Format('%d lobbies', [AData.m_nLobbiesMatching]);
    CheckTestsDone;
  end;
end;

procedure TSteamComponentTest.TestParties;
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

procedure TSteamComponentTest.TestMusic;
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

procedure TSteamComponentTest.TestHTTP;
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
    AddLog('Test TSteamHTTP: GET ' + TEST_HTTP_URL + ', request ' + U64Str(FHTTPRequest));
    ExpectCall(CT_HTTP, 'SendHTTPRequest', Call);
  except
    on E: Exception do ReadFailed(CT_HTTP, 'HTTP calls', E);
  end;
end;

procedure TSteamComponentTest.HTTPRequestCompleted(Sender: TObject; const AData: HTTPRequestCompleted_t);
var
  H: TSteamHTTPPlugin;
  Body: TBytes;
  Size: UInt32;
  ShowBytes: Integer;
  Start: string;
begin
  AddLog(Format('TSteamHTTP.OnHTTPRequestCompleted: request %s, successful %s, HTTP status %d, %d bytes',
    [U64Str(AData.m_hRequest), BoolToStr(AData.m_bRequestSuccessful, True), Ord(AData.m_eStatusCode),
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
        Start := Utf8Text(Body, ShowBytes);
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

procedure TSteamComponentTest.TestHTMLSurface;
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

procedure TSteamComponentTest.HTMLBrowserReady(Sender: TObject; const AData: HTML_BrowserReady_t);
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

procedure TSteamComponentTest.TestInventory;
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

procedure TSteamComponentTest.InventoryResultReady(Sender: TObject; const AData: SteamInventoryResultReady_t);
var
  I: TSteamInventoryPlugin;
  Count: UInt32;
  Step: Integer;
  Gem: SteamItemInstanceID_t;
  Text: string;
begin
  AddLog(Format('TSteamInventory.OnSteamInventoryResultReady: result %d, %s',
    [AData.m_handle, ResultText(AData.m_result)]));
  I := SteamInventory1.Plugin;
  if (FInvResult <> k_SteamInventoryResultInvalid) and (AData.m_handle = FInvResult) then
  begin
    if not Answered(CT_INVENTORY, 'GetAllItems') then
      Exit;
    AddNote(CT_INVENTORY, 'result ' + ResultText(AData.m_result));
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
    // Fail while the Inventory Service is off for the app (every run so far)
    if AData.m_result = k_EResultOK then
      TestInventoryExtended
    else
      AddNote(CT_INVENTORY, 'item test skipped (Inventory Service off? docs/TestSetup.md)');
    CheckTestsDone;
    Exit;
  end;
  for Step := INV_GENERATE to INV_DROP do
    if (FInvSteps[Step] <> k_SteamInventoryResultInvalid) and (AData.m_handle = FInvSteps[Step]) and
      ((I = nil) or (I.GetResultStatus(AData.m_handle) <> k_EResultPending)) then
    begin   // (pending = a repeat for an older result whose number Steam reused)
      if not Answered(CT_INVENTORY, InvStepNames[Step]) then
        Exit;
      Text := InvStepNames[Step] + ' ' + ResultText(AData.m_result);
      Gem := k_SteamItemInstanceIDInvalid;
      if I <> nil then
      try
        if AData.m_result = k_EResultOK then
          Text := Text + ' (' + InventoryItemsText(AData.m_handle, Gem) + ')';
        I.DestroyResult(AData.m_handle);
      except
        on E: Exception do ReadFailed(CT_INVENTORY, InvStepNames[Step] + ' result', E);
      end;
      FInvSteps[Step] := k_SteamInventoryResultInvalid;
      AddNote(CT_INVENTORY, Text);
      if (Step = INV_GENERATE) and (I <> nil) then
      begin
        if Gem = k_SteamItemInstanceIDInvalid then
          AddNote(CT_INVENTORY, 'ConsumeItem skipped (no Test Gem in the result)')
        else
        try
          InventoryStepSent(INV_CONSUME, I.ConsumeItem(FInvSteps[INV_CONSUME], Gem, 1));
        except
          on E: Exception do ReadFailed(CT_INVENTORY, 'ConsumeItem', E);
        end;
      end;
      CheckTestsDone;
      Exit;
    end;
end;

procedure TSteamComponentTest.TestInventoryExtended;
var
  I: TSteamInventoryPlugin;
  Def: SteamItemDef_t;
  Qty: UInt32;
begin
  I := SteamInventory1.Plugin;
  if I = nil then
    Exit;
  AddLog('Test TSteamInventory: the Inventory Service answers - extended test with the item ' +
    'definitions of docs/test-setup/itemdefs_2275430.json');
  try
    Def := TEST_ITEM_GEM;
    Qty := 1;
    InventoryStepSent(INV_GENERATE, I.GenerateItems(FInvSteps[INV_GENERATE], @Def, @Qty, 1));
    InventoryStepSent(INV_PROMO, I.AddPromoItem(FInvSteps[INV_PROMO], TEST_ITEM_PROMO));
    InventoryStepSent(INV_DROP, I.TriggerItemDrop(FInvSteps[INV_DROP], TEST_ITEM_DROP));
  except
    on E: Exception do ReadFailed(CT_INVENTORY, 'extended Inventory calls', E);
  end;
end;

procedure TSteamComponentTest.InventoryStepSent(AStep: Integer; AOK: Boolean);
begin
  if AOK then
  begin
    AddLog(Format('Test TSteamInventory: %s, result handle %d - waiting for callback 4700',
      [InvStepNames[AStep], FInvSteps[AStep]]));
    Expect(CT_INVENTORY, InvStepNames[AStep]);
  end
  else
  begin
    FInvSteps[AStep] := k_SteamInventoryResultInvalid;
    Inc(FTests[CT_INVENTORY].Sent);
    if FTests[CT_INVENTORY].Missing <> '' then
      FTests[CT_INVENTORY].Missing := FTests[CT_INVENTORY].Missing + ', ';
    FTests[CT_INVENTORY].Missing := FTests[CT_INVENTORY].Missing + InvStepNames[AStep] + ' (returned False)';
    AddLog('Test TSteamInventory: ' + InvStepNames[AStep] + ' returned False');
  end;
end;

function TSteamComponentTest.InventoryItemsText(AHandle: SteamInventoryResult_t; out AGem: SteamItemInstanceID_t): string;
var
  I: TSteamInventoryPlugin;
  Items: array of SteamItemDetails_t;
  Count: UInt32;
  K: Integer;
begin
  AGem := k_SteamItemInstanceIDInvalid;
  I := SteamInventory1.Plugin;
  Count := 0;
  if (I = nil) or not I.GetResultItems(AHandle, nil, Count) then
    Exit('GetResultItems False');
  Result := Format('%d items', [Count]);
  if Count = 0 then
    Exit;
  SetLength(Items, Count);
  if not I.GetResultItems(AHandle, @Items[0], Count) then
    Exit(Result + ', GetResultItems False');
  for K := 0 to Integer(Count) - 1 do
  begin
    // m_unFlags: 1 = no trade, $100 = removed (consumed), $200 = consumed
    AddLog(Format('Test TSteamInventory: item %d: instance %s, definition %d, quantity %d, flags $%x',
      [K, U64Str(Items[K].m_itemId), Items[K].m_iDefinition, Items[K].m_unQuantity, Items[K].m_unFlags]));
    if (Items[K].m_iDefinition = TEST_ITEM_GEM) and (Items[K].m_unQuantity > 0) and
      (AGem = k_SteamItemInstanceIDInvalid) then
      AGem := Items[K].m_itemId;
  end;
end;

procedure TSteamComponentTest.TestVideo;
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
    V.GetOPFSettings(FAppID);
    AddLog('Test TSteamVideo: GetOPFSettings - waiting for callback 4624 (UNVERIFIED that Steam ' +
      'answers for an app without 360 video; NO ANSWER here would be that, not a component fault)');
    Expect(CT_VIDEO, 'GetOPFSettings');
  except
    on E: Exception do ReadFailed(CT_VIDEO, 'Video calls', E);
  end;
end;

procedure TSteamComponentTest.VideoOPFSettingsResult(Sender: TObject; const AData: GetOPFSettingsResult_t);
begin
  AddLog(Format('TSteamVideo.OnGetOPFSettingsResult: result %s, video app %d',
    [ResultText(AData.m_eResult), AData.m_unVideoAppID]));
  if Answered(CT_VIDEO, 'GetOPFSettings') then
  begin
    FTests[CT_VIDEO].Note := 'OPF settings ' + ResultText(AData.m_eResult);
    CheckTestsDone;
  end;
end;

procedure TSteamComponentTest.TestParentalSettings;
var
  P: TSteamParentalSettingsPlugin;
begin
  P := SteamParentalSettings1.Plugin;
  if not BeginTest(CT_PARENTAL, SteamParentalSettings1, P) then
    Exit;
  try
    AddLog(Format('Test TSteamParentalSettings: lock enabled %s, locked %s, this app blocked %s / in block list %s, ' +
      'store blocked %s', [BoolToStr(P.BIsParentalLockEnabled, True), BoolToStr(P.BIsParentalLockLocked, True),
      BoolToStr(P.BIsAppBlocked(FAppID), True), BoolToStr(P.BIsAppInBlockList(FAppID), True),
      BoolToStr(P.BIsFeatureBlocked(k_EFeatureStore), True)]));
    FTests[CT_PARENTAL].Note := 'reads only';
  except
    on E: Exception do ReadFailed(CT_PARENTAL, 'ParentalSettings reads', E);
  end;
end;

procedure TSteamComponentTest.TestRemotePlay;
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

procedure TSteamComponentTest.TestNetworking;
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

procedure TSteamComponentTest.TestNetworkingSockets;
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
        [Ord(Ident.m_eType), U64Str(Ident.m_steamID64), IfThen(Same, 'same as', 'DIFFERENT FROM')]));
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
    Data := Utf8Bytes(TEST_TEXT);
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
        [Msgs[I]^.m_conn, Msgs[I]^.m_cbSize, Msgs[I]^.m_nMessageNumber, Utf8Text(Got, Length(Got))]));
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

procedure TSteamComponentTest.NetConnectionStatusChanged(Sender: TObject; const AData: SteamNetConnectionStatusChangedCallback_t);
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

procedure TSteamComponentTest.CloseSocketPair(const AWhy: string);
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

procedure TSteamComponentTest.TestNetworkingMessages;
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

procedure TSteamComponentTest.TestNetworkingUtils;
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

procedure TSteamComponentTest.RelayNetworkStatus(Sender: TObject; const AData: SteamRelayNetworkStatus_t);
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

procedure TSteamComponentTest.ForgetQuery(var AQuery: HServerQuery; const ANote: string);
begin
  AQuery := HSERVERQUERY_INVALID;
  AddServerNote(ANote);
end;

procedure TSteamComponentTest.AddServerNote(const S: string);
begin
  if FTests[CT_SERVERS].Note <> '' then
    FTests[CT_SERVERS].Note := FTests[CT_SERVERS].Note + ', ';
  FTests[CT_SERVERS].Note := FTests[CT_SERVERS].Note + S;
end;

procedure TSteamComponentTest.ServerRequestStarted(const AName, AWhat: string; AOk: Boolean);
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

procedure TSteamComponentTest.TestMatchmakingServers;
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
    FLANList := SteamMatchmakingServers1.StartServerList(sltLAN, FAppID);
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

procedure TSteamComponentTest.EndInternetList(const AHow: string);
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

procedure TSteamComponentTest.ServersResponded(Sender: TObject; ARequest: HServerListRequest; AIndex: Integer;
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

procedure TSteamComponentTest.ServersFailed(Sender: TObject; ARequest: HServerListRequest; AIndex: Integer);
begin
  if (ARequest <> nil) and (ARequest = FServerList) then
    Inc(FServersFailed);
end;

procedure TSteamComponentTest.ServerListComplete(Sender: TObject; ARequest: HServerListRequest;
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

procedure TSteamComponentTest.PingResponded(Sender: TObject; AQuery: HServerQuery; const AServer: gameserveritem_t);
begin
  AddLog(Format('TSteamMatchmakingServers.OnPingResponded: query %d, "%s", %d ms',
    [AQuery, SteamText(@AServer.m_szServerName[0]), AServer.m_nPing]));
  if (AQuery = FGSPingQuery) and (FGSPingQuery <> HSERVERQUERY_INVALID) and
    Answered(CT_GAMESERVER, 'Ping (own server)') then
  begin
    FGSPingQuery := HSERVERQUERY_INVALID;
    AddNote(CT_GAMESERVER, Format('own server: ping %d ms, "%s", %d/%d players',
      [AServer.m_nPing, SteamText(@AServer.m_szServerName[0]), AServer.m_nPlayers, AServer.m_nMaxPlayers]));
    CheckTestsDone;
    Exit;
  end;
  if (AQuery = FPingQuery) and (FPingQuery <> HSERVERQUERY_INVALID) and Answered(CT_SERVERS, 'Ping') then
    ForgetQuery(FPingQuery, Format('ping %d ms', [AServer.m_nPing]));
end;

procedure TSteamComponentTest.PingFailed(Sender: TObject; AQuery: HServerQuery);
begin
  AddLog(Format('TSteamMatchmakingServers.OnPingFailed: query %d', [AQuery]));
  if (AQuery = FGSPingQuery) and (FGSPingQuery <> HSERVERQUERY_INVALID) and
    Answered(CT_GAMESERVER, 'Ping (own server)') then
  begin
    FGSPingQuery := HSERVERQUERY_INVALID;
    AddNote(CT_GAMESERVER, 'own server: ping FAILED');
    FTests[CT_GAMESERVER].ReadsOK := False;
    CheckTestsDone;
    Exit;
  end;
  if (AQuery = FPingQuery) and (FPingQuery <> HSERVERQUERY_INVALID) and Answered(CT_SERVERS, 'Ping') then
    ForgetQuery(FPingQuery, 'ping: no answer from the server');
end;

procedure TSteamComponentTest.ServerPlayer(Sender: TObject; AQuery: HServerQuery; const AName: string;
  AScore: Integer; ATimePlayed: Single);
begin
  if (AQuery = FGSPlayersQuery) and (FGSPlayersQuery <> HSERVERQUERY_INVALID) then
  begin
    AddLog(Format('TSteamMatchmakingServers.OnPlayer (own server): "%s"', [AName]));
    Exit;
  end;
  if (AQuery <> FPlayersQuery) or (FPlayersQuery = HSERVERQUERY_INVALID) then
    Exit;
  Inc(FPlayerCount);
  if FPlayerCount <= 3 then
    AddLog(Format('TSteamMatchmakingServers.OnPlayer: query %d, "%s", score %d, %.0f s',
      [AQuery, AName, AScore, ATimePlayed]));
end;

procedure TSteamComponentTest.PlayersFailed(Sender: TObject; AQuery: HServerQuery);
begin
  AddLog(Format('TSteamMatchmakingServers.OnPlayersFailed: query %d', [AQuery]));
  if (AQuery = FGSPlayersQuery) and (FGSPlayersQuery <> HSERVERQUERY_INVALID) and
    Answered(CT_GAMESERVER, 'Players (own server)') then
  begin
    FGSPlayersQuery := HSERVERQUERY_INVALID;
    AddNote(CT_GAMESERVER, 'own server: players FAILED');
    FTests[CT_GAMESERVER].ReadsOK := False;
    CheckTestsDone;
    Exit;
  end;
  if (AQuery = FPlayersQuery) and (FPlayersQuery <> HSERVERQUERY_INVALID) and Answered(CT_SERVERS, 'Players') then
    ForgetQuery(FPlayersQuery, 'players: no answer from the server');
end;

procedure TSteamComponentTest.PlayersComplete(Sender: TObject; AQuery: HServerQuery);
begin
  AddLog(Format('TSteamMatchmakingServers.OnPlayersComplete: query %d, %d players', [AQuery, FPlayerCount]));
  if (AQuery = FGSPlayersQuery) and (FGSPlayersQuery <> HSERVERQUERY_INVALID) and
    Answered(CT_GAMESERVER, 'Players (own server)') then
  begin
    FGSPlayersQuery := HSERVERQUERY_INVALID;
    AddNote(CT_GAMESERVER, 'own server: players query complete (0 players expected)');
    CheckTestsDone;
    Exit;
  end;
  if (AQuery = FPlayersQuery) and (FPlayersQuery <> HSERVERQUERY_INVALID) and Answered(CT_SERVERS, 'Players') then
    ForgetQuery(FPlayersQuery, Format('%d players', [FPlayerCount]));
end;

procedure TSteamComponentTest.ServerRule(Sender: TObject; AQuery: HServerQuery; const ARule, AValue: string);
begin
  if (AQuery = FGSRulesQuery) and (FGSRulesQuery <> HSERVERQUERY_INVALID) then
  begin
    // RulesResponded of the response object - never seen from a CS2 server
    Inc(FGSRuleCount);
    AddLog(Format('TSteamMatchmakingServers.OnRule (own server): %s = "%s"', [ARule, AValue]));
    if (ARule = TEST_GS_RULE) and (AValue = '1') then
      FGSRuleSeen := True;
    Exit;
  end;
  if (AQuery <> FRulesQuery) or (FRulesQuery = HSERVERQUERY_INVALID) then
    Exit;
  Inc(FRuleCount);
  if FRuleCount <= 3 then
    AddLog(Format('TSteamMatchmakingServers.OnRule: query %d, %s = "%s"', [AQuery, ARule, AValue]));
end;

procedure TSteamComponentTest.RulesFailed(Sender: TObject; AQuery: HServerQuery);
begin
  AddLog(Format('TSteamMatchmakingServers.OnRulesFailed: query %d', [AQuery]));
  if (AQuery = FGSRulesQuery) and (FGSRulesQuery <> HSERVERQUERY_INVALID) and
    Answered(CT_GAMESERVER, 'Rules (own server)') then
  begin
    FGSRulesQuery := HSERVERQUERY_INVALID;
    AddNote(CT_GAMESERVER, 'own server: rules FAILED');
    FTests[CT_GAMESERVER].ReadsOK := False;
    CheckTestsDone;
    Exit;
  end;
  if (AQuery = FRulesQuery) and (FRulesQuery <> HSERVERQUERY_INVALID) and Answered(CT_SERVERS, 'Rules') then
    ForgetQuery(FRulesQuery, 'rules: no answer from the server');
end;

procedure TSteamComponentTest.RulesComplete(Sender: TObject; AQuery: HServerQuery);
begin
  AddLog(Format('TSteamMatchmakingServers.OnRulesComplete: query %d, %d rules', [AQuery, FRuleCount]));
  if (AQuery = FGSRulesQuery) and (FGSRulesQuery <> HSERVERQUERY_INVALID) and
    Answered(CT_GAMESERVER, 'Rules (own server)') then
  begin
    FGSRulesQuery := HSERVERQUERY_INVALID;
    if FGSRuleSeen then
      AddNote(CT_GAMESERVER, Format('own server: %d rules, %s = 1 read back', [FGSRuleCount, TEST_GS_RULE]))
    else
    begin
      AddNote(CT_GAMESERVER, Format('own server: %d rules, %s NOT among them', [FGSRuleCount, TEST_GS_RULE]));
      FTests[CT_GAMESERVER].ReadsOK := False;
    end;
    CheckTestsDone;
    Exit;
  end;
  if (AQuery = FRulesQuery) and (FRulesQuery <> HSERVERQUERY_INVALID) and Answered(CT_SERVERS, 'Rules') then
    ForgetQuery(FRulesQuery, Format('%d rules', [FRuleCount]));
end;

procedure TSteamComponentTest.StopServerRequests(const AWhy: string);
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

{ --- Game server (a listen server in this process) --- }

procedure TSteamComponentTest.TestGameServers;
var
  OldGame, OldQuery: Word;
begin
  FServerStartedByTest := False;
  FUsingServer := False;
  if SteamAPI1.IsGameServerRunning then
    AddLog(Format('Test game server: a game server runs already (query port %d, %d other test(s) using it) - ' +
      'tested as it is', [SteamAPI1.Steam.GameServerQueryPort, DemoGameServerUsers]))
  else
  begin
    // the test's ports for this start only: the form's settings stay
    OldGame := SteamAPI1.GameServerGamePort;
    OldQuery := SteamAPI1.GameServerQueryPort;
    SteamAPI1.GameServerGamePort := TEST_GS_GAME_PORT;
    SteamAPI1.GameServerQueryPort := TEST_GS_QUERY_PORT;
    try
      if SteamAPI1.StartGameServer then
      begin
        FServerStartedByTest := True;
        AddLog(Format('Test game server: listen server started (game port %d, query port %d, version %s)',
          [TEST_GS_GAME_PORT, TEST_GS_QUERY_PORT, SteamAPI1.GameServerVersion]));
      end
      else
        AddLog('Test game server: StartGameServer FAILED: ' + SteamAPI1.Steam.LastError);
    finally
      SteamAPI1.GameServerGamePort := OldGame;
      SteamAPI1.GameServerQueryPort := OldQuery;
    end;
  end;
  if SteamAPI1.IsGameServerRunning then
  begin
    FUsingServer := True;
    Inc(DemoGameServerUsers);
  end;
  FGSQueryPort := SteamAPI1.Steam.GameServerQueryPort;   // the port it runs on
  // TestGameServer LAST: when the server is logged on already it answers
  // at once, and the rows below must have registered their 'log-on' first
  TestGSStats;
  TestGSUtils;
  TestGSNetworking;
  TestGSSockets;
  TestGSMessages;
  TestGSHTTP;
  TestGSUGC;
  TestGSInventory;
  TestGameServer;
end;

procedure TSteamComponentTest.TestGameServer;
var
  G: TSteamGameServerPlugin;
begin
  G := SteamGameServer1.Plugin;
  if not BeginTest(CT_GAMESERVER, SteamGameServer1, G) then
    Exit;
  try
    AddLog(Format('Test TSteamGameServer: logged on %s, secure %s, SteamID %s',
      [BoolToStr(G.BLoggedOn, True), BoolToStr(G.BSecure, True), U64Str(G.GetSteamID.Value)]));
    if G.BLoggedOn then
      GSLoggedOn
    else if not FServerStartedByTest then
    begin
      // another test's server whose log-on is still on its way: wait for 101
      AddLog('Test TSteamGameServer: the server''s log-on is under way - waiting for 101');
      Expect(CT_GAMESERVER, 'LogOnAnonymous');
    end
    else
    begin
      G.SetModDir('tsteamapi');
      G.SetProduct('TSteamAPI');
      G.SetGameDescription('TSteamAPI component test');
      G.SetDedicatedServer(False);
      G.LogOnAnonymous;
      AddLog('Test TSteamGameServer: LogOnAnonymous - waiting for SteamServersConnected_t (101) on the ' +
        'SERVER''s pipe');
      Expect(CT_GAMESERVER, 'LogOnAnonymous');
    end;
  except
    on E: Exception do ReadFailed(CT_GAMESERVER, 'log-on calls', E);
  end;
end;

procedure TSteamComponentTest.TestGSStats;
begin
  if not BeginTest(CT_GSSTATS, SteamGameServerStats1, SteamGameServerStats1.Plugin) then
    Exit;
  Expect(CT_GSSTATS, 'log-on');   // RequestUserStats needs a logged-on server
end;

procedure TSteamComponentTest.TestGSUtils;
var
  U: TSteamUtilsPlugin;
begin
  U := SteamGSUtils1.Plugin;
  if not BeginTest(CT_GSUTILS, SteamGSUtils1, U) then
    Exit;
  try
    AddLog(Format('Test TSteamGameServerUtils: app %d (client %d), universe %d, server time %s',
      [U.GetAppID, FAppID, Ord(U.GetConnectedUniverse),
       FormatDateTime('yyyy-mm-dd hh:nn:ss', UnixUTC(Int64(U.GetServerRealTime)))]));
    if U.GetAppID <> FAppID then
    begin
      FTests[CT_GSUTILS].ReadsOK := False;
      AddNote(CT_GSUTILS, 'server app id differs from the client''s');
    end
    else
      AddNote(CT_GSUTILS, 'reads only; app id = the client''s');
  except
    on E: Exception do ReadFailed(CT_GSUTILS, 'reads', E);
  end;
end;

procedure TSteamComponentTest.TestGSNetworking;
var
  N: TSteamNetworkingPlugin;
  Size: UInt32;
begin
  N := SteamGSNetworking1.Plugin;
  if not BeginTest(CT_GSNETWORKING, SteamGSNetworking1, N) then
    Exit;
  try
    Size := 0;
    AddLog('Test TSteamGameServerNetworking: P2P packet waiting on channel 0 ' +
      BoolToStr(N.IsP2PPacketAvailable(Size, 0), True));
    AddNote(CT_GSNETWORKING, 'reads only');
  except
    on E: Exception do ReadFailed(CT_GSNETWORKING, 'reads', E);
  end;
end;

procedure TSteamComponentTest.TestGSSockets;
begin
  if not BeginTest(CT_GSSOCKETS, SteamGSSockets1, SteamGSSockets1.Plugin) then
    Exit;
  Expect(CT_GSSOCKETS, 'log-on');   // the server's identity is known after it
end;

procedure TSteamComponentTest.TestGSMessages;
var
  M: TSteamNetworkingMessagesPlugin;
  Msgs: array[0..3] of PSteamNetworkingMessage_t;
  Count, I: Integer;
begin
  M := SteamGSMessages1.Plugin;
  if not BeginTest(CT_GSMESSAGES, SteamGSMessages1, M) then
    Exit;
  try
    FillChar(Msgs, SizeOf(Msgs), 0);
    Count := M.ReceiveMessages(0, Msgs);
    for I := 0 to Count - 1 do
      M.ReleaseMessage(Msgs[I]);
    AddLog(Format('Test TSteamGameServerNetworkingMessages: %d messages waiting on channel 0', [Count]));
    AddNote(CT_GSMESSAGES, 'reads only');
  except
    on E: Exception do ReadFailed(CT_GSMESSAGES, 'reads', E);
  end;
end;

procedure TSteamComponentTest.TestGSHTTP;
var
  H: TSteamHTTPPlugin;
  Call: SteamAPICall_t;
begin
  H := SteamGSHTTP1.Plugin;
  if not BeginTest(CT_GSHTTP, SteamGSHTTP1, H) then
    Exit;
  try
    FGSHTTPRequest := H.CreateHTTPRequest(k_EHTTPMethodGET, TEST_HTTP_URL);
    if FGSHTTPRequest = 0 then
    begin
      FTests[CT_GSHTTP].ReadsOK := False;
      AddNote(CT_GSHTTP, 'CreateHTTPRequest returned 0');
      Exit;
    end;
    Call := k_uAPICallInvalid;
    if not H.SendHTTPRequest(FGSHTTPRequest, Call) then
      AddLog('Test TSteamGameServerHTTP: SendHTTPRequest returned False');
    AddLog('Test TSteamGameServerHTTP: GET ' + TEST_HTTP_URL + ', request ' + U64Str(FGSHTTPRequest));
    ExpectCall(CT_GSHTTP, 'SendHTTPRequest', Call);
  except
    on E: Exception do ReadFailed(CT_GSHTTP, 'HTTP calls', E);
  end;
end;

procedure TSteamComponentTest.TestGSUGC;
begin
  if not BeginTest(CT_GSUGC, SteamGSUGC1, SteamGSUGC1.Plugin) then
    Exit;
  Expect(CT_GSUGC, 'log-on');   // the query is sent once the server is logged on
end;

procedure TSteamComponentTest.TestGSInventory;
var
  I: TSteamInventoryPlugin;
begin
  I := SteamGSInventory1.Plugin;
  if not BeginTest(CT_GSINVENTORY, SteamGSInventory1, I) then
    Exit;
  try
    AddLog('Test TSteamGameServerInventory: LoadItemDefinitions ' + BoolToStr(I.LoadItemDefinitions, True));
    AddNote(CT_GSINVENTORY, 'reads only');
  except
    on E: Exception do ReadFailed(CT_GSINVENTORY, 'reads', E);
  end;
end;

procedure TSteamComponentTest.GSServersConnected(Sender: TObject; const AData: SteamServersConnected_t);
begin
  AddLog('TSteamGameServer.OnSteamServersConnected: the game server is logged on (server pipe)');
  if Answered(CT_GAMESERVER, 'LogOnAnonymous') then
  begin
    AddNote(CT_GAMESERVER, 'logged on (anonymous)');
    GSLoggedOn;
    CheckTestsDone;
  end;
end;

procedure TSteamComponentTest.GSConnectFailure(Sender: TObject; const AData: SteamServerConnectFailure_t);
begin
  AddLog(Format('TSteamGameServer.OnSteamServerConnectFailure: result %s, still retrying %s',
    [ResultText(AData.m_eResult), BoolToStr(AData.m_bStillRetrying, True)]));
  if AData.m_bStillRetrying then
    Exit;   // Steam keeps trying: wait for 101
  if Answered(CT_GAMESERVER, 'LogOnAnonymous') then
  begin
    AddNote(CT_GAMESERVER, 'log-on FAILED: ' + ResultText(AData.m_eResult));
    GSLogOnFailed('server log-on failed');
    CheckTestsDone;
  end;
end;

procedure TSteamComponentTest.GSDisconnected(Sender: TObject; const AData: SteamServersDisconnected_t);
begin
  AddLog('TSteamGameServer.OnSteamServersDisconnected: result ' + ResultText(AData.m_eResult));
end;

procedure TSteamComponentTest.GSPolicy(Sender: TObject; const AData: GSPolicyResponse_t);
begin
  AddLog(Format('TSteamGameServer.OnGSPolicyResponse: secure (VAC) %d', [AData.m_bSecure]));
end;

procedure TSteamComponentTest.GSLoggedOn;
var
  G: TSteamGameServerPlugin;
  M: TSteamMatchmakingServers;
  Ident: SteamNetworkingIdentity;
  ServerID, Me: TSteamID;
  IP: UInt32;
  Call: SteamAPICall_t;
begin
  G := SteamGameServer1.Plugin;
  if G = nil then
  begin
    GSLogOnFailed('the game server plug-in is gone');
    Exit;
  end;
  try
    // What the server browser shows - on a server another test started
    // only the test's own rule
    if FServerStartedByTest then
    begin
      G.SetServerName('TSteamAPI test server');
      G.SetMapName('test_map');
      G.SetMaxPlayerCount(4);
      G.SetKeyValue('tsapi_kind', 'component test');
      G.SetAdvertiseServerActive(True);
    end;
    G.SetKeyValue(TEST_GS_RULE, '1');
    ServerID := G.GetSteamID;
    IP := G.PublicIPv4;
    AddLog(Format('Test TSteamGameServer: SteamID %s, secure %s, public IP %d.%d.%d.%d (GetPublicIP); name, map, ' +
      '4 players, rules %s = 1 and tsapi_kind set, advertised', [U64Str(ServerID.Value), BoolToStr(G.BSecure, True),
      (IP shr 24) and $FF, (IP shr 16) and $FF, (IP shr 8) and $FF, IP and $FF, TEST_GS_RULE]));
    // Our own server through the server browser (127.0.0.1, its query port)
    M := SteamMatchmakingServers1;
    if M.Plugin <> nil then
    begin
      FGSRuleCount := 0;
      FGSRuleSeen := False;
      FGSRulesQuery := M.StartServerRules(TEST_GS_LOCALHOST, FGSQueryPort);
      FGSPingQuery := M.StartPing(TEST_GS_LOCALHOST, FGSQueryPort);
      FGSPlayersQuery := M.StartPlayerDetails(TEST_GS_LOCALHOST, FGSQueryPort);
      AddLog(Format('Test TSteamGameServer: own server queried at 127.0.0.1:%d - rules %d, ping %d, players %d',
        [FGSQueryPort, FGSRulesQuery, FGSPingQuery, FGSPlayersQuery]));
      if FGSRulesQuery <> HSERVERQUERY_INVALID then
        Expect(CT_GAMESERVER, 'Rules (own server)');
      if FGSPingQuery <> HSERVERQUERY_INVALID then
        Expect(CT_GAMESERVER, 'Ping (own server)');
      if FGSPlayersQuery <> HSERVERQUERY_INVALID then
        Expect(CT_GAMESERVER, 'Players (own server)');
      if (FGSRulesQuery = HSERVERQUERY_INVALID) or (FGSPingQuery = HSERVERQUERY_INVALID) or
        (FGSPlayersQuery = HSERVERQUERY_INVALID) then
      begin
        FTests[CT_GAMESERVER].ReadsOK := False;
        AddNote(CT_GAMESERVER, 'a server-browser query of the own server was refused (invalid handle)');
      end;
    end;
    // Auth: the logged-on user's ticket for this server's identity
    if SteamUser1.Plugin <> nil then
    begin
      Me := SteamUser1.Plugin.GetSteamID;
      FillChar(Ident, SizeOf(Ident), 0);
      Ident.m_eType := k_ESteamNetworkingIdentityType_SteamID;
      Ident.m_cbSize := 8;
      Ident.m_steamID64 := ServerID.Value;
      SetLength(FGSTicketData, 2048);
      FGSTicketSize := 0;
      FGSTicket := SteamUser1.Plugin.GetAuthSessionTicket(@FGSTicketData[0], Length(FGSTicketData),
        FGSTicketSize, @Ident);
      if FGSTicket = k_HAuthTicketInvalid then
        AddNote(CT_GAMESERVER, 'GetAuthSessionTicket (for the server) gave no ticket')
      else
      begin
        AddLog(Format('Test TSteamGameServer: user %s asked for ticket %s (%d bytes) for the server - waiting ' +
          'for 163, then BeginAuthSession on the server', [U64Str(Me.Value), U64Str(FGSTicket), FGSTicketSize]));
        Expect(CT_GAMESERVER, 'GetAuthSessionTicket (for the server)');
      end;
    end;
  except
    on E: Exception do ReadFailed(CT_GAMESERVER, 'server set-up after log-on', E);
  end;
  // The rows that waited for the log-on
  if Answered(CT_GSSTATS, 'log-on') and (SteamGameServerStats1.Plugin <> nil) and (SteamUser1.Plugin <> nil) then
  try
    ExpectCall(CT_GSSTATS, 'RequestUserStats',
      SteamGameServerStats1.Plugin.RequestUserStats(SteamUser1.Plugin.GetSteamID));
  except
    on E: Exception do ReadFailed(CT_GSSTATS, 'RequestUserStats', E);
  end;
  if Answered(CT_GSSOCKETS, 'log-on') and (SteamGSSockets1.Plugin <> nil) then
  try
    FillChar(Ident, SizeOf(Ident), 0);
    if SteamGSSockets1.Plugin.GetIdentity(Ident) then
    begin
      AddLog(Format('Test TSteamGameServerNetworkingSockets: identity type %d, SteamID %s - %s the server',
        [Ord(Ident.m_eType), U64Str(Ident.m_steamID64), IfThen(Ident.m_steamID64 = G.GetSteamID.Value,
        'same as', 'DIFFERENT FROM')]));
      if Ident.m_steamID64 = G.GetSteamID.Value then
        AddNote(CT_GSSOCKETS, 'identity = the server''s SteamID')
      else
      begin
        FTests[CT_GSSOCKETS].ReadsOK := False;
        AddNote(CT_GSSOCKETS, 'identity is NOT the server''s SteamID');
      end;
    end
    else
      AddNote(CT_GSSOCKETS, 'GetIdentity False');
  except
    on E: Exception do ReadFailed(CT_GSSOCKETS, 'GetIdentity', E);
  end;
  if Answered(CT_GSUGC, 'log-on') and (SteamGSUGC1.Plugin <> nil) then
  try
    FGSUGCQuery := SteamGSUGC1.Plugin.CreateQueryAllUGCRequestPage(k_EUGCQuery_RankedByPublicationDate,
      k_EUGCMatchingUGCType_Items, FAppID, FAppID, 1);
    if FGSUGCQuery = k_UGCQueryHandleInvalid then
    begin
      FTests[CT_GSUGC].ReadsOK := False;
      AddNote(CT_GSUGC, 'CreateQueryAllUGCRequestPage: invalid handle');
    end
    else
    begin
      Call := SteamGSUGC1.Plugin.SendQueryUGCRequest(FGSUGCQuery);
      ExpectCall(CT_GSUGC, 'SendQueryUGCRequest', Call);
    end;
  except
    on E: Exception do ReadFailed(CT_GSUGC, 'Workshop query', E);
  end;
end;

procedure TSteamComponentTest.GSLogOnFailed(const AWhy: string);
begin
  if Answered(CT_GSSTATS, 'log-on') then
    AddNote(CT_GSSTATS, AWhy + ' - nothing requested');
  if Answered(CT_GSSOCKETS, 'log-on') then
    AddNote(CT_GSSOCKETS, AWhy + ' - identity not read');
  if Answered(CT_GSUGC, 'log-on') then
    AddNote(CT_GSUGC, AWhy + ' - no query sent');
end;

procedure TSteamComponentTest.GSAuthValidated(Sender: TObject; const AData: ValidateAuthTicketResponse_t);
begin
  AddLog(Format('TSteamGameServer.OnValidateAuthTicketResponse: user %s, response %d (0 = OK), owner %s',
    [U64Str(AData.m_SteamID.Value), Ord(AData.m_eAuthSessionResponse), U64Str(AData.m_OwnerSteamID.Value)]));
  // only OUR user: the pair test's guest may be validated by the same server
  if not FGSAuthBegun or (SteamUser1.Plugin = nil) or (AData.m_SteamID <> SteamUser1.Plugin.GetSteamID) or
    not Answered(CT_GAMESERVER, 'ValidateAuthTicketResponse') then
    Exit;
  if AData.m_eAuthSessionResponse = k_EAuthSessionResponseOK then
    AddNote(CT_GAMESERVER, 'the user''s ticket validated by the server')
  else
  begin
    AddNote(CT_GAMESERVER, Format('ticket NOT validated: response %d', [Ord(AData.m_eAuthSessionResponse)]));
    FTests[CT_GAMESERVER].ReadsOK := False;
  end;
  try
    if SteamGameServer1.Plugin <> nil then
      SteamGameServer1.Plugin.EndAuthSession(AData.m_SteamID);
    FGSAuthBegun := False;
    if (SteamUser1.Plugin <> nil) and (FGSTicket <> k_HAuthTicketInvalid) then
      SteamUser1.Plugin.CancelAuthTicket(FGSTicket);
    FGSTicket := k_HAuthTicketInvalid;
    AddLog('Test TSteamGameServer: EndAuthSession, ticket cancelled');
  except
    on E: Exception do ReadFailed(CT_GAMESERVER, 'EndAuthSession', E);
  end;
  CheckTestsDone;
end;

procedure TSteamComponentTest.GSStatsReceived(Sender: TObject; const AData: GSStatsReceived_t);
begin
  AddLog(Format('TSteamGameServerStats.OnGSStatsReceived: user %s, result %s',
    [U64Str(AData.m_steamIDUser.Value), ResultText(AData.m_eResult)]));
  if Answered(CT_GSSTATS, 'RequestUserStats') then
  begin
    AddNote(CT_GSSTATS, 'RequestUserStats ' + ResultText(AData.m_eResult));
    CheckTestsDone;
  end;
end;

procedure TSteamComponentTest.GSHTTPCompleted(Sender: TObject; const AData: HTTPRequestCompleted_t);
var
  H: TSteamHTTPPlugin;
begin
  AddLog(Format('TSteamGameServerHTTP.OnHTTPRequestCompleted: request %s, successful %s, HTTP status %d, %d bytes',
    [U64Str(AData.m_hRequest), BoolToStr(AData.m_bRequestSuccessful, True), Ord(AData.m_eStatusCode),
     AData.m_unBodySize]));
  if (AData.m_hRequest <> FGSHTTPRequest) or not Answered(CT_GSHTTP, 'SendHTTPRequest') then
    Exit;
  AddNote(CT_GSHTTP, Format('HTTP %d, %d bytes', [Ord(AData.m_eStatusCode), AData.m_unBodySize]));
  H := SteamGSHTTP1.Plugin;
  if H <> nil then
  try
    AddLog('Test TSteamGameServerHTTP: ReleaseHTTPRequest ' + BoolToStr(H.ReleaseHTTPRequest(FGSHTTPRequest), True));
  except
    on E: Exception do ReadFailed(CT_GSHTTP, 'ReleaseHTTPRequest', E);
  end;
  FGSHTTPRequest := 0;
  CheckTestsDone;
end;

procedure TSteamComponentTest.GSUGCQueryCompleted(Sender: TObject; const AData: SteamUGCQueryCompleted_t);
begin
  AddLog(Format('TSteamGameServerUGC.OnSteamUGCQueryCompleted: query %s, result %s, %d returned, %d matching',
    [U64Str(AData.m_handle), ResultText(AData.m_eResult), AData.m_unNumResultsReturned,
     AData.m_unTotalMatchingResults]));
  if (AData.m_handle <> FGSUGCQuery) or not Answered(CT_GSUGC, 'SendQueryUGCRequest') then
    Exit;
  AddNote(CT_GSUGC, Format('query %s, %d items', [ResultText(AData.m_eResult), AData.m_unTotalMatchingResults]));
  try
    if SteamGSUGC1.Plugin <> nil then
      AddLog('Test TSteamGameServerUGC: ReleaseQueryUGCRequest ' +
        BoolToStr(SteamGSUGC1.Plugin.ReleaseQueryUGCRequest(FGSUGCQuery), True));
  except
    on E: Exception do ReadFailed(CT_GSUGC, 'ReleaseQueryUGCRequest', E);
  end;
  FGSUGCQuery := k_UGCQueryHandleInvalid;
  CheckTestsDone;
end;

procedure TSteamComponentTest.GameServerCleanup;
var
  P: TSteamMatchmakingServersPlugin;
begin
  P := SteamMatchmakingServers1.Plugin;
  if P <> nil then
  begin
    // harmless for queries that have ended
    if FGSPingQuery <> HSERVERQUERY_INVALID then
      P.StopServerQuery(FGSPingQuery);
    if FGSPlayersQuery <> HSERVERQUERY_INVALID then
      P.StopServerQuery(FGSPlayersQuery);
    if FGSRulesQuery <> HSERVERQUERY_INVALID then
      P.StopServerQuery(FGSRulesQuery);
  end;
  if FGSAuthBegun and (SteamGameServer1.Plugin <> nil) and (SteamUser1.Plugin <> nil) then
  begin
    SteamGameServer1.Plugin.EndAuthSession(SteamUser1.Plugin.GetSteamID);
    AddLog('Test cleanup: server auth session ended (never validated)');
  end;
  if (FGSTicket <> k_HAuthTicketInvalid) and (SteamUser1.Plugin <> nil) then
  begin
    SteamUser1.Plugin.CancelAuthTicket(FGSTicket);
    AddLog('Test cleanup: ticket for the server ' + U64Str(FGSTicket) + ' cancelled');
  end;
  if (FGSHTTPRequest <> 0) and (SteamGSHTTP1.Plugin <> nil) then
    AddLog('Test cleanup: server ReleaseHTTPRequest (never completed): ' +
      BoolToStr(SteamGSHTTP1.Plugin.ReleaseHTTPRequest(FGSHTTPRequest), True));
  if (FGSUGCQuery <> k_UGCQueryHandleInvalid) and (SteamGSUGC1.Plugin <> nil) then
    AddLog('Test cleanup: server ReleaseQueryUGCRequest (never completed): ' +
      BoolToStr(SteamGSUGC1.Plugin.ReleaseQueryUGCRequest(FGSUGCQuery), True));
  if FUsingServer then
  begin
    FUsingServer := False;
    Dec(DemoGameServerUsers);
    if (DemoGameServerUsers <= 0) and SteamAPI1.IsGameServerRunning then
    begin
      DemoGameServerUsers := 0;
      if SteamGameServer1.Plugin <> nil then
      begin
        SteamGameServer1.Plugin.SetAdvertiseServerActive(False);
        SteamGameServer1.Plugin.LogOff;
      end;
      // From a handler (CheckTestsDone) the core finishes this after the callback
      SteamAPI1.StopGameServer;
      AddLog('Test cleanup: the listen server logged off and stopped (no test uses it any more)');
    end
    else if SteamAPI1.IsGameServerRunning then
    begin
      if SteamGameServer1.Plugin <> nil then
        SteamGameServer1.Plugin.SetKeyValue(TEST_GS_RULE, '');
      AddLog('Test cleanup: the listen server stays up - the pair test still uses it (our rule removed)');
    end;
  end;
end;

end.
