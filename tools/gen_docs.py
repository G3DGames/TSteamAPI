#!/usr/bin/env python3
"""Generates the Markdown reference for every plug-in / component pair.

    python3 tools/gen_docs.py

For each lib/plugins/Steamworks.Plugin.<Name>.pas it writes
docs/components/TSteam<Name>.md: the component (TSteam<Name>) with every
event, its callback id and payload record (fields from
lib/Steamworks.SDKTypes.pas), then the plug-in (TSteam<Name>Plugin) with
every public method, property and ...Async call, with the PasDoc text
turned into Markdown. Hand-written overview text comes from
tools/doc_extras/<Name>.md and is placed after the title.

Like the plug-ins themselves the output is GENERATED: change this script or
tools/doc_extras/ and run it again; never edit docs/components/TSteam*.md.
docs/components/README.md and TSteamAPI.md are hand-written.

Run it whenever the plug-ins are regenerated (tools/gen_steam_api.py); it
needs only the repository, not the SDK. Exit code 0 = written.
"""
import os, re, sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PLUGINS = os.path.join(ROOT, "lib", "plugins")
SDKTYPES = os.path.join(ROOT, "lib", "Steamworks.SDKTypes.pas")
EXTRAS = os.path.join(ROOT, "tools", "doc_extras")
OUT = os.path.join(ROOT, "docs", "components")


# ---------------------------------------------------------------- PasDoc -> Markdown

def pasdoc_to_md(text):
    """Turns PasDoc markup into Markdown (good enough for generated docs)."""
    # @longCode(# ... #) -> fenced block
    def longcode(m):
        body = m.group(1).strip("\n")
        lines = body.split("\n")
        indent = min((len(l) - len(l.lstrip()) for l in lines if l.strip()), default=0)
        body = "\n".join(l[indent:] for l in lines)
        return "\n\n```pascal\n" + body + "\n```\n\n"
    text = re.sub(r"@longCode\(#(.*?)#\)", longcode, text, flags=re.S)
    # Simple tags (repeat for nesting such as @code(@link(X)))
    for _ in range(3):
        text = re.sub(r"@(?:code|link|name|classname)\(([^()]*)\)", r"`\1`", text)
        text = re.sub(r"@bold\(([^()]*)\)", r"**\1**", text)
        text = re.sub(r"@italic\(([^()]*)\)", r"*\1*", text)
    text = re.sub(r"@true\b", "`True`", text)
    text = re.sub(r"@false\b", "`False`", text)
    text = re.sub(r"@nil\b", "`nil`", text)
    text = re.sub(r"@returns\(", "Returns: (", text)
    text = re.sub(r"@raises\(", "Raises: (", text)
    text = re.sub(r"@param\((\w+)\s+", r"Parameter `\1`: (", text)
    text = text.replace("@@", "@")
    return text


def clean_comment(raw):
    """Strips comment delimiters and re-flows a doc comment."""
    raw = raw.strip()
    if raw.startswith("(*"):
        raw = raw[2:]
        if raw.endswith("*)"):
            raw = raw[:-2]
    elif raw.startswith("{"):
        raw = raw[1:]
        if raw.endswith("}"):
            raw = raw[:-1]
    # keep @longCode blocks' line structure, re-flow everything else
    parts = re.split(r"(@longCode\(#.*?#\))", raw, flags=re.S)
    out = []
    for p in parts:
        if p.startswith("@longCode"):
            out.append(p)
        else:
            out.append(re.sub(r"\s+", " ", p))
    return pasdoc_to_md("".join(out).strip())


def md_cell(text):
    """Makes text safe inside a Markdown table cell."""
    text = text.replace("|", "\\|")
    text = re.sub(r"\n+```pascal\n.*?\n```\n+", " (example in the source) ", text, flags=re.S)
    return re.sub(r"\s+", " ", text).strip()


# ---------------------------------------------------------------- Pascal scanning

def class_body(src, class_name, base):
    """Text of 'class_name = class(base) ... end;' (first match), or ''."""
    m = re.search(r"^\s*" + re.escape(class_name) + r"\s*=\s*class\(" + re.escape(base) + r"\)",
                  src, re.M)
    if not m:
        return ""
    end = re.search(r"^  end;", src[m.end():], re.M)
    return src[m.end():m.end() + end.start()] if end else ""


def class_doc(src, class_name):
    """The doc comment right before 'class_name = class'."""
    m = re.search(r"((?:\{[^}]*\}|\(\*.*?\*\))\s*)(?:\{\$[^}]*\}\s*|\[[^\]]*\]\s*)*" +
                  re.escape(class_name) + r"\s*=\s*class", src, re.S)
    return clean_comment(m.group(1)) if m else ""


def members(body):
    """[(visibility, doc, declaration)] for every member of a class body."""
    result = []
    vis = "private"
    doc = ""
    i = 0
    n = len(body)
    while i < n:
        # skip whitespace
        while i < n and body[i] in " \t\r\n":
            i += 1
        if i >= n:
            break
        if body.startswith("{$", i):                 # compiler directive
            j = body.find("}", i)
            i = j + 1
            continue
        if body.startswith("{", i):
            j = body.find("}", i)
            doc = body[i:j + 1]
            i = j + 1
            continue
        if body.startswith("(*", i):
            j = body.find("*)", i)
            doc = body[i:j + 2]
            i = j + 2
            continue
        if body.startswith("//", i):
            j = body.find("\n", i)
            i = n if j < 0 else j + 1
            continue
        m = re.match(r"(strict\s+)?(private|protected|public|published)\b", body[i:])
        if m:
            vis = m.group(2)
            i += m.end()
            doc = ""
            continue
        # a declaration: up to the ';' that ends it (outside parentheses)
        depth = 0
        j = i
        while j < n:
            c = body[j]
            if c == "(":
                depth += 1
            elif c == ")":
                depth -= 1
            elif c == ";" and depth == 0:
                # directives such as 'override;', 'deprecated;' follow on the same line
                rest = re.match(r"\s*(override|virtual|abstract|static|overload|inline|"
                                r"reintroduce|dynamic|deprecated(\s+'[^']*')?|default)\s*;", body[j + 1:])
                if rest:
                    j += 1 + rest.end() - 1
                    continue
                break
            j += 1
        decl = re.sub(r"\s+", " ", body[i:j + 1]).strip()
        result.append((vis, doc, decl))
        doc = ""
        i = j + 1
    return result


def member_name(decl):
    m = re.match(r"(?:class\s+)?(?:function|procedure|property|constructor|destructor)\s+(\w+)", decl)
    if m:
        return m.group(1)
    m = re.match(r"(\w+)\s*:", decl)
    return m.group(1) if m else decl


def record_fields(sdk, struct):
    """[(doc, 'name: type')] of an SDK record, or None."""
    m = re.search(r"^  " + re.escape(struct) + r" = (?:packed )?record\b(.*?)^  end;", sdk, re.M | re.S)
    if not m:
        return None
    fields = []
    for vis, doc, decl in members(m.group(1)):
        if decl.startswith(("case ", "function", "procedure")):
            continue
        fields.append((clean_comment(doc) if doc else "", decl.rstrip(";")))
    return fields


# ---------------------------------------------------------------- page

def generate(name, sdk):
    unit = f"Steamworks.Plugin.{name}"
    path = os.path.join(PLUGINS, unit + ".pas")
    src = open(path, encoding="ascii").read()
    plugin_cls = f"TSteam{name}Plugin"
    comp_cls = f"TSteam{name}"
    iface = f"ISteam{name}"

    plugin_body = class_body(src, plugin_cls, "TSteamPlugin")
    comp_body = class_body(src, comp_cls, "TSteamPluginComponent")
    if not plugin_body:
        raise SystemExit(f"{unit}: class {plugin_cls} not found")

    # event types: TXxxEvent = procedure(...) of object;
    event_types = {m.group(1): m.group(2) for m in re.finditer(
        r"^\s*(T\w+Event)\s*=\s*(procedure\([^)]*\)) of object;", src, re.M)}

    out = []
    w = out.append
    w(f"# {comp_cls} and {plugin_cls} ({iface})")
    w("")
    w(f"> **Generated** by `tools/gen_docs.py` from `lib/plugins/{unit}.pas` - do not edit.")
    w(f"> Hand-written text: `tools/doc_extras/{name}.md`. Steam's own descriptions are Valve's")
    w("> SDK comments, as in the generated units.")
    w("")
    w(f"Unit: `{unit}` - linking it (a `uses` entry, or dropping a `{comp_cls}`) enables the")
    w(f"plug-in. Steam interface: `{iface}` (SDK 1.65).")
    w("")
    extras = os.path.join(EXTRAS, name + ".md")
    if os.path.exists(extras):
        w(open(extras, encoding="utf-8").read().strip())
        w("")

    comp_members = members(comp_body) if comp_body else []
    events = [(d, decl) for v, d, decl in comp_members if v == "published" and decl.startswith("property On")]
    plug_members = [(d, decl) for v, d, decl in members(plugin_body) if v == "public"]

    w("## Contents")
    w("")
    w(f"* [The component: {comp_cls}](#the-component-{comp_cls.lower()})")
    w(f"  * [Events ({len(events)})](#events)")
    w(f"* [The plug-in: {plugin_cls}](#the-plug-in-{plugin_cls.lower()})")
    w("  * [Methods](#methods)")
    w("  * [Async methods](#async-methods)")
    w("  * [Properties](#properties)")
    w("* [Payload records](#payload-records)")
    w("")

    # ---------------- component
    w(f"## The component: {comp_cls}")
    w("")
    if comp_body:
        w(class_doc(src, comp_cls))
        w("")
        w("| Member | Kind | Description |")
        w("|--------|------|-------------|")
        w(f"| `SteamAPI` | published property | The `TSteamAPI` this component belongs to. At run time a component whose owner has exactly one `TSteamAPI` links itself. |")
        w(f"| `Plugin` | public property | The `{plugin_cls}` for calls; `nil` while Steam is not running. |")
        w("| `Attached` | public property | `True` while the events are subscribed (Steam running, `SteamAPI` set). |")
        w("| `Attach` / `Detach` | public methods | Subscribe / remove the events by hand (normally automatic). |")
        w("")
        w("Events run on the thread chosen by the root's `UpdateMode` / `Delivery` - the main")
        w("thread by default (see [GameEngineIntegration.md](../GameEngineIntegration.md)). Each event")
        w("checks that Steam's payload size equals the Pascal record's; a mismatch raises")
        w("`ESteamworksError` instead of handing over a wrong record. Call results of the same")
        w("struct reach the event too (unless an `...Async` call claimed them); failed call results")
        w("raise no event and are logged as warnings.")
        w("")
        w("### Events")
        w("")
        if events:
            w("| Event | Callback | Payload | Description |")
            w("|-------|----------|---------|-------------|")
            for d, decl in events:
                m = re.match(r"property (On\w+): (T\w+)", decl)
                ev, ty = m.group(1), m.group(2)
                text = clean_comment(d) if d else ""
                cb = re.match(r"Callback (\d+) \((\w+)\):\s*(.*)", text, re.S)
                if cb:
                    w(f"| `{ev}` | {cb.group(1)} | [`{cb.group(2)}`](#{cb.group(2).lower()}) | {md_cell(cb.group(3))} |")
                else:
                    w(f"| `{ev}` | | | {md_cell(text)} |")
            w("")
            w("Handler signature (the IDE generates it when you double-click the event):")
            w("")
            d, decl = events[0]
            m = re.match(r"property (On\w+): (T\w+)", decl)
            sig = event_types.get(m.group(2), "procedure(Sender: TObject; const AData: ...)")
            params = sig[len("procedure"):]
            w("```pascal")
            w(f"procedure TForm1.{comp_cls[1:]}1{m.group(1)[2:]}{params};")
            w("```")
            w("")
        else:
            w("This interface has no callbacks.")
            w("")
    else:
        w("(No component in this unit.)")
        w("")

    # ---------------- plug-in
    w(f"## The plug-in: {plugin_cls}")
    w("")
    w(class_doc(src, plugin_cls) or f"Wraps `{iface}`.")
    w("")
    w("Reach it through the component (`" + comp_cls[1:] + "1.Plugin`) or the core:")
    w("")
    w("```pascal")
    w(f"P := {plugin_cls}(Steam.FindPlugin({plugin_cls}));   // Delphi also: Steam.Plugin<{plugin_cls}>")
    w("if P <> nil then ...")
    w("```")
    w("")
    w("Every flat export is bound as optional: calling a method whose export the loaded")
    w("Steam library lacks raises `ESteamworksError` naming the export (`Assigned(P.Flat.Xxx)`")
    w("tells beforehand). Method names follow Valve's flat API (`GetStatInt32`, not the C++")
    w("overload `GetStat`); `const char*` parameters are `string`, 64-bit Steam ids `TSteamID`,")
    w("single out-values `var`; buffers and NULL-able pointers stay `Pointer`.")
    w("")

    methods, asyncs, props = [], [], []
    for d, decl in plug_members:
        nm = member_name(decl)
        if decl.startswith("class function") and nm in ("PluginName", "InterfaceVersions"):
            continue
        if decl.startswith("property"):
            props.append((d, decl))
        elif "AHandler: TSteamCallResultEvent" in decl:
            # by parameter, not by name: Valve's own FileReadAsync is a plain
            # method, its handler variant an overload of the same name
            asyncs.append((d, decl))
        elif decl.startswith(("function", "procedure", "class function", "class procedure")):
            methods.append((d, decl))

    def emit_list(items):
        for d, decl in items:
            nm = member_name(decl)
            w(f"#### {nm}")
            w("")
            w("```pascal")
            w(decl)
            w("```")
            w("")
            text = clean_comment(d) if d else ""
            if "deprecated" in decl and not text.lower().startswith("deprecated"):
                text = ("**Deprecated.** " + text).strip()
            elif "deprecated" in decl:
                text = "**Deprecated" + text[len("deprecated"):]
                text = text.replace("**Deprecated:", "**Deprecated:**", 1) if text.startswith("**Deprecated:") else text + "**"
            if text:
                w(text)
                w("")

    w("### Methods")
    w("")
    if methods:
        w("| Method | Summary |")
        w("|--------|---------|")
        for d, decl in methods:
            nm = member_name(decl)
            first = md_cell(clean_comment(d)) if d else ""
            if len(first) > 160:   # whole text when short; never cut at "e.g."
                first = first[:157].rsplit(" ", 1)[0] + " ..."
            w(f"| [`{nm}`](#{nm.lower()}) | {first} |")
        w("")
        emit_list(methods)
    else:
        w("None.")
        w("")

    w("### Async methods")
    w("")
    if asyncs:
        w("Each `...Async` method starts the call and registers `AHandler` for its result")
        w("(`procedure(const AData: TSteamCallbackData; AIOFailure: Boolean) of object`). The")
        w("handler runs once, on the delivery thread, with the result record in `AData`")
        w("(`AData.CopyTo(Rec, SizeOf(Rec))`); its object owns the registration - call")
        w("`Steam.Dispatcher.RemoveOwner(Self)` in that object's destructor. The plain method of")
        w("the same name returns the `SteamAPICall_t` instead, and its result reaches the")
        w("component's event.")
        w("")
        plain = {member_name(decl) for _, decl in methods}
        same = sorted({member_name(decl) for _, decl in asyncs} & plain)
        if same:
            w("Valve's own " + " / ".join(f"`{n}`" for n in same) + " already end in Async:")
            w("there the handler variant is an overload of the same name with the extra")
            w("`AHandler` parameter.")
            w("")
        emit_list(asyncs)
    else:
        w("None.")
        w("")

    w("### Properties")
    w("")
    if props:
        w("| Property | Description |")
        w("|----------|-------------|")
        for d, decl in props:
            nm = member_name(decl)
            ty = re.match(r"property \w+(?:\[[^\]]*\])?: ([\w.<>]+)", decl)
            w(f"| `{nm}: {ty.group(1) if ty else ''}` | {md_cell(clean_comment(d)) if d else ''} |")
        w("")
    else:
        w("None.")
        w("")

    # ---------------- payload records
    w("## Payload records")
    w("")
    w("Declared in `Steamworks.SDKTypes` (generated from the SDK headers; layouts verified")
    w("against the C headers for Win64, Win32, Linux64 and macOS ARM64).")
    w("")
    seen = []
    for d, decl in events:
        text = clean_comment(d) if d else ""
        cb = re.match(r"Callback (\d+) \((\w+)\)", text)
        if not cb or cb.group(2) in seen:
            continue
        struct = cb.group(2)
        seen.append(struct)
        w(f"### {struct}")
        w("")
        w(f"Callback id {cb.group(1)} (`{struct}_k_iCallback`).")
        w("")
        fields = record_fields(sdk, struct)
        if fields is None:
            w("(Record not found in Steamworks.SDKTypes.)")
        elif not fields:
            w("No fields (an empty struct in C++).")
        else:
            w("| Field | C declaration |")
            w("|-------|---------------|")
            for fdoc, fdecl in fields:
                w(f"| `{fdecl}` | {md_cell(fdoc)} |")
        w("")

    return "\n".join(out).rstrip() + "\n"


def main():
    sdk = open(SDKTYPES, encoding="ascii").read()
    os.makedirs(OUT, exist_ok=True)
    names = sorted(f[len("Steamworks.Plugin."):-4] for f in os.listdir(PLUGINS)
                   if f.startswith("Steamworks.Plugin.") and f.endswith(".pas"))
    for name in names:
        page = generate(name, sdk)
        dest = os.path.join(OUT, f"TSteam{name}.md")
        with open(dest, "w", encoding="utf-8", newline="\n") as f:
            f.write(page)
        print(f"wrote {os.path.relpath(dest, ROOT)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
