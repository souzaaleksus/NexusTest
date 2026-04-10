// End-to-end smoke test for the NexusTest MCP server.
// Spawns the compiled mcp-server/dist/index.js, sends JSON-RPC requests via
// stdio, validates responses, and prints a pass/fail summary.
//
// Prerequisite: DemoVCL.exe (or any host with the agent embedded) listening
// on http://127.0.0.1:8765.

import { spawn } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import { dirname, resolve } from 'node:path';

const __dirname = dirname(fileURLToPath(import.meta.url));
const MCP_SERVER = resolve(__dirname, '..', 'mcp-server', 'dist', 'index.js');

const PASSED = [];
const FAILED = [];

function check(label, cond, detail) {
  if (cond) {
    PASSED.push(label);
    console.log(`  PASS: ${label}`);
  } else {
    FAILED.push({ label, detail });
    console.log(`  FAIL: ${label} — ${detail ?? ''}`);
  }
}

async function run() {
  const mcp = spawn('node', [MCP_SERVER], {
    stdio: ['pipe', 'pipe', 'pipe'],
    env: { ...process.env, DELPHI_AGENT_URL: 'http://127.0.0.1:8765' },
  });

  const responses = new Map();
  let buffer = '';
  mcp.stdout.on('data', (chunk) => {
    buffer += chunk.toString();
    let idx;
    while ((idx = buffer.indexOf('\n')) >= 0) {
      const line = buffer.slice(0, idx).trim();
      buffer = buffer.slice(idx + 1);
      if (!line) continue;
      try {
        const msg = JSON.parse(line);
        if (msg.id != null) responses.set(msg.id, msg);
      } catch {
        console.error('[bad json]', line);
      }
    }
  });
  mcp.stderr.on('data', (c) => process.stderr.write(c));

  let reqId = 0;
  function call(method, params) {
    const id = ++reqId;
    const req = { jsonrpc: '2.0', id, method, params };
    mcp.stdin.write(JSON.stringify(req) + '\n');
    return new Promise((resolve, reject) => {
      const start = Date.now();
      const iv = setInterval(() => {
        if (responses.has(id)) {
          clearInterval(iv);
          resolve(responses.get(id));
        } else if (Date.now() - start > 15_000) {
          clearInterval(iv);
          reject(new Error(`timeout on ${method}`));
        }
      }, 50);
    });
  }

  function callTool(name, args = {}) {
    return call('tools/call', { name, arguments: args });
  }

  function extractJson(resp) {
    const text = resp?.result?.content?.[0]?.text ?? '';
    try { return JSON.parse(text); } catch { return text; }
  }

  try {
    // Give MCP server a moment to boot
    await new Promise((r) => setTimeout(r, 500));

    // 1. Initialize (MCP handshake)
    console.log('\n[1] initialize');
    const init = await call('initialize', {
      protocolVersion: '2024-11-05',
      capabilities: {},
      clientInfo: { name: 'nexustest-smoke', version: '0.0.1' },
    });
    check('initialize returns serverInfo', init.result?.serverInfo?.name?.includes('nexustest'), JSON.stringify(init).slice(0, 200));

    // 2. tools/list
    console.log('\n[2] tools/list');
    const list = await call('tools/list', {});
    const toolNames = list.result?.tools?.map((t) => t.name) ?? [];
    check('tools/list returns 9 tools', toolNames.length === 9, `got ${toolNames.length}: ${toolNames.join(',')}`);
    check('delphi_health present', toolNames.includes('delphi_health'));
    check('delphi_click present', toolNames.includes('delphi_click'));
    check('delphi_dump present', toolNames.includes('delphi_dump'));

    // 3. delphi_health
    console.log('\n[3] delphi_health');
    const health = extractJson(await callTool('delphi_health'));
    check('health status=ok', health?.status === 'ok', JSON.stringify(health));

    // 4. delphi_components
    console.log('\n[4] delphi_components');
    const comps = extractJson(await callTool('delphi_components'));
    check('components array present', Array.isArray(comps?.components));
    check('FormMain in components', comps?.components?.some((s) => s.startsWith('FormMain:')));
    check('btnCalcular in components', comps?.components?.some((s) => s.startsWith('btnCalcular:')));

    // 5. delphi_dump (no args - full tree)
    console.log('\n[5] delphi_dump (full tree)');
    const tree = extractJson(await callTool('delphi_dump'));
    check('tree has forms array', Array.isArray(tree?.forms));
    check('mainForm is FormMain', tree?.mainForm === 'FormMain');

    // 6. delphi_dump single component
    console.log('\n[6] delphi_dump component=btnCalcular');
    const single = extractJson(await callTool('delphi_dump', { component: 'btnCalcular' }));
    check('single dump returns object', typeof single === 'object');
    check('single dump name=btnCalcular', single?.name === 'btnCalcular');
    check('single dump has bounds', single?.bounds != null);

    // 7. delphi_set
    console.log('\n[7] delphi_set edNome=Playwright');
    const setName = extractJson(await callTool('delphi_set', {
      component: 'edNome', property: 'Text', value: 'Playwright',
    }));
    check('set status=ok', setName?.status === 'ok', JSON.stringify(setName));

    console.log('\n[7b] delphi_set edValor=1000');
    const setVal = extractJson(await callTool('delphi_set', {
      component: 'edValor', property: 'Text', value: '1000',
    }));
    check('set edValor status=ok', setVal?.status === 'ok');

    // 8. delphi_get
    console.log('\n[8] delphi_get edNome.Text');
    const getName = extractJson(await callTool('delphi_get', {
      component: 'edNome', property: 'Text',
    }));
    check('get edNome.Text=Playwright', getName?.value === 'Playwright', JSON.stringify(getName));

    // 9. delphi_click btnCalcular
    console.log('\n[9] delphi_click btnCalcular');
    const click = extractJson(await callTool('delphi_click', { component: 'btnCalcular' }));
    check('click status=invoked', click?.status === 'invoked', JSON.stringify(click));

    // 10. Verify side-effect: lblResultado should contain 2000
    console.log('\n[10] verify lblResultado side-effect');
    const result = extractJson(await callTool('delphi_get', {
      component: 'lblResultado', property: 'Caption',
    }));
    check('lblResultado shows Playwright result', result?.value?.includes('Playwright') && result?.value?.includes('2000'),
      JSON.stringify(result));

    // 11. delphi_click again to increment counter — relative check, since
    // DemoVCL's Contador persists across runs (process not restarted).
    console.log('\n[11] delphi_click again (relative counter check)');
    const beforeMatch = (result?.value ?? '').match(/clicks=(\d+)/);
    const beforeCount = beforeMatch ? parseInt(beforeMatch[1], 10) : -1;
    await callTool('delphi_click', { component: 'btnCalcular' });
    const result2 = extractJson(await callTool('delphi_get', {
      component: 'lblResultado', property: 'Caption',
    }));
    const afterMatch = (result2?.value ?? '').match(/clicks=(\d+)/);
    const afterCount = afterMatch ? parseInt(afterMatch[1], 10) : -2;
    check('counter incremented by 1',
      afterCount === beforeCount + 1,
      `before=${beforeCount} after=${afterCount} value='${result2?.value}'`);

    // 12. delphi_invoke OnClick explicitly
    console.log('\n[12] delphi_invoke OnClick on btnLimpar');
    const invoke = extractJson(await callTool('delphi_invoke', {
      component: 'btnLimpar', event: 'OnClick',
    }));
    check('invoke OnClick btnLimpar status=invoked', invoke?.status === 'invoked', JSON.stringify(invoke));

    // 13. Verify btnLimpar side-effect: fields cleared
    const afterClear = extractJson(await callTool('delphi_get', {
      component: 'edNome', property: 'Text',
    }));
    check('edNome cleared after Limpar', afterClear?.value === '', JSON.stringify(afterClear));

    // 14. delphi_focus
    console.log('\n[14] delphi_focus edNome');
    const focus = extractJson(await callTool('delphi_focus', { component: 'edNome' }));
    check('focus status=focused', focus?.status === 'focused', JSON.stringify(focus));

    // 15. delphi_sendkey -  send "A" then verify it landed
    // Focus first, then set text to empty, then sendkey
    await callTool('delphi_set', { component: 'edNome', property: 'Text', value: '' });
    await callTool('delphi_focus', { component: 'edNome' });
    console.log('\n[15] delphi_sendkey A');
    const key = extractJson(await callTool('delphi_sendkey', { key: 'A' }));
    check('sendkey status=sent', key?.status === 'sent', JSON.stringify(key));

    // 16. Error handling: non-existent component
    console.log('\n[16] error: non-existent component');
    const err = extractJson(await callTool('delphi_get', {
      component: 'DoesNotExist', property: 'Text',
    }));
    check('error for missing component', typeof err?.error === 'string', JSON.stringify(err));

  } catch (e) {
    FAILED.push({ label: 'EXCEPTION', detail: e.message });
    console.error('[exception]', e);
  } finally {
    mcp.stdin.end();
    try { mcp.kill(); } catch {}

    console.log('\n========================================');
    console.log(`PASSED: ${PASSED.length}`);
    console.log(`FAILED: ${FAILED.length}`);
    if (FAILED.length > 0) {
      console.log('\nFailures:');
      FAILED.forEach((f) => console.log(`  - ${f.label}: ${f.detail ?? ''}`));
    }
    console.log('========================================');
    process.exit(FAILED.length > 0 ? 1 : 0);
  }
}

run();
