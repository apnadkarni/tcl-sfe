# Build system for single-file Tcl executables

The `tcl-sfe` build system creates single file Windows executables for Tcl/Tk
9.1, or later, that are fully statically linked and include optional extensions.
Because they are linked statically, they avoid issues arising from writing
shared libraries to disk.

The system is based on Tcl's nmake-based build environment. Autoconf based
builds are not implemented even on Windows.

The following optional extensions are available. See later for instructions on
adding your own.

- thread
- sqlite3
- tdbc::odbc
- twapi

## Build instructions

Running `sfebuild.bat` in the top level directory will create `tclsfe.exe`
and `tksfe.exe` under the release subdirectories of the `win` directory.
The `-help` option will print instructions.

```
c:\src\tcl-sfe>sfebuild -help
Usage:
    sfebuild [-tcldir TCLDIR] [-tkdir TKDIR] [-pkgsdir PKGSDIR] [-pkgs PKGS]
    sfebuild -help
where
    TCLDIR  Tcl source directory (default .\tcl)
    TKDIR   Tk source directory (default TCLDIR\..\tk)
    PKGSDIR Directory containing packages (default TCLDIR\pkgs)
    PKGS    List of one or more of the supported packages to include
            or "all" (default). The directory for each package should
            be the name of the package followed by an optional version
            (similar to the pkgs directory in the Tcl distribution).
Supported packages: sqlite3, thread, tdbc and twapi. The tdbc package
only includes tdbc::odbc.
```

For example, assuming other directories are in their default location relative
to Tcl,

```
c:\src\tcl-sfe>sfebuild -tcldir c:\src\tcltk\91b0\tcl
```

## Adding new extensions

To add an extension, the following changes are required.

Edit `sfebuild.bat` to add your extension. Use one of the existing entries
as a template. Pay particular extension as to whether a `pkgIndex.tcl` file
needs to be generated. Some extensions do not have `pkgIndex.tcl` files
that support static libraries. For simple cases, calling `write_pkgIndex`
will suffice.

Modify the `TclPostInit` function to add code to initialize the extension.
For example, the entry for the `twapi` package looks like

```
#ifdef TCLSFE_HAVE_twapi
    extern int Twapi_Init(Tcl_Interp * interp);
    Tcl_StaticLibrary(NULL, "Twapi", Twapi_Init, NULL);
#endif
```

*Note: correct case is important!*


