# ============================================================
# NEXUS IIoT Demo - Automated Screenshot Capture
# Requires: Node.js (any LTS), demo stack running (start-demo.bat)
# Run from PowerShell: .\capture-screenshots.ps1
# Saves 5 screenshots to ..\screenshots\ with canonical names.
# ============================================================

$ErrorActionPreference = "Continue"
$ScreenshotsDir = Join-Path $PSScriptRoot "..\screenshots"

# ── Preflight checks ──────────────────────────────────────────

Write-Host ""
Write-Host " ========================================"
Write-Host "  NEXUS Demo - Screenshot Capture"
Write-Host " ========================================"
Write-Host ""

# Node.js
if (-not (Get-Command node -ErrorAction SilentlyContinue)) {
    Write-Host " ERROR: Node.js not found." -ForegroundColor Red
    Write-Host " Install from https://nodejs.org (LTS version) and retry."
    Write-Host ""
    exit 1
}
$nodeVersion = node --version
Write-Host " Node.js: $nodeVersion" -ForegroundColor Green

# Demo stack reachable
try {
    $null = Invoke-WebRequest -Uri "http://localhost:8080" -UseBasicParsing -TimeoutSec 5
    Write-Host " NEXUS web app: reachable on :8080" -ForegroundColor Green
} catch {
    Write-Host " ERROR: Cannot reach http://localhost:8080" -ForegroundColor Red
    Write-Host " Make sure the demo is running (start-demo.bat) before capturing."
    Write-Host ""
    exit 1
}

# Screenshots folder
if (-not (Test-Path $ScreenshotsDir)) {
    New-Item -ItemType Directory -Path $ScreenshotsDir | Out-Null
}
Write-Host " Output folder: $ScreenshotsDir"
Write-Host ""

# ── Set up local playwright project (created once, reused) ───

$workDir = Join-Path $env:TEMP "nexus_pw_capture"
$pwModule = Join-Path $workDir "node_modules\playwright"

if (-not (Test-Path $pwModule)) {
    Write-Host " First run: installing Playwright module (~60 s)..."
    New-Item -ItemType Directory -Path $workDir -Force | Out-Null
    '{"name":"nexus-capture","version":"1.0.0"}' | Set-Content (Join-Path $workDir "package.json") -Encoding UTF8
    $env:PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD = "1"
    npm install playwright --prefix $workDir 2>&1 | Out-Null
    Remove-Item Env:PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD -ErrorAction SilentlyContinue
} else {
    Write-Host " Playwright module: cached" -ForegroundColor Green
}

Write-Host " Installing/verifying Chromium browser..."
npx --yes playwright install chromium 2>&1 | Out-Null
Write-Host " Playwright/Chromium ready." -ForegroundColor Green

# ── Write the capture script to a temp file ──────────────────

$captureScript = @"
const { chromium } = require('playwright');
const path = require('path');
const http = require('http');

const OUT = process.argv[2];

// Helper: navigate via sidebar link (SPA — direct URL goto causes 404)
async function clickNav(page, label) {
  const link = page.locator('nav a, aside a, [role="navigation"] a').filter({ hasText: label }).first();
  if (await link.count() > 0) {
    await link.click();
    await page.waitForTimeout(1500);
  }
}

// Helper: POST scenario to simulator
function postScenario(name) {
  return new Promise((resolve, reject) => {
    const body = JSON.stringify({ scenario: name });
    const req = http.request(
      { host: 'localhost', port: 5001, path: '/scenario', method: 'POST',
        headers: { 'Content-Type': 'application/json', 'Content-Length': Buffer.byteLength(body) } },
      (res) => { res.resume(); res.on('end', resolve); }
    );
    req.on('error', reject);
    req.write(body);
    req.end();
  });
}

(async () => {
  const browser = await chromium.launch({ headless: true });
  const ctx = await browser.newContext({ viewport: { width: 1440, height: 900 } });

  // ── 1: Grafana IIoT decision board ────────────────────────
  console.log('  [1/5] Grafana IIoT decision board...');
  const grafana = await ctx.newPage();
  await grafana.goto('http://localhost:3000/login', { waitUntil: 'networkidle' });
  await grafana.fill('input[name="user"]', 'admin');
  await grafana.fill('input[name="password"]', 'change_me_now');
  // Try multiple Grafana login button selectors across versions
  await grafana.click('[data-testid="data-testid Login button"], button[aria-label="Login button"], button:has-text("Log in"), input[type="submit"]').catch(() => {});
  await grafana.waitForTimeout(3000);
  // Dismiss change-password prompt if present
  await grafana.click('button:has-text("Skip"), a:has-text("Skip")').catch(() => {});
  await grafana.waitForTimeout(1000);
  // Navigate directly to the provisioned dashboard by UID
  await grafana.goto(
    'http://localhost:3000/d/nexus-aluminium-decision-board/aluminium-profile-decision-board',
    { waitUntil: 'networkidle', timeout: 20000 }
  );
  await grafana.waitForTimeout(4000); // let panels render
  await grafana.screenshot({ path: path.join(OUT, '01-grafana-decision-board.png'), fullPage: false });
  console.log('    saved 01-grafana-decision-board.png');

  // ── 2: NEXUS Floor Overview (root — SPA entry point) ──────
  console.log('  [2/5] NEXUS Floor Overview...');
  const app = await ctx.newPage();
  await app.goto('http://localhost:8080/', { waitUntil: 'networkidle', timeout: 20000 });
  await app.waitForTimeout(2000);
  await app.screenshot({ path: path.join(OUT, '02-svelte-dashboard.png'), fullPage: false });
  console.log('    saved 02-svelte-dashboard.png');

  // ── 3: Asset browser (click sidebar nav) ──────────────────
  console.log('  [3/5] Asset browser...');
  await clickNav(app, 'Assets');
  await app.waitForTimeout(2000);
  // Click first asset card/row if present to show signal detail
  const firstAsset = app.locator('a[href*="/assets/"], [data-testid="asset-row"], .asset-card').first();
  if (await firstAsset.count() > 0) {
    await firstAsset.click();
    await app.waitForTimeout(2000);
  }
  await app.screenshot({ path: path.join(OUT, '03-asset-list.png'), fullPage: false });
  console.log('    saved 03-asset-list.png');

  // ── 4: Alerts panel (click sidebar nav) ───────────────────
  console.log('  [4/5] Alerts panel...');
  await clickNav(app, 'Alerts');
  await app.waitForTimeout(2000);
  await app.screenshot({ path: path.join(OUT, '04-alerts-panel.png'), fullPage: false });
  console.log('    saved 04-alerts-panel.png');

  // ── 5: Quench fault — capture Grafana decision board ──────
  console.log('  [5/5] Triggering quench fault...');
  await postScenario('QUALITY_HOLD_QUENCH');
  // Wait for SSE + Grafana refresh cycle (~12 s)
  await grafana.waitForTimeout(12000);
  await grafana.reload({ waitUntil: 'networkidle' });
  await grafana.waitForTimeout(3000);
  await grafana.screenshot({ path: path.join(OUT, '05-quench-fault-active.png'), fullPage: false });
  console.log('    saved 05-quench-fault-active.png');

  await browser.close();
  console.log('');
  console.log('  All 5 screenshots captured.');
})();
"@

$tempScript = Join-Path $workDir "capture.js"
Set-Content -Path $tempScript -Value $captureScript -Encoding UTF8

# ── Run capture from workDir so require('playwright') resolves ─

Write-Host " Capturing screenshots (takes ~30 s - Chromium is headless)..."
Write-Host ""

Push-Location $workDir
node $tempScript $ScreenshotsDir
$captureExit = $LASTEXITCODE
Pop-Location

if ($captureExit -ne 0) {
    Write-Host ""
    Write-Host " ERROR: Screenshot capture failed (exit $captureExit)." -ForegroundColor Red
    Write-Host " Check that the demo stack is fully up and Grafana/web app load in your browser."
    Write-Host " Capture script at: $tempScript"
    Write-Host ""
    exit 1
}

# ── Summary ───────────────────────────────────────────────────

Write-Host ""
Write-Host " ========================================"
Write-Host "  Done! Files written to:"
Write-Host "  $ScreenshotsDir"
Write-Host ""
Write-Host "  01-grafana-decision-board.png"
Write-Host "  02-svelte-dashboard.png"
Write-Host "  03-asset-list.png"
Write-Host "  04-alerts-panel.png"
Write-Host "  05-quench-fault-active.png"
Write-Host " ========================================"
Write-Host ""
Write-Host " Reset scenario to NORMAL: run scenario-reset.bat"
Write-Host ""
