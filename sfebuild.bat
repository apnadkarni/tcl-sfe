:: sfebuild -help for usage.
@echo off
setlocal enabledelayedexpansion

if "%CD%\" == "%~dp0" goto check_vc
echo Please run this batch file from the %~dp0 directory.
exit /b 1

:check_vc
:: Need to be running within a Visual Studio prompt
IF DEFINED VCINSTALLDIR goto setup
echo "Not in a Visual Studio command prompt."
exit /B 1

:setup
:: Set up default values
set SFETCLROOT=tcl
set STAGINGDIR=staging
set NMAKE_OPTS=/s /nologo
set PKGS=all

:parse_args
:: Parse options

if "%~1"=="" goto build

if "%~1"=="-tcldir" (
    set "SFETCLROOT=%~2"
    shift
) else if "%~1"=="-tkdir" (
    set "SFETKROOT=%~2"
    shift
) else if "%~1"=="-pkgsdir" (
    set "PKGSDIR=%~2"
    shift
) else if "%~1"=="-stagingdir" (
    set "STAGINGDIR=%~2"
    shift
) else if "%~1"=="-pkgs" (
    set "PKGS=%~2"
    shift
) else if "%~1"=="-verbose" (
    set "NMAKE_OPTS=/nologo"
    echo on
    shift
) else if "%~1"=="-help" (
    goto usage
) else (
    echo Unknown option: %~1
    goto usage
)
shift
goto parse_args

:build
call :fqn !STAGINGDIR! STAGINGDIR
:: mkdir may fail if the path was a file. Check it's a directory.
call :make_dir !STAGINGDIR! || goto :eof
call :ensure_dir !STAGINGDIR! || goto :eof
set STAGINGVFS=!STAGINGDIR!\sfe.vfs
call :empty_dir !STAGINGVFS! || goto :eof
set STAGINGLIB=!STAGINGDIR!\lib
call :make_dir !STAGINGLIB! || goto :eof
call :ensure_dir !STAGINGLIB! || goto :eof

call :fqn !SFETCLROOT! SFETCLROOT
if "!SFETKROOT!" == "" set SFETKROOT=!SFETCLROOT!\..\tk
call :fqn !SFETKROOT! SFETKROOT
if "!PKGSDIR!" == "" set PKGSDIR=!SFETCLROOT!\pkgs
call :fqn !PKGSDIR! PKGSDIR

:build_tcl
call :progress Building Tcl
call :fqn !SFETCLROOT! SFETCLROOT
call :ensure_dir !SFETCLROOT!\win || echo ERROR: Tcl not found. && goto :usage
pushd !SFETCLROOT!\win
nmake %NMAKE_OPTS% /f makefile.vc OPTS=static INSTALLDIR=!STAGINGDIR! shell install-binaries install-libraries || goto :eof
popd

:build_tk
call :progress Building Tk
call :ensure_dir !SFETKROOT!\win || goto :eof
pushd !SFETKROOT!\win
nmake %NMAKE_OPTS% /f makefile.vc OPTS=static INSTALLDIR=!STAGINGDIR! release install || goto :eof
popd

:build_pkgs
call :ensure_dir !PKGSDIR! || goto :eof
echo TCLSFE_DEFINES= > !STAGINGDIR!\tclsfe_nmake.inc
echo TCLSFE_LIBS= >> !STAGINGDIR!\tclsfe_nmake.inc

:build_sqlite
call :pkg_enabled sqlite || goto build_thread
call :build_pkg sqlite SQLITEDIR || goto :eof
call :write_pkgindex sqlite3 !SQLITEDIR! !SQLITEDIR:~6! Sqlite3

:build_thread
call :pkg_enabled thread || goto build_tdbc
call :build_pkg thread THREADDIR || goto :eof
call :make_dir !STAGINGVFS!\!THREADDIR! || goto :eof
copy /y !STAGINGLIB!\!THREADDIR!\*.tcl !STAGINGVFS!\!THREADDIR! || goto :eof
call :write_pkgindex thread !THREADDIR! !THREADDIR:~6! Thread

:build_tdbc
call :pkg_enabled tdbc || goto build_twapi
call :build_pkg tdbc TDBCDIR || goto :eof
call :write_pkgindex tdbc !TDBCDIR! !TDBCDIR:~4! Tdbc

:build_twapi
call :pkg_enabled twapi || goto build_bi
call :build_pkg twapi TWAPIDIR || goto :eof
echo TCLSFE_DEFINES = $(TCLSFE_DEFINES) -DTWAPI_STATIC_BUILD >> !STAGINGDIR!\tclsfe_nmake.inc || goto :eof
call :add_libs advapi32.lib cfgmgr32.lib credui.lib crypt32.lib || goto :eof
call :add_libs gdi32.lib iphlpapi.lib kernel32.lib mpr.lib || goto :eof
call :add_libs netapi32.lib ole32.lib oleaut32.lib pdh.lib || goto :eof
call :add_libs powrprof.lib psapi.lib rpcrt4.lib || goto :eof
call :add_libs secur32.lib setupapi.lib shell32.lib || goto :eof
call :add_libs shlwapi.lib user32.lib userenv.lib || goto :eof
call :add_libs uxtheme.lib version.lib winmm.lib || goto :eof
call :add_libs winspool.lib wintrust.lib ws2_32.lib  || goto :eof
call :add_libs wtsapi32.lib || goto :eof
call :add_libs !STAGINGLIB!\libdyncall_s.lib !STAGINGLIB!\libdynload_s.lib !STAGINGLIB!\libdyncallback_s.lib
call :make_dir !STAGINGVFS!\!TWAPIDIR! || goto :eof
copy /y !STAGINGLIB!\!TWAPIDIR!\*.tcl !STAGINGVFS!\!TWAPIDIR! > nul: || goto :eof

:build_bi
pwd
pushd win
nmake %NMAKE_OPTS% /f makefile.vc TCLDIR="!SFETCLROOT!" TKDIR="!SFETKROOT!" OPTS=static,nostubs || goto :eof
popd

:: End of script
exit /b 0

:pkg_enabled
:: Returns 0 if %PKGS% contains "all" or %1 and 1 otherwise
for %%f in (%PKGS%) do (
    if "%%f" == "all" exit /b 0
    if "%%f" == "%1" exit /b 0
)
exit /b 1

:build_pkg
:: Builds a single package
:: %1 is package prefix
:: %2 is env var to set with directory name
set PKGSUBDIR=%3
call :find_pkg_dir %1 PKGSUBDIR || goto :eof
if "!PKGSUBDIR!" == "" goto :eof
call :progress Building %1 !PKGSUBDIR!
set "%~2=!PKGSUBDIR!"
pushd !PKGSDIR!\!PKGSUBDIR!\win
nmake %NMAKE_OPTS% /f makefile.vc OPTS=static INSTALLDIR=!STAGINGDIR! || goto :eof
nmake %NMAKE_OPTS% /f makefile.vc OPTS=static INSTALLDIR=!STAGINGDIR! install || goto :eof
echo TCLSFE_DEFINES = $(TCLSFE_DEFINES) -DTCLSFE_HAVE_%1 >> !STAGINGDIR!\tclsfe_nmake.inc || goto :eof
echo %1_SUBDIR = !PKGSUBDIR! >> !STAGINGDIR!\tclsfe_nmake.inc || goto :eof
::cd !STAGINGDIR!\!PKGSUBDIR! || goto :eof
echo %1_LIBNAME = tcl9$(%1_SUBDIR:.=)s.lib >> !STAGINGDIR!\tclsfe_nmake.inc || goto :eof
call :add_libs !STAGINGLIB!\$(%1_LIBNAME) || goto :eof
popd
goto :eof

:write_pkgindex
:: Generates the pkgIndex.tcl file for a static library
:: %1 is the package name
:: %2 is the package directory
:: %3 is the package version number
:: %4 is the initialization prefix
call :make_dir !STAGINGVFS!\%2 || goto :eof
:: Note we append to the file in case other packages are present
echo package ifneeded %1 %3 {load {} %4} >> !STAGINGVFS!\%2\pkgIndex.tcl || goto :eof
exit /b 0

:fqn
:: Fully qualifies the path in %1 and sets %2 to the qualified path.
set "%~2=%~f1"
exit /b 0


:find_pkg_dir
:: Find a package directory by prefix, matching only where the match
:: is for the entire prefix or the character after the prefix is a digit (version)
:: %1 - prefix to search for
:: %2 - variable to set to the found directory name
if exist "%~1\" (
    set "%~2=%~1"
    exit /b 0
)
set "SUBDIR="
for /d %%D in (!PKGSDIR!\%1*) do (
    set "CANDIDATE=%%~nxD"
    set "SUFFIX=!CANDIDATE:%1=!"
    echo !SUFFIX! | findstr /r "^[0-9]" >nul && (
        if defined SUBDIR (
            echo Error: multiple directories match prefix: %1
            exit /b 2
        )
        set "SUBDIR=%%~nxD"
    )
)
if "!SUBDIR!"=="" (
echo Error: no directory found for prefix: %1
exit /b 1
)
set "%~2=%SUBDIR%"
exit /b 0

:ensure_dir
:: Ensures the passed path is a directory, otherwise print error
:: and return error code 1
if not exist "%1\" (
    echo Error: not a directory: %1
    exit /b 1
)
exit /b 0

:empty_dir
:: Ensures %1 is an empty directory, creating if necessary
if exist "%1" (
   call :ensure_dir %1 || goto :eof
)
rd /s /q %1 >NUL
md %1
exit /b 0

:progress
echo %*
goto :eof

:make_dir
:: Just to avoid error message if directory already exists
if not exist "%~1" mkdir "%~1" || goto :eof
goto :eof

:add_libs
:: Add libraries for linking
echo>>!STAGINGDIR!\tclsfe_nmake.inc TCLSFE_LIBS = $(TCLSFE_LIBS) %* || goto :eof
goto :eof

:usage
echo Usage:
echo     %0 [-tcldir TCLDIR] [-tkdir TKDIR] [-pkgsdir PKGSDIR] [-pkgs PKGS]
echo     %0 -help
echo where
echo     TCLDIR  Tcl source directory (default .\tcl)
echo     TKDIR   Tk source directory (default TCLDIR\..\tk)
echo     PKGSDIR Directory containing packages (default TCLDIR\pkgs)
echo     PKGS    List of one or more of the supported packages to include
echo             or "all" (default). The directory for each package should
echo             be the name of the package followed by an optional version
echo             (similar to the pkgs directory in the Tcl distribution)
exit /b 1
