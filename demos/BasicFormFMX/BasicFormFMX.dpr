program BasicFormFMX;

uses
  System.StartUpCopy,
  FMX.Forms,
  BasicFormFMXMain in 'BasicFormFMXMain.pas' {Form1};

{$R *.res}

begin
  Application.Initialize;
  Application.CreateForm(TForm1, Form1);
  Application.Run;
end.
