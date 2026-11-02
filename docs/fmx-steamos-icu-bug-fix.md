# Starting a Delphi game on SteamOS (ICU launcher)

On SteamOS (Steam Deck, ROG Ally, ...), Steam Linux Runtime 3.0 gives the
container half of the host's ICU 78. Delphi's runtime picks it and crashes
before your code runs (exit code 139). The full analysis is in
[fmx-steamos-icu-bug.md](fmx-steamos-icu-bug.md).

> **Status (2026-11-01):** proven on a ROG Ally (SteamOS, Game Mode,
> Runtime 3.0). On Ubuntu it changes nothing visible.

## The fix: start the game through a small script

Ship this as `<program>.sh` next to the program, and make it the game's
**Linux launch command** on the Steamworks partner site (instead of the
program itself):

```sh
#!/bin/sh
here=$(dirname "$(readlink -f "$0")")
prog="$here/$(basename "$0" .sh)"

# newest ICU version of the runtime with BOTH libraries present
libdir=/usr/lib/x86_64-linux-gnu
best=""
for f in "$libdir"/libicui18n.so.[0-9]*; do
  [ -e "$f" ] || continue
  v=${f##*/libicui18n.so.}; v=${v%%.*}
  case $v in ''|*[!0-9]*) continue ;; esac
  [ -e "$libdir/libicuuc.so.$v" ] || continue
  if [ -z "$best" ] || [ "$v" -gt "$best" ]; then best=$v; fi
done

# point the unversioned names (which Delphi tries first) at that pair
if [ -n "$best" ]; then
  dir="${XDG_RUNTIME_DIR:-/tmp}/delphi-icu-$best"
  mkdir -p "$dir" &&
    ln -sf "$libdir/libicuuc.so.$best" "$dir/libicuuc.so" &&
    ln -sf "$libdir/libicui18n.so.$best" "$dir/libicui18n.so" &&
    export LD_LIBRARY_PATH="$dir${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
fi

exec "$prog" "$@"
```

`demos/SteamInputDemo/src/SteamInputDemo.sh` is the full version; every
TSteamAPI program that Steam may start on Linux ships an identical copy
named after itself (`SteamDemo.sh`, `SteamConsole.sh`, `VirtualGamepad.sh`)
- the bug is in Delphi's `System` start-up, so console programs need it
too. It also
reports its choice on stderr, and can be tested without changing Steam's
settings: rename the program to `<program>.bin` and copy the script in as
`<program>`.

- It runs inside Steam's runtime, where `/usr/lib/x86_64-linux-gnu` holds
  the runtime's own complete ICU (67 in 3.0).
- Where there's no complete pair there, it changes nothing.
- Keep the script's line endings **LF**. A Windows CRLF breaks it. The
  repository's `.gitattributes` has `*.sh text eol=lf`.

## Also needed

- Steam Linux Runtime **3.0** for the game, and the GTK unit:
  [fmx-steamos-gtk3-bug-fix.md](fmx-steamos-gtk3-bug-fix.md).
- **Steam Input for Xbox-type controllers** (partner site: Application >
  Steam Input; tick the Xbox controllers and "Any Future Devices").
  SteamOS handhelds present their built-in controls as an Xbox pad.
  Without the opt-in, Steam Input is off for them and the game's actions
  get no bindings.
