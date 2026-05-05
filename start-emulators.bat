@echo off
title Suklu - Emulateurs Firebase
set "ROOT=%~dp0"
set "ROOT=%ROOT:~0,-1%"

echo.
echo  ======================================================
echo   SUKLU - Emulateurs Firebase
echo  ======================================================
echo   Auth       : http://localhost:9099
echo   Firestore  : http://localhost:8080
echo   Functions  : http://localhost:5001
echo   Storage    : http://localhost:9199
echo   Hosting    : http://localhost:5000
echo   UI         : http://localhost:4000
echo  ======================================================
echo.

cd /d "%ROOT%\infrastructure\firebase"

where firebase >nul 2>&1 || (
    echo [ERREUR] Firebase CLI non trouve.
    echo Installe-le avec : npm install -g firebase-tools
    pause
    exit /b 1
)

echo Demarrage des emulateurs Firebase...
echo (Appuie sur Ctrl+C pour arreter)
echo.
firebase emulators:start --import="%ROOT%\infrastructure\firebase\emulator-data" --export-on-exit="%ROOT%\infrastructure\firebase\emulator-data"
