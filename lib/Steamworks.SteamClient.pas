{ @abstract(@link(TSteamClientIntf) - wrapper for ISteamClient (isteamclient.h).)

  ISteamClient is the root interface every other Steam interface is obtained
  from. Most games never need it directly (SteamAPI_InitFlat creates the
  global pipe and user), but it is exposed because plug-ins build on it and
  it is needed for advanced work: extra pipes, local users, the warning hook.

  Every method checks that its export exists and returns a neutral value
  (@nil / 0 / @false) otherwise, so one binary works across SDK revisions.

  @longCode(#
  if Steam.Client <> nil then
    Writeln('IPC calls so far: ', Steam.Client.GetIPCCallCount);
  #) }
unit Steamworks.SteamClient;

{$I Steamworks.inc}

interface

uses
  Steamworks.Types, Steamworks.API;

type
  { Delphi/FPC wrapper around an ISteamClient pointer. Created by
    @code(TSteamworks.Initialize); reach it as @code(Steam.Client). }
  TSteamClientIntf = class
  private
    { The ISteamClient pointer. }
    FSelf: Pointer;
    { Interface version string, see @link(Version). }
    FVersion: string;
    { Currently installed warning hook (kept so it is not lost). }
    FHook: SteamAPIWarningMessageHook_t;
    { Calls a GetISteamXxx(user, pipe, version) getter if it is bound. }
    function UserIntf(AFn: TISteamClient_GetUserInterface; AUser: HSteamUser; APipe: HSteamPipe;
      const AVersion: string): Pointer;
  public
    { @param(ASelf  ISteamClient* from SteamInternal_CreateInterface.)
      @param(AVersion  Version string it was created with.) }
    constructor Create(ASelf: Pointer; const AVersion: string);
    { Raw ISteamClient* (pass as "self" to SteamAPI_ISteamClient_* exports). }
    property Handle: Pointer read FSelf;
    { Interface version string this object was created with (e.g. "SteamClient023"). }
    property Version: string read FVersion;

    // --- pipes & users ------------------------------------------------------
    { Creates an extra communication pipe. 0 on failure. }
    function CreateSteamPipe: HSteamPipe;
    { Releases a pipe made by @link(CreateSteamPipe). @returns(@true on success.) }
    function ReleaseSteamPipe(APipe: HSteamPipe): Boolean;
    { Connects a pipe to the logged-in user. }
    function ConnectToGlobalUser(APipe: HSteamPipe): HSteamUser;
    { Creates a local user; also creates a pipe in APipe if it is 0. }
    function CreateLocalUser(var APipe: HSteamPipe; AAccountType: EAccountType): HSteamUser;
    { Releases a user made by @link(CreateLocalUser). }
    procedure ReleaseUser(APipe: HSteamPipe; AUser: HSteamUser);
    { Shuts the client connection down if no pipes remain open. }
    function ShutdownIfAllPipesClosed: Boolean;

    // --- misc ---------------------------------------------------------------
    { Binds Steam networking to a local address and port (call before using pipes). }
    procedure SetLocalIPBinding(const AIP: SteamIPAddress_t; APort: UInt16);
    { Number of IPC calls made since the last call (diagnostics). }
    function GetIPCCallCount: UInt32;
    { Installs a warning hook. Steam only calls it when the game is launched with -debug_steamapi. Pass nil to remove. }
    procedure SetWarningMessageHook(AHook: SteamAPIWarningMessageHook_t);

    // --- interface getters (raw pointers for plug-ins) -----------------------
    { Any user-level interface by version string - the generic route plug-ins use. }
    function GetGenericInterface(AUser: HSteamUser; APipe: HSteamPipe; const AVersion: string): Pointer;
    { Raw ISteamUser pointer for the given version, or @nil if unavailable. }
    function GetISteamUser(AUser: HSteamUser; APipe: HSteamPipe; const AVersion: string): Pointer;
    { Raw ISteamGameServer pointer for the given version, or @nil if unavailable. }
    function GetISteamGameServer(AUser: HSteamUser; APipe: HSteamPipe; const AVersion: string): Pointer;
    { Raw ISteamFriends pointer for the given version, or @nil if unavailable. }
    function GetISteamFriends(AUser: HSteamUser; APipe: HSteamPipe; const AVersion: string): Pointer;
    { Raw ISteamUtils pointer for the given version, or @nil if unavailable. }
    function GetISteamUtils(APipe: HSteamPipe; const AVersion: string): Pointer;
    { Raw ISteamMatchmaking pointer for the given version, or @nil if unavailable. }
    function GetISteamMatchmaking(AUser: HSteamUser; APipe: HSteamPipe; const AVersion: string): Pointer;
    { Raw ISteamMatchmakingServers pointer for the given version, or @nil if unavailable. }
    function GetISteamMatchmakingServers(AUser: HSteamUser; APipe: HSteamPipe; const AVersion: string): Pointer;
    { Raw ISteamUserStats pointer for the given version, or @nil if unavailable. }
    function GetISteamUserStats(AUser: HSteamUser; APipe: HSteamPipe; const AVersion: string): Pointer;
    { Raw ISteamGameServerStats pointer for the given version, or @nil if unavailable. }
    function GetISteamGameServerStats(AUser: HSteamUser; APipe: HSteamPipe; const AVersion: string): Pointer;
    { Raw ISteamApps pointer for the given version, or @nil if unavailable. }
    function GetISteamApps(AUser: HSteamUser; APipe: HSteamPipe; const AVersion: string): Pointer;
    { Raw ISteamNetworking pointer for the given version, or @nil if unavailable. }
    function GetISteamNetworking(AUser: HSteamUser; APipe: HSteamPipe; const AVersion: string): Pointer;
    { Raw ISteamRemoteStorage pointer for the given version, or @nil if unavailable. }
    function GetISteamRemoteStorage(AUser: HSteamUser; APipe: HSteamPipe; const AVersion: string): Pointer;
    { Raw ISteamScreenshots pointer for the given version, or @nil if unavailable. }
    function GetISteamScreenshots(AUser: HSteamUser; APipe: HSteamPipe; const AVersion: string): Pointer;
    { Raw ISteamGameSearch pointer for the given version, or @nil if unavailable. }
    function GetISteamGameSearch(AUser: HSteamUser; APipe: HSteamPipe; const AVersion: string): Pointer;
    { Raw ISteamHTTP pointer for the given version, or @nil if unavailable. }
    function GetISteamHTTP(AUser: HSteamUser; APipe: HSteamPipe; const AVersion: string): Pointer;
    { Raw ISteamController pointer for the given version, or @nil if unavailable. }
    function GetISteamController(AUser: HSteamUser; APipe: HSteamPipe; const AVersion: string): Pointer;
    { Raw ISteamUGC pointer for the given version, or @nil if unavailable. }
    function GetISteamUGC(AUser: HSteamUser; APipe: HSteamPipe; const AVersion: string): Pointer;
    { Raw ISteamMusic pointer for the given version, or @nil if unavailable. }
    function GetISteamMusic(AUser: HSteamUser; APipe: HSteamPipe; const AVersion: string): Pointer;
    { Raw ISteamMusicRemote pointer for the given version, or @nil if unavailable. }
    function GetISteamMusicRemote(AUser: HSteamUser; APipe: HSteamPipe; const AVersion: string): Pointer;
    { Raw ISteamHTMLSurface pointer for the given version, or @nil if unavailable. }
    function GetISteamHTMLSurface(AUser: HSteamUser; APipe: HSteamPipe; const AVersion: string): Pointer;
    { Raw ISteamInventory pointer for the given version, or @nil if unavailable. }
    function GetISteamInventory(AUser: HSteamUser; APipe: HSteamPipe; const AVersion: string): Pointer;
    { Raw ISteamVideo pointer for the given version, or @nil if unavailable. }
    function GetISteamVideo(AUser: HSteamUser; APipe: HSteamPipe; const AVersion: string): Pointer;
    { Raw ISteamParentalSettings pointer for the given version, or @nil if unavailable. }
    function GetISteamParentalSettings(AUser: HSteamUser; APipe: HSteamPipe; const AVersion: string): Pointer;
    { Raw ISteamInput pointer for the given version, or @nil if unavailable. }
    function GetISteamInput(AUser: HSteamUser; APipe: HSteamPipe; const AVersion: string): Pointer;
    { Raw ISteamParties pointer for the given version, or @nil if unavailable. }
    function GetISteamParties(AUser: HSteamUser; APipe: HSteamPipe; const AVersion: string): Pointer;
    { Raw ISteamRemotePlay pointer for the given version, or @nil if unavailable. }
    function GetISteamRemotePlay(AUser: HSteamUser; APipe: HSteamPipe; const AVersion: string): Pointer;
  end;

implementation

{ TSteamClientIntf }

constructor TSteamClientIntf.Create(ASelf: Pointer; const AVersion: string);
begin
  inherited Create;
  FSelf := ASelf;
  FVersion := AVersion;
end;

function TSteamClientIntf.UserIntf(AFn: TISteamClient_GetUserInterface; AUser: HSteamUser;
  APipe: HSteamPipe; const AVersion: string): Pointer;
var
  V: AnsiString;
begin
  if (FSelf = nil) or not Assigned(AFn) then
    Exit(nil);
  V := AnsiString(AVersion);
  Result := AFn(FSelf, AUser, APipe, PAnsiChar(V));
end;

function TSteamClientIntf.CreateSteamPipe: HSteamPipe;
begin
  if (FSelf <> nil) and Assigned(TSteamAPI.ISteamClient_CreateSteamPipe) then
    Result := TSteamAPI.ISteamClient_CreateSteamPipe(FSelf)
  else
    Result := 0;
end;

function TSteamClientIntf.ReleaseSteamPipe(APipe: HSteamPipe): Boolean;
begin
  Result := (FSelf <> nil) and Assigned(TSteamAPI.ISteamClient_BReleaseSteamPipe) and
            TSteamAPI.ISteamClient_BReleaseSteamPipe(FSelf, APipe);
end;

function TSteamClientIntf.ConnectToGlobalUser(APipe: HSteamPipe): HSteamUser;
begin
  if (FSelf <> nil) and Assigned(TSteamAPI.ISteamClient_ConnectToGlobalUser) then
    Result := TSteamAPI.ISteamClient_ConnectToGlobalUser(FSelf, APipe)
  else
    Result := 0;
end;

function TSteamClientIntf.CreateLocalUser(var APipe: HSteamPipe; AAccountType: EAccountType): HSteamUser;
begin
  if (FSelf <> nil) and Assigned(TSteamAPI.ISteamClient_CreateLocalUser) then
    Result := TSteamAPI.ISteamClient_CreateLocalUser(FSelf, @APipe, AAccountType)
  else
    Result := 0;
end;

procedure TSteamClientIntf.ReleaseUser(APipe: HSteamPipe; AUser: HSteamUser);
begin
  if (FSelf <> nil) and Assigned(TSteamAPI.ISteamClient_ReleaseUser) then
    TSteamAPI.ISteamClient_ReleaseUser(FSelf, APipe, AUser);
end;

function TSteamClientIntf.ShutdownIfAllPipesClosed: Boolean;
begin
  Result := (FSelf <> nil) and Assigned(TSteamAPI.ISteamClient_BShutdownIfAllPipesClosed) and
            TSteamAPI.ISteamClient_BShutdownIfAllPipesClosed(FSelf);
end;

procedure TSteamClientIntf.SetLocalIPBinding(const AIP: SteamIPAddress_t; APort: UInt16);
begin
  if (FSelf <> nil) and Assigned(TSteamAPI.ISteamClient_SetLocalIPBinding) then
    TSteamAPI.ISteamClient_SetLocalIPBinding(FSelf, @AIP, APort);
end;

function TSteamClientIntf.GetIPCCallCount: UInt32;
begin
  if (FSelf <> nil) and Assigned(TSteamAPI.ISteamClient_GetIPCCallCount) then
    Result := TSteamAPI.ISteamClient_GetIPCCallCount(FSelf)
  else
    Result := 0;
end;

procedure TSteamClientIntf.SetWarningMessageHook(AHook: SteamAPIWarningMessageHook_t);
begin
  FHook := AHook;
  if (FSelf <> nil) and Assigned(TSteamAPI.ISteamClient_SetWarningMessageHook) then
    TSteamAPI.ISteamClient_SetWarningMessageHook(FSelf, AHook);
end;

function TSteamClientIntf.GetISteamUtils(APipe: HSteamPipe; const AVersion: string): Pointer;
var
  V: AnsiString;
begin
  if (FSelf = nil) or not Assigned(TSteamAPI.ISteamClient_GetISteamUtils) then
    Exit(nil);
  V := AnsiString(AVersion);
  Result := TSteamAPI.ISteamClient_GetISteamUtils(FSelf, APipe, PAnsiChar(V));
end;

function TSteamClientIntf.GetGenericInterface(AUser: HSteamUser; APipe: HSteamPipe; const AVersion: string): Pointer;
begin
  Result := UserIntf(TSteamAPI.ISteamClient_GetISteamGenericInterface, AUser, APipe, AVersion);
end;

function TSteamClientIntf.GetISteamUser(AUser: HSteamUser; APipe: HSteamPipe; const AVersion: string): Pointer;
begin
  Result := UserIntf(TSteamAPI.ISteamClient_GetISteamUser, AUser, APipe, AVersion);
end;

function TSteamClientIntf.GetISteamGameServer(AUser: HSteamUser; APipe: HSteamPipe; const AVersion: string): Pointer;
begin
  Result := UserIntf(TSteamAPI.ISteamClient_GetISteamGameServer, AUser, APipe, AVersion);
end;

function TSteamClientIntf.GetISteamFriends(AUser: HSteamUser; APipe: HSteamPipe; const AVersion: string): Pointer;
begin
  Result := UserIntf(TSteamAPI.ISteamClient_GetISteamFriends, AUser, APipe, AVersion);
end;

function TSteamClientIntf.GetISteamMatchmaking(AUser: HSteamUser; APipe: HSteamPipe; const AVersion: string): Pointer;
begin
  Result := UserIntf(TSteamAPI.ISteamClient_GetISteamMatchmaking, AUser, APipe, AVersion);
end;

function TSteamClientIntf.GetISteamMatchmakingServers(AUser: HSteamUser; APipe: HSteamPipe; const AVersion: string): Pointer;
begin
  Result := UserIntf(TSteamAPI.ISteamClient_GetISteamMatchmakingServers, AUser, APipe, AVersion);
end;

function TSteamClientIntf.GetISteamUserStats(AUser: HSteamUser; APipe: HSteamPipe; const AVersion: string): Pointer;
begin
  Result := UserIntf(TSteamAPI.ISteamClient_GetISteamUserStats, AUser, APipe, AVersion);
end;

function TSteamClientIntf.GetISteamGameServerStats(AUser: HSteamUser; APipe: HSteamPipe; const AVersion: string): Pointer;
begin
  Result := UserIntf(TSteamAPI.ISteamClient_GetISteamGameServerStats, AUser, APipe, AVersion);
end;

function TSteamClientIntf.GetISteamApps(AUser: HSteamUser; APipe: HSteamPipe; const AVersion: string): Pointer;
begin
  Result := UserIntf(TSteamAPI.ISteamClient_GetISteamApps, AUser, APipe, AVersion);
end;

function TSteamClientIntf.GetISteamNetworking(AUser: HSteamUser; APipe: HSteamPipe; const AVersion: string): Pointer;
begin
  Result := UserIntf(TSteamAPI.ISteamClient_GetISteamNetworking, AUser, APipe, AVersion);
end;

function TSteamClientIntf.GetISteamRemoteStorage(AUser: HSteamUser; APipe: HSteamPipe; const AVersion: string): Pointer;
begin
  Result := UserIntf(TSteamAPI.ISteamClient_GetISteamRemoteStorage, AUser, APipe, AVersion);
end;

function TSteamClientIntf.GetISteamScreenshots(AUser: HSteamUser; APipe: HSteamPipe; const AVersion: string): Pointer;
begin
  Result := UserIntf(TSteamAPI.ISteamClient_GetISteamScreenshots, AUser, APipe, AVersion);
end;

function TSteamClientIntf.GetISteamGameSearch(AUser: HSteamUser; APipe: HSteamPipe; const AVersion: string): Pointer;
begin
  Result := UserIntf(TSteamAPI.ISteamClient_GetISteamGameSearch, AUser, APipe, AVersion);
end;

function TSteamClientIntf.GetISteamHTTP(AUser: HSteamUser; APipe: HSteamPipe; const AVersion: string): Pointer;
begin
  Result := UserIntf(TSteamAPI.ISteamClient_GetISteamHTTP, AUser, APipe, AVersion);
end;

function TSteamClientIntf.GetISteamController(AUser: HSteamUser; APipe: HSteamPipe; const AVersion: string): Pointer;
begin
  Result := UserIntf(TSteamAPI.ISteamClient_GetISteamController, AUser, APipe, AVersion);
end;

function TSteamClientIntf.GetISteamUGC(AUser: HSteamUser; APipe: HSteamPipe; const AVersion: string): Pointer;
begin
  Result := UserIntf(TSteamAPI.ISteamClient_GetISteamUGC, AUser, APipe, AVersion);
end;

function TSteamClientIntf.GetISteamMusic(AUser: HSteamUser; APipe: HSteamPipe; const AVersion: string): Pointer;
begin
  Result := UserIntf(TSteamAPI.ISteamClient_GetISteamMusic, AUser, APipe, AVersion);
end;

function TSteamClientIntf.GetISteamMusicRemote(AUser: HSteamUser; APipe: HSteamPipe; const AVersion: string): Pointer;
begin
  Result := UserIntf(TSteamAPI.ISteamClient_GetISteamMusicRemote, AUser, APipe, AVersion);
end;

function TSteamClientIntf.GetISteamHTMLSurface(AUser: HSteamUser; APipe: HSteamPipe; const AVersion: string): Pointer;
begin
  Result := UserIntf(TSteamAPI.ISteamClient_GetISteamHTMLSurface, AUser, APipe, AVersion);
end;

function TSteamClientIntf.GetISteamInventory(AUser: HSteamUser; APipe: HSteamPipe; const AVersion: string): Pointer;
begin
  Result := UserIntf(TSteamAPI.ISteamClient_GetISteamInventory, AUser, APipe, AVersion);
end;

function TSteamClientIntf.GetISteamVideo(AUser: HSteamUser; APipe: HSteamPipe; const AVersion: string): Pointer;
begin
  Result := UserIntf(TSteamAPI.ISteamClient_GetISteamVideo, AUser, APipe, AVersion);
end;

function TSteamClientIntf.GetISteamParentalSettings(AUser: HSteamUser; APipe: HSteamPipe; const AVersion: string): Pointer;
begin
  Result := UserIntf(TSteamAPI.ISteamClient_GetISteamParentalSettings, AUser, APipe, AVersion);
end;

function TSteamClientIntf.GetISteamInput(AUser: HSteamUser; APipe: HSteamPipe; const AVersion: string): Pointer;
begin
  Result := UserIntf(TSteamAPI.ISteamClient_GetISteamInput, AUser, APipe, AVersion);
end;

function TSteamClientIntf.GetISteamParties(AUser: HSteamUser; APipe: HSteamPipe; const AVersion: string): Pointer;
begin
  Result := UserIntf(TSteamAPI.ISteamClient_GetISteamParties, AUser, APipe, AVersion);
end;

function TSteamClientIntf.GetISteamRemotePlay(AUser: HSteamUser; APipe: HSteamPipe; const AVersion: string): Pointer;
begin
  Result := UserIntf(TSteamAPI.ISteamClient_GetISteamRemotePlay, AUser, APipe, AVersion);
end;

end.
