# Gorilla3D programs crash at start-up in Steam Linux Runtime 3.0 (InitGLX)

Bug report for Gorilla3D's author (Gorilla3D 1.5.4, Linux64, OpenGL).

**Status (2026-11-04):** the crash site is identified from the crash
address: `Gorilla.Linux.Glx.InitGLX`. **What inside `InitGLX` fails is not
known yet.** We do not have the reason from the exception message, because
Delphi loses it at that point (see "Why there is no message"). Gorilla3D's
author can probably tell from his source; the open checks are listed at the
end.

## Summary

A Delphi FMX program using Gorilla3D, built for Linux64, works when started
from a terminal. Started by Steam inside **Steam Linux Runtime 3.0
("sniper")**, the Linux runtime Steam uses for native games, it dies before
its first form exists. It prints only:

```
Runtime error 217 at 0000000000B63B34
```

`addr2line` places that address in Gorilla3D:

```
$ addr2line -f -C -e VirtualGamepad 0x0000000000B63B34
Gorilla::Linux::Glx::InitGLX(unsigned long long)
```

The program's own first start-up marker, the first statement of the
`.dpr`'s main block, is never printed. So `InitGLX` runs, and raises, during
**unit initialization**.

## Environment

| | |
|---|---|
| Gorilla3D | 1.5.4 |
| Delphi | 13.2 (37.0), Linux64, Release build |
| Host | Ubuntu 26.04.1 LTS, kernel 7.0.0-38-generic, X11 |
| GPU / driver | Intel Iris Xe (TGL GT2), Mesa 26.0.8 |
| Steam runtime | Steam Linux Runtime 3.0 (sniper), chosen for the game on the partner site |
| Program | VirtualGamepad (TSteamAPI demo): FMX form, `TGorillaViewport`, glTF models |

The same binary also needs to run on SteamOS (Steam Deck, ROG Ally), where
Steam always uses the runtime. It has not been tried there yet.

## Outside the runtime: works

Started from a terminal on the same machine, the program runs fully.
Gorilla3D's own log shows a normal start:

```
<RegisterContextClasses> Registering Gorilla3D TGorillaContextLinux context ...
<TCustomGorillaContextLinux.DoCreateWindowDC> HWND=1024, HDC=583786784
<CreateRenderingContextVersion> glx-version=1.4
<CreateRenderingContextVersion> - new context by 589371696 glXCreateContextAttribsARB(583786784)
Renderer: Mesa Intel(R) Iris(R) Xe Graphics (TGL GT2)
OpenGL-Version: 4.6 (Core Profile) Mesa 26.0.8-1ubuntu0.3
```

## Inside the runtime: what the loader trace shows

The trace was taken with Steam launch options `LD_DEBUG=libs %command% >
~/vg-stderr.txt 2>&1`. In order:

1. GTK 3 and the rest of FMX's libraries load from the runtime's
   `/lib/x86_64-linux-gnu`.
2. `libsk4d.so` is found next to the program (the program's RUNPATH) and
   loads.
3. `libshaderc_shared.so.1` is looked for (`Gorilla.Vulkan.Shaderc`, whose
   initialization calls `LoadShaderc`). The runtime has none. With
   Gorilla3D's own `lib/Vulkan/Linux/x86_x64/libshaderc_shared.so.1` copied
   next to the program, it loads. **The crash is the same either way, at the
   same address**, so shaderc is not the cause. (Separately: an OpenGL
   program probably should not load a Vulkan shader compiler at start-up.)
4. A long run of `dlsym` misses against
   `/usr/lib/pressure-vessel/overrides/lib/x86_64-linux-gnu/libGL.so.1`:
   `CGL...`, `...APPLE`, `...ATI`, `glu...`, `glSampleCoverageOES`, ending
   with `wglSwapIntervalEXT`. That is an OpenGL loader resolving every name
   it knows. Misses for macOS and Windows names are expected. Note that
   this `libGL.so.1` is the **host's** (pressure-vessel imports the host's
   graphics stack), so it is the same OpenGL as outside the runtime.
5. `Runtime error 217` follows directly.

## What differs inside the runtime

These are facts about Steam Linux Runtime 3.0, any of which `InitGLX` may
depend on:

- **Library names:** a runtime for games ships the versioned names
  (`libGL.so.1`, `libGLX.so.0`, `libX11.so.6`); the unversioned developer
  names (`libGL.so`, `libX11.so`) may be missing (not yet checked in this
  container). A desktop with development packages installed has both.
- **Library locations:** graphics libraries are under
  `/usr/lib/pressure-vessel/overrides/lib/x86_64-linux-gnu`, not
  `/usr/lib/x86_64-linux-gnu`. A loader that opens libraries by full path at
  the usual location will not find them.
- **Base libraries:** the runtime's own are Debian 11 (glibc 2.31 era); the
  graphics driver libraries come from the host.
- **`LD_LIBRARY_PATH`:** Steam sets it, and our launcher script prepends one
  folder that holds ICU links only.
- **`DISPLAY` / X11:** these are passed into the container by Steam. GTK
  opens its display normally; the GTK warnings logged are only the optional
  `canberra-gtk-module`.

## Why there is no message

The exception is raised in a unit's `initialization`. Delphi's start-up code
then finalizes the units already initialized, including `SysUtils`, before
re-raising. So the exception class and message are never printed, only
`Runtime error 217` and the address. A Gorilla3D log line before each step
of `InitGLX`, or a try/except there that writes `E.ClassName` and
`E.Message` to stderr, would make this kind of report self-explanatory.

## Steps to reproduce

1. Any FMX program with a `TGorillaViewport`, built for Linux64 (Release).
2. On a Linux desktop with Steam installed, in the program's folder:
   ```
   ~/.local/share/Steam/steamapps/common/SteamLinuxRuntime_sniper/run -- ./Project1
   ```
   **Expected (not yet tried):** `Runtime error 217`. The observed failure
   came from a Steam launch with the runtime set to 3.0, which runs the
   program the same way.
3. The same `./Project1` started directly, outside the runtime, works.

A Delphi program needs a working ICU inside the runtime (a separate
Embarcadero bug on SteamOS; on an Ubuntu host the runtime's ICU 67 is
used). Our launcher script handles that, and the trace shows ICU loaded
before the crash, so ICU is not involved here.

## Suggestions

1. Do not make the GLX set-up fatal during unit initialization. Defer it to
   the first context creation, where an exception can be shown or logged.
2. Open the GL / GLX / X11 libraries by their versioned sonames
   (`libGL.so.1`, `libGLX.so.0`, `libX11.so.6`), with plain `dlopen` and no
   fixed path, if that is not already the case.
3. Check each `dlopen` / `dlsym` / `glXGetProcAddress` result needed by
   `InitGLX`, and name the missing one in the exception message.
4. `Gorilla.Vulkan.Shaderc`: load shaderc only when the Vulkan backend is
   used (it is loaded at start-up in an OpenGL program today).

## Still to check (on our side)

- Which GL / GLX / X11 library names `InitGLX` opens, and what it raises on
  (from `Gorilla.Linux.Glx.pas`).
- The `find library=` lines for `libGL`, `libGLX` and `libX11` in the loader
  trace, to see whether a library was looked for and not found.
- The reproduction in step 2 without Steam.

This report will be updated with the answers.
