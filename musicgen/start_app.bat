@echo off
setlocal

set PORT=5001

REM Find the process ID (PID) using the specified port
for /f "tokens=5" %%a in ('netstat -aon ^| findstr :%PORT% ^| findstr LISTENING') do (
    set PID=%%a
)

REM Check if PID was found
if defined PID (
    echo Port %PORT% is in use by PID %PID%. Killing process...
    taskkill /F /PID %PID%
) else (
    echo Port %PORT% is available.
)


REM Activate the virtual environment
call venv\Scripts\activate

REM Change directory to src/
cd src/

REM Start uvicorn in a separate command prompt
start "" /b  uvicorn api:app --host 0.0.0.0 --port 5001 &

REM Wait for a few seconds to allow uvicorn to start (adjust as needed)
timeout /t 3 /nobreak >nul



set "cinst=Piano"

set "binst=Violoncello"

REM Validation URL
set "validate_url=http://localhost:5001/validate?chords_instrument=%cinst%&bass_instrument=%binst%"

REM Full run URL
set "run_url=http://localhost:5001/begin?melody_flag=1&chords_instrument=%cinst%&bass_instrument=%binst%"


REM Call the endpoint and capture the HTTP response code
for /f "delims=" %%i in ('curl -s -o nul -w "%%{http_code}" -X GET "%validate_url%" -H "Content-Type: application/json"') do set "status=%%i"

echo HTTP Status Code: %status%

REM Check if it was 404
if "%status%"=="404" (
    echo Error: Invalid instrument! Stopping script.
    exit /b 1
)

start "" /b curl -X POST "%run_url%" -H "Content-Type: application/json

:: monitor request 
REM Set the second URL
set "url2=http://localhost:5001/monitor"

REM Use curl to send the POST request to /monitor
start "" /b curl -X POST "%url2%" -H "Content-Type: application/json" 


endlocal

