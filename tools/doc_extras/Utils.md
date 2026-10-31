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
