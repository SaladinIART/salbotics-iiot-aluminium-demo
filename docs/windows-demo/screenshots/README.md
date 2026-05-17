# Demo Screenshots

Screenshots used in [`../WINDOWS_DEMO.md`](../WINDOWS_DEMO.md).

## Naming convention

Files in this folder follow a strict naming scheme so WINDOWS_DEMO.md links always work:

| Filename | What it shows |
|---|---|
| `01-grafana-decision-board.png` | Grafana Aluminium Profile Decision Board — healthy GREEN state |
| `02-svelte-dashboard.png` | NEXUS web app — Executive View / Dashboard |
| `03-asset-list.png` | Asset Browser with signal history chart open for one station |
| `04-alerts-panel.png` | Alert Inbox with at least one OPEN alert visible |
| `05-quench-fault-active.png` | Both Grafana + Svelte showing QUALITY_HOLD_QUENCH active (AMBER) |

## Capture them yourself

With the demo stack running, double-click (or open PowerShell and run):

```powershell
.\capture-screenshots.ps1
```

This uses Playwright (via `npx`) to automate the browser and save each screenshot to this folder with the correct filename. It installs Chromium on first run (~170 MB, cached afterward).

## Manual screenshots

If `capture-screenshots.ps1` fails (no Node.js, etc.), take them manually:

1. Start the demo: `start-demo.bat`
2. Open Grafana (`http://localhost:3000`) and navigate to the Aluminium Profile Decision Board
3. Screenshot (Windows: `Win + Shift + S` → save as `01-grafana-decision-board.png`)
4. Open NEXUS web app (`http://localhost:8080`) and screenshot the Dashboard as `02-svelte-dashboard.png`
5. Navigate to `/assets`, open one asset detail, screenshot as `03-asset-list.png`
6. Navigate to `/alerts`, screenshot as `04-alerts-panel.png`
7. Run `scenario-quench-fault.bat`, wait 10 s, screenshot both tabs stitched or just the most visual one as `05-quench-fault-active.png`
