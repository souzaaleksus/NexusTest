(*
  DelphiTestAgent.Invoke - event invocation and main-thread synchronization.

  All event handlers in VCL must run on the main thread. The HTTP server runs
  on a worker thread, so any action that touches UI state is marshalled via
  TThread.Synchronize.
*)
unit DelphiTestAgent.Invoke;

interface

uses
  System.Classes, System.JSON;

// Invoke OnClick of the named component (if assigned).
// Returns JSON with status=invoked or error.
function InvokeClick(const AComponentName: string): string;

// Invoke an arbitrary published event (TNotifyEvent signature).
// Examples: OnExit, OnEnter, OnChange, OnClick, OnDblClick.
function InvokeNotifyEvent(const AComponentName, AEventName: string): string;

// Focus a component (calls SetFocus if it is a TWinControl).
function SetFocus(const AComponentName: string): string;

// Send a key press to the active control via PostMessage to the focused window.
// Format: single character or virtual key name like VK_RETURN, VK_TAB.
function SendKey(const AKey: string): string;

implementation

uses
  System.SysUtils, System.TypInfo, Winapi.Windows, Winapi.Messages,
  Vcl.Controls, Vcl.Forms,
  DelphiTestAgent.Rtti;

{ ---------- main thread sync ---------- }

procedure RunOnMainThread(AProc: TThreadProcedure);
begin
  if GetCurrentThreadID = MainThreadID then
    AProc()
  else
    TThread.Synchronize(nil, AProc);
end;

{ ---------- event invocation ---------- }

function InvokeNotifyEvent(const AComponentName, AEventName: string): string;
var
  C: TComponent;
  Method: TMethod;
  Notify: TNotifyEvent;
  InvokeError: string;
  InvokeStatus: string;
  Obj: TJSONObject;
begin
  C := FindComponentByName(AComponentName);
  if C = nil then
    Exit(Format('{"error":"component not found: %s"}', [AComponentName]));

  InvokeError := '';
  InvokeStatus := '';

  RunOnMainThread(
    procedure
    begin
      try
        Method := GetMethodProp(C, AEventName);
        if (Method.Code = nil) then
        begin
          InvokeError := Format('event %s not assigned on %s', [AEventName, AComponentName]);
          Exit;
        end;
        TMethod(Notify) := Method;
        Notify(C);
        InvokeStatus := 'invoked';
      except
        on E: Exception do
          InvokeError := E.ClassName + ': ' + E.Message;
      end;
    end
  );

  Obj := TJSONObject.Create;
  try
    Obj.AddPair('component', AComponentName);
    Obj.AddPair('event', AEventName);
    if InvokeError <> '' then
      Obj.AddPair('error', InvokeError)
    else
      Obj.AddPair('status', InvokeStatus);
    Result := Obj.ToJSON;
  finally
    Obj.Free;
  end;
end;

function InvokeClick(const AComponentName: string): string;
begin
  Result := InvokeNotifyEvent(AComponentName, 'OnClick');
end;

{ ---------- focus ---------- }

function SetFocus(const AComponentName: string): string;
var
  C: TComponent;
  FocusError: string;
begin
  C := FindComponentByName(AComponentName);
  if C = nil then
    Exit(Format('{"error":"component not found: %s"}', [AComponentName]));

  FocusError := '';
  RunOnMainThread(
    procedure
    begin
      try
        if C is TWinControl then
          TWinControl(C).SetFocus
        else
          FocusError := C.ClassName + ' is not a TWinControl';
      except
        on E: Exception do
          FocusError := E.Message;
      end;
    end
  );

  if FocusError <> '' then
    Result := Format('{"component":"%s","error":"%s"}', [AComponentName, FocusError])
  else
    Result := Format('{"component":"%s","status":"focused"}', [AComponentName]);
end;

{ ---------- key sending ---------- }

function ParseVirtualKey(const S: string): Word;
begin
  if SameText(S, 'VK_RETURN') then Result := VK_RETURN
  else if SameText(S, 'VK_TAB') then Result := VK_TAB
  else if SameText(S, 'VK_ESCAPE') then Result := VK_ESCAPE
  else if SameText(S, 'VK_SPACE') then Result := VK_SPACE
  else if SameText(S, 'VK_BACK') then Result := VK_BACK
  else if SameText(S, 'VK_DELETE') then Result := VK_DELETE
  else if SameText(S, 'VK_F1') then Result := VK_F1
  else if SameText(S, 'VK_F2') then Result := VK_F2
  else if SameText(S, 'VK_F3') then Result := VK_F3
  else if SameText(S, 'VK_F4') then Result := VK_F4
  else if SameText(S, 'VK_F5') then Result := VK_F5
  else if SameText(S, 'VK_F6') then Result := VK_F6
  else if SameText(S, 'VK_DOWN') then Result := VK_DOWN
  else if SameText(S, 'VK_UP') then Result := VK_UP
  else if SameText(S, 'VK_LEFT') then Result := VK_LEFT
  else if SameText(S, 'VK_RIGHT') then Result := VK_RIGHT
  else Result := 0;
end;

function SendKey(const AKey: string): string;
var
  VK: Word;
  CharCode: Word;
  IsChar: Boolean;
  SendError: string;
begin
  // Single printable character: use WM_CHAR so the edit control receives it
  // exactly once. Posting WM_KEYDOWN/WM_KEYUP for a plain letter causes the
  // edit to process it twice on some Delphi VCL versions (once via
  // TranslateMessage synthesizing WM_CHAR, once via the explicit KEYDOWN).
  IsChar := (Length(AKey) = 1) and
            (not SameText(Copy(AKey, 1, 3), 'VK_'));
  CharCode := 0;
  VK := 0;

  if IsChar then
    CharCode := Ord(AKey[1])
  else
  begin
    VK := ParseVirtualKey(AKey);
    if VK = 0 then
      Exit(Format('{"error":"unknown key: %s"}', [AKey]));
  end;

  SendError := '';
  RunOnMainThread(
    procedure
    var
      HFocus: HWND;
    begin
      try
        HFocus := Winapi.Windows.GetFocus;
        if HFocus = 0 then HFocus := Application.Handle;
        if IsChar then
          PostMessage(HFocus, WM_CHAR, CharCode, 0)
        else
        begin
          PostMessage(HFocus, WM_KEYDOWN, VK, 0);
          PostMessage(HFocus, WM_KEYUP, VK, 0);
        end;
      except
        on E: Exception do
          SendError := E.Message;
      end;
    end
  );

  if SendError <> '' then
    Result := Format('{"key":"%s","error":"%s"}', [AKey, SendError])
  else
    Result := Format('{"key":"%s","status":"sent"}', [AKey]);
end;

end.
