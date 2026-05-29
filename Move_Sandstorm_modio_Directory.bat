@echo off
setlocal enabledelayedexpansion
title Move Sandstorm mod.io Directory

:: Make sure globalsettings.json exists

:: Define path to mod.io globalsettings.json

set "JSON_FILE=%LOCALAPPDATA%\mod.io\globalsettings.json"

:: Check if the file exists
if not exist "%JSON_FILE%" (
    echo Error: File not found at "%JSON_FILE%"
    pause
    exit /b
)

:: Extract RootLocalStoragePath using PowerShell and set it to a Batch variable

for /f "delims=" %%i in ('powershell -NoProfile -Command "(Get-Content '%JSON_FILE%' | ConvertFrom-Json).RootLocalStoragePath"') do (
    set "RootLocalStoragePath=%%i"
)

echo.

:: Display the result

if defined RootLocalStoragePath (
    echo The RootLocalStoragePath is: %RootLocalStoragePath%
) else (
    echo Error: Could not find RootLocalStoragePath in the JSON file.
    pause
    exit /b
)

echo.

:: Change / in directory path to Windows \

set "source_dir=!RootLocalStoragePath:/=\!"

:: Select Destination Folder using Windows GUI selector

echo Selecting destination folder...
set "dest_cmd=(New-Object -ComObject Shell.Application).BrowseForFolder(0, 'Select the DESTINATION folder', 0, 0).Self.Path"
for /f "usebackq delims=" %%I in (`powershell -Command "%dest_cmd%"`) do set "dest_dir=%%I"

if not defined dest_dir (
    echo No destination folder selected. Exiting.
    pause
    exit /b
)

:: Clean up destination Directory path

set "dest_dir=%dest_dir%\mod.io\"
set "dest_dir=%dest_dir:\\=\%"

:: Show Disclaimer then Confirm Moving of Files to new location

echo.
echo Source:      %source_dir%
echo Destination: %dest_dir%
echo.
echo This script will also move mod files for every game that uses 'RootLocalStoragePath'
echo in the globalsettings.json file for mod.io. The script will update the metadata
echo only for Sandstorm.  If any other games use metadata that points to the old location
echo it will not be updated.  If Sandstorm is the only game you have installed that uses
echo Mod.io then go ahead and use this script.  Any game that is installed after the mods
echo have been moved will use the new location for their mods.
echo.

set /p "confirm=Are you sure you want to move all files? (Y/N): "

if /i "%confirm%"=="Y" (
    echo.
    echo Moving files...  robocopy "%source_dir%" "%dest_dir%" /E /MOVE
    robocopy %source_dir% %dest_dir% /E /MOVE
    echo.
) else (
    echo Operation cancelled.
    pause
    exit /b
)

:: Convert Destination Path to format used by mod.io
:: Note: mod.io prefers forward slashes in its paths

set "NEW_PATH=!dest_dir:\=/!"

:: Create a temporary file to rewrite the JSON

set "TEMP_FILE=%TEMP%\globalsettings_temp.json"
echo { > "%TEMP_FILE%"

echo "RootLocalStoragePath": "%NEW_PATH%" >> "%TEMP_FILE%"
echo } >> "%TEMP_FILE%"

:: Overwrite the original file with the new configuration

move /y "%TEMP_FILE%" "%JSON_FILE%" >nul

echo [SUCCESS] Mod storage path updated to %NEW_PATH%

:: Set variables for changing all path locations in the
:: 254\metadata\state.json file to point to the new location
:: If this file is not updated after moving it will still point
:: to the previous locations

set "filepath=%dest_dir%254\metadata\state.json"
set "search=%source_dir%254\mods\"
set "replace=%dest_dir%254\mods\"

:: Convert single \ to Double \\ used by the mod.io state.json file

set "search=%search:\=\\%"
set "replace=%replace:\=\\%"

echo.
echo Replacing %search%
echo With %replace%
echo Inside %filepath%
echo.

:: Perform update on state.json using Powershell

powershell -Command " (Get-Content -Path '%filepath%') -replace [regex]::Escape('%search%'), '%replace%' | Set-Content -Path '%filepath%' "

echo Metadata update inside %filepath% complete!
echo.
echo Moving/Updating Sandstorm mod.io files is complete.
echo.

pause