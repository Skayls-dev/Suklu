@echo off
title Suklu - Panel Admin Flutter Web
set "ROOT=%~dp0"
set "ROOT=%ROOT:~0,-1%"

echo.
echo  ======================================================
echo   SUKLU - Panel Admin (Flutter Web)
echo  ======================================================
echo   URL : http://localhost:8081
  ======================================================
echo.

where flutter >nul 2>&1 || (
    echo [ERREUR] Flutter non installe.
    echo Telecharge : https://flutter.dev/docs/get-started/install/windows
    pause
    exit /b 1
)

cd /d "%ROOT%\apps\admin"

echo Lancement du panel admin dans Chrome...
echo (Appuie sur Ctrl+C pour arreter, puis 'q' dans le terminal Flutter)
echo.
flutter run -d chrome --web-port 8081
