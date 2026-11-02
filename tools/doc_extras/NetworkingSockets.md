## Overview

Connection-oriented networking (`ISteamNetworkingSockets`, Valve's
GameNetworkingSockets): reliable and unreliable messages over connections,
by IP address or peer to peer through the Steam Datagram Relay (SDR). The
connection state arrives in `OnSteamNetConnectionStatusChangedCallback`.

```pascal
var
  C1, C2: HSteamNetConnection;
  MsgNo: Int64;
  Msgs: array[0..15] of PSteamNetworkingMessage_t;
  I, N: Integer;
begin
  // Two connected ends in this process (no network): handy for testing
  SteamNetworkingSockets1.Plugin.CreateSocketPair(C1, C2, False, nil, nil);
  SteamNetworkingSockets1.Plugin.SendMessageToConnection(C1, @Data[0], Length(Data),
    k_nSteamNetworkingSend_Reliable, MsgNo);
  N := SteamNetworkingSockets1.Plugin.ReceiveMessages(C2, Msgs);
  for I := 0 to N - 1 do
  begin
    HandleMessage(Msgs[I]^.m_pData, Msgs[I]^.m_cbSize);
    SteamNetworkingSockets1.Plugin.ReleaseMessage(Msgs[I]);   // always
  end;
  SteamNetworkingSockets1.Plugin.CloseConnection(C1, 0, 'done', False);
  SteamNetworkingSockets1.Plugin.CloseConnection(C2, 0, '', False);
end;
```

* `ReceiveMessages` / `ReceiveMessagesOnGroup` and `ReleaseMessage` are
  hand-written helpers (`tools/plugin_extras/NetworkingSockets.pas.txt`):
  every received message must be released (`SteamNetworkingMessage_t`
  Release, bound from `SteamAPI_SteamNetworkingMessage_t_Release`).
* `SteamNetworkingIdentity`, `SteamNetworkingIPAddr` and
  `SteamNetworkingConfigValue_t` contain C unions; they are hand-written
  variant records (`tools/sdk_extras/`) whose field offsets
  `tools/verify_generated.py` checks against the C headers on every target.
  Fill an identity with `m_eType := k_ESteamNetworkingIdentityType_SteamID`,
  `m_cbSize := 8`, `m_steamID64 := ...`.
* Peer to peer: `CreateListenSocketP2P` / `ConnectP2P` (needs
  `TSteamNetworkingUtils.InitRelayNetworkAccess` first); by IP:
  `CreateListenSocketIP` / `ConnectByIPAddress`. Accept incoming
  connections in the status callback with `AcceptConnection`.
* Many methods still take raw pointers (identity / address records,
  message arrays); pass `@Record`.
