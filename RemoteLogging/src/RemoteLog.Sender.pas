{ @abstract(Sends a program's log lines to the LogReceiver app over the
  local network - 100% optional, nothing to do with Steam.)

  The sender knows almost nothing: @link(TRemoteLogSender.Discover) listens
  for receivers announcing themselves (@link(TRemoteLogDiscovery) does the
  same on a background thread), @link(TRemoteLogSender.Start)
  connects to one, and every @link(TRemoteLogSender.Send) line is queued
  and streamed by a background thread. The receiver does the rest (asks its
  user to accept, stores the session). Lines are kept while the connection
  is down and sent after the thread has reconnected; a reconnect of the same
  session is accepted by the receiver without asking again.

  Status changes are reported through @link(TRemoteLogSender.OnStatus) on
  the main thread (queued), so the handler may touch the UI. Uses Indy,
  which ships with Delphi (Windows, macOS, Linux, Android). Protocol:
  @link(RemoteLog.Protocol). }
unit RemoteLog.Sender;

interface

uses
  System.SysUtils, System.Classes, System.SyncObjs, System.Generics.Collections;

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
    FLock: TCriticalSection;
    { Lines not yet taken by the sending thread. }
    FQueue: TQueue<string>;
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
  public
    { Listens for receiver announcements for ATimeoutMs milliseconds and
      returns every receiver heard (each host:port once). Blocks the caller
      for that time. @raises(Exception if the UDP port cannot be opened,
      e.g. another program on this machine is discovering at the same
      moment) }
    class function Discover(ATimeoutMs: Integer = 2500): TRemoteLogReceiverArray; static;
    { Creates a stopped sender. }
    constructor Create;
    { Stops the session and frees the sender. }
    destructor Destroy; override;
    { Starts streaming to AHost:APort. AApp names the program in the
      receiver (e.g. 'SteamInputDemo'). APlatform is the platform text the
      receiver shows; '' = the RTL's TOSVersion.ToString (which inside Steam's
      Linux runtime names the container, not the host - a caller that knows
      better, such as TSteamLib.PlatformDescription, passes its own; '|' is
      replaced, it separates the greeting's fields). Queued lines are kept. }
    procedure Start(const AHost: string; APort: Word; const AApp: string;
      const APlatform: string = '');
    { Ends the session. While connected, it first waits up to AFlushMs for the
      queued lines to be sent; lines still queued then are dropped. }
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

  { @link(TRemoteLogSender.Discover) on a background thread, so the caller's
    window (and a game loop) keeps running while it listens. Create it with
    a handler; the handler is called once, on the main thread (queued).
    Free it afterwards - but NOT from inside the handler: keep the object
    and free it before the next search or when the program ends. Freeing it
    early waits for the search to end (at most its timeout) and drops a
    result not yet delivered. }
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
  end;

implementation

uses
  System.Diagnostics,
  IdGlobal, IdStack, IdTCPClient, IdUDPClient,
  RemoteLog.Protocol;

type
  { The background thread of a @link(TRemoteLogSender): connect, greet, then
    write queued lines; reconnect after a failure. }
  TRemoteLogThread = class(TThread)
  private
    { The sender that owns this thread. }
    FOwner: TRemoteLogSender;
    { Reports AText through the owner's OnStatus, queued to the main thread
      (queued calls are removed when the thread is freed). }
    procedure Status(const AText: string);
  protected
    { The connect / send / reconnect loop. }
    procedure Execute; override;
  public
    { Creates the (running) thread for AOwner. }
    constructor Create(AOwner: TRemoteLogSender);
  end;

{ TRemoteLogThread }

constructor TRemoteLogThread.Create(AOwner: TRemoteLogSender);
begin
  FOwner := AOwner;
  inherited Create(False);
end;

procedure TRemoteLogThread.Status(const AText: string);
var
  Owner: TRemoteLogSender;
  Text: string;
begin
  Owner := FOwner;
  Text := AText;
  TThread.Queue(Self,
    procedure
    begin
      if Assigned(Owner.FOnStatus) then
        Owner.FOnStatus(Owner, Text);
    end);
end;

procedure TRemoteLogThread.Execute;
var
  Client: TIdTCPClient;
  Pending: TStringList;
  Reply: string;
  I: Integer;
begin
  Pending := TStringList.Create;
  try
    while not Terminated do
    begin
      Client := TIdTCPClient.Create(nil);
      try
        try
          Client.Host := FOwner.FHost;
          Client.Port := FOwner.FPort;
          Client.ConnectTimeout := 5000;
          Status(Format('connecting to %s:%d', [FOwner.FHost, FOwner.FPort]));
          Client.Connect;
          Client.IOHandler.DefStringEncoding := IndyTextEncoding_UTF8;
          Client.IOHandler.WriteLn(FOwner.FHello);
          // the receiver's user has to click Accept: give them up to 2
          // minutes, in half-second slices so Stop is never held up
          Reply := '';
          for I := 1 to 240 do
          begin
            Reply := Trim(Client.IOHandler.ReadLn(LF, 500));
            if (not Client.IOHandler.ReadLnTimedout) or Terminated then
              Break;
          end;
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
            for I := 0 to Pending.Count - 1 do
            begin
              Client.IOHandler.WriteLn(Pending[0]);
              Pending.Delete(0);
            end;
          end;
          Client.Disconnect;
        except
          on E: Exception do
            if not Terminated then
              Status(Format('connection to %s:%d failed or was lost (%s) - retrying in 3 s, %d line(s) kept',
                [FOwner.FHost, FOwner.FPort, E.Message, Pending.Count]));
        end;
      finally
        Client.Free;
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
  Udp: TIdUDPClient;
  Watch: TStopwatch;
  Msg, PeerIP, Key: string;
  PeerPort: TIdPort;
  Parts: TArray<string>;
  Seen: TStringList;
  Info: TRemoteLogReceiverInfo;
  Left, P, I: Integer;
begin
  Result := nil;
  Seen := TStringList.Create;
  Udp := TIdUDPClient.Create(nil);
  try
    Udp.BoundPort := RL_DISCOVERY_PORT;
    Udp.Active := True;
    Watch := TStopwatch.StartNew;
    repeat
      Left := ATimeoutMs - Integer(Watch.ElapsedMilliseconds);
      if Left <= 0 then
        Break;
      PeerIP := '';
      PeerPort := 0;
      Msg := Udp.ReceiveString(PeerIP, PeerPort, Left, IndyTextEncoding_UTF8);
      if Msg = '' then
        Continue;
      // TSTEAMAPI-LOGRECEIVER <version> <tcp port> <name ...>
      Parts := Msg.Trim.Split([' '], 4);
      if (Length(Parts) < 3) or (Parts[0] <> RL_ANNOUNCE) then
        Continue;
      P := StrToIntDef(Parts[2], 0);
      if (P <= 0) or (P > 65535) then
        Continue;
      Key := PeerIP + ':' + IntToStr(P);
      if Seen.IndexOf(Key) >= 0 then
        Continue;
      Seen.Add(Key);
      Info.Host := PeerIP;
      Info.Port := P;
      if Length(Parts) > 3 then
        Info.Name := Parts[3]
      else
        Info.Name := PeerIP;
      I := Length(Result);
      SetLength(Result, I + 1);
      Result[I] := Info;
    until False;
  finally
    Udp.Free;
    Seen.Free;
  end;
end;

constructor TRemoteLogSender.Create;
begin
  inherited Create;
  FLock := TCriticalSection.Create;
  FQueue := TQueue<string>.Create;
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
  Machine, Session, PlatformText: string;
begin
  Stop;
  FHost := AHost;
  FPort := APort;
  TIdStack.IncUsage;
  try
    Machine := GStack.HostName;
  finally
    TIdStack.DecUsage;
  end;
  // one session id for the whole run: the receiver accepts a reconnect of
  // it without asking again and appends to the same file
  Session := FormatDateTime('yyyymmdd-hhnnss', Now) + '-' + IntToHex(Random($10000), 4);
  PlatformText := APlatform;
  if PlatformText = '' then
    PlatformText := TOSVersion.ToString;
  PlatformText := StringReplace(PlatformText, RL_FIELD_SEPARATOR, '/', [rfReplaceAll]);
  FHello := RL_HELLO + ' ' + AApp + RL_FIELD_SEPARATOR + PlatformText + RL_FIELD_SEPARATOR
    + Machine + RL_FIELD_SEPARATOR + Session;
  FThread := TRemoteLogThread.Create(Self);
end;

procedure TRemoteLogSender.Stop(AFlushMs: Integer);
var
  Watch: TStopwatch;
  Left: Integer;
begin
  if FThread = nil then
    Exit;
  // give the thread a moment to send what is queued (e.g. the last lines
  // before a program closes); it takes lines in batches, so an empty queue
  // means they are being written
  Watch := TStopwatch.StartNew;
  repeat
    FLock.Enter;
    try
      Left := FQueue.Count;
    finally
      FLock.Leave;
    end;
    if (Left = 0) or (Watch.ElapsedMilliseconds >= AFlushMs) or FThread.Finished then
      Break;
    FWake.SetEvent;
    Sleep(20);
  until False;
  if Left = 0 then
    Sleep(100);   // let the last batch leave
  FThread.Terminate;
  FWake.SetEvent;
  FThread.WaitFor;   // the thread only Queues, never Synchronizes: no deadlock
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
    FQueue.Enqueue(ALine);
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
    while FQueue.Count > 0 do
      AList.Add(FQueue.Dequeue);
  finally
    FLock.Leave;
  end;
end;

{ TRemoteLogDiscovery }

constructor TRemoteLogDiscovery.Create(ATimeoutMs: Integer; AOnDone: TRemoteLogDiscoveredEvent);
begin
  FTimeoutMs := ATimeoutMs;
  FOnDone := AOnDone;
  // the thread starts after the constructor (AfterConstruction), so the
  // fields above are set before Execute reads them
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
    FFound := TRemoteLogSender.Discover(FTimeoutMs);
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
