#!/usr/bin/env python3
"""Verifies the generated binding against the real SDK headers.

    python3 tools/verify_generated.py <sdk/public/steam folder>

1. Struct layouts: compiles the SDK headers with clang (no platform SDK
   needed: system headers are stubbed) for Win64, Win32, Linux x86_64,
   macOS ARM64 and the FPC-only targets Linux32 (i686) and LinuxARM64
   (aarch64), reads sizeof / alignof / offsetof of every struct generated
   in lib/Steamworks.SDKTypes.pas, and compares them with the layout Delphi
   gives the generated records (alignment rules of {$ALIGN n} / packed
   record, as set by Steamworks.inc and Steamworks.AlignNatural.inc).
   Skipped with a note when clang is not installed.
2. Flat signatures: every Flat entry of every generated plug-in against
   steam_api_flat.h - parameter count, and pointer-ness and size of each
   parameter and of the result.
3. By-value returns: the exports declared by hand because they return a
   struct by value (tools/plugin_extras/Input.pas.txt) - clang's lowering of
   each on every target (register / two registers / hidden pointer) must be
   the one the hand-written declarations assume (BYVALUE below).

Exit code 0 = no differences. Run after every tools/gen_steam_api.py run.

The checks above model DELPHI's record rules. FPC can lay records out
differently (2026-11-02: a packed record with a variant part), so the
compiled layout can be measured too:

    python3 tools/verify_generated.py <sdk> --probe tools/LayoutProbe/LayoutProbe.dpr
        writes a console program that prints SizeOf and every field offset of
        every record in Steamworks.SDKTypes (FPC: fpc -Mdelphi
        -Fu<repo>/lib -Fi<repo>/lib LayoutProbe.dpr; Delphi: a console
        project with lib on its search path). Run it, save the output.
    python3 tools/verify_generated.py <sdk> --compare <output> <clang triple>
        compares that output with the C layout of the SAME target (triple
        as in TARGETS, e.g. x86_64-pc-windows-msvc for Win64).
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
    # FPC-only targets (Delphi has neither): Linux32 and LinuxARM64
    "i686-unknown-linux-gnu": (4, 4),
    "aarch64-unknown-linux-gnu": (8, 4),
}
# Largest alignment a NATURAL-region record ({$packrecords C} in FPC,
# {$ALIGN 8} in Delphi) gives a field: i386 System V aligns 8-byte scalars
# (int64, double) to 4 inside structs, and FPC's C packing follows that
# (maxCrecordalign 4 on i386-linux). Default 8.
NATURAL_CAP = {"i686-unknown-linux-gnu": 4}
BASIC = {"Boolean": 1, "AnsiChar": 1, "Byte": 1, "UInt8": 1, "Int8": 1, "UInt16": 2, "Int16": 2,
         "Integer": 4, "Int32": 4, "UInt32": 4, "Cardinal": 4, "Single": 4, "Int64": 8, "UInt64": 8,
         "Double": 8}
PTR = ("NativeInt", "NativeUInt", "Pointer", "PAnsiChar")


def strip_comments(t):
    t = re.sub(r"\{[^$][^}]*\}", "", t)
    t = re.sub(r"\(\*.*?\*\)", "", t, flags=re.S)
    return re.sub(r"//[^\n]*", "", t)


def parse_unit(path, text=None):
    """Aliases, Pascal enums and records (with alignment context) of a unit,
    as DELPHI sees it: {$ifdef FPC} ... {$endif} blocks (FPC's explicit
    record padding) are left out."""
    txt = (text if text is not None else open(path, encoding="utf-8-sig").read())
    txt = txt.replace("\r", "").split("\nimplementation")[0]
    lines = strip_comments(txt).split("\n")
    kept, depth = [], 0
    for l in lines:
        t = l.strip()
        if depth:
            if re.match(r"^\{\$(if|ifdef|ifndef)\b", t, re.I):
                depth += 1
            elif re.match(r"^\{\$(endif|ifend)\}", t, re.I):
                depth -= 1
            continue
        if re.match(r"^\{\$ifdef FPC\}$", t, re.I):
            depth = 1
            continue
        kept.append(l)
    lines = kept
    aliases, enums, recs, natural, i = {}, set(), {}, False, 0
    while i < len(lines):
        l = lines[i].strip()
        if "AlignNatural.inc" in l:
            natural = True
        elif "AlignDefault.inc" in l:
            natural = False
        m = re.match(r"^(\w+)\s*=\s*(packed |\{\$ifdef FPC\}packed\{\$endif\} )?record\b", l)
        if m:
            fpc_packed = bool(m.group(2)) and m.group(2).startswith("{")
            fields, variants = [], None
            i += 1
            while not lines[i].strip().startswith("end;"):
                ln = lines[i].strip()
                if re.match(r"^case\b.*\bof$", ln):
                    variants = []
                elif variants is not None:
                    # "N: (a: T; b: T);" - may continue over several lines
                    vm = re.match(r"^\d+:\s*\((.*)$", ln)
                    if vm:
                        body = vm.group(1)
                        while not body.endswith(");"):
                            i += 1
                            body += " " + lines[i].strip()
                        variants.append([(a.strip(), b.strip()) for a, b in
                                         (x.split(":", 1) for x in body[:-2].split(";") if x.strip())])
                else:
                    fm = re.match(r"^\s*(\w+): (.+);$", lines[i])
                    if fm:
                        fields.append((fm.group(1), fm.group(2)))
                i += 1
            recs[m.group(1)] = dict(packed=bool(m.group(2)) and not fpc_packed, natural=natural,
                                    fields=fields, variants=variants or [], fpc_packed=fpc_packed)
        else:
            if re.match(r"^(\w+)\s*=\s*\($", l):
                enums.add(l.split("=")[0].strip())
            m = re.match(r"^(\w+)\s*=\s*([\w\[\]. ]+?);$", l)
            if m:
                aliases[m.group(1)] = m.group(2)
        i += 1
    return aliases, enums, recs


class PascalLayout:
    def __init__(self, sdktypes_text=None):
        # set per target by the checks (see NATURAL_CAP)
        self.natural_cap = 8
        a1, e1, r1 = parse_unit(os.path.join(ROOT, "lib", "Steamworks.Types.pas"))
        a2, e2, r2 = parse_unit(os.path.join(ROOT, "lib", "Steamworks.SDKTypes.pas"), sdktypes_text)
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

    def record(self, n, ptr, dflt, named=None):
        """(size, alignment, offsets of the fixed fields); with named = {}
        also every field's offset by name, variant fields included. A variant
        part is laid out as Delphi / FPC do: each variant starts where the
        fixed part ends, each field aligned on its own; the record is as big
        as its largest variant."""
        r = self.recs[n]
        pack = 1 if r["packed"] else (self.natural_cap if r["natural"] else dflt)
        off, ra, offs = 0, 1, []
        for fn, ft in r["fields"]:
            sz, al = self.type(ft, ptr, dflt)
            a = min(al, pack)
            off = (off + a - 1) // a * a
            offs.append(off)
            if named is not None:
                named[fn] = off
            off += sz
            ra = max(ra, a)
        end = off
        for var in r.get("variants", []):
            vo = off
            for fn, ft in var:
                sz, al = self.type(ft, ptr, dflt)
                a = min(al, pack)
                vo = (vo + a - 1) // a * a
                if named is not None:
                    named[fn] = vo
                vo += sz
                ra = max(ra, a)
            end = max(end, vo)
        return (end + ra - 1) // ra * ra, ra, offs


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
        pas.natural_cap = NATURAL_CAP.get(triple, 8)
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


def named_records():
    """[(Pascal record, C type)] of the hand-written union records: every
    record in tools/sdk_extras/*.pas.txt whose doc comment says
    "C type: <C++ type>." (nested types and decltype(...) included)."""
    out = []
    xdir = os.path.join(ROOT, "tools", "sdk_extras")
    for f in sorted(os.listdir(xdir)) if os.path.isdir(xdir) else []:
        t = open(os.path.join(xdir, f), encoding="utf-8").read()
        for m in re.finditer(r"C type:\s*([\w:() ]+?)\.\s*\}\s*\n\s*(\w+)\s*=\s*(?:packed )?record", t):
            out.append((m.group(2), " ".join(m.group(1).split())))
    return out


def check_named(sdk_dir):
    """Hand-written union records: size, alignment and the offset of EVERY
    field - variant members included - compared by name with clang's
    offsetof on every target."""
    recs = named_records()
    if not recs:
        return 0
    clang = shutil.which("clang++")
    if not clang:
        print("named layouts: SKIPPED - clang++ not installed")
        return 0
    pas = PascalLayout()
    order = []
    for pn, ct in recs:
        named = {}
        pas.record(pn, 8, 8, named)
        order.append((pn, ct, list(named)))
    tmp = tempfile.mkdtemp(prefix="steamnamed")
    stub = os.path.join(tmp, "stub")
    os.makedirs(stub)
    open(os.path.join(stub, "string.h"), "w").write(
        "#include <stddef.h>\nvoid *memset(void*,int,size_t); void *memcpy(void*,const void*,size_t);\n"
        "int memcmp(const void*,const void*,size_t); size_t strlen(const char*);\n"
        "char *strncpy(char*,const char*,size_t); int strcmp(const char*,const char*);\n")
    open(os.path.join(stub, "stdio.h"), "w").write(
        "#include <stddef.h>\nint snprintf(char*,size_t,const char*,...); int sprintf(char*,const char*,...);\n")
    src = ["#define private public", "#define protected public", '#include "steam_api.h"',
           '#include "steamnetworkingfakeip.h"', "#include <stddef.h>",
           'extern "C" const long long LAYOUT[] = {']
    for pn, ct, fields in order:
        src.append(f"  (long long)sizeof({ct}), (long long)alignof({ct}),")
        for f in fields:
            src.append(f"  (long long)__builtin_offsetof({ct}, {f}),")
    src.append("  -1 };")
    cpp = os.path.join(tmp, "named.cpp")
    open(cpp, "w").write("\n".join(src) + "\n")
    resdir = subprocess.run([clang, "-print-resource-dir"], capture_output=True, text=True).stdout.strip()
    bad = checked = nfields = 0
    for triple, (ptr, dflt) in TARGETS.items():
        pas.natural_cap = NATURAL_CAP.get(triple, 8)
        ll = os.path.join(tmp, triple + ".ll")
        r = subprocess.run([clang, "-target", triple, "-std=c++17", "-ffreestanding", "-nostdinc++", "-w",
                            "-isystem", stub, "-isystem", os.path.join(resdir, "include"), "-I", sdk_dir,
                            "-S", "-emit-llvm", "-o", ll, cpp], capture_output=True, text=True)
        if r.returncode:
            print(f"named layouts: clang failed for {triple}:\n{r.stderr[:2000]}")
            return 1
        arr = [int(x) for x in re.findall(r"i64 (-?\d+)", re.search(r"@LAYOUT = [^\n]*", open(ll).read()).group(0))]
        k = 0
        for pn, ct, fields in order:
            cs, ca = arr[k], arr[k + 1]
            co = arr[k + 2:k + 2 + len(fields)]
            k += 2 + len(fields)
            named = {}
            ps, pa, _ = pas.record(pn, ptr, dflt, named)
            po = [named[f] for f in fields]
            checked += 1
            nfields += len(fields)
            if (cs, ca, co) != (ps, pa, po):
                bad += 1
                diff = [f"{f} C {c} / Pascal {p}" for f, c, p in zip(fields, co, po) if c != p]
                print(f"named layout {triple} {pn} ({ct}): C size {cs} align {ca}; Pascal size {ps} "
                      f"align {pa}" + (f"; offsets differ: {', '.join(diff)}" if diff else ""))
        assert arr[k] == -1
    shutil.rmtree(tmp, ignore_errors=True)
    print(f"named layouts (hand-written union records): {checked} compared "
          f"({len(order)} records x {len(TARGETS)} targets, {nfields // len(TARGETS)} fields each round), {bad} different")
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
             "uint64_steamid": 8, "uint64_gameid": 8, "intp": "P", "uintp": "P", "intptr_t": "P", "int64_t": 8,
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
        # Types declared inside an interface are written with its scope in
        # steam_api_flat.h (ISteamHTMLSurface::EHTMLMouseButton); the
        # Pascal binding declares them at unit level
        ct = re.sub(r"\b\w+::", "", ct)
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


# Exports that return a struct by value, declared by hand per platform in
# tools/plugin_extras. For each target: how the C result comes back -
# "i16" one 16-bit register, "two" two 64-bit registers, "sret" a hidden
# result pointer (an argument on Windows / x64, X8 on ARM64). Change the
# extras file and this table together. i686 Linux is listed so the C side of
# Linux32 is pinned down too (all sret; the FPC side there is unverified).
# Not visible in the IR: on 32-bit x86 MSVC the caller pops the hidden
# pointer, i386 System V the callee - checked by hand with clang -S.
BYVALUE_TARGETS = ["i686-pc-windows-msvc", "x86_64-pc-windows-msvc", "x86_64-unknown-linux-gnu",
                   "x86_64-apple-macos11", "arm64-apple-macos11", "aarch64-linux-android",
                   "aarch64-unknown-linux-gnu", "i686-unknown-linux-gnu"]
BYVALUE = {
    # export: (struct, params after the interface pointer, {target prefix: lowering})
    "SteamAPI_ISteamInput_GetDigitalActionData": ("InputDigitalActionData_t", 2,
                                                  {"i686-unknown-linux": "sret", "": "i16"}),
    "SteamAPI_ISteamInput_GetAnalogActionData": ("InputAnalogActionData_t", 2,
                                                 {"i686-pc-windows": "sret", "x86_64-pc-windows": "sret", "i686-unknown-linux": "sret",
                                                  "": "two"}),
    "SteamAPI_ISteamInput_GetMotionData": ("InputMotionData_t", 1, {"": "sret"}),
    # 20 bytes, pack(1): tools/plugin_extras/GameServer.pas.txt (2026-11-02)
    "SteamAPI_ISteamGameServer_GetPublicIP": ("SteamIPAddress_t", 0, {"": "sret"}),
}


def check_byvalue(sdk_dir):
    clang = shutil.which("clang++")
    if not clang:
        print("by-value returns: SKIPPED - clang++ not installed")
        return 0
    flat = open(os.path.join(sdk_dir, "steam_api_flat.h"), encoding="latin-1").read()
    bad = 0
    for name, (struct, nparams, _) in BYVALUE.items():
        m = re.search(r"S_API\s+(\w+)\s+" + name + r"\s*\(([^)]*)\)", flat)
        if not m or m.group(1) != struct or len([p for p in m.group(2).split(",") if p.strip()]) != nparams + 1:
            print(f"by-value {name}: steam_api_flat.h no longer declares it as {struct} with "
                  f"{nparams} parameters after self - update tools/plugin_extras and BYVALUE")
            bad += 1
    if bad:
        return bad
    tmp = tempfile.mkdtemp(prefix="steambyval")
    try:
        return bad + _byvalue_ir(clang, sdk_dir, tmp)
    finally:
        shutil.rmtree(tmp, ignore_errors=True)


def _byvalue_ir(clang, sdk_dir, tmp):
    """Compiles a caller of each BYVALUE export per target and compares the
    lowering clang chose with the table."""
    bad = 0
    stub = os.path.join(tmp, "stub")
    os.makedirs(stub)
    open(os.path.join(stub, "string.h"), "w").write(
        "#include <stddef.h>\nvoid *memset(void*,int,size_t); void *memcpy(void*,const void*,size_t);\n"
        "int memcmp(const void*,const void*,size_t); size_t strlen(const char*);\n"
        "char *strncpy(char*,const char*,size_t); int strcmp(const char*,const char*);\n")
    open(os.path.join(stub, "stdio.h"), "w").write(
        "#include <stddef.h>\nint snprintf(char*,size_t,const char*,...); int sprintf(char*,const char*,...);\n")
    src = ['#include "steam_api_flat.h"']
    for i, (name, (struct, nparams, _)) in enumerate(BYVALUE.items()):
        args = ", ".join(["0"] * nparams)
        iface = name.split("_")[1]   # SteamAPI_<ISteamX>_<Method>
        src.append(f"{struct} call{i}(void* s) {{ return {name}(({iface}*)s{', ' + args if args else ''}); }}")
    cpp = os.path.join(tmp, "byval.cpp")
    open(cpp, "w").write("\n".join(src) + "\n")
    resdir = subprocess.run([clang, "-print-resource-dir"], capture_output=True, text=True).stdout.strip()
    n = 0
    for triple in BYVALUE_TARGETS:
        r = subprocess.run([clang, "-target", triple, "-std=c++17", "-ffreestanding", "-nostdinc++", "-w",
                            "-isystem", stub, "-isystem", os.path.join(resdir, "include"),
                            "-I", sdk_dir, "-I", os.path.dirname(os.path.abspath(sdk_dir)),
                            "-S", "-emit-llvm", "-o", "-", cpp], capture_output=True, text=True)
        if r.returncode:
            print(f"by-value returns: clang failed for {triple}:\n{r.stderr[:2000]}")
            return 1
        for name, (struct, _, want) in BYVALUE.items():
            d = re.search(r"^declare .*@" + name + r"\(.*$", r.stdout, re.M)
            if not d:
                print(f"by-value {triple} {name}: no declaration in the IR")
                bad += 1
                continue
            ret = re.match(r"declare (?:\w+ )*?(\{[^}]*\}|\[[^\]]*\]|\w+) @", d.group(0)).group(1)
            got = ("sret" if "sret(" in d.group(0) else "i16" if ret == "i16" else
                   "two" if re.fullmatch(r"\{ i64, i\d+ \}|\[2 x i64\]", ret) else ret)
            exp = next(v for k, v in sorted(want.items(), key=lambda kv: -len(kv[0])) if triple.startswith(k))
            n += 1
            if got != exp:
                bad += 1
                print(f"by-value {triple} {name}: C returns it as {got} ({d.group(0).strip()}), "
                      f"the hand-written declaration assumes {exp}")
    print(f"by-value returns: {n} checked ({len(BYVALUE)} exports x {len(BYVALUE_TARGETS)} targets), {bad} different")
    return bad


def probe_entries(sdk, names):
    """[(Pascal record, C type, [(Pascal field, C field)])] for the probe:
    generated records (C field names from steam_api.json, matched by
    position with the Pascal fields) and the hand-written union records
    (Pascal field names = C member names)."""
    pas = PascalLayout()
    out = []
    for n in names:
        cf = [f["fieldname"] for f in sdk.structs[n]["fields"]]
        pf = [f for f, _ in pas.recs[n]["fields"]]
        if len(cf) != len(pf):
            continue
        out.append((n, n, list(zip(pf, cf))))
    for pn, ct in named_records():
        named = {}
        pas.record(pn, 8, 8, named)
        out.append((pn, ct, [(f, f) for f in named]))
    return out


def write_probe(sdk, names, path):
    ents = probe_entries(sdk, names)
    L = ["(* GENERATED by tools/verify_generated.py --probe: prints SizeOf and the",
         "  offset of every field of every record in Steamworks.SDKTypes, as the",
         "  compiler that builds it lays them out. Compare the output with",
         "  verify_generated.py --compare. Not part of any package. *)",
         "program LayoutProbe;", "", "{$ifdef FPC}", "  {$mode delphi}{$H+}", "{$else}",
         "  {$APPTYPE CONSOLE}", "{$endif}", "", "uses", "  Steamworks.Types, Steamworks.SDKTypes;", "",
         "procedure R(const AName: string; ASize: Integer; const AOffsets: array of NativeInt);",
         "var", "  I: Integer;", "  S: string;", "begin",
         "  Str(ASize, S);", "  S := AName + ' ' + S;", "  for I := 0 to High(AOffsets) do",
         "  begin", "    S := S + ' ';", "    S := S + IntToStrProbe(AOffsets[I]);", "  end;",
         "  Writeln(S);", "end;", ""]
    # IntToStr without SysUtils
    L[L.index("procedure R(const AName: string; ASize: Integer; const AOffsets: array of NativeInt);"):
      L.index("procedure R(const AName: string; ASize: Integer; const AOffsets: array of NativeInt);")] = [
        "function IntToStrProbe(V: NativeInt): string;", "begin", "  Str(V, Result);", "end;", ""]
    L.append("type")
    for pn, _, _ in ents:
        L.append(f"  PProbe_{pn} = ^{pn};")
    L += ["", "begin"]
    for pn, _, fl in ents:
        offs = ", ".join(f"NativeInt(@PProbe_{pn}(nil)^.{p})" for p, _ in fl)
        L.append(f"  R('{pn}', SizeOf({pn}), [{offs}]);")
    L.append("end.")
    os.makedirs(os.path.dirname(os.path.abspath(path)), exist_ok=True)
    open(path, "w", newline="\r\n").write("\n".join(L) + "\n")
    print(f"probe: {path} written ({len(ents)} records)")


def compare_probe(sdk_dir, sdk, names, out_file, triple):
    ents = probe_entries(sdk, names)
    clang = shutil.which("clang++")
    if not clang:
        print("compare: clang++ not installed")
        return 1
    tmp = tempfile.mkdtemp(prefix="steamprobe")
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
    for pn, ct, fl in ents:
        src.append(f"  (long long)sizeof({ct}),")
        for _, c in fl:
            src.append(f"  (long long)__builtin_offsetof({ct}, {c}),")
    src.append("  -1 };")
    cpp = os.path.join(tmp, "probe.cpp")
    open(cpp, "w").write("\n".join(src) + "\n")
    resdir = subprocess.run([clang, "-print-resource-dir"], capture_output=True, text=True).stdout.strip()
    ll = os.path.join(tmp, "probe.ll")
    r = subprocess.run([clang, "-target", triple, "-std=c++17", "-ffreestanding", "-nostdinc++", "-w",
                        "-isystem", stub, "-isystem", os.path.join(resdir, "include"), "-I", sdk_dir,
                        "-S", "-emit-llvm", "-o", ll, cpp], capture_output=True, text=True)
    if r.returncode:
        print(f"compare: clang failed for {triple}:\n{r.stderr[:2000]}")
        return 1
    arr = [int(x) for x in re.findall(r"i64 (-?\d+)", re.search(r"@LAYOUT = [^\n]*", open(ll).read()).group(0))]
    shutil.rmtree(tmp, ignore_errors=True)
    got = {}
    for line in open(out_file, encoding="utf-8", errors="replace"):
        parts = line.split()
        if len(parts) >= 2 and re.fullmatch(r"\w+", parts[0]) and all(re.fullmatch(r"-?\d+", p) for p in parts[1:]):
            got[parts[0]] = [int(p) for p in parts[1:]]
    k = bad = checked = 0
    for pn, ct, fl in ents:
        c = arr[k:k + 1 + len(fl)]
        k += 1 + len(fl)
        g = got.get(pn)
        if g is None:
            print(f"compare: {pn} missing from the probe output")
            bad += 1
            continue
        checked += 1
        if g != c:
            bad += 1
            diff = [f"{p} C {cv} / compiled {gv}" for (p, _), cv, gv in zip(fl, c[1:], g[1:]) if cv != gv]
            print(f"compare {triple} {pn}: C size {c[0]}, compiled size {g[0]}" +
                  (f"; offsets differ: {', '.join(diff)}" if diff else ""))
    print(f"compare: {checked} records compared with {triple}, {bad} different")
    return bad


def main():
    if len(sys.argv) < 2:
        print(__doc__)
        sys.exit(2)
    sdk_dir = sys.argv[1]
    sdk = gen.SDK(sdk_dir)
    types = gen.TypesUnit(sdk)
    types.emit()
    names = [n for n in types.struct_order()
             if n not in types.skipped_structs and n not in types.union_extras]
    if len(sys.argv) >= 4 and sys.argv[2] == "--probe":
        write_probe(sdk, names, sys.argv[3])
        sys.exit(0)
    if len(sys.argv) >= 5 and sys.argv[2] == "--compare":
        sys.exit(1 if compare_probe(sdk_dir, sdk, names, sys.argv[3], sys.argv[4]) else 0)
    bad = (check_layouts(sdk_dir, sdk, names) + check_named(sdk_dir) + check_flat(sdk_dir)
           + check_byvalue(sdk_dir))
    print("Result: " + ("OK" if not bad else f"{bad} problem(s)"))
    sys.exit(1 if bad else 0)


if __name__ == "__main__":
    main()
