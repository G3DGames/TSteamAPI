program SteamInputDemo;

{ Steam Input test for the Steamworks library (AppID 2275430): live digital,
  analog and motion values of every connected controller, read through
  TSteamInput. The redistributable and src\steam_input_manifest.vdf are
  copied next to the executable by the post-build event (Windows) or
  deployed by the Deployment entries (macOS / Linux). }

uses
  System.StartUpCopy,
  FMX.Forms,
  uMain in 'src\uMain.pas' {frmInput};

begin
{$IFDEF DEBUG}
  // Debug builds list leaked blocks when the program ends (Windows only).
  ReportMemoryLeaksOnShutdown := True;
{$ENDIF}
  Application.Initialize;
  Application.CreateForm(TfrmInput, frmInput);
  Application.Run;
end.
