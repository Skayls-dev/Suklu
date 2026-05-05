@echo off
setlocal enabledelayedexpansion
title Suklu - Installation des dependances

set "ROOT=%~dp0"
set "ROOT=%ROOT:~0,-1%"

echo.
echo  ======================================================
echo   SUKLU - Setup des dependances de developpement
echo  ======================================================
echo.

:: ─── Verifications ───────────────────────────────────────────────────────────
echo [1/5] Verification des outils requis...
echo.

where node >nul 2>&1 || (echo [ERREUR] Node.js non installe. Telecharge: https://nodejs.org/ & pause & exit /b 1)
for /f "tokens=*" %%v in ('node -v') do echo   Node.js   : %%v

where npm >nul 2>&1 || (echo [ERREUR] npm non trouve. & pause & exit /b 1)
for /f "tokens=*" %%v in ('npm -v') do echo   npm       : %%v

where flutter >nul 2>&1 || (echo [ERREUR] Flutter non installe. Telecharge: https://flutter.dev & pause & exit /b 1)
for /f "tokens=1,2" %%a in ('flutter --version 2^>nul ^| findstr /i "flutter"') do echo   Flutter   : %%a %%b

where python >nul 2>&1 || (echo [ERREUR] Python non installe. Telecharge: https://python.org & pause & exit /b 1)
for /f "tokens=*" %%v in ('python --version') do echo   Python    : %%v

where firebase >nul 2>&1 || (
    echo [AVERTISSEMENT] Firebase CLI non installe. Installation en cours...
    call npm install -g firebase-tools
)
for /f "tokens=*" %%v in ('firebase --version 2^>nul') do echo   Firebase  : %%v

echo.

:: ─── Cloud Functions ─────────────────────────────────────────────────────────
echo [2/5] Installation des dependances Cloud Functions...
cd /d "%ROOT%\backend\functions"
call npm install
if errorlevel 1 (echo [ERREUR] npm install echoue dans backend/functions & pause & exit /b 1)
echo   OK - backend/functions
echo.

:: ─── Flutter Mobile ──────────────────────────────────────────────────────────
echo [3/5] Installation des packages Flutter (mobile)...
cd /d "%ROOT%\apps\mobile"
call flutter pub get
if errorlevel 1 (echo [ERREUR] flutter pub get echoue dans apps/mobile & pause & exit /b 1)
echo   OK - apps/mobile
echo.

:: ─── Flutter Admin ───────────────────────────────────────────────────────────
echo [4/5] Installation des packages Flutter (admin)...
cd /d "%ROOT%\apps\admin"
call flutter pub get
if errorlevel 1 (echo [ERREUR] flutter pub get echoue dans apps/admin & pause & exit /b 1)
echo   OK - apps/admin
echo.

:: ─── AI Gateway Python ───────────────────────────────────────────────────────
echo [5/5] Configuration de l'environnement Python (AI Gateway)...
cd /d "%ROOT%\backend\ai-gateway"

if not exist ".venv" (
    echo   Creation du venv Python...
    python -m venv .venv
    if errorlevel 1 (echo [ERREUR] Creation du venv echouee & pause & exit /b 1)
) else (
    echo   Venv Python existant detecte.
)

echo   Installation des dependances Python...
call .venv\Scripts\activate.bat
pip install -r requirements.txt --quiet
if errorlevel 1 (echo [ERREUR] pip install echoue & pause & exit /b 1)

if not exist ".env" (
    echo   Creation du fichier .env depuis .env.example...
    copy .env.example .env >nul
    echo.
    echo  [IMPORTANT] Configure les cles API dans :
    echo   %ROOT%\backend\ai-gateway\.env
    echo.
) else (
    echo   .env existant detecte - aucune modification.
)

echo.
echo  ======================================================
echo   Setup termine avec succes !
echo.
echo   Prochaines etapes :
echo   1. Edite backend\ai-gateway\.env avec tes cles API
echo   2. Ajoute firebase-service-account.json dans
echo      backend\ai-gateway\
echo   3. Lance start-all.bat pour demarrer tous les services
echo  ======================================================
echo.
pause
