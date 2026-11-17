## Overview

The OLD peer-to-peer API (`ISteamNetworking`): packets to another Steam
user by SteamID, relayed by Steam when no direct route exists. Valve has
deprecated it; new code should use `TSteamNetworkingMessages` (the same
idea, message based) or `TSteamNetworkingSockets` (connections). It is
bound because existing games still use it.

```pascal
var
  Size, Got: UInt32;
  From: TSteamID;
  Buf: TBytes;
begin
  // send: the first packet to a user also opens the session
  SteamNetworking1.Plugin.SendP2PPacket(Friend, @Data[0], Length(Data), k_EP2PSendReliable, 0);
  // receive (poll every frame)
  while SteamNetworking1.Plugin.IsP2PPacketAvailable(Size, 0) do
  begin
    SetLength(Buf, Size);
    if SteamNetworking1.Plugin.ReadP2PPacket(@Buf[0], Size, Got, From, 0) then
      HandlePacket(From, Copy(Buf, 0, Got));
  end;
end;
```

* `OnP2PSessionRequest`: another user wants to talk to you - call
  `AcceptP2PSessionWithUser(AData.m_steamIDRemote)` to accept.
* `OnP2PSessionConnectFail` reports a session that failed;
  `CloseP2PSessionWithUser` ends one.
* `CreateListenSocket` and `CreateConnectionSocket` (the even older
  socket part) are NOT bound: they take the deprecated `SteamIPAddress_t`
  by value, which the generator does not lower. The rest of that socket
  part is bound.
