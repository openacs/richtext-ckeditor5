<!DOCTYPE html>
<html lang="en">
    <head>
	<meta charset="UTF-8">
	<title>@title@</title>
	<script type="text/javascript" <if @::__csp_nonce@ not nil> nonce="@::__csp_nonce;literal@"</if>>
	 // Helper function to get parameters from the query string.
	 function getUrlParam( paramName ) {
	     var reParam = new RegExp( '(?:[\?&]|&)' + paramName + '=([^&]+)', 'i' );
	     var match = window.location.search.match( reParam );
	     return ( match && match.length > 1 ) ? match[1] : null;
	 }

	 // Simulate user action of selecting a file to be returned to CKEditor.
	 function returnFileUrl(fileUrl, altText) {
	     var funcNum = getUrlParam( 'CKEditorFuncNum' );
	     window.opener.CKEDITOR.tools.callFunction( funcNum, fileUrl, function() {
		 // Get the reference to a dialog window.
		 var dialog = this.getDialog();
		 // Check if this is the Image Properties dialog window.
		 if ( dialog.getName() == 'image' ) {
		     // Get the reference to a text field that stores the "alt" attribute.
		     var element = dialog.getContentElement( 'info', 'txtAlt' );
		     // Assign the new value.
		     if ( element )
			 element.setValue( altText );
		 }
		 // Return "false" to stop further execution. In such case CKEditor will ignore the second argument ("fileUrl")
		 // and the "onSelect" function assigned to the button that called the file manager (if defined).
		 // return false;
	     } );
	     window.close();
	 }
	</script>

	<style>
	 div {
	     display: flex;
	     flex-wrap: wrap;
	 }
	</style>
    </head>
    <body>
	<h2>@page_title@</h2>

	<if @images:rowcount@ gt 0>
	<div>
	    <multiple name="images">
		<figure>
		    <a href="#"><img class="selectable" src="@images.src;noi18n@" alt="@images.alt@"></a>
		</figure>
	    </multiple>
	</div>
	</if>
	<else>
	    <p>@no_attachment@</p>
	</else>

	<p><button class="quit">quit</button></p>
	<script type="text/javascript" <if @::__csp_nonce@ not nil> nonce="@::__csp_nonce;literal@"</if>>
	 var elems = document.getElementsByClassName('selectable');
	 for (var i = 0, l = elems.length; i < l; i++) {
	     var e = elems[i];
	     e.addEventListener('click', function (event) {
		 event.preventDefault();
		 console.log(event);
		 var t = event.target;
		 console.log(t);
		 returnFileUrl(t.getAttribute('src'), t.getAttribute('alt'));
	     });
	 }
	 var elems = document.getElementsByClassName('quit');
	 for (var i = 0, l = elems.length; i < l; i++) {
	     var e = elems[i];
	     e.addEventListener('click', function (event) {
		 window.close();
	     });
	 }
	</script>
    </body>
</html>

<!--
     Local Variables:
     mode: html
     indent-tabs-mode: nil
     End:
   -->
