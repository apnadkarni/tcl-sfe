# Utility commands for SFE distribution
#
# (c) 2026 Ashok P. Nadkarni
# See the file LICENSE for information on usage and redistribution of
# this file, and for a DISCLAIMER OF ALL WARRANTIES.

namespace eval sfe {}

oo::class create sfe::SfeMaker {
    variable vfsDir
    constructor {} {
        my ExtractToVfs
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
    method addPath {dir vfsRelativePath} {
        # Copies content of file or directory to the relative path in
        # the VFS and returns the target path.
        if {[file pathtype $vfsRelativePath] ne "relative"} {
            error "$vfsRelativePath is not a relative path."
        }
        set toPath [file join [my getVfsDir] $vfsRelativePath]
        my CheckCopyable $dir $toPath
        file copy -force -- $dir $toPath
        return $toPath
    }
    method addPackage {dir} {
        # Copies the content of the specified directory to an appropriate
        # package location in the vfs and returns the path
        return [my addPath $dir [file join [file tail $dir]]]
    }
    method addModule {tmPath} {
        # Copies the given path to a directory in the Tcl module search path.
        # tmPath may be either a directory or a file.
        lassign [split [info tclversion] .] major minor
        set destDir [file join [getVfsDir] tcl$major tcl$major$minor]
        if {![file exists destDir]} {
            file mkdir $destDir
        }
        set toPath [file join $destDir [file tail $tmPath]]
        my CheckCopyable $tmPath $toPath
        file copy -force $tmPath $toPath
    }
    method buildSfe {newPath} {
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
    method CheckCopyable {fromPath toPath} {
        # Raises an error if
        #   - toPath exists AND
        #   - one of fromPath or toPath is a directory
        # These combinations can lead to unexpected results so just do
        # not allow them.
        if {[file exists $toPath] &&
            ([file type $toPath] eq "directory" ||
             [file type $fromPath] eq "directory")} {
            error "VFS path $toPath exists and either $toPath or $fromPath is a directory."
        }
    }
}

proc sfe::make {outPath paths} {
    # Creates a new single-file executable from the current one with the
    # addition of paths. If a path is a directory, it is copied along with
    # its content to the top level of the vfs. If an ordinary file, it is
    # copied to a directory in Tcl module path if it has a .tm extension
    # or the top level of the vfs.
    set paths [lsort -unique [lmap path $paths {file normalize $path}]]
    set sfe [SfeMaker new]
    try {
        foreach path $paths {
            set type [file type $path]
            switch $type {
                directory {
                    $sfe addPackage $path
                }
                file {
                    if {[string equal -nocase [file extension $path] eq ".tm"]} {
                        $sfe addModule $path
                    } else {
                        $sfe addPath $path [file tail $path]
                    }
                }
                default {
                    puts stderr "Warning: Skipping $path of type $type."
                }
            }
        }
        $sfe buildSfe $outPath
    } finally {
        $sfe destroy
    }
}
