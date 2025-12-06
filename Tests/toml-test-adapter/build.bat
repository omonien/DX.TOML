@echo off
REM Build script for DX.TOML.TestAdapter

echo Building DX.TOML toml-test adapter...

REM Check if dcc32 is in PATH
where dcc32 >nul 2>&1
if %ERRORLEVEL% NEQ 0 (
    echo Error: dcc32 not found in PATH
    echo Please add Delphi bin directory to your PATH or run from Delphi Command Prompt
    exit /b 1
)

REM Build the adapter
dcc32 -B -E..\..\Win32\Release DX.TOML.TestAdapter.dpr

if %ERRORLEVEL% EQU 0 (
    echo.
    echo Build successful!
    echo Executable: ..\..\Win32\Release\DX.TOML.TestAdapter.exe
    echo.
    echo To run toml-test:
    echo   toml-test ..\..\Win32\Release\DX.TOML.TestAdapter.exe
) else (
    echo.
    echo Build failed!
    exit /b 1
)
