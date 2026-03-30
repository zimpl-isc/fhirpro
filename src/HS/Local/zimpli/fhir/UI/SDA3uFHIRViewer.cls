/**
* Displays a comparison of SDA3 and FHIR data.
*
* @version 2.0 2024-09-01
* @author Brandon Thomas
*/

Class HS.Local.zimpli.fhir.UI.SDA3uFHIRViewer Extends HS.Local.zimpli.fhir.UI.Super
{

ClassMethod OnPage() As %Status [ ServerOnly = 1 ]
{
	&html<<!DOCTYPE HTML>
<html>
<head>
	<title>SDA3 & FHIR Viewer</title>
	#(..MetaTags())#
	#(..LinkJS("assets/ext/jquery-3.7.1.min.js"))#
	#(..LinkJS("assets/ext/jquery-ui-1.13.3.min.js"))#
	#(..XDataJS("BeautifyJS"))#
	#(..XDataJS("StorageHandler"))#
	#(..LinkJS("assets/ext/highlight.min.js"))#
	#(..LinkJS("assets/ext/highlight.xml.js"))#
    #(..LinkJS("assets/ext/highlightjs-line-numbers.min.js"))#
    #(..LinkCSS("assets/ext/highlight.min.css"))#

	#(..LinkJS("assets/SDA3uFHIRViewer.js"))#
	#(..DefaultStyle())#
	#(..LinkCSS("assets/SDA3uFHIRViewer.css"))#
</head>
<body>
<fieldset class="infoBox" id="Controls">
	<legend>&#128270; find</legend>
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
