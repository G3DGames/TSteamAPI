{ @abstract(Linux only: makes GTK 3 visible to FMX's global symbol
  lookups - workaround for a crash inside Steam's Linux runtime.)

  FMX on Linux looks some GTK functions up in the program's GLOBAL symbol
  scope (gtk_event_controller_set_propagation_phase and
  gtk_event_controller_handle_event, when a TListBox is created) and calls
  the result without checking it. Inside Steam Linux Runtime 3.0 (sniper)
  libgtk-3 is loaded but not in that scope, so the lookup returns nil and
  the program dies with "Access violation at address 0" (owner's
  LD_DEBUG=symbols trace, 2026-11-01; a blank form ran, the same form with
  a TListBox did not).

  Using this unit, the program asks the dynamic loader for libgtk-3.so.0
  and libgdk-3.so.0 with RTLD_GLOBAL at start-up: a library already loaded
  privately becomes globally visible, one not yet loaded is loaded so. On
  a normal desktop this changes nothing. The result is written to stderr.
  On every other platform the unit is empty.

  PROVEN: with it SteamInputDemo starts in Steam Linux Runtime 3.0 (owner,
  2026-11-01). Reported to Embarcadero (docs/fmx-steamos-gtk3-bug.md);
  remove this unit once FMX checks those lookups or finds them in GTK
  itself. Four identical copies (demos/SteamInputDemo/src,
  demos/VirtualGamepad/src, demos/SteamDemo/src,
  RemoteLogging/LogReceiver/src - projects use only their own sources);
  tools/project_check.py reports any difference. }
unit FmxLinuxGtkGlobal;

interface

implementation

{$IFDEF LINUX}
uses
  System.SysUtils, Posix.Dlfcn;

{ Opens ALibrary with RTLD_GLOBAL and writes the outcome to stderr.
  @param(ALibrary The library's file name (soname).) }
procedure MakeGlobal(const ALibrary: string);
var
  Handle: NativeUInt;
  Err: MarshaledAString;
begin
  Handle := dlopen(MarshaledAString(UTF8String(ALibrary)), RTLD_LAZY or RTLD_GLOBAL);
  if Handle <> 0 then
    WriteLn(ErrOutput, 'start-up: ' + ALibrary + ' made globally visible (FMX GTK lookups)')
  else
  begin
    Err := dlerror;
    if Err <> nil then
      WriteLn(ErrOutput, 'start-up: ' + ALibrary + ' NOT opened: ' + UTF8ToString(Err))
    else
      WriteLn(ErrOutput, 'start-up: ' + ALibrary + ' NOT opened');
  end;
  Flush(ErrOutput);
end;

initialization
  MakeGlobal('libgtk-3.so.0');
  MakeGlobal('libgdk-3.so.0');
{$ENDIF}
end.
