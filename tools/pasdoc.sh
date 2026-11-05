#!/bin/sh
# PasDoc API reference of the TSteamAPI library, Free Pascal / Lazarus view,
# for Linux and macOS: the FPC part of tools/pasdoc.bat (Delphi and the
# HTML Help .chm files are Windows-only there).
#
#   docs/html/fpc   HTML   lcl/Steamworks.LCL + lib (FPC 3.2.2 view)
#
# Run from anywhere:  sh tools/pasdoc.sh   (or bash; no executable bit needed)
# Needs pasdoc on the PATH, or PASDOC=/full/path/to/pasdoc sh tools/pasdoc.sh
#
# The output folder is deleted first and recreated (only that folder; the
# rest of docs/ is never touched). It is git-ignored.
#
# Dark colours: after the run, tools/pasdoc-dark.css is appended to the
# pasdoc.css PasDoc wrote (dark only when the browser or system asks for it;
# the same as pasdoc.bat does), so PasDoc's own stylesheet stays as it is.
# PASDOC_DARK=0 sh tools/pasdoc.sh leaves it out.
#
# Defines: the SAME as the FPC runs of pasdoc.bat (a Win64 view), so
# docs/html/fpc has the same content whichever OS generated it. PASDOC makes
# Steamworks.inc skip its FPC_FULLVERSION test, which PasDoc cannot evaluate.

PASDOC_URL="https://github.com/pasdoc/pasdoc/releases/"

cd "$(dirname "$0")/.." || exit 1

PASDOC=${PASDOC:-pasdoc}
if ! command -v "$PASDOC" >/dev/null 2>&1; then
  echo "pasdoc was not found (looked for: $PASDOC)." >&2
  echo "Install it from $PASDOC_URL" >&2
  echo "(download the archive for your OS, unpack it and put its bin folder on the PATH," >&2
  echo "or run: PASDOC=/full/path/to/pasdoc sh tools/pasdoc.sh)" >&2
  exit 1
fi

OUT=docs/html/fpc
echo "==== Cleaning $OUT"
rm -rf "$OUT"
if [ -e "$OUT" ]; then
  echo "==== $OUT could NOT be deleted completely" >&2
  exit 1
fi
mkdir -p "$OUT" || exit 1

echo
echo "==== PasDoc html (fpc) -> $OUT"
"$PASDOC" --format html --output "$OUT" \
  --define PASDOC --include lib \
  --visible-members protected,public,published,automated \
  --inherited-members default-hide --write-uses-list --verbosity 3 \
  --define FPC --define MSWINDOWS --define CPU64 --define CPUX86_64 \
  --name TSteamAPI \
  --title "TSteamAPI - Steamworks SDK 1.65 for Free Pascal / Lazarus (LCL)" \
  lcl/Steamworks.LCL.pas lib/*.pas lib/plugins/*.pas
STATUS=$?

if [ "$STATUS" -eq 0 ] && [ "${PASDOC_DARK:-1}" != 0 ]; then
  if [ ! -f tools/pasdoc-dark.css ]; then
    echo "==== tools/pasdoc-dark.css not found - $OUT left in PasDoc's own colours" >&2
    STATUS=1
  elif [ ! -f "$OUT/pasdoc.css" ]; then
    echo "==== $OUT/pasdoc.css not found - dark colours not added" >&2
    STATUS=1
  else
    { echo; cat tools/pasdoc-dark.css; } >> "$OUT/pasdoc.css"
    echo "==== Dark colours from tools/pasdoc-dark.css added to $OUT/pasdoc.css"
  fi
fi

echo
if [ "$STATUS" -eq 0 ]; then
  echo "PasDoc: finished - open $OUT/index.html"
else
  echo "PasDoc: FAILED (exit code $STATUS) - see above"
fi
exit "$STATUS"
