/*
 * tclMainBI.c --
 *
 *	Provides a batteries included version of tclsh.
 *
 * See the file "license.terms" for information on usage and redistribution of
 * this file, and for a DISCLAIMER OF ALL WARRANTIES.
 */

#include "tcl.h"
#include <windows.h>

#ifdef _WIN32
MODULE_SCOPE int TclMainHook(int *argc, WCHAR ***argv);
#else
MODULE_SCOPE int TclMainHook(int *argc, char ***argv);
#endif

/*
 *----------------------------------------------------------------------
 *
 * main --
 *
 *	This is the main program for the application.
 *
 * Results:
 *	None: Tcl_Main never returns here, so this procedure never returns
 *	either.
 *
 * Side effects:
 *	Just about anything, since from here we call arbitrary Tcl code.
 *
 *----------------------------------------------------------------------
 */


static int
TclPostInit(
    Tcl_Interp *interp,
    void *clientData)
{
#ifdef TCLSFE_HAVE_sqlite
    extern int Sqlite3_Init(Tcl_Interp * interp);
    Tcl_StaticLibrary(NULL, "Sqlite3", Sqlite3_Init, NULL);
#endif
#ifdef TCLSFE_HAVE_thread
    extern int Thread_Init(Tcl_Interp * interp);
    Tcl_StaticLibrary(NULL, "Thread", Thread_Init, NULL);
#endif
#ifdef TCLSFE_HAVE_tdbc
    extern int Tdbc_Init(Tcl_Interp * interp);
    Tcl_StaticLibrary(NULL, "Tdbc", Tdbc_Init, NULL);
#endif
#ifdef TCLSFE_HAVE_twapi
    extern int Twapi_Init(Tcl_Interp * interp);
    Tcl_StaticLibrary(NULL, "Twapi", Twapi_Init, NULL);
#endif
    return TCL_OK;
}

int
TclMainHook(
    int *argcPtr,
#ifdef _WIN32
    WCHAR ***argvPtr
#else
    char ***argv
#endif
)
{

    TclZipfs_AppHook(argcPtr, argvPtr);
    Tcl_RegisterPostInitProc(TclPostInit, NULL);
    return 0;					 /* Avoid compiler warning */
}
