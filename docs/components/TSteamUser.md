# TSteamUser and TSteamUserPlugin (ISteamUser)

> **Generated** by `tools/gen_docs.py` from `lib/plugins/Steamworks.Plugin.User.pas` - do not edit.
> Hand-written text: `tools/doc_extras/User.md`. Steam's own descriptions are Valve's
> SDK comments, as in the generated units.

Unit: `Steamworks.Plugin.User` - linking it (a `uses` entry, or dropping a `TSteamUser`) enables the
plug-in. Steam interface: `ISteamUser` (SDK 1.65).

## Overview

The logged-on user: SteamID, logon state, Steam level, authentication
tickets, encrypted app tickets, voice and store / market helpers.

### Who is playing

```pascal
var
  U: TSteamUserPlugin;
begin
  U := SteamUser1.Plugin;
  if U.BLoggedOn then
    Log(Format('SteamID %s, level %d', [U.GetSteamID.ToString, U.GetPlayerSteamLevel]));
end;
```

`BLoggedOn` is `False` while Steam runs offline; most other interfaces then
still work from cached data. `OnSteamServersDisconnected` /
`OnSteamServersConnected` report changes.

### Authentication

* **Web API backend:** `GetAuthTicketForWebApi('your-identity')` -
  the ticket arrives in `OnGetTicketForWebApiResponse`; send it to your
  server, which validates it with Valve's Web API
  (`ISteamUserAuth/AuthenticateUserTicket`).
* **Peer / game server:** `GetAuthSessionTicket` (fills a buffer you pass;
  `OnGetAuthSessionTicketResponse` confirms), the other side calls
  `BeginAuthSession`; both end with `EndAuthSession` / `CancelAuthTicket`.
  The receiver gets `OnValidateAuthTicketResponse`.
* **Encrypted app tickets:** `RequestEncryptedAppTicketAsync`, then
  `GetEncryptedAppTicket` in the handler.

Tickets are binary buffers: these methods take `Pointer` + size, exactly as
in the SDK.

### Other

`GetUserDataFolder` (a buffer method) gives Steam's per-user folder for this
game - prefer Steam Cloud (ISteamRemoteStorage, a later plug-in) for saves.
Voice: `StartVoiceRecording`, `GetAvailableVoice`, `GetVoice`,
`DecompressVoice`, `StopVoiceRecording`.

## Contents

* [The component: TSteamUser](#the-component-tsteamuser)
  * [Events (15)](#events)
* [The plug-in: TSteamUserPlugin](#the-plug-in-tsteamuserplugin)
  * [Methods](#methods)
  * [Async methods](#async-methods)
  * [Properties](#properties)
* [Payload records](#payload-records)

## The component: TSteamUser

ISteamUser component: drop it next to a TSteamAPI (linked automatically at run time when the owner has exactly one, otherwise set SteamAPI). Its events are the ISteamUser callbacks; call the interface through `Plugin`.

| Member | Kind | Description |
|--------|------|-------------|
| `SteamAPI` | published property | The `TSteamAPI` this component belongs to. At run time a component whose owner has exactly one `TSteamAPI` links itself. |
| `Plugin` | public property | The `TSteamUserPlugin` for calls; `nil` while Steam is not running. |
| `Attached` | public property | `True` while the events are subscribed (Steam running, `SteamAPI` set). |
| `Attach` / `Detach` | public methods | Subscribe / remove the events by hand (normally automatic). |

Events run on the thread chosen by the root's `UpdateMode` / `Delivery` - the main
thread by default (see [GameEngineIntegration.md](../GameEngineIntegration.md)). Each event
checks that Steam's payload size equals the Pascal record's; a mismatch raises
`ESteamworksError` instead of handing over a wrong record. Call results of the same
struct reach the event too (unless an `...Async` call claimed them); failed call results
raise no event and are logged as warnings.

### Events

| Event | Callback | Payload | Description |
|-------|----------|---------|-------------|
| `OnSteamServersConnected` | 101 | [`SteamServersConnected_t`](#steamserversconnected_t) | Called when an authenticated connection to the Steam back-end has been established. This means the Steam client now has a working connection to the Steam servers. Usually this will have occurred before the game has launched, and should only be seen if the user has dropped connection due to a networking issue or a Steam server update. |
| `OnSteamServerConnectFailure` | 102 | [`SteamServerConnectFailure_t`](#steamserverconnectfailure_t) | called when a connection attempt has failed this will occur periodically if the Steam client is not connected, and has failed in it's retry to establish a connection. |
| `OnSteamServersDisconnected` | 103 | [`SteamServersDisconnected_t`](#steamserversdisconnected_t) | called if the client has lost connection to the Steam servers real-time services will be disabled until a matching SteamServersConnected_t has been posted. |
| `OnClientGameServerDeny` | 113 | [`ClientGameServerDeny_t`](#clientgameserverdeny_t) | Sent by the Steam server to the client telling it to disconnect from the specified game server, which it may be in the process of or already connected to. The game client should immediately disconnect upon receiving this message. This can usually occur if the user doesn't have rights to play on the game server. |
| `OnIPCFailure` | 117 | [`IPCFailure_t`](#ipcfailure_t) | called when the callback system for this client is in an error state (and has flushed pending callbacks) When getting this message the client should disconnect from Steam, reset any stored Steam state and reconnect. This usually occurs in the rare event the Steam client has some kind of fatal error. |
| `OnLicensesUpdated` | 125 | [`LicensesUpdated_t`](#licensesupdated_t) | Signaled whenever licenses change. |
| `OnValidateAuthTicketResponse` | 143 | [`ValidateAuthTicketResponse_t`](#validateauthticketresponse_t) | callback for BeginAuthSession. |
| `OnMicroTxnAuthorizationResponse` | 152 | [`MicroTxnAuthorizationResponse_t`](#microtxnauthorizationresponse_t) | called when a user has responded to a microtransaction authorization request. |
| `OnEncryptedAppTicketResponse` | 154 | [`EncryptedAppTicketResponse_t`](#encryptedappticketresponse_t) | Result from RequestEncryptedAppTicket. |
| `OnGetAuthSessionTicketResponse` | 163 | [`GetAuthSessionTicketResponse_t`](#getauthsessionticketresponse_t) | callback for GetAuthSessionTicket. |
| `OnGameWebCallback` | 164 | [`GameWebCallback_t`](#gamewebcallback_t) | sent to your game in response to a steam://gamewebcallback/ command. |
| `OnStoreAuthURLResponse` | 165 | [`StoreAuthURLResponse_t`](#storeauthurlresponse_t) | sent to your game in response to ISteamUser::RequestStoreAuthURL. |
| `OnMarketEligibilityResponse` | 166 | [`MarketEligibilityResponse_t`](#marketeligibilityresponse_t) | sent in response to ISteamUser::GetMarketEligibility. |
| `OnDurationControl` | 167 | [`DurationControl_t`](#durationcontrol_t) | sent for games with enabled anti indulgence / duration control, for enabled users. Lets the game know whether the user can keep playing or whether the game should exit, and returns info about remaining gameplay time. This callback is fired asynchronously in response to timers triggering. It is also fired in response to calls to GetDurationControl(). |
| `OnGetTicketForWebApiResponse` | 168 | [`GetTicketForWebApiResponse_t`](#getticketforwebapiresponse_t) | callback for GetTicketForWebApi. |

Handler signature (the IDE generates it when you double-click the event):

```pascal
procedure TForm1.SteamUser1SteamServersConnected(Sender: TObject; const AData: SteamServersConnected_t);
```

## The plug-in: TSteamUserPlugin

ISteamUser plug-in. Registered by linking the unit; find it with @code(Steam.FindPlugin(TSteamUserPlugin)).

Reach it through the component (`SteamUser1.Plugin`) or the core:

```pascal
P := TSteamUserPlugin(Steam.FindPlugin(TSteamUserPlugin));   // Delphi also: Steam.Plugin<TSteamUserPlugin>
if P <> nil then ...
```

Every flat export is bound as optional: calling a method whose export the loaded
Steam library lacks raises `ESteamworksError` naming the export (`Assigned(P.Flat.Xxx)`
tells beforehand). Method names follow Valve's flat API (`GetStatInt32`, not the C++
overload `GetStat`); `const char*` parameters are `string`, 64-bit Steam ids `TSteamID`,
single out-values `var`; buffers and NULL-able pointers stay `Pointer`.

### Methods

| Method | Summary |
|--------|---------|
| [`GetHSteamUser`](#gethsteamuser) | returns the HSteamUser this interface represents this is only used internally by the API, and by a few select interfaces that support multi-user. |
| [`BLoggedOn`](#bloggedon) | returns true if the Steam client current has a live connection to the Steam servers. If false, it means there is no active connection due to either a ... |
| [`GetSteamID`](#getsteamid) | returns the CSteamID of the account currently logged into the Steam client a CSteamID is a unique identifier for an account, and used to differentiate users ... |
| [`InitiateGameConnection_DEPRECATED`](#initiategameconnection_deprecated) | InitiateGameConnection() starts the state machine for authenticating the game client with the game server It is the client portion of a three-way handshake ... |
| [`TerminateGameConnection_DEPRECATED`](#terminategameconnection_deprecated) | notify of disconnect needs to occur when the game client leaves the specified game server, needs to match with the InitiateGameConnection() call DEPRECATED! ... |
| [`TrackAppUsageEvent`](#trackappusageevent) | used by only a few games to track usage events. |
| [`GetUserDataFolder`](#getuserdatafolder) | get the local storage folder for current Steam account to write application data, e.g. save games, configs etc. this will usually be something like ... |
| [`StartVoiceRecording`](#startvoicerecording) | Starts voice recording. Once started, use GetVoice() to get the data. |
| [`StopVoiceRecording`](#stopvoicerecording) | Stops voice recording. Because people often release push-to-talk keys early, the system will keep recording for a little bit after this function is called. ... |
| [`GetAvailableVoice`](#getavailablevoice) | Determine the size of captured audio data that is available from GetVoice. Most applications will only use compressed data and should ignore the other ... |
| [`GetVoice`](#getvoice) | Read captured audio data from the microphone buffer. This should be called at least once per frame, and preferably every few milliseconds, to keep the ... |
| [`DecompressVoice`](#decompressvoice) | Decodes the compressed voice data returned by GetVoice. The output data is raw single-channel 16-bit PCM audio. The decoder supports any sample rate from ... |
| [`GetVoiceOptimalSampleRate`](#getvoiceoptimalsamplerate) | This returns the native sample rate of the Steam voice decompressor; using this sample rate for DecompressVoice will perform the least CPU processing. ... |
| [`GetAuthSessionTicket`](#getauthsessionticket) | Retrieve ticket to be sent to the entity who wishes to authenticate you. pcbTicket retrieves the length of the actual ticket. SteamNetworkingIdentity is an ... |
| [`GetAuthTicketForWebApi`](#getauthticketforwebapi) | Request a ticket which will be used for webapi "ISteamUserAuth\AuthenticateUserTicket" pchIdentity is an optional input parameter to identify the service ... |
| [`BeginAuthSession`](#beginauthsession) | Authenticate ticket from entity steamID to be sure it is valid and isnt reused Registers for callbacks if the entity goes offline or cancels the ticket ( ... |
| [`EndAuthSession`](#endauthsession) | Stop tracking started by BeginAuthSession - called when no longer playing game with this entity. |
| [`CancelAuthTicket`](#cancelauthticket) | Cancel auth ticket from GetAuthSessionTicket, called when no longer playing game with the entity you gave the ticket to. |
| [`UserHasLicenseForApp`](#userhaslicenseforapp) | After receiving a user's authentication data, and passing it to BeginAuthSession, use this function to determine if the user owns downloadable content ... |
| [`BIsBehindNAT`](#bisbehindnat) | returns true if this users looks like they are behind a NAT device. Only valid once the user has connected to steam (i.e a SteamServersConnected_t has been ... |
| [`AdvertiseGame`](#advertisegame) | set data to be replicated to friends so that they can join your game CSteamID steamIDGameServer - the steamID of the game server, received from the game ... |
| [`RequestEncryptedAppTicket`](#requestencryptedappticket) | Requests a ticket encrypted with an app specific shared key pDataToInclude, cbDataToInclude will be encrypted into the ticket ( This is asynchronous, you ... |
| [`GetEncryptedAppTicket`](#getencryptedappticket) | Retrieves a finished ticket. If no ticket is available, or your buffer is too small, returns false. Upon exit, *pcbTicket will be either the size of the ... |
| [`GetGameBadgeLevel`](#getgamebadgelevel) | Trading Card badges data access if you only have one set of cards, the series will be 1 the user has can have two different badges for a series; the regular ... |
| [`GetPlayerSteamLevel`](#getplayersteamlevel) | gets the Steam Level of the user, as shown on their profile. |
| [`RequestStoreAuthURL`](#requeststoreauthurl) | Requests a URL which authenticates an in-game browser for store check-out, and then redirects to the specified URL. As long as the in-game browser accepts ... |
| [`BIsPhoneVerified`](#bisphoneverified) | gets whether the users phone number is verified. |
| [`BIsTwoFactorEnabled`](#bistwofactorenabled) | gets whether the user has two factor enabled on their account. |
| [`BIsPhoneIdentifying`](#bisphoneidentifying) | gets whether the users phone number is identifying. |
| [`BIsPhoneRequiringVerification`](#bisphonerequiringverification) | gets whether the users phone number is awaiting (re)verification. |
| [`GetMarketEligibility`](#getmarketeligibility) | Wraps `SteamAPI_ISteamUser_GetMarketEligibility`. Call result: `MarketEligibilityResponse_t` (`MarketEligibilityResponse_t_k_iCallback`). |
| [`GetDurationControl`](#getdurationcontrol) | Retrieves anti indulgence / duration control for current user. Call result: `DurationControl_t` (`DurationControl_t_k_iCallback`). |
| [`BSetDurationControlOnlineState`](#bsetdurationcontrolonlinestate) | Advise steam china duration control system about the online state of the game. This will prevent offline gameplay time from counting against a user's ... |

#### GetHSteamUser

```pascal
function GetHSteamUser: HSteamUser;
```

returns the HSteamUser this interface represents this is only used internally by the API, and by a few select interfaces that support multi-user.

#### BLoggedOn

```pascal
function BLoggedOn: Boolean;
```

returns true if the Steam client current has a live connection to the Steam servers. If false, it means there is no active connection due to either a networking issue on the local machine, or the Steam server is down/busy. The Steam client will automatically be trying to recreate the connection as often as possible.

#### GetSteamID

```pascal
function GetSteamID: TSteamID;
```

returns the CSteamID of the account currently logged into the Steam client a CSteamID is a unique identifier for an account, and used to differentiate users in all parts of the Steamworks API.

#### InitiateGameConnection_DEPRECATED

```pascal
function InitiateGameConnection_DEPRECATED(pAuthBlob: Pointer; cbMaxAuthBlob: Integer; const steamIDGameServer: TSteamID; unIPServer: UInt32; usPortServer: UInt16; bSecure: Boolean): Integer;
```

InitiateGameConnection() starts the state machine for authenticating the game client with the game server It is the client portion of a three-way handshake between the client, the game server, and the steam servers Parameters: void *pAuthBlob - a pointer to empty memory that will be filled in with the authentication token. int cbMaxAuthBlob - the number of bytes of allocated memory in pBlob. Should be at least 2048 bytes. CSteamID steamIDGameServer - the steamID of the game server, received from the game server by the client CGameID gameID - the ID of the current game. For games without mods, this is just CGameID( <appID> ) uint32 unIPServer, uint16 usPortServer - the IP address of the game server bool bSecure - whether or not the client thinks that the game server is reporting itself as secure (i.e. VAC is running) return value - returns the number of bytes written to pBlob. If the return is 0, then the buffer passed in was too small, and the call has failed The contents of pBlob should then be sent to the game server, for it to use to complete the authentication process. DEPRECATED! This function will be removed from the SDK in an upcoming version. Please migrate to BeginAuthSession and related functions.

#### TerminateGameConnection_DEPRECATED

```pascal
procedure TerminateGameConnection_DEPRECATED(unIPServer: UInt32; usPortServer: UInt16);
```

notify of disconnect needs to occur when the game client leaves the specified game server, needs to match with the InitiateGameConnection() call DEPRECATED! This function will be removed from the SDK in an upcoming version. Please migrate to BeginAuthSession and related functions.

#### TrackAppUsageEvent

```pascal
procedure TrackAppUsageEvent(gameID: UInt64; eAppUsageEvent: Integer; const pchExtraInfo: string);
```

used by only a few games to track usage events.

#### GetUserDataFolder

```pascal
function GetUserDataFolder(pchBuffer: PAnsiChar; cubBuffer: Integer): Boolean;
```

get the local storage folder for current Steam account to write application data, e.g. save games, configs etc. this will usually be something like "C:\Progam Files\Steam\userdata\<SteamID>\<AppID>\local".

#### StartVoiceRecording

```pascal
procedure StartVoiceRecording;
```

Starts voice recording. Once started, use GetVoice() to get the data.

#### StopVoiceRecording

```pascal
procedure StopVoiceRecording;
```

Stops voice recording. Because people often release push-to-talk keys early, the system will keep recording for a little bit after this function is called. GetVoice() should continue to be called until it returns k_eVoiceResultNotRecording.

#### GetAvailableVoice

```pascal
function GetAvailableVoice(var pcbCompressed: UInt32; var pcbUncompressed_Deprecated: UInt32; nUncompressedVoiceDesiredSampleRate_Deprecated: UInt32): EVoiceResult;
```

Determine the size of captured audio data that is available from GetVoice. Most applications will only use compressed data and should ignore the other parameters, which exist primarily for backwards compatibility. See comments below for further explanation of "uncompressed" data.

#### GetVoice

```pascal
function GetVoice(bWantCompressed: Boolean; pDestBuffer: Pointer; cbDestBufferSize: UInt32; var nBytesWritten: UInt32; bWantUncompressed_Deprecated: Boolean; pUncompressedDestBuffer_Deprecated: Pointer; cbUncompressedDestBufferSize_Deprecated: UInt32; var nUncompressBytesWritten_Deprecated: UInt32; nUncompressedVoiceDesiredSampleRate_Deprecated: UInt32): EVoiceResult;
```

Read captured audio data from the microphone buffer. This should be called at least once per frame, and preferably every few milliseconds, to keep the microphone input delay as low as possible. Most applications will only use compressed data and should pass NULL/zero for the "uncompressed" parameters. Compressed data can be transmitted by your application and decoded into raw using the DecompressVoice function below.

#### DecompressVoice

```pascal
function DecompressVoice(pCompressed: Pointer; cbCompressed: UInt32; pDestBuffer: Pointer; cbDestBufferSize: UInt32; var nBytesWritten: UInt32; nDesiredSampleRate: UInt32): EVoiceResult;
```

Decodes the compressed voice data returned by GetVoice. The output data is raw single-channel 16-bit PCM audio. The decoder supports any sample rate from 11025 to 48000; see GetVoiceOptimalSampleRate() below for details. If the output buffer is not large enough, then *nBytesWritten will be set to the required buffer size, and k_EVoiceResultBufferTooSmall is returned. It is suggested to start with a 20kb buffer and reallocate as necessary.

#### GetVoiceOptimalSampleRate

```pascal
function GetVoiceOptimalSampleRate: UInt32;
```

This returns the native sample rate of the Steam voice decompressor; using this sample rate for DecompressVoice will perform the least CPU processing. However, the final audio quality will depend on how well the audio device (and/or your application's audio output SDK) deals with lower sample rates. You may find that you get the best audio output quality when you ignore this function and use the native sample rate of your audio output device, which is usually 48000 or 44100.

#### GetAuthSessionTicket

```pascal
function GetAuthSessionTicket(pTicket: Pointer; cbMaxTicket: Integer; var pcbTicket: UInt32; pSteamNetworkingIdentity: Pointer): HAuthTicket;
```

Retrieve ticket to be sent to the entity who wishes to authenticate you. pcbTicket retrieves the length of the actual ticket. SteamNetworkingIdentity is an optional input parameter to hold the public IP address or SteamID of the entity you are connecting to if an IP address is passed Steam will only allow the ticket to be used by an entity with that IP address if a Steam ID is passed Steam will only allow the ticket to be used by that Steam ID not to be used for "ISteamUserAuth\AuthenticateUserTicket" - it will fail.

#### GetAuthTicketForWebApi

```pascal
function GetAuthTicketForWebApi(const pchIdentity: string): HAuthTicket;
```

Request a ticket which will be used for webapi "ISteamUserAuth\AuthenticateUserTicket" pchIdentity is an optional input parameter to identify the service the ticket will be sent to the ticket will be returned in callback GetTicketForWebApiResponse_t.

#### BeginAuthSession

```pascal
function BeginAuthSession(pAuthTicket: Pointer; cbAuthTicket: Integer; const steamID: TSteamID): EBeginAuthSessionResult;
```

Authenticate ticket from entity steamID to be sure it is valid and isnt reused Registers for callbacks if the entity goes offline or cancels the ticket ( see ValidateAuthTicketResponse_t callback and EAuthSessionResponse ).

#### EndAuthSession

```pascal
procedure EndAuthSession(const steamID: TSteamID);
```

Stop tracking started by BeginAuthSession - called when no longer playing game with this entity.

#### CancelAuthTicket

```pascal
procedure CancelAuthTicket(AHAuthTicket: HAuthTicket);
```

Cancel auth ticket from GetAuthSessionTicket, called when no longer playing game with the entity you gave the ticket to.

#### UserHasLicenseForApp

```pascal
function UserHasLicenseForApp(const steamID: TSteamID; appID: AppId_t): EUserHasLicenseForAppResult;
```

After receiving a user's authentication data, and passing it to BeginAuthSession, use this function to determine if the user owns downloadable content specified by the provided AppID.

#### BIsBehindNAT

```pascal
function BIsBehindNAT: Boolean;
```

returns true if this users looks like they are behind a NAT device. Only valid once the user has connected to steam (i.e a SteamServersConnected_t has been issued) and may not catch all forms of NAT.

#### AdvertiseGame

```pascal
procedure AdvertiseGame(const steamIDGameServer: TSteamID; unIPServer: UInt32; usPortServer: UInt16);
```

set data to be replicated to friends so that they can join your game CSteamID steamIDGameServer - the steamID of the game server, received from the game server by the client uint32 unIPServer, uint16 usPortServer - the IP address of the game server.

#### RequestEncryptedAppTicket

```pascal
function RequestEncryptedAppTicket(pDataToInclude: Pointer; cbDataToInclude: Integer): SteamAPICall_t;
```

Requests a ticket encrypted with an app specific shared key pDataToInclude, cbDataToInclude will be encrypted into the ticket ( This is asynchronous, you must wait for the ticket to be completed by the server ). Call result: `EncryptedAppTicketResponse_t` (`EncryptedAppTicketResponse_t_k_iCallback`).

#### GetEncryptedAppTicket

```pascal
function GetEncryptedAppTicket(pTicket: Pointer; cbMaxTicket: Integer; var pcbTicket: UInt32): Boolean;
```

Retrieves a finished ticket. If no ticket is available, or your buffer is too small, returns false. Upon exit, *pcbTicket will be either the size of the ticket copied into your buffer (if true was returned), or the size needed (if false was returned). To determine the proper size of the ticket, you can pass pTicket=NULL and cbMaxTicket=0; if a ticket is available, *pcbTicket will contain the size needed, otherwise it will be zero.

#### GetGameBadgeLevel

```pascal
function GetGameBadgeLevel(nSeries: Integer; bFoil: Boolean): Integer;
```

Trading Card badges data access if you only have one set of cards, the series will be 1 the user has can have two different badges for a series; the regular (max level 5) and the foil (max level 1).

#### GetPlayerSteamLevel

```pascal
function GetPlayerSteamLevel: Integer;
```

gets the Steam Level of the user, as shown on their profile.

#### RequestStoreAuthURL

```pascal
function RequestStoreAuthURL(const pchRedirectURL: string): SteamAPICall_t;
```

Requests a URL which authenticates an in-game browser for store check-out, and then redirects to the specified URL. As long as the in-game browser accepts and handles session cookies, Steam microtransaction checkout pages will automatically recognize the user instead of presenting a login page. The result of this API call will be a StoreAuthURLResponse_t callback. NOTE: The URL has a very short lifetime to prevent history-snooping attacks, so you should only call this API when you are about to launch the browser, or else immediately navigate to the result URL using a hidden browser window. NOTE 2: The resulting authorization cookie has an expiration time of one day, so it would be a good idea to request and visit a new auth URL every 12 hours. Call result: `StoreAuthURLResponse_t` (`StoreAuthURLResponse_t_k_iCallback`).

#### BIsPhoneVerified

```pascal
function BIsPhoneVerified: Boolean;
```

gets whether the users phone number is verified.

#### BIsTwoFactorEnabled

```pascal
function BIsTwoFactorEnabled: Boolean;
```

gets whether the user has two factor enabled on their account.

#### BIsPhoneIdentifying

```pascal
function BIsPhoneIdentifying: Boolean;
```

gets whether the users phone number is identifying.

#### BIsPhoneRequiringVerification

```pascal
function BIsPhoneRequiringVerification: Boolean;
```

gets whether the users phone number is awaiting (re)verification.

#### GetMarketEligibility

```pascal
function GetMarketEligibility: SteamAPICall_t;
```

Wraps `SteamAPI_ISteamUser_GetMarketEligibility`. Call result: `MarketEligibilityResponse_t` (`MarketEligibilityResponse_t_k_iCallback`).

#### GetDurationControl

```pascal
function GetDurationControl: SteamAPICall_t;
```

Retrieves anti indulgence / duration control for current user. Call result: `DurationControl_t` (`DurationControl_t_k_iCallback`).

#### BSetDurationControlOnlineState

```pascal
function BSetDurationControlOnlineState(eNewState: EDurationControlOnlineState): Boolean;
```

Advise steam china duration control system about the online state of the game. This will prevent offline gameplay time from counting against a user's playtime limits.

### Async methods

Each `...Async` method starts the call and registers `AHandler` for its result
(`procedure(const AData: TSteamCallbackData; AIOFailure: Boolean) of object`). The
handler runs once, on the delivery thread, with the result record in `AData`
(`AData.CopyTo(Rec, SizeOf(Rec))`); its object owns the registration - call
`Steam.Dispatcher.RemoveOwner(Self)` in that object's destructor. The plain method of
the same name returns the `SteamAPICall_t` instead, and its result reaches the
component's event.

#### RequestEncryptedAppTicketAsync

```pascal
function RequestEncryptedAppTicketAsync(pDataToInclude: Pointer; cbDataToInclude: Integer; AHandler: TSteamCallResultEvent): SteamAPICall_t;
```

Calls `RequestEncryptedAppTicket` and registers AHandler for its result (`EncryptedAppTicketResponse_t`). The handler's object owns the registration (remove it with Steam.Dispatcher.RemoveOwner). Returns: (The call handle, or k_uAPICallInvalid when Steam refused the call.)

#### RequestStoreAuthURLAsync

```pascal
function RequestStoreAuthURLAsync(const pchRedirectURL: string; AHandler: TSteamCallResultEvent): SteamAPICall_t;
```

Calls `RequestStoreAuthURL` and registers AHandler for its result (`StoreAuthURLResponse_t`). The handler's object owns the registration (remove it with Steam.Dispatcher.RemoveOwner). Returns: (The call handle, or k_uAPICallInvalid when Steam refused the call.)

#### GetMarketEligibilityAsync

```pascal
function GetMarketEligibilityAsync(AHandler: TSteamCallResultEvent): SteamAPICall_t;
```

Calls `GetMarketEligibility` and registers AHandler for its result (`MarketEligibilityResponse_t`). The handler's object owns the registration (remove it with Steam.Dispatcher.RemoveOwner). Returns: (The call handle, or k_uAPICallInvalid when Steam refused the call.)

#### GetDurationControlAsync

```pascal
function GetDurationControlAsync(AHandler: TSteamCallResultEvent): SteamAPICall_t;
```

Calls `GetDurationControl` and registers AHandler for its result (`DurationControl_t`). The handler's object owns the registration (remove it with Steam.Dispatcher.RemoveOwner). Returns: (The call handle, or k_uAPICallInvalid when Steam refused the call.)

### Properties

| Property | Description |
|----------|-------------|
| `Handle: Pointer` | The raw ISteamUser pointer (first argument of every `Flat` export). |
| `Flat: TSteamUserFlat` | The bound flat exports, for calls the methods do not cover. |

## Payload records

Declared in `Steamworks.SDKTypes` (generated from the SDK headers; layouts verified
against the C headers for Win64, Win32, Linux64 and macOS ARM64).

### SteamServersConnected_t

Callback id 101 (`SteamServersConnected_t_k_iCallback`).

| Field | C declaration |
|-------|---------------|
| `_dummy: Byte` | Placeholder: the C++ struct is empty (sizeof = 1). |

### SteamServerConnectFailure_t

Callback id 102 (`SteamServerConnectFailure_t_k_iCallback`).

| Field | C declaration |
|-------|---------------|
| `m_eResult: EResult` | C field `EResult m_eResult`. |
| `m_bStillRetrying: Boolean` | C field `bool m_bStillRetrying`. |

### SteamServersDisconnected_t

Callback id 103 (`SteamServersDisconnected_t_k_iCallback`).

| Field | C declaration |
|-------|---------------|
| `m_eResult: EResult` | C field `EResult m_eResult`. |

### ClientGameServerDeny_t

Callback id 113 (`ClientGameServerDeny_t_k_iCallback`).

| Field | C declaration |
|-------|---------------|
| `m_uAppID: UInt32` | C field `uint32 m_uAppID`. |
| `m_unGameServerIP: UInt32` | C field `uint32 m_unGameServerIP`. |
| `m_usGameServerPort: UInt16` | C field `uint16 m_usGameServerPort`. |
| `m_bSecure: UInt16` | C field `uint16 m_bSecure`. |
| `m_uReason: UInt32` | C field `uint32 m_uReason`. |

### IPCFailure_t

Callback id 117 (`IPCFailure_t_k_iCallback`).

| Field | C declaration |
|-------|---------------|
| `m_eFailureType: UInt8` | C field `uint8 m_eFailureType`. |

### LicensesUpdated_t

Callback id 125 (`LicensesUpdated_t_k_iCallback`).

| Field | C declaration |
|-------|---------------|
| `_dummy: Byte` | Placeholder: the C++ struct is empty (sizeof = 1). |

### ValidateAuthTicketResponse_t

Callback id 143 (`ValidateAuthTicketResponse_t_k_iCallback`).

| Field | C declaration |
|-------|---------------|
| `m_SteamID: TSteamID` | C field `CSteamID m_SteamID`. |
| `m_eAuthSessionResponse: EAuthSessionResponse` | C field `EAuthSessionResponse m_eAuthSessionResponse`. |
| `m_OwnerSteamID: TSteamID` | C field `CSteamID m_OwnerSteamID`. |

### MicroTxnAuthorizationResponse_t

Callback id 152 (`MicroTxnAuthorizationResponse_t_k_iCallback`).

| Field | C declaration |
|-------|---------------|
| `m_unAppID: UInt32` | C field `uint32 m_unAppID`. |
| `m_ulOrderID: UInt64` | C field `uint64 m_ulOrderID`. |
| `m_bAuthorized: UInt8` | C field `uint8 m_bAuthorized`. |

### EncryptedAppTicketResponse_t

Callback id 154 (`EncryptedAppTicketResponse_t_k_iCallback`).

| Field | C declaration |
|-------|---------------|
| `m_eResult: EResult` | C field `EResult m_eResult`. |

### GetAuthSessionTicketResponse_t

Callback id 163 (`GetAuthSessionTicketResponse_t_k_iCallback`).

| Field | C declaration |
|-------|---------------|
| `m_hAuthTicket: HAuthTicket` | C field `HAuthTicket m_hAuthTicket`. |
| `m_eResult: EResult` | C field `EResult m_eResult`. |

### GameWebCallback_t

Callback id 164 (`GameWebCallback_t_k_iCallback`).

| Field | C declaration |
|-------|---------------|
| `m_szURL: array[0..255] of AnsiChar` | C field `char [256] m_szURL`. |

### StoreAuthURLResponse_t

Callback id 165 (`StoreAuthURLResponse_t_k_iCallback`).

| Field | C declaration |
|-------|---------------|
| `m_szURL: array[0..511] of AnsiChar` | C field `char [512] m_szURL`. |

### MarketEligibilityResponse_t

Callback id 166 (`MarketEligibilityResponse_t_k_iCallback`).

| Field | C declaration |
|-------|---------------|
| `m_bAllowed: Boolean` | C field `bool m_bAllowed`. |
| `m_eNotAllowedReason: EMarketNotAllowedReasonFlags` | C field `EMarketNotAllowedReasonFlags m_eNotAllowedReason`. |
| `m_rtAllowedAtTime: RTime32` | C field `RTime32 m_rtAllowedAtTime`. |
| `m_cdaySteamGuardRequiredDays: Integer` | C field `int m_cdaySteamGuardRequiredDays`. |
| `m_cdayNewDeviceCooldown: Integer` | C field `int m_cdayNewDeviceCooldown`. |

### DurationControl_t

Callback id 167 (`DurationControl_t_k_iCallback`).

| Field | C declaration |
|-------|---------------|
| `m_eResult: EResult` | C field `EResult m_eResult`. |
| `m_appid: AppId_t` | C field `AppId_t m_appid`. |
| `m_bApplicable: Boolean` | C field `bool m_bApplicable`. |
| `m_csecsLast5h: Int32` | C field `int32 m_csecsLast5h`. |
| `m_progress: EDurationControlProgress` | C field `EDurationControlProgress m_progress`. |
| `m_notification: EDurationControlNotification` | C field `EDurationControlNotification m_notification`. |
| `m_csecsToday: Int32` | C field `int32 m_csecsToday`. |
| `m_csecsRemaining: Int32` | C field `int32 m_csecsRemaining`. |

### GetTicketForWebApiResponse_t

Callback id 168 (`GetTicketForWebApiResponse_t_k_iCallback`).

| Field | C declaration |
|-------|---------------|
| `m_hAuthTicket: HAuthTicket` | C field `HAuthTicket m_hAuthTicket`. |
| `m_eResult: EResult` | C field `EResult m_eResult`. |
| `m_cubTicket: Integer` | C field `int m_cubTicket`. |
| `m_rgubTicket: array[0..2559] of UInt8` | C field `uint8 [2560] m_rgubTicket`. |
