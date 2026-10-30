#!/usr/bin/env python3
"""Generates the Pascal binding of the Steamworks flat API from the SDK.

    python3 tools/gen_steam_api.py <sdk/public/steam folder> [--report]

Input (never committed - Steamworks partner licence): steam_api.json and the
headers of sdk/public/steam. The headers supply what the JSON lacks: the
#pragma pack region of every struct and the doc comments of every method.

Output (committed):
  lib/Steamworks.SDKTypes.pas               every typedef, constant, enum,
                                            struct and callback struct
  lib/plugins/Steamworks.Plugin.<Name>.pas  one plug-in per interface in
                                            PLUGINS below

Each plug-in unit has
  * T<Name>Flat - a record of every flat export of the interface, with its
    exact C signature (pointers stay pointers), exposed as the plug-in's Flat
    property together with Handle (the interface pointer);
  * a TSteamPlugin descendant with one method per export, named after the
    flat export (GetStatInt32, not the C++ overload name), converting
    const char* to string, C strings returned to string, uint64 Steam ids to
    TSteamID; anything else keeps its C type. Methods returning a
    SteamAPICall_t with a known result struct get an ...Async overload that
    registers the handler for the result.
  * Every export is bound as optional; calling one the loaded library lacks
    raises ESteamworksError naming the export.
Hand-written additions live in tools/plugin_extras/<Name>.pas.txt (sections
//@uses //@types //@private //@public //@implementation //@initialize) and
are merged verbatim. Generated files must never be edited by hand.

Rules this generator enforces (see CLAUDE.md):
  * ASCII only; doc comment for every declaration (tools/pasdoc_check.py);
  * Pascal enums only when FPC accepts them (ascending, unique values, not
    bit flags); otherwise an Integer type with typed constants;
  * record alignment follows the header: callback-pack regions use the
    Steamworks.inc default (8 Windows / 4 elsewhere), pack(1) regions are
    packed records, natural regions switch to C natural alignment
    (Steamworks.AlignNatural.inc) and back (Steamworks.AlignDefault.inc);
  * pointer-sized C types (intp, uintp, intptr_t, size_t) are NativeInt /
    NativeUInt even though steam_api.json, produced on a 64-bit machine,
    lists them as long long.
"""
import json
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# Interfaces generated as plug-ins (class name -> unit / plug-in name).
# Game-server interfaces and the rest come in later batches.
PLUGINS = {
    "ISteamUtils": "Utils",
    "ISteamUser": "User",
    "ISteamFriends": "Friends",
    "ISteamApps": "Apps",
    "ISteamUserStats": "UserStats",
}

# Declared by hand in lib/Steamworks.Types.pas (read at run time as well).
PASCAL_KEYWORDS = set("""and array as asm begin case class const constructor destructor dispinterface
div do downto else end except exports file finalization finally for function goto if implementation
in inherited initialization inline interface is label library mod nil not object of or out packed
procedure program property raise record repeat resourcestring set shl shr string then threadvar to
try type unit until uses var while with xor absolute abstract operator self result""".split())

# Members of TSteamPlugin / TObject a generated method or parameter must not hide
RESERVED_MEMBERS = set(x.lower() for x in """Create Destroy Free ClassName ClassType Log LogFmt Bind Subscribe
AwaitCallResult Unsubscribe Initialize Finalize Steam Active PluginName Dependencies IsRequired
InterfaceVersions Handle Flat DoInitialize DoFinalize FIntf FFlat Need ToString Equals Hash
GetHashCode Dispatch FieldAddress MethodAddress""".split())

BASIC = {
    "void": None, "bool": "Boolean", "char": "AnsiChar", "signed char": "Int8",
    "unsigned char": "UInt8", "short": "Int16", "unsigned short": "UInt16",
    "int": "Integer", "unsigned int": "UInt32", "long long": "Int64",
    "unsigned long long": "UInt64", "float": "Single", "double": "Double",
    "uint8": "UInt8", "int8": "Int8", "uint16": "UInt16", "int16": "Int16",
    "uint32": "UInt32", "int32": "Int32", "uint64": "UInt64", "int64": "Int64",
    "lint64": "Int64", "ulint64": "UInt64", "int64_t": "Int64",
    "intp": "NativeInt", "uintp": "NativeUInt", "intptr_t": "NativeInt",
    "size_t": "NativeUInt", "uint64_steamid": "UInt64", "uint64_gameid": "UInt64",
}
# Hand-declared records (structs passed by value are not generated)
RECORD_TYPES = {"CSteamID", "CGameID", "SteamIPAddress_t", "CallbackMsg_t", "SteamAPICallCompleted_t"}
SKIP_TYPEDEFS = {"uint8", "int8", "int16", "uint16", "int32", "uint32", "int64", "uint64",
                 "lint64", "ulint64", "intp", "uintp"}


def die(msg):
    sys.stderr.write("gen_steam_api: " + msg + "\n")
    sys.exit(2)


# ------------------------------------------------------------------ text --

def ascii_text(s):
    s = (s.replace("\u2018", "'").replace("\u2019", "'").replace("\u201c", '"')
          .replace("\u201d", '"').replace("\u2013", "-").replace("\u2014", "-")
          .replace("\u2026", "...").replace("\t", " "))
    return "".join(c if 32 <= ord(c) < 127 else "?" for c in s)


def sdk_text(s):
    """Text copied from the SDK: ASCII, PasDoc '@' escaped, ends with a full stop."""
    s = ascii_text(" ".join(s.split())).strip().replace("@", "@@")
    if s and s[-1] not in ".!?":
        s += "."
    return s


def doc(text, indent):
    """A PasDoc comment for TEXT (one line or wrapped), safe for nesting."""
    text = ascii_text(" ".join(text.split())).strip() or "(undocumented in the SDK)"
    if "{" in text or "}" in text:
        text = text.replace("*)", "* )")
        open_, close = "(* ", " *)"
    else:
        open_, close = "{ ", " }"
    words, lines, cur = text.split(" "), [], ""
    width = 96 - len(indent)
    for w in words:
        if cur and len(cur) + 1 + len(w) > width:
            lines.append(cur)
            cur = w
        else:
            cur = (cur + " " + w) if cur else w
    lines.append(cur)
    out = [indent + open_ + lines[0]]
    for l in lines[1:]:
        out.append(indent + "  " + l)
    out[-1] += close
    return "\n".join(out)


# ----------------------------------------------------------------- model --

class SDK:
    def __init__(self, folder):
        path = os.path.join(folder, "steam_api.json")
        if not os.path.isfile(path):
            die(f"{path} not found - pass the SDK's public/steam folder")
        self.json = json.load(open(path, encoding="utf-8"))
        self.headers = {}
        for f in sorted(os.listdir(folder)):
            if f.endswith(".h"):
                self.headers[f] = open(os.path.join(folder, f), encoding="latin-1").read()
        for need in ("steamclientpublic.h", "steamnetworkingtypes.h", "isteamapps.h"):
            if need not in self.headers:
                die(f"{need} missing - pass the complete public/steam folder")
        self.report = []
        self.hand_types = self._hand_names()
        self.typedefs = {t["typedef"]: t["type"] for t in self.json["typedefs"]}
        self._collect_enums()
        self.structs = {s["struct"]: s for s in self.json["structs"] + self.json["callback_structs"]}
        self.region = {name: self._region(name) for name in self.structs}

    def _hand_names(self):
        text = open(os.path.join(ROOT, "lib", "Steamworks.Types.pas"), encoding="utf-8-sig").read()
        iface = text.split("\nimplementation")[0]
        return set(re.findall(r"^\s{2}([A-Za-z_][A-Za-z0-9_]*)\s*(?::\s*[A-Za-z_][A-Za-z0-9_]*\s*)?=", iface, re.M))

    # enums: global, nested in callback structs, nested in interfaces
    def _collect_enums(self):
        self.enums = {}
        def add(e, owner):
            name = e["enumname"]
            if name in self.enums:
                return
            vals = []
            for v in e["values"]:
                vals.append((v["name"], int(v["value"], 0)))
            self.enums[name] = dict(name=name, values=vals, owner=owner)
        for e in self.json["enums"]:
            add(e, None)
        for c in self.json["callback_structs"]:
            for e in c.get("enums", []):
                add(e, c["struct"])
        for i in self.json["interfaces"]:
            for e in i.get("enums", []):
                add(e, i["classname"])
        for e in self.enums.values():
            nums = [v for _, v in e["values"]]
            ascending = all(b > a for a, b in zip(nums, nums[1:]))
            flags = ("Flag" in e["name"] or
                     (len(nums) > 3 and max(nums) > 8 and all(n == 0 or n & (n - 1) == 0 for n in nums)))
            e["pascal"] = ascending and not flags

    def _region(self, name):
        for h, t in self.headers.items():
            m = re.search(r"(\b(?:struct|class)\s+" + re.escape(name) + r"\b(?!\s*;)|STEAM_CALLBACK_BEGIN\(\s*"
                          + re.escape(name) + r"\b)", t)
            if not m:
                continue
            stack = []
            prev = None
            for pm in re.finditer(r"#pragma\s+pack\(\s*(push\s*,\s*(\w+)|pop)\s*\)", t[:m.start()]):
                if pm.group(1).startswith("push"):
                    # '#if SMALL push,4 #elif LARGE push,8 #endif' is ONE push
                    between = t[prev.end():pm.start()] if prev is not None else "x"
                    if (pm.group(2) == "8" and prev is not None and prev.group(1).startswith("push")
                            and prev.group(2) == "4"
                            and all(l.strip() == "" or l.strip().startswith("#") for l in between.split("\n"))):
                        prev = pm
                        continue
                    stack.append(pm.group(2))
                elif stack:
                    stack.pop()
                prev = pm
            top = stack[-1] if stack else None
            return h, {None: "natural", "1": "pack1", "4": "callback", "8": "callback"}[top]
        return None, "unknown"

    def struct_body(self, name):
        """C body of struct / class NAME (comments removed), or ''."""
        for t in self.headers.values():
            m = re.search(r"(\b(?:struct|class)\s+" + re.escape(name) + r"\b[^;{]*\{|STEAM_CALLBACK_BEGIN\(\s*"
                          + re.escape(name) + r"\b[^)]*\))", t)
            if not m:
                continue
            body = t[m.end():]
            body = re.sub(r"//[^\n]*", "", body)
            body = re.sub(r"/\*.*?\*/", "", body, flags=re.S)
            if m.group(0).startswith("STEAM_CALLBACK_BEGIN"):
                end = body.find("STEAM_CALLBACK_END")
                return body[:end] if end >= 0 else body
            depth, i = 1, 0
            while i < len(body) and depth:
                depth += {"{": 1, "}": -1}.get(body[i], 0)
                i += 1
            return body[:i]
        return ""

    # ---------------------------------------------------- header comments
    def method_doc(self, classname, method):
        """Comment lines above 'virtual ... Method(' inside 'class ClassName'."""
        for t in self.headers.values():
            m = re.search(r"\bclass\s+" + re.escape(classname) + r"\b[^;]*?\{", t)
            if not m:
                continue
            body = t[m.end():]
            end = re.search(r"\n\};", body)
            body = body[:end.start()] if end else body
            mm = re.search(r"\n[^\n]*\bvirtual\b[^\n(]*\b" + re.escape(method) + r"\s*\(", body)
            if not mm:
                return ""
            lines = body[:mm.start()].split("\n")
            out = []
            for l in reversed(lines):
                s = l.strip()
                if s.startswith("STEAM_") or s.startswith("#"):
                    continue
                if s.startswith("//"):
                    s = s.lstrip("/").strip()
                    if set(s) <= set("-=*"):
                        continue
                    out.append(s)
                    continue
                break
            return sdk_text(" ".join(reversed(out)))
        return ""

    def decl_doc(self, name, kind):
        """Comment lines above 'enum Name' / 'struct Name' in any header."""
        pat = {"enum": r"\benum\s+" + re.escape(name) + r"\b(?!\s*;)",
               "struct": r"(\b(?:struct|class)\s+" + re.escape(name) + r"\b(?!\s*;)|STEAM_CALLBACK_BEGIN\(\s*"
                         + re.escape(name) + r"\b)"}[kind]
        for t in self.headers.values():
            m = re.search(pat, t)
            if not m:
                continue
            lines = t[:m.start()].split("\n")[:-1]
            out = []
            for l in reversed(lines):
                s = l.strip()
                if s.startswith("#pragma") or s == "" and not out:
                    if s == "":
                        break
                    continue
                if s.startswith("//"):
                    s = s.lstrip("/").strip()
                    if set(s) <= set("-=*") or s.lower().startswith("purpose:") and len(s) < 10:
                        continue
                    out.append(re.sub(r"^Purpose:\s*", "", s))
                    continue
                break
            return sdk_text(" ".join(reversed(out)))
        return ""


# ----------------------------------------------------------- type mapping --

def split_type(ctype):
    """'const char *' -> ('char', is_const, pointer_depth, array_len)."""
    t = ctype.strip()
    arr = None
    m = re.match(r"^(.*?)\s*\[(\d+)\]$", t)
    if m:
        t, arr = m.group(1), int(m.group(2))
    t = t.replace("&", "*")
    depth = t.count("*")
    t = t.replace("*", " ")
    const = bool(re.search(r"\bconst\b", t))
    t = re.sub(r"\bconst\b", " ", t)
    t = " ".join(t.split())
    t = re.sub(r"^(struct|class|enum)\s+", "", t)
    t = t.split("::")[-1]
    return t, const, depth, arr


class Mapper:
    def __init__(self, sdk):
        self.sdk = sdk

    def base(self, name):
        """Pascal name of a non-pointer, non-array C type, or None if unknown."""
        if name in BASIC:
            return BASIC[name]
        if name == "CSteamID":
            return "TSteamID"
        if name == "CGameID":
            return "CGameID"
        if name in self.sdk.enums:
            return name
        if name in self.sdk.typedefs:
            return name if name not in SKIP_TYPEDEFS else BASIC.get(name)
        if name in self.sdk.structs:
            return name
        if name in self.sdk.hand_types:
            return name
        return None

    def field(self, ctype):
        """Pascal type of a struct field (layout must match exactly)."""
        if "(*)" in ctype:
            return "Pointer"
        name, const, depth, arr = split_type(ctype)
        if depth:
            pas = "PAnsiChar" if name == "char" and depth == 1 else "Pointer"
        else:
            pas = self.base(name)
            if pas is None:
                return None
        if arr:
            return f"array[0..{arr - 1}] of {pas}"
        return pas

    def flat(self, ctype):
        """Pascal type in a flat signature: exact ABI, pointers untyped."""
        if "(*)" in ctype:
            return "Pointer"
        name, const, depth, arr = split_type(ctype)
        if arr:
            return "Pointer"
        if depth:
            return "PAnsiChar" if name == "char" and depth == 1 else "Pointer"
        pas = self.base(name)
        if pas is None:
            return None
        if name in self.sdk.structs or name in RECORD_TYPES:
            return "STRUCT_BY_VALUE"
        return pas


# ------------------------------------------------------------ constants --

INT_RANGES = {"Int8": (8, True), "UInt8": (8, False), "Int16": (16, True), "UInt16": (16, False),
              "Integer": (32, True), "Int32": (32, True), "UInt32": (32, False),
              "Int64": (64, True), "UInt64": (64, False), "NativeInt": (64, True), "NativeUInt": (64, False)}


def resolve_basic(sdk, pas):
    """Underlying basic Pascal type of a typedef name (e.g. UGCHandle_t -> UInt64)."""
    seen = 0
    while pas not in INT_RANGES and pas not in ("Single", "Double") and seen < 10:
        c = sdk.typedefs.get(pas)
        if c is None:
            return pas
        pas = BASIC.get(c, c)
        seen += 1
    return pas


def eval_const(expr, values):
    e = expr
    e = re.sub(r"'(.)'", lambda m: str(ord(m.group(1))), e)                   # 'd' -> 100
    e = re.sub(r"\(\s*[A-Za-z_][A-Za-z0-9_ ]*\)\s*(?=[~(0-9A-Za-z_'])", " ", e)  # casts
    e = re.sub(r"(0x[0-9A-Fa-f]+|\d+)(ull|ULL|u|U|ll|LL)\b", r"\1", e)
    e = re.sub(r"(\d+\.\d*|\d+)f\b", r"\1", e)
    e = re.sub(r"\b([A-Za-z_][A-Za-z0-9_]*)\b",
               lambda m: repr(values[m.group(1)]) if m.group(1) in values else m.group(1), e)
    if re.search(r"[A-Za-z_]", re.sub(r"0x[0-9A-Fa-f]+", "0", e)):
        raise ValueError("unresolved name in " + expr)
    return eval(e, {"__builtins__": {}}, {})


# --------------------------------------------------------------- emitter --

class TypesUnit:
    def __init__(self, sdk):
        self.sdk = sdk
        self.map = Mapper(sdk)
        self.out = []
        self.skipped_structs = {}

    def w(self, s=""):
        self.out.append(s)

    def struct_order(self):
        sdk = self.sdk
        names = [n for n in sdk.structs if n not in sdk.hand_types]
        deps = {}
        for n in names:
            d = set()
            for f in sdk.structs[n]["fields"]:
                base, _, depth, _ = split_type(f["fieldtype"])
                if not depth and base in sdk.structs and base != n and base not in sdk.hand_types:
                    d.add(base)
            deps[n] = d
        order, done = [], set()

        def visit(n, stack=()):
            if n in done:
                return
            for d in sorted(deps[n]):
                if d not in stack:
                    visit(d, stack + (n,))
            done.add(n)
            order.append(n)
        # global structs first (alphabetical), then callback structs by id
        cb = {c["struct"]: c["callback_id"] for c in sdk.json["callback_structs"]}
        for n in sorted(names, key=lambda x: (x in cb, cb.get(x, 0), x.lower())):
            visit(n)
        return order

    def check_struct(self, name):
        """Reason the struct cannot be generated, or None."""
        sdk = self.sdk
        if sdk.region[name][1] == "unknown":
            return "layout unknown: only forward-declared in the public headers"
        if re.search(r"\bunion\b", sdk.struct_body(name)):
            return ("contains a C union, which steam_api.json lists as separate fields - "
                    "needs variant-record support (networking batch)")
        for f in sdk.structs[name]["fields"]:
            if self.map.field(f["fieldtype"]) is None:
                return f"field {f['fieldname']}: C type '{f['fieldtype']}' not mapped"
            base, _, depth, _ = split_type(f["fieldtype"])
            if not depth and base in self.skipped_structs:
                return f"field {f['fieldname']}: uses {base}, which is not generated"
        return None

    def emit(self):
        sdk = self.sdk
        w = self.w
        w("(* @abstract(Every typedef, constant, enum, struct and callback struct of the")
        w("  Steamworks SDK " + "1.65 flat API, generated from steam_api.json.)")
        w("")
        w("  GENERATED by tools/gen_steam_api.py - do not edit; change the generator")
        w("  and run it again. Hand-declared types (handles, EUniverse, TSteamID, ...)")
        w("  live in Steamworks.Types and are not repeated here.")
        w("")
        w("  Record alignment follows the SDK headers: callback structs use the")
        w("  default of Steamworks.inc (8 on Windows, 4 elsewhere), pack(1) structs")
        w("  are packed records, and naturally aligned structs are bracketed by")
        w("  Steamworks.AlignNatural.inc / Steamworks.AlignDefault.inc.")
        w("  Bit-flag, non-ascending and duplicate-value enums are Integer types")
        w("  with constants (FPC rejects them as Pascal enums). *)")
        w("unit Steamworks.SDKTypes;")
        w("")
        w("{$I Steamworks.inc}")
        w("")
        w("interface")
        w("")
        w("uses")
        w("  Steamworks.Types;")
        w("")
        w("type")
        w(doc("Game id (CGameID), 64 bits. Declared under #pragma pack(1) in "
              "steamclientpublic.h, so it is only byte-aligned inside structs.", "  "))
        w("  CGameID = packed record")
        w(doc("The raw 64-bit game id.", "    "))
        w("    Value: UInt64;")
        w("  end;")
        w("")
        self.emit_typedefs()
        self.emit_enums()
        self.emit_structs()
        self.emit_consts()
        w("implementation")
        w("")
        w("end.")
        return "\n".join(self.out) + "\n"

    def emit_typedefs(self):
        sdk, w = self.sdk, self.w
        w("  // --- typedefs -------------------------------------------------------------")
        for t in sdk.json["typedefs"]:
            name, ctype = t["typedef"], t["type"]
            if name in SKIP_TYPEDEFS or name in sdk.hand_types:
                continue
            if "(*)" in ctype:
                w(doc(f"C callback type @code({ctype}); passed as an untyped pointer.", "  "))
                w(f"  {name} = Pointer;")
                continue
            pas = self.map.field(ctype)
            if pas is None:
                sdk.report.append(f"typedef {name}: '{ctype}' not mapped - skipped")
                continue
            w(doc(f"C typedef @code({name}) = @code({ctype}).", "  "))
            w(f"  {name} = {pas};")
        w("")

    def emit_enums(self):
        sdk, w = self.sdk, self.w
        w("  // --- enums ----------------------------------------------------------------")
        for e in sorted(sdk.enums.values(), key=lambda e: e["name"].lower()):
            name = e["name"]
            if name in sdk.hand_types:
                continue
            text = sdk.decl_doc(name, "enum") or f"Steam enum {name}."
            if e["owner"]:
                text += f" (Declared inside {e['owner']}.)"
            if e["pascal"]:
                w(doc(text, "  "))
                w(f"  {name} = (")
                vals = e["values"]
                for i, (vn, vv) in enumerate(vals):
                    w(f"    {vn} = {vv}" + ("," if i < len(vals) - 1 else ""))
                w("  );")
            else:
                w(doc(text + " Integer-typed: values are the k_ constants below (bit flags, "
                      "unordered or duplicate values).", "  "))
                w(f"  {name} = Integer;")
        w("")

    def emit_structs(self):
        sdk, w = self.sdk, self.w
        cb_ids = {c["struct"]: c["callback_id"] for c in sdk.json["callback_structs"]}
        w("  // --- structs ----------------------------------------------------------------")
        for name in self.struct_order():
            reason = self.check_struct(name)
            if reason:
                self.skipped_structs[name] = reason
                sdk.report.append(f"struct {name}: not generated ({reason})")
                continue
            s = sdk.structs[name]
            header, region = sdk.region[name]
            text = sdk.decl_doc(name, "struct") or f"Steam struct {name}."
            if name in cb_ids:
                text = f"Callback {cb_ids[name]}: " + text + f" Subscribe with @code({name}_k_iCallback)."
            text += f" ({header}, {'pack(1)' if region == 'pack1' else region + ' alignment'}.)"
            if region == "natural":
                w("{$I Steamworks.AlignNatural.inc}")
            w(doc(text, "  "))
            w(f"  {name} = {'packed record' if region == 'pack1' else 'record'}")
            if not s["fields"]:
                w(doc("Placeholder: the C++ struct is empty (sizeof = 1).", "    "))
                w("    _dummy: Byte;")
            used = set()
            for f in s["fields"]:
                fname = f["fieldname"]
                if fname.lower() in used or fname.lower() in PASCAL_KEYWORDS:
                    fname = fname + "_"
                used.add(fname.lower())
                w(doc(f"C field @code({f['fieldtype']} {f['fieldname']})."
                      + (" Private in the SDK." if f.get("private") else ""), "    "))
                w(f"    {fname}: {self.map.field(f['fieldtype'])};")
            w("  end;")
            w(doc(f"Pointer to @link({name}).", "  "))
            w(f"  P{name} = ^{name};")
            if region == "natural":
                w("{$I Steamworks.AlignDefault.inc}")
            w("")

    def emit_consts(self):
        sdk, w = self.sdk, self.w
        w("const")
        w("  // --- Integer-typed enum values ------------------------------------------------")
        for e in sorted(sdk.enums.values(), key=lambda e: e["name"].lower()):
            if e["pascal"] or e["name"] in sdk.hand_types:
                continue
            for vn, vv in e["values"]:
                w(doc(f"Value of @link({e['name']}).", "  "))
                w(f"  {vn} = {e['name']}({vv});")
        w("")
        w("  // --- constants --------------------------------------------------------------")
        values = {}
        consts = list(sdk.json["consts"])
        for c in sdk.json["callback_structs"]:
            for k in c.get("consts", []):
                k = dict(k)
                k["constname"] = c["struct"] + "_" + k["constname"]
                consts.append(k)
        for c in consts:
            name, ctype, expr = c["constname"], c["consttype"], c["constval"]
            try:
                v = eval_const(expr, values)
            except Exception as ex:
                sdk.report.append(f"const {name} = {expr}: {ex} - skipped")
                continue
            values[name] = v
            if name in sdk.hand_types:
                continue
            pas = self.map.field(ctype) or "Integer"
            basic = resolve_basic(sdk, pas)
            text = f"C constant @code({ctype} {name} = {expr})."
            if isinstance(v, float) or basic in ("Single", "Double"):
                w(doc(text, "  "))
                w(f"  {name} = {float(v)!r};")
                continue
            bits, signed = INT_RANGES.get(basic, (32, True))
            v &= (1 << bits) - 1
            if signed and v >= 1 << (bits - 1):
                v -= 1 << bits
            if not signed and v == (1 << bits) - 1 and bits == 64:
                lit = f"High({pas})"
            else:
                lit = f"{pas}({v})" if v >= 0 else f"{pas}(-{-v})"
            w(doc(text, "  "))
            w(f"  {name} = {lit};")
        w("")
        w("  // --- callback ids -----------------------------------------------------------")
        for c in sorted(sdk.json["callback_structs"], key=lambda c: c["callback_id"]):
            n = c["struct"]
            cname = n + "_k_iCallback"
            if cname in sdk.hand_types or n in self.skipped_structs:
                continue
            w(doc(f"Callback id of @link({n}) ({c['callback_id']}).", "  "))
            w(f"  {cname} = {c['callback_id']};")
        w("")


# ----------------------------------------------------------- plug-in unit --

ARRAY_ANNOT = ("array_count", "out_array_count", "out_array_call", "buffer_count",
               "out_buffer_count", "out_string_count", "out_string")


COUNT_NAME = re.compile(r"^(c[A-Z]|cb|cub|cch|n\w*(Size|Max|Count)$|\w*BufferSize$)")
BUFFER_NAME = re.compile(r"^(pub|pvec|prg|rg)")


class Param:
    def __init__(self, unit, p, next_name=""):
        self.cname = p["paramname"]
        self.ctype = p.get("paramtype_flat", p["paramtype"])
        self.annot = {k: v for k, v in p.items() if k in ARRAY_ANNOT}
        m = unit.map
        self.flat = m.flat(self.ctype)
        base, const, depth, arr = split_type(self.ctype)
        self.base, self.const, self.depth = base, const, depth
        self.kind, self.ftype = "raw", self.flat
        if self.ctype == "uint64_steamid":
            self.kind, self.ftype = "steamid", "TSteamID"
        elif base == "char" and const and depth == 1 and not self.annot:
            self.kind, self.ftype = "str", "string"
        elif (depth == 1 and not const and not self.annot and not arr and base not in ("void", "char")
              and not COUNT_NAME.match(next_name) and not BUFFER_NAME.match(self.cname)):
            # a single out-value; buffers (followed by a count) and const struct
            # pointers (often optional NULL) stay raw pointers
            pas = "TSteamID" if base == "CSteamID" else m.base(base)
            if pas:
                self.kind, self.ftype = "var", pas


class PluginUnit:
    def __init__(self, sdk, iface, name, types_unit):
        self.sdk, self.iface, self.name = sdk, iface, name
        self.map = Mapper(sdk)
        self.types = types_unit
        self.cls = f"TSteam{name}Plugin"
        self.flat_t = f"TSteam{name}Flat"
        self.prefix = f"SteamAPI_{iface['classname']}_"
        self.extras = self.load_extras()
        self.comp = f"TSteam{name}"
        self.callbacks = self.interface_callbacks()
        self.methods = []
        self.unsupported = []
        self.raw_methods = []
        self.prepare()

    def interface_callbacks(self):
        """Generated callback structs declared in this interface's header, by id."""
        sdk = self.sdk
        header = None
        for h, txt in sdk.headers.items():
            if re.search(r"\bclass\s+" + re.escape(self.iface["classname"]) + r"\b[^;]*?\{", txt):
                header = h
                break
        out = []
        for c in sorted(sdk.json["callback_structs"], key=lambda c: c["callback_id"]):
            n = c["struct"]
            if n in sdk.hand_types or n in self.types.skipped_structs:
                continue
            if sdk.region[n][0] == header:
                base = n[:-2] if n.endswith("_t") else n
                out.append(dict(struct=n, id=c["callback_id"], base=base,
                                event=f"T{base}Event", prop=f"On{base}", handler=f"Handle{base}",
                                field=f"FOn{base}", doc=sdk.decl_doc(n, "struct")))
        return out

    def load_extras(self):
        path = os.path.join(ROOT, "tools", "plugin_extras", self.name + ".pas.txt")
        sec = {}
        if os.path.isfile(path):
            cur = None
            for line in open(path, encoding="utf-8").read().split("\n"):
                m = re.match(r"^//@(\w+)\s*$", line)
                if m:
                    cur = m.group(1)
                    sec.setdefault(cur, [])
                elif cur:
                    sec[cur].append(line)
            for k in sec:
                while sec[k] and sec[k][-1].strip() == "":
                    sec[k].pop()
        return sec

    def prepare(self):
        taken = set(RESERVED_MEMBERS)
        for m in self.iface["methods"]:
            flat_name = m["methodname_flat"]
            pname = flat_name[len(self.prefix):] if flat_name.startswith(self.prefix) else m["methodname"]
            ret_c = m.get("returntype_flat", m["returntype"])
            raw = m["params"]
            params = [Param(self, p, raw[i + 1]["paramname"] if i + 1 < len(raw) else "")
                      for i, p in enumerate(raw)]
            ret_flat = None if ret_c == "void" else self.map.flat(ret_c)
            bad = [p.cname for p in params if p.flat in (None, "STRUCT_BY_VALUE")]
            if ret_flat in (None, "STRUCT_BY_VALUE") and ret_c != "void":
                bad.append("return " + ret_c)
            if bad:
                self.unsupported.append(f"{flat_name}: {', '.join(bad)} (struct by value or unmapped type)")
                continue
            if pname.lower() in PASCAL_KEYWORDS or pname.lower() in taken:
                pname += "_"
            taken.add(pname.lower())
            # parameter names: unique, not keywords / members / type names of the signature
            types_used = {p.ftype.lower() for p in params} | {p.flat.lower() for p in params}
            used = set()
            for p in params:
                n = p.cname
                if (n.lower() in PASCAL_KEYWORDS or n.lower() in RESERVED_MEMBERS or n.lower() in types_used
                        or n.lower() in used or n.lower() in ("aintf", "ahandler", "result")):
                    n = "A" + n[0].upper() + n[1:]
                while n.lower() in used:
                    n += "_"
                used.add(n.lower())
                p.pname = n
            cr = m.get("callresult")
            if cr and (cr not in self.sdk.structs or cr in self.types.skipped_structs):
                cr = None
            ret_f = ret_flat
            if ret_c == "uint64_steamid":
                ret_f = "TSteamID"
            elif ret_flat == "PAnsiChar":
                ret_f = "string"
            self.methods.append(dict(name=pname, flat=flat_name, params=params, ret_c=ret_c,
                                     ret_flat=ret_flat, ret_f=ret_f, callresult=cr,
                                     doc=self.sdk.method_doc(self.iface["classname"], m["methodname"])))
            if any(p.kind == "raw" and p.flat in ("Pointer", "PAnsiChar") for p in params):
                self.raw_methods.append(pname)

    # ------------------------------------------------------------ helpers
    def flat_sig(self, m):
        ps = ["AIntf: Pointer"] + [f"{p.pname}: {p.flat}" for p in m["params"]]
        if m["ret_flat"] is None:
            return f"procedure({'; '.join(ps)}); cdecl"
        return f"function({'; '.join(ps)}): {m['ret_flat']}; cdecl"

    def friendly_params(self, m, extra=None):
        ps = []
        for p in m["params"]:
            pre = {"var": "var ", "constref": "const ", "str": "const ", "steamid": "const "}.get(p.kind, "")
            ps.append(f"{pre}{p.pname}: {p.ftype}")
        if extra:
            ps.append(extra)
        return ("(" + "; ".join(ps) + ")") if ps else ""

    def header(self, m, async_=False):
        params = self.friendly_params(m, "AHandler: TSteamCallResultEvent" if async_ else None)
        name = m["name"] + ("Async" if async_ else "")
        if async_:
            return f"function {name}{params}: SteamAPICall_t"
        if m["ret_f"] is None:
            return f"procedure {name}{params}"
        return f"function {name}{params}: {m['ret_f']}"

    def method_text(self, m):
        t = m["doc"] or f"Wraps @code({m['flat']})."
        if m["callresult"]:
            t += f" Call result: @link({m['callresult']}) (@code({m['callresult']}_k_iCallback))."
        return t

    def version_const(self):
        v = self.iface.get("version_string")
        text = open(os.path.join(ROOT, "lib", "Steamworks.Versions.pas"), encoding="utf-8-sig").read()
        for n, val in re.findall(r"^\s*([A-Z0-9_]+_INTERFACE_VERSION)\s*=\s*'([^']*)'", text, re.M):
            if val == v:
                return n
        die(f"{self.iface['classname']}: version {v} not in Steamworks.Versions.pas")

    def accessor_base(self):
        for a in self.iface.get("accessors", []):
            if "GameServer" not in a["name_flat"]:
                return re.sub(r"_v\d+$", "", a["name_flat"][len("SteamAPI_"):])
        return ""

    # ------------------------------------------------------------- emit
    def emit(self):
        out = []
        w = out.append
        ci = self.iface["classname"]
        w(f"(* @abstract({ci} plug-in (SDK 1.65), generated from steam_api.json.)")
        w("")
        w("  GENERATED by tools/gen_steam_api.py - do not edit; hand-written parts")
        w(f"  come from tools/plugin_extras/{self.name}.pas.txt. Linking this unit")
        w("  enables the plug-in:")
        w("  @longCode(#")
        w(f"  P := {self.cls}(Steam.FindPlugin({self.cls}));")
        w("  #)")
        w("  Every flat export is bound as optional. Calling a method whose export the")
        w("  loaded Steam library lacks raises ESteamworksError naming the export; the")
        w("  exports missing at start-up are logged once. Flat gives the raw exports")
        w("  with their exact C signatures (first argument: Handle). *)")
        w(f"unit Steamworks.Plugin.{self.name};")
        w("")
        w("{$I Steamworks.inc}")
        w("")
        w("interface")
        w("")
        w("uses")
        uses = ["SysUtils", "Classes", "Steamworks.Types", "Steamworks.SDKTypes", "Steamworks.API",
                "Steamworks.Callbacks", "Steamworks.Core", "Steamworks.Versions", "Steamworks.Components"]
        for line in self.extras.get("uses", []):
            uses += [u.strip() for u in line.split(",") if u.strip()]
        w("  " + ", ".join(uses) + ";")
        w("")
        w("type")
        if self.extras.get("types"):
            out.extend(self.extras["types"])
            w("")
        w(doc(f"Every flat export of {ci} with its exact C signature (@nil when the "
              "loaded library lacks it). First argument: the interface pointer.", "  "))
        w(f"  {self.flat_t} = record")
        for m in self.methods:
            w(doc(f"@code({m['flat']}).", "    "))
            w(f"    {m['name']}: {self.flat_sig(m)};")
        w("  end;")
        w("")
        w(doc(f"{ci} plug-in. Registered by linking the unit; find it with "
              f"@code(Steam.FindPlugin({self.cls})).", "  "))
        w(f"  {self.cls} = class(TSteamPlugin)")
        w("  private")
        w(doc(f"The {ci} pointer (@nil when not initialised).", "    "))
        w("    FIntf: Pointer;")
        w(doc("Bound flat exports.", "    "))
        w(f"    FFlat: {self.flat_t};")
        # extras first: they may declare fields, and fields must precede methods
        out.extend(self.extras.get("private", []))
        w(doc("Raises ESteamworksError unless the plug-in is initialised and AOk "
              "(the export is bound).", "    "))
        w("    procedure Need(AOk: Boolean; const AExport: string);")
        w("  protected")
        w(doc(f"Acquires {ci} and binds its exports (all optional).", "    "))
        w("    function DoInitialize: Boolean; override;")
        w(doc("Forgets the interface pointer and the bound exports.", "    "))
        w("    procedure DoFinalize; override;")
        w("  public")
        w(doc(f"Returns @code('{ci}').", "    "))
        w("    class function PluginName: string; override;")
        w(doc("The interface version, for versioned initialisation.", "    "))
        w("    class function InterfaceVersions(AVersions: TSteamInterfaceVersions): TSteamStringArray; override;")
        w("")
        for m in self.methods:
            w(doc(self.method_text(m), "    "))
            w(f"    {self.header(m)};")
            if m["callresult"] and m["ret_f"] == "SteamAPICall_t":
                w(doc(f"Calls @link({m['name']}) and registers AHandler for its result "
                      f"(@link({m['callresult']})). The handler's object owns the registration "
                      "(remove it with Steam.Dispatcher.RemoveOwner). @returns(The call handle, "
                      "or k_uAPICallInvalid when Steam refused the call.)", "    "))
                w(f"    {self.header(m, True)};")
        if self.extras.get("public"):
            w("")
            out.extend(self.extras["public"])
        w("")
        w(doc(f"The raw {ci} pointer (first argument of every @link(Flat) export).", "    "))
        w("    property Handle: Pointer read FIntf;")
        w(doc("The bound flat exports, for calls the methods do not cover.", "    "))
        w(f"    property Flat: {self.flat_t} read FFlat;")
        w("  end;")
        w("")
        self.emit_component_decl(w)
        w("implementation")
        w("")
        w("const")
        w(f"  PFX = '{self.prefix}';")
        w("")
        w("function PCharToStr(P: PAnsiChar): string;")
        w("begin")
        w("  if P = nil then")
        w("    Result := ''")
        w("  else")
        w("    Result := string(UTF8String(P));")
        w("end;")
        w("")
        w(f"{{ {self.cls} }}")
        w("")
        w(f"class function {self.cls}.PluginName: string;")
        w("begin")
        w(f"  Result := '{ci}';")
        w("end;")
        w("")
        w(f"class function {self.cls}.InterfaceVersions(AVersions: TSteamInterfaceVersions): TSteamStringArray;")
        w("begin")
        w("  SetLength(Result, 1);")
        w(f"  Result[0] := AVersions.Resolve({self.version_const()});")
        w("end;")
        w("")
        w(f"function {self.cls}.DoInitialize: Boolean;")
        w("var")
        w("  Missing: string;")
        w("begin")
        w(f"  FIntf := AcquireUserInterface({self.version_const()}, '{self.accessor_base()}');")
        w("  if FIntf = nil then")
        w("    Exit(False);")
        w(f"  FFlat := Default({self.flat_t});")
        for m in self.methods:
            w(f"  Bind(FFlat.{m['name']}, PFX + '{m['flat'][len(self.prefix):]}', False);")
        w("  Missing := '';")
        for m in self.methods:
            w(f"  if not Assigned(FFlat.{m['name']}) then Missing := Missing + ' {m['name']}';")
        w("  if Missing <> '' then")
        w("    Log(sllDebug, 'Exports missing from the loaded library (calling them raises):' + Missing);")
        out.extend(self.extras.get("initialize", []))
        w("  Result := True;")
        w("end;")
        w("")
        w(f"procedure {self.cls}.DoFinalize;")
        w("begin")
        w("  FIntf := nil;")
        w(f"  FFlat := Default({self.flat_t});")
        w("end;")
        w("")
        w(f"procedure {self.cls}.Need(AOk: Boolean; const AExport: string);")
        w("begin")
        w("  if FIntf = nil then")
        w(f"    raise ESteamworksError.Create('{ci}.' + AExport + ': the plug-in is not initialised (Steam not running?)');")
        w("  if not AOk then")
        w(f"    raise ESteamworksError.Create('{ci}.' + AExport + ': the loaded Steam library does not export ' + PFX + AExport);")
        w("end;")
        w("")
        for m in self.methods:
            out.extend(self.body(m))
            if m["callresult"] and m["ret_f"] == "SteamAPICall_t":
                out.extend(self.async_body(m))
        if self.extras.get("implementation"):
            out.extend(self.extras["implementation"])
            w("")
        self.emit_component_impl(w)
        w("initialization")
        w(f"  TSteamworks.RegisterPlugin({self.cls});")
        w("")
        w("finalization")
        w(f"  TSteamworks.UnregisterPlugin({self.cls});")
        w("")
        w("end.")
        return "\n".join(out) + "\n"

    def emit_component_decl(self, w):
        ci = self.iface["classname"]
        for cb in self.callbacks:
            w(doc(f"Event of @link({self.comp}.{cb['prop']}): callback {cb['id']}, payload "
                  f"@link({cb['struct']}).", "  "))
            w(f"  {cb['event']} = procedure(Sender: TObject; const AData: {cb['struct']}) of object;")
        if self.callbacks:
            w("")
        w("{$ifndef FPC}")
        w("  [ComponentPlatformsAttribute(STEAM_COMPONENT_PLATFORMS)]")
        w("{$endif}")
        w(doc(f"{ci} component: drop it next to a TSteamAPI (linked automatically at run time when "
              f"the owner has exactly one, otherwise set SteamAPI). Its events are the {ci} callbacks; "
              f"call the interface through @link(Plugin).", "  "))
        w(f"  {self.comp} = class(TSteamPluginComponent)")
        w("  private")
        for cb in self.callbacks:
            w(doc(f"Backing field of @link({cb['prop']}).", "    "))
            w(f"    {cb['field']}: {cb['event']};")
        w(doc("Read accessor of @link(Plugin).", "    "))
        w(f"    function GetPlugin: {self.cls};")
        for cb in self.callbacks:
            w(doc(f"Raises @link({cb['prop']}) for {cb['struct']}.", "    "))
            w(f"    procedure {cb['handler']}(const AData: TSteamCallbackData);")
        w("  protected")
        w(doc("Subscribes every callback of this interface.", "    "))
        w("    procedure DoAttach; override;")
        w("  public")
        w(doc(f"The {ci} plug-in, for calls; @nil while Steam is not running.", "    "))
        w(f"    property Plugin: {self.cls} read GetPlugin;")
        w("  published")
        w(doc("The TSteamAPI this component belongs to.", "    "))
        w("    property SteamAPI;")
        for cb in self.callbacks:
            w(doc(f"Callback {cb['id']} ({cb['struct']}): " + (cb["doc"] or "see the SDK."), "    "))
            w(f"    property {cb['prop']}: {cb['event']} read {cb['field']} write {cb['field']};")
        w("  end;")
        w("")

    def emit_component_impl(self, w):
        c = self.comp
        w(f"{{ {c} }}")
        w("")
        w(f"function {c}.GetPlugin: {self.cls};")
        w("begin")
        w("  Result := nil;")
        w("  if TSteamworks.HasInstance then")
        w(f"    Result := {self.cls}(TSteamworks.Instance.FindPlugin({self.cls}));")
        w("end;")
        w("")
        w(f"procedure {c}.DoAttach;")
        w("begin")
        for cb in self.callbacks:
            w(f"  SubscribeCallback({cb['struct']}_k_iCallback, {cb['handler']});")
        w("end;")
        w("")
        for cb in self.callbacks:
            w(f"procedure {c}.{cb['handler']}(const AData: TSteamCallbackData);")
            w("var")
            w(f"  Ev: {cb['struct']};")
            w("begin")
            w(f"  if not Assigned({cb['field']}) then")
            w("    Exit;")
            w(f"  if not PayloadOK(AData, SizeOf(Ev), '{cb['struct']}') then")
            w("    Exit;")
            w("  AData.CopyTo(Ev, SizeOf(Ev));")
            w(f"  {cb['field']}(Self, Ev);")
            w("end;")
            w("")

    def call_args(self, m):
        args = ["FIntf"]
        for p in m["params"]:
            if p.kind == "str":
                args.append(f"PAnsiChar(U_{p.pname})")
            elif p.kind == "steamid":
                args.append(f"{p.pname}.Value")
            elif p.kind in ("var", "constref"):
                args.append(f"@{p.pname}")
            else:
                args.append(p.pname)
        return ", ".join(args)

    def body(self, m):
        hdr = self.header(m)
        hdr = hdr.replace(f" {m['name']}", f" {self.cls}.{m['name']}", 1)
        lines = [hdr + ";"]
        strs = [p for p in m["params"] if p.kind == "str"]
        if strs:
            lines.append("var")
            for p in strs:
                lines.append(f"  U_{p.pname}: UTF8String;")
        lines.append("begin")
        lines.append(f"  Need(Assigned(FFlat.{m['name']}), '{m['name']}');")
        for p in strs:
            lines.append(f"  U_{p.pname} := UTF8String({p.pname});")
        call = f"FFlat.{m['name']}({self.call_args(m)})"
        if m["ret_f"] is None:
            lines.append(f"  {call};")
        elif m["ret_f"] == "string":
            lines.append(f"  Result := PCharToStr({call});")
        elif m["ret_f"] == "TSteamID":
            lines.append(f"  Result.Value := {call};")
        else:
            lines.append(f"  Result := {call};")
        lines.append("end;")
        lines.append("")
        return lines

    def async_body(self, m):
        hdr = self.header(m, True).replace(f" {m['name']}Async", f" {self.cls}.{m['name']}Async", 1)
        args = ", ".join(p.pname for p in m["params"])
        return [hdr + ";", "begin",
                f"  Result := {m['name']}({args});" if args else f"  Result := {m['name']};",
                "  if Result <> k_uAPICallInvalid then",
                f"    Steam.Dispatcher.AwaitCallResult(Result, {m['callresult']}_k_iCallback, AHandler);",
                "end;", ""]


# ------------------------------------------------------------------ main --

def write(path, text):
    full = os.path.join(ROOT, path)
    data = text.replace("\n", "\r\n").encode("ascii")
    old = open(full, "rb").read() if os.path.exists(full) else None
    if old != data:
        open(full, "wb").write(data)
        print("wrote", path)
    else:
        print("unchanged", path)


def main():
    if len(sys.argv) < 2:
        die(__doc__.split("\n\n")[1])
    sdk = SDK(sys.argv[1])
    types = TypesUnit(sdk)
    write("lib/Steamworks.SDKTypes.pas", types.emit())
    by_name = {i["classname"]: i for i in sdk.json["interfaces"]}
    for ci, name in PLUGINS.items():
        u = PluginUnit(sdk, by_name[ci], name, types)
        write(f"lib/plugins/Steamworks.Plugin.{name}.pas", u.emit())
        for x in u.unsupported:
            sdk.report.append(f"{ci}: not generated: {x}")
        if u.raw_methods:
            sdk.report.append(f"{ci}: {len(u.raw_methods)} methods keep raw pointer parameters "
                              f"(candidates for hand wrappers): {', '.join(u.raw_methods)}")
    comps = [f"TSteam{n}" for n in PLUGINS.values()]
    reg = ["(* @abstract(Design-time registration of the generated plug-in components.)", "",
           "  GENERATED by tools/gen_steam_api.py - do not edit. The components are",
           "  framework-independent, so they are registered once, without a framework",
           "  class group, and appear on the Steamworks palette page for FMX and VCL",
           "  alike; each framework's TSteamAPI is registered by its own design",
           "  package. *)",
           "unit Steamworks.Reg;", "", "{$I Steamworks.inc}", "", "interface", "",
           "{ Registers the plug-in components on the \"Steamworks\" palette page. }",
           "procedure Register;", "", "implementation", "", "uses",
           "  Classes, DesignIntf, DesignEditors, Steamworks.Components, "
           + ", ".join(f"Steamworks.Plugin.{n}" for n in PLUGINS.values()) + ";", "",
           "type",
           "  // Adds the units the IDE-generated event handlers need (record and",
           "  // callback types) to the form's uses clause.",
           "  TSteamPluginSelectionEditor = class(TSelectionEditor)",
           "  public",
           "    procedure RequiresUnits(Proc: TGetStrProc); override;",
           "  end;", "",
           "procedure TSteamPluginSelectionEditor.RequiresUnits(Proc: TGetStrProc);", "begin",
           "  Proc('Steamworks.Types');", "  Proc('Steamworks.SDKTypes');", "  Proc('Steamworks.Callbacks');",
           "  Proc('Steamworks.Components');", "end;", "",
           "procedure Register;", "begin",
           "  RegisterComponents('Steamworks', [" + ", ".join(comps) + "]);",
           "  RegisterSelectionEditor(TSteamPluginComponent, TSteamPluginSelectionEditor);", "end;", "", "end."]
    os.makedirs(os.path.join(ROOT, "design"), exist_ok=True)
    write("design/Steamworks.Reg.pas", "\n".join(reg) + "\n")
    print("\n".join("NOTE " + r for r in sdk.report))


if __name__ == "__main__":
    main()
