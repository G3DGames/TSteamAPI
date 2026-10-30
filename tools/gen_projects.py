#!/usr/bin/env python3
"""Generates the .dproj files (and the package .dpk files) from one
definition list, so the unit lists in .dpr/.dpk and .dproj always agree.

    python3 tools/gen_projects.py

Existing GUIDs are kept (read back from the current .dproj) so the IDE does
not see a "new" project after regeneration. Output .dproj files are UTF-8
with BOM, CRLF line endings, as the IDE writes them.
"""
import os, re, uuid

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

LIB = ["Steamworks.Types", "Steamworks.DynLib", "Steamworks.Versions", "Steamworks.API",
       "Steamworks.Callbacks", "Steamworks.SteamClient", "Steamworks.Core"]
PLUGINS = ["Steamworks.Plugin.Utils"]
# Delphi platforms with a Steam redistributable. Linux32 and LinuxARM64 are
# FPC-only (Delphi has no such targets); see README.
ALL_PLATFORMS = ["Win32", "Win64", "OSX64", "OSXARM64", "Linux64", "Android64"]
DESKTOP_PLATFORMS = ["Win32", "Win64", "OSX64", "OSXARM64", "Linux64"]

def lib_units(rel):   # rel = path from project dir to repo root
    return [(u, f"{rel}lib\\{u}.pas") for u in LIB]

PROJECTS = [
    dict(name="SteamDemo", dir="demos\\SteamDemo", kind="app", framework="FMX",
         platforms=ALL_PLATFORMS, default="Win64",
         units=lib_units("..\\..\\") +
               [(u, f"..\\..\\lib\\plugins\\{u}.pas") for u in PLUGINS] +
               [("Steamworks.FMX", "..\\..\\fmx\\Steamworks.FMX.pas")],
         forms=[("uMain", "src\\uMain.pas", "frmMain")],
         search="..\\..\\lib;..\\..\\lib\\plugins;..\\..\\fmx;src", redist=True),
    dict(name="SteamConsole", dir="demos\\SteamConsole", kind="console", framework="None",
         platforms=DESKTOP_PLATFORMS, default="Win64",
         units=lib_units("..\\..\\") +
               [(u, f"..\\..\\lib\\plugins\\{u}.pas") for u in PLUGINS] +
               [("uConsoleMain", "src\\uConsoleMain.pas")],
         forms=[], search="..\\..\\lib;..\\..\\lib\\plugins;src", redist=True),
    dict(name="SteamworksFMX", dir="packages", kind="runtime", framework="FMX",
         platforms=ALL_PLATFORMS, default="Win64",
         units=lib_units("..\\") + [("Steamworks.FMX", "..\\fmx\\Steamworks.FMX.pas")],
         forms=[], search="..\\lib;..\\fmx", requires=["rtl", "fmx"],
         description="Steamworks SDK 1.65 for FireMonkey - runtime"),
    dict(name="dclSteamworksFMX", dir="packages", kind="design", framework="FMX",
         platforms=["Win32", "Win64"], default="Win32",
         units=[("Steamworks.FMX.Reg", "..\\fmx\\Steamworks.FMX.Reg.pas")],
         forms=[], search="..\\lib;..\\fmx", requires=["rtl", "fmx", "designide", "SteamworksFMX"],
         description="Steamworks SDK 1.65 for FireMonkey - design time",
         depends=["SteamworksFMX"]),
]

NS_BASE = "System;Xml;Data;Datasnap;Web;Soap"
NS_PLAT = {
    "Win32": "Winapi;System.Win;Data.Win;Datasnap.Win;Web.Win;Soap.Win;Xml.Win",
    "Win64": "Winapi;System.Win;Data.Win;Datasnap.Win;Web.Win;Soap.Win;Xml.Win",
    "OSX64": "Macapi;Posix", "OSXARM64": "Macapi;Posix", "Linux64": "Posix",
    "Android64": "Androidapi;Posix",
}
# File name of the Steam redistributable per platform, and where it lives in
# redistributable_bin/ (copied by the user from the Steamworks SDK).
DLL = {"Win32": "steam_api.dll", "Win64": "steam_api64.dll", "OSX64": "libsteam_api.dylib",
       "OSXARM64": "libsteam_api.dylib", "Linux64": "libsteam_api.so", "Android64": "libsteam_api.so"}
REDIST = {"Win32": "", "Win64": "win64\\", "OSX64": "osx\\", "OSXARM64": "osx\\", "Linux64": "linux64\\",
          "Android64": "androidarm64\\"}
# Where the library goes inside the deployed application
REMOTE_DIR = {"OSX64": "Contents\\MacOS\\", "OSXARM64": "Contents\\MacOS\\", "Linux64": ".\\",
              "Android64": "library\\lib\\arm64-v8a\\"}


def existing_guid(path):
    if os.path.exists(path):
        m = re.search(r"<ProjectGuid>(\{[0-9A-Fa-f-]+\})</ProjectGuid>", open(path, encoding="utf-8-sig").read())
        if m:
            return m.group(1)
    return "{" + str(uuid.uuid4()).upper() + "}"


def dproj(p):
    path = os.path.join(ROOT, *p["dir"].split("\\"), p["name"] + ".dproj")
    guid = existing_guid(path)
    is_pkg = p["kind"] in ("runtime", "design")
    main = p["name"] + (".dpk" if is_pkg else ".dpr")
    apptype = "Package" if is_pkg else ("Console" if p["kind"] == "console" else "Application")
    L = []
    a = L.append
    a('<Project xmlns="http://schemas.microsoft.com/developer/msbuild/2003">')
    a('    <PropertyGroup>')
    a(f'        <ProjectGuid>{guid}</ProjectGuid>')
    a('        <ProjectVersion>20.3</ProjectVersion>')
    a(f'        <FrameworkType>{p["framework"]}</FrameworkType>')
    a(f'        <AppType>{apptype}</AppType>')
    a(f'        <MainSource>{main}</MainSource>')
    a('        <Base>True</Base>')
    a("        <Config Condition=\"'$(Config)'==''\">Debug</Config>")
    a(f"        <Platform Condition=\"'$(Platform)'==''\">{p['default']}</Platform>")
    a(f"        <ProjectName Condition=\"'$(ProjectName)'==''\">{p['name']}</ProjectName>")
    a('    </PropertyGroup>')
    a("    <PropertyGroup Condition=\"'$(Config)'=='Base' or '$(Base)'!=''\">")
    a('        <Base>true</Base>')
    a('    </PropertyGroup>')
    for pl in p["platforms"]:
        a(f"    <PropertyGroup Condition=\"('$(Platform)'=='{pl}' and '$(Base)'=='true') or '$(Base_{pl})'!=''\">")
        a(f'        <Base_{pl}>true</Base_{pl}>')
        a('        <CfgParent>Base</CfgParent>')
        a('        <Base>true</Base>')
        a('    </PropertyGroup>')
    for key, cfg in (("Cfg_1", "Debug"), ("Cfg_2", "Release")):
        a(f"    <PropertyGroup Condition=\"'$(Config)'=='{cfg}' or '$({key})'!=''\">")
        a(f'        <{key}>true</{key}>')
        a('        <CfgParent>Base</CfgParent>')
        a('        <Base>true</Base>')
        a('    </PropertyGroup>')
    a("    <PropertyGroup Condition=\"'$(Base)'!=''\">")
    a(f'        <SanitizedProjectName>{p["name"].replace(".", "_")}</SanitizedProjectName>')
    a(f'        <DCC_Namespace>{NS_BASE};$(DCC_Namespace)</DCC_Namespace>')
    a(f'        <DCC_UnitSearchPath>{p["search"]};$(DCC_UnitSearchPath)</DCC_UnitSearchPath>')
    a(f'        <DCC_IncludePath>{p["search"]};$(DCC_IncludePath)</DCC_IncludePath>')
    a('        <DCC_DcuOutput>.\\$(Platform)\\$(Config)\\dcu</DCC_DcuOutput>')
    if is_pkg:
        # No DCC_BplOutput / DCC_DcpOutput: Delphi's defaults ($(BDSCOMMONDIR)\\Bpl and
        # \\Dcp per platform) are on the IDE's PATH and library path, so the design
        # package finds SteamworksFMX.dcp and the IDE can load SteamworksFMX.bpl.
        a('        <GenDll>true</GenDll>')
        a('        <GenPackage>true</GenPackage>')
        a(f'        <DCC_Description>{p["description"]}</DCC_Description>')
        if p["kind"] == "runtime":
            a('        <RuntimeOnlyPackage>true</RuntimeOnlyPackage>')
        else:
            a('        <DesignOnlyPackage>true</DesignOnlyPackage>')
    else:
        a('        <DCC_ExeOutput>.\\$(Platform)\\$(Config)</DCC_ExeOutput>')
    a('        <DCC_E>false</DCC_E>')
    a('        <DCC_N>false</DCC_N>')
    a('        <DCC_S>false</DCC_S>')
    a('        <DCC_F>false</DCC_F>')
    a('        <DCC_K>false</DCC_K>')
    a('    </PropertyGroup>')
    for pl in p["platforms"]:
        a(f"    <PropertyGroup Condition=\"'$(Base_{pl})'!=''\">")
        a(f'        <DCC_Namespace>{NS_PLAT[pl]};$(DCC_Namespace)</DCC_Namespace>')
        if p.get("redist") and pl.startswith("Win"):
            src = f"$(PROJECTDIR)\\..\\..\\redistributable_bin\\{REDIST[pl]}{DLL[pl]}"
            # Two plain lines: a parenthesised if/else breaks when a path contains ')'
            cmd = (f'echo Steamworks post-build: $(Platform) $(Config), copying {DLL[pl]} to $(OUTPUTDIR)\r\n'
                   f'if exist "{src}" copy /Y "{src}" "$(OUTPUTDIR)"\r\n'
                   f'if not exist "{src}" echo WARNING: {DLL[pl]} not found in redistributable_bin\\{REDIST[pl]} - '
                   f'copy redistributable_bin from the Steamworks SDK 1.65 into the repository root, '
                   f'then run tools\\check_redist.py')
            a('        <PostBuildEvent><![CDATA[' + cmd + ']]></PostBuildEvent>')
            a('        <PostBuildEventIgnoreExitCode>true</PostBuildEventIgnoreExitCode>')
        a('    </PropertyGroup>')
    a("    <PropertyGroup Condition=\"'$(Cfg_1)'!=''\">")
    a('        <DCC_Define>DEBUG;$(DCC_Define)</DCC_Define>')
    a('        <DCC_DebugDCUs>true</DCC_DebugDCUs>')
    a('        <DCC_Optimize>false</DCC_Optimize>')
    a('        <DCC_GenerateStackFrames>true</DCC_GenerateStackFrames>')
    a('        <DCC_DebugInfoInExe>true</DCC_DebugInfoInExe>')
    a('        <DCC_RemoteDebug>true</DCC_RemoteDebug>')
    a('    </PropertyGroup>')
    a("    <PropertyGroup Condition=\"'$(Cfg_2)'!=''\">")
    a('        <DCC_LocalDebugSymbols>false</DCC_LocalDebugSymbols>')
    a('        <DCC_Define>RELEASE;$(DCC_Define)</DCC_Define>')
    a('        <DCC_SymbolReferenceInfo>0</DCC_SymbolReferenceInfo>')
    a('        <DCC_DebugInformation>0</DCC_DebugInformation>')
    a('    </PropertyGroup>')
    a('    <ItemGroup>')
    a('        <DelphiCompile Include="$(MainSource)">')
    a('            <MainSource>MainSource</MainSource>')
    a('        </DelphiCompile>')
    for r in p.get("requires", []):
        a(f'        <DCCReference Include="{r}.dcp"/>')
    for u, f in p["units"]:
        a(f'        <DCCReference Include="{f}"/>')
    for u, f, form in p["forms"]:
        a(f'        <DCCReference Include="{f}">')
        a(f'            <Form>{form}</Form>')
        a('            <FormType>fmx</FormType>')
        a('        </DCCReference>')
    a('        <BuildConfiguration Include="Base">')
    a('            <Key>Base</Key>')
    a('        </BuildConfiguration>')
    a('        <BuildConfiguration Include="Debug">')
    a('            <Key>Cfg_1</Key>')
    a('            <CfgParent>Base</CfgParent>')
    a('        </BuildConfiguration>')
    a('        <BuildConfiguration Include="Release">')
    a('            <Key>Cfg_2</Key>')
    a('            <CfgParent>Base</CfgParent>')
    a('        </BuildConfiguration>')
    a('    </ItemGroup>')
    a('    <ProjectExtensions>')
    a('        <Borland.Personality>Delphi.Personality.12</Borland.Personality>')
    a(f'        <Borland.ProjectType>{"Package" if is_pkg else "Application"}</Borland.ProjectType>')
    a('        <BorlandProject>')
    a('            <Delphi.Personality>')
    a('                <Source>')
    a(f'                    <Source Name="MainSource">{main}</Source>')
    a('                </Source>')
    a('            </Delphi.Personality>')
    if p.get("redist"):
        a('            <Deployment Version="5">')
        for pl in ("OSX64", "OSXARM64", "Linux64", "Android64"):
            if pl not in p["platforms"]:
                continue
            remote = REMOTE_DIR[pl]
            for cfg in ("Debug", "Release"):
                a(f'                <DeployFile LocalName="..\\..\\redistributable_bin\\{REDIST[pl]}{DLL[pl]}" Configuration="{cfg}" Class="File">')
                a(f'                    <Platform Name="{pl}">')
                a(f'                        <RemoteDir>{remote}</RemoteDir>')
                a(f'                        <RemoteName>{DLL[pl]}</RemoteName>')
                a('                        <Overwrite>true</Overwrite>')
                a('                    </Platform>')
                a('                </DeployFile>')
        a('            </Deployment>')
    a('            <Platforms>')
    for pl in ALL_PLATFORMS:
        a(f'                <Platform value="{pl}">{"True" if pl in p["platforms"] else "False"}</Platform>')
    a('            </Platforms>')
    a('        </BorlandProject>')
    a('        <ProjectFileVersion>12</ProjectFileVersion>')
    a('    </ProjectExtensions>')
    a("    <Import Project=\"$(BDS)\\Bin\\CodeGear.Delphi.Targets\" Condition=\"Exists('$(BDS)\\Bin\\CodeGear.Delphi.Targets')\"/>")
    a("    <Import Project=\"$(APPDATA)\\Embarcadero\\$(BDSAPPDATABASEDIR)\\$(PRODUCTVERSION)\\UserTools.proj\" Condition=\"Exists('$(APPDATA)\\Embarcadero\\$(BDSAPPDATABASEDIR)\\$(PRODUCTVERSION)\\UserTools.proj')\"/>")
    a("    <Import Project=\"$(MSBuildProjectName).deployproj\" Condition=\"Exists('$(MSBuildProjectName).deployproj')\"/>")
    a('</Project>')
    with open(path, "wb") as fh:
        fh.write(b"\xef\xbb\xbf" + ("\r\n".join(L) + "\r\n").encode("utf-8"))
    return path


def dpk(p):
    path = os.path.join(ROOT, *p["dir"].split("\\"), p["name"] + ".dpk")
    L = [f"package {p['name']};", "",
         f"{{ {p['description']}. Generated by tools/gen_projects.py - edit the generator, not this file. }}", "",
         f"{{$DESCRIPTION '{p['description']}'}}",
         "{$RUNONLY}" if p["kind"] == "runtime" else "{$DESIGNONLY}",
         "{$IMPLICITBUILD ON}", "", "requires"]
    L += [f"  {r}{',' if i < len(p['requires']) - 1 else ';'}" for i, r in enumerate(p["requires"])]
    L += ["", "contains"]
    L += [f"  {u} in '{f}'{',' if i < len(p['units']) - 1 else ';'}" for i, (u, f) in enumerate(p["units"])]
    L += ["", "end."]
    with open(path, "w", newline="\r\n") as fh:
        fh.write("\n".join(L) + "\n")


def groupproj():
    path = os.path.join(ROOT, "Steamworks.groupproj")
    guid = existing_guid(path)
    L = ['<Project xmlns="http://schemas.microsoft.com/developer/msbuild/2003">',
         '    <PropertyGroup>', f'        <ProjectGuid>{guid}</ProjectGuid>', '    </PropertyGroup>',
         '    <ItemGroup>']
    for p in PROJECTS:
        rel = f"{p['dir']}\\{p['name']}.dproj"
        deps = ";".join(f"{q['dir']}\\{q['name']}.dproj" for q in PROJECTS if q["name"] in p.get("depends", []))
        L += [f'        <Projects Include="{rel}">',
              f'            <Dependencies>{deps}</Dependencies>' if deps else '            <Dependencies/>',
              '        </Projects>']
    L += ['    </ItemGroup>', '    <ProjectExtensions>',
          '        <Borland.Personality>Default.Personality.12</Borland.Personality>',
          '        <Borland.ProjectType/>', '        <BorlandProject>',
          '            <Default.Personality/>', '        </BorlandProject>', '    </ProjectExtensions>']
    for p in PROJECTS:
        rel = f"{p['dir']}\\{p['name']}.dproj"
        n = p["name"]
        L += [f'    <Target Name="{n}">', f'        <MSBuild Projects="{rel}"/>', '    </Target>',
              f'    <Target Name="{n}:Clean">', f'        <MSBuild Projects="{rel}" Targets="Clean"/>', '    </Target>',
              f'    <Target Name="{n}:Make">', f'        <MSBuild Projects="{rel}" Targets="Make"/>', '    </Target>']
    names = [p["name"] for p in PROJECTS]
    for t, suf in (("Build", ""), ("Clean", ":Clean"), ("Make", ":Make")):
        L += [f'    <Target Name="{t}">', f'        <CallTarget Targets="{";".join(n + suf for n in names)}"/>', '    </Target>']
    L += ["    <Import Project=\"$(BDS)\\Bin\\CodeGear.Group.Targets\" Condition=\"Exists('$(BDS)\\Bin\\CodeGear.Group.Targets')\"/>",
          '</Project>']
    with open(path, "wb") as fh:
        fh.write(b"\xef\xbb\xbf" + ("\r\n".join(L) + "\r\n").encode("utf-8"))


if __name__ == "__main__":
    for p in PROJECTS:
        print("wrote", os.path.relpath(dproj(p), ROOT))
        if p["kind"] in ("runtime", "design"):
            dpk(p)
            print("wrote", p["dir"] + "\\" + p["name"] + ".dpk")
    groupproj()
    print("wrote Steamworks.groupproj")
