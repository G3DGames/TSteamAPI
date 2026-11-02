{ @abstract(Free Pascal version of @code(RemoteLog.Sender): sends a
  program's log lines to the LogReceiver app over the local network -
  100% optional, nothing to do with Steam.)

  The same classes, methods and behaviour as the Delphi unit
  RemoteLog.Sender (which uses Indy): @link(TRemoteLogSender.Discover)
  listens for receivers announcing themselves on UDP
  (@link(TRemoteLogDiscovery) does it on a background thread),
  @link(TRemoteLogSender.Start) connects to one, and every
  @link(TRemoteLogSender.Send) line is queued and streamed by a background
  thread, which reconnects after a failure and keeps the lines meanwhile.
  Written on FPC's own Sockets unit (no Indy, no extra package), for FPC
  3.2.2 on Windows, Linux and macOS. Protocol: @link(RemoteLog.Protocol).

  Status changes reach @link(TRemoteLogSender.OnStatus) on the main thread
  (TThread.Queue; an LCL program processes the queue itself). }
unit RemoteLog.SenderFPC;

{$mode delphi}{$H+}

interface

uses
  SysUtils, Classes, SyncObjs;

type
  { One receiver found by @link(TRemoteLogSender.Discover). }
  TRemoteLogReceiverInfo = record
    { IP address the announcement came from. }
    Host: string;
    { TCP port the receiver accepts senders on. }
    Port: Word;
    { Name the receiver announced (usually its machine name). }
    Name: string;
  end;

  { Receivers found by @link(TRemoteLogSender.Discover). }
  TRemoteLogReceiverArray = array of TRemoteLogReceiverInfo;

  { Status messages of a @link(TRemoteLogSender), on the main thread. }
  TRemoteLogStatusEvent = procedure(Sender: TObject; const AText: string) of object;

  { Streams log lines to one LogReceiver. Create it, call @link(Start), then
    @link(Send) every line; free it (or call @link(Stop)) to end the
    session. @link(Send) may be called from any thread. }
  TRemoteLogSender = class
  private
    { Guards @link(FQueue). }
    FLock: SyncObjs.TCriticalSection;
    { Lines not yet taken by the sending thread. }
    FQueue: TStringList;
    { Wakes the sending thread when lines arrive or on @link(Stop). }
    FWake: TEvent;
    { The sending thread, or @nil when stopped. }
    FThread: TThread;
    { Receiver address given to @link(Start). }
    FHost: string;
    { Receiver TCP port given to @link(Start). }
    FPort: Word;
    { The greeting line sent on every (re)connect. }
    FHello: string;
    { Handler of @link(OnStatus). }
    FOnStatus: TRemoteLogStatusEvent;
    { Moves every queued line into AList (called by the sending thread). }
    procedure TakeAll(AList: TStrings);
    { Number of queued lines. }
    function QueuedCount: Integer;
  public
    { Listens for receiver announcements for ATimeoutMs milliseconds and
      returns every receiver heard (each host:port once). Blocks the caller
      for that time. @raises(Exception if the UDP port cannot be opened) }
    class function Discover(ATimeoutMs: Integer = 2500): TRemoteLogReceiverArray; overload; static;
    { @link(Discover), and ADiag says what the socket saw (packets, bytes,
      the first text, receive errors, the time-out option's result) - for a
      search that hears nothing although announcements arrive (2026-11-02,
      macOS ARM64: nc heard the receiver, the FPC build did not). }
    class function Discover(ATimeoutMs: Integer; out ADiag: string): TRemoteLogReceiverArray; overload; static;
    { Creates a stopped sender. }
    constructor Create;
    { Stops the session and frees the sender. }
    destructor Destroy; override;
    { Starts streaming to AHost:APort. AApp names the program in the
      receiver; APlatform is the platform text the receiver shows ('' =
      the target the program was compiled for; '|' is replaced, it
      separates the greeting's fields). Queued lines are kept. }
    procedure Start(const AHost: string; APort: Word; const AApp: string;
      const APlatform: string = '');
    { Ends the session. While connected, it first waits up to AFlushMs for
      the queued lines to be sent; lines still queued then are dropped. }
    procedure Stop(AFlushMs: Integer = 1000);
    { Queues one log line (thread-safe). Lines queued before @link(Start)
      are sent once connected. }
    procedure Send(const ALine: string);
    { True between @link(Start) and @link(Stop), unless the receiver refused
      the session or never answered. }
    function Active: Boolean;
    { Status messages (connecting, accepted, refused, connection lost,
      reconnecting), delivered on the main thread. }
    property OnStatus: TRemoteLogStatusEvent read FOnStatus write FOnStatus;
  end;

  { Result of a @link(TRemoteLogDiscovery): the receivers heard and, if the
    search could not run, why (AError; '' when it ran). On the main thread. }
  TRemoteLogDiscoveredEvent = procedure(Sender: TObject; const AFound: TRemoteLogReceiverArray;
    const AError: string) of object;

  { @link(TRemoteLogSender.Discover) on a background thread. Create it with
    a handler; the handler is called once, on the main thread. Free it
    afterwards - but NOT from inside the handler: keep the object and free
    it before the next search or when the program ends. }
  TRemoteLogDiscovery = class(TThread)
  private
    { How long to listen, in milliseconds. }
    FTimeoutMs: Integer;
    { Handler called with the result. }
    FOnDone: TRemoteLogDiscoveredEvent;
    { Receivers heard. }
    FFound: TRemoteLogReceiverArray;
    { Why the search could not run, or ''. }
    FError: string;
    { What the socket saw (see TRemoteLogSender.Discover). }
    FDiag: string;
    { Calls @link(FOnDone) (main thread). }
    procedure DoDone;
  protected
    { Runs the search, then queues @link(DoDone). }
    procedure Execute; override;
  public
    { Starts listening for ATimeoutMs; AOnDone gets the result. }
    constructor Create(ATimeoutMs: Integer; AOnDone: TRemoteLogDiscoveredEvent);
    { Waits for the search to end and drops an undelivered result. }
    destructor Destroy; override;
    { What the socket saw during the search (valid in the handler). }
    property Diagnostics: string read FDiag;
  end;

implementation

uses
  {$IFDEF UNIX}
  BaseUnix,
  {$ENDIF}
  {$IFDEF MSWINDOWS}
  WinSock2,   // SO_RCVTIMEO and friends (Sockets, listed after it, wins)
  {$ENDIF}
  Sockets, RemoteLog.Protocol;

const
  { An invalid socket on every platform (-1 / INVALID_SOCKET). }
  NO_SOCKET = TSocket(-1);
  {$IFDEF LINUX}
  { send() flag MSG_NOSIGNAL (Linux value): report a closed connection as
    an error, no SIGPIPE. }
  SEND_FLAGS = $4000;
  {$ELSE}
  { send() flags (macOS uses the SO_NOSIGPIPE socket option instead). }
  SEND_FLAGS = 0;
  {$ENDIF}
  {$IFDEF DARWIN}
  { macOS socket option: no SIGPIPE when the peer has closed. }
  SO_NOSIGPIPE_OPT = $1022;
  { macOS socket option: several listeners on one UDP port (BSD needs
    this as well as SO_REUSEADDR - e.g. LogReceiver on the same Mac). }
  SO_REUSEPORT_OPT = $0200;
  {$ENDIF}

{ Sets how long a blocking receive on S may wait.
  @param(S The socket.)
  @param(AMs Milliseconds.) }
function SetReceiveTimeout(S: TSocket; AMs: Integer): Integer;
{$IFDEF MSWINDOWS}
var
  Ms: DWord;
begin
  Ms := AMs;
  Result := fpSetSockOpt(S, SOL_SOCKET, SO_RCVTIMEO, @Ms, SizeOf(Ms));
end;
{$ELSE}
var
  TV: TTimeVal;
begin
  TV.tv_sec := AMs div 1000;
  TV.tv_usec := (AMs mod 1000) * 1000;
  Result := fpSetSockOpt(S, SOL_SOCKET, SO_RCVTIMEO, @TV, SizeOf(TV));
end;
{$ENDIF}

{ This machine's name, for the greeting.
  @returns(Host name, or 'unknown'.) }
function MachineName: string;
{$IFDEF UNIX}
var
  U: UtsName;
{$ENDIF}
begin
  Result := '';
  {$IFDEF MSWINDOWS}
  Result := SysUtils.GetEnvironmentVariable('COMPUTERNAME');
  {$ENDIF}
  {$IFDEF UNIX}
  FillChar(U, SizeOf(U), 0);
  if fpUname(U) = 0 then
    Result := StrPas(PChar(@U.Nodename[0]));
  {$ENDIF}
  if Result = '' then
    Result := 'unknown';
end;

{ The target the program was compiled for (default platform text).
  @returns(For example "Win64 (FPC)".) }
function CompiledPlatform: string;
begin
  Result := {$I %FPCTARGETOS%} + ' ' + {$I %FPCTARGETCPU%} + ' (Free Pascal)';
end;

{ Sends every byte of AData on S.
  @raises(Exception when the connection is gone.) }
procedure SendAll(S: TSocket; const AData: RawByteString);
var
  Done, N: Integer;
begin
  Done := 0;
  while Done < Length(AData) do
  begin
    N := fpSend(S, @AData[Done + 1], Length(AData) - Done, SEND_FLAGS);
    if N <= 0 then
      raise Exception.CreateFmt('send failed (socket error %d)', [SocketError]);
    Inc(Done, N);
  end;
end;

type
  { The background thread of a @link(TRemoteLogSender): connect, greet,
    then write queued lines; reconnect after a failure. }
  TRemoteLogThread = class(TThread)
  private
    { The sender that owns this thread. }
    FOwner: TRemoteLogSender;
    { Guards @link(FStatusLines). }
    FStatusLock: SyncObjs.TCriticalSection;
    { Status texts waiting for the main thread. }
    FStatusLines: TStringList;
    { Queues AText for the owner's OnStatus (main thread). }
    procedure Status(const AText: string);
    { Main thread: hands every waiting status text to OnStatus. }
    procedure DeliverStatus;
    { Reads one line (up to LF) from S, waiting at most ATimeoutMs in
      500 ms slices so Terminate is noticed. Returns '' on timeout. }
    function ReadLine(S: TSocket; ATimeoutMs: Integer): string;
  protected
    { The connect / send / reconnect loop. }
    procedure Execute; override;
  public
    { Creates the (running) thread for AOwner. }
    constructor Create(AOwner: TRemoteLogSender);
    { Frees the status list. }
    destructor Destroy; override;
  end;

{ TRemoteLogThread }

constructor TRemoteLogThread.Create(AOwner: TRemoteLogSender);
begin
  FOwner := AOwner;
  FStatusLock := SyncObjs.TCriticalSection.Create;
  FStatusLines := TStringList.Create;
  inherited Create(False);
end;

destructor TRemoteLogThread.Destroy;
begin
  inherited;
  FStatusLines.Free;
  FStatusLock.Free;
end;

procedure TRemoteLogThread.Status(const AText: string);
begin
  FStatusLock.Enter;
  try
    FStatusLines.Add(AText);
  finally
    FStatusLock.Leave;
  end;
  TThread.Queue(Self, DeliverStatus);
end;

procedure TRemoteLogThread.DeliverStatus;
var
  Lines: TStringList;
  I: Integer;
begin
  Lines := TStringList.Create;
  try
    FStatusLock.Enter;
    try
      Lines.Assign(FStatusLines);
      FStatusLines.Clear;
    finally
      FStatusLock.Leave;
    end;
    if Assigned(FOwner.FOnStatus) then
      for I := 0 to Lines.Count - 1 do
        FOwner.FOnStatus(FOwner, Lines[I]);
  finally
    Lines.Free;
  end;
end;

function TRemoteLogThread.ReadLine(S: TSocket; ATimeoutMs: Integer): string;
var
  Buf: AnsiChar;
  Line: RawByteString;
  Waited, N: Integer;
begin
  Result := '';
  Line := '';
  Waited := 0;
  SetReceiveTimeout(S, 500);
  while (Waited < ATimeoutMs) and not Terminated do
  begin
    N := fpRecv(S, @Buf, 1, 0);
    if N = 1 then
    begin
      if Buf = #10 then
        Exit(Trim(string(Line)));
      Line := Line + Buf;
    end
    else if N = 0 then
      raise Exception.Create('the receiver closed the connection')
    else
      Inc(Waited, 500);   // timeout slice (or an error: ends by time)
  end;
end;

procedure TRemoteLogThread.Execute;
var
  S: TSocket;
  Addr: TInetSockAddr;
  Pending: TStringList;
  Reply: string;
  {$IFDEF DARWIN}
  One: Integer;
  {$ENDIF}
begin
  Pending := TStringList.Create;
  try
    while not Terminated do
    begin
      S := NO_SOCKET;
      try
        try
          Status(Format('connecting to %s:%d', [FOwner.FHost, FOwner.FPort]));
          S := fpSocket(AF_INET, SOCK_STREAM, 0);
          if S = NO_SOCKET then
            raise Exception.CreateFmt('no socket (error %d)', [SocketError]);
          {$IFDEF DARWIN}
          One := 1;
          fpSetSockOpt(S, SOL_SOCKET, SO_NOSIGPIPE_OPT, @One, SizeOf(One));
          {$ENDIF}
          FillChar(Addr, SizeOf(Addr), 0);
          Addr.sin_family := AF_INET;
          Addr.sin_port := htons(FOwner.FPort);
          Addr.sin_addr := StrToNetAddr(FOwner.FHost);
          if fpConnect(S, @Addr, SizeOf(Addr)) <> 0 then
            raise Exception.CreateFmt('connect failed (socket error %d)', [SocketError]);
          SendAll(S, UTF8Encode(FOwner.FHello) + #10);
          // the receiver's user has to click Accept: up to 2 minutes, in
          // half-second slices so Stop is never held up
          Reply := ReadLine(S, 120000);
          if Terminated then
            Break;
          if Reply <> RL_ACCEPTED then
          begin
            if Reply = '' then
              Status('the receiver did not answer (no Accept within 2 minutes) - stopped')
            else
              Status('the receiver refused this session - stopped');
            Break;
          end;
          Status('accepted - log lines are being sent');
          while not Terminated do
          begin
            FOwner.TakeAll(Pending);
            if Pending.Count = 0 then
            begin
              FOwner.FWake.WaitFor(500);
              Continue;
            end;
            // a line leaves Pending only once written, so nothing is lost
            // when the connection breaks half way
            while Pending.Count > 0 do
            begin
              SendAll(S, UTF8Encode(Pending[0]) + #10);
              Pending.Delete(0);
            end;
          end;
        except
          on E: Exception do
            if not Terminated then
              Status(Format('connection to %s:%d failed or was lost (%s) - retrying in 3 s, %d line(s) kept',
                [FOwner.FHost, FOwner.FPort, E.Message, Pending.Count]));
        end;
      finally
        if S <> NO_SOCKET then
          CloseSocket(S);
      end;
      // wait before reconnecting (FWake also ends the wait on Stop)
      if not Terminated then
        FOwner.FWake.WaitFor(3000);
    end;
  finally
    Pending.Free;
  end;
end;

{ TRemoteLogSender }

class function TRemoteLogSender.Discover(ATimeoutMs: Integer): TRemoteLogReceiverArray;
var
  Diag: string;
begin
  Result := Discover(ATimeoutMs, Diag);
end;

class function TRemoteLogSender.Discover(ATimeoutMs: Integer; out ADiag: string): TRemoteLogReceiverArray;
var
  Packets, Errors, LastErr, OptRes, FirstOptRes, LastLen: Integer;
  FirstText: string;
  S: TSocket;
  Addr, From: TInetSockAddr;
  FromLen: TSockLen;
  Buf: array[0..1023] of AnsiChar;
  N, P, I, Left: Integer;
  One: Integer;
  Started: QWord;
  Msg: RawByteString;
  Parts: TStringList;
  Key, PeerIP: string;
  Seen: TStringList;
  Info: TRemoteLogReceiverInfo;
begin
  Result := nil;
  ADiag := '';
  Packets := 0;
  Errors := 0;
  LastErr := 0;
  FirstOptRes := 1;
  LastLen := 0;
  FirstText := '';
  S := fpSocket(AF_INET, SOCK_DGRAM, 0);
  if S = NO_SOCKET then
    raise Exception.CreateFmt('no UDP socket (error %d)', [SocketError]);
  Seen := TStringList.Create;
  Parts := TStringList.Create;
  try
    One := 1;
    fpSetSockOpt(S, SOL_SOCKET, SO_REUSEADDR, @One, SizeOf(One));
    {$IFDEF DARWIN}
    fpSetSockOpt(S, SOL_SOCKET, SO_REUSEPORT_OPT, @One, SizeOf(One));
    {$ENDIF}
    FillChar(Addr, SizeOf(Addr), 0);
    Addr.sin_family := AF_INET;
    Addr.sin_port := htons(RL_DISCOVERY_PORT);
    Addr.sin_addr.s_addr := 0;   // INADDR_ANY
    if fpBind(S, @Addr, SizeOf(Addr)) <> 0 then
      raise Exception.CreateFmt('UDP port %d cannot be opened (socket error %d)',
        [RL_DISCOVERY_PORT, SocketError]);
    Started := GetTickCount64;
    repeat
      Left := ATimeoutMs - Integer(GetTickCount64 - Started);
      if Left <= 0 then
        Break;
      if Left > 250 then
        Left := 250;
      OptRes := SetReceiveTimeout(S, Left);
      if FirstOptRes = 1 then
        FirstOptRes := OptRes;
      FromLen := SizeOf(From);
      N := fpRecvFrom(S, @Buf[0], SizeOf(Buf) - 1, 0, @From, @FromLen);
      if N <= 0 then
      begin
        if N < 0 then
        begin
          Inc(Errors);
          LastErr := SocketError;
        end;
        Continue;   // timeout slice
      end;
      Inc(Packets);
      LastLen := N;
      SetString(Msg, PAnsiChar(@Buf[0]), N);
      if FirstText = '' then
        FirstText := Copy(Trim(string(Msg)), 1, 60);
      // TSTEAMAPI-LOGRECEIVER <version> <tcp port> <name ...>
      Parts.Clear;
      Parts.Delimiter := ' ';
      Parts.StrictDelimiter := True;
      Parts.DelimitedText := Trim(string(Msg));
      if (Parts.Count < 3) or (Parts[0] <> RL_ANNOUNCE) then
        Continue;
      P := StrToIntDef(Parts[2], 0);
      if (P <= 0) or (P > 65535) then
        Continue;
      PeerIP := NetAddrToStr(From.sin_addr);
      Key := PeerIP + ':' + IntToStr(P);
      if Seen.IndexOf(Key) >= 0 then
        Continue;
      Seen.Add(Key);
      Info.Host := PeerIP;
      Info.Port := P;
      Info.Name := '';
      // the name may contain spaces: everything after the port
      for I := 3 to Parts.Count - 1 do
        if Info.Name = '' then
          Info.Name := Parts[I]
        else
          Info.Name := Info.Name + ' ' + Parts[I];
      if Info.Name = '' then
        Info.Name := PeerIP;
      SetLength(Result, Length(Result) + 1);
      Result[High(Result)] := Info;
    until False;
    // receive errors are mostly the time-out slices (EAGAIN); the count
    // and the option's result still tell a broken time-out from silence
    ADiag := Format('UDP %d: %d packet(s)', [RL_DISCOVERY_PORT, Packets]);
    if Packets > 0 then
      ADiag := ADiag + Format(' (last %d bytes, first "%s")', [LastLen, FirstText]);
    ADiag := ADiag + Format(', %d receive error(s) (last %d), SO_RCVTIMEO -> %d',
      [Errors, LastErr, FirstOptRes]);
  finally
    CloseSocket(S);
    Parts.Free;
    Seen.Free;
  end;
end;

constructor TRemoteLogSender.Create;
begin
  inherited Create;
  FLock := SyncObjs.TCriticalSection.Create;
  FQueue := TStringList.Create;
  FWake := TEvent.Create(nil, False, False, '');
end;

destructor TRemoteLogSender.Destroy;
begin
  Stop;
  FWake.Free;
  FQueue.Free;
  FLock.Free;
  inherited;
end;

procedure TRemoteLogSender.Start(const AHost: string; APort: Word; const AApp: string;
  const APlatform: string);
var
  Session, PlatformText: string;
begin
  Stop;
  FHost := AHost;
  FPort := APort;
  // one session id for the whole run: the receiver accepts a reconnect of
  // it without asking again and appends to the same file
  Session := FormatDateTime('yyyymmdd-hhnnss', Now) + '-' + IntToHex(Random($10000), 4);
  PlatformText := APlatform;
  if PlatformText = '' then
    PlatformText := CompiledPlatform;
  PlatformText := StringReplace(PlatformText, RL_FIELD_SEPARATOR, '/', [rfReplaceAll]);
  FHello := RL_HELLO + ' ' + AApp + RL_FIELD_SEPARATOR + PlatformText + RL_FIELD_SEPARATOR
    + MachineName + RL_FIELD_SEPARATOR + Session;
  FThread := TRemoteLogThread.Create(Self);
end;

function TRemoteLogSender.QueuedCount: Integer;
begin
  FLock.Enter;
  try
    Result := FQueue.Count;
  finally
    FLock.Leave;
  end;
end;

procedure TRemoteLogSender.Stop(AFlushMs: Integer);
var
  Started: QWord;
  Left: Integer;
begin
  if FThread = nil then
    Exit;
  // give the thread a moment to send what is queued (e.g. the last lines
  // before a program closes)
  Started := GetTickCount64;
  repeat
    Left := QueuedCount;
    if (Left = 0) or (GetTickCount64 - Started >= QWord(AFlushMs)) or FThread.Finished then
      Break;
    FWake.SetEvent;
    Sleep(20);
  until False;
  if Left = 0 then
    Sleep(100);   // let the last batch leave
  FThread.Terminate;
  FWake.SetEvent;
  FThread.WaitFor;   // the thread only Queues, never Synchronizes: no deadlock
  // its status texts not yet delivered must not reach a freed thread
  TThread.RemoveQueuedEvents(FThread);
  FreeAndNil(FThread);
  FLock.Enter;
  try
    FQueue.Clear;
  finally
    FLock.Leave;
  end;
end;

procedure TRemoteLogSender.Send(const ALine: string);
begin
  // a refused / given-up session has a finished thread: nothing would read
  // the queue any more
  if (FThread <> nil) and FThread.Finished then
    Exit;
  FLock.Enter;
  try
    FQueue.Add(ALine);
  finally
    FLock.Leave;
  end;
  FWake.SetEvent;
end;

function TRemoteLogSender.Active: Boolean;
begin
  Result := (FThread <> nil) and not FThread.Finished;
end;

procedure TRemoteLogSender.TakeAll(AList: TStrings);
begin
  FLock.Enter;
  try
    AList.AddStrings(FQueue);
    FQueue.Clear;
  finally
    FLock.Leave;
  end;
end;

{ TRemoteLogDiscovery }

constructor TRemoteLogDiscovery.Create(ATimeoutMs: Integer; AOnDone: TRemoteLogDiscoveredEvent);
begin
  FTimeoutMs := ATimeoutMs;
  FOnDone := AOnDone;
  inherited Create(False);
  FreeOnTerminate := False;
end;

destructor TRemoteLogDiscovery.Destroy;
begin
  Terminate;
  if not Finished then
    WaitFor;
  // a result queued but not yet delivered must not reach a freed handler
  TThread.RemoveQueuedEvents(Self);
  inherited;
end;

procedure TRemoteLogDiscovery.Execute;
begin
  try
    FFound := TRemoteLogSender.Discover(FTimeoutMs, FDiag);
  except
    on E: Exception do
    begin
      FFound := nil;
      FError := E.Message;
    end;
  end;
  if not Terminated then
    Queue(DoDone);
end;

procedure TRemoteLogDiscovery.DoDone;
begin
  if Assigned(FOnDone) and not Terminated then
    FOnDone(Self, FFound, FError);
end;

initialization
  Randomize;

end.
