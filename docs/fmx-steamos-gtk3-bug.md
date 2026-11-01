# FMX on Linux crashes inside Steam Linux Runtime 3.0 when a TListBox is created

Bug report for Embarcadero (FireMonkey for Linux / FMXLinux).

**Status (2026-11-01):** the cause is proven by a symbol trace of the full
application. Two items are **not yet confirmed** and are marked below: the
minimal one-control repro, and the workaround.

## Summary

A Delphi 13 FMX application for Linux64 dies at start-up with

```
Exception EAccessViolation in module <unknown> at 0000000000000000.
Access violation at address 0000000000000000, accessing address 0000000000000000.
```

when it runs inside **Steam Linux Runtime 3.0 ("sniper")**, the container
Steam uses to launch native Linux games. It happens while the main form
is streamed, at the moment a `TListBox` is created. The same executable
runs normally when started directly on the desktop.

Just before the crash FMX looks up two GTK 3 functions in the process's
**global** symbol scope and calls the result without checking it:

- `gtk_event_controller_set_propagation_phase`
- `gtk_event_controller_handle_event`

Both exist in the runtime's GTK 3.24. But inside the container libgtk-3
is loaded privately (not `RTLD_GLOBAL`), so it is not in the global scope.
The lookup returns nil, and FMX calls address 0.

## Environment

| | |
|---|---|
| Delphi | 13 (Studio 37.0), Linux64, Release build |
| FMX Linux library | `libfmux-1.0dev.so` (unpacked by the application into `~/.fmxlinux/` at start-up) |
| Host | Ubuntu 26.04, 64-bit, Wayland desktop |
| Steam runtime | Steam Linux Runtime 3.0 (sniper): Debian 11 based, GTK 3.24, run by Steam's pressure-vessel container |
| libfmux needs | `libgtk-3.so.0`, `libgdk-3.so.0`, `libgdk_pixbuf-2.0.so.0` |

## Steps to reproduce

1. Create a new FMX application. Put **one `TListBox`** on the form.
   *(Not yet confirmed in isolation: the crash was traced in a full
   application, see Evidence. A blank form, and a blank form with a
   `TMainMenu`, both run correctly in the same runtime.)*
2. Build it for Linux64, Release.
3. Run it inside Steam Linux Runtime 3.0. Either:
   - in Steam: add or install it as a game, open Properties >
     Compatibility, choose "Steam Linux Runtime 3.0 (sniper)", and start
     it from Steam; or
   - without launching through Steam, with the runtime's own launcher:
     ```
     ~/.local/share/Steam/steamapps/common/SteamLinuxRuntime_sniper/run -- ./Project1
     ```
4. To see the output when started from Steam, set the game's Launch
   Options to `%command% > /tmp/out.txt 2>&1`.

**Expected:** the form opens, as it does when the program is run
directly on the desktop.

**Actual:** the access violation above, before the form's `OnCreate`.

## Evidence

### Where the crash happens

The application wrote a trace line for each component as the form was
streamed (a `TReader.OnCreateComponent` hook):

```
start-up: units initialised
start-up: application initialised, creating the main form
start-up: Application.Run (FMX creates the queued forms now)
start-up: constructing the main form (reading uMain.fmx)
start-up: creating a TPanel
start-up: creating a TLabel
start-up: creating a TLabel
start-up: creating a TLayout
start-up: creating a TLabel
start-up: creating a TListBox
Exception EAccessViolation in module <unknown> at 0000000000000000.
Access violation at address 0000000000000000, accessing address 0000000000000000.
```

### What FMX looked up

With `LD_DEBUG=symbols`, these were the program's last lookups before the
exception (one line per library searched; paths shortened):

```
symbol=gtk_event_controller_set_propagation_phase;  lookup in file=<game>/Project1 [0]
...
symbol=gtk_event_controller_set_propagation_phase;  lookup in file=.../libXdmcp.so.6 [0]
symbol=gtk_event_controller_handle_event;  lookup in file=<game>/Project1 [0]
symbol=gtk_event_controller_handle_event;  lookup in file=.../gameoverlayrenderer.so [0]
symbol=gtk_event_controller_handle_event;  lookup in file=.../libgcc_s.so.1 [0]
symbol=gtk_event_controller_handle_event;  lookup in file=.../libc.so.6 [0]
symbol=gtk_event_controller_handle_event;  lookup in file=.../libm.so.6 [0]
symbol=gtk_event_controller_handle_event;  lookup in file=.../libdl.so.2 [0]
symbol=gtk_event_controller_handle_event;  lookup in file=.../librt.so.1 [0]
symbol=gtk_event_controller_handle_event;  lookup in file=.../libGL.so.1 [0]
symbol=gtk_event_controller_handle_event;  lookup in file=.../libpthread.so.0 [0]
symbol=gtk_event_controller_handle_event;  lookup in file=/lib64/ld-linux-x86-64.so.2 [0]
symbol=gtk_event_controller_handle_event;  lookup in file=.../libGLdispatch.so.0 [0]
symbol=gtk_event_controller_handle_event;  lookup in file=.../libGLX.so.0 [0]
symbol=gtk_event_controller_handle_event;  lookup in file=.../libX11.so.6 [0]
symbol=gtk_event_controller_handle_event;  lookup in file=.../libxcb.so.1 [0]
symbol=gtk_event_controller_handle_event;  lookup in file=.../libXau.so.6 [0]
symbol=gtk_event_controller_handle_event;  lookup in file=.../libXdmcp.so.6 [0]
symbol=__rstr__ZN6System8Sysconst21_SAccessViolationArg2E;  lookup in file=<game>/Project1 [0]
symbol=_Unwind_RaiseException;  ...
```

Scope `[0]` is the global scope. **libgtk-3 is not in it**, so neither
lookup can succeed. The next lookups are the RTL raising the access
violation.

### What rules out other causes

- A blank FMX form runs in the same runtime, and so does a blank form
  with a `TMainMenu`. GTK 3 is therefore present and usable, and FMX's
  platform start-up works.
- GTK 3.24 contains both functions; they date from GTK 3.14.
- The application's own code had not run yet: the crash comes before
  the form's `OnCreate`.

### Related observation: Steam Linux Runtime 4.0

Under Steam Linux Runtime 4.0 (Steam's default choice on this machine)
any FMX application, a blank form included, stops at once with:

```
GTK 3 is required to be installed.
Runtime error 217 at ...
```

4.0 provides no GTK 3, so FMX can't run there at all. That's probably a
runtime limitation rather than an FMX bug. Developers shipping FMX games
on Steam need to know it, though: the game must be set to use Steam
Linux Runtime 3.0.

## Suggested fix

Resolve GTK functions from the GTK library itself, not from the global
scope: call `dlsym` on the handle of `libgtk-3.so.0` (FMX or libfmux
already has it open), not with `RTLD_DEFAULT`, or open GTK with
`RTLD_GLOBAL`. Check every resolved function pointer for nil before
calling it. A missing optional function should degrade (for example, no
gesture controller) rather than call address 0.

## Workaround (not yet confirmed)

Short version for game developers: [fmx-steamos-gtk3-bug-fix.md](fmx-steamos-gtk3-bug-fix.md).

Before the first form is created, re-open GTK with global visibility.
For a library that is already loaded, `dlopen` with `RTLD_GLOBAL` only
widens its scope:

```pascal
{$IFDEF LINUX}
uses Posix.Dlfcn;
initialization
  dlopen('libgtk-3.so.0', RTLD_LAZY or RTLD_GLOBAL);
  dlopen('libgdk-3.so.0', RTLD_LAZY or RTLD_GLOBAL);
{$ENDIF}
```

TSteamAPI ships this as the unit `FmxLinuxGtkGlobal.pas` in
`demos/SteamInputDemo/src`. Update this section when it's tested in Steam
Linux Runtime 3.0.

## Notes for anyone reproducing this

- Steam always adds its overlay via `LD_PRELOAD`. Lines like
  `ld.so: object '.../gameoverlayrenderer.so' ... wrong ELF class` in the
  output are harmless.
- `Gtk-Message: Failed to load module "canberra-gtk-module"` is harmless.
- `libfmux` does not have to be deployed: the executable carries it and
  unpacks it into `~/.fmxlinux/` at start-up.
- Inside the runtime the game's install folder is not writable. Log
  files have to go to the user's folders.
