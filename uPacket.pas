unit uPacket;

interface

uses
  uUtils;

type
  TPacketType = (ptRawData, ptText, ptAuthorizationRequest, ptAuthorization,
    ptAuthorizationConfirmation, ptUserConnected, ptUserDisconnected,
    ptUserList
    {ptUserRenamed}
  );

  TPacketHeader = packed record
    UserId: TUserId;
    PacketType: TPacketType;
    ContentLength: Cardinal;
  end;

  TPacket = packed record
    Header: TPacketHeader;
    Content: Byte;
  end;
  PPacket = ^TPacket;

  TPacketUserList = packed record
    Header: TPacketHeader;
    UserIds: TArray<TUserId>;
    UserNames: TArray<string>;
  end;

  TPacketFactory = class
  private
    class var LastCreatedPacket: PPacket;
    class function CreateMessagePacket(Content: Pointer; ContentLength: Integer): PPacket; static;
    class function BaseTextPacket(const Text: string): PPacket; static;
    class function Empty(): PPacket; static;
    class destructor Destroy();
  public
    class function TextMessage(const Text: string): PPacket; static;
    class function AuthorizationRequest(): PPacket; static;
    class function Authorization(const Username: string): PPacket; static;
    class function AuthorizationConfirmation(): PPacket; static;
    class function UserConnected(const Username: string): PPacket; static;
    class function UserDisconnected(): PPacket; static;
    class function UserList(UserIds: TArray<TUserId>; UserNames: TArray<string>): PPacket; static;
  end;

  TPF = TPacketFactory;

implementation

uses
  TypInfo;

{ TPacketFactory }

class destructor TPacketFactory.Destroy();
begin
  if Assigned(LastCreatedPacket) then
    FreeMem(LastCreatedPacket);
end;

class function TPacketFactory.CreateMessagePacket(Content: Pointer;
  ContentLength: Integer): PPacket;
var
  Len: Integer;
begin
  if Assigned(LastCreatedPacket) then
    FreeMem(LastCreatedPacket);

  Len := SizeOf(TPacketHeader) + ContentLength;

  Result := AllocMem(Len);
  LastCreatedPacket := Result;

  Result.Header.ContentLength := ContentLength;

  if Assigned(Content) then
    Move(Content^, Result.Content, ContentLength);
end;

class function TPacketFactory.BaseTextPacket(const Text: string): PPacket;
begin
  Result := CreateMessagePacket(PChar(Text), (Length(Text) + 1) * SizeOf(Char));
end;

class function TPacketFactory.Empty(): PPacket;
begin
  Result := CreateMessagePacket(nil, 0);
end;

class function TPacketFactory.TextMessage(const Text: string): PPacket;
begin
  Result := BaseTextPacket(Text);
  Result.Header.PacketType := ptText;
end;

class function TPacketFactory.AuthorizationRequest(): PPacket;
begin
  Result := Empty();
  Result.Header.PacketType := ptAuthorizationRequest;
end;

class function TPacketFactory.Authorization(const Username: string): PPacket;
begin
  Result := BaseTextPacket(Username);
  Result.Header.PacketType := ptAuthorization;
end;

class function TPacketFactory.AuthorizationConfirmation(): PPacket;
begin
  Result := Empty();
  Result.Header.PacketType := ptAuthorizationConfirmation;
end;

class function TPacketFactory.UserConnected(const Username: string): PPacket;
begin
  Result := BaseTextPacket(Username);
  Result.Header.PacketType := ptUserConnected;
end;

class function TPacketFactory.UserDisconnected(): PPacket;
begin
  Result := Empty();
  Result.Header.PacketType := ptUserDisconnected;
end;

class function TPacketFactory.UserList(UserIds: TArray<TUserId>; UserNames: TArray<string>): PPacket;
//var
//  Len: Integer;
//  ti: TTypeInfo;
begin
  Result := CreateMessagePacket(nil, 0);
  Result.Header.PacketType := ptUserList;


//  TypeInfo(TUserId)
//
//  ti.

//  SetLength();
//
//  tkWString
//
//  CopyArray()



//  TPacketUserList = packed record
//    Header: TPacketHeader;
//    UserIds: TArray<UInt64>;
//    UserNames: TArray<string>;
//    Content
//  end;
end;

end.
