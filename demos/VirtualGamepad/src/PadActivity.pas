(* @abstract(Which controls of a pad are in use: the "in use" log lines,
  the glow on the model and the trackpad touch - the same for
  VirtualGamepad, VirtualGamepadLCL and VirtualGamepadVCL.)

  Hand-written; the same file in all three demos (tools/project_check.py
  keeps the copies identical). No engine and no Steam code: the program
  hands over each control's value every poll and reads back how strongly it
  glows (@link(TPadActivity.Glow)) and where a trackpad is touched
  (@link(TPadActivity.Touched)).

  What is logged (owner 2026-11-05: that a control is in use, not its
  values):
  @unorderedList(
    @item(Sticks: "Left stick: horizontal motion" / "vertical motion" when
      an axis passes @link(STICK_USE), once per use; "back at rest" when
      both axes stay under @link(STICK_REST) for @link(STICK_REST_MS).)
    @item(Gyro: "Gyro: motion" / "Gyro: still", the same way (a longer
      rest time, @link(GYRO_REST_MS): a hand never holds a pad quite still).)
    @item(Triggers: "activated" past @link(TRIGGER_USE), "released" under
      @link(TRIGGER_REST).)
    @item(Trackpads: "touched" when a touch position arrives, "touch
      ended" when none has for @link(TOUCH_END_MS).)
  )
  Buttons are not logged here: the programs log presses and releases
  themselves. A control glows fully while in use and fades out over
  @link(GLOW_FADE_MS) after, so a short tap still shows on the model. *)
unit PadActivity;

{$IFDEF FPC}{$mode delphi}{$H+}{$ENDIF}

interface

type
  { What kind of control an index is: decides what counts as in use. }
  TPadControlKind = (
    { A button (digital action). }
    pckButton,
    { A stick (x, y -1..1). }
    pckStick,
    { An analog trigger (x 0..1). }
    pckTrigger,
    { A trackpad as a position (x, y -1..1; 0, 0 when not touched). }
    pckTrackpad,
    { The gyro (x, y). }
    pckGyro);

  { Receives each "in use" line. }
  TPadActivityLogEvent = procedure(const AText: string) of object;

  { The in-use state of every control of one pad (see the unit description).
    Times are milliseconds from @link(PadNowMs). }
  TPadActivity = class
  private
    { Kind of each control. }
    FKinds: array of TPadControlKind;
    { Name of each control in the log ("Left stick"). }
    FNames: array of string;
    { The control is in use now. }
    FInUse: array of Boolean;
    { Horizontal motion was logged in this use (sticks, gyro). }
    FHoriz: array of Boolean;
    { Vertical motion was logged in this use (sticks, gyro). }
    FVert: array of Boolean;
    { When the value went (and stayed) under its rest level; 0 = it is not. }
    FQuietSince: array of UInt64;
    { When the control stopped being in use; 0 = not used since the start or
      the last @link(Reset). }
    FEndedAt: array of UInt64;
    { Last touch position x of each trackpad. }
    FTouchX: array of Single;
    { Last touch position y of each trackpad. }
    FTouchY: array of Single;
    { See @link(OnLog). }
    FOnLog: TPadActivityLogEvent;
    { Hands AText to @link(OnLog). }
    procedure Log(const AText: string);
    { The control stops being in use at ANow; AText is logged. }
    procedure EndUse(AIndex: Integer; ANow: UInt64; const AText: string);
    { AIndex is a control of this pad. }
    function Valid(AIndex: Integer): Boolean;
  public
    { Creates the state of ACount controls (indexes 0..ACount - 1), all
      buttons named by their index until @link(Define) names them. }
    constructor Create(ACount: Integer);
    { Sets the kind and log name of control AIndex. }
    procedure Define(AIndex: Integer; AKind: TPadControlKind; const AName: string);
    { A button's state this poll. }
    procedure SetButton(AIndex: Integer; ADown: Boolean; ANow: UInt64);
    { An analog control's value this poll (x only for triggers). }
    procedure SetAnalog(AIndex: Integer; AX, AY: Single; ANow: UInt64);
    { Every control out of use at ANow, without log lines (the overlay menu
      opened, another pad or model): what glowed fades out. }
    procedure ReleaseAll(ANow: UInt64);
    { Every control out of use and nothing glowing (a new pad). }
    procedure Reset;
    { How strongly control AIndex glows at ANow: 1 while in use, then down
      to 0 over @link(GLOW_FADE_MS). }
    function Glow(AIndex: Integer; ANow: UInt64): Single;
    { Control AIndex is in use now. }
    function InUse(AIndex: Integer): Boolean;
    { Trackpad AIndex is touched; AX, AY is where (-1..1, y up). }
    function Touched(AIndex: Integer; out AX, AY: Single): Boolean;
    { Receives each "in use" line. }
    property OnLog: TPadActivityLogEvent read FOnLog write FOnLog;
  end;

const
  { A stick axis past this counts as motion (logged once per use). }
  STICK_USE = 0.25;
  { Both stick axes under this count as rest. }
  STICK_REST = 0.08;
  { Milliseconds a stick must stay at rest before its use ends. }
  STICK_REST_MS = 150;
  { A gyro axis past this counts as motion. }
  GYRO_USE = 0.25;
  { Both gyro axes under this count as still. }
  GYRO_REST = 0.08;
  { Milliseconds the gyro must stay still before its use ends. }
  GYRO_REST_MS = 1000;
  { A trigger past this is activated. }
  TRIGGER_USE = 0.1;
  { A trigger under this is released. }
  TRIGGER_REST = 0.05;
  { Milliseconds a trigger must stay released before its use ends. }
  TRIGGER_REST_MS = 100;
  { Milliseconds without a touch position before a touch ends (a finger
    exactly in the middle of a pad reads 0, 0 for a moment). }
  TOUCH_END_MS = 150;
  { Milliseconds a glow takes to fade out once the control is let go. }
  GLOW_FADE_MS = 700;

{ Milliseconds since an unspecified start (Free Pascal's GetTickCount64,
  Delphi's TThread.GetTickCount64); for the times of @link(TPadActivity). }
function PadNowMs: UInt64;

implementation

uses
  {$IFDEF FPC}SysUtils, Classes{$ELSE}System.SysUtils, System.Classes{$ENDIF};

function PadNowMs: UInt64;
begin
{$IFDEF FPC}
  Result := GetTickCount64;
{$ELSE}
  Result := TThread.GetTickCount64;
{$ENDIF}
end;

constructor TPadActivity.Create(ACount: Integer);
var
  I: Integer;
begin
  inherited Create;
  SetLength(FKinds, ACount);
  SetLength(FNames, ACount);
  SetLength(FInUse, ACount);
  SetLength(FHoriz, ACount);
  SetLength(FVert, ACount);
  SetLength(FQuietSince, ACount);
  SetLength(FEndedAt, ACount);
  SetLength(FTouchX, ACount);
  SetLength(FTouchY, ACount);
  for I := 0 to ACount - 1 do
  begin
    FKinds[I] := pckButton;
    FNames[I] := 'control ' + IntToStr(I);
  end;
  Reset;
end;

function TPadActivity.Valid(AIndex: Integer): Boolean;
begin
  Result := (AIndex >= 0) and (AIndex < Length(FKinds));
end;

procedure TPadActivity.Define(AIndex: Integer; AKind: TPadControlKind; const AName: string);
begin
  if not Valid(AIndex) then
    Exit;
  FKinds[AIndex] := AKind;
  FNames[AIndex] := AName;
end;

procedure TPadActivity.Log(const AText: string);
begin
  if Assigned(FOnLog) then
    FOnLog(AText);
end;

procedure TPadActivity.EndUse(AIndex: Integer; ANow: UInt64; const AText: string);
begin
  FInUse[AIndex] := False;
  FHoriz[AIndex] := False;
  FVert[AIndex] := False;
  FQuietSince[AIndex] := 0;
  // 0 means "never used": a clock that reads 0 must not lose the fade
  if ANow = 0 then
    ANow := 1;
  FEndedAt[AIndex] := ANow;
  if AText <> '' then
    Log(FNames[AIndex] + ': ' + AText);
end;

procedure TPadActivity.SetButton(AIndex: Integer; ADown: Boolean; ANow: UInt64);
begin
  if not Valid(AIndex) then
    Exit;
  if ADown then
    FInUse[AIndex] := True
  else if FInUse[AIndex] then
    EndUse(AIndex, ANow, '');
end;

procedure TPadActivity.SetAnalog(AIndex: Integer; AX, AY: Single; ANow: UInt64);
var
  UseLevel, RestLevel: Single;
  RestMs: UInt64;
  Quiet: Boolean;
begin
  if not Valid(AIndex) then
    Exit;
  case FKinds[AIndex] of
    pckStick, pckGyro:
      begin
        if FKinds[AIndex] = pckStick then
        begin
          UseLevel := STICK_USE;
          RestLevel := STICK_REST;
          RestMs := STICK_REST_MS;
        end
        else
        begin
          UseLevel := GYRO_USE;
          RestLevel := GYRO_REST;
          RestMs := GYRO_REST_MS;
        end;
        if FKinds[AIndex] = pckGyro then
        begin
          // the gyro: one "motion" line per use, whichever axis moved
          if ((Abs(AX) >= UseLevel) or (Abs(AY) >= UseLevel)) and not FInUse[AIndex] then
          begin
            FInUse[AIndex] := True;
            Log(FNames[AIndex] + ': motion');
          end;
        end
        else
        begin
          // a stick: each axis logged once per use, the first time it passes
          if (Abs(AX) >= UseLevel) and not FHoriz[AIndex] then
          begin
            FHoriz[AIndex] := True;
            FInUse[AIndex] := True;
            Log(FNames[AIndex] + ': horizontal motion');
          end;
          if (Abs(AY) >= UseLevel) and not FVert[AIndex] then
          begin
            FVert[AIndex] := True;
            FInUse[AIndex] := True;
            Log(FNames[AIndex] + ': vertical motion');
          end;
        end;
        Quiet := (Abs(AX) < RestLevel) and (Abs(AY) < RestLevel);
        if not FInUse[AIndex] or not Quiet then
          FQuietSince[AIndex] := 0
        else if FQuietSince[AIndex] = 0 then
          FQuietSince[AIndex] := ANow
        else if ANow - FQuietSince[AIndex] >= RestMs then
          if FKinds[AIndex] = pckGyro then
            EndUse(AIndex, ANow, 'still')
          else
            EndUse(AIndex, ANow, 'back at rest');
      end;
    pckTrigger:
      begin
        if (AX >= TRIGGER_USE) and not FInUse[AIndex] then
        begin
          FInUse[AIndex] := True;
          Log(FNames[AIndex] + ': activated');
        end;
        if not FInUse[AIndex] or (AX >= TRIGGER_REST) then
          FQuietSince[AIndex] := 0
        else if FQuietSince[AIndex] = 0 then
          FQuietSince[AIndex] := ANow
        else if ANow - FQuietSince[AIndex] >= TRIGGER_REST_MS then
          EndUse(AIndex, ANow, 'released');
      end;
    pckTrackpad:
      if (AX <> 0) or (AY <> 0) then
      begin
        FTouchX[AIndex] := AX;
        FTouchY[AIndex] := AY;
        FQuietSince[AIndex] := 0;
        if not FInUse[AIndex] then
        begin
          FInUse[AIndex] := True;
          Log(FNames[AIndex] + ': touched');
        end;
      end
      else if FInUse[AIndex] then
      begin
        // 0, 0: the finger left - or sits exactly in the middle for a moment
        if FQuietSince[AIndex] = 0 then
          FQuietSince[AIndex] := ANow
        else if ANow - FQuietSince[AIndex] >= TOUCH_END_MS then
          EndUse(AIndex, ANow, 'touch ended');
      end;
  else
    // a button handed an analog value: in use while it is not 0
    SetButton(AIndex, (AX <> 0) or (AY <> 0), ANow);
  end;
end;

procedure TPadActivity.ReleaseAll(ANow: UInt64);
var
  I: Integer;
begin
  for I := 0 to High(FKinds) do
    if FInUse[I] then
      EndUse(I, ANow, '');
end;

procedure TPadActivity.Reset;
var
  I: Integer;
begin
  for I := 0 to High(FKinds) do
  begin
    FInUse[I] := False;
    FHoriz[I] := False;
    FVert[I] := False;
    FQuietSince[I] := 0;
    FEndedAt[I] := 0;
    FTouchX[I] := 0;
    FTouchY[I] := 0;
  end;
end;

function TPadActivity.Glow(AIndex: Integer; ANow: UInt64): Single;
var
  Since: UInt64;
begin
  if not Valid(AIndex) then
    Exit(0);
  if FInUse[AIndex] then
    Exit(1);
  if (FEndedAt[AIndex] = 0) or (ANow < FEndedAt[AIndex]) then
    Exit(0);
  Since := ANow - FEndedAt[AIndex];
  if Since >= GLOW_FADE_MS then
    Result := 0
  else
    Result := 1 - Since / GLOW_FADE_MS;
end;

function TPadActivity.InUse(AIndex: Integer): Boolean;
begin
  Result := Valid(AIndex) and FInUse[AIndex];
end;

function TPadActivity.Touched(AIndex: Integer; out AX, AY: Single): Boolean;
begin
  Result := Valid(AIndex) and (FKinds[AIndex] = pckTrackpad) and FInUse[AIndex];
  if Result then
  begin
    AX := FTouchX[AIndex];
    AY := FTouchY[AIndex];
  end
  else
  begin
    AX := 0;
    AY := 0;
  end;
end;

end.
