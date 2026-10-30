{ @abstract(Callback and call-result dispatcher built on Steam's manual
  dispatch API (SteamAPI_ManualDispatch_*).)

  It replaces the C++ CCallback / CCallResult templates, which cannot be used
  from Pascal.

  @definitionList(
    @itemLabel(Callbacks)
    @item(Broadcast notifications identified by the struct's k_iCallback,
      e.g. 704 SteamShutdown_t. Any number of subscribers.)
    @itemLabel(Call results)
    @item(The reply to one async call (a SteamAPICall_t). One handler, removed
      after it fires.)
  )

  The portable API uses method pointers (@code(of object)), which work with
  Delphi and FPC 3.2. When the compiler supports anonymous methods
  (STEAMWORKS_ANONYMOUS_METHODS) closure-based and generic typed overloads are
  available too.

  @bold(Threading.) Steam's queue is drained by ONE thread at a time, in one
  of two ways:
  @unorderedList(
    @item(@link(TSteamCallbackDispatcher.Pump) drains it and delivers every
      callback at once, on the calling thread (timer or game-loop pumping).)
    @item(@link(TSteamCallbackDispatcher.PumpToQueue) drains it on a worker
      thread and copies every payload (call results are fetched there too);
      @link(TSteamCallbackDispatcher.DeliverQueued) later delivers the copies
      on whichever thread calls it - normally the main or game thread.)
  )
  Subscribing, unsubscribing and awaiting call results are safe from any
  thread (the lists are locked); handlers always run outside the lock.
  TSteamworks chooses between the two (see its UpdateMode and Delivery).

  Example (method pointers - Delphi and FPC):
  @longCode(#
  procedure TMyGame.SteamShutdown(const AData: TSteamCallbackData);
  begin
    SaveAndQuit;
  end;
  ...
  Steam.Dispatcher.Subscribe(SteamShutdown_t_k_iCallback, SteamShutdown);
  ...
  Steam.Dispatcher.RemoveOwner(Self);   // in the destructor
  #) }
unit Steamworks.Callbacks;

{$I Steamworks.inc}

interface

uses
  SysUtils, Classes, SyncObjs, Generics.Collections,
  Steamworks.Types;

type
  { Opaque token returned by the Subscribe methods; pass it to
    @link(TSteamCallbackDispatcher.Unsubscribe). 0 means "none". }
  TSteamSubscription = Int64;

  { Everything known about one delivered callback or call result. }
  TSteamCallbackData = record
    { k_iCallback of the payload struct. }
    CallbackID: Integer;
    { Payload. Valid only while the handler runs - copy what you need. }
    Data: Pointer;
    { Payload size in bytes. }
    Size: Integer;
    { User the callback applies to. }
    User: HSteamUser;
    { Non-zero for call results. }
    APICall: SteamAPICall_t;
    { @true if this is the reply to an async call. }
    IsCallResult: Boolean;
    { Call results only: @true if the call failed (Data may then be @nil). }
    IOFailure: Boolean;
    { Copies the payload into ABuffer (zero-filled first). Copies at most
      ABufferSize bytes. @returns(@false if there is no payload.)
      @longCode(#
      var Ev: LowBatteryPower_t;
      if AData.CopyTo(Ev, SizeOf(Ev)) then ...
      #) }
    function CopyTo(out ABuffer; ABufferSize: Integer): Boolean;
    {$ifdef STEAMWORKS_ANONYMOUS_METHODS}
    { Generic form of @link(CopyTo): @code(AData.AsRecord<LowBatteryPower_t>). }
    function AsRecord<T>: T;
    {$endif}
  end;

  { Handler for broadcast callbacks. }
  TSteamCallbackEvent = procedure(const AData: TSteamCallbackData) of object;
  { Handler for call results. AIOFailure duplicates AData.IOFailure. }
  TSteamCallResultEvent = procedure(const AData: TSteamCallbackData; AIOFailure: Boolean) of object;
  { Raised when a handler throws. Set AHandled to @true to swallow the exception. }
  TSteamHandlerErrorEvent = procedure(Sender: TObject; E: Exception; ACallbackID: Integer;
    var AHandled: Boolean) of object;

  {$ifdef STEAMWORKS_ANONYMOUS_METHODS}
  { Closure handler for broadcast callbacks (anonymous-method compilers only). }
  TSteamCallbackProc = reference to procedure(const AData: TSteamCallbackData);
  { Closure handler for call results (anonymous-method compilers only). }
  TSteamCallResultProc = reference to procedure(const AData: TSteamCallbackData; AIOFailure: Boolean);
  { Typed closure handler; T is the SDK struct (anonymous-method compilers only). }
  TSteamCallbackHandler<T> = reference to procedure(const AData: T);
  { Typed closure call-result handler (anonymous-method compilers only). }
  TSteamCallResultHandler<T> = reference to procedure(const AData: T; AIOFailure: Boolean);
  {$endif}

  { @exclude Internal subscription entry. }
  TSteamSubscriptionEntry = record
    { Token returned to the subscriber. }
    Token: TSteamSubscription;
    { Callback id subscribed to. }
    CallbackID: Integer;
    { Object that owns the entry, for @link(TSteamCallbackDispatcher.RemoveOwner). }
    Owner: TObject;
    { Method handler (@nil when a closure is used). }
    Handler: TSteamCallbackEvent;
    {$ifdef STEAMWORKS_ANONYMOUS_METHODS}
    { Closure handler (@nil when a method is used). }
    Proc: TSteamCallbackProc;
    {$endif}
    { Also deliver unclaimed call results with this id. }
    IncludeCallResults: Boolean;
  end;
  { @exclude Internal pending call-result entry. }
  TSteamPendingCallEntry = record
    { Callback id the result struct must have. }
    Expected: Integer;
    { Object that owns the entry, for @link(TSteamCallbackDispatcher.RemoveOwner). }
    Owner: TObject;
    { Method handler (@nil when a closure is used). }
    Handler: TSteamCallResultEvent;
    {$ifdef STEAMWORKS_ANONYMOUS_METHODS}
    { Closure handler (@nil when a method is used). }
    Proc: TSteamCallResultProc;
    {$endif}
  end;
  { One callback or call result copied off Steam's queue by
    @link(TSteamCallbackDispatcher.PumpToQueue), waiting for
    @link(TSteamCallbackDispatcher.DeliverQueued). A class, not a record:
    records in lib/ must not hold managed fields (see Steamworks.inc). }
  TSteamQueuedCallback = class
  public
    { k_iCallback of the payload struct. }
    CallbackID: Integer;
    { User the callback applies to. }
    User: HSteamUser;
    { Call results only: the async call handle. }
    APICall: SteamAPICall_t;
    { @true for the reply to an async call (fetched on the pump thread). }
    IsCallResult: Boolean;
    { Call results only: SteamAPI_ManualDispatch_GetAPICallResult succeeded. }
    FetchOk: Boolean;
    { Call results only: Steam reported a failure (or the fetch failed). }
    IOFailure: Boolean;
    { Payload size in bytes as Steam reported it. }
    Size: Integer;
    { Copy of the payload (at least one byte long, so @code(@@Payload[0]) is valid). }
    Payload: TBytes;
    { The copy as a @link(TSteamCallbackData); its Data points into
      @link(Payload), so it is valid while this object lives. }
    function AsData: TSteamCallbackData;
  end;

  { Routes Steam callbacks and call results to subscribers.
    Normally owned by @code(TSteamworks); use @code(Steam.Dispatcher). }
  TSteamCallbackDispatcher = class
  private
    { All subscriptions, in subscription order. Guarded by @link(FLock). }
    FSubs: TList<TSteamSubscriptionEntry>;
    { Awaited call results by call handle. Guarded by @link(FLock). }
    FPending: TDictionary<SteamAPICall_t, TSteamPendingCallEntry>;
    { Last token issued. Guarded by @link(FLock). }
    FNextToken: TSteamSubscription;
    { Guards @link(FSubs), @link(FPending) and @link(FNextToken); never held
      while a handler runs. }
    FLock: SyncObjs.TCriticalSection;
    { Copies made by @link(PumpToQueue), oldest first. Guarded by @link(FQueueLock). }
    FQueue: TList<TSteamQueuedCallback>;
    { Guards @link(FQueue). }
    FQueueLock: SyncObjs.TCriticalSection;
    { @true while @link(Pump) runs (re-entrancy guard). }
    FPumping: Boolean;
    { @true while @link(PumpToQueue) runs (re-entrancy guard). }
    FQueuePumping: Boolean;
    { @true while @link(DeliverQueued) runs (re-entrancy guard). }
    FDelivering: Boolean;
    { Thread running @link(Pump) or @link(DeliverQueued), i.e. the thread
      whose handlers are running. }
    FHandlerThread: TThreadID;
    { Set by @link(RequestStop); ends the current pump early. }
    FStopRequested: Boolean;
    { Backing field of @link(OnHandlerError). }
    FOnHandlerError: TSteamHandlerErrorEvent;
    { Backing field of @link(OnAnyCallback). }
    FOnAnyCallback: TSteamCallbackEvent;
    { Backing field of @link(CallbacksDispatched). }
    FCallbacksDispatched: Int64;
    { Read accessor of @link(Pumping). }
    function GetPumping: Boolean;
    { Stores a subscription and returns its new token. }
    function AddSub(const ASub: TSteamSubscriptionEntry): TSteamSubscription;
    { Index of a subscription in @link(FSubs), or -1. Caller holds @link(FLock). }
    function IndexOfToken(AToken: TSteamSubscription): Integer;
    { @true while the subscription AToken still exists (takes the lock). }
    function TokenAlive(AToken: TSteamSubscription): Boolean;
    { Hands one callback to @link(OnAnyCallback) and matching subscribers. }
    procedure Deliver(const AData: TSteamCallbackData);
    { Processes SteamAPICallCompleted_t: fetches the result and completes the awaiting handler. }
    procedure HandleCallCompleted(APipe: HSteamPipe; const AMsg: CallbackMsg_t);
    { Removes and returns the handler awaiting ACall.
      @returns(@false if nobody awaits it.) }
    function TakePending(ACall: SteamAPICall_t; out APending: TSteamPendingCallEntry): Boolean;
    { Hands a fetched call result to its awaiting handler (AHasPending) or,
      if it was fetched successfully (AFetchOk), to the subscribers that
      asked for unclaimed results. }
    procedure CompleteCallResult(AHasPending: Boolean; const APending: TSteamPendingCallEntry;
      const AData: TSteamCallbackData; AFetchOk: Boolean);
    { Appends one copy to @link(FQueue) (takes the queue lock). }
    procedure Enqueue(AItem: TSteamQueuedCallback);
    { Puts ABatch[AFrom..] back at the front of @link(FQueue), in order, and
      nils those slots in ABatch. }
    procedure RequeueFront(ABatch: TList<TSteamQueuedCallback>; AFrom: Integer);
    { Detaches every queued copy (oldest first); @nil when the queue is empty. }
    function TakeQueue: TList<TSteamQueuedCallback>;
    { @true if a subscriber wants unclaimed call results of ACallbackID (takes the lock). }
    function HasCallResultSubscribers(ACallbackID: Integer): Boolean;
    { Routes a handler exception to @link(OnHandlerError). @returns(@true if handled.) }
    function HandleError(E: Exception; ACallbackID: Integer): Boolean;
    { Calls one subscription, routing exceptions to @link(HandleError). }
    procedure InvokeSub(const ASub: TSteamSubscriptionEntry; const AData: TSteamCallbackData);
    { Calls one call-result handler, routing exceptions to @link(HandleError). }
    procedure InvokePending(const APending: TSteamPendingCallEntry; const AData: TSteamCallbackData);
  public
    { Creates an empty dispatcher. }
    constructor Create;
    { Releases everything this object owns. }
    destructor Destroy; override;

    { Delivers all pending callbacks for APipe. Re-entrant calls are ignored.
      Requires SteamAPI_ManualDispatch_Init. FreeLastCallback is always called,
      even when a handler raises. }
    procedure Pump(APipe: HSteamPipe);

    { Drains Steam's queue for APipe WITHOUT delivering anything: every
      callback is copied, every completed call result is fetched and copied,
      and the copies wait for @link(DeliverQueued). Meant for a worker thread
      (TSteamworks' pump thread); runs no user code. Never run it at the same
      time as @link(Pump).
      @param(ASteamShutdown  Set to @true if SteamShutdown_t (704) was among
        the callbacks - the Steam client is exiting.)
      @returns(Number of copies queued.) }
    function PumpToQueue(APipe: HSteamPipe; out ASteamShutdown: Boolean): Integer;

    { Delivers the copies queued by @link(PumpToQueue), oldest first, on the
      calling thread. Re-entrant calls (from a handler) are ignored. If a
      handler raises and @link(OnHandlerError) does not handle it, the
      undelivered copies go back to the front of the queue and the exception
      propagates. @returns(Number of copies delivered.) }
    function DeliverQueued: Integer;

    { Frees every queued copy without delivering it (used by shutdown). }
    procedure ClearQueue;

    { Number of copies waiting for @link(DeliverQueued). }
    function QueuedCount: Integer;

    { @true if the calling thread is inside @link(Pump) or
      @link(DeliverQueued), i.e. it is running a handler. }
    function InHandlerOnCurrentThread: Boolean;

    { Stop a running @link(Pump) or @link(DeliverQueued) after the current
      callback (used by shutdown). Undelivered queued copies are kept;
      shutdown clears them. }
    procedure RequestStop;

    { Subscribes a method to a callback id. The method's object becomes the
      subscription owner (see @link(RemoveOwner)).
      @param(ACallbackID  k_iCallback of the struct, e.g. 704.)
      @param(AHandler  Method to call.)
      @param(AIncludeCallResults  Also receive call results of this id that
        nobody registered with @link(AwaitCallResult).)
      @returns(Token for @link(Unsubscribe), or 0 if AHandler is nil.) }
    function Subscribe(ACallbackID: Integer; AHandler: TSteamCallbackEvent;
      AIncludeCallResults: Boolean = False): TSteamSubscription;

    { Registers a one-shot handler for an async call.
      @param(ACall  Handle returned by the Steam function.)
      @param(AExpectedCallbackID  k_iCallback of the result struct. A different
        id is reported as an IO failure, never handed over as the wrong struct.)
      @returns(@false (nothing registered) when ACall is 0.)

      @longCode(#
      Call := F_RequestCurrentStats(FIntf);  // hypothetical flat call
      Steam.Dispatcher.AwaitCallResult(Call, 1101, StatsReceived);
      #) }
    function AwaitCallResult(ACall: SteamAPICall_t; AExpectedCallbackID: Integer;
      AHandler: TSteamCallResultEvent): Boolean;

    {$ifdef STEAMWORKS_ANONYMOUS_METHODS}
    { Closure version of @link(Subscribe). AOwner is used by @link(RemoveOwner). }
    function SubscribeProc(ACallbackID: Integer; const AProc: TSteamCallbackProc;
      AOwner: TObject = nil; AIncludeCallResults: Boolean = False): TSteamSubscription;
    { Typed closure subscription. T must mirror the SDK struct.
      @longCode(#
      Steam.Dispatcher.SubscribeTyped<LowBatteryPower_t>(702,
        procedure(const D: LowBatteryPower_t)
        begin
          ShowBatteryWarning(D.m_nMinutesBatteryLeft);
        end, Self);
      #) }
    function SubscribeTyped<T>(ACallbackID: Integer; const AHandler: TSteamCallbackHandler<T>;
      AOwner: TObject = nil): TSteamSubscription;
    { Closure version of @link(AwaitCallResult). }
    function AwaitCallResultProc(ACall: SteamAPICall_t; AExpectedCallbackID: Integer;
      const AProc: TSteamCallResultProc; AOwner: TObject = nil): Boolean;
    { Typed closure call result. }
    function AwaitCallResultTyped<T>(ACall: SteamAPICall_t; AExpectedCallbackID: Integer;
      const AHandler: TSteamCallResultHandler<T>; AOwner: TObject = nil): Boolean;
    {$endif}

    { Removes one subscription and sets AToken to 0. }
    procedure Unsubscribe(var AToken: TSteamSubscription);
    { Removes every subscription for a callback id. }
    procedure UnsubscribeAll(ACallbackID: Integer);
    { Removes every subscription and pending call result owned by AOwner.
      Call it from the destructor of any object that subscribed. }
    procedure RemoveOwner(AOwner: TObject);
    { Forgets a pending call result. }
    procedure CancelCallResult(ACall: SteamAPICall_t);
    { @true while a call result is awaited. }
    function IsCallResultPending(ACall: SteamAPICall_t): Boolean;
    { Number of call results awaited. }
    function PendingCallResultCount: Integer;
    { Drops every subscription and pending call result. }
    procedure Clear;

    { @true while @link(Pump) or @link(DeliverQueued) runs on any thread
      (handlers may be running). Use @link(InHandlerOnCurrentThread) to ask
      about the calling thread. }
    property Pumping: Boolean read GetPumping;
    { @true while @link(DeliverQueued) runs. }
    property Delivering: Boolean read FDelivering;
    { Number of callbacks delivered since creation. }
    property CallbacksDispatched: Int64 read FCallbacksDispatched;
    { Called for every callback before subscribers (diagnostics). }
    property OnAnyCallback: TSteamCallbackEvent read FOnAnyCallback write FOnAnyCallback;
    { Raised when a handler throws. If unassigned, or AHandled stays @false,
      the exception propagates out of @link(Pump) (after FreeLastCallback). }
    property OnHandlerError: TSteamHandlerErrorEvent read FOnHandlerError write FOnHandlerError;
  end;

implementation

uses
  Math,
  Steamworks.API;

{ TSteamCallbackData }

function TSteamCallbackData.CopyTo(out ABuffer; ABufferSize: Integer): Boolean;
begin
  FillChar(ABuffer, ABufferSize, 0);
  Result := (Data <> nil) and (Size > 0);
  if Result then
    Move(Data^, ABuffer, Min(Size, ABufferSize));
end;

{$ifdef STEAMWORKS_ANONYMOUS_METHODS}
function TSteamCallbackData.AsRecord<T>: T;
begin
  CopyTo(Result, SizeOf(T));
end;
{$endif}

{ TSteamQueuedCallback }

function TSteamQueuedCallback.AsData: TSteamCallbackData;
begin
  Result := Default(TSteamCallbackData);
  Result.CallbackID := CallbackID;
  Result.User := User;
  Result.APICall := APICall;
  Result.IsCallResult := IsCallResult;
  Result.IOFailure := IOFailure;
  if (not IsCallResult) or FetchOk then
  begin
    Result.Size := Size;
    if (Size > 0) and (Length(Payload) > 0) then
      Result.Data := @Payload[0];
  end;
end;

{ TSteamCallbackDispatcher }

constructor TSteamCallbackDispatcher.Create;
begin
  inherited Create;
  FSubs := TList<TSteamSubscriptionEntry>.Create;
  FPending := TDictionary<SteamAPICall_t, TSteamPendingCallEntry>.Create;
  FQueue := TList<TSteamQueuedCallback>.Create;
  // Qualified, as in Steamworks.Core: FPC's Windows unit has a record of that name
  FLock := SyncObjs.TCriticalSection.Create;
  FQueueLock := SyncObjs.TCriticalSection.Create;
end;

destructor TSteamCallbackDispatcher.Destroy;
begin
  if FQueue <> nil then
    ClearQueue;
  FQueue.Free;
  FPending.Free;
  FSubs.Free;
  FQueueLock.Free;
  FLock.Free;
  inherited;
end;

function TSteamCallbackDispatcher.GetPumping: Boolean;
begin
  Result := FPumping or FDelivering;
end;

procedure TSteamCallbackDispatcher.Clear;
begin
  FLock.Enter;
  try
    FSubs.Clear;
    FPending.Clear;
  finally
    FLock.Leave;
  end;
end;

function TSteamCallbackDispatcher.AddSub(const ASub: TSteamSubscriptionEntry): TSteamSubscription;
var
  S: TSteamSubscriptionEntry;
begin
  S := ASub;
  FLock.Enter;
  try
    Inc(FNextToken);
    S.Token := FNextToken;
    FSubs.Add(S);
  finally
    FLock.Leave;
  end;
  Result := S.Token;
end;

function TSteamCallbackDispatcher.IndexOfToken(AToken: TSteamSubscription): Integer;
var
  I: Integer;
begin
  for I := 0 to FSubs.Count - 1 do
    if FSubs[I].Token = AToken then
      Exit(I);
  Result := -1;
end;

function TSteamCallbackDispatcher.TokenAlive(AToken: TSteamSubscription): Boolean;
begin
  FLock.Enter;
  try
    Result := IndexOfToken(AToken) >= 0;
  finally
    FLock.Leave;
  end;
end;

function TSteamCallbackDispatcher.Subscribe(ACallbackID: Integer; AHandler: TSteamCallbackEvent;
  AIncludeCallResults: Boolean): TSteamSubscription;
var
  S: TSteamSubscriptionEntry;
begin
  if not Assigned(AHandler) then
    Exit(0);
  S := Default(TSteamSubscriptionEntry);
  S.CallbackID := ACallbackID;
  S.Handler := AHandler;
  S.Owner := TObject(TMethod(AHandler).Data);
  S.IncludeCallResults := AIncludeCallResults;
  Result := AddSub(S);
end;

function TSteamCallbackDispatcher.AwaitCallResult(ACall: SteamAPICall_t; AExpectedCallbackID: Integer;
  AHandler: TSteamCallResultEvent): Boolean;
var
  P: TSteamPendingCallEntry;
begin
  Result := (ACall <> k_uAPICallInvalid) and Assigned(AHandler);
  if not Result then
    Exit;
  P := Default(TSteamPendingCallEntry);
  P.Expected := AExpectedCallbackID;
  P.Handler := AHandler;
  P.Owner := TObject(TMethod(AHandler).Data);
  FLock.Enter;
  try
    FPending.AddOrSetValue(ACall, P);
  finally
    FLock.Leave;
  end;
end;

{$ifdef STEAMWORKS_ANONYMOUS_METHODS}
function TSteamCallbackDispatcher.SubscribeProc(ACallbackID: Integer; const AProc: TSteamCallbackProc;
  AOwner: TObject; AIncludeCallResults: Boolean): TSteamSubscription;
var
  S: TSteamSubscriptionEntry;
begin
  if not Assigned(AProc) then
    Exit(0);
  S := Default(TSteamSubscriptionEntry);
  S.CallbackID := ACallbackID;
  S.Proc := AProc;
  S.Owner := AOwner;
  S.IncludeCallResults := AIncludeCallResults;
  Result := AddSub(S);
end;

function TSteamCallbackDispatcher.SubscribeTyped<T>(ACallbackID: Integer;
  const AHandler: TSteamCallbackHandler<T>; AOwner: TObject): TSteamSubscription;
var
  H: TSteamCallbackHandler<T>;
begin
  H := AHandler;
  Result := SubscribeProc(ACallbackID,
    procedure(const AData: TSteamCallbackData)
    begin
      H(AData.AsRecord<T>);
    end, AOwner);
end;

function TSteamCallbackDispatcher.AwaitCallResultProc(ACall: SteamAPICall_t; AExpectedCallbackID: Integer;
  const AProc: TSteamCallResultProc; AOwner: TObject): Boolean;
var
  P: TSteamPendingCallEntry;
begin
  Result := (ACall <> k_uAPICallInvalid) and Assigned(AProc);
  if not Result then
    Exit;
  P := Default(TSteamPendingCallEntry);
  P.Expected := AExpectedCallbackID;
  P.Proc := AProc;
  P.Owner := AOwner;
  FLock.Enter;
  try
    FPending.AddOrSetValue(ACall, P);
  finally
    FLock.Leave;
  end;
end;

function TSteamCallbackDispatcher.AwaitCallResultTyped<T>(ACall: SteamAPICall_t; AExpectedCallbackID: Integer;
  const AHandler: TSteamCallResultHandler<T>; AOwner: TObject): Boolean;
var
  H: TSteamCallResultHandler<T>;
begin
  H := AHandler;
  Result := AwaitCallResultProc(ACall, AExpectedCallbackID,
    procedure(const AData: TSteamCallbackData; AIOFailure: Boolean)
    begin
      H(AData.AsRecord<T>, AIOFailure);
    end, AOwner);
end;
{$endif}

procedure TSteamCallbackDispatcher.Unsubscribe(var AToken: TSteamSubscription);
var
  I: Integer;
begin
  if AToken <> 0 then
  begin
    FLock.Enter;
    try
      I := IndexOfToken(AToken);
      if I >= 0 then
        FSubs.Delete(I);
    finally
      FLock.Leave;
    end;
  end;
  AToken := 0;
end;

procedure TSteamCallbackDispatcher.UnsubscribeAll(ACallbackID: Integer);
var
  I: Integer;
begin
  FLock.Enter;
  try
    for I := FSubs.Count - 1 downto 0 do
      if FSubs[I].CallbackID = ACallbackID then
        FSubs.Delete(I);
  finally
    FLock.Leave;
  end;
end;

procedure TSteamCallbackDispatcher.RemoveOwner(AOwner: TObject);
var
  I: Integer;
  Calls: TList<SteamAPICall_t>;
  Pair: TPair<SteamAPICall_t, TSteamPendingCallEntry>;
  C: SteamAPICall_t;
begin
  if AOwner = nil then
    Exit;
  Calls := TList<SteamAPICall_t>.Create;
  try
    FLock.Enter;
    try
      for I := FSubs.Count - 1 downto 0 do
        if FSubs[I].Owner = AOwner then
          FSubs.Delete(I);
      for Pair in FPending do
        if Pair.Value.Owner = AOwner then
          Calls.Add(Pair.Key);
      for C in Calls do
        FPending.Remove(C);
    finally
      FLock.Leave;
    end;
  finally
    Calls.Free;
  end;
end;

procedure TSteamCallbackDispatcher.CancelCallResult(ACall: SteamAPICall_t);
begin
  FLock.Enter;
  try
    FPending.Remove(ACall);
  finally
    FLock.Leave;
  end;
end;

function TSteamCallbackDispatcher.IsCallResultPending(ACall: SteamAPICall_t): Boolean;
begin
  FLock.Enter;
  try
    Result := FPending.ContainsKey(ACall);
  finally
    FLock.Leave;
  end;
end;

function TSteamCallbackDispatcher.PendingCallResultCount: Integer;
begin
  FLock.Enter;
  try
    Result := FPending.Count;
  finally
    FLock.Leave;
  end;
end;

function TSteamCallbackDispatcher.HasCallResultSubscribers(ACallbackID: Integer): Boolean;
var
  I: Integer;
begin
  Result := False;
  FLock.Enter;
  try
    for I := 0 to FSubs.Count - 1 do
      if (FSubs[I].CallbackID = ACallbackID) and FSubs[I].IncludeCallResults then
      begin
        Result := True;
        Break;
      end;
  finally
    FLock.Leave;
  end;
end;

function TSteamCallbackDispatcher.TakePending(ACall: SteamAPICall_t;
  out APending: TSteamPendingCallEntry): Boolean;
begin
  FLock.Enter;
  try
    Result := FPending.TryGetValue(ACall, APending);
    if Result then
      FPending.Remove(ACall);
  finally
    FLock.Leave;
  end;
  if not Result then
    APending := Default(TSteamPendingCallEntry);
end;

function TSteamCallbackDispatcher.HandleError(E: Exception; ACallbackID: Integer): Boolean;
begin
  // True = dealt with; False = caller re-raises
  Result := False;
  if Assigned(FOnHandlerError) then
    FOnHandlerError(Self, E, ACallbackID, Result);
end;

procedure TSteamCallbackDispatcher.InvokeSub(const ASub: TSteamSubscriptionEntry; const AData: TSteamCallbackData);
begin
  try
    if Assigned(ASub.Handler) then
      ASub.Handler(AData)
    {$ifdef STEAMWORKS_ANONYMOUS_METHODS}
    else if Assigned(ASub.Proc) then
      ASub.Proc(AData)
    {$endif};
  except
    on E: Exception do
      if not HandleError(E, AData.CallbackID) then
        raise;
  end;
end;

procedure TSteamCallbackDispatcher.InvokePending(const APending: TSteamPendingCallEntry; const AData: TSteamCallbackData);
begin
  try
    if Assigned(APending.Handler) then
      APending.Handler(AData, AData.IOFailure)
    {$ifdef STEAMWORKS_ANONYMOUS_METHODS}
    else if Assigned(APending.Proc) then
      APending.Proc(AData, AData.IOFailure)
    {$endif};
  except
    on E: Exception do
      if not HandleError(E, AData.CallbackID) then
        raise;
  end;
end;

procedure TSteamCallbackDispatcher.Deliver(const AData: TSteamCallbackData);
var
  Snapshot: array of TSteamSubscriptionEntry;
  I: Integer;
begin
  Inc(FCallbacksDispatched);
  if Assigned(FOnAnyCallback) then
  begin
    try
      FOnAnyCallback(AData);
    except
      on E: Exception do
        if not HandleError(E, AData.CallbackID) then
          raise;
    end;
  end;
  // Snapshot under the lock, call outside it: handlers may subscribe /
  // unsubscribe (on this or another thread) while we iterate
  Snapshot := nil;
  FLock.Enter;
  try
    SetLength(Snapshot, FSubs.Count);
    for I := 0 to FSubs.Count - 1 do
      Snapshot[I] := FSubs[I];
  finally
    FLock.Leave;
  end;
  for I := 0 to High(Snapshot) do
  begin
    if Snapshot[I].CallbackID <> AData.CallbackID then
      Continue;
    if AData.IsCallResult and not Snapshot[I].IncludeCallResults then
      Continue;
    if not TokenAlive(Snapshot[I].Token) then
      Continue; // removed by an earlier handler
    InvokeSub(Snapshot[I], AData);
  end;
end;

procedure TSteamCallbackDispatcher.CompleteCallResult(AHasPending: Boolean;
  const APending: TSteamPendingCallEntry; const AData: TSteamCallbackData; AFetchOk: Boolean);
var
  D: TSteamCallbackData;
begin
  if AHasPending then
  begin
    D := AData;
    if APending.Expected <> AData.CallbackID then
    begin
      // k_ESteamAPICallFailureMismatchedCallback: never hand over the wrong struct
      D.IOFailure := True;
      D.Data := nil;
      D.Size := 0;
    end;
    InvokePending(APending, D);
  end
  // Unclaimed results go to subscribers that asked for them
  else if AFetchOk then
    Deliver(AData);
end;

procedure TSteamCallbackDispatcher.HandleCallCompleted(APipe: HSteamPipe; const AMsg: CallbackMsg_t);
var
  Completed: SteamAPICallCompleted_t;
  Pending: TSteamPendingCallEntry;
  HasPending, Failed, Ok: Boolean;
  Buf: TBytes;
  Data: TSteamCallbackData;
begin
  Completed := Default(SteamAPICallCompleted_t);
  Move(AMsg.m_pubParam^, Completed, Min(AMsg.m_cubParam, SizeOf(Completed)));

  // The raw 703 notification, for anyone interested
  Data := Default(TSteamCallbackData);
  Data.CallbackID := AMsg.m_iCallback;
  Data.Data := AMsg.m_pubParam;
  Data.Size := AMsg.m_cubParam;
  Data.User := AMsg.m_hSteamUser;
  Deliver(Data);

  HasPending := TakePending(Completed.m_hAsyncCall, Pending);
  if not (HasPending or HasCallResultSubscribers(Completed.m_iCallback)) then
    Exit;

  SetLength(Buf, Max(Integer(Completed.m_cubParam), 1));
  Failed := False;
  Ok := TSteamLib.SteamAPI_ManualDispatch_GetAPICallResult(APipe, Completed.m_hAsyncCall,
    @Buf[0], Integer(Completed.m_cubParam), Completed.m_iCallback, Failed);

  Data := Default(TSteamCallbackData);
  Data.CallbackID := Completed.m_iCallback;
  Data.User := AMsg.m_hSteamUser;
  Data.APICall := Completed.m_hAsyncCall;
  Data.IsCallResult := True;
  if Ok then
  begin
    Data.Data := @Buf[0];
    Data.Size := Integer(Completed.m_cubParam);
    Data.IOFailure := Failed;
  end
  else
    Data.IOFailure := True;

  CompleteCallResult(HasPending, Pending, Data, Ok);
end;

procedure TSteamCallbackDispatcher.RequestStop;
begin
  FStopRequested := True;
end;

function TSteamCallbackDispatcher.InHandlerOnCurrentThread: Boolean;
begin
  Result := (FPumping or FDelivering) and (FHandlerThread = TThread.CurrentThread.ThreadID);
end;

procedure TSteamCallbackDispatcher.Pump(APipe: HSteamPipe);
var
  Msg: CallbackMsg_t;
  Data: TSteamCallbackData;
begin
  // Never next to PumpToQueue: one reader of Steam's queue at a time
  if FPumping or FQueuePumping or (APipe = 0) or not TSteamLib.IsLoaded then
    Exit;
  FHandlerThread := TThread.CurrentThread.ThreadID;
  FPumping := True;
  FStopRequested := False;
  try
    TSteamLib.SteamAPI_ManualDispatch_RunFrame(APipe);
    Msg := Default(CallbackMsg_t);
    while (not FStopRequested) and
          TSteamLib.SteamAPI_ManualDispatch_GetNextCallback(APipe, @Msg) do
    begin
      try
        if Msg.m_iCallback = SteamAPICallCompleted_t_k_iCallback then
          HandleCallCompleted(APipe, Msg)
        else
        begin
          Data := Default(TSteamCallbackData);
          Data.CallbackID := Msg.m_iCallback;
          Data.Data := Msg.m_pubParam;
          Data.Size := Msg.m_cubParam;
          Data.User := Msg.m_hSteamUser;
          Deliver(Data);
        end;
      finally
        TSteamLib.SteamAPI_ManualDispatch_FreeLastCallback(APipe);
      end;
    end;
  finally
    FPumping := False;
  end;
end;

{ Queued delivery }

procedure TSteamCallbackDispatcher.Enqueue(AItem: TSteamQueuedCallback);
begin
  FQueueLock.Enter;
  try
    FQueue.Add(AItem);
  finally
    FQueueLock.Leave;
  end;
end;

function TSteamCallbackDispatcher.TakeQueue: TList<TSteamQueuedCallback>;
var
  I: Integer;
begin
  Result := nil;
  FQueueLock.Enter;
  try
    if FQueue.Count = 0 then
      Exit;
    Result := TList<TSteamQueuedCallback>.Create;
    for I := 0 to FQueue.Count - 1 do
      Result.Add(FQueue[I]);
    FQueue.Clear;
  finally
    FQueueLock.Leave;
  end;
end;

function TSteamCallbackDispatcher.QueuedCount: Integer;
begin
  FQueueLock.Enter;
  try
    Result := FQueue.Count;
  finally
    FQueueLock.Leave;
  end;
end;

procedure TSteamCallbackDispatcher.ClearQueue;
var
  Batch: TList<TSteamQueuedCallback>;
  I: Integer;
begin
  Batch := TakeQueue;
  if Batch = nil then
    Exit;
  for I := 0 to Batch.Count - 1 do
    Batch[I].Free;
  Batch.Free;
end;

function TSteamCallbackDispatcher.PumpToQueue(APipe: HSteamPipe; out ASteamShutdown: Boolean): Integer;
var
  Msg: CallbackMsg_t;
  Completed: SteamAPICallCompleted_t;
  Item: TSteamQueuedCallback;
  Failed: Boolean;
begin
  Result := 0;
  ASteamShutdown := False;
  if FQueuePumping or FPumping or (APipe = 0) or not TSteamLib.IsLoaded then
    Exit;
  FQueuePumping := True;
  try
    TSteamLib.SteamAPI_ManualDispatch_RunFrame(APipe);
    Msg := Default(CallbackMsg_t);
    while TSteamLib.SteamAPI_ManualDispatch_GetNextCallback(APipe, @Msg) do
    begin
      try
        // The callback itself (703 included, as Pump delivers it too)
        Item := TSteamQueuedCallback.Create;
        try
          Item.CallbackID := Msg.m_iCallback;
          Item.User := Msg.m_hSteamUser;
          Item.Size := Msg.m_cubParam;
          SetLength(Item.Payload, Max(Msg.m_cubParam, 1));
          if (Msg.m_cubParam > 0) and (Msg.m_pubParam <> nil) then
            Move(Msg.m_pubParam^, Item.Payload[0], Msg.m_cubParam);
        except
          Item.Free;
          raise;
        end;
        Enqueue(Item);
        Inc(Result);
        if Msg.m_iCallback = SteamShutdown_t_k_iCallback then
          ASteamShutdown := True;

        // A finished async call: its result must be fetched here, on the
        // thread that owns the pipe, before FreeLastCallback. Who wants it
        // is decided at delivery time (an AwaitCallResult registered after
        // this pump still gets it).
        if Msg.m_iCallback = SteamAPICallCompleted_t_k_iCallback then
        begin
          Completed := Default(SteamAPICallCompleted_t);
          if Msg.m_pubParam <> nil then
            Move(Msg.m_pubParam^, Completed, Min(Msg.m_cubParam, SizeOf(Completed)));
          Item := TSteamQueuedCallback.Create;
          try
            Item.CallbackID := Completed.m_iCallback;
            Item.User := Msg.m_hSteamUser;
            Item.APICall := Completed.m_hAsyncCall;
            Item.IsCallResult := True;
            Item.Size := Integer(Completed.m_cubParam);
            SetLength(Item.Payload, Max(Integer(Completed.m_cubParam), 1));
            Failed := False;
            Item.FetchOk := TSteamLib.SteamAPI_ManualDispatch_GetAPICallResult(APipe,
              Completed.m_hAsyncCall, @Item.Payload[0], Integer(Completed.m_cubParam),
              Completed.m_iCallback, Failed);
            Item.IOFailure := Failed or not Item.FetchOk;
          except
            Item.Free;
            raise;
          end;
          Enqueue(Item);
          Inc(Result);
        end;
      finally
        TSteamLib.SteamAPI_ManualDispatch_FreeLastCallback(APipe);
      end;
    end;
  finally
    FQueuePumping := False;
  end;
end;

procedure TSteamCallbackDispatcher.RequeueFront(ABatch: TList<TSteamQueuedCallback>; AFrom: Integer);
var
  J: Integer;
begin
  if AFrom >= ABatch.Count then
    Exit;
  FQueueLock.Enter;
  try
    for J := ABatch.Count - 1 downto AFrom do
    begin
      FQueue.Insert(0, ABatch[J]);
      ABatch[J] := nil;   // no longer owned by the batch
    end;
  finally
    FQueueLock.Leave;
  end;
end;

function TSteamCallbackDispatcher.DeliverQueued: Integer;
var
  Batch: TList<TSteamQueuedCallback>;
  Item: TSteamQueuedCallback;
  Pending: TSteamPendingCallEntry;
  HasPending: Boolean;
  I, J: Integer;
begin
  Result := 0;
  if FDelivering or FPumping then
    Exit; // called from inside a handler: the outer call delivers the rest
  Batch := TakeQueue;
  if Batch = nil then
    Exit;
  FHandlerThread := TThread.CurrentThread.ThreadID;
  FDelivering := True;
  FStopRequested := False;
  I := 0;
  try
    try
      while (I < Batch.Count) and not FStopRequested do
      begin
        Item := Batch[I];
        if Item.IsCallResult then
        begin
          HasPending := TakePending(Item.APICall, Pending);
          if HasPending or HasCallResultSubscribers(Item.CallbackID) then
            CompleteCallResult(HasPending, Pending, Item.AsData, Item.FetchOk);
        end
        else
          Deliver(Item.AsData);
        Inc(I);
        Inc(Result);
      end;
    except
      // An unhandled handler exception: the item that raised counts as
      // delivered; the rest go back to the front of the queue, in order.
      RequeueFront(Batch, I + 1);
      raise;
    end;
    // Stopped early (RequestStop, e.g. Shutdown from a handler): keep the
    // rest queued - shutdown clears them, a restart would deliver them.
    RequeueFront(Batch, I);
  finally
    FDelivering := False;
    for J := 0 to Batch.Count - 1 do
      Batch[J].Free;   // nil for items handed back to the queue
    Batch.Free;
  end;
end;

end.
