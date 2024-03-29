set title "Richtext CKEditor Sitewide Admin"
set context [list  $title]
set version $::richtext::ckeditor5::version

#
# Get version info about CKEditor. If not locally installed, offer a
# link for download.
#
set version_info [::richtext::ckeditor5::version_info]
if {[dict exists $version_info resources]} {
    set resources [dict get $version_info resources]
}
set cdn [dict get $version_info cdn]

set path $::acs::rootdir/packages/richtext-ckeditor5/www
set writable [file writable $path]
