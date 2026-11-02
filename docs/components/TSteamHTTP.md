# TSteamHTTP and TSteamHTTPPlugin (ISteamHTTP)

> **Generated** by `tools/gen_docs.py` from `lib/plugins/Steamworks.Plugin.HTTP.pas` - do not edit.
> Hand-written text: `tools/doc_extras/HTTP.md`. Steam's own descriptions are Valve's
> SDK comments, as in the generated units.

Unit: `Steamworks.Plugin.HTTP` - linking it (a `uses` entry, or dropping a `TSteamHTTP`) enables the
plug-in. Steam interface: `ISteamHTTP` (SDK 1.65).

## Overview

HTTP requests through the Steam client: no HTTP library of your own, and
the request works wherever Steam does. Create a request, set it up, send
it, read the answer in `OnHTTPRequestCompleted`, release it.

```pascal
procedure TForm1.Fetch;
var
  Req: HTTPRequestHandle;
  Call: SteamAPICall_t;
begin
  Req := SteamHTTP1.Plugin.CreateHTTPRequest(k_EHTTPMethodGET,
    'https://api.steampowered.com/ISteamWebAPIUtil/GetServerInfo/v1/');
  SteamHTTP1.Plugin.SetHTTPRequestHeaderValue(Req, 'Accept', 'application/json');
  SteamHTTP1.Plugin.SendHTTPRequest(Req, Call);      // -> OnHTTPRequestCompleted
end;

procedure TForm1.SteamHTTP1HTTPRequestCompleted(Sender: TObject;
  const AData: HTTPRequestCompleted_t);
var
  Size: UInt32;
  Body: TBytes;
begin
  if AData.m_bRequestSuccessful and
     SteamHTTP1.Plugin.GetHTTPResponseBodySize(AData.m_hRequest, Size) and (Size > 0) then
  begin
    SetLength(Body, Size);
    SteamHTTP1.Plugin.GetHTTPResponseBodyData(AData.m_hRequest, @Body[0], Size);
    Log(TEncoding.UTF8.GetString(Body));
  end;
  SteamHTTP1.Plugin.ReleaseHTTPRequest(AData.m_hRequest);   // always
end;
```

* `m_eStatusCode` is the HTTP status (`k_EHTTPStatusCode200OK`, ...);
  `m_bRequestSuccessful` is False when no answer came at all.
* `SetHTTPRequestGetOrPostParameter`, `SetHTTPRequestRawPostBody`,
  `SetHTTPRequestContextValue` (comes back as `m_ulContextValue`),
  `SetHTTPRequestNetworkActivityTimeout` / `SetHTTPRequestAbsoluteTimeoutMS`.
* Every request must be released with `ReleaseHTTPRequest`, also one that
  failed.

## Contents

* [The component: TSteamHTTP](#the-component-tsteamhttp)
  * [Events (3)](#events)
* [The plug-in: TSteamHTTPPlugin](#the-plug-in-tsteamhttpplugin)
  * [Methods](#methods)
  * [Async methods](#async-methods)
  * [Properties](#properties)
* [Payload records](#payload-records)

## The component: TSteamHTTP

ISteamHTTP component: drop it next to a TSteamAPI (linked automatically at run time when the owner has exactly one, otherwise set SteamAPI). Its events are the ISteamHTTP callbacks; call the interface through `Plugin`.

| Member | Kind | Description |
|--------|------|-------------|
| `SteamAPI` | published property | The `TSteamAPI` this component belongs to. At run time a component whose owner has exactly one `TSteamAPI` links itself. |
| `Plugin` | public property | The `TSteamHTTPPlugin` for calls; `nil` while Steam is not running. |
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
| `OnHTTPRequestCompleted` | 2101 | [`HTTPRequestCompleted_t`](#httprequestcompleted_t) | see the SDK. |
| `OnHTTPRequestHeadersReceived` | 2102 | [`HTTPRequestHeadersReceived_t`](#httprequestheadersreceived_t) | see the SDK. |
| `OnHTTPRequestDataReceived` | 2103 | [`HTTPRequestDataReceived_t`](#httprequestdatareceived_t) | see the SDK. |

Handler signature (the IDE generates it when you double-click the event):

```pascal
procedure TForm1.SteamHTTP1HTTPRequestCompleted(Sender: TObject; const AData: HTTPRequestCompleted_t);
```

## The plug-in: TSteamHTTPPlugin

ISteamHTTP plug-in. Registered by linking the unit; find it with @code(Steam.FindPlugin(TSteamHTTPPlugin)).

Reach it through the component (`SteamHTTP1.Plugin`) or the core:

```pascal
P := TSteamHTTPPlugin(Steam.FindPlugin(TSteamHTTPPlugin));   // Delphi also: Steam.Plugin<TSteamHTTPPlugin>
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
| [`CreateHTTPRequest`](#createhttprequest) | Initializes a new HTTP request, returning a handle to use in further operations on it. Requires the method (GET or POST) and the absolute URL for the ... |
| [`SetHTTPRequestContextValue`](#sethttprequestcontextvalue) | Set a context value for the request, which will be returned in the HTTPRequestCompleted_t callback after sending the request. This is just so the caller can ... |
| [`SetHTTPRequestNetworkActivityTimeout`](#sethttprequestnetworkactivitytimeout) | Set a timeout in seconds for the HTTP request, must be called prior to sending the request. Default timeout is 60 seconds if you don't call this. Returns ... |
| [`SetHTTPRequestHeaderValue`](#sethttprequestheadervalue) | Set a request header value for the request, must be called prior to sending the request. Will return false if the handle is invalid or the request is ... |
| [`SetHTTPRequestGetOrPostParameter`](#sethttprequestgetorpostparameter) | Set a GET or POST parameter value on the request, which is set will depend on the EHTTPMethod specified when creating the request. Must be called prior to ... |
| [`SendHTTPRequest`](#sendhttprequest) | Sends the HTTP request, will return false on a bad handle, otherwise use SteamCallHandle to wait on asynchronous response via callback. Note: If the user is ... |
| [`SendHTTPRequestAndStreamResponse`](#sendhttprequestandstreamresponse) | Sends the HTTP request, will return false on a bad handle, otherwise use SteamCallHandle to wait on asynchronous response via callback for completion, and ... |
| [`DeferHTTPRequest`](#deferhttprequest) | Defers a request you have sent, the actual HTTP client code may have many requests queued, and this will move the specified request to the tail of the ... |
| [`PrioritizeHTTPRequest`](#prioritizehttprequest) | Prioritizes a request you have sent, the actual HTTP client code may have many requests queued, and this will move the specified request to the head of the ... |
| [`GetHTTPResponseHeaderSize`](#gethttpresponseheadersize) | Checks if a response header is present in a HTTP response given a handle from HTTPRequestCompleted_t, also returns the size of the header value if present ... |
| [`GetHTTPResponseHeaderValue`](#gethttpresponseheadervalue) | Gets header values from a HTTP response given a handle from HTTPRequestCompleted_t, will return false if the header is not present or if your buffer is too ... |
| [`GetHTTPResponseBodySize`](#gethttpresponsebodysize) | Gets the size of the body data from a HTTP response given a handle from HTTPRequestCompleted_t, will return false if the handle is invalid. |
| [`GetHTTPResponseBodyData`](#gethttpresponsebodydata) | Gets the body data from a HTTP response given a handle from HTTPRequestCompleted_t, will return false if the handle is invalid or is to a streaming ... |
| [`GetHTTPStreamingResponseBodyData`](#gethttpstreamingresponsebodydata) | Gets the body data from a streaming HTTP response given a handle from HTTPRequestDataReceived_t. Will return false if the handle is invalid or is to a ... |
| [`ReleaseHTTPRequest`](#releasehttprequest) | Releases an HTTP response handle, should always be called to free resources after receiving a HTTPRequestCompleted_t callback and finishing using the response. |
| [`GetHTTPDownloadProgressPct`](#gethttpdownloadprogresspct) | Gets progress on downloading the body for the request. This will be zero unless a response header has already been received which included a content-length ... |
| [`SetHTTPRequestRawPostBody`](#sethttprequestrawpostbody) | Sets the body for an HTTP Post request. Will fail and return false on a GET request, and will fail if POST params have already been set for the request. ... |
| [`CreateCookieContainer`](#createcookiecontainer) | Creates a cookie container handle which you must later free with ReleaseCookieContainer(). If bAllowResponsesToModify=true than any response to your ... |
| [`ReleaseCookieContainer`](#releasecookiecontainer) | Release a cookie container you are finished using, freeing it's memory. |
| [`SetCookie`](#setcookie) | Adds a cookie to the specified cookie container that will be used with future requests. |
| [`SetHTTPRequestCookieContainer`](#sethttprequestcookiecontainer) | Set the cookie container to use for a HTTP request. |
| [`SetHTTPRequestUserAgentInfo`](#sethttprequestuseragentinfo) | Set the extra user agent info for a request, this doesn't clobber the normal user agent, it just adds the extra info on the end. |
| [`SetHTTPRequestRequiresVerifiedCertificate`](#sethttprequestrequiresverifiedcertificate) | Disable or re-enable verification of SSL/TLS certificates. By default, certificates are checked for all HTTPS requests. |
| [`SetHTTPRequestAbsoluteTimeoutMS`](#sethttprequestabsolutetimeoutms) | Set an absolute timeout on the HTTP request, this is just a total time timeout different than the network activity timeout which can bump everytime we get ... |
| [`GetHTTPRequestWasTimedOut`](#gethttprequestwastimedout) | Check if the reason the request failed was because we timed it out (rather than some harder failure). |

#### CreateHTTPRequest

```pascal
function CreateHTTPRequest(eHTTPRequestMethod: EHTTPMethod; const pchAbsoluteURL: string): HTTPRequestHandle;
```

Initializes a new HTTP request, returning a handle to use in further operations on it. Requires the method (GET or POST) and the absolute URL for the request. Both http and https are supported, so this string must start with http:// or https:// and should look like http://store.steampowered.com/app/250/ or such.

#### SetHTTPRequestContextValue

```pascal
function SetHTTPRequestContextValue(hRequest: HTTPRequestHandle; ulContextValue: UInt64): Boolean;
```

Set a context value for the request, which will be returned in the HTTPRequestCompleted_t callback after sending the request. This is just so the caller can easily keep track of which callbacks go with which request data.

#### SetHTTPRequestNetworkActivityTimeout

```pascal
function SetHTTPRequestNetworkActivityTimeout(hRequest: HTTPRequestHandle; unTimeoutSeconds: UInt32): Boolean;
```

Set a timeout in seconds for the HTTP request, must be called prior to sending the request. Default timeout is 60 seconds if you don't call this. Returns false if the handle is invalid, or the request has already been sent.

#### SetHTTPRequestHeaderValue

```pascal
function SetHTTPRequestHeaderValue(hRequest: HTTPRequestHandle; const pchHeaderName: string; const pchHeaderValue: string): Boolean;
```

Set a request header value for the request, must be called prior to sending the request. Will return false if the handle is invalid or the request is already sent.

#### SetHTTPRequestGetOrPostParameter

```pascal
function SetHTTPRequestGetOrPostParameter(hRequest: HTTPRequestHandle; const pchParamName: string; const pchParamValue: string): Boolean;
```

Set a GET or POST parameter value on the request, which is set will depend on the EHTTPMethod specified when creating the request. Must be called prior to sending the request. Will return false if the handle is invalid or the request is already sent.

#### SendHTTPRequest

```pascal
function SendHTTPRequest(hRequest: HTTPRequestHandle; var pCallHandle: SteamAPICall_t): Boolean;
```

Sends the HTTP request, will return false on a bad handle, otherwise use SteamCallHandle to wait on asynchronous response via callback. Note: If the user is in offline mode in Steam, then this will add a only-if-cached cache-control header and only do a local cache lookup rather than sending any actual remote request.

#### SendHTTPRequestAndStreamResponse

```pascal
function SendHTTPRequestAndStreamResponse(hRequest: HTTPRequestHandle; var pCallHandle: SteamAPICall_t): Boolean;
```

Sends the HTTP request, will return false on a bad handle, otherwise use SteamCallHandle to wait on asynchronous response via callback for completion, and listen for HTTPRequestHeadersReceived_t and HTTPRequestDataReceived_t callbacks while streaming.

#### DeferHTTPRequest

```pascal
function DeferHTTPRequest(hRequest: HTTPRequestHandle): Boolean;
```

Defers a request you have sent, the actual HTTP client code may have many requests queued, and this will move the specified request to the tail of the queue. Returns false on invalid handle, or if the request is not yet sent.

#### PrioritizeHTTPRequest

```pascal
function PrioritizeHTTPRequest(hRequest: HTTPRequestHandle): Boolean;
```

Prioritizes a request you have sent, the actual HTTP client code may have many requests queued, and this will move the specified request to the head of the queue. Returns false on invalid handle, or if the request is not yet sent.

#### GetHTTPResponseHeaderSize

```pascal
function GetHTTPResponseHeaderSize(hRequest: HTTPRequestHandle; const pchHeaderName: string; var unResponseHeaderSize: UInt32): Boolean;
```

Checks if a response header is present in a HTTP response given a handle from HTTPRequestCompleted_t, also returns the size of the header value if present so the caller and allocate a correctly sized buffer for GetHTTPResponseHeaderValue.

#### GetHTTPResponseHeaderValue

```pascal
function GetHTTPResponseHeaderValue(hRequest: HTTPRequestHandle; const pchHeaderName: string; pHeaderValueBuffer: Pointer; unBufferSize: UInt32): Boolean;
```

Gets header values from a HTTP response given a handle from HTTPRequestCompleted_t, will return false if the header is not present or if your buffer is too small to contain it's value. You should first call BGetHTTPResponseHeaderSize to check for the presence of the header and to find out the size buffer needed.

#### GetHTTPResponseBodySize

```pascal
function GetHTTPResponseBodySize(hRequest: HTTPRequestHandle; var unBodySize: UInt32): Boolean;
```

Gets the size of the body data from a HTTP response given a handle from HTTPRequestCompleted_t, will return false if the handle is invalid.

#### GetHTTPResponseBodyData

```pascal
function GetHTTPResponseBodyData(hRequest: HTTPRequestHandle; pBodyDataBuffer: Pointer; unBufferSize: UInt32): Boolean;
```

Gets the body data from a HTTP response given a handle from HTTPRequestCompleted_t, will return false if the handle is invalid or is to a streaming response, or if the provided buffer is not the correct size. Use BGetHTTPResponseBodySize first to find out the correct buffer size to use.

#### GetHTTPStreamingResponseBodyData

```pascal
function GetHTTPStreamingResponseBodyData(hRequest: HTTPRequestHandle; cOffset: UInt32; pBodyDataBuffer: Pointer; unBufferSize: UInt32): Boolean;
```

Gets the body data from a streaming HTTP response given a handle from HTTPRequestDataReceived_t. Will return false if the handle is invalid or is to a non-streaming response (meaning it wasn't sent with SendHTTPRequestAndStreamResponse), or if the buffer size and offset do not match the size and offset sent in HTTPRequestDataReceived_t.

#### ReleaseHTTPRequest

```pascal
function ReleaseHTTPRequest(hRequest: HTTPRequestHandle): Boolean;
```

Releases an HTTP response handle, should always be called to free resources after receiving a HTTPRequestCompleted_t callback and finishing using the response.

#### GetHTTPDownloadProgressPct

```pascal
function GetHTTPDownloadProgressPct(hRequest: HTTPRequestHandle; var pflPercentOut: Single): Boolean;
```

Gets progress on downloading the body for the request. This will be zero unless a response header has already been received which included a content-length field. For responses that contain no content-length it will report zero for the duration of the request as the size is unknown until the connection closes.

#### SetHTTPRequestRawPostBody

```pascal
function SetHTTPRequestRawPostBody(hRequest: HTTPRequestHandle; const pchContentType: string; pubBody: Pointer; unBodyLen: UInt32): Boolean;
```

Sets the body for an HTTP Post request. Will fail and return false on a GET request, and will fail if POST params have already been set for the request. Setting this raw body makes it the only contents for the post, the pchContentType parameter will set the content-type header for the request so the server may know how to interpret the body.

#### CreateCookieContainer

```pascal
function CreateCookieContainer(bAllowResponsesToModify: Boolean): HTTPCookieContainerHandle;
```

Creates a cookie container handle which you must later free with ReleaseCookieContainer(). If bAllowResponsesToModify=true than any response to your requests using this cookie container may add new cookies which may be transmitted with future requests. If bAllowResponsesToModify=false than only cookies you explicitly set will be sent. This API is just for during process lifetime, after steam restarts no cookies are persisted and you have no way to access the cookie container across repeat executions of your process.

#### ReleaseCookieContainer

```pascal
function ReleaseCookieContainer(hCookieContainer: HTTPCookieContainerHandle): Boolean;
```

Release a cookie container you are finished using, freeing it's memory.

#### SetCookie

```pascal
function SetCookie(hCookieContainer: HTTPCookieContainerHandle; const pchHost: string; const pchUrl: string; const pchCookie: string): Boolean;
```

Adds a cookie to the specified cookie container that will be used with future requests.

#### SetHTTPRequestCookieContainer

```pascal
function SetHTTPRequestCookieContainer(hRequest: HTTPRequestHandle; hCookieContainer: HTTPCookieContainerHandle): Boolean;
```

Set the cookie container to use for a HTTP request.

#### SetHTTPRequestUserAgentInfo

```pascal
function SetHTTPRequestUserAgentInfo(hRequest: HTTPRequestHandle; const pchUserAgentInfo: string): Boolean;
```

Set the extra user agent info for a request, this doesn't clobber the normal user agent, it just adds the extra info on the end.

#### SetHTTPRequestRequiresVerifiedCertificate

```pascal
function SetHTTPRequestRequiresVerifiedCertificate(hRequest: HTTPRequestHandle; bRequireVerifiedCertificate: Boolean): Boolean;
```

Disable or re-enable verification of SSL/TLS certificates. By default, certificates are checked for all HTTPS requests.

#### SetHTTPRequestAbsoluteTimeoutMS

```pascal
function SetHTTPRequestAbsoluteTimeoutMS(hRequest: HTTPRequestHandle; unMilliseconds: UInt32): Boolean;
```

Set an absolute timeout on the HTTP request, this is just a total time timeout different than the network activity timeout which can bump everytime we get more data.

#### GetHTTPRequestWasTimedOut

```pascal
function GetHTTPRequestWasTimedOut(hRequest: HTTPRequestHandle; var pbWasTimedOut: Boolean): Boolean;
```

Check if the reason the request failed was because we timed it out (rather than some harder failure).

### Async methods

None.

### Properties

| Property | Description |
|----------|-------------|
| `Handle: Pointer` | The raw ISteamHTTP pointer (first argument of every `Flat` export). |
| `Flat: TSteamHTTPFlat` | The bound flat exports, for calls the methods do not cover. |

## Payload records

Declared in `Steamworks.SDKTypes` (generated from the SDK headers; layouts verified
against the C headers for Win64, Win32, Linux64 and macOS ARM64).

### HTTPRequestCompleted_t

Callback id 2101 (`HTTPRequestCompleted_t_k_iCallback`).

| Field | C declaration |
|-------|---------------|
| `m_hRequest: HTTPRequestHandle` | C field `HTTPRequestHandle m_hRequest`. |
| `m_ulContextValue: UInt64` | C field `uint64 m_ulContextValue`. |
| `m_bRequestSuccessful: Boolean` | C field `bool m_bRequestSuccessful`. |
| `m_eStatusCode: EHTTPStatusCode` | C field `EHTTPStatusCode m_eStatusCode`. |
| `m_unBodySize: UInt32` | C field `uint32 m_unBodySize`. |

### HTTPRequestHeadersReceived_t

Callback id 2102 (`HTTPRequestHeadersReceived_t_k_iCallback`).

| Field | C declaration |
|-------|---------------|
| `m_hRequest: HTTPRequestHandle` | C field `HTTPRequestHandle m_hRequest`. |
| `m_ulContextValue: UInt64` | C field `uint64 m_ulContextValue`. |

### HTTPRequestDataReceived_t

Callback id 2103 (`HTTPRequestDataReceived_t_k_iCallback`).

| Field | C declaration |
|-------|---------------|
| `m_hRequest: HTTPRequestHandle` | C field `HTTPRequestHandle m_hRequest`. |
| `m_ulContextValue: UInt64` | C field `uint64 m_ulContextValue`. |
| `m_cOffset: UInt32` | C field `uint32 m_cOffset`. |
| `m_cBytesReceived: UInt32` | C field `uint32 m_cBytesReceived`. |
