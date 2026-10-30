# TSteamUtils and TSteamUtilsPlugin (ISteamUtils)

> **Generated** by `tools/gen_docs.py` from `lib/plugins/Steamworks.Plugin.Utils.pas` - do not edit.
> Hand-written text: `tools/doc_extras/Utils.md`. Steam's own descriptions are Valve's
> SDK comments, as in the generated units.

Unit: `Steamworks.Plugin.Utils` - linking it (a `uses` entry, or dropping a `TSteamUtils`) enables the
plug-in. Steam interface: `ISteamUtils` (SDK 1.65).

## Overview

Client utilities that every game uses sooner or later: Steam's language,
server time, the overlay state, images (avatars / achievement icons) as
pixels, Steam Deck / Big Picture gamepad text input, battery, and
environment checks. ISteamUtils is available whenever SteamAPI runs
(Steam initialises it itself), so this plug-in is the safest first test
that Steam works.

```pascal
var
  U: TSteamUtilsPlugin;
begin
  U := SteamUtils1.Plugin;
  Log(Format('AppID %d, Steam language %s, server time %s, overlay %s',
    [U.GetAppID, U.GetSteamUILanguage,
     DateTimeToStr(U.ServerTime), BoolToStr(U.IsOverlayEnabled, True)]));
end;
```

### Hand-written additions

These are not in Valve's interface; they come from
`tools/plugin_extras/Utils.pas.txt`:

* `ServerTime: TDateTime` - Steam's server time in UTC.
* `GetImageRGBABytes(Image, out Width, Height): TBytes` - an avatar /
  achievement icon as straight RGBA, 4 bytes per pixel, rows top-down; `nil`
  while the image is not available. The framework units'
  `SteamImageToBitmap` is built on it.
* `OnLowBattery` and `OnIPCountryChanged` - plug-in events for code that does
  not use the component.
* `IsRunningOnSteamDeck` - deprecated: SDK 1.65 removed it. Use
  `IsRunningOnSteamHardware` (returns an `ESteamHardwareType`) or
  `IsSteamInBigPictureMode`.

### Gamepad text input (Steam Deck, Big Picture)

`ShowGamepadTextInput(k_EGamepadTextInputModeNormal,
k_EGamepadTextInputLineModeSingleLine, 'Name', 32, '')` opens Steam's
on-screen keyboard; `OnGamepadTextInputDismissed` reports the result and
`GetEnteredGamepadTextInput` reads the text. `ShowFloatingGamepadTextInput`
is the lighter variant that types into your own edit field.

### Checks

`IsSteamRunningInVR`, `IsSteamInBigPictureMode`, `IsRunningUnderProton`
(SDK 1.65), `IsSteamChinaLauncher`, `GetCurrentBatteryPower` (255 = on
mains power). `GetIPCountry` is the two-letter country of the user's IP
address.

## Contents

* [The component: TSteamUtils](#the-component-tsteamutils)
  * [Events (7)](#events)
* [The plug-in: TSteamUtilsPlugin](#the-plug-in-tsteamutilsplugin)
  * [Methods](#methods)
  * [Async methods](#async-methods)
  * [Properties](#properties)
* [Payload records](#payload-records)

## The component: TSteamUtils

ISteamUtils component: drop it next to a TSteamAPI (linked automatically at run time when the owner has exactly one, otherwise set SteamAPI). Its events are the ISteamUtils callbacks; call the interface through `Plugin`.

| Member | Kind | Description |
|--------|------|-------------|
| `SteamAPI` | published property | The `TSteamAPI` this component belongs to. At run time a component whose owner has exactly one `TSteamAPI` links itself. |
| `Plugin` | public property | The `TSteamUtilsPlugin` for calls; `nil` while Steam is not running. |
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
| `OnIPCountry` | 701 | [`IPCountry_t`](#ipcountry_t) | The country of the user changed. |
| `OnLowBatteryPower` | 702 | [`LowBatteryPower_t`](#lowbatterypower_t) | Fired when running on a handheld PC or laptop with less than 10 minutes of battery is left, fires then every minute. |
| `OnCheckFileSignature` | 705 | [`CheckFileSignature_t`](#checkfilesignature_t) | callback for CheckFileSignature. |
| `OnGamepadTextInputDismissed` | 714 | [`GamepadTextInputDismissed_t`](#gamepadtextinputdismissed_t) | Full Screen gamepad text input has been closed. |
| `OnAppResumingFromSuspend` | 736 | [`AppResumingFromSuspend_t`](#appresumingfromsuspend_t) | see the SDK. |
| `OnFloatingGamepadTextInputDismissed` | 738 | [`FloatingGamepadTextInputDismissed_t`](#floatinggamepadtextinputdismissed_t) | The floating on-screen keyboard has been closed. |
| `OnFilterTextDictionaryChanged` | 739 | [`FilterTextDictionaryChanged_t`](#filtertextdictionarychanged_t) | The text filtering dictionary has changed. |

Handler signature (the IDE generates it when you double-click the event):

```pascal
procedure TForm1.SteamUtils1IPCountry(Sender: TObject; const AData: IPCountry_t);
```

## The plug-in: TSteamUtilsPlugin

ISteamUtils plug-in. Registered by linking the unit; find it with @code(Steam.FindPlugin(TSteamUtilsPlugin)).

Reach it through the component (`SteamUtils1.Plugin`) or the core:

```pascal
P := TSteamUtilsPlugin(Steam.FindPlugin(TSteamUtilsPlugin));   // Delphi also: Steam.Plugin<TSteamUtilsPlugin>
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
| [`GetSecondsSinceAppActive`](#getsecondssinceappactive) | return the number of seconds since the user. |
| [`GetSecondsSinceComputerActive`](#getsecondssincecomputeractive) | Wraps `SteamAPI_ISteamUtils_GetSecondsSinceComputerActive`. |
| [`GetConnectedUniverse`](#getconnecteduniverse) | the universe this client is connecting to. |
| [`GetServerRealTime`](#getserverrealtime) | Steam server time. Number of seconds since January 1, 1970, GMT (i.e unix time). |
| [`GetIPCountry`](#getipcountry) | returns the 2 digit ISO 3166-1-alpha-2 format country code this client is running in (as looked up via an IP-to-location database) e.g "US" or "UK". |
| [`GetImageSize`](#getimagesize) | returns true if the image exists, and valid sizes were filled out. |
| [`GetImageRGBA`](#getimagergba) | returns true if the image exists, and the buffer was successfully filled out results are returned in RGBA format the destination buffer size should be 4 * ... |
| [`GetCurrentBatteryPower`](#getcurrentbatterypower) | return the amount of battery power left in the current system in % [0..100], 255 for being on AC power. |
| [`GetAppID`](#getappid) | returns the appID of the current process. |
| [`SetOverlayNotificationPosition`](#setoverlaynotificationposition) | Sets the position where the overlay instance for the currently calling game should show notifications. This position is per-game and if this function is ... |
| [`IsAPICallCompleted`](#isapicallcompleted) | API asynchronous call results can be used directly, but more commonly used via the callback dispatch API (see steam_api.h). |
| [`GetAPICallFailureReason`](#getapicallfailurereason) | Wraps `SteamAPI_ISteamUtils_GetAPICallFailureReason`. |
| [`GetAPICallResult`](#getapicallresult) | Wraps `SteamAPI_ISteamUtils_GetAPICallResult`. |
| [`GetIPCCallCount`](#getipccallcount) | returns the number of IPC calls made since the last time this function was called Used for perf debugging so you can understand how many IPC calls your game ... |
| [`SetWarningMessageHook`](#setwarningmessagehook) | API warning handling 'int' is the severity; 0 for msg, 1 for warning 'const char *' is the text of the message callbacks will occur directly after the API ... |
| [`IsOverlayEnabled`](#isoverlayenabled) | Returns true if the overlay is running & the user can access it. The overlay process could take a few seconds to start & hook the game process, so this ... |
| [`BOverlayNeedsPresent`](#boverlayneedspresent) | Normally this call is unneeded if your game has a constantly running frame loop that calls the D3D Present API, or OGL SwapBuffers API every frame. However, ... |
| [`CheckFileSignature`](#checkfilesignature) | Asynchronous call to check if an executable file has been signed using the public key set on the signing tab of the partner site, for example to refuse to ... |
| [`ShowGamepadTextInput`](#showgamepadtextinput) | Activates the full-screen text input dialog which takes a initial text string and returns the text the user has typed. |
| [`GetEnteredGamepadTextLength`](#getenteredgamepadtextlength) | Returns previously entered text & length. |
| [`GetEnteredGamepadTextInput`](#getenteredgamepadtextinput) | Wraps `SteamAPI_ISteamUtils_GetEnteredGamepadTextInput`. |
| [`GetSteamUILanguage`](#getsteamuilanguage) | returns the language the steam client is running in, you probably want ISteamApps::GetCurrentGameLanguage instead, this is for very special usage cases. |
| [`IsSteamRunningInVR`](#issteamrunninginvr) | returns true if Steam itself is running in VR mode. |
| [`SetOverlayNotificationInset`](#setoverlaynotificationinset) | Sets the inset of the overlay notification from the corner specified by SetOverlayNotificationPosition. |
| [`IsSteamInBigPictureMode`](#issteaminbigpicturemode) | Returns true if Steam & the Steam Overlay are running in Big Picture mode, where the user is most likely using a gamepad to control the device in a living ... |
| [`StartVRDashboard`](#startvrdashboard) | ask SteamUI to create and render its OpenVR dashboard. |
| [`IsVRHeadsetStreamingEnabled`](#isvrheadsetstreamingenabled) | Returns true if the HMD content will be streamed via Steam Remote Play. |
| [`SetVRHeadsetStreamingEnabled`](#setvrheadsetstreamingenabled) | Set whether the HMD content will be streamed via Steam Remote Play If this is set to true, then the scene in the HMD headset will be streamed, and remote ... |
| [`IsSteamChinaLauncher`](#issteamchinalauncher) | Returns whether this steam client is a Steam China specific client, vs the global client. |
| [`InitFilterText`](#initfiltertext) | Initializes text filtering, loading dictionaries for the language the game is running in. unFilterOptions are reserved for future use and should be set to 0 ... |
| [`FilterText`](#filtertext) | Filters the provided input message and places the filtered result into pchOutFilteredText, using legally required filtering and additional filtering based ... |
| [`GetIPv6ConnectivityState`](#getipv6connectivitystate) | Return what we believe your current ipv6 connectivity to "the internet" is on the specified protocol. This does NOT tell you if the Steam client is ... |
| [`ShowFloatingGamepadTextInput`](#showfloatinggamepadtextinput) | Opens a floating keyboard over the game content and sends OS keyboard keys directly to the game. The text field position is specified in pixels relative the ... |
| [`SetGameLauncherMode`](#setgamelaunchermode) | In game launchers that don't have controller support you can call this to have Steam Input translate the controller input into mouse/kb to navigate the ... |
| [`DismissFloatingGamepadTextInput`](#dismissfloatinggamepadtextinput) | Dismisses the floating keyboard. |
| [`DismissGamepadTextInput`](#dismissgamepadtextinput) | Dismisses the full-screen text input dialog. |
| [`IsRunningOnSteamHardware`](#isrunningonsteamhardware) | Returns if your process is running on a Steam Deck, Machine, Frame or other hardware. This method is intended to be used for usage analytics, support, ... |
| [`GetSteamHardwareDefaultConfig`](#getsteamhardwaredefaultconfig) | Use this method to help choose default game settings (video and other) that you have tuned for specific Steam hardware. It also enables changing your ... |
| [`IsRunningUnderProton`](#isrunningunderproton) | Returns true if running under the Proton compatibility layer. |
| [`ServerTime`](#servertime) | `GetServerRealTime` as a UTC TDateTime. |
| [`GetImageRGBABytes`](#getimagergbabytes) | Avatar / achievement image as RGBA bytes (4 per pixel, rows top-down), or `nil` when the image is not available yet. |
| [`IsRunningOnSteamDeck`](#isrunningonsteamdeck) | Deprecated: removed in SDK 1.65; works only with older redistributables (`False` otherwise). |

#### GetSecondsSinceAppActive

```pascal
function GetSecondsSinceAppActive: UInt32;
```

return the number of seconds since the user.

#### GetSecondsSinceComputerActive

```pascal
function GetSecondsSinceComputerActive: UInt32;
```

Wraps `SteamAPI_ISteamUtils_GetSecondsSinceComputerActive`.

#### GetConnectedUniverse

```pascal
function GetConnectedUniverse: EUniverse;
```

the universe this client is connecting to.

#### GetServerRealTime

```pascal
function GetServerRealTime: UInt32;
```

Steam server time. Number of seconds since January 1, 1970, GMT (i.e unix time).

#### GetIPCountry

```pascal
function GetIPCountry: string;
```

returns the 2 digit ISO 3166-1-alpha-2 format country code this client is running in (as looked up via an IP-to-location database) e.g "US" or "UK".

#### GetImageSize

```pascal
function GetImageSize(iImage: Integer; var pnWidth: UInt32; var pnHeight: UInt32): Boolean;
```

returns true if the image exists, and valid sizes were filled out.

#### GetImageRGBA

```pascal
function GetImageRGBA(iImage: Integer; pubDest: Pointer; nDestBufferSize: Integer): Boolean;
```

returns true if the image exists, and the buffer was successfully filled out results are returned in RGBA format the destination buffer size should be 4 * height * width * sizeof(char).

#### GetCurrentBatteryPower

```pascal
function GetCurrentBatteryPower: UInt8;
```

return the amount of battery power left in the current system in % [0..100], 255 for being on AC power.

#### GetAppID

```pascal
function GetAppID: UInt32;
```

returns the appID of the current process.

#### SetOverlayNotificationPosition

```pascal
procedure SetOverlayNotificationPosition(AENotificationPosition: ENotificationPosition);
```

Sets the position where the overlay instance for the currently calling game should show notifications. This position is per-game and if this function is called from outside of a game context it will do nothing.

#### IsAPICallCompleted

```pascal
function IsAPICallCompleted(hSteamAPICall: SteamAPICall_t; var pbFailed: Boolean): Boolean;
```

API asynchronous call results can be used directly, but more commonly used via the callback dispatch API (see steam_api.h).

#### GetAPICallFailureReason

```pascal
function GetAPICallFailureReason(hSteamAPICall: SteamAPICall_t): ESteamAPICallFailure;
```

Wraps `SteamAPI_ISteamUtils_GetAPICallFailureReason`.

#### GetAPICallResult

```pascal
function GetAPICallResult(hSteamAPICall: SteamAPICall_t; pCallback: Pointer; cubCallback: Integer; iCallbackExpected: Integer; var pbFailed: Boolean): Boolean;
```

Wraps `SteamAPI_ISteamUtils_GetAPICallResult`.

#### GetIPCCallCount

```pascal
function GetIPCCallCount: UInt32;
```

returns the number of IPC calls made since the last time this function was called Used for perf debugging so you can understand how many IPC calls your game makes per frame Every IPC call is at minimum a thread context switch if not a process one so you want to rate control how often you do them.

#### SetWarningMessageHook

```pascal
procedure SetWarningMessageHook(pFunction: SteamAPIWarningMessageHook_t);
```

API warning handling 'int' is the severity; 0 for msg, 1 for warning 'const char *' is the text of the message callbacks will occur directly after the API function is called that generated the warning or message.

#### IsOverlayEnabled

```pascal
function IsOverlayEnabled: Boolean;
```

Returns true if the overlay is running & the user can access it. The overlay process could take a few seconds to start & hook the game process, so this function will initially return false while the overlay is loading.

#### BOverlayNeedsPresent

```pascal
function BOverlayNeedsPresent: Boolean;
```

Normally this call is unneeded if your game has a constantly running frame loop that calls the D3D Present API, or OGL SwapBuffers API every frame. However, if you have a game that only refreshes the screen on an event driven basis then that can break the overlay, as it uses your Present/SwapBuffers calls to drive it's internal frame loop and it may also need to Present() to the screen any time an even needing a notification happens or when the overlay is brought up over the game by a user. You can use this API to ask the overlay if it currently need a present in that case, and then you can check for this periodically (roughly 33hz is desirable) and make sure you refresh the screen with Present or SwapBuffers to allow the overlay to do it's work.

#### CheckFileSignature

```pascal
function CheckFileSignature(const szFileName: string): SteamAPICall_t;
```

Asynchronous call to check if an executable file has been signed using the public key set on the signing tab of the partner site, for example to refuse to load modified executable files. The result is returned in CheckFileSignature_t. k_ECheckFileSignatureNoSignaturesFoundForThisApp - This app has not been configured on the signing tab of the partner site to enable this function. k_ECheckFileSignatureNoSignaturesFoundForThisFile - This file is not listed on the signing tab for the partner site. k_ECheckFileSignatureFileNotFound - The file does not exist on disk. k_ECheckFileSignatureInvalidSignature - The file exists, and the signing tab has been set for this file, but the file is either not signed or the signature does not match. k_ECheckFileSignatureValidSignature - The file is signed and the signature is valid. Call result: `CheckFileSignature_t` (`CheckFileSignature_t_k_iCallback`).

#### ShowGamepadTextInput

```pascal
function ShowGamepadTextInput(eInputMode: EGamepadTextInputMode; eLineInputMode: EGamepadTextInputLineMode; const pchDescription: string; unCharMax: UInt32; const pchExistingText: string): Boolean;
```

Activates the full-screen text input dialog which takes a initial text string and returns the text the user has typed.

#### GetEnteredGamepadTextLength

```pascal
function GetEnteredGamepadTextLength: UInt32;
```

Returns previously entered text & length.

#### GetEnteredGamepadTextInput

```pascal
function GetEnteredGamepadTextInput(pchText: PAnsiChar; cchText: UInt32): Boolean;
```

Wraps `SteamAPI_ISteamUtils_GetEnteredGamepadTextInput`.

#### GetSteamUILanguage

```pascal
function GetSteamUILanguage: string;
```

returns the language the steam client is running in, you probably want ISteamApps::GetCurrentGameLanguage instead, this is for very special usage cases.

#### IsSteamRunningInVR

```pascal
function IsSteamRunningInVR: Boolean;
```

returns true if Steam itself is running in VR mode.

#### SetOverlayNotificationInset

```pascal
procedure SetOverlayNotificationInset(nHorizontalInset: Integer; nVerticalInset: Integer);
```

Sets the inset of the overlay notification from the corner specified by SetOverlayNotificationPosition.

#### IsSteamInBigPictureMode

```pascal
function IsSteamInBigPictureMode: Boolean;
```

Returns true if Steam & the Steam Overlay are running in Big Picture mode, where the user is most likely using a gamepad to control the device in a living room like setting or at an increased viewing distance from the TV. Games must be launched through the Steam client to enable the Big Picture overlay. During development, a game can be added as a non-steam game to the developers library to test this feature.

#### StartVRDashboard

```pascal
procedure StartVRDashboard;
```

ask SteamUI to create and render its OpenVR dashboard.

#### IsVRHeadsetStreamingEnabled

```pascal
function IsVRHeadsetStreamingEnabled: Boolean;
```

Returns true if the HMD content will be streamed via Steam Remote Play.

#### SetVRHeadsetStreamingEnabled

```pascal
procedure SetVRHeadsetStreamingEnabled(bEnabled: Boolean);
```

Set whether the HMD content will be streamed via Steam Remote Play If this is set to true, then the scene in the HMD headset will be streamed, and remote input will not be allowed. If this is set to false, then the application window will be streamed instead, and remote input will be allowed. The default is true unless "VRHeadsetStreaming" "0" is in the extended appinfo for a game. (this is useful for games that have asymmetric multiplayer gameplay).

#### IsSteamChinaLauncher

```pascal
function IsSteamChinaLauncher: Boolean;
```

Returns whether this steam client is a Steam China specific client, vs the global client.

#### InitFilterText

```pascal
function InitFilterText(unFilterOptions: UInt32): Boolean;
```

Initializes text filtering, loading dictionaries for the language the game is running in. unFilterOptions are reserved for future use and should be set to 0 Returns false if filtering is unavailable for the game's language, in which case FilterText() will act as a passthrough. Users can customize the text filter behavior in their Steam Account preferences: https://store.steampowered.com/account/preferences#CommunityContentPreferences.

#### FilterText

```pascal
function FilterText(eContext: ETextFilteringContext; const sourceSteamID: TSteamID; const pchInputMessage: string; pchOutFilteredText: PAnsiChar; nByteSizeOutFilteredText: UInt32): Integer;
```

Filters the provided input message and places the filtered result into pchOutFilteredText, using legally required filtering and additional filtering based on the context and user settings eContext is the type of content in the input string sourceSteamID is the Steam ID that is the source of the input string (e.g. the player with the name, or who said the chat text) pchInputText is the input string that should be filtered, which can be ASCII or UTF-8 pchOutFilteredText is where the output will be placed, even if no filtering is performed nByteSizeOutFilteredText is the size (in bytes) of pchOutFilteredText, should be at least strlen(pchInputText)+1 Returns the number of characters (not bytes) filtered.

#### GetIPv6ConnectivityState

```pascal
function GetIPv6ConnectivityState(eProtocol: ESteamIPv6ConnectivityProtocol): ESteamIPv6ConnectivityState;
```

Return what we believe your current ipv6 connectivity to "the internet" is on the specified protocol. This does NOT tell you if the Steam client is currently connected to Steam via ipv6.

#### ShowFloatingGamepadTextInput

```pascal
function ShowFloatingGamepadTextInput(eKeyboardMode: EFloatingGamepadTextInputMode; nTextFieldXPosition: Integer; nTextFieldYPosition: Integer; nTextFieldWidth: Integer; nTextFieldHeight: Integer): Boolean;
```

Opens a floating keyboard over the game content and sends OS keyboard keys directly to the game. The text field position is specified in pixels relative the origin of the game window and is used to position the floating keyboard in a way that doesn't cover the text field.

#### SetGameLauncherMode

```pascal
procedure SetGameLauncherMode(bLauncherMode: Boolean);
```

In game launchers that don't have controller support you can call this to have Steam Input translate the controller input into mouse/kb to navigate the launcher.

#### DismissFloatingGamepadTextInput

```pascal
function DismissFloatingGamepadTextInput: Boolean;
```

Dismisses the floating keyboard.

#### DismissGamepadTextInput

```pascal
function DismissGamepadTextInput: Boolean;
```

Dismisses the full-screen text input dialog.

#### IsRunningOnSteamHardware

```pascal
function IsRunningOnSteamHardware: ESteamHardwareType;
```

Returns if your process is running on a Steam Deck, Machine, Frame or other hardware. This method is intended to be used for usage analytics, support, diagnostic and other non-functional decisions. If your process needs to make a feature or device capability related decision, the Steamworks SDK exposes a set of other methods. Using one of these alternate methods will enable your game to run correctly on future versions of Steam hardware where this method would return a hardware type not present in old SDK versions. Some alternate methods include: - ISteamUtils::GetSteamHardwareDefaultConfig() - ISteamUtils::IsSteamInBigPictureMode() - ISteamUtils::IsRunningUnderProton() - ISteamUtils::IsSteamRunningInVR() - ISteamUtils::GetCurrentBatteryPower() - ISteamUtils::GetConnectedControllers().

#### GetSteamHardwareDefaultConfig

```pascal
function GetSteamHardwareDefaultConfig: ESteamHardwareDefaultConfig;
```

Use this method to help choose default game settings (video and other) that you have tuned for specific Steam hardware. It also enables changing your default game settings on future Steam hardware without needing to recompile your game. This method returns an ESteamHardwareDefaultConfig, which has two categories of values: - Machine specific values: Map each of these values to a setting configuration tuned for that device. - General values (low, medium, high, max): Map these values to one of your game's user selectable setting presets. If your game has less than 4 presets, it is expected that multiple values might map to the same preset. For example, a game with 3 presets might map high and max to the game's 'high' user preset. For games that only have 1 preset and run great on any device, low, medium, high and max might all be mapped to that single preset. By default, this method will return a value corresponding to the device type returned by ISteamUtils::IsRunningOnSteamHardware(), such as returning k_ESteamHardwareDefaultConfigSteamDeck when running on a Steam Deck. It may also return a configuration value for 3rd party hardware that has similar performance characteristics to Steam hardware, such as returning k_ESteamHardwareDefaultConfigSteamDeck when running on a Legion Go S. You can also change what value the Steam Client returns per device through the Steamworks Partner Site. This allows you to customize the default configuration used on future Steam hardware without recompiling your game. For example, if your game runs well on Steam Machine using your 'high' user preset, but was released before that device became available, you could configure this method to return k_ESteamHardwareDefaultConfigHigh when run on those devices. Similarly if your game was released before Steam Frame, you could configure this method to return k_ESteamHardwareDefaultConfigSteamDeck so that when your game is run in 2d mode, it uses your tuned Steam Deck presets. The following example covers a common approach to choosing default settings when running on Steam hardware: 1. Call GetSteamHardwareDefaultConfig() 2. If the returned value is for hardware that you have a known configuration for, use a tuned matching configuration 3. If the returned value is low, medium, high or max, use a matching user preset 4. If the returned value had no match, fall back to your default setting heuristics.

#### IsRunningUnderProton

```pascal
function IsRunningUnderProton: Boolean;
```

Returns true if running under the Proton compatibility layer.

#### ServerTime

```pascal
function ServerTime: TDateTime;
```

`GetServerRealTime` as a UTC TDateTime.

#### GetImageRGBABytes

```pascal
function GetImageRGBABytes(AImage: Integer; out AWidth, AHeight: UInt32): TBytes;
```

Avatar / achievement image as RGBA bytes (4 per pixel, rows top-down), or `nil` when the image is not available yet.

#### IsRunningOnSteamDeck

```pascal
function IsRunningOnSteamDeck: Boolean; deprecated 'Removed in Steamworks SDK 1.65 - use IsRunningOnSteamHardware / IsSteamInBigPictureMode';
```

**Deprecated:** removed in SDK 1.65; works only with older redistributables (`False` otherwise).

### Async methods

Each `...Async` method starts the call and registers `AHandler` for its result
(`procedure(const AData: TSteamCallbackData; AIOFailure: Boolean) of object`). The
handler runs once, on the delivery thread, with the result record in `AData`
(`AData.CopyTo(Rec, SizeOf(Rec))`); its object owns the registration - call
`Steam.Dispatcher.RemoveOwner(Self)` in that object's destructor. The plain method of
the same name returns the `SteamAPICall_t` instead, and its result reaches the
component's event.

#### CheckFileSignatureAsync

```pascal
function CheckFileSignatureAsync(const szFileName: string; AHandler: TSteamCallResultEvent): SteamAPICall_t;
```

Calls `CheckFileSignature` and registers AHandler for its result (`CheckFileSignature_t`). The handler's object owns the registration (remove it with Steam.Dispatcher.RemoveOwner). Returns: (The call handle, or k_uAPICallInvalid when Steam refused the call.)

### Properties

| Property | Description |
|----------|-------------|
| `OnIPCountryChanged: TNotifyEvent` | The user's IP country changed (IPCountry_t). |
| `OnLowBattery: TLowBatteryEvent` | Battery is low (LowBatteryPower_t); fires every minute below 10 minutes. |
| `Handle: Pointer` | The raw ISteamUtils pointer (first argument of every `Flat` export). |
| `Flat: TSteamUtilsFlat` | The bound flat exports, for calls the methods do not cover. |

## Payload records

Declared in `Steamworks.SDKTypes` (generated from the SDK headers; layouts verified
against the C headers for Win64, Win32, Linux64 and macOS ARM64).

### IPCountry_t

Callback id 701 (`IPCountry_t_k_iCallback`).

| Field | C declaration |
|-------|---------------|
| `_dummy: Byte` | Placeholder: the C++ struct is empty (sizeof = 1). |

### LowBatteryPower_t

Callback id 702 (`LowBatteryPower_t_k_iCallback`).

| Field | C declaration |
|-------|---------------|
| `m_nMinutesBatteryLeft: UInt8` | C field `uint8 m_nMinutesBatteryLeft`. |

### CheckFileSignature_t

Callback id 705 (`CheckFileSignature_t_k_iCallback`).

| Field | C declaration |
|-------|---------------|
| `m_eCheckFileSignature: ECheckFileSignature` | C field `ECheckFileSignature m_eCheckFileSignature`. |

### GamepadTextInputDismissed_t

Callback id 714 (`GamepadTextInputDismissed_t_k_iCallback`).

| Field | C declaration |
|-------|---------------|
| `m_bSubmitted: Boolean` | C field `bool m_bSubmitted`. |
| `m_unSubmittedText: UInt32` | C field `uint32 m_unSubmittedText`. |
| `m_unAppID: AppId_t` | C field `AppId_t m_unAppID`. |

### AppResumingFromSuspend_t

Callback id 736 (`AppResumingFromSuspend_t_k_iCallback`).

| Field | C declaration |
|-------|---------------|
| `_dummy: Byte` | Placeholder: the C++ struct is empty (sizeof = 1). |

### FloatingGamepadTextInputDismissed_t

Callback id 738 (`FloatingGamepadTextInputDismissed_t_k_iCallback`).

| Field | C declaration |
|-------|---------------|
| `_dummy: Byte` | Placeholder: the C++ struct is empty (sizeof = 1). |

### FilterTextDictionaryChanged_t

Callback id 739 (`FilterTextDictionaryChanged_t_k_iCallback`).

| Field | C declaration |
|-------|---------------|
| `m_eLanguage: Integer` | C field `int m_eLanguage`. |
