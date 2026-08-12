@echo off
setlocal EnableExtensions
title GitHub Credential Fix
color 0A
chcp 65001 >nul 2>&1

echo ==================================================
echo   GitHub Credential Check ^& Fix
echo   Verifica primero, corrige solo si hace falta.
echo ==================================================
echo.

REM ===== 1) Git instalado? =====
git --version >nul 2>&1
if errorlevel 1 (
    echo [ERROR] git no encontrado. Instala Git for Windows:
    echo         https://git-scm.com/download/win
    echo.
    pause
    exit /b 1
)
for /f "delims=" %%v in ('git --version') do echo [OK] %%v
echo.

REM ===== 2) Detectar overrides de gh.exe en la config =====
set "FOUND_OVERRIDE="
git config --get-regexp "credential\." 2>nul | findstr /I /R "github\.com\.helper gist\.github\.com\.helper" >nul 2>&1
if not errorlevel 1 set "FOUND_OVERRIDE=1"

if defined FOUND_OVERRIDE (
    echo [DETECTADO] Overrides de gh.exe en la config de git.
    echo             Bloquean el selector de cuentas de GCM.
) else (
    echo [OK] No hay overrides de gh.exe en la config.
)
echo.

REM ===== 3) Prueba funcional: GCM responde? =====
set "TMPF=%TEMP%\ghc_cred_%RANDOM%.txt"
> "%TMPF%" echo protocol=https
>> "%TMPF%" echo host=github.com
>> "%TMPF%" echo.
git credential fill < "%TMPF%" >nul 2>&1
set "FILL_RC=%errorlevel%"
del "%TMPF%" >nul 2>&1

set "GCM_OK="
if "%FILL_RC%"=="0" (
    echo [OK] GCM responde correctamente.
    set "GCM_OK=1"
) else (
    echo [DETECTADO] GCM NO responde - codigo %FILL_RC%.
    echo             El selector de cuentas no aparecera.
)
echo.

REM ===== 4) Decidir: aplicar solucion o terminar =====
if defined FOUND_OVERRIDE goto :apply_fix
if defined GCM_OK goto :all_ok

:apply_fix
echo ==================================================
echo   APLICANDO SOLUCION...
echo ==================================================
echo.
echo [1/3] Quitando overrides de gh.exe (global y local)...
git config --global --unset-all credential.https://github.com.helper 2>nul
git config --global --unset-all credential.https://gist.github.com.helper 2>nul
git config --local --unset-all credential.https://github.com.helper 2>nul
git config --local --unset-all credential.https://gist.github.com.helper 2>nul
echo       Hecho.
echo.
echo [2/3] Asegurando credential.helper=manager...
git config --global --get credential.helper >nul 2>&1
if errorlevel 1 (
    git config --global credential.helper manager
    echo       Definido: manager
) else (
    echo       Ya estaba configurado.
)
echo.
echo [3/3] Re-verificando...
set "TMPF=%TEMP%\ghc_cred_%RANDOM%.txt"
> "%TMPF%" echo protocol=https
>> "%TMPF%" echo host=github.com
>> "%TMPF%" echo.
git credential fill < "%TMPF%" >nul 2>&1
set "RC2=%errorlevel%"
del "%TMPF%" >nul 2>&1

if "%RC2%"=="0" (
    echo.
    echo ==================================================
    echo   SOLUCION APLICADA. El selector de cuentas
    echo   aparecera al clonar.
    echo ==================================================
    pause
    exit /b 0
)

echo.
echo [AVISO] GCM sigue sin responder tras limpiar la config.
echo         Posible causa: Git Credential Manager no esta instalado.
echo         Instalalo con:
echo             winget install Git.CredentialManager
echo.
pause
exit /b 2

:all_ok
echo ==================================================
echo   TODO FUNCIONA. No se necesita ninguna correccion.
echo   El selector de cuentas aparecera al clonar.
echo ==================================================
pause
exit /b 0
