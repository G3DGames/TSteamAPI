{ @abstract(Main form of the 3D gamepad visualiser (FMX).)

  SKELETON (2026-10-31): only the form, so the project builds in the
  group. Planned (CLAUDE.md, "NEXT: the 3D pad visualiser"): TSteamAPI +
  TSteamInput on the form as in SteamInputDemo, a Gorilla3D viewport
  showing the model that matches the controller type, and each Steam
  Input action driving that model's animation clips. }
unit uMain;

interface

uses
  System.SysUtils, System.Classes, FMX.Types, FMX.Controls, FMX.Forms,
  FMX.StdCtrls, FMX.Controls.Presentation;

type
  { Main form: will hold the 3D view of the connected controller. }
  TfrmGamepad = class(TForm)
    { Placeholder text until the 3D view exists. }
    lblInfo: TLabel;
  end;

var
  { The application's main form. }
  frmGamepad: TfrmGamepad;

implementation

{$R *.fmx}

end.
