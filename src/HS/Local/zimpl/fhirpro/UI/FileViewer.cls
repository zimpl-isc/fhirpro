Class HS.Local.zimpl.fhirpro.UI.FileViewer Extends HS.Local.zimpl.fhirpro.UI.Super
{

ClassMethod OnPage() As %Status
{
    set tClassname = $get(%request.Data("classname",1))

	&html<<!DOCTYPE html>
<html>
<head>
	<title>File Viewer</title>
	#(..LinkJS("jquery-3.7.1.min.js"))#
	#(..LinkJS("highlight.min.js"))#
    #(..LinkJS("highlightjs-line-numbers.min.js"))#
    #(..LinkCSS("highlight.min.css"))#
	#(..DefaultStyle())#

<style>
#Controls {
	position: fixed;
	top: 0;
	right: 10em;
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
</style>

<script type="text/javascript">
$(document).ready(function() {
    currentHighlight=0;
    const params    = new URLSearchParams(location.search);
    const doc       = params.get("doc");
    const st        = params.get("st");
    $('#currentDoc').text(doc);
    $('#searchTerm').val(st);
    ApiGetDoc();
    setTimeout(() => {
        highlightSearchTerm(st);
        }, "1000");
    });
function escapeHTML(html) {
	return jQuery('<div />').text(html).html()
}
async function ApiGetDoc(namespace,documentName,searchTerm)
{
    const params    = new URLSearchParams(location.search);
    const doc       = documentName  || params.get("doc");
    const ns        = namespace     || params.get("ns");
    const st        = searchTerm    || params.get("st");
	const api   	= '/api/atelier/v5/'+ns+'/doc/'+doc;

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
        let wait = highlightSyntax();
    }
}
function highlightSyntax()
{
    hljs.highlightAll();
    hljs.initLineNumbersOnLoad();

    return 1
}
function highlightSearchTerm(searchTerm = $('#searchTerm').val())
{
    if (searchTerm==="") {
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
</script>
</head>
<body>
    <fieldset class="infoBox" id="Controls">
		<legend>&#8984; find</legend>
        <span id="currentDoc"></span><br>
		<form onsubmit="highlightSearchTerm(); return false;">
            <input id="searchTerm">
        </form>
            <button onclick="hscroll('-')">&lt;</button>
            <button onclick="hscroll('+')">&gt;</button>
            <br><span class="comment">line <span id="currentFound"></span> of <span id="totalFound"></span></span>
	</fieldset>
    <pre><code class='language-cos'></code></pre>
</body>
</html>
>

    return $$$OK
}

}
