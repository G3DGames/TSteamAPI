# Running an FMX game in Steam's Linux runtime

Steam starts native Linux games inside its own runtime container. Two
things are needed for a Delphi FMX game to start there. The full analysis
is in [fmx-steamos-gtk3-bug.md](fmx-steamos-gtk3-bug.md).

> **Status (2026-11-01):** both steps are proven in Steam Linux Runtime
> 3.0, on Ubuntu 26.04 and on SteamOS (ROG Ally). **SteamOS also needs the
> ICU launcher:** [fmx-steamos-icu-bug-fix.md](fmx-steamos-icu-bug-fix.md).

## 1. Use Steam Linux Runtime 3.0 (sniper), not 4.0

Runtime 4.0 has no GTK 3, so every FMX program stops at once with
"GTK 3 is required to be installed". Runtime 3.0 has GTK 3.

- **To test on your own machine:** open the game's Properties >
  Compatibility, tick "Force the use of a specific Steam Play
  compatibility tool" and choose **Steam Linux Runtime 3.0 (sniper)**.
- **For players:** set the game's Linux launch to Steam Linux Runtime
  3.0 on the Steamworks partner site, so nobody has to change a setting.

## 2. Make GTK 3 globally visible before the first form

In runtime 3.0, FMX crashes with "Access violation at address 0" as soon
as a form containing a `TListBox` is created. FMX looks two GTK functions
up in the global symbol scope, but there GTK is loaded privately. The fix
is to re-open GTK globally at start-up.

Add this unit to the project:

```pascal
unit FmxLinuxGtkGlobal;

interface

implementation

{$IFDEF LINUX}
uses
  Posix.Dlfcn;

initialization
  // GTK is already loaded privately; RTLD_GLOBAL makes it visible to
  // FMX's global lookups (on a normal desktop this changes nothing)
  dlopen('libgtk-3.so.0', RTLD_LAZY or RTLD_GLOBAL);
  dlopen('libgdk-3.so.0', RTLD_LAZY or RTLD_GLOBAL);
{$ENDIF}
end.
```

and list it in the `.dpr`, before the units with your forms:

```pascal
uses
  System.StartUpCopy,
  FMX.Forms,
  FmxLinuxGtkGlobal in 'FmxLinuxGtkGlobal.pas',
  Unit1 in 'Unit1.pas' {Form1};
```

On Windows and macOS the unit compiles to nothing. TSteamAPI's FMX
programs carry the same unit as `src/FmxLinuxGtkGlobal.pas`, which also
writes a line to stderr saying whether each library was opened.

## Checking a launch

Set the game's Launch Options to `%command% > /tmp/game.txt 2>&1`, start
it from Steam, and read `/tmp/game.txt`. Lines about
`gameoverlayrenderer.so ... wrong ELF class` and `canberra-gtk-module`
are harmless. Remove the Launch Options again afterwards.

Also note that the game's install folder is read-only inside the
runtime, so write logs and saves to the user's folders.
