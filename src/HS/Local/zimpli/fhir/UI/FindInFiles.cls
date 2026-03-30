Class HS.Local.zimpli.fhir.UI.FindInFiles Extends HS.Local.zimpli.fhir.UI.Super
{

ClassMethod OnPage() As %Status
{

	&html<<!DOCTYPE html>
<html>
<head>
	<title>Find In Files</title>
	#(..MetaTags())#
	#(..LinkJS("assets/ext/jquery-3.7.1.min.js"))#
	#(..LinkJS("assets/ext/jquery.dataTables.min.js"))#
	#(..LinkCSS("assets/ext/jquery.dataTables.min.css"))#
	#(..LinkJS("assets/FindInFiles.js"))#
	#(..DefaultStyle())#
	#(..LinkCSS("assets/FindInFiles.css"))#
</head>
<body>
<div id="pageShell">
	<div class="card toolbarCard">
		<form id="Controls" onsubmit="ApiSearch(); return false;">
			<div class="formGrid">
				<div class="fieldGroup">
					<label for="host">Host</label>
					<input id="host" type="text" title="host">
				</div>

				<div class="fieldGroup">
					<label for="namespace">Namespace</label>
					<input id="namespace" type="text" value="hscustom" title="namespace">
				</div>

				<div class="fieldGroup">
					<label for="queryString">Search expression</label>
					<input id="queryString" type="text" placeholder="search for..." autofocus>
				</div>

				<div class="fieldGroup">
					<label>&nbsp;</label>
					<input class="primaryButton" type="submit" value="Search">
				</div>
			</div>

			<div class="optionsGrid">
				<div class="fieldGroup">
					<label for="documents">Documents</label>
					<input id="documents" type="text" value="HS.Local.*.cls" title="search in documents...">
					<span class="comment">Comma-delimited list, e.g. *.cls,*.mac,*.int</span>
				</div>

				<div class="checkboxRow">
					<input type="checkbox" id="sys">
					<label for="sys">System items</label>
				</div>

				<div class="checkboxRow">
					<input type="checkbox" id="regex" checked>
					<label for="regex">Regular expression</label>
				</div>

				<div class="checkboxRow">
					<input type="checkbox" id="gen">
					<label for="gen">Generated items</label>
				</div>

				<div class="fieldGroup">
					<label for="max">Maximum rows</label>
					<input type="number" id="max" value="200" step="100">
				</div>
			</div>
		</form>
	</div>

	<div class="card resultsCard">
		<div class="resultsHeader">
			<div class="resultsTitle">Search results</div>
		</div>
		<table id="queryResults" class="display hover" width="100%"></table>
	</div>

	<div id="iframe-tooltip-container">
		<iframe id="tooltip-iframe" src="" frameborder="0"></iframe>
	</div>

</div>
</body>
</html>>

	return $$$OK
}

}
