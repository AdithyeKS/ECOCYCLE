@echo off
echo Adding Flutter to User PATH...
powershell -Command "[System.Environment]::SetEnvironmentVariable('Path', [System.Environment]::GetEnvironmentVariable('Path', 'User') + ';D:\Downloads\flutter_windows_3.35.5-stable\flutter\bin', 'User')"
echo.
echo flutter has been added to your PATH.
echo Please restart your terminal (close and open a new one) for changes to take effect.
pause
