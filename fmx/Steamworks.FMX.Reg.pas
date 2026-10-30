{ @abstract(Design-time registration of the Steamworks FMX components.)

  Compiled only into the design-time package dclSteamworksFMX, which puts
  @code(TSteamworksFMX) on the "Steamworks" page of the tool palette. }
unit Steamworks.FMX.Reg;

{$I Steamworks.inc}

interface

{ Registers the components on the "Steamworks" palette page. }
procedure Register;

implementation

uses
  Classes, Steamworks.FMX;

procedure Register;
begin
  RegisterComponents('Steamworks', [TSteamworksFMX]);
end;

end.
