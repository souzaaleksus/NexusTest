# Scripts de teste do NexusTest

[English](README.md) | [Português (BR)](README.pt-BR.md) | [Español](README.es.md)

Testes de integração e end-to-end para o stack NexusTest (agente Delphi +
servidor MCP + demo). Todos os scripts rodam desta pasta e assumem que o
`mcp-server` foi compilado (`cd mcp-server && npm install && npx tsc`).

## Pré-requisitos

1. Compilar o app demo do agente (uma vez):
   ```
   cd ../agent/demo
   ./build.bat
   ```

2. Compilar o servidor MCP (uma vez):
   ```
   cd ../mcp-server
   npm install
   npx tsc
   ```

3. Iniciar o `DemoVCL.exe` para que o agente escute em
   `http://127.0.0.1:8765`:
   ```
   ../agent/demo/Win32/Release/DemoVCL.exe
   ```

4. Rodar qualquer script daqui com `node`.

## Scripts

### `smoke_all_tools.mjs`
Smoke test end-to-end automatizado. Inicia o servidor MCP via stdio,
exercita todas as 9 tools `delphi_*` com chamadas JSON-RPC e valida cada
resposta. 25 asserções discretas. Falha com exit code 1 se alguma falhar.

```
node smoke_all_tools.mjs
```

Exit code 0 significa que toda a pilha (Node -> MCP stdio -> HTTP -> Indy ->
RTTI -> eventos VCL) está saudável.

### `visual_demo.mjs`
Versão paced do smoke test. Mesmas chamadas de tools, mas com 1.5s de delay
entre cada ação e output descritivo, para que um humano possa observar a
janela DemoVCL sendo atualizada em tempo real. Traz a janela pro primeiro
plano via Win32 API.

```
node visual_demo.mjs
```

Use para demonstrar o projeto ou debugar problemas de timing.

### `verify_github.mjs`
Script Playwright headed que abre `github.com/souzaaleksus/NexusTest` e
verifica se os arquivos pushados estão visíveis. Captura screenshots em
`tests/verification_screenshots/`. Útil após um push para confirmar
visualmente que o estado remoto bate com o local.

```
node verify_github.mjs
```

Requer Chromium instalado via `npx playwright install chromium` no
`mcp-server/`.

### `_create_github_pat.mjs` (gitignored)
Helper Playwright headed que faz login no GitHub e cria um Personal Access
Token. **Nunca commitar este arquivo** — recebe credenciais como argv que
podem aparecer no histórico do shell. Mantido apenas porque criar PATs pela
UI web é tedioso durante desenvolvimento ativo; revogue tokens imediatamente
após o uso.
