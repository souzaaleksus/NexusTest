// Visual verification via Playwright (headed) that the NexusTest repo
// was pushed correctly to github.com/souzaaleksus/NexusTest.
// Navigates to key pages, checks DOM, and captures screenshots.

import { chromium } from '@playwright/test';
import { mkdirSync } from 'node:fs';

const OUT = 'verification_screenshots';
mkdirSync(OUT, { recursive: true });

const browser = await chromium.launch({
  headless: false,
  slowMo: 300,
  args: ['--start-maximized'],
});
const context = await browser.newContext({ viewport: null });
const page = await context.newPage();

const checks = [];
function check(label, cond, detail = '') {
  checks.push({ label, pass: !!cond, detail });
  console.log(`  ${cond ? 'PASS' : 'FAIL'}: ${label}${detail ? ' — ' + detail : ''}`);
}

async function snap(name) {
  await page.screenshot({ path: `${OUT}/${name}.png`, fullPage: false });
}

try {
  // 1. Repo root
  console.log('\n[1] repo root');
  await page.goto('https://github.com/souzaaleksus/NexusTest', { waitUntil: 'domcontentloaded' });
  await page.waitForSelector('h1', { timeout: 15_000 });
  const title = await page.title();
  check('repo title contains NexusTest', title.includes('NexusTest'), title);
  await snap('01_root');

  // Check file list has the expected items
  const rootBody = await page.content();
  check('root shows agent folder', rootBody.includes('agent'));
  check('root shows mcp-server folder', rootBody.includes('mcp-server'));
  check('root shows docs folder', rootBody.includes('docs'));
  check('root shows README.md', rootBody.includes('README.md'));
  check('root shows LICENSE', rootBody.includes('LICENSE'));

  // 2. README rendered
  console.log('\n[2] README rendered');
  await page.waitForTimeout(1500);
  const readmeHeading = await page.locator('article h1').first().textContent().catch(() => '');
  check('README h1 is NexusTest', (readmeHeading ?? '').trim() === 'NexusTest', readmeHeading);
  await snap('02_readme');

  // 3. agent/src contents
  console.log('\n[3] agent/src');
  await page.goto('https://github.com/souzaaleksus/NexusTest/tree/main/agent/src', { waitUntil: 'domcontentloaded' });
  await page.waitForTimeout(2000);
  const agentBody = await page.content();
  check('agent/src shows DelphiTestAgent.pas', agentBody.includes('DelphiTestAgent.pas'));
  check('agent/src shows DelphiTestAgent.Server.pas', agentBody.includes('DelphiTestAgent.Server.pas'));
  check('agent/src shows DelphiTestAgent.Rtti.pas', agentBody.includes('DelphiTestAgent.Rtti.pas'));
  check('agent/src shows DelphiTestAgent.Invoke.pas', agentBody.includes('DelphiTestAgent.Invoke.pas'));
  await snap('03_agent_src');

  // 4. agent/demo
  console.log('\n[4] agent/demo');
  await page.goto('https://github.com/souzaaleksus/NexusTest/tree/main/agent/demo', { waitUntil: 'domcontentloaded' });
  await page.waitForTimeout(2000);
  const demoBody = await page.content();
  check('demo shows DemoVCL.dpr', demoBody.includes('DemoVCL.dpr'));
  check('demo shows DemoMain.pas', demoBody.includes('DemoMain.pas'));
  check('demo shows DemoMain.dfm', demoBody.includes('DemoMain.dfm'));
  check('demo shows build.bat', demoBody.includes('build.bat'));
  await snap('04_agent_demo');

  // 5. mcp-server folder
  console.log('\n[5] mcp-server');
  await page.goto('https://github.com/souzaaleksus/NexusTest/tree/main/mcp-server', { waitUntil: 'domcontentloaded' });
  await page.waitForTimeout(2000);
  const mcpBody = await page.content();
  check('mcp-server shows package.json', mcpBody.includes('package.json'));
  check('mcp-server shows tsconfig.json', mcpBody.includes('tsconfig.json'));
  check('mcp-server shows src folder', mcpBody.includes('src'));
  check('mcp-server shows test_all_tools.mjs', mcpBody.includes('test_all_tools.mjs'));
  await snap('05_mcp_server');

  // 6. docs
  console.log('\n[6] docs');
  await page.goto('https://github.com/souzaaleksus/NexusTest/tree/main/docs', { waitUntil: 'domcontentloaded' });
  await page.waitForTimeout(2000);
  const docsBody = await page.content();
  check('docs shows protocol.md', docsBody.includes('protocol.md'));
  check('docs shows integration.md', docsBody.includes('integration.md'));
  await snap('06_docs');

  // 7. Commit history
  console.log('\n[7] commits');
  await page.goto('https://github.com/souzaaleksus/NexusTest/commits/main', { waitUntil: 'domcontentloaded' });
  await page.waitForTimeout(2000);
  const commitsBody = await page.content();
  check('commits page shows "Initial NexusTest scaffold"', commitsBody.includes('Initial NexusTest scaffold'));
  check('commits page shows smoke test commit', commitsBody.includes('smoke test'));
  await snap('07_commits');

  // 8. Open the RTTI source file and verify content
  console.log('\n[8] view DelphiTestAgent.Rtti.pas');
  await page.goto('https://github.com/souzaaleksus/NexusTest/blob/main/agent/src/DelphiTestAgent.Rtti.pas', { waitUntil: 'domcontentloaded' });
  await page.waitForTimeout(2500);
  const srcBody = await page.content();
  check('source shows DumpTree function', srcBody.includes('DumpTree'));
  check('source shows FindComponentByName', srcBody.includes('FindComponentByName'));
  check('source shows SerializeComponent', srcBody.includes('SerializeComponent'));
  await snap('08_rtti_source');

} catch (err) {
  console.error('[verify] ERROR:', err.message);
  await page.screenshot({ path: `${OUT}/error.png`, fullPage: true });
} finally {
  await browser.close();

  const passed = checks.filter((c) => c.pass).length;
  const failed = checks.filter((c) => !c.pass);
  console.log('\n========================================');
  console.log(`PASSED: ${passed}`);
  console.log(`FAILED: ${failed.length}`);
  if (failed.length) {
    console.log('Failures:');
    failed.forEach((f) => console.log(`  - ${f.label}: ${f.detail}`));
  }
  console.log(`Screenshots in: ${OUT}/`);
  console.log('========================================');
  process.exit(failed.length ? 1 : 0);
}
