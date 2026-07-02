# Utility commands for SFE distribution
#
# (c) 2026 Ashok P. Nadkarni
# See the file LICENSE for information on usage and redistribution of
# this file, and for a DISCLAIMER OF ALL WARRANTIES.

namespace eval sfe {
    oo::class create SfeMaker {
        variable vfsDir
        constructor {} {
            my getVfsDir
        }
        destructor {
            if {[info exists vfsDir]} {
                file delete -force $vfsDir
            }
        }
        method getVfsDir {} {
            if {![info exists vfsDir]} {
                set vfsDir [file normalize [file tempdir]]
            }
            return $vfsDir
        }
        method addDirectoryToVfs {dir vfsRelativePath} {
            # Copies content of specified directory to the relative path in
            # the VFS and returns the target path.
            if {[file pathtype $vfsRelativePath] ne "relative"} {
                error "$vfsRelativePath is not a relative path."
            }
            my ExtractToVfs
            set toPath [file join [my getVfsDir] $vfsRelativePath]
            file copy -force -- $dir $toPath
            return $toPath
        }
        method addPackageToVfs {dir} {
            # Copies the content of the specified directory to an appropriate
            # package location in the vfs and returns the path
            return [my addDirectoryToVfs $dir [file join [file tail $dir]]]
        }
        method makeSfe {newPath} {
            # Returns path to a SFE file that has the contents of the vfs directory
            # attached.
            if {[string equal -nocase [file normalize [info nameofexecutable]] $newPath]} {
                error "Cannot write to host executable."
            }
            set dir [my getVfsDir]
            zipfs mkimg $newPath $dir $dir ""
        }
        method ExtractToVfs {} {
            # Extracts the current //zipfs:/app to a temporary directory and
            # and stores the path in vfsDir
            file copy -- {*}[glob //zipfs:/app/*] [my getVfsDir]
        }
    }
}
