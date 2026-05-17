@echo off
:: ============================================================
:: NEXUS IIoT Demo — Reset scenario to NORMAL
:: Double-click to return all stations to the healthy running state.
:: ============================================================
setlocal

echo.
echo  ========================================
echo   Resetting scenario to NORMAL
echo  ========================================
echo.
echo  All 7 stations will return to RUNNING state.
echo  Grafana decision board should flip back to GREEN within ~10 s.
echo.
echo  Sending reset to simulator...
echo.

curl.exe -s -X POST http://localhost:5001/scenario ^
     -H "Content-Type: application/json" ^
     -d "{\"scenario\": \"NORMAL\"}"

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
echo  Scenario reset. Decision board should return to GREEN shortly.
echo.
pause
