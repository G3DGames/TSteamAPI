# How to install (Lazarus / Free Pascal)

Using TSteamAPI with Free Pascal - from Lazarus, from the command line, or
inside an engine such as Castle Game Engine.

* **Compiler:** FPC **3.2.2** exactly. That is the version Castle Game Engine
  builds with, and the library deliberately uses nothing newer. FPC 3.3.1
  (trunk) also gets the anonymous-method extras.
* **Reference install:** Lazarus 4.8 / FPC 3.2.2, x86_64-win64, win32
  widgetset - the only FPC combination run so far. Linux and macOS with FPC
  are written for but **not yet tested**.
* **You need:** the Steamworks SDK **1.65** (`steamworks_sdk_165.zip`, from
  the Steamworks partner site), a Steam AppID (480 works for experiments),
  and the Steam client installed and logged in.

## Contents

1. [Get the Steam libraries](#1-get-the-steam-libraries)
2. [Install the Lazarus package, and point your project at the sources](#2-install-the-lazarus-package-and-point-your-project-at-the-sources)
3. [Copy the Steam library next to your executable - by hand](#3-copy-the-steam-library-next-to-your-executable---by-hand)
4. [cthreads on Linux and macOS](#4-cthreads-on-linux-and-macos)
5. [Run the demos](#5-run-the-demos)
6. [Use it in your own program](#6-use-it-in-your-own-program)
7. [Differences from Delphi](#7-differences-from-delphi)
8. [Things that look wrong but are not](#8-things-that-look-wrong-but-are-not)

---

## 1. Get the Steam libraries

As for Delphi: copy the **contents** of the SDK's `sdk/redistributable_bin`
into the repository's `redistributable_bin/` and check with

```
python3 tools/check_redist.py
```

(it must end with `Result: all required redistributables OK`). The SDK is
licensed to Steamworks partners and must never be committed.

## 2. Install the Lazarus package, and point your project at the sources

### The package: components on the palette

`packages/SteamworksLCL.lpk` puts `TSteamAPI` (LCL) and the plug-in
components (`TSteamUtils`, `TSteamUser`, `TSteamFriends`, `TSteamApps`,
`TSteamUserStats`, `TSteamRemoteStorage`, `TSteamScreenshots`,
`TSteamTimeline`, `TSteamUGC`, `TSteamInput`) on a **Steamworks** palette page, and lets the form
designer open forms that use them (such as SteamDemoLCL's).

1. **Package -> Open Package File (.lpk)**, choose
   `packages/SteamworksLCL.lpk`.
2. In the package window, **Compile**. Fix nothing yourself - report any
   error.
3. **Use -> Install**, and let Lazarus rebuild and restart the IDE.

Lazarus adds a component's own unit to your form's `uses` when you drop it.
Typed events use the SDK's records, so a form that handles them also needs
`Steamworks.SDKTypes` (and `Steamworks.Callbacks` for `OnCallback`) in its
`uses` - add them yourself; the Delphi IDE does this automatically.

> **Opening a form before the package is installed:** Lazarus does not know
> the Steam classes and offers to remove them from the form. Choose
> **Cancel** and install the package first - otherwise the components are
> deleted.

### Your project's paths

**Recommended: require the package**, as SteamDemoLCL does - Project ->
Project Inspector -> Add -> New Requirement -> `SteamworksLCL`. The package
then compiles the library and supplies its paths; your project needs none.

> Do **not** also put the library folders in a project that requires the
> package: Lazarus warns *"other unit files search path ... contains
> ...\lib, which belongs to package SteamworksLCL"*, because the same units
> could then be compiled twice with different settings.

Without the package (a console program, a project that must build where the
package is not installed), compile the library from source instead: add
these folders of the repository to the project (Project -> Project Options
-> Compiler Options -> Paths):

| Lazarus field | fpc option | Folders |
|---------------|------------|---------|
| Other unit files | `-Fu` | `lib`, `lib/plugins`, and `lcl` if you use the LCL `TSteamAPI` |
| Include files | `-Fi` | `lib` (for `Steamworks.inc`) |

You do not need to change your project's syntax mode: every library unit
sets `{$mode delphi}` itself through `Steamworks.inc`. In your own
`{$mode objfpc}` units, take method addresses with `@` as usual
(`Steam.OnLog := @MyLog;`).

## 3. Copy the Steam library next to your executable - by hand

> **This is the step everyone misses.** Neither FPC nor Lazarus copies the
> Steam library for you, and nothing in this repository does it for FPC
> builds. Without it the program starts but Steam does not, and the log
> lists every path that was tried.

Copy the library for your target from `redistributable_bin/` into the
folder of the executable you run:

| FPC target | Copy | Next to |
|------------|------|---------|
| `x86_64-win64` | `win64/steam_api64.dll` | the `.exe` |
| `i386-win32` | `steam_api.dll` | the `.exe` |
| `x86_64-linux` | `linux64/libsteam_api.so` | the executable |
| `aarch64-linux` | `linuxarm64/libsteam_api.so` | the executable |
| `i386-linux` | `linux32/libsteam_api.so` | the executable (Linux32 may be dropped) |
| `x86_64-darwin`, `aarch64-darwin` | `osx/libsteam_api.dylib` | the executable, or `Contents/MacOS/` inside an `.app` bundle |
| `aarch64-android` | `androidarm64/libsteam_api.so` | in the APK's `lib/arm64-v8a/` |

The loader looks in the executable's folder (and, on macOS, the bundle's
`Contents/MacOS` and `Contents/Frameworks`) **before** the system paths, so
on Linux no `LD_LIBRARY_PATH` is needed for this library.

Copy it **again** for every output folder you use: Lazarus puts each target
in its own folder (`x86_64-win64/`, `x86_64-linux/`, ...), and Debug and
Release builds may differ.

Lazarus has a "Compiler Commands -> Execute after" project option that can
run a copy command after each build; the demos do not use it yet (it is on
the project's to-do list), so the copy above is manual for now.

### When the engine packages it: Castle Game Engine

Castle Game Engine's build tool and editor handle the library **once you put
it in the project's top-level directory** (next to `CastleEngineManifest.xml`)
- they run the game from there - and **list it** in the manifest so
`castle-engine package` includes it:

```xml
<package>
  <include path="steam_api64.dll" />
  <include path="libsteam_api.so" />
</package>
```

On macOS CGE copies `lib*.dylib` into the bundle next to the executable
automatically. Copying the library into that top-level directory is still
manual. See [GameEngineIntegration.md](GameEngineIntegration.md#64-castle-game-engine).

## 4. cthreads on Linux and macOS

On Unix-like systems FPC programs have no thread support unless `cthreads`
is the **first** unit of the program:

```pascal
program MyGame;

{$mode delphi}

uses
  {$ifdef UNIX} cthreads, {$endif}
  ...;
```

The library needs it because Steam calls its debug hook from Steam's own
threads, and for the optional worker thread (`UpdateMode = sumThread`).
Lazarus' application template, `SteamDemoLCL.lpr` and Castle Game Engine's
generated programs already include it. Without it, the worker cannot start:
the log says so and the library falls back to reading callbacks in `Update`.

## 5. Run the demos

**SteamDemoLCL** (the same form as the VCL demo: Output, Personal,
Achievements):

1. Open or install `packages/SteamworksLCL.lpk` once (section 2), so
   Lazarus knows the package the demo requires.
2. Open `demos/SteamDemoLCL/SteamDemoLCL.lpi` in Lazarus and build. It
   compiles the library through the package and passes `-dDEBUG`, so it
   sets the AppID itself (no `steam_appid.txt`).
3. Copy the Steam library into `demos/SteamDemoLCL/<cpu>-<os>/` (e.g.
   `x86_64-win64/steam_api64.dll`) - section 3.
4. Run it with the Steam client running.

**SteamConsole** from the command line:

```
cd demos/SteamConsole
fpc -Mdelphi -Fu../../lib -Fu../../lib/plugins -Fi../../lib -Fusrc SteamConsole.dpr
```

then copy the library next to `SteamConsole(.exe)` and run
`SteamConsole 60` (60 s of callbacks) or `SteamConsole 60 thread` (worker
thread - see [GameEngineIntegration.md](GameEngineIntegration.md#9-testing-it-steamconsole)).

## 6. Use it in your own program

### LCL application with the components

```pascal
uses
  Steamworks.Core, Steamworks.SDKTypes, Steamworks.LCL, Steamworks.Plugin.Friends;

procedure TMainForm.FormCreate(Sender: TObject);
begin
  FSteam := TSteamAPI.Create(Self);
  FSteam.AppID := 2275430;                    // your AppID
  {$ifdef DEBUG}
  FSteam.SetAppIdEnvironment := True;         // development builds only
  {$else}
  FSteam.RestartIfNecessary := True;
  {$endif}
  FFriends := TSteamFriends.Create(Self);
  FFriends.SteamAPI := FSteam;
  FFriends.OnPersonaStateChange := @FriendChanged;   // objfpc: @; delphi mode: no @
  if FSteam.Open then
    Caption := FFriends.Plugin.GetPersonaName;
end;
```

`TSteamAPI` (LCL) uses the LCL `TTimer` by default, so every event arrives
on the main thread; `SteamImageToBitmap` (Steamworks.LCL) turns avatars and
achievement icons into a `TBitmap`. See [components/README.md](components/README.md).

### Without the LCL (console, engines)

Use the core (`Steamworks.Core`) and call `Steam.Update` from your loop -
[GameEngineIntegration.md](GameEngineIntegration.md) has recipes for Castle
Game Engine, PasVulkan and plain loops.

## 7. Differences from Delphi

| Feature | Delphi | FPC 3.2.2 |
|---------|--------|-----------|
| Components on the palette | yes (design packages) | yes (`packages/SteamworksLCL.lpk`) |
| Event-record units added to `uses` for you | yes | no - add `Steamworks.SDKTypes` yourself |
| `Steam.Plugin<TSteamUtilsPlugin>` | yes | no - use `TSteamUtilsPlugin(Steam.FindPlugin(TSteamUtilsPlugin))` |
| `SubscribeTyped<T>`, `AwaitCallResultTyped<T>`, closures | yes | FPC 3.3.1+ only (`STEAMWORKS_ANONYMOUS_METHODS`) |
| Local time of Steam timestamps | `SteamTimeToLocal` | `SteamTimeToLocal` - **not** `UnixToDateTime(T, False)`, which in FPC 3.2 applies today's UTC offset to every date |
| Library loaded from | executable folder / bundle | the same |

## 8. Things that look wrong but are not

### Compiler warnings from Generics.Collections

The first FPC build (Lazarus 4.8, Win64) compiled the library and the LCL
demo with these messages, all from FPC's own `Generics.Collections` and all
harmless:

* `Warning: (4046) Constructing a class "TCustomDictionaryEnumerator..." with
  abstract method ...` - once for every `TDictionary`.
* Notes 5071 and 6058 from the same unit.
* Hints about unused `Sender` parameters and managed local variables.

Most of the rest of a first build log is Lazarus rebuilding its own LCL
packages.

### "Steam did not start (result 2)"

The Steam client is not running or not logged in. With no `OnInitFailed`
handler the LCL `TSteamAPI` shows Steam's message in a message box and
leaves `Active` False - the program keeps running.

### Load error listing many paths

The library is not next to the executable (section 3). Windows error 193 =
wrong bitness (a 32-bit DLL for a 64-bit program, or the reverse).

### "Could not start the callback worker thread ... add cthreads"

Section 4. Steam still works; callbacks are read by `Update` instead.

### Lazarus adds a blank line to the .lpr

Lazarus' own formatting; harmless.
