#!/usr/bin/env python3
"""Checks that the Steamworks redistributables were copied into
redistributable_bin/ correctly.

    python3 tools/check_redist.py            # check redistributable_bin/
    python3 tools/check_redist.py PATH       # check another folder

Expected layout (copy the contents of sdk/redistributable_bin from
steamworks_sdk_165.zip into redistributable_bin/ at the repository root):

    steam_api.dll                  Win32            Delphi + FPC
    steam_api.lib                  (C++ import library, not used)
    win64/steam_api64.dll          Win64            Delphi + FPC
    win64/steam_api64.lib          (C++ import library, not used)
    osx/libsteam_api.dylib         macOS x86_64 + arm64   Delphi + FPC
    linux64/libsteam_api.so        Linux x86_64     Delphi + FPC
    linux32/libsteam_api.so        Linux i386       FPC only (may be dropped)
    linuxarm64/libsteam_api.so     Linux aarch64    FPC only
    androidarm64/libsteam_api.so   Android aarch64  Delphi (Android64) + FPC

A missing linux32 library is only a warning. For each library the script checks that it exists, that the
binary really is for that platform/CPU (not just named like it), and which
SDK generation it comes from, using exports:

    SteamAPI_InitFlat                                present since SDK 1.59
    SteamAPI_ISteamUtils_IsRunningOnSteamHardware    added in SDK 1.65
    SteamAPI_ISteamUtils_IsRunningOnSteamDeck        removed in SDK 1.65

It also spots common mistakes: the folder copied one level too deep, the
whole SDK copied instead of redistributable_bin, Win32/Win64 swapped.

Exit code: 0 = all required libraries OK, 1 = problems found.
Output says exactly what was found, so it can be pasted back as evidence.
"""

import os
import struct
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# (label, relative path, expected binary kind, missing-is-error)
EXPECTED = [
    ("Win32",      "steam_api.dll",                "pe-i386",                True),
    ("Win64",      "win64/steam_api64.dll",        "pe-amd64",               True),
    ("macOS",      "osx/libsteam_api.dylib",       "macho-x86_64+arm64",     True),
    ("Linux64",    "linux64/libsteam_api.so",      "elf64-x86_64",           True),
    ("Linux32",    "linux32/libsteam_api.so",      "elf32-i386",             False),
    ("LinuxARM64", "linuxarm64/libsteam_api.so",   "elf64-aarch64-linux",    True),
    ("Android64",  "androidarm64/libsteam_api.so", "elf64-aarch64-android",  True),
]

MARK_FLAT = b"SteamAPI_InitFlat\x00"
MARK_165_ADDED = b"SteamAPI_ISteamUtils_IsRunningOnSteamHardware\x00"
MARK_165_REMOVED = b"SteamAPI_ISteamUtils_IsRunningOnSteamDeck\x00"


def describe_binary(data):
    """Returns a short kind string such as 'pe-amd64', 'elf-x86_64',
    'macho-x86_64+arm64', or 'unknown (...)'."""
    if data[:2] == b"MZ" and len(data) > 0x40:
        pe = struct.unpack_from("<I", data, 0x3C)[0]
        if data[pe:pe + 4] == b"PE\x00\x00":
            machine = struct.unpack_from("<H", data, pe + 4)[0]
            return {0x14C: "pe-i386", 0x8664: "pe-amd64", 0xAA64: "pe-arm64"}.get(
                machine, f"pe-machine-0x{machine:04x}")
        return "unknown (MZ header without PE signature)"
    if data[:4] == b"\x7fELF":
        cls = {1: "32", 2: "64"}.get(data[4], "?")
        machine = struct.unpack_from("<H", data, 18)[0]
        name = {3: "i386", 62: "x86_64", 183: "aarch64", 40: "arm"}.get(machine, f"machine-{machine}")
        kind = f"elf{cls}-{name}"
        if name == "aarch64":
            # Same CPU for Linux and Android: tell them apart by the C library
            if b".note.android.ident" in data or b"liblog.so" in data:
                kind += "-android"
            elif b"GLIBC_" in data or b"libc.so.6" in data:
                kind += "-linux"
        return kind
    cpu_names = {0x01000007: "x86_64", 0x0100000C: "arm64", 7: "i386", 12: "arm"}
    if data[:4] == b"\xca\xfe\xba\xbe":  # fat / universal (big endian)
        count = struct.unpack_from(">I", data, 4)[0]
        if count < 20:
            cpus = []
            for i in range(count):
                cpu = struct.unpack_from(">I", data, 8 + i * 20)[0]
                cpus.append(cpu_names.get(cpu, f"cpu-0x{cpu:x}"))
            return "macho-" + "+".join(sorted(cpus, key=lambda c: (c != "x86_64", c)))
    if data[:4] in (b"\xcf\xfa\xed\xfe", b"\xce\xfa\xed\xfe"):  # thin, little endian
        cpu = struct.unpack_from("<I", data, 4)[0]
        return "macho-" + cpu_names.get(cpu, f"cpu-0x{cpu:x}")
    return "unknown (not a PE, ELF or Mach-O file)"


def sdk_generation(data):
    if MARK_165_ADDED in data and MARK_165_REMOVED not in data:
        return "1.65 or newer", True
    if MARK_FLAT in data:
        return "1.59 - 1.64 (older than 1.65)", False
    return "older than 1.59", False


def find_misplaced(base):
    """Looks for the usual copy mistakes and returns hints."""
    hints = []
    nested = os.path.join(base, "redistributable_bin")
    if os.path.isdir(nested):
        hints.append(f"found {os.path.relpath(nested, ROOT)} - the folder was copied one level "
                     "too deep; move its contents up into redistributable_bin/")
    for sdk_dir in (os.path.join(base, "sdk"), os.path.join(ROOT, "sdk")):
        if os.path.isdir(os.path.join(sdk_dir, "redistributable_bin")):
            hints.append(f"found {os.path.relpath(sdk_dir, ROOT)}/redistributable_bin - copy only "
                         "sdk/redistributable_bin, not the whole SDK")
    return hints


def main():
    base = os.path.abspath(sys.argv[1]) if len(sys.argv) > 1 else os.path.join(ROOT, "redistributable_bin")
    print(f"Checking {base}")
    if not os.path.isdir(base):
        print("  ERROR: folder does not exist - copy sdk/redistributable_bin from "
              "steamworks_sdk_165.zip into the repository root")
        return 1

    problems = 0
    found_kinds = {}
    for label, rel, want, required in EXPECTED:
        path = os.path.join(base, *rel.split("/"))
        if not os.path.isfile(path):
            if required:
                print(f"  ERROR   {label:10} {rel}: missing")
                problems += 1
            else:
                print(f"  WARNING {label:10} {rel}: missing (optional)")
            continue
        with open(path, "rb") as fh:
            data = fh.read()
        kind = describe_binary(data)
        found_kinds[rel] = kind
        gen, is_165 = sdk_generation(data)
        size_kb = len(data) // 1024
        if want == "macho-x86_64+arm64" and kind == "macho-x86_64" and is_165:
            print(f"  WARNING {label:10} {rel}: {kind} only, {size_kb} KB, SDK {gen} - "
                  "Intel Macs OK, OSXARM64 builds will not load it")
        elif kind == "elf64-aarch64" and want.startswith("elf64-aarch64") and is_165:
            print(f"  WARNING {label:10} {rel}: aarch64, {size_kb} KB, SDK {gen} - could not tell "
                  "whether it is the Linux or the Android build; make sure it came from "
                  f"{rel.split('/')[0]}/")
        elif kind != want:
            print(f"  ERROR   {label:10} {rel}: binary is {kind}, expected {want} ({size_kb} KB)")
            problems += 1
        elif not is_165:
            print(f"  ERROR   {label:10} {rel}: {kind}, {size_kb} KB, SDK {gen} - this repository targets 1.65")
            problems += 1
        else:
            print(f"  OK      {label:10} {rel}: {kind}, {size_kb} KB, SDK {gen}")

    # Win32 / Win64 swapped?
    if (found_kinds.get("steam_api.dll") == "pe-amd64" and
            found_kinds.get("win64/steam_api64.dll") == "pe-i386"):
        print("  HINT    steam_api.dll and win64/steam_api64.dll look swapped")

    if (found_kinds.get("linuxarm64/libsteam_api.so") == "elf64-aarch64-android" and
            found_kinds.get("androidarm64/libsteam_api.so") == "elf64-aarch64-linux"):
        print("  HINT    linuxarm64/ and androidarm64/ libraries look swapped")

    for hint in find_misplaced(base):
        print(f"  HINT    {hint}")
        problems += 1

    print("Result: " + ("all required redistributables OK" if problems == 0
                        else f"{problems} problem(s)"))
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
