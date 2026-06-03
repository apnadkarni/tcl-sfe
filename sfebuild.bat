@echo off
setlocal enabledelayedexpansion

IF DEFINED VCINSTALLDIR goto setup
echo "Not in a Visual Studio command prompt."
exit /B 1

:setup

:: Set up default values
set TCLDIR=tcl
set STAGINGDIR=staging

:parse_args
if "%~1"=="" goto build

if "%~1"=="-tcldir" (
    set "TCLDIR=%~2"
    shift
) else if "%~1"=="-tkdir" (
    set "TKDIR=%~2"
    shift
) else if "%~1"=="-pkgsdir" (
    set "PKGSDIR=%~2"
    shift
) else if "%~1"=="-stagingdir" (
    set "STAGINGDIR=%~2"
    shift
) else (
    echo Unknown option: %~1
    goto usage
)
shift
goto parse_args

:build
call :fqn !STAGINGDIR! STAGINGDIR
mkdir !STAGINGDIR!
set STAGINGVFS=!STAGINGDIR!\vfs
mkdir !STAGINGVFS!
:: mkdir may fail if the path was a file. Check it's a directory.
call :ensure_dir !STAGINGDIR! || goto :eof

:build_tcl
call :progress Building Tcl
call :fqn !TCLDIR! TCLDIR
call :ensure_dir !TCLDIR!\win || goto :eof
pushd !TCLDIR!\win
nmake /f makefile.vc /s /nologo OPTS=static,pdbs INSTALLDIR=!STAGINGDIR! shell install || goto :eof
popd

:build_tk
call :progress Building Tk
if "!TKDIR!" == "" set TKDIR=!TCLDIR!\..\tk
call :fqn !TKDIR! TKDIR
call :ensure_dir !TKDIR!\win || goto :eof
pushd !TKDIR!\win
nmake /f makefile.vc /s /nologo OPTS=static,pdbs INSTALLDIR=!STAGINGDIR! release install || goto :eof
popd

:build_pkgs
if "!PKGSDIR!" == "" set PKGSDIR=!TCLDIR!\pkgs
call :fqn !PKGSDIR! PKGSDIR
call :ensure_dir !PKGSDIR! || goto :eof
echo TCLSFE_DEFINES= > !STAGINGDIR!\tclsfe_nmake.inc
echo TCLSFE_LIBS= >> !STAGINGDIR!\tclsfe_nmake.inc

:build_sqlite
call :build_pkg sqlite SQLITEDIR || goto :eof

:build_thread
call :build_pkg thread THREADDIR || goto :eof
echo THREADDIR=!THREADDIR!
mkdir !STAGINGVFS!\!THREADDIR!
copy /y !STAGINGDIR!\lib\!THREADDIR!\*.tcl !STAGINGVFS!\!THREADDIR!

:: :build_twapi
:: call :build_pkg twapi TWAPIDIR || goto :eof
:: ::echo TWAPIDIR=!TWAPIDIR!
:: ::mkdir !STAGINGVFS!\!TWAPIDIR!
:: ::copy /y !STAGINGDIR!\lib\!TWAPIDIR!\*.tcl !STAGINGVFS!\!TWAPIDIR!
:: exit /b 0

:build_bi
pwd
pushd win
nmake /f makefile.vc TCLDIR="!TCLDIR!" OPTS=static,pdbs,nostubs
popd

:: End of script
exit /b 0


:build_pkg
set PKGSUBDIR=
for /d %%D in (!PKGSDIR!\%1*) do set PKGSUBDIR=%%~nxD
if "!PKGSUBDIR!" == "" goto :eof
echo Building %1 !PKGSUBDIR!
set "%~2=!PKGSUBDIR!"
pushd !PKGSDIR!\!PKGSUBDIR!\win
nmake /f makefile.vc TCLDIR="!TCLDIR!" OPTS=static,pdbs INSTALLDIR=!STAGINGDIR! || goto :eof
nmake /f makefile.vc TCLDIR="!TCLDIR!" OPTS=static,pdbs INSTALLDIR=!STAGINGDIR! install || goto :eof
echo TCLSFE_DEFINES = $(TCLSFE_DEFINES) -DTCLSFE_HAVE_%1 >> !STAGINGDIR!\tclsfe_nmake.inc
echo %1_SUBDIR = !PKGSUBDIR! >> !STAGINGDIR!\tclsfe_nmake.inc
::cd !STAGINGDIR!\!PKGSUBDIR!
echo %1_LIBNAME = tcl9$(%1_SUBDIR:.=)s.lib >> !STAGINGDIR!\tclsfe_nmake.inc
echo TCLSFE_LIBS = $(TCLSFE_LIBS) !STAGINGDIR!\lib\!PKGSUBDIR!\$(%1_LIBNAME) >> !STAGINGDIR!\tclsfe_nmake.inc
popd
goto :eof

:fqn
:: Fully qualifies the path in %1 and sets %2 to the qualified path.
set "%~2=%~f1"
exit /b 0

:ensure_dir
:: Ensures the passed path is a directory, otherwise print error
:: and return error code 1
if not exist "%1\" (
echo Error: not a directory: %1
exit /b 1
)
exit /b 0

:progress
echo %*
goto :eof

:usage
echo.
echo Usage: %0 [-tcldir TCLDIR] -tkdir TKDIR -pkgsdir PKGSDIR
echo.
echo TCLDIR defaults to .\tcl
echo TKDIR defaults to TCLDIR\..\tk
echo PKGSDIR defaults to TCLDIR\pkgs
exit /b 1
