## Overview

Message-based peer to peer (`ISteamNetworkingMessages`): send to a Steam
user (a `SteamNetworkingIdentity`), no connection to manage - the
replacement for the old `TSteamNetworking` P2P packets. Uses the Steam
Datagram Relay, so call `TSteamNetworkingUtils.InitRelayNetworkAccess`
early.

```pascal
var
  Peer: SteamNetworkingIdentity;
  Msgs: array[0..15] of PSteamNetworkingMessage_t;
  I, N: Integer;
begin
  FillChar(Peer, SizeOf(Peer), 0);
  Peer.m_eType := k_ESteamNetworkingIdentityType_SteamID;
  Peer.m_cbSize := 8;
  Peer.m_steamID64 := FriendID;
  SteamNetworkingMessages1.Plugin.SendMessageToUser(@Peer, @Data[0], Length(Data),
    k_nSteamNetworkingSend_Reliable, 0);
  // poll every frame
  N := SteamNetworkingMessages1.Plugin.ReceiveMessages(0, Msgs);
  for I := 0 to N - 1 do
  begin
    HandleMessage(Msgs[I]^.m_identityPeer.m_steamID64, Msgs[I]^.m_pData, Msgs[I]^.m_cbSize);
    SteamNetworkingMessages1.Plugin.ReleaseMessage(Msgs[I]);   // always
  end;
end;
```

* `OnSteamNetworkingMessagesSessionRequest`: a user you have not sent to
  yet wants to talk - accept with `AcceptSessionWithUser(@AData.m_identityRemote)`.
* `OnSteamNetworkingMessagesSessionFailed` reports a session that broke;
  `CloseSessionWithUser` / `CloseChannelWithUser` end one.
* `ReceiveMessages` and `ReleaseMessage` are hand-written helpers
  (`tools/plugin_extras/NetworkingMessages.pas.txt`).
