{ @abstract(File > Send log to receiver for the SteamDemo programs: finds a
  LogReceiver on the network by itself and sends the demo's log there.
  Compiles with Delphi (RemoteLog.Sender, Indy) and FPC (RemoteLog.SenderFPC).)

  OPTIONAL, NOTHING TO DO WITH STEAM (RemoteLogging/README.md): it lets a
  second test machine - the pair test's guest, a Steam Deck - send its log
  to the developer's machine. The form creates one @link(TDemoRemoteLog),
  calls @link(TDemoRemoteLog.Toggle) from its menu item, passes every log
  line to @link(TDemoRemoteLog.Send) and calls
  @link(TDemoRemoteLog.Shutdown) when it closes; @link(TDemoRemoteLog.OnChanged)
  tells it to update the menu text (@link(TDemoRemoteLog.MenuText)). }
unit DemoRemoteLog;

{$ifdef FPC}
  {$mode delphi}{$H+}
{$endif}

interface

uses
  SysUtils, Classes,
  {$ifdef FPC}RemoteLog.SenderFPC{$else}RemoteLog.Sender{$endif};

type
  { A line for the form's log. }
  TDemoRemoteLogEvent = procedure(const AText: string) of object;

  { The remote-log state of one demo window (see the unit description). }
  TDemoRemoteLog = class(TComponent)
  private
    { Program name the receiver shows. }
    FAppName: string;
    { Platform text the receiver shows ('' = the sender's default). }
    FPlatform: string;
    { The sender while connected / sending (@nil otherwise). }
    FSender: TRemoteLogSender;
    { The running (or last) network search; never freed inside its own
      handler. }
    FDiscovery: TRemoteLogDiscovery;
    { Earlier searches of this Toggle (a retry starts inside the handler of
      the previous one, which cannot free itself there); freed by the next
      Toggle and the destructor. }
    FSpent: TList;
    { Searches made for this Toggle (1..SEARCH_TRIES). }
    FTries: Integer;
    { @true while a search runs. }
    FBusy: Boolean;
    { @true once Shutdown ran (late search results are ignored). }
    FClosed: Boolean;
    { The log so far, sent first when a receiver is found. }
    FBacklog: TStringList;
    { Backing field of @link(OnLog). }
    FOnLog: TDemoRemoteLogEvent;
    { Backing field of @link(OnChanged). }
    FOnChanged: TNotifyEvent;
    { Frees the searches in FSpent and FDiscovery (never from a handler). }
    procedure FreeSearches;
    { Starts search number FTries. }
    procedure StartSearch;
    { Writes a "[remote log] ..." line to @link(OnLog). }
    procedure Log(const S: string);
    { Raises @link(OnChanged). }
    procedure Changed;
    { TRemoteLogDiscovery result (main thread). }
    procedure Discovered(Sender: TObject; const AFound: TRemoteLogReceiverArray; const AError: string);
    { TRemoteLogSender.OnStatus. }
    procedure SenderStatus(Sender: TObject; const AText: string);
  public
    { AAppName: the program's name for the receiver; APlatform: what it runs
      on ('' = the sender's own description). }
    constructor Create(AOwner: TComponent; const AAppName, APlatform: string); reintroduce;
    { Stops sending and frees everything. }
    destructor Destroy; override;
    { Not sending: searches the network (2.5 s, in the background, up to 3
      times while nothing answers) and connects to the first LogReceiver that answers, sending ABacklog (the
      log so far) first. Sending: stops. }
    procedure Toggle(ABacklog: TStrings);
    { Sends one log line while connected (queued; never blocks); during the
      search it joins the backlog. }
    procedure Send(const ALine: string);
    { Stops sending (flushes up to 1 s); call when the window closes. }
    procedure Shutdown;
    { @true while connected / sending. }
    function Sending: Boolean;
    { The menu text for the current state. }
    function MenuText: string;
    { "[remote log] ..." lines for the form's log. }
    property OnLog: TDemoRemoteLogEvent read FOnLog write FOnLog;
    { The state changed: update the menu text. }
    property OnChanged: TNotifyEvent read FOnChanged write FOnChanged;
  end;

implementation

const
  { How long a network search waits for LogReceiver answers. }
  SEARCH_MS = 2500;
  { Searches per Toggle while no receiver answers (a LogReceiver that was
    just started, or a lost broadcast, often misses the first one). }
  SEARCH_TRIES = 3;

constructor TDemoRemoteLog.Create(AOwner: TComponent; const AAppName, APlatform: string);
begin
  inherited Create(AOwner);
  FAppName := AAppName;
  FPlatform := APlatform;
  FBacklog := TStringList.Create;
  FSpent := TList.Create;
end;

destructor TDemoRemoteLog.Destroy;
begin
  Shutdown;
  FreeSearches;
  FSpent.Free;
  FBacklog.Free;
  inherited;
end;

procedure TDemoRemoteLog.Log(const S: string);
begin
  if Assigned(FOnLog) then
    FOnLog('[remote log] ' + S);
end;

procedure TDemoRemoteLog.Changed;
begin
  if Assigned(FOnChanged) then
    FOnChanged(Self);
end;

procedure TDemoRemoteLog.FreeSearches;
var
  I: Integer;
begin
  for I := 0 to FSpent.Count - 1 do
    TObject(FSpent[I]).Free;
  FSpent.Clear;
  FreeAndNil(FDiscovery);
end;

procedure TDemoRemoteLog.StartSearch;
begin
  if FDiscovery <> nil then
    FSpent.Add(FDiscovery);   // may be the caller (Discovered): freed later
  FDiscovery := nil;
  FBusy := True;
  Log(Format('looking for LogReceiver apps on the network (%.1f s, try %d of %d)...',
    [SEARCH_MS / 1000, FTries, SEARCH_TRIES]));
  FDiscovery := TRemoteLogDiscovery.Create(SEARCH_MS, Discovered);
end;

function TDemoRemoteLog.Sending: Boolean;
begin
  Result := FSender <> nil;
end;

function TDemoRemoteLog.MenuText: string;
begin
  if FSender <> nil then
    Result := 'Stop sending log'
  else
    Result := 'Send log to receiver...';
end;

procedure TDemoRemoteLog.Toggle(ABacklog: TStrings);
begin
  if FClosed then
    Exit;
  if FSender <> nil then
  begin
    Log('stopped by the user');
    FSender.Stop;
    FreeAndNil(FSender);
    Changed;
    Exit;
  end;
  if FBusy then
  begin
    Log('already looking for a receiver');
    Exit;
  end;
  FBacklog.Clear;
  if ABacklog <> nil then
    FBacklog.Assign(ABacklog);
  FreeSearches;   // the previous searches have delivered their results
  FTries := 1;
  StartSearch;
end;

procedure TDemoRemoteLog.Discovered(Sender: TObject; const AFound: TRemoteLogReceiverArray;
  const AError: string);
var
  I: Integer;
begin
  // FDiscovery is NOT freed here (it is the caller of this handler)
  FBusy := False;
  if FClosed or (FSender <> nil) then
    Exit;
  if AError <> '' then
  begin
    Log('could not search the network: ' + AError);
    Exit;
  end;
  if Length(AFound) = 0 then
  begin
    // what the socket saw (FPC sender; '' with the Delphi one)
    if (Sender is TRemoteLogDiscovery) and (TRemoteLogDiscovery(Sender).Diagnostics <> '') then
      Log('search ' + IntToStr(FTries) + ': ' + TRemoteLogDiscovery(Sender).Diagnostics);
    if FTries < SEARCH_TRIES then
    begin
      Inc(FTries);
      StartSearch;   // FBusy again: log lines keep joining the backlog
    end
    else
      Log(Format('no LogReceiver answered in %d searches of %.1f s - start LogReceiver on a machine on ' +
        'this network, click OK there, check its firewall (UDP broadcast), then try again',
        [SEARCH_TRIES, SEARCH_MS / 1000]));
    Exit;
  end;
  for I := 0 to High(AFound) do
    Log(Format('found %s at %s:%d', [AFound[I].Name, AFound[I].Host, AFound[I].Port]));
  if Length(AFound) > 1 then
    Log(Format('%d receivers answered - using the first (%s)', [Length(AFound), AFound[0].Name]));
  FSender := TRemoteLogSender.Create;
  FSender.OnStatus := SenderStatus;
  // the log so far first, so the receiver gets the whole run
  for I := 0 to FBacklog.Count - 1 do
    FSender.Send(FBacklog[I]);
  FBacklog.Clear;
  FSender.Start(AFound[0].Host, AFound[0].Port, FAppName, FPlatform);
  Log(Format('sending to %s:%d - click Yes in LogReceiver', [AFound[0].Host, AFound[0].Port]));
  Changed;
end;

procedure TDemoRemoteLog.SenderStatus(Sender: TObject; const AText: string);
begin
  Log(AText);
  // refused / no answer: the sender has given up - offer to start again
  if (FSender <> nil) and not FSender.Active then
  begin
    FreeAndNil(FSender);
    Changed;
  end;
end;

procedure TDemoRemoteLog.Send(const ALine: string);
begin
  if FSender <> nil then
    FSender.Send(ALine)
  else if FBusy then
    FBacklog.Add(ALine);   // logged during the search: sent with the backlog
end;

procedure TDemoRemoteLog.Shutdown;
begin
  FClosed := True;
  if FSender <> nil then
  begin
    FSender.Stop;
    FreeAndNil(FSender);
  end;
end;

end.
