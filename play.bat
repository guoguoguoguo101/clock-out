@echo off
setlocal
cd /d "%~dp0"

set "GODOT="
where godot >nul 2>nul && set "GODOT=godot"
if not defined GODOT if exist "%LOCALAPPDATA%\Microsoft\WinGet\Links\godot.exe" set "GODOT=%LOCALAPPDATA%\Microsoft\WinGet\Links\godot.exe"
if not defined GODOT for /d %%D in ("%LOCALAPPDATA%\Microsoft\WinGet\Packages\GodotEngine.GodotEngine*") do (
  if exist "%%D\Godot_v4.7.2-stable_win64.exe" set "GODOT=%%D\Godot_v4.7.2-stable_win64.exe"
)

if not defined GODOT (
  echo 正在用 winget 安装 Godot 4 ...
  winget install --id GodotEngine.GodotEngine --exact --accept-package-agreements --accept-source-agreements
  if exist "%LOCALAPPDATA%\Microsoft\WinGet\Links\godot.exe" set "GODOT=%LOCALAPPDATA%\Microsoft\WinGet\Links\godot.exe"
)

if not defined GODOT (
  echo 没找到 Godot。请安装后把 godot 加到 PATH，或再运行一次本脚本。
  pause
  exit /b 1
)

"%GODOT%" --path . -- --test
if errorlevel 1 (
  echo.
  echo 游戏启动失败，上面是报错。
  pause
)
