## Overview

Steam's party system for a game that puts players together outside the
game itself: a player creates a *beacon* (open slots + a connect string),
others find it and join, and the beacon owner is told about each
reservation.

```pascal
var
  N: UInt32;
begin
  if SteamParties1.Plugin.GetNumAvailableBeaconLocations(N) then
    Log(Format('%d beacon locations, %d active beacons',
      [N, SteamParties1.Plugin.GetNumActiveBeacons]));
end;
```

* `CreateBeacon` (-> `OnCreateBeaconCallback`), `JoinParty` (->
  `OnJoinPartyCallback`), `OnReservationNotificationCallback` on the owner's
  side, then `OnReservationCompleted` and `DestroyBeacon`.
* **Not bound:** `GetBeaconLocationData` - it takes a
  `SteamPartyBeaconLocation_t` *by value*, which needs a per-platform shim
  (Win64 passes it by reference, x86-64 Linux / macOS in registers).
* `GetBeaconDetails` returns its metadata in a raw `PAnsiChar` buffer.
