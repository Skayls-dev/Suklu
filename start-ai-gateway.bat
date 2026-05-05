@echo off
title Suklu - AI Gateway (FastAPI)
set "ROOT=%~dp0"
set "ROOT=%ROOT:~0,-1%"

echo.
echo  ======================================================
echo   SUKLU - AI Gateway FastAPI
echo  ======================================================
echo   URL    : http://localhost:8000
echo   Docs   : http://localhost:8000/docs
echo   Health : http://localhost:8000/health
echo  ======================================================
echo.

cd /d "%ROOT%\backend\ai-gateway"

:: Verification du venv
if not exist ".venv\Scripts\activate.bat" (
    echo [ERREUR] Environnement Python non configure.
    echo Lance d'abord setup.bat
    pause
    exit /b 1
)

:: Verification du .env
if not exist ".env" (
    echo [ERREUR] Fichier .env manquant.
    echo Lance d'abord setup.bat puis configure backend\ai-gateway\.env
    pause
    exit /b 1
)

:: Verification de la cle API
findstr /i "sk-\.\.\." .env >nul 2>&1 && (
    echo [AVERTISSEMENT] La cle OPENAI_API_KEY semble non configuree dans .env
    echo.
)

echo Activation du venv Python...
call .venv\Scripts\activate.bat

echo Demarrage du serveur AI Gateway...
echo (Appuie sur Ctrl+C pour arreter)
echo.
python -m uvicorn main:app --reload --host 0.0.0.0 --port 8000
