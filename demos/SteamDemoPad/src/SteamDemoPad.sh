#!/bin/sh
# Linux launcher for a Delphi program inside Steam's Linux runtime.
#
# Delphi's runtime looks for ICU (libicuuc / libicui18n) at start-up by
# trying the unversioned names first, then versions 99 down to 40 - and it
# takes libicui18n ONLY in the version it found for libicuuc. On SteamOS,
# Steam Linux Runtime 3.0 brings in the host's libicuuc.so.78 (for the
# graphics drivers) but not libicui18n.so.78, so the runtime binds
# ucol_open to nil and the program dies at once (signal 11, exit code 139).
# See docs/fmx-steamos-icu-bug.md.
#
# This script points the UNVERSIONED names at the newest COMPLETE ICU of the
# runtime itself (both libraries present), so Delphi picks a matching pair.
# Where there is no such pair (a normal desktop), it changes nothing.
#
# Use: ship it next to the program and make it the game's Linux launch
# command, named <program>.sh - it starts <program>. Named <program>
# itself, it starts <program>.bin (for testing without changing Steam's
# launch settings: rename the program to <program>.bin, copy this as
# <program>).

here=$(dirname "$(readlink -f "$0")")
self=$(basename "$0")
prog="$here/${self%.sh}"
[ "$prog" = "$here/$self" ] && prog="$prog.bin"

libdir=/usr/lib/x86_64-linux-gnu
best=""
for f in "$libdir"/libicui18n.so.[0-9]*; do
  [ -e "$f" ] || continue
  v=${f##*/libicui18n.so.}
  v=${v%%.*}
  case $v in ''|*[!0-9]*) continue ;; esac
  [ -e "$libdir/libicuuc.so.$v" ] || continue
  if [ -z "$best" ] || [ "$v" -gt "$best" ]; then best=$v; fi
done

if [ -n "$best" ]; then
  dir="${XDG_RUNTIME_DIR:-/tmp}/delphi-icu-$best"
  if mkdir -p "$dir" &&
     ln -sf "$libdir/libicuuc.so.$best" "$dir/libicuuc.so" &&
     ln -sf "$libdir/libicui18n.so.$best" "$dir/libicui18n.so"; then
    export LD_LIBRARY_PATH="$dir${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
    echo "launcher: ICU $best for Delphi's runtime ($dir)" >&2
  fi
fi

exec "$prog" "$@"
