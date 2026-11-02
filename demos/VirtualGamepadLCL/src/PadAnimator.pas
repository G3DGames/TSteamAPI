{ @abstract(Plays any number of a gamepad model's glTF clips at once, on
  the joints themselves (Free Pascal; no engine code).)

  Our models (models/*_Animated.glb) have one clip per control
  (A_Press, Stick_Left_Up, Trigger_Right_Press_Full, ...). Every clip
  writes EVERY joint the file animates (Blender exports every bone into
  every action: 51 channels on the Xbox model, 48 on the PS5, 63 on the
  Steam Controller), but moves only one of them. Playing two clips the
  normal way therefore makes them fight: the last one written wins and
  puts the other control back to rest.

  This unit reads the clips straight from the .glb file (JSON + binary
  chunk, fpjson), keeps only the channels that really move, and combines
  the clips that are playing ADDITIVELY on the rest pose - the method of
  Gorilla3D's TGorillaParallelAnimator (VirtualGamepad), written again
  here for any engine: translations add their offsets from the clip's
  first key, rotations multiply their turns from it, on top of the
  node's own pose. The result for each joint is
  handed to @link(TPadAnimator.OnApplyJoint); the program writes it into
  its engine's joint (Castle Game Engine: TTransformNode Translation /
  Rotation).

  Controls:
  @unorderedList(
    @item(@link(TPadAnimator.Press) plays a clip to its peak (the key of
      largest movement) and holds it; @link(TPadAnimator.Release) plays it
      back to rest - buttons.)
    @item(@link(TPadAnimator.SetValue) shows a clip at a fraction 0..1 of
      the way to its peak at once - triggers.)
    @item(@link(TPadAnimator.SetAxis) drives a pair of clips from one
      value -1..1 - stick axes.)
  )
  Clips go out and back in the file (rest, peak, rest); only the part up
  to the peak is used. LINEAR and STEP samplers are played; a CUBICSPLINE
  sampler (three values per key) is skipped. }
unit PadAnimator;

{$mode delphi}{$H+}

interface

uses
  SysUtils, Classes, Types;

type
  { A translation (x, y, z), as glTF stores it. }
  TAnimVec3 = record
    { X part. }
    X: Single;
    { Y part. }
    Y: Single;
    { Z part. }
    Z: Single;
  end;

  { A rotation quaternion (x, y, z, w), as glTF stores it. }
  TAnimQuat = record
    { X part. }
    X: Single;
    { Y part. }
    Y: Single;
    { Z part. }
    Z: Single;
    { W (real) part. }
    W: Single;
  end;

  { Called with a joint's new pose (local translation and rotation).
    @param(AJoint Index in @link(TPadAnimator.JointNames).)
    @param(ATranslation Local translation.)
    @param(ARotation Local rotation.) }
  TJointApplyEvent = procedure(AJoint: Integer; const ATranslation: TAnimVec3;
    const ARotation: TAnimQuat) of object;

  { What a clip is doing. }
  TClipMode = (
    { At rest (contributes nothing). }
    cmOff,
    { Playing towards its peak, then holding (button down). }
    cmPress,
    { Playing back to rest (button let go). }
    cmRelease,
    { Shown at a fixed fraction of the way to its peak (trigger / axis). }
    cmValue);

  { One moving channel of a clip: a joint's translation or rotation. }
  TPadChannel = class
  public
    { The joint it moves (index in TPadAnimator's joints). }
    Joint: Integer;
    { Rotation (4 values per key) rather than translation (3). }
    IsRotation: Boolean;
    { STEP interpolation (else LINEAR). }
    Step: Boolean;
    { Key times in seconds. }
    Times: TSingleDynArray;
    { Key values, 3 or 4 per key, in key order. }
    Values: TSingleDynArray;
  end;

  { One clip (glTF animation) with only its moving channels. }
  TPadClip = class
  public
    { The animation's name in the file. }
    Name: string;
    { Time of the key with the largest movement, in seconds. }
    PeakTime: Single;
    { The moving channels (TPadChannel, owned). }
    Channels: array of TPadChannel;
    { What the clip is doing now. }
    Mode: TClipMode;
    { The play head, 0 .. PeakTime. }
    Time: Single;
    { Frees the channels. }
    destructor Destroy; override;
  end;

  { Reads a .glb's clips and plays any number of them at once
    (see the unit description). }
  TPadAnimator = class
  private
    { Names of the joints any clip moves (glTF node names). }
    FJointNames: TStringList;
    { glTF node index of each joint in @link(FJointNames). }
    FJointNodes: array of Integer;
    { Rest translation of each joint (the node's own translation). }
    FRestT: array of TAnimVec3;
    { Rest rotation of each joint (the node's own rotation). }
    FRestR: array of TAnimQuat;
    { Pose last handed to OnApplyJoint, per joint (translation). }
    FLastT: array of TAnimVec3;
    { Pose last handed to OnApplyJoint, per joint (rotation). }
    FLastR: array of TAnimQuat;
    { The pose was handed out at least once, per joint. }
    FApplied: array of Boolean;
    { Every clip with at least one moving channel (owned). }
    FClips: array of TPadClip;
    { Clips in the file, moving or not (for the log). }
    FFileClipCount: Integer;
    { See @link(OnApplyJoint). }
    FOnApplyJoint: TJointApplyEvent;
    { Frees every clip and forgets the joints. }
    procedure Clear;
    { Index of the joint for glTF node ANode, adding it if new.
      @param(ANode glTF node index.)
      @param(ARestT The node's translation.)
      @param(ARestR The node's rotation.)
      @returns(Joint index.) }
    function JointFor(ANode: Integer; const AName: string; const ARestT: TAnimVec3;
      const ARestR: TAnimQuat): Integer;
    { Number of joints. }
    function GetJointCount: Integer;
    { Name of joint I. }
    function GetJointName(I: Integer): string;
    { Number of clips. }
    function GetClipCount: Integer;
    { Name of clip I. }
    function GetClipName(I: Integer): string;
  public
    { Creates an empty animator. }
    constructor Create;
    { Frees the clips. }
    destructor Destroy; override;
    { Reads the clips of a .glb file (replaces any loaded before).
      @param(AFileName The .glb file.)
      @returns('' when done, else what went wrong.) }
    function LoadFromFile(const AFileName: string): string;
    { Index of the clip called AName, or -1.
      @param(AName Clip (animation) name, as in the file.) }
    function FindClip(const AName: string): Integer;
    { Plays clip AName to its peak and holds it.
      @returns(@false when the model has no such moving clip.) }
    function Press(const AName: string): Boolean;
    { Plays clip AName back to rest.
      @returns(@false when the model has no such moving clip.) }
    function Release(const AName: string): Boolean;
    { Shows clip AName at fraction AValue (0..1) of the way to its peak.
      @returns(@false when the model has no such moving clip.) }
    function SetValue(const AName: string; AValue: Single): Boolean;
    { Drives two clips from one axis value: ANeg for AValue < 0, APos for
      AValue > 0 (each at the size of the value), the other at rest. }
    procedure SetAxis(const ANeg, APos: string; AValue: Single);
    { Puts every clip back to rest (the next @link(Update) applies it). }
    procedure StopAll;
    { Advances pressed / released clips by ASeconds and hands every
      joint whose pose changed to @link(OnApplyJoint). }
    procedure Update(ASeconds: Single);
    { Clips the file holds, moving or not. }
    property FileClipCount: Integer read FFileClipCount;
    { Number of clips that move something. }
    property ClipCount: Integer read GetClipCount;
    { Names of the moving clips. }
    property ClipNames[I: Integer]: string read GetClipName;
    { Number of joints the clips move. }
    property JointCount: Integer read GetJointCount;
    { Names of those joints (glTF node names). }
    property JointNames[I: Integer]: string read GetJointName;
    { Receives each joint's new pose from @link(Update). }
    property OnApplyJoint: TJointApplyEvent read FOnApplyJoint write FOnApplyJoint;
  end;

{ The identity rotation. }
function AnimQuatIdentity: TAnimQuat;

{ Quaternion product A * B (B applied first).
  @param(A Left factor.)
  @param(B Right factor.)
  @returns(The product.) }
function AnimQuatMul(const A, B: TAnimQuat): TAnimQuat;

{ Conjugate (the inverse of a unit quaternion).
  @param(Q The quaternion.)
  @returns(Its conjugate.) }
function AnimQuatConj(const Q: TAnimQuat): TAnimQuat;

{ Scales Q to length 1 (identity when it is all zeros).
  @param(Q The quaternion.)
  @returns(Unit quaternion.) }
function AnimQuatNormalize(const Q: TAnimQuat): TAnimQuat;

{ Axis and angle of a rotation, as X3D / Castle Game Engine store a
  rotation: axis (x, y, z) and angle in radians.
  @param(Q The rotation.)
  @param(AX Axis x.)
  @param(AY Axis y.)
  @param(AZ Axis z.)
  @param(AAngle Angle in radians, 0..Pi.) }
procedure AnimQuatToAxisAngle(const Q: TAnimQuat; out AX, AY, AZ, AAngle: Single);

implementation

uses
  Math, fpjson, jsonparser;

const
  { glTF component type of a 32-bit float. }
  GLTF_FLOAT = 5126;
  { GLB magic "glTF", little-endian. }
  GLB_MAGIC = $46546C67;
  { GLB chunk type "JSON". }
  GLB_JSON = $4E4F534A;
  { GLB chunk type "BIN" + 0. }
  GLB_BIN = $004E4942;
  { Two values closer than this count as the same (movement test). }
  EPS = 1E-5;

{ V limited to ALow..AHigh (Single only: Math's Min / Max / EnsureRange
  overloads are ambiguous for mixed integer / float arguments in FPC). }
function ClampF(V, ALow, AHigh: Single): Single;
begin
  if V < ALow then
    Result := ALow
  else if V > AHigh then
    Result := AHigh
  else
    Result := V;
end;

function AnimQuatIdentity: TAnimQuat;
begin
  Result.X := 0;
  Result.Y := 0;
  Result.Z := 0;
  Result.W := 1;
end;

function AnimQuatMul(const A, B: TAnimQuat): TAnimQuat;
begin
  Result.W := A.W * B.W - A.X * B.X - A.Y * B.Y - A.Z * B.Z;
  Result.X := A.W * B.X + A.X * B.W + A.Y * B.Z - A.Z * B.Y;
  Result.Y := A.W * B.Y - A.X * B.Z + A.Y * B.W + A.Z * B.X;
  Result.Z := A.W * B.Z + A.X * B.Y - A.Y * B.X + A.Z * B.W;
end;

function AnimQuatConj(const Q: TAnimQuat): TAnimQuat;
begin
  Result.X := -Q.X;
  Result.Y := -Q.Y;
  Result.Z := -Q.Z;
  Result.W := Q.W;
end;

function AnimQuatNormalize(const Q: TAnimQuat): TAnimQuat;
var
  L: Single;
begin
  L := Sqrt(Q.X * Q.X + Q.Y * Q.Y + Q.Z * Q.Z + Q.W * Q.W);
  if L < 1E-6 then
    Exit(AnimQuatIdentity);
  Result.X := Q.X / L;
  Result.Y := Q.Y / L;
  Result.Z := Q.Z / L;
  Result.W := Q.W / L;
end;

procedure AnimQuatToAxisAngle(const Q: TAnimQuat; out AX, AY, AZ, AAngle: Single);
var
  N: TAnimQuat;
  S: Single;
begin
  N := AnimQuatNormalize(Q);
  // the same rotation with w >= 0 has an angle of at most Pi
  if N.W < 0 then
  begin
    N.X := -N.X;
    N.Y := -N.Y;
    N.Z := -N.Z;
    N.W := -N.W;
  end;
  AAngle := 2 * ArcCos(ClampF(N.W, -1, 1));
  S := Sqrt(ClampF(1 - N.W * N.W, 0, 1));
  if S < 1E-6 then
  begin
    // no turn: any axis
    AX := 0;
    AY := 1;
    AZ := 0;
    AAngle := 0;
  end
  else
  begin
    AX := N.X / S;
    AY := N.Y / S;
    AZ := N.Z / S;
  end;
end;

{ Angle between two rotations, in radians (0..Pi).
  @param(A First rotation.)
  @param(B Second rotation.)
  @returns(The angle of the turn from A to B.) }
function QuatAngleBetween(const A, B: TAnimQuat): Single;
var
  D: Single;
begin
  D := Abs(A.X * B.X + A.Y * B.Y + A.Z * B.Z + A.W * B.W);
  Result := 2 * ArcCos(ClampF(D, 0, 1));
end;

{ TPadClip }

destructor TPadClip.Destroy;
var
  I: Integer;
begin
  for I := 0 to High(Channels) do
    Channels[I].Free;
  inherited;
end;

{ TPadAnimator }

constructor TPadAnimator.Create;
begin
  inherited Create;
  FJointNames := TStringList.Create;
end;

destructor TPadAnimator.Destroy;
begin
  Clear;
  FJointNames.Free;
  inherited;
end;

procedure TPadAnimator.Clear;
var
  I: Integer;
begin
  for I := 0 to High(FClips) do
    FClips[I].Free;
  FClips := nil;
  FJointNames.Clear;
  FJointNodes := nil;
  FRestT := nil;
  FRestR := nil;
  FLastT := nil;
  FLastR := nil;
  FApplied := nil;
  FFileClipCount := 0;
end;

function TPadAnimator.JointFor(ANode: Integer; const AName: string; const ARestT: TAnimVec3;
  const ARestR: TAnimQuat): Integer;
var
  I, N: Integer;
begin
  for I := 0 to High(FJointNodes) do
    if FJointNodes[I] = ANode then
      Exit(I);
  N := Length(FJointNodes);
  SetLength(FJointNodes, N + 1);
  SetLength(FRestT, N + 1);
  SetLength(FRestR, N + 1);
  SetLength(FLastT, N + 1);
  SetLength(FLastR, N + 1);
  SetLength(FApplied, N + 1);
  FJointNodes[N] := ANode;
  FRestT[N] := ARestT;
  FRestR[N] := ARestR;
  FLastT[N] := ARestT;
  FLastR[N] := ARestR;
  FApplied[N] := False;
  FJointNames.Add(AName);
  Result := N;
end;

function TPadAnimator.GetJointCount: Integer;
begin
  Result := Length(FJointNodes);
end;

function TPadAnimator.GetJointName(I: Integer): string;
begin
  Result := FJointNames[I];
end;

function TPadAnimator.GetClipCount: Integer;
begin
  Result := Length(FClips);
end;

function TPadAnimator.GetClipName(I: Integer): string;
begin
  Result := FClips[I].Name;
end;

{ The array called AName of AObj, or @nil. }
function JsonArray(AObj: TJSONObject; const AName: string): TJSONArray;
var
  D: TJSONData;
begin
  Result := nil;
  if AObj = nil then
    Exit;
  D := AObj.Find(AName);
  if (D <> nil) and (D.JSONType = jtArray) then
    Result := TJSONArray(D);
end;

{ The object at index I of AArr, or @nil. }
function JsonItem(AArr: TJSONArray; I: Integer): TJSONObject;
begin
  Result := nil;
  if (AArr = nil) or (I < 0) or (I >= AArr.Count) then
    Exit;
  if AArr.Items[I].JSONType = jtObject then
    Result := TJSONObject(AArr.Items[I]);
end;

{ The integer member AName of AObj, or ADefault. }
function JsonInt(AObj: TJSONObject; const AName: string; ADefault: Integer): Integer;
var
  D: TJSONData;
begin
  Result := ADefault;
  if AObj = nil then
    Exit;
  D := AObj.Find(AName);
  if (D <> nil) and (D.JSONType = jtNumber) then
    Result := D.AsInteger;
end;

{ The string member AName of AObj, or ''. }
function JsonStr(AObj: TJSONObject; const AName: string): string;
var
  D: TJSONData;
begin
  Result := '';
  if AObj = nil then
    Exit;
  D := AObj.Find(AName);
  if (D <> nil) and (D.JSONType = jtString) then
    Result := D.AsString;
end;

{ Reads the float accessor AIndex of a glTF document into AOut
  (count x components values).
  @param(AJson The document's top object.)
  @param(ABin The binary chunk.)
  @param(AIndex Accessor index.)
  @param(AComponents Expected values per element (1, 3 or 4).)
  @param(AOut The values.)
  @returns('' when read, else why not.) }
function ReadAccessor(AJson: TJSONObject; const ABin: TBytes; AIndex, AComponents: Integer;
  out AOut: TSingleDynArray): string;
var
  Acc, View: TJSONObject;
  Count, Stride, Offset, I, K: Integer;
  TypeName: string;
  N: Integer;
  V: Single;
begin
  AOut := nil;
  Acc := JsonItem(JsonArray(AJson, 'accessors'), AIndex);
  if Acc = nil then
    Exit(Format('accessor %d missing', [AIndex]));
  if JsonInt(Acc, 'componentType', 0) <> GLTF_FLOAT then
    Exit(Format('accessor %d is not float', [AIndex]));
  TypeName := JsonStr(Acc, 'type');
  if TypeName = 'SCALAR' then
    N := 1
  else if TypeName = 'VEC3' then
    N := 3
  else if TypeName = 'VEC4' then
    N := 4
  else
    N := 0;
  if N <> AComponents then
    Exit(Format('accessor %d is %s, expected %d values', [AIndex, TypeName, AComponents]));
  View := JsonItem(JsonArray(AJson, 'bufferViews'), JsonInt(Acc, 'bufferView', -1));
  if View = nil then
    Exit(Format('accessor %d has no buffer view', [AIndex]));
  Count := JsonInt(Acc, 'count', 0);
  Stride := JsonInt(View, 'byteStride', 4 * N);
  Offset := JsonInt(View, 'byteOffset', 0) + JsonInt(Acc, 'byteOffset', 0);
  if (Count < 0) or (Offset < 0)
    or (Int64(Offset) + Int64(Count - 1) * Stride + 4 * N > Length(ABin)) then
    Exit(Format('accessor %d lies outside the binary chunk', [AIndex]));
  SetLength(AOut, Count * N);
  for I := 0 to Count - 1 do
    for K := 0 to N - 1 do
    begin
      Move(ABin[Offset + I * Stride + 4 * K], V, 4);
      AOut[I * N + K] := V;
    end;
  Result := '';
end;

function TPadAnimator.LoadFromFile(const AFileName: string): string;
var
  F: TFileStream;
  Header: array[0..2] of UInt32;
  ChunkLen, ChunkType: UInt32;
  JsonText: RawByteString;
  Bin: TBytes;
  Doc: TJSONData;
  Root, Node, Anim, Chan, Target, Samp: TJSONObject;
  Nodes, Anims, Chans, Samps, Arr: TJSONArray;
  A, C, I, K, NodeIndex, NV, KeyCount, BestKey, ChanCount: Integer;
  Path, Why: string;
  Times, Values: TSingleDynArray;
  RestT: TAnimVec3;
  RestR, Q: TAnimQuat;
  Clip: TPadClip;
  Ch: TPadChannel;
  Moves: Boolean;
  Dev, BestDev, ClipBest: Single;
begin
  Clear;
  Doc := nil;
  try
  try
    F := TFileStream.Create(AFileName, fmOpenRead or fmShareDenyWrite);
    try
      // GLB: header (magic, version, length), then JSON chunk, then BIN chunk
      F.ReadBuffer(Header, SizeOf(Header));
      if Header[0] <> GLB_MAGIC then
        Exit('not a binary glTF (.glb) file');
      F.ReadBuffer(ChunkLen, 4);
      F.ReadBuffer(ChunkType, 4);
      if ChunkType <> GLB_JSON then
        Exit('first chunk is not JSON');
      SetLength(JsonText, ChunkLen);
      if ChunkLen > 0 then
        F.ReadBuffer(JsonText[1], ChunkLen);
      Bin := nil;
      if F.Position + 8 <= F.Size then
      begin
        F.ReadBuffer(ChunkLen, 4);
        F.ReadBuffer(ChunkType, 4);
        if ChunkType = GLB_BIN then
        begin
          SetLength(Bin, ChunkLen);
          if ChunkLen > 0 then
            F.ReadBuffer(Bin[0], ChunkLen);
        end;
      end;
    finally
      F.Free;
    end;
    // the chunk is UTF-8 text: no code-page conversion on the way in
    SetCodePage(JsonText, CP_UTF8, False);
    Doc := GetJSON(UTF8String(JsonText));
    if (Doc = nil) or (Doc.JSONType <> jtObject) then
      Exit('JSON chunk is not an object');
    Root := TJSONObject(Doc);
    Nodes := JsonArray(Root, 'nodes');
    Anims := JsonArray(Root, 'animations');
    if Anims = nil then
      Exit('');   // no clips: nothing to play
    FFileClipCount := Anims.Count;
    for A := 0 to Anims.Count - 1 do
    begin
      Anim := JsonItem(Anims, A);
      Chans := JsonArray(Anim, 'channels');
      Samps := JsonArray(Anim, 'samplers');
      Clip := TPadClip.Create;
      try
      Clip.Name := JsonStr(Anim, 'name');
      ClipBest := -1;
      ChanCount := 0;
      if Chans <> nil then
        ChanCount := Chans.Count;
      for C := 0 to ChanCount - 1 do
      begin
        Chan := JsonItem(Chans, C);
        Target := nil;
        if (Chan <> nil) and (Chan.Find('target') <> nil)
          and (Chan.Find('target').JSONType = jtObject) then
          Target := TJSONObject(Chan.Find('target'));
        Path := JsonStr(Target, 'path');
        NodeIndex := JsonInt(Target, 'node', -1);
        if (Path <> 'translation') and (Path <> 'rotation') then
          Continue;   // scale / weights: not used by our models
        Node := JsonItem(Nodes, NodeIndex);
        Samp := JsonItem(Samps, JsonInt(Chan, 'sampler', -1));
        if (Node = nil) or (Samp = nil) then
          Continue;
        // CUBICSPLINE stores three values per key (in-tangent, value,
        // out-tangent): reading it as plain keys would animate garbage.
        // Blender exports LINEAR / STEP; such a channel is skipped.
        if JsonStr(Samp, 'interpolation') = 'CUBICSPLINE' then
          Continue;
        if Path = 'rotation' then
          NV := 4
        else
          NV := 3;
        Why := ReadAccessor(Root, Bin, JsonInt(Samp, 'input', -1), 1, Times);
        if Why = '' then
          Why := ReadAccessor(Root, Bin, JsonInt(Samp, 'output', -1), NV, Values);
        if Why <> '' then
          Continue;   // unreadable channel: skipped
        KeyCount := Length(Times);
        if (KeyCount = 0) or (Length(Values) < KeyCount * NV) then
          Continue;
        // the node's own pose is the rest pose (glTF defaults otherwise)
        RestT.X := 0; RestT.Y := 0; RestT.Z := 0;
        RestR := AnimQuatIdentity;
        Arr := JsonArray(Node, 'translation');
        if (Arr <> nil) and (Arr.Count = 3) then
        begin
          RestT.X := Arr.Floats[0]; RestT.Y := Arr.Floats[1]; RestT.Z := Arr.Floats[2];
        end;
        Arr := JsonArray(Node, 'rotation');
        if (Arr <> nil) and (Arr.Count = 4) then
        begin
          RestR.X := Arr.Floats[0]; RestR.Y := Arr.Floats[1];
          RestR.Z := Arr.Floats[2]; RestR.W := Arr.Floats[3];
        end;
        // does it move at all? (every clip carries every joint)
        Moves := False;
        for I := 1 to KeyCount - 1 do
          for K := 0 to NV - 1 do
            if Abs(Values[I * NV + K] - Values[K]) > EPS then
              Moves := True;
        if not Moves then
          Continue;
        // its key of largest movement from rest = a candidate peak
        BestKey := 0;
        BestDev := -1;
        for I := 0 to KeyCount - 1 do
        begin
          if NV = 4 then
          begin
            Q.X := Values[I * 4]; Q.Y := Values[I * 4 + 1];
            Q.Z := Values[I * 4 + 2]; Q.W := Values[I * 4 + 3];
            Dev := QuatAngleBetween(AnimQuatNormalize(Q), RestR);
          end
          else
            Dev := Sqrt(Sqr(Values[I * 3] - RestT.X) + Sqr(Values[I * 3 + 1] - RestT.Y)
              + Sqr(Values[I * 3 + 2] - RestT.Z));
          if Dev > BestDev then
          begin
            BestDev := Dev;
            BestKey := I;
          end;
        end;
        Ch := TPadChannel.Create;
        Ch.Joint := JointFor(NodeIndex, JsonStr(Node, 'name'), RestT, RestR);
        Ch.IsRotation := NV = 4;
        Ch.Step := JsonStr(Samp, 'interpolation') = 'STEP';
        Ch.Times := Copy(Times);
        Ch.Values := Copy(Values);
        SetLength(Clip.Channels, Length(Clip.Channels) + 1);
        Clip.Channels[High(Clip.Channels)] := Ch;
        // the clip's peak: the time of its largest single movement
        // (rotation in radians, translation in model units - our clips
        // move one joint each, so the two never compete)
        if BestDev > ClipBest then
        begin
          ClipBest := BestDev;
          Clip.PeakTime := Times[BestKey];
        end;
      end;
      except
        Clip.Free;   // not kept: free it before the error goes on
        raise;
      end;
      if Length(Clip.Channels) = 0 then
        Clip.Free   // moves nothing (EmptyAction, clips for missing joints)
      else
      begin
        SetLength(FClips, Length(FClips) + 1);
        FClips[High(FClips)] := Clip;
      end;
    end;
    Result := '';
  except
    on E: Exception do
      Result := E.ClassName + ': ' + E.Message;
  end;
  finally
    // also on every Exit above
    Doc.Free;
  end;
end;

function TPadAnimator.FindClip(const AName: string): Integer;
var
  I: Integer;
begin
  for I := 0 to High(FClips) do
    if FClips[I].Name = AName then
      Exit(I);
  Result := -1;
end;

function TPadAnimator.Press(const AName: string): Boolean;
var
  I: Integer;
begin
  I := FindClip(AName);
  Result := I >= 0;
  if Result then
    FClips[I].Mode := cmPress;
end;

function TPadAnimator.Release(const AName: string): Boolean;
var
  I: Integer;
begin
  I := FindClip(AName);
  Result := I >= 0;
  if Result and (FClips[I].Mode <> cmOff) then
    FClips[I].Mode := cmRelease;
end;

function TPadAnimator.SetValue(const AName: string; AValue: Single): Boolean;
var
  I: Integer;
begin
  I := FindClip(AName);
  Result := I >= 0;
  if not Result then
    Exit;
  AValue := ClampF(AValue, 0, 1);
  if AValue <= 0 then
  begin
    FClips[I].Mode := cmOff;
    FClips[I].Time := 0;
  end
  else
  begin
    FClips[I].Mode := cmValue;
    FClips[I].Time := AValue * FClips[I].PeakTime;
  end;
end;

procedure TPadAnimator.SetAxis(const ANeg, APos: string; AValue: Single);
begin
  if AValue >= 0 then
  begin
    SetValue(ANeg, 0);
    SetValue(APos, AValue);
  end
  else
  begin
    SetValue(APos, 0);
    SetValue(ANeg, -AValue);
  end;
end;

procedure TPadAnimator.StopAll;
var
  I: Integer;
begin
  for I := 0 to High(FClips) do
  begin
    FClips[I].Mode := cmOff;
    FClips[I].Time := 0;
  end;
end;

{ The channel's value at time T: translation into AT, or rotation into
  AR (whichever the channel holds). }
procedure SampleChannel(Ch: TPadChannel; T: Single; out AT: TAnimVec3; out AR: TAnimQuat);
var
  N, I, K, NV: Integer;
  F, D: Single;
  A, B: array[0..3] of Single;
begin
  N := Length(Ch.Times);
  NV := 3;
  if Ch.IsRotation then
    NV := 4;
  // key segment [I, I + 1] holding T, and the fraction F within it
  if T <= Ch.Times[0] then
  begin
    I := 0;
    F := 0;
  end
  else if T >= Ch.Times[N - 1] then
  begin
    I := N - 1;
    F := 0;
  end
  else
  begin
    I := 0;
    while (I < N - 2) and (Ch.Times[I + 1] <= T) do
      Inc(I);
    D := Ch.Times[I + 1] - Ch.Times[I];
    if (D <= 0) or Ch.Step then
      F := 0
    else
      F := (T - Ch.Times[I]) / D;
  end;
  for K := 0 to NV - 1 do
  begin
    A[K] := Ch.Values[I * NV + K];
    if (F > 0) and (I + 1 < N) then
      B[K] := Ch.Values[(I + 1) * NV + K]
    else
      B[K] := A[K];
  end;
  if Ch.IsRotation then
  begin
    // normalised lerp, along the shorter way
    if A[0] * B[0] + A[1] * B[1] + A[2] * B[2] + A[3] * B[3] < 0 then
      for K := 0 to 3 do
        B[K] := -B[K];
    AR.X := A[0] + (B[0] - A[0]) * F;
    AR.Y := A[1] + (B[1] - A[1]) * F;
    AR.Z := A[2] + (B[2] - A[2]) * F;
    AR.W := A[3] + (B[3] - A[3]) * F;
    AR := AnimQuatNormalize(AR);
    AT.X := 0; AT.Y := 0; AT.Z := 0;
  end
  else
  begin
    AT.X := A[0] + (B[0] - A[0]) * F;
    AT.Y := A[1] + (B[1] - A[1]) * F;
    AT.Z := A[2] + (B[2] - A[2]) * F;
    AR := AnimQuatIdentity;
  end;
end;

procedure TPadAnimator.Update(ASeconds: Single);
var
  I, C, J: Integer;
  Clip: TPadClip;
  T: array of TAnimVec3;
  R: array of TAnimQuat;
  ST: TAnimVec3;
  SR, Base: TAnimQuat;
  Ch: TPadChannel;
begin
  // play heads
  for I := 0 to High(FClips) do
  begin
    Clip := FClips[I];
    case Clip.Mode of
      cmPress:
        Clip.Time := ClampF(Clip.Time + ASeconds, 0, Clip.PeakTime);
      cmRelease:
        begin
          Clip.Time := ClampF(Clip.Time - ASeconds, 0, Clip.PeakTime);
          if Clip.Time <= 0 then
            Clip.Mode := cmOff;
        end;
    end;
  end;
  // every joint starts at rest; each playing clip adds its movement
  SetLength(T, Length(FJointNodes));
  SetLength(R, Length(FJointNodes));
  for J := 0 to High(FJointNodes) do
  begin
    T[J] := FRestT[J];
    R[J] := FRestR[J];
  end;
  for I := 0 to High(FClips) do
  begin
    Clip := FClips[I];
    if (Clip.Mode = cmOff) or (Clip.Time <= 0) then
      Continue;
    for C := 0 to High(Clip.Channels) do
    begin
      Ch := Clip.Channels[C];
      J := Ch.Joint;
      SampleChannel(Ch, Clip.Time, ST, SR);
      // the movement is measured from the clip's FIRST key, not from the
      // node's pose: on the PS5 model Menu_Press / View_Press start ~1.5 mm
      // away from it, which would jump at the start of a press
      if Ch.IsRotation then
      begin
        Base.X := Ch.Values[0]; Base.Y := Ch.Values[1];
        Base.Z := Ch.Values[2]; Base.W := Ch.Values[3];
        // pose * (base^-1 * sample): the clip's turn, added on top
        R[J] := AnimQuatNormalize(AnimQuatMul(R[J],
          AnimQuatMul(AnimQuatConj(AnimQuatNormalize(Base)), SR)));
      end
      else
      begin
        T[J].X := T[J].X + (ST.X - Ch.Values[0]);
        T[J].Y := T[J].Y + (ST.Y - Ch.Values[1]);
        T[J].Z := T[J].Z + (ST.Z - Ch.Values[2]);
      end;
    end;
  end;
  // hand out only what changed
  if not Assigned(FOnApplyJoint) then
    Exit;
  for J := 0 to High(FJointNodes) do
    if not FApplied[J]
      or (Abs(T[J].X - FLastT[J].X) > EPS) or (Abs(T[J].Y - FLastT[J].Y) > EPS)
      or (Abs(T[J].Z - FLastT[J].Z) > EPS)
      // component by component: an angle through ArcCos is never exactly 0
      // in single precision (rest joints would be rewritten every frame)
      or (Abs(R[J].X - FLastR[J].X) > EPS) or (Abs(R[J].Y - FLastR[J].Y) > EPS)
      or (Abs(R[J].Z - FLastR[J].Z) > EPS) or (Abs(R[J].W - FLastR[J].W) > EPS) then
    begin
      FLastT[J] := T[J];
      FLastR[J] := R[J];
      FApplied[J] := True;
      FOnApplyJoint(J, T[J], R[J]);
    end;
end;

end.
