/**
* Search for a string in classes.
*
* @version 1.0 2024-07-31
* @author Brandon Thomas

API Doc:
/// Input request:
/// <pre>
/// GET localhost:57772/api/atelier/v2/:namespace/action/search?query=expr&documents=list&sys=1&gen=1&amp;regex=1&max=200
/// </pre>
/// Required arguments are:<br>
/// query = the search expression, a regular expression or a plain text string<br>
/// documents = a comma-separated list of documents or masks with the * wild card<br>
/// <br>
/// Optional arguments are:<br>
/// regex = 0 or 1 (default 1) whether the query string is a regular expression or not<br>
/// sys = 0 or 1 (default 0) include sytem documents in the search<br>
/// gen = 0 or 1 (default 0) include generated documents in the search<br>
/// max = nnn (default 200) maxinum number of results to return<br>
/// <br>
/// The result is returned as the console output of the search and as a JSON array.<br>
/// <br>
/// Example input to search for the word Email in all classes and MAC routines:
/// <pre>
/// GET localhost:57772/api/atelier/v2/SAMPLES/action/search?query=.*\bEmail\b.*&documents=*.cls,*.mac
/// </pre>

*/

Class HS.Local.zimpl.fhirpro.UI.FindInFiles Extends HS.Local.zimpl.fhirpro.UI.Super
{

ClassMethod OnPage() As %Status
{

	&html<<!DOCTYPE html>
<html>
<head>
	<title>Find In Files</title>
	#(..LinkJS("jquery-3.7.1.min.js"))#
	#(..LinkJS("jquery.dataTables.min.js"))#
	#(..LinkCSS("jquery.dataTables.min.css"))#
	#(..LinkCSS("DTLViewer.css"))#
	#(..DefaultStyle())#

<style>
body {padding:5px;}
h2 {display:none;}
#Controls {
	margin: 1em 0 2em 1em;
}
#filterForUnique {
	float: right;
	margin-right: 1em;
}
tr.odd,tr.even {
	cursor: pointer;
}
svg.active {
	filter: drop-shadow(0px 0px 2px #333695);
}
</style>

<script type="text/javascript">
async function ApiSearch()
{
	$('#LoadingMessage',window.parent.document).toggle(true);

	const host		= $('#host').val();
	const namespace	= $('#namespace').val();
    const apiRsc	= host+'/api/atelier/v5/'+namespace+'/action/search';
	
	let query		= encodeURI($('#queryString').val());
	let documents	= encodeURI($('#documents').val());
	let regex		= $('#regex').val()==="on";
	let sys			= $('#sys').val()==="on";
	let gen			= $('#gen').val()==="on";
	let max			= $('#max').val();

	let querystr    = '?query='+query + '&documents='+documents + '&regex='+regex + '&sys='+sys + '&gen='+gen + '&max='+max;
	
	// Fetch
	let headers = new Headers();
	headers.set('Authorization', 'Basic ' + btoa('_system' + ":" + 'SYS'));

	queryResponse = await fetch(apiRsc+querystr, {cache: "no-cache", method:'GET', headers:headers})
							.then(response => response.text()
								.then(status = response.status));
	
	if (parseInt(status) !== 200) {
		let tSc = 'Fetch failed with status code: ' + status;
		console.log(tSc);
	} else {
		const results = JSON.parse(queryResponse).result;
		dataSet = new Array();
		dataSet.filtered = false;
		results.forEach((result) => {
			result.matches.forEach((match) => {
				dataSet.push([result.doc, match.attr||"", match.member||"", escapeHTML(match.text)]);
			});
		});

		drawTable(dataSet);
	}
	$('#LoadingMessage',window.parent.document).toggle(false);
}

function drawTable(pData) {
	let query		= encodeURI($('#queryString').val());
	let namespace	= $('#namespace').val();

	$('#queryResults').DataTable({
			destroy: true,
			language: {
				"search": "Filter rows:"
			},
			columns: [
				{ title: 'Classname', render: function (data, type, row, meta) {
    											return "<a href='HS.Local.zimpl.fhirpro.UI.FileViewer.cls?doc="+data+"&ns="+namespace+"&st="+query+"' target=_blank>"+data+'</a>';
												}
      			},
				{ title: 'Attr' },
				{ title: 'Member' },
				{ title: 'Text' },
			],
			data: pData
		});

		$('#queryResults th').first().html($('#queryResults th').first().html() + '<a id="filterForUnique">');
		$('#filterForUnique').html('<svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" fill="white" viewBox="0 0 16 16"><path d="M1.5 1.5A.5.5 0 0 1 2 1h12a.5.5 0 0 1 .5.5v2a.5.5 0 0 1-.128.334L10 8.692V13.5a.5.5 0 0 1-.342.474l-3 1A.5.5 0 0 1 6 14.5V8.692L1.628 3.834A.5.5 0 0 1 1.5 3.5zm1 .5v1.308l4.372 4.858A.5.5 0 0 1 7 8.5v5.306l2-.666V8.5a.5.5 0 0 1 .128-.334L13.5 3.308V2z"></path></svg>');
		$('#filterForUnique').on('click', distill);

		return "ok"
}

function distill() {
	/// https://stackoverflow.com/questions/9229645/remove-duplicate-values-from-js-array
	function uniqBy(a, key) {
		var seen = {};
		return a.filter(function(item) {
			var k = key(item[0]);
			return seen.hasOwnProperty(k) ? false : (seen[k] = true);
		})
	}

	// toggle between filtered and unfiltered values
	if (dataSet.filtered) {
		dataSet.filtered = false;
		drawTable(dataSet);

	} else {
		dataSet.filtered = true;
		let dataSetDistilled = uniqBy(dataSet,JSON.stringify);
		let drawComplete = drawTable(dataSetDistilled);
		$('#filterForUnique svg').addClass('active');
	}	
}

function escapeHTML(html) {
	return jQuery('<div />').text(html).html()
}
$(document).ready(function() {
        //$('#host').val(window.location.origin);
		$('#host').val(window.location.href.split('/csp')[0]);
    });

</script>

</head>
<body>
	<h2>Find in Files</h2>
  	<form id="Controls" onsubmit="ApiSearch(); return false;">
		<input id="host" title="host"><input id="namespace" value="hscustom" title="namespace">
		<input id="queryString" placeholder="search for..." autofocus autocomplete/>
		<input type="submit"/>
		<fieldset class="infoBox">
        	<legend>options</legend>
			<input id="documents" value="HS.Local.*.cls" title="search in documents..."/>
			<span class="comment">comma-delimited list (e.g. *.cls,*.mac,*.int)</span>
			<br>

			<input type="checkbox" id="sys">
				<label for="sys">System items</label><br>

			<input type="checkbox" id="regex" checked>
				<label for="regex">Regular expression</label><br>

			<input type="checkbox" id="gen">
				<label for="gen">Generated items</label><br>

			<input type="number" id="max" size="5" value="200" step="100">
				<label for="max">Maximum rows</label><br>
		</fieldset>
    </form>
	<div id="Results">
		<table id="queryResults" class="display" width="100%"></table>
	</div>
</body>
</html>>

	return $$$OK
}

}
