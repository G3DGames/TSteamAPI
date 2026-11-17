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
