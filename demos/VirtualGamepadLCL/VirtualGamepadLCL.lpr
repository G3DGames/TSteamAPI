program VirtualGamepadLCL;

{ 3D gamepad visualiser for Lazarus / Free Pascal with Castle Game Engine
  (AppID 480). The form is src/uMain.pas / .lfm; the clips are played by
  src/PadAnimator.pas. Required Lazarus packages (see the .lpi):
  SteamworksLCL (packages/SteamworksLCL.lpk), castle_engine_base and
  castle_engine_lcl (Castle Game Engine), LCL. Copy the Steam library for
  the target platform from ../../redistributable_bin next to the
  executable (x86_64-win64/ etc.). }

{$mode delphi}{$H+}

uses
  {$IFDEF UNIX}
  cthreads,   // Steam calls the warning hook from its own threads
  {$ENDIF}
  Interfaces, Forms, uMain, PadAnimator;

{$R *.res}  // Lazarus builds it from the .lpi: XP manifest, DPI awareness

begin
  Application.Scaled := True;
  Application.Initialize;
  Application.CreateForm(TfrmGamepadLCL, frmGamepadLCL);
  Application.Run;
end.
