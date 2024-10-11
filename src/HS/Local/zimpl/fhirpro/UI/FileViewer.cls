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
	<title>#($piece($get(%request.Data("doc",1)), ".", *-1))#</title>
    <link rel="shortcut icon" href="data:image/svg+xml, <svg width='30px' height='30px' viewBox='0 -0.5 25 25' fill='none' xmlns='http://www.w3.org/2000/svg'><path fill-rule='evenodd' clip-rule='evenodd' d='M11.132 9.71395C10.139 11.2496 10.3328 13.2665 11.6 14.585C12.8468 15.885 14.8527 16.0883 16.335 15.065C16.6466 14.8505 16.9244 14.5906 17.159 14.294C17.3897 14.0023 17.5773 13.679 17.716 13.334C18.0006 12.6253 18.0742 11.8495 17.928 11.1C17.7841 10.3573 17.4268 9.67277 16.9 9.12995C16.3811 8.59347 15.7128 8.22552 14.982 8.07395C14.2541 7.92522 13.4982 8.00197 12.815 8.29395C12.1254 8.58951 11.5394 9.08388 11.132 9.71395Z' stroke='%23000000' stroke-width='1.5' stroke-linecap='round' stroke-linejoin='round'></path><path d='M17.5986 13.6868C17.2639 13.4428 16.7947 13.5165 16.5508 13.8513C16.3069 14.1861 16.3806 14.6552 16.7154 14.8991L17.5986 13.6868ZM19.0584 16.6061C19.3931 16.85 19.8623 16.7764 20.1062 16.4416C20.3501 16.1068 20.2764 15.6377 19.9416 15.3938L19.0584 16.6061ZM7.5 12.7499C7.91421 12.7499 8.25 12.4142 8.25 11.9999C8.25 11.5857 7.91421 11.2499 7.5 11.2499V12.7499ZM5.5 11.2499C5.08579 11.2499 4.75 11.5857 4.75 11.9999C4.75 12.4142 5.08579 12.7499 5.5 12.7499V11.2499ZM7.5 15.7499C7.91421 15.7499 8.25 15.4142 8.25 14.9999C8.25 14.5857 7.91421 14.2499 7.5 14.2499V15.7499ZM5.5 14.2499C5.08579 14.2499 4.75 14.5857 4.75 14.9999C4.75 15.4142 5.08579 15.7499 5.5 15.7499V14.2499ZM8.5 9.74994C8.91421 9.74994 9.25 9.41415 9.25 8.99994C9.25 8.58573 8.91421 8.24994 8.5 8.24994V9.74994ZM5.5 8.24994C5.08579 8.24994 4.75 8.58573 4.75 8.99994C4.75 9.41415 5.08579 9.74994 5.5 9.74994V8.24994ZM16.7154 14.8991L19.0584 16.6061L19.9416 15.3938L17.5986 13.6868L16.7154 14.8991ZM7.5 11.2499H5.5V12.7499H7.5V11.2499ZM7.5 14.2499H5.5V15.7499H7.5V14.2499ZM8.5 8.24994H5.5V9.74994H8.5V8.24994Z' fill='%23000000'></path></svg>">
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
	cursor: alias;
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
    
    $('fieldset.infoBox').draggable();
    $('#searchTerm').select();
    
    /*
        if (temp0.nextElementSibling.className === 'hljs-ISC_Method') {
            // let searchterm = temp0.nextElementSibling.innerText 
        }
    */
    setTimeout(() => {
        $('.hljs-ISC_ClassName').each(function(ix){
            //console.log('add link #'+ix);
            $(this).html( "<a title='&#10548; "+$(this).text()+"' target=_blank onclick='openPage(\""+$(this).text()+".cls\")'>"+ $(this).text() +"</a>");
        });
    }, 1000);

    setTimeout(() => {
        $('.hljs-ISC_Include').each(function(ix){
            //console.log('add link #'+ix);
            $(this).html( "<a title='&#10548; "+$(this).text()+"' target=_blank onclick='openPage(\""+$(this).text()+".inc\")'>"+ $(this).text() +"</a>");
        });
    }, 1000);

    setTimeout(() => {
        highlightSearchTerm(st);
        }, "2000");
});
function openPage(pageName) {
    //console.log(pageName);
    //console.log($('#searchTerm').val());
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

    $('body :not(script,#currentDoc)').contents().filter(function() {
        return this.nodeType === 3;
    }).replaceWith(function() {
        if (this.nodeValue == searchTerm) {
            return this.nodeValue.replace(searchTerm,'<mark>'+searchTerm+'</mark>');
        } else {
            return escapeHTML(this.nodeValue);
        }
        
    });

    foundTerm = new Array();

    $('mark').each(function(iter,blk){
        //console.log(iter,$(this).offset().top);
        foundTerm.push($(this).offset().top);
    });
   
    currentHighlight = -1;
    
    $('#totalFound').text(foundTerm.length);
    hscroll('+');
}
</script>
</head>
<body>
    <fieldset class="infoBox" id="Controls">
		<legend>&#128270; find</legend>
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
