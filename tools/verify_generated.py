#!/usr/bin/env python3
"""Verifies the generated binding against the real SDK headers.

    python3 tools/verify_generated.py <sdk/public/steam folder>

1. Struct layouts: compiles the SDK headers with clang (no platform SDK
   needed: system headers are stubbed) for Win64, Win32, Linux x86_64 and
   macOS ARM64, reads sizeof / alignof / offsetof of every struct generated
   in lib/Steamworks.SDKTypes.pas, and compares them with the layout Delphi
   gives the generated records (alignment rules of {$ALIGN n} / packed
   record, as set by Steamworks.inc and Steamworks.AlignNatural.inc).
   Skipped with a note when clang is not installed.
2. Flat signatures: every Flat entry of every generated plug-in against
   steam_api_flat.h - parameter count, and pointer-ness and size of each
   parameter and of the result.

Exit code 0 = no differences. Run after every tools/gen_steam_api.py run.
"""
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "tools"))
import gen_steam_api as gen  # noqa: E402

TARGETS = {  # triple: (pointer size, default record alignment of Steamworks.inc)
    "x86_64-pc-windows-msvc": (8, 8),
    "i686-pc-windows-msvc": (4, 8),
    "x86_64-unknown-linux-gnu": (8, 4),
    "arm64-apple-macos11": (8, 4),
}
BASIC = {"Boolean": 1, "AnsiChar": 1, "Byte": 1, "UInt8": 1, "Int8": 1, "UInt16": 2, "Int16": 2,
         "Integer": 4, "Int32": 4, "UInt32": 4, "Cardinal": 4, "Single": 4, "Int64": 8, "UInt64": 8,
         "Double": 8}
PTR = ("NativeInt", "NativeUInt", "Pointer", "PAnsiChar")


def strip_comments(t):
    t = re.sub(r"\{[^$][^}]*\}", "", t)
    t = re.sub(r"\(\*.*?\*\)", "", t, flags=re.S)
    return re.sub(r"//[^\n]*", "", t)


def parse_unit(path):
    """Aliases, Pascal enums and records (with alignment context) of a unit."""
    txt = open(path, encoding="utf-8-sig").read().replace("\r", "").split("\nimplementation")[0]
    lines = strip_comments(txt).split("\n")
    aliases, enums, recs, natural, i = {}, set(), {}, False, 0
    while i < len(lines):
        l = lines[i].strip()
        if "AlignNatural.inc" in l:
            natural = True
        elif "AlignDefault.inc" in l:
            natural = False
        m = re.match(r"^(\w+)\s*=\s*(packed )?record\b", l)
        if m:
            fields = []
            i += 1
            while not lines[i].strip().startswith("end;"):
                fm = re.match(r"^\s*(\w+): (.+);$", lines[i])
                if fm and "case" not in lines[i]:
                    fields.append((fm.group(1), fm.group(2)))
                i += 1
            recs[m.group(1)] = dict(packed=bool(m.group(2)), natural=natural, fields=fields)
        else:
            if re.match(r"^(\w+)\s*=\s*\($", l):
                enums.add(l.split("=")[0].strip())
            m = re.match(r"^(\w+)\s*=\s*([\w\[\]. ]+?);$", l)
            if m:
                aliases[m.group(1)] = m.group(2)
        i += 1
    return aliases, enums, recs


class PascalLayout:
    def __init__(self):
        a1, e1, r1 = parse_unit(os.path.join(ROOT, "lib", "Steamworks.Types.pas"))
        a2, e2, r2 = parse_unit(os.path.join(ROOT, "lib", "Steamworks.SDKTypes.pas"))
        self.aliases, self.enums, self.recs = {**a1, **a2}, e1 | e2, {**r1, **r2}

    def type(self, t, ptr, dflt):
        t = t.strip()
        m = re.match(r"^array\[0\.\.(\d+)\] of (.+)$", t)
        if m:
            sz, al = self.type(m.group(2), ptr, dflt)
            return sz * (int(m.group(1)) + 1), al
        if t in BASIC:
            return BASIC[t], BASIC[t]
        if t in PTR or t.startswith("^"):
            return ptr, ptr
        if t in self.enums:
            return 4, 4
        if t in self.recs:
            return self.record(t, ptr, dflt)[:2]
        if t in self.aliases:
            return self.type(self.aliases[t], ptr, dflt)
        if t.startswith("P"):
            return ptr, ptr
        raise KeyError(t)

    def record(self, n, ptr, dflt):
        r = self.recs[n]
        pack = 1 if r["packed"] else (8 if r["natural"] else dflt)
        off, ra, offs = 0, 1, []
        for _, ft in r["fields"]:
            sz, al = self.type(ft, ptr, dflt)
            a = min(al, pack)
            off = (off + a - 1) // a * a
            offs.append(off)
            off += sz
            ra = max(ra, a)
        return (off + ra - 1) // ra * ra, ra, offs


def check_layouts(sdk_dir, sdk, names):
    clang = shutil.which("clang++")
    if not clang:
        print("layouts: SKIPPED - clang++ not installed")
        return 0
    structs = sdk.structs
    tmp = tempfile.mkdtemp(prefix="steamlayout")
    stub = os.path.join(tmp, "stub")
    os.makedirs(stub)
    open(os.path.join(stub, "string.h"), "w").write(
        "#include <stddef.h>\nvoid *memset(void*,int,size_t); void *memcpy(void*,const void*,size_t);\n"
        "int memcmp(const void*,const void*,size_t); size_t strlen(const char*);\n"
        "char *strncpy(char*,const char*,size_t); int strcmp(const char*,const char*);\n")
    open(os.path.join(stub, "stdio.h"), "w").write(
        "#include <stddef.h>\nint snprintf(char*,size_t,const char*,...); int sprintf(char*,const char*,...);\n")
    src = ["#define private public", "#define protected public", '#include "steam_api.h"',
           '#include "steam_gameserver.h"', '#include "steamnetworkingfakeip.h"', "#include <stddef.h>",
           'extern "C" const long long LAYOUT[] = {']
    for n in names:
        src.append(f"  (long long)sizeof({n}), (long long)alignof({n}),")
        for f in structs[n]["fields"]:
            src.append(f"  (long long)offsetof({n}, {f['fieldname']}),")
    src.append("  -1 };")
    cpp = os.path.join(tmp, "layout.cpp")
    open(cpp, "w").write("\n".join(src) + "\n")
    resdir = subprocess.run([clang, "-print-resource-dir"], capture_output=True, text=True).stdout.strip()
    pas = PascalLayout()
    bad = checked = 0
    for triple, (ptr, dflt) in TARGETS.items():
        ll = os.path.join(tmp, triple + ".ll")
        r = subprocess.run([clang, "-target", triple, "-std=c++17", "-ffreestanding", "-nostdinc++", "-w",
                            "-isystem", stub, "-isystem", os.path.join(resdir, "include"), "-I", sdk_dir,
                            "-S", "-emit-llvm", "-o", ll, cpp], capture_output=True, text=True)
        if r.returncode:
            print(f"layouts: clang failed for {triple}:\n{r.stderr[:2000]}")
            return 1
        arr = [int(x) for x in re.findall(r"i64 (-?\d+)", re.search(r"@LAYOUT = [^\n]*", open(ll).read()).group(0))]
        k = 0
        for n in names:
            cs, ca = arr[k], arr[k + 1]
            k += 2
            nf = len(structs[n]["fields"])
            co = arr[k:k + nf]
            k += nf
            ps, pa, po = pas.record(n, ptr, dflt)
            if not nf:
                co = po = []
            checked += 1
            if (cs, ca, co) != (ps, pa, po):
                bad += 1
                print(f"layout {triple} {n}: C size {cs} align {ca} offsets {co}; "
                      f"Pascal size {ps} align {pa} offsets {po}")
        assert arr[k] == -1
    shutil.rmtree(tmp, ignore_errors=True)
    print(f"layouts: {checked} compared ({len(names)} structs x {len(TARGETS)} targets), {bad} different")
    return bad


def check_flat(sdk_dir):
    flat = open(os.path.join(sdk_dir, "steam_api_flat.h"), encoding="latin-1").read()
    decl = {}
    for m in re.finditer(r"S_API\s+(.*?)\s*\b(SteamAPI_\w+)\s*\(([^)]*)\)\s*;", flat):
        ps = [p.strip() for p in m.group(3).split(",") if p.strip() and p.strip() != "void"]
        decl[m.group(2)] = (m.group(1).strip(), ps)
    csize = {"bool": 1, "char": 1, "int8": 1, "uint8": 1, "unsigned char": 1, "int16": 2, "uint16": 2,
             "short": 2, "unsigned short": 2, "int": 4, "int32": 4, "uint32": 4, "unsigned int": 4,
             "float": 4, "int64": 8, "uint64": 8, "long long": 8, "unsigned long long": 8, "double": 8,
             "uint64_steamid": 8, "uint64_gameid": 8, "intp": "P", "uintp": "P", "int64_t": 8,
             "int32_t": 4}
    psz = dict(BASIC, **{p: "P" for p in PTR})
    pas = PascalLayout()

    def pascal_size(t):
        t = t.strip()
        while t in pas.aliases and t not in psz:
            t = pas.aliases[t]
        return 4 if t in pas.enums else psz.get(t, "?" + t)

    def c_size(ct):
        ct = " ".join(re.sub(r"\bconst\b", "", ct).split())
        if "*" in ct or "&" in ct:
            return "P"
        return csize.get(ct, pascal_size(ct))

    bad = n = 0
    plugdir = os.path.join(ROOT, "lib", "plugins")
    for f in sorted(os.listdir(plugdir)):
        t = open(os.path.join(plugdir, f), encoding="utf-8-sig").read().replace("\r", "")
        pm = re.search(r"PFX = '(\w+)'", t)
        if not pm or "GENERATED by tools/gen_steam_api.py" not in t:
            continue
        for m in re.finditer(r"Bind\(FFlat\.(\w+), PFX \+ '(\w+)'", t):
            name = pm.group(1) + m.group(2)
            sig = re.search(r"^    " + m.group(1) + r": (function|procedure)\(([^)]*)\)(?:: (\w+))?; cdecl;", t, re.M)
            pps = [x.split(":")[1].strip() for x in sig.group(2).split(";")][1:]
            if name not in decl:
                print(f"flat {name}: not declared in steam_api_flat.h")
                bad += 1
                continue
            cret, cps = decl[name]
            cps = cps[1:]
            n += 1
            probs = []
            if len(pps) != len(cps):
                probs.append(f"{len(pps)} parameters, C has {len(cps)}")
            else:
                for pp, cp in zip(pps, cps):
                    ct = re.sub(r"\s*\w+$", "", cp) if re.search(r"\w$", cp) else cp
                    if pascal_size(pp) != c_size(ct):
                        probs.append(f"{pp} vs C '{cp}'")
            pr = sig.group(3)
            if (pr is None) != (cret == "void") or (pr and pascal_size(pr) != c_size(cret)):
                probs.append(f"result {pr} vs C {cret}")
            if probs:
                bad += 1
                print(f"flat {name}: {'; '.join(probs)}")
    print(f"flat signatures: {n} checked against steam_api_flat.h, {bad} different")
    return bad


def main():
    if len(sys.argv) < 2:
        print(__doc__)
        sys.exit(2)
    sdk_dir = sys.argv[1]
    sdk = gen.SDK(sdk_dir)
    types = gen.TypesUnit(sdk)
    types.emit()
    names = [n for n in types.struct_order() if n not in types.skipped_structs]
    bad = check_layouts(sdk_dir, sdk, names) + check_flat(sdk_dir)
    print("Result: " + ("OK" if not bad else f"{bad} problem(s)"))
    sys.exit(1 if bad else 0)


if __name__ == "__main__":
    main()
