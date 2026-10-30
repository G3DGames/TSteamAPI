unit BasicFormFMXMain;

interface

uses
  System.SysUtils, System.Types, System.UITypes, System.Classes, System.Variants,
  FMX.Types, FMX.Controls, FMX.Forms, FMX.Graphics, FMX.Dialogs, Steamworks.FMX,
  Steamworks.Types, Steamworks.Callbacks, Steamworks.Core,
  Steamworks.Components, Steamworks.SDKTypes, Steamworks.Plugin.Friends,
  FMX.Memo.Types, FMX.Controls.Presentation, FMX.ScrollBox, FMX.Memo;

type
  TForm1 = class(TForm)
    SteamAPI1: TSteamAPI;
    SteamFriends1: TSteamFriends;
    Memo1: TMemo;
    procedure SteamFriends1PersonaStateChange(Sender: TObject;
      const AData: PersonaStateChange_t);
    procedure FormCreate(Sender: TObject);
    procedure SteamAPI1InitFailed(Sender: TObject; AResult: Integer;
      const AMessage: string);
    procedure SteamAPI1Initialized(Sender: TObject);
    procedure SteamAPI1Callback(Sender: TObject;
      const AData: TSteamCallbackData);
  private
    { Private declarations }
  public
    { Public declarations }
  end;

var
  Form1: TForm1;

implementation

{$R *.fmx}

procedure TForm1.FormCreate(Sender: TObject);
begin
  SteamApi1.active := True;
end;

procedure TForm1.SteamAPI1Callback(Sender: TObject;
  const AData: TSteamCallbackData);
begin
 Memo1.Lines.Add('SteamAPI1Callback');
end;

procedure TForm1.SteamAPI1InitFailed(Sender: TObject; AResult: Integer;
  const AMessage: string);
begin
 Memo1.Lines.Add('SteamAPI1InitFailed');
end;

procedure TForm1.SteamAPI1Initialized(Sender: TObject);
begin
 Memo1.Lines.Add('SteamAPI1Initialized');
end;

procedure TForm1.SteamFriends1PersonaStateChange(Sender: TObject;
  const AData: PersonaStateChange_t);
begin
 Memo1.Lines.Add('SteamFriends1PersonaStateChange');
end;

end.
