# A front-end launcher for several programs under one AppID (plan)

> **Status (2026-11-01):** a plan for later. Nothing here is built yet.
> It records the discussion and the open decisions so the work can start
> from here.

## The idea

One Steam app (one AppID) with a launcher as its only launch option. The
launcher shows a menu of its child programs plus Exit. So far the children
are SteamDemo, SteamInputDemo and VirtualGamepad.

- Choosing a child starts it as a child process and hides the launcher.
- When the child exits, the launcher shows itself again.
- Exit closes the launcher, which ends the game for Steam.

The children run under the same AppID as the launcher.

## Steam set-up

1. Put the launcher and every child in the same depot, one folder per
   child:

   ```
   Launcher(.exe / .app / .sh)
   SteamDemo/SteamDemo(.exe)
   SteamInputDemo/SteamInputDemo(.exe)
   VirtualGamepad/VirtualGamepad(.exe)
   ```

2. Partner site, App Admin > Installation > General Installation: ONE
   launch option per operating system, pointing at the launcher (on
   Linux, `Launcher.sh` - see below).
3. Publish and set the build live.

## Rules the launcher must follow

- **Stay alive while a child runs.** Steam treats the app as running
  while the process it started (and that process's children) is alive.
  If the launcher exits after starting a child, playtime, the "Running"
  state and Cloud sync timing go wrong. Hide the window, wait for the
  child, then show the window again.
- **Start the child as a real child process**, with its working directory
  set to the child's folder:
  - Windows: `CreateProcess`.
  - Linux: `fork` + `exec` (or `posix_spawn`) of the child's executable.
  - macOS: start the binary INSIDE the bundle
    (`Child.app/Contents/MacOS/Child`) with `posix_spawn`. Never use
    `open`: it hands the app to the system, so Steam loses track of it
    and the launcher cannot wait for it.
- **Only the launcher calls `SteamAPI_RestartAppIfNecessary`.** A child
  that calls it can relaunch itself through Steam and loop (see
  "Detecting the launcher").
- **Each child finds its own files next to its executable** (manifest,
  layouts, models, log), as the demos already do. The working directory
  is set anyway.

## Detecting the launcher

A child must know whether the launcher started it, mainly to decide about
`RestartIfNecessary` (the demos' Release builds set it True).

### Chosen approach: an environment variable

Just before starting a child, the launcher sets for example
`TSTEAMAPI_LAUNCHER_PID=<launcher's process id>`. A child process
inherits its parent's environment, so the child finds it.

The child's decision:

| Started by | Marker | Child does |
|------------|--------|------------|
| the launcher | present | no `RestartIfNecessary` |
| hand (double-click, terminal) | absent | `RestartIfNecessary` True: Steam starts its only launch option, the launcher |
| development (IDE) | absent | Debug builds already skip the restart (`SetAppIdEnvironment`) |

Optional second check: the process id in the variable equals the child's
parent process. This catches a variable that leaked into a shell.

### Rejected or weaker alternatives

- **Steam's own variables** (`SteamAppId`, `SteamGameId`): Steam sets them
  for the launcher and every child alike, so they cannot tell "via the
  launcher" from "directly from Steam".
- **A command-line argument:** works, but players can add arguments in
  Steam's Launch Options, and it shows in process lists. The environment
  variable is invisible and only arrives through the launcher.
- **Parent-process inspection only** (Toolhelp on Windows, `/proc/<pid>`
  on Linux, `proc_pidpath` on macOS): possible everywhere, but wrappers
  get in the way - the Linux launcher script, Proton, Steam's reaper
  process. Useful only as the second check above.

## Steam API and Steam Input

- **Only one process holds Steam at a time.** On SteamOS the launcher needs
  the pad (Game Mode shows it full screen with no mouse), so it uses Steam
  Input itself. It shuts Steam Input and the Steam API down before starting
  a child and starts them again when the child exits. TSteamAPI's Stop /
  Start in one process is tested in the demos.
- **One action manifest for the whole AppID.** On Steam the app has one
  Steam Input manifest, set on the partner site, shared by the launcher and
  every child. SteamInputDemo and VirtualGamepad already use identical
  manifests and layouts (tools/gen_input_mapping.py writes both). The
  launcher's own actions (move, confirm, back) must go into the same
  manifest.
- **Development:** without Steam launching anything, each program needs
  `steam_appid.txt` next to it (never ship it), or the Debug-build
  `SetAppIdEnvironment` the demos use.
- **Overlay:** it normally hooks child processes started this way. Test it
  in each child anyway, especially the OpenGL / Gorilla3D one.

## Platform notes

- **Linux / SteamOS:** Steam starts `Launcher.sh` (the ICU launcher
  script, [fmx-steamos-icu-bug-fix.md](fmx-steamos-icu-bug-fix.md)). The
  ICU fix (`LD_LIBRARY_PATH`) and Steam's overlay (`LD_PRELOAD`) reach the
  children through the inherited environment, so the launcher can start
  each child's executable directly rather than its `.sh`. Every FMX child
  still needs `FmxLinuxGtkGlobal` (already in all three). Use Steam Linux
  Runtime 3.0.
- **SteamOS Game Mode:** every window is full screen. When the launcher
  hides, the child's window takes the screen; when the child exits, the
  launcher must show itself and take focus again (to test).
- **macOS:** see "start the child as a real child process" above. Signing
  and entitlements apply to every bundle.
- **Windows:** nothing special beyond `CreateProcess` and waiting on the
  process handle.

## Shared Steam features

All children share the app's achievements, stats, Cloud storage, rich
presence and leaderboards.

- Prefix achievement and stat names per child (`SD_...`, `SID_...`,
  `VG_...`).
- Steam Cloud: give each child its own subfolder in the Auto-Cloud root
  paths so saves never collide.
- Steam DRM wrapper (optional): if used, wrap every executable players
  run, and test that child launches still work.

## Proposed build (when this starts)

- `demos/Launcher` (FMX): a list of children plus Exit, driven by the pad
  (Steam Input), keyboard or mouse; hides while a child runs; shows the
  child's exit code in its log.
- A small framework-free helper in `lib/` with two sides: the launcher
  sets the marker and starts / waits for the child per platform, and a
  child asks whether the launcher started it.
- The three children skip `RestartIfNecessary` when they were started by
  the launcher.
- Deployment: one folder per child in the depot. The Windows post-build
  step and the macOS / Linux deploy entries change accordingly.

## Open decisions

1. **Pad navigation in the launcher:** reuse the Menu action set
   (MenuConfirm / MenuBack / MenuUp / MenuDown, as VirtualGamepad's
   overlay menu does) or give the launcher
   its own action set in the shared manifest.
2. **Depot folder names:** one folder per child, named after it (as
   above), or another layout.
3. **The children's own Exit:** whether a child started by the launcher
   shows "Back to launcher" instead of Exit (same action: the child just
   ends).
