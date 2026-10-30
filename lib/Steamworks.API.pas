{ @abstract(Loader and bindings for the core, framework-independent Steamworks
  flat API.)

  Covers these SDK headers:
  @unorderedList(
    @item(steam_api.h - SteamAPI_InitFlat / Shutdown / RunCallbacks /
      RestartAppIfNecessary ...)
    @item(steam_api_common.h - pipe / user handles, manual dispatch)
    @item(steam_api_internal.h - SteamInternal_* interface factories)
    @item(isteamclient.h - ISteamClient through the SteamAPI_ISteamClient_*
      flat exports)
  )

  Everything is resolved at run time through @link(TSteamDynLib), so the
  program starts (and can report a useful error) when the redistributable is
  missing, and redistributables that add or drop exports do not stop it from
  loading. Plug-ins bind their own exports with @link(TSteamAPI.Bind).

  All Steamworks exports use the cdecl calling convention (S_CALLTYPE).

  @link(TSteamInterfaceVersions) discovers which interface versions the loaded
  redistributable was built against. }
unit Steamworks.API;

{$I Steamworks.inc}

interface

uses
  SysUtils, Classes, Generics.Collections,
  Steamworks.Types, Steamworks.DynLib;

type
  { Base class of all Steamworks library exceptions. }
  ESteamworksError = class(Exception);

  // --- steam_api.h ----------------------------------------------------------
  { Signature of the @code(SteamAPI_Init) export. }
  TSteamAPI_Init                  = function: Boolean; cdecl;
  { Signature of the @code(SteamAPI_InitSafe) export. }
  TSteamAPI_InitSafe              = function: Boolean; cdecl;
  { Signature of the @code(SteamAPI_InitFlat) export. }
  TSteamAPI_InitFlat              = function(pOutErrMsg: PSteamErrMsg): ESteamAPIInitResult; cdecl;
  { Signature of the @code(SteamInternal_SteamAPI_Init) export. }
  TSteamInternal_SteamAPI_Init    = function(pszInternalCheckInterfaceVersions: PAnsiChar; pOutErrMsg: PSteamErrMsg): ESteamAPIInitResult; cdecl;
  { Signature of the @code(SteamAPI_Shutdown) export. }
  TSteamAPI_Shutdown              = procedure; cdecl;
  { Signature of the @code(SteamAPI_RestartAppIfNecessary) export. }
  TSteamAPI_RestartAppIfNecessary = function(unOwnAppID: UInt32): Boolean; cdecl;
  { Signature of the @code(SteamAPI_ReleaseCurrentThreadMemory) export. }
  TSteamAPI_ReleaseCurrentThreadMemory = procedure; cdecl;
  { Signature of the @code(SteamAPI_WriteMiniDump) export. }
  TSteamAPI_WriteMiniDump         = procedure(uStructuredExceptionCode: UInt32; pvExceptionInfo: Pointer; uBuildID: UInt32); cdecl;
  { Signature of the @code(SteamAPI_SetMiniDumpComment) export. }
  TSteamAPI_SetMiniDumpComment    = procedure(pchMsg: PAnsiChar); cdecl;
  { Signature of the @code(SteamAPI_RunCallbacks) export. }
  TSteamAPI_RunCallbacks          = procedure; cdecl;
  { Signature of the @code(SteamAPI_IsSteamRunning) export. }
  TSteamAPI_IsSteamRunning        = function: Boolean; cdecl;
  { Signature of the @code(SteamAPI_GetSteamInstallPath) export. }
  TSteamAPI_GetSteamInstallPath   = function: PAnsiChar; cdecl;
  { Signature of the @code(SteamAPI_SetTryCatchCallbacks) export. }
  TSteamAPI_SetTryCatchCallbacks  = procedure(bTryCatchCallbacks: Boolean); cdecl;

  // --- steam_api_common.h ---------------------------------------------------
  { Signature of the @code(SteamAPI_GetHSteamPipe) export. }
  TSteamAPI_GetHSteamPipe = function: HSteamPipe; cdecl;
  { Signature of the @code(SteamAPI_GetHSteamUser) export. }
  TSteamAPI_GetHSteamUser = function: HSteamUser; cdecl;
  { Signature of the @code(SteamAPI_ManualDispatch_Init) export. }
  TSteamAPI_ManualDispatch_Init             = procedure; cdecl;
  { Signature of the @code(SteamAPI_ManualDispatch_RunFrame) export. }
  TSteamAPI_ManualDispatch_RunFrame         = procedure(hSteamPipe: HSteamPipe); cdecl;
  { Signature of the @code(SteamAPI_ManualDispatch_GetNextCallback) export. }
  TSteamAPI_ManualDispatch_GetNextCallback  = function(hSteamPipe: HSteamPipe; pCallbackMsg: PCallbackMsg_t): Boolean; cdecl;
  { Signature of the @code(SteamAPI_ManualDispatch_FreeLastCallback) export. }
  TSteamAPI_ManualDispatch_FreeLastCallback = procedure(hSteamPipe: HSteamPipe); cdecl;
  { Signature of the @code(SteamAPI_ManualDispatch_GetAPICallResult) export. }
  TSteamAPI_ManualDispatch_GetAPICallResult = function(hSteamPipe: HSteamPipe; hSteamAPICall: SteamAPICall_t;
    pCallback: Pointer; cubCallback: Integer; iCallbackExpected: Integer; var pbFailed: Boolean): Boolean; cdecl;

  // --- steam_api_internal.h -------------------------------------------------
  { Signature of the @code(SteamInternal_CreateInterface) export. }
  TSteamInternal_CreateInterface                 = function(ver: PAnsiChar): Pointer; cdecl;
  { Signature of the @code(SteamInternal_FindOrCreateUserInterface) export. }
  TSteamInternal_FindOrCreateUserInterface       = function(hSteamUser: HSteamUser; pszVersion: PAnsiChar): Pointer; cdecl;
  { Signature of the @code(SteamInternal_FindOrCreateGameServerInterface) export. }
  TSteamInternal_FindOrCreateGameServerInterface = function(hSteamUser: HSteamUser; pszVersion: PAnsiChar): Pointer; cdecl;

  // --- isteamclient.h (flat) ------------------------------------------------
  { Signature of the @code(SteamAPI_ISteamClient_CreateSteamPipe) export. }
  TISteamClient_CreateSteamPipe     = function(self: Pointer): HSteamPipe; cdecl;
  { Signature of the @code(SteamAPI_ISteamClient_BReleaseSteamPipe) export. }
  TISteamClient_BReleaseSteamPipe   = function(self: Pointer; hSteamPipe: HSteamPipe): Boolean; cdecl;
  { Signature of the @code(SteamAPI_ISteamClient_ConnectToGlobalUser) export. }
  TISteamClient_ConnectToGlobalUser = function(self: Pointer; hSteamPipe: HSteamPipe): HSteamUser; cdecl;
  { Signature of the @code(SteamAPI_ISteamClient_CreateLocalUser) export. }
  TISteamClient_CreateLocalUser     = function(self: Pointer; phSteamPipe: PHSteamPipe; eAccountType: EAccountType): HSteamUser; cdecl;
  { Signature of the @code(SteamAPI_ISteamClient_ReleaseUser) export. }
  TISteamClient_ReleaseUser         = procedure(self: Pointer; hSteamPipe: HSteamPipe; hUser: HSteamUser); cdecl;
  { Shape shared by the ISteamClient::GetISteamXxx(hUser, hPipe, version) getters. }
  TISteamClient_GetUserInterface    = function(self: Pointer; hSteamUser: HSteamUser; hSteamPipe: HSteamPipe; pchVersion: PAnsiChar): Pointer; cdecl;
  { Signature of the @code(SteamAPI_ISteamClient_GetPipeInterface) export. }
  TISteamClient_GetPipeInterface    = function(self: Pointer; hSteamPipe: HSteamPipe; pchVersion: PAnsiChar): Pointer; cdecl;
  { C++ takes @code(const SteamIPAddress_t &), i.e. a pointer - never pass the record by value. }
  TISteamClient_SetLocalIPBinding   = procedure(self: Pointer; unIP: PSteamIPAddress_t; usPort: UInt16); cdecl;
  { Signature of the @code(SteamAPI_ISteamClient_GetIPCCallCount) export. }
  TISteamClient_GetIPCCallCount     = function(self: Pointer): UInt32; cdecl;
  { Signature of the @code(SteamAPI_ISteamClient_SetWarningMessageHook) export. }
  TISteamClient_SetWarningMessageHook = procedure(self: Pointer; pFunction: SteamAPIWarningMessageHook_t); cdecl;
  { Signature of the @code(SteamAPI_ISteamClient_BShutdownIfAllPipesClosed) export. }
  TISteamClient_BShutdownIfAllPipesClosed = function(self: Pointer): Boolean; cdecl;

  { Static holder for the loaded redistributable and the core flat entry
    points. Entry points that are not in every redistributable are @nil when
    missing - test them with Assigned() before calling.

    Usually you do not use this class directly; @code(TSteamworks) loads it.

    @longCode(#
    TSteamAPI.Load;  // default name, next to the exe
    if TSteamAPI.SteamAPI_IsSteamRunning() then ...
    TSteamAPI.Unload;
    #) }
  TSteamAPI = class
  private
    { The loaded redistributable (@nil when not loaded). }
    class var FLib: TSteamDynLib;
    { Backing field of @link(OnWarning). }
    class var FOnWarning: TSteamDynLibWarningEvent;
    { Binds every core export; raises if a required one is missing. }
    class procedure BindAll; static;
    { Sets every bound export to @nil. }
    class procedure ClearAll; static;
  public
    // --- steam_api.h ---
    { Bound @code(SteamAPI_Init) export (@nil if missing). }
    class var SteamAPI_Init: TSteamAPI_Init;
    { Bound @code(SteamAPI_InitSafe) export (@nil if missing). }
    class var SteamAPI_InitSafe: TSteamAPI_InitSafe;
    { Bound @code(SteamAPI_InitFlat) export (@nil if missing). }
    class var SteamAPI_InitFlat: TSteamAPI_InitFlat;
    { Bound @code(SteamInternal_SteamAPI_Init) export (@nil if missing). }
    class var SteamInternal_SteamAPI_Init: TSteamInternal_SteamAPI_Init;
    { Bound @code(SteamAPI_Shutdown) export (@nil if missing). }
    class var SteamAPI_Shutdown: TSteamAPI_Shutdown;
    { Bound @code(SteamAPI_RestartAppIfNecessary) export (@nil if missing). }
    class var SteamAPI_RestartAppIfNecessary: TSteamAPI_RestartAppIfNecessary;
    { Bound @code(SteamAPI_ReleaseCurrentThreadMemory) export (@nil if missing). }
    class var SteamAPI_ReleaseCurrentThreadMemory: TSteamAPI_ReleaseCurrentThreadMemory;
    { Bound @code(SteamAPI_WriteMiniDump) export (@nil if missing). }
    class var SteamAPI_WriteMiniDump: TSteamAPI_WriteMiniDump;
    { Bound @code(SteamAPI_SetMiniDumpComment) export (@nil if missing). }
    class var SteamAPI_SetMiniDumpComment: TSteamAPI_SetMiniDumpComment;
    { Bound @code(SteamAPI_RunCallbacks) export (@nil if missing). }
    class var SteamAPI_RunCallbacks: TSteamAPI_RunCallbacks;
    { Bound @code(SteamAPI_IsSteamRunning) export (@nil if missing). }
    class var SteamAPI_IsSteamRunning: TSteamAPI_IsSteamRunning;
    { Bound @code(SteamAPI_GetSteamInstallPath) export (@nil if missing). }
    class var SteamAPI_GetSteamInstallPath: TSteamAPI_GetSteamInstallPath;
    { Bound @code(SteamAPI_SetTryCatchCallbacks) export (@nil if missing). }
    class var SteamAPI_SetTryCatchCallbacks: TSteamAPI_SetTryCatchCallbacks;
    // --- steam_api_common.h ---
    { Bound @code(SteamAPI_GetHSteamPipe) export (@nil if missing). }
    class var SteamAPI_GetHSteamPipe: TSteamAPI_GetHSteamPipe;
    { Bound @code(SteamAPI_GetHSteamUser) export (@nil if missing). }
    class var SteamAPI_GetHSteamUser: TSteamAPI_GetHSteamUser;
    { Bound @code(SteamAPI_ManualDispatch_Init) export (@nil if missing). }
    class var SteamAPI_ManualDispatch_Init: TSteamAPI_ManualDispatch_Init;
    { Bound @code(SteamAPI_ManualDispatch_RunFrame) export (@nil if missing). }
    class var SteamAPI_ManualDispatch_RunFrame: TSteamAPI_ManualDispatch_RunFrame;
    { Bound @code(SteamAPI_ManualDispatch_GetNextCallback) export (@nil if missing). }
    class var SteamAPI_ManualDispatch_GetNextCallback: TSteamAPI_ManualDispatch_GetNextCallback;
    { Bound @code(SteamAPI_ManualDispatch_FreeLastCallback) export (@nil if missing). }
    class var SteamAPI_ManualDispatch_FreeLastCallback: TSteamAPI_ManualDispatch_FreeLastCallback;
    { Bound @code(SteamAPI_ManualDispatch_GetAPICallResult) export (@nil if missing). }
    class var SteamAPI_ManualDispatch_GetAPICallResult: TSteamAPI_ManualDispatch_GetAPICallResult;
    // --- steam_api_internal.h ---
    { Bound @code(SteamInternal_CreateInterface) export (@nil if missing). }
    class var SteamInternal_CreateInterface: TSteamInternal_CreateInterface;
    { Bound @code(SteamInternal_FindOrCreateUserInterface) export (@nil if missing). }
    class var SteamInternal_FindOrCreateUserInterface: TSteamInternal_FindOrCreateUserInterface;
    { Bound @code(SteamInternal_FindOrCreateGameServerInterface) export (@nil if missing). }
    class var SteamInternal_FindOrCreateGameServerInterface: TSteamInternal_FindOrCreateGameServerInterface;
    // --- isteamclient.h ---
    { Bound @code(SteamAPI_ISteamClient_CreateSteamPipe) export (@nil if missing). }
    class var ISteamClient_CreateSteamPipe: TISteamClient_CreateSteamPipe;
    { Bound @code(SteamAPI_ISteamClient_BReleaseSteamPipe) export (@nil if missing). }
    class var ISteamClient_BReleaseSteamPipe: TISteamClient_BReleaseSteamPipe;
    { Bound @code(SteamAPI_ISteamClient_ConnectToGlobalUser) export (@nil if missing). }
    class var ISteamClient_ConnectToGlobalUser: TISteamClient_ConnectToGlobalUser;
    { Bound @code(SteamAPI_ISteamClient_CreateLocalUser) export (@nil if missing). }
    class var ISteamClient_CreateLocalUser: TISteamClient_CreateLocalUser;
    { Bound @code(SteamAPI_ISteamClient_ReleaseUser) export (@nil if missing). }
    class var ISteamClient_ReleaseUser: TISteamClient_ReleaseUser;
    { Bound @code(SteamAPI_ISteamClient_GetISteamUser) export (@nil if missing). }
    class var ISteamClient_GetISteamUser: TISteamClient_GetUserInterface;
    { Bound @code(SteamAPI_ISteamClient_GetISteamGameServer) export (@nil if missing). }
    class var ISteamClient_GetISteamGameServer: TISteamClient_GetUserInterface;
    { Bound @code(SteamAPI_ISteamClient_SetLocalIPBinding) export (@nil if missing). }
    class var ISteamClient_SetLocalIPBinding: TISteamClient_SetLocalIPBinding;
    { Bound @code(SteamAPI_ISteamClient_GetISteamFriends) export (@nil if missing). }
    class var ISteamClient_GetISteamFriends: TISteamClient_GetUserInterface;
    { Bound @code(SteamAPI_ISteamClient_GetISteamUtils) export (@nil if missing). }
    class var ISteamClient_GetISteamUtils: TISteamClient_GetPipeInterface;
    { Bound @code(SteamAPI_ISteamClient_GetISteamMatchmaking) export (@nil if missing). }
    class var ISteamClient_GetISteamMatchmaking: TISteamClient_GetUserInterface;
    { Bound @code(SteamAPI_ISteamClient_GetISteamMatchmakingServers) export (@nil if missing). }
    class var ISteamClient_GetISteamMatchmakingServers: TISteamClient_GetUserInterface;
    { Bound @code(SteamAPI_ISteamClient_GetISteamGenericInterface) export (@nil if missing). }
    class var ISteamClient_GetISteamGenericInterface: TISteamClient_GetUserInterface;
    { Bound @code(SteamAPI_ISteamClient_GetISteamUserStats) export (@nil if missing). }
    class var ISteamClient_GetISteamUserStats: TISteamClient_GetUserInterface;
    { Bound @code(SteamAPI_ISteamClient_GetISteamGameServerStats) export (@nil if missing). }
    class var ISteamClient_GetISteamGameServerStats: TISteamClient_GetUserInterface;
    { Bound @code(SteamAPI_ISteamClient_GetISteamApps) export (@nil if missing). }
    class var ISteamClient_GetISteamApps: TISteamClient_GetUserInterface;
    { Bound @code(SteamAPI_ISteamClient_GetISteamNetworking) export (@nil if missing). }
    class var ISteamClient_GetISteamNetworking: TISteamClient_GetUserInterface;
    { Bound @code(SteamAPI_ISteamClient_GetISteamRemoteStorage) export (@nil if missing). }
    class var ISteamClient_GetISteamRemoteStorage: TISteamClient_GetUserInterface;
    { Bound @code(SteamAPI_ISteamClient_GetISteamScreenshots) export (@nil if missing). }
    class var ISteamClient_GetISteamScreenshots: TISteamClient_GetUserInterface;
    { Bound @code(SteamAPI_ISteamClient_GetISteamGameSearch) export (@nil if missing). }
    class var ISteamClient_GetISteamGameSearch: TISteamClient_GetUserInterface;
    { Bound @code(SteamAPI_ISteamClient_GetIPCCallCount) export (@nil if missing). }
    class var ISteamClient_GetIPCCallCount: TISteamClient_GetIPCCallCount;
    { Bound @code(SteamAPI_ISteamClient_SetWarningMessageHook) export (@nil if missing). }
    class var ISteamClient_SetWarningMessageHook: TISteamClient_SetWarningMessageHook;
    { Bound @code(SteamAPI_ISteamClient_BShutdownIfAllPipesClosed) export (@nil if missing). }
    class var ISteamClient_BShutdownIfAllPipesClosed: TISteamClient_BShutdownIfAllPipesClosed;
    { Bound @code(SteamAPI_ISteamClient_GetISteamHTTP) export (@nil if missing). }
    class var ISteamClient_GetISteamHTTP: TISteamClient_GetUserInterface;
    { Bound @code(SteamAPI_ISteamClient_GetISteamController) export (@nil if missing). }
    class var ISteamClient_GetISteamController: TISteamClient_GetUserInterface;
    { Bound @code(SteamAPI_ISteamClient_GetISteamUGC) export (@nil if missing). }
    class var ISteamClient_GetISteamUGC: TISteamClient_GetUserInterface;
    { Bound @code(SteamAPI_ISteamClient_GetISteamMusic) export (@nil if missing). }
    class var ISteamClient_GetISteamMusic: TISteamClient_GetUserInterface;
    { Bound @code(SteamAPI_ISteamClient_GetISteamMusicRemote) export (@nil if missing). }
    class var ISteamClient_GetISteamMusicRemote: TISteamClient_GetUserInterface;
    { Bound @code(SteamAPI_ISteamClient_GetISteamHTMLSurface) export (@nil if missing). }
    class var ISteamClient_GetISteamHTMLSurface: TISteamClient_GetUserInterface;
    { Bound @code(SteamAPI_ISteamClient_GetISteamInventory) export (@nil if missing). }
    class var ISteamClient_GetISteamInventory: TISteamClient_GetUserInterface;
    { Bound @code(SteamAPI_ISteamClient_GetISteamVideo) export (@nil if missing). }
    class var ISteamClient_GetISteamVideo: TISteamClient_GetUserInterface;
    { Bound @code(SteamAPI_ISteamClient_GetISteamParentalSettings) export (@nil if missing). }
    class var ISteamClient_GetISteamParentalSettings: TISteamClient_GetUserInterface;
    { Bound @code(SteamAPI_ISteamClient_GetISteamInput) export (@nil if missing). }
    class var ISteamClient_GetISteamInput: TISteamClient_GetUserInterface;
    { Bound @code(SteamAPI_ISteamClient_GetISteamParties) export (@nil if missing). }
    class var ISteamClient_GetISteamParties: TISteamClient_GetUserInterface;
    { Bound @code(SteamAPI_ISteamClient_GetISteamRemotePlay) export (@nil if missing). }
    class var ISteamClient_GetISteamRemotePlay: TISteamClient_GetUserInterface;

    { Platform file name of the redistributable: steam_api64.dll / steam_api.dll
      (Windows), libsteam_api.dylib (macOS), libsteam_api.so (Linux, Android). }
    class function DefaultLibraryName: string; static;

    { Where the library for the platform this program was compiled for lives
      inside the SDK's redistributable_bin folder, e.g. @code('win64/steam_api64.dll')
      or @code('linuxarm64/libsteam_api.so'); '' if Steam has none. Used in
      error messages so the user knows exactly which file to copy. }
    class function RedistributableName: string; static;

    { Compile-time target of this program, e.g. @code('macOS ARM64') or
      @code('Windows x86'). }
    class function BuildTarget: string; static;
    { How the running process relates to the machine, or '' when nothing
      applies or it cannot be told: on macOS @code('Rosetta 2') when an x64
      build is translated on Apple silicon; on Windows when an x86 / x64 build
      is emulated on ARM64 Windows or an x86 build runs under WOW64. }
    class function ProcessTranslation: string; static;
    { @link(BuildTarget) and @link(ProcessTranslation) as one log line, e.g.
      @code('macOS x64 build, running under Rosetta 2'). }
    class function PlatformDescription: string; static;

    { Loads the redistributable and binds the core exports.
      @param(APath  Explicit file; empty = @link(DefaultLibraryName), searched
        as described in @link(TSteamDynLib.CandidatePaths).)
      @raises(ESteamDynLibError  if the library cannot be loaded or a required
        export is missing.) }
    class procedure Load(const APath: string = ''); static;

    { Clears every binding, then unloads the library. Safe if not loaded. }
    class procedure Unload; static;

    { @true while the library is loaded. }
    class function IsLoaded: Boolean; static;

    { Address of any export, or @nil. }
    class function GetProc(const AName: string): Pointer; static;

    { Binds an export into a procedural variable, for plug-ins.
      @param(ARequired  @false = optional; a missing symbol leaves @nil.)
      @returns(@true if found.) }
    class function Bind(var AProc; const AName: string; ARequired: Boolean = True): Boolean; static;

    { The loaded library object (@nil when not loaded). }
    class function Lib: TSteamDynLib; static;

    { File the library was loaded from ('' when not loaded). }
    class function LibraryPath: string; static;

    { SDK generation of the loaded redistributable, judged by its exports:
      @code('1.65+') (has IsRunningOnSteamHardware, no IsRunningOnSteamDeck),
      @code('1.59-1.64') (has SteamAPI_InitFlat), @code('pre-1.59'), or
      '' when nothing is loaded. tools/check_redist.py applies the same test
      to the files in redistributable_bin. }
    class function SDKGeneration: string; static;

    { Exports that were looked up but not found. }
    class function MissingExports: TSteamStringArray; static;

    { Receives non-fatal library warnings. }
    class property OnWarning: TSteamDynLibWarningEvent read FOnWarning write FOnWarning;
  end;

  { Discovers which interface version strings the loaded redistributable was
    built against by scanning its binary for version literals such as
    @code(SteamUtils010) or @code(STEAMAPPS_INTERFACE_VERSION008).

    Each flat function in the redistributable is compiled against exactly one
    version of its interface, so following the binary - instead of a table
    copied from one header revision - keeps vtables in step.

    @longCode(#
    Versions.ScanFile(TSteamAPI.LibraryPath);
    Ver := Versions.Resolve('SteamUtils010');  // e.g. 'SteamUtils011' if that is what was found
    #) }
  TSteamInterfaceVersions = class
  private
    { Family (upper case) to highest version string found. }
    FMap: TDictionary<string, string>;
    { Extracts NUL-terminated identifier literals from a binary image. }
    procedure Scan(const ABytes: TBytes);
    { Records AToken if it looks like an interface version string. }
    procedure Consider(const AToken: string);
  public
    { Creates an empty version table. }
    constructor Create;
    { Releases everything this object owns. }
    destructor Destroy; override;
    { Forget all scan results. }
    procedure Clear;
    { Scans a library file. @returns(@false if the file could not be read.) }
    function ScanFile(const AFileName: string): Boolean;
    { Version to use for an interface family.
      @param(AFallback  A full version string, e.g. @code('SteamUtils010').
        Its family (@code(SteamUtils)) is looked up; AFallback is returned
        when the scan did not find that family.) }
    function Resolve(const AFallback: string): string;
    { @true if the scan found the family of AFallback. }
    function Contains(const AFallback: string): Boolean;
    { Family part, upper case: @code('SteamUtils010') -> @code('STEAMUTILS'). }
    class function FamilyOf(const AVersion: string): string; static;
    { Trailing three digits: @code('SteamUtils010') -> @code('010'). }
    class function NumberOf(const AVersion: string): string; static;
    { Number of families found. }
    function Count: Integer;
    { All detected version strings, sorted. }
    function ToArray: TSteamStringArray;
  end;

implementation

{$if defined(STEAMWORKS_WINDOWS)}
uses
  Windows;

type
  { IsWow64Process2 (Windows 10 1709+), looked up at run time. }
  TIsWow64Process2 = function(hProcess: THandle; out ProcessMachine: Word;
    out NativeMachine: Word): BOOL; stdcall;

const
  { IMAGE_FILE_MACHINE_ARM64 }
  MachineArm64 = $AA64;
{$elseif defined(STEAMWORKS_MACOS)}
{ libc sysctlbyname; used to ask whether the process is translated (Rosetta). }
function sysctlbyname(name: PAnsiChar; oldp: Pointer; oldlenp: PNativeUInt;
  newp: Pointer; newlen: NativeUInt): Integer; cdecl;
  external {$ifdef FPC}'c'{$else}'/usr/lib/libc.dylib'{$endif} name 'sysctlbyname';
{$endif}

{ TSteamAPI }

class function TSteamAPI.DefaultLibraryName: string;
begin
{$if defined(STEAMWORKS_WINDOWS)}
  {$ifdef STEAMWORKS_CPU64}
  Result := 'steam_api64.dll';
  {$else}
  Result := 'steam_api.dll';
  {$endif}
{$elseif defined(STEAMWORKS_MACOS)}
  Result := 'libsteam_api.dylib';
{$elseif defined(STEAMWORKS_LINUX) or defined(STEAMWORKS_ANDROID)}
  Result := 'libsteam_api.so';
{$else}
  Result := '';
{$endif}
end;

class function TSteamAPI.BuildTarget: string;
var
  OS, CPU: string;
begin
{$if defined(STEAMWORKS_WINDOWS)}
  OS := 'Windows';
{$elseif defined(STEAMWORKS_MACOS)}
  OS := 'macOS';
{$elseif defined(STEAMWORKS_ANDROID)}
  OS := 'Android';
{$elseif defined(STEAMWORKS_LINUX)}
  OS := 'Linux';
{$else}
  OS := 'unsupported OS';
{$endif}
{$if defined(STEAMWORKS_CPUARM64)}
  CPU := 'ARM64';
{$elseif defined(STEAMWORKS_CPU386)}
  CPU := 'x86';
{$elseif defined(STEAMWORKS_CPU64)}
  CPU := 'x64';
{$else}
  CPU := 'unknown CPU';
{$endif}
  Result := OS + ' ' + CPU;
end;

class function TSteamAPI.ProcessTranslation: string;
{$if defined(STEAMWORKS_WINDOWS)}
var
  Fn: TIsWow64Process2;
  ProcessMachine, NativeMachine: Word;
begin
  Result := '';
  Fn := TIsWow64Process2(GetProcAddress(GetModuleHandle('kernel32.dll'), 'IsWow64Process2'));
  if not Assigned(Fn) then
    Exit; // older Windows: cannot tell
  if not Fn(GetCurrentProcess, ProcessMachine, NativeMachine) then
    Exit;
  {$ifndef STEAMWORKS_CPUARM64}
  if NativeMachine = MachineArm64 then
    Exit('emulation on ARM64 Windows');
  {$endif}
  if ProcessMachine <> 0 then // IMAGE_FILE_MACHINE_UNKNOWN unless WOW64
    Result := 'WOW64 on 64-bit Windows';
end;
{$elseif defined(STEAMWORKS_MACOS)}
var
  Translated: Integer;
  Len: NativeUInt;
begin
  Result := '';
  Translated := 0;
  Len := SizeOf(Translated);
  // Fails (ENOENT) on Intel Macs, where nothing is translated
  if (sysctlbyname('sysctl.proc_translated', @Translated, @Len, nil, 0) = 0) and
     (Translated = 1) then
    Result := 'Rosetta 2';
end;
{$else}
begin
  Result := '';
end;
{$endif}

class function TSteamAPI.PlatformDescription: string;
var
  T: string;
begin
  Result := BuildTarget + ' build';
  T := ProcessTranslation;
  if T <> '' then
    Result := Result + ', running under ' + T;
end;

class function TSteamAPI.RedistributableName: string;
begin
{$if defined(STEAMWORKS_WINDOWS)}
  {$ifdef STEAMWORKS_CPU64}
  Result := 'win64/steam_api64.dll';
  {$else}
  Result := 'steam_api.dll';
  {$endif}
{$elseif defined(STEAMWORKS_MACOS)}
  Result := 'osx/libsteam_api.dylib';
{$elseif defined(STEAMWORKS_ANDROID)}
  {$ifdef STEAMWORKS_CPUARM64}
  Result := 'androidarm64/libsteam_api.so';
  {$else}
  Result := '';
  {$endif}
{$elseif defined(STEAMWORKS_LINUX)}
  {$if defined(STEAMWORKS_CPUARM64)}
  Result := 'linuxarm64/libsteam_api.so';
  {$elseif defined(STEAMWORKS_CPU64)}
  Result := 'linux64/libsteam_api.so';
  {$else}
  Result := 'linux32/libsteam_api.so';
  {$endif}
{$else}
  Result := '';
{$endif}
end;

class function TSteamAPI.IsLoaded: Boolean;
begin
  Result := FLib <> nil;
end;

class function TSteamAPI.Lib: TSteamDynLib;
begin
  Result := FLib;
end;

class function TSteamAPI.LibraryPath: string;
begin
  if FLib <> nil then
    Result := FLib.FileName
  else
    Result := '';
end;

class function TSteamAPI.GetProc(const AName: string): Pointer;
begin
  if FLib = nil then
    Result := nil
  else
    Result := FLib.Symbol(AName);
end;

class function TSteamAPI.Bind(var AProc; const AName: string; ARequired: Boolean): Boolean;
begin
  if FLib = nil then
  begin
    Pointer(AProc) := nil;
    Result := False;
  end
  else
    Result := FLib.Bind(AProc, AName, ARequired);
end;

class function TSteamAPI.SDKGeneration: string;
begin
  if FLib = nil then
    Result := ''
  else if FLib.HasSymbol('SteamAPI_ISteamUtils_IsRunningOnSteamHardware') and
          not FLib.HasSymbol('SteamAPI_ISteamUtils_IsRunningOnSteamDeck') then
    Result := '1.65+'
  else if FLib.HasSymbol('SteamAPI_InitFlat') then
    Result := '1.59-1.64'
  else
    Result := 'pre-1.59';
end;

class function TSteamAPI.MissingExports: TSteamStringArray;
var
  I: Integer;
begin
  if FLib = nil then
  begin
    SetLength(Result, 0);
    Exit;
  end;
  SetLength(Result, FLib.MissingSymbols.Count);
  for I := 0 to FLib.MissingSymbols.Count - 1 do
    Result[I] := FLib.MissingSymbols[I];
end;

class procedure TSteamAPI.Load(const APath: string);
var
  Name: string;
begin
  if FLib <> nil then
    Exit;
  if APath <> '' then
    Name := APath
  else
    Name := DefaultLibraryName;
  if Name = '' then
    raise ESteamDynLibError.Create('Steamworks is not available on this platform');
  FLib := TSteamDynLib.Load(Name, True);
  // Missing symbols silently return nil; BindAll decides what is required.
  FLib.SymbolErrorMode := semReturnNil;
  FLib.OnWarning := FOnWarning;
  try
    BindAll;
  except
    Unload;
    raise;
  end;
end;

class procedure TSteamAPI.Unload;
begin
  ClearAll;            // never leave pointers into unloaded code
  FreeAndNil(FLib);
end;

class procedure TSteamAPI.ClearAll;
begin
  SteamAPI_Init := nil;
  SteamAPI_InitSafe := nil;
  SteamAPI_InitFlat := nil;
  SteamInternal_SteamAPI_Init := nil;
  SteamAPI_Shutdown := nil;
  SteamAPI_RestartAppIfNecessary := nil;
  SteamAPI_ReleaseCurrentThreadMemory := nil;
  SteamAPI_WriteMiniDump := nil;
  SteamAPI_SetMiniDumpComment := nil;
  SteamAPI_RunCallbacks := nil;
  SteamAPI_IsSteamRunning := nil;
  SteamAPI_GetSteamInstallPath := nil;
  SteamAPI_SetTryCatchCallbacks := nil;
  SteamAPI_GetHSteamPipe := nil;
  SteamAPI_GetHSteamUser := nil;
  SteamAPI_ManualDispatch_Init := nil;
  SteamAPI_ManualDispatch_RunFrame := nil;
  SteamAPI_ManualDispatch_GetNextCallback := nil;
  SteamAPI_ManualDispatch_FreeLastCallback := nil;
  SteamAPI_ManualDispatch_GetAPICallResult := nil;
  SteamInternal_CreateInterface := nil;
  SteamInternal_FindOrCreateUserInterface := nil;
  SteamInternal_FindOrCreateGameServerInterface := nil;
  ISteamClient_CreateSteamPipe := nil;
  ISteamClient_BReleaseSteamPipe := nil;
  ISteamClient_ConnectToGlobalUser := nil;
  ISteamClient_CreateLocalUser := nil;
  ISteamClient_ReleaseUser := nil;
  ISteamClient_GetISteamUser := nil;
  ISteamClient_GetISteamGameServer := nil;
  ISteamClient_SetLocalIPBinding := nil;
  ISteamClient_GetISteamFriends := nil;
  ISteamClient_GetISteamUtils := nil;
  ISteamClient_GetISteamMatchmaking := nil;
  ISteamClient_GetISteamMatchmakingServers := nil;
  ISteamClient_GetISteamGenericInterface := nil;
  ISteamClient_GetISteamUserStats := nil;
  ISteamClient_GetISteamGameServerStats := nil;
  ISteamClient_GetISteamApps := nil;
  ISteamClient_GetISteamNetworking := nil;
  ISteamClient_GetISteamRemoteStorage := nil;
  ISteamClient_GetISteamScreenshots := nil;
  ISteamClient_GetISteamGameSearch := nil;
  ISteamClient_GetIPCCallCount := nil;
  ISteamClient_SetWarningMessageHook := nil;
  ISteamClient_BShutdownIfAllPipesClosed := nil;
  ISteamClient_GetISteamHTTP := nil;
  ISteamClient_GetISteamController := nil;
  ISteamClient_GetISteamUGC := nil;
  ISteamClient_GetISteamMusic := nil;
  ISteamClient_GetISteamMusicRemote := nil;
  ISteamClient_GetISteamHTMLSurface := nil;
  ISteamClient_GetISteamInventory := nil;
  ISteamClient_GetISteamVideo := nil;
  ISteamClient_GetISteamParentalSettings := nil;
  ISteamClient_GetISteamInput := nil;
  ISteamClient_GetISteamParties := nil;
  ISteamClient_GetISteamRemotePlay := nil;
end;

class procedure TSteamAPI.BindAll;

  procedure Req(var AProc; const AName: string);
  begin
    if not FLib.Bind(AProc, AName, False) then
      raise ESteamDynLibError.CreateFmt('Required Steamworks export "%s" was not found in %s',
        [AName, FLib.FileName]);
  end;

  procedure Opt(var AProc; const AName: string);
  begin
    FLib.Bind(AProc, AName, False);
  end;

begin
  // Initialisation - at least one must exist
  Opt(SteamAPI_InitFlat,           'SteamAPI_InitFlat');            // SDK 1.59+
  Opt(SteamInternal_SteamAPI_Init, 'SteamInternal_SteamAPI_Init');  // SDK 1.59+
  Opt(SteamAPI_InitSafe,           'SteamAPI_InitSafe');
  Opt(SteamAPI_Init,               'SteamAPI_Init');                // before 1.59
  if not (Assigned(SteamAPI_InitFlat) or Assigned(SteamInternal_SteamAPI_Init) or
          Assigned(SteamAPI_InitSafe) or Assigned(SteamAPI_Init)) then
    raise ESteamDynLibError.Create('No SteamAPI initialisation entry point in ' + FLib.FileName);

  Req(SteamAPI_Shutdown,                   'SteamAPI_Shutdown');
  Req(SteamAPI_RestartAppIfNecessary,      'SteamAPI_RestartAppIfNecessary');
  Req(SteamAPI_RunCallbacks,               'SteamAPI_RunCallbacks');
  Opt(SteamAPI_ReleaseCurrentThreadMemory, 'SteamAPI_ReleaseCurrentThreadMemory');
  Opt(SteamAPI_WriteMiniDump,              'SteamAPI_WriteMiniDump');      // Windows only
  Opt(SteamAPI_SetMiniDumpComment,         'SteamAPI_SetMiniDumpComment'); // Windows only
  Opt(SteamAPI_IsSteamRunning,             'SteamAPI_IsSteamRunning');
  Opt(SteamAPI_GetSteamInstallPath,        'SteamAPI_GetSteamInstallPath');
  Opt(SteamAPI_SetTryCatchCallbacks,       'SteamAPI_SetTryCatchCallbacks');

  Req(SteamAPI_GetHSteamPipe, 'SteamAPI_GetHSteamPipe');
  Req(SteamAPI_GetHSteamUser, 'SteamAPI_GetHSteamUser');

  Req(SteamAPI_ManualDispatch_Init,             'SteamAPI_ManualDispatch_Init');
  Req(SteamAPI_ManualDispatch_RunFrame,         'SteamAPI_ManualDispatch_RunFrame');
  Req(SteamAPI_ManualDispatch_GetNextCallback,  'SteamAPI_ManualDispatch_GetNextCallback');
  Req(SteamAPI_ManualDispatch_FreeLastCallback, 'SteamAPI_ManualDispatch_FreeLastCallback');
  Req(SteamAPI_ManualDispatch_GetAPICallResult, 'SteamAPI_ManualDispatch_GetAPICallResult');

  Req(SteamInternal_CreateInterface,                 'SteamInternal_CreateInterface');
  Req(SteamInternal_FindOrCreateUserInterface,       'SteamInternal_FindOrCreateUserInterface');
  Opt(SteamInternal_FindOrCreateGameServerInterface, 'SteamInternal_FindOrCreateGameServerInterface');

  // ISteamClient - all optional
  Opt(ISteamClient_CreateSteamPipe,      'SteamAPI_ISteamClient_CreateSteamPipe');
  Opt(ISteamClient_BReleaseSteamPipe,    'SteamAPI_ISteamClient_BReleaseSteamPipe');
  Opt(ISteamClient_ConnectToGlobalUser,  'SteamAPI_ISteamClient_ConnectToGlobalUser');
  Opt(ISteamClient_CreateLocalUser,      'SteamAPI_ISteamClient_CreateLocalUser');
  Opt(ISteamClient_ReleaseUser,          'SteamAPI_ISteamClient_ReleaseUser');
  Opt(ISteamClient_GetISteamUser,        'SteamAPI_ISteamClient_GetISteamUser');
  Opt(ISteamClient_GetISteamGameServer,  'SteamAPI_ISteamClient_GetISteamGameServer');
  Opt(ISteamClient_SetLocalIPBinding,    'SteamAPI_ISteamClient_SetLocalIPBinding');
  Opt(ISteamClient_GetISteamFriends,     'SteamAPI_ISteamClient_GetISteamFriends');
  Opt(ISteamClient_GetISteamUtils,       'SteamAPI_ISteamClient_GetISteamUtils');
  Opt(ISteamClient_GetISteamMatchmaking, 'SteamAPI_ISteamClient_GetISteamMatchmaking');
  Opt(ISteamClient_GetISteamMatchmakingServers, 'SteamAPI_ISteamClient_GetISteamMatchmakingServers');
  Opt(ISteamClient_GetISteamGenericInterface,   'SteamAPI_ISteamClient_GetISteamGenericInterface');
  Opt(ISteamClient_GetISteamUserStats,   'SteamAPI_ISteamClient_GetISteamUserStats');
  Opt(ISteamClient_GetISteamGameServerStats, 'SteamAPI_ISteamClient_GetISteamGameServerStats');
  Opt(ISteamClient_GetISteamApps,        'SteamAPI_ISteamClient_GetISteamApps');
  Opt(ISteamClient_GetISteamNetworking,  'SteamAPI_ISteamClient_GetISteamNetworking');
  Opt(ISteamClient_GetISteamRemoteStorage, 'SteamAPI_ISteamClient_GetISteamRemoteStorage');
  Opt(ISteamClient_GetISteamScreenshots, 'SteamAPI_ISteamClient_GetISteamScreenshots');
  Opt(ISteamClient_GetISteamGameSearch,  'SteamAPI_ISteamClient_GetISteamGameSearch');
  Opt(ISteamClient_GetIPCCallCount,      'SteamAPI_ISteamClient_GetIPCCallCount');
  Opt(ISteamClient_SetWarningMessageHook, 'SteamAPI_ISteamClient_SetWarningMessageHook');
  Opt(ISteamClient_BShutdownIfAllPipesClosed, 'SteamAPI_ISteamClient_BShutdownIfAllPipesClosed');
  Opt(ISteamClient_GetISteamHTTP,        'SteamAPI_ISteamClient_GetISteamHTTP');
  Opt(ISteamClient_GetISteamController,  'SteamAPI_ISteamClient_GetISteamController');
  Opt(ISteamClient_GetISteamUGC,         'SteamAPI_ISteamClient_GetISteamUGC');
  Opt(ISteamClient_GetISteamMusic,       'SteamAPI_ISteamClient_GetISteamMusic');
  Opt(ISteamClient_GetISteamMusicRemote, 'SteamAPI_ISteamClient_GetISteamMusicRemote');
  Opt(ISteamClient_GetISteamHTMLSurface, 'SteamAPI_ISteamClient_GetISteamHTMLSurface');
  Opt(ISteamClient_GetISteamInventory,   'SteamAPI_ISteamClient_GetISteamInventory');
  Opt(ISteamClient_GetISteamVideo,       'SteamAPI_ISteamClient_GetISteamVideo');
  Opt(ISteamClient_GetISteamParentalSettings, 'SteamAPI_ISteamClient_GetISteamParentalSettings');
  Opt(ISteamClient_GetISteamInput,       'SteamAPI_ISteamClient_GetISteamInput');
  Opt(ISteamClient_GetISteamParties,     'SteamAPI_ISteamClient_GetISteamParties');
  Opt(ISteamClient_GetISteamRemotePlay,  'SteamAPI_ISteamClient_GetISteamRemotePlay');
end;

{ TSteamInterfaceVersions }

constructor TSteamInterfaceVersions.Create;
begin
  inherited Create;
  FMap := TDictionary<string, string>.Create;
end;

destructor TSteamInterfaceVersions.Destroy;
begin
  FMap.Free;
  inherited;
end;

procedure TSteamInterfaceVersions.Clear;
begin
  FMap.Clear;
end;

function TSteamInterfaceVersions.Count: Integer;
begin
  Result := FMap.Count;
end;

function TSteamInterfaceVersions.ToArray: TSteamStringArray;
var
  L: TStringList;
  S: string;
  I: Integer;
begin
  L := TStringList.Create;
  try
    for S in FMap.Values do
      L.Add(S);
    L.Sort;
    SetLength(Result, L.Count);
    for I := 0 to L.Count - 1 do
      Result[I] := L[I];
  finally
    L.Free;
  end;
end;

class function TSteamInterfaceVersions.NumberOf(const AVersion: string): string;
begin
  if Length(AVersion) >= 3 then
    Result := Copy(AVersion, Length(AVersion) - 2, 3)
  else
    Result := '';
end;

class function TSteamInterfaceVersions.FamilyOf(const AVersion: string): string;
var
  I: Integer;
begin
  I := Length(AVersion);
  while (I > 0) and (AVersion[I] >= '0') and (AVersion[I] <= '9') do
    Dec(I);
  while (I > 0) and (AVersion[I] = '_') do
    Dec(I);
  Result := UpperCase(Copy(AVersion, 1, I));
end;

procedure TSteamInterfaceVersions.Consider(const AToken: string);
var
  Fam, Existing: string;
  Digits, I: Integer;
begin
  // <Steam|STEAM><identifier><exactly 3 digits>
  if (Length(AToken) < 8) or (Length(AToken) > 64) then
    Exit;
  if (Copy(AToken, 1, 5) <> 'Steam') and (Copy(AToken, 1, 5) <> 'STEAM') then
    Exit;
  if (Copy(AToken, 1, 9) = 'SteamAPI_') or (Copy(AToken, 1, 14) = 'SteamInternal_') then
    Exit; // export names, not interface version literals
  Digits := 0;
  for I := Length(AToken) downto 1 do
    if (AToken[I] >= '0') and (AToken[I] <= '9') then
      Inc(Digits)
    else
      Break;
  if Digits <> 3 then
    Exit;
  Fam := FamilyOf(AToken);
  if Fam = '' then
    Exit;
  if (not FMap.TryGetValue(Fam, Existing)) or (NumberOf(AToken) > NumberOf(Existing)) then
    FMap.AddOrSetValue(Fam, AToken);
end;

procedure TSteamInterfaceVersions.Scan(const ABytes: TBytes);

  function IsIdentChar(B: Byte): Boolean;
  begin
    Result := ((B >= Ord('A')) and (B <= Ord('Z'))) or
              ((B >= Ord('a')) and (B <= Ord('z'))) or
              ((B >= Ord('0')) and (B <= Ord('9'))) or (B = Ord('_'));
  end;

var
  I, Start, Len, J: Integer;
  Tok: string;
begin
  I := 0;
  Len := Length(ABytes);
  while I < Len do
  begin
    if IsIdentChar(ABytes[I]) then
    begin
      Start := I;
      while (I < Len) and IsIdentChar(ABytes[I]) do
        Inc(I);
      // Must be a NUL-terminated C string literal
      if (I < Len) and (ABytes[I] = 0) and (I - Start >= 8) and (I - Start <= 64) then
      begin
        SetLength(Tok, I - Start);
        for J := 0 to I - Start - 1 do
          Tok[J + 1] := Char(ABytes[Start + J]);
        Consider(Tok);
      end;
    end
    else
      Inc(I);
  end;
end;

function TSteamInterfaceVersions.ScanFile(const AFileName: string): Boolean;
var
  FS: TFileStream;
  Bytes: TBytes;
begin
  Result := False;
  if (AFileName = '') or not FileExists(AFileName) then
    Exit;
  try
    FS := TFileStream.Create(AFileName, fmOpenRead or fmShareDenyNone);
    try
      SetLength(Bytes, FS.Size);
      if Length(Bytes) > 0 then
        FS.ReadBuffer(Bytes[0], Length(Bytes));
    finally
      FS.Free;
    end;
    Scan(Bytes);
    Result := True;
  except
    on Exception do
      Result := False;
  end;
end;

function TSteamInterfaceVersions.Resolve(const AFallback: string): string;
begin
  if not FMap.TryGetValue(FamilyOf(AFallback), Result) then
    Result := AFallback;
end;

function TSteamInterfaceVersions.Contains(const AFallback: string): Boolean;
begin
  Result := FMap.ContainsKey(FamilyOf(AFallback));
end;

initialization

finalization
  TSteamAPI.Unload;

end.
