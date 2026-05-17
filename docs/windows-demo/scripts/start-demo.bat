@echo off
:: ============================================================
:: NEXUS IIoT Demo — Start
:: Double-click to spin up the full stack and open your browser.
:: Requires: Docker Desktop running with WSL2 enabled.
:: ============================================================
setlocal enabledelayedexpansion

set "REPO_ROOT=%~dp0..\..\..\"
set "ATTEMPTS=0"
set "MAX_ATTEMPTS=18"

echo.
echo  ========================================
echo   NEXUS Aluminium Demo — Starting up
echo  ========================================
echo.

:: ── Verify Docker is reachable ───────────────────────────────
docker info > nul 2>&1
if errorlevel 1 (
    echo  ERROR: Docker Desktop is not running.
    echo.
    echo  Please open Docker Desktop, wait for the whale icon
    echo  in the system tray to go solid, then run this script again.
    echo.
    pause
    exit /b 1
)

:: ── Start the stack ──────────────────────────────────────────
echo  Starting containers (first run takes ~3 min for image build)...
echo.

pushd "%REPO_ROOT%"
docker compose up -d --build
if errorlevel 1 (
    echo.
    echo  ERROR: docker compose failed. See output above for details.
    echo  Common fixes:
    echo    - Port already in use: check WINDOWS_DEMO.md Troubleshooting
    echo    - Missing .env file: copy .env.example to .env and re-run
    echo.
    popd
    pause
    exit /b 1
)

:: ── Wait for API and Grafana to be ready ─────────────────────
echo.
echo  Waiting for services to become healthy...

:wait_loop
set /a "ATTEMPTS+=1"
docker compose ps --format "{{.Service}} {{.Status}}" 2>nul | findstr /I "api.*running api.*healthy" > nul 2>&1
if not errorlevel 1 (
    docker compose ps --format "{{.Service}} {{.Status}}" 2>nul | findstr /I "grafana.*running grafana.*healthy" > nul 2>&1
    if not errorlevel 1 goto ready
)

if %ATTEMPTS% geq %MAX_ATTEMPTS% (
    echo.
    echo  WARNING: Timed out waiting for healthy status.
    echo  The stack may still be starting. Check http://localhost:3000
    echo  in 30 seconds. Run  docker compose ps  to see container state.
    echo.
    goto open_browsers
)

echo  Still starting... (%ATTEMPTS%/%MAX_ATTEMPTS%) — checking again in 5 s
timeout /t 5 /nobreak > nul
goto wait_loop

:ready
echo.
echo  All services ready.

:open_browsers
popd
echo.
echo  ----------------------------------------
echo   Opening dashboards in your browser...
echo  ----------------------------------------
echo.
echo   Grafana decision board  ->  http://localhost:3000
echo   Login: admin / change_me_now
echo.
echo   NEXUS web app           ->  http://localhost:8080
echo.

timeout /t 2 /nobreak > nul
start "" http://localhost:3000
timeout /t 1 /nobreak > nul
start "" http://localhost:8080

echo  Done. To trigger a fault scenario, run scenario-quench-fault.bat
echo  To stop the stack, run stop-demo.bat
echo.
pause
