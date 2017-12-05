ad_include_contract {
} {
    {object_id:naturalnum}
    {type:word}
    {CKEditorFuncNum ""}
    {CKEditor:word ""}
    {langCode en}
}

set title "Browse Attached Images"
set page_title "Selectable Images"
set no_attachment "No Attachment Available"

template::multirow create images src alt

foreach tuple [attachments::get_attachments -object_id $object_id] {
    lassign $tuple image_id .
    template::multirow append images \
        /acs-content-repository/ckfinder/view?image_id=$image_id ""
}

#
# Local variables:
#    mode: tcl
#    tcl-indent-level: 4
#    indent-tabs-mode: nil
# End:
