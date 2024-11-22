@echo off
title Manage Mullvad Devices
setlocal enabledelayedexpansion
mode con: cols=70 lines=15

set "DEVICE_COUNT=0"
set "MAX_DEVICES=3"
set "REVOKED_COUNT=0"

:: Initialize array for authorized devices
set "AUTHORIZED_DEVICES_COUNT=1"

:: Function to fetch account key with error handling
:FetchAccountKey
set "AUTHORIZED_KEY="
for /f "tokens=2 delims=: " %%A in ('mullvad account get 2^>nul ^| findstr /c:"Mullvad account: "') do (
    set "AUTHORIZED_KEY=%%A"
)

if not defined AUTHORIZED_KEY (
    echo Error: Could not fetch Mullvad account key.
    echo Attempting to re-login to Mullvad account...
    mullvad account logout
    timeout /t 2 /nobreak >nul
    mullvad account login
    timeout /t 5 /nobreak >nul
    goto FetchAccountKey
)

:: Function to fetch authorized device name with error handling
:FetchAuthorizedDevice
set "AUTHORIZED_DEVICE_1="
for /f "tokens=3* usebackq" %%A in (`mullvad account get 2^>nul ^| findstr /c:"Device name    :"`) do (
    set "AUTHORIZED_DEVICE_1=%%B"
)

if not defined AUTHORIZED_DEVICE_1 (
    echo Error: Could not fetch authorized device name.
    echo Attempting to re-login to Mullvad account...
    mullvad account logout
    timeout /t 2 /nobreak >nul
    mullvad account login
    timeout /t 5 /nobreak >nul
    goto FetchAuthorizedDevice
)

:PROMPT_EXTRA_DEVICE
cls
echo Current authorized device: !AUTHORIZED_DEVICE_1!
echo ----------------------------------------------------------------------
echo Would you like to add an extra authorized device? (Y/N)
choice /c YN /n
if errorlevel 2 goto LOOP
if errorlevel 1 (
    echo Enter the name of the device to authorize:
    set /p "AUTHORIZED_DEVICE_2="
    set /a "AUTHORIZED_DEVICES_COUNT=2"
    echo Added !AUTHORIZED_DEVICE_2! to authorized devices.
    timeout /t 2 /nobreak >nul
)

:LOOP
set "UNAUTHORIZED_COUNT=0"
set /a "DEVICE_COUNT=0"
set "NEEDS_UPDATE=0"

:: Function to list devices with account key verification
:ListDevices
set "DEVICE_LIST_ERROR=0"

:: Verify account key before listing devices
set "CURRENT_ACCOUNT_KEY="
for /f "tokens=2 delims=: " %%A in ('mullvad account get 2^>nul ^| findstr /c:"Mullvad account: "') do (
    set "CURRENT_ACCOUNT_KEY=%%A"
)

if not "!CURRENT_ACCOUNT_KEY!"=="%AUTHORIZED_KEY%" (
    echo [ALERT] Unauthorized account key detected.
    echo Relogging to authorized account...
    mullvad account logout
    mullvad account login %AUTHORIZED_KEY%
    timeout /t 1 /nobreak >nul
    mullvad connect
    
    :: Re-fetch the authorized device name after re-login
    set "AUTHORIZED_DEVICE_1="
    for /f "tokens=3* usebackq" %%A in (`mullvad account get 2^>nul ^| findstr /c:"Device name    :"`) do (
        set "AUTHORIZED_DEVICE_1=%%B"
    )
    
    if not defined AUTHORIZED_DEVICE_1 (
        echo Failed to fetch new device name. Retrying...
        goto ListDevices
    )
)

:: List devices
for /f "skip=1 tokens=* usebackq" %%A in (`mullvad account list-devices 2^>nul`) do (
    set "DEVICE=%%A"
    
    if not "!DEVICE!"=="" (
        set /a "DEVICE_COUNT+=1"
        
        set "IS_AUTHORIZED=0"
        :: Check against all authorized devices
        for /L %%i in (1,1,!AUTHORIZED_DEVICES_COUNT!) do (
            if /i "!DEVICE!"=="!AUTHORIZED_DEVICE_%%i!" (
                set "IS_AUTHORIZED=1"
            )
        )
        
        if !IS_AUTHORIZED! equ 0 (
            set /a "UNAUTHORIZED_COUNT+=1"
            set "UNAUTHORIZED_DEVICE_!UNAUTHORIZED_COUNT!=!DEVICE!"
            set "NEEDS_UPDATE=1"
        )
    )
)

:: Check if device listing failed
if !DEVICE_COUNT! equ 0 (
    echo Error: Could not list Mullvad devices.
    echo Attempting to re-login to Mullvad account...
    mullvad account logout
    timeout /t 2 /nobreak >nul
    mullvad account login
    timeout /t 5 /nobreak >nul
    goto ListDevices
)

:: Generate random index for next device to revoke
if !UNAUTHORIZED_COUNT! gtr 0 (
    set /a "NEXT_TO_REVOKE=(!RANDOM! %% !UNAUTHORIZED_COUNT!) + 1"
)

if !DEVICE_COUNT! gtr %MAX_DEVICES% (
    if !UNAUTHORIZED_COUNT! gtr 0 (
        cls
        echo Authorized devices:
        for /L %%i in (1,1,!AUTHORIZED_DEVICES_COUNT!) do (
            echo   !AUTHORIZED_DEVICE_%%i!
        )
        echo ----------------------------------------------------------------------
        echo [ALERT] More than %MAX_DEVICES% devices connected.
        echo Revoking device: [!UNAUTHORIZED_DEVICE_%NEXT_TO_REVOKE%!]
        mullvad account revoke-device "!UNAUTHORIZED_DEVICE_%NEXT_TO_REVOKE%!"
        set /a "REVOKED_COUNT+=1"
        echo Device revoked successfully.
        timeout /t 3 /nobreak >nul
    )
)

cls
echo Authorized devices:
for /L %%i in (1,1,!AUTHORIZED_DEVICES_COUNT!) do (
    echo   !AUTHORIZED_DEVICE_%%i!
)
echo ----------------------------------------------------------------------
echo Unauthorized devices (!UNAUTHORIZED_COUNT! found):
if !UNAUTHORIZED_COUNT! gtr 0 (
    for /L %%i in (1,1,!UNAUTHORIZED_COUNT!) do (
        echo   [!UNAUTHORIZED_DEVICE_%%i!]
    )
    echo ----------------------------------------------------------------------
    echo Next to be revoked: [!UNAUTHORIZED_DEVICE_%NEXT_TO_REVOKE%!]
) else (
    echo   None detected
    echo Next to be revoked: None
)

timeout /t 1 /nobreak >nul

goto LOOP
