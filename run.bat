@echo off
REM run.bat - starts backend (FastAPI/uvicorn) and frontend (Flutter) together
REM Place this file at your project root, one level above your backend/ and frontend/ folders.
REM Adjust the folder names below if yours are different.

echo Starting backend...
start "Backend" cmd /k "cd /d %~dp0backend && uvicorn main:app --reload"

REM Give the backend a few seconds to boot before launching the frontend
timeout /t 5 /nobreak > nul

echo Starting frontend...
start "Frontend" cmd /k "cd /d %~dp0frontend && flutter run"

echo Both services launching in separate windows.
