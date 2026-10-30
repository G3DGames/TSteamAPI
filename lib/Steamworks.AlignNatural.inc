(* Switches record alignment to C natural alignment, for SDK structs declared
   outside any #pragma pack region. Used by the generated Steamworks.SDKTypes;
   always paired with Steamworks.AlignDefault.inc after the record. *)
{$ifdef FPC}
  {$packrecords C}
{$else}
  {$ALIGN 8}
{$endif}
