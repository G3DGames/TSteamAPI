{ @abstract(Modal form of SteamInputDemo for choosing the LogReceiver to
  send the log to - part of the OPTIONAL remote logging, see
  RemoteLogging/README.md.)

  Shown only when discovery did not find exactly one receiver (none, or
  several): with one, the demo connects to it without asking. The form
  lists the receivers heard, fills the address box from the selected one,
  can search again (in the background, the window keeps running) and
  accepts an address typed by hand (@code(IP:port), or just the IP for
  the default port). It opens centred on the main window. }
unit uRemoteLogTarget;

interface

uses
  System.SysUtils, System.Types, System.UITypes, System.Classes,
  FMX.Types, FMX.Controls, FMX.Forms, FMX.StdCtrls, FMX.Layouts, FMX.ListBox,
  FMX.Edit, FMX.Controls.Presentation,
  RemoteLog.Sender;

type
  { Chooses or types the receiver address; see @link(Execute). }
  TfrmRemoteLogTarget = class(TForm)
    { What was found and what to do. }
    lblHint: TLabel;
    { The receivers heard (name - host:port). }
    lbFound: TListBox;
    { Holds @link(lblAddress) and @link(edtAddress). }
    layAddress: TLayout;
    { Caption of @link(edtAddress). }
    lblAddress: TLabel;
    { The address to connect to, IP:port. }
    edtAddress: TEdit;
    { Holds the buttons. }
    layButtons: TLayout;
    { Listens for receivers again (2.5 s, in the background). }
    btnSearch: TButton;
    { Connects to the address in @link(edtAddress) (Enter). }
    btnConnect: TButton;
    { Closes without connecting (Esc). }
    btnCancel: TButton;
    { Copies the selected receiver into @link(edtAddress). }
    procedure lbFoundChange(Sender: TObject);
    { Connects to the double-clicked receiver. }
    procedure lbFoundDblClick(Sender: TObject);
    { Starts a new search. }
    procedure btnSearchClick(Sender: TObject);
    { Checks the address and closes with mrOk. }
    procedure btnConnectClick(Sender: TObject);
    { Ends a search still running. }
    procedure FormDestroy(Sender: TObject);
  private
    { Receivers listed in @link(lbFound). }
    FFound: TRemoteLogReceiverArray;
    { The search started by @link(btnSearch), or @nil. }
    FDiscovery: TRemoteLogDiscovery;
    { Host chosen (valid after mrOk). }
    FHost: string;
    { Port chosen (valid after mrOk). }
    FPort: Word;
    { Fills @link(lbFound) and @link(lblHint) from @link(FFound). }
    procedure ShowFound(const AError: string);
    { Result of a search started here. }
    procedure DiscoveryDone(Sender: TObject; const AFound: TRemoteLogReceiverArray;
      const AError: string);
    { Splits @link(edtAddress) into @link(FHost) / @link(FPort); False when
      it is not an address. }
    function ParseAddress: Boolean;
  public
    { Shows the form modally, centred on AOwner (the main window), listing
      AFound (AError: why discovery failed, or ''). Returns True with the
      chosen AHost / APort, False when cancelled. }
    class function Execute(AOwner: TComponent; const AFound: TRemoteLogReceiverArray;
      const AError: string; out AHost: string; out APort: Word): Boolean;
  end;

implementation

{$R *.fmx}

uses
  RemoteLog.Protocol;

{ Address text of a receiver: host:port. }
function AddressOf(const R: TRemoteLogReceiverInfo): string;
begin
  Result := Format('%s:%d', [R.Host, R.Port]);
end;

class function TfrmRemoteLogTarget.Execute(AOwner: TComponent; const AFound: TRemoteLogReceiverArray;
  const AError: string; out AHost: string; out APort: Word): Boolean;
var
  F: TfrmRemoteLogTarget;
begin
  AHost := '';
  APort := 0;
  F := TfrmRemoteLogTarget.Create(AOwner);
  try
    F.FFound := AFound;
    F.ShowFound(AError);
    Result := F.ShowModal = mrOk;
    if Result then
    begin
      AHost := F.FHost;
      APort := F.FPort;
    end;
  finally
    F.Free;
  end;
end;

procedure TfrmRemoteLogTarget.ShowFound(const AError: string);
var
  I: Integer;
begin
  lbFound.Clear;
  for I := 0 to High(FFound) do
    lbFound.Items.Add(Format('%s  -  %s', [FFound[I].Name, AddressOf(FFound[I])]));
  if Length(FFound) > 0 then
  begin
    lblHint.Text := Format('%d LogReceiver apps answered. Choose one (or type an address) '
      + 'and press Connect, then click Yes in that LogReceiver.', [Length(FFound)]);
    lbFound.ItemIndex := 0;
    edtAddress.Text := AddressOf(FFound[0]);
  end
  else if AError <> '' then
    lblHint.Text := 'Could not search the network (' + AError + '). Type the address '
      + 'LogReceiver shows on its top line, e.g. 192.168.1.20:47812.'
  else
    lblHint.Text := 'No LogReceiver answered within 2.5 s (none running, or the network '
      + 'blocks broadcasts). Start LogReceiver and search again, or type the address it shows '
      + 'on its top line, e.g. 192.168.1.20:47812.';
end;

procedure TfrmRemoteLogTarget.lbFoundChange(Sender: TObject);
var
  I: Integer;
begin
  I := lbFound.ItemIndex;
  if (I >= 0) and (I <= High(FFound)) then
    edtAddress.Text := AddressOf(FFound[I]);
end;

procedure TfrmRemoteLogTarget.lbFoundDblClick(Sender: TObject);
begin
  lbFoundChange(Sender);
  btnConnectClick(Sender);
end;

procedure TfrmRemoteLogTarget.btnSearchClick(Sender: TObject);
begin
  // the previous search has delivered its result (the button is disabled
  // while one runs), so freeing it here is safe
  FreeAndNil(FDiscovery);
  btnSearch.Enabled := False;
  lblHint.Text := 'Searching for LogReceiver apps (2.5 s)...';
  FDiscovery := TRemoteLogDiscovery.Create(2500, DiscoveryDone);
end;

procedure TfrmRemoteLogTarget.DiscoveryDone(Sender: TObject; const AFound: TRemoteLogReceiverArray;
  const AError: string);
begin
  // FDiscovery is NOT freed here (it is the caller of this handler)
  btnSearch.Enabled := True;
  FFound := AFound;
  ShowFound(AError);
end;

function TfrmRemoteLogTarget.ParseAddress: Boolean;
var
  Text: string;
  P, Port: Integer;
begin
  Text := Trim(edtAddress.Text);
  P := Text.LastIndexOf(':');
  if P > 0 then
  begin
    FHost := Trim(Text.Substring(0, P));
    Port := StrToIntDef(Trim(Text.Substring(P + 1)), 0);
  end
  else
  begin
    FHost := Text;
    Port := RL_DEFAULT_TCP_PORT;
  end;
  Result := (FHost <> '') and (Port > 0) and (Port <= 65535);
  if Result then
    FPort := Port;
end;

procedure TfrmRemoteLogTarget.btnConnectClick(Sender: TObject);
begin
  if ParseAddress then
    ModalResult := mrOk
  else
    lblHint.Text := '"' + Trim(edtAddress.Text) + '" is not an address. Type IP:port as '
      + 'LogReceiver shows it, e.g. 192.168.1.20:47812 (just the IP means port '
      + IntToStr(RL_DEFAULT_TCP_PORT) + ').';
end;

procedure TfrmRemoteLogTarget.FormDestroy(Sender: TObject);
begin
  // waits for a search still running (at most 2.5 s) and drops its result
  FreeAndNil(FDiscovery);
end;

end.
