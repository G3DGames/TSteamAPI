# Delphi programs crash at start-up in Steam Linux Runtime 3.0 on SteamOS (ICU)

Bug report for Embarcadero (Delphi RTL, Linux).

**Status (2026-11-01):** cause proven by a loader trace and the RTL source.
The workaround is proven on SteamOS (ROG Ally), launched from Steam in Game
Mode.

## Summary

A Delphi 13 Linux64 program dies with signal 11 (exit code 139) before
any of its own code runs. It prints nothing, not even output from the
first unit's initialization. This happens when it starts inside **Steam
Linux Runtime 3.0 ("sniper") on SteamOS**. The same program runs on SteamOS
outside the runtime, and inside the runtime on an Ubuntu host.

## Cause

Inside the container Steam provides, there are **two** ICU versions:

| Location in the container | ICU |
|---|---|
| `/usr/lib/pressure-vessel/overrides/lib/x86_64-linux-gnu` (copied from the SteamOS host for its graphics drivers) | `libicuuc.so.78`, `libicudata.so.78` only, **no `libicui18n.so.78`** |
| `/usr/lib/x86_64-linux-gnu` (the runtime's own) | ICU 67, complete (`libicuuc`, `libicui18n`, ...) |

`InitICU` (`source/rtl/sys/ICU.inc`, run from `System`'s initialization):

1. `OpenICU_Lib('libicuuc.so')` tries the unversioned name, then versions
   99 down to 40. It loads `libicuuc.so.78` and **remembers 78**.
2. `OpenICU_Lib('libicui18n.so')` then tries **only** `libicui18n.so.78`.
   That fails, so `HICUI18N` is 0, with no fallback to a version for which
   both libraries exist.
3. `ucol_open := dlsym(HICUI18N, 'ucol_open_78')`: handle 0 means the
   global scope, which doesn't have it, so `ucol_open` is nil. It isn't
   checked.
4. Still in `System`'s initialization, `SetUTF8CompareLocale` calls
   `GetNewLocalICU`, which calls `ucol_open` and crashes.

Loader trace (`LD_DEBUG=libs`):

```
.../overrides/lib/x86_64-linux-gnu/libicuuc.so.78: error: symbol lookup error: undefined symbol: u_strToUTF8 (fatal)
./Project1: error: symbol lookup error: undefined symbol: ucol_open_78 (fatal)
./Project1: error: symbol lookup error: undefined symbol: ucol_close_78 (fatal)
```

`System.Internal.ICU` doesn't check its `dlsym` results either.

## Steps to reproduce

1. Any Delphi 13 Linux64 program (a blank FMX form is enough).
2. On SteamOS (Steam Deck, ROG Ally, ...), in Desktop Mode, in the
   program's folder:
   ```
   ~/.local/share/Steam/steamapps/common/SteamLinuxRuntime_sniper/run -- ./Project1; echo $?
   ```
   Result: `139`, no output. Run as `./Project1` outside the runtime, it
   works.

## Suggested fix

- Open `libicuuc` and `libicui18n` **as a pair**: for each version try
  both, and accept a version only if both load. Fall back to the next
  version otherwise.
- Check every function pointer from `dlsym` for nil. If ICU is unusable,
  set `HICUUC := 0` and use the existing non-ICU code paths
  (`IsICUAvailable = False`).

## Workaround

Make the **unversioned** names point at a complete pair before the program
starts. `OpenICU_Lib` tries them first, and then doesn't fix a version for
`libicui18n`. TSteamAPI ships a launcher script that does this:
[fmx-steamos-icu-bug-fix.md](fmx-steamos-icu-bug-fix.md).
