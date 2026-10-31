# Game engine integration

How TSteamAPI gets Steam's callbacks into your program, and how to wire it
into FMX, VCL, LCL, Castle Game Engine, Gorilla3D, Skia4Delphi, PasVulkan or
a loop of your own, with or without a worker thread.

> **Status (2026-10-30):** the update modes described here are new and have
> not been compiled or run yet. The timer mode (`sumTimer`) is the behaviour
> tested on every platform so far. Report anything that does not match this
> page.

## Contents

1. [Why "updating" matters](#1-why-updating-matters)
2. [The choices: UpdateMode and Delivery](#2-the-choices-updatemode-and-delivery)
3. [API reference](#3-api-reference)
4. [What happens inside](#4-what-happens-inside)
5. [Threading rules - read before using sumThread](#5-threading-rules---read-before-using-sumthread)
6. [Recipes](#6-recipes)
   * [FMX](#61-fmx) - [VCL](#62-vcl) - [LCL](#63-lcl-lazarus)
   * [Castle Game Engine](#64-castle-game-engine)
   * [Gorilla3D](#65-gorilla3d)
   * [Skia4Delphi](#66-skia4delphi)
   * [PasVulkan](#67-pasvulkan)
   * [Console program or a loop of your own](#68-console-program-or-a-loop-of-your-own)
7. [Choosing the interval](#7-choosing-the-interval)
8. [Shutdown and the Steam client exiting](#8-shutdown-and-the-steam-client-exiting)
9. [Testing it: SteamConsole](#9-testing-it-steamconsole)
10. [Troubleshooting](#10-troubleshooting)

---

## 1. Why "updating" matters

Steam does not call your code by itself. Everything it wants to tell you -
a friend came online, an achievement icon finished downloading, a
leaderboard query completed, the Steam client is closing - waits in a queue
inside the Steam client library until **your process asks for it**. Valve
calls asking "running callbacks"; this library calls it **updating**.

* If nobody updates, nothing arrives: no events fire, async calls never
  complete, and Steam may consider the game unresponsive.
* Valve's guidance is to update at least ten times a second; once per frame
  is normal for a game.
* The C++ SDK's `SteamAPI_RunCallbacks` + `CCallback` templates cannot be
  used from Pascal. This library uses Valve's **manual dispatch** API
  (`SteamAPI_ManualDispatch_*`) instead, as Castle Game Engine's own Steam
  unit does. Manual dispatch has one hard rule: **only one thread at a time
  may drain the queue.**

Updating has two halves, and this library lets you put them on different
threads:

| Half | What it does | Cost |
|------|--------------|------|
| **Reading** | Ask Steam for the next callback; fetch the result of each finished async call | Talks to the Steam client process (IPC); usually fast, occasionally not |
| **Delivering** | Run your event handlers with the payload | Whatever your handlers do |

---

## 2. The choices: UpdateMode and Delivery

### UpdateMode - who reads

| Value | Who reads Steam's queue | When to use |
|-------|-------------------------|-------------|
| `sumTimer` (component default) | The framework's `TTimer` on the UI thread calls `Update` every `CallbackInterval` ms | Ordinary FMX / VCL / LCL applications. Simple and proven. |
| `sumThread` | A worker thread owned by the library, every `PumpInterval` (component: `CallbackInterval`) ms | Games and engines: Steam's I/O never costs frame time, and reading continues while the main thread is busy (loading, modal dialogs, a long frame). |
| `sumManual` | Your code, by calling `Update` | A game loop that already runs every frame and wants everything on its own thread at a known point in the frame. |

For the core without components (`TSteamworks`), `sumTimer` behaves like
`sumManual`: the core has no timer, so something must call `Steam.Update`.

### Delivery - where handlers run (only with `sumThread`)

| Value | Handlers run on | Needs | Use it when |
|-------|-----------------|-------|-------------|
| `sdMainThread` (default) | The main thread, handed over with `TThread.Queue` | A main loop that calls `CheckSynchronize` - FMX, VCL and LCL do, and so does Castle Game Engine; a console program must call it itself | You use the components / a UI framework and want threaded reading with zero changes to your handlers |
| `sdOnUpdate` | The thread that calls `Update`, inside that call | Nothing - you call `Update` once per frame | **Game engines.** You decide exactly when in the frame Steam events are handled, on your game thread |
| `sdPumpThread` | The worker thread itself | Your handlers do their own locking | Lowest latency, e.g. a dedicated networking layer. **Never** touch UI or engine objects from these handlers |

With `sumTimer` and `sumManual`, `Delivery` is ignored: handlers run inside
`Update`, on the thread that calls it.

### All combinations

| UpdateMode | Delivery | Reading on | Handlers on | You must |
|------------|----------|-----------|-------------|----------|
| `sumTimer` | (any) | UI thread (timer) | UI thread | nothing (components); call `Steam.Update` regularly (core only) |
| `sumManual` | (any) | your thread, in `Update` | same thread, in `Update` | call `Update` every frame, always from the same thread |
| `sumThread` | `sdMainThread` | worker | main thread | keep the main loop running `CheckSynchronize` |
| `sumThread` | `sdOnUpdate` | worker | your thread, in `Update` | call `Update` every frame |
| `sumThread` | `sdPumpThread` | worker | worker | synchronise inside every handler |

**Recommendation:** UI applications keep the default `sumTimer`. Games use
`sumThread` + `sdOnUpdate` (handlers in your frame, I/O off the frame) or
`sumManual` (simplest, everything on one thread).

---

## 3. API reference

### Core (`Steamworks.Core`, no framework)

```pascal
type
  TSteamUpdateMode = (sumTimer, sumThread, sumManual);
  TSteamDelivery   = (sdMainThread, sdOnUpdate, sdPumpThread);

// TSteamworks (the singleton, reached through the Steam function):
procedure SetUpdateMode(AMode: TSteamUpdateMode; ADelivery: TSteamDelivery;
  AIntervalMs: Integer = -1);       // -1 keeps PumpInterval
procedure Update;                   // = RunCallbacks
procedure RunCallbacks;
function  QueuedCallbackCount: Integer;
property  UpdateMode: TSteamUpdateMode;   // default sumTimer
property  Delivery: TSteamDelivery;       // default sdMainThread
property  PumpInterval: Integer;          // ms, default 33, minimum 1
property  Threaded: Boolean;              // read-only: the worker is running
```

* Set the mode **before** `Steam.Initialize`, or at any time while running
  (the worker is started, stopped or restarted as needed). Call
  `SetUpdateMode` from your main / game thread - never from a handler.
* `Threaded` is `False` in `sumThread` mode if the worker could not be
  started (see [Troubleshooting](#10-troubleshooting)); `Update` then reads
  and delivers itself, so a game loop calling it keeps working.
* `QueuedCallbackCount` is how many callbacks the worker has read and not
  yet delivered - useful in a debug overlay.

What `Update` (= `RunCallbacks`) does in each mode:

| Mode | `Update` |
|------|----------|
| `sumTimer`, `sumManual`, or `sumThread` without a running worker | Reads Steam's queue and delivers everything, now, on this thread |
| `sumThread` + `sdOnUpdate` | Delivers what the worker has read, now, on this thread |
| `sumThread` + `sdMainThread` | On the main thread: delivers now (otherwise the queued delivery will). On another thread: nothing |
| `sumThread` + `sdPumpThread` | Nothing (the worker delivers) - calling it is harmless |

### Components (`TSteamAPI` in Steamworks.FMX / .VCL / .LCL)

| Member | Meaning |
|--------|---------|
| `UpdateMode` (published, default `sumTimer`) | As above. `sumTimer` runs the framework timer; `sumThread` starts the core's worker (and uses the timer only as a fallback if the worker cannot start); `sumManual` runs nothing. |
| `Delivery` (published, default `sdMainThread`) | As above. |
| `CallbackInterval` (published, default 33) | Timer interval (`sumTimer`; 0 = no timer) or worker period (`sumThread`; 0 = 1 ms). |
| `Update` | Same as `RunCallbacks`. Call it per frame in `sumManual`, or in `sumThread` + `sdOnUpdate`. |
| `SetUpdateMode(Mode, Delivery, IntervalMs = -1)` | All three in one call; applies at once while running. |

All three properties can be set in the Object Inspector.

---

## 4. What happens inside

```
                 sumThread                                   delivery
 Steam client  ------------->  worker thread  -----------> +----------------+
 (IPC queue)    RunFrame,      PumpToQueue:                 | sdMainThread:  |
                GetNext...     - copy every payload         |  TThread.Queue |
                               - fetch every finished       |  -> main loop  |
                                 call result now            | sdOnUpdate:    |
                               - FreeLastCallback           |  your Update   |
                                       |                    | sdPumpThread:  |
                                       v                    |  the worker    |
                               thread-safe queue  --------> +----------------+
                               (copies, in order)            DeliverQueued:
                                                             handlers, events,
                                                             plug-in components
```

* **Payload lifetime.** A callback's payload lives inside Steam only until
  `FreeLastCallback`. In threaded modes the worker copies it first, so
  `AData.Data` in a handler points at the copy. It is valid while the handler
  runs - copy what you keep, exactly as before.
* **Call results.** A finished async call (callback 703) must be fetched on
  the thread that owns the pipe, so the worker fetches every result
  immediately. Who receives it - an `...Async` handler, `AwaitCallResult`, or
  a component event - is decided at delivery time, on the delivery thread.
* **Order.** Callbacks are delivered in the order Steam produced them, call
  results right after their 703 notification, exactly as in timer mode.
* **Subscriptions** (`Subscribe`, `AwaitCallResult`, `RemoveOwner`, plug-in
  components attaching / detaching) are locked, so they are safe from any
  thread. Handlers never run while the lock is held, so a handler may
  subscribe or unsubscribe.
* **Handler exceptions** go to `OnHandlerError` as before (the components
  show them on the main thread; on a worker they are logged instead). A
  handler exception that nobody handles stops delivery of that batch; the
  undelivered callbacks go back to the front of the queue.
* **Steam's debug hook** (`OnWarning`) and errors caught on the worker are
  delivered on the delivery thread.
* **Per-thread memory.** The worker calls `SteamAPI_ReleaseCurrentThreadMemory`
  about once a second and when it ends, as Valve asks of threads that use
  Steam.

---

## 5. Threading rules - read before using sumThread

These rules exist because Steam, your engine and the RTL all have
thread-affinity rules of their own. Breaking them gives crashes that appear
"randomly".

1. **Steam calls are allowed from any thread.** Calling plug-in methods
   (`Friends.GetPersonaName`, `Stats.SetAchievement`, ...) from your game
   thread while the worker reads is fine - Valve's API supports calls from
   several threads (that is what `SteamAPI_ReleaseCurrentThreadMemory` is
   for). Only *draining the queue* is single-threaded, and the library
   guarantees that.
2. **Where your handlers run is decided by `Delivery`** - see the table in
   section 2. In `sdMainThread` and `sdOnUpdate` your handlers run exactly
   where they would in timer mode, so existing handler code needs no change.
3. **`sdPumpThread` handlers must never touch UI or engine objects.** No
   `Label.Text := ...`, no scene changes, no `ShowMessage`. Hand data over
   with `TThread.Queue` (not `Synchronize` - see rule 6) or a lock-protected
   structure of your own. This includes the **TSteamAPI component's own
   events**: with `sdPumpThread`, `OnLog`, `OnWarning`, `OnCallback`,
   `OnSteamShutdown` and `OnShutdown` also fire on the worker (only the
   component's message boxes and application exit are moved to the main
   thread for you). A log handler that appends to a memo is UI code.
4. **Call `Initialize`, `Shutdown`, `SetUpdateMode` and `Active :=` from the
   delivery thread** (main thread, or your game thread with `sdOnUpdate`) -
   not from a third thread, and `SetUpdateMode` never from a handler.
   `Shutdown` from inside a handler is fine: it completes after that
   handler returns.
5. **Freeing objects that subscribed.** Call
   `Steam.Dispatcher.RemoveOwner(Self)` in their destructor, as always. With
   `sdMainThread` / `sdOnUpdate`, free them on the delivery thread and there
   is no race. With `sdPumpThread`, `RemoveOwner` does not wait for a
   handler that is already running on the worker, so that handler can still
   be inside an object another thread is freeing - free such objects only
   after `Shutdown`, or from a handler on the worker itself.
6. **No `TThread.Synchronize` in `sdPumpThread` handlers.** If the main thread
   is shutting Steam down at that moment it waits for the worker, and the
   worker would wait for the main thread. Use `TThread.Queue`.
7. **FPC on Linux / macOS / FreeBSD: `cthreads` must be the first unit** of
   the program's `uses` clause, or no thread can be created:

   ```pascal
   program MyGame;
   uses
     {$ifdef UNIX} cthreads, {$endif}
     ...
   ```

   Lazarus' application template and Castle Game Engine's generated
   programs already do this. Without it the worker fails to start, the log
   says why, and the library falls back to reading in `Update`.
8. **Keep handlers short** in every mode. A handler that blocks delays every
   callback behind it (and, with `sdMainThread`, the UI).

---

## 6. Recipes

### 6.1 FMX

Nothing to do for a normal application: drop a `TSteamAPI` and the plug-in
components, set `AppID`, done (timer mode).

For a game, or to keep Steam I/O off the UI thread, set two properties in
the Object Inspector, or in code before `Active := True`:

```pascal
SteamAPI1.UpdateMode := sumThread;
SteamAPI1.Delivery := sdMainThread;    // events still arrive on the UI thread
SteamAPI1.Active := True;
```

Every component event (`TSteamFriends.OnPersonaStateChange`, ...) still runs
on the main thread, so handlers can update controls directly.

### 6.2 VCL

Identical to FMX - the VCL `TSteamAPI` has the same properties. The VCL
message loop processes `TThread.Queue` requests (via `CheckSynchronize`),
including while a modal dialog or menu is open.

### 6.3 LCL (Lazarus)

Identical again; the LCL calls `CheckSynchronize` in its idle processing.
On Linux / macOS keep `cthreads` first in the `.lpr` (the Lazarus template
and `SteamDemoLCL.lpr` have it).

### 6.4 Castle Game Engine

CGE has no TSteamAPI component of its own here, so use the core directly.
CGE offers one global per-frame event that works for `TCastleWindow` and
`TCastleControl` alike: `ApplicationProperties.OnUpdate` (unit
`CastleApplicationProperties`), a list of `TNotifyEvent`s called
continuously while a window is open. CGE's own Steam unit hooks it the same
way.

> **Do not use CGE's `CastleSteam` unit together with this library.** Both
> initialise SteamAPI and both drain the same manual-dispatch queue - each
> would steal the other's callbacks. Use one or the other.

Recommended: `sumThread` + `sdOnUpdate` (reading on the worker, handlers in
CGE's update, on the main thread):

```pascal
unit GameSteam;

interface

procedure StartSteam;

implementation

uses
  SysUtils, Classes, CastleApplicationProperties, CastleLog,
  Steamworks.Core, Steamworks.Plugin.Utils, Steamworks.Plugin.UserStats;

type
  TSteamGlue = class
    procedure Update(Sender: TObject);
    procedure Log(Sender: TObject; ALevel: TSteamLogLevel; const AMessage: string);
  end;

var
  Glue: TSteamGlue;

procedure TSteamGlue.Update(Sender: TObject);
begin
  Steam.Update;   // delivers what the worker read: handlers run here
end;

procedure TSteamGlue.Log(Sender: TObject; ALevel: TSteamLogLevel; const AMessage: string);
begin
  WritelnLog('Steam', AMessage);
end;

procedure StartSteam;
begin
  Glue := TSteamGlue.Create;
  Steam.OnLog := {$ifdef FPC}@{$endif}Glue.Log;
  Steam.AppID := 2275430;                // your AppID
  {$ifdef DEBUG}
  Steam.SetAppIdEnvironment := True;     // no steam_appid.txt needed
  {$else}
  if Steam.RestartAppIfNecessary then
    Halt;                                // Steam relaunches the game
  {$endif}
  Steam.SetUpdateMode(sumThread, sdOnUpdate);
  if Steam.Initialize then
    ApplicationProperties.OnUpdate.Add({$ifdef FPC}@{$endif}Glue.Update)
  else
    WritelnWarning('Steam', Steam.LastError);
end;

finalization
  if Glue <> nil then
  begin
    if ApplicationProperties(False) <> nil then
      ApplicationProperties(False).OnUpdate.Remove({$ifdef FPC}@{$endif}Glue.Update);
    if TSteamworks.HasInstance then
      Steam.Shutdown;
    FreeAndNil(Glue);
  end;
end.
```

Call `StartSteam` from `ApplicationInitialize` (gameinitialize.pas). Notes:

* `sumManual` works too (`Steam.SetUpdateMode(sumManual, sdOnUpdate)`):
  everything then happens in `OnUpdate`, on the main thread.
* `sdMainThread` also works: CGE calls `CheckSynchronize` from its update
  under FPC, and Delphi delivers `TThread.Queue` through the window's message
  loop or FMX. `sdOnUpdate` is still preferred - it has no such dependency.
* `OnUpdate` runs only while a window is open. If Steam must keep updating
  without one (a loading screen in another process, a server), use
  `sdMainThread` with your own `CheckSynchronize` calls, or `sdPumpThread`.
* With `TCastleControl` inside an LCL / VCL / FMX form you may instead drop
  that framework's `TSteamAPI` on the form; either works, but use only one.
* **Packaging.** CGE's build tool packages the Steam library for you
  **once you put it in the project's top-level directory and list it** in
  `CastleEngineManifest.xml` (it does not fetch it from the SDK):

  ```xml
  <package>
    <include path="steam_api64.dll" />      <!-- Windows 64-bit -->
    <include path="libsteam_api.so" />      <!-- Linux, with a run.sh setting LD_LIBRARY_PATH -->
  </package>
  ```

  On macOS CGE copies `lib*.dylib` (and `steam_appid.txt`) into the bundle
  next to the executable automatically. See CGE's Steam page
  (castle-engine.io/steam) for the `run.sh` it expects on Linux.
* CGE's generated program already starts with `CThreads` on Unix (unless
  `CASTLE_DISABLE_THREADS` is defined - then use `sumManual`).

### 6.5 Gorilla3D

Gorilla3D is built on FMX, so the FMX `TSteamAPI` works unchanged. What
matters is how `TGorillaViewport` produces frames (Gorilla3D 1.5.4.4003;
unchanged from 1.5.3 for everything below):

| Member | Declaration | Behaviour |
|--------|-------------|-----------|
| `UseFixedFrameRate` | `Boolean`, published | Renders continuously on the viewport's own timer. **Since 1.5.4: Windows, macOS, Linux and Android, default `True` on all of them; iOS has no fixed-rate timer and always renders event based** (Gorilla3D's author, 2026-10-31; before 1.5.4 the property was silently ignored on Linux and Android). On Linux and Android the timer only *paces* rendering: each tick requests a paint and the frame is drawn inside the normal FMX paint cycle (the FMX canvas shares the GL context there), so a form that takes longer than one tick to paint lowers the frame rate below `FixedFrameRate`. |
| `FixedFrameRate` | `Integer`, default 60 | Target rate while `UseFixedFrameRate` is on. |
| `VSync` | `Boolean`, default `False` | Caps the rate between `FixedFrameRate` and the monitor refresh rate. |
| `ManualRendering` | `Boolean`, default `False` | Frames only when `RenderManual` is called; effective only while `UseFixedFrameRate` is `False`. |
| `RenderManual` | `procedure RenderManual(); virtual;` | Renders exactly one frame (with `ManualRendering`). |
| `Invalidate` | `procedure Invalidate(); virtual;` | Marks the viewport for redraw. |
| `OnBeforeRender` | `TGorillaFrameEvent`, published | Per frame, on the main thread, **inside** the render lock. Must not call `RenderManual` or `Application.ProcessMessages`. |
| `OnAfterRender` | `TGorillaFrameEvent`, published | Per frame, after the render lock is released. |
| `DeltaTime` | `Double`, read-only | Seconds between the previous and the current frame (wall clock; 0 on the first frame; not clamped - after a pause or breakpoint the first frame reports the whole gap). Also passed to both events as `ADeltaTime`. |

The consequence for Steam: **without `UseFixedFrameRate`** - on iOS, on
Android / Linux before 1.5.4, or whenever it is switched off - frames
come only when something invalidates the viewport (a changed object, a
running animation, `RenderManual`). A still scene renders nothing, so
anything tied to frames stops too.

Recommended - Steam independent of rendering:

```pascal
SteamAPI1.UpdateMode := sumThread;
SteamAPI1.Delivery := sdMainThread;   // events on the UI thread, frames or not
```

If you want Steam events at a fixed point of the frame instead, use
`sdOnUpdate` and call `SteamAPI1.Update` from the viewport's
**`OnAfterRender`** handler (let the IDE generate it - it creates the
`TGorillaFrameEvent` signature - and add the one line). Outside the render
lock a Steam handler may show a message or change the scene. Then make sure
frames keep coming on every platform: `UseFixedFrameRate` (the default
since 1.5.4) on Windows, macOS, Linux and Android; on iOS `ManualRendering`
plus a timer calling `RenderManual`.
Do not use `OnBeforeRender` for this: Steam handlers would run inside the
render lock.

About `TGorillaTimer` (unit `Gorilla.Utils.Timer`): it is a `TThread`
descendant, but its `OnTimer` event is **always synchronised with the main
thread** (confirmed by Gorilla3D's author). Its `Mode` property
(`TGorillaTimerMode`) chooses how: a classic `Synchronize`, a `Queue`, or a
queue that holds at most one pending event (ticks do not stack up while the
main thread is busy). So `OnTimer` is a safe place for the per-frame Steam
call too:

```pascal
procedure TForm1.GorillaTimerTick(Sender: TObject);   // signature as the IDE generates it
begin
  GorillaViewport1.RenderManual;   // with ManualRendering
  SteamAPI1.Update;                // UpdateMode = sumThread, Delivery = sdOnUpdate
end;
```

For this, prefer the queue-once mode: a slow frame then skips a tick
instead of piling up queued calls, and nothing is lost - the worker keeps
reading Steam's queue, and the next `Update` delivers everything read in
the meantime. Steam handlers run on the main thread, outside the render
lock.

The timer default (`sumTimer`) also works with Gorilla; it simply shares the
UI thread with rendering.

New in 1.5.4.4003 and harmless for Steam: the viewport can render at a
different resolution than its size (`RenderScale`, `RenderWidth` /
`RenderHeight`, `RenderFit`, `RenderFilter`); picking and
`ScreenToWorld` / `WorldToScreen` follow it. It changes nothing about when
frames - and so frame-tied Steam updates - happen.

> Sources: Gorilla3D's v1.5 viewport guide (as of 1.5.4.4003), its API
> reference for `TGorillaViewport` and `TGorillaTimer` (1.5.3), and the
> [1.5.4.4003 changelist](https://docs.gorilla3d.de/version/v1.5/page/Getting-Started/Changelist.md#changelist-v1544003).

### 6.6 Skia4Delphi

Skia4Delphi draws inside FMX or VCL controls; it does not own a loop. Use
the host framework's `TSteamAPI` exactly as in 6.1 / 6.2 - the default timer
mode is right for most Skia applications.

If your Skia scene is driven by `TSkAnimatedPaintBox` (FMX or VCL), its
`OnAnimationProcess` event (a `TNotifyEvent`, on the main thread, once per
animation step) is a natural per-frame hook for `sdOnUpdate`:

```pascal
procedure TForm1.SkAnimatedPaintBox1AnimationProcess(Sender: TObject);
begin
  SteamAPI1.Update;   // UpdateMode = sumThread, Delivery = sdOnUpdate
end;
```

It only fires while the animation runs, so prefer `sdMainThread` if the
animation can stop.

### 6.7 PasVulkan

A PasVulkan application calls, per frame, `Check(DeltaTime)` and then
`Update(DeltaTime)` on the active `TpvApplicationScreen`. They do not run on
the same thread:

* `Check` runs on the application's run-loop thread.
* `Update` may run on a different thread: with `UseExtraUpdateThread` it
  runs on a dedicated update thread, and when frames are processed in
  parallel it runs as a PasMP job on a worker - not necessarily the same
  thread every frame.

So:

* **`sumManual`:** call `Steam.Update` from `Check`. Reading must stay on
  one thread, and `Check` guarantees that.
* **`sumThread` + `sdOnUpdate`:** call `Steam.Update` from `Update` if your
  game state lives there, so your Steam handlers run with the rest of the
  frame's game logic. Calls from `Update` never overlap (PasVulkan runs one
  update at a time), which is all `sdOnUpdate` needs.

```pascal
type
  TGameScreen = class(TpvApplicationScreen)
  public
    procedure Update(const aDeltaTime: TpvDouble); override;
  end;

procedure TGameScreen.Update(const aDeltaTime: TpvDouble);
begin
  Steam.Update;            // sumThread + sdOnUpdate: Steam handlers run here
  inherited Update(aDeltaTime);
  // ... game logic ...
end;

// program start, before the application runs:
//   Steam.AppID := ...;
//   Steam.SetUpdateMode(sumThread, sdOnUpdate);
//   if not Steam.Initialize then ...
// after it ends:
//   Steam.Shutdown;
```

PasVulkan is threaded, so on Unix its programs already need `cthreads`
first (rule 7).

### 6.8 Console program or a loop of your own

```pascal
Steam.AppID := 2275430;
Steam.SetUpdateMode(sumThread, sdOnUpdate);
if Steam.Initialize then
try
  while Running do
  begin
    Steam.Update;          // handlers run here
    DoFrame;
  end;
finally
  Steam.Shutdown;
end;
```

With `sdMainThread` in a console program, call `CheckSynchronize` in the
loop (`CheckSynchronize(16)` waits up to 16 ms for queued work - a
convenient frame limiter). With `sumManual`, just call `Steam.Update` - the
classic single-threaded loop.

---

## 7. Choosing the interval

| Setting | Effect |
|---------|--------|
| 33 ms (default) | ~30 reads per second. Plenty for Steam: its events are human-scale (friends, stats, overlay). |
| 16 ms | Matches a 60 Hz frame. Use if you show Steam data that changes visibly every frame (rare). |
| 100 ms | Valve's minimum recommendation (10 per second). Lowest CPU. |
| 1 ms (`sumThread` with 0) | Busy polling; only for networking-heavy uses. |

With `sdOnUpdate` / `sumManual`, the delivery rate is your frame rate; the
interval only sets how often the worker reads.

---

## 8. Shutdown and the Steam client exiting

`ShutdownOnSteamExit` (default on) works in every mode: when Steam sends
`SteamShutdown_t` (704 - the user chose Steam -> Exit), `OnSteamShutdown`
runs on the delivery thread, then SteamAPI shuts down.

In threaded modes the worker sees 704 first and **stops talking to Steam at
once**: on Linux Steam's pipe disappears about 1.5 s after 704, and any
later call (even `SteamAPI_Shutdown`) makes the Steam client assert and
write minidumps. The shutdown itself then happens on the delivery thread
(or on the worker with `sdPumpThread`).

`Shutdown` (and `Active := False`) stops the worker and waits for it before
calling `SteamAPI_Shutdown`. Callbacks read but not yet delivered are
dropped at shutdown.

On Windows a windowed program usually gets close requests instead of 704;
see README, "When the Steam client exits".

---

## 9. Testing it: SteamConsole

SteamConsole's second parameter selects the mode, and every callback line
says which thread ran it:

```
SteamConsole 60 manual    sumManual                    - callbacks "on the main thread"
SteamConsole 60 thread    sumThread + sdOnUpdate       - "on the main thread"
SteamConsole 60 main      sumThread + sdMainThread     - "on the main thread" (loop calls CheckSynchronize)
SteamConsole 60 worker    sumThread + sdPumpThread     - "on the WORKER thread"
```

Look for `Callback worker thread started (every 33 ms, delivery ...)` in the
log, then use Steam -> Exit and check for a clean `SteamAPI shut down`.

The GUI demos (SteamDemo, SteamDemoVCL, SteamDemoLCL) have `SteamAPI1`
dropped on their form: to try the worker thread, select it in the form
designer, set `UpdateMode` to `sumThread` (leave `Delivery` at
`sdMainThread` - the only threaded mode that suits a UI without a frame
loop) and rebuild. Their log's first lines say which mode is in use
(`Update mode (from the form): ...`).

---

## 10. Troubleshooting

| Symptom | Cause / fix |
|---------|-------------|
| No events at all, `sumManual` or `sdOnUpdate` | Nothing calls `Update`. Hook it into your per-frame event. |
| No events, `sdMainThread`, console or custom loop | The main loop never calls `CheckSynchronize`. Call it, or use `sdOnUpdate`. |
| No events, Gorilla3D with `sdOnUpdate` | No frames are rendered while the scene is still (always the case on Linux / Android / iOS without a timer calling `RenderManual`). Use `sdMainThread`, or keep frames coming. |
| Log: "Could not start the callback worker thread ... add cthreads" | FPC on Unix without `cthreads` as the program's first unit (rule 7). Steam still works: `Update` reads instead. |
| Random access violations in handlers with `sdPumpThread` | A handler touches UI / engine objects from the worker (rule 3). |
| Freeze when closing, `sdPumpThread` | A handler calls `TThread.Synchronize` (rule 6). |
| Events stop after Steam -> Exit | Expected: `ShutdownOnSteamExit` shut Steam down. Call `Open` / `Initialize` again once Steam is back. |
| `Threaded` is False although `UpdateMode = sumThread` | The worker could not start (see the log) or Steam is not running. |
