# Integrando DelphiTestAgent en un proyecto VCL existente

[English](../en/integration.md) | [Português (BR)](../pt-BR/integration.md) | [Español](integration.md)

## 1. Agregar los archivos fuente a tu proyecto

Copia o referencia los cuatro archivos de `agent/src/`:

- `DelphiTestAgent.pas`
- `DelphiTestAgent.Server.pas`
- `DelphiTestAgent.Rtti.pas`
- `DelphiTestAgent.Invoke.pas`

Agrégalos directamente a tu .dproj/.dpr, o suma
`NexusTest\agent\src` al search path del proyecto.

## 2. Agregar una directiva condicional

Crea un build mode (Debug con agente) que defina `TESTAGENT`:

```
Project > Options > Building > Delphi Compiler > Conditional defines
Add: TESTAGENT
```

O mediante un response file (`.rsp`):
```
-dTESTAGENT
```

O desde la línea de comandos:
```
dcc32 -dTESTAGENT MyApp.dpr
```

## 3. Editar tu .dpr

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

(Reemplaza `{.IFDEF}` por el `{$IFDEF}` real — el punto está aquí sólo para
mantener este markdown compilable.)

## 4. (Opcional) Configuración personalizada

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

## 5. Compilar y verificar

```
dcc32 -dTESTAGENT MyApp.dpr
MyApp.exe
curl http://localhost:8765/health
curl http://localhost:8765/components
```

## 6. Conectar Claude Code vía MCP

Agrega al `.mcp.json` de tu proyecto o a `~/.claude/mcp.json`:

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

Claude Code tendrá las tools: `delphi_health`, `delphi_components`,
`delphi_dump`, `delphi_get`, `delphi_set`, `delphi_click`, `delphi_invoke`,
`delphi_focus`, `delphi_sendkey`.

## Seguridad en producción

Nunca publiques un build de producción con `TESTAGENT` definido. El agente
abre un puerto HTTP local y expone todo el árbol de componentes — incluyendo
campos con datos sensibles (contraseñas, tokens, etc.).

La directiva condicional te da un toggle hard en tiempo de compilación: sin
`-dTESTAGENT`, cero código del agente entra en el binario.
