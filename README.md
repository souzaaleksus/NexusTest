# NexusTest

[English](README.md) | [Português (BR)](README.pt-BR.md) | [Español](README.es.md)

Runtime-embedded HTTP agent for Delphi VCL applications + generic MCP server
so that AI assistants (Claude Code, Continue, etc.) can inspect and drive the
UI of any VCL app via RTTI.

## Why

UI automation of Delphi VCL applications is painful with generic tools:

- **UIAutomation (UIA2/UIA3)**: TSpeedButton / DevExpress controls / runtime-created
  frames are invisible because they are canvas-drawn and have no HWND.
- **AutoIt**: coordinate-based, fragile to layout changes, no semantic knowledge.
- **FlaUI / WinAppDriver**: same UIA limitations.

This project uses a different approach, borrowed from the
"Delphi Open Application" pattern used internally by TestComplete / Ranorex:

1. An HTTP server is **embedded inside the target VCL app** (conditional compile,
   disabled in release builds).
2. The server walks `Application.MainForm` and all `Screen.Forms` using `System.Rtti`
   and `TypInfo` to expose the full component tree as JSON.
3. Any published property can be read / written, and any `OnClick` / `OnExit` /
   other published event can be invoked programmatically.
4. A generic MCP server in TypeScript forwards Claude Code tool calls to the
   embedded HTTP agent.

The agent sees everything the Delphi IDE sees because it uses the same RTTI
metadata. TSpeedButton, TcxGrid, TLbButton, custom frames — all queryable by
`Name`.

## Components

```
NexusTest/
├── agent/          # Delphi Pascal — HTTP agent embedded in target app
│   ├── src/        # DelphiTestAgent.*.pas units
│   └── demo/       # Minimal VCL demo app with agent enabled
├── mcp-server/     # TypeScript — generic MCP server
│   └── src/
├── tests/          # Integration tests for the whole stack
└── docs/
    ├── en/         # English documentation
    ├── pt-BR/      # Portuguese (Brazilian)
    └── es/         # Spanish
```

## Quick start (agent side)

In your Delphi project `.dpr`:

```delphi
program MyApp;

uses
  Forms,
  {$IFDEF TESTAGENT}
  DelphiTestAgent,
  {$ENDIF}
  MainForm in 'MainForm.pas' {Form1};

begin
  Application.Initialize;
  Application.CreateForm(TForm1, Form1);
  {$IFDEF TESTAGENT}
  DelphiTestAgent.Start;
  {$ENDIF}
  Application.Run;
end.
```

Build with `-dTESTAGENT` and the app listens on `http://127.0.0.1:8765`.

```bash
curl http://localhost:8765/health
curl http://localhost:8765/tree
curl http://localhost:8765/get/lb_salvar/Caption
curl -X POST http://localhost:8765/click -d '{"component":"lb_salvar"}'
```

See [docs/en/integration.md](docs/en/integration.md) for detailed setup.

## Quick start (MCP server side)

Add to `.mcp.json`:

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

Claude Code then has tools: `delphi_dump`, `delphi_get`, `delphi_set`,
`delphi_click`, `delphi_invoke`, `delphi_focus`, `delphi_sendkey`,
`delphi_components`, `delphi_health`.

See [docs/en/protocol.md](docs/en/protocol.md) for the full HTTP contract.

## Security

The agent binds to `127.0.0.1` by default. Optional token auth via
`X-Agent-Token` header. Never enable in production builds — protect with
`{$IFDEF TESTAGENT}` conditional.

## Status

Early MVP. Works for VCL only (FMX is a planned extension — most of the
RTTI walker is reusable).

## License

MIT. See [LICENSE](LICENSE).
