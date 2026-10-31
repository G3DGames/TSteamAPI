{ @abstract(Main form of LogReceiver: receives log lines from programs on
  the local network - 100% optional, nothing to do with Steam.)

  The receiver does the work so senders need almost none:
  @unorderedList(
    @item(it first asks which network to listen on (unit uNetworks orders
      them: the machine's real network first, then 192.168 / 172.16 / 10
      ranges); OK starts listening on that address only;)
    @item(it announces itself once a second on UDP port
      @code(RL_DISCOVERY_PORT) (broadcast), so senders can find it;)
    @item(it accepts TCP connections on @code(RL_DEFAULT_TCP_PORT), reads
      the sender's greeting and asks the user to Accept or Refuse it - a
      session accepted before (a reconnect) is let in without asking;)
    @item(every accepted session is shown live and saved to its own file
      under Documents/LogReceiver.))
  Each connection runs on an Indy worker thread. The Accept question is
  QUEUED to the main thread and the worker waits for the answer on an event
  (checking every 200 ms whether the window is closing), so closing the
  window can never deadlock with a worker; the UI reads new lines from a
  timer, so the workers never touch controls. Protocol: unit
  RemoteLog.Protocol. }
unit uReceiver;

interface

uses
  System.SysUtils, System.Types, System.UITypes, System.Classes, System.SyncObjs,
  System.Generics.Collections,
  FMX.Types, FMX.Controls, FMX.Forms, FMX.Graphics, FMX.Dialogs, FMX.StdCtrls,
  FMX.Controls.Presentation, FMX.Memo.Types, FMX.ScrollBox, FMX.Memo, FMX.Layouts,
  FMX.ListBox, FMX.Menus,
  IdContext, IdTCPServer, IdUDPClient,
  uNetworks;

type
  { One sender session: its greeting, file and lines not yet shown. }
  TLogSession = class
  public
    { Session id from the greeting (stays the same across reconnects). }
    Id: string;
    { Program name from the greeting. }
    App: string;
    { Platform text from the greeting. }
    Platform: string;
    { Machine name from the greeting. }
    Machine: string;
    { IP address the session connected from. }
    PeerIP: string;
    { Full path of the session's log file. }
    FileName: string;
    { Lines received so far. }
    LineCount: Integer;
    { A worker thread is currently connected for this session. }
    Connected: Boolean;
    { Lines received but not yet shown (taken by the UI timer). }
    NewLines: TStringList;
    { Creates an empty session. }
    constructor Create;
    { Frees the session. }
    destructor Destroy; override;
    { Text of the session's row in the list. }
    function Caption: string;
  end;

  { LogReceiver main form. }
  TfrmReceiver = class(TForm)
    { File menu. }
    MainMenu1: TMainMenu;
    { File. }
    mnuFile: TMenuItem;
    { File > Exit. }
    mnuExit: TMenuItem;
    { The "listen on" row, shown until listening starts. }
    layChoose: TLayout;
    { Caption of @link(cbNetwork). }
    lblChoose: TLabel;
    { This machine's networks (see unit uNetworks for the order). }
    cbNetwork: TComboBox;
    { Starts listening on the chosen network. }
    btnListen: TButton;
    { Where the receiver can be reached and where logs are saved. }
    lblInfo: TLabel;
    { One row per session; the selected one is shown in @link(memLines). }
    lbSessions: TListBox;
    { Splitter between the session list and the lines. }
    splSessions: TSplitter;
    { Lines of the selected session. }
    memLines: TMemo;
    { What happened last (connections, refusals, errors). }
    lblStatus: TLabel;
    { Moves new lines from the sessions into the UI. }
    tmUI: TTimer;
    { Broadcasts the announcement once a second. }
    tmAnnounce: TTimer;
    { Starts the server and the announcements. }
    procedure FormCreate(Sender: TObject);
    { Stops the server before the controls go. }
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
    { Shows new lines and session changes. }
    procedure tmUITimer(Sender: TObject);
    { Sends the UDP announcement. }
    procedure tmAnnounceTimer(Sender: TObject);
    { Another session was selected. }
    procedure lbSessionsChange(Sender: TObject);
    { OK: starts listening on the network chosen in @link(cbNetwork). }
    procedure btnListenClick(Sender: TObject);
    { File > Exit. }
    procedure mnuExitClick(Sender: TObject);
  private
    { The networks listed in @link(cbNetwork), in the same order. }
    FChoices: TNetworkChoices;
    { LogReceiver.ini in @link(FFolder): remembers the network chosen last. }
    FIniFile: string;
    { The TCP server senders connect to. }
    FServer: TIdTCPServer;
    { Sends the UDP announcement. }
    FAnnouncer: TIdUDPClient;
    { Guards @link(FSessions) and every session's fields. }
    FLock: TCriticalSection;
    { Every session accepted since start (kept after disconnecting). }
    FSessions: TObjectList<TLogSession>;
    { Which session each connection belongs to. }
    FContexts: TDictionary<TIdContext, TLogSession>;
    { Folder the log files are written to. }
    FFolder: string;
    { The session shown in @link(memLines), or @nil. }
    FShown: TLogSession;
    { Set when sessions were added or changed state (list needs redrawing). }
    FListChanged: Boolean;
    { Name sent in the announcement (this machine's name). }
    FName: string;
    { Where the announcement goes: the chosen network's directed broadcast
      address (192.168.1.255, ...) and 255.255.255.255. Windows may send
      255.255.255.255 out of another adapter (with a VPN, the VPN), so the
      network is also addressed directly. }
    FTargets: TStringList;
    { The window is closing: workers stop waiting for answers. }
    FClosing: Boolean;
    { TCP port actually listened on (RL_DEFAULT_TCP_PORT or one of the next
      ones if it was taken); 0 while not listening. }
    FPort: Integer;
    { The session list is being rebuilt: ignore its OnChange. }
    FUpdatingList: Boolean;
    { Shows S in @link(lblStatus) (main thread only). }
    procedure SetStatus(const S: string);
    { Server: sets UTF-8 for the new connection. }
    procedure ServerConnect(AContext: TIdContext);
    { Server: greeting / accept on the first call, then one line per call. }
    procedure ServerExecute(AContext: TIdContext);
    { Server: marks the connection's session as disconnected. }
    procedure ServerDisconnect(AContext: TIdContext);
    { Handles a greeting line; returns the accepted session or @nil. }
    function Greet(AContext: TIdContext; const AHello: string): TLogSession;
    { Appends ALine to the session's file and its pending lines. }
    procedure AddLine(ASession: TLogSession; const ALine: string);
  end;

var
  { The main form instance. }
  frmReceiver: TfrmReceiver;

implementation

{$R *.fmx}

uses
  System.IOUtils, System.StrUtils, System.IniFiles, FMX.DialogService.Sync,
  IdGlobal, IdStack, IdSocketHandle, RemoteLog.Protocol;

type
  { An Accept question shared by a worker thread and the main thread. An
    interface, so it lives until both are done with it (the worker may give
    up before the user answers). }
  IAcceptPrompt = interface
    ['{9145DA9C-7FCE-416A-8BAA-B7D42B0861E6}']
    { The question shown to the user. }
    function GetQuestion: string;
    { The user's answer (mrNo until answered). }
    function GetAnswer: TModalResult;
    { Sets the answer (main thread). }
    procedure SetAnswer(AValue: TModalResult);
    { Signalled once the user has answered. }
    function GetDone: TEvent;
    { The question shown to the user. }
    property Question: string read GetQuestion;
    { The user's answer. }
    property Answer: TModalResult read GetAnswer write SetAnswer;
    { Signalled once the user has answered. }
    property Done: TEvent read GetDone;
  end;

  { Implementation of @link(IAcceptPrompt). }
  TAcceptPrompt = class(TInterfacedObject, IAcceptPrompt)
  private
    FQuestion: string;
    FAnswer: TModalResult;
    FDone: TEvent;
  public
    constructor Create(const AQuestion: string);
    destructor Destroy; override;
    function GetQuestion: string;
    function GetAnswer: TModalResult;
    procedure SetAnswer(AValue: TModalResult);
    function GetDone: TEvent;
  end;

constructor TAcceptPrompt.Create(const AQuestion: string);
begin
  inherited Create;
  FQuestion := AQuestion;
  FAnswer := mrNo;
  FDone := TEvent.Create(nil, True, False, '');
end;

destructor TAcceptPrompt.Destroy;
begin
  FDone.Free;
  inherited;
end;

function TAcceptPrompt.GetQuestion: string;
begin
  Result := FQuestion;
end;

function TAcceptPrompt.GetAnswer: TModalResult;
begin
  Result := FAnswer;
end;

procedure TAcceptPrompt.SetAnswer(AValue: TModalResult);
begin
  FAnswer := AValue;
end;

function TAcceptPrompt.GetDone: TEvent;
begin
  Result := FDone;
end;

{ Appends AText to AFile as UTF-8 without a byte order mark (creates the
  file if needed). }
procedure AppendUtf8(const AFile, AText: string);
var
  FS: TFileStream;
  Bytes: TBytes;
begin
  Bytes := TEncoding.UTF8.GetBytes(AText);
  if TFile.Exists(AFile) then
    FS := TFileStream.Create(AFile, fmOpenWrite or fmShareDenyNone)
  else
    FS := TFileStream.Create(AFile, fmCreate);
  try
    FS.Seek(0, soEnd);
    if Length(Bytes) > 0 then
      FS.WriteBuffer(Bytes[0], Length(Bytes));
  finally
    FS.Free;
  end;
end;

{ Characters that are safe in a file name; anything else becomes '_'. }
function SafeName(const S: string): string;
var
  I: Integer;
begin
  Result := S;
  for I := 1 to Length(Result) do
    if not CharInSet(Result[I], ['A'..'Z', 'a'..'z', '0'..'9', '-', '.']) then
      Result[I] := '_';
end;

{ TLogSession }

constructor TLogSession.Create;
begin
  inherited Create;
  NewLines := TStringList.Create;
end;

destructor TLogSession.Destroy;
begin
  NewLines.Free;
  inherited;
end;

function TLogSession.Caption: string;
begin
  Result := Format('%s on %s (%s) - %d line(s)%s',
    [App, Machine, PeerIP, LineCount, IfThen(Connected, '', ' - disconnected')]);
end;

{ TfrmReceiver }

procedure TfrmReceiver.FormCreate(Sender: TObject);
var
  I, Sel: Integer;
  Last: string;
  Ini: TMemIniFile;
begin
  FLock := TCriticalSection.Create;
  FSessions := TObjectList<TLogSession>.Create(True);
  FContexts := TDictionary<TIdContext, TLogSession>.Create;
  FFolder := TPath.Combine(TPath.GetDocumentsPath, 'LogReceiver');
  ForceDirectories(FFolder);
  FIniFile := TPath.Combine(FFolder, 'LogReceiver.ini');
  FTargets := TStringList.Create;
  FServer := TIdTCPServer.Create(nil);
  FServer.OnConnect := ServerConnect;
  FServer.OnExecute := ServerExecute;
  FServer.OnDisconnect := ServerDisconnect;
  FAnnouncer := TIdUDPClient.Create(nil);
  FAnnouncer.BroadcastEnabled := True;

  TIdStack.IncUsage;
  try
    FName := GStack.HostName;
  finally
    TIdStack.DecUsage;
  end;
  // the networks, real one first (unit uNetworks); the one chosen last
  // time is preselected if it is still there
  Last := '';
  try
    Ini := TMemIniFile.Create(FIniFile);
    try
      Last := Ini.ReadString('Listen', 'IP', '');
    finally
      Ini.Free;
    end;
  except
    // no settings yet
  end;
  try
    FChoices := LocalNetworks;
  except
    on E: Exception do
    begin
      FChoices := nil;
      SetStatus('Could not list the networks: ' + E.Message);
    end;
  end;
  Sel := 0;
  for I := 0 to High(FChoices) do
  begin
    cbNetwork.Items.Add(NetworkText(FChoices[I]));
    if FChoices[I].IP = Last then
      Sel := I;
  end;
  if Length(FChoices) > 0 then
  begin
    cbNetwork.ItemIndex := Sel;
    lblInfo.Text := ' Choose the network the sending device is on, then OK. LogReceiver listens '
      + 'on that address only. Logs: ' + FFolder;
    SetStatus('The first time, allow LogReceiver through the firewall on private networks.');
  end
  else
  begin
    btnListen.Enabled := False;
    lblInfo.Text := ' This machine has no IPv4 network. Connect it to the network and start '
      + 'LogReceiver again.';
  end;
end;

procedure TfrmReceiver.btnListenClick(Sender: TObject);
var
  C: TNetworkChoice;
  B: TIdSocketHandle;
  Failure, Target: string;
  P: Integer;
  Ini: TMemIniFile;
begin
  if (cbNetwork.ItemIndex < 0) or (cbNetwork.ItemIndex > High(FChoices)) then
    Exit;
  C := FChoices[cbNetwork.ItemIndex];
  // the default port, or the next free one of RL_PORT_TRIES (another
  // LogReceiver or another program may have it); the announcement carries
  // the port, so senders that discover the receiver need not know it
  FPort := 0;
  Failure := '';
  for P := RL_DEFAULT_TCP_PORT to RL_DEFAULT_TCP_PORT + RL_PORT_TRIES - 1 do
  begin
    try
      FServer.Bindings.Clear;
      B := FServer.Bindings.Add;
      B.IPVersion := Id_IPv4;
      B.IP := C.IP;
      B.Port := P;
      FServer.DefaultPort := P;
      FServer.Active := True;
      FPort := P;
      Break;
    except
      on E: Exception do
      begin
        if Failure = '' then
          Failure := E.Message;
        try
          FServer.Active := False;
        except
          // not open: nothing to close
        end;
      end;
    end;
  end;
  if FPort = 0 then
  begin
    lblInfo.Text := Format(' Could not listen on %s, TCP ports %d-%d (first error: %s). Choose '
      + 'another network or close other LogReceivers.',
      [C.IP, RL_DEFAULT_TCP_PORT, RL_DEFAULT_TCP_PORT + RL_PORT_TRIES - 1, Failure]);
    Exit;
  end;
  // announcements leave from the chosen address, to its own network and
  // to 255.255.255.255
  FTargets.Clear;
  Target := DirectedBroadcast(C.IP, C.Mask);
  if Target <> '' then
    FTargets.Add(Target);
  FTargets.Add('255.255.255.255');
  FAnnouncer.BoundIP := C.IP;
  tmAnnounce.Enabled := True;
  layChoose.Visible := False;
  lblInfo.Text := Format(' Listening on %s port %d%s. Announced on UDP port %d (to %s). Logs: %s',
    [C.IP, FPort, IfThen(C.Name <> '', ' (' + C.Name + ')', ''), RL_DISCOVERY_PORT,
     FTargets.CommaText, FFolder]);
  if FPort <> RL_DEFAULT_TCP_PORT then
    SetStatus(Format('TCP port %d was in use, so port %d is used: senders that find this receiver '
      + 'automatically need nothing.', [RL_DEFAULT_TCP_PORT, FPort]))
  else
    SetStatus('Waiting for senders.');
  try
    Ini := TMemIniFile.Create(FIniFile);
    try
      Ini.WriteString('Listen', 'IP', C.IP);
      Ini.UpdateFile;
    finally
      Ini.Free;
    end;
  except
    // only a convenience
  end;
end;

procedure TfrmReceiver.mnuExitClick(Sender: TObject);
begin
  Close;
end;

procedure TfrmReceiver.FormClose(Sender: TObject; var Action: TCloseAction);
begin
  lbSessions.OnChange := nil;
  tmAnnounce.Enabled := False;
  tmUI.Enabled := False;
  // Active := False waits for the worker threads; a worker waiting for an
  // Accept answer notices FClosing within 200 ms and gives up (it never
  // waits on the main thread itself, so this cannot deadlock)
  FClosing := True;
  FServer.Active := False;
  FreeAndNil(FServer);
  FreeAndNil(FAnnouncer);
  FreeAndNil(FContexts);
  FreeAndNil(FSessions);
  FreeAndNil(FTargets);
  FreeAndNil(FLock);
end;

procedure TfrmReceiver.SetStatus(const S: string);
begin
  lblStatus.Text := ' ' + FormatDateTime('hh:nn:ss', Now) + '  ' + S;
end;

procedure TfrmReceiver.tmAnnounceTimer(Sender: TObject);
var
  I: Integer;
begin
  // to every network separately (see FTargets); one failing (adapter gone,
  // no network for the moment) does not stop the others
  for I := 0 to FTargets.Count - 1 do
    try
      FAnnouncer.Broadcast(Format('%s %s %d %s', [RL_ANNOUNCE, RL_VERSION, FPort, FName]),
        RL_DISCOVERY_PORT, FTargets[I], IndyTextEncoding_UTF8);
    except
      // try again on the next tick
    end;
end;

procedure TfrmReceiver.ServerConnect(AContext: TIdContext);
begin
  AContext.Connection.IOHandler.DefStringEncoding := IndyTextEncoding_UTF8;
end;

function TfrmReceiver.Greet(AContext: TIdContext; const AHello: string): TLogSession;
var
  Fields: TArray<string>;
  Session: TLogSession;
  PeerIP, Question: string;
  Known: Boolean;
  Answer: TModalResult;
  Prompt: IAcceptPrompt;
  I: Integer;
begin
  Result := nil;
  if not AHello.StartsWith(RL_HELLO + ' ') then
    Exit;
  // HELLO <app>|<platform>|<machine>|<session>
  Fields := AHello.Substring(Length(RL_HELLO) + 1).Split([RL_FIELD_SEPARATOR]);
  SetLength(Fields, 4);   // missing fields become ''
  PeerIP := AContext.Binding.PeerIP;

  Session := nil;
  FLock.Enter;
  try
    for I := 0 to FSessions.Count - 1 do
      if (FSessions[I].Id <> '') and (FSessions[I].Id = Fields[3]) then
        Session := FSessions[I];
  finally
    FLock.Leave;
  end;
  Known := Session <> nil;

  if not Known then
  begin
    Question := Format('Accept the log of %s from %s (%s, %s)?',
      [Fields[0], Fields[2], PeerIP, Fields[1]]);
    Prompt := TAcceptPrompt.Create(Question);   // reference counted: outlives either side
    TThread.Queue(nil,
      procedure
      begin
        if FClosing then
          Prompt.Answer := mrNo
        else
          Prompt.Answer := TDialogServiceSync.MessageDialog(Prompt.Question, TMsgDlgType.mtConfirmation,
            [TMsgDlgBtn.mbYes, TMsgDlgBtn.mbNo], TMsgDlgBtn.mbNo, 0);
        Prompt.Done.SetEvent;
      end);
    // wait for the user, but give up when the window closes or the sender
    // goes away (2 minutes, as the sender waits)
    Answer := mrNo;
    for I := 1 to 600 do
    begin
      if Prompt.Done.WaitFor(200) = wrSignaled then
      begin
        Answer := Prompt.Answer;
        Break;
      end;
      // a 0-byte read notices a sender that has closed its end
      AContext.Connection.IOHandler.CheckForDataOnSource(0);
      if FClosing or not AContext.Connection.Connected then
        Break;
    end;
    if Answer <> mrYes then
    begin
      TThread.Queue(nil,
        procedure
        begin
          if not FClosing then
            SetStatus(Format('Refused %s from %s', [Fields[0], PeerIP]));
        end);
      Exit;
    end;
    Session := TLogSession.Create;
    Session.Id := Fields[3];
    Session.App := Fields[0];
    Session.Platform := Fields[1];
    Session.Machine := Fields[2];
    Session.FileName := TPath.Combine(FFolder, Format('%s_%s_%s.log',
      [SafeName(Session.Id), SafeName(Session.App), SafeName(Session.Machine)]));
  end;

  FLock.Enter;
  try
    Session.PeerIP := PeerIP;
    Session.Connected := True;
    if not Known then
      FSessions.Add(Session);
    FContexts.AddOrSetValue(AContext, Session);
    FListChanged := True;
  finally
    FLock.Leave;
  end;
  AddLine(Session, Format('--- %s: %s (%s) %s from %s, platform %s ---',
    [FormatDateTime('yyyy-mm-dd hh:nn:ss', Now), IfThen(Known, 'reconnected', 'accepted'),
     Session.App, Session.Machine, PeerIP, Session.Platform]));
  Result := Session;
end;

procedure TfrmReceiver.ServerExecute(AContext: TIdContext);
var
  Session: TLogSession;
  Line: string;
begin
  FLock.Enter;
  try
    if not FContexts.TryGetValue(AContext, Session) then
      Session := nil;
  finally
    FLock.Leave;
  end;
  Line := AContext.Connection.IOHandler.ReadLn;
  if Session = nil then
  begin
    // first line of the connection: the greeting
    Session := Greet(AContext, Line);
    if Session = nil then
    begin
      AContext.Connection.IOHandler.WriteLn(RL_REFUSED);
      AContext.Connection.Disconnect;
    end
    else
      AContext.Connection.IOHandler.WriteLn(RL_ACCEPTED);
  end
  else
    AddLine(Session, Line);
end;

procedure TfrmReceiver.ServerDisconnect(AContext: TIdContext);
var
  Session: TLogSession;
begin
  FLock.Enter;
  try
    if FContexts.TryGetValue(AContext, Session) then
    begin
      FContexts.Remove(AContext);
      // a reconnect may already have a new connection for this session
      Session.Connected := FContexts.ContainsValue(Session);
      FListChanged := True;
    end;
  finally
    FLock.Leave;
  end;
end;

procedure TfrmReceiver.AddLine(ASession: TLogSession; const ALine: string);
begin
  // only this session's worker thread writes its file, so no lock is needed
  // for the file itself; the counters and pending lines are shared with the UI
  try
    AppendUtf8(ASession.FileName, ALine + sLineBreak);
  except
    // a file error must not end the connection; the line is still shown
  end;
  FLock.Enter;
  try
    Inc(ASession.LineCount);
    ASession.NewLines.Add(ALine);
  finally
    FLock.Leave;
  end;
end;

procedure TfrmReceiver.tmUITimer(Sender: TObject);
var
  I, Sel: Integer;
  Show, Captions: TStringList;
  Changed: Boolean;
  ShownBefore: TLogSession;
begin
  Show := TStringList.Create;
  Captions := TStringList.Create;
  try
    // copy everything needed under the lock; touch controls only after it
    // (changing ItemIndex fires lbSessionsChange, which takes the lock too)
    FLock.Enter;
    try
      Changed := FListChanged or (lbSessions.Count <> FSessions.Count);
      FListChanged := False;
      for I := 0 to FSessions.Count - 1 do
        Captions.Add(FSessions[I].Caption);
      ShownBefore := FShown;
      if FShown <> nil then
      begin
        Show.Assign(FShown.NewLines);
        FShown.NewLines.Clear;
      end;
      // lines of sessions not shown wait in NewLines; they are in the file
      // anyway, so keep the list short
      for I := 0 to FSessions.Count - 1 do
        if (FSessions[I] <> FShown) and (FSessions[I].NewLines.Count > 5000) then
          FSessions[I].NewLines.Clear;
    finally
      FLock.Leave;
    end;
    if Changed then
    begin
      // rebuilding the list fires OnChange (Clear selects nothing): ignore
      // that, and select the session shown before, or the newest one
      FUpdatingList := True;
      try
        lbSessions.BeginUpdate;
        try
          lbSessions.Clear;
          lbSessions.Items.AddStrings(Captions);
        finally
          lbSessions.EndUpdate;
        end;
      finally
        FUpdatingList := False;
      end;
      Sel := -1;
      if ShownBefore <> nil then
      begin
        FLock.Enter;
        try
          Sel := FSessions.IndexOf(ShownBefore);
        finally
          FLock.Leave;
        end;
      end;
      if Sel < 0 then
        Sel := Captions.Count - 1;
      lbSessions.ItemIndex := Sel;   // loads the file only if it is another session
    end
    else
      for I := 0 to Captions.Count - 1 do
        if lbSessions.ListItems[I].Text <> Captions[I] then
          lbSessions.ListItems[I].Text := Captions[I];
    // (if another session was selected meanwhile, its file has just been
    // loaded and these lines belong to the previous one)
    if (Show.Count > 0) and (FShown = ShownBefore) then
    begin
      memLines.Lines.BeginUpdate;
      try
        memLines.Lines.AddStrings(Show);
      finally
        memLines.Lines.EndUpdate;
      end;
      memLines.GoToTextEnd;
    end;
  finally
    Captions.Free;
    Show.Free;
  end;
end;

procedure TfrmReceiver.lbSessionsChange(Sender: TObject);
var
  Session: TLogSession;
  FS: TFileStream;
begin
  if FUpdatingList or FClosing or (FLock = nil) then
    Exit;
  Session := nil;
  FLock.Enter;
  try
    if (lbSessions.ItemIndex >= 0) and (lbSessions.ItemIndex < FSessions.Count) then
      Session := FSessions[lbSessions.ItemIndex];
    if Session = FShown then
      Exit;
    FShown := Session;
    if Session <> nil then
      Session.NewLines.Clear;   // the file holds them all: reload from it below
  finally
    FLock.Leave;
  end;
  memLines.Lines.Clear;
  if (Session <> nil) and TFile.Exists(Session.FileName) then
    try
      // shared read: a worker may be appending at this moment
      FS := TFileStream.Create(Session.FileName, fmOpenRead or fmShareDenyNone);
      try
        memLines.Lines.LoadFromStream(FS, TEncoding.UTF8);
      finally
        FS.Free;
      end;
      memLines.GoToTextEnd;
    except
      on E: Exception do
        SetStatus('Could not read ' + Session.FileName + ': ' + E.Message);
    end;
end;

end.
