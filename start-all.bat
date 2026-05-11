@echo off
title Suklu - Demarrage complet
set "ROOT=%~dp0"
set "ROOT=%ROOT:~0,-1%"

echo.
echo  ======================================================
echo   SUKLU - Demarrage de tous les services
echo  ======================================================
echo.
echo  Ce script va ouvrir 3 fenetres separees :
echo.
echo   [1] Emulateurs Firebase
echo       - UI      : http://localhost:4000
echo       - Auth    : http://localhost:9099
echo       - Firestore: http://localhost:8080 (interne)
echo       - Functions: http://localhost:5001
echo.
echo   [2] AI Gateway (FastAPI)
echo       - API  : http://localhost:8000
echo       - Docs : http://localhost:8000/docs
echo.
echo   [3] Panel Admin (Flutter Web)
       - URL  : http://localhost:8081
echo.
echo  L'app mobile se lance separement via start-mobile.bat
echo  ======================================================
echo.

:: Verification .env AI Gateway
if not exist "%ROOT%\backend\ai-gateway\.env" (
    echo [ERREUR] backend\ai-gateway\.env manquant.
    echo Lance d'abord setup.bat et configure les cles API.
    pause
    exit /b 1
)

set /p CONFIRM="Demarrer tous les services ? (O/N) : "
if /i not "%CONFIRM%"=="O" (
    echo Annule.
    exit /b 0
)

echo.
echo Ouverture des fenetres de services...
echo.

:: Fenetre 1 : Emulateurs Firebase
echo [1/3] Demarrage des emulateurs Firebase...
start "Suklu - Emulateurs Firebase" cmd /k "cd /d %ROOT%\infrastructure\firebase && firebase emulators:start --import=%ROOT%\infrastructure\firebase\emulator-data --export-on-exit=%ROOT%\infrastructure\firebase\emulator-data"

:: Attendre quelques secondes que Firebase s'initialise
echo Attente de l'initialisation Firebase (10s)...
timeout /t 10 /nobreak >nul

:: Fenetre 2 : AI Gateway
echo [2/3] Demarrage de l'AI Gateway...
start "Suklu - AI Gateway" cmd /k "cd /d %ROOT%\backend\ai-gateway && call .venv\Scripts\activate.bat && python -m uvicorn main:app --reload --host 0.0.0.0 --port 8000"

:: Fenetre 3 : Panel Admin
echo [3/3] Demarrage du panel admin...
start "Suklu - Admin Panel" cmd /k "cd /d %ROOT%\apps\admin && flutter run -d chrome --web-port 8081"

echo.
echo  ======================================================
echo   Tous les services ont ete lances dans des fenetres
echo   separees. Pour arreter un service, ferme sa fenetre
echo   ou appuie sur Ctrl+C dedans.
echo.
echo   Pour lancer l'app mobile : start-mobile.bat
echo  ======================================================
echo.
pause
