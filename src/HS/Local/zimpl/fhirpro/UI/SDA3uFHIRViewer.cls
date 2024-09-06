/**
* Displays a comparison of SDA3 and FHIR data.
*
* @version 2.0 2024-09-01
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
	#(..LinkJS("jquery-ui-1.13.3.min.js"))#
	#(..XDataJS("BeautifyJS"))#
	#(..XDataJS("StorageHandler"))#
	#(..LinkJS("highlight.min.js"))#
	#(..LinkJS("hightlight.xml.js"))#
    #(..LinkJS("highlightjs-line-numbers.min.js"))#
    #(..LinkCSS("highlight.min.css"))#

	#(..DefaultStyle())#
		
<style>
body {background-image:none;}
#Controls {
	position: fixed;
	top: 0;
	right: 10em;
	cursor: move;
}
#container {
	/*height:98vh;*/
	width: 100%;
	display: flex;
}
pre, code {
	padding-top: 0;
	margin-top: 0;
}
#separator {
	cursor: col-resize;
	background-color: #aaa;
	background-image: url("data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' width='10' height='30'><path d='M2 0 v30 M5 0 v30 M8 0 v30' fill='none' stroke='black'/></svg>");
	background-repeat: no-repeat;
	background-position: center;
	min-width: 5px;
	min-height: 100%;

	/* Prevent the browser's built-in drag from interfering */
	-moz-user-select: none;
	-ms-user-select: none;
	user-select: none;
}

#sdaSource {
	background-color: rgba(51, 54, 149, 0.01);
	height: 100%;
	min-width: 10px;
}

#fhirSource {
	background-color: rgba(0, 181, 175, 0.01);
	height: 100%;
	min-width: 10px;
}
.highlight {
	background-color: aqua;
}
</style>
		
<script type="text/javascript">
$(document).ready(function(){
	dragElement( document.getElementById("separator"), "H" );
	parse();
	hljs.highlightAll();
	hljs.initLineNumbersOnLoad();

	setTimeout(() => {
        $('.hljs-xmlval, .hljs-string').on('dblclick', highlightUserSelection);
    }, 1000);

	$('fieldset.infoBox').draggable();
});

function escapeHTML(html) {
	return jQuery('<div />').text(html).html()
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
		$('#sdaSource').html(escapeHTML(tSDA, ' '));
	}

	let tFHIR = getFhirData();
	if (tFHIR === null) {
		console.log("No FHIR data found in localStorage. Search for a patient first.");
	} else {
		$('#fhirSource').html(vkbeautify.json(tFHIR, ' '));
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
function hscroll(direction = '+')
{
    if (direction === '+') {
        currentHighlight = currentHighlight+1;
        if (currentHighlight > (foundTerm.length-1)) {
            currentHighlight = 0;
        }
    } else {
        currentHighlight = currentHighlight-1;
        if (currentHighlight < 0) {
            currentHighlight = foundTerm.length-1;
        }
    }
    $('#currentFound').text(currentHighlight+1);
    $('html').animate({scrollTop:foundTerm[currentHighlight] },800);
}
function highlightUserSelection(jQueryEle) {
	console.log($(this).text());
	$('#searchTerm').val($(this).text());
	highlightSearchTerm($(this).text());
}
function highlightSearchTerm(searchTerm)
{
    if (searchTerm==="" || searchTerm===null) {
        return
    }

	$('.highlight').removeClass('highlight');

    const regx = new RegExp(String.raw`${searchTerm}`, "g");

    foundTerm = new Array();

    $('.hljs-xmlval, .hljs-string').each(function(iter,blk){
        if ($(this).html().match(regx)) {
            console.log(iter,$(this).offset().top);
            foundTerm.push($(this).offset().top);
            //$(this).html($(this).html().replaceAll(searchTerm, '<mark>'+searchTerm+'</mark>'));
			$(this).addClass('highlight');
            currentHighlight = -1;
        }
        
    });

    $('#totalFound').text(foundTerm.length);
    hscroll('+');
}
</script>
</head>
	<body>
	<fieldset class="infoBox" id="Controls">
		<legend>&#8984; find</legend>
        <!--span id="currentDoc"></span><br-->
		<table><tr>
		<td><form onsubmit="highlightSearchTerm($('#searchTerm').val()); return false;">
            <input id="searchTerm" autofocus />
        </form></td>
        <td><button onclick="hscroll('-')">&lt;</button></td>
        <td><button onclick="hscroll('+')">&gt;</button></td>
		</tr></table>
            <br>
        <button onclick="$('html').animate({scrollTop:0},800);">&#10514;</button>
        <button onclick="$('html').animate({scrollTop:$(document).height()},800);">&#10515;</button>
        <span class="comment">line <span id="currentFound"></span> of <span id="totalFound"></span></span>
	</fieldset>
		<div id="container">
			<div><pre><code id="sdaSource" class='language-xml' autocomplete="off" readonly placeholder="SDA Data..."></code></pre></div>
			<div id="separator" ></div>
			<div><pre><code id="fhirSource" class='language-json' autocomplete="off" readonly placeholder="FHIR Data..."></code></pre></div>
		</div>	
	</body>
	</html>>

	return $$$OK
}

}
