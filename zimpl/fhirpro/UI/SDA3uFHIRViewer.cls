/**
* Displays a comparison of SDA3 and FHIR data.
*
* @version 1.0 2024-03-27
* @author Brandon Thomas
*/

Class HS.Local.zimpl.fhirpro.UI.SDA3uFHIRViewer Extends HS.Local.zimpl.fhirpro.UI.Super
{

/// Event handler for <b>PAGE</b> event: this is invoked in order to  
/// generate the content of a csp page.
ClassMethod OnPage() As %Status [ ServerOnly = 1 ]
{
	&html<<!DOCTYPE HTML>
<html>
<head>
	<title>HSFHIRToolkit | SDA3 & FHIR</title>
	#(..MetaTags())#
	#(..LinkJS("jquery-3.7.1.min.js"))#
	#(..XDataJS("BeautifyJS"))#
	#(..XDataJS("StorageHandler"))#
	#(..DefaultStyle())#
		
	<style>
	body {background-image:none;}
	textarea {
		width: 100%;
		height: 100%;
		overflow: scroll;
	}
	#container {
		height:98vh;
    	width: 100%;
    	display: flex;
	}

	#separator {
	    cursor: col-resize;
	    background-color: #aaa;
	    background-image: url("data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' width='10' height='30'><path d='M2 0 v30 M5 0 v30 M8 0 v30' fill='none' stroke='black'/></svg>");
	    background-repeat: no-repeat;
	    background-position: center;
	    width: 5px;
	    height: 100%;

	    /* Prevent the browser's built-in drag from interfering */
	    -moz-user-select: none;
	    -ms-user-select: none;
	    user-select: none;
	}

	#sdaSource {
	    background-color: rgba(51, 54, 149, 0.01);
	    width: 20%;
	    height: 100%;
	    min-width: 10px;
	}

	#fhirSource {
	    background-color: rgba(0, 181, 175, 0.01);
	    width: 80%;
	    height: 100%;
	    min-width: 10px;
	}
</style>
		
<script type="text/javascript">
$(document).ready(function(){
	dragElement( document.getElementById("separator"), "H" );
	parse();
	/* TODO: create components to display and highlight search terms of the sda and fhir
			reference: https://css-tricks.com/creating-an-editable-textarea-that-supports-syntax-highlighted-code/
	$('.textarea').on('dblclick', function(ele){
		
		let searchTerm = window.getSelection().toString();
		console.log('this', $(this));
		console.log($(this).parent().attr('id'), searchTerm);
		searchHighlight($(this).parent().attr('id'), searchTerm);
		
	});
	*/
});

function searchHighlight(sourceTextArea, searchTerm) {
	let targetTextArea = (sourceTextArea==='sdaSource') ? 'fhirSource':'sdaSource';
	let regex = new RegExp(`(${searchTerm})`, "gi");
	let text = $('#'+targetTextArea).val();
	console.log(text.match(regex));
	
	let parts = text.split(regex);
	let highlightedText = parts
        .map((part) =>
          part.match(regex)
            ? `<span style="background-color: yellow;">${part}</span>`
            : part
        )
        .join("");
      // Replace the original text with the highlighted version
      $('#'+targetTextArea).html(highlightedText);
}

function parse() {
		
	let tMpiid = getMpiid();
	if (tMpiid == "") {
		console.log("No MPIID found in current session. Search for a patient first.");
		return
	}
	
	let tSDA = getSdaData();
	if (tSDA === null) {
		console.log("No SDA data found in localStorage. Search for a patient first.");
	} else {
		$('#sdaSource').val(vkbeautify.xml(tSDA, ' '));
		//$('#sdaSource').html('<xmp class="textarea"><?xml version="1.0" encoding="UTF-8"?>'+vkbeautify.xml(tSDA, ' ')+'</xmp>');
	}

	let tFHIR = getFhirData();
	if (tFHIR === null) {
		console.log("No FHIR data found in localStorage. Search for a patient first.");
	} else {
		$('#fhirSource').val(vkbeautify.json(tFHIR, ' '));
		//$('#fhirSource').html('<pre class="textarea">'+vkbeautify.json(tFHIR, ' ')+'</pre>');
	}
	
}
function dragElement(element, direction) {
    var   md; // remember mouse down info
    const first  = document.getElementById("sdaSource");
    const second = document.getElementById("fhirSource");

    element.onmousedown = onMouseDown;

	function onMouseDown(e) {
		//console.log("mouse down: " + e.clientX);
		md = {e:e,
		      offsetLeft:  element.offsetLeft,
		      offsetTop:   element.offsetTop,
		      firstWidth:  first.offsetWidth,
		      secondWidth: second.offsetWidth
		     };

		document.onmousemove = onMouseMove;
		document.onmouseup = () => {
		    //console.log("mouse up");
		    document.onmousemove = document.onmouseup = null;
		}
	}

	function onMouseMove(e) {
		//console.log("mouse move: " + e.clientX);
		var delta = {x: e.clientX - md.e.clientX,
		             y: e.clientY - md.e.clientY};

		if (direction === "H" ) // Horizontal
		{
		    // Prevent negative-sized elements
		    delta.x = Math.min(Math.max(delta.x, -md.firstWidth),
		               md.secondWidth);

		    element.style.left = md.offsetLeft + delta.x + "px";
		    first.style.width = (md.firstWidth + delta.x) + "px";
		    second.style.width = (md.secondWidth - delta.x) + "px";
		}
	}
}
</script>
</head>
	<body>
		<div id="container">
			<textarea id="sdaSource" autocomplete="off" readonly placeholder="SDA Data..."></textarea>
			<div id="separator" ></div>
			<textarea id="fhirSource" autocomplete="off" readonly placeholder="FHIR Data..."></textarea>
			<!--div id="sdaSource" autocomplete="off" readonly placeholder="SDA Data..."></div>
			<div id="separator" ></div>
			<div id="fhirSource" autocomplete="off" readonly placeholder="FHIR Data..."></div-->
		</div>	
	</body>
	</html>>

	return $$$OK
}

}
