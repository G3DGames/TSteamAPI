program SteamDemo;

{ FMX demo for the Steamworks library (AppID 2275430).
  The redistributable for the target platform is copied from
  ..\..\dlls\<Platform> next to the executable by the post-build event
  (Windows) or deployed by the Deployment entries (macOS / Linux). }

uses
  System.StartUpCopy,
  FMX.Forms,
  Steamworks.Types in '..\..\lib\Steamworks.Types.pas',
  Steamworks.DynLib in '..\..\lib\Steamworks.DynLib.pas',
  Steamworks.Versions in '..\..\lib\Steamworks.Versions.pas',
  Steamworks.API in '..\..\lib\Steamworks.API.pas',
  Steamworks.Callbacks in '..\..\lib\Steamworks.Callbacks.pas',
  Steamworks.SteamClient in '..\..\lib\Steamworks.SteamClient.pas',
  Steamworks.Core in '..\..\lib\Steamworks.Core.pas',
  Steamworks.Plugin.Utils in '..\..\lib\plugins\Steamworks.Plugin.Utils.pas',
  Steamworks.FMX in '..\..\fmx\Steamworks.FMX.pas',
  uMain in 'src\uMain.pas' {frmMain};

begin
  Application.Initialize;
  Application.CreateForm(TfrmMain, frmMain);
  Application.Run;
end.
