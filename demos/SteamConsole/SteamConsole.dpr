program SteamConsole;

{ Console program for the Steamworks library (no UI framework): smoke test,
  the demos' component and pair tests, a dedicated game server - see
  src/uConsoleMain.pas and README.md (SteamConsole --help).
  The redistributable for the target platform is copied from
  ..\..\redistributable_bin (copied there from the Steamworks SDK)
  next to the executable by the post-build event.
  The Free Pascal twin of this file is SteamConsoleFPC.lpr (same units). }

{$APPTYPE CONSOLE}

uses
  {$ifdef FPC}{$ifdef UNIX}
  cthreads,   // FPC on Linux / macOS: needed for the worker thread (mode thread / main / worker)
  {$endif}{$endif}
  SysUtils,
  SteamComponentTest in '..\Shared\SteamComponentTest.pas',
  SteamPairTest in '..\Shared\SteamPairTest.pas',
  uConsoleStop in 'src\uConsoleStop.pas',
  uConsoleMain in 'src\uConsoleMain.pas';

begin
  try
    ExitCode := RunConsoleDemo;
  except
    on E: Exception do
    begin
      Writeln(E.ClassName, ': ', E.Message);
      ExitCode := EXIT_USAGE;
    end;
  end;
end.
