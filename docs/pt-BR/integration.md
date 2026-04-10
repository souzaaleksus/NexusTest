# Integrando o DelphiTestAgent em um projeto VCL existente

[English](../en/integration.md) | [Português (BR)](integration.md) | [Español](../es/integration.md)

## 1. Adicionar os arquivos fonte ao seu projeto

Copie ou referencie os quatro arquivos de `agent/src/`:

- `DelphiTestAgent.pas`
- `DelphiTestAgent.Server.pas`
- `DelphiTestAgent.Rtti.pas`
- `DelphiTestAgent.Invoke.pas`

Adicione-os diretamente ao seu .dproj/.dpr, ou adicione
`NexusTest\agent\src` ao search path do projeto.

## 2. Adicionar uma diretiva condicional

Crie um build mode (Debug com agente) que define `TESTAGENT`:

```
Project > Options > Building > Delphi Compiler > Conditional defines
Add: TESTAGENT
```

Ou via um response file (`.rsp`):
```
-dTESTAGENT
```

Ou pela linha de comando:
```
dcc32 -dTESTAGENT MyApp.dpr
```

## 3. Editar seu .dpr

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

(Substitua `{.IFDEF}` pelo `{$IFDEF}` real — o ponto está aqui só pra manter
este markdown compilável.)

## 4. (Opcional) Configuração customizada

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

## 5. Compilar e verificar

```
dcc32 -dTESTAGENT MyApp.dpr
MyApp.exe
curl http://localhost:8765/health
curl http://localhost:8765/components
```

## 6. Ligar o Claude Code via MCP

Adicione ao `.mcp.json` do seu projeto ou `~/.claude/mcp.json`:

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

O Claude Code passa a ter as tools: `delphi_health`, `delphi_components`,
`delphi_dump`, `delphi_get`, `delphi_set`, `delphi_click`, `delphi_invoke`,
`delphi_focus`, `delphi_sendkey`.

## Segurança em produção

Nunca envie um build de produção com `TESTAGENT` definido. O agente abre uma
porta HTTP local e expõe toda a árvore de componentes — incluindo campos com
dados sensíveis (senhas, tokens, etc.).

A diretiva condicional te dá um toggle hard em compile-time: sem
`-dTESTAGENT`, zero código do agente entra no binário.
