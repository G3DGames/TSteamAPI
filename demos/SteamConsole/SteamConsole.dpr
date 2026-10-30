program SteamConsole;

{ Console smoke test for the Steamworks core (no UI framework).
  The redistributable for the target platform is copied from
  ..\..\redistributable_bin (copied there from the Steamworks SDK)
  next to the executable by the post-build event. }

{$APPTYPE CONSOLE}

uses
  SysUtils,
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
