# TSteamTimeline and TSteamTimelinePlugin (ISteamTimeline)

> **Generated** by `tools/gen_docs.py` from `lib/plugins/Steamworks.Plugin.Timeline.pas` - do not edit.
> Hand-written text: `tools/doc_extras/Timeline.md`. Steam's own descriptions are Valve's
> SDK comments, as in the generated units.

Unit: `Steamworks.Plugin.Timeline` - linking it (a `uses` entry, or dropping a `TSteamTimeline`) enables the
plug-in. Steam interface: `ISteamTimeline` (SDK 1.65).

## Overview

Steam game recording: markers on the timeline the user sees when Steam
records gameplay in the background or the user saves a clip. Everything
here is a hint; calls are cheap and safe when recording is off.

### Game mode, events and phases

```pascal
var
  T: TSteamTimelinePlugin;
  Boss: TimelineEventHandle_t;
begin
  T := SteamTimeline1.Plugin;

  T.SetTimelineGameMode(k_ETimelineGameMode_Playing);   // Menus, LoadingScreen, Staging ...

  // a moment: title, description, icon, priority, offset (s), clip priority
  T.AddInstantaneousTimelineEvent('Level up', 'Reached level 10', 'steam_starburst',
    0, 0, k_ETimelineEventClipPriority_Standard);

  // a span: start now, end when the fight is over
  Boss := T.StartRangeTimelineEvent('Boss fight', 'The Warden', 'steam_flag',
    0, 0, k_ETimelineEventClipPriority_Featured);
  ...
  T.EndRangeTimelineEvent(Boss, 0);

  // a phase: one match / chapter / run, with tags and attributes
  T.StartGamePhase;
  T.SetGamePhaseID(MatchId);
  T.AddGamePhaseTag('Victory', 'steam_heart', 'Result', 100);
  T.SetGamePhaseAttribute('Score', '12 / 3', 50);
  T.EndGamePhase;
end;
```

* Icons are your own timeline icons (uploaded on the partner site) or
  Steam's built-in `steam_...` ones (the header's examples use `steam_heart`,
  `steam_flag`, `steam_starburst`; the partner documentation lists the
  rest). Text should be in the language `GetSteamUILanguage` (TSteamUtils)
  returns.
* Time offsets are seconds relative to now; negative values mark something
  that already happened.
* `SetTimelineTooltip` describes the current state (shown for the stretch
  of timeline until it changes); `ClearTimelineTooltip` removes it.
* `DoesEventRecordingExist` / `DoesGamePhaseRecordingExist` answer through
  `OnSteamTimelineEventRecordingExists` /
  `OnSteamTimelineGamePhaseRecordingExists` (or their `...Async` handler);
  if a recording exists, `OpenOverlayToTimelineEvent` /
  `OpenOverlayToGamePhase` show it.

## Contents

* [The component: TSteamTimeline](#the-component-tsteamtimeline)
  * [Events (2)](#events)
* [The plug-in: TSteamTimelinePlugin](#the-plug-in-tsteamtimelineplugin)
  * [Methods](#methods)
  * [Async methods](#async-methods)
  * [Properties](#properties)
* [Payload records](#payload-records)

## The component: TSteamTimeline

ISteamTimeline component: drop it next to a TSteamAPI (linked automatically at run time when the owner has exactly one, otherwise set SteamAPI). Its events are the ISteamTimeline callbacks; call the interface through `Plugin`.

| Member | Kind | Description |
|--------|------|-------------|
| `SteamAPI` | published property | The `TSteamAPI` this component belongs to. At run time a component whose owner has exactly one `TSteamAPI` links itself. |
| `Plugin` | public property | The `TSteamTimelinePlugin` for calls; `nil` while Steam is not running. |
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
| `OnSteamTimelineGamePhaseRecordingExists` | 6001 | [`SteamTimelineGamePhaseRecordingExists_t`](#steamtimelinegamephaserecordingexists_t) | Callback for querying UGC. |
| `OnSteamTimelineEventRecordingExists` | 6002 | [`SteamTimelineEventRecordingExists_t`](#steamtimelineeventrecordingexists_t) | Callback for querying UGC. |

Handler signature (the IDE generates it when you double-click the event):

```pascal
procedure TForm1.SteamTimeline1SteamTimelineGamePhaseRecordingExists(Sender: TObject; const AData: SteamTimelineGamePhaseRecordingExists_t);
```

## The plug-in: TSteamTimelinePlugin

ISteamTimeline plug-in. Registered by linking the unit; find it with @code(Steam.FindPlugin(TSteamTimelinePlugin)).

Reach it through the component (`SteamTimeline1.Plugin`) or the core:

```pascal
P := TSteamTimelinePlugin(Steam.FindPlugin(TSteamTimelinePlugin));   // Delphi also: Steam.Plugin<TSteamTimelinePlugin>
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
| [`SetTimelineTooltip`](#settimelinetooltip) | Sets a description for the current game state in the timeline. These help the user to find specific moments in the timeline when saving clips. Setting a new ... |
| [`ClearTimelineTooltip`](#cleartimelinetooltip) | Wraps `SteamAPI_ISteamTimeline_ClearTimelineTooltip`. |
| [`SetTimelineGameMode`](#settimelinegamemode) | Changes the color of the timeline bar. See ETimelineGameMode comments for how to use each value. |
| [`AddInstantaneousTimelineEvent`](#addinstantaneoustimelineevent) | quick helpers that add to the timeline in one call. |
| [`AddRangeTimelineEvent`](#addrangetimelineevent) | Wraps `SteamAPI_ISteamTimeline_AddRangeTimelineEvent`. |
| [`StartRangeTimelineEvent`](#startrangetimelineevent) | Starts a timeline event at a the current time, plus an offset in seconds. This event must be ended with EndRangeTimelineEvent. Any timeline events that have ... |
| [`UpdateRangeTimelineEvent`](#updaterangetimelineevent) | Updates fields on a range timeline event that was started with StartRangeTimelineEvent, and which has not been ended. |
| [`EndRangeTimelineEvent`](#endrangetimelineevent) | Ends a range timeline event and shows it in the UI. |
| [`RemoveTimelineEvent`](#removetimelineevent) | delete the event from the timeline. This can be called on a timeline event from AddInstantaneousTimelineEvent, AddRangeTimelineEvent, or ... |
| [`DoesEventRecordingExist`](#doeseventrecordingexist) | add a tag to whatever time range is represented by the event. Call result: `SteamTimelineEventRecordingExists_t` ... |
| [`StartGamePhase`](#startgamephase) | Game phases allow the user to navigate their background recordings and clips. Exactly what a game phase means will vary game to game, but the game phase ... |
| [`EndGamePhase`](#endgamephase) | Wraps `SteamAPI_ISteamTimeline_EndGamePhase`. |
| [`SetGamePhaseID`](#setgamephaseid) | Games can set a phase ID so they can refer back to a phase in OpenOverlayToPhase. |
| [`DoesGamePhaseRecordingExist`](#doesgamephaserecordingexist) | Wraps `SteamAPI_ISteamTimeline_DoesGamePhaseRecordingExist`. Call result: `SteamTimelineGamePhaseRecordingExists_t` ... |
| [`AddGamePhaseTag`](#addgamephasetag) | Add a tag that applies to the entire phase. |
| [`SetGamePhaseAttribute`](#setgamephaseattribute) | Add a text attribute that applies to the entire phase. |
| [`OpenOverlayToGamePhase`](#openoverlaytogamephase) | Opens the Steam overlay to a game phase. Parameters: - pchPhaseID: The ID of a phase that was previously provided by the game in SetGamePhaseID. |
| [`OpenOverlayToTimelineEvent`](#openoverlaytotimelineevent) | Opens the Steam overlay to a timeline event. Parameters: - ulEventID: The ID of a timeline event returned by StartEvent or AddSimpleTimelineEvent. |

#### SetTimelineTooltip

```pascal
procedure SetTimelineTooltip(const pchDescription: string; flTimeDelta: Single);
```

Sets a description for the current game state in the timeline. These help the user to find specific moments in the timeline when saving clips. Setting a new state description replaces any previous description. Examples could include: * Where the user is in the world in a single player game * Which round is happening in a multiplayer game * The current score for a sports game Parameters: - pchDescription: provide a localized string in the language returned by SteamUtils()->GetSteamUILanguage() - flTimeDelta: The time offset in seconds to apply to this event. Negative times indicate an event that happened in the past.

#### ClearTimelineTooltip

```pascal
procedure ClearTimelineTooltip(flTimeDelta: Single);
```

Wraps `SteamAPI_ISteamTimeline_ClearTimelineTooltip`.

#### SetTimelineGameMode

```pascal
procedure SetTimelineGameMode(eMode: ETimelineGameMode);
```

Changes the color of the timeline bar. See ETimelineGameMode comments for how to use each value.

#### AddInstantaneousTimelineEvent

```pascal
function AddInstantaneousTimelineEvent(const pchTitle: string; const pchDescription: string; const pchIcon: string; unIconPriority: UInt32; flStartOffsetSeconds: Single; ePossibleClip: ETimelineEventClipPriority): TimelineEventHandle_t;
```

quick helpers that add to the timeline in one call.

#### AddRangeTimelineEvent

```pascal
function AddRangeTimelineEvent(const pchTitle: string; const pchDescription: string; const pchIcon: string; unIconPriority: UInt32; flStartOffsetSeconds: Single; flDuration: Single; ePossibleClip: ETimelineEventClipPriority): TimelineEventHandle_t;
```

Wraps `SteamAPI_ISteamTimeline_AddRangeTimelineEvent`.

#### StartRangeTimelineEvent

```pascal
function StartRangeTimelineEvent(const pchTitle: string; const pchDescription: string; const pchIcon: string; unPriority: UInt32; flStartOffsetSeconds: Single; ePossibleClip: ETimelineEventClipPriority): TimelineEventHandle_t;
```

Starts a timeline event at a the current time, plus an offset in seconds. This event must be ended with EndRangeTimelineEvent. Any timeline events that have not been ended when the game exits will be discarded.

#### UpdateRangeTimelineEvent

```pascal
procedure UpdateRangeTimelineEvent(ulEvent: TimelineEventHandle_t; const pchTitle: string; const pchDescription: string; const pchIcon: string; unPriority: UInt32; ePossibleClip: ETimelineEventClipPriority);
```

Updates fields on a range timeline event that was started with StartRangeTimelineEvent, and which has not been ended.

#### EndRangeTimelineEvent

```pascal
procedure EndRangeTimelineEvent(ulEvent: TimelineEventHandle_t; flEndOffsetSeconds: Single);
```

Ends a range timeline event and shows it in the UI.

#### RemoveTimelineEvent

```pascal
procedure RemoveTimelineEvent(ulEvent: TimelineEventHandle_t);
```

delete the event from the timeline. This can be called on a timeline event from AddInstantaneousTimelineEvent, AddRangeTimelineEvent, or StartRangeTimelineEvent/EndRangeTimelineEvent. The timeline event handle must be from the current game process.

#### DoesEventRecordingExist

```pascal
function DoesEventRecordingExist(ulEvent: TimelineEventHandle_t): SteamAPICall_t;
```

add a tag to whatever time range is represented by the event. Call result: `SteamTimelineEventRecordingExists_t` (`SteamTimelineEventRecordingExists_t_k_iCallback`).

#### StartGamePhase

```pascal
procedure StartGamePhase;
```

Game phases allow the user to navigate their background recordings and clips. Exactly what a game phase means will vary game to game, but the game phase should be a section of gameplay that is usually between 10 minutes and a few hours in length, and should be the main way a user would think to divide up the game. These are presented to the user in a UI that shows the date the game was played, with one row per game slice. Game phases should be used to mark sections of gameplay that the user might be interested in watching. Examples could include: * A single match in a multiplayer PvP game * A chapter of a story-based singleplayer game * A single run in a roguelike Game phases are started with StartGamePhase, and while a phase is still happening, they can have tags and attributes added to them. Phase attributes represent generic text fields that can be updated throughout the duration of the phase. They are meant to be used for phase metadata that is not part of a well defined set of options. For example, a KDA attribute that starts with the value "0/0/0" and updates as the phase progresses, or something like a played-entered character name. Attributes can be set as many times as the game likes with SetGamePhaseAttribute, and only the last value will be shown to the user. Phase tags represent data with a well defined set of options, which could be data such as match resolution, hero played, game mode, etc. Tags can have an icon in addition to a text name. Multiple tags within the same group may be added per phase and all will be remembered. For example, AddGamePhaseTag may be called multiple times for a "Bosses Defeated" group, with different names and icons for each boss defeated during the phase, all of which will be shown to the user. The phase will continue until the game exits, until the game calls EndGamePhase, or until the game calls StartGamePhase to start a new phase. The game phase functions take these parameters: - pchTagIcon: The name of a game provided timeline icon or builtin "steam_" icon. - pchPhaseID: A game-provided persistent ID for a game phase. This could be a the match ID in a multiplayer game, a chapter name in a single player game, the ID of a character, etc. - pchTagName: The localized name of the tag in the language returned by SteamUtils()->GetSteamUILanguage(). - pchTagGroup: The localized name of the tag group. - pchAttributeValue: The localized name of the attribute. - pchAttributeGroup: The localized name of the attribute group. - unPriority: Used to order tags and attributes in the UI displayed to the user, with higher priority values leading to more prominent positioning. In contexts where there is limited space, lower priority items may be hidden.

#### EndGamePhase

```pascal
procedure EndGamePhase;
```

Wraps `SteamAPI_ISteamTimeline_EndGamePhase`.

#### SetGamePhaseID

```pascal
procedure SetGamePhaseID(const pchPhaseID: string);
```

Games can set a phase ID so they can refer back to a phase in OpenOverlayToPhase.

#### DoesGamePhaseRecordingExist

```pascal
function DoesGamePhaseRecordingExist(const pchPhaseID: string): SteamAPICall_t;
```

Wraps `SteamAPI_ISteamTimeline_DoesGamePhaseRecordingExist`. Call result: `SteamTimelineGamePhaseRecordingExists_t` (`SteamTimelineGamePhaseRecordingExists_t_k_iCallback`).

#### AddGamePhaseTag

```pascal
procedure AddGamePhaseTag(const pchTagName: string; const pchTagIcon: string; const pchTagGroup: string; unPriority: UInt32);
```

Add a tag that applies to the entire phase.

#### SetGamePhaseAttribute

```pascal
procedure SetGamePhaseAttribute(const pchAttributeGroup: string; const pchAttributeValue: string; unPriority: UInt32);
```

Add a text attribute that applies to the entire phase.

#### OpenOverlayToGamePhase

```pascal
procedure OpenOverlayToGamePhase(const pchPhaseID: string);
```

Opens the Steam overlay to a game phase. Parameters: - pchPhaseID: The ID of a phase that was previously provided by the game in SetGamePhaseID.

#### OpenOverlayToTimelineEvent

```pascal
procedure OpenOverlayToTimelineEvent(ulEvent: TimelineEventHandle_t);
```

Opens the Steam overlay to a timeline event. Parameters: - ulEventID: The ID of a timeline event returned by StartEvent or AddSimpleTimelineEvent.

### Async methods

Each `...Async` method starts the call and registers `AHandler` for its result
(`procedure(const AData: TSteamCallbackData; AIOFailure: Boolean) of object`). The
handler runs once, on the delivery thread, with the result record in `AData`
(`AData.CopyTo(Rec, SizeOf(Rec))`); its object owns the registration - call
`Steam.Dispatcher.RemoveOwner(Self)` in that object's destructor. The plain method of
the same name returns the `SteamAPICall_t` instead, and its result reaches the
component's event.

#### DoesEventRecordingExistAsync

```pascal
function DoesEventRecordingExistAsync(ulEvent: TimelineEventHandle_t; AHandler: TSteamCallResultEvent): SteamAPICall_t;
```

Calls `DoesEventRecordingExist` and registers AHandler for its result (`SteamTimelineEventRecordingExists_t`). The handler's object owns the registration (remove it with Steam.Dispatcher.RemoveOwner). Returns: (The call handle, or k_uAPICallInvalid when Steam refused the call.)

#### DoesGamePhaseRecordingExistAsync

```pascal
function DoesGamePhaseRecordingExistAsync(const pchPhaseID: string; AHandler: TSteamCallResultEvent): SteamAPICall_t;
```

Calls `DoesGamePhaseRecordingExist` and registers AHandler for its result (`SteamTimelineGamePhaseRecordingExists_t`). The handler's object owns the registration (remove it with Steam.Dispatcher.RemoveOwner). Returns: (The call handle, or k_uAPICallInvalid when Steam refused the call.)

### Properties

| Property | Description |
|----------|-------------|
| `Handle: Pointer` | The raw ISteamTimeline pointer (first argument of every `Flat` export). |
| `Flat: TSteamTimelineFlat` | The bound flat exports, for calls the methods do not cover. |

## Payload records

Declared in `Steamworks.SDKTypes` (generated from the SDK headers; layouts verified
against the C headers for Win64, Win32, Linux64 and macOS ARM64).

### SteamTimelineGamePhaseRecordingExists_t

Callback id 6001 (`SteamTimelineGamePhaseRecordingExists_t_k_iCallback`).

| Field | C declaration |
|-------|---------------|
| `m_rgchPhaseID: array[0..63] of AnsiChar` | C field `char [64] m_rgchPhaseID`. |
| `m_ulRecordingMS: UInt64` | C field `uint64 m_ulRecordingMS`. |
| `m_ulLongestClipMS: UInt64` | C field `uint64 m_ulLongestClipMS`. |
| `m_unClipCount: UInt32` | C field `uint32 m_unClipCount`. |
| `m_unScreenshotCount: UInt32` | C field `uint32 m_unScreenshotCount`. |

### SteamTimelineEventRecordingExists_t

Callback id 6002 (`SteamTimelineEventRecordingExists_t_k_iCallback`).

| Field | C declaration |
|-------|---------------|
| `m_ulEventID: UInt64` | C field `uint64 m_ulEventID`. |
| `m_bRecordingExists: Boolean` | C field `bool m_bRecordingExists`. |
