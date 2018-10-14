unit uConnection;

interface

uses
  Windows, WinSock2, Classes, SysUtils, Dialogs, SyncObjs, uPacket, uConnectionThreads, uUtils;

type
  TConnectionBase = class
  strict protected
    FSocket: TSocket;
    FThread: TSocketThread;
    procedure Stop();
  public
    Name: string;
    constructor Create(Sock: TSocket);
    destructor Destroy; override;
  end;

  TConnection = class;
  TConnectionOnMessage = reference to procedure(Connection: TConnection; Packet: PPacket);
  TConnection = class(TConnectionBase)
  strict private
    OnMessage: TConnectionOnMessage;
    procedure Receive(Buffer: Pointer; Len: Integer);
    procedure OnException(E: Exception);
    procedure SendInternal(Buffer: Pointer; Len: Integer);
    procedure GotDisconnected();
  private
    FUserId: TUserId;
    procedure SendPacket(Packet: PPacket);
  public
    property UserId: UInt64 read FUserId;
    procedure ReceiveMessages(OnMessage: TConnectionOnMessage);
    procedure SendPacketAnonymously(Packet: PPacket);
    procedure SendText(const Text: string);
//    procedure SendFile(Buffer: Pointer; Len: Integer);
    destructor Destroy(); override;
  end;

  TListener = class(TConnectionBase)
  private type
    TOnNewConnection = reference to procedure(Connection: TConnection);
  strict private
    GeneratorUserId: TUserId;
    OnNewConnection: TOnNewConnection;
    procedure OnException(E: Exception);
    function RequestAuthorization(Incomer: TConnection): Boolean;
    procedure OnIncomingConnectionInternal(IncomerSocket: TSocket);
  public
    procedure ListenForConnections(OnNewConnection: TOnNewConnection);
    destructor Destroy(); override;
  end;

  TConnectionFactory = class
  private
    class constructor Create();
    class destructor Destroy();
  public
    class function Join(Address: string; Port: Integer): TConnection;
    class function Host(Port: Integer): TListener;
  end;

  EConnectionException = class(Exception);
  TSystemNotification = reference to procedure(const Text: string);

  procedure SystemNotify(const Text: string);

var
  SystemNotification: TSystemNotification = nil;

const
  DEFAULTPORT = 10800;
  ADDRESS_LOCALHOST = '127.0.0.1';

implementation

const
  PROTOCOL = IPPROTO_TCP;

procedure SystemNotify(const Text: string);
begin
  if Assigned(SystemNotification) then
    SystemNotification(Text);
end;

function MakeAddressInfo(Port: Integer; Address: string): TSockAddr;
var
  Sin: TSockAddrIn;
begin
  FillChar(Sin, SizeOf(Sin), 0);
  Sin.sin_family := AF_INET;
  Sin.sin_port := Port;
  Sin.sin_addr.S_addr := inet_addr(PAnsiChar(AnsiString(Address)));
  Result := TSockAddr(Sin);
end;

{ TConnectionFactory }

class constructor TConnectionFactory.Create();
var
  Winsock_version: Word;
  Winsock_error: Integer;
  Winsock_data: WSADATA;
begin
  Winsock_version := MakeWord(2, 0);
  Winsock_error := WSAStartup(Winsock_version, Winsock_data);
  if Winsock_error <> 0 then
    raise Exception.Create('Winsock initialization error.');
end;

class destructor TConnectionFactory.Destroy();
begin
  WSACleanup();
end;

class function TConnectionFactory.Join(Address: string;
  Port: Integer): TConnection;
var
  AddressInfo: TSockAddr;
  ServerSocket: TSocket;
begin
  AddressInfo := MakeAddressInfo(Port, Address);

  ServerSocket := ValidateSocket(socket(AddressInfo.sa_family, SOCK_STREAM, PROTOCOL));
  try
    ValidateOperation(connect(ServerSocket, AddressInfo, SizeOf(AddressInfo)));
  except
    closesocket(ServerSocket);
    raise;
  end;

  Result := TConnection.Create(ServerSocket);
  Result.Name := 'NewClient';
end;

class function TConnectionFactory.Host(Port: Integer): TListener;
var
  AddressInfo: TSockAddr;
  ListenerSocket: TSocket;
begin
  AddressInfo := MakeAddressInfo(Port, ADDRESS_LOCALHOST);

  ListenerSocket := ValidateSocket(socket(AddressInfo.sa_family, SOCK_STREAM, PROTOCOL));
  try
    ValidateOperation(bind(ListenerSocket, AddressInfo, SizeOf(AddressInfo)));
    ValidateOperation(listen(ListenerSocket, SOMAXCONN));
  except
    closesocket(ListenerSocket);
    raise;
  end;

  Result := TListener.Create(ListenerSocket);
end;

{ TConnectionBase }

constructor TConnectionBase.Create(Sock: TSocket);
begin
  inherited Create();
  FSocket := Sock;
end;

destructor TConnectionBase.Destroy();
begin
  closesocket(FSocket);
  FreeAndNil(FThread);
  Stop();

  inherited;
end;

procedure TConnectionBase.Stop();
begin
  if not Assigned(FThread) then
    Exit();

  FThread.Terminate();
end;

{ TConnection }

procedure TConnection.ReceiveMessages(OnMessage: TConnectionOnMessage);
begin
  Assert(Assigned(OnMessage));
  Self.OnMessage := OnMessage;

  if not Assigned(FThread) then
  begin
    FThread := TConnectionThread.Create(FSocket, OnException);
    TConnectionThread(FThread).OnMessage := Receive;
    FThread.Name := Name;
  end;

  if not FThread.Started then
    FThread.Start();
end;

procedure TConnection.OnException(E: Exception);
begin
  SystemNotify(Format(
    'Exception at connection "%s": %s',
    [Name, E.Message]
  ));
end;

procedure TConnection.Receive(Buffer: Pointer; Len: Integer);
var
  Packet: PPacket;
begin
  if Len = 0 then
  begin
    GotDisconnected();
    Exit();
  end;

  Packet := PPacket(Buffer);

  if Packet.Header.PacketType = ptAuthorizationRequest then
    SendPacket(TPF.Authorization(Name))
  else if Packet.Header.PacketType = ptAuthorizationConfirmation then
  begin
    FUserId := Packet.Header.UserId;
    SendPacket(TPF.UserConnected(Name));
  end
  else
    OnMessage(Self, Packet);
end;

procedure TConnection.GotDisconnected();
begin
  Stop();
  SystemNotify(Name + ' got disconnected.');
end;

procedure TConnection.SendText(const Text: string);
begin
  SendPacket(TPacketFactory.TextMessage(Text));
end;

destructor TConnection.Destroy;
begin
  shutdown(FSocket, SD_SEND);
  inherited;
end;

procedure TConnection.SendPacket(Packet: PPacket);
begin
  Packet.Header.UserId := UserId;
  SendPacketAnonymously(Packet);
end;

procedure TConnection.SendPacketAnonymously(Packet: PPacket);
var
  Len: Integer;
begin
  Len := SizeOf(Packet.Header) + Packet.Header.ContentLength;
  SendInternal(Packet, Len);
end;

procedure TConnection.SendInternal(Buffer: Pointer; Len: Integer);
begin
  ValidateOperation(send(FSocket, Buffer^, Len, 0));
end;

{ TListener }

destructor TListener.Destroy;
begin
  OnNewConnection := nil;
  inherited;
end;

procedure TListener.ListenForConnections(OnNewConnection: TOnNewConnection);
begin
  Assert(Assigned(OnNewConnection));
  Self.OnNewConnection := OnNewConnection;

  FThread := TListenerThread.Create(FSocket, OnException);
  TListenerThread(FThread).OnIncomingConnection := OnIncomingConnectionInternal;

  FThread.Name := Name;
  FThread.Start();
  SystemNotify('Host opened.');
end;

procedure TListener.OnException(E: Exception);
begin
  SystemNotify('Host shutdown.');
end;

procedure TListener.OnIncomingConnectionInternal(IncomerSocket: TSocket);
var
  Incomer: TConnection;
begin
  if IncomerSocket = 0 then
  begin
    Stop();
    Exit();
  end;

  Incomer := TConnection.Create(IncomerSocket);
  RequestAuthorization(Incomer);
end;

function TListener.RequestAuthorization(Incomer: TConnection): Boolean;
begin
  Incomer.ReceiveMessages(
  procedure(Connection: TConnection; Packet: PPacket)
  begin
    if Packet.Header.PacketType = ptAuthorization then
    begin
      Incomer.Name := string(PChar(@(Packet.Content)));

      Inc(GeneratorUserId);
      Incomer.FUserId := GeneratorUserId;
      Incomer.SendPacket(TPF.AuthorizationConfirmation());

      OnNewConnection(Incomer);
    end;
  end);

  Incomer.SendPacket(TPF.AuthorizationRequest());

  Result := True;
end;

end.
