Steamworks redistributable for the Delphi Linux64 platform.

Copy libsteam_api.so here from the Steamworks SDK 1.65 zip:
  sdk/redistributable_bin/linux64/libsteam_api.so

The SDK is only available to Steamworks partners
(https://partner.steamgames.com/downloads/steamworks_sdk_165.zip), so the binary
is not part of this repository. Check the licence before committing it.

The demo projects copy it next to the executable after each build (Windows)
or deploy it with the application (macOS / Linux).
