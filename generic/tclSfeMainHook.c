/*
 * tclMainBI.c --
 *
 *	Provides a batteries included version of tclsh.
 *
 * (c) 2026 Ashok P. Nadkarni
 * See the file LICENSE for information on usage and redistribution of
 * this file, and for a DISCLAIMER OF ALL WARRANTIES.
 */

#include "tcl.h"
#include <windows.h>

#ifdef _WIN32
MODULE_SCOPE int TclMainHook(int *argc, WCHAR ***argv);
#else
MODULE_SCOPE int TclMainHook(int *argc, char ***argv);
#endif

#ifndef STRINGIFY
#  define STRINGIFY(x) STRINGIFY1(x)
#  define STRINGIFY1(x) #x
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
#ifdef TCLSFE_HAVE_tdbcodbc
    extern int Tdbcodbc_Init(Tcl_Interp * interp);
    Tcl_StaticLibrary(NULL, "Tdbcodbc", Tdbcodbc_Init, NULL);
#endif
#ifdef TCLSFE_HAVE_twapi
    extern int Twapi_Init(Tcl_Interp * interp);
    Tcl_StaticLibrary(NULL, "Twapi", Twapi_Init, NULL);
#endif

    /* Overwrite auto_path to only include zipfs paths */
    Tcl_Obj *pathPtr = Tcl_NewListObj(2, NULL);
    Tcl_ListObjAppendElement(NULL, pathPtr,
                             Tcl_NewStringObj(
                                 "//zipfs:/app/tcl_library", -1));
    Tcl_ListObjAppendElement(NULL, pathPtr,
                             Tcl_NewStringObj("//zipfs:/app", -1));
    (void) Tcl_SetVar2Ex(interp, "auto_path", NULL, pathPtr, TCL_GLOBAL_ONLY);
    pathPtr = Tcl_NewStringObj("//zipfs:/app/tcl"
                               STRINGIFY(TCL_MAJOR_VERSION)
                               "/" TCL_VERSION,
                               -1);

    /* Not tm is lazy initialized so we cannot directly set the tm::paths var  */
    int ret = Tcl_EvalEx(interp,
                         "tcl::tm::path remove {*}[tcl::tm::path list];"
                         "tcl::tm::roots //zipfs:/app",
                         -1, TCL_EVAL_GLOBAL);
    if (ret == TCL_OK) {
        pathPtr = Tcl_NewStringObj("//zipfs:/app/_sfeinit.tcl", -1);
        Tcl_IncrRefCount(pathPtr);
        if (Tcl_FSAccess(pathPtr, 0) == 0) {
            ret = Tcl_FSEvalFile(interp, pathPtr);
        }
        Tcl_DecrRefCount(pathPtr);
    }
    return ret;
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
