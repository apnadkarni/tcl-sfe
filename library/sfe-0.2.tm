# Utility commands for SFE distribution
#
# (c) 2026 Ashok P. Nadkarni
# See the file LICENSE for information on usage and redistribution of
# this file, and for a DISCLAIMER OF ALL WARRANTIES.

namespace eval sfe {}

oo::class create sfe::SfeMaker {
    variable newSfePath
    variable vfsDir
    variable iconPath
    variable versionInfo

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
        set destDir [file join [my getVfsDir] tcl$major $major.$minor]
        if {![file exists destDir]} {
            file mkdir $destDir
        }
        set toPath [file join $destDir [file tail $tmPath]]
        my CheckCopyable $tmPath $toPath
        file copy -force $tmPath $toPath
    }
    method replaceIcon {newIconPath} {
        # Replaces the icon in the SFE stub with the one in the icon file
        # passed in.
        set iconPath [file normalize $newIconPath]
    }
    method replaceVersion {newVersionInfo} {
        set versionInfo $newVersionInfo
    }
    method buildSfe {toPath} {
        # Returns path to a SFE file that has the contents of the vfs directory
        # attached.
        set toPath [file normalize $toPath]
        if {[string equal -nocase [file normalize [info nameofexecutable]] $toPath]} {
            error "Cannot write to host executable."
        }
        set newSfePath $toPath
        set dir [my getVfsDir]
        if {![info exists iconPath] && ![info exists versionInfo]} {
            # No version or icon to replace. Do the easy way.
            zipfs mkimg $newSfePath $dir $dir ""
            return
        }

        # To replace the version or icon, we need to split the zipfs from the
        # executable.
        lassign [zipfs info //zipfs:/app] - - - zipOffset
        set exeChan [open [info nameofexecutable] rb]
        try {
            set chan [file tempfile tempPath]
            try {
                chan configure $chan -translation binary
                chan copy $exeChan $chan -size $zipOffset
            } finally {
                close $chan
            }
        } on error {} {
            if {[info exists tempPath]} {
                file delete $tempPath
            }
        } finally {
            close $exeChan
        }

        if {[info exists versionInfo]} {
            my ReplaceVersionInStub $tempPath
        }
        if {[info exists iconPath]} {
            my ReplaceIconInStub $tempPath
        }
        try {
            zipfs mkimg $newSfePath $dir $dir "" $tempPath
        } finally {
            file delete $tempPath
        }
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
    method VersionInfoStringBlob {key val {nestedBytes {}}} {
        # Returns a binary blob in the form used in resource string tables.
        # WORD - length of the blob in bytes
        # WORD - number of UTF-16LE units in value including terminating nul
        # WORD - type (1 for strings)
        # STRING - key UTF-16LE string
        # ?PAD? - DWORD padding if needed
        # STRING - value UTF-16LE string (may be empty)
        # ?PAD? - if needed
        if {$key eq ""} {
            error "Empty key passed to VersionInfoStringBlob."
        }
        append key \0
        if {$value ne ""} {
            append value \0
        }
        set utf16key [encoding convertto utf-16le $key]
        set utf16val [encoding convertto utf-16le $value]

        # Calculate lengths of all the pieces and padding first

        # Header fields and key
        set blobLength [expr {6 + [string length $utf16key]}]
        # Padding after key string
        set padlen [expr {4 - ($blobLength & 3)}]
        set padkey [expr {$padlen < 4 ? [string repeat \0 $padlen] : ""}]
        incr blobLength [string length $padkey]

        # Value string
        incr blobLength [string length $utf16val]
        # Padding after value string
        set padlen [expr {4 - ($blobLength & 3)}]
        set padval [expr {$padlen < 4 ? [string repeat \0 $padlen] : ""}]
        incr blobLength [string length $padval]

        # Nested bytes
        incr blobLength [string length $nestedBytes]

        if {$blobLength > 32767} {
            error "String blob too big"
        }

        set padlen [expr {4 - ($blobLength & 3)}]
        set padend [expr {$padlen < 4 ? [string repeat \0 $padlen] : ""}]
        # DON'T increase blobLength to account for trailing pad

        # Now we have all the length information, construct the blob
        return [string cat \
                    [binary format s3 \
                         $blobLength \
                         [expr {[string length $utf16val]/2}] \
                         1] \
                    $utf16key $padkey \
                    $utf16val $padval \
                    $nestedBytes $padend
               ]
    }
    method BuildVersionResource {} {
        # Returns a version resource binary.
        # Caller should have ensured versionInfo variable exists

        if {![dict exists $versionInfo FileVersion]} {
            error "FileVersion information is missing."
        }
        set fileVersion [dict get $versionInfo FileVersion]
        if {![regexp {^(\d+)\.(\d+)\.(\d+)\.(\d+)$} $fileVersion
                  -> major minor build revision]} {
            error "Invalid FileVersion, must of the form N.N.N.N"
        }
        set productVersion [dict getdef $versionInfo ProductVersion $fileVersion]
        if {![regexp {^(\d+)\.(\d+)\.(\d+)\.(\d+)$} $version
                  -> pmajor pminor pbuild prevision]} {
            error "Invalid ProductVersion, must of the form N.N.N.N"
        }

        set ts [twapi::secs_since_1970_to_large_system_time [clock seconds]]
        set tsLow [expr {$ts >> 32}]
        set tsHigh [expr {wide(0xffffffff) & $ts}]

        # Fixed component:
        # Signature, StructVersion, FileVersionMS, FileVersionLS,
        # ProductVersionMS, ProductVersionLS, FileFlagMask, FileFlags,
        # FileOS, FileType, FileSubType, FileDateMS, FileDateLS
        set fixedPart \
            [binary format i13 \
                 [list \
                      0xFEEF04BD 0x00010000 \
                      [expr {(($major & 0xFFFF) << 16) | ($minor & 0xFFFF)}] \
                      [expr {(($build & 0xFFFF) << 16) | ($revision & 0xFFFF)}] \
                      [expr {(($pmajor & 0xFFFF) << 16) | ($pminor & 0xFFFF)}] \
                      [expr {(($pbuild & 0xFFFF) << 16) | ($prevision & 0xFFFF)}] \
                      0x3F 0 0x00040004 1 0 $tsHigh $tsLow]]

        # string table - mandatory fields
        set stringData ""
        append stringData \
            [my VersionInfoStringBlob FileVersion $fileVersion] \
            [my VersionInfoStringBlob ProductVersion $productVersion] \
            [my VersionInfoStringBlob OriginalFileName [file tail $newSfePath]] \
            [my VersionInfoStringBlob InternalName \
                 [file tail [file rootname $newSfePath]]]
        foreach {key defaultValue} {
            CompanyName "The Tcl Community"
            FileDescription "Tcl/Tk Single File Executable"
            ProductName "Tcl/Tk Single File Application"
        } {
            append stringData \
                [my VersionInfoStringBlob $key \
                     [dict getdef $versionInfo $key $defaultValue]]
        }
        # string table - optional fields
        if {[dict exists $versionInfo LegalCopyright]} {
            append stringData \
                [my VersionInfoStringBlob LegalCopyright \
                     [dict get $versionInfo LegalCopyright]]
        }

        # Strings are contained within a StringTable
        # Hex rep 0409 -> US English, 04b0 -> Unicode code page
        set stringTable [my VersionInfoStringBlob "040904b0" "" $stringData]

        # The StringTable is under a StringFileInfo
        set stringFileInfo [my VersionInfoStringBlob "StringFileInfo" \
                                "" $stringTable]

        # Done with the StringTable, now deal with the VarFileInfo block
        set varBlock [my VersionInfoBinaryBlob "Translation" \
                          [binary format ss 0x0409 0x04b0]]
        set varFileInfo [my VersionInfoStringBlob "VarFileInfo" "" $varBlock]

        # Finally the whol enchilada
        return [my VersionInfoBinaryBlob "VS_VERSION_INFO" $fixedPart \
                   [string cat $stringFileInfo $varFileInfo]]
    }
    method ReplaceVersionInStub {stubPath} {
        # Replaces the version information in the SFE executable stub.
        package require twapi

        # Find the current version resources in the SFE for deletion.
        set libh [twapi::load_library $stubPath -datafile]
        try {
            set resources [twapi::extract_resources $libh]
            set versionResources [dict getdef $resources 16 {}]
        } trap {TWAPI_WIN32 1812} {} {
            # No resource section. That's ok
        } trap {TWAPI_WIN32 1814} {} {
            # No such resource in resource section. That's ok too
        } finally {
            twapi::free_library $libh
        }

        # Now do the actual update
        set libh [twapi::begin_resource_update $stubPath]
        try {
            # First delete all existing version resources
            if {[info exists versionResources]} {
                dict for {versionId perLangDict} $versionResources {
                    foreach langId [dict keys $perLangDict] {
                        twapi::delete_resource $libh 16 $versionId $langId
                    }
                }
            }
            # Construct the mandatory fields.
            twapi::update_resource $libh 16 [my BuildVersionResource]
        } trap {} {msg} {
            twapi::end_resource_update $libh -discard
            error $msg
        }
        twapi::end_resource_update $libh
    }
    method ReplaceIconInStub {stubPath} {
        # Replaces the icon in the SFE executable stub.
        package require twapi

        const sfeIconGroup SFE
        const sfeIconLang 1033

        if {![info exists iconPath]} {
            return
        }
        set libh [twapi::load_library $stubPath -datafile]

        # Read the icon group and collect its referenced icon id's
        set iconIdsInGroup {}
        set iconGroupExists false
        try {
            # Get list of all icon ids. We will need this when generating new id's
            # 3 -> RT_ICON
            set resources [twapi::extract_resources $libh]
            set existingIconIds [dict keys [dict getdef $resources 3 {}]]
            if {[llength $existingIconIds]} {
                # Assumes integer icon ids!
                set maxExistingIconId [lindex [lsort -integer $existingIconIds] end]
            } else {
                set maxExistingIconId 0
            }

            # Read the icon group of interest 14 -> RT_GROUP_ICON
            set res [twapi::read_resource $libh 14 $sfeIconGroup $sfeIconLang]
            set iconGroupExists true
            lassign [binary scan $res ttt reserved type count]
            if {$type != 1} {
                error "RT_GROUP_ICON idType is not 1 as expected."
            }
            # Loop through icon dir entries
            for {set i 0} {$i < $count} {incr i} {
                # Initial RT_GROUP_ICON header is 6 bytes, each dir
                # entry is 14 bytes with icon id in last two bytes
                set offset [expr {6 + (14*$i)}]
                binary scan $res "@${offset}x12t" id
                lappend iconIdsInGroup $id
            }
        } trap {TWAPI_WIN32 1812} {} {
            # No resource section. That's ok
        } trap {TWAPI_WIN32 1814} {} {
            # No such resource in resource section. That's ok too
        } finally {
            twapi::free_library $libh
        }

        # Read in the new icon file
        set iconData [readFile $iconPath binary]
        binary scan $iconData ttt reserved type iconCount
        if {$reserved != 0 || $type != 1} {
            error "$iconPath not recognized as a .ICO file"
        }
        if {$iconCount == 0} {
            error "No icons in $iconPath"
        }

        # Now do the actual update
        set libh [twapi::begin_resource_update $stubPath]
        try {
            if {$iconGroupExists} {
                # Don't delete, just replace later in an attempt to preserve
                # its place in the icon group order.
                #twapi::delete_resource $libh 14 $sfeIconGroup $sfeIconLang
            }
            foreach iconId $iconIdsInGroup {
                twapi::delete_resource $libh 3 $iconId $sfeIconLang
            }

            # RT_ICON_GROUP header
            set groupHeader [binary format ttt 0 1 $iconCount]
            # Loop and copy icons
            for {set i 0} {$i < $iconCount} {incr i} {
                # Initial RT_GROUP_ICON header is 6 bytes, each dir in ICO file
                # entry is 16 bytes.
                set offset [expr {6 + (16*$i)}]
                binary scan $iconData "@${offset} cu cu cu cu tu tu nu nu" width height colorcount reserved places bitcount bytesinres imageoffset
                if {$width == 0} {set width 256}
                if {$height == 0} {set height 256}
                # Find an id to use for the ICO, reusing one from existing
                # if possible
                if {[llength $iconIdsInGroup]} {
                    set iconId [lpop iconIdsInGroup 0]
                } else {
                    set iconId [incr maxExistinIconId]
                }
                # Format the directory entry for the icon
                append groupHeader [binary format "cu cu cu cu tu tu nu tu" \
                                        $width $height $colorcount $reserved \
                                        $places $bitcount $bytesinres $iconId]
                # Write out the actual RT_ICON
                twapi::update_resource $libh 3 $iconId $sfeIconLang  \
                    [string range $iconData $imageoffset \
                         [expr {$imageoffset+$bytesinres-1}]]
            }
            # Write out the group icon resource
            twapi::update_resource $libh 14 \
                $sfeIconGroup $sfeIconLang $groupHeader
        } trap {} {msg} {
            twapi::end_resource_update $libh -discard
            error $msg
        }
        twapi::end_resource_update $libh
    }
}


proc sfe::make {args} {
    # Creates a new single-file executable from the current one with the
    # addition of paths. If a path is a directory, it is copied along with
    # its content to the top level of the vfs. If an ordinary file, it is
    # copied to a directory in Tcl module path if it has a .tm extension
    # or the top level of the vfs.

    array set opts {}
    while {[llength $args]} {
        set arg [lpop args 0]
        switch -glob $arg {
            -icon -
            -version {
                if {[llength $args] == 0} {
                    error "Missing argument for option $arg"
                }
                set opts(-icon) [lpop args 0]
            }
            -- {
                if {[llength $args]} {
                    set outPath [lpop args 0]
                }
                return -code break -level 0
            }
            -* {
                error "Unknown option \"$arg\""
            }
            default {
                set outPath $arg
                return -code break -level 0
            }
        }
    }

    if {![info exists outPath]} {
        error "Missing argument for output path."
    }

    set outPath [file normalize $outPath]
    set paths [lsort -unique [lmap path $args {file normalize $path}]]
    set sfe [SfeMaker new]
    try {
        foreach path $paths {
            set type [file type $path]
            switch $type {
                directory {
                    $sfe addPackage $path
                }
                file {
                    if {[string equal -nocase [file extension $path] ".tm"]} {
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
        if {[info exists opts(-icon)]} {
            $sfe replaceIcon $opts(-icon)
        }
        if {[info exists opts(-version)]} {
            $sfe replaceVersion $opts(-version)
        }
        $sfe buildSfe $outPath
    } finally {
        $sfe destroy
    }
}
