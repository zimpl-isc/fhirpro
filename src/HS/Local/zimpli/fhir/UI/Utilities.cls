/**
* Developer utilities page — base64 decoder and other small tools
*
* @version 1.0 2026-04-29
* @author Brandon Thomas
*/

Class HS.Local.zimpli.fhir.UI.Utilities Extends HS.Local.zimpli.fhir.UI.Super
{

ClassMethod OnPage() As %Status
{
	&html<<!DOCTYPE html>
<html>
<head>
	<title>Utilities</title>
	#(..MetaTags())#
	#(..LinkJS("assets/ext/jquery-3.7.1.min.js"))#
	#(..DefaultStyle())#
	#(..LinkCSS("assets/Utilities.css"))#
</head>
<body>
<div id="pageShell">

	<div class="card pageHeader">
		<h1 class="pageTitle">Utilities</h1>
	</div>

	<!-- Tool selector -->
	<div class="card toolbarCard">
		<div class="toolTabs" id="ToolTabs">
			<button class="toolTab active" data-tool="base64">Base64 Decoder</button>
		</div>
	</div>

	<!-- Base64 Decoder -->
	<div id="tool-base64" class="toolPanel card">
		<div class="toolPanelInner">

			<div class="inputPane">
				<div class="paneHeader">
					<span class="paneTitle">Input</span>
					<div class="paneActions">
						<button id="ClearBtn" type="button">Clear</button>
						<button id="DecodeBtn" type="button" class="primaryButton">Decode</button>
					</div>
				</div>
				<textarea id="InputArea" placeholder="Paste base64 string here&#x2026;" spellcheck="false" autocomplete="off"></textarea>
			</div>

			<div class="outputPane">
				<div class="paneHeader">
					<span class="paneTitle">Output</span>
					<div class="paneActions">
						<span id="DetectedType" class="detectedBadge"></span>
						<button id="CopyBtn" type="button">Copy</button>
						<a id="DownloadLink" class="downloadLink is-hidden" download="">Download</a>
					</div>
				</div>
				<div id="OutputArea">
					<div id="OutputText" class="outputText is-hidden"></div>
					<img id="OutputImage" class="outputImage is-hidden" alt="decoded image" />
					<iframe id="OutputPdf" class="outputPdf is-hidden" title="decoded pdf"></iframe>
					<div id="OutputEmpty" class="outputEmpty">Decoded output will appear here</div>
				</div>
			</div>

		</div>
	</div>

</div>
#(..LinkJS("assets/Utilities.js"))#
</body>
</html>>

	return $$$OK
}

}
