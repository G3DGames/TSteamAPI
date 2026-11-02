# TSteamNetworkingUtils and TSteamNetworkingUtilsPlugin (ISteamNetworkingUtils)

> **Generated** by `tools/gen_docs.py` from `lib/plugins/Steamworks.Plugin.NetworkingUtils.pas` - do not edit.
> Hand-written text: `tools/doc_extras/NetworkingUtils.md`. Steam's own descriptions are Valve's
> SDK comments, as in the generated units.

Unit: `Steamworks.Plugin.NetworkingUtils` - linking it (a `uses` entry, or dropping a `TSteamNetworkingUtils`) enables the
plug-in. Steam interface: `ISteamNetworkingUtils` (SDK 1.65).

## Overview

Utilities for the networking interfaces (`ISteamNetworkingUtils`): the
Steam Datagram Relay (SDR) start-up and status, ping locations and
estimates, the local high-resolution clock, configuration values and
debug output.

```pascal
var
  Status: SteamRelayNetworkStatus_t;
begin
  SteamNetworkingUtils1.Plugin.InitRelayNetworkAccess;   // early, e.g. at start-up
  if SteamNetworkingUtils1.Plugin.GetRelayNetworkStatus(Status) =
     k_ESteamNetworkingAvailability_Current then
    Log('relay network ready');
end;
```

* `OnSteamRelayNetworkStatus` reports every change of the relay network
  state (`m_eAvail`, `m_debugMsg`).
* `GetLocalTimestamp` is the clock the networking messages are stamped
  with (`m_usecTimeReceived`), in microseconds.
* `GetLocalPingLocation` (-1 until the relay network has measured it),
  `EstimatePingTimeBetweenTwoLocations`, `GetPingToDataCenter`,
  `GetPOPCount` / `GetPOPList`: ping and data-centre information for
  matchmaking.
* `SetGlobalConfigValueInt32` / `...Float` / `...String` and
  `SetConnectionConfigValue...` change networking settings (fake lag and
  loss for testing, timeouts, ...); the generic `SetConfigValue` takes raw
  pointers.

## Contents

* [The component: TSteamNetworkingUtils](#the-component-tsteamnetworkingutils)
  * [Events (1)](#events)
* [The plug-in: TSteamNetworkingUtilsPlugin](#the-plug-in-tsteamnetworkingutilsplugin)
  * [Methods](#methods)
  * [Async methods](#async-methods)
  * [Properties](#properties)
* [Payload records](#payload-records)

## The component: TSteamNetworkingUtils

ISteamNetworkingUtils component: drop it next to a TSteamAPI (linked automatically at run time when the owner has exactly one, otherwise set SteamAPI). Its events are the ISteamNetworkingUtils callbacks; call the interface through `Plugin`.

| Member | Kind | Description |
|--------|------|-------------|
| `SteamAPI` | published property | The `TSteamAPI` this component belongs to. At run time a component whose owner has exactly one `TSteamAPI` links itself. |
| `Plugin` | public property | The `TSteamNetworkingUtilsPlugin` for calls; `nil` while Steam is not running. |
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
| `OnSteamRelayNetworkStatus` | 1281 | [`SteamRelayNetworkStatus_t`](#steamrelaynetworkstatus_t) | A struct used to describe our readiness to use the relay network. To do this we first need to fetch the network configuration, which describes what POPs are available. |

Handler signature (the IDE generates it when you double-click the event):

```pascal
procedure TForm1.SteamNetworkingUtils1SteamRelayNetworkStatus(Sender: TObject; const AData: SteamRelayNetworkStatus_t);
```

## The plug-in: TSteamNetworkingUtilsPlugin

ISteamNetworkingUtils plug-in. Registered by linking the unit; find it with @code(Steam.FindPlugin(TSteamNetworkingUtilsPlugin)).

Reach it through the component (`SteamNetworkingUtils1.Plugin`) or the core:

```pascal
P := TSteamNetworkingUtilsPlugin(Steam.FindPlugin(TSteamNetworkingUtilsPlugin));   // Delphi also: Steam.Plugin<TSteamNetworkingUtilsPlugin>
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
| [`AllocateMessage`](#allocatemessage) | Allocate and initialize a message object. Usually the reason you call this is to pass it to ISteamNetworkingSockets::SendMessages. The returned object will ... |
| [`InitRelayNetworkAccess`](#initrelaynetworkaccess) | Wraps `SteamAPI_ISteamNetworkingUtils_InitRelayNetworkAccess`. |
| [`GetRelayNetworkStatus`](#getrelaynetworkstatus) | Fetch current status of the relay network. SteamRelayNetworkStatus_t is also a callback. It will be triggered on both the user and gameserver interfaces any ... |
| [`GetLocalPingLocation`](#getlocalpinglocation) | Return location info for the current host. Returns the approximate age of the data, in seconds, or -1 if no data is available. It takes a few seconds to ... |
| [`EstimatePingTimeBetweenTwoLocations`](#estimatepingtimebetweentwolocations) | Estimate the round-trip latency between two arbitrary locations, in milliseconds. This is a conservative estimate, based on routing through the relay ... |
| [`EstimatePingTimeFromLocalHost`](#estimatepingtimefromlocalhost) | Same as EstimatePingTime, but assumes that one location is the local host. This is a bit faster, especially if you need to calculate a bunch of these in a ... |
| [`ConvertPingLocationToString`](#convertpinglocationtostring) | Convert a ping location into a text format suitable for sending over the wire. The format is a compact and human readable. However, it is subject to change ... |
| [`ParsePingLocationString`](#parsepinglocationstring) | Parse back SteamNetworkPingLocation_t string. Returns false if we couldn't understand the string. |
| [`CheckPingDataUpToDate`](#checkpingdatauptodate) | Check if the ping data of sufficient recency is available, and if it's too old, start refreshing it. Please only call this function when you *really* do ... |
| [`GetPingToDataCenter`](#getpingtodatacenter) | Fetch ping time of best available relayed route from this host to the specified data center. |
| [`GetDirectPingToPOP`](#getdirectpingtopop) | Get *direct* ping time to the relays at the data center. |
| [`GetPOPCount`](#getpopcount) | Get number of network points of presence in the config. |
| [`GetPOPList`](#getpoplist) | Get list of all POP IDs. Returns the number of entries that were filled into your list. |
| [`GetLocalTimestamp`](#getlocaltimestamp) | Fetch current timestamp. This timer has the following properties: - Monotonicity is guaranteed. - The initial value will be at least 24*3600*30*1e6, i.e. ... |
| [`SetDebugOutputFunction`](#setdebugoutputfunction) | Set a function to receive network-related information that is useful for debugging. This can be very useful during development, but it can also be useful ... |
| [`IsFakeIPv4`](#isfakeipv4) | Wraps `SteamAPI_ISteamNetworkingUtils_IsFakeIPv4`. |
| [`GetIPv4FakeIPType`](#getipv4fakeiptype) | Wraps `SteamAPI_ISteamNetworkingUtils_GetIPv4FakeIPType`. |
| [`GetRealIdentityForFakeIP`](#getrealidentityforfakeip) | Get the real identity associated with a given FakeIP. On failure, returns: - k_EResultInvalidParam: the IP is not a FakeIP. - k_EResultNoMatch: we don't ... |
| [`SetGlobalConfigValueInt32`](#setglobalconfigvalueint32) | Wraps `SteamAPI_ISteamNetworkingUtils_SetGlobalConfigValueInt32`. |
| [`SetGlobalConfigValueFloat`](#setglobalconfigvaluefloat) | Wraps `SteamAPI_ISteamNetworkingUtils_SetGlobalConfigValueFloat`. |
| [`SetGlobalConfigValueString`](#setglobalconfigvaluestring) | Wraps `SteamAPI_ISteamNetworkingUtils_SetGlobalConfigValueString`. |
| [`SetGlobalConfigValuePtr`](#setglobalconfigvalueptr) | Wraps `SteamAPI_ISteamNetworkingUtils_SetGlobalConfigValuePtr`. |
| [`SetConnectionConfigValueInt32`](#setconnectionconfigvalueint32) | Wraps `SteamAPI_ISteamNetworkingUtils_SetConnectionConfigValueInt32`. |
| [`SetConnectionConfigValueFloat`](#setconnectionconfigvaluefloat) | Wraps `SteamAPI_ISteamNetworkingUtils_SetConnectionConfigValueFloat`. |
| [`SetConnectionConfigValueString`](#setconnectionconfigvaluestring) | Wraps `SteamAPI_ISteamNetworkingUtils_SetConnectionConfigValueString`. |
| [`SetGlobalCallback_SteamNetConnectionStatusChanged`](#setglobalcallback_steamnetconnectionstatuschanged) | Wraps `SteamAPI_ISteamNetworkingUtils_SetGlobalCallback_SteamNetConnectionStatusChanged`. |
| [`SetGlobalCallback_SteamNetAuthenticationStatusChanged`](#setglobalcallback_steamnetauthenticationstatuschanged) | Wraps `SteamAPI_ISteamNetworkingUtils_SetGlobalCallback_SteamNetAuthenticationStatusChanged`. |
| [`SetGlobalCallback_SteamRelayNetworkStatusChanged`](#setglobalcallback_steamrelaynetworkstatuschanged) | Wraps `SteamAPI_ISteamNetworkingUtils_SetGlobalCallback_SteamRelayNetworkStatusChanged`. |
| [`SetGlobalCallback_FakeIPResult`](#setglobalcallback_fakeipresult) | Wraps `SteamAPI_ISteamNetworkingUtils_SetGlobalCallback_FakeIPResult`. |
| [`SetGlobalCallback_MessagesSessionRequest`](#setglobalcallback_messagessessionrequest) | Wraps `SteamAPI_ISteamNetworkingUtils_SetGlobalCallback_MessagesSessionRequest`. |
| [`SetGlobalCallback_MessagesSessionFailed`](#setglobalcallback_messagessessionfailed) | Wraps `SteamAPI_ISteamNetworkingUtils_SetGlobalCallback_MessagesSessionFailed`. |
| [`SetConfigValue`](#setconfigvalue) | Set a configuration value. - eValue: which value is being set - eScope: Onto what type of object are you applying the setting? - scopeArg: Which object you ... |
| [`SetConfigValueStruct`](#setconfigvaluestruct) | Wraps `SteamAPI_ISteamNetworkingUtils_SetConfigValueStruct`. |
| [`GetConfigValue`](#getconfigvalue) | Get a configuration value. - eValue: which value to fetch - eScopeType: query setting on what type of object - eScopeArg: the object to query the setting ... |
| [`GetConfigValueInfo`](#getconfigvalueinfo) | Get info about a configuration value. Returns the name of the value, or NULL if the value doesn't exist. Other output parameters can be NULL if you do not ... |
| [`IterateGenericEditableConfigValues`](#iterategenericeditableconfigvalues) | Iterate the list of all configuration values in the current environment that it might be possible to display or edit using a generic UI. To get the first ... |
| [`SteamNetworkingIPAddr_ToString`](#steamnetworkingipaddr_tostring) | String conversions. You'll usually access these using the respective inline methods. |
| [`SteamNetworkingIPAddr_ParseString`](#steamnetworkingipaddr_parsestring) | Wraps `SteamAPI_ISteamNetworkingUtils_SteamNetworkingIPAddr_ParseString`. |
| [`SteamNetworkingIPAddr_GetFakeIPType`](#steamnetworkingipaddr_getfakeiptype) | Wraps `SteamAPI_ISteamNetworkingUtils_SteamNetworkingIPAddr_GetFakeIPType`. |
| [`SteamNetworkingIdentity_ToString`](#steamnetworkingidentity_tostring) | Wraps `SteamAPI_ISteamNetworkingUtils_SteamNetworkingIdentity_ToString`. |
| [`SteamNetworkingIdentity_ParseString`](#steamnetworkingidentity_parsestring) | Wraps `SteamAPI_ISteamNetworkingUtils_SteamNetworkingIdentity_ParseString`. |

#### AllocateMessage

```pascal
function AllocateMessage(cbAllocateBuffer: Integer): Pointer;
```

Allocate and initialize a message object. Usually the reason you call this is to pass it to ISteamNetworkingSockets::SendMessages. The returned object will have all of the relevant fields cleared to zero. Optionally you can also request that this system allocate space to hold the payload itself. If cbAllocateBuffer is nonzero, the system will allocate memory to hold a payload of at least cbAllocateBuffer bytes. m_pData will point to the allocated buffer, m_cbSize will be set to the size, and m_pfnFreeData will be set to the proper function to free up the buffer. If cbAllocateBuffer=0, then no buffer is allocated. m_pData will be NULL, m_cbSize will be zero, and m_pfnFreeData will be NULL. You will need to set each of these.

#### InitRelayNetworkAccess

```pascal
procedure InitRelayNetworkAccess;
```

Wraps `SteamAPI_ISteamNetworkingUtils_InitRelayNetworkAccess`.

#### GetRelayNetworkStatus

```pascal
function GetRelayNetworkStatus(var pDetails: SteamRelayNetworkStatus_t): ESteamNetworkingAvailability;
```

Fetch current status of the relay network. SteamRelayNetworkStatus_t is also a callback. It will be triggered on both the user and gameserver interfaces any time the status changes, or ping measurement starts or stops. SteamRelayNetworkStatus_t::m_eAvail is returned. If you want more details, you can pass a non-NULL value.

#### GetLocalPingLocation

```pascal
function GetLocalPingLocation(var AResult: SteamNetworkPingLocation_t): Single;
```

Return location info for the current host. Returns the approximate age of the data, in seconds, or -1 if no data is available. It takes a few seconds to initialize access to the relay network. If you call this very soon after calling InitRelayNetworkAccess, the data may not be available yet. This always return the most up-to-date information we have available right now, even if we are in the middle of re-calculating ping times.

#### EstimatePingTimeBetweenTwoLocations

```pascal
function EstimatePingTimeBetweenTwoLocations(location1: Pointer; location2: Pointer): Integer;
```

Estimate the round-trip latency between two arbitrary locations, in milliseconds. This is a conservative estimate, based on routing through the relay network. For most basic relayed connections, this ping time will be pretty accurate, since it will be based on the route likely to be actually used. If a direct IP route is used (perhaps via NAT traversal), then the route will be different, and the ping time might be better. Or it might actually be a bit worse! Standard IP routing is frequently suboptimal! But even in this case, the estimate obtained using this method is a reasonable upper bound on the ping time. (Also it has the advantage of returning immediately and not sending any packets.) In a few cases we might not able to estimate the route. In this case a negative value is returned. k_nSteamNetworkingPing_Failed means the reason was because of some networking difficulty. (Failure to ping, etc) k_nSteamNetworkingPing_Unknown is returned if we cannot currently answer the question for some other reason. Do you need to be able to do this from a backend/matchmaking server? You are looking for the "game coordinator" library.

#### EstimatePingTimeFromLocalHost

```pascal
function EstimatePingTimeFromLocalHost(remoteLocation: Pointer): Integer;
```

Same as EstimatePingTime, but assumes that one location is the local host. This is a bit faster, especially if you need to calculate a bunch of these in a loop to find the fastest one. In rare cases this might return a slightly different estimate than combining GetLocalPingLocation with EstimatePingTimeBetweenTwoLocations. That's because this function uses a slightly more complete set of information about what route would be taken.

#### ConvertPingLocationToString

```pascal
procedure ConvertPingLocationToString(location: Pointer; pszBuf: PAnsiChar; cchBufSize: Integer);
```

Convert a ping location into a text format suitable for sending over the wire. The format is a compact and human readable. However, it is subject to change so please do not parse it yourself. Your buffer must be at least k_cchMaxSteamNetworkingPingLocationString bytes.

#### ParsePingLocationString

```pascal
function ParsePingLocationString(const pszString: string; var AResult: SteamNetworkPingLocation_t): Boolean;
```

Parse back SteamNetworkPingLocation_t string. Returns false if we couldn't understand the string.

#### CheckPingDataUpToDate

```pascal
function CheckPingDataUpToDate(flMaxAgeSeconds: Single): Boolean;
```

Check if the ping data of sufficient recency is available, and if it's too old, start refreshing it. Please only call this function when you *really* do need to force an immediate refresh of the data. (For example, in response to a specific user input to refresh this information.) Don't call it "just in case", before every connection, etc. That will cause extra traffic to be sent for no benefit. The library will automatically refresh the information as needed. Returns true if sufficiently recent data is already available. Returns false if sufficiently recent data is not available. In this case, ping measurement is initiated, if it is not already active. (You cannot restart a measurement already in progress.) You can use GetRelayNetworkStatus or listen for SteamRelayNetworkStatus_t to know when ping measurement completes.

#### GetPingToDataCenter

```pascal
function GetPingToDataCenter(popID: SteamNetworkingPOPID; var pViaRelayPoP: SteamNetworkingPOPID): Integer;
```

Fetch ping time of best available relayed route from this host to the specified data center.

#### GetDirectPingToPOP

```pascal
function GetDirectPingToPOP(popID: SteamNetworkingPOPID): Integer;
```

Get *direct* ping time to the relays at the data center.

#### GetPOPCount

```pascal
function GetPOPCount: Integer;
```

Get number of network points of presence in the config.

#### GetPOPList

```pascal
function GetPOPList(list: Pointer; nListSz: Integer): Integer;
```

Get list of all POP IDs. Returns the number of entries that were filled into your list.

#### GetLocalTimestamp

```pascal
function GetLocalTimestamp: SteamNetworkingMicroseconds;
```

Fetch current timestamp. This timer has the following properties: - Monotonicity is guaranteed. - The initial value will be at least 24*3600*30*1e6, i.e. about 30 days worth of microseconds. In this way, the timestamp value of 0 will always be at least "30 days ago". Also, negative numbers will never be returned. - Wraparound / overflow is not a practical concern. If you are running under the debugger and stop the process, the clock might not advance the full wall clock time that has elapsed between calls. If the process is not blocked from normal operation, the timestamp values will track wall clock time, even if you don't call the function frequently. The value is only meaningful for this run of the process. Don't compare it to values obtained on another computer, or other runs of the same process.

#### SetDebugOutputFunction

```pascal
procedure SetDebugOutputFunction(eDetailLevel: ESteamNetworkingSocketsDebugOutputType; pfnFunc: FSteamNetworkingSocketsDebugOutput);
```

Set a function to receive network-related information that is useful for debugging. This can be very useful during development, but it can also be useful for troubleshooting problems with tech savvy end users. If you have a console or other log that customers can examine, these log messages can often be helpful to troubleshoot network issues. (Especially any warning/error messages.) The detail level indicates what message to invoke your callback on. Lower numeric value means more important, and the value you pass is the lowest priority (highest numeric value) you wish to receive callbacks for. The value here controls the detail level for most messages. You can control the detail level for various subsystems (perhaps only for certain connections) by adjusting the configuration values k_ESteamNetworkingConfig_LogLevel_Xxxxx. Except when debugging, you should only use k_ESteamNetworkingSocketsDebugOutputType_Msg or k_ESteamNetworkingSocketsDebugOutputType_Warning. For best performance, do NOT request a high detail level and then filter out messages in your callback. This incurs all of the expense of formatting the messages, which are then discarded. Setting a high priority value (low numeric value) here allows the library to avoid doing this work. IMPORTANT: This may be called from a service thread, while we own a mutex, etc. Your output function must be threadsafe and fast! Do not make any other Steamworks calls from within the handler.

#### IsFakeIPv4

```pascal
function IsFakeIPv4(nIPv4: UInt32): Boolean;
```

Wraps `SteamAPI_ISteamNetworkingUtils_IsFakeIPv4`.

#### GetIPv4FakeIPType

```pascal
function GetIPv4FakeIPType(nIPv4: UInt32): ESteamNetworkingFakeIPType;
```

Wraps `SteamAPI_ISteamNetworkingUtils_GetIPv4FakeIPType`.

#### GetRealIdentityForFakeIP

```pascal
function GetRealIdentityForFakeIP(fakeIP: Pointer; var pOutRealIdentity: SteamNetworkingIdentity): EResult;
```

Get the real identity associated with a given FakeIP. On failure, returns: - k_EResultInvalidParam: the IP is not a FakeIP. - k_EResultNoMatch: we don't recognize that FakeIP and don't know the corresponding identity. FakeIP's used by active connections, or the FakeIPs assigned to local identities, will always work. FakeIPs for recently destroyed connections will continue to return results for a little while, but not forever. At some point, we will forget FakeIPs to save space. It's reasonably safe to assume that you can read back the real identity of a connection very soon after it is destroyed. But do not wait indefinitely.

#### SetGlobalConfigValueInt32

```pascal
function SetGlobalConfigValueInt32(eValue: ESteamNetworkingConfigValue; val: Int32): Boolean;
```

Wraps `SteamAPI_ISteamNetworkingUtils_SetGlobalConfigValueInt32`.

#### SetGlobalConfigValueFloat

```pascal
function SetGlobalConfigValueFloat(eValue: ESteamNetworkingConfigValue; val: Single): Boolean;
```

Wraps `SteamAPI_ISteamNetworkingUtils_SetGlobalConfigValueFloat`.

#### SetGlobalConfigValueString

```pascal
function SetGlobalConfigValueString(eValue: ESteamNetworkingConfigValue; const val: string): Boolean;
```

Wraps `SteamAPI_ISteamNetworkingUtils_SetGlobalConfigValueString`.

#### SetGlobalConfigValuePtr

```pascal
function SetGlobalConfigValuePtr(eValue: ESteamNetworkingConfigValue; val: Pointer): Boolean;
```

Wraps `SteamAPI_ISteamNetworkingUtils_SetGlobalConfigValuePtr`.

#### SetConnectionConfigValueInt32

```pascal
function SetConnectionConfigValueInt32(hConn: HSteamNetConnection; eValue: ESteamNetworkingConfigValue; val: Int32): Boolean;
```

Wraps `SteamAPI_ISteamNetworkingUtils_SetConnectionConfigValueInt32`.

#### SetConnectionConfigValueFloat

```pascal
function SetConnectionConfigValueFloat(hConn: HSteamNetConnection; eValue: ESteamNetworkingConfigValue; val: Single): Boolean;
```

Wraps `SteamAPI_ISteamNetworkingUtils_SetConnectionConfigValueFloat`.

#### SetConnectionConfigValueString

```pascal
function SetConnectionConfigValueString(hConn: HSteamNetConnection; eValue: ESteamNetworkingConfigValue; const val: string): Boolean;
```

Wraps `SteamAPI_ISteamNetworkingUtils_SetConnectionConfigValueString`.

#### SetGlobalCallback_SteamNetConnectionStatusChanged

```pascal
function SetGlobalCallback_SteamNetConnectionStatusChanged(fnCallback: FnSteamNetConnectionStatusChanged): Boolean;
```

Wraps `SteamAPI_ISteamNetworkingUtils_SetGlobalCallback_SteamNetConnectionStatusChanged`.

#### SetGlobalCallback_SteamNetAuthenticationStatusChanged

```pascal
function SetGlobalCallback_SteamNetAuthenticationStatusChanged(fnCallback: FnSteamNetAuthenticationStatusChanged): Boolean;
```

Wraps `SteamAPI_ISteamNetworkingUtils_SetGlobalCallback_SteamNetAuthenticationStatusChanged`.

#### SetGlobalCallback_SteamRelayNetworkStatusChanged

```pascal
function SetGlobalCallback_SteamRelayNetworkStatusChanged(fnCallback: FnSteamRelayNetworkStatusChanged): Boolean;
```

Wraps `SteamAPI_ISteamNetworkingUtils_SetGlobalCallback_SteamRelayNetworkStatusChanged`.

#### SetGlobalCallback_FakeIPResult

```pascal
function SetGlobalCallback_FakeIPResult(fnCallback: FnSteamNetworkingFakeIPResult): Boolean;
```

Wraps `SteamAPI_ISteamNetworkingUtils_SetGlobalCallback_FakeIPResult`.

#### SetGlobalCallback_MessagesSessionRequest

```pascal
function SetGlobalCallback_MessagesSessionRequest(fnCallback: FnSteamNetworkingMessagesSessionRequest): Boolean;
```

Wraps `SteamAPI_ISteamNetworkingUtils_SetGlobalCallback_MessagesSessionRequest`.

#### SetGlobalCallback_MessagesSessionFailed

```pascal
function SetGlobalCallback_MessagesSessionFailed(fnCallback: FnSteamNetworkingMessagesSessionFailed): Boolean;
```

Wraps `SteamAPI_ISteamNetworkingUtils_SetGlobalCallback_MessagesSessionFailed`.

#### SetConfigValue

```pascal
function SetConfigValue(eValue: ESteamNetworkingConfigValue; eScopeType: ESteamNetworkingConfigScope; scopeObj: NativeInt; eDataType: ESteamNetworkingConfigDataType; pArg: Pointer): Boolean;
```

Set a configuration value. - eValue: which value is being set - eScope: Onto what type of object are you applying the setting? - scopeArg: Which object you want to change? (Ignored for global scope). E.g. connection handle, listen socket handle, interface pointer, etc. - eDataType: What type of data is in the buffer at pValue? This must match the type of the variable exactly! - pArg: Value to set it to. You can pass NULL to remove a non-global setting at this scope, causing the value for that object to use global defaults. Or at global scope, passing NULL will reset any custom value and restore it to the system default. NOTE: When setting pointers (e.g. callback functions), do not pass the function pointer directly. Your argument should be a pointer to a function pointer.

#### SetConfigValueStruct

```pascal
function SetConfigValueStruct(opt: Pointer; eScopeType: ESteamNetworkingConfigScope; scopeObj: NativeInt): Boolean;
```

Wraps `SteamAPI_ISteamNetworkingUtils_SetConfigValueStruct`.

#### GetConfigValue

```pascal
function GetConfigValue(eValue: ESteamNetworkingConfigValue; eScopeType: ESteamNetworkingConfigScope; scopeObj: NativeInt; var pOutDataType: ESteamNetworkingConfigDataType; pResult: Pointer; var cbResult: NativeUInt): ESteamNetworkingGetConfigValueResult;
```

Get a configuration value. - eValue: which value to fetch - eScopeType: query setting on what type of object - eScopeArg: the object to query the setting for - pOutDataType: If non-NULL, the data type of the value is returned. - pResult: Where to put the result. Pass NULL to query the required buffer size. (k_ESteamNetworkingGetConfigValue_BufferTooSmall will be returned.) - cbResult: IN: the size of your buffer. OUT: the number of bytes filled in or required.

#### GetConfigValueInfo

```pascal
function GetConfigValueInfo(eValue: ESteamNetworkingConfigValue; var pOutDataType: ESteamNetworkingConfigDataType; var pOutScope: ESteamNetworkingConfigScope): string;
```

Get info about a configuration value. Returns the name of the value, or NULL if the value doesn't exist. Other output parameters can be NULL if you do not need them.

#### IterateGenericEditableConfigValues

```pascal
function IterateGenericEditableConfigValues(eCurrent: ESteamNetworkingConfigValue; bEnumerateDevVars: Boolean): ESteamNetworkingConfigValue;
```

Iterate the list of all configuration values in the current environment that it might be possible to display or edit using a generic UI. To get the first iterable value, pass k_ESteamNetworkingConfig_Invalid. Returns k_ESteamNetworkingConfig_Invalid to signal end of list. The bEnumerateDevVars argument can be used to include "dev" vars. These are vars that are recommended to only be editable in "debug" or "dev" mode and typically should not be shown in a retail environment where a malicious local user might use this to cheat.

#### SteamNetworkingIPAddr_ToString

```pascal
procedure SteamNetworkingIPAddr_ToString(addr: Pointer; buf: PAnsiChar; cbBuf: UInt32; bWithPort: Boolean);
```

String conversions. You'll usually access these using the respective inline methods.

#### SteamNetworkingIPAddr_ParseString

```pascal
function SteamNetworkingIPAddr_ParseString(var pAddr: SteamNetworkingIPAddr; const pszStr: string): Boolean;
```

Wraps `SteamAPI_ISteamNetworkingUtils_SteamNetworkingIPAddr_ParseString`.

#### SteamNetworkingIPAddr_GetFakeIPType

```pascal
function SteamNetworkingIPAddr_GetFakeIPType(addr: Pointer): ESteamNetworkingFakeIPType;
```

Wraps `SteamAPI_ISteamNetworkingUtils_SteamNetworkingIPAddr_GetFakeIPType`.

#### SteamNetworkingIdentity_ToString

```pascal
procedure SteamNetworkingIdentity_ToString(identity: Pointer; buf: PAnsiChar; cbBuf: UInt32);
```

Wraps `SteamAPI_ISteamNetworkingUtils_SteamNetworkingIdentity_ToString`.

#### SteamNetworkingIdentity_ParseString

```pascal
function SteamNetworkingIdentity_ParseString(var pIdentity: SteamNetworkingIdentity; const pszStr: string): Boolean;
```

Wraps `SteamAPI_ISteamNetworkingUtils_SteamNetworkingIdentity_ParseString`.

### Async methods

None.

### Properties

| Property | Description |
|----------|-------------|
| `Handle: Pointer` | The raw ISteamNetworkingUtils pointer (first argument of every `Flat` export). |
| `Flat: TSteamNetworkingUtilsFlat` | The bound flat exports, for calls the methods do not cover. |

## Payload records

Declared in `Steamworks.SDKTypes` (generated from the SDK headers; layouts verified
against the C headers for Win64, Win32, Linux64 and macOS ARM64).

### SteamRelayNetworkStatus_t

Callback id 1281 (`SteamRelayNetworkStatus_t_k_iCallback`).

| Field | C declaration |
|-------|---------------|
| `m_eAvail: ESteamNetworkingAvailability` | C field `ESteamNetworkingAvailability m_eAvail`. |
| `m_bPingMeasurementInProgress: Integer` | C field `int m_bPingMeasurementInProgress`. |
| `m_eAvailNetworkConfig: ESteamNetworkingAvailability` | C field `ESteamNetworkingAvailability m_eAvailNetworkConfig`. |
| `m_eAvailAnyRelay: ESteamNetworkingAvailability` | C field `ESteamNetworkingAvailability m_eAvailAnyRelay`. |
| `m_debugMsg: array[0..255] of AnsiChar` | C field `char [256] m_debugMsg`. |
