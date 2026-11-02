# Test setup: second user, Steam Cloud, Workshop, Inventory

The demos' **Test components** run needs nothing but Steam. These extra
tests need settings on the Steamworks partner site (and, for the two-user
tests, a second Steam account on a second machine):

| Test | Needs |
|------|-------|
| Two-user tests (lobby, P2P, messages, rich presence, auth tickets, listen game server) | a second account that owns the app, on a second PC |
| Steam Cloud write / read with Cloud on for the app | Steam Cloud enabled (section 2) |
| Workshop item create / upload / query / delete | Steam Cloud quota + Workshop enabled (section 3) |
| Inventory items (promo, generate, consume, playtime drop) | Inventory Service enabled + the item definitions below (section 4) |

Everything here is for the test AppID of this repository (2275430). For your
own game, use your AppID and your own item definitions.

## 1. Second user

* A second Steam account that owns the app (a key or a developer comp).
* A second PC (or virtual machine) with Steam logged in to that account -
  one PC cannot run two Steam accounts at once.
* A build of SteamDemo (FMX, VCL or LCL - they pair with each other) from
  the SAME sources on both machines. Debug builds set the AppID themselves; Release builds
  need to be started from Steam.
* Mixed pairs are worth a run: SteamDemoLCL (Lazarus / FPC) on one side
  and SteamDemo (FMX) or SteamDemoVCL (Delphi) on the other proves the FPC
  and Delphi bindings agree on everything that crosses the wire (lobby
  data, chat lines, auth tickets, P2P payloads). Each copy publishes its
  program, compiler and platform in the lobby, and both logs name the
  other side's ("the other copy: ...", and the "finished as" line).
* The two accounts do NOT need to be Steam friends: the demos find each
  other through a lobby (Matchmaking), tagged so that only the test joins
  it. EXCEPT for the rich-presence row: Steam does not show a new, limited
  account's rich presence to a non-friend (seen 2026-11-02 in every role
  and framework pairing), so that row passes only once the accounts are
  friends or both are full accounts. As friends it passed at once (both
  sides read the other's within a second), and the whole pair test took
  about 10 s instead of waiting out the 60 s time-out.
* Each account signed in on ONE machine only. With the main account's
  Steam client also running on a second PC, rich presence crossed in
  neither direction (Steam sent updates for the peer with no keys at
  all). After Steam > Exit on that PC, the macOS copy read the Windows
  account's rich presence at once, but the Windows copy still did not see
  the macOS account's (2026-11-02, still open: does the Windows friend
  list show the macOS account as in-game?). Closing Steam's window is not
  enough - it keeps running in the tray / menu bar.
* Both PCs need internet access; P2P connections go through Steam's relay
  network when a direct path is not possible.
* The host's listen server (game-server row) uses UDP 27215 (game) and
  27216 (queries). The guest's rules query of the host's PUBLIC address is
  informational - a router without port forwarding blocks it; the row
  passes on the server's auth verdict. Windows may ask once whether the
  demo may accept incoming connections (allow it on private networks).

## 2. Steam Cloud

Partner site, App Admin for 2275430 -> **Steam Cloud Settings**
(`partner.steamgames.com/apps/cloud/2275430`):

1. **Byte quota per user**: e.g. `10000000` (10 MB - the test writes a few
   hundred bytes, Workshop previews need more).
2. **Number of files allowed per user**: e.g. `100`.
3. If the app is already released and Cloud should stay hidden from
   players for now: tick **Enable cloud support for developers only**.
4. **Save**, then **Publish** the change (Publish tab).

Steam says to allow up to 10 minutes, or restart the Steam client, before
the change shows. The player's own setting must allow it too: Steam
Settings -> Cloud (global) and the game's Properties -> General (per game).

Check: SteamDemo's RemoteStorage row should then say `cloud for app was on`
(today it reports Cloud off for the app).

## 3. Workshop

Needs the Steam Cloud quota from section 2 (previews are stored there).

1. **Workshop -> Configuration** (Steam Workshop Configuration page): under
   *Additional Configuration Options* tick the option that enables
   **ISteamUGC for file transfer**.
2. **Workshop -> General**: **Visibility State** = *Developers & Testers*
   (or *Developers Only*) while testing. *Everyone* needs the Workshop
   checklist complete first.
3. **Save**, then **Publish**.

What the test does once `GetWorkshopEULAStatus` answers OK (today it
answers InvalidParam, and the row says "Workshop item test skipped"):
create one item (`CreateItem`), upload a title, private visibility and a
one-file content folder (`StartItemUpdate`, `SetItemTitle`,
`SetItemVisibility`, `SetItemContent`, `SubmitItemUpdate`; the folder is
`WorkshopTest` in the demo's settings folder and is removed afterwards),
and delete the item again (`DeleteItem` - permanent, no prompt). Not
verified: that the EULA status really turns OK once the Workshop is set
up - if the row keeps saying "skipped" after section 3, tell us. Valve keeps new items hidden until
the uploader has accepted the Steam Workshop Legal Agreement; the test
reports that flag (`m_bUserNeedsToAcceptWorkshopLegalAgreement`) and does
not need the item to be visible.

## 4. Inventory

Partner site -> **Steam Inventory Service**
(`partner.steamgames.com/apps/inventoryservice/2275430`):

1. Upload the item definitions in
   [test-setup/itemdefs_2275430.json](test-setup/itemdefs_2275430.json):

   | itemdefid | type | used by |
   |-----------|------|---------|
   | 100 | item, promo `manual` - "TSteamAPI Test Token" | `AddPromoItem` |
   | 101 | item - "TSteamAPI Test Gem" | `GenerateItems`, `ConsumeItem` |
   | 10 | playtimegenerator (drops item 101) | `TriggerItemDrop` |

   None is tradable or marketable. Their icons are
   [test-setup/test_item.png](test-setup/test_item.png) and
   [test-setup/test_gem.png](test-setup/test_gem.png); the JSON points at
   their raw GitHub URLs, so they must be pushed before the upload (Steam
   downloads and caches them).
2. Tick **Enable Inventory Service** on the same page, save, publish.
3. Item visibility stays **Private** (Steam Economy Settings): then only
   accounts in your Steamworks partner group get the items in-game - the
   developer account running the test is one. A second account needs to
   be in the group (or visibility public) to see them.

The extended test runs when `GetAllItems` answers OK. Checks: Inventory row with `GenerateItems` -> one
Test Gem, `ConsumeItem` -> gone again, `AddPromoItem` -> one Test Token
(granted once per account), `TriggerItemDrop` -> a Gem or an empty result
(Steam decides by playtime). Today's Inventory row reports `result 2
(Fail)` because the service is off.

`GenerateItems` works only for accounts in the app's Steamworks partner
group (the developer account): for the second user it answers Fail and
`ConsumeItem` is skipped - expected. A repeated `AddPromoItem` answers OK
with 0 items (the token is granted once per account) - still a pass.

Not verified yet (no access to the partner site from here): the exact
labels of the Workshop checkbox and of the Inventory page, and whether `promo: "manual"` lets the
game's own `AddPromoItem` grant the token, whether
`drop_interval 1` is accepted - adjust and tell us; the test reports what
Steam answers either way.
