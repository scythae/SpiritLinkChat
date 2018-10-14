unit uConnectionThreads;

interface

uses
  Windows, WinSock2, Classes, SysUtils, uUtils, uPacket;

type
  TSocketThread = class(TThread)
  private type
    TOnException = reference to procedure(E: Exception);
  private
    Sock: TSocket;
    OnException: TOnException;
  protected
    procedure Execute(); override; final;
    procedure ExecuteInternal(); virtual; abstract;
  public
    Name: string;  {$Message 'Remove after debug'}
    constructor Create(Sock: TSocket; OnException: TOnException);
  end;

  TConnectionThread = class(TSocketThread)
  private type
    TConnectionThreadOnMessage = reference to procedure(Buffer: Pointer; Len: Integer);
  private
    procedure Receive();
  protected
    procedure ExecuteInternal(); override;
  public
    OnMessage: TConnectionThreadOnMessage;
  end;

  TListenerThread = class(TSocketThread)
  private type
    TOnIncomingConnection = reference to procedure(IncomerSocket: TSocket);
  protected
    procedure ExecuteInternal(); override;
  public
    OnIncomingConnection: TOnIncomingConnection;
  end;

implementation

{ TConnectionThreadBase }

constructor TSocketThread.Create(Sock: TSocket; OnException: TOnException);
begin
  inherited Create(True);

  Self.Sock := Sock;
  Self.OnException := OnException;
end;

procedure TSocketThread.Execute();
begin
  inherited;

  try
    while not Terminated do
      ExecuteInternal();
  except on E: Exception do
    if Assigned(OnException) then
      OnException(E)
    else
      raise;
  end;
end;

{ TConnectionThread }

procedure TConnectionThread.ExecuteInternal();
begin
  Receive();
end;

procedure TConnectionThread.Receive();
const
  RECEIVE_LENGTH = 255;
var
  Buffer: Pointer;
  ReceivedLength: Integer;
begin
  Buffer := AllocMem(RECEIVE_LENGTH);
  try
    ReceivedLength := ValidateReceiving(recv(Sock, Buffer^, RECEIVE_LENGTH, 0));

    Synchronize(procedure
    begin
      OnMessage(Buffer, ReceivedLength);
    end);
  finally
    FreeMem(Buffer, RECEIVE_LENGTH);
  end;
end;

{ TListenerThread }

procedure TListenerThread.ExecuteInternal();
var
  IncomingConnectionSocket: TSocket;
begin
  IncomingConnectionSocket := ValidateSocket(accept(Sock, nil, nil));

  Synchronize(procedure
  begin
    OnIncomingConnection(IncomingConnectionSocket);
  end);
end;

end.
