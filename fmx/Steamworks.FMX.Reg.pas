{ @abstract(Design-time registration of the Steamworks FMX components.)

  Compiled only into the design-time package dclSteamworksFMX, which puts
  @code(TSteamAPI) (FireMonkey) on the "Steamworks" page of the tool palette. }
unit Steamworks.FMX.Reg;

{$I Steamworks.inc}

interface

{ Registers the FMX TSteamAPI on the "Steamworks" palette page. The plug-in
  components (TSteamFriends, ...) are framework-independent and registered by
  dclSteamworks (design/Steamworks.Reg.pas). }
procedure Register;

implementation

uses
  Classes, DesignIntf, DesignEditors, FMX.Types, Steamworks.FMX;

type
  // Adds the units the IDE-generated TSteamAPI event handlers need
  // (TSteamLogLevel, TSteamCallbackData, ...) to the form's uses clause.
  TSteamAPISelectionEditor = class(TSelectionEditor)
  public
    procedure RequiresUnits(Proc: TGetStrProc); override;
  end;

procedure TSteamAPISelectionEditor.RequiresUnits(Proc: TGetStrProc);
begin
  Proc('Steamworks.Types');
  Proc('Steamworks.Callbacks');
  Proc('Steamworks.Core');
  Proc('Steamworks.Components');
end;

procedure Register;
begin
  // FMX class group: lets the VCL TSteamAPI (same name) be installed as well,
  // as with FMX / VCL TButton.
  GroupDescendentsWith(TSteamAPI, TFmxObject);
  RegisterComponents('Steamworks', [TSteamAPI]);
  RegisterSelectionEditor(TSteamAPI, TSteamAPISelectionEditor);
end;

end.
