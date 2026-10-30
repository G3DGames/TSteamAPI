
program SteamDemoLCL;

{ Lazarus / LCL demo for the Steamworks library (AppID 2275430). The form,
  shared with the VCL demo, is ../shared/uSteamDemoDesktop.pas; this demo
  compiles the library from source (lib, lib/plugins, lcl - see the .lpi).
  Copy the Steam library for the target platform from
  ../../redistributable_bin next to the executable (x86_64-win64/ etc.). }

{$mode delphi}{$H+}

uses
  {$IFDEF UNIX}
  cthreads,   // Steam calls the warning hook from its own threads
  {$ENDIF}
  Interfaces, Forms, uSteamDemoDesktop;

{$R *.res}  // Lazarus builds it from the .lpi: XP manifest, DPI awareness

begin
  Application.Scaled := True;
  Application.Initialize;
  Application.CreateForm(TfrmSteamDemo, frmSteamDemo);
  Application.Run;
end.
