# TSteamInventory and TSteamInventoryPlugin (ISteamInventory)

> **Generated** by `tools/gen_docs.py` from `lib/plugins/Steamworks.Plugin.Inventory.pas` - do not edit.
> Hand-written text: `tools/doc_extras/Inventory.md`. Steam's own descriptions are Valve's
> SDK comments, as in the generated units.

Unit: `Steamworks.Plugin.Inventory` - linking it (a `uses` entry, or dropping a `TSteamInventory`) enables the
plug-in. Steam interface: `ISteamInventory` (SDK 1.65).

**Game-server copy:** `TSteamGameServerInventory` (plug-in `TSteamGameServerInventoryPlugin`) in the same unit - the
game server's own `ISteamInventory`, with every method and event on this page. It attaches
while the game server runs and gets its events from the server's callback pipe
(see [TSteamGameServer](TSteamGameServer.md#server-components)).

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

## Contents

* [The component: TSteamInventory](#the-component-tsteaminventory)
  * [Events (6)](#events)
* [The plug-in: TSteamInventoryPlugin](#the-plug-in-tsteaminventoryplugin)
  * [Methods](#methods)
  * [Async methods](#async-methods)
  * [Properties](#properties)
* [Payload records](#payload-records)

## The component: TSteamInventory

ISteamInventory component: drop it next to a TSteamAPI (linked automatically at run time when the owner has exactly one, otherwise set SteamAPI). Its events are the ISteamInventory callbacks; call the interface through `Plugin`.

| Member | Kind | Description |
|--------|------|-------------|
| `SteamAPI` | published property | The `TSteamAPI` this component belongs to. At run time a component whose owner has exactly one `TSteamAPI` links itself. |
| `Plugin` | public property | The `TSteamInventoryPlugin` for calls; `nil` while Steam is not running. |
| `Attached` | public property | `True` while the events are subscribed (Steam running, `SteamAPI` set). |
| `Attach` / `Detach` | public methods | Subscribe / remove the events by hand (normally automatic). |

Events run on the thread chosen by the root's `UpdateMode` / `Delivery` - the main
thread by default (see [GameEngineIntegration.md](../GameEngineIntegration.md)). Each event
checks that Steam's payload size equals the Pascal record's; a mismatch raises
`ESteamworksError` instead of handing over a wrong record. Call results of the same
struct reach the event too (unless an `...Async` call claimed them); failed call results
raise no event and are logged as warnings.

### Events

| Event | Callback | Payload | Description |
|-------|----------|---------|-------------|
| `OnSteamInventoryResultReady` | 4700 | [`SteamInventoryResultReady_t`](#steaminventoryresultready_t) | SteamInventoryResultReady_t callbacks are fired whenever asynchronous results transition from "Pending" to "OK" or an error state. There will always be exactly one callback per handle. |
| `OnSteamInventoryFullUpdate` | 4701 | [`SteamInventoryFullUpdate_t`](#steaminventoryfullupdate_t) | SteamInventoryFullUpdate_t callbacks are triggered when GetAllItems successfully returns a result which is newer / fresher than the last known result. (It will not trigger if the inventory hasn't changed, or if results from two overlapping calls are reversed in flight and the earlier result is already known to be stale/out-of-date.) The normal ResultReady callback will still be triggered immediately afterwards; this is an additional notification for your convenience. |
| `OnSteamInventoryDefinitionUpdate` | 4702 | [`SteamInventoryDefinitionUpdate_t`](#steaminventorydefinitionupdate_t) | A SteamInventoryDefinitionUpdate_t callback is triggered whenever item definitions have been updated, which could be in response to LoadItemDefinitions() or any other async request which required a definition update in order to process results from the server. |
| `OnSteamInventoryEligiblePromoItemDefIDs` | 4703 | [`SteamInventoryEligiblePromoItemDefIDs_t`](#steaminventoryeligiblepromoitemdefids_t) | Returned. |
| `OnSteamInventoryStartPurchaseResult` | 4704 | [`SteamInventoryStartPurchaseResult_t`](#steaminventorystartpurchaseresult_t) | Triggered from StartPurchase call. |
| `OnSteamInventoryRequestPricesResult` | 4705 | [`SteamInventoryRequestPricesResult_t`](#steaminventoryrequestpricesresult_t) | Triggered from RequestPrices. |

Handler signature (the IDE generates it when you double-click the event):

```pascal
procedure TForm1.SteamInventory1SteamInventoryResultReady(Sender: TObject; const AData: SteamInventoryResultReady_t);
```

## The plug-in: TSteamInventoryPlugin

ISteamInventory plug-in. Registered by linking the unit; find it with @code(Steam.FindPlugin(TSteamInventoryPlugin)).

Reach it through the component (`SteamInventory1.Plugin`) or the core:

```pascal
P := TSteamInventoryPlugin(Steam.FindPlugin(TSteamInventoryPlugin));   // Delphi also: Steam.Plugin<TSteamInventoryPlugin>
if P <> nil then ...
```

Every flat export is bound as optional: calling a method whose export the loaded
Steam library lacks raises `ESteamworksError` naming the export (`Assigned(P.Flat.Xxx)`
tells beforehand). Method names follow Valve's flat API (`GetStatInt32`, not the C++
overload `GetStat`); `const char*` parameters are `string`, 64-bit Steam ids `TSteamID`,
single out-values `var`; buffers and NULL-able pointers stay `Pointer`.

### Methods

| Method | Summary |
|--------|---------|
| [`GetResultStatus`](#getresultstatus) | Find out the status of an asynchronous inventory result handle. Possible values: k_EResultPending - still in progress k_EResultOK - done, result ready ... |
| [`GetResultItems`](#getresultitems) | Copies the contents of a result set into a flat array. The specific contents of the result set depend on which query which was used. |
| [`GetResultItemProperty`](#getresultitemproperty) | In combination with GetResultItems, you can use GetResultItemProperty to retrieve dynamic string properties for a given item returned in the result set. ... |
| [`GetResultTimestamp`](#getresulttimestamp) | Returns the server time at which the result was generated. Compare against the value of IClientUtils::GetServerRealTime() to determine age. |
| [`CheckResultSteamID`](#checkresultsteamid) | Returns true if the result belongs to the target steam ID, false if the result does not. This is important when using DeserializeResult, to verify that a ... |
| [`DestroyResult`](#destroyresult) | Destroys a result handle and frees all associated memory. |
| [`GetAllItems`](#getallitems) | Captures the entire state of the current user's Steam inventory. You must call DestroyResult on this handle when you are done with it. Returns false and ... |
| [`GetItemsByID`](#getitemsbyid) | Captures the state of a subset of the current user's Steam inventory, identified by an array of item instance IDs. The results from this call can be ... |
| [`SerializeResult`](#serializeresult) | Serializes a result set with signature bytes to an output buffer. Pass NULL as an output buffer to get the required size via punOutBufferSize. The size of a ... |
| [`DeserializeResult`](#deserializeresult) | Deserializes a result set and verifies the signature bytes. Returns false if bRequireFullOnlineVerify is set but Steam is running in Offline mode. Otherwise ... |
| [`GenerateItems`](#generateitems) | GenerateItems() creates one or more items and then generates a SteamInventoryCallback_t notification with a matching nCallbackContext parameter. This API is ... |
| [`GrantPromoItems`](#grantpromoitems) | GrantPromoItems() checks the list of promotional items for which the user may be eligible and grants the items (one time only). On success, the result set ... |
| [`AddPromoItem`](#addpromoitem) | AddPromoItem() / AddPromoItems() are restricted versions of GrantPromoItems(). Instead of scanning for all eligible promotional items, the check is ... |
| [`AddPromoItems`](#addpromoitems) | Wraps `SteamAPI_ISteamInventory_AddPromoItems`. |
| [`ConsumeItem`](#consumeitem) | ConsumeItem() removes items from the inventory, permanently. They cannot be recovered. Not for the faint of heart - if your game implements item removal at ... |
| [`ExchangeItems`](#exchangeitems) | ExchangeItems() is an atomic combination of item generation and consumption. It can be used to implement crafting recipes or transmutations, or items which ... |
| [`TransferItemQuantity`](#transferitemquantity) | TransferItemQuantity() is intended for use with items which are "stackable" (can have quantity greater than one). It can be used to split a stack into two, ... |
| [`SendItemDropHeartbeat`](#senditemdropheartbeat) | Deprecated. Calling this method is not required for proper playtime accounting. |
| [`TriggerItemDrop`](#triggeritemdrop) | Playtime credit must be consumed and turned into item drops by your game. Only item definitions which are marked as "playtime item generators" can be ... |
| [`TradeItems`](#tradeitems) | Deprecated. This method is not supported. |
| [`LoadItemDefinitions`](#loaditemdefinitions) | LoadItemDefinitions triggers the automatic load and refresh of item definitions. Every time new item definitions are available (eg, from the dynamic ... |
| [`GetItemDefinitionIDs`](#getitemdefinitionids) | GetItemDefinitionIDs returns the set of all defined item definition IDs (which are defined via Steamworks configuration, and not necessarily contiguous ... |
| [`GetItemDefinitionProperty`](#getitemdefinitionproperty) | GetItemDefinitionProperty returns a string property from a given item definition. Note that some properties (for example, "name") may be localized and will ... |
| [`RequestEligiblePromoItemDefinitionsIDs`](#requesteligiblepromoitemdefinitionsids) | Request the list of "eligible" promo items that can be manually granted to the given user. These are promo items of type "manual" that won't be granted ... |
| [`GetEligiblePromoItemDefinitionIDs`](#geteligiblepromoitemdefinitionids) | After handling a SteamInventoryEligiblePromoItemDefIDs_t call result, use this function to pull out the list of item definition ids that the user can be ... |
| [`StartPurchase`](#startpurchase) | Starts the purchase process for the given item definitions. The callback SteamInventoryStartPurchaseResult_t will be posted if Steam was able to initialize ... |
| [`RequestPrices`](#requestprices) | Request current prices for all applicable item definitions. Call result: `SteamInventoryRequestPricesResult_t` ... |
| [`GetNumItemsWithPrices`](#getnumitemswithprices) | Returns the number of items with prices. Need to call RequestPrices() first. |
| [`GetItemsWithPrices`](#getitemswithprices) | Returns item definition ids and their prices in the user's local currency. Need to call RequestPrices() first. |
| [`GetItemPrice`](#getitemprice) | Retrieves the price for the item definition id Returns false if there is no price stored for the item definition. |
| [`StartUpdateProperties`](#startupdateproperties) | Create a request to update properties on items. |
| [`RemoveProperty`](#removeproperty) | Remove the property on the item. |
| [`SetPropertyString`](#setpropertystring) | Wraps `SteamAPI_ISteamInventory_SetPropertyString`. |
| [`SetPropertyBool`](#setpropertybool) | Wraps `SteamAPI_ISteamInventory_SetPropertyBool`. |
| [`SetPropertyInt64`](#setpropertyint64) | Wraps `SteamAPI_ISteamInventory_SetPropertyInt64`. |
| [`SetPropertyFloat`](#setpropertyfloat) | Wraps `SteamAPI_ISteamInventory_SetPropertyFloat`. |
| [`SubmitUpdateProperties`](#submitupdateproperties) | Submit the update request by handle. |
| [`InspectItem`](#inspectitem) | Wraps `SteamAPI_ISteamInventory_InspectItem`. |

#### GetResultStatus

```pascal
function GetResultStatus(resultHandle: SteamInventoryResult_t): EResult;
```

Find out the status of an asynchronous inventory result handle. Possible values: k_EResultPending - still in progress k_EResultOK - done, result ready k_EResultExpired - done, result ready, maybe out of date (see DeserializeResult) k_EResultInvalidParam - ERROR: invalid API call parameters k_EResultServiceUnavailable - ERROR: service temporarily down, you may retry later k_EResultLimitExceeded - ERROR: operation would exceed per-user inventory limits k_EResultFail - ERROR: unknown / generic error.

#### GetResultItems

```pascal
function GetResultItems(resultHandle: SteamInventoryResult_t; pOutItemsArray: Pointer; var punOutItemsArraySize: UInt32): Boolean;
```

Copies the contents of a result set into a flat array. The specific contents of the result set depend on which query which was used.

#### GetResultItemProperty

```pascal
function GetResultItemProperty(resultHandle: SteamInventoryResult_t; unItemIndex: UInt32; const pchPropertyName: string; pchValueBuffer: PAnsiChar; var punValueBufferSizeOut: UInt32): Boolean;
```

In combination with GetResultItems, you can use GetResultItemProperty to retrieve dynamic string properties for a given item returned in the result set. Property names are always composed of ASCII letters, numbers, and/or underscores. Pass a NULL pointer for pchPropertyName to get a comma - separated list of available property names. If pchValueBuffer is NULL, *punValueBufferSize will contain the suggested buffer size. Otherwise it will be the number of bytes actually copied to pchValueBuffer. If the results do not fit in the given buffer, partial results may be copied.

#### GetResultTimestamp

```pascal
function GetResultTimestamp(resultHandle: SteamInventoryResult_t): UInt32;
```

Returns the server time at which the result was generated. Compare against the value of IClientUtils::GetServerRealTime() to determine age.

#### CheckResultSteamID

```pascal
function CheckResultSteamID(resultHandle: SteamInventoryResult_t; const steamIDExpected: TSteamID): Boolean;
```

Returns true if the result belongs to the target steam ID, false if the result does not. This is important when using DeserializeResult, to verify that a remote player is not pretending to have a different user's inventory.

#### DestroyResult

```pascal
procedure DestroyResult(resultHandle: SteamInventoryResult_t);
```

Destroys a result handle and frees all associated memory.

#### GetAllItems

```pascal
function GetAllItems(var pResultHandle: SteamInventoryResult_t): Boolean;
```

Captures the entire state of the current user's Steam inventory. You must call DestroyResult on this handle when you are done with it. Returns false and sets *pResultHandle to zero if inventory is unavailable. Note: calls to this function are subject to rate limits and may return cached results if called too frequently. It is suggested that you call this function only when you are about to display the user's full inventory, or if you expect that the inventory may have changed.

#### GetItemsByID

```pascal
function GetItemsByID(var pResultHandle: SteamInventoryResult_t; pInstanceIDs: Pointer; unCountInstanceIDs: UInt32): Boolean;
```

Captures the state of a subset of the current user's Steam inventory, identified by an array of item instance IDs. The results from this call can be serialized and passed to other players to "prove" that the current user owns specific items, without exposing the user's entire inventory. For example, you could call GetItemsByID with the IDs of the user's currently equipped cosmetic items and serialize this to a buffer, and then transmit this buffer to other players upon joining a game.

#### SerializeResult

```pascal
function SerializeResult(resultHandle: SteamInventoryResult_t; pOutBuffer: Pointer; var punOutBufferSize: UInt32): Boolean;
```

Serializes a result set with signature bytes to an output buffer. Pass NULL as an output buffer to get the required size via punOutBufferSize. The size of a serialized result depends on the number items which are being serialized. When securely transmitting items to other players, it is recommended to use "GetItemsByID" first to create a minimal result set. Results have a built-in timestamp which will be considered "expired" after an hour has elapsed. See DeserializeResult for expiration handling.

#### DeserializeResult

```pascal
function DeserializeResult(var pOutResultHandle: SteamInventoryResult_t; pBuffer: Pointer; unBufferSize: UInt32; bRESERVED_MUST_BE_FALSE: Boolean): Boolean;
```

Deserializes a result set and verifies the signature bytes. Returns false if bRequireFullOnlineVerify is set but Steam is running in Offline mode. Otherwise returns true and then delivers error codes via GetResultStatus. The bRESERVED_MUST_BE_FALSE flag is reserved for future use and should not be set to true by your game at this time. DeserializeResult has a potential soft-failure mode where the handle status is set to k_EResultExpired. GetResultItems() still succeeds in this mode. The "expired" result could indicate that the data may be out of date - not just due to timed expiration (one hour), but also because one of the items in the result set may have been traded or consumed since the result set was generated. You could compare the timestamp from GetResultTimestamp() to ISteamUtils::GetServerRealTime() to determine how old the data is. You could simply ignore the "expired" result code and continue as normal, or you could challenge the player with expired data to send an updated result set.

#### GenerateItems

```pascal
function GenerateItems(var pResultHandle: SteamInventoryResult_t; pArrayItemDefs: Pointer; punArrayQuantity: Pointer; unArrayLength: UInt32): Boolean;
```

GenerateItems() creates one or more items and then generates a SteamInventoryCallback_t notification with a matching nCallbackContext parameter. This API is only intended for prototyping - it is only usable by Steam accounts that belong to the publisher group for your game. If punArrayQuantity is not NULL, it should be the same length as pArrayItems and should describe the quantity of each item to generate.

#### GrantPromoItems

```pascal
function GrantPromoItems(var pResultHandle: SteamInventoryResult_t): Boolean;
```

GrantPromoItems() checks the list of promotional items for which the user may be eligible and grants the items (one time only). On success, the result set will include items which were granted, if any. If no items were granted because the user isn't eligible for any promotions, this is still considered a success.

#### AddPromoItem

```pascal
function AddPromoItem(var pResultHandle: SteamInventoryResult_t; itemDef: SteamItemDef_t): Boolean;
```

AddPromoItem() / AddPromoItems() are restricted versions of GrantPromoItems(). Instead of scanning for all eligible promotional items, the check is restricted to a single item definition or set of item definitions. This can be useful if your game has custom UI for showing a specific promo item to the user.

#### AddPromoItems

```pascal
function AddPromoItems(var pResultHandle: SteamInventoryResult_t; pArrayItemDefs: Pointer; unArrayLength: UInt32): Boolean;
```

Wraps `SteamAPI_ISteamInventory_AddPromoItems`.

#### ConsumeItem

```pascal
function ConsumeItem(var pResultHandle: SteamInventoryResult_t; itemConsume: SteamItemInstanceID_t; unQuantity: UInt32): Boolean;
```

ConsumeItem() removes items from the inventory, permanently. They cannot be recovered. Not for the faint of heart - if your game implements item removal at all, a high-friction UI confirmation process is highly recommended.

#### ExchangeItems

```pascal
function ExchangeItems(var pResultHandle: SteamInventoryResult_t; pArrayGenerate: Pointer; punArrayGenerateQuantity: Pointer; unArrayGenerateLength: UInt32; pArrayDestroy: Pointer; punArrayDestroyQuantity: Pointer; unArrayDestroyLength: UInt32): Boolean;
```

ExchangeItems() is an atomic combination of item generation and consumption. It can be used to implement crafting recipes or transmutations, or items which unpack themselves into other items (e.g., a chest). Exchange recipes are defined in the ItemDef, and explicitly list the required item types and resulting generated type. Exchange recipes are evaluated atomically by the Inventory Service; if the supplied components do not match the recipe, or do not contain sufficient quantity, the exchange will fail.

#### TransferItemQuantity

```pascal
function TransferItemQuantity(var pResultHandle: SteamInventoryResult_t; itemIdSource: SteamItemInstanceID_t; unQuantity: UInt32; itemIdDest: SteamItemInstanceID_t): Boolean;
```

TransferItemQuantity() is intended for use with items which are "stackable" (can have quantity greater than one). It can be used to split a stack into two, or to transfer quantity from one stack into another stack of identical items. To split one stack into two, pass k_SteamItemInstanceIDInvalid for itemIdDest and a new item will be generated.

#### SendItemDropHeartbeat

```pascal
procedure SendItemDropHeartbeat;
```

Deprecated. Calling this method is not required for proper playtime accounting.

#### TriggerItemDrop

```pascal
function TriggerItemDrop(var pResultHandle: SteamInventoryResult_t; dropListDefinition: SteamItemDef_t): Boolean;
```

Playtime credit must be consumed and turned into item drops by your game. Only item definitions which are marked as "playtime item generators" can be spawned. The call will return an empty result set if there is not enough playtime credit for a drop. Your game should call TriggerItemDrop at an appropriate time for the user to receive new items, such as between rounds or while the player is dead. Note that players who hack their clients could modify the value of "dropListDefinition", so do not use it to directly control rarity. See your Steamworks configuration to set playtime drop rates for individual itemdefs. The client library will suppress too-frequent calls to this method.

#### TradeItems

```pascal
function TradeItems(var pResultHandle: SteamInventoryResult_t; const steamIDTradePartner: TSteamID; pArrayGive: Pointer; pArrayGiveQuantity: Pointer; nArrayGiveLength: UInt32; pArrayGet: Pointer; pArrayGetQuantity: Pointer; nArrayGetLength: UInt32): Boolean;
```

Deprecated. This method is not supported.

#### LoadItemDefinitions

```pascal
function LoadItemDefinitions: Boolean;
```

LoadItemDefinitions triggers the automatic load and refresh of item definitions. Every time new item definitions are available (eg, from the dynamic addition of new item types while players are still in-game), a SteamInventoryDefinitionUpdate_t callback will be fired.

#### GetItemDefinitionIDs

```pascal
function GetItemDefinitionIDs(pItemDefIDs: Pointer; var punItemDefIDsArraySize: UInt32): Boolean;
```

GetItemDefinitionIDs returns the set of all defined item definition IDs (which are defined via Steamworks configuration, and not necessarily contiguous integers). If pItemDefIDs is null, the call will return true and *punItemDefIDsArraySize will contain the total size necessary for a subsequent call. Otherwise, the call will return false if and only if there is not enough space in the output array.

#### GetItemDefinitionProperty

```pascal
function GetItemDefinitionProperty(iDefinition: SteamItemDef_t; const pchPropertyName: string; pchValueBuffer: PAnsiChar; var punValueBufferSizeOut: UInt32): Boolean;
```

GetItemDefinitionProperty returns a string property from a given item definition. Note that some properties (for example, "name") may be localized and will depend on the current Steam language settings (see ISteamApps::GetCurrentGameLanguage). Property names are always composed of ASCII letters, numbers, and/or underscores. Pass a NULL pointer for pchPropertyName to get a comma - separated list of available property names. If pchValueBuffer is NULL, *punValueBufferSize will contain the suggested buffer size. Otherwise it will be the number of bytes actually copied to pchValueBuffer. If the results do not fit in the given buffer, partial results may be copied.

#### RequestEligiblePromoItemDefinitionsIDs

```pascal
function RequestEligiblePromoItemDefinitionsIDs(const steamID: TSteamID): SteamAPICall_t;
```

Request the list of "eligible" promo items that can be manually granted to the given user. These are promo items of type "manual" that won't be granted automatically. An example usage of this is an item that becomes available every week. Call result: `SteamInventoryEligiblePromoItemDefIDs_t` (`SteamInventoryEligiblePromoItemDefIDs_t_k_iCallback`).

#### GetEligiblePromoItemDefinitionIDs

```pascal
function GetEligiblePromoItemDefinitionIDs(const steamID: TSteamID; pItemDefIDs: Pointer; var punItemDefIDsArraySize: UInt32): Boolean;
```

After handling a SteamInventoryEligiblePromoItemDefIDs_t call result, use this function to pull out the list of item definition ids that the user can be manually granted via the AddPromoItems() call.

#### StartPurchase

```pascal
function StartPurchase(pArrayItemDefs: Pointer; punArrayQuantity: Pointer; unArrayLength: UInt32): SteamAPICall_t;
```

Starts the purchase process for the given item definitions. The callback SteamInventoryStartPurchaseResult_t will be posted if Steam was able to initialize the transaction. Once the purchase has been authorized and completed by the user, the callback SteamInventoryResultReady_t will be posted. Call result: `SteamInventoryStartPurchaseResult_t` (`SteamInventoryStartPurchaseResult_t_k_iCallback`).

#### RequestPrices

```pascal
function RequestPrices: SteamAPICall_t;
```

Request current prices for all applicable item definitions. Call result: `SteamInventoryRequestPricesResult_t` (`SteamInventoryRequestPricesResult_t_k_iCallback`).

#### GetNumItemsWithPrices

```pascal
function GetNumItemsWithPrices: UInt32;
```

Returns the number of items with prices. Need to call RequestPrices() first.

#### GetItemsWithPrices

```pascal
function GetItemsWithPrices(pArrayItemDefs: Pointer; pCurrentPrices: Pointer; pBasePrices: Pointer; unArrayLength: UInt32): Boolean;
```

Returns item definition ids and their prices in the user's local currency. Need to call RequestPrices() first.

#### GetItemPrice

```pascal
function GetItemPrice(iDefinition: SteamItemDef_t; var pCurrentPrice: UInt64; var pBasePrice: UInt64): Boolean;
```

Retrieves the price for the item definition id Returns false if there is no price stored for the item definition.

#### StartUpdateProperties

```pascal
function StartUpdateProperties: SteamInventoryUpdateHandle_t;
```

Create a request to update properties on items.

#### RemoveProperty

```pascal
function RemoveProperty(AHandle: SteamInventoryUpdateHandle_t; nItemID: SteamItemInstanceID_t; const pchPropertyName: string): Boolean;
```

Remove the property on the item.

#### SetPropertyString

```pascal
function SetPropertyString(AHandle: SteamInventoryUpdateHandle_t; nItemID: SteamItemInstanceID_t; const pchPropertyName: string; const pchPropertyValue: string): Boolean;
```

Wraps `SteamAPI_ISteamInventory_SetPropertyString`.

#### SetPropertyBool

```pascal
function SetPropertyBool(AHandle: SteamInventoryUpdateHandle_t; nItemID: SteamItemInstanceID_t; const pchPropertyName: string; bValue: Boolean): Boolean;
```

Wraps `SteamAPI_ISteamInventory_SetPropertyBool`.

#### SetPropertyInt64

```pascal
function SetPropertyInt64(AHandle: SteamInventoryUpdateHandle_t; nItemID: SteamItemInstanceID_t; const pchPropertyName: string; nValue: Int64): Boolean;
```

Wraps `SteamAPI_ISteamInventory_SetPropertyInt64`.

#### SetPropertyFloat

```pascal
function SetPropertyFloat(AHandle: SteamInventoryUpdateHandle_t; nItemID: SteamItemInstanceID_t; const pchPropertyName: string; flValue: Single): Boolean;
```

Wraps `SteamAPI_ISteamInventory_SetPropertyFloat`.

#### SubmitUpdateProperties

```pascal
function SubmitUpdateProperties(AHandle: SteamInventoryUpdateHandle_t; var pResultHandle: SteamInventoryResult_t): Boolean;
```

Submit the update request by handle.

#### InspectItem

```pascal
function InspectItem(var pResultHandle: SteamInventoryResult_t; const pchItemToken: string): Boolean;
```

Wraps `SteamAPI_ISteamInventory_InspectItem`.

### Async methods

Each `...Async` method starts the call and registers `AHandler` for its result
(`procedure(const AData: TSteamCallbackData; AIOFailure: Boolean) of object`). The
handler runs once, on the delivery thread, with the result record in `AData`
(`AData.CopyTo(Rec, SizeOf(Rec))`); its object owns the registration - call
`Steam.Dispatcher.RemoveOwner(Self)` in that object's destructor. The plain method of
the same name returns the `SteamAPICall_t` instead, and its result reaches the
component's event.

#### RequestEligiblePromoItemDefinitionsIDsAsync

```pascal
function RequestEligiblePromoItemDefinitionsIDsAsync(const steamID: TSteamID; AHandler: TSteamCallResultEvent): SteamAPICall_t;
```

Calls `RequestEligiblePromoItemDefinitionsIDs` and registers AHandler for its result (`SteamInventoryEligiblePromoItemDefIDs_t`). The handler's object owns the registration (remove it with Plugin.Dispatcher.RemoveOwner). Returns: (The call handle, or k_uAPICallInvalid when Steam refused the call.)

#### StartPurchaseAsync

```pascal
function StartPurchaseAsync(pArrayItemDefs: Pointer; punArrayQuantity: Pointer; unArrayLength: UInt32; AHandler: TSteamCallResultEvent): SteamAPICall_t;
```

Calls `StartPurchase` and registers AHandler for its result (`SteamInventoryStartPurchaseResult_t`). The handler's object owns the registration (remove it with Plugin.Dispatcher.RemoveOwner). Returns: (The call handle, or k_uAPICallInvalid when Steam refused the call.)

#### RequestPricesAsync

```pascal
function RequestPricesAsync(AHandler: TSteamCallResultEvent): SteamAPICall_t;
```

Calls `RequestPrices` and registers AHandler for its result (`SteamInventoryRequestPricesResult_t`). The handler's object owns the registration (remove it with Plugin.Dispatcher.RemoveOwner). Returns: (The call handle, or k_uAPICallInvalid when Steam refused the call.)

### Properties

| Property | Description |
|----------|-------------|
| `Handle: Pointer` | The raw ISteamInventory pointer (first argument of every `Flat` export). |
| `Flat: TSteamInventoryFlat` | The bound flat exports, for calls the methods do not cover. |

## Payload records

Declared in `Steamworks.SDKTypes` (generated from the SDK headers; layouts verified
against the C headers for Win64, Win32, Linux64 and macOS ARM64).

### SteamInventoryResultReady_t

Callback id 4700 (`SteamInventoryResultReady_t_k_iCallback`).

| Field | C declaration |
|-------|---------------|
| `m_handle: SteamInventoryResult_t` | C field `SteamInventoryResult_t m_handle`. |
| `m_result: EResult` | C field `EResult m_result`. |

### SteamInventoryFullUpdate_t

Callback id 4701 (`SteamInventoryFullUpdate_t_k_iCallback`).

| Field | C declaration |
|-------|---------------|
| `m_handle: SteamInventoryResult_t` | C field `SteamInventoryResult_t m_handle`. |

### SteamInventoryDefinitionUpdate_t

Callback id 4702 (`SteamInventoryDefinitionUpdate_t_k_iCallback`).

| Field | C declaration |
|-------|---------------|
| `_dummy: Byte` | Placeholder: the C++ struct is empty (sizeof = 1). |

### SteamInventoryEligiblePromoItemDefIDs_t

Callback id 4703 (`SteamInventoryEligiblePromoItemDefIDs_t_k_iCallback`).

| Field | C declaration |
|-------|---------------|
| `m_result: EResult` | C field `EResult m_result`. |
| `m_steamID: TSteamID` | C field `CSteamID m_steamID`. |
| `m_numEligiblePromoItemDefs: Integer` | C field `int m_numEligiblePromoItemDefs`. |
| `m_bCachedData: Boolean` | C field `bool m_bCachedData`. |

### SteamInventoryStartPurchaseResult_t

Callback id 4704 (`SteamInventoryStartPurchaseResult_t_k_iCallback`).

| Field | C declaration |
|-------|---------------|
| `m_result: EResult` | C field `EResult m_result`. |
| `m_ulOrderID: UInt64` | C field `uint64 m_ulOrderID`. |
| `m_ulTransID: UInt64` | C field `uint64 m_ulTransID`. |

### SteamInventoryRequestPricesResult_t

Callback id 4705 (`SteamInventoryRequestPricesResult_t_k_iCallback`).

| Field | C declaration |
|-------|---------------|
| `m_result: EResult` | C field `EResult m_result`. |
| `m_rgchCurrency: array[0..3] of AnsiChar` | C field `char [4] m_rgchCurrency`. |
