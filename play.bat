@echo off
setlocal EnableDelayedExpansion
cd /d "%~dp0"

set "GODOT="
where godot >nul 2>nul && for /f "delims=" %%G in ('where godot') do (
  set "GODOT=%%G"
  goto :found
)

if exist "%LOCALAPPDATA%\Microsoft\WinGet\Links\godot.exe" (
  set "GODOT=%LOCALAPPDATA%\Microsoft\WinGet\Links\godot.exe"
  goto :found
)

for /d %%D in ("%LOCALAPPDATA%\Microsoft\WinGet\Packages\GodotEngine.GodotEngine*") do (
  if exist "%%D\Godot_v4.7.2-stable_win64_console.exe" (
    set "GODOT=%%D\Godot_v4.7.2-stable_win64_console.exe"
    goto :found
  )
  if exist "%%D\Godot_v4.7.2-stable_win64.exe" (
    set "GODOT=%%D\Godot_v4.7.2-stable_win64.exe"
    goto :found
  )
)

echo Godot not found. Install Godot 4.7 and retry.
pause
exit /b 1

:found
echo Using: !GODOT!
echo Dir: %CD%
echo.
"!GODOT!" --path "%CD%" -- --test
set "ERR=!ERRORLEVEL!"
echo.
echo Exit code !ERR!
if not "!ERR!"=="0" pause
exit /b !ERR!
