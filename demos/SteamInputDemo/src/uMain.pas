{ @abstract(Main form of the Steam Input test (FMX).)

  Everything is on the form (uMain.fmx): the @code(TSteamAPI) root and a
  @code(TSteamInput) component with its device events wired in the form
  file. Start opens Steam; @link(TfrmInput.SteamInitialized) then starts
  ISteamInput with an explicit RunFrame, enables device callbacks and points
  Steam at steam_input_manifest.vdf next to the executable (the action sets
  InGame and Menu). A 16 ms timer is the "game loop": RunFrame, the
  connected controllers, then every action of the active set on the selected
  controller - all on the UI thread, so no ISteamInput call crosses threads
  whatever the update mode.

  The log records what a test needs: controllers appearing / disappearing,
  each button press and release, stick / trigger movement (at most four
  lines a second per action), the first non-zero motion data, the bindings
  of every action with the path of Steam's glyph for each (shown in the
  Bindings list), and the results of Bindings / Rumble. Every line is also
  appended to SteamInputDemo.log next to the executable. }
unit uMain;

interface

uses
  System.SysUtils, System.Types, System.UITypes, System.Classes,
  FMX.Types, FMX.Controls, FMX.Forms, FMX.Graphics, FMX.Dialogs, FMX.StdCtrls,
  FMX.Controls.Presentation, FMX.Memo.Types, FMX.ScrollBox, FMX.Memo,
  FMX.Layouts, FMX.ListBox,
  Steamworks.Types, Steamworks.SDKTypes, Steamworks.Callbacks, Steamworks.Core, Steamworks.Components,
  Steamworks.FMX, Steamworks.Plugin.Input;

type
  { The actions of steam_input_manifest.vdf. }
  TInputAction = (iaMove, iaCamera, iaThrottle, iaFire, iaJump, iaMenu, iaSelect, iaBack);
  { The action sets of steam_input_manifest.vdf. }
  TInputSet = (isInGame, isMenu);

  { Steam Input test form. }
  TfrmInput = class(TForm)
    { Toolbar holding the buttons. }
    pnlTop: TPanel;
    { Starts Steam (and with it ISteamInput). }
    btnStart: TButton;
    { Shuts Steam down. }
    btnStop: TButton;
    { Opens Steam's binding panel for the selected controller. }
    btnBindings: TButton;
    { Rumbles the selected controller for half a second. }
    btnRumble: TButton;
    { Writes the live state and every action's bindings to the log. }
    btnLogState: TButton;
    { Copies the log to the clipboard. }
    btnCopy: TButton;
    { Left column: controllers and live state. }
    layLeft: TLayout;
    { Caption of @link(lbControllers). }
    lblControllers: TLabel;
    { Connected controllers; the selected one is read. }
    lbControllers: TListBox;
    { Caption of @link(memState). }
    lblState: TLabel;
    { Live values of every action, refreshed by @link(tmPoll). }
    memState: TMemo;
    { Caption of @link(lbBindings). }
    lblBindings: TLabel;
    { One row per action: the buttons bound to it, with Steam's glyph of the
      first one. }
    lbBindings: TListBox;
    { The log. }
    memLog: TMemo;
    { The "game loop": RunFrame and reading the actions. }
    tmPoll: TTimer;
    { Ends the rumble started by @link(btnRumble). }
    tmRumble: TTimer;
    { The Steam root component. Active is False in the form: Start opens Steam. }
    SteamAPI1: TSteamAPI;
    { ISteamInput component; its events report devices and configurations. }
    SteamInput1: TSteamInput;
    { Debug-only settings, the log file, the state font. }
    procedure FormCreate(Sender: TObject);
    { Stops polling and shuts Steam down while the controls still exist. }
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
    { Handler of @link(btnStart). }
    procedure btnStartClick(Sender: TObject);
    { Handler of @link(btnStop). }
    procedure btnStopClick(Sender: TObject);
    { Handler of @link(btnBindings). }
    procedure btnBindingsClick(Sender: TObject);
    { Handler of @link(btnRumble). }
    procedure btnRumbleClick(Sender: TObject);
    { Handler of @link(btnLogState). }
    procedure btnLogStateClick(Sender: TObject);
    { Handler of @link(btnCopy). }
    procedure btnCopyClick(Sender: TObject);
    { Another controller was selected. }
    procedure lbControllersChange(Sender: TObject);
    { One frame of the "game loop". }
    procedure tmPollTimer(Sender: TObject);
    { Stops the rumble. }
    procedure tmRumbleTimer(Sender: TObject);
    { SteamAPI1.OnLog: core log messages. }
    procedure SteamLog(Sender: TObject; ALevel: TSteamLogLevel; const AMessage: string);
    { SteamAPI1.OnInitialized: Steam started - start ISteamInput. }
    procedure SteamInitialized(Sender: TObject);
    { SteamAPI1.OnInitFailed: Steam failed to start. }
    procedure SteamInitFailed(Sender: TObject; AResult: Integer; const AMessage: string);
    { SteamAPI1.OnShutdown: Steam shut down - stop polling. }
    procedure SteamShutdown(Sender: TObject);
    { SteamAPI1.OnSteamShutdown: the Steam client is exiting. }
    procedure SteamClientExit(Sender: TObject);
    { SteamInput1.OnSteamInputDeviceConnected (callback 2801). }
    procedure InputDeviceConnected(Sender: TObject; const AData: SteamInputDeviceConnected_t);
    { SteamInput1.OnSteamInputDeviceDisconnected (callback 2802). }
    procedure InputDeviceDisconnected(Sender: TObject; const AData: SteamInputDeviceDisconnected_t);
    { SteamInput1.OnSteamInputConfigurationLoaded (callback 2803). }
    procedure InputConfigurationLoaded(Sender: TObject; const AData: SteamInputConfigurationLoaded_t);
    { SteamInput1.OnSteamInputGamepadSlotChange (callback 2804). }
    procedure InputGamepadSlotChange(Sender: TObject; const AData: SteamInputGamepadSlotChange_t);
  private
    { Log file every line is appended to; '' if it cannot be written. }
    FLogFile: string;
    { Action set handles (0 until Steam has loaded the manifest). }
    FSetHandles: array[TInputSet] of InputActionSetHandle_t;
    { Action handles, digital or analog (0 until resolved). }
    FActionHandles: array[TInputAction] of UInt64;
    { The action set activated on the controller. }
    FCurrentSet: TInputSet;
    { Controllers seen in the last frame. }
    FControllers: TSteamInputHandleArray;
    { The controller read (0 = none). }
    FActive: InputHandle_t;
    { Pressed state of each digital action in the last frame. }
    FPressed: array[TInputAction] of Boolean;
    { Last logged x of each analog action. }
    FLoggedX: array[TInputAction] of Single;
    { Last logged y of each analog action. }
    FLoggedY: array[TInputAction] of Single;
    { When each analog action was last logged. }
    FLoggedAt: array[TInputAction] of TDateTime;
    { When the handles were last looked up. }
    FLastResolve: TDateTime;
    { Every set and action handle is non-zero. }
    FResolved: Boolean;
    { The "handles still 0" hint was logged. }
    FResolveWarned: Boolean;
    { Bindings were logged for the current handles and controller. }
    FOriginsLogged: Boolean;
    { The first non-zero motion data was logged. }
    FMotionLogged: Boolean;
    { Guards @link(tmPollTimer) against re-entry. }
    FPolling: Boolean;
    { Guards @link(lbControllersChange) while the list is refilled. }
    FFillingList: Boolean;
    { Exceptions raised by the poll so far (polling stops at 3). }
    FPollErrors: Integer;
    { Text last put into @link(memState). }
    FStateText: string;
    { Appends a time-stamped line to @link(memLog) and the log file. }
    procedure AddLog(const S: string);
    { The started ISteamInput plug-in, or @nil. }
    function Input: TSteamInputPlugin;
    { Full path of steam_input_manifest.vdf, or '' when not found. }
    function ManifestPath: string;
    { Forgets every handle and controller (Steam stopped). }
    procedure ResetState;
    { Looks up the action set and action handles; logs them once resolved. }
    procedure ResolveHandles(P: TSteamInputPlugin);
    { Reads the connected controllers and logs any change. }
    procedure RefreshControllers(P: TSteamInputPlugin);
    { Logs the bindings (origins) of every action on the active controller
      and lists them in @link(lbBindings) with Steam's glyphs. }
    procedure LogOrigins(P: TSteamInputPlugin);
    { Loads Steam's glyph of AOrigin into ABitmap; returns a log text (path
      and result). }
    function LoadGlyph(P: TSteamInputPlugin; AOrigin: EInputActionOrigin; ABitmap: TBitmap): string;
    { Activates ASet on the active controller (applied at the next RunFrame). }
    procedure SwitchSet(ASet: TInputSet);
    { "Xbox One controller (handle ..., gamepad index ...)". }
    function ControllerText(P: TSteamInputPlugin; AHandle: InputHandle_t): string;
    { Reads every action of the current set; logs edges and movement;
      returns the live-state text. }
    function ReadActions(P: TSteamInputPlugin): string;
  end;

var
  { The main form instance. }
  frmInput: TfrmInput;

implementation

{$R *.fmx}

uses
  System.IOUtils, System.DateUtils, System.StrUtils, FMX.Platform;

const
  { Manifest file name, next to the executable. }
  MANIFEST_FILE = 'steam_input_manifest.vdf';
  { Text of each log level. }
  LevelNames: array[TSteamLogLevel] of string = ('debug', 'info', 'warn', 'ERROR');
  { Action names as in the manifest. }
  ActionNames: array[TInputAction] of string =
    ('Move', 'Camera', 'Throttle', 'Fire', 'Jump', 'Menu', 'Select', 'Back');
  { Analog actions (StickPadGyro / AnalogTrigger); the rest are buttons. }
  ActionAnalog: array[TInputAction] of Boolean =
    (True, True, True, False, False, False, False, False);
  { The set each action belongs to. }
  ActionSet: array[TInputAction] of TInputSet =
    (isInGame, isInGame, isInGame, isInGame, isInGame, isInGame, isMenu, isMenu);
  { Action set names as in the manifest. }
  SetNames: array[TInputSet] of string = ('InGame', 'Menu');
  { Analog change that is logged (stick units, -1..1). }
  ANALOG_LOG_STEP = 0.2;
  { Fewest milliseconds between two log lines of one analog action. }
  ANALOG_LOG_MS = 250;

{ Fixed-format number for the log and the state (invariant decimal point). }
function F2(V: Single): string;
begin
  Result := FormatFloat('+0.00;-0.00;0.00', V, TFormatSettings.Invariant);
end;

{ Readable name of a Steam Input controller type. }
function InputTypeName(T: ESteamInputType): string;
begin
  case T of
    k_ESteamInputType_SteamController:      Result := 'Steam Controller';
    k_ESteamInputType_XBox360Controller:    Result := 'Xbox 360 controller';
    k_ESteamInputType_XBoxOneController:    Result := 'Xbox One / Series controller';
    k_ESteamInputType_GenericGamepad:       Result := 'generic gamepad';
    k_ESteamInputType_PS4Controller:        Result := 'PS4 controller';
    k_ESteamInputType_PS5Controller:        Result := 'PS5 controller';
    k_ESteamInputType_SwitchProController:  Result := 'Switch Pro controller';
    k_ESteamInputType_SwitchJoyConPair:     Result := 'Joy-Con pair';
    k_ESteamInputType_SwitchJoyConSingle:   Result := 'single Joy-Con';
    k_ESteamInputType_SteamDeckController:  Result := 'Steam Deck';
  else
    Result := 'controller type ' + IntToStr(Ord(T));
  end;
end;

{ Readable name of an analog source mode. }
function SourceModeName(M: EInputSourceMode): string;
begin
  case M of
    k_EInputSourceMode_None:           Result := 'none';
    k_EInputSourceMode_JoystickMove:   Result := 'joystick move';
    k_EInputSourceMode_JoystickCamera: Result := 'joystick camera';
    k_EInputSourceMode_JoystickMouse:  Result := 'joystick mouse';
    k_EInputSourceMode_AbsoluteMouse:  Result := 'absolute mouse';
    k_EInputSourceMode_RelativeMouse:  Result := 'relative mouse';
    k_EInputSourceMode_Trigger:        Result := 'trigger';
  else
    Result := 'mode ' + IntToStr(Ord(M));
  end;
end;

procedure TfrmInput.FormCreate(Sender: TObject);
begin
  FLogFile := TPath.Combine(ExpandFileName(ExtractFilePath(ParamStr(0))), 'SteamInputDemo.log');
  try
    TFile.WriteAllText(FLogFile, '');
  except
    FLogFile := '';
  end;
  // A form file cannot depend on the build configuration, so this is here:
{$IFDEF DEBUG}
  SteamAPI1.SetAppIdEnvironment := True;   // no steam_appid.txt needed
  SteamAPI1.RestartIfNecessary := False;   // never relaunch through Steam
{$ELSE}
  SteamAPI1.RestartIfNecessary := True;
{$ENDIF}
  // Fixed-width font for the live values (set here: a wrong font property
  // name in the form file would stop it loading)
  memState.StyledSettings := memState.StyledSettings - [TStyledSetting.Family];
{$IFDEF MSWINDOWS}
  memState.TextSettings.Font.Family := 'Consolas';
{$ELSE}
  {$IFDEF MACOS}
  memState.TextSettings.Font.Family := 'Menlo';
  {$ELSE}
  memState.TextSettings.Font.Family := 'Monospace';
  {$ENDIF}
{$ENDIF}
  ResetState;
  AddLog(Format('Steam Input test, AppID %d, %d plug-in class(es) linked',
    [SteamAPI1.AppID, Length(TSteamworks.RegisteredPlugins)]));
  if FLogFile <> '' then
    AddLog('Log file: ' + FLogFile)
  else
    AddLog('Log file could not be created; log is on screen only');
  if ManifestPath <> '' then
    AddLog('Action manifest: ' + ManifestPath)
  else
    AddLog('Action manifest ' + MANIFEST_FILE + ' NOT FOUND next to the executable '
      + '(the post-build event copies it from src\)');
  AddLog('Press Start Steam, then use a controller. Steam Input must be enabled '
    + 'for this game in the Steam client for Xbox / generic controllers.');
end;

procedure TfrmInput.FormClose(Sender: TObject; var Action: TCloseAction);
begin
  AddLog(Format('FormClose: window closing (Steam running: %s)', [BoolToStr(SteamAPI1.IsRunning, True)]));
  tmPoll.Enabled := False;
  tmRumble.Enabled := False;
  SteamAPI1.Close;
end;

procedure TfrmInput.AddLog(const S: string);
var
  Line: string;
begin
  Line := FormatDateTime('hh:nn:ss.zzz', Now) + '  ' + S;
  memLog.Lines.Add(Line);
  memLog.GoToTextEnd;
  if FLogFile <> '' then
  try
    TFile.AppendAllText(FLogFile, Line + sLineBreak);
  except
    FLogFile := '';
  end;
end;

function TfrmInput.Input: TSteamInputPlugin;
begin
  Result := SteamInput1.Plugin;
  if (Result <> nil) and not Result.Started then
    Result := nil;
end;

function TfrmInput.ManifestPath: string;
var
  Dir, P: string;
begin
  Dir := ExpandFileName(ExtractFilePath(ParamStr(0)));
  // next to the executable (post-build copy / deployment) ...
  P := TPath.Combine(Dir, MANIFEST_FILE);
  if not TFile.Exists(P) then
    // ... or in the project's src folder when run from .\<platform>\<config>
    P := ExpandFileName(TPath.Combine(Dir, '..' + PathDelim + '..' + PathDelim + 'src'
      + PathDelim + MANIFEST_FILE));
  if TFile.Exists(P) then
    Result := P
  else
    Result := '';
end;

procedure TfrmInput.ResetState;
var
  A: TInputAction;
  S: TInputSet;
begin
  for S := Low(TInputSet) to High(TInputSet) do
    FSetHandles[S] := 0;
  for A := Low(TInputAction) to High(TInputAction) do
  begin
    FActionHandles[A] := 0;
    FPressed[A] := False;
    FLoggedX[A] := 0;
    FLoggedY[A] := 0;
    FLoggedAt[A] := 0;
  end;
  FCurrentSet := isInGame;
  FControllers := nil;
  FActive := 0;
  FLastResolve := 0;
  FResolved := False;
  FResolveWarned := False;
  FOriginsLogged := False;
  FMotionLogged := False;
  FPollErrors := 0;
  FStateText := '';
end;

procedure TfrmInput.btnStartClick(Sender: TObject);
begin
  AddLog('Start pressed');
  if SteamAPI1.Open then
    AddLog('Open returned True: Steam is running')
  else
    AddLog('Open returned False: Steam did not start');
end;

procedure TfrmInput.btnStopClick(Sender: TObject);
begin
  AddLog('Stop pressed');
  SteamAPI1.Close;
end;

procedure TfrmInput.btnBindingsClick(Sender: TObject);
var
  P: TSteamInputPlugin;
begin
  P := Input;
  if (P = nil) or (FActive = 0) then
  begin
    AddLog('Bindings: no controller selected (press Start, connect a controller)');
    Exit;
  end;
  try
    if P.ShowBindingPanel(FActive) then
      AddLog('ShowBindingPanel: True (the Steam overlay shows the binding panel)')
    else
      AddLog('ShowBindingPanel: False - the overlay is not available to this process. '
        + 'Edit the layout in the Steam client instead: Library > this game > controller icon');
  except
    on E: Exception do AddLog('ShowBindingPanel failed: ' + E.Message);
  end;
end;

procedure TfrmInput.btnRumbleClick(Sender: TObject);
var
  P: TSteamInputPlugin;
begin
  P := Input;
  if (P = nil) or (FActive = 0) then
  begin
    AddLog('Rumble: no controller selected');
    Exit;
  end;
  try
    P.TriggerVibration(FActive, 40000, 40000);
    tmRumble.Enabled := True;
    AddLog('Rumble: TriggerVibration(40000, 40000) for 500 ms on ' + ControllerText(P, FActive));
  except
    on E: Exception do AddLog('TriggerVibration failed: ' + E.Message);
  end;
end;

procedure TfrmInput.tmRumbleTimer(Sender: TObject);
var
  P: TSteamInputPlugin;
begin
  tmRumble.Enabled := False;
  P := Input;
  if (P = nil) or (FActive = 0) then
    Exit;
  try
    P.TriggerVibration(FActive, 0, 0);
    AddLog('Rumble stopped: TriggerVibration(0, 0)');
  except
    on E: Exception do AddLog('TriggerVibration failed: ' + E.Message);
  end;
end;

procedure TfrmInput.btnLogStateClick(Sender: TObject);
var
  P: TSteamInputPlugin;
  L: TStringList;
  I: Integer;
begin
  P := Input;
  if P = nil then
  begin
    AddLog('Log state: Steam Input is not running - press Start first');
    Exit;
  end;
  L := TStringList.Create;
  try
    L.Text := FStateText;
    AddLog('--- state ---');
    for I := 0 to L.Count - 1 do
      AddLog('  ' + L[I]);
  finally
    L.Free;
  end;
  FOriginsLogged := False;
  if FActive <> 0 then
    LogOrigins(P);
end;

procedure TfrmInput.btnCopyClick(Sender: TObject);
var
  Svc: IFMXClipboardService;
begin
  if TPlatformServices.Current.SupportsPlatformService(IFMXClipboardService, Svc) then
  begin
    Svc.SetClipboard(memLog.Text);
    AddLog('Log copied to clipboard');
  end;
end;

procedure TfrmInput.lbControllersChange(Sender: TObject);
var
  P: TSteamInputPlugin;
  A: TInputAction;
begin
  if FFillingList then
    Exit;
  P := Input;
  if (P = nil) or (lbControllers.ItemIndex < 0) or (lbControllers.ItemIndex > High(FControllers)) then
    Exit;
  FActive := FControllers[lbControllers.ItemIndex];
  for A := Low(TInputAction) to High(TInputAction) do
    FPressed[A] := False;
  FOriginsLogged := False;
  FMotionLogged := False;
  AddLog('Reading ' + ControllerText(P, FActive));
end;

procedure TfrmInput.SteamLog(Sender: TObject; ALevel: TSteamLogLevel; const AMessage: string);
begin
  AddLog('[' + LevelNames[ALevel] + '] ' + AMessage);
end;

procedure TfrmInput.SteamInitialized(Sender: TObject);
var
  P: TSteamInputPlugin;
  Path: string;
begin
  AddLog('OnInitialized: Steam is running');
  ResetState;
  P := SteamInput1.Plugin;
  if P = nil then
  begin
    AddLog('ISteamInput plug-in is not active');
    Exit;
  end;
  try
    // Explicit RunFrame: the poll timer calls it on the UI thread right
    // before reading the actions, as a game loop would.
    if not P.Start(True) then
    begin
      AddLog('ISteamInput Init returned False');
      Exit;
    end;
    AddLog('ISteamInput started (Init(True): explicit RunFrame)');
    P.EnableDeviceCallbacks;
    AddLog('EnableDeviceCallbacks called (device connect / disconnect events)');
    Path := ManifestPath;
    if Path = '' then
      AddLog('Action manifest not found: actions will stay unbound (handles 0)')
    else
      AddLog(Format('SetInputActionManifestFilePath(%s): %s',
        [Path, BoolToStr(P.SetInputActionManifestFilePath(Path), True)]));
    AddLog(Format('Session input configuration settings: $%.4x', [P.GetSessionInputConfigurationSettings]));
    tmPoll.Enabled := True;
    AddLog(Format('Polling every %d ms', [tmPoll.Interval]));
  except
    on E: Exception do AddLog('Starting ISteamInput failed: ' + E.ClassName + ': ' + E.Message);
  end;
end;

procedure TfrmInput.SteamInitFailed(Sender: TObject; AResult: Integer; const AMessage: string);
begin
  AddLog(Format('OnInitFailed: result %d: %s', [AResult, AMessage]));
end;

procedure TfrmInput.SteamShutdown(Sender: TObject);
begin
  tmPoll.Enabled := False;
  tmRumble.Enabled := False;
  ResetState;
  FFillingList := True;
  try
    lbControllers.Clear;
  finally
    FFillingList := False;
  end;
  lbBindings.Clear;
  memState.Text := 'Steam is not running.';
  AddLog('OnShutdown: Steam shut down (ISteamInput was shut down first)');
end;

procedure TfrmInput.SteamClientExit(Sender: TObject);
begin
  AddLog('OnSteamShutdown: the Steam client is exiting');
end;

procedure TfrmInput.InputDeviceConnected(Sender: TObject; const AData: SteamInputDeviceConnected_t);
var
  P: TSteamInputPlugin;
begin
  P := Input;
  if P <> nil then
    AddLog('OnSteamInputDeviceConnected: ' + ControllerText(P, AData.m_ulConnectedDeviceHandle))
  else
    AddLog('OnSteamInputDeviceConnected: handle ' + UIntToStr(AData.m_ulConnectedDeviceHandle));
end;

procedure TfrmInput.InputDeviceDisconnected(Sender: TObject; const AData: SteamInputDeviceDisconnected_t);
begin
  AddLog('OnSteamInputDeviceDisconnected: handle ' + UIntToStr(AData.m_ulDisconnectedDeviceHandle));
end;

procedure TfrmInput.InputConfigurationLoaded(Sender: TObject; const AData: SteamInputConfigurationLoaded_t);
begin
  AddLog(Format('OnSteamInputConfigurationLoaded: app %d, handle %s, mapping by %s, revision %d.%d, '
    + 'uses Steam Input API %s, uses gamepad API %s',
    [AData.m_unAppID, UIntToStr(AData.m_ulDeviceHandle), AData.m_ulMappingCreator.ToString,
     AData.m_unMajorRevision, AData.m_unMinorRevision,
     BoolToStr(AData.m_bUsesSteamInputAPI, True), BoolToStr(AData.m_bUsesGamepadAPI, True)]));
  // a new layout: look the handles and bindings up again (all of them -
  // ResolveHandles only fills handles that are 0)
  FillChar(FSetHandles, SizeOf(FSetHandles), 0);
  FillChar(FActionHandles, SizeOf(FActionHandles), 0);
  FResolved := False;
  FLastResolve := 0;
  FOriginsLogged := False;
end;

procedure TfrmInput.InputGamepadSlotChange(Sender: TObject; const AData: SteamInputGamepadSlotChange_t);
begin
  AddLog(Format('OnSteamInputGamepadSlotChange: handle %s, %s, slot %d -> %d',
    [UIntToStr(AData.m_ulDeviceHandle), InputTypeName(AData.m_eDeviceType),
     AData.m_nOldGamepadSlot, AData.m_nNewGamepadSlot]));
end;

function TfrmInput.ControllerText(P: TSteamInputPlugin; AHandle: InputHandle_t): string;
begin
  Result := Format('%s (handle %s, gamepad index %d)',
    [InputTypeName(P.GetInputTypeForHandle(AHandle)), UIntToStr(AHandle),
     P.GetGamepadIndexForController(AHandle)]);
end;

procedure TfrmInput.ResolveHandles(P: TSteamInputPlugin);
var
  A: TInputAction;
  S: TInputSet;
  Missing, Text: string;
begin
  FLastResolve := Now;
  Missing := '';
  for S := Low(TInputSet) to High(TInputSet) do
  begin
    if FSetHandles[S] = 0 then
      FSetHandles[S] := P.GetActionSetHandle(SetNames[S]);
    if FSetHandles[S] = 0 then
      Missing := Missing + ' ' + SetNames[S];
  end;
  for A := Low(TInputAction) to High(TInputAction) do
  begin
    if FActionHandles[A] = 0 then
      if ActionAnalog[A] then
        FActionHandles[A] := P.GetAnalogActionHandle(ActionNames[A])
      else
        FActionHandles[A] := P.GetDigitalActionHandle(ActionNames[A]);
    if FActionHandles[A] = 0 then
      Missing := Missing + ' ' + ActionNames[A];
  end;
  FResolved := Missing = '';
  if FResolved then
  begin
    Text := '';
    for S := Low(TInputSet) to High(TInputSet) do
      Text := Text + Format(' %s=%s', [SetNames[S], UIntToStr(FSetHandles[S])]);
    for A := Low(TInputAction) to High(TInputAction) do
      Text := Text + Format(' %s=%s', [ActionNames[A], UIntToStr(FActionHandles[A])]);
    AddLog('Handles resolved:' + Text);
    FResolveWarned := False;
  end
  else if not FResolveWarned then
  begin
    AddLog('Handles still 0 for:' + Missing + ' - the manifest is not loaded yet (retrying every '
      + 'second; if it stays so, check the manifest path and that Steam Input is enabled for this game)');
    FResolveWarned := True;
  end;
end;

procedure TfrmInput.RefreshControllers(P: TSteamInputPlugin);
var
  Now_: TSteamInputHandleArray;
  Changed: Boolean;
  I, Sel: Integer;
begin
  Now_ := P.ConnectedControllers;
  Changed := Length(Now_) <> Length(FControllers);
  if not Changed then
    for I := 0 to High(Now_) do
      if Now_[I] <> FControllers[I] then
        Changed := True;
  if not Changed then
    Exit;
  FControllers := Now_;
  AddLog(Format('Connected controllers: %d', [Length(FControllers)]));
  Sel := -1;
  FFillingList := True;
  try
    lbControllers.Clear;
    for I := 0 to High(FControllers) do
    begin
      lbControllers.Items.Add(ControllerText(P, FControllers[I]));
      AddLog('  ' + IntToStr(I) + ': ' + ControllerText(P, FControllers[I]));
      if FControllers[I] = FActive then
        Sel := I;
    end;
    if (Sel < 0) and (Length(FControllers) > 0) then
      Sel := 0;
    lbControllers.ItemIndex := Sel;
  finally
    FFillingList := False;
  end;
  if Sel < 0 then
  begin
    if FActive <> 0 then
      AddLog('No controller to read');
    FActive := 0;
  end
  else if FControllers[Sel] <> FActive then
  begin
    FActive := FControllers[Sel];
    FOriginsLogged := False;
    FMotionLogged := False;
    AddLog('Reading ' + ControllerText(P, FActive));
  end;
end;

function TfrmInput.LoadGlyph(P: TSteamInputPlugin; AOrigin: EInputActionOrigin; ABitmap: TBitmap): string;
var
  Path: string;
begin
  // Knockout: transparent background, coloured face buttons - readable on
  // light and dark styles alike
  Path := P.GetGlyphPNGForActionOrigin(AOrigin, k_ESteamInputGlyphSize_Small, ESteamInputGlyphStyle_Knockout);
  if Path = '' then
    Exit('no glyph (empty path)');
  if not TFile.Exists(Path) then
    Exit('glyph file missing: ' + Path);
  try
    ABitmap.LoadFromFile(Path);
    Result := Format('glyph %s (%dx%d)', [Path, ABitmap.Width, ABitmap.Height]);
  except
    on E: Exception do
      Result := 'glyph ' + Path + ' could not be loaded: ' + E.Message;
  end;
end;

procedure TfrmInput.LogOrigins(P: TSteamInputPlugin);
var
  A: TInputAction;
  Origins: TSteamInputOriginArray;
  I: Integer;
  Text, Glyph: string;
  Item: TListBoxItem;
begin
  if FOriginsLogged or (FActive = 0) then
    Exit;
  FOriginsLogged := True;
  AddLog('Bindings on ' + ControllerText(P, FActive) + ':');
  lbBindings.BeginUpdate;
  try
    lbBindings.Clear;
    for A := Low(TInputAction) to High(TInputAction) do
    begin
      Item := TListBoxItem.Create(lbBindings);
      Item.Parent := lbBindings;
      Item.ItemData.Text := SetNames[ActionSet[A]] + '.' + ActionNames[A];
      if (FActionHandles[A] = 0) or (FSetHandles[ActionSet[A]] = 0) then
      begin
        Item.ItemData.Detail := 'handle not resolved';
        AddLog(Format('  %s.%s: handle not resolved', [SetNames[ActionSet[A]], ActionNames[A]]));
        Continue;
      end;
      if ActionAnalog[A] then
        Origins := P.AnalogActionOrigins(FActive, FSetHandles[ActionSet[A]], FActionHandles[A])
      else
        Origins := P.DigitalActionOrigins(FActive, FSetHandles[ActionSet[A]], FActionHandles[A]);
      Text := '';
      for I := 0 to High(Origins) do
      begin
        if Text <> '' then
          Text := Text + ', ';
        Text := Text + P.GetStringForActionOrigin(Origins[I]) + ' (' + IntToStr(Ord(Origins[I])) + ')';
      end;
      if Text = '' then
      begin
        Item.ItemData.Detail := 'not bound';
        AddLog(Format('  %s.%s: NOT BOUND in the current layout', [SetNames[ActionSet[A]], ActionNames[A]]));
        Continue;
      end;
      Item.ItemData.Detail := Text;
      Glyph := LoadGlyph(P, Origins[0], Item.ItemData.Bitmap);
      AddLog(Format('  %s.%s: %s; %s', [SetNames[ActionSet[A]], ActionNames[A], Text, Glyph]));
    end;
  finally
    lbBindings.EndUpdate;
  end;
end;

procedure TfrmInput.SwitchSet(ASet: TInputSet);
var
  A: TInputAction;
begin
  if ASet = FCurrentSet then
    Exit;
  FCurrentSet := ASet;
  for A := Low(TInputAction) to High(TInputAction) do
    FPressed[A] := False;
  AddLog('Action set -> ' + SetNames[ASet] + ' (active from the next frame)');
end;

function TfrmInput.ReadActions(P: TSteamInputPlugin): string;
var
  A: TInputAction;
  D: InputDigitalActionData_t;
  An: InputAnalogActionData_t;
  M: InputMotionData_t;
  Lines: TStringList;
begin
  Lines := TStringList.Create;
  try
    Lines.Add('Controller: ' + ControllerText(P, FActive));
    Lines.Add(Format('Action set: %s (handle %s, controller reports %s)',
      [SetNames[FCurrentSet], UIntToStr(FSetHandles[FCurrentSet]),
       UIntToStr(P.GetCurrentActionSet(FActive))]));
    Lines.Add('');
    for A := Low(TInputAction) to High(TInputAction) do
    begin
      if ActionSet[A] <> FCurrentSet then
      begin
        Lines.Add(Format('%-9s (not in this set)', [ActionNames[A]]));
        Continue;
      end;
      if FActionHandles[A] = 0 then
      begin
        Lines.Add(Format('%-9s handle 0', [ActionNames[A]]));
        Continue;
      end;
      if ActionAnalog[A] then
      begin
        An := P.GetAnalogActionData(FActive, FActionHandles[A]);
        Lines.Add(Format('%-9s x %s  y %s  %s, active %s',
          [ActionNames[A], F2(An.x), F2(An.y), SourceModeName(An.eMode), BoolToStr(An.bActive, True)]));
        if ((Abs(An.x - FLoggedX[A]) >= ANALOG_LOG_STEP) or (Abs(An.y - FLoggedY[A]) >= ANALOG_LOG_STEP)
            or ((An.x = 0) and (An.y = 0) and ((FLoggedX[A] <> 0) or (FLoggedY[A] <> 0))))
          and (MilliSecondsBetween(Now, FLoggedAt[A]) >= ANALOG_LOG_MS) then
        begin
          AddLog(Format('%s: x %s, y %s (%s, active %s)',
            [ActionNames[A], F2(An.x), F2(An.y), SourceModeName(An.eMode), BoolToStr(An.bActive, True)]));
          FLoggedX[A] := An.x;
          FLoggedY[A] := An.y;
          FLoggedAt[A] := Now;
        end;
      end
      else
      begin
        D := P.GetDigitalActionData(FActive, FActionHandles[A]);
        Lines.Add(Format('%-9s %s, active %s',
          [ActionNames[A], IfThen(D.bState, 'PRESSED', 'up'), BoolToStr(D.bActive, True)]));
        if D.bState <> FPressed[A] then
        begin
          FPressed[A] := D.bState;
          AddLog(Format('%s %s (active %s)',
            [ActionNames[A], IfThen(D.bState, 'pressed', 'released'), BoolToStr(D.bActive, True)]));
          if D.bState and (A = iaMenu) then
            SwitchSet(isMenu)
          else if D.bState and (A = iaBack) then
            SwitchSet(isInGame);
        end;
      end;
    end;
    M := P.GetMotionData(FActive);
    Lines.Add('');
    Lines.Add(Format('Motion   quat %s %s %s %s', [F2(M.rotQuatX), F2(M.rotQuatY), F2(M.rotQuatZ), F2(M.rotQuatW)]));
    Lines.Add(Format('         accel %s %s %s', [F2(M.posAccelX), F2(M.posAccelY), F2(M.posAccelZ)]));
    Lines.Add(Format('         gyro  %s %s %s', [F2(M.rotVelX), F2(M.rotVelY), F2(M.rotVelZ)]));
    if not FMotionLogged and ((M.rotQuatW <> 0) or (M.posAccelX <> 0) or (M.posAccelY <> 0)
      or (M.posAccelZ <> 0) or (M.rotVelX <> 0) or (M.rotVelY <> 0) or (M.rotVelZ <> 0)) then
    begin
      FMotionLogged := True;
      AddLog(Format('First motion data: quat %s %s %s %s, accel %s %s %s, gyro %s %s %s',
        [F2(M.rotQuatX), F2(M.rotQuatY), F2(M.rotQuatZ), F2(M.rotQuatW),
         F2(M.posAccelX), F2(M.posAccelY), F2(M.posAccelZ), F2(M.rotVelX), F2(M.rotVelY), F2(M.rotVelZ)]));
    end;
    Result := Lines.Text;
  finally
    Lines.Free;
  end;
end;

procedure TfrmInput.tmPollTimer(Sender: TObject);
var
  P: TSteamInputPlugin;
  Text: string;
begin
  if FPolling then
    Exit;
  FPolling := True;
  try
    try
      P := Input;
      if P = nil then
        Exit;
      P.RunFrame(False);             // explicit RunFrame (Start(True))
      RefreshControllers(P);
      if FActive = 0 then
        Text := 'No controller connected (or Steam Input is off for this game).'
      else
      begin
        if not FResolved and (MilliSecondsBetween(Now, FLastResolve) >= 1000) then
          ResolveHandles(P);
        if FSetHandles[FCurrentSet] <> 0 then
          P.ActivateActionSet(FActive, FSetHandles[FCurrentSet]);
        // bindings once every handle is known (and again after a new layout
        // or another controller)
        if FResolved and not FOriginsLogged then
          LogOrigins(P);
        Text := ReadActions(P);
      end;
      if Text <> FStateText then
      begin
        FStateText := Text;
        memState.Text := Text;
      end;
    except
      on E: Exception do
      begin
        Inc(FPollErrors);
        AddLog('Poll failed: ' + E.ClassName + ': ' + E.Message);
        if FPollErrors >= 3 then
        begin
          tmPoll.Enabled := False;
          AddLog('Polling stopped after 3 errors');
        end;
      end;
    end;
  finally
    FPolling := False;
  end;
end;

end.
