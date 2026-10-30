(* Restores the record alignment Steamworks.inc sets (Steam's callback packing:
   8 on Windows, 4 elsewhere) after Steamworks.AlignNatural.inc. Keep in step
   with the compiler section of Steamworks.inc. *)
{$ifdef FPC}
  {$ifdef MSWINDOWS}
    {$packrecords 8}
  {$else}
    {$packrecords 4}
  {$endif}
{$else}
  {$ifdef MSWINDOWS}
    {$ALIGN 8}
  {$else}
    {$ALIGN 4}
  {$endif}
{$endif}
