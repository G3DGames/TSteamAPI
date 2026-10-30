{ @abstract(Core Steamworks types shared by the core library and every plug-in.)

  Mirrors steam_api_common.h, steamclientpublic.h and steamtypes.h of the
  Steamworks SDK 1.65. Names follow the SDK (e.g. @code(HSteamPipe),
  @code(k_EUniversePublic)) so the Valve documentation applies directly.

  Struct layout is controlled by Steamworks.inc - every unit that declares
  SDK structs must include it. }
unit Steamworks.Types;

{$I Steamworks.inc}

interface

type
  // --- steamtypes.h ---------------------------------------------------------
  { Handle of a communication pipe to the Steam client. }
  HSteamPipe     = Int32;
  { Handle of a Steam user on a pipe. }
  HSteamUser     = Int32;
  { Pointer to an @link(HSteamPipe). }
  PHSteamPipe    = ^HSteamPipe;
  { Steam application id (your game is 2275430, Spacewar is 480). }
  AppId_t        = UInt32;
  { Steam depot id. }
  DepotId_t      = UInt32;
  { Unix time, seconds since 1970-01-01 UTC. }
  RTime32        = UInt32;
  { Handle of an asynchronous API call; see @link(TSteamCallbackDispatcher.AwaitCallResult). }
  SteamAPICall_t = UInt64;
  { 32-bit account part of a CSteamID. }
  AccountID_t    = UInt32;
  { Handle of an ISteamParties beacon. }
  PartyBeaconID_t = UInt64;
  { Handle of an auth session ticket. }
  HAuthTicket    = UInt32;

  { Raw 64-bit CSteamID as passed through the flat API. }
  uint64_steamid = UInt64;

const
  { Invalid @link(AppId_t). }
  k_uAppIdInvalid: AppId_t = 0;
  { Invalid @link(SteamAPICall_t); returned when an async call could not start. }
  k_uAPICallInvalid: SteamAPICall_t = 0;
  { Invalid @link(HAuthTicket). }
  k_HAuthTicketInvalid: HAuthTicket = 0;

type
  { Dynamic array of strings (portable replacement for TArray<string>). }
  TSteamStringArray = array of string;

  { Buffer filled by SteamAPI_InitFlat / SteamAPI_InitEx (SteamErrMsg). }
  TSteamErrMsg = array[0..1023] of AnsiChar;
  { Pointer to a @link(TSteamErrMsg). }
  PSteamErrMsg = ^TSteamErrMsg;

  // --- steam_api.h ----------------------------------------------------------
  { Result of SteamAPI_InitFlat / SteamInternal_SteamAPI_Init. }
  ESteamAPIInitResult = (
    k_ESteamAPIInitResult_OK              = 0,
    k_ESteamAPIInitResult_FailedGeneric   = 1, //< some other failure
    k_ESteamAPIInitResult_NoSteamClient   = 2, //< Steam client not running / cannot connect
    k_ESteamAPIInitResult_VersionMismatch = 3 //< Steam client too old for requested interfaces
  );

  // --- steamclientpublic.h --------------------------------------------------
  { Steam universe (environment) a client or id belongs to. }
  EUniverse = (
    k_EUniverseInvalid  = 0,
    k_EUniversePublic   = 1,
    k_EUniverseBeta     = 2,
    k_EUniverseInternal = 3,
    k_EUniverseDev      = 4,
    k_EUniverseMax      = 5
  );

  { Steam account type (steamclientpublic.h). }
  EAccountType = (
    k_EAccountTypeInvalid        = 0,
    k_EAccountTypeIndividual     = 1,
    k_EAccountTypeMultiseat      = 2,
    k_EAccountTypeGameServer     = 3,
    k_EAccountTypeAnonGameServer = 4,
    k_EAccountTypePending        = 5,
    k_EAccountTypeContentServer  = 6,
    k_EAccountTypeClan           = 7,
    k_EAccountTypeChat           = 8,
    k_EAccountTypeConsoleUser    = 9,
    k_EAccountTypeAnonUser       = 10,
    k_EAccountTypeMax            = 11
  );

  { Why an async API call failed (ISteamUtils::GetAPICallFailureReason). }
  ESteamAPICallFailure = (
    k_ESteamAPICallFailureNone               = -1,
    k_ESteamAPICallFailureSteamGone          = 0,
    k_ESteamAPICallFailureNetworkFailure     = 1,
    k_ESteamAPICallFailureInvalidHandle      = 2,
    k_ESteamAPICallFailureMismatchedCallback = 3
  );

  { Address family of a @link(SteamIPAddress_t). }
  ESteamIPType = (
    k_ESteamIPTypeIPv4 = 0,
    k_ESteamIPTypeIPv6 = 1
  );

  { SteamIPAddress_t - declared with #pragma pack(1) in the SDK. }
  SteamIPAddress_t = packed record
    case Integer of
      0: (m_rgubIPv6: array[0..15] of Byte; m_eType: ESteamIPType);
      1: (m_unIPv4: UInt32);
  end;
  { Pointer to a @link(SteamIPAddress_t); used for C++ reference parameters. }
  PSteamIPAddress_t = ^SteamIPAddress_t;

  { Signature for ISteamClient::SetWarningMessageHook. nSeverity: 0 = message, 1 = warning. }
  SteamAPIWarningMessageHook_t = procedure(nSeverity: Integer; pchDebugText: PAnsiChar); cdecl;

  // --- steam_api_common.h : manual dispatch ---------------------------------
  { Internal structure used in manual callback dispatch. }
  CallbackMsg_t = record
    { User the callback applies to. }
    m_hSteamUser: HSteamUser;
    { Callback id (k_iCallback of the payload struct). }
    m_iCallback: Int32;
    { Points to the callback struct. }
    m_pubParam: PByte;
    { Size in bytes of the struct at @link(m_pubParam). }
    m_cubParam: Int32;
  end;
  { Pointer to a @link(CallbackMsg_t). }
  PCallbackMsg_t = ^CallbackMsg_t;

  { Callback 703 - an asynchronous API call has completed. }
  SteamAPICallCompleted_t = record
    { The call that completed. }
    m_hAsyncCall: SteamAPICall_t;
    { k_iCallback of the call-result struct. }
    m_iCallback: Int32;
    { Size in bytes of the call-result struct. }
    m_cubParam: UInt32;
  end;
  { Pointer to a @link(SteamAPICallCompleted_t). }
  PSteamAPICallCompleted_t = ^SteamAPICallCompleted_t;

  { Callback 704 - Steam is shutting down. Empty struct in C++. }
  SteamShutdown_t = record
    { Placeholder: the C++ struct is empty (sizeof = 1). }
    _dummy: Byte;
  end;

  { Helper around a 64-bit CSteamID (account id, instance, type and universe
    packed into one UInt64). Converts implicitly to and from UInt64:

    @longCode(#
    var Id: TSteamID;
    Id := SomeFlatCallReturningUInt64(...);
    if Id.IsValid and (Id.AccountType = k_EAccountTypeIndividual) then
      Writeln(Id.AccountID);
    #)
    A packed record: the SDK declares CSteamID under #pragma pack(1), so inside
    callback structs it is only byte-aligned (offset 4 after a uint32, not 8). }
  TSteamID = packed record
    { The raw 64-bit CSteamID. }
    Value: UInt64;
    { TSteamID from a raw 64-bit value. }
    class function Create(AValue: UInt64): TSteamID; static; inline;
    { Account number (bits 0-31). }
    function AccountID: AccountID_t; inline;
    { Instance (bits 32-51). }
    function AccountInstance: UInt32; inline;
    { Account type (bits 52-55). }
    function AccountType: EAccountType; inline;
    { Universe (bits 56-63). }
    function Universe: EUniverse; inline;
    { @true if type and universe are in range (and an individual has a non-zero account id). }
    function IsValid: Boolean;
    { Decimal representation, as shown in Steam URLs. }
    function ToString: string;
    { Conversion between @code(TSteamID) and @code(UInt64). }
    class operator Implicit(const A: TSteamID): UInt64; inline;
    { Conversion between @code(TSteamID) and @code(UInt64). }
    class operator Implicit(A: UInt64): TSteamID; inline;
    { @true if both ids are the same. }
    class operator Equal(const A, B: TSteamID): Boolean; inline;
    { @true if the ids differ. }
    class operator NotEqual(const A, B: TSteamID): Boolean; inline;
  end;

const
  // --- Callback id bases (steam_api_common.h / isteamclient.h) -------------
  { Base callback id of the User interfaces (k_iSteamUserCallbacks). }
  k_iSteamUserCallbacks               = 100;
  { Base callback id of the GameServer interfaces (k_iSteamGameServerCallbacks). }
  k_iSteamGameServerCallbacks         = 200;
  { Base callback id of the Friends interfaces (k_iSteamFriendsCallbacks). }
  k_iSteamFriendsCallbacks            = 300;
  { Base callback id of the Billing interfaces (k_iSteamBillingCallbacks). }
  k_iSteamBillingCallbacks            = 400;
  { Base callback id of the Matchmaking interfaces (k_iSteamMatchmakingCallbacks). }
  k_iSteamMatchmakingCallbacks        = 500;
  { Base callback id of the ContentServer interfaces (k_iSteamContentServerCallbacks). }
  k_iSteamContentServerCallbacks      = 600;
  { Base callback id of the Utils interfaces (k_iSteamUtilsCallbacks). }
  k_iSteamUtilsCallbacks              = 700;
  { Base callback id of the Apps interfaces (k_iSteamAppsCallbacks). }
  k_iSteamAppsCallbacks               = 1000;
  { Base callback id of the UserStats interfaces (k_iSteamUserStatsCallbacks). }
  k_iSteamUserStatsCallbacks          = 1100;
  { Base callback id of the Networking interfaces (k_iSteamNetworkingCallbacks). }
  k_iSteamNetworkingCallbacks         = 1200;
  { Base callback id of the NetworkingSockets interfaces (k_iSteamNetworkingSocketsCallbacks). }
  k_iSteamNetworkingSocketsCallbacks  = 1220;
  { Base callback id of the NetworkingMessages interfaces (k_iSteamNetworkingMessagesCallbacks). }
  k_iSteamNetworkingMessagesCallbacks = 1250;
  { Base callback id of the NetworkingUtils interfaces (k_iSteamNetworkingUtilsCallbacks). }
  k_iSteamNetworkingUtilsCallbacks    = 1280;
  { Base callback id of the RemoteStorage interfaces (k_iSteamRemoteStorageCallbacks). }
  k_iSteamRemoteStorageCallbacks      = 1300;
  { Base callback id of the GameServerItems interfaces (k_iSteamGameServerItemsCallbacks). }
  k_iSteamGameServerItemsCallbacks    = 1500;
  { Base callback id of the GameCoordinator interfaces (k_iSteamGameCoordinatorCallbacks). }
  k_iSteamGameCoordinatorCallbacks    = 1700;
  { Base callback id of the GameServerStats interfaces (k_iSteamGameServerStatsCallbacks). }
  k_iSteamGameServerStatsCallbacks    = 1800;
  { Base callback id of the 2Async interfaces (k_iSteam2AsyncCallbacks). }
  k_iSteam2AsyncCallbacks             = 1900;
  { Base callback id of the GameStats interfaces (k_iSteamGameStatsCallbacks). }
  k_iSteamGameStatsCallbacks          = 2000;
  { Base callback id of the HTTP interfaces (k_iSteamHTTPCallbacks). }
  k_iSteamHTTPCallbacks               = 2100;
  { Base callback id of the Screenshots interfaces (k_iSteamScreenshotsCallbacks). }
  k_iSteamScreenshotsCallbacks        = 2300;
  { Base callback id of the StreamLauncher interfaces (k_iSteamStreamLauncherCallbacks). }
  k_iSteamStreamLauncherCallbacks     = 2600;
  { Base callback id of the Controller interfaces (k_iSteamControllerCallbacks). }
  k_iSteamControllerCallbacks         = 2800;
  { Base callback id of the UGC interfaces (k_iSteamUGCCallbacks). }
  k_iSteamUGCCallbacks                = 3400;
  { Base callback id of the StreamClient interfaces (k_iSteamStreamClientCallbacks). }
  k_iSteamStreamClientCallbacks       = 3500;
  { Base callback id of the Music interfaces (k_iSteamMusicCallbacks). }
  k_iSteamMusicCallbacks              = 4000;
  { Base callback id of the MusicRemote interfaces (k_iSteamMusicRemoteCallbacks). }
  k_iSteamMusicRemoteCallbacks        = 4100;
  { Base callback id of the GameNotification interfaces (k_iSteamGameNotificationCallbacks). }
  k_iSteamGameNotificationCallbacks   = 4400;
  { Base callback id of the HTMLSurface interfaces (k_iSteamHTMLSurfaceCallbacks). }
  k_iSteamHTMLSurfaceCallbacks        = 4500;
  { Base callback id of the Video interfaces (k_iSteamVideoCallbacks). }
  k_iSteamVideoCallbacks              = 4600;
  { Base callback id of the Inventory interfaces (k_iSteamInventoryCallbacks). }
  k_iSteamInventoryCallbacks          = 4700;
  { Base callback id of the ParentalSettings interfaces (k_iSteamParentalSettingsCallbacks). }
  k_iSteamParentalSettingsCallbacks   = 5000;
  { Base callback id of the GameSearch interfaces (k_iSteamGameSearchCallbacks). }
  k_iSteamGameSearchCallbacks         = 5200;
  { Base callback id of the Parties interfaces (k_iSteamPartiesCallbacks). }
  k_iSteamPartiesCallbacks            = 5300;
  { Base callback id of the STAR interfaces (k_iSteamSTARCallbacks). }
  k_iSteamSTARCallbacks               = 5500;
  { Base callback id of the RemotePlay interfaces (k_iSteamRemotePlayCallbacks). }
  k_iSteamRemotePlayCallbacks         = 5700;
  { Base callback id of the Chat interfaces (k_iSteamChatCallbacks). }
  k_iSteamChatCallbacks               = 5900;
  { Base callback id of the Timeline interfaces (k_iSteamTimelineCallbacks). }
  k_iSteamTimelineCallbacks           = 6000;

  // --- Core callback ids ----------------------------------------------------
  { Callback id of @link(SteamAPICallCompleted_t) (703). }
  SteamAPICallCompleted_t_k_iCallback = k_iSteamUtilsCallbacks + 3;
  { Callback id of @link(SteamShutdown_t) (704). }
  SteamShutdown_t_k_iCallback         = k_iSteamUtilsCallbacks + 4;

{ Diagnostic label for a callback id: the public interface range it falls in
  and its offset, e.g. 304 -> @code('Friends+4'), 703 -> @code('Utils+3').
  Ids of 1000000 and above are the Steam client's own internal callbacks,
  which manual dispatch also delivers; they are not in the public SDK headers
  and are labelled @code('internal').
  @param(ACallbackID  k_iCallback value.) }
function SteamCallbackGroupName(ACallbackID: Integer): string;

{ Human-readable text for an @link(ESteamAPIInitResult).
  @param(AResult  Value returned by SteamAPI_InitFlat.) }
function SteamInitResultToString(AResult: ESteamAPIInitResult): string;

implementation

uses
  SysUtils;

const
  (* Public callback ranges, highest base first (see the k_i...Callbacks
     constants), as two parallel arrays. Not an array of records: lib/ units
     use Steam's packing ({$ALIGN 4} outside Windows), which put the string
     field of such a record at offset 4 - a misaligned managed pointer in a
     typed constant. On Linux64 (Delphi 13) Format then read a bad pointer
     (access violation in WideFormatBuf) the first time a non-internal
     callback (704) was named. *)
  SteamCallbackBases: array[0..37] of Integer = (
    k_iSteamTimelineCallbacks,
    k_iSteamChatCallbacks,
    k_iSteamRemotePlayCallbacks,
    k_iSteamSTARCallbacks,
    k_iSteamPartiesCallbacks,
    k_iSteamGameSearchCallbacks,
    k_iSteamParentalSettingsCallbacks,
    k_iSteamInventoryCallbacks,
    k_iSteamVideoCallbacks,
    k_iSteamHTMLSurfaceCallbacks,
    k_iSteamGameNotificationCallbacks,
    k_iSteamMusicRemoteCallbacks,
    k_iSteamMusicCallbacks,
    k_iSteamStreamClientCallbacks,
    k_iSteamUGCCallbacks,
    k_iSteamControllerCallbacks,
    k_iSteamStreamLauncherCallbacks,
    k_iSteamScreenshotsCallbacks,
    k_iSteamHTTPCallbacks,
    k_iSteamGameStatsCallbacks,
    k_iSteam2AsyncCallbacks,
    k_iSteamGameServerStatsCallbacks,
    k_iSteamGameCoordinatorCallbacks,
    k_iSteamGameServerItemsCallbacks,
    k_iSteamRemoteStorageCallbacks,
    k_iSteamNetworkingUtilsCallbacks,
    k_iSteamNetworkingMessagesCallbacks,
    k_iSteamNetworkingSocketsCallbacks,
    k_iSteamNetworkingCallbacks,
    k_iSteamUserStatsCallbacks,
    k_iSteamAppsCallbacks,
    k_iSteamUtilsCallbacks,
    k_iSteamContentServerCallbacks,
    k_iSteamMatchmakingCallbacks,
    k_iSteamBillingCallbacks,
    k_iSteamFriendsCallbacks,
    k_iSteamGameServerCallbacks,
    k_iSteamUserCallbacks
  );
  { Group names, same order as @link(SteamCallbackBases). }
  SteamCallbackNames: array[0..37] of string = (
    'Timeline',
    'Chat',
    'RemotePlay',
    'STAR',
    'Parties',
    'GameSearch',
    'ParentalSettings',
    'Inventory',
    'Video',
    'HTMLSurface',
    'GameNotification',
    'MusicRemote',
    'Music',
    'StreamClient',
    'UGC',
    'Controller/Input',
    'StreamLauncher',
    'Screenshots',
    'HTTP',
    'GameStats',
    'Steam2Async',
    'GameServerStats',
    'GameCoordinator',
    'GameServerItems',
    'RemoteStorage',
    'NetworkingUtils',
    'NetworkingMessages',
    'NetworkingSockets',
    'Networking',
    'UserStats',
    'Apps',
    'Utils',
    'ContentServer',
    'Matchmaking',
    'Billing',
    'Friends',
    'GameServer',
    'User'
  );

function SteamCallbackGroupName(ACallbackID: Integer): string;
var
  I: Integer;
begin
  if ACallbackID >= 1000000 then
    Exit('internal');
  for I := Low(SteamCallbackBases) to High(SteamCallbackBases) do
    if ACallbackID >= SteamCallbackBases[I] then
      Exit(SteamCallbackNames[I] + '+' + IntToStr(ACallbackID - SteamCallbackBases[I]));
  Result := 'unknown';
end;

function SteamInitResultToString(AResult: ESteamAPIInitResult): string;
begin
  case AResult of
    k_ESteamAPIInitResult_OK:              Result := 'OK';
    k_ESteamAPIInitResult_FailedGeneric:   Result := 'Failed (generic)';
    k_ESteamAPIInitResult_NoSteamClient:   Result := 'Steam client not running or cannot be reached';
    k_ESteamAPIInitResult_VersionMismatch: Result := 'Steam client is out of date for the requested interfaces';
  else
    Result := Format('Unknown result (%d)', [Ord(AResult)]);
  end;
end;

{ TSteamID }

class function TSteamID.Create(AValue: UInt64): TSteamID;
begin
  Result.Value := AValue;
end;

function TSteamID.AccountID: AccountID_t;
begin
  Result := AccountID_t(Value and $FFFFFFFF);
end;

function TSteamID.AccountInstance: UInt32;
begin
  Result := UInt32((Value shr 32) and $FFFFF);
end;

function TSteamID.AccountType: EAccountType;
begin
  Result := EAccountType((Value shr 52) and $F);
end;

function TSteamID.Universe: EUniverse;
begin
  Result := EUniverse((Value shr 56) and $FF);
end;

function TSteamID.IsValid: Boolean;
var
  T: Integer;
  U: Integer;
begin
  T := Ord(AccountType);
  U := Ord(Universe);
  Result := (T > Ord(k_EAccountTypeInvalid)) and (T < Ord(k_EAccountTypeMax)) and
            (U > Ord(k_EUniverseInvalid)) and (U < Ord(k_EUniverseMax));
  if Result and (AccountType = k_EAccountTypeIndividual) then
    Result := AccountID <> 0;
end;

function TSteamID.ToString: string;
begin
  Result := IntToStr(Value);
end;

class operator TSteamID.Implicit(const A: TSteamID): UInt64;
begin
  Result := A.Value;
end;

class operator TSteamID.Implicit(A: UInt64): TSteamID;
begin
  Result.Value := A;
end;

class operator TSteamID.Equal(const A, B: TSteamID): Boolean;
begin
  Result := A.Value = B.Value;
end;

class operator TSteamID.NotEqual(const A, B: TSteamID): Boolean;
begin
  Result := A.Value <> B.Value;
end;

end.
