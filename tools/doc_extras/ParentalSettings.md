## Overview

Steam Family View: whether the account is under parental control and which
features or apps are blocked, so the game can hide what the user may not
use.

```pascal
with SteamParentalSettings1.Plugin do
  if BIsParentalLockEnabled and BIsFeatureBlocked(k_EFeatureStore) then
    HideStoreButton;
```

* `BIsParentalLockLocked` - locked now (unlocked with the PIN);
  `BIsAppBlocked` / `BIsAppInBlockList` for an app, `BIsFeatureBlocked` /
  `BIsFeatureInBlockList` for a feature (`k_EFeatureStore`,
  `k_EFeatureCommunity`, `k_EFeatureFriends`, ...).
* `OnSteamParentalSettingsChanged` fires when the settings change.
