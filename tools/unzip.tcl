proc usage {} {
    puts stderr "Usage: [file tail [info nameofexecutable]] $::argv0 FROMZIP TODIR"
}

if {[llength $::argv] != 2} {
    usage
    exit 1
}

lassign $::argv zipfile todir
set zipdir [file join [zipfs root] tmp]
zipfs mount $zipfile $zipdir
file copy -force $zipdir $todir
