@echo off
setlocal
set BDS=C:\Program Files (x86)\Embarcadero\Studio\37.0
set PATH=%BDS%\bin;%PATH%
set LIB_WIN32_RELEASE=%BDS%\lib\Win32\release
set LIB_WIN32_DEBUG=%BDS%\lib\Win32\debug

cd /d %~dp0
if not exist Win32\Release mkdir Win32\Release

dcc32 @build.rsp ^
  -U"%LIB_WIN32_RELEASE%" ^
  -I"%LIB_WIN32_RELEASE%" ^
  -O"%LIB_WIN32_RELEASE%" ^
  -R"%LIB_WIN32_RELEASE%"

if errorlevel 1 (
  echo === BUILD FAILED ===
  exit /b 1
)
echo === BUILD OK ===
dir Win32\Release\DemoVCL.exe
