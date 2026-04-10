# NexusTest test scripts

[English](README.md) | [Português (BR)](README.pt-BR.md) | [Español](README.es.md)

Integration and end-to-end tests for the NexusTest stack (Delphi agent +
MCP server + demo). All scripts run from this folder and assume the
`mcp-server` has been built (`cd mcp-server && npm install && npx tsc`).

## Prerequisites

1. Build the agent demo app (once):
   ```
   cd ../agent/demo
   ./build.bat
   ```

2. Build the MCP server (once):
   ```
   cd ../mcp-server
   npm install
   npx tsc
   ```

3. Start `DemoVCL.exe` so the agent is listening on
   `http://127.0.0.1:8765`:
   ```
   ../agent/demo/Win32/Release/DemoVCL.exe
   ```

4. Run any script from here with `node`.

## Scripts

### `smoke_all_tools.mjs`
Automated end-to-end smoke test. Spawns the MCP server via stdio,
exercises all 9 `delphi_*` tools with JSON-RPC calls, and validates
every response. 25 discrete assertions. Fails with exit code 1 if any
assertion fails.

```
node smoke_all_tools.mjs
```

Exit code 0 means the entire stack (Node -> MCP stdio -> HTTP -> Indy ->
RTTI -> VCL events) is healthy.

### `visual_demo.mjs`
Paced version of the smoke test. Same tool calls, but with 1.5s delays
between each action and descriptive output, so a human can watch the
DemoVCL window update in real time. Also brings the demo window to the
foreground via the Win32 API.

```
node visual_demo.mjs
```

Use this when demoing the project or debugging timing issues.

### `verify_github.mjs`
Headed Playwright script that opens `github.com/souzaaleksus/NexusTest`
and verifies the pushed files are visible. Captures screenshots to
`tests/verification_screenshots/`. Useful after a push to confirm the
remote state matches the local state visually.

```
node verify_github.mjs
```

Requires Chromium installed via `npx playwright install chromium` in
`mcp-server/`.

### `_create_github_pat.mjs` (gitignored)
Headed Playwright helper that logs into GitHub and creates a Personal
Access Token. **Never commit this file** — it takes credentials as argv
which can end up in shell history. Kept around only because creating
PATs via web UI is tedious during active development; revoke tokens
immediately after use.
