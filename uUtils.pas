unit uUtils;

interface

uses
  Windows, WinSock2, SysUtils;

type
  EWSException = class(Exception)
  public
    WSAError: Integer;
    constructor Create();
  end;

  TUserId = Uint64;

const
  PROTOCOL = IPPROTO_TCP;

procedure ValidateOperation(CommandResult: Integer);
function ValidateSocket(S: TSocket): TSocket;
function ValidateReceiving(ReceiveResult: Integer): Integer;

implementation

procedure ValidateOperation(CommandResult: Integer);
begin
  if CommandResult = SOCKET_ERROR then
    raise EWSException.Create() at ReturnAddress;
end;

function If10004ThenZeroElseRaise(): Integer;
begin
  if WSAGetLastError() = 10004 then
    Result := 0
  else
    raise EWSException.Create() at ReturnAddress;
end;

function ValidateSocket(S: TSocket): TSocket;
begin
  if S = INVALID_SOCKET then
    Result := If10004ThenZeroElseRaise()
  else
    Result := S;
end;

function ValidateReceiving(ReceiveResult: Integer): Integer;
begin
  if ReceiveResult = SOCKET_ERROR then
    Result := If10004ThenZeroElseRaise()
  else
    Result := ReceiveResult;
end;

{ EWSException }

constructor EWSException.Create();
var
  WSAError: Integer;
begin
  WSAError := WSAGetLastError();

  inherited Create(
    'Winsock error. Code: ' + IntToStr(WSAError) +
    #13#10 + SysErrorMessage(WSAError)
  );

  Self.WSAError := WSAError;
end;

end.
