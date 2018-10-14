unit uMain;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes, Vcl.Graphics,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.StdCtrls, System.Generics.Collections,

  uConnection, uPacket, uUtils,

  Vcl.ExtCtrls, Math;

type
  TUsers = class(TDictionary<TUserId, string>)

  end;

  TConnectionList = class(TList<TConnection>)
  private
    procedure CloseAll();
    procedure OnMessageInternal(Connection: TConnection; Packet: PPacket);
    function GetUniqueName(const OriginalName: string): string;
    procedure SendToAll(Packet: PPacket);
    procedure GiveListOfUsersToIncomer(Incomer: TConnection);
  public
    OnMessage: TConnectionOnMessage;
    procedure AddConnection(Incomer: TConnection);
    destructor Destroy(); override;
  end;

  TfrMain = class(TForm)
    pNavigation: TPanel;
    btnHost: TButton;
    btnJoin: TButton;
    lbConnections: TListBox;
    pChat: TPanel;
    mChat: TMemo;
    pMyMessage: TPanel;
    mMyMessage: TMemo;
    pMyMessageButtons: TPanel;
    btnSend: TButton;
    splChat: TSplitter;
    splMyMessage: TSplitter;
    procedure btnHostClick(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure btnJoinClick(Sender: TObject);
    procedure btnSendClick(Sender: TObject);
  private
    Users: TUsers;
    ClientList: TConnectionList;
    MyConnectionToTheHost: TConnection;
    Listener: TListener;
    procedure OnNewConnection(Connection: TConnection);
    procedure OnConnectionMessage(Connection: TConnection; Packet: PPacket);
    procedure AdjustControls;
    function Hosted: Boolean;
    procedure AddToChat(const Text: string);
    function CheckParametersOfJoin(const Values: array of string): Boolean;
    procedure GetParametersOfJoin(out Address: string; out Port: Integer;
      out Username: string);
    procedure JoinToTheHost(Address: string; Port: Integer; Username: string);
    function Joined: Boolean;
    procedure TryUnhost;
    function GetUserName(UserId: TUserId): string;
  end;

var
  frMain: TfrMain;

implementation

{$R *.dfm}

const
  SERVICE_SYMBOL = '!';
  MIN_PORT = 0;
  MAX_PORT = 65535;

function TfrMain.Hosted(): Boolean;
begin
  Result := Assigned(Listener);
end;

function TfrMain.Joined(): Boolean;
begin
  Result := Assigned(MyConnectionToTheHost);
end;

procedure TfrMain.btnHostClick(Sender: TObject);
begin
  if not Hosted() then
  begin
    Listener := TConnectionFactory.Host(DEFAULTPORT);
    Listener.Name := SERVICE_SYMBOL+'Listener';
    Listener.ListenForConnections(OnNewConnection);

    JoinToTheHost(ADDRESS_LOCALHOST, DEFAULTPORT, SERVICE_SYMBOL+'Server');
  end
  else
    TryUnhost();

  AdjustControls();
end;

procedure TfrMain.AdjustControls();
begin
  if Hosted() then
  begin
    btnHost.Caption := 'Unhost';
  end
  else
  begin
    btnHost.Caption := 'Host';
  end;

  btnJoin.Visible := not Hosted();
  btnJoin.TabOrder := btnHost.Top + 1;
end;

procedure TfrMain.OnNewConnection(Connection: TConnection);
begin
  ClientList.AddConnection(Connection);
end;

procedure TfrMain.btnJoinClick(Sender: TObject);
var
  Address: string;
  Port: Integer;
  Username: string;
begin
  GetParametersOfJoin(Address, Port, Username);
  JoinToTheHost(Address, Port, Username);
end;

procedure TfrMain.JoinToTheHost(Address: string; Port: Integer; Username: string);
begin
  MyConnectionToTheHost := TConnectionFactory.Join(Address, Port);
  MyConnectionToTheHost.Name := Username;
  MyConnectionToTheHost.ReceiveMessages(OnConnectionMessage);
end;

procedure TfrMain.GetParametersOfJoin(out Address: string; out Port: Integer; out Username: string);
var
  Params: TArray<string>;
begin
  Params := [ADDRESS_LOCALHOST, DEFAULTPORT.ToString(), 'Username'];

  if not InputQuery(
    'Join to ...', ['Host''s IP-Address', 'Host''s port', 'Username'],
    Params, CheckParametersOfJoin
  ) then
    Abort();

  Address := Params[0];
  Port := Params[1].ToInteger();
  Username := Trim(Params[2]);
end;

function TfrMain.CheckParametersOfJoin(const Values: array of string): Boolean;
  function CheckUsername(): Boolean;
  begin
    Result := not Values[2].Contains(SERVICE_SYMBOL);
    if not Result then
      ShowMessage('Symbol "' + SERVICE_SYMBOL + '" is reserved by server.');
  end;

  function CheckPort(): Boolean;
  var
    tmpPort: Integer;
  begin
    Result := TryStrToInt(Values[1], tmpPort) and InRange(tmpPort, MIN_PORT, MAX_PORT);
    if not Result then
      ShowMessage(Format('Port should be a number in a %d..%d range.', [MIN_PORT, MAX_PORT]));
  end;
begin
  Result := CheckUsername() and CheckPort();
end;

procedure TfrMain.OnConnectionMessage(Connection: TConnection; Packet: PPacket);
var
  SenderId: TUserId;
  Text: string;
begin
  SenderId := Packet.Header.UserId;

  if Packet.Header.PacketType = ptUserConnected then
  begin
    Text := string(PChar(@Packet.Content));
    Users.Add(SenderId, Text);
    AddToChat(GetUserName(SenderId) + ' has joined.');
  end
  else if Packet.Header.PacketType = ptText then
    AddToChat(GetUserName(SenderId) + ': ' + string(PChar(@Packet.Content)));
end;

function TfrMain.GetUserName(UserId: TUserId): string;
begin
  if Users.ContainsKey(UserId) then
    Result := Users[UserId]
  else
    Result := '!Noname';
end;

procedure TfrMain.AddToChat(const Text: string);
begin
  mChat.Lines.Add(Text);
end;

procedure TfrMain.FormCreate(Sender: TObject);
begin
  ClientList := TConnectionList.Create();
  ClientList.OnMessage := OnConnectionMessage;

  Users := TUsers.Create();

  SystemNotification := AddToChat;
end;

procedure TfrMain.FormDestroy(Sender: TObject);
begin
//  TryUnhost();
  FreeAndNil(Listener);
  FreeAndNil(MyConnectionToTheHost);
  FreeAndNil(ClientList);
  FreeAndNil(Users);
end;

procedure TfrMain.TryUnhost();
begin
  if Hosted() then
  begin
    FreeAndNil(MyConnectionToTheHost);
    FreeAndNil(Listener);
    ClientList.CloseAll();
    Users.Clear();
  end;
end;

procedure TfrMain.btnSendClick(Sender: TObject);
begin
  if not Assigned(MyConnectionToTheHost) then
  begin
    ShowMessage('You are not connected to server.');
    Exit();
  end;
  MyConnectionToTheHost.SendText(mMyMessage.Text);
  mMyMessage.Clear();

//  Users.
end;

{ TConnectionList }

procedure TConnectionList.AddConnection(Incomer: TConnection);
begin
  Add(Incomer);

  Incomer.Name := GetUniqueName(Incomer.Name);
  Incomer.ReceiveMessages(OnMessageInternal);
  GiveListOfUsersToIncomer(Incomer);
end;

procedure TConnectionList.GiveListOfUsersToIncomer(Incomer: TConnection);
begin

//  Connection.SendPacketAnonymously(nil);
end;


function TConnectionList.GetUniqueName(const OriginalName: string): string;
begin
  Result := 'Clients' + SERVICE_SYMBOL + OriginalName;

//  if Result = '' then
//    Result := 'Client' + IntToStr(GenClientId());
end;

procedure TConnectionList.CloseAll();
var
  AllConnections: TArray<TConnection>;
  Connection: TConnection;
begin
  AllConnections := ToArray();

  for Connection in AllConnections do
  begin
    Connection.Free();
    Remove(Connection);
  end
end;

destructor TConnectionList.Destroy;
begin
  CloseAll();
  inherited;
end;

procedure TConnectionList.OnMessageInternal(Connection: TConnection; Packet: PPacket);
begin
  SendToAll(Packet);
end;

procedure TConnectionList.SendToAll(Packet: PPacket);
var
  C: TConnection;
begin
  for C in ToArray() do
    C.SendPacketAnonymously(Packet);
end;

end.
