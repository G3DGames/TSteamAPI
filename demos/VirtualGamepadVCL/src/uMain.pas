{ @abstract(Main form of the 3D gamepad visualiser for Delphi's VCL, with
  Castle Game Engine as the 3D engine.)

  The VCL member of the set: demos/VirtualGamepad (FMX + Gorilla3D),
  demos/VirtualGamepadLCL (Lazarus + Castle Game Engine) and this one. A
  port of VirtualGamepadLCL - the same Steam Input set-up, manifest and
  default layouts (tools/gen_input_mapping.py writes them into src/ here
  too), the same models (models/*_Animated.glb), the same animator
  (src/PadAnimator.pas, the same file as VirtualGamepadLCL's) and the same
  overlay menu. AppID: VirtualGamepad's own, set on SteamAPI1 in the form
  file (Debug builds set it themselves and never relaunch through Steam;
  Release builds use RestartIfNecessary). Windows only (the VCL).

  The 3D view is a Castle Game Engine TCastleControl (unit
  Vcl.CastleControl, created in code, Align alClient) holding a
  TCastleViewport with the model (TCastleScene), an examine navigation
  (left drag turns the view, the wheel zooms) and a directional light
  riding on the camera. Castle UI controls go into the control's
  Container.Controls (the VCL control has no Controls shortcut of its own,
  unlike the LCL one).

  Every button, stick and trigger moves on the model, any number at once:
  @link(TPadAnimator) reads the clips from the .glb and combines them on
  the joints itself, because each clip in our models writes every joint and
  clips played side by side would fight.

  Motion is OFF at start. A long press of Start (LONG_PRESS_MS, 0.8 s)
  shows an overlay menu drawn by Castle's own UI (so it is always on top
  of the 3D view) and switches to the Menu action set: with several pads
  a controller row (D-pad left / right, A shows that pad), then Return to
  App, Enable / Disable Motion (greyed out until the pad sends motion
  data), Controller Settings (Steam's binding panel, as File > View
  Controller Settings - Big Picture shows no window menu), Start / Stop
  Remote Logging and Exit; D-pad up / down moves, A chooses, B goes back,
  every choice closes it. Remote logging (also File > Send log to
  receiver) uses RemoteLog.Sender (RemoteLogging/src) and connects to the
  same LogReceiver. In Big Picture / Game Mode TSteamAPI maximises the
  window (BigPictureWindow).

  Data files (manifest, layouts, models) are read from the executable's
  folder, or - run from the IDE's .\<platform>\<config>\ without the
  post-build copy - from src\ and the repository's models\ folder. Every
  log line goes to VirtualGamepadVCL.log next to the executable; every
  FPS_LOG_MS the frame rate Castle measures is logged. }
unit uMain;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Classes, System.UITypes,
  Vcl.Controls, Vcl.Forms, Vcl.StdCtrls, Vcl.ExtCtrls, Vcl.Menus, Vcl.Graphics,
  Vcl.CastleControl, CastleViewport, CastleScene, CastleCameras, CastleControls,
  CastleUIControls, CastleKeysMouse, CastleVectors, CastleColors, CastleRectangles,
  X3DNodes,
  Steamworks.VCL,
  Steamworks.Types, Steamworks.SDKTypes, Steamworks.Core, Steamworks.Components,
  Steamworks.Plugin.Input,
  // optional remote logging (RemoteLogging/src, nothing to do with Steam)
  RemoteLog.Sender,
  PadAnimator;

type
  { The InGame actions of @link(MANIFEST_FILE): one per physical
    control, named by position with the Xbox letters (iaButtonA = the
    bottom face button on every pad). Same order as in VirtualGamepad. }
  TInputAction = (iaLeftStick, iaRightStick, iaGyro,
    iaLeftTrackpad, iaRightTrackpad, iaCenterTrackpad, iaLeftTrigger, iaRightTrigger,
    iaButtonA, iaButtonB, iaButtonX, iaButtonY, iaLeftBumper, iaRightBumper,
    iaLeftStickClick, iaRightStickClick, iaDPadUp, iaDPadDown, iaDPadLeft, iaDPadRight,
    iaStart, iaSelect, iaBackLeft, iaBackRight, iaBackLeftUpper, iaBackRightUpper,
    iaLeftTrackpadClick, iaRightTrackpadClick, iaCenterTrackpadClick);

  { The Menu set's actions (the overlay menu): A, B, D-pad. }
  TMenuAction = (maConfirm, maBack, maUp, maDown, maLeft, maRight);

  { The overlay menu's items, top to bottom (oiController only with more
    than one controller connected). }
  TOverlayItem = (oiController, oiReturn, oiMotion, oiSettings, oiRemoteLog, oiExit);

const
  { Posted to the form: close it after the current poll (the overlay
    menu's Exit). A message, not a queued closure: a form that is gone
    has no window, so the message is simply dropped. }
  WM_VG_CLOSE = WM_APP + 1;
  { Posted to the form: open Steam's binding panel after the current poll
    (the overlay menu's Controller Settings). }
  WM_VG_SETTINGS = WM_APP + 2;

type

  { A rotation as Steam reports it (InputMotionData_t.rotQuat*). }
  TPadQuat = record
    { X part. }
    X: Single;
    { Y part. }
    Y: Single;
    { Z part. }
    Z: Single;
    { W (real) part. }
    W: Single;
  end;

  { Main form: the 3D view of the connected controller. }
  TfrmGamepadVCL = class(TForm)
    { Banner: the controller shown. }
    pnlPad: TPanel;
    { Name of the controller shown (large, bold). }
    lblPadName: TLabel;
    { The "game loop": RunFrame, reading the actions, moving the model. }
    tmPoll: TTimer;
    { Opens Steam once the form is up, and again while it fails / after
      the Steam client exited. }
    tmStart: TTimer;
    { The menu bar. }
    MainMenu1: TMainMenu;
    { File menu. }
    mnuFile: TMenuItem;
    { Opens Steam's controller layout screen for the controller shown. }
    mnuLayout: TMenuItem;
    { Starts / stops sending the log to a LogReceiver (its caption says
      which). }
    mnuRemoteLog: TMenuItem;
    { Separator above @link(mnuExit). }
    mnuSep1: TMenuItem;
    { Closes the program. }
    mnuExit: TMenuItem;
    { View menu. }
    mnuView: TMenuItem;
    { Switches turning the model with the pad's motion sensors on / off
      (its caption says which). }
    mnuMotion: TMenuItem;
    { Takes the pad's present orientation as the model's front view. }
    mnuRecenter: TMenuItem;
    { Turns the model round to show its back or its face again. }
    mnuShowBack: TMenuItem;
    { Puts the camera back where it showed the whole model. }
    mnuResetView: TMenuItem;
    { The Steam root component (Active False: tmStart opens Steam). }
    SteamAPI1: TSteamAPI;
    { ISteamInput component. }
    SteamInput1: TSteamInput;
    { Log file, Steam settings, the 3D scene, the overlay, the deployment
      check. }
    procedure FormCreate(Sender: TObject);
    { Stops polling and shuts Steam down while the controls still exist. }
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
    { One frame of the "game loop". }
    procedure tmPollTimer(Sender: TObject);
    { Opens Steam (see @link(tmStart)). }
    procedure tmStartTimer(Sender: TObject);
    { File > View Controller Settings: Steam's layout screen. }
    procedure mnuLayoutClick(Sender: TObject);
    { File > Send log to receiver / Stop sending log. }
    procedure mnuRemoteLogClick(Sender: TObject);
    { File > Exit. }
    procedure mnuExitClick(Sender: TObject);
    { View > Follow pad motion. }
    procedure mnuMotionClick(Sender: TObject);
    { View > Recenter motion. }
    procedure mnuRecenterClick(Sender: TObject);
    { View > Show back / Show face. }
    procedure mnuShowBackClick(Sender: TObject);
    { View > Reset view. }
    procedure mnuResetViewClick(Sender: TObject);
    { SteamAPI1.OnLog: core log messages. }
    procedure SteamLog(Sender: TObject; ALevel: TSteamLogLevel; const AMessage: string);
    { SteamAPI1.OnInitialized: Steam started - start ISteamInput. }
    procedure SteamInitialized(Sender: TObject);
    { SteamAPI1.OnInitFailed: Steam failed to start - try again later. }
    procedure SteamInitFailed(Sender: TObject; AResult: Integer; const AMessage: string);
    { SteamAPI1.OnShutdown: Steam shut down - stop polling, wait for it. }
    procedure SteamShutdown(Sender: TObject);
    { SteamAPI1.OnSteamShutdown: the Steam client is exiting. }
    procedure SteamClientExit(Sender: TObject);
    { SteamInput1.OnSteamInputConfigurationLoaded (callback 2803): Steam
      loaded a layout for a controller. }
    procedure InputConfigurationLoaded(Sender: TObject; const AData: SteamInputConfigurationLoaded_t);
  private
    { Log file every line is appended to; '' if it cannot be written. }
    FLogFile: string;
    { Castle Game Engine's OpenGL control (Vcl.CastleControl, created in
      code, alClient). }
    FControl: TCastleControl;
    { Logs Castle's frame rate every FPS_LOG_MS. }
    FFpsTimer: TTimer;
    { The 3D viewport inside @link(FControl). }
    FViewport: TCastleViewport;
    { Left drag turns the view, the wheel zooms. }
    FNavigation: TCastleExamineNavigation;
    { Headlight: a directional light under the camera. }
    FLight: TCastleDirectionalLight;
    { The model shown, or @nil. }
    FScene: TCastleScene;
    { File name (no folder) of @link(FScene); '' when none is loaded. }
    FModelFile: string;
    { Plays any number of the model's clips at once on its joints. }
    FAnimator: TPadAnimator;
    { Castle's node for each of the animator's joints (@nil when the
      scene has no node of that name). }
    FJointNodes: array of TTransformNode;
    { The model uses the PlayStation clip names (Cross / Circle / Square /
      Triangle) for the face buttons. }
    FPlayStation: Boolean;
    { Sign of the stick values before SetAxis: -1 on the PS5 model, +1 on
      the Xbox and Steam Controller models (as found on VirtualGamepad,
      owner 2026-11-01; NOT YET SEEN in Castle). }
    FStickSign: Single;
    { Last x / y given to the animator for each analog action (a clip is
      only driven when its value changes). }
    FAnimX: array[TInputAction] of Single;
    { See @link(FAnimX). }
    FAnimY: array[TInputAction] of Single;
    { When the animator was last advanced. }
    FLastFrame: TDateTime;
    { Turn the model with the pad's motion sensors. }
    FFollowMotion: Boolean;
    { Orientation of the pad that counts as "facing the camera". }
    FMotionZero: TPadQuat;
    { @link(FMotionZero) is set. }
    FHasMotionZero: Boolean;
    { The next motion data becomes @link(FMotionZero). }
    FRecenter: Boolean;
    { Show the model's back instead of its face. }
    FShowBack: Boolean;
    { The pad's rotation last applied (relative to @link(FMotionZero)). }
    FLastMotion: TPadQuat;
    { The controller shown has reported real motion data. }
    FHasMotion: Boolean;
    { The InGame action set handle (0 until Steam has loaded the
      manifest). }
    FSetHandle: InputActionSetHandle_t;
    { Action handles, digital or analog (0 until resolved). }
    FActionHandles: array[TInputAction] of UInt64;
    { Pressed state of each digital action in the last frame. }
    FPressed: array[TInputAction] of Boolean;
    { The Menu action set handle (0 until Steam has loaded the manifest). }
    FMenuSetHandle: InputActionSetHandle_t;
    { Digital action handles of the Menu set (0 until resolved). }
    FMenuHandles: array[TMenuAction] of UInt64;
    { Pressed state of each Menu action in the last frame (True when the
      overlay opens, so a button already held must be let go first). }
    FMenuPressed: array[TMenuAction] of Boolean;
    { Every handle is non-zero. }
    FResolved: Boolean;
    { The "handles still 0" hint was logged. }
    FResolveWarned: Boolean;
    { When the handles were last looked up. }
    FLastResolve: TDateTime;
    { The controller shown (0 = none). }
    FActive: InputHandle_t;
    { The controller the user chose in the overlay (0 = the first one
      Steam lists). }
    FChosenPad: InputHandle_t;
    { Number of controllers in the last frame (a change is logged). }
    FControllerCount: Integer;
    { Controllers Steam has loaded a layout for. }
    FConfigHandles: TSteamInputHandleArray;
    { Which layout Steam loaded for each of @link(FConfigHandles). }
    FConfigTexts: array of string;
    { What the banner shows: rebuilt only when this changes. }
    FPadKey: string;
    { The first non-zero motion data was logged. }
    FMotionLogged: Boolean;
    { When Start went down (0 = not held). }
    FStartDownAt: TDateTime;
    { This hold of Start has opened the overlay already. }
    FStartUsed: Boolean;
    { The overlay menu is shown. }
    FMenuOpen: Boolean;
    { The overlay reads the InGame set's D-pad / A / B instead of the
      Menu set (the loaded layout does not bind the Menu set). }
    FMenuUsesInGame: Boolean;
    { The item the overlay highlights. }
    FMenuItem: TOverlayItem;
    { The controllers connected when the overlay opened. }
    FMenuPads: TSteamInputHandleArray;
    { Index in @link(FMenuPads) of the controller the row names. }
    FMenuPadIndex: Integer;
    { The overlay: dims the whole view, holds @link(FOverlayPanel). }
    FOverlay: TCastleRectangleControl;
    { The overlay's box in the middle. }
    FOverlayPanel: TCastleRectangleControl;
    { Background of each item (its colour shows the highlight). }
    FOverlayItems: array[TOverlayItem] of TCastleRectangleControl;
    { Text of each item (grey when it cannot be chosen). }
    FOverlayLabels: array[TOverlayItem] of TCastleLabel;
    { The key help at the bottom of the overlay (made last). }
    FOverlayHint: TCastleLabel;
    { Every line logged so far (sent first when remote logging starts);
      the oldest are dropped past LOG_KEEP_LINES. }
    FLogLines: TStringList;
    { Streams every log line to a LogReceiver while assigned. }
    FSender: TRemoteLogSender;
    { The last search for receivers (kept until the next one or the end:
      it must not be freed from its own result handler). }
    FDiscovery: TRemoteLogDiscovery;
    { From the start of a search until its result is handled. }
    FRemoteBusy: Boolean;
    { Guards @link(tmPollTimer) against re-entry. }
    FPolling: Boolean;
    { Exceptions raised by the poll so far (polling stops at 3). }
    FPollErrors: Integer;
    { The window is closing: Steam is not opened again. }
    FClosing: Boolean;
    { Appends a time-stamped line to the log file, the backlog and the
      LogReceiver (when sending). }
    procedure AddLog(const S: string);
    { Status messages of @link(FSender), written to the log. }
    procedure RemoteLogStatus(Sender: TObject; const AText: string);
    { Starts sending the log: searches for receivers in the background.
      AWhy names what asked in the log. }
    procedure StartRemoteLog(const AWhy: string);
    { Stops sending the log. AWhy names what asked in the log. }
    procedure StopRemoteLog(const AWhy: string);
    { Result of the search: connects to the first receiver found. }
    procedure RemoteLogDiscovered(Sender: TObject; const AFound: TRemoteLogReceiverArray;
      const AError: string);
    { Creates @link(FSender), sends the log so far and connects. }
    procedure ConnectRemoteLog(const AHost: string; APort: Word);
    { Puts the remote log state into the File menu and the overlay. }
    procedure UpdateRemoteLogText;
    { Logs whether the manifest, the layouts and the models are found. }
    procedure CheckDeployment;
    { Creates the Castle control, viewport, navigation and headlight. }
    procedure CreateScene;
    { Shows the model for controller type T (keeps the one shown when it
      is the same file). }
    procedure ShowModelFor(T: ESteamInputType);
    { Removes the model shown. }
    procedure RemoveModel;
    { Writes one joint's pose into Castle (FAnimator.OnApplyJoint). }
    procedure ApplyJoint(AJoint: Integer; const ATranslation: TAnimVec3;
      const ARotation: TAnimQuat);
    { Puts the model in its front (or back) view, rotated by AQ. }
    procedure SetModelRotation(const AQ: TPadQuat);
    { Turns the model to the pad's orientation when motion is on. }
    procedure ApplyMotion(const M: InputMotionData_t);
    { Switches following the pad's motion on (recentred) or off. }
    procedure SetFollowMotion(AOn: Boolean);
    { Drives the clips of analog action A when its value changed. }
    procedure AnimateAnalog(A: TInputAction; X, Y: Single);
    { Presses or releases the clip of button action A. }
    procedure AnimateButton(A: TInputAction; APressed: Boolean);
    { Puts every clip back to rest and forgets the analog values. }
    procedure ResetAnimState;
    { The started ISteamInput plug-in, or @nil. }
    function Input: TSteamInputPlugin;
    { Full path of @link(MANIFEST_FILE), or '' when not found. }
    function ManifestPath: string;
    { Full path of the model file AFileName, or '' when not found. }
    function ModelPath(const AFileName: string): string;
    { Forgets every handle and controller. }
    procedure ResetState;
    { Looks up the action set and action handles. }
    procedure ResolveHandles(P: TSteamInputPlugin);
    { Picks the controller to show; logs changes. }
    procedure RefreshControllers(P: TSteamInputPlugin);
    { Shows the controller in the banner and loads its model. }
    procedure UpdatePadBanner(P: TSteamInputPlugin);
    { Reads every InGame action, moves the model, opens the overlay on a
      long press of Start. }
    procedure ReadActions(P: TSteamInputPlugin);
    { Reads the motion data: logs the first, turns the model. }
    procedure ReadMotion(P: TSteamInputPlugin);
    { Creates the overlay menu (hidden). }
    procedure CreateOverlay;
    { Shows the overlay and switches to the Menu action set. }
    procedure OpenOverlay;
    { Hides the overlay; the InGame set again. }
    procedure CloseOverlay;
    { Item I can be chosen. }
    function OverlayItemEnabled(I: TOverlayItem): Boolean;
    { Redraws the overlay (texts, greying, highlight, layout). }
    procedure UpdateOverlay;
    { Moves the highlight ADelta items, skipping disabled ones. }
    procedure MoveOverlay(ADelta: Integer);
    { The controller row's text. }
    function PadRowText: string;
    { Moves the controller row ADelta pads on, wrapping. }
    procedure CyclePad(ADelta: Integer);
    { Does what the highlighted item says, then closes the overlay. }
    procedure ChooseOverlayItem;
    { Mouse press on the dimmed area: swallowed, so the 3D view does not
      see it. }
    procedure OverlaySwallowPress(const Sender: TCastleUserInterface;
      const Event: TInputPressRelease; var Handled: Boolean);
    { Mouse press on an overlay item: highlights and chooses it. }
    procedure OverlayItemPress(const Sender: TCastleUserInterface;
      const Event: TInputPressRelease; var Handled: Boolean);
    { Reads the Menu set (or its InGame stand-ins) while the overlay is
      shown. }
    procedure ReadMenuActions(P: TSteamInputPlugin);
    { Logs the frame rate Castle measured (FControl.Container.Fps). }
    procedure FpsTimerTick(Sender: TObject);
    { @link(WM_VG_CLOSE): closes the form. }
    procedure WMVgClose(var Msg: TMessage); message WM_VG_CLOSE;
    { @link(WM_VG_SETTINGS): Steam's binding panel (File > View Controller
      Settings). }
    procedure WMVgSettings(var Msg: TMessage); message WM_VG_SETTINGS;
  public
    { Frees the log sender, the animator and the backlog. }
    destructor Destroy; override;
  end;

{ The folder holding the program's data files, with a trailing path
  delimiter: the executable's folder.
  @returns(Absolute folder path.) }
function DataFolder: string;

var
  { The application's main form. }
  frmGamepadVCL: TfrmGamepadVCL;

implementation

{$R *.dfm}

uses
  System.DateUtils,
  System.Math,       // before System.StrUtils, whose string IfThen must win
  System.StrUtils, CastleUriUtils, Steamworks.API, Steamworks.Versions;

const
  { Manifest file name. }
  MANIFEST_FILE = 'steam_controllers.vdf';   // tools/gen_input_mapping.py MANIFEST_NAME
  { Default layouts expected next to the manifest (keep in step with
    CONTROLLERS in tools/gen_input_mapping.py). }
  EXPECTED_LAYOUTS = 11;
  { Xbox model. }
  MODEL_XBOX = 'XBoxOne_Animated.glb';
  { PlayStation model. }
  MODEL_PS = 'PS5_Animated.glb';
  { Steam Controller model. }
  MODEL_STEAM = 'SteamController_Animated.glb';
  { Every model (the deployment check looks for each). }
  MODEL_FILES: array[0..2] of string = (MODEL_XBOX, MODEL_PS, MODEL_STEAM);
  { How long a LogReceiver search listens for answers (ms). }
  REMOTE_SEARCH_MS = 2500;
  { Pause between attempts to resolve the action handles (ms). }
  RESOLVE_RETRY_MS = 1000;
  { Text of each log level. }
  LevelNames: array[TSteamLogLevel] of string = ('debug', 'info', 'warn', 'ERROR');
  { Action names as in the manifest. }
  ActionNames: array[TInputAction] of string =
    ('LeftStick', 'RightStick', 'Gyro',
     'LeftTrackpad', 'RightTrackpad', 'CenterTrackpad', 'LeftTrigger', 'RightTrigger',
     'ButtonA', 'ButtonB', 'ButtonX', 'ButtonY', 'LeftBumper', 'RightBumper',
     'LeftStickClick', 'RightStickClick', 'DPadUp', 'DPadDown', 'DPadLeft', 'DPadRight',
     'Start', 'Select', 'BackLeft', 'BackRight', 'BackLeftUpper', 'BackRightUpper',
     'LeftTrackpadClick', 'RightTrackpadClick', 'CenterTrackpadClick');
  { Analog actions (StickPadGyro / AnalogTrigger); the rest are buttons. }
  ActionAnalog: array[TInputAction] of Boolean =
    (True, True, True,
     True, True, True, True, True,
     False, False, False, False, False, False,
     False, False, False, False, False, False,
     False, False, False, False, False, False,
     False, False, False);
  { The InGame action set name as in the manifest. }
  SET_NAME = 'InGame';
  { The Menu action set name as in the manifest. }
  MENU_SET_NAME = 'Menu';
  { The Menu set's action names as in the manifest. }
  MenuActionNames: array[TMenuAction] of string =
    ('MenuConfirm', 'MenuBack', 'MenuUp', 'MenuDown', 'MenuLeft', 'MenuRight');
  { The InGame action read instead of each Menu action when the loaded
    layout does not bind the Menu set. }
  MenuFallback: array[TMenuAction] of TInputAction =
    (iaButtonA, iaButtonB, iaDPadUp, iaDPadDown, iaDPadLeft, iaDPadRight);
  { Milliseconds Start must be held to open the overlay menu. }
  LONG_PRESS_MS = 800;
  { Milliseconds between attempts to open Steam while it fails. }
  RETRY_MS = 5000;
  { Poll errors in a row after which polling stops. }
  MAX_POLL_ERRORS = 3;
  { The identity rotation. }
  QUAT_IDENTITY: TPadQuat = (X: 0; Y: 0; Z: 0; W: 1);
  { Half a turn about Y: the model's back to the camera (View > Show
    back). Castle and glTF are both Y-up, so the face needs no turn. }
  QUAT_HALF_TURN_Y: TPadQuat = (X: 0; Y: 1; Z: 0; W: 0);
  { Overlay item height and gap, in Castle UI units. }
  ITEM_HEIGHT = 48;
  { See @link(ITEM_HEIGHT). }
  ITEM_GAP = 8;
  { Overlay panel width. }
  PANEL_WIDTH = 600;
  { Lines kept in memory for the remote log's backlog. }
  LOG_KEEP_LINES = 20000;
  { Milliseconds between two frame-rate log lines. }
  FPS_LOG_MS = 5000;

var
  { Number formatting with a decimal point whatever the locale. }
  InvariantFormat: TFormatSettings;

function DataFolder: string;
begin
  Result := ExtractFilePath(ExpandFileName(ParamStr(0)));
end;

{ Fixed-format number (decimal point).
  @param(V The value.)
  @returns(Text such as +0.25.) }
function F2(V: Single): string;
begin
  Result := FormatFloat('+0.00;-0.00;0.00', V, InvariantFormat);
end;

{ An overlay colour.
  @returns(Opaque colour of the given 0..255 components.) }
function UiColor(R, G, B: Byte): TCastleColor;
begin
  Result := Vector4(R / 255, G / 255, B / 255, 1);
end;

{ Readable name of a Steam Input controller type.
  @param(T The type.)
  @returns(Name for the banner and the log.) }
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

{ The model file for a controller type: PlayStation pads -> PS5, Steam
  Controllers and the Deck -> Steam Controller, everything else -> Xbox.
  @param(T The type.)
  @returns(File name.) }
function ModelFileFor(T: ESteamInputType): string;
begin
  case T of
    k_ESteamInputType_PS3Controller, k_ESteamInputType_PS4Controller,
    k_ESteamInputType_PS5Controller:
      Result := MODEL_PS;
    k_ESteamInputType_SteamController, k_ESteamInputType_SteamController2026,
    k_ESteamInputType_SteamDeckController:
      Result := MODEL_STEAM;
  else
    Result := MODEL_XBOX;
  end;
end;

{ The model clip of a button action (positional; the PS5 model names its
  face clips after the PlayStation symbols).
  @param(A The action.)
  @param(APlayStation The model uses the PlayStation clip names.)
  @returns(Clip name, or '' when the models have no clip for it.) }
function ButtonClip(A: TInputAction; APlayStation: Boolean): string;
begin
  case A of
    iaButtonA:         Result := IfThen(APlayStation, 'X_Press', 'A_Press');
    iaButtonB:         Result := IfThen(APlayStation, 'Circle_Press', 'B_Press');
    iaButtonX:         Result := IfThen(APlayStation, 'Square_Press', 'X_Press');
    iaButtonY:         Result := IfThen(APlayStation, 'Triangle_Press', 'Y_Press');
    iaLeftBumper:      Result := 'Shoulder_Left_Press';
    iaRightBumper:     Result := 'Shoulder_Right_Press';
    iaLeftStickClick:  Result := 'Stick_Left_Press';
    iaRightStickClick: Result := 'Stick_Right_Press';
    iaDPadUp:          Result := 'DPad_Up';
    iaDPadDown:        Result := 'DPad_Down';
    iaDPadLeft:        Result := 'DPad_Left';
    iaDPadRight:       Result := 'DPad_Right';
    iaStart:           Result := 'Menu_Press';
    iaSelect:          Result := 'View_Press';
    iaBackLeft:        Result := 'L5_Press';
    iaBackRight:       Result := 'R5_Press';
    iaBackLeftUpper:   Result := 'L4_Press';
    iaBackRightUpper:  Result := 'R4_Press';
  else
    Result := '';
  end;
end;

{ Quaternion product A * B (B applied first).
  @param(A Left factor.)
  @param(B Right factor.)
  @returns(The product.) }
function QuatMul(const A, B: TPadQuat): TPadQuat;
begin
  Result.W := A.W * B.W - A.X * B.X - A.Y * B.Y - A.Z * B.Z;
  Result.X := A.W * B.X + A.X * B.W + A.Y * B.Z - A.Z * B.Y;
  Result.Y := A.W * B.Y - A.X * B.Z + A.Y * B.W + A.Z * B.X;
  Result.Z := A.W * B.Z + A.X * B.Y - A.Y * B.X + A.Z * B.W;
end;

{ Conjugate (the inverse of a unit quaternion).
  @param(Q The quaternion.)
  @returns(Its conjugate.) }
function QuatConj(const Q: TPadQuat): TPadQuat;
begin
  Result.X := -Q.X;
  Result.Y := -Q.Y;
  Result.Z := -Q.Z;
  Result.W := Q.W;
end;

{ A pad rotation as the animator's quaternion type.
  @param(Q The rotation.)
  @returns(The same rotation.) }
function ToAnimQuat(const Q: TPadQuat): TAnimQuat;
begin
  Result.X := Q.X;
  Result.Y := Q.Y;
  Result.Z := Q.Z;
  Result.W := Q.W;
end;

{ A rotation as Castle stores one: axis (x, y, z) and angle in radians.
  @param(Q The rotation.)
  @returns(Axis-angle vector.) }
function QuatToCastleRotation(const Q: TAnimQuat): TVector4;
var
  AX, AY, AZ, Angle: Single;
begin
  AnimQuatToAxisAngle(Q, AX, AY, AZ, Angle);
  Result := Vector4(AX, AY, AZ, Angle);
end;

{ Appends one line (UTF-8, line break) to a file, creating it if needed.
  @param(AFileName The file.)
  @param(ALine The line.) }
procedure AppendLine(const AFileName, ALine: string);
var
  F: TFileStream;
  Data: RawByteString;
begin
  if FileExists(AFileName) then
    F := TFileStream.Create(AFileName, fmOpenReadWrite or fmShareDenyNone)
  else
    F := TFileStream.Create(AFileName, fmCreate);
  try
    F.Seek(0, soEnd);
    Data := UTF8Encode(ALine + sLineBreak);
    if Length(Data) > 0 then
      F.WriteBuffer(Data[1], Length(Data));
  finally
    F.Free;
  end;
end;

procedure TfrmGamepadVCL.FormCreate(Sender: TObject);
var
  LogFileError: string;
begin
  LogFileError := '';
  FLogLines := TStringList.Create;
  FLogFile := DataFolder + 'VirtualGamepadVCL.log';
  try
    // start an empty log
    TFileStream.Create(FLogFile, fmCreate).Free;
  except
    on E: Exception do
    begin
      LogFileError := FLogFile + ': ' + E.Message;
      FLogFile := '';
    end;
  end;
  AddLog('FormCreate started');
  // Title from the live values: SteamAPI1.AppID (set in the form file) and
  // the SDK level this library targets - never typed into the caption
  Caption := Format('%s - AppID %d (SDK %s) - %s', [Caption, SteamAPI1.AppID,
    STEAMWORKS_SDK_VERSION, TSteamLib.PlatformDescription]);
  AddLog('Platform: ' + TSteamLib.PlatformDescription);
  if LogFileError <> '' then
    AddLog('Log file NOT written: ' + LogFileError);
  // A form file cannot depend on the build configuration, so this is here:
{$IFDEF DEBUG}
  SteamAPI1.SetAppIdEnvironment := True;   // no steam_appid.txt needed
  SteamAPI1.RestartIfNecessary := False;   // never relaunch through Steam
{$ELSE}
  SteamAPI1.RestartIfNecessary := True;
{$ENDIF}
  lblPadName.Font.Size := 16;
  // fully qualified: X3DNodes (later in the uses) declares its own fsBold
  lblPadName.Font.Style := [System.UITypes.TFontStyle.fsBold];
  // motion off at start; the overlay menu or View > Follow pad motion
  FFollowMotion := False;
  FLastMotion := QUAT_IDENTITY;
  FStickSign := 1;
  FAnimator := TPadAnimator.Create;
  FAnimator.OnApplyJoint := ApplyJoint;
  ResetState;
  AddLog('Virtual Gamepad (VCL / Castle Game Engine), AppID ' + IntToStr(SteamAPI1.AppID));
  if FLogFile <> '' then
    AddLog('Log file: ' + FLogFile);
  CheckDeployment;
  try
    CreateScene;
  except
    on E: Exception do
      AddLog('3D scene could not be created: ' + E.ClassName + ': ' + E.Message);
  end;
  try
    CreateOverlay;
  except
    on E: Exception do
      AddLog('Overlay menu could not be created: ' + E.ClassName + ': ' + E.Message);
  end;
  AddLog(Format('Hold Start for %d ms for the overlay menu (motion, controller settings, remote logging, controller, exit). '
    + 'Drag on the 3D view to turn it, wheel to zoom. Steam is opened automatically.',
    [LONG_PRESS_MS]));
end;

destructor TfrmGamepadVCL.Destroy;
begin
  // normally freed in FormClose already
  FreeAndNil(FDiscovery);
  FreeAndNil(FSender);
  inherited;
  FreeAndNil(FAnimator);
  FreeAndNil(FLogLines);
end;

procedure TfrmGamepadVCL.FormClose(Sender: TObject; var Action: TCloseAction);
begin
  AddLog(Format('FormClose: window closing (Steam running: %s)', [BoolToStr(SteamAPI1.IsRunning, True)]));
  FClosing := True;
  tmStart.Enabled := False;
  tmPoll.Enabled := False;
  if FFpsTimer <> nil then
    FFpsTimer.Enabled := False;
  SteamAPI1.Close;
  // a search still running ends within 2.5 s; its result is dropped
  FreeAndNil(FDiscovery);
  // last: the shutdown lines above are still sent (Stop waits briefly)
  FreeAndNil(FSender);
end;

procedure TfrmGamepadVCL.AddLog(const S: string);
var
  Line: string;
begin
  Line := FormatDateTime('hh:nn:ss.zzz', Now) + '  ' + S;
  if FLogLines <> nil then
  begin
    FLogLines.Add(Line);
    if FLogLines.Count > LOG_KEEP_LINES then
      FLogLines.Delete(0);
  end;
  if FSender <> nil then
    FSender.Send(Line);
  if FLogFile <> '' then
  try
    AppendLine(FLogFile, Line);
  except
    FLogFile := '';
  end;
end;

procedure TfrmGamepadVCL.CheckDeployment;
var
  Dir, Missing: string;
  SR: TSearchRec;
  Layouts, I: Integer;
begin
  Dir := DataFolder;
  AddLog('Data folder: ' + Dir);
  Layouts := 0;
  if FindFirst(Dir + 'controller_*.vdf', faAnyFile, SR) = 0 then
  begin
    repeat
      Inc(Layouts);
    until FindNext(SR) <> 0;
    FindClose(SR);
  end;
  Missing := '';
  if not FileExists(Dir + MANIFEST_FILE) then
    Missing := Missing + ' ' + MANIFEST_FILE;
  for I := Low(MODEL_FILES) to High(MODEL_FILES) do
    if not FileExists(Dir + MODEL_FILES[I]) then
      Missing := Missing + ' ' + MODEL_FILES[I];
  if (Missing = '') and (Layouts = EXPECTED_LAYOUTS) then
    AddLog(Format('Deployment OK: manifest, %d layouts, %d models', [Layouts, Length(MODEL_FILES)]))
  else
    AddLog(Format('Data not next to the program (%d of %d layouts; missing:%s) - using src\ '
      + 'and the repository''s models\ folder where they exist',
      [Layouts, EXPECTED_LAYOUTS, IfThen(Missing = '', ' nothing else', Missing)]));
end;

procedure TfrmGamepadVCL.CreateScene;
begin
  FControl := TCastleControl.Create(Self);
  FControl.Parent := Self;
  FControl.Align := alClient;
  FViewport := TCastleViewport.Create(Self);
  FViewport.FullSize := True;
  FViewport.BackgroundColor := UiColor($20, $24, $28);
  FControl.Container.Controls.InsertFront(FViewport);
  // a light that follows the camera, so the side looked at is lit: a
  // directional light as the camera's child shines where the camera looks
  // (Castle's replacement for the deprecated Items.UseHeadlight)
  FLight := TCastleDirectionalLight.Create(Self);
  FViewport.Camera.Add(FLight);
  FNavigation := TCastleExamineNavigation.Create(Self);
  FViewport.InsertFront(FNavigation);
  AddLog('3D scene created: Castle Game Engine control, viewport, examine navigation, '
    + 'directional light on the camera');
  FFpsTimer := TTimer.Create(Self);
  FFpsTimer.Interval := FPS_LOG_MS;
  FFpsTimer.OnTimer := FpsTimerTick;
  FFpsTimer.Enabled := True;
  AddLog(Format('Frame rate: Castle''s own measurement, logged every %d ms', [FPS_LOG_MS]));
end;

procedure TfrmGamepadVCL.FpsTimerTick(Sender: TObject);
begin
  if FControl = nil then
    Exit;
  // RealFps: frames per second really shown; OnlyRenderFps: what rendering
  // alone would allow (Castle's TFramesPerSecond)
  AddLog(Format('Frame rate: %.1f fps (rendering alone would allow %.1f; view %d x %d)',
    [FControl.Container.Fps.RealFps, FControl.Container.Fps.OnlyRenderFps,
     FControl.Width, FControl.Height], InvariantFormat));
end;

procedure TfrmGamepadVCL.RemoveModel;
begin
  if FScene <> nil then
  begin
    FViewport.Items.Remove(FScene);
    FreeAndNil(FScene);
    AddLog('Model removed: ' + FModelFile);
  end;
  FJointNodes := nil;
  if FAnimator <> nil then
    FAnimator.StopAll;
  FModelFile := '';
end;

procedure TfrmGamepadVCL.ShowModelFor(T: ESteamInputType);
var
  FileName, Path, Why, Missing: string;
  J: Integer;
begin
  if FViewport = nil then
    Exit;
  FileName := ModelFileFor(T);
  if FileName = FModelFile then
    Exit;
  Path := ModelPath(FileName);
  RemoveModel;
  if Path = '' then
  begin
    AddLog('Model NOT FOUND: ' + FileName + ' is neither next to the program nor in the '
      + 'repository''s models folder');
    Exit;
  end;
  try
    FScene := TCastleScene.Create(Self);
    // field changes from code (the joints) are processed like events
    FScene.ProcessEvents := True;
    FScene.Load(FilenameToUriSafe(Path));
    FViewport.Items.Add(FScene);
    FModelFile := FileName;
    AddLog('Model loaded: ' + Path);
    // the clips, read from the same file
    Why := FAnimator.LoadFromFile(Path);
    if Why <> '' then
      AddLog('Reading the clips FAILED: ' + Why);
    SetLength(FJointNodes, FAnimator.JointCount);
    Missing := '';
    for J := 0 to FAnimator.JointCount - 1 do
    begin
      FJointNodes[J] := FScene.Node(TTransformNode, FAnimator.JointNames[J],
        [fnNilOnMissing]) as TTransformNode;
      if FJointNodes[J] = nil then
        Missing := Missing + ' ' + FAnimator.JointNames[J];
    end;
    FPlayStation := FAnimator.FindClip('Circle_Press') >= 0;
    // stick clip directions per model, as found on VirtualGamepad
    if FileName = MODEL_PS then
      FStickSign := -1
    else
      FStickSign := 1;
    AddLog(Format('Animator: %d moving clips of %d, %d joints moved, %s clip names%s',
      [FAnimator.ClipCount, FAnimator.FileClipCount, FAnimator.JointCount,
       IfThen(FPlayStation, 'PlayStation', 'Xbox / Steam'),
       IfThen(Missing = '', '', '; NO Castle node for:' + Missing)]));
    ResetAnimState;
    // turns about the model's middle
    FScene.Center := FScene.LocalBoundingBox.Center;
    FHasMotionZero := False;
    FLastMotion := QUAT_IDENTITY;
    SetModelRotation(QUAT_IDENTITY);
    FNavigation.ModelBox := FScene.BoundingBox;
    FViewport.AssignDefaultCamera;
  except
    on E: Exception do
    begin
      AddLog('Loading the model FAILED: ' + Path + ': ' + E.ClassName + ': ' + E.Message);
      RemoveModel;
    end;
  end;
end;

procedure TfrmGamepadVCL.ApplyJoint(AJoint: Integer; const ATranslation: TAnimVec3;
  const ARotation: TAnimQuat);
var
  N: TTransformNode;
begin
  if (AJoint < 0) or (AJoint > High(FJointNodes)) then
    Exit;
  N := FJointNodes[AJoint];
  if N = nil then
    Exit;
  N.Translation := Vector3(ATranslation.X, ATranslation.Y, ATranslation.Z);
  N.Rotation := QuatToCastleRotation(ARotation);
end;

procedure TfrmGamepadVCL.SetModelRotation(const AQ: TPadQuat);
var
  Q: TPadQuat;
begin
  FLastMotion := AQ;
  if FScene = nil then
    Exit;
  if FShowBack then
    Q := QuatMul(AQ, QUAT_HALF_TURN_Y)
  else
    Q := AQ;
  // Steam's motion axes against Castle's: NOT YET SEEN on screen
  FScene.Rotation := QuatToCastleRotation(ToAnimQuat(Q));
end;

procedure TfrmGamepadVCL.ApplyMotion(const M: InputMotionData_t);
var
  Q: TPadQuat;
  N: TAnimQuat;
begin
  Q.X := M.rotQuatX;
  Q.Y := M.rotQuatY;
  Q.Z := M.rotQuatZ;
  Q.W := M.rotQuatW;
  if (Q.X = 0) and (Q.Y = 0) and (Q.Z = 0) and ((Q.W = 0) or (Q.W = 1)) then
    Exit;   // no motion sensors (all zeros or the identity Steam reports then)
  if not FHasMotion then
  begin
    FHasMotion := True;
    UpdateOverlay;
  end;
  N := AnimQuatNormalize(ToAnimQuat(Q));
  Q.X := N.X;
  Q.Y := N.Y;
  Q.Z := N.Z;
  Q.W := N.W;
  if FRecenter or not FHasMotionZero then
  begin
    FMotionZero := Q;
    FHasMotionZero := True;
    if FRecenter then
      AddLog(Format('Motion recentered at quat %s %s %s %s', [F2(Q.X), F2(Q.Y), F2(Q.Z), F2(Q.W)]));
    FRecenter := False;
  end;
  if FFollowMotion then
    SetModelRotation(QuatMul(QuatConj(FMotionZero), Q));
end;

procedure TfrmGamepadVCL.SetFollowMotion(AOn: Boolean);
begin
  FFollowMotion := AOn;
  if AOn then
  begin
    mnuMotion.Caption := 'Follow pad motion: on';
    // the pad's orientation NOW becomes the front view: no jump
    FRecenter := True;
  end
  else
  begin
    mnuMotion.Caption := 'Follow pad motion: off';
    SetModelRotation(QUAT_IDENTITY);
  end;
  AddLog('Follow pad motion: ' + BoolToStr(AOn, True));
  UpdateOverlay;
end;

function TfrmGamepadVCL.Input: TSteamInputPlugin;
begin
  Result := SteamInput1.Plugin;
  if (Result <> nil) and not Result.Started then
    Result := nil;
end;

function TfrmGamepadVCL.ManifestPath: string;
var
  P: string;
begin
  P := DataFolder + MANIFEST_FILE;
  if not FileExists(P) then
    // run from the IDE's output: <project>\<platform>\<config>\ -> <project>\src\
    P := ExpandFileName(DataFolder + '..' + PathDelim + '..' + PathDelim + 'src' + PathDelim
      + MANIFEST_FILE);
  if FileExists(P) then
    Result := P
  else
    Result := '';
end;

function TfrmGamepadVCL.ModelPath(const AFileName: string): string;
begin
  Result := DataFolder + AFileName;
  if FileExists(Result) then
    Exit;
  // <repo>\demos\VirtualGamepadVCL\<platform>\<config>\ -> <repo>\models\
  Result := ExpandFileName(DataFolder + '..' + PathDelim + '..' + PathDelim + '..'
    + PathDelim + '..' + PathDelim + 'models' + PathDelim + AFileName);
  if not FileExists(Result) then
    Result := '';
end;

procedure TfrmGamepadVCL.ResetState;
var
  A: TInputAction;
  M: TMenuAction;
begin
  CloseOverlay;
  FSetHandle := 0;
  FMenuSetHandle := 0;
  for M := Low(TMenuAction) to High(TMenuAction) do
    FMenuHandles[M] := 0;
  for A := Low(TInputAction) to High(TInputAction) do
  begin
    FActionHandles[A] := 0;
    FPressed[A] := False;
  end;
  FStartDownAt := 0;
  FStartUsed := False;
  FHasMotion := False;
  UpdateOverlay;
  ResetAnimState;
  FResolved := False;
  FResolveWarned := False;
  FLastResolve := 0;
  FActive := 0;
  FChosenPad := 0;
  FControllerCount := 0;
  FConfigHandles := nil;
  FConfigTexts := nil;
  FPadKey := '';
  FMotionLogged := False;
  FPollErrors := 0;
end;

procedure TfrmGamepadVCL.mnuLayoutClick(Sender: TObject);
var
  P: TSteamInputPlugin;
begin
  P := Input;
  if (P = nil) or (FActive = 0) then
  begin
    AddLog('View Controller Settings: no controller (Steam not running or no pad connected)');
    Exit;
  end;
  try
    if P.ShowBindingPanel(FActive) then
      AddLog('ShowBindingPanel: True - the Steam overlay shows the layout screen')
    else
      AddLog('ShowBindingPanel: False (no Steam overlay in this process) - choose the layout '
        + 'in the Steam client');
  except
    on E: Exception do AddLog('View Controller Settings failed: ' + E.Message);
  end;
end;

procedure TfrmGamepadVCL.mnuExitClick(Sender: TObject);
begin
  Close;
end;

procedure TfrmGamepadVCL.mnuRemoteLogClick(Sender: TObject);
begin
  if FSender <> nil then
    StopRemoteLog('File > Stop sending log')
  else
    StartRemoteLog('File > Send log to receiver');
end;

procedure TfrmGamepadVCL.UpdateRemoteLogText;
begin
  if FSender <> nil then
    mnuRemoteLog.Caption := 'Stop sending log'
  else
    mnuRemoteLog.Caption := 'Send log to receiver...';
  UpdateOverlay;
end;

procedure TfrmGamepadVCL.StopRemoteLog(const AWhy: string);
begin
  if FSender = nil then
    Exit;
  AddLog('[remote log] stopped by the user (' + AWhy + ')');
  FreeAndNil(FSender);
  UpdateRemoteLogText;
end;

// StartRemoteLog .. RemoteLogStatus: the same code as VirtualGamepad's
procedure TfrmGamepadVCL.StartRemoteLog(const AWhy: string);
begin
  if FClosing then
    Exit;
  if FSender <> nil then
  begin
    AddLog('[remote log] ' + AWhy + ': already sending');
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
  AddLog(Format('[remote log] %s: looking for LogReceiver apps on the network (%d ms)...',
    [AWhy, REMOTE_SEARCH_MS]));
  // in the background: the window and the controller poll keep running
  FDiscovery := TRemoteLogDiscovery.Create(REMOTE_SEARCH_MS, RemoteLogDiscovered);
  UpdateRemoteLogText;
end;

procedure TfrmGamepadVCL.RemoteLogDiscovered(Sender: TObject; const AFound: TRemoteLogReceiverArray;
  const AError: string);
var
  I: Integer;
begin
  // FDiscovery is NOT freed here (it is the caller of this handler)
  FRemoteBusy := False;
  if FClosing then
    Exit;
  UpdateRemoteLogText;
  if FSender <> nil then
    Exit;
  if AError <> '' then
  begin
    AddLog('[remote log] could not search the network: ' + AError);
    Exit;
  end;
  if Length(AFound) = 0 then
  begin
    AddLog(Format('[remote log] no LogReceiver answered within %d ms - start LogReceiver on a machine '
      + 'on this network, click OK there, then try again', [REMOTE_SEARCH_MS]));
    Exit;
  end;
  for I := 0 to High(AFound) do
    AddLog(Format('[remote log] found %s at %s:%d', [AFound[I].Name, AFound[I].Host, AFound[I].Port]));
  if Length(AFound) > 1 then
    AddLog(Format('[remote log] %d receivers answered - using the first (%s); close the others '
      + 'to send elsewhere', [Length(AFound), AFound[0].Name]));
  ConnectRemoteLog(AFound[0].Host, AFound[0].Port);
end;

procedure TfrmGamepadVCL.ConnectRemoteLog(const AHost: string; APort: Word);
var
  I: Integer;
begin
  FSender := TRemoteLogSender.Create;
  FSender.OnStatus := RemoteLogStatus;
  // the log so far first, so the receiver gets the whole run
  for I := 0 to FLogLines.Count - 1 do
    FSender.Send(FLogLines[I]);
  FSender.Start(AHost, APort, 'VirtualGamepadVCL', TSteamLib.PlatformDescription);
  UpdateRemoteLogText;
  AddLog(Format('[remote log] sending to %s:%d - click Yes in LogReceiver', [AHost, APort]));
end;

procedure TfrmGamepadVCL.RemoteLogStatus(Sender: TObject; const AText: string);
begin
  AddLog('[remote log] ' + AText);
  // refused / no answer: the sender has given up - offer to start again
  if (FSender <> nil) and not FSender.Active then
  begin
    FreeAndNil(FSender);
    UpdateRemoteLogText;
  end;
end;

procedure TfrmGamepadVCL.mnuMotionClick(Sender: TObject);
begin
  SetFollowMotion(not FFollowMotion);
end;

procedure TfrmGamepadVCL.mnuRecenterClick(Sender: TObject);
begin
  FRecenter := True;
  AddLog('Recenter: the pad''s next orientation becomes the front view');
end;

procedure TfrmGamepadVCL.mnuShowBackClick(Sender: TObject);
begin
  FShowBack := not FShowBack;
  if FShowBack then
    mnuShowBack.Caption := 'Show face'
  else
    mnuShowBack.Caption := 'Show back';
  SetModelRotation(FLastMotion);
  AddLog('Model shows its ' + IfThen(FShowBack, 'back', 'face'));
end;

procedure TfrmGamepadVCL.mnuResetViewClick(Sender: TObject);
begin
  if FViewport <> nil then
    FViewport.AssignDefaultCamera;
  AddLog('View reset');
end;

procedure TfrmGamepadVCL.tmStartTimer(Sender: TObject);
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

procedure TfrmGamepadVCL.SteamLog(Sender: TObject; ALevel: TSteamLogLevel; const AMessage: string);
begin
  AddLog('[' + LevelNames[ALevel] + '] ' + AMessage);
end;

procedure TfrmGamepadVCL.SteamInitialized(Sender: TObject);
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
    if not P.Start(True) then
    begin
      AddLog('ISteamInput Init returned False');
      Exit;
    end;
    AddLog('ISteamInput started (Init(True): explicit RunFrame)');
    P.EnableDeviceCallbacks;
    Path := ManifestPath;
    if Path = '' then
      AddLog('Action manifest ' + MANIFEST_FILE + ' NOT FOUND: actions will stay unbound (handles 0)')
    else
      AddLog(Format('SetInputActionManifestFilePath(%s): %s',
        [Path, BoolToStr(P.SetInputActionManifestFilePath(Path), True)]));
    FLastFrame := Now;
    tmPoll.Enabled := True;
    AddLog(Format('Polling every %d ms', [tmPoll.Interval]));
  except
    on E: Exception do AddLog('Starting ISteamInput failed: ' + E.ClassName + ': ' + E.Message);
  end;
end;

procedure TfrmGamepadVCL.SteamInitFailed(Sender: TObject; AResult: Integer; const AMessage: string);
begin
  AddLog(Format('OnInitFailed: result %d: %s', [AResult, AMessage]));
  if not FClosing then
  begin
    tmStart.Interval := RETRY_MS;
    tmStart.Enabled := True;
    AddLog(Format('Trying again in %d s', [RETRY_MS div 1000]));
  end;
end;

procedure TfrmGamepadVCL.SteamShutdown(Sender: TObject);
begin
  tmPoll.Enabled := False;
  ResetState;
  RemoveModel;
  lblPadName.Caption := 'Steam is not running - waiting for it';
  AddLog('OnShutdown: Steam shut down (ISteamInput was shut down first)');
  if not FClosing then
  begin
    tmStart.Interval := RETRY_MS;
    tmStart.Enabled := True;
    AddLog(Format('Trying to open Steam again in %d s', [RETRY_MS div 1000]));
  end;
end;

procedure TfrmGamepadVCL.SteamClientExit(Sender: TObject);
begin
  AddLog('OnSteamShutdown: the Steam client is exiting');
end;

procedure TfrmGamepadVCL.InputConfigurationLoaded(Sender: TObject; const AData: SteamInputConfigurationLoaded_t);
var
  Text: string;
  I: Integer;
  Found: Boolean;
  A: TInputAction;
  M: TMenuAction;
begin
  AddLog(Format('OnSteamInputConfigurationLoaded: handle %s, mapping by %s, revision %d.%d, '
    + 'uses Steam Input API %s',
    [UIntToStr(AData.m_ulDeviceHandle), AData.m_ulMappingCreator.ToString,
     AData.m_unMajorRevision, AData.m_unMinorRevision, BoolToStr(AData.m_bUsesSteamInputAPI, True)]));
  Text := Format('mapping by %s', [AData.m_ulMappingCreator.ToString]);
  if not AData.m_bUsesSteamInputAPI then
    Text := 'Steam Input is NOT active for this pad (' + Text + ')'
  else if AData.m_ulMappingCreator.Value = 0 then
    Text := 'the game''s default layout (' + Text + ')'
  else
    Text := 'a DIFFERENT layout, not ours (' + Text + ')';
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
  // a new layout: look every handle up again
  FSetHandle := 0;
  FMenuSetHandle := 0;
  for A := Low(TInputAction) to High(TInputAction) do
    FActionHandles[A] := 0;
  for M := Low(TMenuAction) to High(TMenuAction) do
    FMenuHandles[M] := 0;
  FResolved := False;
  FLastResolve := 0;
end;

procedure TfrmGamepadVCL.ResolveHandles(P: TSteamInputPlugin);
var
  A: TInputAction;
  M: TMenuAction;
  Missing: string;
begin
  FLastResolve := Now;
  Missing := '';
  if FSetHandle = 0 then
    FSetHandle := P.GetActionSetHandle(SET_NAME);
  if FSetHandle = 0 then
    Missing := ' ' + SET_NAME;
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
  if FMenuSetHandle = 0 then
    FMenuSetHandle := P.GetActionSetHandle(MENU_SET_NAME);
  if FMenuSetHandle = 0 then
    Missing := Missing + ' ' + MENU_SET_NAME;
  for M := Low(TMenuAction) to High(TMenuAction) do
  begin
    if FMenuHandles[M] = 0 then
      FMenuHandles[M] := P.GetDigitalActionHandle(MenuActionNames[M]);
    if FMenuHandles[M] = 0 then
      Missing := Missing + ' ' + MenuActionNames[M];
  end;
  FResolved := Missing = '';
  if FResolved then
  begin
    AddLog(Format('Handles resolved: set %s = %s and %d actions, set %s = %s and %d actions',
      [SET_NAME, UIntToStr(FSetHandle), Ord(High(TInputAction)) + 1,
       MENU_SET_NAME, UIntToStr(FMenuSetHandle), Ord(High(TMenuAction)) + 1]));
    FResolveWarned := False;
  end
  else if not FResolveWarned then
  begin
    AddLog(Format('Handles still 0 for:%s - the manifest is not loaded yet (retrying every '
      + '%d ms; if it stays so, check the manifest path)', [Missing, RESOLVE_RETRY_MS]));
    FResolveWarned := True;
  end;
end;

procedure TfrmGamepadVCL.RefreshControllers(P: TSteamInputPlugin);
var
  List: TSteamInputHandleArray;
  First: InputHandle_t;
  A: TInputAction;
  I: Integer;
begin
  List := P.ConnectedControllers;
  if Length(List) <> FControllerCount then
  begin
    FControllerCount := Length(List);
    AddLog(Format('Connected controllers: %d', [FControllerCount]));
    // the overlay's controller row would be out of date
    CloseOverlay;
  end;
  // the pad chosen in the overlay while it is connected, else the first
  First := 0;
  for I := 0 to High(List) do
    if (FChosenPad <> 0) and (List[I] = FChosenPad) then
      First := FChosenPad;
  if (First = 0) and (Length(List) > 0) then
    First := List[0];
  if First = FActive then
    Exit;
  FActive := First;
  for A := Low(TInputAction) to High(TInputAction) do
    FPressed[A] := False;
  ResetAnimState;
  FMotionLogged := False;
  FHasMotionZero := False;
  FHasMotion := False;
  FStartDownAt := 0;
  FStartUsed := False;
  CloseOverlay;
  UpdateOverlay;
  if FActive = 0 then
    AddLog('No controller to show')
  else
    AddLog(Format('Showing %s (handle %s)', [InputTypeName(P.GetInputTypeForHandle(FActive)),
      UIntToStr(FActive)]));
end;

procedure TfrmGamepadVCL.UpdatePadBanner(P: TSteamInputPlugin);
var
  T: ESteamInputType;
  PadName, Loaded, Key: string;
  I, N: Integer;
  List: TSteamInputHandleArray;
begin
  if FActive = 0 then
    T := k_ESteamInputType_Unknown
  else
    T := P.GetInputTypeForHandle(FActive);
  Loaded := 'no layout loaded yet';
  for I := 0 to High(FConfigHandles) do
    if FConfigHandles[I] = FActive then
      Loaded := FConfigTexts[I];
  Key := Format('%s/%d/%d/%s', [UIntToStr(FActive), Ord(T), FControllerCount, Loaded]);
  if Key = FPadKey then
    Exit;
  FPadKey := Key;
  if FActive = 0 then
    RemoveModel
  else
    ShowModelFor(T);
  if FActive = 0 then
    PadName := 'No controller'
  else
  begin
    PadName := InputTypeName(T);
    if FControllerCount > 1 then
    begin
      List := P.ConnectedControllers;
      N := 0;
      for I := 0 to High(List) do
        if List[I] = FActive then
          N := I + 1;
      PadName := Format('%s   (%d of %d connected - hold Start to change)',
        [PadName, N, FControllerCount]);
    end;
  end;
  lblPadName.Caption := PadName;
  if FActive <> 0 then
    AddLog(Format('Controller identified: %s - Steam type %d - model %s - %s',
      [PadName, Ord(T), FModelFile, Loaded]));
end;

procedure TfrmGamepadVCL.ResetAnimState;
var
  A: TInputAction;
begin
  for A := Low(TInputAction) to High(TInputAction) do
  begin
    FAnimX[A] := 0;
    FAnimY[A] := 0;
  end;
  if FAnimator <> nil then
    FAnimator.StopAll;
end;

procedure TfrmGamepadVCL.AnimateButton(A: TInputAction; APressed: Boolean);
var
  Clip: string;
begin
  if FScene = nil then
    Exit;
  Clip := ButtonClip(A, FPlayStation);
  if Clip = '' then
    Exit;
  // a clip the model lacks returns False (the Xbox model has no paddles)
  if APressed then
    FAnimator.Press(Clip)
  else
    FAnimator.Release(Clip);
end;

procedure TfrmGamepadVCL.AnimateAnalog(A: TInputAction; X, Y: Single);
begin
  if FScene = nil then
    Exit;
  if (X = FAnimX[A]) and (Y = FAnimY[A]) then
    Exit;
  FAnimX[A] := X;
  FAnimY[A] := Y;
  // stick signs per model (FStickSign); Steam's y is positive for up
  case A of
    iaLeftStick:
      begin
        FAnimator.SetAxis('Stick_Left_Left', 'Stick_Left_Right', FStickSign * X);
        FAnimator.SetAxis('Stick_Left_Down', 'Stick_Left_Up', FStickSign * Y);
      end;
    iaRightStick:
      begin
        FAnimator.SetAxis('Stick_Right_Left', 'Stick_Right_Right', FStickSign * X);
        FAnimator.SetAxis('Stick_Right_Down', 'Stick_Right_Up', FStickSign * Y);
      end;
    iaLeftTrigger:
      FAnimator.SetValue('Trigger_Left_Press_Full', X);
    iaRightTrigger:
      FAnimator.SetValue('Trigger_Right_Press_Full', X);
  end;
end;

procedure TfrmGamepadVCL.ReadActions(P: TSteamInputPlugin);
var
  A: TInputAction;
  D: InputDigitalActionData_t;
  An: InputAnalogActionData_t;
  OpenMenu: Boolean;
begin
  OpenMenu := False;
  for A := Low(TInputAction) to High(TInputAction) do
  begin
    if FActionHandles[A] = 0 then
      Continue;
    if ActionAnalog[A] then
    begin
      An := P.GetAnalogActionData(FActive, FActionHandles[A]);
      AnimateAnalog(A, An.x, An.y);
    end
    else
    begin
      D := P.GetDigitalActionData(FActive, FActionHandles[A]);
      if D.bState <> FPressed[A] then
      begin
        FPressed[A] := D.bState;
        AnimateButton(A, D.bState);
        AddLog(ActionNames[A] + IfThen(D.bState, ' pressed', ' released'));
      end;
      // a LONG press of Start opens the overlay menu (once per hold)
      if A = iaStart then
      begin
        if not D.bState then
        begin
          FStartDownAt := 0;
          FStartUsed := False;
        end
        else if not FStartUsed then
        begin
          if FStartDownAt = 0 then
            FStartDownAt := Now
          else if MilliSecondsBetween(Now, FStartDownAt) >= LONG_PRESS_MS then
          begin
            FStartUsed := True;
            OpenMenu := True;
          end;
        end;
      end;
    end;
  end;
  ReadMotion(P);
  if OpenMenu then
    OpenOverlay;
end;

procedure TfrmGamepadVCL.ReadMotion(P: TSteamInputPlugin);
var
  M: InputMotionData_t;
begin
  M := P.GetMotionData(FActive);
  if not FMotionLogged and ((M.rotQuatX <> 0) or (M.rotQuatY <> 0) or (M.rotQuatZ <> 0)
    or ((M.rotQuatW <> 0) and (M.rotQuatW <> 1))) then
  begin
    FMotionLogged := True;
    AddLog(Format('First motion data: quat %s %s %s %s - the pad has motion sensors (Enable '
      + 'Motion in the overlay menu, or View > Follow pad motion)',
      [F2(M.rotQuatX), F2(M.rotQuatY), F2(M.rotQuatZ), F2(M.rotQuatW)]));
  end;
  ApplyMotion(M);
end;

procedure TfrmGamepadVCL.CreateOverlay;
var
  I: TOverlayItem;
  L: TCastleLabel;
begin
  if FControl = nil then
    Exit;
  // dims the whole view and swallows clicks meant for the 3D view
  FOverlay := TCastleRectangleControl.Create(Self);
  FOverlay.FullSize := True;
  FOverlay.Color := Vector4(0, 0, 0, 0.69);
  FOverlay.OnPress := OverlaySwallowPress;
  FOverlay.Exists := False;
  FControl.Container.Controls.InsertFront(FOverlay);
  FOverlayPanel := TCastleRectangleControl.Create(Self);
  FOverlayPanel.Width := PANEL_WIDTH;
  FOverlayPanel.Anchor(hpMiddle);
  FOverlayPanel.Anchor(vpMiddle);
  FOverlayPanel.Color := UiColor($2A, $2E, $33);
  FOverlay.InsertFront(FOverlayPanel);
  L := TCastleLabel.Create(Self);
  L.Caption := 'Menu';
  L.FontSize := 24;
  L.Color := UiColor($FF, $FF, $FF);
  L.Anchor(hpMiddle);
  L.Anchor(vpTop, -16);
  FOverlayPanel.InsertFront(L);
  for I := Low(TOverlayItem) to High(TOverlayItem) do
  begin
    FOverlayItems[I] := TCastleRectangleControl.Create(Self);
    FOverlayItems[I].Width := PANEL_WIDTH - 32;
    FOverlayItems[I].Height := ITEM_HEIGHT;
    FOverlayItems[I].Anchor(hpMiddle);
    FOverlayItems[I].Tag := Ord(I);
    FOverlayItems[I].OnPress := OverlayItemPress;
    FOverlayPanel.InsertFront(FOverlayItems[I]);
    FOverlayLabels[I] := TCastleLabel.Create(Self);
    FOverlayLabels[I].FontSize := 20;
    FOverlayLabels[I].Anchor(hpMiddle);
    FOverlayLabels[I].Anchor(vpMiddle);
    FOverlayItems[I].InsertFront(FOverlayLabels[I]);
  end;
  L := TCastleLabel.Create(Self);
  L.FontSize := 14;
  L.Color := UiColor($6E, $74, $7B);
  L.Anchor(hpMiddle);
  L.Anchor(vpBottom, 12);
  FOverlayPanel.InsertFront(L);
  FOverlayHint := L;
  UpdateOverlay;
  AddLog('Overlay menu created (hidden; Castle UI, drawn above the 3D view)');
end;

function TfrmGamepadVCL.OverlayItemEnabled(I: TOverlayItem): Boolean;
begin
  case I of
    oiController: Result := Length(FMenuPads) > 1;
    oiMotion:     Result := FHasMotion;
    oiSettings:   Result := (Input <> nil) and (FActive <> 0);   // a pad to show the layout of
    oiRemoteLog:  Result := not FRemoteBusy;
  else
    Result := True;
  end;
end;

function TfrmGamepadVCL.PadRowText: string;
var
  P: TSteamInputPlugin;
  H: InputHandle_t;
  Name: string;
begin
  if (FMenuPadIndex < 0) or (FMenuPadIndex > High(FMenuPads)) then
    Exit('');
  H := FMenuPads[FMenuPadIndex];
  P := Input;
  if P <> nil then
    Name := InputTypeName(P.GetInputTypeForHandle(H))
  else
    Name := 'controller';
  // plain < > (Castle's default font may lack arrow characters)
  Result := '<   ' + Name + Format('  (%d of %d)', [FMenuPadIndex + 1, Length(FMenuPads)])
    + IfThen(H = FActive, ' - shown', '') + '   >';
end;

procedure TfrmGamepadVCL.CyclePad(ADelta: Integer);
var
  N: Integer;
begin
  N := Length(FMenuPads);
  if N < 2 then
    Exit;
  FMenuPadIndex := ((FMenuPadIndex + ADelta) mod N + N) mod N;
  AddLog('Overlay menu: controller row now names ' + PadRowText);
  UpdateOverlay;
end;

procedure TfrmGamepadVCL.UpdateOverlay;
var
  I: TOverlayItem;
  T: string;
  Y: Single;
  Shown: Integer;
begin
  // FOverlayHint is made last: nil = the overlay is not (fully) there
  if FOverlayHint = nil then
    Exit;
  if not OverlayItemEnabled(FMenuItem) then
    FMenuItem := oiReturn;
  // the controller row only with more than one pad (hidden, not greyed)
  FOverlayItems[oiController].Exists := Length(FMenuPads) > 1;
  Shown := 0;
  Y := 16 + 44;
  for I := Low(TOverlayItem) to High(TOverlayItem) do
    if FOverlayItems[I].Exists then
    begin
      FOverlayItems[I].Anchor(vpTop, -Y);
      Y := Y + ITEM_HEIGHT + ITEM_GAP;
      Inc(Shown);
    end;
  FOverlayPanel.Height := 16 + 44 + Shown * (ITEM_HEIGHT + ITEM_GAP) + 32 + 16;
  if FOverlayItems[oiController].Exists then
    FOverlayHint.Caption := 'D-pad: move, left / right: controller     A: choose     B: back'
  else
    FOverlayHint.Caption := 'D-pad: move     A: choose     B: back';
  for I := Low(TOverlayItem) to High(TOverlayItem) do
  begin
    case I of
      oiController: T := PadRowText;
      oiReturn:     T := 'Return to App';
      oiMotion:     T := IfThen(FFollowMotion, 'Disable Motion', 'Enable Motion');
      oiSettings:   T := 'Controller Settings';
      oiRemoteLog:
        if FSender <> nil then
          T := 'Stop Remote Logging'
        else if FRemoteBusy then
          T := 'Remote Logging: looking for a receiver...'
        else
          T := 'Start Remote Logging';
    else
      T := 'Exit';
    end;
    FOverlayLabels[I].Caption := T;
    if OverlayItemEnabled(I) then
      FOverlayLabels[I].Color := UiColor($FF, $FF, $FF)
    else
      FOverlayLabels[I].Color := UiColor($6E, $74, $7B);
    if I = FMenuItem then
      FOverlayItems[I].Color := UiColor($3A, $6E, $A5)
    else
      FOverlayItems[I].Color := UiColor($35, $3A, $40);
  end;
end;

procedure TfrmGamepadVCL.OpenOverlay;
var
  A: TInputAction;
  M: TMenuAction;
  P: TSteamInputPlugin;
  Unbound: string;
  I: Integer;
begin
  if FOverlay = nil then
    Exit;
  if FMenuSetHandle = 0 then
  begin
    AddLog('Long press of Start: the Menu action set is not loaded (handle 0) - no overlay menu');
    Exit;
  end;
  for A := Low(TInputAction) to High(TInputAction) do
    FPressed[A] := False;
  ResetAnimState;
  for M := Low(TMenuAction) to High(TMenuAction) do
    FMenuPressed[M] := True;
  // does the layout Steam loaded bind the Menu set? (an older copy of our
  // layout has no MenuUp / Down / Left / Right)
  Unbound := '';
  P := Input;
  if P <> nil then
    for M := Low(TMenuAction) to High(TMenuAction) do
      if (FMenuHandles[M] = 0)
        or (Length(P.DigitalActionOrigins(FActive, FMenuSetHandle, FMenuHandles[M])) = 0) then
        Unbound := Unbound + ' ' + MenuActionNames[M];
  FMenuUsesInGame := Unbound <> '';
  FMenuPads := nil;
  FMenuPadIndex := 0;
  if P <> nil then
    FMenuPads := P.ConnectedControllers;
  for I := 0 to High(FMenuPads) do
    if FMenuPads[I] = FActive then
      FMenuPadIndex := I;
  if FMenuUsesInGame then
    AddLog('The layout Steam loaded for this pad binds nothing to' + Unbound + ' in the '
      + MENU_SET_NAME + ' set (an older copy of the layout - ours binds them all - or '
      + 'a player layout): the overlay reads the D-pad, ButtonA and ButtonB of the '
      + SET_NAME + ' set instead');
  FMenuOpen := True;
  FMenuItem := oiReturn;
  FOverlay.Exists := True;
  // no turning the view by dragging over the menu
  if FNavigation <> nil then
    FNavigation.Exists := False;
  UpdateOverlay;
  AddLog('Long press of Start: overlay menu open, action set '
    + IfThen(FMenuUsesInGame, SET_NAME, MENU_SET_NAME) + Format('; %d controller(s) connected',
    [Length(FMenuPads)]));
end;

procedure TfrmGamepadVCL.CloseOverlay;
var
  A: TInputAction;
begin
  if not FMenuOpen then
    Exit;
  FMenuOpen := False;
  FMenuPads := nil;
  if FOverlay <> nil then
    FOverlay.Exists := False;
  if FNavigation <> nil then
    FNavigation.Exists := True;
  // buttons still held count as new presses in the InGame set (Start
  // cannot reopen the overlay before it is let go: FStartUsed)
  for A := Low(TInputAction) to High(TInputAction) do
    FPressed[A] := False;
  AddLog('Overlay menu closed: action set ' + SET_NAME + ' again');
end;

procedure TfrmGamepadVCL.MoveOverlay(ADelta: Integer);
var
  I: Integer;
begin
  I := Ord(FMenuItem);
  repeat
    Inc(I, ADelta);
    if (I < Ord(Low(TOverlayItem))) or (I > Ord(High(TOverlayItem))) then
      Exit;   // at the end: stay
  until OverlayItemEnabled(TOverlayItem(I));
  FMenuItem := TOverlayItem(I);
  UpdateOverlay;
end;

procedure TfrmGamepadVCL.ChooseOverlayItem;
var
  Item: TOverlayItem;
begin
  Item := FMenuItem;
  if not OverlayItemEnabled(Item) then
    Exit;
  AddLog('Overlay menu: ' + FOverlayLabels[Item].Caption);
  // A on the controller row: show that pad (before CloseOverlay, which
  // forgets the list)
  if (Item = oiController) and (FMenuPadIndex <= High(FMenuPads))
    and (FMenuPads[FMenuPadIndex] <> FActive) then
  begin
    FChosenPad := FMenuPads[FMenuPadIndex];
    AddLog('Overlay menu: switching to controller handle ' + UIntToStr(FChosenPad));
  end;
  // every choice closes the overlay
  CloseOverlay;
  case Item of
    oiMotion:
      SetFollowMotion(not FFollowMotion);
    oiSettings:
      // Steam's binding panel, as File > View Controller Settings (Big
      // Picture / Game Mode has no window menu); after this poll
      PostMessage(Handle, WM_VG_SETTINGS, 0, 0);
    oiRemoteLog:
      if FSender <> nil then
        StopRemoteLog('overlay menu')
      else
        StartRemoteLog('Overlay menu');
    oiExit:
      // after this poll: closing shuts Steam down, which must not happen
      // while the poll is still reading the pad
      PostMessage(Handle, WM_VG_CLOSE, 0, 0);
  end;
  UpdateOverlay;
end;

procedure TfrmGamepadVCL.WMVgClose(var Msg: TMessage);
begin
  Close;
end;

procedure TfrmGamepadVCL.WMVgSettings(var Msg: TMessage);
begin
  mnuLayoutClick(nil);
end;

procedure TfrmGamepadVCL.OverlaySwallowPress(const Sender: TCastleUserInterface;
  const Event: TInputPressRelease; var Handled: Boolean);
begin
  Handled := True;
end;

procedure TfrmGamepadVCL.OverlayItemPress(const Sender: TCastleUserInterface;
  const Event: TInputPressRelease; var Handled: Boolean);
var
  I: TOverlayItem;
begin
  if not Event.IsMouseButton(buttonLeft) then
    Exit;
  Handled := True;
  I := TOverlayItem(Sender.Tag);
  if not OverlayItemEnabled(I) then
    Exit;
  FMenuItem := I;
  UpdateOverlay;
  ChooseOverlayItem;
end;

procedure TfrmGamepadVCL.ReadMenuActions(P: TSteamInputPlugin);
var
  M: TMenuAction;
  D: InputDigitalActionData_t;
  H: UInt64;
begin
  for M := Low(TMenuAction) to High(TMenuAction) do
  begin
    if FMenuUsesInGame then
      H := FActionHandles[MenuFallback[M]]
    else
      H := FMenuHandles[M];
    if H = 0 then
      Continue;
    D := P.GetDigitalActionData(FActive, H);
    if D.bState = FMenuPressed[M] then
      Continue;
    FMenuPressed[M] := D.bState;
    if not D.bState then
      Continue;
    AddLog(IfThen(FMenuUsesInGame, ActionNames[MenuFallback[M]], MenuActionNames[M]) + ' pressed');
    case M of
      maUp:      MoveOverlay(-1);
      maDown:    MoveOverlay(1);
      maLeft:    if FMenuItem = oiController then CyclePad(-1);
      maRight:   if FMenuItem = oiController then CyclePad(1);
      maConfirm: ChooseOverlayItem;
      maBack:    CloseOverlay;
    end;
    if not FMenuOpen then
      Break;
  end;
  ReadMotion(P);
end;

procedure TfrmGamepadVCL.tmPollTimer(Sender: TObject);
var
  P: TSteamInputPlugin;
  Dt: Single;
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
      UpdatePadBanner(P);
      if FActive <> 0 then
      begin
        if not FResolved and (MilliSecondsBetween(Now, FLastResolve) >= RESOLVE_RETRY_MS) then
          ResolveHandles(P);
        if FMenuOpen and not FMenuUsesInGame and (FMenuSetHandle <> 0) then
          P.ActivateActionSet(FActive, FMenuSetHandle)
        else if FSetHandle <> 0 then
          P.ActivateActionSet(FActive, FSetHandle);
        if FMenuOpen then
          ReadMenuActions(P)
        else
          ReadActions(P);
      end;
      // the animator advances with real time (presses / releases)
      Dt := (Now - FLastFrame) * SecsPerDay;
      FLastFrame := Now;
      // limited to 0..0.1 s (a stalled frame must not jump a press)
      if Dt < 0 then
        Dt := 0
      else if Dt > 0.1 then
        Dt := 0.1;
      FAnimator.Update(Dt);
    except
      on E: Exception do
      begin
        Inc(FPollErrors);
        AddLog('Poll failed: ' + E.ClassName + ': ' + E.Message);
        if FPollErrors >= MAX_POLL_ERRORS then
        begin
          tmPoll.Enabled := False;
          AddLog(Format('Polling stopped after %d errors', [MAX_POLL_ERRORS]));
        end;
      end;
    end;
  finally
    FPolling := False;
  end;
end;

initialization
  InvariantFormat := TFormatSettings.Invariant;
end.
