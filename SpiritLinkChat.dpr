program SpiritLinkChat;

uses
  Vcl.Forms,
  uMain in 'uMain.pas' {frMain},
  uConnection in 'uConnection.pas',
  uUtils in 'uUtils.pas',
  uPacket in 'uPacket.pas',
  uConnectionThreads in 'uConnectionThreads.pas';

{$R *.res}

begin
  ReportMemoryLeaksOnShutdown := True;
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.CreateForm(TfrMain, frMain);
  Application.Run;
end.
