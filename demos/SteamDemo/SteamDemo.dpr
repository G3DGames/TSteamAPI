program SteamDemo;

{ FMX demo for the Steamworks library (AppID 2275430).
  The redistributable for the target platform is copied from
  ..\..\redistributable_bin (copied there from the Steamworks SDK)
  next to the executable by the post-build event
  (Windows) or deployed by the Deployment entries (macOS / Linux). }

uses
  System.StartUpCopy,
  FMX.Forms,
  // GTK 3 in the global symbol scope before the first form: without it FMX
  // crashes in Steam's Linux runtime 3.0 when a TListBox is created
  // (docs/fmx-steamos-gtk3-bug.md); compiles to nothing off Linux
  FmxLinuxGtkGlobal in 'src\FmxLinuxGtkGlobal.pas',
  uMain in 'src\uMain.pas' {frmMain};

begin
{$IFDEF DEBUG}
  // Debug builds list leaked blocks when the program ends. Effective with
  // Delphi's default memory manager on Windows; on Linux / macOS / Android
  // the RTL uses the platform allocator and this setting has no effect.
  ReportMemoryLeaksOnShutdown := True;
{$ENDIF}
{$IFDEF POSIX}
  // Start-up markers on stderr (Linux / macOS only): under Steam's Linux
  // runtime a crash before the form's OnCreate leaves no log, and stderr
  // is what Steam's launch options can capture (%command% > file 2>&1)
  WriteLn(ErrOutput, 'start-up: units initialised');
{$ENDIF}
  Application.Initialize;
{$IFDEF POSIX}
  WriteLn(ErrOutput, 'start-up: application initialised, creating the main form');
{$ENDIF}
  Application.CreateForm(TfrmMain, frmMain);
{$IFDEF POSIX}
  // FMX only QUEUES the form here; it is created inside Application.Run
  WriteLn(ErrOutput, 'start-up: Application.Run (FMX creates the queued forms now)');
{$ENDIF}
  Application.Run;
end.
