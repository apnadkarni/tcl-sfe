@echo off
setlocal
if "x%VSCMD_ARG_TGT_ARCH%" == "x" echo ERROR: VSCMD_ARG_TGT_ARCH not set. Run from a VS prompt. && exit /b 1
md dist
echo Building barebones SFE
call sfebuild -tcldir %1 -pkgs thread || echo ERROR: could not build barebones SFE && goto :eof
move /Y staging\tclsfe-%VSCMD_ARG_TGT_ARCH%.exe dist\tclsfe-bb-%VSCMD_ARG_TGT_ARCH%.exe || echo Could not copy tclsfe-bb && exit /b 1
move /Y staging\tksfe-%VSCMD_ARG_TGT_ARCH%.exe dist\tksfe-bb-%VSCMD_ARG_TGT_ARCH%.exe || echo Could not copy tclsfe-bb && exit /b 1

echo Building twapi SFE
call sfebuild -tcldir %1 -pkgs "thread twapi" || echo ERROR: could not build twapi SFE && goto :eof
move /Y staging\tclsfe-%VSCMD_ARG_TGT_ARCH%.exe dist\tclsfe-twapi-%VSCMD_ARG_TGT_ARCH%.exe || echo Could not copy tclsfe-bb && exit /b 1
move /Y staging\tksfe-%VSCMD_ARG_TGT_ARCH%.exe dist\tksfe-twapi-%VSCMD_ARG_TGT_ARCH%.exe || echo Could not copy tclsfe-bb && exit /b 1

echo Building full SFE
call sfebuild -tcldir %1 || echo ERROR: could not build full SFE && goto :eof
move /Y staging\tclsfe-%VSCMD_ARG_TGT_ARCH%.exe dist\tclsfe-%VSCMD_ARG_TGT_ARCH%.exe || echo Could not copy tclsfe-bb && exit /b 1
move /Y staging\tksfe-%VSCMD_ARG_TGT_ARCH%.exe dist\tksfe-%VSCMD_ARG_TGT_ARCH%.exe || echo Could not copy tclsfe-bb && exit /b 1
