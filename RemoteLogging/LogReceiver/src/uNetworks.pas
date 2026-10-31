{ @abstract(The IPv4 networks of this machine, for LogReceiver's "listen
  on" choice - part of the OPTIONAL remote logging.)

  Order of the list (owner's rule): the machine's REAL network first, then
  by the size of the private range the address is in - 192.168.x.x (the
  smallest), 172.16-31.x.x, 10.x.x.x (the largest; VPNs often use it),
  other addresses, link-local 169.254.x.x last. Loopback is left out.

  "Real" can only be told on Windows, where GetAdaptersAddresses names
  each adapter and gives its type and default gateway: an adapter that is
  up, is Ethernet or Wi-Fi, has an IPv4 default gateway and whose name /
  description does not look virtual (VPN, Hyper-V / WSL vEthernet, VMware,
  VirtualBox, TAP, WireGuard, ...). Elsewhere Indy's address list is used
  and nothing is marked real. }
unit uNetworks;

interface

type
  { One IPv4 address of this machine. }
  TNetworkChoice = record
    { The address, e.g. 192.168.1.63. }
    IP: string;
    { Its subnet mask, e.g. 255.255.255.0 ('' if unknown). }
    Mask: string;
    { Adapter name (Windows: its friendly name, e.g. Wi-Fi), or ''. }
    Name: string;
    { Looks like the machine's real network (Windows only, see the unit). }
    Real: Boolean;
    { Sort rank of the address range (0 = 192.168, 1 = 172.16-31, 2 = 10,
      3 = other, 4 = link-local). }
    Rank: Integer;
  end;

  { The networks, in the order they are offered. }
  TNetworkChoices = array of TNetworkChoice;

{ Every IPv4 address of this machine except loopback, sorted as described
  in the unit comment. }
function LocalNetworks: TNetworkChoices;

{ Text of AChoice in the list: address, adapter name, mask, "real" mark. }
function NetworkText(const AChoice: TNetworkChoice): string;

{ Directed broadcast address of AIP in the subnet AMask (192.168.1.63 /
  255.255.255.0 -> 192.168.1.255), or '' if either is not a dotted IPv4
  address. }
function DirectedBroadcast(const AIP, AMask: string): string;

implementation

uses
  System.SysUtils, System.StrUtils,
  IdGlobal, IdStack;

{ Rank of the address range of AIP (see TNetworkChoice.Rank); -1 for
  loopback (left out). }
function RangeRank(const AIP: string): Integer;
var
  B: TArray<string>;
  A1, A2: Integer;
begin
  B := AIP.Split(['.']);
  if Length(B) <> 4 then
    Exit(3);
  A1 := StrToIntDef(B[0], -1);
  A2 := StrToIntDef(B[1], -1);
  if A1 = 127 then
    Result := -1
  else if (A1 = 192) and (A2 = 168) then
    Result := 0
  else if (A1 = 172) and (A2 >= 16) and (A2 <= 31) then
    Result := 1
  else if A1 = 10 then
    Result := 2
  else if (A1 = 169) and (A2 = 254) then
    Result := 4
  else
    Result := 3;
end;

{ Dotted subnet mask of a prefix length (24 -> 255.255.255.0). }
function MaskOfPrefix(APrefix: Integer): string;
var
  I, Bits: Integer;
begin
  Result := '';
  for I := 0 to 3 do
  begin
    Bits := APrefix - 8 * I;
    if Bits > 8 then
      Bits := 8
    else if Bits < 0 then
      Bits := 0;
    Result := Result + IfThen(I > 0, '.', '') + IntToStr((255 shl (8 - Bits)) and 255);
  end;
end;

function DirectedBroadcast(const AIP, AMask: string): string;
var
  A, M: TArray<string>;
  I, X, Y: Integer;
begin
  Result := '';
  A := AIP.Split(['.']);
  M := AMask.Split(['.']);
  if (Length(A) <> 4) or (Length(M) <> 4) then
    Exit;
  for I := 0 to 3 do
  begin
    X := StrToIntDef(A[I], -1);
    Y := StrToIntDef(M[I], -1);
    if (X < 0) or (X > 255) or (Y < 0) or (Y > 255) then
      Exit('');
    Result := Result + IfThen(I > 0, '.', '') + IntToStr((X and Y) or (not Y and 255));
  end;
end;

function NetworkText(const AChoice: TNetworkChoice): string;
begin
  Result := AChoice.IP;
  if AChoice.Name <> '' then
    Result := Result + '   ' + AChoice.Name;
  if AChoice.Mask <> '' then
    Result := Result + '   (mask ' + AChoice.Mask + ')';
  if AChoice.Real then
    Result := Result + '   - this machine''s network';
end;

{ Adds AIP to AList unless it is loopback or already there. }
procedure AddChoice(var AList: TNetworkChoices; const AIP, AMask, AName: string; AReal: Boolean);
var
  I: Integer;
  C: TNetworkChoice;
begin
  C.Rank := RangeRank(AIP);
  if (AIP = '') or (C.Rank < 0) then
    Exit;
  for I := 0 to High(AList) do
    if AList[I].IP = AIP then
      Exit;
  C.IP := AIP;
  C.Mask := AMask;
  C.Name := AName;
  C.Real := AReal;
  I := Length(AList);
  SetLength(AList, I + 1);
  AList[I] := C;
end;

{$IFDEF MSWINDOWS}
// GetAdaptersAddresses (iphlpapi.dll, Windows Vista and later). The records
// follow IP_ADAPTER_ADDRESSES_LH / IP_ADAPTER_UNICAST_ADDRESS_LH /
// IP_ADAPTER_GATEWAY_ADDRESS_LH of iptypes.h up to the last field used here
// (natural alignment, as Delphi lays records out by default); the API
// allocates them, only pointers to them are followed.
const
  { IPv4 only. }
  AF_INET_FAMILY = 2;
  { Skip anycast, multicast and DNS server lists; include gateways. }
  GAA_FLAGS = $0002 or $0004 or $0008 or $0080;
  { The buffer was too small (SizePointer holds the size needed). }
  ERROR_BUFFER_OVERFLOW_CODE = 111;
  { IfType: Ethernet. }
  IF_TYPE_ETHERNET = 6;
  { IfType: Wi-Fi. }
  IF_TYPE_WIFI = 71;
  { OperStatus: up. }
  IF_OPER_UP = 1;

type
  { sockaddr_in. }
  TSockAddrIn4 = packed record
    { AF_INET for IPv4. }
    Family: Word;
    { Port (unused here). }
    Port: Word;
    { The address, network byte order. }
    Addr: array[0..3] of Byte;
  end;
  { Pointer to a TSockAddrIn4. }
  PSockAddrIn4 = ^TSockAddrIn4;

  { SOCKET_ADDRESS. }
  TSocketAddressRec = record
    { The sockaddr. }
    SockAddr: PSockAddrIn4;
    { Its length. }
    SockAddrLength: Integer;
  end;

  { Pointer to a TUnicastAddress. }
  PUnicastAddress = ^TUnicastAddress;
  { IP_ADAPTER_UNICAST_ADDRESS_LH. }
  TUnicastAddress = record
    { Size of the structure. }
    Length: Cardinal;
    { Flags. }
    Flags: Cardinal;
    { Next address of the adapter. }
    Next: PUnicastAddress;
    { The address. }
    Address: TSocketAddressRec;
    { IP_PREFIX_ORIGIN. }
    PrefixOrigin: Integer;
    { IP_SUFFIX_ORIGIN. }
    SuffixOrigin: Integer;
    { IP_DAD_STATE. }
    DadState: Integer;
    { Seconds the address is valid. }
    ValidLifetime: Cardinal;
    { Seconds the address is preferred. }
    PreferredLifetime: Cardinal;
    { DHCP lease seconds. }
    LeaseLifetime: Cardinal;
    { Prefix length of the address's subnet (24 = 255.255.255.0). }
    OnLinkPrefixLength: Byte;
  end;

  { Pointer to a TGatewayAddress. }
  PGatewayAddress = ^TGatewayAddress;
  { IP_ADAPTER_GATEWAY_ADDRESS_LH. }
  TGatewayAddress = record
    { Size of the structure. }
    Length: Cardinal;
    { Reserved. }
    Reserved: Cardinal;
    { Next gateway. }
    Next: PGatewayAddress;
    { The gateway's address. }
    Address: TSocketAddressRec;
  end;

  { Pointer to a TAdapterAddresses. }
  PAdapterAddresses = ^TAdapterAddresses;
  { IP_ADAPTER_ADDRESSES_LH, up to FirstGatewayAddress. }
  TAdapterAddresses = record
    { Size of the structure. }
    Length: Cardinal;
    { IPv4 interface index. }
    IfIndex: Cardinal;
    { Next adapter. }
    Next: PAdapterAddresses;
    { Adapter GUID name. }
    AdapterName: PAnsiChar;
    { First unicast address. }
    FirstUnicastAddress: PUnicastAddress;
    { Anycast list (skipped). }
    FirstAnycastAddress: Pointer;
    { Multicast list (skipped). }
    FirstMulticastAddress: Pointer;
    { DNS server list (skipped). }
    FirstDnsServerAddress: Pointer;
    { DNS suffix. }
    DnsSuffix: PWideChar;
    { Description, e.g. "Intel(R) Wi-Fi 6 AX201 160MHz". }
    Description: PWideChar;
    { Friendly name, e.g. "Wi-Fi". }
    FriendlyName: PWideChar;
    { MAC address. }
    PhysicalAddress: array[0..7] of Byte;
    { Bytes used in PhysicalAddress. }
    PhysicalAddressLength: Cardinal;
    { Flags. }
    Flags: Cardinal;
    { MTU. }
    Mtu: Cardinal;
    { Interface type (IF_TYPE_ETHERNET, IF_TYPE_WIFI, ...). }
    IfType: Cardinal;
    { IF_OPER_STATUS (IF_OPER_UP = up). }
    OperStatus: Integer;
    { IPv6 interface index. }
    Ipv6IfIndex: Cardinal;
    { Scope zone indices. }
    ZoneIndices: array[0..15] of Cardinal;
    { Prefix list. }
    FirstPrefix: Pointer;
    { Transmit speed, bit/s. }
    TransmitLinkSpeed: UInt64;
    { Receive speed, bit/s. }
    ReceiveLinkSpeed: UInt64;
    { WINS server list. }
    FirstWinsServerAddress: Pointer;
    { Gateway list (GAA_FLAG_INCLUDE_GATEWAYS). }
    FirstGatewayAddress: PGatewayAddress;
  end;

{ iphlpapi GetAdaptersAddresses. }
function LR_GetAdaptersAddresses(Family, Flags: Cardinal; Reserved: Pointer;
  AdapterAddresses: PAdapterAddresses; var SizePointer: Cardinal): Cardinal; stdcall;
  external 'iphlpapi.dll' name 'GetAdaptersAddresses';

{ Words in an adapter's name or description that mark it virtual. }
const
  VIRTUAL_WORDS: array[0..19] of string = ('virtual', 'vpn', 'tap-', 'tap ', 'hyper-v',
    'vmware', 'virtualbox', 'vethernet', 'wsl', 'loopback', 'tunnel', 'wireguard',
    'zerotier', 'tailscale', 'openvpn', 'nordlynx', 'proton', 'docker', 'npcap', 'bluetooth');

{ Dotted text of an IPv4 sockaddr, or '' if it is not one. }
function SockAddrText(P: PSockAddrIn4): string;
begin
  if (P = nil) or (P^.Family <> AF_INET_FAMILY) then
    Exit('');
  Result := Format('%d.%d.%d.%d', [P^.Addr[0], P^.Addr[1], P^.Addr[2], P^.Addr[3]]);
end;

{ Adds the IPv4 addresses Windows reports, marking the real ones; False if
  the call failed (the caller then uses Indy's list). }
function AddWindowsNetworks(var AList: TNetworkChoices): Boolean;
var
  Buffer: TBytes;
  Size, R: Cardinal;
  Tries: Integer;
  A: PAdapterAddresses;
  U: PUnicastAddress;
  G: PGatewayAddress;
  Gateway, Physical, Looks: Boolean;
  Name, Words: string;
  W: string;
begin
  Result := False;
  Size := 16 * 1024;
  R := ERROR_BUFFER_OVERFLOW_CODE;
  for Tries := 1 to 3 do
  begin
    SetLength(Buffer, Size);
    R := LR_GetAdaptersAddresses(AF_INET_FAMILY, GAA_FLAGS, nil, PAdapterAddresses(@Buffer[0]), Size);
    if R <> ERROR_BUFFER_OVERFLOW_CODE then
      Break;
  end;
  if R <> 0 then
    Exit;
  Result := True;
  A := PAdapterAddresses(@Buffer[0]);
  while A <> nil do
  begin
    if A^.OperStatus = IF_OPER_UP then
    begin
      Gateway := False;
      G := A^.FirstGatewayAddress;
      while G <> nil do
      begin
        if (SockAddrText(G^.Address.SockAddr) <> '') and (SockAddrText(G^.Address.SockAddr) <> '0.0.0.0') then
          Gateway := True;
        G := G^.Next;
      end;
      Name := string(A^.FriendlyName);
      Words := LowerCase(Name + ' ' + string(A^.Description));
      Looks := False;
      for W in VIRTUAL_WORDS do
        if Words.Contains(W) then
          Looks := True;
      Physical := (A^.IfType = IF_TYPE_ETHERNET) or (A^.IfType = IF_TYPE_WIFI);
      U := A^.FirstUnicastAddress;
      while U <> nil do
      begin
        AddChoice(AList, SockAddrText(U^.Address.SockAddr), MaskOfPrefix(U^.OnLinkPrefixLength),
          Name, Physical and Gateway and not Looks);
        U := U^.Next;
      end;
    end;
    A := A^.Next;
  end;
end;
{$ENDIF}

{ Adds the IPv4 addresses Indy reports (no names, none marked real). }
procedure AddIndyNetworks(var AList: TNetworkChoices);
var
  Addresses: TIdStackLocalAddressList;
  I: Integer;
begin
  TIdStack.IncUsage;
  try
    Addresses := TIdStackLocalAddressList.Create;
    try
      GStack.GetLocalAddressList(Addresses);
      for I := 0 to Addresses.Count - 1 do
        if Addresses[I].IPVersion = Id_IPv4 then
          AddChoice(AList, Addresses[I].IPAddress,
            TIdStackLocalAddressIPv4(Addresses[I]).SubNetMask, '', False);
    finally
      Addresses.Free;
    end;
  finally
    TIdStack.DecUsage;
  end;
end;

{ True if A goes before B: real first, then rank (the original order is
  kept within a rank). }
function Before(const A, B: TNetworkChoice): Boolean;
begin
  if A.Real <> B.Real then
    Result := A.Real
  else
    Result := A.Rank < B.Rank;
end;

function LocalNetworks: TNetworkChoices;
var
  I, J: Integer;
  C: TNetworkChoice;
  Done: Boolean;
begin
  Result := nil;
  Done := False;
{$IFDEF MSWINDOWS}
  try
    Done := AddWindowsNetworks(Result);
  except
    Result := nil;
    Done := False;
  end;
{$ENDIF}
  if not Done then
    AddIndyNetworks(Result);
  // insertion sort: stable, so the system's order is kept within a rank
  for I := 1 to High(Result) do
  begin
    C := Result[I];
    J := I - 1;
    while (J >= 0) and Before(C, Result[J]) do
    begin
      Result[J + 1] := Result[J];
      Dec(J);
    end;
    Result[J + 1] := C;
  end;
end;

end.
