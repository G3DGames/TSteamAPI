## Overview

The current user's persona, friends, groups (clans), avatars, rich
presence and the Steam overlay.

### Persona and friends

```pascal
var
  F: TSteamFriendsPlugin;
  I: Integer;
  Id: TSteamID;
begin
  F := SteamFriends1.Plugin;
  Caption := F.GetPersonaName;
  for I := 0 to F.GetFriendCount(k_EFriendFlagImmediate) - 1 do
  begin
    Id := F.GetFriendByIndex(I, k_EFriendFlagImmediate);
    ListBox1.Items.Add(F.GetFriendPersonaName(Id));
  end;
end;
```

Pass the same flags to `GetFriendCount` and `GetFriendByIndex`. Persona
names are UTF-8 in Steam and arrive here as `string`.

`OnPersonaStateChange` fires when a friend's (or your own) name, status,
avatar or game changes; `m_nChangeFlags` says what changed. Steam sends it
for your own SteamID at start-up too.

### Avatars

`GetSmallFriendAvatar` (32 px), `GetMediumFriendAvatar` (64 px) and
`GetLargeFriendAvatar` (184 px) return an image handle:

* a positive handle: ready - `SteamImageToBitmap(Handle, Bitmap)`;
* **-1**: Steam is downloading it - wait for `OnAvatarImageLoaded`
  (`m_steamID`, `m_iImage` = the handle);
* 0: no avatar set.

`RequestUserInformation(SteamID, False)` makes Steam fetch name and avatar of
a user who is not a friend (`OnPersonaStateChange` follows).

### The overlay

* `ActivateGameOverlay('Friends' | 'Community' | 'Players' | 'Settings' |
  'OfficialGameGroup' | 'Stats' | 'Achievements')`.
* `ActivateGameOverlayToWebPage(URL, k_EActivateGameOverlayToWebPageMode_Default)`,
  `ActivateGameOverlayToStore`, `ActivateGameOverlayToUser`,
  `ActivateGameOverlayInviteDialog`.
* `OnGameOverlayActivated` (`m_bActive <> 0`) is the signal to pause a
  single-player game.
* The overlay only appears when the game was started by Steam (or with the
  overlay injected) and renders with a supported graphics API;
  `TSteamUtilsPlugin.IsOverlayEnabled` tells whether it is available.

### Rich presence

`SetRichPresence('status', 'Exploring the caves')` sets what friends see;
the `connect` key makes "Join game" possible (`OnGameRichPresenceJoinRequested`
arrives in the friend's game). `ClearRichPresence` removes all keys. Keys
are limited by Steam (see Valve's rich presence documentation).
