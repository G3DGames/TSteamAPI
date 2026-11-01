program LogReceiver;

{ LogReceiver - receives log lines that programs on the local network send
  with RemoteLog.Sender, asks the user to accept each sender and saves every
  session to Documents/LogReceiver. 100% optional, nothing to do with Steam:
  see RemoteLogging/README.md. }

uses
  System.StartUpCopy,
  FMX.Forms,
  FmxLinuxGtkGlobal in 'src\FmxLinuxGtkGlobal.pas',
  FmxLinuxMenu in 'src\FmxLinuxMenu.pas',
  uNetworks in 'src\uNetworks.pas',
  uReceiver in 'src\uReceiver.pas' {frmReceiver};

begin
  Application.Initialize;
  Application.CreateForm(TfrmReceiver, frmReceiver);
  Application.Run;
end.
