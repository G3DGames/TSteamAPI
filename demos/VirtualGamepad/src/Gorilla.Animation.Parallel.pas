unit Gorilla.Animation.Parallel;

/// <summary>
/// Plays any number of animation clips of ONE model at the same time.
/// </summary>
/// <remarks>
/// <para>WHY THIS EXISTS. TGorillaAnimationManager runs one clip per model: a
/// new clip stops the running one (with a short crossfade). And every clip of a
/// glTF file writes ALL nodes the file animates - those it does not move are
/// held at their rest pose (Blender exports every bone into every action, and
/// the glTF loader pads missing tracks the same way). For a model with one clip
/// per part - typically a 3D game controller with "A_Press", "Stick_Left_Up",
/// "Trigger_Right_Press_Full", ... - that means pressing one button snaps all
/// others back to rest. Several inputs can not be shown at once.</para>
///
/// <para>HOW. TGorillaParallelAnimator extracts from every clip only the joints
/// that really move (TGorillaParallelTrack) and drops the constant ones. Each
/// clip becomes an independent TGorillaParallelClip with its own play head and
/// play mode. All running clips are combined ADDITIVELY on top of the rest
/// pose: a clip contributes the difference between its current pose and its
/// first key. So two clips on different joints simply run side by side, and
/// two clips on the same joint add up - "Stick_Left_Up" + "Stick_Left_Right"
/// tilt the stick diagonally, "Stick_Left_Press" pushes it down at the same
/// time.</para>
///
/// <para>The clips are typically authored "rest -> pressed -> rest". The
/// animator detects the time of the largest deflection (PeakTime) and offers
/// input oriented play modes on top of plain playback:
///   Play     - plays the clip once (a tap)
///   PlayLoop - loops the clip (e.g. "Stick_Left_Spin_CW")
///   Press    - plays up to PeakTime and holds there while the input is down
///   Release  - plays back to rest from wherever the clip currently is
///   SetValue - analog input 0..1, mapped onto 0..PeakTime (triggers, sticks)
///   SetAxis  - analog axis -1..1 onto a pair of clips (stick left/right)</para>
///
/// <para>The model's own AnimationManager must not play at the same time, both
/// would write the same joints. Attaching the animator resets the model to its
/// bind pose and stops all running clips. Load the model WITHOUT animation
/// caching (ACaching = []): cached clips draw baked frames instead of the
/// joints this animator moves.</para>
/// </remarks>
/// <example>
/// <code>
///   FModel := TGorillaModel.LoadNewModelFromFile(FViewport, nil,
///     'PS5_Animated.glb', []);
///   FModel.Parent := FViewport;
///
///   FAnimator := TGorillaParallelAnimator.Create(Self);
///   FAnimator.Model := FModel;   // extracts the clips
///
///   FAnimator.Press('X_Press');               // button down ...
///   FAnimator.Press('Circle_Press');          // ... a second one at once
///   FAnimator.SetValue('Trigger_Right_Press_Full', 0.6);
///   FAnimator.SetAxis('Stick_Left_Left', 'Stick_Left_Right', -0.3);
///   FAnimator.SetAxis('Stick_Left_Down', 'Stick_Left_Up', 1.0);
///   FAnimator.Release('X_Press');             // button up
/// </code>
/// </example>

interface

uses
  System.SysUtils, System.Classes, System.Types, System.Math,
  System.Math.Vectors, System.Generics.Collections,
  FMX.Types, FMX.Ani, FMX.Types3D,
  Gorilla.Transform,
  Gorilla.Model;

// Was {$I .\..\Gorilla.Platforms.inc} (Gorilla3D's source tree, not in
// this repository). For Delphi 10.3 and later - this project needs 11+ -
// that include declares only this:
const
  pfidAllGorillaPlatforms = pidAllPlatforms;

type
  TGorillaParallelAnimator = class;
  TGorillaParallelClip = class;

  /// <summary>
  /// Play state of a TGorillaParallelClip.
  /// </summary>
  /// <remarks>
  /// pmIdle: the clip does not contribute anything.
  /// pmOnce: plays from the current time to the end, then pmIdle.
  /// pmLoop: plays endlessly.
  /// pmHold: plays to PeakTime and stays there (Press).
  /// pmRelease: returns to rest - backwards before PeakTime, forwards behind it.
  /// pmValue: the time is set from outside (SetValue), no automatic advance.
  /// </remarks>
  TGorillaParallelPlayMode = (pmIdle, pmOnce, pmLoop, pmHold, pmRelease, pmValue);

  TGorillaParallelClipEvent = procedure(ASender : TObject;
    AClip : TGorillaParallelClip) of object;

  /// <summary>
  /// A joint moved by at least one clip, together with its rest pose.
  /// </summary>
  TGorillaParallelJoint = class
    protected
      FJoint      : TGorillaTransform;
      FName       : String;
      FIndex      : Integer;
      FRestMatrix : TMatrix3D;
      FRestPos    : TPoint3D;
      FRestScale  : TPoint3D;
      FRestRot    : TMatrix3D;
      /// The joint currently shows something else than its rest pose.
      FWritten    : Boolean;

    public
      property Joint : TGorillaTransform read FJoint;
      /// <summary>Node name as stored in the model file.</summary>
      property Name : String read FName;
      property RestMatrix : TMatrix3D read FRestMatrix;

      constructor Create(const AJoint : TGorillaTransform; const AIndex : Integer);
  end;

  /// <summary>
  /// The keys of one moving joint inside one clip. Positions, scales and
  /// rotations are stored decomposed, the key times in seconds.
  /// </summary>
  TGorillaParallelTrack = class
    protected
      [Unsafe]
      FJoint     : TGorillaParallelJoint;
      FTimes     : TArray<Single>;
      FPositions : TArray<TPoint3D>;
      FScales    : TArray<TPoint3D>;
      FRotations : TArray<TQuaternion3D>;
      /// first key - the additive contribution is measured against it
      FBasePos   : TPoint3D;
      FBaseScale : TPoint3D;
      FBaseRotInv : TMatrix3D;

      function GetKeyCount() : Integer;
      function GetDuration() : Single;

    public
      property Joint : TGorillaParallelJoint read FJoint;
      property KeyCount : Integer read GetKeyCount;
      /// <summary>Time of the last key in seconds.</summary>
      property Duration : Single read GetDuration;

      /// <summary>
      /// Pose of the joint at ATime (seconds), clamped to the keyed range.
      /// </summary>
      procedure Sample(const ATime : Single; out APos, AScale : TPoint3D;
        out ARot : TQuaternion3D);
      /// <summary>
      /// How far the pose at ATime is away from the first key: translation in
      /// model units, rotation in radians and the largest scale change.
      /// </summary>
      procedure Deviation(const ATime : Single; out APos, ARot, AScale : Single);
  end;

  TGorillaParallelTrackList = TObjectList<TGorillaParallelTrack>;

  /// <summary>
  /// One clip of the model with its own play head. Only the joints the clip
  /// really moves are part of it.
  /// </summary>
  TGorillaParallelClip = class
    protected
      [Unsafe]
      FAnimator : TGorillaParallelAnimator;
      FName     : String;
      FTracks   : TGorillaParallelTrackList;
      FDuration : Single;
      FPeakTime : Single;
      FEndsAtRest : Boolean;
      FMode     : TGorillaParallelPlayMode;
      FTime     : Single;
      FSpeed    : Single;
      FWeight   : Single;
      FValue    : Single;

      function GetIsActive() : Boolean;
      procedure SetPeakTime(const AValue : Single);
      procedure SetWeight(const AValue : Single);
      procedure SetSpeed(const AValue : Single);
      procedure DetectPeakTime();
      procedure Changed();
      /// <summary>
      /// Moves the play head by ADeltaTime seconds. Returns TRUE when the clip
      /// reached its end in this step.
      /// </summary>
      function Advance(const ADeltaTime : Single) : Boolean;

    public
      /// <summary>Clip name as stored in the model file.</summary>
      property Name : String read FName;
      property Tracks : TGorillaParallelTrackList read FTracks;
      /// <summary>Length in seconds.</summary>
      property Duration : Single read FDuration;
      /// <summary>
      /// Time of the largest deflection in seconds - where Press holds and
      /// where SetValue(1) points to. Detected from the keys, can be overridden.
      /// </summary>
      property PeakTime : Single read FPeakTime write SetPeakTime;
      /// <summary>
      /// TRUE if the clip returns to rest by itself ("rest -> pressed ->
      /// rest"), FALSE if it ends deflected ("rest -> pressed"). Play() of the
      /// latter plays back to rest after reaching the end.
      /// </summary>
      property EndsAtRest : Boolean read FEndsAtRest;
      property Mode : TGorillaParallelPlayMode read FMode;
      /// <summary>Current play head in seconds.</summary>
      property Time : Single read FTime;
      /// <summary>Playback speed factor, default 1.</summary>
      property Speed : Single read FSpeed write SetSpeed;
      /// <summary>
      /// Strength of the contribution 0..1, default 1. Scales the movement,
      /// not the time - SetValue is usually the better choice for analog input.
      /// </summary>
      property Weight : Single read FWeight write SetWeight;
      /// <summary>Last value given to SetValue.</summary>
      property Value : Single read FValue;
      /// <summary>True while the clip contributes to the pose.</summary>
      property IsActive : Boolean read GetIsActive;

      constructor Create(const AAnimator : TGorillaParallelAnimator; const AName : String);
      destructor Destroy(); override;

      /// <summary>
      /// Plays the clip once from the start (a tap). A clip that ends
      /// deflected (EndsAtRest = FALSE) plays back to rest afterwards.
      /// </summary>
      procedure Play();
      /// <summary>Loops the clip from the start until Stop or Release.</summary>
      procedure PlayLoop();
      /// <summary>
      /// Input down: plays (from the current time) to PeakTime and holds.
      /// </summary>
      procedure Press();
      /// <summary>
      /// Input up: returns smoothly to the rest pose. Before PeakTime the clip
      /// plays backwards, behind it forwards to its end - unless it ends
      /// deflected (EndsAtRest = FALSE), then always backwards.
      /// </summary>
      procedure Release();
      /// <summary>
      /// Analog input: 0 = rest, 1 = PeakTime. Values in between pick the
      /// pose of the clip at AValue * PeakTime. 0 deactivates the clip.
      /// </summary>
      procedure SetValue(const AValue : Single);
      /// <summary>Puts the play head at ATime (seconds) and holds there.</summary>
      procedure SeekTo(const ATime : Single);
      /// <summary>Snaps back to rest immediately.</summary>
      procedure Stop();
  end;

  TGorillaParallelClipList = TObjectList<TGorillaParallelClip>;

  /// <summary>
  /// Internal ticker: an endless FMX animation below the model, so the
  /// animator advances on the same clock as Gorilla3D's own animations (the
  /// render clock from Delphi 13 on, the FMX animation thread before).
  /// </summary>
  TGorillaParallelTicker = class(TAnimation)
    protected
      [Unsafe]
      FAnimator : TGorillaParallelAnimator;
      FLastTime : Single;

      procedure FirstFrame(); override;
      procedure ProcessAnimation(); override;

    public
      constructor Create(AOwner : TComponent); override;

      procedure Start(); override;
      procedure Stop(); override;
  end;

  /// <summary>
  /// Extracts the clips of a model into independent TGorillaParallelClip
  /// instances and plays any number of them at the same time - see the unit
  /// description.
  /// </summary>
  [ComponentPlatforms(pfidAllGorillaPlatforms)]
  TGorillaParallelAnimator = class(TComponent)
    protected
      FModel      : TGorillaModel;
      FClips      : TGorillaParallelClipList;
      FClipMap    : TDictionary<String, TGorillaParallelClip>;
      FJoints     : TObjectList<TGorillaParallelJoint>;
      FJointMap   : TDictionary<TGorillaTransform, TGorillaParallelJoint>;
      FTicker     : TGorillaParallelTicker;
      FAutoUpdate : Boolean;
      FUpdating   : Boolean;
      FOnClipFinished : TGorillaParallelClipEvent;

      procedure SetModel(const AValue : TGorillaModel);
      procedure SetAutoUpdate(const AValue : Boolean);
      function GetClipCount() : Integer;
      function GetClipByIndex(const AIndex : Integer) : TGorillaParallelClip;

      procedure Notification(AComponent : TComponent; AOperation : TOperation); override;

      function FindOrAddJoint(const AJoint : TGorillaTransform) : TGorillaParallelJoint;
      procedure ExtractClips();
      procedure UpdateTicker();
      /// <summary>
      /// Requests a new frame - also the one that ticks the render clock.
      /// </summary>
      procedure RequestFrame();
      /// <summary>Writes the combined pose of all active clips.</summary>
      procedure ApplyPose();

    public
      /// <summary>Extracted clips, sorted by name.</summary>
      property Clips[const AIndex : Integer] : TGorillaParallelClip read GetClipByIndex;
      property ClipCount : Integer read GetClipCount;
      /// <summary>All joints moved by at least one clip.</summary>
      property Joints : TObjectList<TGorillaParallelJoint> read FJoints;

      constructor Create(AOwner : TComponent); override;
      destructor Destroy(); override;

      /// <summary>
      /// Extracts the clips of Model again, f.e. after AddAnimationFromFile.
      /// All clips are stopped, the model is reset to its bind pose.
      /// </summary>
      procedure Rebuild();
      /// <summary>Case-insensitive lookup, nil if the clip does not exist or
      /// does not move anything.</summary>
      function FindClip(const AName : String) : TGorillaParallelClip;
      /// <summary>Names of all extracted clips, sorted.</summary>
      function GetClipNames() : TArray<String>;

      /// <summary>Shortcuts for FindClip(AName).Play() etc. They return FALSE
      /// and do nothing if the clip does not exist.</summary>
      function Play(const AName : String) : Boolean;
      function PlayLoop(const AName : String) : Boolean;
      function Press(const AName : String) : Boolean;
      function Release(const AName : String) : Boolean;
      function SetValue(const AName : String; const AValue : Single) : Boolean;
      function Stop(const AName : String) : Boolean;
      /// <summary>
      /// Drives two opposite clips by one axis value -1..1: negative values go
      /// to ANegative, positive ones to APositive, the other one is set to 0.
      /// </summary>
      /// <example>
      ///   SetAxis('Stick_Left_Left', 'Stick_Left_Right', LGamepad.LeftX);
      ///   SetAxis('Stick_Left_Down', 'Stick_Left_Up', LGamepad.LeftY);
      /// </example>
      function SetAxis(const ANegative, APositive : String; const AValue : Single) : Boolean;
      /// <summary>Snaps all clips back to rest.</summary>
      procedure StopAll();
      /// <summary>True if any clip contributes to the pose.</summary>
      function IsAnyActive() : Boolean;

      /// <summary>
      /// Advances all clips by ADeltaTime seconds and writes the pose.
      /// Called automatically while AutoUpdate is set - call it yourself, f.e.
      /// from TGorillaViewport.OnBeforeRender, if AutoUpdate is off.
      /// </summary>
      procedure Update(const ADeltaTime : Single);

    published
      /// <summary>
      /// The model to animate. Assigning it extracts the clips, resets the
      /// model to its bind pose and stops its AnimationManager.
      /// </summary>
      property Model : TGorillaModel read FModel write SetModel;
      /// <summary>
      /// Advance the clips automatically on Gorilla3D's animation clock
      /// (default). Switch off to drive Update() yourself.
      /// </summary>
      property AutoUpdate : Boolean read FAutoUpdate write SetAutoUpdate default true;
      /// <summary>
      /// Called when a clip played with Play or Release reached its end.
      /// </summary>
      property OnClipFinished : TGorillaParallelClipEvent read FOnClipFinished write FOnClipFinished;
  end;

implementation

uses
  Gorilla.DefTypes,
  Gorilla.Animation,
  Gorilla.Armature,
  Gorilla.Utils.Math;

const
  /// A track whose keys stay closer than this to its first key is constant
  /// (exported for every bone by Blender) and dropped.
  PARALLEL_POS_EPSILON   = 1E-5;  // model units
  PARALLEL_ROT_EPSILON   = 1E-4;  // radians
  PARALLEL_SCALE_EPSILON = 1E-5;
  /// sampling rate for the peak time detection
  PARALLEL_PEAK_SAMPLES_PER_SECOND = 120;
  /// FMX skips animations with a duration near 0 - any long value will do,
  /// the ticker loops and only uses the time differences
  PARALLEL_TICKER_DURATION = 1000;

{ helpers }

/// Splits an affine matrix (S * R * T, row vectors) into its parts. The
/// rotation is returned as a pure 4x4 rotation matrix.
function DecomposeMatrix(const AMat : TMatrix3D; out APos, AScale : TPoint3D;
  out ARot : TMatrix3D) : Boolean;
const
  MIN_SCALE = 1E-6;
var I : Integer;
begin
  APos := TPoint3D(AMat.M[3]);

  AScale.X := TPoint3D(AMat.M[0]).Length;
  AScale.Y := TPoint3D(AMat.M[1]).Length;
  AScale.Z := TPoint3D(AMat.M[2]).Length;

  ARot := TMatrix3D.Identity;
  if (AScale.X < MIN_SCALE) or (AScale.Y < MIN_SCALE) or (AScale.Z < MIN_SCALE) then
    Exit(false);

  for I := 0 to 2 do
  begin
    ARot.M[I].X := AMat.M[I].X / AScale.V[I];
    ARot.M[I].Y := AMat.M[I].Y / AScale.V[I];
    ARot.M[I].Z := AMat.M[I].Z / AScale.V[I];
  end;

  Result := true;
end;

function QuatDot(const A, B : TQuaternion3D) : Single;
begin
  Result := A.ImagPart.X * B.ImagPart.X + A.ImagPart.Y * B.ImagPart.Y
          + A.ImagPart.Z * B.ImagPart.Z + A.RealPart * B.RealPart;
end;

function QuatConjugate(const A : TQuaternion3D) : TQuaternion3D;
begin
  Result.ImagPart := -A.ImagPart;
  Result.RealPart := A.RealPart;
end;

/// Angle in radians between two rotations (q and -q are the same rotation).
/// Measured by the chord between both quaternions: 2 * ArcCos(|dot|) is
/// useless here, in single precision the dot of two EQUAL quaternions comes
/// out as 0.99999994 - which ArcCos turns into 0.0007 rad.
function QuatAngle(const A, B : TQuaternion3D) : Single;
var LMinus, LPlus : Single;
begin
  LMinus := Sqrt(Sqr(A.ImagPart.X - B.ImagPart.X) + Sqr(A.ImagPart.Y - B.ImagPart.Y)
    + Sqr(A.ImagPart.Z - B.ImagPart.Z) + Sqr(A.RealPart - B.RealPart));
  LPlus := Sqrt(Sqr(A.ImagPart.X + B.ImagPart.X) + Sqr(A.ImagPart.Y + B.ImagPart.Y)
    + Sqr(A.ImagPart.Z + B.ImagPart.Z) + Sqr(A.RealPart + B.RealPart));
  // chord c of the quaternion arc: rotation angle = 4 * ArcSin(c / 2)
  Result := 4 * ArcSin(Min(1, Min(LMinus, LPlus) / 2));
end;

/// Shortest-path spherical linear interpolation, same as the one of
/// TTransformationKeyAnimation (Gorilla.Animation.pas).
function QuatSlerp(const A, B : TQuaternion3D; const AT : Single) : TQuaternion3D;
const
  LERP_THRESHOLD = 0.9995;
var LCos, LTheta, LSin, LW1, LW2, LSign, LLen : Single;
begin
  LCos := QuatDot(A, B);
  if (LCos < 0) then
  begin
    LSign := -1;
    LCos := -LCos;
  end
  else
    LSign := 1;

  if (LCos > LERP_THRESHOLD) then
  begin
    LW1 := 1 - AT;
    LW2 := AT * LSign;
  end
  else
  begin
    LTheta := ArcCos(LCos);
    LSin := Sin(LTheta);
    LW1 := Sin((1 - AT) * LTheta) / LSin;
    LW2 := Sin(AT * LTheta) / LSin * LSign;
  end;

  Result.ImagPart := A.ImagPart * LW1 + B.ImagPart * LW2;
  Result.RealPart := A.RealPart * LW1 + B.RealPart * LW2;

  LLen := Sqrt(QuatDot(Result, Result));
  if (LLen > 0) then
  begin
    Result.ImagPart := Result.ImagPart / LLen;
    Result.RealPart := Result.RealPart / LLen;
  end;
end;

function SafeRatio(const AValue, ABase : Single) : Single;
begin
  if (Abs(ABase) < 1E-6) then
    Result := 1
  else
    Result := AValue / ABase;
end;

{ TGorillaParallelJoint }

constructor TGorillaParallelJoint.Create(const AJoint : TGorillaTransform;
  const AIndex : Integer);
begin
  inherited Create();

  FJoint := AJoint;
  FIndex := AIndex;

  // the rest pose is the transformation the joint was loaded with - the same
  // one TGorillaAnimationManager.ResetToBindPose restores
  if (AJoint.Def is TTransformDef) then
  begin
    FRestMatrix := TTransformDef(AJoint.Def).Transform;
    FName := AJoint.Def.Id;
  end
  else
  begin
    FRestMatrix := AJoint.TransformMatrix;
    FName := AJoint.Name;
  end;

  if (FName = '') then
    FName := AJoint.Name;

  DecomposeMatrix(FRestMatrix, FRestPos, FRestScale, FRestRot);
end;

{ TGorillaParallelTrack }

function TGorillaParallelTrack.GetKeyCount() : Integer;
begin
  Result := Length(FTimes);
end;

function TGorillaParallelTrack.GetDuration() : Single;
begin
  if (Length(FTimes) = 0) then
    Result := 0
  else
    Result := FTimes[High(FTimes)];
end;

procedure TGorillaParallelTrack.Sample(const ATime : Single; out APos,
  AScale : TPoint3D; out ARot : TQuaternion3D);
var LLow, LHigh, LMid : Integer;
    LFrac : Single;
begin
  if (Length(FTimes) = 0) then
  begin
    APos := FBasePos;
    AScale := FBaseScale;
    ARot := TQuaternion3D.Identity;
    Exit;
  end;

  if (Length(FTimes) = 1) or (ATime <= FTimes[0]) then
  begin
    APos := FPositions[0];
    AScale := FScales[0];
    ARot := FRotations[0];
    Exit;
  end;

  if (ATime >= FTimes[High(FTimes)]) then
  begin
    APos := FPositions[High(FTimes)];
    AScale := FScales[High(FTimes)];
    ARot := FRotations[High(FTimes)];
    Exit;
  end;

  // last key with a time <= ATime
  LLow := 0;
  LHigh := High(FTimes);
  while (LHigh - LLow > 1) do
  begin
    LMid := (LLow + LHigh) div 2;
    if (FTimes[LMid] <= ATime) then
      LLow := LMid
    else
      LHigh := LMid;
  end;

  if (FTimes[LHigh] - FTimes[LLow] > 0) then
    LFrac := (ATime - FTimes[LLow]) / (FTimes[LHigh] - FTimes[LLow])
  else
    LFrac := 0;

  APos := FPositions[LLow] + (FPositions[LHigh] - FPositions[LLow]) * LFrac;
  AScale := FScales[LLow] + (FScales[LHigh] - FScales[LLow]) * LFrac;
  ARot := QuatSlerp(FRotations[LLow], FRotations[LHigh], LFrac);
end;

procedure TGorillaParallelTrack.Deviation(const ATime : Single; out APos, ARot,
  AScale : Single);
var LPos, LScale : TPoint3D;
    LRot : TQuaternion3D;
begin
  Sample(ATime, LPos, LScale, LRot);
  APos := (LPos - FBasePos).Length;
  ARot := QuatAngle(LRot, FRotations[0]);
  AScale := Max(Abs(LScale.X - FBaseScale.X),
    Max(Abs(LScale.Y - FBaseScale.Y), Abs(LScale.Z - FBaseScale.Z)));
end;

{ TGorillaParallelClip }

constructor TGorillaParallelClip.Create(const AAnimator : TGorillaParallelAnimator;
  const AName : String);
begin
  inherited Create();

  FAnimator := AAnimator;
  FName := AName;
  FTracks := TGorillaParallelTrackList.Create(true);
  FMode := TGorillaParallelPlayMode.pmIdle;
  FSpeed := 1;
  FWeight := 1;
end;

destructor TGorillaParallelClip.Destroy();
begin
  FreeAndNil(FTracks);

  inherited;
end;

function TGorillaParallelClip.GetIsActive() : Boolean;
begin
  Result := (FMode <> TGorillaParallelPlayMode.pmIdle);
end;

procedure TGorillaParallelClip.SetPeakTime(const AValue : Single);
begin
  FPeakTime := EnsureRange(AValue, 0, FDuration);
end;

procedure TGorillaParallelClip.SetWeight(const AValue : Single);
begin
  FWeight := EnsureRange(AValue, 0, 1);
  Changed();
end;

procedure TGorillaParallelClip.SetSpeed(const AValue : Single);
begin
  FSpeed := Max(AValue, 0);
end;

procedure TGorillaParallelClip.DetectPeakTime();
var LTrack : TGorillaParallelTrack;
    LMaxPos, LMaxRot, LMaxScale : array of Single;
    LPos, LRot, LScale, LSum, LBest, LTime : Single;
    LSteps, I, J : Integer;
begin
  FDuration := 0;
  for LTrack in FTracks do
    FDuration := Max(FDuration, LTrack.Duration);

  FPeakTime := FDuration;
  FEndsAtRest := true;
  if (FDuration <= 0) or (FTracks.Count = 0) then
    Exit;

  LSteps := Max(2, Ceil(FDuration * PARALLEL_PEAK_SAMPLES_PER_SECOND));

  // 1) largest deviation per track, to weigh translation and rotation alike
  SetLength(LMaxPos, FTracks.Count);
  SetLength(LMaxRot, FTracks.Count);
  SetLength(LMaxScale, FTracks.Count);
  for J := 0 to FTracks.Count - 1 do
  begin
    LMaxPos[J] := 0;
    LMaxRot[J] := 0;
    LMaxScale[J] := 0;
    for I := 0 to LSteps do
    begin
      FTracks[J].Deviation(FDuration * I / LSteps, LPos, LRot, LScale);
      LMaxPos[J] := Max(LMaxPos[J], LPos);
      LMaxRot[J] := Max(LMaxRot[J], LRot);
      LMaxScale[J] := Max(LMaxScale[J], LScale);
    end;

    // still deflected at the end? (f.e. 2-key clips "rest -> pressed")
    FTracks[J].Deviation(FDuration, LPos, LRot, LScale);
    if (LPos > Max(PARALLEL_POS_EPSILON, LMaxPos[J] * 0.1))
    or (LRot > Max(PARALLEL_ROT_EPSILON, LMaxRot[J] * 0.1))
    or (LScale > Max(PARALLEL_SCALE_EPSILON, LMaxScale[J] * 0.1)) then
      FEndsAtRest := false;
  end;

  // 2) the time where all tracks together are deflected most
  LBest := -1;
  for I := 0 to LSteps do
  begin
    LTime := FDuration * I / LSteps;
    LSum := 0;
    for J := 0 to FTracks.Count - 1 do
    begin
      FTracks[J].Deviation(LTime, LPos, LRot, LScale);
      if (LMaxPos[J] > PARALLEL_POS_EPSILON) then
        LSum := LSum + LPos / LMaxPos[J];
      if (LMaxRot[J] > PARALLEL_ROT_EPSILON) then
        LSum := LSum + LRot / LMaxRot[J];
      if (LMaxScale[J] > PARALLEL_SCALE_EPSILON) then
        LSum := LSum + LScale / LMaxScale[J];
    end;

    // ">" keeps the FIRST maximum of a plateau - a button held down in the
    // file reaches its end position there
    if (LSum > LBest + 1E-4) then
    begin
      LBest := LSum;
      FPeakTime := LTime;
    end;
  end;
end;

procedure TGorillaParallelClip.Changed();
begin
  if Assigned(FAnimator) then
    FAnimator.RequestFrame();
end;

function TGorillaParallelClip.Advance(const ADeltaTime : Single) : Boolean;
var LStep : Single;
begin
  Result := false;
  LStep := ADeltaTime * FSpeed;

  case FMode of
    TGorillaParallelPlayMode.pmOnce :
      begin
        FTime := FTime + LStep;
        if (FTime >= FDuration) then
        begin
          if FEndsAtRest then
          begin
            FTime := 0;
            FMode := TGorillaParallelPlayMode.pmIdle;
            Result := true;
          end
          else
          begin
            // ends deflected - the way back is the way in, reversed
            FTime := FDuration;
            FMode := TGorillaParallelPlayMode.pmRelease;
          end;
        end;
      end;

    TGorillaParallelPlayMode.pmLoop :
      begin
        if (FDuration > 0) then
          FTime := FMod(FTime + LStep, FDuration)
        else
          FTime := 0;
      end;

    TGorillaParallelPlayMode.pmHold :
      begin
        if (FTime < FPeakTime) then
          FTime := Min(FTime + LStep, FPeakTime)
        else if (FTime > FPeakTime) then
          // pressed again while returning behind the peak - go back to it
          FTime := Max(FTime - LStep, FPeakTime);
      end;

    TGorillaParallelPlayMode.pmRelease :
      begin
        if (FTime <= FPeakTime) or not FEndsAtRest then
        begin
          // released before the peak - or a clip without a way back of its
          // own: the way back is the way in, reversed
          FTime := FTime - LStep;
          if (FTime <= 0) then
          begin
            FTime := 0;
            FMode := TGorillaParallelPlayMode.pmIdle;
            Result := true;
          end;
        end
        else
        begin
          // behind the peak the clip carries its own way back to rest
          FTime := FTime + LStep;
          if (FTime >= FDuration) then
          begin
            FTime := 0;
            FMode := TGorillaParallelPlayMode.pmIdle;
            Result := true;
          end;
        end;
      end;
  end;
end;

procedure TGorillaParallelClip.Play();
begin
  FTime := 0;
  FMode := TGorillaParallelPlayMode.pmOnce;
  Changed();
end;

procedure TGorillaParallelClip.PlayLoop();
begin
  FTime := 0;
  FMode := TGorillaParallelPlayMode.pmLoop;
  Changed();
end;

procedure TGorillaParallelClip.Press();
begin
  // a looping or finished clip starts over, a returning one turns around
  if (FMode in [TGorillaParallelPlayMode.pmIdle, TGorillaParallelPlayMode.pmLoop,
    TGorillaParallelPlayMode.pmOnce]) then
    FTime := 0;

  FMode := TGorillaParallelPlayMode.pmHold;
  Changed();
end;

procedure TGorillaParallelClip.Release();
begin
  if (FMode = TGorillaParallelPlayMode.pmIdle) then
    Exit;

  FMode := TGorillaParallelPlayMode.pmRelease;
  Changed();
end;

procedure TGorillaParallelClip.SetValue(const AValue : Single);
begin
  FValue := EnsureRange(AValue, 0, 1);
  FTime := FValue * FPeakTime;

  if (FValue > 0) then
    FMode := TGorillaParallelPlayMode.pmValue
  else
    FMode := TGorillaParallelPlayMode.pmIdle;

  Changed();
end;

procedure TGorillaParallelClip.SeekTo(const ATime : Single);
begin
  FTime := EnsureRange(ATime, 0, FDuration);
  FValue := 0;
  FMode := TGorillaParallelPlayMode.pmValue;
  Changed();
end;

procedure TGorillaParallelClip.Stop();
begin
  FTime := 0;
  FValue := 0;
  FMode := TGorillaParallelPlayMode.pmIdle;
  Changed();
end;

{ TGorillaParallelTicker }

constructor TGorillaParallelTicker.Create(AOwner : TComponent);
begin
  inherited;

  Stored := false;
  Loop := true;
  Duration := PARALLEL_TICKER_DURATION;
end;

procedure TGorillaParallelTicker.FirstFrame();
begin
  inherited;

  FLastTime := CurrentTime;
end;

procedure TGorillaParallelTicker.ProcessAnimation();
var LDelta : Single;
begin
  LDelta := CurrentTime - FLastTime;
  // the loop wrapped around
  if (LDelta < 0) then
    LDelta := LDelta + Duration;
  FLastTime := CurrentTime;

  if Assigned(FAnimator) and (LDelta > 0) then
    FAnimator.Update(LDelta);
end;

procedure TGorillaParallelTicker.Start();
begin
  inherited;

{$IF CompilerVersion >= 37.0}
  // after inherited, so a Start that did not take hands over no clock
  if Self.Running then
    TGorillaRenderClock.TakeOver(Self);
{$ENDIF}
end;

procedure TGorillaParallelTicker.Stop();
begin
{$IF CompilerVersion >= 37.0}
  TGorillaRenderClock.Release(Self);
{$ENDIF}

  inherited;
end;

{ TGorillaParallelAnimator }

constructor TGorillaParallelAnimator.Create(AOwner : TComponent);
begin
  inherited;

  FClips := TGorillaParallelClipList.Create(true);
  FClipMap := TDictionary<String, TGorillaParallelClip>.Create();
  FJoints := TObjectList<TGorillaParallelJoint>.Create(true);
  FJointMap := TDictionary<TGorillaTransform, TGorillaParallelJoint>.Create();
  FAutoUpdate := true;
end;

destructor TGorillaParallelAnimator.Destroy();
begin
  if Assigned(FTicker) then
  begin
    FTicker.Stop();
    FreeAndNil(FTicker);
  end;

  if Assigned(FModel) then
    FModel.RemoveFreeNotification(Self);
  FModel := nil;

  FreeAndNil(FClipMap);
  FreeAndNil(FClips);
  FreeAndNil(FJointMap);
  FreeAndNil(FJoints);

  inherited;
end;

procedure TGorillaParallelAnimator.Notification(AComponent : TComponent;
  AOperation : TOperation);
begin
  inherited;

  if (AOperation <> opRemove) then
    Exit;

  // the ticker is a child of the model - a destroyed model takes it along
  if (AComponent = FTicker) then
    FTicker := nil;

  if (AComponent = FModel) then
  begin
    FModel := nil;
    // joints and tracks point into the destroyed model
    FClipMap.Clear();
    FClips.Clear();
    FJointMap.Clear();
    FJoints.Clear();
  end;
end;

procedure TGorillaParallelAnimator.SetModel(const AValue : TGorillaModel);
begin
  if (FModel = AValue) then
    Exit;

  if Assigned(FTicker) then
  begin
    FTicker.Stop();
    FreeAndNil(FTicker);
  end;

  if Assigned(FModel) then
  begin
    // leave the old model in its rest pose
    StopAll();
    ApplyPose();
    FModel.RemoveFreeNotification(Self);
  end;

  FModel := AValue;

  if Assigned(FModel) then
    FModel.FreeNotification(Self);

  Rebuild();
end;

procedure TGorillaParallelAnimator.SetAutoUpdate(const AValue : Boolean);
begin
  FAutoUpdate := AValue;
  UpdateTicker();
end;

function TGorillaParallelAnimator.GetClipCount() : Integer;
begin
  Result := FClips.Count;
end;

function TGorillaParallelAnimator.GetClipByIndex(const AIndex : Integer) : TGorillaParallelClip;
begin
  Result := FClips[AIndex];
end;

function TGorillaParallelAnimator.FindOrAddJoint(const AJoint : TGorillaTransform) : TGorillaParallelJoint;
begin
  if FJointMap.TryGetValue(AJoint, Result) then
    Exit;

  Result := TGorillaParallelJoint.Create(AJoint, FJoints.Count);
  FJoints.Add(Result);
  FJointMap.Add(AJoint, Result);
end;

procedure TGorillaParallelAnimator.ExtractClips();

  /// Builds a track from the keys of one target of an interpolator. Returns
  /// nil if the target does not move (constant track).
  function ExtractTrack(const AInter : TTransformationKeyAnimation;
    const ATarget : TGorillaTransform; const AUseElement : Boolean) : TGorillaParallelTrack;
  var LCount, I : Integer;
      LKey      : TTransformationKey;
      LMat, LRotMat : TMatrix3D;
      LDuration : Single;
      LMaxPos, LMaxRot, LMaxScale : Single;
  begin
    Result := nil;

    LCount := AInter.Keys.Count;
    if (LCount < 2) then
      Exit;

    LDuration := Abs(AInter.Duration);

    Result := TGorillaParallelTrack.Create();
    try
      SetLength(Result.FTimes, LCount);
      SetLength(Result.FPositions, LCount);
      SetLength(Result.FScales, LCount);
      SetLength(Result.FRotations, LCount);

      for I := 0 to LCount - 1 do
      begin
        LKey := AInter.Keys.Items[I] as TTransformationKey;
        // key times are normalized to 0..1 of the interpolator duration
        Result.FTimes[I] := LKey.Key * LDuration;

        if AUseElement then
          LMat := LKey.Value[ATarget]
        else
          LMat := LKey.GetDefaultValue();

        DecomposeMatrix(LMat, Result.FPositions[I], Result.FScales[I], LRotMat);
        Result.FRotations[I] := TQuaternion3D.Create(LRotMat);

        // keep the quaternions on one hemisphere, q and -q are the same
        // rotation and would make the interpolation take the long way
        if (I > 0) and (QuatDot(Result.FRotations[I], Result.FRotations[I - 1]) < 0) then
        begin
          Result.FRotations[I].ImagPart := -Result.FRotations[I].ImagPart;
          Result.FRotations[I].RealPart := -Result.FRotations[I].RealPart;
        end;
      end;

      Result.FBasePos := Result.FPositions[0];
      Result.FBaseScale := Result.FScales[0];
      Result.FBaseRotInv := TMatrix3D(QuatConjugate(Result.FRotations[0]));

      // constant track? - Blender writes every bone into every action
      LMaxPos := 0;
      LMaxRot := 0;
      LMaxScale := 0;
      for I := 1 to LCount - 1 do
      begin
        LMaxPos := Max(LMaxPos, (Result.FPositions[I] - Result.FBasePos).Length);
        LMaxRot := Max(LMaxRot, QuatAngle(Result.FRotations[I], Result.FRotations[0]));
        LMaxScale := Max(LMaxScale, Max(Abs(Result.FScales[I].X - Result.FBaseScale.X),
          Max(Abs(Result.FScales[I].Y - Result.FBaseScale.Y),
              Abs(Result.FScales[I].Z - Result.FBaseScale.Z))));
      end;

      if (LMaxPos <= PARALLEL_POS_EPSILON) and (LMaxRot <= PARALLEL_ROT_EPSILON)
      and (LMaxScale <= PARALLEL_SCALE_EPSILON) then
        FreeAndNil(Result);
    except
      FreeAndNil(Result);
      raise;
    end;
  end;

var LAnims : TArray<TGorillaAnimation>;
    LAnim  : TGorillaAnimation;
    LInter : TPropertyKeyAnimation;
    LComp  : TComponent;
    LClip  : TGorillaParallelClip;
    LTrack : TGorillaParallelTrack;
    LName  : String;
    I      : Integer;
begin
  if not (Assigned(FModel) and Assigned(FModel.AnimationManager)) then
    Exit;

  // sorted by name, so Clips[] has a stable order
  LAnims := FModel.AnimationManager.GetSortedAnimations();
  for LAnim in LAnims do
  begin
    if not (Assigned(LAnim) and Assigned(LAnim.Skeleton)
      and Assigned(LAnim.Skeleton.Interpolators)) then
      Continue;

    if Assigned(LAnim.Def) and (LAnim.Def.Id <> '') then
      LName := LAnim.Def.Id
    else
      LName := LAnim.Id;

    // two clips of the same name: the first one wins
    if FClipMap.ContainsKey(LowerCase(LName)) then
      Continue;

    LClip := TGorillaParallelClip.Create(Self, LName);
    try
      for I := 0 to LAnim.Skeleton.Interpolators.Count - 1 do
      begin
        LInter := LAnim.Skeleton.Interpolators[I];
        // glTF / FBX / DAE skeletons are unified to matrix keys on load
        // (TAnimationDef.UnifyInterpolators), written to "TransformMatrix"
        if not (LInter is TTransformationKeyAnimation) then
          Continue;

        if Assigned(LInter.Elements) and (LInter.Elements.Count > 0) then
        begin
          for LComp in LInter.Elements.Keys do
          begin
            if not (LComp is TGorillaTransform) then
              Continue;

            LTrack := ExtractTrack(TTransformationKeyAnimation(LInter),
              TGorillaTransform(LComp), true);
            if Assigned(LTrack) then
            begin
              LTrack.FJoint := FindOrAddJoint(TGorillaTransform(LComp));
              LClip.FTracks.Add(LTrack);
            end;
          end;
        end
        else if (LInter.Parent is TGorillaTransform) then
        begin
          // without elements an interpolator writes to its parent
          LTrack := ExtractTrack(TTransformationKeyAnimation(LInter),
            TGorillaTransform(LInter.Parent), false);
          if Assigned(LTrack) then
          begin
            LTrack.FJoint := FindOrAddJoint(TGorillaTransform(LInter.Parent));
            LClip.FTracks.Add(LTrack);
          end;
        end;
      end;

      // a clip that moves nothing (f.e. "EmptyAction") is not offered
      if (LClip.FTracks.Count = 0) then
      begin
        FreeAndNil(LClip);
        Continue;
      end;

      LClip.DetectPeakTime();
    except
      FreeAndNil(LClip);
      raise;
    end;

    FClips.Add(LClip);
    FClipMap.Add(LowerCase(LName), LClip);
  end;
end;

procedure TGorillaParallelAnimator.Rebuild();
begin
  FClipMap.Clear();
  FClips.Clear();
  FJointMap.Clear();
  FJoints.Clear();

  if Assigned(FModel) then
  begin
    // the manager must not write the same joints - stop it and start from
    // the bind pose, the additive pose is built on top of it
    FModel.ResetToBindPose();
    ExtractClips();
  end;

  UpdateTicker();
end;

procedure TGorillaParallelAnimator.UpdateTicker();
var LRun : Boolean;
begin
  LRun := FAutoUpdate and Assigned(FModel) and (FClips.Count > 0)
    and not (csDesigning in ComponentState);

  if not LRun then
  begin
    if Assigned(FTicker) then
    begin
      FTicker.Stop();
      FreeAndNil(FTicker);
    end;
    Exit;
  end;

  if not Assigned(FTicker) then
  begin
    FTicker := TGorillaParallelTicker.Create(Self);
    FTicker.FAnimator := Self;
    // below the model, so FMX finds a root and the clock reaches it
    FTicker.Parent := FModel;
  end;

  if not FTicker.Running then
    FTicker.Start();
end;

procedure TGorillaParallelAnimator.RequestFrame();
begin
  // the render clock only ticks while frames are rendered - a clip started
  // in an idle scene needs one to get going
  if Assigned(FModel) then
    FModel.Repaint();
end;

function TGorillaParallelAnimator.FindClip(const AName : String) : TGorillaParallelClip;
begin
  if not FClipMap.TryGetValue(LowerCase(AName), Result) then
    Result := nil;
end;

function TGorillaParallelAnimator.GetClipNames() : TArray<String>;
var I : Integer;
begin
  SetLength(Result, FClips.Count);
  for I := 0 to FClips.Count - 1 do
    Result[I] := FClips[I].Name;
end;

function TGorillaParallelAnimator.Play(const AName : String) : Boolean;
var LClip : TGorillaParallelClip;
begin
  LClip := FindClip(AName);
  Result := Assigned(LClip);
  if Result then
    LClip.Play();
end;

function TGorillaParallelAnimator.PlayLoop(const AName : String) : Boolean;
var LClip : TGorillaParallelClip;
begin
  LClip := FindClip(AName);
  Result := Assigned(LClip);
  if Result then
    LClip.PlayLoop();
end;

function TGorillaParallelAnimator.Press(const AName : String) : Boolean;
var LClip : TGorillaParallelClip;
begin
  LClip := FindClip(AName);
  Result := Assigned(LClip);
  if Result then
    LClip.Press();
end;

function TGorillaParallelAnimator.Release(const AName : String) : Boolean;
var LClip : TGorillaParallelClip;
begin
  LClip := FindClip(AName);
  Result := Assigned(LClip);
  if Result then
    LClip.Release();
end;

function TGorillaParallelAnimator.SetValue(const AName : String;
  const AValue : Single) : Boolean;
var LClip : TGorillaParallelClip;
begin
  LClip := FindClip(AName);
  Result := Assigned(LClip);
  if Result then
    LClip.SetValue(AValue);
end;

function TGorillaParallelAnimator.Stop(const AName : String) : Boolean;
var LClip : TGorillaParallelClip;
begin
  LClip := FindClip(AName);
  Result := Assigned(LClip);
  if Result then
    LClip.Stop();
end;

function TGorillaParallelAnimator.SetAxis(const ANegative, APositive : String;
  const AValue : Single) : Boolean;
var LNeg, LPos : Boolean;
begin
  LNeg := SetValue(ANegative, Max(-AValue, 0));
  LPos := SetValue(APositive, Max(AValue, 0));
  Result := LNeg or LPos;
end;

procedure TGorillaParallelAnimator.StopAll();
var LClip : TGorillaParallelClip;
begin
  for LClip in FClips do
  begin
    LClip.FTime := 0;
    LClip.FValue := 0;
    LClip.FMode := TGorillaParallelPlayMode.pmIdle;
  end;

  RequestFrame();
end;

function TGorillaParallelAnimator.IsAnyActive() : Boolean;
var LClip : TGorillaParallelClip;
begin
  for LClip in FClips do
    if LClip.IsActive then
      Exit(true);

  Result := false;
end;

procedure TGorillaParallelAnimator.ApplyPose();
type
  TJointAccu = record
    Used  : Boolean;
    Pos   : TPoint3D;
    Scale : TPoint3D;
    Rot   : TMatrix3D;
  end;
var LAccu   : TArray<TJointAccu>;
    LClip   : TGorillaParallelClip;
    LTrack  : TGorillaParallelTrack;
    LJoint  : TGorillaParallelJoint;
    LPos, LScale : TPoint3D;
    LRot, LDeltaQ : TQuaternion3D;
    LDelta  : TMatrix3D;
    LWeight : Single;
    LChanged : Boolean;
    I       : Integer;
begin
  if not Assigned(FModel) or (FJoints.Count = 0) then
    Exit;

  SetLength(LAccu, FJoints.Count);
  for I := 0 to High(LAccu) do
  begin
    LAccu[I].Used := false;
    LAccu[I].Pos := TPoint3D.Zero;
    LAccu[I].Scale := Point3D(1, 1, 1);
    LAccu[I].Rot := TMatrix3D.Identity;
  end;

  // 1) sum up the contributions of all active clips per joint
  for LClip in FClips do
  begin
    if not LClip.IsActive or (LClip.FWeight <= 0) then
      Continue;

    LWeight := LClip.FWeight;
    for LTrack in LClip.FTracks do
    begin
      LTrack.Sample(LClip.FTime, LPos, LScale, LRot);
      I := LTrack.FJoint.FIndex;

      LAccu[I].Used := true;
      LAccu[I].Pos := LAccu[I].Pos + (LPos - LTrack.FBasePos) * LWeight;
      LAccu[I].Scale.X := LAccu[I].Scale.X * (1 + (SafeRatio(LScale.X, LTrack.FBaseScale.X) - 1) * LWeight);
      LAccu[I].Scale.Y := LAccu[I].Scale.Y * (1 + (SafeRatio(LScale.Y, LTrack.FBaseScale.Y) - 1) * LWeight);
      LAccu[I].Scale.Z := LAccu[I].Scale.Z * (1 + (SafeRatio(LScale.Z, LTrack.FBaseScale.Z) - 1) * LWeight);

      // rotation relative to the first key, in the joint's own space:
      // R(t) = D * R(0)  ->  D = R(t) * R(0)^-1
      LDelta := TMatrix3D(LRot) * LTrack.FBaseRotInv;
      if (LWeight < 1) then
      begin
        LDeltaQ := QuatSlerp(TQuaternion3D.Identity, TQuaternion3D.Create(LDelta), LWeight);
        LDelta := TMatrix3D(LDeltaQ);
      end;
      LAccu[I].Rot := LAccu[I].Rot * LDelta;
    end;
  end;

  // 2) write the joints: rest pose + contributions, or back to the rest pose
  //    for joints whose clips just ended
  LChanged := false;
  Inc(GorillaPoseWriting);
  try
    for LJoint in FJoints do
    begin
      I := LJoint.FIndex;
      if LAccu[I].Used then
      begin
        LJoint.FJoint.SetLocalTransformMatrix(
          TTransformationMatrixUtils.GetTransformation(
            LJoint.FRestPos + LAccu[I].Pos,
            Point3D(LJoint.FRestScale.X * LAccu[I].Scale.X,
                    LJoint.FRestScale.Y * LAccu[I].Scale.Y,
                    LJoint.FRestScale.Z * LAccu[I].Scale.Z),
            LAccu[I].Rot * LJoint.FRestRot));
        LJoint.FWritten := true;
        LChanged := true;
      end
      else if LJoint.FWritten then
      begin
        LJoint.FJoint.SetLocalTransformMatrix(LJoint.FRestMatrix);
        LJoint.FWritten := false;
        LChanged := true;
      end;
    end;
  finally
    Dec(GorillaPoseWriting);
  end;

  if not LChanged then
    Exit;

  // 3) skin again - joints moved from outside an animation, see
  //    TGorillaAnimationManager.ResetToBindPose
  for I := 0 to FModel.ComponentCount - 1 do
  begin
    if (FModel.Components[I] is TGorillaArmature) then
      TGorillaArmature(FModel.Components[I]).InvalidatePose();
  end;

  FModel.Repaint();
end;

procedure TGorillaParallelAnimator.Update(const ADeltaTime : Single);
var LClip : TGorillaParallelClip;
    LFinished : TList<TGorillaParallelClip>;
begin
  // OnClipFinished may call Update (f.e. through Application.ProcessMessages)
  if FUpdating or not Assigned(FModel) then
    Exit;

  FUpdating := true;
  LFinished := nil;
  try
    for LClip in FClips do
    begin
      if LClip.Advance(Max(ADeltaTime, 0)) then
      begin
        if not Assigned(LFinished) then
          LFinished := TList<TGorillaParallelClip>.Create();
        LFinished.Add(LClip);
      end;
    end;

    ApplyPose();

    if Assigned(LFinished) and Assigned(FOnClipFinished) then
      for LClip in LFinished do
        FOnClipFinished(Self, LClip);
  finally
    FreeAndNil(LFinished);
    FUpdating := false;
  end;
end;

initialization
  RegisterFmxClasses([TGorillaParallelAnimator]);

end.
