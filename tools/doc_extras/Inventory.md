## Overview

Steam Inventory: items the user owns in this game (cosmetics, drops,
purchases), defined on the Steamworks partner site. Every request returns
a *result handle*; `OnSteamInventoryResultReady` says when it is ready, and
every result must be destroyed.

```pascal
procedure TForm1.LoadItems;
begin
  SteamInventory1.Plugin.GetAllItems(FResult);   // -> OnSteamInventoryResultReady
end;

procedure TForm1.SteamInventory1SteamInventoryResultReady(Sender: TObject;
  const AData: SteamInventoryResultReady_t);
var
  Count: UInt32;
  Items: array of SteamItemDetails_t;
begin
  if AData.m_handle <> FResult then
    Exit;
  Count := 0;
  SteamInventory1.Plugin.GetResultItems(FResult, nil, Count);      // size first
  SetLength(Items, Count);
  if Count > 0 then
    SteamInventory1.Plugin.GetResultItems(FResult, @Items[0], Count);
  SteamInventory1.Plugin.DestroyResult(FResult);                   // always
end;
```

* `LoadItemDefinitions` / `OnSteamInventoryDefinitionUpdate` for the item
  definitions; `TriggerItemDrop`, `ConsumeItem`, `AddPromoItem`,
  `ExchangeItems`, `StartPurchase`.
* Many methods take raw arrays (pointer + count): pass `nil` first to get
  the size, as above.
* Results can be serialised and checked on a game server
  (`SerializeResult`, `CheckResultSteamID`).
