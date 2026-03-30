/**
* Displays a cleaner timeline visualization of FHIR data.
*
* Demo-oriented version with Encounter subgroups for MII:
* - Fall
* - AK (Abteilungskontakt)
* - VK (Versorgungsstellenkontakt)
*
* @version 3.0 2026-03-18
* @author Brandon Thomas
*/

Class HS.Local.zimpli.fhir.UI.FHIRTimeline Extends HS.Local.zimpli.fhir.UI.Super
{

ClassMethod OnPage() As %Status
{
	&html<<!DOCTYPE HTML>
<html>
<head>
  <title>FHIR Timeline</title>
  	#(..MetaTags())#
	#(..LinkJS("assets/ext/jquery-3.7.1.min.js"))#
	#(..XDataJS("StorageHandler"))#
	#(..LinkJS("assets/ext/vis-timeline-graph2d.min.js"))#
	#(..LinkCSS("assets/ext/vis-timeline-graph2d.min.css"))#
    #(..LinkJS("assets/FHIRTimeline.js"))#
	#(..DefaultStyle())#
	#(..LinkCSS("assets/FHIRTimeline.css"))#
</head>
<body>

<div id="pageToolbar">
    <div id="pageToolbarText">
        <div id="pageTitle">Patient Journey</div>
        <div id="PatientSummary"></div>
    </div>

    <div id="pageToolbarActions">
        <select id="EncounterSelector"></select>
        <button id="buttonReplay" type="button">&#x25B8; Replay</button>
        <button id="buttonRefit" type="button" title="Refit timeline">Refit</button>
    </div>
</div>

<div id="visualization"></div>
<div id="timelineTooltip"></div>
<div id="replayCard">
    <div id="replayCardHeader">
        <button id="buttonReplayCardCancel">&#10006;</button>
        <span id="replayCardTitle">Patient Journey Replay</span>
        <div id="replayCardActions">
            <button id="buttonReplayCardPrev">&#9664; Prev</button>
            <button id="buttonReplayCardNext">&#9654; Next</button>
            
        </div>
        </div>
    <div id="replayCardBody"></div>
</div>

</body>
</html>
	>
	
	return $$$OK
}

}
