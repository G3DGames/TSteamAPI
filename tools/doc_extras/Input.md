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
