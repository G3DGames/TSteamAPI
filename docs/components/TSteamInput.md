# TSteamInput and TSteamInputPlugin (ISteamInput)

> **Generated** by `tools/gen_docs.py` from `lib/plugins/Steamworks.Plugin.Input.pas` - do not edit.
> Hand-written text: `tools/doc_extras/Input.md`. Steam's own descriptions are Valve's
> SDK comments, as in the generated units.

Unit: `Steamworks.Plugin.Input` - linking it (a `uses` entry, or dropping a `TSteamInput`) enables the
plug-in. Steam interface: `ISteamInput` (SDK 1.65).

## Overview

Steam Input: one API for every controller Steam supports (Xbox, PlayStation,
Switch, Steam Deck, Steam Controller, generic gamepads). The game declares
**actions** ("Jump", "Move") grouped in **action sets** in an action
manifest file; the player binds buttons and sticks to them in Steam's
binding panel, and the game reads the actions, never raw buttons.

`demos/SteamInputDemo` is a complete test: action manifest, live values of
every action, controller list, bindings, rumble.
[SteamInputMapping.md](../SteamInputMapping.md) explains the manifest,
shipping default layouts, and mapping origins to physical buttons.

### Starting

```pascal
procedure TForm1.SteamAPI1Initialized(Sender: TObject);
var
  P: TSteamInputPlugin;
begin
  P := SteamInput1.Plugin;
  P.Start(True);             // Init; True = the game calls RunFrame itself
  P.EnableDeviceCallbacks;   // OnSteamInputDeviceConnected / ...Disconnected
  // development only: use this manifest instead of the one in the depot
  P.SetInputActionManifestFilePath(ExtractFilePath(ParamStr(0)) + 'steam_input_manifest.vdf');
end;
```

* Use `Start` / `Stop` rather than the raw `Init` / `Shutdown`: `Start`
  remembers the call, so the plug-in calls `Shutdown` before
  `SteamAPI_Shutdown` when Steam stops.
* `Start(False)` lets Steam's callback pump call `RunFrame`. With a worker
  thread update mode that is the worker; `Start(True)` and `RunFrame` from
  the game loop keep every ISteamInput call on one thread.
* A shipped game puts the manifest into its depot and sets it on the
  partner site (Steam Input settings); `SetInputActionManifestFilePath` is
  for development.

### Reading actions every frame

```pascal
procedure TGame.Frame;
var
  Pads: TSteamInputHandleArray;
  Jump: InputDigitalActionData_t;
  Move: InputAnalogActionData_t;
begin
  P.RunFrame(False);                                 // with Start(True)
  Pads := P.ConnectedControllers;
  if Length(Pads) = 0 then
    Exit;
  if FInGame = 0 then                                // 0 until the manifest is loaded
  begin
    FInGame := P.GetActionSetHandle('InGame');
    FJump := P.GetDigitalActionHandle('Jump');
    FMove := P.GetAnalogActionHandle('Move');
  end;
  P.ActivateActionSet(Pads[0], FInGame);
  Jump := P.GetDigitalActionData(Pads[0], FJump);
  if Jump.bState then
    Player.Jump;
  Move := P.GetAnalogActionData(Pads[0], FMove);     // x, y in -1..1
  Player.Walk(Move.x, Move.y);
end;
```

* Handles are 0 until Steam has loaded the manifest; look them up again
  (once a second is plenty) until they are not.
* `bActive` is False when the action is not in the active set or not
  bound.
* `GetMotionData` gives gyro / accelerometer data of controllers that have
  them.
* `DigitalActionOrigins` / `AnalogActionOrigins` list the buttons bound to an
  action; `GetStringForActionOrigin` names them and
  `GetGlyphPNGForActionOrigin` gives an image path for "press (A)" prompts.
* `ShowBindingPanel(Pad)` opens the binding panel in the overlay; it returns
  False when the overlay is not available (a game started outside Steam).
* `TriggerVibration(Pad, Left, Right)` rumbles (0..65535; send 0, 0 to
  stop).

### Before testing

* Xbox and generic controllers reach Steam Input only when it is enabled for
  the game: Steam client, Library, the game's Properties, Controller.
  PlayStation, Switch and Steam controllers usually are by default.
* A controller type without a default layout in the manifest is unbound
  until a layout is chosen in the binding panel. SteamInputDemo ships
  layouts for Xbox, PlayStation, Switch Pro, Steam Deck and the 2015 Steam
  Controller, written by `tools/gen_input_mapping.py`.
* The manifest must not contain `//` comments.

### Three methods written by hand

`GetDigitalActionData`, `GetAnalogActionData` and `GetMotionData` return a
struct **by value** in the C API, which Pascal compilers do not always return
the same way as C. They are declared per platform in
`tools/plugin_extras/Input.pas.txt` exactly as clang lowers them (a register,
two registers, or a hidden result pointer), and `tools/verify_generated.py`
checks that lowering for every target on every SDK update. They are not in
`Flat`. Linux32 (FPC only) uses the compiler's own record return and is
unverified.

`EnableActionEventCallbacks` (action changes pushed to a C callback) needs
`SteamInputActionEvent_t`, a struct with a C union that is not generated
yet; poll the actions instead.

## Contents

* [The component: TSteamInput](#the-component-tsteaminput)
  * [Events (4)](#events)
* [The plug-in: TSteamInputPlugin](#the-plug-in-tsteaminputplugin)
  * [Methods](#methods)
  * [Async methods](#async-methods)
  * [Properties](#properties)
* [Payload records](#payload-records)

## The component: TSteamInput

ISteamInput component: drop it next to a TSteamAPI (linked automatically at run time when the owner has exactly one, otherwise set SteamAPI). Its events are the ISteamInput callbacks; call the interface through `Plugin`.

| Member | Kind | Description |
|--------|------|-------------|
| `SteamAPI` | published property | The `TSteamAPI` this component belongs to. At run time a component whose owner has exactly one `TSteamAPI` links itself. |
| `Plugin` | public property | The `TSteamInputPlugin` for calls; `nil` while Steam is not running. |
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
| `OnSteamInputDeviceConnected` | 2801 | [`SteamInputDeviceConnected_t`](#steaminputdeviceconnected_t) | called when a new controller has been connected, will fire once per controller if multiple new controllers connect in the same frame. |
| `OnSteamInputDeviceDisconnected` | 2802 | [`SteamInputDeviceDisconnected_t`](#steaminputdevicedisconnected_t) | called when a new controller has been connected, will fire once per controller if multiple new controllers connect in the same frame. |
| `OnSteamInputConfigurationLoaded` | 2803 | [`SteamInputConfigurationLoaded_t`](#steaminputconfigurationloaded_t) | called when a controller configuration has been loaded, will fire once per controller per focus change for Steam Input enabled controllers. |
| `OnSteamInputGamepadSlotChange` | 2804 | [`SteamInputGamepadSlotChange_t`](#steaminputgamepadslotchange_t) | called when controller gamepad slots change - on Linux/macOS these slots are shared for all running apps. |

Handler signature (the IDE generates it when you double-click the event):

```pascal
procedure TForm1.SteamInput1SteamInputDeviceConnected(Sender: TObject; const AData: SteamInputDeviceConnected_t);
```

## The plug-in: TSteamInputPlugin

ISteamInput plug-in. Registered by linking the unit; find it with @code(Steam.FindPlugin(TSteamInputPlugin)).

Reach it through the component (`SteamInput1.Plugin`) or the core:

```pascal
P := TSteamInputPlugin(Steam.FindPlugin(TSteamInputPlugin));   // Delphi also: Steam.Plugin<TSteamInputPlugin>
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
| [`Init`](#init) | Init and Shutdown must be called when starting/ending use of this interface. if bExplicitlyCallRunFrame is called then you will need to manually call ... |
| [`Shutdown`](#shutdown) | Wraps `SteamAPI_ISteamInput_Shutdown`. |
| [`SetInputActionManifestFilePath`](#setinputactionmanifestfilepath) | Set the absolute path to the Input Action Manifest file containing the in-game actions and file paths to the official configurations. Used in games that ... |
| [`RunFrame`](#runframe) | Synchronize API state with the latest Steam Input action data available. This is performed automatically by SteamAPI_RunCallbacks, but for the absolute ... |
| [`BWaitForData`](#bwaitfordata) | Waits on an IPC event from Steam sent when there is new data to be fetched from the data drop. Returns true when data was recievied before the timeout ... |
| [`BNewDataAvailable`](#bnewdataavailable) | Returns true if new data has been received since the last time action data was accessed via GetDigitalActionData or GetAnalogActionData. The game will still ... |
| [`GetConnectedControllers`](#getconnectedcontrollers) | Enumerate currently connected Steam Input enabled devices - developers can opt in controller by type (ex: Xbox/Playstation/etc) via the Steam Input settings ... |
| [`EnableDeviceCallbacks`](#enabledevicecallbacks) | Enable SteamInputDeviceConnected_t and SteamInputDeviceDisconnected_t callbacks. Each controller that is already connected will generate a device connected ... |
| [`EnableActionEventCallbacks`](#enableactioneventcallbacks) | Enable SteamInputActionEvent_t callbacks. Directly calls your callback function for lower latency than standard Steam callbacks. Supports one callback at a ... |
| [`GetActionSetHandle`](#getactionsethandle) | Lookup the handle for an Action Set. Best to do this once on startup, and store the handles for all future API calls. |
| [`ActivateActionSet`](#activateactionset) | Reconfigure the controller to use the specified action set (ie 'Menu', 'Walk' or 'Drive') This is cheap, and can be safely called repeatedly. It's often ... |
| [`GetCurrentActionSet`](#getcurrentactionset) | Wraps `SteamAPI_ISteamInput_GetCurrentActionSet`. |
| [`ActivateActionSetLayer`](#activateactionsetlayer) | ACTION SET LAYERS. |
| [`DeactivateActionSetLayer`](#deactivateactionsetlayer) | Wraps `SteamAPI_ISteamInput_DeactivateActionSetLayer`. |
| [`DeactivateAllActionSetLayers`](#deactivateallactionsetlayers) | Wraps `SteamAPI_ISteamInput_DeactivateAllActionSetLayers`. |
| [`GetActiveActionSetLayers`](#getactiveactionsetlayers) | Enumerate currently active layers. handlesOut should point to a STEAM_INPUT_MAX_ACTIVE_LAYERS sized array of InputActionSetHandle_t handles Returns the ... |
| [`GetDigitalActionHandle`](#getdigitalactionhandle) | Lookup the handle for a digital action. Best to do this once on startup, and store the handles for all future API calls. |
| [`GetDigitalActionOrigins`](#getdigitalactionorigins) | Get the origin(s) for a digital action within an action set. Returns the number of origins supplied in originsOut. Use this to display the appropriate ... |
| [`GetStringForDigitalActionName`](#getstringfordigitalactionname) | Returns a localized string (from Steam's language setting) for the user-facing action name corresponding to the specified handle. |
| [`GetAnalogActionHandle`](#getanalogactionhandle) | Lookup the handle for an analog action. Best to do this once on startup, and store the handles for all future API calls. |
| [`GetAnalogActionOrigins`](#getanalogactionorigins) | Get the origin(s) for an analog action within an action set. Returns the number of origins supplied in originsOut. Use this to display the appropriate ... |
| [`GetGlyphPNGForActionOrigin`](#getglyphpngforactionorigin) | Get a local path to a PNG file for the provided origin's glyph. |
| [`GetGlyphSVGForActionOrigin`](#getglyphsvgforactionorigin) | Get a local path to a SVG file for the provided origin's glyph. |
| [`GetGlyphForActionOrigin_Legacy`](#getglyphforactionorigin_legacy) | Get a local path to an older, Big Picture Mode-style PNG file for a particular origin. |
| [`GetStringForActionOrigin`](#getstringforactionorigin) | Returns a localized string (from Steam's language setting) for the specified origin. |
| [`GetStringForAnalogActionName`](#getstringforanalogactionname) | Returns a localized string (from Steam's language setting) for the user-facing action name corresponding to the specified handle. |
| [`StopAnalogActionMomentum`](#stopanalogactionmomentum) | Stop analog momentum for the action if it is a mouse action in trackball mode. |
| [`TriggerVibration`](#triggervibration) | Trigger a vibration event on supported controllers - Steam will translate these commands into haptic pulses for Steam Controllers. |
| [`TriggerVibrationExtended`](#triggervibrationextended) | Trigger a vibration event on supported controllers including Xbox trigger impulse rumble - Steam will translate these commands into haptic pulses for Steam ... |
| [`TriggerSimpleHapticEvent`](#triggersimplehapticevent) | Send a haptic pulse, works on Steam Deck and Steam Controller devices. |
| [`SetLEDColor`](#setledcolor) | Set the controller LED color on supported controllers. nFlags is a bitmask of values from ESteamInputLEDFlag - 0 will default to setting a color. Steam will ... |
| [`Legacy_TriggerHapticPulse`](#legacy_triggerhapticpulse) | Trigger a haptic pulse on a Steam Controller - if you are approximating rumble you may want to use TriggerVibration instead. Good uses for Haptic pulses ... |
| [`Legacy_TriggerRepeatedHapticPulse`](#legacy_triggerrepeatedhapticpulse) | Trigger a haptic pulse with a duty cycle of usDurationMicroSec / usOffMicroSec, unRepeat times. If you are approximating rumble you may want to use ... |
| [`ShowBindingPanel`](#showbindingpanel) | Invokes the Steam overlay and brings up the binding screen if the user is using Big Picture Mode If the user is not in Big Picture Mode it will open up the ... |
| [`GetInputTypeForHandle`](#getinputtypeforhandle) | Returns the input type for a particular handle - unlike EInputActionOrigin which update with Steam and may return unrecognized values ESteamInputType will ... |
| [`GetControllerForGamepadIndex`](#getcontrollerforgamepadindex) | Returns the associated controller handle for the specified emulated gamepad - can be used with the above 2 functions to identify controllers presented to ... |
| [`GetGamepadIndexForController`](#getgamepadindexforcontroller) | Returns the associated gamepad index for the specified controller, if emulating a gamepad or -1 if not associated with an Xinput index. |
| [`GetStringForXboxOrigin`](#getstringforxboxorigin) | Returns a localized string (from Steam's language setting) for the specified Xbox controller origin. |
| [`GetGlyphForXboxOrigin`](#getglyphforxboxorigin) | Get a local path to art for on-screen glyph for a particular Xbox controller origin. |
| [`GetActionOriginFromXboxOrigin`](#getactionoriginfromxboxorigin) | Get the equivalent ActionOrigin for a given Xbox controller origin this can be chained with GetGlyphForActionOrigin to provide future proof glyphs for ... |
| [`TranslateActionOrigin`](#translateactionorigin) | Convert an origin to another controller type - for inputs not present on the other controller type this will return k_EInputActionOrigin_None When a new ... |
| [`GetDeviceBindingRevision`](#getdevicebindingrevision) | Get the binding revision for a given device. Returns false if the handle was not valid or if a mapping is not yet loaded for the device. |
| [`GetRemotePlaySessionID`](#getremoteplaysessionid) | Get the Steam Remote Play session ID associated with a device, or 0 if there is no session associated with it See isteamremoteplay.h for more information on ... |
| [`GetSessionInputConfigurationSettings`](#getsessioninputconfigurationsettings) | Get a bitmask of the Steam Input Configuration types opted in for the current session. Returns ESteamInputConfigurationEnableType values. Note: user can ... |
| [`SetDualSenseTriggerEffect`](#setdualsensetriggereffect) | Set the trigger effect for a DualSense controller. |
| [`GetDigitalActionData`](#getdigitalactiondata) | Current state of a digital action (a button) on one controller: `bState` pressed, `bActive` the action is in the active action set and bound. Poll it every ... |
| [`GetAnalogActionData`](#getanalogactiondata) | Current state of an analog action (a stick, trigger or pad) on one controller: `x` / `y`, `eMode` the source, `bActive` as for digital actions. Poll it ... |
| [`GetMotionData`](#getmotiondata) | Raw gyro / accelerometer data of a controller that has them (rotation quaternion, acceleration, angular velocity); zeros otherwise. |
| [`Start`](#start) | Calls Init(AExplicitlyCallRunFrame) and remembers it, so the plug-in calls Shutdown when Steam shuts down (or on `Stop`). With `False` (the default) Steam's ... |
| [`Stop`](#stop) | Calls Shutdown if `Start` succeeded; harmless otherwise. |
| [`ConnectedControllers`](#connectedcontrollers) | Handles of the connected controllers (at most STEAM_INPUT_MAX_COUNT); empty until `Start` and the first RunFrame. |
| [`DigitalActionOrigins`](#digitalactionorigins) | The origins (buttons) bound to a digital action in an action set, for glyphs and "press X" texts (GetStringForActionOrigin). |
| [`AnalogActionOrigins`](#analogactionorigins) | The origins (sticks, triggers, pads) bound to an analog action. |

#### Init

```pascal
function Init(bExplicitlyCallRunFrame: Boolean): Boolean;
```

Init and Shutdown must be called when starting/ending use of this interface. if bExplicitlyCallRunFrame is called then you will need to manually call RunFrame each frame, otherwise Steam Input will updated when SteamAPI_RunCallbacks() is called.

#### Shutdown

```pascal
function Shutdown: Boolean;
```

Wraps `SteamAPI_ISteamInput_Shutdown`.

#### SetInputActionManifestFilePath

```pascal
function SetInputActionManifestFilePath(const pchInputActionManifestAbsolutePath: string): Boolean;
```

Set the absolute path to the Input Action Manifest file containing the in-game actions and file paths to the official configurations. Used in games that bundle Steam Input configurations inside of the game depot instead of using the Steam Workshop.

#### RunFrame

```pascal
procedure RunFrame(bReservedValue: Boolean);
```

Synchronize API state with the latest Steam Input action data available. This is performed automatically by SteamAPI_RunCallbacks, but for the absolute lowest possible latency, you call this directly before reading controller state. Note: This must be called from somewhere before GetConnectedControllers will return any handles.

#### BWaitForData

```pascal
function BWaitForData(bWaitForever: Boolean; unTimeout: UInt32): Boolean;
```

Waits on an IPC event from Steam sent when there is new data to be fetched from the data drop. Returns true when data was recievied before the timeout expires. Useful for games with a dedicated input thread.

#### BNewDataAvailable

```pascal
function BNewDataAvailable: Boolean;
```

Returns true if new data has been received since the last time action data was accessed via GetDigitalActionData or GetAnalogActionData. The game will still need to call SteamInput()->RunFrame() or SteamAPI_RunCallbacks() before this to update the data stream.

#### GetConnectedControllers

```pascal
function GetConnectedControllers(handlesOut: Pointer): Integer;
```

Enumerate currently connected Steam Input enabled devices - developers can opt in controller by type (ex: Xbox/Playstation/etc) via the Steam Input settings in the Steamworks site or users can opt-in in their controller settings in Steam. handlesOut should point to a STEAM_INPUT_MAX_COUNT sized array of InputHandle_t handles Returns the number of handles written to handlesOut.

#### EnableDeviceCallbacks

```pascal
procedure EnableDeviceCallbacks;
```

Enable SteamInputDeviceConnected_t and SteamInputDeviceDisconnected_t callbacks. Each controller that is already connected will generate a device connected callback when you enable them.

#### EnableActionEventCallbacks

```pascal
procedure EnableActionEventCallbacks(pCallback: SteamInputActionEventCallbackPointer);
```

Enable SteamInputActionEvent_t callbacks. Directly calls your callback function for lower latency than standard Steam callbacks. Supports one callback at a time. Note: this is called within either SteamInput()->RunFrame or by SteamAPI_RunCallbacks.

#### GetActionSetHandle

```pascal
function GetActionSetHandle(const pszActionSetName: string): InputActionSetHandle_t;
```

Lookup the handle for an Action Set. Best to do this once on startup, and store the handles for all future API calls.

#### ActivateActionSet

```pascal
procedure ActivateActionSet(inputHandle: InputHandle_t; actionSetHandle: InputActionSetHandle_t);
```

Reconfigure the controller to use the specified action set (ie 'Menu', 'Walk' or 'Drive') This is cheap, and can be safely called repeatedly. It's often easier to repeatedly call it in your state loops, instead of trying to place it in all of your state transitions.

#### GetCurrentActionSet

```pascal
function GetCurrentActionSet(inputHandle: InputHandle_t): InputActionSetHandle_t;
```

Wraps `SteamAPI_ISteamInput_GetCurrentActionSet`.

#### ActivateActionSetLayer

```pascal
procedure ActivateActionSetLayer(inputHandle: InputHandle_t; actionSetLayerHandle: InputActionSetHandle_t);
```

ACTION SET LAYERS.

#### DeactivateActionSetLayer

```pascal
procedure DeactivateActionSetLayer(inputHandle: InputHandle_t; actionSetLayerHandle: InputActionSetHandle_t);
```

Wraps `SteamAPI_ISteamInput_DeactivateActionSetLayer`.

#### DeactivateAllActionSetLayers

```pascal
procedure DeactivateAllActionSetLayers(inputHandle: InputHandle_t);
```

Wraps `SteamAPI_ISteamInput_DeactivateAllActionSetLayers`.

#### GetActiveActionSetLayers

```pascal
function GetActiveActionSetLayers(inputHandle: InputHandle_t; handlesOut: Pointer): Integer;
```

Enumerate currently active layers. handlesOut should point to a STEAM_INPUT_MAX_ACTIVE_LAYERS sized array of InputActionSetHandle_t handles Returns the number of handles written to handlesOut.

#### GetDigitalActionHandle

```pascal
function GetDigitalActionHandle(const pszActionName: string): InputDigitalActionHandle_t;
```

Lookup the handle for a digital action. Best to do this once on startup, and store the handles for all future API calls.

#### GetDigitalActionOrigins

```pascal
function GetDigitalActionOrigins(inputHandle: InputHandle_t; actionSetHandle: InputActionSetHandle_t; digitalActionHandle: InputDigitalActionHandle_t; originsOut: Pointer): Integer;
```

Get the origin(s) for a digital action within an action set. Returns the number of origins supplied in originsOut. Use this to display the appropriate on-screen prompt for the action. originsOut should point to a STEAM_INPUT_MAX_ORIGINS sized array of EInputActionOrigin handles. The EInputActionOrigin enum will get extended as support for new controller controllers gets added to the Steam client and will exceed the values from this header, please check bounds if you are using a look up table.

#### GetStringForDigitalActionName

```pascal
function GetStringForDigitalActionName(eActionHandle: InputDigitalActionHandle_t): string;
```

Returns a localized string (from Steam's language setting) for the user-facing action name corresponding to the specified handle.

#### GetAnalogActionHandle

```pascal
function GetAnalogActionHandle(const pszActionName: string): InputAnalogActionHandle_t;
```

Lookup the handle for an analog action. Best to do this once on startup, and store the handles for all future API calls.

#### GetAnalogActionOrigins

```pascal
function GetAnalogActionOrigins(inputHandle: InputHandle_t; actionSetHandle: InputActionSetHandle_t; analogActionHandle: InputAnalogActionHandle_t; originsOut: Pointer): Integer;
```

Get the origin(s) for an analog action within an action set. Returns the number of origins supplied in originsOut. Use this to display the appropriate on-screen prompt for the action. originsOut should point to a STEAM_INPUT_MAX_ORIGINS sized array of EInputActionOrigin handles. The EInputActionOrigin enum will get extended as support for new controller controllers gets added to the Steam client and will exceed the values from this header, please check bounds if you are using a look up table.

#### GetGlyphPNGForActionOrigin

```pascal
function GetGlyphPNGForActionOrigin(eOrigin: EInputActionOrigin; eSize: ESteamInputGlyphSize; unFlags: UInt32): string;
```

Get a local path to a PNG file for the provided origin's glyph.

#### GetGlyphSVGForActionOrigin

```pascal
function GetGlyphSVGForActionOrigin(eOrigin: EInputActionOrigin; unFlags: UInt32): string;
```

Get a local path to a SVG file for the provided origin's glyph.

#### GetGlyphForActionOrigin_Legacy

```pascal
function GetGlyphForActionOrigin_Legacy(eOrigin: EInputActionOrigin): string;
```

Get a local path to an older, Big Picture Mode-style PNG file for a particular origin.

#### GetStringForActionOrigin

```pascal
function GetStringForActionOrigin(eOrigin: EInputActionOrigin): string;
```

Returns a localized string (from Steam's language setting) for the specified origin.

#### GetStringForAnalogActionName

```pascal
function GetStringForAnalogActionName(eActionHandle: InputAnalogActionHandle_t): string;
```

Returns a localized string (from Steam's language setting) for the user-facing action name corresponding to the specified handle.

#### StopAnalogActionMomentum

```pascal
procedure StopAnalogActionMomentum(inputHandle: InputHandle_t; eAction: InputAnalogActionHandle_t);
```

Stop analog momentum for the action if it is a mouse action in trackball mode.

#### TriggerVibration

```pascal
procedure TriggerVibration(inputHandle: InputHandle_t; usLeftSpeed: UInt16; usRightSpeed: UInt16);
```

Trigger a vibration event on supported controllers - Steam will translate these commands into haptic pulses for Steam Controllers.

#### TriggerVibrationExtended

```pascal
procedure TriggerVibrationExtended(inputHandle: InputHandle_t; usLeftSpeed: UInt16; usRightSpeed: UInt16; usLeftTriggerSpeed: UInt16; usRightTriggerSpeed: UInt16);
```

Trigger a vibration event on supported controllers including Xbox trigger impulse rumble - Steam will translate these commands into haptic pulses for Steam Controllers.

#### TriggerSimpleHapticEvent

```pascal
procedure TriggerSimpleHapticEvent(inputHandle: InputHandle_t; eHapticLocation: EControllerHapticLocation; nIntensity: UInt8; nGainDB: AnsiChar; nOtherIntensity: UInt8; nOtherGainDB: AnsiChar);
```

Send a haptic pulse, works on Steam Deck and Steam Controller devices.

#### SetLEDColor

```pascal
procedure SetLEDColor(inputHandle: InputHandle_t; nColorR: UInt8; nColorG: UInt8; nColorB: UInt8; nFlags: UInt32);
```

Set the controller LED color on supported controllers. nFlags is a bitmask of values from ESteamInputLEDFlag - 0 will default to setting a color. Steam will handle the behavior on exit of your program so you don't need to try restore the default as you are shutting down.

#### Legacy_TriggerHapticPulse

```pascal
procedure Legacy_TriggerHapticPulse(inputHandle: InputHandle_t; eTargetPad: ESteamControllerPad; usDurationMicroSec: UInt16);
```

Trigger a haptic pulse on a Steam Controller - if you are approximating rumble you may want to use TriggerVibration instead. Good uses for Haptic pulses include chimes, noises, or directional gameplay feedback (taking damage, footstep locations, etc).

#### Legacy_TriggerRepeatedHapticPulse

```pascal
procedure Legacy_TriggerRepeatedHapticPulse(inputHandle: InputHandle_t; eTargetPad: ESteamControllerPad; usDurationMicroSec: UInt16; usOffMicroSec: UInt16; unRepeat: UInt16; nFlags: UInt32);
```

Trigger a haptic pulse with a duty cycle of usDurationMicroSec / usOffMicroSec, unRepeat times. If you are approximating rumble you may want to use TriggerVibration instead. nFlags is currently unused and reserved for future use.

#### ShowBindingPanel

```pascal
function ShowBindingPanel(inputHandle: InputHandle_t): Boolean;
```

Invokes the Steam overlay and brings up the binding screen if the user is using Big Picture Mode If the user is not in Big Picture Mode it will open up the binding in a new window.

#### GetInputTypeForHandle

```pascal
function GetInputTypeForHandle(inputHandle: InputHandle_t): ESteamInputType;
```

Returns the input type for a particular handle - unlike EInputActionOrigin which update with Steam and may return unrecognized values ESteamInputType will remain static and only return valid values from your SDK version.

#### GetControllerForGamepadIndex

```pascal
function GetControllerForGamepadIndex(nIndex: Integer): InputHandle_t;
```

Returns the associated controller handle for the specified emulated gamepad - can be used with the above 2 functions to identify controllers presented to your game over Xinput. Returns 0 if the Xinput index isn't associated with Steam Input.

#### GetGamepadIndexForController

```pascal
function GetGamepadIndexForController(ulinputHandle: InputHandle_t): Integer;
```

Returns the associated gamepad index for the specified controller, if emulating a gamepad or -1 if not associated with an Xinput index.

#### GetStringForXboxOrigin

```pascal
function GetStringForXboxOrigin(eOrigin: EXboxOrigin): string;
```

Returns a localized string (from Steam's language setting) for the specified Xbox controller origin.

#### GetGlyphForXboxOrigin

```pascal
function GetGlyphForXboxOrigin(eOrigin: EXboxOrigin): string;
```

Get a local path to art for on-screen glyph for a particular Xbox controller origin.

#### GetActionOriginFromXboxOrigin

```pascal
function GetActionOriginFromXboxOrigin(inputHandle: InputHandle_t; eOrigin: EXboxOrigin): EInputActionOrigin;
```

Get the equivalent ActionOrigin for a given Xbox controller origin this can be chained with GetGlyphForActionOrigin to provide future proof glyphs for non-Steam Input API action games. Note - this only translates the buttons directly and doesn't take into account any remapping a user has made in their configuration.

#### TranslateActionOrigin

```pascal
function TranslateActionOrigin(eDestinationInputType: ESteamInputType; eSourceOrigin: EInputActionOrigin): EInputActionOrigin;
```

Convert an origin to another controller type - for inputs not present on the other controller type this will return k_EInputActionOrigin_None When a new input type is added you will be able to pass in k_ESteamInputType_Unknown and the closest origin that your version of the SDK recognized will be returned ex: if a Playstation 5 controller was released this function would return Playstation 4 origins.

#### GetDeviceBindingRevision

```pascal
function GetDeviceBindingRevision(inputHandle: InputHandle_t; var pMajor: Integer; var pMinor: Integer): Boolean;
```

Get the binding revision for a given device. Returns false if the handle was not valid or if a mapping is not yet loaded for the device.

#### GetRemotePlaySessionID

```pascal
function GetRemotePlaySessionID(inputHandle: InputHandle_t): UInt32;
```

Get the Steam Remote Play session ID associated with a device, or 0 if there is no session associated with it See isteamremoteplay.h for more information on Steam Remote Play sessions.

#### GetSessionInputConfigurationSettings

```pascal
function GetSessionInputConfigurationSettings: UInt16;
```

Get a bitmask of the Steam Input Configuration types opted in for the current session. Returns ESteamInputConfigurationEnableType values. Note: user can override the settings from the Steamworks Partner site so the returned values may not exactly match your default configuration.

#### SetDualSenseTriggerEffect

```pascal
procedure SetDualSenseTriggerEffect(inputHandle: InputHandle_t; pParam: Pointer);
```

Set the trigger effect for a DualSense controller.

#### GetDigitalActionData

```pascal
function GetDigitalActionData(inputHandle: InputHandle_t; digitalActionHandle: InputDigitalActionHandle_t): InputDigitalActionData_t;
```

Current state of a digital action (a button) on one controller: `bState` pressed, `bActive` the action is in the active action set and bound. Poll it every frame.

#### GetAnalogActionData

```pascal
function GetAnalogActionData(inputHandle: InputHandle_t; analogActionHandle: InputAnalogActionHandle_t): InputAnalogActionData_t;
```

Current state of an analog action (a stick, trigger or pad) on one controller: `x` / `y`, `eMode` the source, `bActive` as for digital actions. Poll it every frame.

#### GetMotionData

```pascal
function GetMotionData(inputHandle: InputHandle_t): InputMotionData_t;
```

Raw gyro / accelerometer data of a controller that has them (rotation quaternion, acceleration, angular velocity); zeros otherwise.

#### Start

```pascal
function Start(AExplicitlyCallRunFrame: Boolean = False): Boolean;
```

Calls Init(AExplicitlyCallRunFrame) and remembers it, so the plug-in calls Shutdown when Steam shuts down (or on `Stop`). With `False` (the default) Steam's callback pump runs RunFrame; with `True` the game calls RunFrame itself before reading the actions each frame. Returns: (`True` when ISteamInput started.) Raises: (ESteamworksError when the loaded library lacks the Init export.)

#### Stop

```pascal
procedure Stop;
```

Calls Shutdown if `Start` succeeded; harmless otherwise.

#### ConnectedControllers

```pascal
function ConnectedControllers: TSteamInputHandleArray;
```

Handles of the connected controllers (at most STEAM_INPUT_MAX_COUNT); empty until `Start` and the first RunFrame.

#### DigitalActionOrigins

```pascal
function DigitalActionOrigins(inputHandle: InputHandle_t; actionSetHandle: InputActionSetHandle_t; digitalActionHandle: InputDigitalActionHandle_t): TSteamInputOriginArray;
```

The origins (buttons) bound to a digital action in an action set, for glyphs and "press X" texts (GetStringForActionOrigin).

#### AnalogActionOrigins

```pascal
function AnalogActionOrigins(inputHandle: InputHandle_t; actionSetHandle: InputActionSetHandle_t; analogActionHandle: InputAnalogActionHandle_t): TSteamInputOriginArray;
```

The origins (sticks, triggers, pads) bound to an analog action.

### Async methods

None.

### Properties

| Property | Description |
|----------|-------------|
| `Started: Boolean` | `True` between a successful `Start` and `Stop`. |
| `Handle: Pointer` | The raw ISteamInput pointer (first argument of every `Flat` export). |
| `Flat: TSteamInputFlat` | The bound flat exports, for calls the methods do not cover. |

## Payload records

Declared in `Steamworks.SDKTypes` (generated from the SDK headers; layouts verified
against the C headers for Win64, Win32, Linux64 and macOS ARM64).

### SteamInputDeviceConnected_t

Callback id 2801 (`SteamInputDeviceConnected_t_k_iCallback`).

| Field | C declaration |
|-------|---------------|
| `m_ulConnectedDeviceHandle: InputHandle_t` | C field `InputHandle_t m_ulConnectedDeviceHandle`. |

### SteamInputDeviceDisconnected_t

Callback id 2802 (`SteamInputDeviceDisconnected_t_k_iCallback`).

| Field | C declaration |
|-------|---------------|
| `m_ulDisconnectedDeviceHandle: InputHandle_t` | C field `InputHandle_t m_ulDisconnectedDeviceHandle`. |

### SteamInputConfigurationLoaded_t

Callback id 2803 (`SteamInputConfigurationLoaded_t_k_iCallback`).

| Field | C declaration |
|-------|---------------|
| `m_unAppID: AppId_t` | C field `AppId_t m_unAppID`. |
| `m_ulDeviceHandle: InputHandle_t` | C field `InputHandle_t m_ulDeviceHandle`. |
| `m_ulMappingCreator: TSteamID` | C field `CSteamID m_ulMappingCreator`. |
| `m_unMajorRevision: UInt32` | C field `uint32 m_unMajorRevision`. |
| `m_unMinorRevision: UInt32` | C field `uint32 m_unMinorRevision`. |
| `m_bUsesSteamInputAPI: Boolean` | C field `bool m_bUsesSteamInputAPI`. |
| `m_bUsesGamepadAPI: Boolean` | C field `bool m_bUsesGamepadAPI`. |

### SteamInputGamepadSlotChange_t

Callback id 2804 (`SteamInputGamepadSlotChange_t_k_iCallback`).

| Field | C declaration |
|-------|---------------|
| `m_unAppID: AppId_t` | C field `AppId_t m_unAppID`. |
| `m_ulDeviceHandle: InputHandle_t` | C field `InputHandle_t m_ulDeviceHandle`. |
| `m_eDeviceType: ESteamInputType` | C field `ESteamInputType m_eDeviceType`. |
| `m_nOldGamepadSlot: Integer` | C field `int m_nOldGamepadSlot`. |
| `m_nNewGamepadSlot: Integer` | C field `int m_nNewGamepadSlot`. |
