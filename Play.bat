@echo off
rem Launch The Oregon Trail in Windows Terminal at a good size.
rem The game asks for a window size at startup; pass -WindowSize 120x36 (or Classic,
rem Comfortable, Large, Wide, current, max) to skip that prompt.
rem Falls back to the classic console if Windows Terminal is unavailable.
where wt.exe >nul 2>&1
if %errorlevel%==0 (
    start "" wt.exe --size 110,32 new-tab --title "The Oregon Trail" powershell.exe -NoProfile -ExecutionPolicy Bypass -NoExit -File "%~dp0OregonTrail.ps1" %*
) else (
    mode con: cols=110 lines=32
    powershell.exe -NoProfile -ExecutionPolicy Bypass -NoExit -File "%~dp0OregonTrail.ps1" %*
)
