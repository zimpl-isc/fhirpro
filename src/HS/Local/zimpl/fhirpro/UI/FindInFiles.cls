/**
* Search for a string in classes.
*
* @version 1.0 2024-03-27
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
	<title>FHIR Bundle Visualizer</title>
	#(..MetaTags())#
	#(..LinkJS("jquery-3.7.1.min.js"))#
	#(..LinkJS("jquery.dataTables.min.js"))#
	#(..LinkCSS("jquery.dataTables.min.css"))#
	#(..LinkCSS("DTLViewer.css"))#

<style>
#Controls {
	margin: 1em 0 2em 1em;
}
#Options {
	margin: 0.5em;
}
</style>

<script type="text/javascript">
async function fetchData()
{
	$('#LoadingMessage',window.parent.document).toggle(true);

    const queryRsc  = '/api/atelier/v5/hscustom/action/search';
	let query		= $('#queryString').val();
	let documents	= $('#documents').val();
	let regex		= $('#regex').val();
	let sys			= $('#sys').val();
	let gen			= $('#gen').val();
	let max			= $('#max').val();

	let querystr    = '?query='+query + '&documents='+documents + '&regex='+regex + '&sys='+sys + '&gen='+gen + '&max='+max;
	
	// Fetch
	queryResponse = await fetch(queryRsc+querystr, {cache: "no-cache"})
							.then(response => response.text()
								.then(status = response.status));
	
	if (parseInt(status) !== 200) {
		let tSc = 'Fetch failed with status code: ' + status;
		console.log(tSc);
	} else {
		dataSet = new Array();
		const result = JSON.parse(queryResponse).result
		result.forEach((e)=>{
			let doc=e.doc; 
			e.matches.forEach((m)=>{
				dataSet.push([doc,m.attr||"",m.member||"", jQuery('<div />').text(m.text).html()])
				})
		});
		
		$('#queryResults').DataTable({
			destroy: true,
			language: {
				"search": "Filter rows:"
			},
			columns: [
				{ title: 'Classname' },
				{ title: 'Attr' },
				{ title: 'Member' },
				{ title: 'Text' },
			],
			data: dataSet
		});
	}
	$('#LoadingMessage',window.parent.document).toggle(false);
}

$(document).ready(function(){
	$('#queryString').on('keypress', function(event) {
		if ( event.which == 13 ) {
			$('#searchButton').trigger('click');
		}
	});
});
</script>

</head>
<body>
	<h2>Search in Files</h2>
  	<div id="Controls">
		<input id="queryString" placeholder="search for..." autofocus autocomplete="on"/>
		<button id="searchButton" onclick="fetchData()">Search</button>
		<div id="Options">
			<input id="documents" value="*.cls,*.mac"/><br>

			<input type="checkbox" id="sys">
				<label for="sys">System items</label><br>

			<input type="checkbox" id="regex" checked>
				<label for="regex">Regular expression</label><br>

			<input type="checkbox" id="gen">
				<label for="gen">Generated items</label><br>

			<input type="number" id="max" size="4" value="200">
				<label for="max">Maximum rows</label><br>
		</div>
    </div>
	<div id="Results">
		<table id="queryResults" class="display" width="100%"></table>
	</div>
</body>
</html>>

	return $$$OK
}

}
