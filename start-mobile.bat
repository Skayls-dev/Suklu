@echo off
title Suklu - App Mobile Flutter
set "ROOT=%~dp0"
set "ROOT=%ROOT:~0,-1%"

echo.
echo  ======================================================
echo   SUKLU - Application Mobile Flutter
echo  ======================================================
echo.

where flutter >nul 2>&1 || (
    echo [ERREUR] Flutter non installe.
    echo Telecharge : https://flutter.dev/docs/get-started/install/windows
    pause
    exit /b 1
)

cd /d "%ROOT%\apps\mobile"

:: Verification google-services.json
if not exist "android\app\google-services.json" (
    echo [AVERTISSEMENT] android\app\google-services.json manquant.
    echo Telecharge-le depuis la console Firebase et place-le dans apps\mobile\android\app\
    echo.
)

echo Appareils disponibles :
echo.
flutter devices
echo.

set /p DEVICE="Entrez l'ID de l'appareil cible (laisse vide pour l'appareil par defaut) : "

echo.
echo Lancement de l'application...
echo (Appuie sur Ctrl+C pour arreter, puis 'q' dans le terminal Flutter)
echo.

if "%DEVICE%"=="" (
    flutter run
) else (
    flutter run -d %DEVICE%
)
