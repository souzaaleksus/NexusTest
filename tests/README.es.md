# Scripts de test de NexusTest

[English](README.md) | [Português (BR)](README.pt-BR.md) | [Español](README.es.md)

Tests de integración y end-to-end para el stack NexusTest (agente Delphi +
servidor MCP + demo). Todos los scripts corren desde esta carpeta y asumen
que el `mcp-server` fue compilado (`cd mcp-server && npm install && npx tsc`).

## Requisitos previos

1. Compilar la app demo del agente (una vez):
   ```
   cd ../agent/demo
   ./build.bat
   ```

2. Compilar el servidor MCP (una vez):
   ```
   cd ../mcp-server
   npm install
   npx tsc
   ```

3. Iniciar `DemoVCL.exe` para que el agente escuche en
   `http://127.0.0.1:8765`:
   ```
   ../agent/demo/Win32/Release/DemoVCL.exe
   ```

4. Ejecutar cualquier script desde aquí con `node`.

## Scripts

### `smoke_all_tools.mjs`
Smoke test end-to-end automatizado. Lanza el servidor MCP vía stdio,
ejercita las 9 tools `delphi_*` con llamadas JSON-RPC y valida cada
respuesta. 25 aserciones discretas. Falla con exit code 1 si alguna aserción
falla.

```
node smoke_all_tools.mjs
```

Exit code 0 significa que todo el stack (Node -> MCP stdio -> HTTP -> Indy
-> RTTI -> eventos VCL) está sano.

### `visual_demo.mjs`
Versión pausada del smoke test. Las mismas llamadas a tools, pero con 1.5s
de delay entre cada acción y output descriptivo, para que un humano pueda
ver la ventana DemoVCL actualizarse en tiempo real. También trae la ventana
de la demo al frente vía la Win32 API.

```
node visual_demo.mjs
```

Úsalo para demostrar el proyecto o para debugar problemas de timing.

### `verify_github.mjs`
Script Playwright headed que abre `github.com/souzaaleksus/NexusTest` y
verifica que los archivos subidos están visibles. Captura screenshots en
`tests/verification_screenshots/`. Útil después de un push para confirmar
visualmente que el estado remoto coincide con el local.

```
node verify_github.mjs
```

Requiere Chromium instalado vía `npx playwright install chromium` en
`mcp-server/`.

### `_create_github_pat.mjs` (gitignored)
Helper Playwright headed que hace login en GitHub y crea un Personal Access
Token. **Nunca commitear este archivo** — toma credenciales como argv que
pueden terminar en el historial de la shell. Se mantiene sólo porque crear
PATs vía UI web es tedioso durante desarrollo activo; revocar tokens
inmediatamente después de usarlos.
