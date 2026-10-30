# How to install (Delphi)

Step-by-step installation of TSteamAPI for Delphi, from a fresh clone to a
running program, with every step that looks alarming explained.

* **Reference compiler:** Delphi 13 (Studio 37.0). It is the only version
  tested. Delphi 11.0 and later should work but are not yet tested or
  guaranteed.
* **Targets:** Win32, Win64, macOS x64 and ARM64, Linux64, Android64
  (Android not yet run on a device).
* **You need:** the Steamworks SDK **1.65** (`steamworks_sdk_165.zip`, from
  the Steamworks partner site), a Steam AppID (Valve's public test app 480
  works for experiments), and the Steam client installed and logged in.

## Contents

1. [Get the Steam libraries](#1-get-the-steam-libraries)
2. [Open the project group](#2-open-the-project-group)
3. [Build the runtime packages - once per platform](#3-build-the-runtime-packages---once-per-platform)
4. [Install the design-time packages](#4-install-the-design-time-packages)
5. [Run a demo](#5-run-a-demo)
6. [Use it in your own project](#6-use-it-in-your-own-project)
7. [Shipping your game](#7-shipping-your-game)
8. [Things that look wrong but are not](#8-things-that-look-wrong-but-are-not)
9. [Updating the library](#9-updating-the-library)

---

## 1. Get the Steam libraries

The Steam client library (`steam_api64.dll` and friends) is part of the SDK,
which Valve licenses to partners. It is **not** in this repository and must
never be committed.

1. Unzip `steamworks_sdk_165.zip` anywhere.
2. Copy the **contents** of its `sdk/redistributable_bin` folder into the
   repository's `redistributable_bin/` folder - so you get
   `redistributable_bin/win64/steam_api64.dll`, not
   `redistributable_bin/redistributable_bin/...`.
3. Check it (Python 3, any OS):

   ```
   python3 tools/check_redist.py
   ```

   It must end with `Result: all required redistributables OK`. It checks
   that every file is present, is really for its platform and CPU, and comes
   from SDK 1.65.

## 2. Open the project group

Open `Steamworks.groupproj` in Delphi. It contains, in build order:

| Project | Kind | Contents |
|---------|------|----------|
| `Steamworks` | runtime package | the whole framework-free library: core, plug-ins, plug-in components (`lib/`, `lib/plugins/`) |
| `dclSteamworks` | design package | registers the plug-in components (TSteamUtils, TSteamUser, TSteamFriends, TSteamApps, TSteamUserStats) |
| `SteamworksFMX` / `dclSteamworksFMX` | runtime / design | the FMX `TSteamAPI` |
| `SteamworksVCL` / `dclSteamworksVCL` | runtime / design | the VCL `TSteamAPI` |
| `SteamDemo`, `SteamDemoVCL`, `SteamConsole` | demos | |

## 3. Build the runtime packages - once per platform

Your projects, and the demos, do **not** compile the library from source.
They link the compiled units (`.dcu`) the runtime packages write into
Delphi's own `Dcp` folder:

* Win32: `$(BDSCOMMONDIR)\Dcp`
* every other platform: `$(BDSCOMMONDIR)\Dcp\<platform>`

That folder is on Delphi's default library path, so **no search paths are
needed** in your projects - but only for platforms whose packages you built.

For **each platform you target** (Win32, Win64, Linux64, ...):

1. In the Projects window, select the platform under `Steamworks` and
   **Build** it (not Install).
2. Do the same for `SteamworksFMX` and / or `SteamworksVCL`.

Debug and Release builds write to the same folder; the last one built is the
one your projects link. After changing library sources, rebuild the packages
before rebuilding anything that uses them.

> A new project starts on **Win32**. If you work in the 64-bit IDE you may
> only have built Win64 packages - see
> [F2613 Unit 'Steamworks.Types' not found](#f2613-unit-steamworkstypes-not-found).

## 4. Install the design-time packages

Design packages run inside the IDE, so they must match the IDE's own
platform: **Win64 for the 64-bit IDE, Win32 for the 32-bit IDE**. Each IDE
keeps its own list of installed packages - if you use both, install in
both.

1. Build the runtime packages for the IDE's platform (step 3).
2. Right-click `dclSteamworks` -> **Install**.
3. Right-click `dclSteamworksFMX` and / or `dclSteamworksVCL` -> **Install**.

The components appear on the **Steamworks** palette page. The FMX and VCL
`TSteamAPI` have the same name, like `TButton`; the IDE shows the right one
for the kind of form you are editing.

## 5. Run a demo

With the Steam client running and logged in, build and run **SteamDemo**
(FMX), **SteamDemoVCL** or **SteamConsole** (`SteamConsole 60` keeps
pumping for 60 s; see [GameEngineIntegration.md](GameEngineIntegration.md)
for its update-mode parameter).

Debug builds set the AppID through the environment (`SetAppIdEnvironment`),
so no `steam_appid.txt` is needed.

## 6. Use it in your own project

### With components

1. Create an FMX or VCL application.
2. Drop a **TSteamAPI** and the plug-in components you need (e.g.
   **TSteamFriends**, **TSteamUserStats**) on the main form. Plug-in
   components link themselves to the form's only TSteamAPI at run time; set
   their `SteamAPI` property if the form has more than one.
3. Set `TSteamAPI.AppID` to your AppID.
4. For development builds set `SetAppIdEnvironment := True` (or put a
   `steam_appid.txt` containing the AppID next to the executable); for
   release builds set `RestartIfNecessary := True` instead.
5. Set `Active := True`, or call `SteamAPI1.Open` in `FormCreate`.
6. Double-click events in the Object Inspector as usual; the IDE adds the
   units the typed event parameters need.
7. **Put the Steam library next to the executable** - see
   [the next section](#getting-the-library-next-to-your-executable).

See [components/README.md](components/README.md) for every component.

### Without components

Use the core directly - see the README, "Without any component", and
[GameEngineIntegration.md](GameEngineIntegration.md) for game loops.

### Getting the library next to your executable

Steam's library is loaded at run time from the executable's folder (and the
macOS bundle's `Contents/MacOS` / `Contents/Frameworks`). Delphi does not
copy it for you. Choose one:

* **Windows - a post-build event** (what the demos do). Project -> Options ->
  Building -> Build Events -> Post-build events, for each Windows platform,
  command (Win64 shown; Win32 uses `steam_api.dll` in the folder itself):

  ```
  copy /Y "<path to repository>\redistributable_bin\win64\steam_api64.dll" "$(OUTPUTDIR)"
  ```

  Read [the post-build warnings section](#post-build-copy-messages-on-windows-targets)
  before you do this.
* **Windows - by hand:** copy the DLL into the output folder once
  (`Win64\Debug\`, `Win64\Release\`, ...). It is not deleted by a rebuild.
* **macOS, Linux, Android - Deployment.** Project -> Deployment, **Add
  Files**, pick the library from `redistributable_bin/`, and set its remote
  path:

  | Platform | Library | Remote path |
  |----------|---------|-------------|
  | OSX64 / OSXARM64 | `osx/libsteam_api.dylib` | `Contents\MacOS\` |
  | Linux64 | `linux64/libsteam_api.so` | `.\` |
  | Android64 | `androidarm64/libsteam_api.so` | `library\lib\arm64-v8a\` |

## 7. Shipping your game

* Ship the Steam library for each platform next to the executable (inside
  the bundle on macOS). It may be redistributed with your game under the
  Steamworks agreement.
* **Do not** ship `steam_appid.txt` and do not use `SetAppIdEnvironment` in
  release builds: on a customer's machine Steam supplies the AppID when it
  launches the game. Use `RestartIfNecessary := True`, so a game started
  outside Steam is relaunched through it.
* If you upload with SteamPipe, the depot simply contains the executable and
  the library side by side.

---

## 8. Things that look wrong but are not

### Post-build copy messages on Windows targets

The Windows demos copy the Steam DLL with a **post-build event**: a
command-line `copy` that runs after the linker. What you see in the
Messages / Output pane comes from that command, not from the compiler:

* `Steamworks post-build: Win64 Debug, copying steam_api64.dll to ...` - an
  `echo` we added so the step is always visible.
* `1 file(s) copied.` - Windows' own message: success.
* The IDE may list these post-build lines among the build's messages with
  warning styling, even though nothing is wrong.
  **TODO (owner):** paste the exact text Delphi 13 shows here, so this
  section can quote it.

What is **not** harmless:

* `ERROR: could not copy steam_api64.dll from redistributable_bin\win64\ - ...`
  and a **failed build**: the DLL is missing from `redistributable_bin/`
  (step 1), or the target is locked because the program is still running.
  This is deliberate - a build without the DLL would only fail later, at run
  time.

Why a post-build event and not Delphi's Deployment for Windows: a local
Windows run starts the executable straight from the output folder without a
deployment step (Deployment is what PAServer targets use), so the DLL has to
be copied there by the build.

If you write your own post-build event: the IDE joins its lines into one
`cmd` line with `&&`, so **never use `if`** in it (`cmd` treats everything
after `if ...` as part of the `if`). Use `copy ... || (echo ERROR ... & exit /b 1)`
as the demos do.

### F2613 Unit 'Steamworks.Types' not found

(or `'Steamworks.FMX' not found`, `dcc32`): the runtime packages have not
been built for the project's platform yet - usually Win32, which every new
project starts on. Select that platform under `Steamworks` and
`SteamworksFMX` / `SteamworksVCL` and **Build** them (step 3). The
Structure pane may meanwhile show `F2063 Could not compile used unit ...` -
Error Insight saying the same thing.

### "Optional export SteamAPI_ISteamUtils_IsRunningOnSteamDeck not found"

A debug log line, not an error: SDK 1.65 removed that function.

### The VCL demo looks like Windows 95

Left deliberately: a project without a manifest gets no themes. Project ->
Options -> Application -> Manifest: tick **Enable runtime themes** and pick a
DPI awareness. See the README's "Known issues".

### Steam -> Exit closes the window twice on Windows

Steam sends one close request per top-level window; `FormClose` runs twice.
Make close handling tolerate it. See the README, "When the Steam client
exits".

### Achievement icon is 0

Either Steam is still fetching it (wait for `OnUserAchievementIconFetched`)
or the achievement has no icon. After changing icons on the partner site,
publish, then restart the Steam client - it caches them.

### The program starts, but Steam does not ("result 2")

The Steam client is not running or not logged in. With no `OnInitFailed`
handler, `TSteamAPI` shows Steam's message and leaves `Active` False - it
does not end the program.

### "This build needs ... steam_api64.dll ... next to the executable"

The library was not found. The message lists every path tried with
Windows' error; error 193 means a 32-bit DLL in a 64-bit program (or the
reverse).

---

## 9. Updating the library

After pulling a new version: rebuild the runtime packages for every platform
you use, then rebuild (and if needed reinstall) the design packages, then
your projects. The `.dproj` files are authoritative; let the IDE re-save
them if it asks.
