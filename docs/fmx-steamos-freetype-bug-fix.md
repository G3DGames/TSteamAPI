# Skia text in Steam Linux Runtime 3.0 (FreeType)

In Steam Linux Runtime 3.0, a Delphi program that draws text with Skia
crashes the first time it does so: an access violation reading address
0, in the runtime's `libfreetype.so.6.17.4` (FreeType 2.10.4).
`libsk4d.so` uses the system's FreeType and needs a newer one. The full
analysis is in [fmx-steamos-freetype-bug.md](fmx-steamos-freetype-bug.md).

> **Status (2026-11-17):** proven on a Steam Deck (SteamOS 3.9.5,
> Runtime 3.0, launched from Steam) with EpubUnum's EpubReader. Programs
> that draw no text with Skia (FMX's own canvas only) don't need it.

## The fix: a newer FreeType next to the program, loaded first

1. **Ship FreeType 2.11.1 or newer** next to the program:
   `libfreetype.so.6` with the two brotli libraries it needs. Ubuntu
   22.04's build (FreeType 2.11.1, glibc 2.35) is the tested one. Take it
   from a container:

   ```sh
   mkdir -p ft
   docker run --rm -v "$PWD/ft":/out ubuntu:22.04 sh -c 'apt-get update -qq &&
     apt-get install -y -qq libfreetype6 > /dev/null &&
     L=/usr/lib/x86_64-linux-gnu &&
     cp -L $L/libfreetype.so.6 $L/libbrotlidec.so.1 $L/libbrotlicommon.so.1 /out/ &&
     cp /usr/share/doc/libfreetype6/copyright /out/FreeType-copyright.txt &&
     cp /usr/share/doc/libbrotli1/copyright /out/brotli-copyright.txt'
   ```

   The two copyright files are the licences, which travel with the
   libraries: FreeType is under the FreeType License (FTL) or GPLv2,
   brotli under MIT.

2. **Load it first.** It is not enough that `libsk4d.so` would find it:
   the loader reuses a library that is already loaded under the same
   name, and GTK, loaded earlier, brings in the runtime's FreeType. So
   the program's folder must come first on `LD_LIBRARY_PATH` before the
   program starts. Add this to the ICU launcher script
   ([fmx-steamos-icu-bug-fix.md](fmx-steamos-icu-bug-fix.md)), just before
   its last line, `exec "$prog" "$@"`:

   ```sh
   # the libraries next to the program first, when it ships its own FreeType
   if [ -e "$here/libfreetype.so.6" ]; then
     export LD_LIBRARY_PATH="$here${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
     echo "launcher: $here first on LD_LIBRARY_PATH (its own FreeType)" >&2
   fi
   ```

   Without a `libfreetype.so.6` next to the program the script changes
   nothing, so the same script serves programs with and without Skia.
   GTK, cairo and fontconfig then use the newer FreeType as well. Its
   soname and ABI are the same (`.6`), and they work with it.

3. **Deploy:** the three libraries and the licence texts go into the
   Linux depot next to the program. With PAServer, add them to the
   project's deployment (Linux64) so a Clean followed by Deploy keeps
   them.

## Checking a launch

Run from a terminal, the script reports on stderr:

```
launcher: ICU 67 for Delphi's runtime (/run/user/1000/delphi-icu-67)
launcher: /home/deck/.local/share/Steam/steamapps/common/EPubUnum first on LD_LIBRARY_PATH (its own FreeType)
```

The program then draws its Skia text. If it still crashes in
`libfreetype.so.6.17.4`, the runtime's FreeType was loaded after all:
the program was started without the script, or the script has no
`libfreetype.so.6` next to it.

## Also needed

- Steam Linux Runtime **3.0** and the GTK unit:
  [fmx-steamos-gtk3-bug-fix.md](fmx-steamos-gtk3-bug-fix.md).
- The ICU launcher itself, which this addition goes into:
  [fmx-steamos-icu-bug-fix.md](fmx-steamos-icu-bug-fix.md).
