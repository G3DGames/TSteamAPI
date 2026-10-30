program SteamDemo;

{ FMX demo for the Steamworks library (AppID 2275430).
  The redistributable for the target platform is copied from
  ..\..\redistributable_bin (copied there from the Steamworks SDK)
  next to the executable by the post-build event
  (Windows) or deployed by the Deployment entries (macOS / Linux). }

uses
  System.StartUpCopy,
  FMX.Forms,
  uMain in 'src\uMain.pas' {frmMain};

begin
{$IFDEF DEBUG}
  // Debug builds list leaked blocks when the program ends. Effective with
  // Delphi's default memory manager on Windows; on Linux / macOS / Android
  // the RTL uses the platform allocator and this setting has no effect.
  ReportMemoryLeaksOnShutdown := True;
{$ENDIF}
  Application.Initialize;
  Application.CreateForm(TfrmMain, frmMain);
  Application.Run;
end.
