Class HS.Local.zimpli.fhir.UI.DataInspector Extends HS.Local.zimpli.fhir.UI.Super
{

ClassMethod OnPage() As %Status [ ServerOnly = 1 ]
{
	&html<<!DOCTYPE html>
<html>
<head>
	<title>SDA3 & FHIR Inspector</title>
	#(..MetaTags())#
    #(..XDataJS("StorageHandler"))#
	#(..LinkJS("assets/ext/jquery-3.7.1.min.js"))#
	#(..LinkJS("assets/ext/jquery-ui-1.13.3.min.js"))#
    #(..LinkJS("assets/DataInspector.js"))#
    #(..DefaultStyle())#
    #(..LinkCSS("assets/DataInspector.css"))#
</head>
<body>
    <fieldset class="infoBox" id="Controls">
        <legend class="srOnly">inspect</legend>

        <div class="controlsHeader">
            <span class="controlsTitle">&#128270; Inspect</span>
        </div>

        <div class="controlRow searchRow">
            <form class="searchForm" onsubmit="viewerSearch($('#searchTerm').val()); return false;">
                <input id="searchTerm" autofocus placeholder="Search text / value / id / fullUrl" />
                <button type="submit">Find</button>
                <button type="button" onclick="clearSearch()">Clear</button>
            </form>
        </div>

        <div class="controlRow matchRow">
            <span class="comment">match <span id="currentFound">0</span> of <span id="totalFound">0</span></span>
            <button type="button" onclick="viewerPrev()">&lt;</button>
            <button type="button" onclick="viewerNext()">&gt;</button>
            <!-- <span class="comment status" id="statusBar"></span> -->
        </div>

        <!--div class="controlRow scrollRow">
            <button type="button" onclick="$('html').animate({scrollTop:0},300);">&#10514; Top</button>
            <button type="button" onclick="$('html').animate({scrollTop:$(document).height()},300);">&#10515; Bottom</button>
        </div-->
    </fieldset>

	<div id="container">
        <div class="viewerPane" id="fhirPane">
            <div class="paneHeaderVertical">
                <div class="paneTitle">FHIR</div>
                <div class="paneTabs vertical">
                    <button type="button" class="tabBtn active" data-pane="fhir" data-view="tree" title="Tree view">&#x2630;</button>
                    <button type="button" class="tabBtn" data-pane="fhir" data-view="raw" title="Raw view">&#123; &#125;</button>
                    <button type="button" class="paneActionBtn" onclick="expandPane('fhir')" title="Expand all">&#x2922;</button>
                    <button type="button" class="paneActionBtn" onclick="collapsePane('fhir')" title="Collapse all">&#x2921;</button>
                </div>
            </div>
            <div class="paneBody">
                <div class="paneView treeView active" id="fhirTreeView"></div>
                <div class="paneView rawView" id="fhirRawView">
                    <!--div class="rawActions">
                        <button type="button" onclick="applyFhirRaw()">Apply</button>
                        <button type="button" onclick="resetFhirRaw()">Reset</button>
                        <span class="comment" id="fhirRawState">read from sessionStorage</span>
                    </div-->
                    <textarea id="fhirRawText" spellcheck="false"></textarea>
                </div>
            </div>
        </div>

        <div id="separator"></div>

        <div class="viewerPane" id="sdaPane">
            <div class="paneHeaderVertical">
                <div class="paneTitle">SDA3</div>
                <div class="paneTabs vertical">
                    <button type="button" class="tabBtn active" data-pane="sda" data-view="tree" title="Tree view">&#x2630;</button>
                    <button type="button" class="tabBtn" data-pane="sda" data-view="raw" title="Raw view">&#123; &#125;</button>
                    <button type="button" class="paneActionBtn" onclick="expandPane('sda')" title="Expand all">&#x2922;</button>
                    <button type="button" class="paneActionBtn" onclick="collapsePane('sda')" title="Collapse all">&#x2921;</button>
                </div>
            </div>
            <div class="paneBody">
                <div class="paneView treeView active" id="sdaTreeView"></div>
                <div class="paneView rawView" id="sdaRawView">
                    <pre id="sdaRawPre"></pre>
                </div>
            </div>
        </div>
    </div>
</body>
</html>>

	Quit $$$OK
}

}
