@echo off
cd /d "%~dp0"
python tools\export_tables.py
if errorlevel 1 (
  echo Export failed. Existing JSON was preserved.
) else (
  echo Export complete. Restart the game to load the new data.
)
pause
