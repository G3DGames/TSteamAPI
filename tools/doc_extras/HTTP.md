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
