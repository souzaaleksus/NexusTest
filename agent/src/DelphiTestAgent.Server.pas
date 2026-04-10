(*
  DelphiTestAgent.Server - HTTP server (Indy) that routes incoming requests
  to the Rtti and Invoke units.

  Protocol (see docs/protocol.md for details):
    GET  /health
    GET  /tree
    GET  /components
    GET  /dump/<ComponentName>
    GET  /get/<ComponentName>/<Property>
    POST /set        body: component, property, value
    POST /click      body: component
    POST /invoke     body: component, event
    POST /focus      body: component
    POST /sendkey    body: key

  All endpoints require X-Agent-Token header if Token was configured.
*)
unit DelphiTestAgent.Server;

interface

uses
  System.Classes, IdHTTPServer, IdContext, IdCustomHTTPServer,
  DelphiTestAgent;

type
  TAgentServer = class
  private
    FHTTP: TIdHTTPServer;
    FConfig: TAgentConfig;
    procedure HandleCommand(AContext: TIdContext;
      ARequestInfo: TIdHTTPRequestInfo;
      AResponseInfo: TIdHTTPResponseInfo);
    function ReadBody(ARequestInfo: TIdHTTPRequestInfo): string;
    function Authorize(ARequestInfo: TIdHTTPRequestInfo): Boolean;
    procedure Route(const AMethod, APath, ABody: string;
      AResponseInfo: TIdHTTPResponseInfo);
  public
    constructor Create(const AConfig: TAgentConfig);
    destructor Destroy; override;
    procedure Start;
    procedure Stop;
    function Active: Boolean;
  end;

implementation

uses
  System.SysUtils, System.StrUtils, System.JSON,
  IdGlobal,
  DelphiTestAgent.Rtti,
  DelphiTestAgent.Invoke;

{ ---------- helpers ---------- }

function JsonField(const Obj: TJSONObject; const Name: string;
  const Default: string = ''): string;
var
  Val: TJSONValue;
begin
  if Obj = nil then Exit(Default);
  Val := Obj.GetValue(Name);
  if Val = nil then Exit(Default);
  Result := Val.Value;
end;

function SplitPath(const Path: string): TArray<string>;
var
  S: string;
begin
  S := Path;
  if (Length(S) > 0) and (S[1] = '/') then
    Delete(S, 1, 1);
  Result := S.Split(['/']);
end;

{ ---------- TAgentServer ---------- }

constructor TAgentServer.Create(const AConfig: TAgentConfig);
begin
  inherited Create;
  FConfig := AConfig;
  FHTTP := TIdHTTPServer.Create(nil);
  FHTTP.OnCommandGet := HandleCommand;
end;

destructor TAgentServer.Destroy;
begin
  try
    Stop;
  except
  end;
  FHTTP.Free;
  inherited;
end;

procedure TAgentServer.Start;
begin
  if FHTTP.Active then Exit;
  FHTTP.Bindings.Clear;
  with FHTTP.Bindings.Add do
  begin
    IP := FConfig.BindAddress;
    Port := FConfig.Port;
  end;
  FHTTP.Active := True;
end;

procedure TAgentServer.Stop;
begin
  if FHTTP.Active then
    FHTTP.Active := False;
end;

function TAgentServer.Active: Boolean;
begin
  Result := FHTTP.Active;
end;

function TAgentServer.Authorize(ARequestInfo: TIdHTTPRequestInfo): Boolean;
var
  Provided: string;
begin
  if FConfig.Token = '' then Exit(True);
  Provided := ARequestInfo.RawHeaders.Values['X-Agent-Token'];
  Result := Provided = FConfig.Token;
end;

function TAgentServer.ReadBody(ARequestInfo: TIdHTTPRequestInfo): string;
var
  Bytes: TBytes;
begin
  Result := '';
  if not Assigned(ARequestInfo.PostStream) then Exit;
  if ARequestInfo.PostStream.Size = 0 then Exit;
  ARequestInfo.PostStream.Position := 0;
  SetLength(Bytes, ARequestInfo.PostStream.Size);
  ARequestInfo.PostStream.Read(Bytes[0], Length(Bytes));
  Result := TEncoding.UTF8.GetString(Bytes);
end;

procedure TAgentServer.HandleCommand(AContext: TIdContext;
  ARequestInfo: TIdHTTPRequestInfo; AResponseInfo: TIdHTTPResponseInfo);
var
  Body: string;
begin
  AResponseInfo.ContentType := 'application/json; charset=utf-8';
  AResponseInfo.CharSet := 'utf-8';
  AResponseInfo.CustomHeaders.Values['Access-Control-Allow-Origin'] := '*';

  if not Authorize(ARequestInfo) then
  begin
    AResponseInfo.ResponseNo := 401;
    AResponseInfo.ContentText := '{"error":"unauthorized"}';
    Exit;
  end;

  Body := ReadBody(ARequestInfo);

  try
    Route(ARequestInfo.Command, ARequestInfo.Document, Body, AResponseInfo);
  except
    on E: Exception do
    begin
      AResponseInfo.ResponseNo := 500;
      AResponseInfo.ContentText :=
        Format('{"error":"%s","class":"%s"}',
          [StringReplace(E.Message, '"', '\"', [rfReplaceAll]), E.ClassName]);
    end;
  end;
end;

procedure TAgentServer.Route(const AMethod, APath, ABody: string;
  AResponseInfo: TIdHTTPResponseInfo);
var
  Parts: TArray<string>;
  Json: TJSONObject;
  CompName, PropName, Value, EventName: string;
begin
  Parts := SplitPath(APath);

  { GET /health }
  if (AMethod = 'GET') and (APath = '/health') then
  begin
    AResponseInfo.ContentText := '{"status":"ok","agent":"DelphiTestAgent","version":"0.1.0"}';
    Exit;
  end;

  { GET /tree }
  if (AMethod = 'GET') and (APath = '/tree') then
  begin
    AResponseInfo.ContentText := DumpTree(FConfig.MaxDepth);
    Exit;
  end;

  { GET /components }
  if (AMethod = 'GET') and (APath = '/components') then
  begin
    AResponseInfo.ContentText := ListAllComponents;
    Exit;
  end;

  { GET /dump/<ComponentName> }
  if (AMethod = 'GET') and (Length(Parts) = 2) and (Parts[0] = 'dump') then
  begin
    AResponseInfo.ContentText := DumpComponent(Parts[1], FConfig.MaxDepth);
    Exit;
  end;

  { GET /get/<ComponentName>/<Property> }
  if (AMethod = 'GET') and (Length(Parts) = 3) and (Parts[0] = 'get') then
  begin
    AResponseInfo.ContentText := GetProperty(Parts[1], Parts[2]);
    Exit;
  end;

  { POST /set }
  if (AMethod = 'POST') and (APath = '/set') then
  begin
    Json := TJSONObject.ParseJSONValue(ABody) as TJSONObject;
    if Json = nil then
    begin
      AResponseInfo.ContentText := '{"error":"invalid json"}';
      Exit;
    end;
    try
      CompName := JsonField(Json, 'component');
      PropName := JsonField(Json, 'property');
      Value := JsonField(Json, 'value');
      AResponseInfo.ContentText := SetProperty(CompName, PropName, Value);
    finally
      Json.Free;
    end;
    Exit;
  end;

  { POST /click }
  if (AMethod = 'POST') and (APath = '/click') then
  begin
    Json := TJSONObject.ParseJSONValue(ABody) as TJSONObject;
    if Json = nil then
    begin
      AResponseInfo.ContentText := '{"error":"invalid json"}';
      Exit;
    end;
    try
      CompName := JsonField(Json, 'component');
      AResponseInfo.ContentText := InvokeClick(CompName);
    finally
      Json.Free;
    end;
    Exit;
  end;

  { POST /invoke }
  if (AMethod = 'POST') and (APath = '/invoke') then
  begin
    Json := TJSONObject.ParseJSONValue(ABody) as TJSONObject;
    if Json = nil then
    begin
      AResponseInfo.ContentText := '{"error":"invalid json"}';
      Exit;
    end;
    try
      CompName := JsonField(Json, 'component');
      EventName := JsonField(Json, 'event', 'OnClick');
      AResponseInfo.ContentText := InvokeNotifyEvent(CompName, EventName);
    finally
      Json.Free;
    end;
    Exit;
  end;

  { POST /focus }
  if (AMethod = 'POST') and (APath = '/focus') then
  begin
    Json := TJSONObject.ParseJSONValue(ABody) as TJSONObject;
    if Json = nil then
    begin
      AResponseInfo.ContentText := '{"error":"invalid json"}';
      Exit;
    end;
    try
      CompName := JsonField(Json, 'component');
      AResponseInfo.ContentText := DelphiTestAgent.Invoke.SetFocus(CompName);
    finally
      Json.Free;
    end;
    Exit;
  end;

  { POST /sendkey }
  if (AMethod = 'POST') and (APath = '/sendkey') then
  begin
    Json := TJSONObject.ParseJSONValue(ABody) as TJSONObject;
    if Json = nil then
    begin
      AResponseInfo.ContentText := '{"error":"invalid json"}';
      Exit;
    end;
    try
      Value := JsonField(Json, 'key');
      AResponseInfo.ContentText := SendKey(Value);
    finally
      Json.Free;
    end;
    Exit;
  end;

  { Fallback }
  AResponseInfo.ResponseNo := 404;
  AResponseInfo.ContentText := Format('{"error":"not found","path":"%s","method":"%s"}',
    [APath, AMethod]);
end;

end.
