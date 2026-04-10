# NexusTest

[English](README.md) | [Português (BR)](README.pt-BR.md) | [Español](README.es.md)

Agente HTTP embutido em runtime para aplicações Delphi VCL + servidor MCP
genérico que permite assistentes de IA (Claude Code, Continue, etc.)
inspecionar e controlar a UI de qualquer app VCL via RTTI.

## Por quê

Automação de UI em aplicações Delphi VCL é dolorosa com ferramentas genéricas:

- **UIAutomation (UIA2/UIA3)**: TSpeedButton / controles DevExpress / frames
  criados em runtime ficam invisíveis porque são desenhados em canvas e não
  têm HWND.
- **AutoIt**: baseado em coordenadas, frágil a mudanças de layout, sem
  conhecimento semântico.
- **FlaUI / WinAppDriver**: mesmas limitações do UIA.

Este projeto usa uma abordagem diferente, emprestada do padrão
"Delphi Open Application" usado internamente pelo TestComplete / Ranorex:

1. Um servidor HTTP é **embutido dentro do app VCL alvo** (compilação
   condicional, desabilitado em builds de release).
2. O servidor percorre `Application.MainForm` e todas as `Screen.Forms` usando
   `System.Rtti` e `TypInfo` para expor a árvore completa de componentes como JSON.
3. Qualquer propriedade publicada pode ser lida / escrita, e qualquer evento
   `OnClick` / `OnExit` / etc. pode ser invocado programaticamente.
4. Um servidor MCP genérico em TypeScript encaminha as chamadas de tools do
   Claude Code para o agente HTTP embutido.

O agente enxerga tudo que o Delphi IDE enxerga porque usa os mesmos metadados
RTTI. TSpeedButton, TcxGrid, TLbButton, frames customizados — todos
consultáveis pelo `Name`.

## Componentes

```
NexusTest/
├── agent/          # Delphi Pascal — agente HTTP embutido no app alvo
│   ├── src/        # Units DelphiTestAgent.*.pas
│   └── demo/       # App VCL demo mínimo com o agente habilitado
├── mcp-server/     # TypeScript — servidor MCP genérico
│   └── src/
├── tests/          # Testes de integração de toda a pilha
└── docs/
    ├── en/         # Documentação em inglês
    ├── pt-BR/      # Documentação em português (Brasil)
    └── es/         # Documentação em espanhol
```

## Início rápido (lado do agente)

No `.dpr` do seu projeto Delphi:

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

Compile com `-dTESTAGENT` e o app escuta em `http://127.0.0.1:8765`.

```bash
curl http://localhost:8765/health
curl http://localhost:8765/tree
curl http://localhost:8765/get/lb_salvar/Caption
curl -X POST http://localhost:8765/click -d '{"component":"lb_salvar"}'
```

Veja [docs/pt-BR/integration.md](docs/pt-BR/integration.md) para setup detalhado.

## Início rápido (lado do servidor MCP)

Adicione ao `.mcp.json`:

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

O Claude Code passa a ter as tools: `delphi_dump`, `delphi_get`, `delphi_set`,
`delphi_click`, `delphi_invoke`, `delphi_focus`, `delphi_sendkey`,
`delphi_components`, `delphi_health`.

Veja [docs/pt-BR/protocol.md](docs/pt-BR/protocol.md) para o contrato HTTP completo.

## Segurança

O agente faz bind em `127.0.0.1` por padrão. Autenticação por token opcional
via header `X-Agent-Token`. Nunca habilitar em builds de produção — proteger
com condicional `{$IFDEF TESTAGENT}`.

## Status

MVP inicial. Funciona apenas para VCL (FMX é extensão planejada — a maior
parte do walker RTTI é reaproveitável).

## Licença

MIT. Veja [LICENSE](LICENSE).
