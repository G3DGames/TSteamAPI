(* @abstract(Reference plug-in: ISteamUtils (isteamutils.h, SDK 1.65).)

  This unit is deliberately complete enough to be useful and small enough to
  serve as the template for every other interface plug-in. The recipe is:

    1. {$I Steamworks.inc} so structs/enums match the SDK layout.
    2. Declare cdecl procedural types for the SteamAPI_ISteamXxx_* exports
       (first parameter is always the interface pointer, "self").
    3. Descend from TSteamPlugin; in DoInitialize acquire the interface with
       AcquireUserInterface and Bind() the exports (optional ones with False).
    4. Wrap them in friendly Delphi methods/properties; subscribe to callbacks.
    5. Register the class in the initialization section.

  Including this unit in the project is all it takes to enable it:
  @longCode(#
  Utils := TSteamUtilsPlugin(Steam.FindPlugin(TSteamUtilsPlugin));
  if Utils <> nil then
    Writeln(Utils.SteamUILanguage);
  #) *)
unit Steamworks.Plugin.Utils;

{$I Steamworks.inc}

interface

uses
  SysUtils, Classes,
  Steamworks.Types, Steamworks.API, Steamworks.Callbacks, Steamworks.Core,
  Steamworks.Versions;

type
  { Corner used by Steam overlay notifications. }
  ENotificationPosition = (
    k_EPositionInvalid     = -1,
    k_EPositionTopLeft     = 0,
    k_EPositionTopRight    = 1,
    k_EPositionBottomLeft  = 2,
    k_EPositionBottomRight = 3
  );

  { Keyboard layout for the floating gamepad text input. }
  EFloatingGamepadTextInputMode = (
    k_EFloatingGamepadTextInputModeModeSingleLine    = 0,
    k_EFloatingGamepadTextInputModeModeMultipleLines = 1,
    k_EFloatingGamepadTextInputModeModeEmail         = 2,
    k_EFloatingGamepadTextInputModeModeNumeric       = 3
  );

  // --- callbacks ------------------------------------------------------------
  { 701 - the user's country (by IP) changed. Empty struct. }
  IPCountry_t = record
    { Placeholder: the C++ struct is empty (sizeof = 1). }
    _dummy: Byte;
  end;

  { 702 - fewer than 10 minutes of battery left (fires every minute). }
  LowBatteryPower_t = record
    { Estimated minutes of battery left. }
    m_nMinutesBatteryLeft: UInt8;
  end;

const
  { Callback id of @link(IPCountry_t) (701). }
  IPCountry_t_k_iCallback       = k_iSteamUtilsCallbacks + 1;
  { Callback id of @link(LowBatteryPower_t) (702). }
  LowBatteryPower_t_k_iCallback = k_iSteamUtilsCallbacks + 2;

type
  // --- flat exports -----------------------------------------------------------
  { Flat-export shape: @code(uint32 (self)). }
  TUtils_U32       = function(self: Pointer): UInt32; cdecl;
  { Flat-export shape: @code(bool (self)). }
  TUtils_Bool      = function(self: Pointer): Boolean; cdecl;
  { Flat-export shape: @code(const char* (self)). }
  TUtils_PChar     = function(self: Pointer): PAnsiChar; cdecl;
  { Flat-export shape: @code(EUniverse (self)). }
  TUtils_Universe  = function(self: Pointer): EUniverse; cdecl;
  { Flat-export shape: @code(uint8 (self)). }
  TUtils_U8        = function(self: Pointer): UInt8; cdecl;
  { Flat-export shape: @code(int (self)); also used for enums returned as int. }
  TUtils_Int       = function(self: Pointer): Integer; cdecl;
  { Flat-export shape: @code(void (self)). }
  TUtils_Proc      = procedure(self: Pointer); cdecl;
  { Flat-export shape: @code(void (self, bool)). }
  TUtils_SetBool   = procedure(self: Pointer; bValue: Boolean); cdecl;
  { Signature of SteamAPI_ISteamUtils_SetOverlayNotificationPosition. }
  TUtils_SetNotificationPosition = procedure(self: Pointer; eNotificationPosition: ENotificationPosition); cdecl;
  { Signature of SteamAPI_ISteamUtils_SetOverlayNotificationInset. }
  TUtils_SetNotificationInset    = procedure(self: Pointer; nHorizontalInset, nVerticalInset: Integer); cdecl;
  { Signature of SteamAPI_ISteamUtils_GetImageSize. }
  TUtils_GetImageSize  = function(self: Pointer; iImage: Integer; var pnWidth, pnHeight: UInt32): Boolean; cdecl;
  { Signature of SteamAPI_ISteamUtils_GetImageRGBA. }
  TUtils_GetImageRGBA  = function(self: Pointer; iImage: Integer; pubDest: PByte; nDestBufferSize: Integer): Boolean; cdecl;
  { Signature of SteamAPI_ISteamUtils_IsAPICallCompleted. }
  TUtils_IsAPICallCompleted = function(self: Pointer; hSteamAPICall: SteamAPICall_t; var pbFailed: Boolean): Boolean; cdecl;
  { Signature of SteamAPI_ISteamUtils_GetAPICallFailureReason. }
  TUtils_GetAPICallFailureReason = function(self: Pointer; hSteamAPICall: SteamAPICall_t): ESteamAPICallFailure; cdecl;
  { Signature of SteamAPI_ISteamUtils_ShowFloatingGamepadTextInput. }
  TUtils_ShowFloatingGamepadTextInput = function(self: Pointer; eKeyboardMode: EFloatingGamepadTextInputMode;
    nTextFieldXPosition, nTextFieldYPosition, nTextFieldWidth, nTextFieldHeight: Integer): Boolean; cdecl;

  { Event for @link(TSteamUtilsPlugin.OnLowBattery). }
  TLowBatteryEvent = procedure(Sender: TObject; AMinutesLeft: Integer) of object;

  { ISteamUtils plug-in: system, overlay, time and image utilities. Register by linking the unit. }
  TSteamUtilsPlugin = class(TSteamPlugin)
  private
    { The ISteamUtils pointer. }
    FIntf: Pointer;
    { Bound @code(SteamAPI_ISteamUtils_GetSecondsSinceAppActive) export (@nil if missing). }
    F_GetSecondsSinceAppActive: TUtils_U32;
    { Bound @code(SteamAPI_ISteamUtils_GetSecondsSinceComputerActive) export (@nil if missing). }
    F_GetSecondsSinceComputerActive: TUtils_U32;
    { Bound @code(SteamAPI_ISteamUtils_GetConnectedUniverse) export (@nil if missing). }
    F_GetConnectedUniverse: TUtils_Universe;
    { Bound @code(SteamAPI_ISteamUtils_GetServerRealTime) export (@nil if missing). }
    F_GetServerRealTime: TUtils_U32;
    { Bound @code(SteamAPI_ISteamUtils_GetIPCountry) export (@nil if missing). }
    F_GetIPCountry: TUtils_PChar;
    { Bound @code(SteamAPI_ISteamUtils_GetImageSize) export (@nil if missing). }
    F_GetImageSize: TUtils_GetImageSize;
    { Bound @code(SteamAPI_ISteamUtils_GetImageRGBA) export (@nil if missing). }
    F_GetImageRGBA: TUtils_GetImageRGBA;
    { Bound @code(SteamAPI_ISteamUtils_GetCurrentBatteryPower) export (@nil if missing). }
    F_GetCurrentBatteryPower: TUtils_U8;
    { Bound @code(SteamAPI_ISteamUtils_GetAppID) export (@nil if missing). }
    F_GetAppID: TUtils_U32;
    { Bound @code(SteamAPI_ISteamUtils_SetOverlayNotificationPosition) export (@nil if missing). }
    F_SetOverlayNotificationPosition: TUtils_SetNotificationPosition;
    { Bound @code(SteamAPI_ISteamUtils_SetOverlayNotificationInset) export (@nil if missing). }
    F_SetOverlayNotificationInset: TUtils_SetNotificationInset;
    { Bound @code(SteamAPI_ISteamUtils_IsAPICallCompleted) export (@nil if missing). }
    F_IsAPICallCompleted: TUtils_IsAPICallCompleted;
    { Bound @code(SteamAPI_ISteamUtils_GetAPICallFailureReason) export (@nil if missing). }
    F_GetAPICallFailureReason: TUtils_GetAPICallFailureReason;
    { Bound @code(SteamAPI_ISteamUtils_GetIPCCallCount) export (@nil if missing). }
    F_GetIPCCallCount: TUtils_U32;
    { Bound @code(SteamAPI_ISteamUtils_IsOverlayEnabled) export (@nil if missing). }
    F_IsOverlayEnabled: TUtils_Bool;
    { Bound @code(SteamAPI_ISteamUtils_BOverlayNeedsPresent) export (@nil if missing). }
    F_BOverlayNeedsPresent: TUtils_Bool;
    { Bound @code(SteamAPI_ISteamUtils_GetSteamUILanguage) export (@nil if missing). }
    F_GetSteamUILanguage: TUtils_PChar;
    { Bound @code(SteamAPI_ISteamUtils_IsSteamRunningInVR) export (@nil if missing). }
    F_IsSteamRunningInVR: TUtils_Bool;
    { Bound @code(SteamAPI_ISteamUtils_IsSteamInBigPictureMode) export (@nil if missing). }
    F_IsSteamInBigPictureMode: TUtils_Bool;
    { Bound @code(SteamAPI_ISteamUtils_StartVRDashboard) export (@nil if missing). }
    F_StartVRDashboard: TUtils_Proc;
    { Bound @code(SteamAPI_ISteamUtils_IsSteamChinaLauncher) export (@nil if missing). }
    F_IsSteamChinaLauncher: TUtils_Bool;
    { Bound @code(SteamAPI_ISteamUtils_SetGameLauncherMode) export (@nil if missing). }
    F_SetGameLauncherMode: TUtils_SetBool;
    { Bound @code(SteamAPI_ISteamUtils_ShowFloatingGamepadTextInput) export (@nil if missing). }
    F_ShowFloatingGamepadTextInput: TUtils_ShowFloatingGamepadTextInput;
    { Bound @code(SteamAPI_ISteamUtils_DismissFloatingGamepadTextInput) export (@nil if missing). }
    F_DismissFloatingGamepadTextInput: TUtils_Bool;
    { Bound @code(SteamAPI_ISteamUtils_IsRunningOnSteamHardware) export - new in SDK 1.65, so optional (@nil with older redistributables). }
    F_IsRunningOnSteamHardware: TUtils_Int;
    { Bound @code(SteamAPI_ISteamUtils_IsRunningUnderProton) export - new in SDK 1.65 (@nil with older redistributables). }
    F_IsRunningUnderProton: TUtils_Bool;
    { Bound @code(SteamAPI_ISteamUtils_IsRunningOnSteamDeck) export - removed in SDK 1.65, so only found in older redistributables. }
    F_IsRunningOnSteamDeck: TUtils_Bool;

    { Backing field of @link(OnIPCountryChanged). }
    FOnIPCountryChanged: TNotifyEvent;
    { Backing field of @link(OnLowBattery). }
    FOnLowBattery: TLowBatteryEvent;
    { Converts a UTF-8 C string from Steam to a string ('' for @nil). }
    function PCharToStr(P: PAnsiChar): string;
    { Handler of IPCountry_t; raises @link(OnIPCountryChanged). }
    procedure HandleIPCountry(const AData: TSteamCallbackData);
    { Handler of LowBatteryPower_t; raises @link(OnLowBattery). }
    procedure HandleLowBattery(const AData: TSteamCallbackData);
  protected
    { Acquires ISteamUtils, binds its exports and subscribes to its callbacks. }
    function DoInitialize: Boolean; override;
    { Forgets the interface pointer. }
    procedure DoFinalize; override;
  public
    { Returns @code(ISteamUtils). }
    class function PluginName: string; override;
    { Declares the SteamUtils interface version for versioned initialisation. }
    class function InterfaceVersions(AVersions: TSteamInterfaceVersions): TSteamStringArray; override;

    { Seconds since the user last interacted with the game. }
    function SecondsSinceAppActive: UInt32;
    { Seconds since the user last interacted with the computer. }
    function SecondsSinceComputerActive: UInt32;
    { Universe this client is connected to (normally k_EUniversePublic). }
    function ConnectedUniverse: EUniverse;
    { Steam server time, Unix epoch seconds. }
    function ServerRealTime: UInt32;
    { @link(ServerRealTime) as a UTC TDateTime. }
    function ServerTime: TDateTime;
    { 2-letter ISO 3166-1 country code from the user's IP. }
    function IPCountry: string;
    { 0..100, or 255 when on AC power. }
    function CurrentBatteryPower: Integer;
    { AppID of the running game as Steam sees it. }
    function AppID: AppId_t;
    { IPC calls since the last call to this function (diagnostics). }
    function IPCCallCount: UInt32;
    { @true if the Steam overlay is enabled and running for this game. }
    function IsOverlayEnabled: Boolean;
    { @true if the overlay needs a present call to update (when not rendering every frame). }
    function OverlayNeedsPresent: Boolean;
    { Steam UI language, e.g. 'english'. }
    function SteamUILanguage: string;
    { @true if Steam is running in VR mode. }
    function IsSteamRunningInVR: Boolean;
    { @true if Steam is in Big Picture mode (@false if unavailable). }
    function IsSteamInBigPictureMode: Boolean;
    { @true if running through the Steam China launcher. }
    function IsSteamChinaLauncher: Boolean;
    { Opens the SteamVR dashboard. }
    procedure StartVRDashboard;
    { Corner where overlay notifications appear. }
    procedure SetOverlayNotificationPosition(APosition: ENotificationPosition);
    { Inset of overlay notifications from the chosen corner, in pixels. }
    procedure SetOverlayNotificationInset(AHorizontal, AVertical: Integer);
    { Tells Steam the game is acting as a launcher (gamepad navigation hints). }
    procedure SetGameLauncherMode(ALauncherMode: Boolean);
    { Polls an async call. @returns(@true when complete; AFailed tells whether it failed.) }
    function IsAPICallCompleted(ACall: SteamAPICall_t; out AFailed: Boolean): Boolean;
    { Why an async call failed. }
    function APICallFailureReason(ACall: SteamAPICall_t): ESteamAPICallFailure;

    { Gets an avatar/achievement image (RGBA, 4 bytes per pixel). }
    function GetImageSize(AImage: Integer; out AWidth, AHeight: UInt32): Boolean;
    { Image pixels (RGBA, 4 bytes per pixel, rows top-down) or @nil. }
    function GetImageRGBA(AImage: Integer; out AWidth, AHeight: UInt32): TBytes;

    { Shows the floating on-screen keyboard over a text field (Steam Deck / Big Picture). }
    function ShowFloatingGamepadTextInput(AMode: EFloatingGamepadTextInputMode;
      AX, AY, AWidth, AHeight: Integer): Boolean;
    { Hides the floating on-screen keyboard. }
    function DismissFloatingGamepadTextInput: Boolean;

    // --- SDK 1.65 ------------------------------------------------------------
    { @true if the SDK 1.65 IsRunningOnSteamHardware export is available. }
    function HasSteamHardwareDetection: Boolean;
    { Raw ESteamHardwareType from ISteamUtils::IsRunningOnSteamHardware (SDK 1.65). Valve intends this for analytics / support only. Returns -1 if unavailable. }
    function SteamHardwareType: Integer;
    { True when running under Proton on Linux (SDK 1.65; False if unavailable). }
    function IsRunningUnderProton: Boolean;
    { Deprecated: removed in SDK 1.65; works only with older redistributables. }
    function IsRunningOnSteamDeck: Boolean; deprecated 'Removed in Steamworks SDK 1.65 - use SteamHardwareType / IsSteamInBigPictureMode';

    { The raw ISteamUtils pointer, for flat calls not wrapped here. }
    property Handle: Pointer read FIntf;
    { The user's IP country changed (IPCountry_t). }
    property OnIPCountryChanged: TNotifyEvent read FOnIPCountryChanged write FOnIPCountryChanged;
    { Battery is low (LowBatteryPower_t); fires every minute below 10 minutes. }
    property OnLowBattery: TLowBatteryEvent read FOnLowBattery write FOnLowBattery;
  end;

implementation

uses
  DateUtils;

const
  PFX = 'SteamAPI_ISteamUtils_';

{ TSteamUtilsPlugin }

class function TSteamUtilsPlugin.PluginName: string;
begin
  Result := 'ISteamUtils';
end;

class function TSteamUtilsPlugin.InterfaceVersions(AVersions: TSteamInterfaceVersions): TSteamStringArray;
begin
  SetLength(Result, 1);
  Result[0] := AVersions.Resolve(STEAMUTILS_INTERFACE_VERSION);
end;

function TSteamUtilsPlugin.DoInitialize: Boolean;
begin
  FIntf := AcquireUserInterface(STEAMUTILS_INTERFACE_VERSION, 'SteamUtils');
  if FIntf = nil then
    Exit(False);

  Result :=
    Bind(F_GetSecondsSinceAppActive, PFX + 'GetSecondsSinceAppActive') and
    Bind(F_GetSecondsSinceComputerActive, PFX + 'GetSecondsSinceComputerActive') and
    Bind(F_GetConnectedUniverse, PFX + 'GetConnectedUniverse') and
    Bind(F_GetServerRealTime, PFX + 'GetServerRealTime') and
    Bind(F_GetIPCountry, PFX + 'GetIPCountry') and
    Bind(F_GetImageSize, PFX + 'GetImageSize') and
    Bind(F_GetImageRGBA, PFX + 'GetImageRGBA') and
    Bind(F_GetCurrentBatteryPower, PFX + 'GetCurrentBatteryPower') and
    Bind(F_GetAppID, PFX + 'GetAppID') and
    Bind(F_SetOverlayNotificationPosition, PFX + 'SetOverlayNotificationPosition') and
    Bind(F_IsAPICallCompleted, PFX + 'IsAPICallCompleted') and
    Bind(F_GetAPICallFailureReason, PFX + 'GetAPICallFailureReason') and
    Bind(F_GetIPCCallCount, PFX + 'GetIPCCallCount') and
    Bind(F_IsOverlayEnabled, PFX + 'IsOverlayEnabled') and
    Bind(F_BOverlayNeedsPresent, PFX + 'BOverlayNeedsPresent') and
    Bind(F_GetSteamUILanguage, PFX + 'GetSteamUILanguage') and
    Bind(F_IsSteamRunningInVR, PFX + 'IsSteamRunningInVR');
  if not Result then
    Exit;

  // Optional / version dependent
  Bind(F_SetOverlayNotificationInset, PFX + 'SetOverlayNotificationInset', False);
  Bind(F_IsSteamInBigPictureMode, PFX + 'IsSteamInBigPictureMode', False);
  Bind(F_StartVRDashboard, PFX + 'StartVRDashboard', False);
  Bind(F_IsSteamChinaLauncher, PFX + 'IsSteamChinaLauncher', False);
  Bind(F_SetGameLauncherMode, PFX + 'SetGameLauncherMode', False);
  Bind(F_ShowFloatingGamepadTextInput, PFX + 'ShowFloatingGamepadTextInput', False);
  Bind(F_DismissFloatingGamepadTextInput, PFX + 'DismissFloatingGamepadTextInput', False);
  Bind(F_IsRunningOnSteamHardware, PFX + 'IsRunningOnSteamHardware', False);
  Bind(F_IsRunningUnderProton, PFX + 'IsRunningUnderProton', False);
  Bind(F_IsRunningOnSteamDeck, PFX + 'IsRunningOnSteamDeck', False);

  Subscribe(IPCountry_t_k_iCallback, HandleIPCountry);
  Subscribe(LowBatteryPower_t_k_iCallback, HandleLowBattery);
end;

procedure TSteamUtilsPlugin.HandleIPCountry(const AData: TSteamCallbackData);
begin
  if Assigned(FOnIPCountryChanged) then
    FOnIPCountryChanged(Self);
end;

procedure TSteamUtilsPlugin.HandleLowBattery(const AData: TSteamCallbackData);
var
  Ev: LowBatteryPower_t;
begin
  if AData.CopyTo(Ev, SizeOf(Ev)) and Assigned(FOnLowBattery) then
    FOnLowBattery(Self, Ev.m_nMinutesBatteryLeft);
end;

procedure TSteamUtilsPlugin.DoFinalize;
begin
  FIntf := nil;
end;

function TSteamUtilsPlugin.PCharToStr(P: PAnsiChar): string;
begin
  if P = nil then
    Result := ''
  else
    Result := string(UTF8String(P));
end;

function TSteamUtilsPlugin.SecondsSinceAppActive: UInt32;
begin
  Result := F_GetSecondsSinceAppActive(FIntf);
end;

function TSteamUtilsPlugin.SecondsSinceComputerActive: UInt32;
begin
  Result := F_GetSecondsSinceComputerActive(FIntf);
end;

function TSteamUtilsPlugin.ConnectedUniverse: EUniverse;
begin
  Result := F_GetConnectedUniverse(FIntf);
end;

function TSteamUtilsPlugin.ServerRealTime: UInt32;
begin
  Result := F_GetServerRealTime(FIntf);
end;

function TSteamUtilsPlugin.ServerTime: TDateTime;
begin
  Result := UnixToDateTime(ServerRealTime, True);
end;

function TSteamUtilsPlugin.IPCountry: string;
begin
  Result := PCharToStr(F_GetIPCountry(FIntf));
end;

function TSteamUtilsPlugin.CurrentBatteryPower: Integer;
begin
  Result := F_GetCurrentBatteryPower(FIntf);
end;

function TSteamUtilsPlugin.AppID: AppId_t;
begin
  Result := F_GetAppID(FIntf);
end;

function TSteamUtilsPlugin.IPCCallCount: UInt32;
begin
  Result := F_GetIPCCallCount(FIntf);
end;

function TSteamUtilsPlugin.IsOverlayEnabled: Boolean;
begin
  Result := F_IsOverlayEnabled(FIntf);
end;

function TSteamUtilsPlugin.OverlayNeedsPresent: Boolean;
begin
  Result := F_BOverlayNeedsPresent(FIntf);
end;

function TSteamUtilsPlugin.SteamUILanguage: string;
begin
  Result := PCharToStr(F_GetSteamUILanguage(FIntf));
end;

function TSteamUtilsPlugin.IsSteamRunningInVR: Boolean;
begin
  Result := F_IsSteamRunningInVR(FIntf);
end;

function TSteamUtilsPlugin.IsSteamInBigPictureMode: Boolean;
begin
  Result := Assigned(F_IsSteamInBigPictureMode) and F_IsSteamInBigPictureMode(FIntf);
end;

function TSteamUtilsPlugin.IsSteamChinaLauncher: Boolean;
begin
  Result := Assigned(F_IsSteamChinaLauncher) and F_IsSteamChinaLauncher(FIntf);
end;

procedure TSteamUtilsPlugin.StartVRDashboard;
begin
  if Assigned(F_StartVRDashboard) then
    F_StartVRDashboard(FIntf);
end;

procedure TSteamUtilsPlugin.SetOverlayNotificationPosition(APosition: ENotificationPosition);
begin
  F_SetOverlayNotificationPosition(FIntf, APosition);
end;

procedure TSteamUtilsPlugin.SetOverlayNotificationInset(AHorizontal, AVertical: Integer);
begin
  if Assigned(F_SetOverlayNotificationInset) then
    F_SetOverlayNotificationInset(FIntf, AHorizontal, AVertical);
end;

procedure TSteamUtilsPlugin.SetGameLauncherMode(ALauncherMode: Boolean);
begin
  if Assigned(F_SetGameLauncherMode) then
    F_SetGameLauncherMode(FIntf, ALauncherMode);
end;

function TSteamUtilsPlugin.IsAPICallCompleted(ACall: SteamAPICall_t; out AFailed: Boolean): Boolean;
begin
  AFailed := False;
  Result := F_IsAPICallCompleted(FIntf, ACall, AFailed);
end;

function TSteamUtilsPlugin.APICallFailureReason(ACall: SteamAPICall_t): ESteamAPICallFailure;
begin
  Result := F_GetAPICallFailureReason(FIntf, ACall);
end;

function TSteamUtilsPlugin.GetImageSize(AImage: Integer; out AWidth, AHeight: UInt32): Boolean;
begin
  AWidth := 0;
  AHeight := 0;
  Result := F_GetImageSize(FIntf, AImage, AWidth, AHeight);
end;

function TSteamUtilsPlugin.GetImageRGBA(AImage: Integer; out AWidth, AHeight: UInt32): TBytes;
begin
  Result := nil;
  if not GetImageSize(AImage, AWidth, AHeight) or (AWidth = 0) or (AHeight = 0) then
    Exit;
  SetLength(Result, AWidth * AHeight * 4);
  if not F_GetImageRGBA(FIntf, AImage, @Result[0], Length(Result)) then
    Result := nil;
end;

function TSteamUtilsPlugin.ShowFloatingGamepadTextInput(AMode: EFloatingGamepadTextInputMode;
  AX, AY, AWidth, AHeight: Integer): Boolean;
begin
  Result := Assigned(F_ShowFloatingGamepadTextInput) and
            F_ShowFloatingGamepadTextInput(FIntf, AMode, AX, AY, AWidth, AHeight);
end;

function TSteamUtilsPlugin.DismissFloatingGamepadTextInput: Boolean;
begin
  Result := Assigned(F_DismissFloatingGamepadTextInput) and F_DismissFloatingGamepadTextInput(FIntf);
end;

function TSteamUtilsPlugin.HasSteamHardwareDetection: Boolean;
begin
  Result := Assigned(F_IsRunningOnSteamHardware);
end;

function TSteamUtilsPlugin.SteamHardwareType: Integer;
begin
  if Assigned(F_IsRunningOnSteamHardware) then
    Result := F_IsRunningOnSteamHardware(FIntf)
  else
    Result := -1;
end;

function TSteamUtilsPlugin.IsRunningUnderProton: Boolean;
begin
  Result := Assigned(F_IsRunningUnderProton) and F_IsRunningUnderProton(FIntf);
end;

function TSteamUtilsPlugin.IsRunningOnSteamDeck: Boolean;
begin
  Result := Assigned(F_IsRunningOnSteamDeck) and F_IsRunningOnSteamDeck(FIntf);
end;

initialization
  TSteamworks.RegisterPlugin(TSteamUtilsPlugin);

finalization
  TSteamworks.UnregisterPlugin(TSteamUtilsPlugin);

end.
