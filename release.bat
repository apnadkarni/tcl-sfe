echo off
md dist
echo Building barebones SFE
call sfebuild -tcldir %1 -pkgs thread || echo ERROR: could not build barebones SFE && goto :eof
move /Y staging\tclsfe.exe dist\tclsfe-bb.exe
move /Y staging\tksfe.exe dist\tksfe-bb.exe

echo Building twapi SFE
call sfebuild -tcldir %1 -pkgs "thread twapi" || echo ERROR: could not build twapi SFE && goto :eof
move /Y staging\tclsfe.exe dist\tclsfe-twapi.exe
move /Y staging\tksfe.exe dist\tksfe-twapi.exe

echo Building full SFE
call sfebuild -tcldir %1 || echo ERROR: could not build full SFE && goto :eof
move /Y staging\tclsfe.exe dist\tclsfe.exe
move /Y staging\tksfe.exe dist\tksfe.exe
