(*
  DelphiTestAgent - public API unit.

  Embeds an HTTP server inside a VCL application that exposes the entire
  component tree via RTTI. Allows an external test runner (MCP server + AI
  assistant) to inspect properties and invoke events without touching the
  screen or simulating keystrokes.

  See docs/integration.md for usage and conditional-compile setup.
  The agent listens on 127.0.0.1:8765 by default.
*)
unit DelphiTestAgent;

interface

type
  TAgentConfig = record
    Port: Integer;
    BindAddress: string;
    Token: string;   // optional; empty disables auth
    MaxDepth: Integer; // max component tree depth when dumping
  end;

{ Configure must be called before Start. If not called, defaults apply:
    Port=8765, BindAddress='127.0.0.1', Token='', MaxDepth=20 }
procedure Configure(const AConfig: TAgentConfig);

{ Start the HTTP server on the main thread. Idempotent. }
procedure Start;

{ Stop the HTTP server. Idempotent. }
procedure Stop;

{ True if the server is currently listening. }
function IsRunning: Boolean;

{ Default config factory. }
function DefaultConfig: TAgentConfig;

implementation

uses
  System.SysUtils,
  DelphiTestAgent.Server;

var
  GConfig: TAgentConfig;
  GServer: TAgentServer;

function DefaultConfig: TAgentConfig;
begin
  Result.Port := 8765;
  Result.BindAddress := '127.0.0.1';
  Result.Token := '';
  Result.MaxDepth := 20;
end;

procedure Configure(const AConfig: TAgentConfig);
begin
  GConfig := AConfig;
  if GConfig.Port <= 0 then GConfig.Port := 8765;
  if GConfig.BindAddress = '' then GConfig.BindAddress := '127.0.0.1';
  if GConfig.MaxDepth <= 0 then GConfig.MaxDepth := 20;
end;

procedure Start;
begin
  if not Assigned(GServer) then
    GServer := TAgentServer.Create(GConfig);
  if not GServer.Active then
    GServer.Start;
end;

procedure Stop;
begin
  if Assigned(GServer) and GServer.Active then
    GServer.Stop;
end;

function IsRunning: Boolean;
begin
  Result := Assigned(GServer) and GServer.Active;
end;

initialization
  GConfig := DefaultConfig;

finalization
  if Assigned(GServer) then
  begin
    try
      GServer.Stop;
    except
    end;
    FreeAndNil(GServer);
  end;

end.
