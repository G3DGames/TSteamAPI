program SteamDemoPad;

{ The Big Picture / Steam Deck variant of SteamDemo (FMX, AppID 2275430):
  driven by the game pad through Steam Input, its screen drawn by the
  program (src/uMain.pas). The redistributable and the program's own
  Steam Input manifest + layouts are copied next to the executable by the
  post-build event (Windows) or deployed (macOS / Linux). }

uses
  System.StartUpCopy,
  FMX.Forms,
  // Project > Enable Skia (owner 2026-11-04: "a good test case"); the IDE's
  // "GlobalUseSkia := True;" line is NOT kept - FmxSkiaCanvas decides
  FMX.Skia,
  // GTK 3 in the global symbol scope before the first form: FMX crashed in
  // Steam's Linux runtime 3.0 without it (docs/fmx-steamos-gtk3-bug.md);
  // compiles to nothing off Linux
  FmxLinuxGtkGlobal in 'src\FmxLinuxGtkGlobal.pas',
  // Windows build under Wine / Proton: FMX draws with GDI+, because Wine's
  // Direct2D leaves FMX windows white; a no-op on Windows and elsewhere
  FmxWineCanvas in 'src\FmxWineCanvas.pas',
  // ... and Skia's raster / Vulkan canvas when TSAPI_FMX_CANVAS asks for it
  // (same file as VirtualGamepad's; a no-op off Wine)
  FmxSkiaCanvas in 'src\FmxSkiaCanvas.pas',
  // the component test and the two-user test, shared with the SteamDemos
  SteamComponentTest in '..\Shared\SteamComponentTest.pas',
  SteamPairTest in '..\Shared\SteamPairTest.pas',
  // optional: the log to a LogReceiver (RemoteLogging/README.md);
  // RemoteLog.Sender comes from ..\..\RemoteLogging\src on the search path
  DemoRemoteLog in '..\Shared\DemoRemoteLog.pas',
  uMain in 'src\uMain.pas' {frmPad};

// The project resource the IDE builds from the .dproj (git-ignored, rebuilt
// on every build): its MAINICON is SteamDemoPad.ico, the program's task bar
// icon (macOS: the .icns). Drawn by tools/gen_icons.py.
{$R *.res}

begin
{$IFDEF DEBUG}
  // Debug builds list leaked blocks when the program ends (Windows)
  ReportMemoryLeaksOnShutdown := True;
{$ENDIF}
{$IFDEF POSIX}
  // start-up markers on stderr: under Steam's Linux runtime a crash before
  // the form's OnCreate leaves no log, and stderr is what the launch
  // options can capture (%command% > file 2>&1)
  WriteLn(ErrOutput, 'start-up: units initialised');
{$ENDIF}
  Application.Initialize;
  Application.CreateForm(TfrmPad, frmPad);
{$IFDEF POSIX}
  WriteLn(ErrOutput, 'start-up: Application.Run (FMX creates the queued forms now)');
{$ENDIF}
  Application.Run;
end.
