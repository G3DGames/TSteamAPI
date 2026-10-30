# TSteamFriends and TSteamFriendsPlugin (ISteamFriends)

> **Generated** by `tools/gen_docs.py` from `lib/plugins/Steamworks.Plugin.Friends.pas` - do not edit.
> Hand-written text: `tools/doc_extras/Friends.md`. Steam's own descriptions are Valve's
> SDK comments, as in the generated units.

Unit: `Steamworks.Plugin.Friends` - linking it (a `uses` entry, or dropping a `TSteamFriends`) enables the
plug-in. Steam interface: `ISteamFriends` (SDK 1.65).

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

## Contents

* [The component: TSteamFriends](#the-component-tsteamfriends)
  * [Events (21)](#events)
* [The plug-in: TSteamFriendsPlugin](#the-plug-in-tsteamfriendsplugin)
  * [Methods](#methods)
  * [Async methods](#async-methods)
  * [Properties](#properties)
* [Payload records](#payload-records)

## The component: TSteamFriends

ISteamFriends component: drop it next to a TSteamAPI (linked automatically at run time when the owner has exactly one, otherwise set SteamAPI). Its events are the ISteamFriends callbacks; call the interface through `Plugin`.

| Member | Kind | Description |
|--------|------|-------------|
| `SteamAPI` | published property | The `TSteamAPI` this component belongs to. At run time a component whose owner has exactly one `TSteamAPI` links itself. |
| `Plugin` | public property | The `TSteamFriendsPlugin` for calls; `nil` while Steam is not running. |
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
| `OnPersonaStateChange` | 304 | [`PersonaStateChange_t`](#personastatechange_t) | called when a friends' status changes. |
| `OnGameOverlayActivated` | 331 | [`GameOverlayActivated_t`](#gameoverlayactivated_t) | posted when game overlay activates or deactivates the game can use this to be pause or resume single player games. |
| `OnGameServerChangeRequested` | 332 | [`GameServerChangeRequested_t`](#gameserverchangerequested_t) | called when the user tries to join a different game server from their friends list game client should attempt to connect to specified server when this is received. |
| `OnGameLobbyJoinRequested` | 333 | [`GameLobbyJoinRequested_t`](#gamelobbyjoinrequested_t) | called when the user tries to join a lobby from their friends list game client should attempt to connect to specified lobby when this is received. |
| `OnAvatarImageLoaded` | 334 | [`AvatarImageLoaded_t`](#avatarimageloaded_t) | called when an avatar is loaded in from a previous GetLargeFriendAvatar() call if the image wasn't already available. |
| `OnClanOfficerListResponse` | 335 | [`ClanOfficerListResponse_t`](#clanofficerlistresponse_t) | marks the return of a request officer list call. |
| `OnFriendRichPresenceUpdate` | 336 | [`FriendRichPresenceUpdate_t`](#friendrichpresenceupdate_t) | callback indicating updated data about friends rich presence information. |
| `OnGameRichPresenceJoinRequested` | 337 | [`GameRichPresenceJoinRequested_t`](#gamerichpresencejoinrequested_t) | called when the user tries to join a game from their friends list rich presence will have been set with the "connect" key which is set here. |
| `OnGameConnectedClanChatMsg` | 338 | [`GameConnectedClanChatMsg_t`](#gameconnectedclanchatmsg_t) | a chat message has been received for a clan chat the game has joined. |
| `OnGameConnectedChatJoin` | 339 | [`GameConnectedChatJoin_t`](#gameconnectedchatjoin_t) | a user has joined a clan chat. |
| `OnGameConnectedChatLeave` | 340 | [`GameConnectedChatLeave_t`](#gameconnectedchatleave_t) | a user has left the chat we're in. |
| `OnDownloadClanActivityCountsResult` | 341 | [`DownloadClanActivityCountsResult_t`](#downloadclanactivitycountsresult_t) | a DownloadClanActivityCounts() call has finished. |
| `OnJoinClanChatRoomCompletionResult` | 342 | [`JoinClanChatRoomCompletionResult_t`](#joinclanchatroomcompletionresult_t) | a JoinClanChatRoom() call has finished. |
| `OnGameConnectedFriendChatMsg` | 343 | [`GameConnectedFriendChatMsg_t`](#gameconnectedfriendchatmsg_t) | a chat message has been received from a user. |
| `OnFriendsGetFollowerCount` | 344 | [`FriendsGetFollowerCount_t`](#friendsgetfollowercount_t) | see the SDK. |
| `OnFriendsIsFollowing` | 345 | [`FriendsIsFollowing_t`](#friendsisfollowing_t) | see the SDK. |
| `OnFriendsEnumerateFollowingList` | 346 | [`FriendsEnumerateFollowingList_t`](#friendsenumeratefollowinglist_t) | see the SDK. |
| `OnUnreadChatMessagesChanged` | 348 | [`UnreadChatMessagesChanged_t`](#unreadchatmessageschanged_t) | Invoked when the status of unread messages changes. |
| `OnOverlayBrowserProtocolNavigation` | 349 | [`OverlayBrowserProtocolNavigation_t`](#overlaybrowserprotocolnavigation_t) | Dispatched when an overlay browser instance is navigated to a protocol/scheme registered by RegisterProtocolInOverlayBrowser(). |
| `OnEquippedProfileItemsChanged` | 350 | [`EquippedProfileItemsChanged_t`](#equippedprofileitemschanged_t) | A user's equipped profile items have changed. |
| `OnEquippedProfileItems` | 351 | [`EquippedProfileItems_t`](#equippedprofileitems_t) | see the SDK. |

Handler signature (the IDE generates it when you double-click the event):

```pascal
procedure TForm1.SteamFriends1PersonaStateChange(Sender: TObject; const AData: PersonaStateChange_t);
```

## The plug-in: TSteamFriendsPlugin

ISteamFriends plug-in. Registered by linking the unit; find it with @code(Steam.FindPlugin(TSteamFriendsPlugin)).

Reach it through the component (`SteamFriends1.Plugin`) or the core:

```pascal
P := TSteamFriendsPlugin(Steam.FindPlugin(TSteamFriendsPlugin));   // Delphi also: Steam.Plugin<TSteamFriendsPlugin>
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
| [`GetPersonaName`](#getpersonaname) | returns the local players name - guaranteed to not be NULL. this is the same name as on the users community profile page this is stored in UTF-8 format like ... |
| [`GetPersonaState`](#getpersonastate) | gets the status of the current user. |
| [`GetFriendCount`](#getfriendcount) | friend iteration takes a set of k_EFriendFlags, and returns the number of users the client knows about who meet that criteria then GetFriendByIndex() can ... |
| [`GetFriendByIndex`](#getfriendbyindex) | returns the steamID of a user iFriend is a index of range [0, GetFriendCount()) iFriendsFlags must be the same value as used in GetFriendCount() the ... |
| [`GetFriendRelationship`](#getfriendrelationship) | returns a relationship to a user. |
| [`GetFriendPersonaState`](#getfriendpersonastate) | returns the current status of the specified user this will only be known by the local user if steamIDFriend is in their friends list; on the same game ... |
| [`GetFriendPersonaName`](#getfriendpersonaname) | returns the name another user - guaranteed to not be NULL. same rules as GetFriendPersonaState() apply as to whether or not the user knowns the name of the ... |
| [`GetFriendGamePlayed`](#getfriendgameplayed) | returns true if the friend is actually in a game, and fills in pFriendGameInfo with an extra details. |
| [`GetFriendPersonaNameHistory`](#getfriendpersonanamehistory) | accesses old friends names - returns an empty string when their are no more items in the history. |
| [`GetFriendSteamLevel`](#getfriendsteamlevel) | friends steam level. |
| [`GetPlayerNickname`](#getplayernickname) | Returns nickname the current user has set for the specified player. Returns NULL if the no nickname has been set for that player. DEPRECATED: GetPersonaName ... |
| [`GetFriendsGroupCount`](#getfriendsgroupcount) | friend grouping (tag) apis returns the number of friends groups. |
| [`GetFriendsGroupIDByIndex`](#getfriendsgroupidbyindex) | returns the friends group ID for the given index (invalid indices return k_FriendsGroupID_Invalid). |
| [`GetFriendsGroupName`](#getfriendsgroupname) | returns the name for the given friends group (NULL in the case of invalid friends group IDs). |
| [`GetFriendsGroupMembersCount`](#getfriendsgroupmemberscount) | returns the number of members in a given friends group. |
| [`GetFriendsGroupMembersList`](#getfriendsgroupmemberslist) | gets up to nMembersCount members of the given friends group, if fewer exist than requested those positions' SteamIDs will be invalid. |
| [`HasFriend`](#hasfriend) | returns true if the specified user meets any of the criteria specified in iFriendFlags iFriendFlags can be the union (binary or, \|) of one or more ... |
| [`GetClanCount`](#getclancount) | clan (group) iteration and access functions. |
| [`GetClanByIndex`](#getclanbyindex) | Wraps `SteamAPI_ISteamFriends_GetClanByIndex`. |
| [`GetClanName`](#getclanname) | Wraps `SteamAPI_ISteamFriends_GetClanName`. |
| [`GetClanTag`](#getclantag) | Wraps `SteamAPI_ISteamFriends_GetClanTag`. |
| [`GetClanActivityCounts`](#getclanactivitycounts) | returns the most recent information we have about what's happening in a clan. |
| [`DownloadClanActivityCounts`](#downloadclanactivitycounts) | for clans a user is a member of, they will have reasonably up-to-date information, but for others you'll have to download the info to have the latest. Call ... |
| [`GetFriendCountFromSource`](#getfriendcountfromsource) | iterators for getting users in a chat room, lobby, game server or clan note that large clans that cannot be iterated by the local user note that the current ... |
| [`GetFriendFromSourceByIndex`](#getfriendfromsourcebyindex) | Wraps `SteamAPI_ISteamFriends_GetFriendFromSourceByIndex`. |
| [`IsUserInSource`](#isuserinsource) | returns true if the local user can see that steamIDUser is a member or in steamIDSource. |
| [`SetInGameVoiceSpeaking`](#setingamevoicespeaking) | User is in a game pressing the talk button (will suppress the microphone for all voice comms from the Steam friends UI). |
| [`ActivateGameOverlay`](#activategameoverlay) | activates the game overlay, with an optional dialog to open valid options include "Friends", "Community", "Players", "Settings", "OfficialGameGroup", ... |
| [`ActivateGameOverlayToUser`](#activategameoverlaytouser) | activates game overlay to a specific place valid options are "steamid" - opens the overlay web browser to the specified user or groups profile "chat" - ... |
| [`ActivateGameOverlayToWebPage`](#activategameoverlaytowebpage) | activates game overlay web browser directly to the specified URL full address with protocol type is required, e.g. http://www.steamgames.com/. |
| [`ActivateGameOverlayToStore`](#activategameoverlaytostore) | activates game overlay to store page for app. |
| [`SetPlayedWith`](#setplayedwith) | Mark a target user as 'played with'. This is a client-side only feature that requires that the calling user is in game. |
| [`ActivateGameOverlayInviteDialog`](#activategameoverlayinvitedialog) | activates game overlay to open the invite dialog. Invitations will be sent for the provided lobby. |
| [`GetSmallFriendAvatar`](#getsmallfriendavatar) | gets the small (32x32) avatar of the current user, which is a handle to be used in IClientUtils::GetImageRGBA(), or 0 if none set. |
| [`GetMediumFriendAvatar`](#getmediumfriendavatar) | gets the medium (64x64) avatar of the current user, which is a handle to be used in IClientUtils::GetImageRGBA(), or 0 if none set. |
| [`GetLargeFriendAvatar`](#getlargefriendavatar) | gets the large (184x184) avatar of the current user, which is a handle to be used in IClientUtils::GetImageRGBA(), or 0 if none set returns -1 if this image ... |
| [`RequestUserInformation`](#requestuserinformation) | requests information about a user - persona name & avatar if bRequireNameOnly is set, then the avatar of a user isn't downloaded - it's a lot slower to ... |
| [`RequestClanOfficerList`](#requestclanofficerlist) | requests information about a clan officer list when complete, data is returned in ClanOfficerListResponse_t call result this makes available the calls below ... |
| [`GetClanOwner`](#getclanowner) | returns the steamID of the clan owner. |
| [`GetClanOfficerCount`](#getclanofficercount) | returns the number of officers in a clan (including the owner). |
| [`GetClanOfficerByIndex`](#getclanofficerbyindex) | returns the steamID of a clan officer, by index, of range [0,GetClanOfficerCount). |
| [`SetRichPresence`](#setrichpresence) | Rich Presence data is automatically shared between friends who are in the same game Each user has a set of Key/Value pairs Note the following limits: ... |
| [`ClearRichPresence`](#clearrichpresence) | Wraps `SteamAPI_ISteamFriends_ClearRichPresence`. |
| [`GetFriendRichPresence`](#getfriendrichpresence) | Wraps `SteamAPI_ISteamFriends_GetFriendRichPresence`. |
| [`GetFriendRichPresenceKeyCount`](#getfriendrichpresencekeycount) | Wraps `SteamAPI_ISteamFriends_GetFriendRichPresenceKeyCount`. |
| [`GetFriendRichPresenceKeyByIndex`](#getfriendrichpresencekeybyindex) | Wraps `SteamAPI_ISteamFriends_GetFriendRichPresenceKeyByIndex`. |
| [`RequestFriendRichPresence`](#requestfriendrichpresence) | Requests rich presence for a specific user. |
| [`InviteUserToGame`](#inviteusertogame) | Rich invite support. If the target accepts the invite, a GameRichPresenceJoinRequested_t callback is posted containing the connect string. (Or you can ... |
| [`GetCoplayFriendCount`](#getcoplayfriendcount) | recently-played-with friends iteration this iterates the entire list of users recently played with, across games GetFriendCoplayTime() returns as a unix time. |
| [`GetCoplayFriend`](#getcoplayfriend) | Wraps `SteamAPI_ISteamFriends_GetCoplayFriend`. |
| [`GetFriendCoplayTime`](#getfriendcoplaytime) | Wraps `SteamAPI_ISteamFriends_GetFriendCoplayTime`. |
| [`GetFriendCoplayGame`](#getfriendcoplaygame) | Wraps `SteamAPI_ISteamFriends_GetFriendCoplayGame`. |
| [`JoinClanChatRoom`](#joinclanchatroom) | chat interface for games this allows in-game access to group (clan) chats from in the game the behavior is somewhat sophisticated, because the user may or ... |
| [`LeaveClanChatRoom`](#leaveclanchatroom) | Wraps `SteamAPI_ISteamFriends_LeaveClanChatRoom`. |
| [`GetClanChatMemberCount`](#getclanchatmembercount) | Wraps `SteamAPI_ISteamFriends_GetClanChatMemberCount`. |
| [`GetChatMemberByIndex`](#getchatmemberbyindex) | Wraps `SteamAPI_ISteamFriends_GetChatMemberByIndex`. |
| [`SendClanChatMessage`](#sendclanchatmessage) | Wraps `SteamAPI_ISteamFriends_SendClanChatMessage`. |
| [`GetClanChatMessage`](#getclanchatmessage) | Wraps `SteamAPI_ISteamFriends_GetClanChatMessage`. |
| [`IsClanChatAdmin`](#isclanchatadmin) | Wraps `SteamAPI_ISteamFriends_IsClanChatAdmin`. |
| [`IsClanChatWindowOpenInSteam`](#isclanchatwindowopeninsteam) | interact with the Steam (game overlay / desktop). |
| [`OpenClanChatWindowInSteam`](#openclanchatwindowinsteam) | Wraps `SteamAPI_ISteamFriends_OpenClanChatWindowInSteam`. |
| [`CloseClanChatWindowInSteam`](#closeclanchatwindowinsteam) | Wraps `SteamAPI_ISteamFriends_CloseClanChatWindowInSteam`. |
| [`SetListenForFriendsMessages`](#setlistenforfriendsmessages) | peer-to-peer chat interception this is so you can show P2P chats inline in the game. |
| [`ReplyToFriendMessage`](#replytofriendmessage) | Wraps `SteamAPI_ISteamFriends_ReplyToFriendMessage`. |
| [`GetFriendMessage`](#getfriendmessage) | Wraps `SteamAPI_ISteamFriends_GetFriendMessage`. |
| [`GetFollowerCount`](#getfollowercount) | following apis. Call result: `FriendsGetFollowerCount_t` (`FriendsGetFollowerCount_t_k_iCallback`). |
| [`IsFollowing`](#isfollowing) | Wraps `SteamAPI_ISteamFriends_IsFollowing`. Call result: `FriendsIsFollowing_t` (`FriendsIsFollowing_t_k_iCallback`). |
| [`EnumerateFollowingList`](#enumeratefollowinglist) | Wraps `SteamAPI_ISteamFriends_EnumerateFollowingList`. Call result: `FriendsEnumerateFollowingList_t` (`FriendsEnumerateFollowingList_t_k_iCallback`). |
| [`IsClanPublic`](#isclanpublic) | Wraps `SteamAPI_ISteamFriends_IsClanPublic`. |
| [`IsClanOfficialGameGroup`](#isclanofficialgamegroup) | Wraps `SteamAPI_ISteamFriends_IsClanOfficialGameGroup`. |
| [`GetNumChatsWithUnreadPriorityMessages`](#getnumchatswithunreadprioritymessages) | Return the number of chats (friends or chat rooms) with unread messages. A "priority" message is one that would generate some sort of toast or notification, ... |
| [`ActivateGameOverlayRemotePlayTogetherInviteDialog`](#activategameoverlayremoteplaytogetherinvitedialog) | activates game overlay to open the remote play together invite dialog. Invitations will be sent for remote play together. |
| [`RegisterProtocolInOverlayBrowser`](#registerprotocolinoverlaybrowser) | Call this before calling ActivateGameOverlayToWebPage() to have the Steam Overlay Browser block navigations to your specified protocol (scheme) uris and ... |
| [`ActivateGameOverlayInviteDialogConnectString`](#activategameoverlayinvitedialogconnectstring) | Activates the game overlay to open an invite dialog that will send the provided Rich Presence connect string to selected friends. |
| [`RequestEquippedProfileItems`](#requestequippedprofileitems) | Steam Community items equipped by a user on their profile You can register for EquippedProfileItemsChanged_t to know when a friend has changed their ... |
| [`BHasEquippedProfileItem`](#bhasequippedprofileitem) | Wraps `SteamAPI_ISteamFriends_BHasEquippedProfileItem`. |
| [`GetProfileItemPropertyString`](#getprofileitempropertystring) | Wraps `SteamAPI_ISteamFriends_GetProfileItemPropertyString`. |
| [`GetProfileItemPropertyUint`](#getprofileitempropertyuint) | Wraps `SteamAPI_ISteamFriends_GetProfileItemPropertyUint`. |

#### GetPersonaName

```pascal
function GetPersonaName: string;
```

returns the local players name - guaranteed to not be NULL. this is the same name as on the users community profile page this is stored in UTF-8 format like all the other interface functions that return a char *, it's important that this pointer is not saved off; it will eventually be free'd or re-allocated.

#### GetPersonaState

```pascal
function GetPersonaState: EPersonaState;
```

gets the status of the current user.

#### GetFriendCount

```pascal
function GetFriendCount(iFriendFlags: Integer): Integer;
```

friend iteration takes a set of k_EFriendFlags, and returns the number of users the client knows about who meet that criteria then GetFriendByIndex() can then be used to return the id's of each of those users.

#### GetFriendByIndex

```pascal
function GetFriendByIndex(iFriend: Integer; iFriendFlags: Integer): TSteamID;
```

returns the steamID of a user iFriend is a index of range [0, GetFriendCount()) iFriendsFlags must be the same value as used in GetFriendCount() the returned CSteamID can then be used by all the functions below to access details about the user.

#### GetFriendRelationship

```pascal
function GetFriendRelationship(const steamIDFriend: TSteamID): EFriendRelationship;
```

returns a relationship to a user.

#### GetFriendPersonaState

```pascal
function GetFriendPersonaState(const steamIDFriend: TSteamID): EPersonaState;
```

returns the current status of the specified user this will only be known by the local user if steamIDFriend is in their friends list; on the same game server; in a chat room or lobby; or in a small group with the local user.

#### GetFriendPersonaName

```pascal
function GetFriendPersonaName(const steamIDFriend: TSteamID): string;
```

returns the name another user - guaranteed to not be NULL. same rules as GetFriendPersonaState() apply as to whether or not the user knowns the name of the other user note that on first joining a lobby, chat room or game server the local user will not known the name of the other users automatically; that information will arrive asyncronously.

#### GetFriendGamePlayed

```pascal
function GetFriendGamePlayed(const steamIDFriend: TSteamID; var pFriendGameInfo: FriendGameInfo_t): Boolean;
```

returns true if the friend is actually in a game, and fills in pFriendGameInfo with an extra details.

#### GetFriendPersonaNameHistory

```pascal
function GetFriendPersonaNameHistory(const steamIDFriend: TSteamID; iPersonaName: Integer): string;
```

accesses old friends names - returns an empty string when their are no more items in the history.

#### GetFriendSteamLevel

```pascal
function GetFriendSteamLevel(const steamIDFriend: TSteamID): Integer;
```

friends steam level.

#### GetPlayerNickname

```pascal
function GetPlayerNickname(const steamIDPlayer: TSteamID): string;
```

Returns nickname the current user has set for the specified player. Returns NULL if the no nickname has been set for that player. DEPRECATED: GetPersonaName follows the Steam nickname preferences, so apps shouldn't need to care about nicknames explicitly.

#### GetFriendsGroupCount

```pascal
function GetFriendsGroupCount: Integer;
```

friend grouping (tag) apis returns the number of friends groups.

#### GetFriendsGroupIDByIndex

```pascal
function GetFriendsGroupIDByIndex(iFG: Integer): FriendsGroupID_t;
```

returns the friends group ID for the given index (invalid indices return k_FriendsGroupID_Invalid).

#### GetFriendsGroupName

```pascal
function GetFriendsGroupName(friendsGroupID: FriendsGroupID_t): string;
```

returns the name for the given friends group (NULL in the case of invalid friends group IDs).

#### GetFriendsGroupMembersCount

```pascal
function GetFriendsGroupMembersCount(friendsGroupID: FriendsGroupID_t): Integer;
```

returns the number of members in a given friends group.

#### GetFriendsGroupMembersList

```pascal
procedure GetFriendsGroupMembersList(friendsGroupID: FriendsGroupID_t; pOutSteamIDMembers: Pointer; nMembersCount: Integer);
```

gets up to nMembersCount members of the given friends group, if fewer exist than requested those positions' SteamIDs will be invalid.

#### HasFriend

```pascal
function HasFriend(const steamIDFriend: TSteamID; iFriendFlags: Integer): Boolean;
```

returns true if the specified user meets any of the criteria specified in iFriendFlags iFriendFlags can be the union (binary or, |) of one or more k_EFriendFlags values.

#### GetClanCount

```pascal
function GetClanCount: Integer;
```

clan (group) iteration and access functions.

#### GetClanByIndex

```pascal
function GetClanByIndex(iClan: Integer): TSteamID;
```

Wraps `SteamAPI_ISteamFriends_GetClanByIndex`.

#### GetClanName

```pascal
function GetClanName(const steamIDClan: TSteamID): string;
```

Wraps `SteamAPI_ISteamFriends_GetClanName`.

#### GetClanTag

```pascal
function GetClanTag(const steamIDClan: TSteamID): string;
```

Wraps `SteamAPI_ISteamFriends_GetClanTag`.

#### GetClanActivityCounts

```pascal
function GetClanActivityCounts(const steamIDClan: TSteamID; var pnOnline: Integer; var pnInGame: Integer; var pnChatting: Integer): Boolean;
```

returns the most recent information we have about what's happening in a clan.

#### DownloadClanActivityCounts

```pascal
function DownloadClanActivityCounts(psteamIDClans: Pointer; cClansToRequest: Integer): SteamAPICall_t;
```

for clans a user is a member of, they will have reasonably up-to-date information, but for others you'll have to download the info to have the latest. Call result: `DownloadClanActivityCountsResult_t` (`DownloadClanActivityCountsResult_t_k_iCallback`).

#### GetFriendCountFromSource

```pascal
function GetFriendCountFromSource(const steamIDSource: TSteamID): Integer;
```

iterators for getting users in a chat room, lobby, game server or clan note that large clans that cannot be iterated by the local user note that the current user must be in a lobby to retrieve CSteamIDs of other users in that lobby steamIDSource can be the steamID of a group, game server, lobby or chat room.

#### GetFriendFromSourceByIndex

```pascal
function GetFriendFromSourceByIndex(const steamIDSource: TSteamID; iFriend: Integer): TSteamID;
```

Wraps `SteamAPI_ISteamFriends_GetFriendFromSourceByIndex`.

#### IsUserInSource

```pascal
function IsUserInSource(const steamIDUser: TSteamID; const steamIDSource: TSteamID): Boolean;
```

returns true if the local user can see that steamIDUser is a member or in steamIDSource.

#### SetInGameVoiceSpeaking

```pascal
procedure SetInGameVoiceSpeaking(const steamIDUser: TSteamID; bSpeaking: Boolean);
```

User is in a game pressing the talk button (will suppress the microphone for all voice comms from the Steam friends UI).

#### ActivateGameOverlay

```pascal
procedure ActivateGameOverlay(const pchDialog: string);
```

activates the game overlay, with an optional dialog to open valid options include "Friends", "Community", "Players", "Settings", "OfficialGameGroup", "Stats", "Achievements", "chatroomgroup/nnnn".

#### ActivateGameOverlayToUser

```pascal
procedure ActivateGameOverlayToUser(const pchDialog: string; const steamID: TSteamID);
```

activates game overlay to a specific place valid options are "steamid" - opens the overlay web browser to the specified user or groups profile "chat" - opens a chat window to the specified user, or joins the group chat "jointrade" - opens a window to a Steam Trading session that was started with the ISteamEconomy/StartTrade Web API "stats" - opens the overlay web browser to the specified user's stats "achievements" - opens the overlay web browser to the specified user's achievements "friendadd" - opens the overlay in minimal mode prompting the user to add the target user as a friend "friendremove" - opens the overlay in minimal mode prompting the user to remove the target friend "friendrequestaccept" - opens the overlay in minimal mode prompting the user to accept an incoming friend invite "friendrequestignore" - opens the overlay in minimal mode prompting the user to ignore an incoming friend invite.

#### ActivateGameOverlayToWebPage

```pascal
procedure ActivateGameOverlayToWebPage(const pchURL: string; eMode: EActivateGameOverlayToWebPageMode);
```

activates game overlay web browser directly to the specified URL full address with protocol type is required, e.g. http://www.steamgames.com/.

#### ActivateGameOverlayToStore

```pascal
procedure ActivateGameOverlayToStore(nAppID: AppId_t; eFlag: EOverlayToStoreFlag);
```

activates game overlay to store page for app.

#### SetPlayedWith

```pascal
procedure SetPlayedWith(const steamIDUserPlayedWith: TSteamID);
```

Mark a target user as 'played with'. This is a client-side only feature that requires that the calling user is in game.

#### ActivateGameOverlayInviteDialog

```pascal
procedure ActivateGameOverlayInviteDialog(const steamIDLobby: TSteamID);
```

activates game overlay to open the invite dialog. Invitations will be sent for the provided lobby.

#### GetSmallFriendAvatar

```pascal
function GetSmallFriendAvatar(const steamIDFriend: TSteamID): Integer;
```

gets the small (32x32) avatar of the current user, which is a handle to be used in IClientUtils::GetImageRGBA(), or 0 if none set.

#### GetMediumFriendAvatar

```pascal
function GetMediumFriendAvatar(const steamIDFriend: TSteamID): Integer;
```

gets the medium (64x64) avatar of the current user, which is a handle to be used in IClientUtils::GetImageRGBA(), or 0 if none set.

#### GetLargeFriendAvatar

```pascal
function GetLargeFriendAvatar(const steamIDFriend: TSteamID): Integer;
```

gets the large (184x184) avatar of the current user, which is a handle to be used in IClientUtils::GetImageRGBA(), or 0 if none set returns -1 if this image has yet to be loaded, in this case wait for a AvatarImageLoaded_t callback and then call this again.

#### RequestUserInformation

```pascal
function RequestUserInformation(const steamIDUser: TSteamID; bRequireNameOnly: Boolean): Boolean;
```

requests information about a user - persona name & avatar if bRequireNameOnly is set, then the avatar of a user isn't downloaded - it's a lot slower to download avatars and churns the local cache, so if you don't need avatars, don't request them if returns true, it means that data is being requested, and a PersonaStateChange_t callback will be posted when it's retrieved if returns false, it means that we already have all the details about that user, and functions can be called immediately.

#### RequestClanOfficerList

```pascal
function RequestClanOfficerList(const steamIDClan: TSteamID): SteamAPICall_t;
```

requests information about a clan officer list when complete, data is returned in ClanOfficerListResponse_t call result this makes available the calls below you can only ask about clans that a user is a member of note that this won't download avatars automatically; if you get an officer, and no avatar image is available, call RequestUserInformation( steamID, false ) to download the avatar. Call result: `ClanOfficerListResponse_t` (`ClanOfficerListResponse_t_k_iCallback`).

#### GetClanOwner

```pascal
function GetClanOwner(const steamIDClan: TSteamID): TSteamID;
```

returns the steamID of the clan owner.

#### GetClanOfficerCount

```pascal
function GetClanOfficerCount(const steamIDClan: TSteamID): Integer;
```

returns the number of officers in a clan (including the owner).

#### GetClanOfficerByIndex

```pascal
function GetClanOfficerByIndex(const steamIDClan: TSteamID; iOfficer: Integer): TSteamID;
```

returns the steamID of a clan officer, by index, of range [0,GetClanOfficerCount).

#### SetRichPresence

```pascal
function SetRichPresence(const pchKey: string; const pchValue: string): Boolean;
```

Rich Presence data is automatically shared between friends who are in the same game Each user has a set of Key/Value pairs Note the following limits: k_cchMaxRichPresenceKeys, k_cchMaxRichPresenceKeyLength, k_cchMaxRichPresenceValueLength There are five magic keys: "status" - a UTF-8 string that will show up in the 'view game info' dialog in the Steam friends list "connect" - a UTF-8 string that contains the command-line for how a friend can connect to a game "steam_display" - Names a rich presence localization token that will be displayed in the viewing user's selected language in the Steam client UI. For more info: https://partner.steamgames.com/doc/api/ISteamFriends#richpresencelocalization "steam_player_group" - When set, indicates to the Steam client that the player is a member of a particular group. Players in the same group may be organized together in various places in the Steam UI. "steam_player_group_size" - When set, indicates the total number of players in the steam_player_group. The Steam client may use this number to display additional information about a group when all of the members are not part of a user's friends list. GetFriendRichPresence() returns an empty string "" if no value is set SetRichPresence() to a NULL or an empty string deletes the key You can iterate the current set of keys for a friend with GetFriendRichPresenceKeyCount() and GetFriendRichPresenceKeyByIndex() (typically only used for debugging).

#### ClearRichPresence

```pascal
procedure ClearRichPresence;
```

Wraps `SteamAPI_ISteamFriends_ClearRichPresence`.

#### GetFriendRichPresence

```pascal
function GetFriendRichPresence(const steamIDFriend: TSteamID; const pchKey: string): string;
```

Wraps `SteamAPI_ISteamFriends_GetFriendRichPresence`.

#### GetFriendRichPresenceKeyCount

```pascal
function GetFriendRichPresenceKeyCount(const steamIDFriend: TSteamID): Integer;
```

Wraps `SteamAPI_ISteamFriends_GetFriendRichPresenceKeyCount`.

#### GetFriendRichPresenceKeyByIndex

```pascal
function GetFriendRichPresenceKeyByIndex(const steamIDFriend: TSteamID; iKey: Integer): string;
```

Wraps `SteamAPI_ISteamFriends_GetFriendRichPresenceKeyByIndex`.

#### RequestFriendRichPresence

```pascal
procedure RequestFriendRichPresence(const steamIDFriend: TSteamID);
```

Requests rich presence for a specific user.

#### InviteUserToGame

```pascal
function InviteUserToGame(const steamIDFriend: TSteamID; const pchConnectString: string): Boolean;
```

Rich invite support. If the target accepts the invite, a GameRichPresenceJoinRequested_t callback is posted containing the connect string. (Or you can configure your game so that it is passed on the command line instead. This is a deprecated path; ask us if you really need this.).

#### GetCoplayFriendCount

```pascal
function GetCoplayFriendCount: Integer;
```

recently-played-with friends iteration this iterates the entire list of users recently played with, across games GetFriendCoplayTime() returns as a unix time.

#### GetCoplayFriend

```pascal
function GetCoplayFriend(iCoplayFriend: Integer): TSteamID;
```

Wraps `SteamAPI_ISteamFriends_GetCoplayFriend`.

#### GetFriendCoplayTime

```pascal
function GetFriendCoplayTime(const steamIDFriend: TSteamID): Integer;
```

Wraps `SteamAPI_ISteamFriends_GetFriendCoplayTime`.

#### GetFriendCoplayGame

```pascal
function GetFriendCoplayGame(const steamIDFriend: TSteamID): AppId_t;
```

Wraps `SteamAPI_ISteamFriends_GetFriendCoplayGame`.

#### JoinClanChatRoom

```pascal
function JoinClanChatRoom(const steamIDClan: TSteamID): SteamAPICall_t;
```

chat interface for games this allows in-game access to group (clan) chats from in the game the behavior is somewhat sophisticated, because the user may or may not be already in the group chat from outside the game or in the overlay use ActivateGameOverlayToUser( "chat", steamIDClan ) to open the in-game overlay version of the chat. Call result: `JoinClanChatRoomCompletionResult_t` (`JoinClanChatRoomCompletionResult_t_k_iCallback`).

#### LeaveClanChatRoom

```pascal
function LeaveClanChatRoom(const steamIDClan: TSteamID): Boolean;
```

Wraps `SteamAPI_ISteamFriends_LeaveClanChatRoom`.

#### GetClanChatMemberCount

```pascal
function GetClanChatMemberCount(const steamIDClan: TSteamID): Integer;
```

Wraps `SteamAPI_ISteamFriends_GetClanChatMemberCount`.

#### GetChatMemberByIndex

```pascal
function GetChatMemberByIndex(const steamIDClan: TSteamID; iUser: Integer): TSteamID;
```

Wraps `SteamAPI_ISteamFriends_GetChatMemberByIndex`.

#### SendClanChatMessage

```pascal
function SendClanChatMessage(const steamIDClanChat: TSteamID; const pchText: string): Boolean;
```

Wraps `SteamAPI_ISteamFriends_SendClanChatMessage`.

#### GetClanChatMessage

```pascal
function GetClanChatMessage(const steamIDClanChat: TSteamID; iMessage: Integer; prgchText: Pointer; cchTextMax: Integer; var peChatEntryType: EChatEntryType; var psteamidChatter: TSteamID): Integer;
```

Wraps `SteamAPI_ISteamFriends_GetClanChatMessage`.

#### IsClanChatAdmin

```pascal
function IsClanChatAdmin(const steamIDClanChat: TSteamID; const steamIDUser: TSteamID): Boolean;
```

Wraps `SteamAPI_ISteamFriends_IsClanChatAdmin`.

#### IsClanChatWindowOpenInSteam

```pascal
function IsClanChatWindowOpenInSteam(const steamIDClanChat: TSteamID): Boolean;
```

interact with the Steam (game overlay / desktop).

#### OpenClanChatWindowInSteam

```pascal
function OpenClanChatWindowInSteam(const steamIDClanChat: TSteamID): Boolean;
```

Wraps `SteamAPI_ISteamFriends_OpenClanChatWindowInSteam`.

#### CloseClanChatWindowInSteam

```pascal
function CloseClanChatWindowInSteam(const steamIDClanChat: TSteamID): Boolean;
```

Wraps `SteamAPI_ISteamFriends_CloseClanChatWindowInSteam`.

#### SetListenForFriendsMessages

```pascal
function SetListenForFriendsMessages(bInterceptEnabled: Boolean): Boolean;
```

peer-to-peer chat interception this is so you can show P2P chats inline in the game.

#### ReplyToFriendMessage

```pascal
function ReplyToFriendMessage(const steamIDFriend: TSteamID; const pchMsgToSend: string): Boolean;
```

Wraps `SteamAPI_ISteamFriends_ReplyToFriendMessage`.

#### GetFriendMessage

```pascal
function GetFriendMessage(const steamIDFriend: TSteamID; iMessageID: Integer; pvData: Pointer; cubData: Integer; var peChatEntryType: EChatEntryType): Integer;
```

Wraps `SteamAPI_ISteamFriends_GetFriendMessage`.

#### GetFollowerCount

```pascal
function GetFollowerCount(const steamID: TSteamID): SteamAPICall_t;
```

following apis. Call result: `FriendsGetFollowerCount_t` (`FriendsGetFollowerCount_t_k_iCallback`).

#### IsFollowing

```pascal
function IsFollowing(const steamID: TSteamID): SteamAPICall_t;
```

Wraps `SteamAPI_ISteamFriends_IsFollowing`. Call result: `FriendsIsFollowing_t` (`FriendsIsFollowing_t_k_iCallback`).

#### EnumerateFollowingList

```pascal
function EnumerateFollowingList(unStartIndex: UInt32): SteamAPICall_t;
```

Wraps `SteamAPI_ISteamFriends_EnumerateFollowingList`. Call result: `FriendsEnumerateFollowingList_t` (`FriendsEnumerateFollowingList_t_k_iCallback`).

#### IsClanPublic

```pascal
function IsClanPublic(const steamIDClan: TSteamID): Boolean;
```

Wraps `SteamAPI_ISteamFriends_IsClanPublic`.

#### IsClanOfficialGameGroup

```pascal
function IsClanOfficialGameGroup(const steamIDClan: TSteamID): Boolean;
```

Wraps `SteamAPI_ISteamFriends_IsClanOfficialGameGroup`.

#### GetNumChatsWithUnreadPriorityMessages

```pascal
function GetNumChatsWithUnreadPriorityMessages: Integer;
```

Return the number of chats (friends or chat rooms) with unread messages. A "priority" message is one that would generate some sort of toast or notification, and depends on user settings. You can register for UnreadChatMessagesChanged_t callbacks to know when this has potentially changed.

#### ActivateGameOverlayRemotePlayTogetherInviteDialog

```pascal
procedure ActivateGameOverlayRemotePlayTogetherInviteDialog(const steamIDLobby: TSteamID);
```

activates game overlay to open the remote play together invite dialog. Invitations will be sent for remote play together.

#### RegisterProtocolInOverlayBrowser

```pascal
function RegisterProtocolInOverlayBrowser(const pchProtocol: string): Boolean;
```

Call this before calling ActivateGameOverlayToWebPage() to have the Steam Overlay Browser block navigations to your specified protocol (scheme) uris and instead dispatch a OverlayBrowserProtocolNavigation_t callback to your game. ActivateGameOverlayToWebPage() must have been called with k_EActivateGameOverlayToWebPageMode_Modal.

#### ActivateGameOverlayInviteDialogConnectString

```pascal
procedure ActivateGameOverlayInviteDialogConnectString(const pchConnectString: string);
```

Activates the game overlay to open an invite dialog that will send the provided Rich Presence connect string to selected friends.

#### RequestEquippedProfileItems

```pascal
function RequestEquippedProfileItems(const steamID: TSteamID): SteamAPICall_t;
```

Steam Community items equipped by a user on their profile You can register for EquippedProfileItemsChanged_t to know when a friend has changed their equipped profile items. Call result: `EquippedProfileItems_t` (`EquippedProfileItems_t_k_iCallback`).

#### BHasEquippedProfileItem

```pascal
function BHasEquippedProfileItem(const steamID: TSteamID; itemType: ECommunityProfileItemType): Boolean;
```

Wraps `SteamAPI_ISteamFriends_BHasEquippedProfileItem`.

#### GetProfileItemPropertyString

```pascal
function GetProfileItemPropertyString(const steamID: TSteamID; itemType: ECommunityProfileItemType; prop: ECommunityProfileItemProperty): string;
```

Wraps `SteamAPI_ISteamFriends_GetProfileItemPropertyString`.

#### GetProfileItemPropertyUint

```pascal
function GetProfileItemPropertyUint(const steamID: TSteamID; itemType: ECommunityProfileItemType; prop: ECommunityProfileItemProperty): UInt32;
```

Wraps `SteamAPI_ISteamFriends_GetProfileItemPropertyUint`.

### Async methods

Each `...Async` method starts the call and registers `AHandler` for its result
(`procedure(const AData: TSteamCallbackData; AIOFailure: Boolean) of object`). The
handler runs once, on the delivery thread, with the result record in `AData`
(`AData.CopyTo(Rec, SizeOf(Rec))`); its object owns the registration - call
`Steam.Dispatcher.RemoveOwner(Self)` in that object's destructor. The plain method of
the same name returns the `SteamAPICall_t` instead, and its result reaches the
component's event.

#### DownloadClanActivityCountsAsync

```pascal
function DownloadClanActivityCountsAsync(psteamIDClans: Pointer; cClansToRequest: Integer; AHandler: TSteamCallResultEvent): SteamAPICall_t;
```

Calls `DownloadClanActivityCounts` and registers AHandler for its result (`DownloadClanActivityCountsResult_t`). The handler's object owns the registration (remove it with Steam.Dispatcher.RemoveOwner). Returns: (The call handle, or k_uAPICallInvalid when Steam refused the call.)

#### RequestClanOfficerListAsync

```pascal
function RequestClanOfficerListAsync(const steamIDClan: TSteamID; AHandler: TSteamCallResultEvent): SteamAPICall_t;
```

Calls `RequestClanOfficerList` and registers AHandler for its result (`ClanOfficerListResponse_t`). The handler's object owns the registration (remove it with Steam.Dispatcher.RemoveOwner). Returns: (The call handle, or k_uAPICallInvalid when Steam refused the call.)

#### JoinClanChatRoomAsync

```pascal
function JoinClanChatRoomAsync(const steamIDClan: TSteamID; AHandler: TSteamCallResultEvent): SteamAPICall_t;
```

Calls `JoinClanChatRoom` and registers AHandler for its result (`JoinClanChatRoomCompletionResult_t`). The handler's object owns the registration (remove it with Steam.Dispatcher.RemoveOwner). Returns: (The call handle, or k_uAPICallInvalid when Steam refused the call.)

#### GetFollowerCountAsync

```pascal
function GetFollowerCountAsync(const steamID: TSteamID; AHandler: TSteamCallResultEvent): SteamAPICall_t;
```

Calls `GetFollowerCount` and registers AHandler for its result (`FriendsGetFollowerCount_t`). The handler's object owns the registration (remove it with Steam.Dispatcher.RemoveOwner). Returns: (The call handle, or k_uAPICallInvalid when Steam refused the call.)

#### IsFollowingAsync

```pascal
function IsFollowingAsync(const steamID: TSteamID; AHandler: TSteamCallResultEvent): SteamAPICall_t;
```

Calls `IsFollowing` and registers AHandler for its result (`FriendsIsFollowing_t`). The handler's object owns the registration (remove it with Steam.Dispatcher.RemoveOwner). Returns: (The call handle, or k_uAPICallInvalid when Steam refused the call.)

#### EnumerateFollowingListAsync

```pascal
function EnumerateFollowingListAsync(unStartIndex: UInt32; AHandler: TSteamCallResultEvent): SteamAPICall_t;
```

Calls `EnumerateFollowingList` and registers AHandler for its result (`FriendsEnumerateFollowingList_t`). The handler's object owns the registration (remove it with Steam.Dispatcher.RemoveOwner). Returns: (The call handle, or k_uAPICallInvalid when Steam refused the call.)

#### RequestEquippedProfileItemsAsync

```pascal
function RequestEquippedProfileItemsAsync(const steamID: TSteamID; AHandler: TSteamCallResultEvent): SteamAPICall_t;
```

Calls `RequestEquippedProfileItems` and registers AHandler for its result (`EquippedProfileItems_t`). The handler's object owns the registration (remove it with Steam.Dispatcher.RemoveOwner). Returns: (The call handle, or k_uAPICallInvalid when Steam refused the call.)

### Properties

| Property | Description |
|----------|-------------|
| `Handle: Pointer` | The raw ISteamFriends pointer (first argument of every `Flat` export). |
| `Flat: TSteamFriendsFlat` | The bound flat exports, for calls the methods do not cover. |

## Payload records

Declared in `Steamworks.SDKTypes` (generated from the SDK headers; layouts verified
against the C headers for Win64, Win32, Linux64 and macOS ARM64).

### PersonaStateChange_t

Callback id 304 (`PersonaStateChange_t_k_iCallback`).

| Field | C declaration |
|-------|---------------|
| `m_ulSteamID: UInt64` | C field `uint64 m_ulSteamID`. |
| `m_nChangeFlags: Integer` | C field `int m_nChangeFlags`. |

### GameOverlayActivated_t

Callback id 331 (`GameOverlayActivated_t_k_iCallback`).

| Field | C declaration |
|-------|---------------|
| `m_bActive: UInt8` | C field `uint8 m_bActive`. |
| `m_bUserInitiated: Boolean` | C field `bool m_bUserInitiated`. |
| `m_nAppID: AppId_t` | C field `AppId_t m_nAppID`. |
| `m_dwOverlayPID: UInt32` | C field `uint32 m_dwOverlayPID`. |

### GameServerChangeRequested_t

Callback id 332 (`GameServerChangeRequested_t_k_iCallback`).

| Field | C declaration |
|-------|---------------|
| `m_rgchServer: array[0..63] of AnsiChar` | C field `char [64] m_rgchServer`. |
| `m_rgchPassword: array[0..63] of AnsiChar` | C field `char [64] m_rgchPassword`. |

### GameLobbyJoinRequested_t

Callback id 333 (`GameLobbyJoinRequested_t_k_iCallback`).

| Field | C declaration |
|-------|---------------|
| `m_steamIDLobby: TSteamID` | C field `CSteamID m_steamIDLobby`. |
| `m_steamIDFriend: TSteamID` | C field `CSteamID m_steamIDFriend`. |

### AvatarImageLoaded_t

Callback id 334 (`AvatarImageLoaded_t_k_iCallback`).

| Field | C declaration |
|-------|---------------|
| `m_steamID: TSteamID` | C field `CSteamID m_steamID`. |
| `m_iImage: Integer` | C field `int m_iImage`. |
| `m_iWide: Integer` | C field `int m_iWide`. |
| `m_iTall: Integer` | C field `int m_iTall`. |

### ClanOfficerListResponse_t

Callback id 335 (`ClanOfficerListResponse_t_k_iCallback`).

| Field | C declaration |
|-------|---------------|
| `m_steamIDClan: TSteamID` | C field `CSteamID m_steamIDClan`. |
| `m_cOfficers: Integer` | C field `int m_cOfficers`. |
| `m_bSuccess: UInt8` | C field `uint8 m_bSuccess`. |

### FriendRichPresenceUpdate_t

Callback id 336 (`FriendRichPresenceUpdate_t_k_iCallback`).

| Field | C declaration |
|-------|---------------|
| `m_steamIDFriend: TSteamID` | C field `CSteamID m_steamIDFriend`. |
| `m_nAppID: AppId_t` | C field `AppId_t m_nAppID`. |

### GameRichPresenceJoinRequested_t

Callback id 337 (`GameRichPresenceJoinRequested_t_k_iCallback`).

| Field | C declaration |
|-------|---------------|
| `m_steamIDFriend: TSteamID` | C field `CSteamID m_steamIDFriend`. |
| `m_rgchConnect: array[0..255] of AnsiChar` | C field `char [256] m_rgchConnect`. |

### GameConnectedClanChatMsg_t

Callback id 338 (`GameConnectedClanChatMsg_t_k_iCallback`).

| Field | C declaration |
|-------|---------------|
| `m_steamIDClanChat: TSteamID` | C field `CSteamID m_steamIDClanChat`. |
| `m_steamIDUser: TSteamID` | C field `CSteamID m_steamIDUser`. |
| `m_iMessageID: Integer` | C field `int m_iMessageID`. |

### GameConnectedChatJoin_t

Callback id 339 (`GameConnectedChatJoin_t_k_iCallback`).

| Field | C declaration |
|-------|---------------|
| `m_steamIDClanChat: TSteamID` | C field `CSteamID m_steamIDClanChat`. |
| `m_steamIDUser: TSteamID` | C field `CSteamID m_steamIDUser`. |

### GameConnectedChatLeave_t

Callback id 340 (`GameConnectedChatLeave_t_k_iCallback`).

| Field | C declaration |
|-------|---------------|
| `m_steamIDClanChat: TSteamID` | C field `CSteamID m_steamIDClanChat`. |
| `m_steamIDUser: TSteamID` | C field `CSteamID m_steamIDUser`. |
| `m_bKicked: Boolean` | C field `bool m_bKicked`. |
| `m_bDropped: Boolean` | C field `bool m_bDropped`. |

### DownloadClanActivityCountsResult_t

Callback id 341 (`DownloadClanActivityCountsResult_t_k_iCallback`).

| Field | C declaration |
|-------|---------------|
| `m_bSuccess: Boolean` | C field `bool m_bSuccess`. |

### JoinClanChatRoomCompletionResult_t

Callback id 342 (`JoinClanChatRoomCompletionResult_t_k_iCallback`).

| Field | C declaration |
|-------|---------------|
| `m_steamIDClanChat: TSteamID` | C field `CSteamID m_steamIDClanChat`. |
| `m_eChatRoomEnterResponse: EChatRoomEnterResponse` | C field `EChatRoomEnterResponse m_eChatRoomEnterResponse`. |

### GameConnectedFriendChatMsg_t

Callback id 343 (`GameConnectedFriendChatMsg_t_k_iCallback`).

| Field | C declaration |
|-------|---------------|
| `m_steamIDUser: TSteamID` | C field `CSteamID m_steamIDUser`. |
| `m_iMessageID: Integer` | C field `int m_iMessageID`. |

### FriendsGetFollowerCount_t

Callback id 344 (`FriendsGetFollowerCount_t_k_iCallback`).

| Field | C declaration |
|-------|---------------|
| `m_eResult: EResult` | C field `EResult m_eResult`. |
| `m_steamID: TSteamID` | C field `CSteamID m_steamID`. |
| `m_nCount: Integer` | C field `int m_nCount`. |

### FriendsIsFollowing_t

Callback id 345 (`FriendsIsFollowing_t_k_iCallback`).

| Field | C declaration |
|-------|---------------|
| `m_eResult: EResult` | C field `EResult m_eResult`. |
| `m_steamID: TSteamID` | C field `CSteamID m_steamID`. |
| `m_bIsFollowing: Boolean` | C field `bool m_bIsFollowing`. |

### FriendsEnumerateFollowingList_t

Callback id 346 (`FriendsEnumerateFollowingList_t_k_iCallback`).

| Field | C declaration |
|-------|---------------|
| `m_eResult: EResult` | C field `EResult m_eResult`. |
| `m_rgSteamID: array[0..49] of TSteamID` | C field `CSteamID [50] m_rgSteamID`. |
| `m_nResultsReturned: Int32` | C field `int32 m_nResultsReturned`. |
| `m_nTotalResultCount: Int32` | C field `int32 m_nTotalResultCount`. |

### UnreadChatMessagesChanged_t

Callback id 348 (`UnreadChatMessagesChanged_t_k_iCallback`).

| Field | C declaration |
|-------|---------------|
| `_dummy: Byte` | Placeholder: the C++ struct is empty (sizeof = 1). |

### OverlayBrowserProtocolNavigation_t

Callback id 349 (`OverlayBrowserProtocolNavigation_t_k_iCallback`).

| Field | C declaration |
|-------|---------------|
| `rgchURI: array[0..1023] of AnsiChar` | C field `char [1024] rgchURI`. |

### EquippedProfileItemsChanged_t

Callback id 350 (`EquippedProfileItemsChanged_t_k_iCallback`).

| Field | C declaration |
|-------|---------------|
| `m_steamID: TSteamID` | C field `CSteamID m_steamID`. |

### EquippedProfileItems_t

Callback id 351 (`EquippedProfileItems_t_k_iCallback`).

| Field | C declaration |
|-------|---------------|
| `m_eResult: EResult` | C field `EResult m_eResult`. |
| `m_steamID: TSteamID` | C field `CSteamID m_steamID`. |
| `m_bHasAnimatedAvatar: Boolean` | C field `bool m_bHasAnimatedAvatar`. |
| `m_bHasAvatarFrame: Boolean` | C field `bool m_bHasAvatarFrame`. |
| `m_bHasProfileModifier: Boolean` | C field `bool m_bHasProfileModifier`. |
| `m_bHasProfileBackground: Boolean` | C field `bool m_bHasProfileBackground`. |
| `m_bHasMiniProfileBackground: Boolean` | C field `bool m_bHasMiniProfileBackground`. |
| `m_bFromCache: Boolean` | C field `bool m_bFromCache`. |
