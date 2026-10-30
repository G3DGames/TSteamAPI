# CLAUDE.md - working rules for this repository

Read README.md first, then this file. Keep both up to date with every change.

## Starting a new session (read this first)
- Repository: https://github.com/G3DGames/steamworks (branch `main`, public).
  Clone it fresh:
  `GIT_LFS_SKIP_SMUDGE=1 git clone --depth 5 https://github.com/G3DGames/steamworks`
  The owner's working copy is `C:\src\Steamworks` and may be ahead of GitHub:
  build on files the owner attaches or pastes.
- The cloud workspace has NO Steamworks SDK (partner download, unreachable)
  and no Delphi / FPC compiler. Never claim to have the SDK. For SDK facts
  (headers, steam_api.json, enum values) ask the owner to paste them; for
  compile/run results rely on the owner's logs.
- Owner's setup: Delphi 13 (Studio 37.0, 64-bit IDE, so design packages are
  built Win64 with dcc64); SDK 1.65 copied into `redistributable_bin/` (all
  seven libraries, verified by check_redist.py).
- Read the "Handover" section at the end for where testing stopped.

## Syncing safely
- When the owner says a push is done: clone or fetch into a SEPARATE scratch
  folder, compare every file delivered since the last push (ignore CRLF and
  BOM differences), report, and only then reset the working copy to
  `origin/main`. Never `git stash` + `reset` + `stash drop` over undelivered
  work (this lost a working copy once; it was restored from the last zip).
- The IDE re-saves .dproj / .groupproj files (see Project files); differences
  there after a push are normal - check the important parts survived
  (post-build events, DeployFile entries, search paths) rather than expecting
  byte equality.

## Project
Pascal binding of the Steamworks SDK 1.65. Core + plug-ins.
Target order: FMX, then VCL, then Free Pascal. Delphi 13 is the reference
compiler; Windows is the main development platform, macOS (PAServer) and
Linux64 are also tested. Supported: every platform Valve ships a
redistributable for - Win32, Win64, macOS (x64/ARM64), Linux64, Android64
(Delphi + FPC) and Linux32, LinuxARM64 (FPC only; Linux32 may be dropped).
Project AppID: 2275430.

## Delivery
- Deliver whole changed files in a zip with paths from the repository root.
  Never send patches.
- Fold follow-up requests into the same delivery.
- Do not commit or push; the owner applies the zip and pushes. When the stop
  hook asks to commit and push, answer in one line that changes stay
  uncommitted on purpose.
- Until the owner pushes, each zip is cumulative since the last pushed commit
  and says which zip it supersedes. Leave out files whose only change is line
  endings (git stores LF; the IDE and the generator write CRLF).
- Before delivering run, and fix everything reported by:
  - `python3 tools/pasdoc_check.py`
  - `python3 tools/project_check.py`

## Layout rules
- `lib/` - framework-free units only. No FMX, VCL or LCL here, ever.
  Must compile with Delphi and with FPC 3.2+ (`{$mode delphi}` via Steamworks.inc).
- `lib/plugins/` - one unit per Steam interface (`Steamworks.Plugin.<Name>.pas`).
- Never create a folder with a '-' in its name under any `lib/`: `.gitignore`
  ignores `lib/*-*/` (Lazarus unit output such as `lib/x86_64-linux/`).
- `fmx/` - FireMonkey-specific units. Future: `vcl/`, `lcl/`.
- `redistributable_bin/` - each developer copies `sdk/redistributable_bin`
  from the Steamworks SDK 1.65 here. Only its README.md is tracked; never
  commit SDK binaries (partner licence). `tools/check_redist.py` validates it;
  projects copy / deploy from it (paths set in `tools/gen_projects.py`).
- `demos/<Name>/` - `<Name>.dpr` + `<Name>.dproj` in the folder, all other
  sources in `demos/<Name>/src/`.
- `packages/` - runtime and design-time packages.
- `Steamworks.groupproj` at the root lists every project.
- `tools/` - Python helpers.

## Project files
- The .dproj / .groupproj files in the repository were re-saved by the Delphi
  13 IDE (ProjectVersion 20.5, extra platform sections, post-build events
  repeated per configuration). They are now AUTHORITATIVE.
- `tools/gen_projects.py` created them and still holds the reference settings
  (post-build copy, DeployFile paths, search paths). By default it only creates
  MISSING files (a new demo or package); `--force` overwrites everything and
  would discard IDE changes - only use it deliberately and re-check in the IDE.
- To add a unit to an existing project: add it to the `.dpr`/`.dpk` uses /
  contains clause AND a `<DCCReference Include="...">` in the .dproj (or let the
  owner add it in the IDE), then run project_check.py. Keep the generator's
  lists in step so a future `--force` would produce the same set.
- Every unit must be in both the `.dpr`/`.dpk` and the `.dproj`
  (project_check.py verifies this).
- `.dproj` files are UTF-8 with BOM and CRLF and must parse as XML.

## Source rules
- ASCII only in sources; use `#$xxxx` codes for other characters.
- `{$I Steamworks.inc}` right after the `unit` line of every library unit.
- RTL units unscoped in `lib/` (`SysUtils`, `Generics.Collections`, ...)
  so they resolve in Delphi (via DCC_Namespace) and FPC.
- Portable callbacks use method pointers (`of object`). Anonymous methods
  only inside `{$ifdef STEAMWORKS_ANONYMOUS_METHODS}`.
- No class constructors/destructors in `lib/` (use unit initialization /
  finalization) - keeps FPC behaviour predictable.
- C `bool` -> `Boolean`; C enums need 4 bytes (the .inc does this);
  C++ `const T&` parameters are pointers, never records by value;
  structs under `#pragma pack(1)` are `packed record`.
- Flat exports are cdecl. Optional exports must be checked with Assigned().
- Pascal comments do not nest: a doc comment that contains `{$...}` or any
  `{` must use `(* *)` (pasdoc_check.py enforces this).
- No `TArray<T>` / `.ToArray` in `lib/` (FPC 3.2's Generics.Collections
  clashes); use `TSteamStringArray`, `TSteamPluginClassArray` or local
  `array of` types and copy loops.
- Generic methods in `lib/` only under `{$ifdef STEAMWORKS_ANONYMOUS_METHODS}`
  or `{$ifndef FPC}`; typed variants are named `...Typed<T>`.
- PasDoc on every unit (comment before `unit`) and every member, private
  fields included. Use @link, @code, @param, @returns, @raises, @longCode(# #).
- Hand-written .fmx/.dfm files: set only the properties the form needs.
  Leave defaults (Touch.*, DataDetectorTypes, ...) to the IDE - a wrong enum
  name stops the form loading.
- No credentials in source or logs.

## Logging and testing
- Log lines must say exactly what happened (values, results, paths): the
  owner tests promptly and pastes the demo log back as evidence.
- State plainly when an earlier conclusion was wrong.

## Known gaps / to check
- ESteamHardwareType values and GetSteamHardwareDefaultConfig() need the
  1.65 isteamutils.h.
- Tested 2026-10-30, Delphi 13 Win64: packages build and install; SteamConsole
  and SteamDemo initialise with AppID 2275430, ISteamUtils returns live data,
  stop / restart works, closing while running is clean. Version fallbacks match
  the 1.65 Win64 scan. check_redist.py identifies all seven real 1.65
  libraries (incl. Linux vs Android aarch64; the macOS dylib is universal).
  Steam not running -> clean failure, result 2 with Steam's message.
- Steam client exit, tested 2026-10-30 (Steam -> Exit): windowed demo gets a
  close request with no prior 704, closes cleanly; FormClose ran twice (likely
  one WM_CLOSE per top-level window). Console gets 704 then 103 and is ended
  ~10 s later; SteamConsole exits by itself on 704 (tested: stops within 50 ms).
- Failure messages tested 2026-10-30 (Win64): Steam not running -> result 2
  with Steam's text; missing DLL and 32-bit DLL in a Win64 folder -> every
  path tried with the Windows error (193 for wrong bitness) and the
  redistributable_bin file to copy. -debug_steamapi: no warnings produced, so
  the warning hook is still unexercised.
- Win32 tested 2026-10-30: SteamConsole and SteamDemo match Win64 (DLL load,
  SDK 1.65, AppID 2275430, Show info, stop / restart). The earlier "post-build
  did not copy" was steam_api.dll missing from redistributable_bin (probably
  moved, not copied, during test 6) - not a project problem. Post-build now
  always echoes a line; check_redist.py would have reported it.
- SteamMatchGameSearch and STEAMMUSICREMOTE versions were not found in the
  1.65 redistributable; check isteamgamesearch.h / isteammusicremote.h.
- FPC build of lib/ and SteamConsole not yet run.
- Android64 is enabled in the FMX projects with only the Steam library deployed
  (library\lib\arm64-v8a\); the IDE adds the standard Android deployment
  entries itself. Not yet run on a device.

## Handover (2026-10-30, end of first test session)
State: everything delivered up to Handover.zip is pushed (commit 0c832e5
"handover") and verified against a fresh clone; this CLAUDE.md update and the
safer gen_projects.py follow it. All Windows
tests pass on Delphi 13 (Win64 and Win32): packages build / install, both
demos, Steam-not-running, Steam client exit, missing and wrong-bitness DLL
messages, check_redist.py against the real 1.65 files.

Next tests, in order:
1. Linux64 via PAServer - SteamConsole then SteamDemo; libsteam_api.so deployed
   beside the executable; log shows SDK 1.65 or newer.
2. macOS OSX64 and OSXARM64 - dylib in Contents/MacOS.
3. Android64 - build and deploy only (check the .so is in the APK).
4. Warning hook - -debug_steamapi produced nothing; needs a deliberate misuse
   to prove the hook path.
5. Later: overlay and Release relaunch once a build of 2275430 is on Steam;
   InitMode simVersioned; FPC build of lib/ + SteamConsole.

Open question for the owner: should a missing redistributable FAIL the demo
builds (post-build exit code) instead of printing a WARNING line?

After that: start the interface plug-ins (User, Friends, UserStats/achievements,
Apps, RemoteStorage, ...), ideally generated from sdk/public/steam/steam_api.json.

