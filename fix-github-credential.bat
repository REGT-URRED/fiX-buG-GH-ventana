@echo off
setlocal EnableExtensions EnableDelayedExpansion
title GitHub Credential Fix
color 0A

REM Nota: sin "chcp 65001" a proposito. Este archivo es ASCII puro y
REM cambiar el code page a UTF-8 rompe "set /p" cuando la entrada
REM viene redirigida (bug conocido de cmd).

REM ============================================================
REM  GitHub Credential Fix
REM  Restaura el selector de cuentas de Git Credential Manager
REM  y permite limpiar cuentas guardadas de forma selectiva.
REM
REM  Este archivo NO contiene cuentas, tokens ni rutas de usuario.
REM  Las cuentas se detectan y se eligen desde el menu.
REM ============================================================

set "GH_HOST=github.com"
set "BAD=0"

REM ===== Preflight =====
git --version >nul 2>&1
if errorlevel 1 (
    echo [ERROR] git no encontrado. Instala Git for Windows:
    echo         https://git-scm.com/download/win
    echo.
    pause
    exit /b 1
)

goto :main_menu


REM ============================================================
REM  Menu principal
REM ============================================================
:main_menu
cls
echo ==================================================
echo   GitHub Credential Fix
echo ==================================================
echo   1) Corregir   - limpia overrides de gh.exe y asegura GCM
echo   2) Verificar  - estado actual (solo lectura)
echo   3) Limpiar    - elegir cuentas a eliminar o conservar
echo   4) Otros      - reparar tokens / ayuda
echo   0) Salir
echo ==================================================
echo.
set "OPT="
set /p "OPT=Elegi una opcion: "

if "%OPT%"=="1" goto :do_corregir
if "%OPT%"=="2" goto :do_verificar
if "%OPT%"=="3" goto :do_limpiar
if "%OPT%"=="4" goto :do_otros
if "%OPT%"=="0" goto :salir

set /a BAD+=1
if %BAD% GTR 5 goto :salir
echo.
echo     Opcion invalida.
timeout /t 1 >nul 2>&1
goto :main_menu


REM ============================================================
REM  1) Corregir
REM ============================================================
:do_corregir
cls
echo [Corregir] Limpieza de overrides de gh.exe y verificacion de GCM
echo.

git config --global --unset-all credential.https://github.com.helper 2>nul
git config --global --unset-all credential.https://gist.github.com.helper 2>nul
git config --local  --unset-all credential.https://github.com.helper 2>nul
git config --local  --unset-all credential.https://gist.github.com.helper 2>nul
echo     [OK] Overrides de gh.exe eliminados (global y local).

git config --global credential.helper manager
echo     [OK] credential.helper=manager

git credential-manager --version >nul 2>&1
if errorlevel 1 (
    echo     [AVISO] Git Credential Manager no responde.
    echo             Instalalo con: winget install Git.CredentialManager
) else (
    echo     [OK] Git Credential Manager presente.
)
echo.
pause
goto :main_menu


REM ============================================================
REM  2) Verificar  (solo lectura)
REM ============================================================
:do_verificar
cls
echo [Verificar] Estado actual. Este modo no modifica nada.
echo.
echo     Cuentas detectadas en GCM:
call :load_accounts
if "%ACCT_COUNT%"=="0" echo     (ninguna)
echo.
echo     Entradas en Credential Manager:
cmdkey /list 2>nul | findstr /I "target=git:https://"
echo.
echo     Validacion de tokens:
call :validate_all
echo.
pause
goto :main_menu


REM ============================================================
REM  3) Limpiar
REM ============================================================
:do_limpiar
cls
echo [Limpiar] Cuentas detectadas:
echo.
call :load_accounts

if "%ACCT_COUNT%"=="0" (
    echo.
    echo     No hay cuentas para procesar.
    echo.
    pause
    goto :main_menu
)

echo.
echo   a) Eliminar las que elija    (el resto se conserva)
echo   b) Conservar las que elija   (el resto se elimina)
echo   v) Volver
echo.
set "MODE="
set /p "MODE=Opcion: "
if /i "%MODE%"=="v" goto :main_menu
if /i not "%MODE%"=="a" if /i not "%MODE%"=="b" (
    set /a BAD+=1
    if !BAD! GTR 5 goto :salir
    echo.
    echo     Opcion invalida.
    timeout /t 1 >nul 2>&1
    goto :do_limpiar
)

echo.
set "SEL="
set /p "SEL=Numeros (ej: 1 3  o  1,3  o  * = todas): "
if not defined SEL (
    set /a BAD+=1
    if !BAD! GTR 5 goto :salir
    echo.
    echo     Nada seleccionado. No se toco nada.
    timeout /t 1 >nul 2>&1
    goto :do_limpiar
)

set "PICKED="
set "SELALL="
if not "%SEL%"=="%SEL:**=%" set "SELALL=1"
if defined SELALL (
    call :select_all
) else (
    for %%N in (%SEL%) do call :resolve_index "%%N"
)
call :build_targets

if not defined TARGETS (
    echo.
    echo     La seleccion no deja nada por hacer. No se toco nada.
    echo.
    pause
    goto :main_menu
)

echo.
echo ==================================================
echo   Se van a ELIMINAR:
for %%T in (%TARGETS%) do echo     - %%T
echo.
echo   Se CONSERVAN:
for %%A in (%ACCT_NAMES%) do call :show_if_kept "%%A"
echo ==================================================
echo.
set "OK="
set /p "OK=Confirmar? (S/N): "
if /i not "%OK%"=="S" (
    echo.
    echo     Cancelado. No se toco nada.
    echo.
    pause
    goto :main_menu
)

echo.
for %%T in (%TARGETS%) do call :delete_account "%%T"
echo.
echo     Estado final:
call :load_accounts
if "%ACCT_COUNT%"=="0" echo     (ninguna)
echo.
pause
goto :main_menu


REM ============================================================
REM  4) Otros
REM ============================================================
:do_otros
cls
echo [Otros]
echo.
echo   a) Reparar / actualizar tokens vencidos
echo   b) Ver ayuda (solucion manual)
echo   v) Volver
echo.
set "SUB="
set /p "SUB=Opcion: "
if /i "%SUB%"=="v" goto :main_menu
if /i "%SUB%"=="b" goto :show_help
if /i "%SUB%"=="a" goto :repair_tokens
set /a BAD+=1
if %BAD% GTR 5 goto :salir
echo.
echo     Opcion invalida.
timeout /t 1 >nul 2>&1
goto :do_otros

:repair_tokens
echo.
call :load_accounts
if "%ACCT_COUNT%"=="0" (
    echo.
    echo     No hay cuentas registradas.
    echo.
    pause
    goto :main_menu
)
echo.
echo     Validando...
set "BROKEN="
for %%A in (%ACCT_NAMES%) do call :check_token "%%A"
if not defined BROKEN (
    echo.
    echo     [OK] Todos los tokens son validos.
    echo.
    pause
    goto :main_menu
)
echo.
for %%U in (%BROKEN%) do call :update_token "%%U"
echo.
pause
goto :main_menu

:show_help
cls
echo [Ayuda] Solucion manual equivalente
echo.
echo   git config --global --unset-all credential.https://github.com.helper
echo   git config --global --unset-all credential.https://gist.github.com.helper
echo   git config --local  --unset-all credential.https://github.com.helper
echo   git config --local  --unset-all credential.https://gist.github.com.helper
echo   git config --global credential.helper manager
echo.
echo   Revocar tokens expuestos:
echo   https://github.com/settings/tokens
echo.
echo   Ver cuentas guardadas en Windows:
echo   cmdkey /list
echo.
pause
goto :main_menu


REM ============================================================
REM  Salida
REM ============================================================
:salir
endlocal
exit /b 0


REM ============================================================
REM  Subrutinas: deteccion de cuentas
REM ============================================================

:load_accounts
set "ACCT_COUNT=0"
set "ACCT_NAMES="
for /f "delims=" %%A in ('git credential-manager github list 2^>nul') do call :push_account "%%A"
goto :eof

:push_account
set "A=%~1"
if "%A%"=="" goto :eof
set /a ACCT_COUNT+=1
set "ACC_%ACCT_COUNT%=%A%"
set "ACCT_NAMES=%ACCT_NAMES% %A%"
echo     %ACCT_COUNT%) %A%
goto :eof


REM ============================================================
REM  Subrutinas: seleccion
REM ============================================================

:resolve_index
set "N=%~1"
if "%N%"=="" goto :eof
for /f "delims=0123456789" %%X in ("%N%") do (
    echo     [AVISO] No es un numero valido: %N%
    goto :eof
)
if not defined ACC_%N% (
    echo     [AVISO] Fuera de rango: %N%
    goto :eof
)
set "PICKED=%PICKED% !ACC_%N%!"
goto :eof

:select_all
for %%A in (%ACCT_NAMES%) do set "PICKED=!PICKED! %%A"
goto :eof

:is_picked
for %%P in (%PICKED%) do if /i "%%P"=="%~1" exit /b 0
exit /b 1

:is_target
for %%T in (%TARGETS%) do if /i "%%T"=="%~1" exit /b 0
exit /b 1

:build_targets
set "TARGETS="
if /i "%MODE%"=="a" (
    set "TARGETS=%PICKED%"
    goto :eof
)
for %%A in (%ACCT_NAMES%) do (
    call :is_picked "%%A"
    if errorlevel 1 set "TARGETS=!TARGETS! %%A"
)
goto :eof

:show_if_kept
call :is_target "%~1"
if errorlevel 1 echo     - %~1
goto :eof


REM ============================================================
REM  Subrutinas: borrado
REM ============================================================

:delete_account
set "UN=%~1"
if "%UN%"=="" goto :eof

git credential-manager github logout "%UN%" --no-ui >nul 2>&1
if errorlevel 1 (
    echo     [AVISO] GCM no pudo eliminar: %UN%
) else (
    echo     [BORRADA] %UN%
)

REM Via secundaria: protocolo credential reject (borra residuos)
set "TMPF=%TEMP%\ghc_rej_%RANDOM%.txt"
> "%TMPF%" echo protocol=https
>> "%TMPF%" echo host=%GH_HOST%
>> "%TMPF%" echo username=%UN%
>> "%TMPF%" echo.
git credential reject < "%TMPF%" >nul 2>&1
del "%TMPF%" >nul 2>&1
goto :eof


REM ============================================================
REM  Subrutinas: validacion de tokens
REM ============================================================

:validate_all
where curl.exe >nul 2>&1
if errorlevel 1 (
    echo     [AVISO] curl.exe no encontrado. Validacion omitida.
    goto :eof
)
if "%ACCT_COUNT%"=="0" goto :eof
for %%A in (%ACCT_NAMES%) do call :check_token "%%A"
goto :eof

:check_token
set "USER=%~1"
set "TOKEN="
set "HTTP_CODE="
set "GCM_INTERACTIVE=never"

set "TMPF=%TEMP%\ghc_read_%RANDOM%.txt"
> "%TMPF%" echo protocol=https
>> "%TMPF%" echo host=%GH_HOST%
>> "%TMPF%" echo username=%USER%
>> "%TMPF%" echo.
git credential fill < "%TMPF%" > "%TMPF%.out" 2>&1
del "%TMPF%" >nul 2>&1

for /f "tokens=1,* delims==" %%a in ('type "%TMPF%.out" 2^>nul') do (
    if /i "%%a"=="password" set "TOKEN=%%b"
)
del "%TMPF%.out" >nul 2>&1

if not defined TOKEN (
    echo     [SIN GUARDAR] %USER%
    set "BROKEN=%BROKEN% %USER%"
    goto :eof
)

set "CODEF=%TEMP%\ghc_code_%RANDOM%.code"
curl.exe -s -o nul -w "%%{http_code}" -H "Authorization: Bearer %TOKEN%" https://api.github.com/user > "%CODEF%" 2>nul
set /p HTTP_CODE= < "%CODEF%" 2>nul
del "%CODEF%" >nul 2>&1

if "%HTTP_CODE%"=="200" (
    echo     [OK] %USER%
    goto :eof
)
if "%HTTP_CODE%"=="" (
    echo     [NO VALIDADO] %USER% - sin respuesta de la API
    goto :eof
)
echo     [EXPIRADO] %USER% - codigo %HTTP_CODE%
set "BROKEN=%BROKEN% %USER%"
goto :eof


REM ============================================================
REM  Subrutinas: reparacion de tokens
REM ============================================================

:update_token
set "USER=%~1"
set "ATTEMPTS=0"

:update_retry
set /a ATTEMPTS+=1
if %ATTEMPTS% GTR 3 (
    echo     [FALLO] Maximo de intentos para %USER%. Saltando.
    goto :eof
)

echo.
set "NEWTTOK="
set /p "NEWTTOK=Pega el PAT nuevo para %USER% (vacio = cancelar): "
if not defined NEWTTOK (
    echo     Cancelado.
    goto :eof
)

echo %NEWTTOK% | findstr /B /R "ghp_ gho_ ghs_ github_pat_" >nul 2>&1
if errorlevel 1 (
    echo     [AVISO] No parece un PAT valido. Reintento %ATTEMPTS%/3.
    goto :update_retry
)

set "TMPF=%TEMP%\ghc_new_%RANDOM%.txt"
> "%TMPF%" echo protocol=https
>> "%TMPF%" echo host=%GH_HOST%
>> "%TMPF%" echo username=%USER%
>> "%TMPF%" echo password=%NEWTTOK%
>> "%TMPF%" echo.
type "%TMPF%" | git credential approve >nul 2>&1
set "APPROVE_RC=%errorlevel%"
del "%TMPF%" >nul 2>&1
if not "%APPROVE_RC%"=="0" (
    echo     [ERROR] Fallo al guardar en GCM.
    goto :update_retry
)

set "CODEF=%TEMP%\ghc_code_%RANDOM%.code"
curl.exe -s -o nul -w "%%{http_code}" -H "Authorization: Bearer %NEWTTOK%" https://api.github.com/user > "%CODEF%" 2>nul
set /p HTTP_CODE= < "%CODEF%" 2>nul
del "%CODEF%" >nul 2>&1

if "%HTTP_CODE%"=="200" (
    echo     [OK] %USER% actualizado.
    goto :eof
)
echo     [ERROR] Revalidacion fallo - codigo %HTTP_CODE%. Reintento %ATTEMPTS%/3.
goto :update_retry
