@echo off
:: ============================================================
:: NEXUS IIoT Demo — Reset (wipe data + restart)
:: Stops containers, deletes ALL volumes (DB data, Grafana state),
:: then starts a fresh stack. Use when demo data is messy.
:: ============================================================
setlocal

set "REPO_ROOT=%~dp0..\..\..\"

echo.
echo  ========================================
echo   NEXUS Aluminium Demo — Reset
echo  ========================================
echo.
echo  WARNING: This will DELETE all stored demo data:
echo    - All telemetry records in TimescaleDB
echo    - All alert history
echo    - Grafana dashboards will be re-provisioned from scratch
echo.

choice /M "Are you sure you want to wipe all data and reset?"
if errorlevel 2 (
    echo.
    echo  Reset cancelled. No data was changed.
    echo.
    pause
    exit /b 0
)

echo.
echo  Stopping containers and removing volumes...
pushd "%REPO_ROOT%"
docker compose down -v
if errorlevel 1 (
    echo.
    echo  ERROR: docker compose down -v failed. See output above.
    popd
    pause
    exit /b 1
)
popd

echo.
echo  Volumes cleared. Restarting with fresh state...
echo.

call "%~dp0start-demo.bat"
