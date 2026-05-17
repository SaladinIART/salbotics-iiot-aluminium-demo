@echo off
:: ============================================================
:: NEXUS IIoT Demo — Stop
:: Double-click to stop all containers cleanly.
:: Your data (TimescaleDB volumes) is preserved for next run.
:: ============================================================
setlocal

set "REPO_ROOT=%~dp0..\..\..\"

echo.
echo  ========================================
echo   NEXUS Aluminium Demo — Stopping
echo  ========================================
echo.
echo  Stopping containers (volumes kept — your alert history is safe)...
echo.

pushd "%REPO_ROOT%"
docker compose down
if errorlevel 1 (
    echo.
    echo  ERROR: docker compose down failed. See output above.
    popd
    pause
    exit /b 1
)
popd

echo.
echo  All containers stopped.
echo  Volumes kept — next start will have your data intact.
echo.
echo  To wipe all data and start fresh: run reset-demo.bat
echo.
pause
