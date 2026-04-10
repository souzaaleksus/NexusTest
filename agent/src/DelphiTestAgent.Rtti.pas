(*
  DelphiTestAgent.Rtti - component tree walker and property reflection.

  Uses classic TypInfo/RTTI (not the new System.Rtti TValue API) because it
  works reliably on older Delphi versions and handles enum/set/string
  properties without boxing/unboxing overhead.
*)
unit DelphiTestAgent.Rtti;

interface

uses
  System.Classes, System.JSON;

// Serialize the full component tree starting at Application.MainForm to JSON.
// MaxDepth limits recursion. Returns ToJSON string of the root object.
function DumpTree(MaxDepth: Integer = 20): string;

// Dump a single component (and its children) by Name.
function DumpComponent(const AName: string; MaxDepth: Integer = 20): string;

// Find a component by Name anywhere in Screen.Forms or Application.
// Case-insensitive. Returns nil if not found.
function FindComponentByName(const AName: string): TComponent;

// Read a published property. Returns JSON with component, property, value
// on success or error field on failure.
function GetProperty(const AComponentName, APropertyName: string): string;

// Set a published property via string-based TypInfo.SetPropValue.
// Supports strings, integers, enums, booleans, sets.
function SetProperty(const AComponentName, APropertyName, AValue: string): string;

// Return a flat list of all component names visible.
function ListAllComponents: string;

implementation

uses
  System.SysUtils, System.Variants, System.TypInfo,
  Vcl.Controls, Vcl.Forms;

{ ---------- helpers ---------- }

function JsonEscape(const S: string): string;
var
  I: Integer;
  Sb: TStringBuilder;
  C: Char;
begin
  Sb := TStringBuilder.Create;
  try
    for I := 1 to Length(S) do
    begin
      C := S[I];
      case C of
        '"': Sb.Append('\"');
        '\': Sb.Append('\\');
        #8: Sb.Append('\b');
        #9: Sb.Append('\t');
        #10: Sb.Append('\n');
        #12: Sb.Append('\f');
        #13: Sb.Append('\r');
      else
        if Ord(C) < 32 then
          Sb.Append('\u').Append(IntToHex(Ord(C), 4))
        else
          Sb.Append(C);
      end;
    end;
    Result := Sb.ToString;
  finally
    Sb.Free;
  end;
end;

function SafeGetPropValue(C: TComponent; const PropName: string): string;
begin
  try
    Result := VarToStr(GetPropValue(C, PropName, True));
  except
    on E: Exception do
      Result := '<' + E.Message + '>';
  end;
end;

{ ---------- component finder ---------- }

function FindRecursive(Parent: TComponent; const N: string): TComponent;
var
  I: Integer;
begin
  Result := nil;
  if Parent = nil then Exit;
  if SameText(Parent.Name, N) then Exit(Parent);
  for I := 0 to Parent.ComponentCount - 1 do
  begin
    Result := FindRecursive(Parent.Components[I], N);
    if Assigned(Result) then Exit;
  end;
end;

function FindComponentByName(const AName: string): TComponent;
var
  I: Integer;
begin
  Result := nil;
  if AName = '' then Exit;

  { Scan all live forms (MainForm + modal dialogs + secondary forms) }
  for I := 0 to Screen.FormCount - 1 do
  begin
    Result := FindRecursive(Screen.Forms[I], AName);
    if Assigned(Result) then Exit;
  end;

  { Also check Application and DataModules }
  for I := 0 to Screen.DataModuleCount - 1 do
  begin
    Result := FindRecursive(Screen.DataModules[I], AName);
    if Assigned(Result) then Exit;
  end;

  Result := FindRecursive(Application, AName);
end;

{ ---------- serialization ---------- }

function SerializeComponent(C: TComponent; Depth, MaxDepth: Integer): TJSONObject;
var
  I, J, PropCount: Integer;
  Children: TJSONArray;
  Props: TJSONObject;
  PropList: PPropList;
  PropInfo: PPropInfo;
  PropName, PropValue: string;
  Ctrl: TControl;
  Rect: TJSONObject;
begin
  Result := TJSONObject.Create;
  Result.AddPair('name', C.Name);
  Result.AddPair('class', C.ClassName);

  { Bounds if it's a visual control }
  if C is TControl then
  begin
    Ctrl := TControl(C);
    Rect := TJSONObject.Create;
    Rect.AddPair('left', TJSONNumber.Create(Ctrl.Left));
    Rect.AddPair('top', TJSONNumber.Create(Ctrl.Top));
    Rect.AddPair('width', TJSONNumber.Create(Ctrl.Width));
    Rect.AddPair('height', TJSONNumber.Create(Ctrl.Height));
    Rect.AddPair('visible', TJSONBool.Create(Ctrl.Visible));
    Result.AddPair('bounds', Rect);
  end;

  { Published properties via TypInfo }
  Props := TJSONObject.Create;
  PropCount := GetPropList(C.ClassInfo, tkProperties, nil);
  if PropCount > 0 then
  begin
    GetMem(PropList, SizeOf(PPropInfo) * PropCount);
    try
      GetPropList(C.ClassInfo, tkProperties, PropList);
      for J := 0 to PropCount - 1 do
      begin
        PropInfo := PropList^[J];
        PropName := string(PropInfo^.Name);
        { Skip method pointers — they're events, handled separately }
        if PropInfo^.PropType^.Kind = tkMethod then Continue;
        PropValue := SafeGetPropValue(C, PropName);
        Props.AddPair(PropName, PropValue);
      end;
    finally
      FreeMem(PropList);
    end;
  end;
  Result.AddPair('props', Props);

  { Recurse into child components }
  Children := TJSONArray.Create;
  if Depth < MaxDepth then
  begin
    for I := 0 to C.ComponentCount - 1 do
      Children.AddElement(SerializeComponent(C.Components[I], Depth + 1, MaxDepth));
  end;
  Result.AddPair('children', Children);
end;

function DumpTree(MaxDepth: Integer): string;
var
  Root: TJSONObject;
  Forms: TJSONArray;
  I: Integer;
begin
  Root := TJSONObject.Create;
  try
    Root.AddPair('application', Application.Title);
    if Application.MainForm <> nil then
      Root.AddPair('mainForm', Application.MainForm.Name)
    else
      Root.AddPair('mainForm', '');

    Forms := TJSONArray.Create;
    for I := 0 to Screen.FormCount - 1 do
      Forms.AddElement(SerializeComponent(Screen.Forms[I], 0, MaxDepth));
    Root.AddPair('forms', Forms);

    Result := Root.ToJSON;
  finally
    Root.Free;
  end;
end;

function DumpComponent(const AName: string; MaxDepth: Integer): string;
var
  C: TComponent;
  Obj: TJSONObject;
begin
  C := FindComponentByName(AName);
  if C = nil then
    Exit(Format('{"error":"component not found: %s"}', [AName]));

  Obj := SerializeComponent(C, 0, MaxDepth);
  try
    Result := Obj.ToJSON;
  finally
    Obj.Free;
  end;
end;

function GetProperty(const AComponentName, APropertyName: string): string;
var
  C: TComponent;
  Value: string;
  Obj: TJSONObject;
begin
  C := FindComponentByName(AComponentName);
  if C = nil then
    Exit(Format('{"error":"component not found: %s"}', [AComponentName]));

  Obj := TJSONObject.Create;
  try
    Obj.AddPair('component', AComponentName);
    Obj.AddPair('property', APropertyName);
    try
      Value := VarToStr(GetPropValue(C, APropertyName, True));
      Obj.AddPair('value', Value);
    except
      on E: Exception do
      begin
        Obj.AddPair('error', E.Message);
        Result := Obj.ToJSON;
        Exit;
      end;
    end;
    Result := Obj.ToJSON;
  finally
    Obj.Free;
  end;
end;

function SetProperty(const AComponentName, APropertyName, AValue: string): string;
var
  C: TComponent;
  Obj: TJSONObject;
begin
  C := FindComponentByName(AComponentName);
  if C = nil then
    Exit(Format('{"error":"component not found: %s"}', [AComponentName]));

  Obj := TJSONObject.Create;
  try
    Obj.AddPair('component', AComponentName);
    Obj.AddPair('property', APropertyName);
    Obj.AddPair('value', AValue);
    try
      SetPropValue(C, APropertyName, AValue);
      Obj.AddPair('status', 'ok');
    except
      on E: Exception do
        Obj.AddPair('error', E.Message);
    end;
    Result := Obj.ToJSON;
  finally
    Obj.Free;
  end;
end;

function ListAllComponents: string;
var
  Arr: TJSONArray;
  Result_: TJSONObject;
  I: Integer;

  procedure Walk(Parent: TComponent);
  var
    K: Integer;
  begin
    if Parent = nil then Exit;
    if Parent.Name <> '' then
      Arr.Add(Parent.Name + ':' + Parent.ClassName);
    for K := 0 to Parent.ComponentCount - 1 do
      Walk(Parent.Components[K]);
  end;

begin
  Result_ := TJSONObject.Create;
  Arr := TJSONArray.Create;
  try
    for I := 0 to Screen.FormCount - 1 do
      Walk(Screen.Forms[I]);
    Result_.AddPair('components', Arr);
    Result := Result_.ToJSON;
  finally
    Result_.Free;
  end;
end;

end.
