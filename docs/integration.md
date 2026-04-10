# Integrating DelphiTestAgent into an existing VCL project

## 1. Add source files to your project

Copy or reference the four source files from `agent/src/`:

- `DelphiTestAgent.pas`
- `DelphiTestAgent.Server.pas`
- `DelphiTestAgent.Rtti.pas`
- `DelphiTestAgent.Invoke.pas`

Either add them directly to your .dproj/.dpr, or add `NexusTest\agent\src` to
the project search path.

## 2. Add a conditional define

Create a build mode (Debug with agent) that defines `TESTAGENT`:

```
Project > Options > Building > Delphi Compiler > Conditional defines
Add: TESTAGENT
```

Or from a response file (`.rsp`):
```
-dTESTAGENT
```

Or from the command line:
```
dcc32 -dTESTAGENT MyApp.dpr
```

## 3. Edit your .dpr

```pascal
program MyApp;

uses
  Vcl.Forms,
  {.IFDEF TESTAGENT}
  DelphiTestAgent,
  {.ENDIF}
  MainForm in 'MainForm.pas' {Form1};

begin
  Application.Initialize;
  Application.CreateForm(TForm1, Form1);
  {.IFDEF TESTAGENT}
  DelphiTestAgent.Start;
  {.ENDIF}
  Application.Run;
end.
```

(Replace `{.IFDEF}` with actual `{$IFDEF}` — the dot is only here to keep this
documentation compilable.)

## 4. (Optional) Custom configuration

```pascal
var
  Cfg: TAgentConfig;
begin
  Cfg := DelphiTestAgent.DefaultConfig;
  Cfg.Port := 9000;
  Cfg.Token := 'dev-only';
  Cfg.MaxDepth := 10;
  DelphiTestAgent.Configure(Cfg);
  DelphiTestAgent.Start;
end;
```

## 5. Build and verify

```
dcc32 -dTESTAGENT MyApp.dpr
MyApp.exe
curl http://localhost:8765/health
curl http://localhost:8765/components
```

## 6. Wire up Claude Code via MCP

Add to your project's `.mcp.json` or `~/.claude/mcp.json`:

```json
{
  "mcpServers": {
    "delphi": {
      "command": "node",
      "args": ["F:\\Workspace\\NexusTest\\mcp-server\\dist\\index.js"],
      "env": {
        "DELPHI_AGENT_URL": "http://localhost:8765"
      }
    }
  }
}
```

Claude Code will now have tools: `delphi_health`, `delphi_components`,
`delphi_dump`, `delphi_get`, `delphi_set`, `delphi_click`, `delphi_invoke`,
`delphi_focus`, `delphi_sendkey`.

## Production safety

Never ship a production build with `TESTAGENT` defined. The agent opens a
local HTTP port and exposes the entire component tree including any field
containing sensitive data (passwords, tokens, etc.).

The conditional define gives you a hard compile-time toggle: without
`-dTESTAGENT`, zero agent code is in the binary.
