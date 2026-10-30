{ @abstract(Design-time registration of the VCL TSteamAPI.)

  Compiled only into dclSteamworksVCL. The plug-in components (TSteamFriends,
  ...) are framework-independent and registered by dclSteamworks. }
unit Steamworks.VCL.Reg;

{$I Steamworks.inc}

interface

{ Registers the VCL TSteamAPI on the "Steamworks" palette page. }
procedure Register;

implementation

uses
  System.Classes, Vcl.Controls, DesignIntf, DesignEditors, Steamworks.VCL;

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
  // VCL class group: the FMX TSteamAPI (same name) can be installed as well
  GroupDescendentsWith(TSteamAPI, Vcl.Controls.TControl);
  RegisterComponents('Steamworks', [TSteamAPI]);
  RegisterSelectionEditor(TSteamAPI, TSteamAPISelectionEditor);
end;

end.
