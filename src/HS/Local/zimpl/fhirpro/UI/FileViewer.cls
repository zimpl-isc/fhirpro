/**
* Viewer for cls,int,mac
* with highlighting and hyperlinks where possible
*
* @version 1.0beta 2024-08-30
* @author Brandon Thomas
*/

Class HS.Local.zimpl.fhirpro.UI.FileViewer Extends HS.Local.zimpl.fhirpro.UI.Super
{

ClassMethod OnPage() As %Status
{
	&html<<!DOCTYPE html>
<html>
<head>
	<title>File Viewer</title>
	#(..LinkJS("jquery-3.7.1.min.js"))#
    #(..LinkJS("jquery-ui-1.13.3.min.js"))#
	#(..LinkJS("highlight.min.js"))#
    #(..LinkJS("highlight.cos.js"))#
    #(..LinkJS("highlightjs-line-numbers.min.js"))#
    #(..LinkCSS("highlight.min.css"))#
	#(..DefaultStyle())#

<style>
pre {
	margin-top: 0;
}
pre code.hljs {
    padding-top:0;
}
a {
	cursor: pointer;
}
#Controls {
	position: fixed;
	top: 0;
	right: 10em;
    cursor: move;
}
form {
	display: inline;
}
#currentDoc {
	font-weight: bolder;
}
.comment {
	float: right;
	margin-right: 1em;
}
.hljs-name {
	color: blue !important;
}
td.hljs-ln-numbers {
	padding-right: 0.5em;
	color: lightslategray;
	border-right: 2px dashed lightgray;
}
td.hljs-ln-code {
	padding-left: 0.75em;
}
.hljs-ISC_ClassMember, .hljs-ISC_System {
	color: blue;
}
.hljs-ISC_Macro, .hljs-ISC_Method {
    color: rgb(79,56,15);
}
.hljs-keyword {
    font-weight: initial;
}
.hljs-ISC_Variable {
	color: cornflowerblue;
}
.hljs-comment {
	color: darkgreen;
}
.hljs-ISC_Function {
    color: blue;
}
.hljs-ISC_MethodParameter {
	color: purple;
}
.hljs-ISC_ClassName a, .hljs-ISC_Include a {
	color: teal;
	text-decoration: none;
}
.hljs-ISC_ClassName a:hover, .hljs-ISC_Include a:hover {
	text-decoration: underline;
}
</style>

<script type="text/javascript">
var ns;
$(document).ready(function() {
    currentHighlight=0;
    const params    = new URLSearchParams(location.search);
    const doc       = params.get("doc");
    const st        = params.get("st");
    ns              = params.get("ns");
    $('#currentDoc').text(doc);
    $('#searchTerm').val(st);
    ApiGetDoc();
    setTimeout(() => {
        highlightSearchTerm(st);
        }, "2000");
    $('fieldset.infoBox').draggable();
    $('#searchTerm').select();
    
    /*
        if (temp0.nextElementSibling.className === 'hljs-ISC_Method') {
            // let searchterm = temp0.nextElementSibling.innerText 
        }
    */
    setTimeout(() => {
        $('.hljs-ISC_ClassName').each(function(ix){
            console.log('add link #'+ix);
            $(this).html( "<a title='&#10548; "+$(this).text()+"' target=_blank onclick='openPage(\""+$(this).text()+".cls\")'>"+ $(this).text() +"</a>");
        });
    }, 1000);

    setTimeout(() => {
        $('.hljs-ISC_Include').each(function(ix){
            console.log('add link #'+ix);
            $(this).html( "<a title='&#10548; "+$(this).text()+"' target=_blank onclick='openPage(\""+$(this).text()+".inc\")'>"+ $(this).text() +"</a>");
        });
    }, 1000);

    

});
function openPage(pageName) {
    console.log(pageName);
    console.log($('#searchTerm').val());
    window.open('?doc='+pageName+'&ns='+ns+'&st='+$('#searchTerm').val(), '_blank');
    return false
}
function escapeHTML(html) {
	return jQuery('<div />').text(html).html()
}
async function ApiGetDoc(namespace,documentName,searchTerm)
{
    const params    = new URLSearchParams(location.search);
    const doc       = documentName  || params.get("doc");
    const ns        = namespace     || params.get("ns");
    const st        = searchTerm    || params.get("st");
	const api   	= '/api/atelier/v5/'+ns+'/doc/' + encodeURI(doc);

	// Fetch
	queryResponse = await fetch(api, {cache: "no-cache"})
							.then(response => response.text()
								.then(status = response.status));
	
	if (parseInt(status) !== 200) {
		let tSc = 'Fetch failed with status code: ' + status;
		console.log(tSc);
	} else {
		const results = JSON.parse(queryResponse).result;
        let html = "";
		results.content.forEach((codeLine) => {
			html += escapeHTML(codeLine)+'\n';
		});
        $('pre code').html(html);
        highlightSyntax();
    }
}
function highlightSyntax()
{
    hljs.highlightAll();
    hljs.initLineNumbersOnLoad();
}
function removeHighlightSearch()
{
    currentHighlight = 0;
    delete foundTerm;
    $('mark').each(function(){
        $(this).replaceWith( $(this).text() );
    });
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
function highlightSearchTerm(searchTerm = $('#searchTerm').val())
{
    if (searchTerm==="" || searchTerm===null) {
        return
    }

    removeHighlightSearch();

    const regx = new RegExp(String.raw`${searchTerm}`, "g");

    foundTerm = new Array();

    $('.hljs-ln-code').each(function(iter,blk){
        if ($(this).html().match(regx)) {
            console.log(iter,$(this).offset().top);
            foundTerm.push($(this).offset().top);
            $(this).html($(this).html().replaceAll(searchTerm, '<mark>'+searchTerm+'</mark>'));
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
        <span id="currentDoc"></span><br>
		<form onsubmit="highlightSearchTerm(); return false;">
            <input id="searchTerm" autofocus />
        </form>
            <button onclick="hscroll('-')">&lt;</button>
            <button onclick="hscroll('+')">&gt;</button>
            <br>
            <button onclick="$('html').animate({scrollTop:0},800);">&#10514;</button>
            <button onclick="$('html').animate({scrollTop:$(document).height()},800);">&#10515;</button>
            <span class="comment">line <span id="currentFound"></span> of <span id="totalFound"></span></span>
	</fieldset>
    <pre><code class='language-cos'></code></pre>
</body>
</html>
>

    return $$$OK
}

}
