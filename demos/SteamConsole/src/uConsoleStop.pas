{ @abstract(Stop requests for SteamConsole: Enter, Ctrl+C and the operating
  system's stop signals - Delphi and FPC, Windows and POSIX.)

  @link(StartStopWatch) installs:
  @unorderedList(
    @item(Windows: a console control handler for Ctrl+C, Ctrl+Break, closing
      the console window, log-off and shut-down. Closing the window gives a
      program about 5 s: the handler waits (up to @link(STOP_CLOSE_WAIT_MS))
      until the program calls @link(StopWatchDone), so Steam is shut down
      before Windows ends the process.)
    @item(Linux / macOS / Android: handlers for SIGINT (Ctrl+C), SIGTERM
      (kill, systemd, a Steam stop) and SIGHUP (terminal closed). Each
      handler puts its signal back to the default action, so a SECOND
      Ctrl+C ends a program that hangs while shutting down.)
    @item(Optionally a thread that waits for a line on standard input
      (Enter). When the input is not a console (redirected from a file or
      /dev/null, a program started by Steam) it sees end of file at once
      and simply ends - only the signals remain.)
  )
  The handlers only record what happened (@link(StopRequested)); the
  program's loop polls it and shuts down in the normal way, on its own
  thread. }
unit uConsoleStop;

{$ifdef FPC}{$mode delphi}{$H+}{$endif}

interface

const
  { Windows: longest time the console control handler keeps a closing
    console window (or log-off / shut-down) waiting for
    @link(StopWatchDone). Windows ends the process about 5 s after the
    window is closed, whatever the handler does. }
  STOP_CLOSE_WAIT_MS = 4500;
  { Code of a stop requested by a line on standard input (Enter). }
  STOP_ENTER = -1;
  { Code of a stop requested by the program itself (@link(RequestStop)). }
  STOP_PROGRAM = -2;
  { Offset added to a Windows console control event (CTRL_C_EVENT = 0, ...)
    to form a stop code. }
  STOP_WINDOWS_EVENT = 1000;

{ Installs the stop handlers (see the unit description). With AWatchEnter
  a thread also waits for Enter on standard input. Call once. }
procedure StartStopWatch(AWatchEnter: Boolean);

{ Tells a waiting Windows close / log-off / shut-down handler that the
  program has shut Steam down and may now be ended. Call before the
  program returns. }
procedure StopWatchDone;

{ Records a stop request (the first one wins). ACode: a signal number,
  STOP_WINDOWS_EVENT + a console control event, @link(STOP_ENTER) or
  @link(STOP_PROGRAM). }
procedure RequestStop(ACode: Integer);

{ @true once a stop has been requested. }
function StopRequested: Boolean;

{ What requested the stop, for the log ('' when none did). }
function StopReasonText: string;

implementation

uses
  {$ifdef MSWINDOWS}
  Windows,
  {$endif}
  {$ifdef FPC}{$ifdef UNIX}
  BaseUnix,
  {$endif}{$endif}
  {$ifndef FPC}{$ifdef POSIX}
  Posix.Signal,
  {$endif}{$endif}
  SysUtils, Classes;

type
  { Waits for one line on standard input, then requests a stop. }
  TStdinWatcher = class(TThread)
  protected
    { Reads one line (or sees end of file and ends). }
    procedure Execute; override;
  end;

var
  { 0 = no stop requested; otherwise the code given to RequestStop. Written
    by signal / control handlers and the input thread, read by the loop. }
  GStopCode: Integer = 0;
  { Set by StopWatchDone: a waiting Windows close handler may return. }
  GDone: Boolean = False;
  { StartStopWatch ran. }
  GStarted: Boolean = False;

procedure RequestStop(ACode: Integer);
begin
  if GStopCode = 0 then
    GStopCode := ACode;
end;

function StopRequested: Boolean;
begin
  Result := GStopCode <> 0;
end;

procedure StopWatchDone;
begin
  GDone := True;
end;

function StopReasonText: string;
var
  C: Integer;
begin
  C := GStopCode;
  if C = 0 then
    Result := ''
  else if C = STOP_ENTER then
    Result := 'Enter pressed'
  else if C = STOP_PROGRAM then
    Result := 'the program asked to stop'
  else if C >= STOP_WINDOWS_EVENT then
  begin
    case C - STOP_WINDOWS_EVENT of
      0: Result := 'Ctrl+C';
      1: Result := 'Ctrl+Break';
      2: Result := 'console window closed';
      5: Result := 'user logging off';
      6: Result := 'Windows shutting down';
    else
      Result := Format('console control event %d', [C - STOP_WINDOWS_EVENT]);
    end;
  end
  else
  begin
    // POSIX numbers, the same on Linux, macOS and Android
    case C of
      1: Result := Format('signal %d (SIGHUP: terminal closed)', [C]);
      2: Result := Format('signal %d (SIGINT: Ctrl+C)', [C]);
      15: Result := Format('signal %d (SIGTERM)', [C]);
    else
      Result := Format('signal %d', [C]);
    end;
  end;
end;

procedure TStdinWatcher.Execute;
var
  Line: string;
begin
  try
    // Eof waits for input on a console; redirected from a file or
    // /dev/null (no console) it is True at once and the thread just ends
    if Eof(Input) then
      Exit;
    Readln(Line);
    RequestStop(STOP_ENTER);   // a Ctrl+C that aborted the read came first
  except
    // no usable standard input: only the signals / control events stop
  end;
end;

{$ifdef MSWINDOWS}
{ Windows console control handler (runs on a thread Windows creates). }
function ConsoleCtrl(ACtrlType: DWORD): LongBool; stdcall;
var
  Waited: Integer;
begin
  if (ACtrlType <= CTRL_BREAK_EVENT) and ((GStopCode = STOP_WINDOWS_EVENT + Integer(CTRL_C_EVENT)) or
    (GStopCode = STOP_WINDOWS_EVENT + Integer(CTRL_BREAK_EVENT))) then
  begin
    // SECOND Ctrl+C / Ctrl+Break (after Enter, the first one still stops
    // normally): not handled - Windows ends the process
    Result := False;
    Exit;
  end;
  RequestStop(STOP_WINDOWS_EVENT + Integer(ACtrlType));
  Result := True;
  // (no "in [...]": a DWORD is too wide for a set)
  if (ACtrlType = CTRL_CLOSE_EVENT) or (ACtrlType = CTRL_LOGOFF_EVENT) or (ACtrlType = CTRL_SHUTDOWN_EVENT) then
  begin
    // Windows ends the process when this returns: give the loop time to
    // shut Steam down first
    Waited := 0;
    while (not GDone) and (Waited < STOP_CLOSE_WAIT_MS) do
    begin
      Sleep(50);
      Inc(Waited, 50);
    end;
  end;
end;
{$endif}

{$ifdef FPC}{$ifdef UNIX}
{ POSIX signal handler (FPC): records the signal and restores the default
  action, so the same signal again ends the program. }
procedure StopSignal(ASig: LongInt); cdecl;
begin
  RequestStop(ASig);
  fpSignal(ASig, nil);
end;
{$endif}{$endif}

{$ifndef FPC}{$ifdef POSIX}
{ POSIX signal handler (Delphi): records the signal and restores the
  default action, so the same signal again ends the program. }
procedure StopSignal(ASig: Integer); cdecl;
begin
  RequestStop(ASig);
  signal(ASig, nil);
end;
{$endif}{$endif}

procedure StartStopWatch(AWatchEnter: Boolean);
var
  W: TStdinWatcher;
begin
  if GStarted then
    Exit;
  GStarted := True;
  {$ifdef MSWINDOWS}
  SetConsoleCtrlHandler(@ConsoleCtrl, True);
  {$endif}
  {$ifdef FPC}{$ifdef UNIX}
  fpSignal(SIGINT, @StopSignal);
  fpSignal(SIGTERM, @StopSignal);
  fpSignal(SIGHUP, @StopSignal);
  {$endif}{$endif}
  {$ifndef FPC}{$ifdef POSIX}
  signal(SIGINT, @StopSignal);
  signal(SIGTERM, @StopSignal);
  signal(SIGHUP, @StopSignal);
  {$endif}{$endif}
  if AWatchEnter then
  begin
    // Never waited for: it may sit in Readln until the process ends
    W := TStdinWatcher.Create(True);
    W.FreeOnTerminate := True;
    W.Start;
  end;
end;

end.
