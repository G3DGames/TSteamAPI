#!/usr/bin/env python3
"""Checks project files before delivery.

    python3 tools/project_check.py

For every .dproj / .groupproj under the repository:
  * UTF-8 BOM present and the XML parses;
  * every DCCReference to a .pas exists on disk;
  * the .pas units of the .dproj match the "in '...'" units of the
    .dpr / .dpk (same set, compared case-insensitively);
  * every project in a .groupproj exists;
  * no demo source includes Steamworks.inc (demos have no path to lib/).
Exit code 0 = clean, 1 = problems found.
"""
import os, re, sys
import xml.etree.ElementTree as ET

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
NS = "{http://schemas.microsoft.com/developer/msbuild/2003}"
problems = []


def native(base, rel):
    return os.path.normpath(os.path.join(base, *rel.split("\\")))


def source_units(path):
    text = open(path, encoding="latin-1").read()
    return {os.path.normcase(native(os.path.dirname(path), m))
            for m in re.findall(r"\bin\s+'([^']+\.pas)'", text, re.I)}


for dirpath, _, files in os.walk(ROOT):
    if "/." in dirpath or "__history" in dirpath:
        continue
    for f in files:
        if not f.endswith((".dproj", ".groupproj")):
            continue
        path = os.path.join(dirpath, f)
        rel = os.path.relpath(path, ROOT)
        data = open(path, "rb").read()
        if not data.startswith(b"\xef\xbb\xbf"):
            problems.append(f"{rel}: missing UTF-8 BOM")
        try:
            tree = ET.fromstring(data.decode("utf-8-sig"))
        except ET.ParseError as e:
            problems.append(f"{rel}: XML does not parse: {e}")
            continue
        if f.endswith(".groupproj"):
            for p in tree.iter(NS + "Projects"):
                if not os.path.exists(native(dirpath, p.get("Include"))):
                    problems.append(f"{rel}: project {p.get('Include')} does not exist")
            continue
        refs = set()
        for r in tree.iter(NS + "DCCReference"):
            inc = r.get("Include")
            if inc.lower().endswith(".pas"):
                full = native(dirpath, inc)
                if not os.path.exists(full):
                    problems.append(f"{rel}: DCCReference {inc} does not exist")
                refs.add(os.path.normcase(full))
        main = None
        for m in tree.iter(NS + "MainSource"):
            if m.text and m.text.lower().endswith((".dpr", ".dpk")):
                main = native(dirpath, m.text)
                break
        if main is None or not os.path.exists(main):
            problems.append(f"{rel}: main source missing")
            continue
        src = source_units(main)
        for u in sorted(src - refs):
            problems.append(f"{rel}: {os.path.relpath(u, ROOT)} is in {os.path.basename(main)} but not in the .dproj")
        for u in sorted(refs - src):
            problems.append(f"{rel}: {os.path.relpath(u, ROOT)} is in the .dproj but not in {os.path.basename(main)}")

# Demos have no path to lib/ (they link the packages' DCUs), so a demo
# source that includes Steamworks.inc fails with F1026 in Delphi.
INC = re.compile(r"\{\$I(?:NCLUDE)?\s+'?Steamworks\.inc", re.I)
for dirpath, _, files in os.walk(os.path.join(ROOT, "demos")):
    for f in files:
        if f.lower().endswith((".pas", ".dpr", ".lpr")):
            path = os.path.join(dirpath, f)
            if INC.search(open(path, encoding="latin-1").read()):
                problems.append(f"{os.path.relpath(path, ROOT)}: includes Steamworks.inc "
                                "(demos have no path to lib/ - use {$ifdef FPC}{$mode delphi}{$endif})")

# FmxLinuxMenu.pas exists twice (projects use only their own sources): the
# copies must stay identical (line endings aside).
COPIES = ["demos/SteamInputDemo/src/FmxLinuxMenu.pas",
          "RemoteLogging/LogReceiver/src/FmxLinuxMenu.pas"]
texts = []
for c in COPIES:
    path = os.path.join(ROOT, *c.split("/"))
    if not os.path.exists(path):
        problems.append(f"{c}: missing (one of the FmxLinuxMenu copies)")
    else:
        texts.append(open(path, encoding="latin-1").read().replace("\r\n", "\n"))
if len(texts) == len(COPIES) and len(set(texts)) > 1:
    problems.append("FmxLinuxMenu.pas copies differ: " + " vs ".join(COPIES) + " - keep them identical")

for p in problems:
    print(p)
print(f"{len(problems)} problem(s)")
sys.exit(1 if problems else 0)
