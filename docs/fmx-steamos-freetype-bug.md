# Skia crashes on its first text in Steam Linux Runtime 3.0 (FreeType)

Bug report for Embarcadero (Skia in Delphi, Linux: `libsk4d.so`).

**Status (2026-11-17):** the crashing library has been identified from
`/proc/self/maps` at the moment of the crash. Two tests narrowed the
cause down, and the workaround is proven on a Steam Deck (SteamOS 3.9.5,
Steam Linux Runtime 3.0 build 3.0.20261021.266025), launched from Steam.
Found with EpubUnum's EpubReader (FMX + Skia, Delphi 13).

## Summary

A Delphi 13 Linux64 FMX program that draws text with **Skia** (a
`TSkCustomControl` using `TSkParagraphBuilder`) crashes the first time
Skia draws text:

```
Access violation at address 00007F1D74B8F2B7, accessing address 0000000000000000
```

It happens only inside **Steam Linux Runtime 3.0 ("sniper")**. Everything
before that point works there: the window, FMX's own text (labels,
buttons, list boxes), the Steam API, sound. The same build runs on SteamOS
outside the runtime and on a current Ubuntu (26.04).

## Cause

The faulting address is inside the **runtime's FreeType**:

```
libfreetype.so.6.17.4 +0x522B7 (/usr/lib/x86_64-linux-gnu/libfreetype.so.6.17.4)
```

`libfreetype.so.6.17.4` is FreeType **2.10.4**, the Debian 11 version
Steam Linux Runtime 3.0 is built from.

`libsk4d.so` links the **system's** FreeType dynamically:

```
$ ldd libsk4d.so | grep -i freetype
        libfreetype.so.6 => /usr/lib/libfreetype.so.6
```

So inside the runtime, Skia gets 2.10.4. Outside it, it gets the host's
much newer FreeType (SteamOS, Ubuntu 26.04), and there it works.
`libsk4d.so` evidently expects a newer FreeType than 2.10.4. The soname
(`.6`) is the same, so nothing stops it loading the older one, and it
then fails on the first glyph. Which FreeType call fails was not
identified (no symbols).

FMX's own text rendering on Linux uses FreeType too, but survives with
2.10.4. Only Skia's path crashes.

## What was ruled out

- **No fonts in the runtime:** fonts are there. Inside the runtime
  `TSkTypeface.MakeFromName` found `sans-serif` -> DejaVu Sans, `serif` ->
  DejaVu Serif, `monospace` -> DejaVu Sans Mono, and Noto Sans. The host's
  fonts are passed in under `/run/host/fonts`.
- **A host font that FreeType 2.10.4 cannot handle:** the program still
  crashes with `FONTCONFIG_FILE` pointing at a configuration that lists
  only the runtime's own `/usr/share/fonts`.
- **The program's own code:** the crash is inside FreeType, called while
  Skia lays out or draws the first paragraph. Everything up to the first
  paint completes.

## Steps to reproduce

1. A Delphi 13 Linux64 FMX program with Skia enabled that draws a
   paragraph: a `TSkPaintBox` whose `OnDraw` builds and paints an
   `ISkParagraph` is enough.
2. Deploy it with `libsk4d.so`, and with the ICU launcher and GTK unit
   that Steam Linux Runtime 3.0 needs anyway
   ([fmx-steamos-icu-bug-fix.md](fmx-steamos-icu-bug-fix.md),
   [fmx-steamos-gtk3-bug-fix.md](fmx-steamos-gtk3-bug-fix.md)).
3. Start it through Steam with Runtime 3.0 on SteamOS. Or, in Desktop
   Mode, in the program's folder:
   ```
   ~/.local/share/Steam/steamapps/common/SteamLinuxRuntime_sniper/run -- ./Project1.sh
   ```
   Result: the access violation above, in `libfreetype.so.6.17.4`.
   Started outside the runtime, it works.

## Suggested fix

- Link FreeType into `libsk4d.so` statically (as Skia's own build does
  with `skia_use_system_freetype2=false`). Skia then no longer depends on
  whichever FreeType the system has.
- Or document the minimum FreeType version `libsk4d.so` needs, and check
  it at start-up (`FT_Library_Version`), failing with a message instead
  of crashing.

## Workaround

Ship a newer FreeType next to the program, and put the program's folder
first on `LD_LIBRARY_PATH` before it starts, so that FreeType is loaded
instead of the runtime's:
[fmx-steamos-freetype-bug-fix.md](fmx-steamos-freetype-bug-fix.md).
