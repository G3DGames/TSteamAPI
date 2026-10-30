program SteamDemo;

{ FMX demo for the Steamworks library (AppID 2275430).
  The redistributable for the target platform is copied from
  ..\..\redistributable_bin (copied there from the Steamworks SDK)
  next to the executable by the post-build event
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
  Steamworks.SDKTypes in '..\..\lib\Steamworks.SDKTypes.pas',
  Steamworks.Core in '..\..\lib\Steamworks.Core.pas',
  Steamworks.Components in '..\..\lib\Steamworks.Components.pas',
  Steamworks.Plugin.Utils in '..\..\lib\plugins\Steamworks.Plugin.Utils.pas',
  Steamworks.Plugin.User in '..\..\lib\plugins\Steamworks.Plugin.User.pas',
  Steamworks.Plugin.Friends in '..\..\lib\plugins\Steamworks.Plugin.Friends.pas',
  Steamworks.Plugin.Apps in '..\..\lib\plugins\Steamworks.Plugin.Apps.pas',
  Steamworks.Plugin.UserStats in '..\..\lib\plugins\Steamworks.Plugin.UserStats.pas',
  Steamworks.FMX in '..\..\fmx\Steamworks.FMX.pas',
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
