ad_library {

    CKEditor 5 helper for ckfinder interface (not complete)

    This script defines the following public procs:

       ::richtext::ckeditor5::ckfinder::image_attach
       ::richtext::ckeditor5::ckfinder::return_file

    @author Gustaf Neumann
    @creation-date 15 Aug 2017
    @cvs-id $Id$

    NOTE: the delivery of files performs two permission checks, once
    in the requestprocessor (the site nodes) and once for the concrete image.
    If one whishes to make uploaded images readable by "The Public", make
    sure that the /

} 

namespace eval ::richtext::ckeditor5::ckfinder {

    ad_proc -public file_attach {
        -import_file
        -mime_type
        -object_id
        {-privilege read}
        -user_id
        -peeraddr
        -package_id
        {-image:boolean}
    } {

        Insert the provided image file to the content repository as a
        new item and attach the image to the specified object_id via
        the attachment API. This makes sure that the image will be
        deleted from the content repository, when the provided
        object_id is deleted.

        The user must have at least "read" privileges on the object,
        but other stronger privileges can be supplied via parameter.

    } {
        permission::require_permission \
            -party_id $user_id \
            -object_id $object_id \
            -privilege $privilege

        if {$image_p} {
            #
            # Check if we can handle the mime type. Currently, only the
            # following four mime types are supported, since these are
            # supported by "ns_imgsize", which is used to determine the
            # dimensions of the image.
            #
            switch -- $mime_type {
                image/jpg -
                image/jpeg -
                image/gif -
                image/png {
                    set ext .[lindex [split $mime_type /] 1]
                    lassign [ns_imgsize $import_file] width height
                    set success 1
                }
                default {
                    ns_log warning "image_attach: can't handle image type '$mime_type'"
                    return [list \
                                success 0 \
                                errMsg "can't handle image type '$mime_type'"]
                }
            }
        } else {
            set width 0
            set height 0
            set success 1
        }
        #
        # Create a new item without child_rels
        #
        set name $object_id-[clock clicks -microseconds]
        set item_id [::xo::db::sql::content_item new \
                         -name            $name \
                         -parent_id       [require_root_folder] \
                         -context_id      $object_id \
                         -creation_user   $user_id \
                         -creation_ip     $peeraddr \
                         -item_subtype    "content_item" \
                         -storage_type    "file" \
                         -package_id      $package_id \
                         -with_child_rels f]

        #
        # Create a revision for the fresh content_item
        #
        set revision_id [xo::dc nextval acs_object_id_seq]
        content::revision::new \
            -revision_id     $revision_id \
            -item_id         $item_id \
            -title           $name \
            -is_live         t \
            -creation_user   $user_id \
            -creation_ip     $peeraddr \
            -content_type    "content_revision" \
            -package_id      $package_id \
            -tmp_filename    $import_file \
            -mime_type       $mime_type

        #
        # Attach the image to the object via the attachments API
        #
        attachments::attach \
            -object_id $object_id \
            -attachment_id $revision_id

        return [list \
                    success $success \
                    name $name \
                    file_id $revision_id \
                    width $width \
                    height $height \
                   ]
    }

    ad_proc -public return_file {
        -revision_id
        -user_id
    } {

        Return the file with the specified revision_id to the
        user. The user must have at read permissions to obtain the
        file (image).

    } {
        permission::require_permission \
            -party_id $user_id \
            -object_id $revision_id \
            -privilege read

        set file_path [content::revision::get_cr_file_path \
                           -revision_id $revision_id]
        set mime_type [db_string get_mime_type {
            select mime_type from cr_revisions where revision_id = :revision_id
        }]
        ad_returnfile_background 200 $mime_type $file_path
    }

    ad_proc -private require_root_folder {
        {-parent_id -100}
        {-name attachments}
    } {

        Helper function to find the root folder for ckfinder
        attachments.

    } {
        set root_folder_id [content::item::get_id \
                                -root_folder_id $parent_id \
                                -item_path $name]
        if {$root_folder_id eq ""} {
            set root_folder_id [content::item::new \
                                    -name $name \
                                    -parent_id $parent_id]
        }
        return $root_folder_id
    }


    ad_proc -private query_page_contract {
        {-level 1}
        params
    } {

        Helper function similar to ad_page_contract, but works only on
        query variables.

        @return list of complaints, which is empty in case of success

    } {
        #
        # Process params provided by the query
        #
        foreach p [split [ns_conn query] &] {
            lassign [split $p =] var value
            set param($var) $value
        }
        #ns_log notice "provided params [array get param]"
        #
        # Process params as specified in the page contract
        #
        foreach p $params {
            lassign $p spec default
            lassign [split $spec :] name filters
            #ns_log notice "param $name exists [info exists param($name)]"
            if {[info exists param($name)]} {
                set value $param($name)
                #
                # Call every page contract filter for this
                # parameter. On failures, complaints are added to a
                # global variable which is picked-up later.
                #
                foreach filter [split $filters ,] {
                    ad_page_contract_filter_invoke $filter $name value
                }
            } else {
                set param($name) $default
            }
            uplevel $level [list set $name $param($name)]
        }
        if {[info exists ::ad_page_contract_complaints]} {
            set complaints [ad_complaints_get_list]
        } else {
            set complaints ""
        }
        return $complaints
    }

}

#
# Local variables:
#    mode: tcl
#    tcl-indent-level: 4
#    indent-tabs-mode: nil
# End:
