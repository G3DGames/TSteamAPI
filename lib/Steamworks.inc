(* Steamworks.inc

  Shared compiler settings for every Steamworks unit, including plug-ins.
  Include it at the top of EVERY unit, before the uses clause:

  @longCode(#
  unit MySteamPlugin;
  {$I Steamworks.inc}
  interface
  #)

  It makes the same source compile with Delphi (FMX / VCL) and Free Pascal
  (FPC 3.2+, {$mode delphi}), and makes record and enum layout match the C++
  headers of the Steamworks SDK:

  - steamclientpublic.h packs callback structs with
    #pragma pack(push, 8) on Windows (VALVE_CALLBACK_PACK_LARGE) and
    #pragma pack(push, 4) on Linux / macOS (VALVE_CALLBACK_PACK_SMALL).
  - C enums are 32-bit ints, so Pascal enums must be at least 4 bytes.

  A few SDK structs override this with their own #pragma pack(1)
  (e.g. SteamIPAddress_t, the Steam Input *Data_t structs). Declare those
  explicitly as "packed record".

  Defines produced here (use them instead of compiler-specific symbols):

  - STEAMWORKS_WINDOWS, STEAMWORKS_MACOS, STEAMWORKS_LINUX
  - STEAMWORKS_CPU64
  - STEAMWORKS_UNSUPPORTED_PLATFORM  (iOS, Android, WebAssembly, ...)
  - STEAMWORKS_ANONYMOUS_METHODS     (compiler supports "reference to")
*)

{ ---------------------------------------------------------------- compiler }
{$ifdef FPC}
  {$mode delphi}
  {$H+}
  {$macro on}
  {$ifdef MSWINDOWS}
    {$packrecords 8}
  {$else}
    {$packrecords 4}
  {$endif}
  {$packenum 4}
  {$scopedenums off}
  // FPC 3.3.1+ (trunk) supports function references / anonymous functions.
  {$if FPC_FULLVERSION >= 30301}
    {$modeswitch functionreferences}
    {$modeswitch anonymousfunctions}
    {$define STEAMWORKS_ANONYMOUS_METHODS}
  {$endif}
{$else}
  {$ifdef MSWINDOWS}
    {$ALIGN 8}
  {$else}
    {$ALIGN 4}
  {$endif}
  {$MINENUMSIZE 4}
  {$SCOPEDENUMS OFF}
  {$define STEAMWORKS_ANONYMOUS_METHODS}
{$endif}

{ ---------------------------------------------------------------- platform }
{$if defined(ANDROID) or defined(IOS) or defined(IPHONESIM) or defined(WASI) or defined(WASM)}
  {$define STEAMWORKS_UNSUPPORTED_PLATFORM}
{$elseif defined(MSWINDOWS)}
  {$define STEAMWORKS_WINDOWS}
{$elseif defined(DARWIN) or defined(MACOS)}
  {$define STEAMWORKS_MACOS}
{$elseif defined(LINUX)}
  {$define STEAMWORKS_LINUX}
{$else}
  {$define STEAMWORKS_UNSUPPORTED_PLATFORM}
{$endif}

{$if defined(CPU64) or defined(CPU64BITS) or defined(CPUX64)}
  {$define STEAMWORKS_CPU64}
{$endif}
