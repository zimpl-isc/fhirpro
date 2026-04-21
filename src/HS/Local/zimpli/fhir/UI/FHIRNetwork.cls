/**
* Displays a network visualization of FHIR data.
*
* @version 3.2 2026-03-24
* @author Brandon Thomas
*/

Class HS.Local.zimpli.fhir.UI.FHIRNetwork Extends HS.Local.zimpli.fhir.UI.Super
{

Parameter ValidationEndpointPrefix = "zimpliFHIR:validation:";

ClassMethod GetValidationCatalogJSON() As %String
{
	#dim tStatement As %String
	#dim tResultSet As %SQL.StatementResult
	#dim tArray As %DynamicArray
	#dim tObj As %DynamicObject
	#dim tName As %String
	#dim tCode As %String

	set tStatement = "select name from HS_Registry_Service.HTTP"
		_" where type='HTTP' and status=1"
		_" and name %STARTSWITH '"_..#ValidationEndpointPrefix_"'"
		_" order by name"

	set tResultSet = ##class(%SQL.Statement).%ExecDirect(, tStatement)

	set tArray = ##class(%DynamicArray).%New()

	while tResultSet.%Next() {
		set tName = tResultSet.%GetData(1)
		set tCode = $piece(tName, ..#ValidationEndpointPrefix, 2)
		continue:tCode=""

		set tObj = ##class(%DynamicObject).%New()
		set tObj.code = tCode
		set tObj.label = ..ValidationProfileLabel(tCode)

		do tArray.%Push(tObj)
	}

	quit tArray.%ToJSON()
}

ClassMethod ValidationProfileLabel(pCode As %String) As %String
{
	set pCode = $zconvert($get(pCode), "L")

	if pCode="core" quit "FHIR Core"
	if pCode="mii" quit "MII"
	if pCode="isik" quit "ISiK"
	if pCode="r4core" quit "R4 Core"

	quit $zconvert(pCode, "W")
}

/// Returns CSP URL of the validation endpoint used by the frontend JS.
ClassMethod GetValidationEndpointURL() As %String
{
	quit ..#FHIRValidator
}

/// Returns JSON array of backend tool links from Service Registry
/// Query entries like: zimpliFHIR:links:DTLEditor
ClassMethod GetBackendToolLinksJSON() As %String
{
	#dim tStatement As %String
	#dim tResultSet As %SQL.StatementResult
	#dim tArray As %DynamicArray
	#dim tObj As %DynamicObject
	#dim tName As %String
	#dim tCode As %String
	#dim tURL As %String

	Set tPrefix = "zimpliFHIR:links:"

	Set tStatement = "select name, url from HS_Registry_Service.HTTP"
		_" where type='HTTP' and status=1"
		_" and name %STARTSWITH '"_tPrefix_"'"
		_" order by name"

	Set tResultSet = ##class(%SQL.Statement).%ExecDirect(, tStatement)

	Set tArray = ##class(%DynamicArray).%New()

	While tResultSet.%Next() {
		Set tName = tResultSet.%GetData(1)
		Set tURL = tResultSet.%GetData(2)
		Set tCode = $Piece(tName, tPrefix, 2)
		Continue:tCode=""

		Set tObj = ##class(%DynamicObject).%New()
		Set tObj.code = tCode
		Set tObj.url = tURL
		Set tObj.label = ..BackendToolLabel(tCode)
		Do tArray.%Push(tObj)
	}

	Quit tArray.%ToJSON()
}

/// Returns display label for backend tool code
ClassMethod BackendToolLabel(pCode As %String) As %String
{
	If pCode="DTLEditor" Quit "DTL Editor"
	If pCode="DTLViewer" Quit "DTL Viewer"
	If pCode="OIDMap" Quit "OID Map"
	If pCode="Terminology" Quit "Terminology Viewer"
	Quit pCode
}

ClassMethod OnPage() As %Status
{
	&html<<!DOCTYPE html>
<html>
<head>
	<title>FHIR Network</title>
	#(..MetaTags())#
	#(..LinkJS("assets/ext/jquery-3.7.1.min.js"))#
	#(..LinkJS("assets/ext/vis-network.min.js"))#
	#(..XDataJS("StorageHandler"))#
	#(..LinkJS("assets/FHIRNetwork.js"))#
	#(..DefaultStyle())#
	#(..LinkCSS("assets/FHIRNetwork.css"))#
	<script type="text/javascript">
		window.FHIRNetworkConfig = {
			validationProfiles: #(..GetValidationCatalogJSON())#,
			validationEndpoint: "#(..GetValidationEndpointURL())#"
		};
	</script>
</head>
<body>
<div id="pageShell">
	<div id="networkLayout">

		<div id="mainArea">
			<div id="NetworkCard" class="card">
				<div id="NetworkToolbar">
					<button type="button" id="RailToggleButton" title="Resource types">&#9776;</button>

					<div id="NetworkZoomControls">
						<button type="button" id="ZoomInButton" title="Zoom in">+</button>
						<button type="button" id="ZoomOutButton" title="Zoom out">-</button>
						<button type="button" id="ZoomFitButton" title="Fit network / refresh viewport">&#9974;</button>
					</div>
				</div>

				<div id="VisNetworkPane"></div>
			</div>
		</div>

		<div id="DrawerBackdrop"></div>

		<div id="leftRail" class="drawer">

			<div id="validationControls" class="card">
				<div id="validationControlsHeader">
					<span>Validation</span>
				</div>

				<div id="validationControlsBody">
					<div class="formRow formRow--inline">
						<select id="ValidationProfileSelector">
							<option value="">-- Profile --</option>
						</select>
						<button type="button" id="RunValidationButton">Validate</button>
					</div>

					<div id="ValidationSummary" class="validationSummary is-hidden"></div>
					<div id="ValidationBundleIssues" class="validationBundleIssues is-hidden"></div>
				</div>
			</div>

			<div id="episodeControls" class="card">
				<div id="episodeControlsHeader">
					<span>Episode</span>
				</div>
				<div id="episodeControlsBody">
					<select id="EpisodeSelector">
						<option value="">$everything</option>
					</select>
					<label id="showUnlinkedLabel">
						<input type="checkbox" id="ShowUnlinkedCheckbox" checked> Show unlinked
					</label>
				</div>
			</div>

			<div id="resourceTypeControls" class="card">
				<div id="resourceTypeControlsHeader">
					<span>Resource types</span>
					<button type="button" id="ToggleAllResourceTypesButton" title="Invert selection">&#8646;</button>
				</div>

				<div style="padding:12px 16px 0 16px;">
					<select id="PresetSelector"></select>
				</div>

				<div id="resourceTypeControlsBody">
					<ul></ul>
					<div id="HiddenResourceTray"></div>
				</div>
			</div>
		</div>

		<div id="ResourceInspector" class="drawer card">
			<div id="ResourceInspectorHeader">
				<div id="ResourceInspectorTitle">FHIR Resource</div>
				<div id="ResourceInspectorActions">
					<button id="HideResourceButton">Hide on map</button>
					<button id="CloseInspectorButton" type="button">Close</button>
				</div>
			</div>
			<div id="ResourceInspectorBody">

				<div id="InspectorValidationPanel" class="inspectorValidationPanel is-hidden">
					<div id="InspectorValidationHeaderRow">
						<div id="InspectorValidationTitle">Validation</div>
						<button type="button" id="InspectorValidationToggleButton">Hide</button>
					</div>
					<div id="InspectorValidationIssues"></div>
				</div>

				<pre><code id="resourceJSON" class="language-json" autocomplete="off"></code></pre>
			</div>
		</div>

	</div>
</div>
</body>
</html>>
	
	return $$$OK
}

}
