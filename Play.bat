@echo off
rem Launch The Oregon Trail in Windows Terminal at a good size.
rem Falls back to the classic console if Windows Terminal is unavailable.
where wt.exe >nul 2>&1
if %errorlevel%==0 (
    start "" wt.exe --title "The Oregon Trail" powershell.exe -NoProfile -ExecutionPolicy Bypass -NoExit -File "%~dp0OregonTrail.ps1"
) else (
    mode con: cols=110 lines=32
    powershell.exe -NoProfile -ExecutionPolicy Bypass -NoExit -File "%~dp0OregonTrail.ps1"
)
