#
# This is a minimal AJAX based ckfinder interface.
#
# It supports currently just the drag and drop interface of the
# "uploadimage" plugin. Dropped images are uploaded to the content
# repository and attached to the displayed object_id via the
# attachment package.
#
# Since it is not clear, what is the best place for mounting the
# package (the richtext-* is a singleton package, what should be done
# e.g. on host-node mapped subsites? Should we add some support to
# acs-subsite or acs-content-repository), we just register the few
# URLs .../upload and .../view via ns_register_proc. This might change
# in the future.
#
# NOTE: the delivery of files performs two permission checks, once in
# the request processor (checking the site nodes) and once for the
# concrete image.  In order to make uploaded images readable by "The
# Public", make sure that the package_id pointed to by the CKFinderURL
# (per default /acs-content-repository) offers as well read
# permissions to the public.

# This interface can be used obtaining a customized version of
# CKEditor containing he "uploadimage" plugin. When this is installed,
# it can be used e.g. with a widget spec like the following
#
#    {text:richtext(richtext)
#        {html {...}}
#        {label "...."}
#        {options {
#            editor ckeditor5
#            plugins "uploadimage"
#        }}
#
# For attaching the images, make sure to pass the property
# "displayed_object_id" on the page, where the richtext form is
# displayed.
#

#
# We need here a small helper for input checking using the usual
# checkers for two reasons:
#
#  1) The way ckfinder is recommended to work relies on the
#     separate processing of QUERY and POST variables of an
#     request. The traditional OpenACS input handling does NOT
#     support both types of variables at the same time. so we use
#     here a small helper, such we can use at least the
#     traditional calling conventions and page contract filters.
#
#  2) The classical page_contract cannot be configured to interact
#     properly with AJAX, at least not with a predefined AJAX
#     interface expecting always a certain JSON array as result.
#     This corresponds to "responseType=json" in the uploadUrl.
#

ns_register_proc POST $::richtext::ckeditor5::ckfinder_url/uploadimage {
    #
    # Image upload handler (for "uploadimage" plugin)
    #
    set complaints [::richtext::ckeditor5::ckfinder::query_page_contract {
        {object_id:naturalnum}
        {type:word}
    }]

    if {[llength $complaints] == 0 && $type eq "Images"} {

        set form [ns_getform]
        set d [::richtext::ckeditor5::ckfinder::image_attach \
                   -object_id   $object_id \
                   -import_file [ns_set get $form upload.tmpfile] \
                   -mime_type   [ns_set get $form upload.content-type] \
                   -user_id     [ad_conn user_id] \
                   -peeraddr    [ad_conn peeraddr] \
                   -package_id  [ad_conn package_id] \
                   -image \
                  ]
        set success [dict get $d success]
        if {$success eq "1"} {
            #
            # Successful operation
            #
            set view_url [export_vars \
                              -base $::richtext::ckeditor5::ckfinder_url/view {
                                  {image_id "[dict get $d file_id]"}
                              }]
            set reply [subst {{
                "uploaded":  [dict get $d success],
                "fileName": "[dict get $d name]",
                "url":      "$view_url",
                "width":     [dict get $d width],
                "height":    [dict get $d height]
            }}]
        } else {
            #
            # ckfinder::image_attach returned an error
            #
            set errMsg [dict get $d errMsg]
        }
    } else {
        #
        # Either page contract failed or invalid value for 'type' was
        # specified
        #
        dict set d errMsg "invalid query parameter // $complaints"
        set success 0
    }

    if {$success eq "0"} {
        set reply [subst {{
            "uploaded":  $success,
            "error": {
                "message": "[dict get $d errMsg]",
            }
        }}]
    }
    ns_log notice $reply

    ns_return 200 text/plain $reply
}


ns_register_proc POST $::richtext::ckeditor5::ckfinder_url/upload {
    #
    # Upload handler (for the standard "filebrowser" plugin)
    #
    set complaints [::richtext::ckeditor5::ckfinder::query_page_contract {
        {object_id:naturalnum}
        {type:word}
        {CKEditorFuncNum ""}
        {command:word ""}
        {CKEditor:word ""}
        {langCode en}
    }]

    if {[llength $complaints] == 0 && $type eq "Files"} {

        set form [ns_getform]
        set d [::richtext::ckeditor5::ckfinder::file_attach \
                   -object_id   $object_id \
                   -import_file [ns_set get $form upload.tmpfile] \
                   -mime_type   [ns_set get $form upload.content-type] \
                   -user_id     [ad_conn user_id] \
                   -peeraddr    [ad_conn peeraddr] \
                   -package_id  [ad_conn package_id] \
                  ]
        set success [dict get $d success]
        if {$success eq "1"} {
            #
            # Successful operation
            #
            set view_url [export_vars \
                              -base $::richtext::ckeditor5::ckfinder_url/view {
                                  {image_id "[dict get $d file_id]"}
                              }]
            set reply [subst {
                <script type="text/javascript">
                window.parent.CKEDITOR.tools.callFunction("$CKEditorFuncNum", "$view_url", "");
                </script>
            }]
        } else {
            #
            # ckfinder::image_attach returned an error
            #
            set errMsg [dict get $d errMsg]
        }
    } else {
        #
        # Either page contract failed or invalid value for 'type' was
        # specified
        #
        dict set d errMsg "invalid query parameter // $complaints"
        set success 0
    }

    if {$success eq "0"} {
        set reply [subst {[dict get $d errMsg]}]
    }
    ns_log notice $reply
    ns_return 200 text/html $reply
}

ns_register_proc GET $::richtext::ckeditor5::ckfinder_url/browse {
    #
    # File-browser (for the standard "filebrowser" plugin)
    #
    set complaints [::richtext::ckeditor5::ckfinder::query_page_contract {
        {object_id:naturalnum}
        {type:word}
        {CKEditorFuncNum ""}
        {CKEditor:word ""}
        {langCode en}
    }]

    permission::require_permission \
        -party_id [ad_conn user_id] \
        -object_id $object_id \
        -privilege read

    set reply [template::adp_include \
                   /packages/richtext-ckeditor5/lib/file-browser [subst {
                       object_id "$object_id"
                       type "$type"
                       CKEditorFuncNum "$CKEditorFuncNum"
                       CKEditor "$CKEditor"
                       langCode "$langCode"
    }]]

    ns_return 200 text/html $reply
}

#
# View handler
#

ns_register_proc GET $::richtext::ckeditor5::ckfinder_url/view {
    #
    # View function (for "filebrowser" and "uploadimage" plugins)
    #
    set ::template::parse_level [info level]
    ad_try {
        #
        # Use the standard page_contract
        #
        ad_page_contract {
        } {
            {image_id:naturalnum ""}
        }
        ::richtext::ckeditor5::ckfinder::return_file \
            -revision_id $image_id \
            -user_id [ad_conn user_id]

    } ad_script_abort val {
        #
        # The page contract has probably failed, no need to raise an
        # exception.
        #
    }
}

#
# Local variables:
#    mode: tcl
#    tcl-indent-level: 4
#    indent-tabs-mode: nil
# End:
