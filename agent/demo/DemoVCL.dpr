program DemoVCL;

uses
  Vcl.Forms,
  DemoMain in 'DemoMain.pas' {FormMain},
  DelphiTestAgent in '..\src\DelphiTestAgent.pas',
  DelphiTestAgent.Server in '..\src\DelphiTestAgent.Server.pas',
  DelphiTestAgent.Rtti in '..\src\DelphiTestAgent.Rtti.pas',
  DelphiTestAgent.Invoke in '..\src\DelphiTestAgent.Invoke.pas';

begin
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.Title := 'NexusTest Demo VCL';
  Application.CreateForm(TFormMain, FormMain);
  DelphiTestAgent.Start;
  Application.Run;
end.
