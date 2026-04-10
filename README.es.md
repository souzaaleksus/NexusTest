# NexusTest

[English](README.md) | [Português (BR)](README.pt-BR.md) | [Español](README.es.md)

Agente HTTP embebido en tiempo de ejecución para aplicaciones Delphi VCL +
servidor MCP genérico que permite a asistentes de IA (Claude Code, Continue,
etc.) inspeccionar y controlar la UI de cualquier aplicación VCL vía RTTI.

## Por qué

La automatización de UI en aplicaciones Delphi VCL es dolorosa con
herramientas genéricas:

- **UIAutomation (UIA2/UIA3)**: TSpeedButton / controles DevExpress / frames
  creados en runtime son invisibles porque se dibujan en canvas y no tienen
  HWND.
- **AutoIt**: basado en coordenadas, frágil ante cambios de layout, sin
  conocimiento semántico.
- **FlaUI / WinAppDriver**: las mismas limitaciones de UIA.

Este proyecto usa un enfoque distinto, tomado del patrón "Delphi Open
Application" usado internamente por TestComplete / Ranorex:

1. Un servidor HTTP se **embebe dentro de la aplicación VCL objetivo**
   (compilación condicional, desactivado en builds de release).
2. El servidor recorre `Application.MainForm` y todos los `Screen.Forms` usando
   `System.Rtti` y `TypInfo` para exponer el árbol completo de componentes como
   JSON.
3. Cualquier propiedad publicada puede leerse / escribirse, y cualquier evento
   `OnClick` / `OnExit` / etc. puede invocarse programáticamente.
4. Un servidor MCP genérico en TypeScript reenvía las llamadas de tools del
   Claude Code al agente HTTP embebido.

El agente ve todo lo que el IDE de Delphi ve, porque usa los mismos metadatos
RTTI. TSpeedButton, TcxGrid, TLbButton, frames personalizados — todos
consultables por su `Name`.

## Componentes

```
NexusTest/
├── agent/          # Delphi Pascal — agente HTTP embebido en la app objetivo
│   ├── src/        # Unidades DelphiTestAgent.*.pas
│   └── demo/       # Aplicación VCL demo mínima con el agente habilitado
├── mcp-server/     # TypeScript — servidor MCP genérico
│   └── src/
├── tests/          # Tests de integración del stack completo
└── docs/
    ├── en/         # Documentación en inglés
    ├── pt-BR/      # Documentación en portugués (Brasil)
    └── es/         # Documentación en español
```

## Inicio rápido (lado del agente)

En el `.dpr` de tu proyecto Delphi:

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

Compila con `-dTESTAGENT` y la aplicación escucha en `http://127.0.0.1:8765`.

```bash
curl http://localhost:8765/health
curl http://localhost:8765/tree
curl http://localhost:8765/get/lb_salvar/Caption
curl -X POST http://localhost:8765/click -d '{"component":"lb_salvar"}'
```

Consulta [docs/es/integration.md](docs/es/integration.md) para una configuración detallada.

## Inicio rápido (lado del servidor MCP)

Agrega a `.mcp.json`:

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

Claude Code tendrá entonces las tools: `delphi_dump`, `delphi_get`, `delphi_set`,
`delphi_click`, `delphi_invoke`, `delphi_focus`, `delphi_sendkey`,
`delphi_components`, `delphi_health`.

Consulta [docs/es/protocol.md](docs/es/protocol.md) para el contrato HTTP completo.

## Seguridad

El agente hace bind a `127.0.0.1` por defecto. Autenticación por token
opcional vía header `X-Agent-Token`. Nunca habilitarlo en builds de producción
— protegerlo con condicional `{$IFDEF TESTAGENT}`.

## Estado

MVP inicial. Funciona sólo para VCL (FMX es una extensión planeada — la mayor
parte del walker RTTI es reutilizable).

## Licencia

MIT. Ver [LICENSE](LICENSE).
