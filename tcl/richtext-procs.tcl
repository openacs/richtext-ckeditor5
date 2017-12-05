ad_library {

    CKEditor 5 integration with the richtext widget of acs-templating.

    In addition to the richttext widget properties,
    https://openacs.org/api-doc/proc-view?proc=template::widget::richtext&source_p=1
    the CKEditor 5 allows us to specify a editor class 

    Note: CKEditor 5 no longer comes with a configuration setting to change its height.
    https://stackoverflow.com/questions/46559354/how-to-set-the-height-of-ckeditor-5-classic-editor/46559355#46559355

    The current release 1.0.0-alpha.2 not for easy imaging support "Coming soon"
    
    This script defines in essence following two procs:

       ::richtext-ckeditor5::initialize_widget
       ::richtext-ckeditor5::render_widgets

    @author Gustaf Neumann
    @creation-date 2 Dec 2017
    @cvs-id $Id$
}

namespace eval ::richtext::ckeditor5 {

    set package_id [apm_package_id_from_key "richtext-ckeditor5"]

    # ns_section ns/server/${server}/acs/richtext-ckeditor
    #        ns_param CKEditorVersion   1.0.0-alpha.2
    #        ns_param CKEditorPackage   standard
    #        ns_param CKFinderURL       /acs-content-repository/ckfinder
    #        ns_param StandardPlugins   uploadimage
    #
    set version [parameter::get \
                     -package_id $package_id \
                     -parameter CKEditorVersion \
                     -default 1.0.0-alpha.2]
    set ckfinder_url [parameter::get \
                          -package_id $package_id \
                          -parameter CKFinderURL \
                          -default /acs-content-repository/ckfinder]
    set standard_plugins [parameter::get \
                              -package_id $package_id \
                              -parameter StandardPlugins \
                              -default ""]
    set JSEditorClass [parameter::get \
                           -package_id $package_id \
                           -parameter JSEditorClass \
                           -default ClassicEditor]
    # ClassicEditor | BalloonEditor | InlineEditor

    #
    # The cp_package might be basic, standard, of full;
    #
    # Use "custom" for customized downloads, expand the downloaded zip file in
    #    richtext-ckeditor5/www/resources/$version
    # and rename the expanded top-folder from "ckeditor" to "custom"
    #
    set ck_package [parameter::get \
                              -package_id $package_id \
                              -parameter CKEditorPackage \
                        -default "classic"]

    ad_proc initialize_widget {
        -form_id
        -text_id
        {-options {}}
    } {

        Initialize an CKEditor richtext editor widget.

    } {
        ns_log notice "initialize CKEditor instance with <$options>"

        # Allow per default all CSS-classes, unless the user has specified
        # it differently
        if {![dict exists $options extraAllowedContent]} {
            dict set options extraAllowedContent {*(*)}
        }

        #
        # The richtext widget might be specified by "options {editor
        # ckeditor5}" or via the package parameter "RichTextEditor" of
        # acs-templating.
        #
        # The following options handled by the CKEditor integration
        # can be specified in the widget spec of the richtext widget:
        #
        #      plugins skin customConfig spellcheck
        #
        set ckOptionsList {}

        if {![dict exists $options spellcheck]} {
            set package_id [apm_package_id_from_key "richtext-ckeditor5"]
            dict set options spellcheck [parameter::get \
                                             -package_id $package_id \
                                             -parameter "SCAYT" \
                                             -default "false"]
        }
        # For the native spellchecker, one has to hold "ctrl" or "cmd"
        # with the right click.

        lappend ckOptionsList \
            "language: '[lang::conn::language]'" \
            "disableNativeSpellChecker: false" \
            "scayt_autoStartup: [dict get $options spellcheck]" 

        #
        # Get the property "displayed_object_id" from the call-stack
        #
        for {set l 0} {$l < [info level]} {incr l} {
            set propVar __adp_properties(displayed_object_id)
            if {[uplevel #$l [list info exists $propVar]]} {
                set displayed_object_id [uplevel #$l [list set $propVar]]
                break
            }
        }
        if {[info exists displayed_object_id]} {
            #
            # If we have a displayed_object_id, configure it for the
            # plugins "filebrowser" and "uploadimage".
            #
            set image_upload_url [export_vars \
                                      -base $::richtext::ckeditor5::ckfinder_url/uploadimage {
                                          {object_id $displayed_object_id} {type Images}
                                      }]
            set file_upload_url [export_vars \
                                     -base $::richtext::ckeditor5::ckfinder_url/upload {
                                         {object_id $displayed_object_id} {type Files} {command QuickUpload}
                                     }]
            set file_browse_url [export_vars \
                                     -base $::richtext::ckeditor5::ckfinder_url/browse {
                                         {object_id $displayed_object_id} {type Files}
                                     }]
            lappend ckOptionsList \
                "imageUploadUrl: '$image_upload_url'" \
                "filebrowserBrowseUrl: '$file_browse_url'" \
                "filebrowserUploadUrl: '$file_upload_url'" \
                "filebrowserWindowWidth: '800'" \
                "filebrowserWindowHeight: '600'"
        }
        
        set plugins [split $::richtext::ckeditor5::standard_plugins ,]
        if {[dict exists $options plugins]} {
            lappend plugins {*}[split [dict get $options plugins] ,]
        }
        if {[llength $plugins] > 0} {
            lappend ckOptionsList "plugins: \[ [join $plugins ,] \]"
        }
        if {[dict exists $options skin]} {
            lappend ckOptionsList "skin: '[dict get $options skin]'"
        }
        if {[dict exists $options customConfig]} {
            lappend ckOptionsList \
                "customConfig: '[dict get $options customConfig]'"
        }
        if {[dict exists $options extraAllowedContent]} {
            lappend ckOptionsList \
                "extraAllowedContent: '[dict get $options extraAllowedContent]'"
        }
        #
        # For the time being, set the global variable
        # ::richtext::ckeditor5::JSEditorClass of the JavaScript
        # editor class to the provided value, since we need this value
        # for computing the richt CDN url.
        #
        if {[dict exists $options JSEditorClass]} {
            set ::richtext::ckeditor5::JSEditorClass [dict get $options JSEditorClass]
        }
        set JSEditorClass $::richtext::ckeditor5::JSEditorClass

        set ckOptions [join $ckOptionsList ", "]

        #
        # Add the configuration via body script
        #
        ns_log notice "initialize_widget: $JSEditorClass.create(document.querySelector( '#$text_id', {$ckOptions} )"
        template::add_script -section body -script [subst {
            $JSEditorClass
               .create( document.querySelector( '#$text_id', {$ckOptions} ))
               .catch( error => {
                   console.error( error );
               } );
        }]

        #
        # Load the editor and everything necessary to the current page.
        #
        ::richtext::ckeditor5::add_editor

        #
        # do we need render_widgets?
        #
        return ""
    }


    ad_proc render_widgets {} {

        Render the ckeditor5 rich-text widgets. This function is created
        at a time when all rich-text widgets of this page are already
        initialized. The function is controlled via the global variables

           ::acs_blank_master(ckeditor5)
           ::acs_blank_master__htmlareas

    } {
        #
        # In case no ckeditor5 instances are created, nothing has to be
        # done.
        #
        if {![info exists ::acs_blank_master(ckeditor5)]} {
            return
        }
        #
        # Since "template::head::add_javascript -src ..." prevents
        # loading the same resource multiple times, we can perform the
        # load in the per-widget initialization and we are done here.
        #
    }

    ad_proc ::richtext::ckeditor5::version_info {
        {-ck_package ""}
        {-version ""}
    } {

        Get information about available version(s) of CKEditor, either
        from the local file system, or from CDN.

    } {
        #
        # If no version or ck editor package are specified, use the
        # namespaced variables as default.
        #
        if {$version eq ""} {
            set version ${::richtext::ckeditor5::version}
        }
        if {$ck_package eq ""} {
            switch  ${::richtext::ckeditor5::JSEditorClass} {
                ClassicEditor { set ck_package classic}
                BalloonEditor { set ck_package balloon}
                InlineEditor  { set ck_package inline}
                default       { set ck_package ${::richtext::ckeditor5::ck_package}}
            }
        }
        ns_log notice "CKeditor setting ck_package to <${::richtext::ckeditor5::ck_package}> editorclass $::richtext::ckeditor5::JSEditorClass"
        set ::richtext::ckeditor5::ck_package ${::richtext::ckeditor5::ck_package}

        set suffix ckeditor5/$version/$ck_package/ckeditor.js
        set resources $::acs::rootdir/packages/richtext-ckeditor5/www/resources
        if {[file exists $resources/$suffix]} {
            lappend result file $resources/$suffix
            lappend result resources /resources/richtext-ckeditor5/$suffix
        }
        lappend result cdn "//cdn.ckeditor.com/$suffix"
        ns_log notice "CKEditor path <$result> "
        # https://cdn.ckeditor.com/ckeditor5/1.0.0-alpha.2/classic/ckeditor.js

        return $result
    }

    ad_proc ::richtext::ckeditor5::add_editor {
        {-ck_package ""}
        {-version ""}
    } {

        Add the necessary JavaScript and other files to the current
        page. The naming is modeled after "add_script", "add_css",
        ... but is intended to care about everything necessary,
        including the content security policies. Similar naming
        conventions should be used for other editors as well.

        This function can be as well used from other packages, such
        e.g. from the xowiki form-fields, which provide a much higher
        customization.

    } {
        set version_info [::richtext::ckeditor5::version_info \
                              -ck_package $ck_package \
                              -version $version]

        if {[dict exists $version_info resources]} {
            template::head::add_javascript \
                -src [dict get $version_info resources]
        } else {
            template::head::add_javascript -src [dict get $version_info cdn]
            security::csp::require script-src cdn.ckeditor.com
            security::csp::require style-src cdn.ckeditor.com
            security::csp::require img-src cdn.ckeditor.com
        }

        #
        # add required general directives for content security policies
        #
        #security::csp::require script-src 'unsafe-eval'
        security::csp::require -force script-src 'unsafe-inline'

        # this is needed currently for "imageUploadUrl"
        security::csp::require img-src data:
    }

    ad_proc ::richtext::ckeditor5::download {
        {-ck_package ""}
        {-version ""}
    } {

        Download the CKeditor package in the specified version and put
        it into a directory structure similar to the CDN structure to
        allow installation of multiple versions. When the local
        structure is available, it will be used by initialize_widget.

        Notice, that for this automated download, the "unzip" program
        must be installed and $::acs::rootdir/packages/www must be
        writable by the web server.

    } {
        #
        # If no version or ck editor package are specified, use the
        # namespaced variables as default.
        #
        if {$version eq ""} {
            set version ${::richtext::ckeditor5::version}
        }
        if {$ck_package eq ""} {
            set ck_package ${::richtext::ckeditor5::ck_package}
        }

        set download_url http://download.cksource.com/CKEditor/CKEditor/CKEditor%20${version}/ckeditor_${version}_${ck_package}.zip
        set resources $::acs::rootdir/packages/richtext-ckeditor5/www/resources

        #
        # Do we have unzip installed?
        #
        set unzip [::util::which unzip]
        if {$unzip eq ""} {
            error "can't install CKeditor locally; no unzip program found on PATH"
        }

        #
        # Do we have a writable output directory under resources?
        #
        if {![file isdirectory $resources/$version]} {
            file mkdir $resources/$version
        }
        if {![file writable $resources/$version]} {
            error "directory $resources/$version is not writable"
        }

        #
        # So far, everything is fine, download the editor package
        #
        set result [util::http::get -url $download_url -spool]
        #ns_log notice "GOT $result"
        if {[dict get $result status] == 200} {
            #
            # The Download was successful, unzip it and let the
            # directory structure look similar as on the CDN.
            #
            set fn [dict get $result file]
            set output [exec $unzip -o $fn -d $resources/$version]
            file rename -- \
                $resources/$version/ckeditor \
                $resources/$version/$ck_package
        } else {
            error "download of $download_url failed, HTTP status: [dict get $result status]"
        }
    }

    ad_proc -public get_tag {-options} {
        Return the tag for rendering
    } {
        ns_log notice "=== get_tag $options"
        if {[dict exists $options editor]
            && [dict get $options editor] eq "ckeditor5"
            && [dict exists $options JSEditorClass]
            && [dict get $options JSEditorClass] ne "ClassicEditor"
        } {
            set edit_item_tag div
        }
    }
    
}


# Local variables:
#    mode: tcl
#    tcl-indent-level: 4
#    indent-tabs-mode: nil
# End:
