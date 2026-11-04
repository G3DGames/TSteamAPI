{ @abstract(SteamDemoPad - the Big Picture / Steam Deck variant of
  SteamDemo (FMX): driven by the game pad through Steam Input, its whole
  screen drawn by the program.)

  There are no standard controls for the content: one TPaintBox
  (@code(pbView)) draws a page row, a list, a hint line, a status bar and,
  on top, the menu or a confirmation. Everything is laid out on a 1280 x 800
  virtual screen (the Steam Deck's) and scaled to the window, so the smallest
  text stays readable (Valve's Deck rule: at least 9 px at 1280 x 800; the
  smallest here is @link(TEXT_SMALL)).

  @unorderedList(
    @item(Steam starts BY ITSELF when the window is up; then Show Info (to
      the log) and the shared component test run on their own. Their
      result is on the status bar.)
    @item(Pages, switched with the shoulder buttons (LB / RB): Personal,
      Achievements, Two Users. D-pad or left stick: move; A: select; right
      stick: scroll.)
    @item(Start / Menu (short press) opens the menu: the controller row
      (only with more than one pad: Left / Right names another pad, A makes
      it THE pad - as in VirtualGamepad), Controller Settings
      (Steam's layout screen for the pad, ShowBindingPanel), Rumble (both
      motors for @code(tmRumble.Interval) ms), Start Sending to Remote, Take
      Screenshot, Restart Steam, Exit. Restart, not Stop: Steam Input needs
      Steam, so after a plain Stop the pad could not reach Start. Controller
      Settings, Rumble and the button names on the hint line use the pad
      chosen in the controller row, else the pad that pressed a button
      last. Every pad still moves through the pages.)
    @item(A on an achievement unlocks or clears it after an OK / Cancel
      confirmation. A on the first row of Two Users starts the pair test.)
    @item(The log goes to a LogReceiver (RemoteLogging/): a receiver is
      looked for at start, and the menu item tries again - the user must
      Accept on the receiver, which often needs more than one attempt.)
  )
  Input comes from the program's OWN action manifest
  (@link(MANIFEST_FILE), action set @link(SET_NAME); written by
  tools/gen_input_mapping.py, profile "pad"). Every connected pad is read.
  Keyboard, mouse and touch work too (for a desktop test and for the time
  Steam is not running): arrows, Enter, Escape, Q / E (pages), M (menu);
  click / tap, mouse wheel. }
unit uMain;

interface

uses
  // Windows FIRST of all units (a unit listed later wins on a shared name):
  // SysUtils' RenameFile is inlined only with it (H2443)
  {$IFDEF MSWINDOWS}Winapi.Windows,{$ENDIF}
  System.SysUtils, System.Types, System.UITypes, System.Classes, System.Generics.Collections,
  FMX.Types, FMX.Controls, FMX.Forms, FMX.Graphics, FMX.Objects, FMX.TextLayout,
  Steamworks.Types, Steamworks.SDKTypes, Steamworks.Callbacks, Steamworks.Core, Steamworks.Components,
  Steamworks.FMX, Steamworks.Plugin.Utils, Steamworks.Plugin.User, Steamworks.Plugin.Friends,
  Steamworks.Plugin.Apps, Steamworks.Plugin.UserStats, Steamworks.Plugin.RemoteStorage,
  Steamworks.Plugin.Screenshots, Steamworks.Plugin.Timeline, Steamworks.Plugin.UGC,
  Steamworks.Plugin.Input,
  SteamComponentTest, SteamPairTest,
  // optional remote logging (nothing to do with Steam - RemoteLogging/README.md)
  DemoRemoteLog;

type
  { The pages, switched with LB / RB. }
  TPadPage = (ppPersonal, ppAchievements, ppTwoUsers);

  { The logical buttons of the program (one Steam Input action each, see
    ActionNames in the implementation). }
  TPadButton = (pbUp, pbDown, pbLeft, pbRight, pbSelect, pbBack, pbPagePrev, pbPageNext, pbMenu);

  { What a list row is. }
  TRowKind = (
    { A title between groups of rows; skipped by the highlight. }
    rkHeader,
    { A name and a value. }
    rkInfo,
    { A friend (avatar, name, state). }
    rkFriend,
    { An achievement (icon; A unlocks / clears it). }
    rkAchievement,
    { The pair test's start row (A starts the test). }
    rkPairStart,
    { One row of the pair test. }
    rkPairRow);

  { The menu's items, top to bottom. }
  TMenuEntry = (
    { The controller row (shown only with more than one pad connected). }
    meController,
    meControllerSettings, meRumble, meRemoteLog, meScreenshot, meRestart, meExit);

  { What is shown on top of the page. }
  TOverlayKind = (okNone, okMenu, okConfirm);

  { What a rectangle of the last frame reacts to (mouse / touch). }
  THitKind = (hkTab, hkRow, hkMenuEntry, hkConfirmOK, hkConfirmCancel,
    { A panel's own area: a click there does nothing (it must not reach
      hkOutside underneath). }
    hkPanel,
    { Outside the menu / confirmation: closes / cancels it. }
    hkOutside);

  { One part of the hint line: the buttons' icons (or names), then a word.
    Keys holds Ord(TPadButton) values, or @link(KEY_SCROLL) for the
    right stick. }
  THintItem = record
    { The buttons, left to right. }
    Keys: array of Integer;
    { What they do. }
    Text: string;
  end;

  { One row of a page. }
  TPadRow = class
  public
    { What the row is. }
    Kind: TRowKind;
    { First line (bold). }
    Title: string;
    { Second line. }
    Detail: string;
    { Identifies the row: a SteamID text, an achievement's API name. }
    Key: string;
    { Avatar / icon (@nil = none); owned by the row. }
    Image: TBitmap;
    { Colour of the state mark at the left edge (0 = none). }
    Mark: TAlphaColor;
    { @true for an unlocked achievement. }
    Achieved: Boolean;
    { Frees the image. }
    destructor Destroy; override;
  end;

  { A rectangle (window pixels) of the last frame and what it reacts to. }
  THit = record
    { Where. }
    R: TRectF;
    { What. }
    Kind: THitKind;
    { Page, row or menu entry index. }
    Index: Integer;
  end;

  { The main (and only) form. }
  TfrmPad = class(TForm)
    { The whole screen, drawn in @link(pbViewPaint). }
    pbView: TPaintBox;
    { The pad poll and the "game loop" (RunFrame, input, scrolling, repaint). }
    tmPoll: TTimer;
    { Once a second: the tests' Tick, deferred work. }
    tmTests: TTimer;
    { Starts Steam once, when the window is up. }
    tmStart: TTimer;
    { Ends the rumble of Menu > Rumble (its Interval is how long it lasts). }
    tmRumble: TTimer;
    { The Steam root (AppID, update mode, Big Picture window in the form file). }
    SteamAPI1: TSteamAPI;
    { Personal page: persona, friends, avatars. }
    SteamFriends1: TSteamFriends;
    { Achievements page. }
    SteamUserStats1: TSteamUserStats;
    { The pad. }
    SteamInput1: TSteamInput;
    { Opens the log file, creates the tests, the remote log, starts looking
      for a receiver and arms @link(tmStart). }
    procedure FormCreate(Sender: TObject);
    { Ends the tests, closes Steam and the remote log. }
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
    { Stops the timers, frees the page lists. }
    procedure FormDestroy(Sender: TObject);
    { Keyboard: the same buttons as the pad. }
    procedure FormKeyDown(Sender: TObject; var Key: Word; var KeyChar: WideChar; Shift: TShiftState);
    { Draws everything. }
    procedure pbViewPaint(Sender: TObject; Canvas: TCanvas);
    { Mouse / touch: pages, rows, the menu, the confirmation; right click opens the menu. }
    procedure pbViewMouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Single);
    { Mouse wheel: scrolls the list. }
    procedure pbViewMouseWheel(Sender: TObject; Shift: TShiftState; WheelDelta: Integer; var Handled: Boolean);
    { The pad poll (see @link(tmPoll)). }
    procedure tmPollTimer(Sender: TObject);
    { See @link(tmTests). }
    procedure tmTestsTimer(Sender: TObject);
    { See @link(tmStart). }
    procedure tmStartTimer(Sender: TObject);
    { See @link(tmRumble): both motors off. }
    procedure tmRumbleTimer(Sender: TObject);
    { SteamAPI1.OnInitialized: Steam Input, the pages, the start-up tests. }
    procedure SteamInitialized(Sender: TObject);
    { SteamAPI1.OnInitFailed. }
    procedure SteamInitFailed(Sender: TObject; AResult: Integer; const AMessage: string);
    { SteamAPI1.OnShutdown. }
    procedure SteamShutdown(Sender: TObject);
    { SteamAPI1.OnSteamShutdown: the Steam client is exiting. }
    procedure SteamClientExit(Sender: TObject);
    { SteamAPI1.OnLog. }
    procedure SteamLog(Sender: TObject; ALevel: TSteamLogLevel; const AMessage: string);
    { SteamAPI1.OnWarning. }
    procedure SteamWarning(Sender: TObject; ASeverity: Integer; const AText: string);
    { SteamFriends1.OnPersonaStateChange: the Personal page is rebuilt. }
    procedure FriendPersonaChanged(Sender: TObject; const AData: PersonaStateChange_t);
    { SteamFriends1.OnAvatarImageLoaded: an avatar arrived. }
    procedure FriendAvatarLoaded(Sender: TObject; const AData: AvatarImageLoaded_t);
    { SteamUserStats1.OnUserStatsReceived: the Achievements page is rebuilt. }
    procedure StatsReceived(Sender: TObject; const AData: UserStatsReceived_t);
    { SteamUserStats1.OnUserStatsStored: the result of StoreStats. }
    procedure StatsStored(Sender: TObject; const AData: UserStatsStored_t);
    { SteamUserStats1.OnUserAchievementIconFetched: an icon arrived. }
    procedure AchievementIconFetched(Sender: TObject; const AData: UserAchievementIconFetched_t);
    { SteamInput1.OnSteamInputConfigurationLoaded: which layout Steam loaded. }
    procedure InputConfigurationLoaded(Sender: TObject; const AData: SteamInputConfigurationLoaded_t);
  private
    { The rows of each page (owned). }
    FRows: array[TPadPage] of TObjectList<TPadRow>;
    { The highlighted row of each page (-1 = none). }
    FSel: array[TPadPage] of Integer;
    { Scroll offset of each page's list, virtual pixels. }
    FScroll: array[TPadPage] of Single;
    { The page shown. }
    FPage: TPadPage;
    { What is shown on top of the page. }
    FOverlay: TOverlayKind;
    { The highlighted menu entry. }
    FMenuSel: TMenuEntry;
    { The confirmation's question. }
    FConfirmText: string;
    { @true while OK (not Cancel) is highlighted in the confirmation. }
    FConfirmOK: Boolean;
    { The achievement the confirmation is about (API name). }
    FConfirmKey: string;
    { @true: the confirmation unlocks (else clears) @code(FConfirmKey). }
    FConfirmUnlock: Boolean;
    { Rectangles of the last frame (mouse / touch). }
    FHits: TList<THit>;
    { Window pixels per virtual pixel (last frame). }
    FScale: Single;
    { Width of the virtual screen; wider than @link(VIRTUAL_W) on a wider
      window. }
    FVirtualW: Single;
    { Height of the virtual screen; taller than @link(VIRTUAL_H) on a
      taller window (the status bar stays at the bottom). }
    FVirtualH: Single;
    { Reused for every piece of text; created at the first paint for the
      canvas class FMX really uses (GDI+, Direct2D, Skia ...). }
    FText: TTextLayout;
    { Big Picture as Steam said at the last check (once a second). }
    FInBigPicture: Boolean;
    { The Personal page has asked Steam for every friend's name and avatar
      (once per Steam start; later rebuilds only read). }
    FFriendsRequested: Boolean;
    { Height of the list area of the last frame, virtual pixels. }
    FListH: Single;
    { Something changed: repaint on the next poll. }
    FDirty: Boolean;
    { The Pad action set (0 until the manifest is loaded). }
    FSetHandle: InputActionSetHandle_t;
    { The digital actions. }
    FActions: array[TPadButton] of InputDigitalActionHandle_t;
    { The analog scroll action. }
    FScrollAction: InputAnalogActionHandle_t;
    { Every handle is known. }
    FResolved: Boolean;
    { @link(TestTicks) of the last attempt to resolve the handles. }
    FLastResolve: UInt64;
    { The handles were missing once (logged once). }
    FResolveWarned: Boolean;
    { Pads connected at the last poll. }
    FPads: TSteamInputHandleArray;
    { The pad that pressed a button last (0 = none yet: the first pad);
      Controller Settings and Rumble act on it. }
    FActivePad: InputHandle_t;
    { The pad that rumbles now (0 = none). }
    FRumblePad: InputHandle_t;
    { The pad chosen in the menu's controller row (0 = none: the pad that
      pressed last is used). }
    FChosenPad: InputHandle_t;
    { The pads the menu's controller row steps through (taken when the menu
      opens). }
    FMenuPads: TSteamInputHandleArray;
    { The pad the controller row names (index in @code(FMenuPads)). }
    FMenuPadIndex: Integer;
    { Each button held at the last poll (any pad). }
    FHeld: array[TPadButton] of Boolean;
    { When a held direction repeats next (TestTicks). }
    FRepeatAt: array[TPadButton] of UInt64;
    { What each button is called on the active pad (hint line). }
    FGlyphs: array[TPadButton] of string;
    { Steam's picture of each button on the active pad (@nil = none: the
      name is shown); owned. }
    FGlyphIcons: array[TPadButton] of TBitmap;
    { The right stick's (scroll) name and picture (@nil = none; owned). }
    FScrollName: string;
    { See @code(FScrollName). }
    FScrollIcon: TBitmap;
    { The pad @code(FGlyphs) were read for (0 = defaults). }
    FGlyphPad: InputHandle_t;
    { TestTicks of the last poll (scroll speed). }
    FLastPoll: UInt64;
    { The poll is running (a nested timer event is skipped). }
    FPolling: Boolean;
    { Log file ('' = none). }
    FLogFile: string;
    { Every log line (the backlog for a receiver found later). }
    FLog: TStringList;
    { The remote log. }
    FRemote: TDemoRemoteLog;
    { The last "[remote log] ..." line (status bar). }
    FRemoteStatus: string;
    { The controller line as last drawn (a change repaints). }
    FDeviceText: string;
    { The shared component test. }
    FTest: TSteamComponentTest;
    { The shared pair test. }
    FPair: TSteamPairTest;
    { The component test's result (status bar). }
    FTestSummary: string;
    { Steam's state (status bar). }
    FSteamStatus: string;
    { Show Info + the component test run at the next tmTests tick. }
    FStartupDue: Boolean;
    { The Personal page is rebuilt at the next tmTests tick. }
    FPersonalDirty: Boolean;
    { TestTicks when the screenshot is due (0 = none): the menu must be
      gone from the window first. }
    FShotDue: UInt64;
    { The window is closing. }
    FClosing: Boolean;
    { Adds a time-stamped line to the log (file, stderr on POSIX, receiver). }
    procedure AddLog(const S: string);
    { DemoRemoteLog.OnLog. }
    procedure RemoteLogLine(const AText: string);
    { DemoRemoteLog.OnChanged. }
    procedure RemoteLogChanged(Sender: TObject);
    { The Steam Input plug-in once started (@nil otherwise). }
    function Input: TSteamInputPlugin;
    { Full path of @link(MANIFEST_FILE) ('' = not found). }
    function ManifestPath: string;
    { Starts ISteamInput and loads the manifest (OnInitialized). }
    procedure StartInput;
    { Forgets the input handles and buttons (Steam stopped / restarted). }
    procedure ResetInput;
    { Looks up the set and action handles. }
    procedure ResolveHandles(P: TSteamInputPlugin);
    { Reads what the buttons are called on pad APad, and Steam's pictures
      of them (hint line, page row). }
    procedure ReadGlyphs(P: TSteamInputPlugin; APad: InputHandle_t);
    { Loads Steam's picture of AOrigin into a new bitmap (@nil when Steam
      has none). @returns(What was loaded or tried, for the log.) }
    function LoadGlyph(P: TSteamInputPlugin; AOrigin: EInputActionOrigin; out ABitmap: TBitmap): string;
    { Frees the button pictures. }
    procedure FreeGlyphIcons;
    { Width of key AKey drawn by @link(DrawKey), virtual pixels. }
    function KeyWidth(C: TCanvas; AKey: Integer): Single;
    { Draws key AKey (picture, else name) with its left edge at AX,
      centred on AY. @returns(Its width.) }
    function DrawKey(C: TCanvas; AKey: Integer; AX, AY: Single): Single;
    { Draws the hint items centred in ARect. }
    procedure DrawHint(C: TCanvas; const ARect: TRectF; const AItems: array of THintItem);
    { Reads every pad: presses, repeats, scrolling. }
    procedure ReadPads(P: TSteamInputPlugin);
    { One press of a logical button (pad, keyboard). }
    procedure PressButton(B: TPadButton);
    { Moves the highlight by ADelta rows (headers skipped). }
    procedure MoveSelection(ADelta: Integer);
    { Scrolls so the highlighted row is in view. }
    procedure KeepSelectionVisible;
    { Scrolls the list by ADelta virtual pixels (and repaints). }
    procedure ScrollBy(ADelta: Single);
    { Keeps the page's scroll offset in range (no repaint: called while
      drawing). }
    procedure ClampScroll(APage: TPadPage);
    { Shows page APage. }
    procedure ShowPage(APage: TPadPage);
    { A on the highlighted row. }
    procedure ActivateRow;
    { Opens the menu. }
    procedure OpenMenu;
    { Closes the menu / confirmation. }
    procedure CloseOverlay;
    { Text of menu entry E (depends on the state). }
    function MenuEntryText(E: TMenuEntry): string;
    { @true when menu entry E can do something now (else it is drawn greyed). }
    function MenuEntryEnabled(E: TMenuEntry): Boolean;
    { @true when menu entry E is in the menu at all (the controller row
      only with more than one pad). }
    function MenuEntryVisible(E: TMenuEntry): Boolean;
    { Moves the menu highlight by ADelta visible entries. }
    procedure MoveMenu(ADelta: Integer);
    { The controller row's text: the pad it names, "n of N", arrows. }
    function PadRowText: string;
    { Left / Right on the controller row: the next / previous pad. }
    procedure CyclePad(ADelta: Integer);
    { The pad Controller Settings and Rumble act on (0 = none connected). }
    function TargetPad: InputHandle_t;
    { Menu > Controller Settings: Steam's layout screen for the pad. }
    procedure ShowControllerSettings;
    { Menu > Rumble: both motors of the pad, then @link(tmRumble) stops them. }
    procedure Rumble;
    { Runs the highlighted menu entry. }
    procedure ChooseMenu;
    { Answers the confirmation (AOK: OK, else Cancel). }
    procedure AnswerConfirm(AOK: Boolean);
    { Unlocks / clears an achievement and stores it. }
    procedure SetAchievement(const AName: string; AUnlock: Boolean);
    { Starts Steam (no-op while it runs). }
    procedure StartSteam(const AWhy: string);
    { Ends the tests (cleanup needs Steam) and closes Steam. }
    procedure StopSteam(const AWhy: string);
    { Menu > Restart Steam (Start Steam while it is not running). }
    procedure RestartSteam;
    { The start-up checks: Show Info to the log, then the component test. }
    procedure RunStartupChecks;
    { Show Info: the plug-ins' state to the log. }
    procedure ShowInfo;
    { Rebuilds the Personal page. }
    procedure LoadPersonal;
    { Rebuilds the Achievements page. }
    procedure LoadAchievements;
    { Rebuilds the Two Users page. }
    procedure LoadPairRows;
    { Keeps a page's highlight on a selectable row after a rebuild. }
    procedure FixSelection(APage: TPadPage);
    { The row of APage whose Key is AKey (@nil = none). }
    function FindRow(APage: TPadPage; const AKey: string): TPadRow;
    { Sets row ARow's image from a Steam image handle. }
    procedure SetRowImage(ARow: TPadRow; AImage: Integer);
    { FTest.OnRowChanged: the status bar summary. }
    procedure TestRow(AIndex: Integer; const AText: string);
    { FTest.OnFinished. }
    procedure TestFinished(Sender: TObject);
    { FTest.OnScreenshotRequested. }
    procedure TestScreenshotRequested(Sender: TObject);
    { FPair.OnRowChanged. }
    procedure PairRow(AIndex: Integer; const AText: string);
    { FPair.OnFinished. }
    procedure PairFinished(Sender: TObject);
    { Writes the window as a Steam screenshot. }
    procedure TakeScreenshot;
    { Updates @code(FSteamStatus). }
    procedure UpdateSteamStatus;
    { Asks Steam whether it is in Big Picture (once a second): the window
      goes full screen when it is - also when Big Picture is switched on
      after the start (TSteamAPI checks only once, at Open). }
    procedure CheckBigPicture;
    { Asks for a repaint at the next poll. }
    procedure Invalidate;
    { Virtual rectangle -> window pixels. }
    function Px(const R: TRectF): TRectF;
    { Fills a rounded rectangle (virtual coordinates). }
    procedure Box(C: TCanvas; const R: TRectF; AColor: TAlphaColor; ARadius: Single = 0);
    { One line (or, with AWrap, a block) of text (virtual coordinates);
      trimmed with an ellipsis when too long. }
    procedure Text(C: TCanvas; const R: TRectF; const S: string; ASize: Single; AColor: TAlphaColor;
      AAlign: TTextAlign = TTextAlign.Leading; ABold: Boolean = False; AWrap: Boolean = False);
    { Records a hit rectangle (virtual coordinates). }
    procedure AddHit(const R: TRectF; AKind: THitKind; AIndex: Integer);
    { Draws the page row. }
    procedure DrawTabs(C: TCanvas);
    { Draws the line under the page row naming the controller in use. }
    procedure DrawDevice(C: TCanvas);
    { The text of that line. }
    function DeviceText: string;
    { Draws the list of the page shown. }
    procedure DrawList(C: TCanvas; const AArea: TRectF);
    { Draws the hint line and the status bar. }
    procedure DrawBars(C: TCanvas);
    { Draws the menu. }
    procedure DrawMenu(C: TCanvas);
    { Draws the confirmation. }
    procedure DrawConfirm(C: TCanvas);
  end;

var
  { The application's main form. }
  frmPad: TfrmPad;

const
  { Width of the virtual screen the layout is made for (the Steam Deck's). }
  VIRTUAL_W = 1280;
  { Height of the virtual screen. }
  VIRTUAL_H = 800;
  { Smallest text, virtual pixels (Valve's Deck rule: >= 9 at 1280 x 800;
    12 recommended). }
  TEXT_SMALL = 16;
  { The program's own action manifest (tools/gen_input_mapping.py
    PAD_MANIFEST_NAME; gen_projects.py's PAD_INPUT_FILES). }
  MANIFEST_FILE = 'steamdemopad_controllers.vdf';
  { The manifest's only action set. }
  SET_NAME = 'Pad';
  { The manifest's analog scroll action. }
  SCROLL_ACTION = 'PadScroll';
  { Names of the pages. }
  PageTitles: array[TPadPage] of string = ('Personal', 'Achievements', 'Two Users');

{ The folder of the program's data files (manifest and layouts): next to
  the executable; on macOS Contents/Resources of the bundle. }
function DataFolder: string;

implementation

{$R *.fmx}

uses
  System.IOUtils, System.DateUtils,
  System.Math,       // Min / Max - BEFORE System.StrUtils, whose string IfThen must win
  System.StrUtils, Steamworks.API, Steamworks.Versions, FmxWineCanvas;

const
  { The digital actions of the manifest, one per logical button. }
  ActionNames: array[TPadButton] of string = ('PadUp', 'PadDown', 'PadLeft', 'PadRight', 'PadSelect',
    'PadBack', 'PagePrev', 'PageNext', 'PadMenu');
  { What a button is called until Steam says it for the pad in use. }
  DefaultGlyphs: array[TPadButton] of string = ('Up', 'Down', 'Left', 'Right', 'A', 'B', 'LB', 'RB',
    'Start');
  { A held direction repeats after this many milliseconds ... }
  REPEAT_DELAY_MS = 400;
  { ... then every this many milliseconds. }
  REPEAT_MS = 90;
  { Up / Down held in the menu move one entry this often (first step
    included) - slower than the lists: the menu is short and wraps round
    (owner 2026-11-04: "about 0.5 s"). }
  MENU_REPEAT_MS = 500;
  { Missing handles are looked up again this often (the manifest may load
    a moment after Init). }
  RESOLVE_RETRY_MS = 1000;
  { Right stick at full deflection scrolls this many virtual pixels a second. }
  SCROLL_SPEED = 1200;
  { Stick deflection below this is ignored. }
  STICK_DEAD = 0.2;
  { A wheel notch (120) scrolls this many virtual pixels. }
  WHEEL_STEP = 72;
  { The screenshot is taken this long after the menu closed. }
  SHOT_DELAY_MS = 150;
  { Speed of both rumble motors for Menu > Rumble (0..65535); how long it
    lasts is tmRumble.Interval. }
  RUMBLE_SPEED = 40000;
  { Motor speed that stops the rumble. }
  RUMBLE_OFF = 0;
  { GetCurrentBatteryPower's answer on mains power (no battery). }
  BATTERY_MAINS = 255;
  { WriteScreenshot's answer when it failed (INVALID_SCREENSHOT_HANDLE). }
  INVALID_SCREENSHOT = 0;
  { Key code of the right stick in a @link(THintItem) (the buttons use
    Ord(TPadButton)). }
  KEY_SCROLL = -1;
  { Height of a button picture in the hint line and the page row. }
  ICON_H = 34;
  { Height of a list row, virtual pixels. }
  ROW_H = 72;
  { Side length of a row's picture. }
  PIC_SIZE = 56;
  { Height of the page row at the top. }
  TABS_H = 76;
  { Height of the line under the page row that names the controller in use. }
  DEVICE_H = 40;
  { Height of the hint line. }
  HINT_H = 40;
  { Height of the status bar. }
  STATUS_H = 44;
  { Left / right margin of the list. }
  MARGIN = 48;
  { Text sizes, virtual pixels. }
  TEXT_TITLE = 22;
  { See TEXT_TITLE. }
  TEXT_ROW = 20;
  { See TEXT_TITLE. }
  TEXT_DETAIL = 17;
  { Menu panel width. }
  MENU_W = 560;
  { Menu entry height. }
  MENU_ITEM_H = 64;
  { Confirmation panel width. }
  CONFIRM_W = 720;
  { Colours. }
  COL_BACK = $FF14171B;
  { See COL_BACK. }
  COL_BAR = $FF1E2329;
  { See COL_BACK. }
  COL_ROW = $FF22272E;
  { See COL_BACK. }
  COL_SELECT = $FF2F6FD6;
  { See COL_BACK. }
  COL_TEXT = $FFEDEFF2;
  { See COL_BACK. }
  COL_DIM_TEXT = $FFA5ADB8;
  { See COL_BACK. }
  COL_HEADER = $FF8FB6FF;
  { See COL_BACK. }
  COL_PASS = $FF3DBE6B;
  { See COL_BACK. }
  COL_FAIL = $FFE0524A;
  { See COL_BACK. }
  COL_WAIT = $FFE0B44A;
  { See COL_BACK. }
  COL_SHADE = $C0000000;
  { See COL_BACK. }
  COL_PANEL = $FF2A2E33;
  { Text for each log level. }
  LevelNames: array[TSteamLogLevel] of string = ('debug', 'info', 'warn', 'ERROR');

function DataFolder: string;
begin
  // ExpandFileName: ParamStr(0) can be relative on POSIX (argv[0])
  Result := ExtractFilePath(ExpandFileName(ParamStr(0)));
{$IF DEFINED(MACOS) and not DEFINED(IOS)}
  // <bundle>/Contents/MacOS/<exe> -> <bundle>/Contents/Resources/
  Result := IncludeTrailingPathDelimiter(ExpandFileName(Result + '..' + PathDelim + 'Resources'));
{$ENDIF}
end;

{ "yes" / "no" (Delphi's BoolToStr has no texts parameters). }
function YesNo(AValue: Boolean): string;
begin
  if AValue then
    Result := 'yes'
  else
    Result := 'no';
end;

{ Readable persona state. }
function PersonaStateText(AState: EPersonaState): string;
begin
  case Ord(AState) of
    0: Result := 'offline';
    1: Result := 'online';
    2: Result := 'busy';
    3: Result := 'away';
    4: Result := 'snooze';
    5: Result := 'looking to trade';
    6: Result := 'looking to play';
    7: Result := 'invisible';
  else
    Result := 'state ' + IntToStr(Ord(AState));
  end;
end;

{ Mark colour of a test row text (PASS / FAIL / anything else). }
function VerdictColor(const AText: string): TAlphaColor;
begin
  if StartsStr('PASS', AText) then
    Result := COL_PASS
  else if StartsStr('FAIL', AText) then
    Result := COL_FAIL
  else if AText <> '' then
    Result := COL_WAIT
  else
    Result := 0;
end;

{ Readable name of a Steam Input controller type (every type of SDK 1.65;
  the same list as VirtualGamepad's). }
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

{ A hint item: keys AKeys, then AText. }
function HintItem(const AKeys: array of Integer; const AText: string): THintItem;
var
  I: Integer;
begin
  SetLength(Result.Keys, Length(AKeys));
  for I := 0 to High(AKeys) do
    Result.Keys[I] := AKeys[I];
  Result.Text := AText;
end;

{ TPadRow }

destructor TPadRow.Destroy;
begin
  Image.Free;
  inherited;
end;

{ TfrmPad - start / end }

procedure TfrmPad.FormCreate(Sender: TObject);
var
  P: TPadPage;
  B: TPadButton;
  LogFileError: string;
begin
  FLog := TStringList.Create;
  FHits := TList<THit>.Create;
  for P := Low(TPadPage) to High(TPadPage) do
  begin
    FRows[P] := TObjectList<TPadRow>.Create(True);
    FSel[P] := -1;
    FScroll[P] := 0;
  end;
  for B := Low(TPadButton) to High(TPadButton) do
    FGlyphs[B] := DefaultGlyphs[B];
  FScrollName := 'Right stick';
  FScale := 1;
  FVirtualW := VIRTUAL_W;
  FVirtualH := VIRTUAL_H;
  FListH := VIRTUAL_H;
  FPage := ppPersonal;
  FTestSummary := 'Component test: not run yet';
  FRemoteStatus := 'remote log: looking for a receiver';

  FLogFile := TPath.Combine(ExtractFilePath(ExpandFileName(ParamStr(0))), 'SteamDemoPad.log');
  LogFileError := '';
  // the previous run's log stays as SteamDemoPad.previous.log
  if FileExists(FLogFile) then
  begin
    System.SysUtils.DeleteFile(ChangeFileExt(FLogFile, '.previous.log'));
    RenameFile(FLogFile, ChangeFileExt(FLogFile, '.previous.log'));
  end;
  try
    TFile.WriteAllText(FLogFile, '');
  except
    on E: Exception do
    begin
      // in Steam's Linux runtime the game folder is not writable
      LogFileError := FLogFile + ': ' + E.Message;
      FLogFile := '';
    end;
  end;
  AddLog('FormCreate started');
  if LogFileError <> '' then
    AddLog('Log file could not be created (' + LogFileError + '); the log goes to the receiver'
      {$IFDEF POSIX} + ' and stderr'{$ENDIF} + ' only')
  else
    AddLog('Log file: ' + FLogFile);
  Caption := Format('%s - AppID %d (SDK %s) - %s', [Caption, SteamAPI1.AppID, STEAMWORKS_SDK_VERSION,
    TSteamLib.PlatformDescription]);
  if FmxWineCanvasNote <> '' then
    AddLog(FmxWineCanvasNote);
  AddLog('FMX canvas in use: ' + FmxCanvasClassName);
{$IFDEF DEBUG}
  // Development: no steam_appid.txt needed, never relaunch through Steam
  SteamAPI1.SetAppIdEnvironment := True;
  SteamAPI1.RestartIfNecessary := False;
{$ELSE}
  SteamAPI1.RestartIfNecessary := True;
{$ENDIF}
  FTest := TSteamComponentTest.Create(Self, SteamAPI1);
  FTest.OnLog := AddLog;
  FTest.OnRowChanged := TestRow;
  FTest.OnFinished := TestFinished;
  FTest.OnScreenshotRequested := TestScreenshotRequested;
  FPair := TSteamPairTest.Create(Self, SteamAPI1);
  FPair.AppName := 'SteamDemoPad (FMX)';
  FPair.OnLog := AddLog;
  FPair.OnRowChanged := PairRow;
  FPair.OnFinished := PairFinished;
  LoadPairRows;
  FRemote := TDemoRemoteLog.Create(Self, 'SteamDemoPad', TSteamLib.PlatformDescription);
  FRemote.OnLog := RemoteLogLine;
  FRemote.OnChanged := RemoteLogChanged;
  AddLog(Format('SteamDemoPad, AppID %d, %d plug-in class(es) linked; update mode %s, delivery %s, '
    + 'interval %d ms; pad poll every %d ms', [SteamAPI1.AppID, Length(TSteamworks.RegisteredPlugins),
    UpdateModeText(SteamAPI1.UpdateMode), IntToStr(Ord(SteamAPI1.Delivery)), SteamAPI1.CallbackInterval,
    tmPoll.Interval]));
  // Look for a receiver at once (it often needs the user to Accept on the
  // receiver; the menu item tries again)
  AddLog('Remote log: looking for a LogReceiver (Menu > Start Sending to Remote tries again)');
  FRemote.Toggle(FLog);
  UpdateSteamStatus;
  // Steam starts by itself, once the window is up (not inside FormCreate)
  AddLog(Format('Steam starts in %d ms (automatically - this program has no Start button)', [tmStart.Interval]));
  tmStart.Enabled := True;
  // the poll also drives keyboard repaints and the screenshot delay
  FLastPoll := TestTicks;
  tmPoll.Enabled := True;
  Invalidate;
end;

procedure TfrmPad.FormClose(Sender: TObject; var Action: TCloseAction);
begin
  FClosing := True;
  AddLog(Format('FormClose: window closing (Steam running: %s)', [YesNo(SteamAPI1.IsRunning)]));
  tmStart.Enabled := False;
  // a running rumble stops now, while the plug-in is still there
  if tmRumble.Enabled then
    tmRumbleTimer(nil);
  StopSteam('window closing');
  tmPoll.Enabled := False;
  tmTests.Enabled := False;
  // last: the lines above still reach the receiver
  FRemote.Shutdown;
end;

procedure TfrmPad.FormDestroy(Sender: TObject);
var
  P: TPadPage;
begin
  tmPoll.Enabled := False;
  tmTests.Enabled := False;
  tmStart.Enabled := False;
  tmRumble.Enabled := False;
  for P := Low(TPadPage) to High(TPadPage) do
    FRows[P].Free;
  FHits.Free;
  FreeAndNil(FText);
  FreeAndNil(FLog);
  FreeGlyphIcons;
end;

procedure TfrmPad.AddLog(const S: string);
var
  Line: string;
begin
  Line := FormatDateTime('hh:nn:ss.zzz', Now) + '  ' + S;
{$IFDEF POSIX}
  // stderr first: in Steam's Linux runtime the game folder is read-only,
  // and stderr is what the launch options capture
  WriteLn(ErrOutput, Line);
  Flush(ErrOutput);
{$ENDIF}
  if FLog <> nil then
    FLog.Add(Line);
  if FLogFile <> '' then
  try
    TFile.AppendAllText(FLogFile, Line + sLineBreak);
  except
    FLogFile := '';
  end;
  if FRemote <> nil then
    FRemote.Send(Line);
end;

procedure TfrmPad.RemoteLogLine(const AText: string);
begin
  AddLog(AText);
  // the remote log's own state for the status bar
  FRemoteStatus := AText;
  Invalidate;
end;

procedure TfrmPad.RemoteLogChanged(Sender: TObject);
begin
  case FRemote.State of
    drsSearching: FRemoteStatus := '[remote log] looking for a receiver';
    drsConnecting: FRemoteStatus := '[remote log] connecting - waiting for Accept on the receiver';
    drsSending: FRemoteStatus := '[remote log] sending to the receiver';
  else
    ;   // idle: the last "[remote log]" line (RemoteLogLine) says why
  end;
  Invalidate;
end;

procedure TfrmPad.Invalidate;
begin
  FDirty := True;
end;

procedure TfrmPad.UpdateSteamStatus;
begin
  if SteamAPI1.IsRunning then
    FSteamStatus := Format('Steam running, AppID %d', [SteamAPI1.AppID])
  else
    FSteamStatus := 'Steam NOT running (Menu > Start Steam)';
  Invalidate;
end;

{ --- Steam --- }

procedure TfrmPad.tmStartTimer(Sender: TObject);
begin
  tmStart.Enabled := False;
  StartSteam('Starting Steam (automatic start)');
end;

procedure TfrmPad.StartSteam(const AWhy: string);
begin
  AddLog(AWhy);
  if SteamAPI1.IsRunning then
  begin
    AddLog('Steam is already running');
    Exit;
  end;
  if SteamAPI1.Open then
    AddLog('Open returned True: Steam is running')
  else
    AddLog('Open returned False: Steam did not start');
  UpdateSteamStatus;
end;

procedure TfrmPad.StopSteam(const AWhy: string);
begin
  // before Close: the tests' cleanup needs Steam (OnShutdown is too late)
  if FTest.Running then
    FTest.Finish(AWhy);
  if FPair.Running then
    FPair.Finish(AWhy);
  FStartupDue := False;
  if SteamAPI1.IsRunning then
  begin
    AddLog('Closing Steam: ' + AWhy);
    SteamAPI1.Close;
  end;
  ResetInput;
  UpdateSteamStatus;
end;

procedure TfrmPad.RestartSteam;
begin
  if SteamAPI1.IsRunning then
  begin
    StopSteam('Menu > Restart Steam');
    StartSteam('Menu > Restart Steam: starting Steam again');
  end
  else
    StartSteam('Menu > Start Steam');
end;

procedure TfrmPad.SteamInitialized(Sender: TObject);
begin
  AddLog(Format('OnInitialized: pipe %d, user %d, %d plug-in(s) active',
    [SteamAPI1.Steam.Pipe, SteamAPI1.Steam.User, SteamAPI1.Steam.PluginCount]));
  // TSteamAPI's own check at Open (BigPictureWindow = bpwFullScreen in the
  // form); CheckBigPicture repeats it every second from now on
  FInBigPicture := SteamAPI1.InBigPicture;
  AddLog(Format('Big Picture at start: %s; window full screen: %s', [YesNo(FInBigPicture), YesNo(FullScreen)]));
  StartInput;
  FFriendsRequested := False;   // a new Steam session: ask again
  LoadPersonal;
  LoadAchievements;
  LoadPairRows;
  // Show Info and the component test at the next tmTests tick: not inside
  // Open (the test starts a game server)
  FStartupDue := True;
  tmTests.Enabled := True;
  UpdateSteamStatus;
end;

procedure TfrmPad.SteamInitFailed(Sender: TObject; AResult: Integer; const AMessage: string);
begin
  AddLog(Format('OnInitFailed: result %d (%s): %s',
    [AResult, SteamInitResultToString(ESteamAPIInitResult(AResult)), AMessage]));
  FSteamStatus := Format('Steam did not start (result %d) - Menu > Start Steam', [AResult]);
  Invalidate;
end;

procedure TfrmPad.SteamShutdown(Sender: TObject);
begin
  AddLog('OnShutdown: SteamAPI shut down');
  // only reached with a test running when Steam went away by itself
  if FTest.Running then
    FTest.Finish('Steam shut down while the component test was running (no cleanup possible)');
  if FPair.Running then
    FPair.Finish('Steam shut down while the pair test was running (no cleanup possible)');
  ResetInput;
  UpdateSteamStatus;
end;

procedure TfrmPad.SteamClientExit(Sender: TObject);
begin
  AddLog('OnSteamShutdown: the Steam client is exiting; SteamAPI shuts down next');
end;

procedure TfrmPad.SteamLog(Sender: TObject; ALevel: TSteamLogLevel; const AMessage: string);
begin
  AddLog('[' + LevelNames[ALevel] + '] ' + AMessage);
end;

procedure TfrmPad.SteamWarning(Sender: TObject; ASeverity: Integer; const AText: string);
begin
  AddLog(Format('Steam debug (severity %d): %s', [ASeverity, AText]));
end;

procedure TfrmPad.CheckBigPicture;
var
  U: TSteamUtilsPlugin;
  Now_: Boolean;
begin
  if not SteamAPI1.IsRunning then
    Exit;
  U := SteamAPI1.Steam.Plugin<TSteamUtilsPlugin>;
  if U = nil then
    Exit;
  try
    Now_ := U.IsSteamInBigPictureMode;
  except
    Exit;
  end;
  if Now_ = FInBigPicture then
    Exit;
  FInBigPicture := Now_;
  if Now_ then
  begin
    AddLog(Format('Big Picture: yes (IsSteamInBigPictureMode) - window full screen (was full screen: %s)',
      [YesNo(FullScreen)]));
    FullScreen := True;
  end
  else
    // left as it is: the player may have chosen the window size
    AddLog('Big Picture: no (IsSteamInBigPictureMode) - window left as it is');
end;

procedure TfrmPad.tmTestsTimer(Sender: TObject);
begin
  CheckBigPicture;
  if FStartupDue then
  begin
    FStartupDue := False;
    RunStartupChecks;
  end;
  if FPersonalDirty then
  begin
    FPersonalDirty := False;
    LoadPersonal;
  end;
  if FTest.Running then
    FTest.Tick;
  if FPair.Running then
    FPair.Tick;
end;

procedure TfrmPad.RunStartupChecks;
begin
  if not SteamAPI1.IsRunning then
    Exit;
  AddLog('Start-up: Show Info');
  ShowInfo;
  AddLog('Start-up: component test');
  FTestSummary := 'Component test: running';
  Invalidate;
  FTest.Start;
end;

procedure TfrmPad.ShowInfo;
var
  U: TSteamUtilsPlugin;
  Usr: TSteamUserPlugin;
  Fr: TSteamFriendsPlugin;
  Apps: TSteamAppsPlugin;
  Stats: TSteamUserStatsPlugin;
  RS: TSteamRemoteStoragePlugin;
  Ugc: TSteamUGCPlugin;
  QuotaTotal, QuotaAvailable: UInt64;
  Id: TSteamID;
  V: string;
begin
  AddLog(Format('Library %s: %d interface versions detected',
    [TSteamLib.LibraryPath, SteamAPI1.Steam.Versions.Count]));
  for V in SteamAPI1.Steam.Versions.ToArray do
    AddLog('  ' + V);
  // each block logs its own failure and the next block still runs
  U := SteamAPI1.Steam.Plugin<TSteamUtilsPlugin>;
  if U <> nil then
  try
    AddLog(Format('ISteamUtils: AppID %d, country %s, UI language %s, overlay %s, battery %d (%d = mains), '
      + 'Big Picture %s', [U.GetAppID, U.GetIPCountry, U.GetSteamUILanguage, YesNo(U.IsOverlayEnabled),
      U.GetCurrentBatteryPower, BATTERY_MAINS, YesNo(U.IsSteamInBigPictureMode)]));
    if Assigned(U.Flat.IsRunningOnSteamHardware) then
      AddLog(Format('Steam hardware type: %d, under Proton: %s',
        [Ord(U.IsRunningOnSteamHardware), YesNo(U.IsRunningUnderProton)]));
  except
    on E: Exception do AddLog('ISteamUtils failed: ' + E.Message);
  end;
  Usr := SteamAPI1.Steam.Plugin<TSteamUserPlugin>;
  if Usr <> nil then
  try
    Id := Usr.GetSteamID;
    AddLog(Format('ISteamUser: logged on %s, SteamID %s, Steam level %d',
      [YesNo(Usr.BLoggedOn), Id.ToString, Usr.GetPlayerSteamLevel]));
  except
    on E: Exception do AddLog('ISteamUser failed: ' + E.Message);
  end;
  Fr := SteamAPI1.Steam.Plugin<TSteamFriendsPlugin>;
  if Fr <> nil then
  try
    AddLog(Format('ISteamFriends: persona "%s", immediate friends %d',
      [Fr.GetPersonaName, Fr.GetFriendCount(k_EFriendFlagImmediate)]));
  except
    on E: Exception do AddLog('ISteamFriends failed: ' + E.Message);
  end;
  Apps := SteamAPI1.Steam.Plugin<TSteamAppsPlugin>;
  if Apps <> nil then
  try
    AddLog(Format('ISteamApps: subscribed %s, game language %s, build id %d',
      [YesNo(Apps.BIsSubscribed), Apps.GetCurrentGameLanguage, Apps.GetAppBuildId]));
  except
    on E: Exception do AddLog('ISteamApps failed: ' + E.Message);
  end;
  Stats := SteamAPI1.Steam.Plugin<TSteamUserStatsPlugin>;
  if Stats <> nil then
  try
    AddLog(Format('ISteamUserStats: %d achievements defined', [Stats.GetNumAchievements]));
  except
    on E: Exception do AddLog('ISteamUserStats failed: ' + E.Message);
  end;
  try
    RS := SteamAPI1.Steam.Plugin<TSteamRemoteStoragePlugin>;
    if RS <> nil then
    begin
      QuotaTotal := 0;
      QuotaAvailable := 0;
      RS.GetQuota(QuotaTotal, QuotaAvailable);
      AddLog(Format('ISteamRemoteStorage: cloud for account %s / app %s, %d files, %s of %s bytes free',
        [YesNo(RS.IsCloudEnabledForAccount), YesNo(RS.IsCloudEnabledForApp), RS.GetFileCount,
         UIntToStr(QuotaAvailable), UIntToStr(QuotaTotal)]));
    end;
  except
    on E: Exception do AddLog('ISteamRemoteStorage failed: ' + E.Message);
  end;
  try
    Ugc := SteamAPI1.Steam.Plugin<TSteamUGCPlugin>;
    if Ugc <> nil then
      AddLog(Format('ISteamUGC: %d subscribed items, %d downloaded',
        [Ugc.GetNumSubscribedItems(False), Ugc.GetNumDownloadedItems]));
  except
    on E: Exception do AddLog('ISteamUGC failed: ' + E.Message);
  end;
end;

{ --- the pages --- }

function TfrmPad.FindRow(APage: TPadPage; const AKey: string): TPadRow;
var
  R: TPadRow;
begin
  for R in FRows[APage] do
    if R.Key = AKey then
      Exit(R);
  Result := nil;
end;

procedure TfrmPad.SetRowImage(ARow: TPadRow; AImage: Integer);
begin
  if (ARow = nil) or (AImage <= 0) then
    Exit;
  if ARow.Image = nil then
    ARow.Image := TBitmap.Create;
  if not SteamImageToBitmap(AImage, ARow.Image) then
    FreeAndNil(ARow.Image);
  Invalidate;
end;

procedure TfrmPad.FixSelection(APage: TPadPage);
var
  I: Integer;
begin
  I := FSel[APage];
  if I < 0 then
    I := 0;   // none yet: the first selectable row
  if I >= FRows[APage].Count then
    I := FRows[APage].Count - 1;
  // the nearest selectable row, downwards first
  while (I >= 0) and (I < FRows[APage].Count) and (FRows[APage][I].Kind = rkHeader) do
    Inc(I);
  if I >= FRows[APage].Count then
  begin
    I := FRows[APage].Count - 1;
    while (I >= 0) and (FRows[APage][I].Kind = rkHeader) do
      Dec(I);
  end;
  FSel[APage] := I;
  Invalidate;
end;

procedure TfrmPad.LoadPersonal;
var
  Usr: TSteamUserPlugin;
  Fr: TSteamFriendsPlugin;
  U: TSteamUtilsPlugin;
  Me, Friend: TSteamID;
  I, Count, H: Integer;
  Nick: string;
  L: TObjectList<TPadRow>;

  function Add(AKind: TRowKind; const ATitle, ADetail: string; const AKey: string = ''): TPadRow;
  begin
    Result := TPadRow.Create;
    Result.Kind := AKind;
    Result.Title := ATitle;
    Result.Detail := ADetail;
    Result.Key := AKey;
    L.Add(Result);
  end;

begin
  L := FRows[ppPersonal];
  L.Clear;
  Usr := SteamAPI1.Steam.Plugin<TSteamUserPlugin>;
  Fr := SteamFriends1.Plugin;
  U := SteamAPI1.Steam.Plugin<TSteamUtilsPlugin>;
  if (Usr = nil) or (Fr = nil) then
  begin
    Add(rkHeader, 'Steam is not running', '');
    FixSelection(ppPersonal);
    Exit;
  end;
  try
    Me := Usr.GetSteamID;
    Add(rkHeader, 'You', '');
    SetRowImage(Add(rkInfo, Fr.GetPersonaName, PersonaStateText(Fr.GetPersonaState), Me.ToString),
      Fr.GetLargeFriendAvatar(Me));
    Add(rkInfo, 'SteamID', Format('%s  [U:1:%d]', [Me.ToString, Me.AccountID]));
    Add(rkInfo, 'Steam level', IntToStr(Usr.GetPlayerSteamLevel));
    if U <> nil then
    begin
      Add(rkInfo, 'Country (by IP)', U.GetIPCountry);
      Add(rkInfo, 'Steam UI language', U.GetSteamUILanguage);
    end;
    Count := Fr.GetFriendCount(k_EFriendFlagImmediate);
    Add(rkHeader, Format('Friends (%d)', [Count]), '');
    for I := 0 to Count - 1 do
    begin
      Friend := Fr.GetFriendByIndex(I, k_EFriendFlagImmediate);
      // name / avatar on their way: PersonaStateChange_t, AvatarImageLoaded_t
      // (asked once per Steam start: every answer rebuilds this page)
      if not FFriendsRequested then
        Fr.RequestUserInformation(Friend, False);
      Nick := Fr.GetPlayerNickname(Friend);
      H := Fr.GetMediumFriendAvatar(Friend);
      SetRowImage(Add(rkFriend, Fr.GetFriendPersonaName(Friend) + IfThen(Nick <> '', ' (' + Nick + ')', ''),
        Format('%s, level %d', [PersonaStateText(Fr.GetFriendPersonaState(Friend)),
        Fr.GetFriendSteamLevel(Friend)]), Friend.ToString), H);
    end;
    if not FFriendsRequested then
      AddLog(Format('Personal page: %s, %d friend(s); name / avatar asked for each', [Fr.GetPersonaName, Count]));
    FFriendsRequested := True;
  except
    on E: Exception do AddLog('Personal page failed: ' + E.Message);
  end;
  FixSelection(ppPersonal);
end;

procedure TfrmPad.LoadAchievements;
var
  S: TSteamUserStatsPlugin;
  I: Integer;
  N, UnlockTime: UInt32;
  AchName, Desc, State: string;
  Achieved: Boolean;
  R: TPadRow;
  L: TObjectList<TPadRow>;
begin
  L := FRows[ppAchievements];
  L.Clear;
  S := SteamUserStats1.Plugin;
  if S = nil then
  begin
    R := TPadRow.Create;
    R.Kind := rkHeader;
    R.Title := 'Steam is not running';
    L.Add(R);
    FixSelection(ppAchievements);
    Exit;
  end;
  try
    N := S.GetNumAchievements;
    R := TPadRow.Create;
    R.Kind := rkHeader;
    R.Title := Format('%d achievements - A: unlock / clear (asks first)', [N]);
    L.Add(R);
    for I := 0 to Integer(N) - 1 do
    begin
      AchName := S.GetAchievementName(UInt32(I));
      Achieved := False;
      UnlockTime := 0;
      S.GetAchievementAndUnlockTime(AchName, Achieved, UnlockTime);
      Desc := S.GetAchievementDisplayAttribute(AchName, 'desc');
      if Achieved then
        State := 'unlocked ' + FormatDateTime('yyyy-mm-dd hh:nn', SteamTimeToLocal(UnlockTime))
      else
        State := 'locked';
      if (not Achieved) and (S.GetAchievementDisplayAttribute(AchName, 'hidden') = '1') then
        Desc := 'Hidden achievement';
      R := TPadRow.Create;
      R.Kind := rkAchievement;
      R.Title := S.GetAchievementDisplayAttribute(AchName, 'name');
      R.Detail := Desc + ' - ' + State;
      R.Key := AchName;
      R.Achieved := Achieved;
      if Achieved then
        R.Mark := COL_PASS;
      L.Add(R);
      // 0: Steam fetches it, then callback 1109 (AchievementIconFetched)
      SetRowImage(R, S.GetAchievementIcon(AchName));
    end;
  except
    on E: Exception do AddLog('Achievements page failed: ' + E.Message);
  end;
  FixSelection(ppAchievements);
end;

procedure TfrmPad.LoadPairRows;
var
  L: TObjectList<TPadRow>;
  R: TPadRow;
  I: Integer;
begin
  L := FRows[ppTwoUsers];
  L.Clear;
  R := TPadRow.Create;
  R.Kind := rkPairStart;
  R.Title := 'Pair test';
  if not SteamAPI1.IsRunning then
    R.Detail := 'Steam is not running'
  else if FPair.Running then
    R.Detail := 'running - the other copy: a SteamDemo''s Pair, or SteamConsole --pair'
  else
    R.Detail := 'A: start - then Pair on the second PC (another Steam account)';
  L.Add(R);
  for I := 0 to PT_COUNT - 1 do
  begin
    R := TPadRow.Create;
    R.Kind := rkPairRow;
    R.Title := PairTestNames[I];
    R.Detail := FPair.RowText[I];
    if R.Detail = '' then
      R.Detail := 'not run';
    R.Mark := VerdictColor(FPair.RowText[I]);
    L.Add(R);
  end;
  FixSelection(ppTwoUsers);
end;

procedure TfrmPad.FriendPersonaChanged(Sender: TObject; const AData: PersonaStateChange_t);
begin
  // many arrive at once (one per friend): rebuilt once, at the next second
  FPersonalDirty := True;
end;

procedure TfrmPad.FriendAvatarLoaded(Sender: TObject; const AData: AvatarImageLoaded_t);
begin
  AddLog(Format('TSteamFriends.OnAvatarImageLoaded: SteamID %s, image %d, %dx%d',
    [AData.m_steamID.ToString, AData.m_iImage, AData.m_iWide, AData.m_iTall]));
  SetRowImage(FindRow(ppPersonal, AData.m_steamID.ToString), AData.m_iImage);
end;

procedure TfrmPad.StatsReceived(Sender: TObject; const AData: UserStatsReceived_t);
begin
  AddLog(Format('TSteamUserStats.OnUserStatsReceived: SteamID %s, result %d',
    [AData.m_steamIDUser.ToString, Ord(AData.m_eResult)]));
  if AData.m_eResult = k_EResultOK then
    LoadAchievements;
end;

procedure TfrmPad.StatsStored(Sender: TObject; const AData: UserStatsStored_t);
begin
  AddLog(Format('TSteamUserStats.OnUserStatsStored: result %d (%d = OK)', [Ord(AData.m_eResult), Ord(k_EResultOK)]));
  LoadAchievements;
end;

procedure TfrmPad.AchievementIconFetched(Sender: TObject; const AData: UserAchievementIconFetched_t);
var
  AchName: string;
begin
  AchName := string(UTF8String(PAnsiChar(@AData.m_rgchAchievementName[0])));
  AddLog(Format('TSteamUserStats.OnUserAchievementIconFetched: %s, icon %d', [AchName, AData.m_nIconHandle]));
  SetRowImage(FindRow(ppAchievements, AchName), AData.m_nIconHandle);
end;

procedure TfrmPad.SetAchievement(const AName: string; AUnlock: Boolean);
var
  S: TSteamUserStatsPlugin;
  Done, Stored: Boolean;
begin
  S := SteamUserStats1.Plugin;
  if S = nil then
  begin
    AddLog('Achievement ' + AName + ': Steam is not running');
    Exit;
  end;
  try
    if AUnlock then
      Done := S.SetAchievement(AName)
    else
      Done := S.ClearAchievement(AName);
    Stored := S.StoreStats;
    AddLog(Format('Achievement %s: %s -> %s, StoreStats -> %s (then OnUserStatsStored)',
      [AName, IfThen(AUnlock, 'SetAchievement', 'ClearAchievement'), YesNo(Done), YesNo(Stored)]));
  except
    on E: Exception do AddLog('Achievement ' + AName + ' FAILED: ' + E.Message);
  end;
  LoadAchievements;
end;

{ --- the tests --- }

procedure TfrmPad.TestRow(AIndex: Integer; const AText: string);
var
  I, Pass, Fail, Done: Integer;
  T: string;
begin
  Pass := 0;
  Fail := 0;
  for I := 0 to CT_COUNT - 1 do
  begin
    T := FTest.RowText[I];
    if StartsStr('PASS', T) then
      Inc(Pass)
    else if StartsStr('FAIL', T) then
      Inc(Fail);
  end;
  Done := Pass + Fail;
  if FTest.Running then
    FTestSummary := Format('Component test: running, %d / %d done, %d FAIL', [Done, CT_COUNT, Fail])
  else
    FTestSummary := Format('Component test: %d / %d PASS', [Pass, CT_COUNT]);
  Invalidate;
end;

procedure TfrmPad.TestFinished(Sender: TObject);
begin
  TestRow(0, '');
  AddLog(FTestSummary);
end;

procedure TfrmPad.TestScreenshotRequested(Sender: TObject);
begin
  // only while screenshots are hooked (the test unhooks them at once)
  TakeScreenshot;
end;

procedure TfrmPad.PairRow(AIndex: Integer; const AText: string);
begin
  LoadPairRows;
end;

procedure TfrmPad.PairFinished(Sender: TObject);
begin
  LoadPairRows;
end;

procedure TfrmPad.TakeScreenshot;
var
  S: TSteamScreenshotsPlugin;
  RGB: TBytes;
  W, H: Integer;
  Shot: ScreenshotHandle;
begin
  // the component test's TSteamScreenshots: its OnScreenshotReady tags the picture
  S := FTest.Screenshots;
  if (S = nil) or not SteamAPI1.IsRunning then
  begin
    AddLog('Screenshot: Steam is not running');
    Exit;
  end;
  try
    RGB := SteamFormToRGB(Self, W, H);
    if RGB = nil then
    begin
      AddLog('Screenshot: SteamFormToRGB returned nothing - window not captured');
      Exit;
    end;
    Shot := S.WriteScreenshot(@RGB[0], Length(RGB), W, H);
    AddLog(Format('Screenshot: window %dx%d (%d bytes RGB), WriteScreenshot -> handle %d (%d = failed); '
      + 'then OnScreenshotReady (callback %d)', [W, H, Length(RGB), Shot, INVALID_SCREENSHOT, ScreenshotReady_t_k_iCallback]));
  except
    on E: Exception do AddLog('Screenshot FAILED: ' + E.Message);
  end;
end;

{ --- Steam Input --- }

function TfrmPad.Input: TSteamInputPlugin;
begin
  Result := SteamInput1.Plugin;
  if (Result <> nil) and not Result.Started then
    Result := nil;
end;

function TfrmPad.ManifestPath: string;
var
  P: string;
begin
  // the data folder (post-build copy / deployment) ...
  P := DataFolder + MANIFEST_FILE;
  if not TFile.Exists(P) then
    // ... or the project's src folder when run from .\<platform>\<config>
    P := ExpandFileName(ExtractFilePath(ExpandFileName(ParamStr(0))) + '..' + PathDelim + '..'
      + PathDelim + 'src' + PathDelim + MANIFEST_FILE);
  if TFile.Exists(P) then
    Result := P
  else
    Result := '';
end;

procedure TfrmPad.ResetInput;
var
  B: TPadButton;
begin
  FSetHandle := 0;
  FScrollAction := 0;
  for B := Low(TPadButton) to High(TPadButton) do
  begin
    FActions[B] := 0;
    FHeld[B] := False;
    FRepeatAt[B] := 0;
    FGlyphs[B] := DefaultGlyphs[B];
  end;
  FreeGlyphIcons;
  FScrollName := 'Right stick';
  FResolved := False;
  FResolveWarned := False;
  FLastResolve := 0;
  FPads := nil;
  FGlyphPad := 0;
  FActivePad := 0;
  FChosenPad := 0;
  FMenuPads := nil;
  FMenuPadIndex := 0;
  // the plug-in is gone (or new): a rumble cannot be stopped any more
  tmRumble.Enabled := False;
  FRumblePad := 0;
end;

procedure TfrmPad.StartInput;
var
  P: TSteamInputPlugin;
  Path: string;
begin
  ResetInput;
  P := SteamInput1.Plugin;
  if P = nil then
  begin
    AddLog('ISteamInput plug-in is not active: keyboard / mouse / touch only');
    Exit;
  end;
  try
    // explicit RunFrame: tmPoll calls it right before reading the actions
    if not P.Start(True) then
    begin
      AddLog('ISteamInput Init returned False: keyboard / mouse / touch only');
      Exit;
    end;
    P.EnableDeviceCallbacks;
    Path := ManifestPath;
    if Path = '' then
      AddLog('Action manifest ' + MANIFEST_FILE + ' NOT FOUND: the pad stays unbound (keyboard / mouse / touch work)')
    else
      AddLog(Format('ISteamInput started; SetInputActionManifestFilePath(%s): %s',
        [Path, YesNo(P.SetInputActionManifestFilePath(Path))]));
  except
    on E: Exception do AddLog('Starting ISteamInput failed: ' + E.ClassName + ': ' + E.Message);
  end;
end;

procedure TfrmPad.InputConfigurationLoaded(Sender: TObject; const AData: SteamInputConfigurationLoaded_t);
begin
  AddLog(Format('Steam Input layout loaded: app %d, pad %s, revision %d.%d, uses the Steam Input API %s',
    [AData.m_unAppID, UIntToStr(AData.m_ulDeviceHandle), AData.m_unMajorRevision, AData.m_unMinorRevision,
     YesNo(AData.m_bUsesSteamInputAPI)]));
  // names of the buttons again for this pad (another layout, other origins)
  FGlyphPad := 0;
end;

procedure TfrmPad.ResolveHandles(P: TSteamInputPlugin);
var
  B: TPadButton;
  Missing: string;
begin
  FLastResolve := TestTicks;
  if FSetHandle = 0 then
    FSetHandle := P.GetActionSetHandle(SET_NAME);
  if FScrollAction = 0 then
    FScrollAction := P.GetAnalogActionHandle(SCROLL_ACTION);
  for B := Low(TPadButton) to High(TPadButton) do
    if FActions[B] = 0 then
      FActions[B] := P.GetDigitalActionHandle(ActionNames[B]);
  Missing := '';
  if FSetHandle = 0 then
    Missing := Missing + ' ' + SET_NAME;
  if FScrollAction = 0 then
    Missing := Missing + ' ' + SCROLL_ACTION;
  for B := Low(TPadButton) to High(TPadButton) do
    if FActions[B] = 0 then
      Missing := Missing + ' ' + ActionNames[B];
  FResolved := Missing = '';
  if FResolved then
    AddLog(Format('Steam Input: action set %s and %d actions resolved', [SET_NAME, Ord(High(TPadButton)) + 2]))
  else if not FResolveWarned then
  begin
    AddLog(Format('Steam Input: handles still 0 for:%s - the manifest is not loaded yet (retrying every %d ms)',
      [Missing, RESOLVE_RETRY_MS]));
    FResolveWarned := True;
  end;
end;

procedure TfrmPad.FreeGlyphIcons;
var
  B: TPadButton;
begin
  for B := Low(TPadButton) to High(TPadButton) do
    FreeAndNil(FGlyphIcons[B]);
  FreeAndNil(FScrollIcon);
end;

function TfrmPad.LoadGlyph(P: TSteamInputPlugin; AOrigin: EInputActionOrigin; out ABitmap: TBitmap): string;
const
  { The UI is dark: knockout (white, no background) first, then dark (white
    on black), then the small sizes, then light (SteamInputDemo's light
    background needs the opposite order). }
  Styles: array[0..3] of ESteamInputGlyphStyle = (ESteamInputGlyphStyle_Knockout,
    ESteamInputGlyphStyle_Dark, ESteamInputGlyphStyle_Knockout, ESteamInputGlyphStyle_Light);
  Sizes: array[0..3] of ESteamInputGlyphSize = (k_ESteamInputGlyphSize_Medium,
    k_ESteamInputGlyphSize_Medium, k_ESteamInputGlyphSize_Small, k_ESteamInputGlyphSize_Medium);
  StyleNames: array[0..3] of string = ('knockout medium', 'dark medium', 'knockout small', 'light medium');
var
  Path, Got: string;
  I: Integer;

  { Loads APath into ABitmap; Got says what was loaded. }
  function TryFile(const APath, AWhat: string): Boolean;
  begin
    Result := False;
    if (APath = '') or not TFile.Exists(APath) then
      Exit;
    try
      ABitmap := TBitmap.CreateFromFile(APath);
      Got := Format('%s (%s, %dx%d)', [ExtractFileName(APath), AWhat, ABitmap.Width, ABitmap.Height]);
      Result := True;
    except
      FreeAndNil(ABitmap);
    end;
  end;

begin
  ABitmap := nil;
  Got := 'no picture (the name is shown)';
  for I := Low(Styles) to High(Styles) do
  begin
    Path := P.GetGlyphPNGForActionOrigin(AOrigin, Sizes[I], UInt32(Styles[I]));
    if TryFile(Path, StyleNames[I]) then
      Break;
  end;
  // last resort: the legacy call (Steam had no PNG for some origins)
  if ABitmap = nil then
    TryFile(P.GetGlyphForActionOrigin_Legacy(AOrigin), 'legacy');
  Result := Got;
end;

procedure TfrmPad.ReadGlyphs(P: TSteamInputPlugin; APad: InputHandle_t);
var
  B: TPadButton;
  Origins: TSteamInputOriginArray;
  Names, Name, Pics: string;
  I, Best: Integer;
begin
  FGlyphPad := APad;
  FreeGlyphIcons;
  Names := '';
  Pics := '';
  for B := Low(TPadButton) to High(TPadButton) do
  begin
    FGlyphs[B] := DefaultGlyphs[B];
    Origins := P.DigitalActionOrigins(APad, FSetHandle, FActions[B]);
    // an action bound twice (Up: d-pad and left stick) shows its SHORTEST
    // origin - "D-Pad Up" rather than "Left Stick Move Up" (owner's screen,
    // 2026-11-04) - and that origin's picture
    Best := -1;
    for I := 0 to High(Origins) do
    begin
      Name := P.GetStringForActionOrigin(Origins[I]);
      if (Best < 0) or ((Name <> '') and (Length(Name) < Length(FGlyphs[B]))) then
      begin
        Best := I;
        FGlyphs[B] := Name;
      end;
    end;
    if Best >= 0 then
      Pics := Pics + Format(' %s=%s', [ActionNames[B], LoadGlyph(P, Origins[Best], FGlyphIcons[B])]);
    Names := Names + Format(' %s=%s', [ActionNames[B], FGlyphs[B]]);
  end;
  FScrollName := 'Right stick';
  Origins := P.AnalogActionOrigins(APad, FSetHandle, FScrollAction);
  if Length(Origins) > 0 then
  begin
    FScrollName := P.GetStringForActionOrigin(Origins[0]);
    Pics := Pics + Format(' %s=%s', [SCROLL_ACTION, LoadGlyph(P, Origins[0], FScrollIcon)]);
  end;
  AddLog('Steam Input: buttons on this pad:' + Names + Format(' %s=%s', [SCROLL_ACTION, FScrollName]));
  AddLog('Steam Input: button pictures:' + Pics);
  Invalidate;
end;

procedure TfrmPad.ReadPads(P: TSteamInputPlugin);
var
  B: TPadButton;
  Now_, Dt: UInt64;
  Pad: InputHandle_t;
  Down: array[TPadButton] of Boolean;
  D: InputDigitalActionData_t;
  A: InputAnalogActionData_t;
  ScrollY: Single;
begin
  Now_ := TestTicks;
  Dt := TicksSince(Now_, FLastPoll);
  FLastPoll := Now_;
  FPads := P.ConnectedControllers;
  // a pad connected / disconnected or another one picked up: the line under
  // the page row changes (the program repaints only on change)
  if DeviceText <> FDeviceText then
  begin
    FDeviceText := DeviceText;
    Invalidate;
  end;
  if not FResolved then
  begin
    if TicksSince(Now_, FLastResolve) >= RESOLVE_RETRY_MS then
      ResolveHandles(P);
    if not FResolved then
      Exit;
  end;
  // the button names of THE pad (chosen, else the one that pressed last)
  if (TargetPad <> 0) and (FGlyphPad <> TargetPad) then
    ReadGlyphs(P, TargetPad);
  for B := Low(TPadButton) to High(TPadButton) do
    Down[B] := False;
  ScrollY := 0;
  // every connected pad drives the program (whichever is picked up)
  for Pad in FPads do
  begin
    P.ActivateActionSet(Pad, FSetHandle);
    for B := Low(TPadButton) to High(TPadButton) do
    begin
      D := P.GetDigitalActionData(Pad, FActions[B]);
      if D.bState then
      begin
        Down[B] := True;
        if not FHeld[B] then
          FActivePad := Pad;   // a new press: this pad is in the player's hands
      end;
    end;
    A := P.GetAnalogActionData(Pad, FScrollAction);
    if Abs(A.y) > Abs(ScrollY) then
      ScrollY := A.y;
  end;
  for B := Low(TPadButton) to High(TPadButton) do
  begin
    // FHeld first: a press below may restart Steam (ResetInput clears it)
    if Down[B] and not FHeld[B] then
    begin
      FHeld[B] := True;
      if FOverlay = okMenu then
        FRepeatAt[B] := Now_ + MENU_REPEAT_MS
      else
        FRepeatAt[B] := Now_ + REPEAT_DELAY_MS;
      PressButton(B);
    end
    // held: lists and pages repeat every direction, the menu only Up /
    // Down (Left / Right there switch pads - one step a press), the
    // OK / Cancel confirmation nothing
    else if Down[B] and (Now_ >= FRepeatAt[B])
      and (((FOverlay = okNone) and (B in [pbUp, pbDown, pbLeft, pbRight]))
        or ((FOverlay = okMenu) and (B in [pbUp, pbDown]))) then
    begin
      if FOverlay = okMenu then
        FRepeatAt[B] := Now_ + MENU_REPEAT_MS
      else
        FRepeatAt[B] := Now_ + REPEAT_MS;
      PressButton(B);
    end
    else
      FHeld[B] := Down[B];
    // Restart Steam or Exit from the menu: P is gone (or a new plug-in
    // runs) - nothing more may be read from it in this frame
    if (not FResolved) or (Input <> P) then
      Exit;
  end;
  // right stick up (y > 0) scrolls towards the top
  if (FOverlay = okNone) and (Abs(ScrollY) > STICK_DEAD) then
    ScrollBy(-ScrollY * SCROLL_SPEED * Dt / 1000);
end;

function TfrmPad.TargetPad: InputHandle_t;
var
  Pad: InputHandle_t;
begin
  Result := 0;
  // the pad chosen in the menu, while it is connected ...
  for Pad in FPads do
    if Pad = FChosenPad then
      Exit(Pad);
  // ... else the one that pressed last, else the first
  for Pad in FPads do
    if Pad = FActivePad then
      Exit(Pad);
  if Length(FPads) > 0 then
    Result := FPads[0];
end;

procedure TfrmPad.ShowControllerSettings;
var
  P: TSteamInputPlugin;
  Pad: InputHandle_t;
begin
  P := Input;
  Pad := TargetPad;
  if (P = nil) or (Pad = 0) then
  begin
    AddLog('Controller Settings: no controller (Steam not running or no pad connected)');
    Exit;
  end;
  try
    if P.ShowBindingPanel(Pad) then
      AddLog(Format('Controller Settings: ShowBindingPanel(%s) True - the Steam overlay shows the layout '
        + 'screen; a changed layout arrives as OnSteamInputConfigurationLoaded', [UIntToStr(Pad)]))
    else
      AddLog(Format('Controller Settings: ShowBindingPanel(%s) False (no Steam overlay in this process) - '
        + 'choose the layout in the Steam client: this game > Controller settings', [UIntToStr(Pad)]));
  except
    on E: Exception do AddLog('Controller Settings failed: ' + E.Message);
  end;
end;

procedure TfrmPad.Rumble;
var
  P: TSteamInputPlugin;
  Pad: InputHandle_t;
begin
  P := Input;
  Pad := TargetPad;
  if (P = nil) or (Pad = 0) then
  begin
    AddLog('Rumble: no controller (Steam not running or no pad connected)');
    Exit;
  end;
  try
    P.TriggerVibration(Pad, RUMBLE_SPEED, RUMBLE_SPEED);
    FRumblePad := Pad;
    tmRumble.Enabled := False;   // restart the time on a second press
    tmRumble.Enabled := True;
    AddLog(Format('Rumble: TriggerVibration(%d, %d) for %d ms on pad %s', [RUMBLE_SPEED, RUMBLE_SPEED,
      tmRumble.Interval, UIntToStr(Pad)]));
  except
    on E: Exception do AddLog('Rumble: TriggerVibration failed: ' + E.Message);
  end;
end;

procedure TfrmPad.tmRumbleTimer(Sender: TObject);
var
  P: TSteamInputPlugin;
begin
  tmRumble.Enabled := False;
  P := Input;
  if (P = nil) or (FRumblePad = 0) then
    Exit;
  try
    P.TriggerVibration(FRumblePad, RUMBLE_OFF, RUMBLE_OFF);
    AddLog(Format('Rumble stopped: TriggerVibration(%d, %d)', [RUMBLE_OFF, RUMBLE_OFF]));
  except
    on E: Exception do AddLog('Rumble: TriggerVibration failed: ' + E.Message);
  end;
  FRumblePad := 0;
end;

procedure TfrmPad.tmPollTimer(Sender: TObject);
var
  P: TSteamInputPlugin;
begin
  if FPolling then
    Exit;
  FPolling := True;
  try
    try
      if (FShotDue <> 0) and (TestTicks >= FShotDue) then
      begin
        FShotDue := 0;
        TakeScreenshot;
      end;
      P := Input;
      if P <> nil then
      begin
        P.RunFrame(False);   // explicit RunFrame (Start(True))
        ReadPads(P);
      end
      else
        FLastPoll := TestTicks;
    except
      on E: Exception do
      begin
        // the pad is not read again until Steam restarts (ResetInput);
        // the timer keeps running for keyboard / mouse repaints
        FResolved := False;
        FLastResolve := High(UInt64) div 2;   // no retry
        AddLog('Pad poll FAILED, the pad is no longer read (Menu > Restart Steam): ' + E.ClassName + ': ' + E.Message);
      end;
    end;
    if FDirty then
    begin
      FDirty := False;
      pbView.Repaint;
    end;
  finally
    FPolling := False;
  end;
end;

{ --- navigation --- }

procedure TfrmPad.PressButton(B: TPadButton);
begin
  case FOverlay of
    okConfirm:
      case B of
        pbLeft: FConfirmOK := True;     // OK is the left button
        pbRight: FConfirmOK := False;   // Cancel the right one
        pbUp, pbDown: FConfirmOK := not FConfirmOK;
        pbSelect: AnswerConfirm(FConfirmOK);
        pbBack, pbMenu: AnswerConfirm(False);
      end;
    okMenu:
      case B of
        pbUp: MoveMenu(-1);
        pbDown: MoveMenu(1);
        pbLeft: if FMenuSel = meController then CyclePad(-1);
        pbRight: if FMenuSel = meController then CyclePad(1);
        pbSelect: ChooseMenu;
        pbBack, pbMenu: CloseOverlay;
      end;
  else
    case B of
      pbUp: MoveSelection(-1);
      pbDown: MoveSelection(1);
      pbSelect: ActivateRow;
      pbPagePrev:
        if FPage = Low(TPadPage) then
          ShowPage(High(TPadPage))
        else
          ShowPage(Pred(FPage));
      pbPageNext:
        if FPage = High(TPadPage) then
          ShowPage(Low(TPadPage))
        else
          ShowPage(Succ(FPage));
      pbMenu: OpenMenu;
    end;
  end;
  Invalidate;
end;

procedure TfrmPad.ShowPage(APage: TPadPage);
begin
  FPage := APage;
  FixSelection(APage);
  KeepSelectionVisible;
end;

procedure TfrmPad.MoveSelection(ADelta: Integer);
var
  I: Integer;
  L: TObjectList<TPadRow>;
begin
  L := FRows[FPage];
  I := FSel[FPage];
  repeat
    Inc(I, ADelta);
    if (I < 0) or (I >= L.Count) then
      Exit;   // at the end: stay
  until L[I].Kind <> rkHeader;
  FSel[FPage] := I;
  KeepSelectionVisible;
end;

procedure TfrmPad.KeepSelectionVisible;
var
  Top, Bottom: Single;
begin
  if FSel[FPage] < 0 then
    Exit;
  Top := FSel[FPage] * ROW_H;
  Bottom := Top + ROW_H;
  // the header above the first row in view too, when there is one
  if (FSel[FPage] > 0) and (FRows[FPage][FSel[FPage] - 1].Kind = rkHeader) then
    Top := Top - ROW_H;
  if Top < FScroll[FPage] then
    FScroll[FPage] := Top
  else if Bottom > FScroll[FPage] + FListH then
    FScroll[FPage] := Bottom - FListH;
  ScrollBy(0);   // clamps
end;

procedure TfrmPad.ScrollBy(ADelta: Single);
begin
  FScroll[FPage] := FScroll[FPage] + ADelta;
  ClampScroll(FPage);
  Invalidate;
end;

procedure TfrmPad.ClampScroll(APage: TPadPage);
begin
  FScroll[APage] := EnsureRange(FScroll[APage], 0, Max(0, FRows[APage].Count * ROW_H - FListH));
end;

procedure TfrmPad.ActivateRow;
var
  R: TPadRow;
begin
  if (FSel[FPage] < 0) or (FSel[FPage] >= FRows[FPage].Count) then
    Exit;
  R := FRows[FPage][FSel[FPage]];
  case R.Kind of
    rkAchievement:
      begin
        FConfirmKey := R.Key;
        FConfirmUnlock := not R.Achieved;
        if FConfirmUnlock then
          FConfirmText := Format('Unlock the achievement "%s"?', [R.Title])
        else
          FConfirmText := Format('Clear the achievement "%s"? It becomes locked again.', [R.Title]);
        FConfirmOK := False;   // Cancel first: A twice must not change anything by accident
        FOverlay := okConfirm;
        AddLog('Confirmation: ' + FConfirmText);
      end;
    rkPairStart:
      if not SteamAPI1.IsRunning then
        AddLog('Pair test: Steam is not running')
      else if FPair.Running then
        AddLog('Pair test: already running')
      else
      begin
        AddLog('Pair test: started from the Two Users page');
        FPair.Start;
        LoadPairRows;
      end;
  else
    AddLog(Format('Row "%s": %s', [R.Title, R.Detail]));
  end;
end;

procedure TfrmPad.AnswerConfirm(AOK: Boolean);
begin
  FOverlay := okNone;
  if AOK then
  begin
    AddLog('Confirmation: OK');
    SetAchievement(FConfirmKey, FConfirmUnlock);
  end
  else
    AddLog('Confirmation: Cancel');
  Invalidate;
end;

procedure TfrmPad.OpenMenu;
var
  I: Integer;
begin
  // the controller row: every connected pad, starting at THE pad
  FMenuPads := Copy(FPads);
  FMenuPadIndex := 0;
  for I := 0 to High(FMenuPads) do
    if FMenuPads[I] = TargetPad then
      FMenuPadIndex := I;
  FOverlay := okMenu;
  FMenuSel := Low(TMenuEntry);
  if not MenuEntryVisible(FMenuSel) then
    MoveMenu(1);
  AddLog(Format('Menu opened (%d controller(s) connected)', [Length(FMenuPads)]));
  Invalidate;
end;

function TfrmPad.MenuEntryVisible(E: TMenuEntry): Boolean;
begin
  if E = meController then
    Result := Length(FMenuPads) > 1
  else
    Result := True;
end;

procedure TfrmPad.MoveMenu(ADelta: Integer);
var
  I, N, Steps: Integer;
begin
  N := Ord(High(TMenuEntry)) - Ord(Low(TMenuEntry)) + 1;
  I := Ord(FMenuSel);
  Steps := 0;
  // wraps round: Up on the first entry goes to the last, Down on the last
  // to the first; invisible entries (the controller row with one pad) are
  // stepped over
  repeat
    I := Ord(Low(TMenuEntry)) + ((I - Ord(Low(TMenuEntry)) + ADelta) mod N + N) mod N;
    Inc(Steps);
    if Steps > N then
      Exit;   // nothing visible (cannot happen: Exit always is)
  until MenuEntryVisible(TMenuEntry(I));
  FMenuSel := TMenuEntry(I);
end;

function TfrmPad.PadRowText: string;
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
  // left / right arrows (U+25C0 / U+25B6) round the pad's name
  Result := #$25C0 + '   ' + Name + Format('  (%d of %d)', [FMenuPadIndex + 1, Length(FMenuPads)])
    + IfThen(H = TargetPad, ' - in use', '') + '   ' + #$25B6;
end;

procedure TfrmPad.CyclePad(ADelta: Integer);
var
  N: Integer;
begin
  N := Length(FMenuPads);
  if N < 2 then
    Exit;
  // wraps round however many pads there are
  FMenuPadIndex := ((FMenuPadIndex + ADelta) mod N + N) mod N;
  AddLog('Menu: the controller row now names ' + PadRowText);
  Invalidate;
end;

procedure TfrmPad.CloseOverlay;
begin
  FOverlay := okNone;
  Invalidate;
end;

function TfrmPad.MenuEntryEnabled(E: TMenuEntry): Boolean;
begin
  case E of
    meControllerSettings, meRumble: Result := (Input <> nil) and (Length(FPads) > 0);
    meScreenshot: Result := SteamAPI1.IsRunning;
    // looking for / connecting to a receiver: nothing to click until it
    // is accepted (Stop) or has failed (Start again)
    meRemoteLog: Result := not FRemote.Busy;
  else
    Result := True;
  end;
end;

function TfrmPad.MenuEntryText(E: TMenuEntry): string;
begin
  case E of
    meController: Result := PadRowText;
    meControllerSettings: Result := 'Controller Settings';
    meRumble: Result := 'Rumble';
    meRemoteLog:
      // Stop only once the receiver has ACCEPTED (owner 2026-11-04)
      case FRemote.State of
        drsSearching: Result := 'Looking for Remote...';
        drsConnecting: Result := 'Connecting...';
        drsSending: Result := 'Stop Sending to Remote';
      else
        Result := 'Start Sending to Remote';
      end;
    meScreenshot: Result := 'Take Screenshot';
    meRestart:
      if SteamAPI1.IsRunning then
        Result := 'Restart Steam'
      else
        Result := 'Start Steam';
  else
    Result := 'Exit';
  end;
end;

procedure TfrmPad.ChooseMenu;
var
  E: TMenuEntry;
begin
  E := FMenuSel;
  if not MenuEntryVisible(E) then
    Exit;
  if not MenuEntryEnabled(E) then
  begin
    if E = meRemoteLog then
      AddLog('Menu > ' + MenuEntryText(E) + ': wait - the receiver has not answered yet')
    else
      AddLog('Menu > ' + MenuEntryText(E) + ': not available now (no controller, or Steam not running)');
    Exit;
  end;
  AddLog('Menu > ' + MenuEntryText(E));
  // A on the controller row: that pad becomes THE pad (before CloseOverlay)
  if (E = meController) and (FMenuPadIndex <= High(FMenuPads)) then
  begin
    FChosenPad := FMenuPads[FMenuPadIndex];
    FGlyphPad := 0;   // its button names on the hint line
    AddLog(Format('Menu: controller %s (handle %s) is now the pad for Controller Settings, Rumble and '
      + 'the button names', [PadRowText, UIntToStr(FChosenPad)]));
  end;
  CloseOverlay;
  case E of
    meController: ;   // done above
    meControllerSettings: ShowControllerSettings;
    meRumble: Rumble;
    meRemoteLog: FRemote.Toggle(FLog);
    meScreenshot:
      // after the menu has gone from the window
      FShotDue := TestTicks + SHOT_DELAY_MS;
    meRestart: RestartSteam;
    meExit: Close;
  end;
end;

{ --- keyboard, mouse, touch --- }

procedure TfrmPad.FormKeyDown(Sender: TObject; var Key: Word; var KeyChar: WideChar; Shift: TShiftState);
var
  B: TPadButton;
  Known: Boolean;
begin
  Known := True;
  B := pbSelect;
  case Key of
    vkUp: B := pbUp;
    vkDown: B := pbDown;
    vkLeft: B := pbLeft;
    vkRight: B := pbRight;
    vkReturn, vkSpace: B := pbSelect;
    vkEscape, vkBack: B := pbBack;
    vkPrior: B := pbPagePrev;
    vkNext: B := pbPageNext;
    vkTab:
      if ssShift in Shift then
        B := pbPagePrev
      else
        B := pbPageNext;
    vkF10: B := pbMenu;
  else
    case UpCase(KeyChar) of
      'Q': B := pbPagePrev;
      'E': B := pbPageNext;
      'M': B := pbMenu;
    else
      Known := False;
    end;
  end;
  if not Known then
    Exit;
  Key := 0;
  KeyChar := #0;
  PressButton(B);
end;

procedure TfrmPad.pbViewMouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Single);
var
  I: Integer;
  H: THit;
begin
  // right click: the menu (there is no menu button on screen - owner
  // 2026-11-04; the pad's Start, M or F10 open it too)
  if Button = TMouseButton.mbRight then
  begin
    if FOverlay = okNone then
      OpenMenu
    else
      PressButton(pbBack);
    Exit;
  end;
  // topmost first: the hits are recorded in drawing order
  for I := FHits.Count - 1 downto 0 do
  begin
    H := FHits[I];
    if not H.R.Contains(PointF(X, Y)) then
      Continue;
    case H.Kind of
      hkTab: ShowPage(TPadPage(H.Index));
      hkRow:
        if FSel[FPage] = H.Index then
          ActivateRow
        else
        begin
          FSel[FPage] := H.Index;
          KeepSelectionVisible;
        end;
      hkMenuEntry:
        begin
          FMenuSel := TMenuEntry(H.Index);
          ChooseMenu;
        end;
      hkConfirmOK: AnswerConfirm(True);
      hkConfirmCancel: AnswerConfirm(False);
      hkPanel: ;   // inside the panel, but on no button
      hkOutside:
        if FOverlay = okConfirm then
          AnswerConfirm(False)
        else
          CloseOverlay;
    end;
    Invalidate;
    Exit;
  end;
end;

procedure TfrmPad.pbViewMouseWheel(Sender: TObject; Shift: TShiftState; WheelDelta: Integer; var Handled: Boolean);
begin
  if FOverlay = okNone then
    ScrollBy(-WheelDelta / 120 * WHEEL_STEP);
  Handled := True;
end;

{ --- drawing --- }

function TfrmPad.Px(const R: TRectF): TRectF;
begin
  Result := RectF(R.Left * FScale, R.Top * FScale, R.Right * FScale, R.Bottom * FScale);
end;

procedure TfrmPad.Box(C: TCanvas; const R: TRectF; AColor: TAlphaColor; ARadius: Single);
begin
  C.Fill.Kind := TBrushKind.Solid;
  C.Fill.Color := AColor;
  C.FillRect(Px(R), ARadius * FScale, ARadius * FScale, AllCorners, 1);
end;

procedure TfrmPad.Text(C: TCanvas; const R: TRectF; const S: string; ASize: Single; AColor: TAlphaColor;
  AAlign: TTextAlign; ABold, AWrap: Boolean);
var
  P: TRectF;
begin
  P := Px(R);
  FText.BeginUpdate;
  try
    FText.TopLeft := P.TopLeft;
    FText.MaxSize := PointF(P.Width, P.Height);
    FText.Text := S;
    FText.WordWrap := AWrap;
    FText.Trimming := TTextTrimming.Character;
    FText.HorizontalAlign := AAlign;
    FText.VerticalAlign := TTextAlign.Center;
    FText.Font.Size := ASize * FScale;
    if ABold then
      FText.Font.Style := [TFontStyle.fsBold]
    else
      FText.Font.Style := [];
    FText.Color := AColor;
  finally
    FText.EndUpdate;
  end;
  FText.RenderLayout(C);
end;

procedure TfrmPad.AddHit(const R: TRectF; AKind: THitKind; AIndex: Integer);
var
  H: THit;
begin
  H.R := Px(R);
  H.Kind := AKind;
  H.Index := AIndex;
  FHits.Add(H);
end;

procedure TfrmPad.pbViewPaint(Sender: TObject; Canvas: TCanvas);
var
  ListArea: TRectF;
begin
  FHits.Clear;
  // one scale for both directions; a wider window gets a wider virtual screen
  FScale := Min(pbView.Width / VIRTUAL_W, pbView.Height / VIRTUAL_H);
  if FScale <= 0 then
    Exit;
  if FText = nil then
    FText := TTextLayoutManager.TextLayoutByCanvas(TCanvasClass(Canvas.ClassType)).Create;
  FVirtualW := pbView.Width / FScale;
  FVirtualH := pbView.Height / FScale;
  Box(Canvas, RectF(0, 0, FVirtualW, FVirtualH), COL_BACK);
  DrawTabs(Canvas);
  DrawDevice(Canvas);
  ListArea := RectF(MARGIN, TABS_H + DEVICE_H + 4, FVirtualW - MARGIN, FVirtualH - HINT_H - STATUS_H - 8);
  FListH := ListArea.Height;
  DrawList(Canvas, ListArea);
  DrawBars(Canvas);
  case FOverlay of
    okMenu: DrawMenu(Canvas);
    okConfirm: DrawConfirm(Canvas);
  end;
end;

function TfrmPad.KeyWidth(C: TCanvas; AKey: Integer): Single;
var
  Bmp: TBitmap;
  Name: string;
begin
  if AKey = KEY_SCROLL then
  begin
    Bmp := FScrollIcon;
    Name := FScrollName;
  end
  else
  begin
    Bmp := FGlyphIcons[TPadButton(AKey)];
    Name := FGlyphs[TPadButton(AKey)];
  end;
  if (Bmp <> nil) and (Bmp.Height > 0) then
    Result := ICON_H * Bmp.Width / Bmp.Height
  else
  begin
    C.Font.Size := TEXT_DETAIL * FScale;
    C.Font.Style := [];
    Result := C.TextWidth(Name) / FScale + 8;
  end;
end;

function TfrmPad.DrawKey(C: TCanvas; AKey: Integer; AX, AY: Single): Single;
var
  Bmp: TBitmap;
  Name: string;
begin
  if AKey = KEY_SCROLL then
  begin
    Bmp := FScrollIcon;
    Name := FScrollName;
  end
  else
  begin
    Bmp := FGlyphIcons[TPadButton(AKey)];
    Name := FGlyphs[TPadButton(AKey)];
  end;
  Result := KeyWidth(C, AKey);
  if (Bmp <> nil) and (Bmp.Height > 0) then
    C.DrawBitmap(Bmp, RectF(0, 0, Bmp.Width, Bmp.Height), Px(RectF(AX, AY - ICON_H / 2, AX + Result,
      AY + ICON_H / 2)), 1, False)
  else
    Text(C, RectF(AX, AY - ICON_H / 2, AX + Result, AY + ICON_H / 2), Name, TEXT_DETAIL, COL_TEXT,
      TTextAlign.Center, True);
end;

procedure TfrmPad.DrawHint(C: TCanvas; const ARect: TRectF; const AItems: array of THintItem);
const
  KEY_GAP = 6;
  WORD_GAP = 10;
  ITEM_GAP = 40;
var
  I, K: Integer;
  Total, X, Y, W: Single;
begin
  Total := 0;
  for I := 0 to High(AItems) do
  begin
    for K := 0 to High(AItems[I].Keys) do
      Total := Total + KeyWidth(C, AItems[I].Keys[K]) + KEY_GAP;
    C.Font.Size := TEXT_DETAIL * FScale;
    C.Font.Style := [];
    Total := Total + WORD_GAP + C.TextWidth(AItems[I].Text) / FScale + 4;
    if I < High(AItems) then
      Total := Total + ITEM_GAP;
  end;
  X := ARect.Left + Max(0, (ARect.Width - Total) / 2);
  Y := (ARect.Top + ARect.Bottom) / 2;
  for I := 0 to High(AItems) do
  begin
    for K := 0 to High(AItems[I].Keys) do
      X := X + DrawKey(C, AItems[I].Keys[K], X, Y) + KEY_GAP;
    X := X + WORD_GAP;
    C.Font.Size := TEXT_DETAIL * FScale;
    C.Font.Style := [];
    W := C.TextWidth(AItems[I].Text) / FScale + 4;
    Text(C, RectF(X, ARect.Top, X + W, ARect.Bottom), AItems[I].Text, TEXT_DETAIL, COL_DIM_TEXT);
    X := X + W + ITEM_GAP;
  end;
end;

procedure TfrmPad.DrawTabs(C: TCanvas);
const
  TAB_W = 230;
  TAB_GAP = 12;
var
  P: TPadPage;
  X, TotalW: Single;
  R: TRectF;
begin
  // no title and no menu button (owner 2026-11-04: pointless, above all in
  // Big Picture): the page row only, centred, the shoulder buttons' names
  // either side
  Box(C, RectF(0, 0, FVirtualW, TABS_H), COL_BAR);
  TotalW := Ord(High(TPadPage)) * (TAB_W + TAB_GAP) + TAB_W;
  X := (FVirtualW - TotalW) / 2;
  // the shoulder buttons as Steam draws them for this pad (else their names)
  DrawKey(C, Ord(pbPagePrev), X - 16 - KeyWidth(C, Ord(pbPagePrev)), TABS_H / 2);
  for P := Low(TPadPage) to High(TPadPage) do
  begin
    R := RectF(X, 14, X + TAB_W, TABS_H - 14);
    if P = FPage then
      Box(C, R, COL_SELECT, 8)
    else
      Box(C, R, COL_ROW, 8);
    Text(C, R, PageTitles[P], TEXT_ROW, COL_TEXT, TTextAlign.Center, P = FPage);
    AddHit(R, hkTab, Ord(P));
    X := X + TAB_W + TAB_GAP;
  end;
  DrawKey(C, Ord(pbPageNext), X + 4, TABS_H / 2);
end;

function TfrmPad.DeviceText: string;
var
  P: TSteamInputPlugin;
  Pad: InputHandle_t;
begin
  P := Input;
  if P = nil then
    Exit('No controller - Steam is not running (keyboard, mouse or touch)');
  Pad := TargetPad;
  if Pad = 0 then
    Exit('No controller connected (keyboard, mouse or touch)');
  // the pad whose buttons the hint line shows (chosen in the menu, else
  // the one that pressed last)
  Result := 'Controller in use: ' + InputTypeName(P.GetInputTypeForHandle(Pad));
  if Length(FPads) > 1 then
    Result := Result + Format('  (%d connected)', [Length(FPads)]);
end;

procedure TfrmPad.DrawDevice(C: TCanvas);
begin
  // owner 2026-11-04: under the page row, centred, the normal row text size
  Text(C, RectF(MARGIN, TABS_H, FVirtualW - MARGIN, TABS_H + DEVICE_H), DeviceText, TEXT_ROW, COL_TEXT,
    TTextAlign.Center);
end;

procedure TfrmPad.DrawList(C: TCanvas; const AArea: TRectF);
var
  L: TObjectList<TPadRow>;
  Row: TPadRow;
  I, First, Last: Integer;
  Y, TextLeft: Single;
  R, Pic, Clipped: TRectF;
  State: TCanvasSaveState;
  BarH, BarY: Single;
begin
  L := FRows[FPage];
  ClampScroll(FPage);   // after a resize / rebuild (no repaint request while drawing)
  State := C.SaveState;
  try
    C.IntersectClipRect(Px(AArea));
    First := Max(0, Trunc(FScroll[FPage] / ROW_H));
    Last := Min(L.Count - 1, Trunc((FScroll[FPage] + AArea.Height) / ROW_H));
    for I := First to Last do
    begin
      Row := L[I];
      Y := AArea.Top + I * ROW_H - FScroll[FPage];
      R := RectF(AArea.Left, Y + 4, AArea.Right - 16, Y + ROW_H - 4);
      if Row.Kind = rkHeader then
      begin
        Text(C, RectF(R.Left + 8, R.Top, R.Right, R.Bottom), Row.Title, TEXT_ROW, COL_HEADER,
          TTextAlign.Leading, True);
        Continue;
      end;
      if I = FSel[FPage] then
        Box(C, R, COL_SELECT, 8)
      else
        Box(C, R, COL_ROW, 8);
      if Row.Mark <> 0 then
        Box(C, RectF(R.Left, R.Top, R.Left + 6, R.Bottom), Row.Mark, 3);
      TextLeft := R.Left + 20;
      if Row.Image <> nil then
      begin
        Pic := RectF(R.Left + 16, R.Top + (R.Height - PIC_SIZE) / 2, R.Left + 16 + PIC_SIZE, R.Top + (R.Height + PIC_SIZE) / 2);
        C.DrawBitmap(Row.Image, RectF(0, 0, Row.Image.Width, Row.Image.Height), Px(Pic), 1, False);
        TextLeft := Pic.Right + 16;
      end
      else if Row.Kind in [rkFriend, rkAchievement] then
        TextLeft := R.Left + 16 + PIC_SIZE + 16;   // keep the column while the picture loads
      Text(C, RectF(TextLeft, R.Top + 4, R.Right - 16, R.Top + R.Height / 2 + 2), Row.Title, TEXT_ROW,
        COL_TEXT, TTextAlign.Leading, True);
      Text(C, RectF(TextLeft, R.Top + R.Height / 2, R.Right - 16, R.Bottom - 4), Row.Detail, TEXT_DETAIL,
        COL_DIM_TEXT);
      // only the visible part reacts: a row scrolled half under the page
      // row must not take a click meant for a tab
      Clipped := TRectF.Intersect(R, AArea);
      if not Clipped.IsEmpty then
        AddHit(Clipped, hkRow, I);
    end;
  finally
    C.RestoreState(State);
  end;
  // scroll bar when the list is longer than the area
  if L.Count * ROW_H > AArea.Height then
  begin
    BarH := Max(40, AArea.Height * AArea.Height / (L.Count * ROW_H));
    BarY := AArea.Top + (AArea.Height - BarH) * FScroll[FPage] / (L.Count * ROW_H - AArea.Height);
    Box(C, RectF(AArea.Right - 8, AArea.Top, AArea.Right, AArea.Bottom), COL_ROW, 4);
    Box(C, RectF(AArea.Right - 8, BarY, AArea.Right, BarY + BarH), COL_DIM_TEXT, 4);
  end;
end;

procedure TfrmPad.DrawBars(C: TCanvas);
var
  Status: string;
  Y: Single;
  R: TRectF;
begin
  Y := FVirtualH - HINT_H - STATUS_H;
  R := RectF(MARGIN, Y, FVirtualW - MARGIN, Y + HINT_H);
  // Steam's button pictures for this pad (its names where there is none)
  case FOverlay of
    okMenu:
      if FMenuSel = meController then
        DrawHint(C, R, [HintItem([Ord(pbLeft), Ord(pbRight)], 'another controller'),
          HintItem([Ord(pbSelect)], 'use it'), HintItem([Ord(pbUp), Ord(pbDown)], 'move'),
          HintItem([Ord(pbBack)], 'close')])
      else
        DrawHint(C, R, [HintItem([Ord(pbUp), Ord(pbDown)], 'move'), HintItem([Ord(pbSelect)], 'choose'),
          HintItem([Ord(pbBack)], 'close')]);
    okConfirm:
      DrawHint(C, R, [HintItem([Ord(pbLeft), Ord(pbRight)], 'OK or Cancel'), HintItem([Ord(pbSelect)], 'choose'),
        HintItem([Ord(pbBack)], 'cancel')]);
  else
    DrawHint(C, R, [HintItem([Ord(pbUp), Ord(pbDown)], 'move'), HintItem([Ord(pbSelect)], 'select'),
      HintItem([Ord(pbPagePrev), Ord(pbPageNext)], 'page'), HintItem([KEY_SCROLL], 'scroll'),
      HintItem([Ord(pbMenu)], 'menu')]);
  end;
  Box(C, RectF(0, FVirtualH - STATUS_H, FVirtualW, FVirtualH), COL_BAR);
  Status := FSteamStatus + '   |   ' + FTestSummary + '   |   ' + FRemoteStatus;
  Text(C, RectF(MARGIN / 2, FVirtualH - STATUS_H, FVirtualW - MARGIN / 2, FVirtualH), Status, TEXT_SMALL,
    COL_TEXT);
end;

procedure TfrmPad.DrawMenu(C: TCanvas);
var
  Panel, R: TRectF;
  E: TMenuEntry;
  H: Single;
  N: Integer;
begin
  Box(C, RectF(0, 0, FVirtualW, FVirtualH), COL_SHADE);
  AddHit(RectF(0, 0, FVirtualW, FVirtualH), hkOutside, 0);
  N := 0;
  for E := Low(TMenuEntry) to High(TMenuEntry) do
    if MenuEntryVisible(E) then
      Inc(N);
  H := 72 + N * (MENU_ITEM_H + 8) + 16;
  Panel := RectF((FVirtualW - MENU_W) / 2, (FVirtualH - H) / 2, (FVirtualW + MENU_W) / 2, (FVirtualH + H) / 2);
  Box(C, Panel, COL_PANEL, 12);
  AddHit(Panel, hkPanel, 0);
  Text(C, RectF(Panel.Left, Panel.Top + 8, Panel.Right, Panel.Top + 64), 'Menu', TEXT_TITLE, COL_TEXT,
    TTextAlign.Center, True);
  N := 0;
  for E := Low(TMenuEntry) to High(TMenuEntry) do
  begin
    if not MenuEntryVisible(E) then
      Continue;
    R := RectF(Panel.Left + 24, Panel.Top + 72 + N * (MENU_ITEM_H + 8), Panel.Right - 24,
      Panel.Top + 72 + N * (MENU_ITEM_H + 8) + MENU_ITEM_H);
    Inc(N);
    if E = FMenuSel then
      Box(C, R, COL_SELECT, 8)
    else
      Box(C, R, COL_ROW, 8);
    if MenuEntryEnabled(E) then
      Text(C, R, MenuEntryText(E), TEXT_ROW, COL_TEXT, TTextAlign.Center, E = FMenuSel)
    else
      Text(C, R, MenuEntryText(E), TEXT_ROW, COL_DIM_TEXT, TTextAlign.Center, E = FMenuSel);
    AddHit(R, hkMenuEntry, Ord(E));
  end;
end;

procedure TfrmPad.DrawConfirm(C: TCanvas);
const
  BUTTON_W = 220;
  BUTTON_H = 60;
  PANEL_H = 260;
var
  Panel, OKR, CancelR: TRectF;
begin
  Box(C, RectF(0, 0, FVirtualW, FVirtualH), COL_SHADE);
  AddHit(RectF(0, 0, FVirtualW, FVirtualH), hkOutside, 0);
  Panel := RectF((FVirtualW - CONFIRM_W) / 2, (FVirtualH - PANEL_H) / 2, (FVirtualW + CONFIRM_W) / 2,
    (FVirtualH + PANEL_H) / 2);
  Box(C, Panel, COL_PANEL, 12);
  AddHit(Panel, hkPanel, 0);
  Text(C, RectF(Panel.Left + 32, Panel.Top + 24, Panel.Right - 32, Panel.Bottom - BUTTON_H - 40), FConfirmText,
    TEXT_TITLE, COL_TEXT, TTextAlign.Center, False, True);
  OKR := RectF(Panel.Left + CONFIRM_W / 2 - BUTTON_W - 16, Panel.Bottom - BUTTON_H - 24,
    Panel.Left + CONFIRM_W / 2 - 16, Panel.Bottom - 24);
  CancelR := RectF(Panel.Left + CONFIRM_W / 2 + 16, OKR.Top, Panel.Left + CONFIRM_W / 2 + 16 + BUTTON_W, OKR.Bottom);
  if FConfirmOK then
  begin
    Box(C, OKR, COL_SELECT, 8);
    Box(C, CancelR, COL_ROW, 8);
  end
  else
  begin
    Box(C, OKR, COL_ROW, 8);
    Box(C, CancelR, COL_SELECT, 8);
  end;
  Text(C, OKR, 'OK', TEXT_ROW, COL_TEXT, TTextAlign.Center, FConfirmOK);
  Text(C, CancelR, 'Cancel', TEXT_ROW, COL_TEXT, TTextAlign.Center, not FConfirmOK);
  AddHit(OKR, hkConfirmOK, 0);
  AddHit(CancelR, hkConfirmCancel, 0);
end;

end.
