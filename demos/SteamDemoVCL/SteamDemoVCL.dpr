program SteamDemoVCL;

{ VCL demo for the Steamworks library (AppID 2275430). The form, with the
  Steam components dropped on it, is src\uMain.pas / .dfm. Like every demo it
  links the library from the runtime packages' DCUs (build Steamworks and
  SteamworksVCL first); the post-build event copies the Steam library from
  ..\..\redistributable_bin next to the executable. }

uses
  Vcl.Forms,
  uMain in 'src\uMain.pas' {frmSteamDemo};

{$R *.res}

begin
{$IFDEF DEBUG}
  // Debug builds list leaked blocks when the program ends (Windows memory manager)
  ReportMemoryLeaksOnShutdown := True;
{$ENDIF}
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.CreateForm(TfrmSteamDemo, frmSteamDemo);
  Application.Run;
end.
