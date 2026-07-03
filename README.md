# Single-file Tcl executables

This repository hosts single file Tcl/Tk executables for Windows and a build
system to create and customize them. These are completely statically linked
(other than the C and Windows runtimes) and therefore avoid issues that arise
from similar single file executables that write shared libraries to disk.

The `tclsfe.exe` and `tksfe.exe` programs are enhanced versions of `tclsh.exe`
and `wish.exe` that include the following extensions by default:

- thread
- sqlite3
- tdbc::odbc
- twapi

The build system allows omission of any of these if smaller executables are
desired. Further, SFE's can be customized by

- adding additional packages or Tcl modules

- addition of a main script that implements a complete application

- adding statically linked extensions

## Running SFE executables

SFE programs are self-contained. They can be copied anywhere and run without any
installation or unpackaging step. In other respects, unless **customized*, they
are identical to their standard counterparts including handling of command line
arguments, reading of the `tclshrc.tcl` and `wishrc.tcl` files at startup etc.
with one difference: the default paths set up for searching packages via
`auto_path` and for Tcl modules via `tcl::tm::path` is limited to the SFE
internal file system. This is to avoid interference from external sources.
If desired, the values can be changed from within your own scripts.

## Adding a package or module

Both `tclsfe` and `tksfe` include a built-in package `sfe` that makes it easy
to create new SFE's that include additional packages. The easiest way is via
the `sfe::make` command which will create a new SFE that includes the specified
packages and files in addition to the existing ones.

```
package require sfe
sfe::make NEWSFEPATH ?PATH ...? 
```

`NEWFSEPPATH` is the executable to create. Each `PATH` may be a directory or a
file. If a directory, it is assumed to be a package and copied to an appropriate
location in `auto_path` in the new SFE. If it is a file ending in `.tm` indicating
a Tcl module, it is copied to an appropriate location in the Tcl module search
path within the new SFE. Other files are copied to the top level of new SFE's
contained virtual file system.

For example, the following will create a SFE `sfemondo.exe` that includes
all packages in the `tcllib` and `tklib` distributions.

```
:\src\tcl-sfe>tclsfe
% package require sfe
0.1
% sfe::make sfemondo.exe c:/tcl/magic/lib/tcllib c:/tcl/magic/lib/tklib0.9
```

Note the package directories must be in their installed form, not the source
repositories (unless they have the same structure). Further, the new SFE is
always based on the one in which the commands are run so for a `wish` equivalent
that the `sfe::make` must be run in `tksfe.exe`, not `tclsfe.exe`.

Packages with DLL components may added in exactly the same manner as described
above. However, in this case the included DLL components will be written to
disk at runtime when the package is loaded. To avoid this, you may compile and
build your own modified SFE with the extension statically linked as described
below in **Adding static extensions**.

## Building a custom application

By default, the SFE's behave like the standard `tclsh` or `wish` shells.
You can make a custom SFE that implements a different behavior by adding a
`main.tcl` file. For example, here is an application that `hello` that
does the obvious.

```
c:\src\tcl-sfe>tclsfe
% package require sfe
0.1
% writeFile main.tcl "puts {Hello world!}"
% sfe::make hello.exe main.tcl
% exit

c:\src\tcl-sfe>hello
Hello world!
```

## The SFE build system

This section describes how to build `tclsfe` and `tksfe` with optional
customization.

The system is based on Tcl's nmake-based build environment. Autoconf based
builds are not implemented even on Windows.

Running `sfebuild.bat` in the top level directory will create `tclsfe.exe`
and `tksfe.exe` under the release subdirectories of the `win` directory.
The `-help` option prints instructions.

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

For example,

```
c:\src\tcl-sfe>sfebuild -tcldir c:\src\tcltk\91b0\tcl
```

This assumes other directories are in their default location relative to Tcl, so
`Tk` sources are under `....\91b0\tk` and `thread3.0.5`, `twapi` etc. are under
`....\91b0\tcl\pkgs`.

### Adding static extensions

To add your own static extension, the following changes are required.
The extension must be buildable as a static library using the standard
nmake (TIP 477) build system.

Copy your package sources under the location pointed by the `-pkgsdir`
option to `sfebuild`.

Edit `sfebuild.bat` to add your extension. Use one of the existing entries
as a template. Pay particular extension as to whether a `pkgIndex.tcl` file
needs to be generated. Some extensions do not have `pkgIndex.tcl` files
that support static libraries. For simple cases, calling `write_pkgIndex`
will suffice. Otherwise, look at `tdbc` or `tdbc::odbc` for examples.

Modify the `TclPostInit` function to add code to initialize the extension.
For example, the entry for the `twapi` package looks like

```
#ifdef TCLSFE_HAVE_twapi
    extern int Twapi_Init(Tcl_Interp * interp);
    Tcl_StaticLibrary(NULL, "Twapi", Twapi_Init, NULL);
#endif
```
*Note: correct case is important!*

The `TCLFSE_HAVE...` preprocessor defines are automatically set by
`sfebuild`.

Then run `sfebuild` as usual. Expect some gremlins that will need to be
debugged.
