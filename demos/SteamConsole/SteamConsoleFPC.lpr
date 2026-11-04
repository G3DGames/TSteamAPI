program SteamConsoleFPC;

{ Free Pascal / Lazarus twin of SteamConsole.dpr: the same units, built by
  plain FPC 3.2.2 - no LCL, no package (SteamConsoleFPC.lpi compiles the
  library from ../../lib and ../../lib/plugins). Open the .lpi in Lazarus
  and Run > Build, or from a terminal: lazbuild SteamConsoleFPC.lpi
  The executable goes to <cpu>-<os>/ (e.g. x86_64-win64/); copy the Steam
  library for that platform from ../../redistributable_bin next to it.
  What it does: src/uConsoleMain.pas and README.md (SteamConsoleFPC --help). }

{$mode delphi}{$H+}

uses
  {$IFDEF UNIX}
  cthreads,   // first: the worker thread (modes thread / main), the tests, the Enter watcher
  {$ENDIF}
  SysUtils, SteamComponentTest, SteamPairTest, uConsoleStop, uConsoleMain;

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
