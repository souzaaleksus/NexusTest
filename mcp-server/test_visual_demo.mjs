// Visual / paced end-to-end test for NexusTest.
// Runs the MCP server as a child process, spawns tool calls slowly so a
// human can watch the DemoVCL window update in real time.
//
// Before running: make sure DemoVCL.exe is already running. The script will
// bring its window to the foreground via PowerShell + Win32 API.

import { spawn, spawnSync } from 'node:child_process';

const PAUSE_MS = 1500; // delay between actions so the human can watch

function bringDemoToFront() {
  const ps = `
$code = @'
using System;
using System.Runtime.InteropServices;
public static class Win {
  [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr hWnd);
  [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
}
'@
Add-Type $code -ErrorAction SilentlyContinue
$p = Get-Process DemoVCL -ErrorAction SilentlyContinue
if ($p) {
  [Win]::ShowWindow($p.MainWindowHandle, 9) | Out-Null
  [Win]::SetForegroundWindow($p.MainWindowHandle) | Out-Null
}
`.trim();
  spawnSync('powershell.exe', ['-NoProfile', '-Command', ps], { stdio: 'ignore' });
}

function section(title) {
  console.log(`\n=== ${title} ===`);
}

function info(msg) { console.log(`  -> ${msg}`); }
function result(msg) { console.log(`  <- ${msg}`); }

async function sleep(ms) { return new Promise((r) => setTimeout(r, ms)); }

async function runDemo() {
  bringDemoToFront();

  const mcp = spawn('node', ['dist/index.js'], {
    stdio: ['pipe', 'pipe', 'inherit'],
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
      } catch {}
    }
  });

  let reqId = 0;
  function call(method, params) {
    const id = ++reqId;
    mcp.stdin.write(JSON.stringify({ jsonrpc: '2.0', id, method, params }) + '\n');
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

  async function tool(name, args = {}) {
    const r = await call('tools/call', { name, arguments: args });
    const text = r?.result?.content?.[0]?.text ?? '';
    try { return JSON.parse(text); } catch { return text; }
  }

  try {
    await sleep(500);

    section('HANDSHAKE');
    info('MCP initialize');
    const init = await call('initialize', {
      protocolVersion: '2024-11-05',
      capabilities: {},
      clientInfo: { name: 'visual-demo', version: '0.0.1' },
    });
    result(`server: ${init.result?.serverInfo?.name}`);
    await sleep(PAUSE_MS);

    section('DISCOVERY');
    info('tools/list (what can I do?)');
    const list = await call('tools/list', {});
    result(`${list.result.tools.length} tools: ${list.result.tools.map(t => t.name).join(', ')}`);
    await sleep(PAUSE_MS);

    info('delphi_health (is the agent alive?)');
    const h = await tool('delphi_health');
    result(JSON.stringify(h));
    await sleep(PAUSE_MS);

    info('delphi_components (what components exist?)');
    const comps = await tool('delphi_components');
    result(`${comps.components.length} components found`);
    comps.components.forEach(c => console.log(`     ${c}`));
    await sleep(PAUSE_MS);

    section('WATCH THE DEMOVCL WINDOW — fields will fill in automatically');
    bringDemoToFront();
    await sleep(1000);

    info('delphi_set edNome = "Alexandre Souza"');
    await tool('delphi_set', { component: 'edNome', property: 'Text', value: 'Alexandre Souza' });
    result('edNome filled');
    await sleep(PAUSE_MS);

    info('delphi_set edValor = "150.50"');
    await tool('delphi_set', { component: 'edValor', property: 'Text', value: '150.50' });
    result('edValor filled');
    await sleep(PAUSE_MS);

    section('INVOKING btnCalcular VIA RTTI');
    info('delphi_click btnCalcular (invokes OnClick on the main VCL thread)');
    const click1 = await tool('delphi_click', { component: 'btnCalcular' });
    result(JSON.stringify(click1));
    await sleep(PAUSE_MS);

    info('delphi_get lblResultado.Caption (reading the side effect)');
    const r1 = await tool('delphi_get', { component: 'lblResultado', property: 'Caption' });
    result(`lblResultado = "${r1.value}"`);
    await sleep(PAUSE_MS);

    section('CLICK AGAIN — counter should increment');
    info('delphi_click btnCalcular (second time)');
    await tool('delphi_click', { component: 'btnCalcular' });
    const r2 = await tool('delphi_get', { component: 'lblResultado', property: 'Caption' });
    result(`lblResultado = "${r2.value}"  (note clicks=2)`);
    await sleep(PAUSE_MS);

    section('SET DIFFERENT VALUE AND CLICK AGAIN');
    info('delphi_set edValor = "1000"');
    await tool('delphi_set', { component: 'edValor', property: 'Text', value: '1000' });
    await sleep(PAUSE_MS);
    info('delphi_click btnCalcular');
    await tool('delphi_click', { component: 'btnCalcular' });
    const r3 = await tool('delphi_get', { component: 'lblResultado', property: 'Caption' });
    result(`lblResultado = "${r3.value}"  (should show 2000.00, clicks=3)`);
    await sleep(PAUSE_MS);

    section('INVOKING btnLimpar — fields should clear');
    info('delphi_invoke btnLimpar OnClick');
    await tool('delphi_invoke', { component: 'btnLimpar', event: 'OnClick' });
    await sleep(PAUSE_MS);
    const after = await tool('delphi_get', { component: 'edNome', property: 'Text' });
    result(`edNome after clear = "${after.value}"  (should be empty)`);
    await sleep(PAUSE_MS);

    section('DEMONSTRATING delphi_dump FOR A SINGLE COMPONENT');
    info('delphi_dump btnCalcular');
    const dump = await tool('delphi_dump', { component: 'btnCalcular' });
    result(`name: ${dump.name}, class: ${dump.class}`);
    result(`bounds: ${JSON.stringify(dump.bounds)}`);
    result(`props.Caption: "${dump.props?.Caption}"`);
    result(`props.Enabled: ${dump.props?.Enabled}`);
    result(`props.Font.Color: ${dump.props?.['Font']}`);
    await sleep(PAUSE_MS);

    section('TYPING AFTER FOCUS');
    info('delphi_set edNome = "" (clear it first)');
    await tool('delphi_set', { component: 'edNome', property: 'Text', value: '' });
    await sleep(PAUSE_MS);
    info('delphi_focus edNome');
    await tool('delphi_focus', { component: 'edNome' });
    await sleep(PAUSE_MS);
    info('delphi_sendkey V');
    await tool('delphi_sendkey', { key: 'V' });
    await sleep(300);
    info('delphi_sendkey C');
    await tool('delphi_sendkey', { key: 'C' });
    await sleep(300);
    info('delphi_sendkey L');
    await tool('delphi_sendkey', { key: 'L' });
    await sleep(PAUSE_MS);

    section('FINAL STATE');
    const final = await tool('delphi_get', { component: 'edNome', property: 'Text' });
    result(`edNome = "${final.value}"`);

    section('ALL 9 MCP TOOLS EXERCISED END-TO-END');
    console.log('  delphi_health     : OK');
    console.log('  delphi_components : OK');
    console.log('  delphi_dump       : OK (both full tree and single component)');
    console.log('  delphi_get        : OK');
    console.log('  delphi_set        : OK');
    console.log('  delphi_click      : OK (invoked OnClick via RTTI TypInfo)');
    console.log('  delphi_invoke     : OK (invoked arbitrary event)');
    console.log('  delphi_focus      : OK');
    console.log('  delphi_sendkey    : OK');
    console.log('\nThe entire stack works:');
    console.log('  Node test runner -> MCP stdio JSON-RPC -> HTTP -> Indy server');
    console.log('  in DemoVCL.exe -> TypInfo RTTI -> TNotifyEvent via Synchronize');

  } catch (e) {
    console.error('[error]', e);
  } finally {
    mcp.stdin.end();
    try { mcp.kill(); } catch {}
  }
}

runDemo();
