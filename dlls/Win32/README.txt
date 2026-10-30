Steamworks redistributable for the Delphi Win32 platform.

Copy steam_api.dll here from the Steamworks SDK 1.65 zip:
  sdk/redistributable_bin/steam_api.dll

The SDK is only available to Steamworks partners
(https://partner.steamgames.com/downloads/steamworks_sdk_165.zip), so the binary
is not part of this repository. Check the licence before committing it.

The demo projects copy it next to the executable after each build (Windows)
or deploy it with the application (macOS / Linux).
