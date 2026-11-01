program SteamInputDemo;

{ Steam Input test for the Steamworks library (AppID 2275430): live digital,
  analog and motion values of every connected controller, read through
  TSteamInput. The redistributable and src\steam_input_manifest.vdf are
  copied next to the executable by the post-build event (Windows) or
  deployed by the Deployment entries (macOS / Linux). }

uses
  System.StartUpCopy,
  FMX.Forms,
  FmxLinuxGtkGlobal in 'src\FmxLinuxGtkGlobal.pas',
  FmxLinuxMenu in 'src\FmxLinuxMenu.pas',
  uMain in 'src\uMain.pas' {frmInput};

begin
{$IFDEF DEBUG}
  // Debug builds list leaked blocks when the program ends (Windows only).
  ReportMemoryLeaksOnShutdown := True;
{$ENDIF}
{$IFDEF POSIX}
  // Start-up markers on stderr (Linux / macOS only - a Windows GUI program
  // has no stderr): under Steam's Linux runtime the program died before
  // its form's OnCreate (owner's runs 2026-11-01), and stderr is what
  // Steam's launch options can capture (%command% > file 2>&1)
  WriteLn(ErrOutput, 'start-up: units initialised');
{$ENDIF}
  Application.Initialize;
{$IFDEF POSIX}
  WriteLn(ErrOutput, 'start-up: application initialised, creating the main form');
{$ENDIF}
  Application.CreateForm(TfrmInput, frmInput);
{$IFDEF POSIX}
  // FMX only QUEUES the form here; it is created inside Application.Run
  WriteLn(ErrOutput, 'start-up: Application.Run (FMX creates the queued forms now)');
{$ENDIF}
  Application.Run;
end.
