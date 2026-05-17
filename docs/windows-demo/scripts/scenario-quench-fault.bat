@echo off
:: ============================================================
:: NEXUS IIoT Demo — Trigger Quench Fault (flagship scenario)
:: Double-click while the demo is running to inject a live fault.
:: Watch Grafana and the web app update within ~10 seconds.
:: ============================================================
setlocal

echo.
echo  ========================================
echo   Triggering: QUALITY_HOLD_QUENCH
echo  ========================================
echo.
echo  What will happen:
echo    - Quench station flips to FAULTED (fault code 311)
echo    - Quench flow registers drop below spec
echo    - Exit temperature rises above T5/T6 window
echo    - Grafana decision board flips to AMBER
echo    - NEXUS alerts panel receives a new open alert (no refresh needed)
echo.
echo  Open browser tabs before continuing:
echo    Grafana ->  http://localhost:3000
echo    Web app ->  http://localhost:8080/alerts
echo.
echo  Sending scenario to simulator...
echo.

curl.exe -s -X POST http://localhost:5001/scenario ^
     -H "Content-Type: application/json" ^
     -d "{\"scenario\": \"QUALITY_HOLD_QUENCH\"}"

if errorlevel 1 (
    echo.
    echo  ERROR: Could not reach the simulator on port 5001.
    echo  Make sure the demo stack is running (start-demo.bat).
    echo.
    pause
    exit /b 1
)

echo.
echo.
echo  Scenario active. Watch Grafana and the Alerts page for updates.
echo  The scenario auto-resets to NORMAL after 10 minutes.
echo  To reset immediately, run scenario-reset.bat
echo.
pause
