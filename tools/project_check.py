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

# Shared Linux / SteamOS fixes exist once per project (projects use only
# their own sources): the copies must stay identical (line endings aside).
# FmxLinuxMenu only where a form has a TMainMenu; the ICU launcher script
# is named after its program (it starts <name> from <name>.sh).
MENU_DIRS = ["demos/SteamInputDemo/src", "RemoteLogging/LogReceiver/src",
             "demos/VirtualGamepad/src", "demos/SteamDemo/src"]
SHARED = {
    "FmxLinuxMenu.pas": [f"{d}/FmxLinuxMenu.pas" for d in MENU_DIRS],
    "FmxLinuxGtkGlobal.pas": [f"{d}/FmxLinuxGtkGlobal.pas" for d in MENU_DIRS],
    "ICU launcher": [f"demos/{n}/src/{n}.sh"
                     for n in ("SteamInputDemo", "SteamDemo", "SteamConsole", "VirtualGamepad")],
}
for unit, copies in SHARED.items():
    texts = []
    for c in copies:
        path = os.path.join(ROOT, *c.split("/"))
        if not os.path.exists(path):
            problems.append(f"{c}: missing (one of the {unit} copies)")
        else:
            texts.append(open(path, encoding="latin-1").read().replace("\r\n", "\n"))
    if len(texts) == len(copies) and len(set(texts)) > 1:
        problems.append(f"{unit} copies differ: " + " vs ".join(copies) + " - keep them identical")

# E2169 "Field definition not allowed after methods or properties": inside
# one visibility section of a class, a field may not follow a method or
# property (Delphi; FPC accepts it). Checked in every hand-written unit.
def strip_comments(text):
    """Blanks comments (keeping newlines, so line numbers stay) and strings."""
    out, i, n = [], 0, len(text)
    while i < n:
        c = text[i]
        if c == "'":
            j = text.find("'", i + 1)
            j = n if j < 0 else j + 1
            out.append("''" + "\n" * text.count("\n", i, j))
            i = j
        elif c == "{" or text.startswith("(*", i) or text.startswith("//", i):
            end = "}" if c == "{" else ("*)" if c == "(" else "\n")
            j = text.find(end, i + (1 if c == "{" else 2))
            j = n if j < 0 else j + (0 if end == "\n" else len(end))
            out.append(" " + "\n" * text.count("\n", i, j))
            i = j
        else:
            out.append(c)
            i += 1
    return "".join(out)

SECTION_WORDS = re.compile(r"^(strict\s+)?(private|protected|public|published)\b\s*", re.I)
MEMBER = re.compile(r"^(class\s+)?(procedure|function|constructor|destructor|property|operator)\b", re.I)
FIELD = re.compile(r"^(class\s+var\s+)?[A-Za-z_]\w*(\s*,\s*[A-Za-z_]\w*)*\s*:", re.I)
CLASS_HEAD = re.compile(r"\b\w+\s*=\s*class\b(?!\s*(of\b|;|\(\s*\w+\s*\)\s*;))", re.I)
for top in ("demos", "RemoteLogging", "lib", "fmx", "vcl", "lcl", "design"):
    for dirpath, _, files in os.walk(os.path.join(ROOT, top)):
        for f in files:
            if not f.lower().endswith(".pas"):
                continue
            path = os.path.join(dirpath, f)
            text = strip_comments(open(path, encoding="latin-1").read())
            for m in CLASS_HEAD.finditer(text):
                pos = m.end()
                # skip the ancestor list
                k = pos
                while k < len(text) and text[k] in " \t\r\n":
                    k += 1
                if k < len(text) and text[k] == "(":
                    k = text.index(")", k) + 1
                after_member, depth = False, 0
                while k < len(text):
                    # one statement up to ';' (outside parentheses / brackets)
                    start, par = k, 0
                    while k < len(text):
                        ch = text[k]
                        if ch in "([":
                            par += 1
                        elif ch in ")]":
                            par -= 1
                        elif ch == ";" and par == 0:
                            break
                        k += 1
                    stmt = text[start:k].strip()
                    k += 1
                    line = text.count("\n", 0, start + (len(text[start:k]) - len(text[start:k].lstrip()))) + 1
                    while True:   # leading section words
                        sm = SECTION_WORDS.match(stmt)
                        if not sm:
                            break
                        after_member = False
                        stmt = stmt[sm.end():]
                    low = stmt.lower()
                    if re.search(r"\b(record|case)\b", low) and not MEMBER.match(stmt):
                        depth += len(re.findall(r"\brecord\b", low))
                    if re.match(r"^end\b", low) or re.search(r"\bend$", low):
                        if depth:
                            depth -= 1
                            continue
                        break
                    if depth or not stmt:
                        continue
                    if MEMBER.match(stmt):
                        after_member = True
                    elif re.match(r"^(var|const|type|class\s+var)\b", low):
                        after_member = False   # a nested var / const / type block starts anew
                        if re.match(r"^class\s+var\b", low):
                            continue
                    elif after_member and FIELD.match(stmt) and not re.match(r"^(read|write|default|stored|index|overload|override|virtual|abstract|reintroduce|static|inline|dynamic|message|cdecl|stdcall|register|deprecated|platform|final)\b", low):
                        problems.append(f"{os.path.relpath(path, ROOT)}({line}): field after a method or property "
                                        "in the same section (Delphi E2169) - move it above the methods")

for p in problems:
    print(p)
print(f"{len(problems)} problem(s)")
sys.exit(1 if problems else 0)
