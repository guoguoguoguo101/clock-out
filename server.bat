@echo off
setlocal
cd /d "%~dp0"

set "GOEXE="
where go >nul 2>nul && set "GOEXE=go"
if not defined GOEXE if exist "%ProgramFiles%\Go\bin\go.exe" set "GOEXE=%ProgramFiles%\Go\bin\go.exe"
if not defined GOEXE if exist "%LOCALAPPDATA%\Programs\Go\bin\go.exe" set "GOEXE=%LOCALAPPDATA%\Programs\Go\bin\go.exe"

if not defined GOEXE (
  echo 没找到 Go。请安装 https://go.dev/dl/ 后重试。
  pause
  exit /b 1
)

cd server
echo 启动 clock-out Go 服务端  端口 27111
"%GOEXE%" run ./cmd/clockout-server %*
if errorlevel 1 (
  echo.
  echo 服务端退出异常。
  pause
)
