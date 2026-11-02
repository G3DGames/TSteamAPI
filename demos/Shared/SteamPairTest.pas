{ @abstract(The two-user test of the demos: two copies of SteamDemo, one per
  Steam account on two PCs, find each other through a lobby and test what
  needs a second user. No UI, compiles with Delphi and FPC.)

  Press Pair on both machines (the order does not matter). Each copy looks
  for a public lobby tagged @link(PAIR_KEY); the first one creates it
  (HOST), the second joins it (GUEST). Should both create one at the same
  moment, the copy with the higher SteamID leaves its own lobby and joins
  the other (it looks again every few seconds while alone). Once paired,
  every test runs on both copies at once, each in its own row:
  @unorderedList(
    @item(Lobby (Matchmaking): created / found / joined, two members,
      lobby data and member data read on the other side.)
    @item(Lobby chat: a text message each way.)
    @item(Friends: the other user's persona name, and rich presence set
      here and read there.)
    @item(Auth ticket (User): each sends its session ticket through the
      lobby chat, the other validates it with BeginAuthSession ->
      ValidateAuthTicketResponse.)
    @item(NetworkingMessages: host -> guest "ping", guest accepts the
      session and answers "pong".)
    @item(NetworkingSockets P2P: host listens (CreateListenSocketP2P),
      guest connects (ConnectP2P), host accepts, a message each way.)
    @item(Networking (old P2P packets): host -> guest, guest accepts the
      session and answers.)
    @item(Game server: the host starts a LISTEN server in its process
      (TSteamAPI.StartGameServer, ports @link(PAIR_GS_GAME_PORT) /
      @link(PAIR_GS_QUERY_PORT)), logs it on anonymously and sends its
      SteamID, public IP and query port; the guest makes a ticket for the
      server's identity and sends it; the SERVER validates it
      (BeginAuthSession -> 143 on the server's pipe) and the host reports
      the verdict back. The guest's rules query of the host's public
      address is informational only (NAT may block it).)
  )
  A row PASSES when its exchange completed on THIS copy; read both logs
  together. Everything is closed again at the end (lobby left, sessions,
  sockets, auth sessions, rich presence). The test creates its own
  components (owned by it) next to whatever the form has.

  Not covered: Remote Play Together (needs a Remote Play session), game
  invites through the overlay (need a user to click), Steam friends lists
  (the two accounts need not be friends). }
unit SteamPairTest;

{$ifdef FPC}
  {$mode delphi}{$H+}
{$endif}

interface

uses
  SysUtils, Classes, StrUtils,
  Steamworks.Types, Steamworks.SDKTypes, Steamworks.Callbacks, Steamworks.Core, Steamworks.Components,
  Steamworks.Plugin.User, Steamworks.Plugin.Friends, Steamworks.Plugin.Matchmaking,
  Steamworks.Plugin.Networking, Steamworks.Plugin.NetworkingSockets, Steamworks.Plugin.NetworkingMessages,
  Steamworks.Plugin.GameServer, Steamworks.Plugin.MatchmakingServers;

const
  { Pair test row: the lobby. }
  PT_LOBBY = 0;
  { Pair test row: lobby chat. }
  PT_CHAT = 1;
  { Pair test row: persona name + rich presence. }
  PT_FRIENDS = 2;
  { Pair test row: auth session ticket. }
  PT_AUTH = 3;
  { Pair test row: ISteamNetworkingMessages. }
  PT_MESSAGES = 4;
  { Pair test row: ISteamNetworkingSockets P2P. }
  PT_SOCKETS = 5;
  { Pair test row: ISteamNetworking (old P2P packets). }
  PT_P2P = 6;
  { Pair test row: the host's listen server authenticates the guest. }
  PT_SERVER = 7;
  { Number of pair test rows. }
  PT_COUNT = 8;
  { Row titles, indexed by the PT_ constants. }
  PairTestNames: array[0..PT_COUNT - 1] of string = ('Lobby (Matchmaking)', 'Lobby chat (Matchmaking)',
    'Persona + rich presence (Friends)', 'Auth ticket (User)', 'NetworkingMessages', 'NetworkingSockets P2P',
    'Networking (old P2P packets)', 'Game server (listen server + auth)');
  { Game port of the host's listen server (not the component test's 27115). }
  PAIR_GS_GAME_PORT = 27215;
  { Query port of the host's listen server. }
  PAIR_GS_QUERY_PORT = 27216;
  { Rule the host's server sets; the guest's rules query looks for it. }
  PAIR_GS_RULE = 'tsapi_pair';
  { Lobby data key that marks the test's lobby (with value @link(PAIR_VALUE)). }
  PAIR_KEY = 'tsteamapi_pair';
  { Value of @link(PAIR_KEY) - change it when the protocol changes, so old builds do not pair. }
  PAIR_VALUE = '1';
  { Waiting for the other copy gives up after this many milliseconds. }
  PAIR_WAIT_MS = 300000;
  { Once paired, every row must finish within this many milliseconds. }
  PAIR_TIMEOUT_MS = 60000;
  { While alone in its lobby a copy looks for another pair lobby this often. }
  PAIR_RESCAN_MS = 5000;
  { After the last row, the copy waits this long before closing everything,
    so the other copy still gets its last answers. }
  PAIR_GRACE_MS = 3000;
  { ISteamNetworkingMessages channel of the test. }
  PAIR_MSG_CHANNEL = 1;
  { ISteamNetworking channel of the test. }
  PAIR_P2P_CHANNEL = 2;
  { Virtual port of the NetworkingSockets P2P listen socket. }
  PAIR_SOCKET_PORT = 0;

type
  { A line for the log. }
  TPairTestLogEvent = procedure(const AText: string) of object;
  { Row AIndex (a PT_ constant) has new text. }
  TPairTestRowEvent = procedure(AIndex: Integer; const AText: string) of object;

  { Where the pairing stands. }
  TPairPhase = (ppIdle, ppSearching, ppCreating, ppJoining, ppWaiting, ppRunning, ppClosing);

  { State of one row. }
  TPairRowState = record
    { The row has its verdict. }
    Done: Boolean;
    { The verdict. }
    OK: Boolean;
    { Progress / result text. }
    Note: string;
  end;

  { The two-user test (see the unit description). Create it once per form;
    call @link(Start) from a button, @link(Tick) from a timer (1 s is
    enough), @link(Finish) before Steam is closed. }
  TSteamPairTest = class(TComponent)
  private
    { The root the components are linked to. }
    SteamAPI1: TCustomSteamAPI;
    { Components created and owned by the test. }
    FUser: TSteamUser;
    { See FUser. }
    FFriends: TSteamFriends;
    { See FUser. }
    FMatch: TSteamMatchmaking;
    { See FUser. }
    FP2P: TSteamNetworking;
    { See FUser. }
    FSockets: TSteamNetworkingSockets;
    { See FUser. }
    FMessages: TSteamNetworkingMessages;
    { See FUser (attaches while a game server runs). }
    FGS: TSteamGameServer;
    { See FUser. }
    FServers: TSteamMatchmakingServers;
    { Host: this test started the game server (it logs it on and names it). }
    FServerStarted: Boolean;
    { Host: this test counts in DemoGameServerUsers (the last user stops
      the server). }
    FUsingServer: Boolean;
    { Host: start the server on the next Tick (StartGameServer cannot be
      called from a callback handler, and Paired runs in one). }
    FServerStartDue: Boolean;
    { Host: SERVER was sent to the guest. }
    FServerAnnounced: Boolean;
    { Host: the server began an auth session for the guest. }
    FGSAuthBegun: Boolean;
    { Guest: the host's server (SteamID, public IPv4 host order, query port). }
    FServerID: TSteamID;
    { See FServerID. }
    FServerIP: UInt32;
    { See FServerID. }
    FServerQueryPort: Word;
    { Guest: our ticket for the host's server (k_HAuthTicketInvalid = none). }
    FGSTicket: HAuthTicket;
    { Its bytes (FGSTicketSize used). }
    FGSTicketBytes: TBytes;
    { See FGSTicketBytes. }
    FGSTicketSize: UInt32;
    { Guest: GSAUTH was sent. }
    FGSTicketSent: Boolean;
    { Guest: the rules query of the host's server (HSERVERQUERY_INVALID = none). }
    FRulesQuery: HServerQuery;
    { Guest: what the rules query reported so far. }
    FRulesNote: string;
    { Guest: @link(PAIR_GS_RULE) was among the rules. }
    FRuleSeen: Boolean;
    { Backing field of @link(OnLog). }
    FOnLog: TPairTestLogEvent;
    { Backing field of @link(OnRowChanged). }
    FOnRowChanged: TPairTestRowEvent;
    { Backing field of @link(OnFinished). }
    FOnFinished: TNotifyEvent;
    { Where the pairing stands. }
    FPhase: TPairPhase;
    { @true: this copy created the lobby. }
    FIsHost: Boolean;
    { This user. }
    FMe: TSteamID;
    { The other user (0 until paired). }
    FPeer: TSteamID;
    { The lobby (0 = none). }
    FLobby: TSteamID;
    { PairTicks of Start / of the pairing / of the last lobby search / when to close. }
    FStartTicks, FPairedTicks, FScanTicks, FCloseAt: UInt64;
    { A lobby search made while waiting (tie-break), not the first one. }
    FRescan: Boolean;
    { Rows. }
    FRows: array[0..PT_COUNT - 1] of TPairRowState;
    { Lobby: guest's member data seen (host) / host's lobby data seen (guest). }
    FLobbyDataSeen: Boolean;
    { Auth: our ticket, its handle and size; the peer's ticket was begun. }
    FTicket: TBytes;
    { See FTicket. }
    FTicketHandle: HAuthTicket;
    { See FTicket. }
    FTicketSize: UInt32;
    { See FTicket. }
    FAuthBegun: Boolean;
    { Rich presence value we set (and the one we expect from the peer). }
    FMyStatus, FPeerStatus: string;
    { NetworkingSockets: listen socket (host) and the connection (both). }
    FListen: HSteamListenSocket;
    { See FListen. }
    FConn: HSteamNetConnection;
    { NetworkingSockets: the guest sent its hello (once connected). }
    FSockHelloSent: Boolean;
    { Rich presence: when the peer's value was last requested (re-asked
      every @link(PAIR_RESCAN_MS) until it is read). }
    FPresenceTicks: UInt64;
    { We sent DONE (every row of ours has its verdict) at @code(FDoneTicks). }
    FDoneSent: Boolean;
    { See FDoneSent. }
    FDoneTicks: UInt64;
    { The peer sent DONE: it needs nothing more from us. }
    FPeerDone: Boolean;
    { Our ticket went out (Steam may confirm it twice). }
    FTicketSent: Boolean;
    { A NetworkingMessages / old P2P session request that came before we
      knew the peer (0 = none); accepted in Paired if it is the peer's. }
    FEarlyMsgPeer, FEarlyP2PPeer: UInt64;
    { Sends a line to OnLog. }
    procedure AddLog(const S: string);
    { Sets a row's note (and shows it). }
    procedure RowNote(AIndex: Integer; const ANote: string);
    { Gives a row its verdict (once). }
    procedure RowDone(AIndex: Integer; AOK: Boolean; const ANote: string);
    { Shows a row. }
    procedure ShowRow(AIndex: Integer);
    { Starts a lobby search (first search or tie-break). }
    procedure SearchLobbies(ARescan: Boolean);
    { Both copies are in the lobby: start every test. }
    procedure Paired;
    { Sends "TSAPI|ACmd|AArg" through the lobby chat. @returns(SendLobbyChatMsg's answer.) }
    function SendChat(const ACmd, AArg: string): Boolean;
    { A chat line from the peer. }
    procedure ChatFromPeer(const ACmd, AArg: string);
    { Our auth ticket is ready: send it. }
    procedure SendTicket;
    { Polls NetworkingMessages, sockets and old P2P for incoming data. }
    procedure Poll;
    { Ends the test when every row is done. }
    procedure CheckDone;
    { The identity of AUser as a SteamNetworkingIdentity. }
    function IdentityOf(const AUser: TSteamID): SteamNetworkingIdentity;
    { Component events (wired in the constructor). }
    procedure LobbyMatchList(Sender: TObject; const AData: LobbyMatchList_t);
    { See LobbyMatchList. }
    procedure LobbyCreated(Sender: TObject; const AData: LobbyCreated_t);
    { See LobbyMatchList. }
    procedure LobbyEnter(Sender: TObject; const AData: LobbyEnter_t);
    { See LobbyMatchList. }
    procedure LobbyChatUpdate(Sender: TObject; const AData: LobbyChatUpdate_t);
    { See LobbyMatchList. }
    procedure LobbyDataUpdate(Sender: TObject; const AData: LobbyDataUpdate_t);
    { See LobbyMatchList. }
    procedure LobbyChatMsg(Sender: TObject; const AData: LobbyChatMsg_t);
    { See LobbyMatchList. }
    procedure RichPresenceUpdate(Sender: TObject; const AData: FriendRichPresenceUpdate_t);
    { See LobbyMatchList. }
    procedure AuthTicketReady(Sender: TObject; const AData: GetAuthSessionTicketResponse_t);
    { See LobbyMatchList. }
    procedure AuthValidated(Sender: TObject; const AData: ValidateAuthTicketResponse_t);
    { See LobbyMatchList. }
    procedure MessagesSessionRequest(Sender: TObject; const AData: SteamNetworkingMessagesSessionRequest_t);
    { See LobbyMatchList. }
    procedure MessagesSessionFailed(Sender: TObject; const AData: SteamNetworkingMessagesSessionFailed_t);
    { See LobbyMatchList. }
    procedure SocketStatus(Sender: TObject; const AData: SteamNetConnectionStatusChangedCallback_t);
    { See LobbyMatchList. }
    procedure P2PSessionRequest(Sender: TObject; const AData: P2PSessionRequest_t);
    { See LobbyMatchList. }
    procedure P2PSessionFailed(Sender: TObject; const AData: P2PSessionConnectFail_t);
    { Host: starts the listen server (unless one runs) and logs it on. }
    procedure StartServerForPeer;
    { Host: the server is logged on - rules set, SERVER sent to the guest. }
    procedure ServerReady;
    { FGS.OnSteamServersConnected (101, server pipe). }
    procedure GSConnected(Sender: TObject; const AData: SteamServersConnected_t);
    { FGS.OnSteamServerConnectFailure (102, server pipe). }
    procedure GSConnectFailure(Sender: TObject; const AData: SteamServerConnectFailure_t);
    { FGS.OnValidateAuthTicketResponse (143, server pipe): the guest's ticket. }
    procedure GSAuthValidated(Sender: TObject; const AData: ValidateAuthTicketResponse_t);
    { FServers.OnRule: a rule of the host's server. }
    procedure ServerRule(Sender: TObject; AQuery: HServerQuery; const ARule, AValue: string);
    { FServers.OnRulesComplete. }
    procedure ServerRulesComplete(Sender: TObject; AQuery: HServerQuery);
    { FServers.OnRulesFailed. }
    procedure ServerRulesFailed(Sender: TObject; AQuery: HServerQuery);
    { Read accessor of @link(RowText). }
    function GetRowText(AIndex: Integer): string;
  public
    { Creates the six components it uses, owned by the test and linked to ASteamAPI. }
    constructor Create(AOwner: TComponent; ASteamAPI: TCustomSteamAPI); reintroduce;
    { Looks for the other copy (or waits for it). Steam must be running. }
    procedure Start;
    { Call about once a second: polls for data, times out, ends the test. }
    procedure Tick;
    { Ends the test now and closes everything (only while Steam runs).
      AReason is logged when not ''. }
    procedure Finish(const AReason: string);
    { @true from Start until Finish. }
    function Running: Boolean;
    { Text of row AIndex (a PT_ constant). }
    property RowText[AIndex: Integer]: string read GetRowText;
    { Every log line of the test. }
    property OnLog: TPairTestLogEvent read FOnLog write FOnLog;
    { A row changed. }
    property OnRowChanged: TPairTestRowEvent read FOnRowChanged write FOnRowChanged;
    { The test ended. }
    property OnFinished: TNotifyEvent read FOnFinished write FOnFinished;
  end;

implementation

uses
  SteamComponentTest;   // DemoGameServerUsers: the game server both tests may share

const
  { Prefix of every chat line of the test. }
  CHAT_PREFIX = 'TSAPI|';
  { Payloads of the data exchanges. }
  MSG_PING = 'TSteamAPI pair test: NetworkingMessages ping';
  MSG_PONG = 'TSteamAPI pair test: NetworkingMessages pong';
  SOCK_HELLO = 'TSteamAPI pair test: socket hello';
  SOCK_REPLY = 'TSteamAPI pair test: socket reply';
  P2P_PING = 'TSteamAPI pair test: P2P packet ping';
  P2P_PONG = 'TSteamAPI pair test: P2P packet pong';

{ Milliseconds since some start point (both compilers). }
function PairTicks: UInt64;
begin
{$ifdef FPC}
  Result := GetTickCount64;
{$else}
  Result := TThread.GetTickCount64;
{$endif}
end;

{ The UTF-8 bytes of S (no terminating NUL). }
function Utf8Of(const S: string): TBytes;
var
  U: UTF8String;
begin
  U := UTF8String(S);
  Result := nil;
  SetLength(Result, Length(U));
  if Length(U) > 0 then
    Move(U[1], Result[0], Length(U));
end;

{ ACount bytes at P as UTF-8 text. }
function TextOf(P: Pointer; ACount: Integer): string;
var
  U: UTF8String;
begin
  if (P = nil) or (ACount <= 0) then
    Exit('');
  SetLength(U, ACount);
  Move(P^, U[1], ACount);
  Result := string(U);
end;

{ Bytes as hex text. }
function HexOf(const B: TBytes; ACount: Integer): string;
const
  Digits: array[0..15] of Char = ('0', '1', '2', '3', '4', '5', '6', '7', '8', '9', 'A', 'B', 'C', 'D', 'E', 'F');
var
  I: Integer;
begin
  Result := '';
  for I := 0 to ACount - 1 do
    Result := Result + Digits[B[I] shr 4] + Digits[B[I] and 15];
end;

{ Hex text as bytes (stops at the first non-hex pair). }
function BytesOfHex(const S: string): TBytes;
var
  I, N, V: Integer;
begin
  Result := nil;
  SetLength(Result, Length(S) div 2);
  N := 0;
  for I := 0 to Length(S) div 2 - 1 do
  begin
    if not TryStrToInt('$' + Copy(S, I * 2 + 1, 2), V) then
      Break;
    Result[I] := Byte(V);
    Inc(N);
  end;
  SetLength(Result, N);
end;

{ An unsigned 64-bit number as text (both compilers). }
function U64Text(AValue: UInt64): string;
begin
{$ifdef FPC}
  Result := IntToStr(AValue);
{$else}
  Result := UIntToStr(AValue);
{$endif}
end;

{ Length of a NUL-terminated C string in a fixed buffer (at most AMax). }
function CLen(P: PAnsiChar; AMax: Integer): Integer;
begin
  Result := 0;
  while (Result < AMax) and (P[Result] <> #0) do
    Inc(Result);
end;

{ A SteamID as text (both compilers). }
function IDText(const AID: TSteamID): string;
begin
  Result := AID.ToString;
end;

{ TSteamPairTest }

constructor TSteamPairTest.Create(AOwner: TComponent; ASteamAPI: TCustomSteamAPI);
var
  I: Integer;
begin
  inherited Create(AOwner);
  SteamAPI1 := ASteamAPI;
  FListen := k_HSteamListenSocket_Invalid;
  FConn := k_HSteamNetConnection_Invalid;
  for I := 0 to PT_COUNT - 1 do
    FRows[I].Note := 'not run - press Pair on BOTH machines (two Steam accounts, see docs/TestSetup.md)';
  FUser := TSteamUser.Create(Self);
  FUser.Name := 'PairUser';
  FUser.OnGetAuthSessionTicketResponse := AuthTicketReady;
  FUser.OnValidateAuthTicketResponse := AuthValidated;
  FUser.SteamAPI := ASteamAPI;
  FFriends := TSteamFriends.Create(Self);
  FFriends.Name := 'PairFriends';
  FFriends.OnFriendRichPresenceUpdate := RichPresenceUpdate;
  FFriends.SteamAPI := ASteamAPI;
  FMatch := TSteamMatchmaking.Create(Self);
  FMatch.Name := 'PairMatchmaking';
  FMatch.OnLobbyMatchList := LobbyMatchList;
  FMatch.OnLobbyCreated := LobbyCreated;
  FMatch.OnLobbyEnter := LobbyEnter;
  FMatch.OnLobbyChatUpdate := LobbyChatUpdate;
  FMatch.OnLobbyDataUpdate := LobbyDataUpdate;
  FMatch.OnLobbyChatMsg := LobbyChatMsg;
  FMatch.SteamAPI := ASteamAPI;
  FP2P := TSteamNetworking.Create(Self);
  FP2P.Name := 'PairNetworking';
  FP2P.OnP2PSessionRequest := P2PSessionRequest;
  FP2P.OnP2PSessionConnectFail := P2PSessionFailed;
  FP2P.SteamAPI := ASteamAPI;
  FSockets := TSteamNetworkingSockets.Create(Self);
  FSockets.Name := 'PairSockets';
  FSockets.OnSteamNetConnectionStatusChangedCallback := SocketStatus;
  FSockets.SteamAPI := ASteamAPI;
  FMessages := TSteamNetworkingMessages.Create(Self);
  FMessages.Name := 'PairMessages';
  FMessages.OnSteamNetworkingMessagesSessionRequest := MessagesSessionRequest;
  FMessages.OnSteamNetworkingMessagesSessionFailed := MessagesSessionFailed;
  FMessages.SteamAPI := ASteamAPI;
  FGS := TSteamGameServer.Create(Self);
  FGS.Name := 'PairGameServer';
  FGS.OnSteamServersConnected := GSConnected;
  FGS.OnSteamServerConnectFailure := GSConnectFailure;
  FGS.OnValidateAuthTicketResponse := GSAuthValidated;
  FGS.SteamAPI := ASteamAPI;
  FServers := TSteamMatchmakingServers.Create(Self);
  FServers.Name := 'PairServers';
  FServers.OnRule := ServerRule;
  FServers.OnRulesComplete := ServerRulesComplete;
  FServers.OnRulesFailed := ServerRulesFailed;
  FServers.SteamAPI := ASteamAPI;
  FGSTicket := k_HAuthTicketInvalid;
  FRulesQuery := HSERVERQUERY_INVALID;
end;

procedure TSteamPairTest.AddLog(const S: string);
begin
  if Assigned(FOnLog) then
    FOnLog('Pair test: ' + S);
end;

function TSteamPairTest.GetRowText(AIndex: Integer): string;
begin
  Result := '';
  if (AIndex < 0) or (AIndex >= PT_COUNT) then
    Exit;
  if FRows[AIndex].Done then
    Result := IfThen(FRows[AIndex].OK, 'PASS - ', 'FAIL - ') + FRows[AIndex].Note
  else
    Result := FRows[AIndex].Note;
end;

procedure TSteamPairTest.ShowRow(AIndex: Integer);
begin
  if Assigned(FOnRowChanged) then
    FOnRowChanged(AIndex, GetRowText(AIndex));
end;

procedure TSteamPairTest.RowNote(AIndex: Integer; const ANote: string);
begin
  if FRows[AIndex].Done then
    Exit;
  FRows[AIndex].Note := ANote;
  ShowRow(AIndex);
end;

procedure TSteamPairTest.RowDone(AIndex: Integer; AOK: Boolean; const ANote: string);
begin
  if FRows[AIndex].Done then
    Exit;
  FRows[AIndex].Done := True;
  FRows[AIndex].OK := AOK;
  FRows[AIndex].Note := ANote;
  AddLog(Format('%s: %s - %s', [PairTestNames[AIndex], IfThen(AOK, 'PASS', 'FAIL'), ANote]));
  ShowRow(AIndex);
  CheckDone;
end;

function TSteamPairTest.Running: Boolean;
begin
  Result := FPhase <> ppIdle;
end;

function TSteamPairTest.IdentityOf(const AUser: TSteamID): SteamNetworkingIdentity;
begin
  FillChar(Result, SizeOf(Result), 0);
  Result.m_eType := k_ESteamNetworkingIdentityType_SteamID;
  Result.m_cbSize := 8;
  Result.m_steamID64 := AUser.Value;
end;

procedure TSteamPairTest.Start;
var
  I: Integer;
begin
  if not SteamAPI1.IsRunning then
  begin
    AddLog('Steam is not running - press Start first');
    Exit;
  end;
  if Running then
    Finish('restarted by Pair');
  if (FUser.Plugin = nil) or (FMatch.Plugin = nil) or (FFriends.Plugin = nil) or (FP2P.Plugin = nil) or
    (FSockets.Plugin = nil) or (FMessages.Plugin = nil) then
  begin
    AddLog('a plug-in is not active (User, Friends, Matchmaking, Networking, NetworkingSockets, NetworkingMessages)');
    Exit;
  end;
  for I := 0 to PT_COUNT - 1 do
  begin
    FRows[I].Done := False;
    FRows[I].OK := False;
    FRows[I].Note := 'waiting for the other copy ...';
    ShowRow(I);
  end;
  FMe := FUser.Plugin.GetSteamID;
  FPeer := TSteamID.Create(0);
  FLobby := TSteamID.Create(0);
  FIsHost := False;
  FLobbyDataSeen := False;
  FTicket := nil;
  FTicketHandle := k_HAuthTicketInvalid;
  FTicketSize := 0;
  FAuthBegun := False;
  FServerStarted := False;
  FUsingServer := False;
  FServerStartDue := False;
  FServerAnnounced := False;
  FGSAuthBegun := False;
  FServerID := TSteamID.Create(0);
  FServerIP := 0;
  FServerQueryPort := 0;
  FGSTicket := k_HAuthTicketInvalid;
  FGSTicketBytes := nil;
  FGSTicketSize := 0;
  FGSTicketSent := False;
  FRulesQuery := HSERVERQUERY_INVALID;
  FRulesNote := '';
  FRuleSeen := False;
  FListen := k_HSteamListenSocket_Invalid;
  FConn := k_HSteamNetConnection_Invalid;
  FSockHelloSent := False;
  FPresenceTicks := 0;
  FMyStatus := '';
  FPeerStatus := '';
  FDoneSent := False;
  FDoneTicks := 0;
  FPeerDone := False;
  FTicketSent := False;
  FEarlyMsgPeer := 0;
  FEarlyP2PPeer := 0;
  FCloseAt := 0;
  FStartTicks := PairTicks;
  AddLog(Format('started as %s (%s); looking for the other copy''s lobby (%s = %s)',
    [FFriends.Plugin.GetPersonaName, IDText(FMe), PAIR_KEY, PAIR_VALUE]));
  SearchLobbies(False);
end;

procedure TSteamPairTest.SearchLobbies(ARescan: Boolean);
var
  Call: SteamAPICall_t;
begin
  FRescan := ARescan;
  FScanTicks := PairTicks;
  FMatch.Plugin.AddRequestLobbyListStringFilter(PAIR_KEY, PAIR_VALUE, k_ELobbyComparisonEqual);
  FMatch.Plugin.AddRequestLobbyListDistanceFilter(k_ELobbyDistanceFilterWorldwide);
  FMatch.Plugin.AddRequestLobbyListResultCountFilter(10);
  Call := FMatch.Plugin.RequestLobbyList;
  if not ARescan then
  begin
    FPhase := ppSearching;
    AddLog(Format('RequestLobbyList sent (call %s)', [U64Text(Call)]));
  end;
end;

procedure TSteamPairTest.LobbyMatchList(Sender: TObject; const AData: LobbyMatchList_t);
var
  I: Integer;
  L, Host, Best: TSteamID;
  HostID: UInt64;
  Code: Integer;
  S: string;
begin
  // Steam posts 510 twice (call result + callback): act on the first only
  if not ((FPhase = ppSearching) or ((FPhase = ppWaiting) and FRescan)) then
    Exit;
  Best := TSteamID.Create(0);
  for I := 0 to Integer(AData.m_nLobbiesMatching) - 1 do
  begin
    L := FMatch.Plugin.GetLobbyByIndex(I);
    if L = FLobby then
      Continue;   // our own
    // the component test's RequestLobbyList answers here too (same 510)
    if FMatch.Plugin.GetLobbyData(L, PAIR_KEY) <> PAIR_VALUE then
      Continue;
    S := FMatch.Plugin.GetLobbyData(L, 'host');
    Val(S, HostID, Code);
    if (Code <> 0) or (HostID = 0) then
      Continue;
    Host := TSteamID.Create(HostID);
    if Host = FMe then
      Continue;   // a lobby of ours left over from an earlier run
    if FRescan and (Host.Value > FMe.Value) then
      Continue;   // tie-break: the copy with the higher SteamID joins the other
    Best := L;
    Break;
  end;
  if FPhase = ppWaiting then
  begin
    FRescan := False;
    if Best.Value = 0 then
      Exit;
    AddLog(Format('both copies created a lobby: leaving ours (%s), joining %s', [IDText(FLobby), IDText(Best)]));
    FMatch.Plugin.LeaveLobby(FLobby);
    FLobby := TSteamID.Create(0);
    FPhase := ppJoining;
    FMatch.Plugin.JoinLobby(Best);
    Exit;
  end;
  if Best.Value <> 0 then
  begin
    AddLog(Format('%d pair lobby(s) found; joining %s (host %s)', [AData.m_nLobbiesMatching, IDText(Best),
      FMatch.Plugin.GetLobbyData(Best, 'host_name')]));
    FPhase := ppJoining;
    FMatch.Plugin.JoinLobby(Best);
  end
  else
  begin
    AddLog('no pair lobby found - creating one (public, 2 members) and waiting for the other copy');
    FPhase := ppCreating;
    FMatch.Plugin.CreateLobby(k_ELobbyTypePublic, 2);
  end;
end;

procedure TSteamPairTest.LobbyCreated(Sender: TObject; const AData: LobbyCreated_t);
begin
  if FPhase <> ppCreating then
    Exit;
  if AData.m_eResult <> k_EResultOK then
  begin
    RowDone(PT_LOBBY, False, Format('CreateLobby failed: result %d', [Ord(AData.m_eResult)]));
    Finish('no lobby');
    Exit;
  end;
  FLobby := TSteamID.Create(AData.m_ulSteamIDLobby);
  FIsHost := True;
  FMatch.Plugin.SetLobbyData(FLobby, PAIR_KEY, PAIR_VALUE);
  FMatch.Plugin.SetLobbyData(FLobby, 'host', U64Text(FMe.Value));
  FMatch.Plugin.SetLobbyData(FLobby, 'host_name', FFriends.Plugin.GetPersonaName);
  FPhase := ppWaiting;
  FScanTicks := PairTicks;
  AddLog(Format('lobby %s created, lobby data set - HOST, waiting for the guest (press Pair on the other machine)',
    [IDText(FLobby)]));
  RowNote(PT_LOBBY, 'lobby created - waiting for the other copy (press Pair there)');
end;

procedure TSteamPairTest.LobbyEnter(Sender: TObject; const AData: LobbyEnter_t);
var
  HostID: UInt64;
  Code: Integer;
begin
  if FPhase <> ppJoining then
    Exit;   // the creator gets 504 too: handled by LobbyCreated
  if AData.m_EChatRoomEnterResponse <> UInt32(Ord(k_EChatRoomEnterResponseSuccess)) then
  begin
    RowDone(PT_LOBBY, False, Format('JoinLobby failed: enter response %d', [AData.m_EChatRoomEnterResponse]));
    Finish('could not join');
    Exit;
  end;
  FLobby := TSteamID.Create(AData.m_ulSteamIDLobby);
  FIsHost := False;
  Val(FMatch.Plugin.GetLobbyData(FLobby, 'host'), HostID, Code);
  if (Code <> 0) or (HostID = 0) then
    FPeer := FMatch.Plugin.GetLobbyOwner(FLobby)
  else
    FPeer := TSteamID.Create(HostID);
  FMatch.Plugin.SetLobbyMemberData(FLobby, 'guest_name', FFriends.Plugin.GetPersonaName);
  AddLog(Format('joined lobby %s - GUEST; host %s "%s", %d member(s), lobby data host_name "%s"',
    [IDText(FLobby), IDText(FPeer), FFriends.Plugin.GetFriendPersonaName(FPeer),
     FMatch.Plugin.GetNumLobbyMembers(FLobby), FMatch.Plugin.GetLobbyData(FLobby, 'host_name')]));
  FLobbyDataSeen := FMatch.Plugin.GetLobbyData(FLobby, 'host_name') <> '';
  Paired;
end;

procedure TSteamPairTest.LobbyChatUpdate(Sender: TObject; const AData: LobbyChatUpdate_t);
begin
  if (AData.m_ulSteamIDLobby <> FLobby.Value) or (AData.m_ulSteamIDUserChanged = FMe.Value) then
    Exit;
  AddLog(Format('lobby member %s: state change $%x', [U64Text(AData.m_ulSteamIDUserChanged),
    AData.m_rgfChatMemberStateChange]));
  if (FPhase = ppWaiting) and ((AData.m_rgfChatMemberStateChange and k_EChatMemberStateChangeEntered) <> 0) then
  begin
    FPeer := TSteamID.Create(AData.m_ulSteamIDUserChanged);
    AddLog(Format('the guest %s "%s" entered; %d member(s)', [IDText(FPeer),
      FFriends.Plugin.GetFriendPersonaName(FPeer), FMatch.Plugin.GetNumLobbyMembers(FLobby)]));
    Paired;
  end
  else if (FPhase = ppRunning) and (AData.m_ulSteamIDUserChanged = FPeer.Value) and
    ((AData.m_rgfChatMemberStateChange and (k_EChatMemberStateChangeLeft or k_EChatMemberStateChangeDisconnected or
    k_EChatMemberStateChangeKicked or k_EChatMemberStateChangeBanned)) <> 0) and (FCloseAt = 0) then
    // The peer closes only after our DONE, so this is a copy that stopped
    // or crashed: no need to wait for the timeouts
    Finish('the other copy left the lobby before both were done');
end;

procedure TSteamPairTest.LobbyDataUpdate(Sender: TObject; const AData: LobbyDataUpdate_t);
var
  S: string;
begin
  if (FPhase <> ppRunning) or not FIsHost or (AData.m_ulSteamIDLobby <> FLobby.Value) or
    (AData.m_ulSteamIDMember <> FPeer.Value) or FLobbyDataSeen then
    Exit;
  S := FMatch.Plugin.GetLobbyMemberData(FLobby, FPeer, 'guest_name');
  if S <> '' then
  begin
    FLobbyDataSeen := True;
    RowDone(PT_LOBBY, True, Format('HOST: lobby created, guest "%s" joined (%d members), its member data read',
      [S, FMatch.Plugin.GetNumLobbyMembers(FLobby)]));
  end;
end;

procedure TSteamPairTest.Paired;
var
  Ident: SteamNetworkingIdentity;
  Res: EResult;
  Data: TBytes;
  Buf: array[0..2047] of Byte;
  Size: UInt32;
  OK: Boolean;
begin
  FPhase := ppRunning;
  FPairedTicks := PairTicks;
  AddLog(Format('PAIRED as %s with %s - running every test', [IfThen(FIsHost, 'HOST', 'GUEST'), IDText(FPeer)]));
  // Lobby: the guest has read the host's lobby data already; the host
  // waits for the guest's member data (LobbyDataUpdate) - or has it
  if FIsHost then
  begin
    RowNote(PT_LOBBY, 'guest joined - waiting for its member data');
    if FMatch.Plugin.GetLobbyMemberData(FLobby, FPeer, 'guest_name') <> '' then
    begin
      FLobbyDataSeen := True;
      RowDone(PT_LOBBY, True, Format('HOST: lobby created, guest "%s" joined (%d members), its member data read',
        [FMatch.Plugin.GetLobbyMemberData(FLobby, FPeer, 'guest_name'), FMatch.Plugin.GetNumLobbyMembers(FLobby)]));
    end;
  end
  else
    RowDone(PT_LOBBY, FLobbyDataSeen, Format('GUEST: lobby found (RequestLobbyList + filter) and joined, %d members, ' +
      'lobby data host_name "%s"', [FMatch.Plugin.GetNumLobbyMembers(FLobby),
      FMatch.Plugin.GetLobbyData(FLobby, 'host_name')]));
  // Session requests that came before we knew the peer
  if (FEarlyMsgPeer <> 0) and (FEarlyMsgPeer = FPeer.Value) then
  begin
    Ident := IdentityOf(FPeer);
    AddLog('NetworkingMessages: accepting the peer''s earlier session request: ' +
      BoolToStr(FMessages.Plugin.AcceptSessionWithUser(@Ident), True));
  end;
  if (FEarlyP2PPeer <> 0) and (FEarlyP2PPeer = FPeer.Value) then
    AddLog('Networking: accepting the peer''s earlier P2P session request: ' +
      BoolToStr(FP2P.Plugin.AcceptP2PSessionWithUser(FPeer), True));
  // Friends: rich presence is set BEFORE the HELLO, and the peer's value
  // is requested when its HELLO arrives (and again in Poll): for a
  // non-friend Steam answers each request once and pushes no updates
  FMyStatus := 'TSteamAPI pair test ' + IDText(FMe);
  FPeerStatus := 'TSteamAPI pair test ' + IDText(FPeer);
  // SetRichPresence's result and the value read back are logged: when the
  // PEER never sees ours, this side's log says whether Steam took it (a
  // new limited account - no purchase, level 0 - may not publish it to
  // non-friends; the test is then worth a run with the two as friends)
  OK := FFriends.Plugin.SetRichPresence('status', FMyStatus);
  AddLog(Format('Friends: SetRichPresence("status") -> %s; read back "%s"',
    [BoolToStr(OK, True), FFriends.Plugin.GetFriendRichPresence(FMe, 'status')]));
  FFriends.Plugin.RequestFriendRichPresence(FPeer);
  FPresenceTicks := PairTicks;
  if OK then
    RowNote(PT_FRIENDS, Format('peer persona "%s"; rich presence set, the peer''s requested ' +
      '(not friends: a limited new account may never show it - try as friends)',
      [FFriends.Plugin.GetFriendPersonaName(FPeer)]))
  else
    RowNote(PT_FRIENDS, Format('peer persona "%s"; SetRichPresence returned False here, the peer''s requested',
      [FFriends.Plugin.GetFriendPersonaName(FPeer)]));
  // Lobby chat
  if SendChat('HELLO', FFriends.Plugin.GetPersonaName) then
    RowNote(PT_CHAT, 'HELLO sent - waiting for the other''s')
  else
    RowDone(PT_CHAT, False, 'SendLobbyChatMsg returned False');
  // Auth: a ticket for the peer (its identity, as the 1.65 docs ask for
  // P2P); sent once Steam confirms it (163)
  Size := 0;
  Ident := IdentityOf(FPeer);
  FTicketHandle := FUser.Plugin.GetAuthSessionTicket(@Buf[0], SizeOf(Buf), Size, @Ident);
  FTicketSize := Size;
  SetLength(FTicket, Size);
  if Size > 0 then
    Move(Buf[0], FTicket[0], Size);
  if FTicketHandle = k_HAuthTicketInvalid then
    RowDone(PT_AUTH, False, 'GetAuthSessionTicket returned no ticket')
  else
    RowNote(PT_AUTH, Format('ticket %d (%d bytes) asked for - waiting for Steam''s confirmation (163)',
      [FTicketHandle, Size]));
  // Host starts the data exchanges; the guest answers
  if FIsHost then
  begin
    Ident := IdentityOf(FPeer);
    Data := Utf8Of(MSG_PING);
    Res := FMessages.Plugin.SendMessageToUser(@Ident, @Data[0], Length(Data), k_nSteamNetworkingSend_Reliable,
      PAIR_MSG_CHANNEL);
    AddLog(Format('NetworkingMessages: SendMessageToUser(ping, channel %d) -> %d', [PAIR_MSG_CHANNEL, Ord(Res)]));
    if Res = k_EResultOK then
      RowNote(PT_MESSAGES, 'ping sent - waiting for pong')
    else
      RowDone(PT_MESSAGES, False, Format('SendMessageToUser returned %d', [Ord(Res)]));
    FListen := FSockets.Plugin.CreateListenSocketP2P(PAIR_SOCKET_PORT, 0, nil);
    if FListen = k_HSteamListenSocket_Invalid then
      RowDone(PT_SOCKETS, False, 'CreateListenSocketP2P failed')
    else
    begin
      AddLog(Format('NetworkingSockets: listen socket %u on virtual port %d - telling the guest',
        [FListen, PAIR_SOCKET_PORT]));
      SendChat('LISTEN', IntToStr(PAIR_SOCKET_PORT));
      RowNote(PT_SOCKETS, 'listening - waiting for the guest to connect');
    end;
    Data := Utf8Of(P2P_PING);
    if FP2P.Plugin.SendP2PPacket(FPeer, @Data[0], Length(Data), k_EP2PSendReliable, PAIR_P2P_CHANNEL) then
      RowNote(PT_P2P, 'packet sent - waiting for the answer')
    else
      RowDone(PT_P2P, False, 'SendP2PPacket returned False');
  end
  else
  begin
    RowNote(PT_MESSAGES, 'waiting for the host''s ping');
    RowNote(PT_SOCKETS, 'waiting for the host''s listen socket');
    RowNote(PT_P2P, 'waiting for the host''s packet');
    RowNote(PT_SERVER, 'waiting for the host''s game server');
  end;
  if FIsHost then
  begin
    FServerStartDue := True;   // next Tick: Paired runs inside a callback handler
    RowNote(PT_SERVER, 'starting the listen server on the next tick');
  end;
end;

function TSteamPairTest.SendChat(const ACmd, AArg: string): Boolean;
var
  Data: TBytes;
begin
  Data := Utf8Of(CHAT_PREFIX + ACmd + '|' + AArg);
  Result := FMatch.Plugin.SendLobbyChatMsg(FLobby, @Data[0], Length(Data));
end;

procedure TSteamPairTest.LobbyChatMsg(Sender: TObject; const AData: LobbyChatMsg_t);
var
  Buf: array[0..4095] of Byte;
  User: TSteamID;
  EntryType: EChatEntryType;
  N, P: Integer;
  S, Cmd: string;
begin
  if (FPhase <> ppRunning) or (AData.m_ulSteamIDLobby <> FLobby.Value) then
    Exit;
  User := TSteamID.Create(0);
  EntryType := k_EChatEntryTypeChatMsg;
  N := FMatch.Plugin.GetLobbyChatEntry(FLobby, Integer(AData.m_iChatID), User, @Buf[0], SizeOf(Buf), EntryType);
  if (User <> FPeer) or (N <= 0) then
    Exit;   // our own lines come back too
  S := TextOf(@Buf[0], N);
  if Copy(S, 1, Length(CHAT_PREFIX)) <> CHAT_PREFIX then
    Exit;
  Delete(S, 1, Length(CHAT_PREFIX));
  P := Pos('|', S);
  if P = 0 then
    Exit;
  Cmd := Copy(S, 1, P - 1);
  ChatFromPeer(Cmd, Copy(S, P + 1, MaxInt));
end;

procedure TSteamPairTest.ChatFromPeer(const ACmd, AArg: string);
var
  Parts: TStringList;
  ID64: UInt64;
  Code: Integer;
  Ticket: TBytes;
  Res: EBeginAuthSessionResult;
  Ident: SteamNetworkingIdentity;
begin
  if ACmd = 'HELLO' then
  begin
    RowDone(PT_CHAT, True, Format('HELLO sent, the other''s received ("%s")', [AArg]));
    // the peer set its rich presence before sending HELLO
    if not FRows[PT_FRIENDS].Done then
    begin
      FFriends.Plugin.RequestFriendRichPresence(FPeer);
      FPresenceTicks := PairTicks;
    end;
  end
  else if (ACmd = 'SERVER') and not FIsHost then
  begin
    // "<server SteamID>,<public IPv4 host order>,<query port>"
    Parts := TStringList.Create;
    try
      Parts.CommaText := AArg;
      if Parts.Count >= 3 then
      begin
        Val(Parts[0], ID64, Code);
        FServerID := TSteamID.Create(ID64);
        FServerIP := UInt32(StrToInt64Def(Parts[1], 0));
        FServerQueryPort := Word(StrToIntDef(Parts[2], 0));
      end;
    finally
      Parts.Free;
    end;
    AddLog(Format('Game server: the host''s server %s at %d.%d.%d.%d, query port %d', [IDText(FServerID),
      (FServerIP shr 24) and $FF, (FServerIP shr 16) and $FF, (FServerIP shr 8) and $FF, FServerIP and $FF,
      FServerQueryPort]));
    if FServerID.Value = 0 then
    begin
      RowDone(PT_SERVER, False, 'the host''s SERVER line was garbled: ' + AArg);
      Exit;
    end;
    // a ticket for the SERVER's identity, sent once Steam confirms it (163)
    Ident := IdentityOf(FServerID);
    SetLength(FGSTicketBytes, 2048);
    FGSTicketSize := 0;
    FGSTicket := FUser.Plugin.GetAuthSessionTicket(@FGSTicketBytes[0], Length(FGSTicketBytes), FGSTicketSize, @Ident);
    if FGSTicket = k_HAuthTicketInvalid then
      RowDone(PT_SERVER, False, 'GetAuthSessionTicket for the host''s server gave no ticket')
    else
      RowNote(PT_SERVER, 'ticket for the host''s server asked for - waiting for 163');
    // the server browser's view of it: informational (NAT may block it)
    if (FServerIP <> 0) and (FServerQueryPort <> 0) and (FServers.Plugin <> nil) then
    begin
      FRulesQuery := FServers.StartServerRules(FServerIP, FServerQueryPort);
      FRulesNote := 'rules query sent';
      AddLog(Format('Game server: StartServerRules -> query %d', [FRulesQuery]));
    end
    else
      FRulesNote := 'no public IP / query port - rules not queried';
  end
  else if (ACmd = 'SERVERFAIL') and not FIsHost then
    RowDone(PT_SERVER, False, 'the host''s game server failed: ' + AArg)
  else if (ACmd = 'GSAUTH') and FIsHost then
  begin
    if FGSAuthBegun or (FGS.Plugin = nil) then
      Exit;
    Ticket := BytesOfHex(AArg);
    if Length(Ticket) = 0 then
    begin
      RowDone(PT_SERVER, False, 'the guest''s server ticket arrived empty / garbled');
      SendChat('GSAUTHRESULT', '-1');
      Exit;
    end;
    Res := FGS.Plugin.BeginAuthSession(@Ticket[0], Length(Ticket), FPeer);
    AddLog(Format('Game server: BeginAuthSession(the guest''s ticket, %d bytes) on the SERVER -> %d',
      [Length(Ticket), Ord(Res)]));
    if Res = k_EBeginAuthSessionResultOK then
    begin
      FGSAuthBegun := True;
      RowNote(PT_SERVER, 'guest''s ticket begun on the server - waiting for 143 (server pipe)');
    end
    else
    begin
      RowDone(PT_SERVER, False, Format('server BeginAuthSession returned %d', [Ord(Res)]));
      SendChat('GSAUTHRESULT', IntToStr(-100 - Ord(Res)));
    end;
  end
  else if (ACmd = 'GSAUTHRESULT') and not FIsHost then
    RowDone(PT_SERVER, AArg = '0', Format('the host''s listen server validated our ticket: response %s (0 = OK); ' +
      '%s', [AArg, FRulesNote]))
  else if ACmd = 'DONE' then
  begin
    FPeerDone := True;
    AddLog('the other copy has every verdict (DONE)');
    CheckDone;
  end
  else if ACmd = 'AUTH' then
  begin
    if FAuthBegun then
      Exit;   // a repeat: a second BeginAuthSession would answer DuplicateRequest
    Ticket := BytesOfHex(AArg);
    if Length(Ticket) = 0 then
    begin
      RowDone(PT_AUTH, False, 'the peer''s ticket arrived empty / garbled');
      Exit;
    end;
    Res := FUser.Plugin.BeginAuthSession(@Ticket[0], Length(Ticket), FPeer);
    AddLog(Format('Auth: the peer''s ticket (%d bytes) -> BeginAuthSession %d', [Length(Ticket), Ord(Res)]));
    if Res = k_EBeginAuthSessionResultOK then
    begin
      FAuthBegun := True;
      RowNote(PT_AUTH, 'peer''s ticket begun - waiting for ValidateAuthTicketResponse (143)');
    end
    else
      RowDone(PT_AUTH, False, Format('BeginAuthSession returned %d', [Ord(Res)]));
  end
  else if (ACmd = 'LISTEN') and not FIsHost then
  begin
    Ident := IdentityOf(FPeer);
    FConn := FSockets.Plugin.ConnectP2P(@Ident, StrToIntDef(AArg, PAIR_SOCKET_PORT), 0, nil);
    AddLog(Format('NetworkingSockets: host listens - ConnectP2P(port %s) -> connection %u', [AArg, FConn]));
    if FConn = k_HSteamNetConnection_Invalid then
      RowDone(PT_SOCKETS, False, 'ConnectP2P failed')
    else
      RowNote(PT_SOCKETS, 'connecting ...');
  end;
end;

procedure TSteamPairTest.SendTicket;
begin
  if SendChat('AUTH', HexOf(FTicket, FTicketSize)) then
    AddLog(Format('Auth: ticket %d (%d bytes) sent to the peer through the lobby chat', [FTicketHandle, FTicketSize]))
  else
    RowDone(PT_AUTH, False, 'sending the ticket (SendLobbyChatMsg) failed');
end;

procedure TSteamPairTest.AuthTicketReady(Sender: TObject; const AData: GetAuthSessionTicketResponse_t);
begin
  if (FPhase = ppRunning) and (FGSTicket <> k_HAuthTicketInvalid) and (AData.m_hAuthTicket = FGSTicket) then
  begin
    if FGSTicketSent then
      Exit;   // a repeat of 163
    AddLog(Format('Game server: Steam confirmed our ticket for the server: result %d', [Ord(AData.m_eResult)]));
    if AData.m_eResult <> k_EResultOK then
    begin
      RowDone(PT_SERVER, False, Format('our ticket for the host''s server was refused: result %d',
        [Ord(AData.m_eResult)]));
      Exit;
    end;
    FGSTicketSent := True;
    if SendChat('GSAUTH', HexOf(FGSTicketBytes, FGSTicketSize)) then
      RowNote(PT_SERVER, 'ticket sent to the host - waiting for its server''s verdict')
    else
      RowDone(PT_SERVER, False, 'sending the server ticket (SendLobbyChatMsg) failed');
    Exit;
  end;
  if (FPhase <> ppRunning) or (AData.m_hAuthTicket <> FTicketHandle) then
    Exit;
  if FTicketSent then
    Exit;   // a repeat of 163: the ticket went out already
  AddLog(Format('Auth: Steam confirmed ticket %d: result %d', [AData.m_hAuthTicket, Ord(AData.m_eResult)]));
  if AData.m_eResult = k_EResultOK then
  begin
    FTicketSent := True;
    SendTicket;
  end
  else
    RowDone(PT_AUTH, False, Format('our ticket was refused: result %d', [Ord(AData.m_eResult)]));
end;

procedure TSteamPairTest.AuthValidated(Sender: TObject; const AData: ValidateAuthTicketResponse_t);
begin
  if (FPhase <> ppRunning) or not FAuthBegun or (AData.m_SteamID <> FPeer) then
    Exit;
  RowDone(PT_AUTH, AData.m_eAuthSessionResponse = k_EAuthSessionResponseOK,
    Format('ticket sent; the peer''s ticket validated: response %d (0 = OK), owner %s',
    [Ord(AData.m_eAuthSessionResponse), IDText(AData.m_OwnerSteamID)]));
end;

procedure TSteamPairTest.RichPresenceUpdate(Sender: TObject; const AData: FriendRichPresenceUpdate_t);
var
  S: string;
begin
  if (FPhase <> ppRunning) or (AData.m_steamIDFriend <> FPeer) then
    Exit;
  S := FFriends.Plugin.GetFriendRichPresence(FPeer, 'status');
  AddLog(Format('Friends: rich presence update for the peer (app %d): status "%s"', [AData.m_nAppID, S]));
  if S = FPeerStatus then
    RowDone(PT_FRIENDS, True, Format('peer persona "%s"; rich presence set here, the peer''s read ("%s")',
      [FFriends.Plugin.GetFriendPersonaName(FPeer), S]));
end;

procedure TSteamPairTest.MessagesSessionRequest(Sender: TObject; const AData: SteamNetworkingMessagesSessionRequest_t);
var
  Ident: SteamNetworkingIdentity;
begin
  Ident := AData.m_identityRemote;
  if FPhase in [ppSearching, ppCreating, ppJoining, ppWaiting] then
  begin
    FEarlyMsgPeer := Ident.m_steamID64;   // accepted in Paired if it is the peer
    AddLog('NetworkingMessages: session request from ' + U64Text(Ident.m_steamID64) + ' before pairing - kept');
    Exit;
  end;
  if FPhase <> ppRunning then
    Exit;
  AddLog(Format('NetworkingMessages: session request from %s - %s', [U64Text(Ident.m_steamID64),
    IfThen(Ident.m_steamID64 = FPeer.Value, 'accepting', 'not the peer, ignored')]));
  if Ident.m_steamID64 = FPeer.Value then
    FMessages.Plugin.AcceptSessionWithUser(@Ident);
end;

procedure TSteamPairTest.MessagesSessionFailed(Sender: TObject; const AData: SteamNetworkingMessagesSessionFailed_t);
begin
  if FPhase <> ppRunning then
    Exit;
  RowDone(PT_MESSAGES, False, Format('session failed: end reason %d, "%s"', [AData.m_info.m_eEndReason,
    TextOf(@AData.m_info.m_szEndDebug[0], CLen(@AData.m_info.m_szEndDebug[0], SizeOf(AData.m_info.m_szEndDebug)))]));
end;

procedure TSteamPairTest.SocketStatus(Sender: TObject; const AData: SteamNetConnectionStatusChangedCallback_t);
var
  St: Integer;
  Data: TBytes;
  MsgNo: Int64;
  Res: EResult;
begin
  if FPhase <> ppRunning then
    Exit;
  St := Ord(AData.m_info.m_eState);
  // Host: an incoming connection on our listen socket
  if FIsHost and (FListen <> k_HSteamListenSocket_Invalid) and (AData.m_info.m_hListenSocket = FListen) and
    (St = Ord(k_ESteamNetworkingConnectionState_Connecting)) and (FConn = k_HSteamNetConnection_Invalid) then
  begin
    FConn := AData.m_hConn;
    Res := FSockets.Plugin.AcceptConnection(FConn);
    AddLog(Format('NetworkingSockets: incoming connection %u from %s - AcceptConnection %d',
      [FConn, U64Text(AData.m_info.m_identityRemote.m_steamID64), Ord(Res)]));
    if Res <> k_EResultOK then
      RowDone(PT_SOCKETS, False, Format('AcceptConnection returned %d', [Ord(Res)]));
    Exit;
  end;
  if (FConn = k_HSteamNetConnection_Invalid) or (AData.m_hConn <> FConn) then
    Exit;
  AddLog(Format('NetworkingSockets: connection %u state %d -> %d', [FConn, Ord(AData.m_eOldState), St]));
  if (St = Ord(k_ESteamNetworkingConnectionState_Connected)) and not FIsHost and not FSockHelloSent then
  begin
    FSockHelloSent := True;
    Data := Utf8Of(SOCK_HELLO);
    MsgNo := 0;
    Res := FSockets.Plugin.SendMessageToConnection(FConn, @Data[0], Length(Data), k_nSteamNetworkingSend_Reliable,
      MsgNo);
    AddLog(Format('NetworkingSockets: connected - hello sent: %d', [Ord(Res)]));
    RowNote(PT_SOCKETS, 'connected, hello sent - waiting for the reply');
  end
  else if (St = Ord(k_ESteamNetworkingConnectionState_ClosedByPeer)) or
    (St = Ord(k_ESteamNetworkingConnectionState_ProblemDetectedLocally)) then
    RowDone(PT_SOCKETS, False, Format('connection ended: state %d, reason %d, "%s"', [St, AData.m_info.m_eEndReason,
      TextOf(@AData.m_info.m_szEndDebug[0], CLen(@AData.m_info.m_szEndDebug[0], SizeOf(AData.m_info.m_szEndDebug)))]));
end;

procedure TSteamPairTest.P2PSessionRequest(Sender: TObject; const AData: P2PSessionRequest_t);
begin
  if FPhase in [ppSearching, ppCreating, ppJoining, ppWaiting] then
  begin
    FEarlyP2PPeer := AData.m_steamIDRemote.Value;   // accepted in Paired if it is the peer
    AddLog('Networking: P2P session request from ' + IDText(AData.m_steamIDRemote) + ' before pairing - kept');
    Exit;
  end;
  if FPhase <> ppRunning then
    Exit;
  AddLog(Format('Networking: P2P session request from %s - %s', [IDText(AData.m_steamIDRemote),
    IfThen(AData.m_steamIDRemote = FPeer, 'accepting', 'not the peer, ignored')]));
  if AData.m_steamIDRemote = FPeer then
    FP2P.Plugin.AcceptP2PSessionWithUser(FPeer);
end;

procedure TSteamPairTest.P2PSessionFailed(Sender: TObject; const AData: P2PSessionConnectFail_t);
begin
  if (FPhase <> ppRunning) or (AData.m_steamIDRemote <> FPeer) then
    Exit;
  RowDone(PT_P2P, False, Format('P2P session to the peer failed: error %d', [AData.m_eP2PSessionError]));
end;

procedure TSteamPairTest.Poll;
var
  Msgs: array[0..15] of PSteamNetworkingMessage_t;
  N, I: Integer;
  S: string;
  Ident: SteamNetworkingIdentity;
  Data: TBytes;
  Res: EResult;
  MsgNo: Int64;
  Size, Got: UInt32;
  Buf: array[0..1199] of Byte;
  From: TSteamID;
begin
  // NetworkingMessages
  N := FMessages.Plugin.ReceiveMessages(PAIR_MSG_CHANNEL, Msgs);
  for I := 0 to N - 1 do
  begin
    S := TextOf(Msgs[I]^.m_pData, Msgs[I]^.m_cbSize);
    AddLog(Format('NetworkingMessages: received "%s" from %s', [S, U64Text(Msgs[I]^.m_identityPeer.m_steamID64)]));
    if (S = MSG_PING) and not FIsHost then
    begin
      Ident := IdentityOf(FPeer);
      Data := Utf8Of(MSG_PONG);
      Res := FMessages.Plugin.SendMessageToUser(@Ident, @Data[0], Length(Data), k_nSteamNetworkingSend_Reliable,
        PAIR_MSG_CHANNEL);
      RowDone(PT_MESSAGES, Res = k_EResultOK, Format('session request accepted, ping received, pong sent: %d',
        [Ord(Res)]));
    end
    else if (S = MSG_PONG) and FIsHost then
      RowDone(PT_MESSAGES, True, 'ping sent, pong received');
    FMessages.Plugin.ReleaseMessage(Msgs[I]);
  end;
  // NetworkingSockets
  if FConn <> k_HSteamNetConnection_Invalid then
  begin
    N := FSockets.Plugin.ReceiveMessages(FConn, Msgs);
    for I := 0 to N - 1 do
    begin
      S := TextOf(Msgs[I]^.m_pData, Msgs[I]^.m_cbSize);
      AddLog(Format('NetworkingSockets: received "%s" on connection %u', [S, FConn]));
      if (S = SOCK_HELLO) and FIsHost then
      begin
        Data := Utf8Of(SOCK_REPLY);
        MsgNo := 0;
        Res := FSockets.Plugin.SendMessageToConnection(FConn, @Data[0], Length(Data),
          k_nSteamNetworkingSend_Reliable, MsgNo);
        RowDone(PT_SOCKETS, Res = k_EResultOK, Format('listened, accepted connection %u, hello received, ' +
          'reply sent: %d', [FConn, Ord(Res)]));
      end
      else if (S = SOCK_REPLY) and not FIsHost then
        RowDone(PT_SOCKETS, True, Format('ConnectP2P connection %u connected, hello sent, reply received', [FConn]));
      FSockets.Plugin.ReleaseMessage(Msgs[I]);
    end;
  end;
  // Networking (old P2P)
  Size := 0;
  while FP2P.Plugin.IsP2PPacketAvailable(Size, PAIR_P2P_CHANNEL) do
  begin
    Got := 0;
    From := TSteamID.Create(0);
    if not FP2P.Plugin.ReadP2PPacket(@Buf[0], SizeOf(Buf), Got, From, PAIR_P2P_CHANNEL) then
      Break;
    S := TextOf(@Buf[0], Got);
    AddLog(Format('Networking: packet "%s" from %s', [S, IDText(From)]));
    if (S = P2P_PING) and not FIsHost and (From = FPeer) then
    begin
      Data := Utf8Of(P2P_PONG);
      RowDone(PT_P2P, FP2P.Plugin.SendP2PPacket(FPeer, @Data[0], Length(Data), k_EP2PSendReliable,
        PAIR_P2P_CHANNEL), 'session accepted, packet received, answer sent');
    end
    else if (S = P2P_PONG) and FIsHost and (From = FPeer) then
      RowDone(PT_P2P, True, 'packet sent, answer received');
  end;
  // Friends: also poll (the update callback may not come for non-friends)
  // and ask again every PAIR_RESCAN_MS (one answer per request)
  if not FRows[PT_FRIENDS].Done then
  begin
    if FFriends.Plugin.GetFriendRichPresence(FPeer, 'status') = FPeerStatus then
      RowDone(PT_FRIENDS, True, Format('peer persona "%s"; rich presence set here, the peer''s read ("%s", polled)',
        [FFriends.Plugin.GetFriendPersonaName(FPeer), FPeerStatus]))
    else if PairTicks - FPresenceTicks >= PAIR_RESCAN_MS then
    begin
      FFriends.Plugin.RequestFriendRichPresence(FPeer);
      FPresenceTicks := PairTicks;
      AddLog('Friends: the peer''s rich presence not there yet - requested again');
    end;
  end;
end;

procedure TSteamPairTest.CheckDone;
var
  I: Integer;
begin
  if (FPhase <> ppRunning) or (FCloseAt <> 0) then
    Exit;
  for I := 0 to PT_COUNT - 1 do
    if not FRows[I].Done then
      Exit;
  // Closing early would break the other copy's open rows (its auth
  // validation, rich presence read, chat): tell it, and close only once
  // it says it has every verdict too (or PAIR_TIMEOUT_MS later)
  if not FDoneSent then
  begin
    FDoneSent := True;
    FDoneTicks := PairTicks;
    AddLog('every row has its verdict - DONE sent: ' + BoolToStr(SendChat('DONE', ''), True) +
      IfThen(FPeerDone, '', '; waiting for the other copy''s DONE'));
  end;
  if not FPeerDone then
    Exit;
  FCloseAt := PairTicks + PAIR_GRACE_MS;
  AddLog(Format('both copies are done - closing in %d ms', [PAIR_GRACE_MS]));
end;

procedure TSteamPairTest.Tick;
var
  I: Integer;
  NowT: UInt64;
begin
  if FPhase = ppIdle then
    Exit;
  NowT := PairTicks;
  try
    case FPhase of
      ppSearching, ppCreating, ppJoining:
        if NowT - FStartTicks > PAIR_WAIT_MS then
          Finish(Format('no answer from Steam / no other copy within %d s', [PAIR_WAIT_MS div 1000]));
      ppWaiting:
        if NowT - FStartTicks > PAIR_WAIT_MS then
          Finish(Format('the other copy did not join within %d s', [PAIR_WAIT_MS div 1000]))
        else if NowT - FScanTicks >= PAIR_RESCAN_MS then
          SearchLobbies(True);
      ppRunning:
        begin
          if FServerStartDue then
          begin
            FServerStartDue := False;
            StartServerForPeer;
          end;
          Poll;
          if (FCloseAt <> 0) and (NowT >= FCloseAt) then
            Finish('')
          else if FDoneSent and not FPeerDone and (NowT - FDoneTicks > PAIR_TIMEOUT_MS) then
            Finish(Format('the other copy sent no DONE within %d s', [PAIR_TIMEOUT_MS div 1000]))
          else if not FDoneSent and (NowT - FPairedTicks > PAIR_TIMEOUT_MS) then
          begin
            for I := 0 to PT_COUNT - 1 do
              if not FRows[I].Done then
                RowDone(I, False, 'NO ANSWER within ' + IntToStr(PAIR_TIMEOUT_MS div 1000) + ' s; last: ' +
                  FRows[I].Note);
          end;
        end;
    end;
  except
    on E: Exception do
      Finish('error: ' + E.ClassName + ': ' + E.Message);
  end;
end;

procedure TSteamPairTest.Finish(const AReason: string);
var
  I, Passed: Integer;
  Ident: SteamNetworkingIdentity;
  Closed: string;
begin
  if FPhase = ppIdle then
    Exit;
  FPhase := ppClosing;
  if AReason <> '' then
    AddLog('stopped: ' + AReason);
  for I := 0 to PT_COUNT - 1 do
    if not FRows[I].Done then
    begin
      FRows[I].Done := True;
      FRows[I].OK := False;
      FRows[I].Note := 'not finished: ' + FRows[I].Note;
      ShowRow(I);
    end;
  if SteamAPI1.IsRunning then
  begin
    Closed := '';   // what there was to close (the log names only that)
    try
      if FConn <> k_HSteamNetConnection_Invalid then
      begin
        FSockets.Plugin.CloseConnection(FConn, 0, 'pair test done', True);
        Closed := Closed + ', connection';
      end;
      // closes the connections accepted on it ungracefully (linger lost) -
      // harmless: both copies have said DONE, nothing is left in flight
      if FListen <> k_HSteamListenSocket_Invalid then
      begin
        FSockets.Plugin.CloseListenSocket(FListen);
        Closed := Closed + ', listen socket';
      end;
      if FPeer.Value <> 0 then
      begin
        Ident := IdentityOf(FPeer);
        FMessages.Plugin.CloseSessionWithUser(@Ident);
        FP2P.Plugin.CloseP2PSessionWithUser(FPeer);
        Closed := Closed + ', sessions with the peer';
        if FAuthBegun then
        begin
          FUser.Plugin.EndAuthSession(FPeer);
          Closed := Closed + ', auth session';
        end;
      end;
      if FTicketHandle <> k_HAuthTicketInvalid then
      begin
        FUser.Plugin.CancelAuthTicket(FTicketHandle);
        Closed := Closed + ', our ticket';
      end;
      // game server: the guest's session, our ticket for it, the query,
      // and the server itself when this test started it
      if FGSAuthBegun and (FGS.Plugin <> nil) then
      begin
        FGS.Plugin.EndAuthSession(FPeer);
        Closed := Closed + ', server auth session';
      end;
      if FGSTicket <> k_HAuthTicketInvalid then
      begin
        FUser.Plugin.CancelAuthTicket(FGSTicket);
        Closed := Closed + ', our server ticket';
      end;
      if (FRulesQuery <> HSERVERQUERY_INVALID) and (FServers.Plugin <> nil) then
      begin
        FServers.Plugin.StopServerQuery(FRulesQuery);
        Closed := Closed + ', rules query';
      end;
      if FUsingServer then
      begin
        FUsingServer := False;
        Dec(DemoGameServerUsers);
        if (DemoGameServerUsers <= 0) and SteamAPI1.IsGameServerRunning then
        begin
          DemoGameServerUsers := 0;
          if FGS.Plugin <> nil then
          begin
            FGS.Plugin.SetAdvertiseServerActive(False);
            FGS.Plugin.LogOff;
          end;
          SteamAPI1.StopGameServer;   // from a handler: the core finishes it after the callback
          Closed := Closed + ', game server';
        end
        else if SteamAPI1.IsGameServerRunning then
        begin
          if FGS.Plugin <> nil then
            FGS.Plugin.SetKeyValue(PAIR_GS_RULE, '');
          Closed := Closed + ', our server rule (the component test still uses the server)';
        end;
      end;
      if FMyStatus <> '' then
      begin
        FFriends.Plugin.ClearRichPresence;
        Closed := Closed + ', rich presence';
      end;
      if FLobby.Value <> 0 then
      begin
        FMatch.Plugin.LeaveLobby(FLobby);
        Closed := Closed + ', lobby ' + IDText(FLobby);
      end;
      if Closed = '' then
        AddLog('closed: nothing was open')
      else
        AddLog('closed: ' + Copy(Closed, 3, MaxInt));
    except
      on E: Exception do AddLog('cleanup failed: ' + E.Message);
    end;
  end;
  FConn := k_HSteamNetConnection_Invalid;
  FListen := k_HSteamListenSocket_Invalid;
  FTicketHandle := k_HAuthTicketInvalid;
  FAuthBegun := False;
  FGSAuthBegun := False;
  FGSTicket := k_HAuthTicketInvalid;
  FRulesQuery := HSERVERQUERY_INVALID;
  FServerStarted := False;
  FServerStartDue := False;
  FMyStatus := '';
  FLobby := TSteamID.Create(0);
  Passed := 0;
  for I := 0 to PT_COUNT - 1 do
  begin
    if FRows[I].OK then
      Inc(Passed);
    AddLog(Format('result %s: %s', [PairTestNames[I], GetRowText(I)]));
  end;
  AddLog(Format('finished as %s: %d of %d PASS', [IfThen(FIsHost, 'HOST', 'GUEST'), Passed, PT_COUNT]));
  FPhase := ppIdle;
  if Assigned(FOnFinished) then
    FOnFinished(Self);
end;

procedure TSteamPairTest.StartServerForPeer;
var
  G: TSteamGameServerPlugin;
  OldGame, OldQuery: Word;
  Started: Boolean;
begin
  if not SteamAPI1.IsGameServerRunning then
  begin
    // the pair test's ports for this start only: the form's settings stay
    OldGame := SteamAPI1.GameServerGamePort;
    OldQuery := SteamAPI1.GameServerQueryPort;
    SteamAPI1.GameServerGamePort := PAIR_GS_GAME_PORT;
    SteamAPI1.GameServerQueryPort := PAIR_GS_QUERY_PORT;
    try
      Started := SteamAPI1.StartGameServer;
    finally
      SteamAPI1.GameServerGamePort := OldGame;
      SteamAPI1.GameServerQueryPort := OldQuery;
    end;
    if not Started then
    begin
      RowDone(PT_SERVER, False, 'StartGameServer failed: ' + SteamAPI1.Steam.LastError);
      SendChat('SERVERFAIL', 'StartGameServer failed');
      Exit;
    end;
    FServerStarted := True;
    AddLog(Format('Game server: listen server started (game port %d, query port %d)',
      [PAIR_GS_GAME_PORT, PAIR_GS_QUERY_PORT]));
  end
  else
    AddLog(Format('Game server: a game server runs already (query port %d) - used as it is',
      [SteamAPI1.Steam.GameServerQueryPort]));
  FUsingServer := True;
  Inc(DemoGameServerUsers);
  G := FGS.Plugin;
  if G = nil then
  begin
    RowDone(PT_SERVER, False, 'the game server plug-in is not active');
    SendChat('SERVERFAIL', 'plug-in not active');
    Exit;
  end;
  if G.BLoggedOn then
    ServerReady
  else if not FServerStarted then
    RowNote(PT_SERVER, 'the running server''s log-on is under way - waiting for 101')
  else
  begin
    G.SetModDir('tsteamapi');
    G.SetProduct('TSteamAPI');
    G.SetGameDescription('TSteamAPI pair test');
    G.SetDedicatedServer(False);
    G.LogOnAnonymous;
    RowNote(PT_SERVER, 'listen server started - logging on (101 on the server pipe)');
  end;
end;

procedure TSteamPairTest.ServerReady;
var
  G: TSteamGameServerPlugin;
begin
  G := FGS.Plugin;
  if (G = nil) or FServerAnnounced then
    Exit;
  FServerAnnounced := True;
  if FServerStarted then
  begin
    G.SetServerName('TSteamAPI pair test (' + FFriends.Plugin.GetPersonaName + ')');
    G.SetMapName('pair_test');
    G.SetMaxPlayerCount(2);
    G.SetAdvertiseServerActive(True);
  end;
  G.SetKeyValue(PAIR_GS_RULE, '1');
  FServerID := G.GetSteamID;
  FServerIP := G.PublicIPv4;
  AddLog(Format('Game server: logged on as %s, secure %s, public IP %d.%d.%d.%d - telling the guest',
    [IDText(FServerID), BoolToStr(G.BSecure, True), (FServerIP shr 24) and $FF, (FServerIP shr 16) and $FF,
     (FServerIP shr 8) and $FF, FServerIP and $FF]));
  if SendChat('SERVER', Format('%s,%u,%d', [U64Text(FServerID.Value), FServerIP, SteamAPI1.Steam.GameServerQueryPort])) then
    RowNote(PT_SERVER, 'server logged on - waiting for the guest''s ticket')
  else
    RowDone(PT_SERVER, False, 'sending SERVER (SendLobbyChatMsg) failed');
end;

procedure TSteamPairTest.GSConnected(Sender: TObject; const AData: SteamServersConnected_t);
begin
  AddLog('Game server: SteamServersConnected_t (101) on the server pipe');
  if (FPhase = ppRunning) and FIsHost then
    ServerReady;
end;

procedure TSteamPairTest.GSConnectFailure(Sender: TObject; const AData: SteamServerConnectFailure_t);
begin
  AddLog(Format('Game server: SteamServerConnectFailure_t (102): result %d, still retrying %s',
    [Ord(AData.m_eResult), BoolToStr(AData.m_bStillRetrying, True)]));
  if (FPhase = ppRunning) and FIsHost and not AData.m_bStillRetrying and not FServerAnnounced then
  begin
    RowDone(PT_SERVER, False, Format('server log-on failed: result %d', [Ord(AData.m_eResult)]));
    SendChat('SERVERFAIL', Format('log-on failed: result %d', [Ord(AData.m_eResult)]));
  end;
end;

procedure TSteamPairTest.GSAuthValidated(Sender: TObject; const AData: ValidateAuthTicketResponse_t);
begin
  if (FPhase <> ppRunning) or not FIsHost or not FGSAuthBegun or (AData.m_SteamID <> FPeer) then
    Exit;
  AddLog(Format('Game server: ValidateAuthTicketResponse (143, server pipe) for the guest: response %d, owner %s',
    [Ord(AData.m_eAuthSessionResponse), IDText(AData.m_OwnerSteamID)]));
  SendChat('GSAUTHRESULT', IntToStr(Ord(AData.m_eAuthSessionResponse)));
  RowDone(PT_SERVER, AData.m_eAuthSessionResponse = k_EAuthSessionResponseOK,
    Format('listen server %s logged on; the guest''s ticket validated by it: response %d (0 = OK)',
    [IDText(FServerID), Ord(AData.m_eAuthSessionResponse)]));
end;

procedure TSteamPairTest.ServerRule(Sender: TObject; AQuery: HServerQuery; const ARule, AValue: string);
begin
  if (AQuery <> FRulesQuery) or (FRulesQuery = HSERVERQUERY_INVALID) then
    Exit;
  AddLog(Format('Game server: rule of the host''s server: %s = "%s"', [ARule, AValue]));
  if ARule = PAIR_GS_RULE then
    FRuleSeen := True;
end;

procedure TSteamPairTest.ServerRulesComplete(Sender: TObject; AQuery: HServerQuery);
begin
  if (AQuery <> FRulesQuery) or (FRulesQuery = HSERVERQUERY_INVALID) then
    Exit;
  FRulesQuery := HSERVERQUERY_INVALID;
  if FRuleSeen then
    FRulesNote := 'rules query OK, ' + PAIR_GS_RULE + ' = 1 read back'
  else
    FRulesNote := 'rules query answered WITHOUT ' + PAIR_GS_RULE;
  AddLog('Game server: ' + FRulesNote);
end;

procedure TSteamPairTest.ServerRulesFailed(Sender: TObject; AQuery: HServerQuery);
begin
  if (AQuery <> FRulesQuery) or (FRulesQuery = HSERVERQUERY_INVALID) then
    Exit;
  FRulesQuery := HSERVERQUERY_INVALID;
  FRulesNote := 'rules query: no answer from the host''s public address (NAT? informational)';
  AddLog('Game server: ' + FRulesNote);
end;

end.
