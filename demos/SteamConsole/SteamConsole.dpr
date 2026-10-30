program SteamConsole;

{ Console smoke test for the Steamworks core (no UI framework).
  The redistributable for the target platform is copied from
  ..\..\redistributable_bin (copied there from the Steamworks SDK)
  next to the executable by the post-build event. }

{$APPTYPE CONSOLE}

uses
  SysUtils,
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
  uConsoleMain in 'src\uConsoleMain.pas';

begin
  try
    ExitCode := RunConsoleDemo;
  except
    on E: Exception do
    begin
      Writeln(E.ClassName, ': ', E.Message);
      ExitCode := 2;
    end;
  end;
end.
