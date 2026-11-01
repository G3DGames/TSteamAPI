# TSteamAPI documentation

| Document | For |
|----------|-----|
| [Install-Delphi.md](Install-Delphi.md) | Installing and using the library with Delphi (FMX, VCL): packages, paths, getting the Steam DLL next to the executable, and everything that looks wrong but is not |
| [Install-Lazarus-FPC.md](Install-Lazarus-FPC.md) | Using it with Free Pascal 3.2.2 / Lazarus: paths, **copying the Steam library by hand**, `cthreads`, differences from Delphi |
| [GameEngineIntegration.md](GameEngineIntegration.md) | How callbacks are pumped - timer, worker thread or your own loop - and recipes for FMX, VCL, LCL, Castle Game Engine, Gorilla3D, Skia4Delphi, PasVulkan and custom loops |
| [SteamInputMapping.md](SteamInputMapping.md) | Steam Input: the action manifest, shipping default layouts per controller type, development vs shipping, origins to physical buttons, which pad picture / model for which controller, troubleshooting |
| [components/](components/README.md) | One page per component / plug-in: every property, method, event and payload record |
| [fmx-menu-bug-fix.md](fmx-menu-bug-fix.md) | FMX main menu on Linux shows only first letters: replacing it with an FMX menu bar (short, with code) |
| [fmx-steamos-gtk3-bug-fix.md](fmx-steamos-gtk3-bug-fix.md) | Getting an FMX game to start in Steam's Linux runtime: use Runtime 3.0, and make GTK 3 globally visible (short, with code) |
| [fmx-steamos-gtk3-bug.md](fmx-steamos-gtk3-bug.md) | Bug report for Embarcadero: FMX on Linux crashes inside Steam Linux Runtime 3.0 when a TListBox is created (GTK functions looked up in the global scope); FMX cannot run in Runtime 4.0 (no GTK 3) |
| [ComponentIcons.md](ComponentIcons.md) | Brief for the palette icons: every current and planned component, format and sizes |
| [../README.md](../README.md) | Project overview, design notes, Steam's quirks ("Known issues") |

The API reference in HTML / CHM form is generated from the sources' PasDoc
comments.
