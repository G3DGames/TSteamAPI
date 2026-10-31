{ @abstract(Main form of the Steam Input test (FMX).)

  Everything is on the form (uMain.fmx): the @code(TSteamAPI) root and a
  @code(TSteamInput) component with its device events wired in the form
  file. Steam is opened by itself right after the form is shown (no
  buttons - this is now a tool for examining pads; the File menu has View
  Controller Settings, Rumble, Send log to receiver and Exit; DPadUp +
  ButtonY + LeftBumper together also start the log sending, for SteamOS
  where the window is full screen),
  and tried again every few seconds while it fails or after the Steam
  client exits; @link(TfrmInput.SteamInitialized) then starts
  ISteamInput with an explicit RunFrame, enables device callbacks and points
  Steam at steam_input_manifest.vdf next to the executable (the action sets
  InGame and Menu). A 16 ms timer is the "game loop": RunFrame, the
  connected controllers, then every action of the active set on the selected
  controller - all on the UI thread, so no ISteamInput call crosses threads
  whatever the update mode.

  The controller being read is shown prominently at the top: its type, the
  layout file Steam looks for (controller_<type>.vdf - ours when it is next
  to the manifest), the matching 3D model in models/ and whether it has
  motion sensors. Each change is logged ("Controller identified").

  The log records what a test needs: controllers appearing / disappearing,
  each button press and release, stick / trigger movement (at most four
  lines a second per action), the first non-zero motion data, the bindings
  of every action with the path of Steam's glyph for each (shown in the
  Bindings list), motion while the pad turns, and Steam taking the pad
  away (every action inactive). Every line is also
  appended to SteamInputDemo.log next to the executable. }
unit uMain;

interface

uses
  System.SysUtils, System.Types, System.UITypes, System.Classes,
  FMX.Types, FMX.Controls, FMX.Forms, FMX.Graphics, FMX.Dialogs, FMX.StdCtrls,
  FMX.Controls.Presentation, FMX.Memo.Types, FMX.ScrollBox, FMX.Memo,
  FMX.Layouts, FMX.ListBox, FMX.Menus,
  Steamworks.Types, Steamworks.SDKTypes, Steamworks.Callbacks, Steamworks.Core, Steamworks.Components,
  Steamworks.FMX, Steamworks.Plugin.Input,
  // optional remote logging (RemoteLogging\src, nothing to do with Steam)
  RemoteLog.Sender;

type
  { The actions of steam_input_manifest.vdf: in InGame one per physical
    control, named by position with the Xbox letters (iaButtonA = the bottom
    face button on every pad), so every pad reports the same actions. }
  TInputAction = (iaLeftStick, iaRightStick, iaGyro,
    iaLeftTrackpad, iaRightTrackpad, iaCenterTrackpad, iaLeftTrigger, iaRightTrigger,
    iaButtonA, iaButtonB, iaButtonX, iaButtonY, iaLeftBumper, iaRightBumper,
    iaLeftStickClick, iaRightStickClick, iaDPadUp, iaDPadDown, iaDPadLeft, iaDPadRight,
    iaStart, iaSelect, iaBackLeft, iaBackRight, iaBackLeftUpper, iaBackRightUpper,
    iaLeftTrackpadClick, iaRightTrackpadClick, iaCenterTrackpadClick,
    iaMenuConfirm, iaMenuBack);
  { The action sets of steam_input_manifest.vdf. }
  TInputSet = (isInGame, isMenu);

  { Steam Input test form. }
  TfrmInput = class(TForm)
    { Banner: the controller being read, in large type. }
    pnlPad: TPanel;
    { Name of the controller being read (large, bold). }
    lblPadName: TLabel;
    { Steam type, layout file, 3D model and motion sensors of that controller. }
    lblPadInfo: TLabel;
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
    { Drag to share the left column between @link(memState) and
      @link(lbBindings). }
    splState: TSplitter;
    { Caption of @link(lbBindings). }
    lblBindings: TLabel;
    { One row per action: the buttons bound to it, with Steam's glyph of the
      first one. }
    lbBindings: TListBox;
    { Drag to change the width of the left column against the log. }
    splLeft: TSplitter;
    { The log. }
    memLog: TMemo;
    { The "game loop": RunFrame and reading the actions. }
    tmPoll: TTimer;
    { Opens Steam once the form is up, and again while it fails / after the
      Steam client exited. }
    tmStart: TTimer;
    { Ends the rumble started by @link(mnuRumble). }
    tmRumble: TTimer;
    { The menu bar. }
    MainMenu1: TMainMenu;
    { File menu. }
    mnuFile: TMenuItem;
    { Opens Steam's controller layout screen for the selected controller. }
    mnuLayout: TMenuItem;
    { Rumbles the selected controller for half a second. }
    mnuRumble: TMenuItem;
    { Streams the log to a LogReceiver app on the network (optional), or
      stops doing so. }
    mnuRemoteLog: TMenuItem;
    { Separator above @link(mnuExit). }
    mnuSep1: TMenuItem;
    { Closes the program. }
    mnuExit: TMenuItem;
    { The Steam root component. Active is False in the form: Start opens Steam. }
    SteamAPI1: TSteamAPI;
    { ISteamInput component; its events report devices and configurations. }
    SteamInput1: TSteamInput;
    { Debug-only settings, the log file, the state font. }
    procedure FormCreate(Sender: TObject);
    { Stops polling and shuts Steam down while the controls still exist. }
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
    { Another controller was selected. }
    procedure lbControllersChange(Sender: TObject);
    { One frame of the "game loop". }
    procedure tmPollTimer(Sender: TObject);
    { Opens Steam (see @link(tmStart)). }
    procedure tmStartTimer(Sender: TObject);
    { Stops the rumble. }
    procedure tmRumbleTimer(Sender: TObject);
    { File > View Controller Settings: Steam's layout screen (overlay
      binding panel, else the steam:// link). }
    procedure mnuLayoutClick(Sender: TObject);
    { File > Rumble. }
    procedure mnuRumbleClick(Sender: TObject);
    { File > Exit. }
    procedure mnuExitClick(Sender: TObject);
    { File > Send log to receiver / Stop sending log. }
    procedure mnuRemoteLogClick(Sender: TObject);
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
    { Whether the current set's actions were active in the last frame: -1
      not known yet, 0 all inactive, 1 at least one active. A change is
      logged (Steam or Windows taking the controller shows up here). }
    FSetActiveState: Integer;
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
    { When motion was last logged while the pad was turning. }
    FMotionLoggedAt: TDateTime;
    { Guards @link(tmPollTimer) against re-entry. }
    FPolling: Boolean;
    { Guards @link(lbControllersChange) while the list is refilled. }
    FFillingList: Boolean;
    { Exceptions raised by the poll so far (polling stops at 3). }
    FPollErrors: Integer;
    { The window is closing: Steam is not opened again. }
    FClosing: Boolean;
    { Text last put into @link(memState). }
    FStateText: string;
    { What the banner shows (handle, type, controller count): it is only
      rebuilt when this changes, so the poll does no file checks per frame. }
    FPadKey: string;
    { Streams every log line to a LogReceiver while assigned (optional, see
      RemoteLogging/README.md). }
    FSender: TRemoteLogSender;
    { The last search for receivers (kept until the next one or the end:
      it must not be freed from its own result handler). }
    FDiscovery: TRemoteLogDiscovery;
    { From the start of a search until its result is handled: a second
      start is ignored. }
    FRemoteBusy: Boolean;
    { Controllers Steam has loaded a layout for (OnSteamInputConfigurationLoaded). }
    FConfigHandles: TSteamInputHandleArray;
    { Which layout Steam loaded for each of @link(FConfigHandles). }
    FConfigTexts: array of string;
    { When the controller now read was first read (see LAYOUT_WAIT_MS). }
    FActiveSince: TDateTime;
    { Status messages of @link(FSender), written to the log. }
    procedure RemoteLogStatus(Sender: TObject; const AText: string);
    { Starts sending the log: searches for receivers in the background
      (@link(RemoteLogDiscovered) goes on). AWhy names what asked (menu or
      the controller shortcut) in the log. Ignored while sending or
      searching. }
    procedure StartRemoteLog(const AWhy: string);
    { Result of the search: connects to the receiver found (the first one
      if several answered); none -> logs what to do. No questions here -
      LogReceiver itself asks its user to Accept. }
    procedure RemoteLogDiscovered(Sender: TObject; const AFound: TRemoteLogReceiverArray;
      const AError: string);
    { Creates @link(FSender), sends the log so far and connects. }
    procedure ConnectRemoteLog(const AHost: string; APort: Word);
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
    { Loads Steam's glyph of AOrigin into ABitmap, trying light small, light
      medium, dark and knockout in turn, then the legacy call; returns a log text (the path
      used and every failed attempt, or "NO GLYPH" with all of them). }
    function LoadGlyph(P: TSteamInputPlugin; AOrigin: EInputActionOrigin;
      ABitmap: FMX.Graphics.TBitmap): string;
    { Activates ASet on the active controller (applied at the next RunFrame). }
    procedure SwitchSet(ASet: TInputSet);
    { Names the current action set in the caption of @link(memState). }
    procedure UpdateStateCaption;
    { Whether Steam has reported a layout for AHandle
      (OnSteamInputConfigurationLoaded). }
    function LayoutLoaded(AHandle: InputHandle_t): Boolean;
    { Shows the controller being read in the banner; logs each change.
      Called every frame; cheap unless the controller changed. }
    procedure UpdatePadBanner(P: TSteamInputPlugin);
    { "Xbox One controller (handle ..., gamepad index ...)". }
    function ControllerText(P: TSteamInputPlugin; AHandle: InputHandle_t): string;
    { Reads every action of the current set; logs edges and movement;
      opens the Menu set on Start + RightTrigger past MENU_TRIGGER_MIN and
      returns from it on MenuBack + MenuConfirm; DPadUp + ButtonY +
      LeftBumper together start sending the log (@link(StartRemoteLog));
      returns the live-state text. }
    function ReadActions(P: TSteamInputPlugin): string;
  end;

var
  { The main form instance. }
  frmInput: TfrmInput;

implementation

{$R *.fmx}

uses
  System.IOUtils, System.DateUtils, System.StrUtils, FmxLinuxMenu
{$IFDEF MSWINDOWS}
  , Winapi.ShellAPI   // not Winapi.Windows: its TBitmap would hide FMX's here
{$ENDIF}
{$IFDEF POSIX}
  , Posix.Stdlib
{$ENDIF}
  ;

{ Hands AURL (a steam:// link) to the system, which passes it to the Steam
  client. }
procedure OpenURL(const AURL: string);
begin
{$IFDEF MSWINDOWS}
  ShellExecute(0, 'open', PChar(AURL), nil, nil, 1 {SW_SHOWNORMAL});
{$ENDIF}
{$IFDEF MACOS}
  _system(PAnsiChar(AnsiString('open "' + AURL + '"')));
{$ELSE}
  {$IFDEF POSIX}
  _system(PAnsiChar(AnsiString('xdg-open "' + AURL + '" &')));
  {$ENDIF}
{$ENDIF}
end;

const
  { Manifest file name, next to the executable. }
  MANIFEST_FILE = 'steam_input_manifest.vdf';
  { Text of each log level. }
  LevelNames: array[TSteamLogLevel] of string = ('debug', 'info', 'warn', 'ERROR');
  { Action names as in the manifest. }
  ActionNames: array[TInputAction] of string =
    ('LeftStick', 'RightStick', 'Gyro',
     'LeftTrackpad', 'RightTrackpad', 'CenterTrackpad', 'LeftTrigger', 'RightTrigger',
     'ButtonA', 'ButtonB', 'ButtonX', 'ButtonY', 'LeftBumper', 'RightBumper',
     'LeftStickClick', 'RightStickClick', 'DPadUp', 'DPadDown', 'DPadLeft', 'DPadRight',
     'Start', 'Select', 'BackLeft', 'BackRight', 'BackLeftUpper', 'BackRightUpper',
     'LeftTrackpadClick', 'RightTrackpadClick', 'CenterTrackpadClick',
     'MenuConfirm', 'MenuBack');
  { Analog actions (StickPadGyro / AnalogTrigger); the rest are buttons. }
  ActionAnalog: array[TInputAction] of Boolean =
    (True, True, True,
     True, True, True, True, True,
     False, False, False, False, False, False,
     False, False, False, False, False, False,
     False, False, False, False, False, False,
     False, False, False,
     False, False);
  { Actions only some pads have (gyro, trackpads, back paddles): unbound is normal
    there. Every other action is bound on every pad by our layouts
    (tools/gen_input_mapping.py, OPTIONAL). }
  ActionOptional: array[TInputAction] of Boolean =
    (False, False, True,
     True, True, True, False, False,
     False, False, False, False, False, False,
     False, False, False, False, False, False,
     False, False, True, True, True, True,
     True, True, True,
     False, False);
  { The set each action belongs to. }
  ActionSet: array[TInputAction] of TInputSet =
    (isInGame, isInGame, isInGame,
     isInGame, isInGame, isInGame, isInGame, isInGame,
     isInGame, isInGame, isInGame, isInGame, isInGame, isInGame,
     isInGame, isInGame, isInGame, isInGame, isInGame, isInGame,
     isInGame, isInGame, isInGame, isInGame, isInGame, isInGame,
     isInGame, isInGame, isInGame,
     isMenu, isMenu);
  { Action set names as in the manifest. }
  SetNames: array[TInputSet] of string = ('InGame', 'Menu');
  { Analog change that is logged (stick units, -1..1). }
  ANALOG_LOG_STEP = 0.2;
  { How far RightTrigger must be pulled while Start is pressed to open the
    Menu set (see @link(TfrmInput.ReadActions)). }
  MENU_TRIGGER_MIN = 0.25;
  { How long to wait for Steam's layout of a new controller before its
    bindings are listed anyway. }
  LAYOUT_WAIT_MS = 15000;
  { Milliseconds between attempts to open Steam while it fails. }
  RETRY_MS = 5000;
  { Fewest milliseconds between two log lines of one analog action. }
  ANALOG_LOG_MS = 250;
  { Rotation speed (largest axis, raw units) above which motion is logged -
    about 30 deg/s if the range is +-2000 deg/s over +-32767. }
  MOTION_LOG_ROTVEL = 500;
  { Fewest milliseconds between two motion log lines. }
  MOTION_LOG_MS = 1000;

{ Fixed-format number for the log and the state (invariant decimal point). }
function F2(V: Single): string;
begin
  Result := FormatFloat('+0.00;-0.00;0.00', V, TFormatSettings.Invariant);
end;

{ Readable name of a Steam Input controller type (every type of SDK 1.65). }
function InputTypeName(T: ESteamInputType): string;
begin
  case T of
    k_ESteamInputType_Unknown:                  Result := 'unknown controller';
    k_ESteamInputType_SteamController:          Result := 'Steam Controller (2015)';
    k_ESteamInputType_XBox360Controller:        Result := 'Xbox 360 controller';
    k_ESteamInputType_XBoxOneController:        Result := 'Xbox One / Series controller';
    k_ESteamInputType_GenericGamepad:           Result := 'generic gamepad';
    k_ESteamInputType_PS4Controller:            Result := 'PS4 controller';
    k_ESteamInputType_AppleMFiController:       Result := 'Apple MFi controller';
    k_ESteamInputType_AndroidController:        Result := 'Android controller';
    k_ESteamInputType_SwitchJoyConPair:         Result := 'Joy-Con pair';
    k_ESteamInputType_SwitchJoyConSingle:       Result := 'single Joy-Con';
    k_ESteamInputType_SwitchProController:      Result := 'Switch Pro controller';
    k_ESteamInputType_MobileTouch:              Result := 'Remote Play touch controller';
    k_ESteamInputType_PS3Controller:            Result := 'PS3 controller';
    k_ESteamInputType_PS5Controller:            Result := 'PS5 DualSense controller';
    k_ESteamInputType_SteamDeckController:      Result := 'Steam Deck';
    k_ESteamInputType_SteamOSHandheld:          Result := 'SteamOS handheld';
    k_ESteamInputType_Switch2ProController:     Result := 'Switch 2 Pro controller';
    k_ESteamInputType_SteamController2026:      Result := 'Steam Controller (2026)';
    k_ESteamInputType_SteamFrameControllerPair: Result := 'Steam Frame controllers';
  else
    Result := 'controller type ' + IntToStr(Ord(T));
  end;
end;

{ Steam's own name of the type (the ESteamInputType value without its
  prefix). }
function InputTypeId(T: ESteamInputType): string;
begin
  case T of
    k_ESteamInputType_Unknown:                  Result := 'Unknown';
    k_ESteamInputType_SteamController:          Result := 'SteamController';
    k_ESteamInputType_XBox360Controller:        Result := 'XBox360Controller';
    k_ESteamInputType_XBoxOneController:        Result := 'XBoxOneController';
    k_ESteamInputType_GenericGamepad:           Result := 'GenericGamepad';
    k_ESteamInputType_PS4Controller:            Result := 'PS4Controller';
    k_ESteamInputType_AppleMFiController:       Result := 'AppleMFiController';
    k_ESteamInputType_AndroidController:        Result := 'AndroidController';
    k_ESteamInputType_SwitchJoyConPair:         Result := 'SwitchJoyConPair';
    k_ESteamInputType_SwitchJoyConSingle:       Result := 'SwitchJoyConSingle';
    k_ESteamInputType_SwitchProController:      Result := 'SwitchProController';
    k_ESteamInputType_MobileTouch:              Result := 'MobileTouch';
    k_ESteamInputType_PS3Controller:            Result := 'PS3Controller';
    k_ESteamInputType_PS5Controller:            Result := 'PS5Controller';
    k_ESteamInputType_SteamDeckController:      Result := 'SteamDeckController';
    k_ESteamInputType_SteamOSHandheld:          Result := 'SteamOSHandheld';
    k_ESteamInputType_Switch2ProController:     Result := 'Switch2ProController';
    k_ESteamInputType_SteamController2026:      Result := 'SteamController2026';
    k_ESteamInputType_SteamFrameControllerPair: Result := 'SteamFrameControllerPair';
  else
    Result := IntToStr(Ord(T));
  end;
end;

{ The controller_type Steam looks for in the manifest's "configurations" for
  this type ('' when no name is known). Elite / DualSense Edge pads report
  the base type but have layout names of their own; a single Joy-Con is
  _left or _right. Keep in step with tools/gen_input_mapping.py. }
function LayoutTypeName(T: ESteamInputType): string;
begin
  case T of
    k_ESteamInputType_SteamController:      Result := 'controller_steamcontroller_gordon';
    k_ESteamInputType_XBox360Controller:    Result := 'controller_xbox360';
    k_ESteamInputType_XBoxOneController:    Result := 'controller_xboxone';
    k_ESteamInputType_GenericGamepad:       Result := 'controller_generic';
    k_ESteamInputType_PS4Controller:        Result := 'controller_ps4';
    k_ESteamInputType_SwitchJoyConPair:     Result := 'controller_switch_joycon_pair';
    k_ESteamInputType_SwitchProController:  Result := 'controller_switch_pro';
    k_ESteamInputType_MobileTouch:          Result := 'controller_mobile_touch';
    k_ESteamInputType_PS3Controller:        Result := 'controller_ps3';
    k_ESteamInputType_PS5Controller:        Result := 'controller_ps5';
    k_ESteamInputType_SteamDeckController:  Result := 'controller_neptune';
    k_ESteamInputType_Switch2ProController: Result := 'controller_switch2_pro';
    k_ESteamInputType_SteamController2026:  Result := 'controller_triton';
  else
    Result := '';
  end;
end;

{ The 3D model in models/ for this type (docs/SteamInputMapping.md,
  section 5). }
function ModelName(T: ESteamInputType): string;
begin
  case T of
    k_ESteamInputType_PS5Controller, k_ESteamInputType_PS4Controller,
    k_ESteamInputType_PS3Controller:
      Result := 'PS5';
    k_ESteamInputType_SteamController2026:
      Result := 'Steam Controller';
    k_ESteamInputType_SwitchProController, k_ESteamInputType_Switch2ProController,
    k_ESteamInputType_SwitchJoyConPair:
      Result := 'Xbox One (Switch model planned; positions match)';
  else
    Result := 'Xbox One';
  end;
end;

{ Whether this type has motion sensors ('yes', 'no' or 'unknown'). }
function MotionText(T: ESteamInputType): string;
begin
  case T of
    k_ESteamInputType_SteamController, k_ESteamInputType_PS4Controller,
    k_ESteamInputType_PS5Controller, k_ESteamInputType_SwitchProController,
    k_ESteamInputType_Switch2ProController, k_ESteamInputType_SwitchJoyConPair,
    k_ESteamInputType_SwitchJoyConSingle, k_ESteamInputType_SteamDeckController,
    k_ESteamInputType_SteamController2026, k_ESteamInputType_PS3Controller:
      Result := 'yes';
    k_ESteamInputType_XBox360Controller, k_ESteamInputType_XBoxOneController:
      Result := 'no';
  else
    Result := 'unknown';
  end;
  // our default layouts bind the gyro to the Gyro action on these
  // (sources with "gyro" in tools/gen_input_mapping.py)
  if T in [k_ESteamInputType_SteamController, k_ESteamInputType_PS4Controller,
    k_ESteamInputType_PS5Controller, k_ESteamInputType_SwitchProController,
    k_ESteamInputType_Switch2ProController, k_ESteamInputType_SwitchJoyConPair,
    k_ESteamInputType_SteamDeckController, k_ESteamInputType_SteamController2026] then
    Result := Result + ', bound to the Gyro action';
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
  // Linux: FMX's menu bar instead of GTK's, which shows only first letters
  // (FmxLinuxMenu). FIRST, before anything touches a menu item.
  ReplaceMainMenu(Self, MainMenu1);
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
  // Large type for the controller banner (set here for the same reason)
  lblPadName.StyledSettings := lblPadName.StyledSettings - [TStyledSetting.Size, TStyledSetting.Style];
  lblPadName.TextSettings.Font.Size := 24;
  lblPadName.TextSettings.Font.Style := [TFontStyle.fsBold];
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
  AddLog('Hold the right trigger past ' + F2(MENU_TRIGGER_MIN) + ' and press Start to open the '
    + 'Menu set; ButtonB returns. Start alone is just a button here.');
  AddLog('Send the log to a LogReceiver on another machine (optional): File > Send log to '
    + 'receiver..., or hold DPadUp + ButtonY (top face button) + LeftBumper together.');
  AddLog('Steam is opened automatically; then use a controller. Steam Input must be enabled '
    + 'for this game in the Steam client for Xbox / generic controllers.');
  // tmStart (enabled in the form, short interval) opens Steam once the
  // window is up, so the first log lines are visible before Steam starts
end;

procedure TfrmInput.FormClose(Sender: TObject; var Action: TCloseAction);
begin
  AddLog(Format('FormClose: window closing (Steam running: %s)', [BoolToStr(SteamAPI1.IsRunning, True)]));
  FClosing := True;
  tmStart.Enabled := False;
  tmRumble.Enabled := False;
  tmPoll.Enabled := False;
  SteamAPI1.Close;
  // a search still running ends within 2.5 s; its result is dropped
  FreeAndNil(FDiscovery);
  // last: the shutdown lines above are still sent (Stop waits briefly)
  FreeAndNil(FSender);
end;

procedure TfrmInput.AddLog(const S: string);
var
  Line: string;
begin
  Line := FormatDateTime('hh:nn:ss.zzz', Now) + '  ' + S;
  memLog.Lines.Add(Line);
  memLog.GoToTextEnd;
  if FSender <> nil then
    FSender.Send(Line);
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
  FSetActiveState := -1;
  UpdateStateCaption;
  FControllers := nil;
  FConfigHandles := nil;
  FConfigTexts := nil;
  FActive := 0;
  FLastResolve := 0;
  FResolved := False;
  FResolveWarned := False;
  FOriginsLogged := False;
  FMotionLogged := False;
  FPollErrors := 0;
  FStateText := '';
end;

procedure TfrmInput.mnuLayoutClick(Sender: TObject);
var
  P: TSteamInputPlugin;
  URL: string;
begin
  P := Input;
  if (P = nil) or (FActive = 0) then
  begin
    AddLog('View Controller Settings: no controller (Steam not running or no pad connected)');
    Exit;
  end;
  // The binding panel is part of the Steam overlay, which is only in the
  // process when the game was started by Steam; otherwise ask the Steam
  // client through its steam:// link (UNTESTED - see the log)
  try
    if P.ShowBindingPanel(FActive) then
    begin
      AddLog('ShowBindingPanel: True - the Steam overlay shows the layout screen');
      Exit;
    end;
    URL := 'steam://controllerconfig/' + IntToStr(SteamAPI1.AppID);
    AddLog('ShowBindingPanel: False (no Steam overlay in this process); asking the Steam client: ' + URL);
    OpenURL(URL);
  except
    on E: Exception do AddLog('View Controller Settings failed: ' + E.Message);
  end;
  AddLog('After choosing a layout, wait for "OnSteamInputConfigurationLoaded" and the banner '
    + 'to show it; restart only if it does not (docs/SteamInputMapping.md, '
    + '"When Steam keeps loading another layout")');
end;

procedure TfrmInput.mnuRumbleClick(Sender: TObject);
var
  P: TSteamInputPlugin;
begin
  P := Input;
  if (P = nil) or (FActive = 0) then
  begin
    AddLog('Rumble: no controller');
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

procedure TfrmInput.mnuRemoteLogClick(Sender: TObject);
begin
  if FSender <> nil then
  begin
    AddLog('[remote log] stopped by the user');
    FreeAndNil(FSender);
    mnuRemoteLog.Text := 'Send log to receiver...';
    Exit;
  end;
  StartRemoteLog('File > Send log to receiver');
end;

procedure TfrmInput.StartRemoteLog(const AWhy: string);
begin
  if FClosing then
    Exit;
  if FSender <> nil then
  begin
    AddLog('[remote log] ' + AWhy + ': already sending (File > Stop sending log ends it)');
    Exit;
  end;
  if FRemoteBusy then
  begin
    AddLog('[remote log] ' + AWhy + ': already looking for a receiver');
    Exit;
  end;
  FRemoteBusy := True;
  // the previous search has delivered its result (FRemoteBusy was False)
  FreeAndNil(FDiscovery);
  AddLog('[remote log] ' + AWhy + ': looking for LogReceiver apps on the network (2.5 s)...');
  // in the background: the window and the controller poll keep running
  FDiscovery := TRemoteLogDiscovery.Create(2500, RemoteLogDiscovered);
end;

procedure TfrmInput.RemoteLogDiscovered(Sender: TObject; const AFound: TRemoteLogReceiverArray;
  const AError: string);
var
  I: Integer;
begin
  // FDiscovery is NOT freed here (it is the caller of this handler)
  FRemoteBusy := False;
  if FClosing or (FSender <> nil) then
    Exit;
  if AError <> '' then
  begin
    AddLog('[remote log] could not search the network: ' + AError);
    Exit;
  end;
  if Length(AFound) = 0 then
  begin
    AddLog('[remote log] no LogReceiver answered within 2.5 s - start LogReceiver on a machine '
      + 'on this network, click OK there, then try again');
    Exit;
  end;
  for I := 0 to High(AFound) do
    AddLog(Format('[remote log] found %s at %s:%d', [AFound[I].Name, AFound[I].Host, AFound[I].Port]));
  if Length(AFound) > 1 then
    AddLog(Format('[remote log] %d receivers answered - using the first (%s); close the others '
      + 'to send elsewhere', [Length(AFound), AFound[0].Name]));
  ConnectRemoteLog(AFound[0].Host, AFound[0].Port);
end;

procedure TfrmInput.ConnectRemoteLog(const AHost: string; APort: Word);
var
  I: Integer;
begin
  FSender := TRemoteLogSender.Create;
  FSender.OnStatus := RemoteLogStatus;
  // the log so far first, so the receiver gets the whole run
  for I := 0 to memLog.Lines.Count - 1 do
    FSender.Send(memLog.Lines[I]);
  FSender.Start(AHost, APort, 'SteamInputDemo');
  mnuRemoteLog.Text := 'Stop sending log';
  AddLog(Format('[remote log] sending to %s:%d - click Yes in LogReceiver', [AHost, APort]));
end;

procedure TfrmInput.RemoteLogStatus(Sender: TObject; const AText: string);
begin
  AddLog('[remote log] ' + AText);
  // refused / no answer: the sender has given up - offer to start again
  if (FSender <> nil) and not FSender.Active then
  begin
    FreeAndNil(FSender);
    mnuRemoteLog.Text := 'Send log to receiver...';
  end;
end;

procedure TfrmInput.mnuExitClick(Sender: TObject);
begin
  Close;
end;

procedure TfrmInput.tmStartTimer(Sender: TObject);
begin
  tmStart.Enabled := False;
  if FClosing or SteamAPI1.IsRunning then
    Exit;
  AddLog('Opening Steam');
  if SteamAPI1.Open then
    AddLog('Open returned True: Steam is running')
  else
    AddLog('Open returned False: Steam did not start');
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
  FSetActiveState := -1;
  FActiveSince := Now;
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
  if not FClosing then
  begin
    // try again later (Steam not running yet, or still starting)
    tmStart.Interval := RETRY_MS;
    tmStart.Enabled := True;
    AddLog(Format('Trying again in %d s', [RETRY_MS div 1000]));
  end;
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
  FPadKey := '';
  lblPadName.Text := 'No controller';
  lblPadInfo.Text := 'Steam is not running - waiting for it.';
  AddLog('OnShutdown: Steam shut down (ISteamInput was shut down first)');
  if not FClosing then
  begin
    // the Steam client exited (or failed): open again once it is back
    tmStart.Interval := RETRY_MS;
    tmStart.Enabled := True;
    AddLog(Format('Trying to open Steam again in %d s', [RETRY_MS div 1000]));
  end;
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
var
  Text: string;
  I: Integer;
  Found: Boolean;
begin
  AddLog(Format('OnSteamInputConfigurationLoaded: app %d, handle %s, mapping by %s, revision %d.%d, '
    + 'uses Steam Input API %s, uses gamepad API %s',
    [AData.m_unAppID, UIntToStr(AData.m_ulDeviceHandle), AData.m_ulMappingCreator.ToString,
     AData.m_unMajorRevision, AData.m_unMinorRevision,
     BoolToStr(AData.m_bUsesSteamInputAPI, True), BoolToStr(AData.m_bUsesGamepadAPI, True)]));
  // remember which layout this controller got, for the banner: creator 0 =
  // the game's own default layout (ours), anything else = a layout made by a
  // player or a Steam template
  Text := Format('mapping by %s, revision %d.%d',
    [AData.m_ulMappingCreator.ToString, AData.m_unMajorRevision, AData.m_unMinorRevision]);
  // "uses Steam Input API False": Steam gave this pad a layout with no game
  // actions at all - Steam Input is OFF for it (an Xbox 360-type pad,
  // owner's log 2026-10-31: mapping by 0 but every action NOT BOUND) or a
  // plain gamepad / keyboard template was chosen
  if not AData.m_bUsesSteamInputAPI then
    Text := 'Steam Input is NOT active for this pad (' + Text + ', uses Steam Input API False) - '
      + 'turn Steam Input on for this controller / game in the Steam client'
  else if AData.m_ulMappingCreator.Value = 0 then
    Text := 'Steam loaded OUR default layout (' + Text + ')'
  else
    Text := 'Steam loaded a DIFFERENT layout, not ours (' + Text
      + ') - reset it to the default in Steam''s controller settings for this game';
  Found := False;
  for I := 0 to High(FConfigHandles) do
    if FConfigHandles[I] = AData.m_ulDeviceHandle then
    begin
      FConfigTexts[I] := Text;
      Found := True;
    end;
  if not Found then
  begin
    SetLength(FConfigHandles, Length(FConfigHandles) + 1);
    SetLength(FConfigTexts, Length(FConfigTexts) + 1);
    FConfigHandles[High(FConfigHandles)] := AData.m_ulDeviceHandle;
    FConfigTexts[High(FConfigTexts)] := Text;
  end;
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

function TfrmInput.LayoutLoaded(AHandle: InputHandle_t): Boolean;
var
  I: Integer;
begin
  Result := False;
  for I := 0 to High(FConfigHandles) do
    if FConfigHandles[I] = AHandle then
      Exit(True);
end;

procedure TfrmInput.UpdatePadBanner(P: TSteamInputPlugin);
var
  T: ESteamInputType;
  PadName, Info, Layout, Dir, Key, Loaded: string;
  I, Sel: Integer;
  Ours: Boolean;
begin
  Ours := False;
  if FActive = 0 then
    T := k_ESteamInputType_Unknown
  else
    T := P.GetInputTypeForHandle(FActive);
  Loaded := 'no layout loaded yet';
  for I := 0 to High(FConfigHandles) do
    if FConfigHandles[I] = FActive then
      Loaded := FConfigTexts[I];
  Key := Format('%s/%d/%d/%s', [UIntToStr(FActive), Ord(T), Length(FControllers), Loaded]);
  if Key = FPadKey then
    Exit;
  FPadKey := Key;
  if FActive = 0 then
  begin
    PadName := 'No controller';
    Info := 'Connect one (Steam Input must be enabled for this game for Xbox / generic pads).';
  end
  else
  begin
    PadName := InputTypeName(T);
    if Length(FControllers) > 1 then
    begin
      Sel := 0;
      for I := 0 to High(FControllers) do
        if FControllers[I] = FActive then
          Sel := I;
      PadName := Format('%s   (%d of %d connected)', [PadName, Sel + 1, Length(FControllers)]);
    end;
    Layout := LayoutTypeName(T);
    if T = k_ESteamInputType_SwitchJoyConSingle then
      Layout := 'layout controller_switch_joycon_left / _right (no file of ours for this type)'
    else if Layout = '' then
      Layout := 'layout: no controller_type name known'
    else
    begin
      Dir := ExtractFilePath(ManifestPath);
      if (Dir <> '') and TFile.Exists(TPath.Combine(Dir, Layout + '.vdf')) then
      begin
        Layout := 'layout ' + Layout + '.vdf (ours)';
        Ours := True;
      end
      else
        Layout := 'layout ' + Layout + ' (no file of ours for this type)';
    end;
    // Without a file of ours Steam ADAPTS the game's default layout from
    // another type (a single Joy-Con, owner's log 2026-10-31: mapping by 0,
    // only the controls the pad has) - say so instead of "OUR layout"
    if not Ours and StartsText('Steam loaded OUR default layout', Loaded) then
      Loaded := 'Steam ADAPTED the game''s default layout' + Copy(Loaded, Length('Steam loaded OUR default layout') + 1, MaxInt)
        + ' - only the controls this pad has are bound';
    Info := Format('Steam type %s (%d) - %s - 3D model %s - motion sensors %s'
      + sLineBreak + '%s',
      [InputTypeId(T), Ord(T), Layout, ModelName(T), MotionText(T), Loaded]);
  end;
  lblPadName.Text := PadName;
  lblPadInfo.Text := Info;
  if FActive <> 0 then
    AddLog('Controller identified: ' + PadName + ' - ' + StringReplace(Info, sLineBreak, ' - ', [rfReplaceAll]));
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
    FSetActiveState := -1;
    FActiveSince := Now;
    AddLog('Reading ' + ControllerText(P, FActive));
  end;
end;

function TfrmInput.LoadGlyph(P: TSteamInputPlugin; AOrigin: EInputActionOrigin;
  ABitmap: FMX.Graphics.TBitmap): string;
const
  { Attempts in order. Light first: black detail on a white background,
    visible on the list's light background. Knockout (the old choice) draws
    everything except Xbox-coloured face buttons WHITE on a transparent
    background - invisible on a light list: the PS5 glyphs "did not show"
    although every one loaded (owner's log, 2026-10-31 15:06), and on Xbox
    only A / B were visible. Then the others in case Steam has no file. }
  Styles: array[0..3] of ESteamInputGlyphStyle = (ESteamInputGlyphStyle_Light,
    ESteamInputGlyphStyle_Light, ESteamInputGlyphStyle_Dark, ESteamInputGlyphStyle_Knockout);
  Sizes: array[0..3] of ESteamInputGlyphSize = (k_ESteamInputGlyphSize_Small,
    k_ESteamInputGlyphSize_Medium, k_ESteamInputGlyphSize_Small, k_ESteamInputGlyphSize_Small);
  StyleNames: array[0..3] of string = ('light small', 'light medium', 'dark small', 'knockout small');
var
  Path, Failed: string;
  I: Integer;
begin
  Failed := '';
  for I := Low(Styles) to High(Styles) do
  begin
    Path := P.GetGlyphPNGForActionOrigin(AOrigin, Sizes[I], UInt32(Styles[I]));
    if Path = '' then
      Failed := Failed + Format(' [%s: empty path]', [StyleNames[I]])
    else if not TFile.Exists(Path) then
      Failed := Failed + Format(' [%s: file missing %s]', [StyleNames[I], Path])
    else
      try
        ABitmap.LoadFromFile(Path);
        Result := Format('glyph %s (%s, %dx%d)', [Path, StyleNames[I], ABitmap.Width, ABitmap.Height]);
        if Failed <> '' then
          Result := Result + '; failed first:' + Failed;
        Exit;
      except
        on E: Exception do
          Failed := Failed + Format(' [%s: %s could not be loaded: %s]', [StyleNames[I], Path, E.Message]);
      end;
  end;
  // Last resort: the legacy call (Steam returned no PNG of any style for the
  // Joy-Con pair's "Right JoyCon Gyro Move", owner's log 2026-10-31)
  Path := P.GetGlyphForActionOrigin_Legacy(AOrigin);
  if (Path <> '') and TFile.Exists(Path) then
    try
      ABitmap.LoadFromFile(Path);
      Exit(Format('glyph %s (legacy, %dx%d); failed first:%s', [Path, ABitmap.Width, ABitmap.Height, Failed]));
    except
      on E: Exception do
        Failed := Failed + Format(' [legacy: %s could not be loaded: %s]', [Path, E.Message]);
    end
  else
    Failed := Failed + Format(' [legacy: %s]', [IfThen(Path = '', 'empty path', 'file missing ' + Path)]);
  Result := 'NO GLYPH:' + Failed;
end;

procedure TfrmInput.LogOrigins(P: TSteamInputPlugin);
var
  A: TInputAction;
  Origins: TSteamInputOriginArray;
  I: Integer;
  Text, Glyph, OriginName: string;
  Item: TListBoxItem;
  NoneBound: Boolean;
begin
  if FOriginsLogged or (FActive = 0) then
    Exit;
  FOriginsLogged := True;
  // Steam returns no origins at all for a pad that is going away (Linux
  // run 20:59: every PS5 action "NOT BOUND", the PS5 disconnected 5 s
  // later). Then "a different layout" would be wrong: say it once instead.
  NoneBound := True;
  for A := Low(TInputAction) to High(TInputAction) do
    if not ActionOptional[A] and (FActionHandles[A] <> 0) and (FSetHandles[ActionSet[A]] <> 0) then
    begin
      if ActionAnalog[A] then
        Origins := P.AnalogActionOrigins(FActive, FSetHandles[ActionSet[A]], FActionHandles[A])
      else
        Origins := P.DigitalActionOrigins(FActive, FSetHandles[ActionSet[A]], FActionHandles[A]);
      if Length(Origins) > 0 then
      begin
        NoneBound := False;
        Break;
      end;
    end;
  AddLog('Bindings on ' + ControllerText(P, FActive) + ':');
  if NoneBound then
    AddLog('  NO action has a binding on this pad right now - Steam reports this while a pad is '
      + 'disconnecting (switched off, Bluetooth lost) or when it uses a layout without our actions '
      + 'at all; if the pad stays, choose the game''s official layout in Steam (File > View '
      + 'Controller Settings)');
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
        OriginName := P.GetStringForActionOrigin(Origins[I]);
        if OriginName = '' then
          OriginName := '(Steam gives no name)';   // e.g. a single Joy-Con's N / E / S / W buttons
        Text := Text + OriginName + ' (' + IntToStr(Ord(Origins[I])) + ')';
      end;
      if Text = '' then
      begin
        if ActionOptional[A] then
        begin
          Item.ItemData.Detail := 'not on this controller';
          AddLog(Format('  %s.%s: not bound (optional: not every pad has it)',
            [SetNames[ActionSet[A]], ActionNames[A]]));
        end
        else if NoneBound then
          Item.ItemData.Detail := 'NO BINDINGS (see log)'
        else
        begin
          Item.ItemData.Detail := 'NOT BOUND';
          AddLog(Format('  %s.%s: NOT BOUND in the current layout - our layouts bind it on every '
            + 'pad, so Steam is using a different layout', [SetNames[ActionSet[A]], ActionNames[A]]));
        end;
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
  FSetActiveState := -1;
  for A := Low(TInputAction) to High(TInputAction) do
    FPressed[A] := False;
  UpdateStateCaption;
  AddLog('Action set -> ' + SetNames[ASet] + ' (active from the next frame)');
end;

procedure TfrmInput.UpdateStateCaption;
begin
  case FCurrentSet of
    isInGame:
      lblState.Text := ' Live state - action set InGame (every control; RightTrigger + Start '
        + 'opens Menu), motion';
  else
    lblState.Text := ' Live state - action set MENU (MenuConfirm = A, MenuBack = B; A + B '
      + 'together returns), motion';
  end;
end;

function TfrmInput.ReadActions(P: TSteamInputPlugin): string;
var
  A: TInputAction;
  D: InputDigitalActionData_t;
  An: InputAnalogActionData_t;
  M: InputMotionData_t;
  Lines: TStringList;
  RightTrigger: Single;
  AnyActive: Boolean;
begin
  RightTrigger := 0;
  AnyActive := False;
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
        Continue;
      if FActionHandles[A] = 0 then
      begin
        Lines.Add(Format('%-15s handle 0', [ActionNames[A]]));
        Continue;
      end;
      if ActionAnalog[A] then
      begin
        An := P.GetAnalogActionData(FActive, FActionHandles[A]);
        if A = iaRightTrigger then
          RightTrigger := An.x;   // read before Start: analog actions come first
        AnyActive := AnyActive or An.bActive;
        Lines.Add(Format('%-15s x %s  y %s  %s, active %s',
          [ActionNames[A], F2(An.x), F2(An.y), SourceModeName(An.eMode), BoolToStr(An.bActive, True)]));
        // logged: a change of ANALOG_LOG_STEP, a return to zero, and ANY
        // move away from zero (Gyro and trackpads report small mouse-like
        // values that may never reach the step)
        if ((Abs(An.x - FLoggedX[A]) >= ANALOG_LOG_STEP) or (Abs(An.y - FLoggedY[A]) >= ANALOG_LOG_STEP)
            or ((An.x = 0) and (An.y = 0) and ((FLoggedX[A] <> 0) or (FLoggedY[A] <> 0)))
            or ((FLoggedX[A] = 0) and (FLoggedY[A] = 0) and ((An.x <> 0) or (An.y <> 0))))
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
        AnyActive := AnyActive or D.bActive;
        Lines.Add(Format('%-15s %s, active %s',
          [ActionNames[A], IfThen(D.bState, 'PRESSED', 'up'), BoolToStr(D.bActive, True)]));
        if D.bState <> FPressed[A] then
        begin
          FPressed[A] := D.bState;
          AddLog(Format('%s %s (active %s)',
            [ActionNames[A], IfThen(D.bState, 'pressed', 'released'), BoolToStr(D.bActive, True)]));
          // Opening the Menu set takes a COMBINATION: Start while RightTrigger
          // is pulled past MENU_TRIGGER_MIN. Bad design for a game, right for
          // this tool: Start alone must stay an ordinary button that can be
          // pressed and watched like every other one, and a set switch empties
          // the Live state panel (only the Menu set's actions are read there).
          // A deliberate two-handed combination cannot happen by accident
          // while a pad is being tested.
          if D.bState and (A = iaStart) then
          begin
            if RightTrigger > MENU_TRIGGER_MIN then
            begin
              AddLog(Format('Start + RightTrigger %s: opening the Menu set', [F2(RightTrigger)]));
              SwitchSet(isMenu);
            end
            else
              AddLog(Format('(Start alone does not open the Menu set: hold RightTrigger past %s '
                + 'and press Start; RightTrigger is %s)', [F2(MENU_TRIGGER_MIN), F2(RightTrigger)]));
          end
          // Leaving the Menu set is a combination too (MenuConfirm + MenuBack,
          // A + B, held together), so each of them alone can be watched.
          else if D.bState and (A in [iaMenuConfirm, iaMenuBack])
            and FPressed[iaMenuConfirm] and FPressed[iaMenuBack] then
          begin
            AddLog('MenuConfirm + MenuBack together: back to the InGame set');
            SwitchSet(isInGame);
          end;
          // Remote log shortcut for SteamOS / handhelds (every main window is
          // full screen there, the File menu is awkward): DPadUp + ButtonY +
          // LeftBumper held together. Checked on each press, so it fires
          // once, when the last of the three goes down (in one frame too:
          // the last of them read sees the other two already pressed).
          if D.bState and (A in [iaDPadUp, iaButtonY, iaLeftBumper])
            and FPressed[iaDPadUp] and FPressed[iaButtonY] and FPressed[iaLeftBumper] then
          begin
            AddLog('DPadUp + ButtonY + LeftBumper together: remote log shortcut');
            StartRemoteLog('Controller shortcut');
          end;
        end;
      end;
    end;
    // Steam reports every action inactive while something else has the
    // controller - e.g. the Guide / Xbox button opened Steam's overlay or
    // Windows' Game Bar. Log the change, once each way.
    if (FSetActiveState >= 0) and (Ord(AnyActive) <> FSetActiveState) then
      if AnyActive then
        AddLog('Actions active again')
      else
        AddLog('Every action of the set is now INACTIVE (active False): Steam reports this while '
          + 'something else has the controller - the Guide / Xbox button (Steam overlay, Xbox '
          + 'Game Bar) or another window');
    FSetActiveState := Ord(AnyActive);
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
    // while the pad turns, one motion line a second (the raw values are the
    // evidence for units and axes)
    if ((Abs(M.rotVelX) > MOTION_LOG_ROTVEL) or (Abs(M.rotVelY) > MOTION_LOG_ROTVEL)
        or (Abs(M.rotVelZ) > MOTION_LOG_ROTVEL))
      and (MilliSecondsBetween(Now, FMotionLoggedAt) >= MOTION_LOG_MS) then
    begin
      FMotionLoggedAt := Now;
      AddLog(Format('Motion: quat %s %s %s %s, accel %.0f %.0f %.0f, gyro %.0f %.0f %.0f',
        [F2(M.rotQuatX), F2(M.rotQuatY), F2(M.rotQuatZ), F2(M.rotQuatW),
         M.posAccelX, M.posAccelY, M.posAccelZ, M.rotVelX, M.rotVelY, M.rotVelZ],
        TFormatSettings.Invariant));
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
      // every frame: the type may only be known a few frames after a
      // controller appears (changes are logged)
      UpdatePadBanner(P);
      if FActive = 0 then
        Text := 'No controller connected (or Steam Input is off for this game).'
      else
      begin
        if not FResolved and (MilliSecondsBetween(Now, FLastResolve) >= 1000) then
          ResolveHandles(P);
        if FSetHandles[FCurrentSet] <> 0 then
          P.ActivateActionSet(FActive, FSetHandles[FCurrentSet]);
        // bindings once every handle is known AND Steam has loaded a layout
        // for this controller (and again after a new layout or another
        // controller). A pad can appear seconds before its layout: listing
        // the bindings then showed every action "NOT BOUND" although the
        // right layout arrived 5 s later (2026 Steam Controller, owner's
        // log 16:14). After LAYOUT_WAIT_MS they are listed anyway.
        if FResolved and not FOriginsLogged
          and (LayoutLoaded(FActive) or (MilliSecondsBetween(Now, FActiveSince) >= LAYOUT_WAIT_MS)) then
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
