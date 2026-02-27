@echo off
set FLUTTER_PATH=D:\Downloads\flutter_windows_3.35.5-stable\flutter\bin
echo Using Flutter from: %FLUTTER_PATH%
echo Running application...
"%FLUTTER_PATH%\flutter.bat" run
if %ERRORLEVEL% NEQ 0 (
    echo.
    echo detailed error info:
    echo ----------------------------------------
    "%FLUTTER_PATH%\flutter.bat" doctor
    echo ----------------------------------------
    echo.
    echo An error occurred while running the app.
    pause
    exit /b %ERRORLEVEL%
)
pause
