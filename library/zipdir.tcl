proc usage {} {
    puts stderr "Usage: [file tail [info nameofexecutable]] $::argv0 FROMDIR TOZIP"
}

if {[llength $::argv] != 2} {
    usage
    exit 1
}

lassign $::argv fromdir zipfile
zipfs mkzip $zipfile $fromdir $fromdir
