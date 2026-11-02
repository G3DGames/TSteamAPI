@echo off
rem PasDoc API reference of the TSteamAPI library - four runs:
rem   docs\html\delphi  HTML       FMX + VCL + lib (Delphi view)
rem   docs\html\fpc     HTML       LCL + lib (Free Pascal / Lazarus view)
rem   docs\chm\delphi   HTML Help  as docs\html\delphi, compiled to a .chm
rem   docs\chm\fpc      HTML Help  as docs\html\fpc, compiled to a .chm
rem
rem Needs pasdoc on the PATH (or set PASDOC=full path). The .chm files need
rem Microsoft HTML Help Workshop's hhc.exe (set HHC=full path if it is not
rem in the default folder); without it the HTML Help projects are written
rem but not compiled. Run from anywhere; the output folders are git-ignored.
rem The four output folders are deleted first (only those: the rest of docs\
rem is never touched), so no page of an earlier run is left behind.
rem
rem Defines: PasDoc defines no platform symbols itself, so the Win64 view is
rem chosen here. The Delphi runs leave FPC undefined (Steamworks.inc then
rem takes its Delphi branch: anonymous-method / generic overloads included);
rem the FPC runs define FPC (FPC 3.2.2 view: those overloads left out -
rem Steamworks.inc skips its FPC_FULLVERSION test when PASDOC is defined).
rem The framework .Reg units are design-time registration, not API.

setlocal
cd /d "%~dp0.."

if "%PASDOC%"=="" set PASDOC=pasdoc
rem pasdoc installed? (a full path in PASDOC, or a program on the PATH)
set FOUND=0
if exist "%PASDOC%" set FOUND=1
if %FOUND%==0 where "%PASDOC%" >nul 2>&1 && set FOUND=1
if %FOUND%==0 (
  echo pasdoc was not found ^(looked for: %PASDOC%^).
  echo Install it from https://github.com/pasdoc/pasdoc/releases/
  echo ^(download the archive for Windows, unpack it and put its bin folder on the PATH,
  echo or set PASDOC=full path of pasdoc.exe before running this script^)
  endlocal & exit /b 1
)
if "%HHC%"=="" set HHC=%ProgramFiles(x86)%\HTML Help Workshop\hhc.exe

set COMMON=--define PASDOC --include lib --visible-members protected,public,published,automated --inherited-members default-hide --write-uses-list --verbosity 3
set LIBSRC=lib\*.pas lib\plugins\*.pas
set DELPHI=--define MSWINDOWS --define CPUX64 --name TSteamAPI --title "TSteamAPI - Steamworks SDK 1.65 for Delphi (FMX, VCL)" fmx\Steamworks.FMX.pas vcl\Steamworks.VCL.pas %LIBSRC%
set FPCSRC=--define FPC --define MSWINDOWS --define CPU64 --define CPUX86_64 --name TSteamAPI --title "TSteamAPI - Steamworks SDK 1.65 for Free Pascal / Lazarus (LCL)" lcl\Steamworks.LCL.pas %LIBSRC%

set FAILED=0
echo ==== Cleaning the output folders
call :clean docs\html\delphi
call :clean docs\html\fpc
call :clean docs\chm\delphi
call :clean docs\chm\fpc
call :run html delphi docs\html\delphi %DELPHI%
call :run html fpc docs\html\fpc %FPCSRC%
call :run htmlhelp delphi docs\chm\delphi %DELPHI%
call :run htmlhelp fpc docs\chm\fpc %FPCSRC%
call :chm docs\chm\delphi
call :chm docs\chm\fpc

echo.
if %FAILED%==0 (echo PasDoc: all four runs finished) else (echo PasDoc: %FAILED% step^(s^) FAILED - see above)
endlocal & exit /b %FAILED%

rem ---- :clean <folder> - deletes one output folder with everything in it
:clean
if not exist "%~1\" (
  echo      %1: not there yet
  exit /b 0
)
rmdir /s /q "%~1"
if exist "%~1\" (
  echo      %1: could NOT be deleted completely - is a file in it open ^(browser, .chm viewer^)?
  set /a FAILED+=1
) else (
  echo      %1: deleted
)
exit /b 0

rem ---- :run <format> <label> <output folder> <defines, title and sources...>
:run
set FMT=%1
set LABEL=%2
set OUT=%3
shift & shift & shift
set ARGS=
:collect
if "%~1"=="" goto collected
set ARGS=%ARGS% %1
shift
goto collect
:collected
echo.
echo ==== PasDoc %FMT% (%LABEL%) -^> %OUT%
if not exist "%OUT%" mkdir "%OUT%"
"%PASDOC%" --format %FMT% --output %OUT% %COMMON% %ARGS%
if errorlevel 1 (echo ==== PasDoc %FMT% %LABEL% FAILED & set /a FAILED+=1)
exit /b 0

rem ---- :chm <folder> - compiles the HTML Help project PasDoc wrote there
:chm
if not exist "%HHC%" (
  echo ==== %1: hhc.exe not found at "%HHC%" - .hhp written, .chm not compiled
  exit /b 0
)
for %%F in ("%~1\*.hhp") do (
  echo ==== Compiling %%F
  "%HHC%" "%%F"
  rem hhc.exe exits with 1 on SUCCESS and 0 on failure
  if not errorlevel 1 (echo ==== %%F: .chm NOT compiled & set /a FAILED+=1)
)
exit /b 0
