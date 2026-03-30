/**
* Displays a 3D network visualization of FHIR data.
*
* @version 4.0 2026-03-19
* @author Brandon Thomas
*/

Class HS.Local.zimpli.fhir.UI.FHIRForce3d Extends HS.Local.zimpli.fhir.UI.Super
{

ClassMethod OnPage() As %Status
{
	&html<<!DOCTYPE html>
<html>
<head>
	<title>FHIR Network 3D</title>
	#(..MetaTags())#
	#(..LinkJS("assets/ext/jquery-3.7.1.min.js"))#
	#(..XDataJS("StorageHandler"))#
	#(..DefaultStyle())#

	<script src="https://unpkg.com/three@0.159.0/build/three.min.js"></script>
    <script src="https://unpkg.com/3d-force-graph@1.76.0/dist/3d-force-graph.min.js"></script>
    <script src="https://unpkg.com/three-spritetext@1.10.0/dist/three-spritetext.min.js"></script>

<style type="text/css">
html,
body {
	margin: 0;
	padding: 0;
	height: 100%;
	overflow: hidden;
	background: #f5f7fb;
	box-sizing: border-box;
	font-family: Arial, Helvetica, sans-serif;
	color: #1f2937;
}

*,
*::before,
*::after {
	box-sizing: inherit;
}

button,
input,
textarea,
select {
	font: inherit;
}

#pageShell {
	height: 100%;
	padding: 16px;
	overflow: hidden;
}

#networkLayout {
	position: relative;
	height: 100%;
	overflow: hidden;
}

.card {
	background: #ffffff;
	border: 1px solid #e5e7eb;
	border-radius: 12px;
	box-shadow: 0 1px 3px rgba(0,0,0,0.06);
}

/* MAIN AREA */
#mainArea {
	position: relative;
	width: 100%;
	height: 100%;
	min-width: 0;
	min-height: 0;
	overflow: hidden;
}

#NetworkCard {
	position: relative;
	width: 100%;
	height: 100%;
	padding: 0;
	overflow: hidden;
	background: #ffffff;
}

#ForceGraphPane {
	width: 100%;
	height: 100%;
	min-height: 620px;
	background: #ffffff;
	overflow: hidden;
	touch-action: none;
}

/* TOP LEFT TOOLBAR */
#NetworkToolbar {
	position: absolute;
	top: 16px;
	left: 16px;
	z-index: 40;
	display: flex;
	align-items: flex-start;
	gap: 10px;
}

#RailToggleButton {
	height: 36px;
	min-width: 36px;
	display: flex;
	align-items: center;
	justify-content: center;
	border: 1px solid #cbd5e1;
	border-radius: 10px;
	background: rgba(255,255,255,0.96);
	color: #334155;
	font-size: 18px;
	line-height: 1;
	cursor: pointer;
	box-shadow: 0 1px 3px rgba(0,0,0,0.08);
}

#RailToggleButton:hover {
	background: #f8fafc;
}

#NetworkZoomControls {
	display: flex;
	flex-direction: column;
	gap: 8px;
}

#NetworkZoomControls button {
	width: 36px;
	height: 36px;
	display: flex;
	align-items: center;
	justify-content: center;
	border: 1px solid #cbd5e1;
	border-radius: 10px;
	background: rgba(255,255,255,0.96);
	color: #334155;
	font-size: 16px;
	line-height: 1;
	cursor: pointer;
	box-shadow: 0 1px 3px rgba(0,0,0,0.08);
}

#NetworkZoomControls button:hover {
	background: #f8fafc;
}

/* subtle caption */
#GraphModeBadge {
	position: absolute;
	right: 16px;
	top: 16px;
	z-index: 20;
	padding: 8px 10px;
	border-radius: 10px;
	background: rgba(255,255,255,0.94);
	border: 1px solid #e5e7eb;
	color: #64748b;
	font-size: 12px;
	line-height: 1;
}

/* BACKDROP */
#DrawerBackdrop {
	position: absolute;
	inset: 0;
	background: rgba(15, 23, 42, 0.18);
	z-index: 25;
	opacity: 0;
	visibility: hidden;
	pointer-events: none;
	transition: opacity 180ms ease, visibility 180ms ease;
}

#DrawerBackdrop.open {
	opacity: 1;
	visibility: visible;
	pointer-events: auto;
}

/* GENERIC DRAWER */
.drawer {
	position: absolute;
	top: 0;
	bottom: 0;
	z-index: 35;
	will-change: transform, opacity;
	transition: transform 180ms ease, opacity 180ms ease, visibility 180ms ease;
	opacity: 0;
	visibility: hidden;
	pointer-events: none;
	display: flex;
	flex-direction: column;
	min-height: 0;
}

.drawer.open {
	opacity: 1;
	visibility: visible;
	pointer-events: auto;
}

/* LEFT DRAWER */
#leftRail {
	left: 0;
	width: min(360px, calc(100vw - 48px));
	transform: translateX(calc(-100% - 12px));
	gap: 12px;
}

#leftRail.open {
	transform: translateX(0);
}

#resourceTypeControls {
	display: flex;
	flex-direction: column;
	min-height: 0;
	height: 100%;
	overflow: hidden;
}

#resourceTypeControlsHeader {
	display: flex;
	align-items: center;
	justify-content: space-between;
	padding: 14px 16px 10px 16px;
	border-bottom: 1px solid #e5e7eb;
	font-size: 16px;
	font-weight: 600;
	flex: 0 0 auto;
}

#ToggleAllResourceTypesButton {
	height: 28px;
	min-width: 28px;
	padding: 0 8px;
	border: 1px solid #cbd5e1;
	border-radius: 8px;
	background: #ffffff;
	color: #334155;
	cursor: pointer;
	font-size: 14px;
	line-height: 1;
}

#ToggleAllResourceTypesButton:hover {
	background: #f8fafc;
}

#resourceTypeControlsBody {
	padding: 12px 16px 16px 16px;
	overflow: auto;
	min-height: 0;
}

#resourceTypeControls ul {
	list-style: none;
	margin: 0;
	padding: 0;
}

#resourceTypeControls li {
	display: flex;
	align-items: center;
	justify-content: space-between;
	gap: 8px;
	padding: 7px 0;
	border-bottom: 1px solid #f1f5f9;
}

#resourceTypeControls li:last-child {
	border-bottom: none;
}

.typeLeft {
	display: flex;
	align-items: center;
	gap: 6px;
	min-width: 0;
}

.typeLabel {
	color: #334155;
	font-size: 14px;
	font-weight: 500;
	white-space: nowrap;
	overflow: hidden;
	text-overflow: ellipsis;
}

.typeCount {
	color: #94a3b8;
	font-size: 13px;
}

.typeToggle {
	width: 16px;
	height: 16px;
	cursor: pointer;
}

#HiddenResourceTray {
	margin-top: 12px;
	display: flex;
	flex-wrap: wrap;
	gap: 8px;
}

.unhideButton {
	border: 1px solid #cbd5e1;
	background: #ffffff;
	color: #334155;
	border-radius: 8px;
	padding: 6px 10px;
	font-size: 12px;
	line-height: 1.2;
	cursor: pointer;
}

.unhideButton:hover {
	background: #f8fafc;
}

/* RIGHT DRAWER / INSPECTOR */
#ResourceInspector {
	right: 0;
	width: min(760px, calc(100vw - 48px));
	transform: translateX(calc(100% + 12px));
	overflow: hidden;
}

#ResourceInspector.open {
	transform: translateX(0);
}

#ResourceInspectorHeader {
	display: flex;
	align-items: center;
	justify-content: space-between;
	gap: 12px;
	padding: 14px 16px;
	border-bottom: 1px solid #e5e7eb;
	background: #ffffff;
	flex: 0 0 auto;
}

#ResourceInspectorTitle {
	font-size: 16px;
	font-weight: 600;
	color: #1f2937;
	min-width: 0;
}

#ResourceInspectorActions {
	display: flex;
	align-items: center;
	gap: 8px;
	flex: 0 0 auto;
}

#HideResourceButton,
#CloseInspectorButton {
	height: 32px;
	padding: 0 10px;
	border: 1px solid #cbd5e1;
	border-radius: 8px;
	background: #ffffff;
	color: #334155;
	cursor: pointer;
	white-space: nowrap;
}

#HideResourceButton:hover,
#CloseInspectorButton:hover {
	background: #f8fafc;
}

#ResourceInspectorBody {
	flex: 1 1 auto;
	min-height: 0;
	overflow: auto;
	padding: 8px;
	background: #ffffff;
	font-size: 12px;
}

#ResourceInspectorBody pre {
	background: #f8fafc;
	border: 1px solid #e5e7eb;
	border-radius: 10px;
	padding: 10px;
	overflow: auto;
	line-height: 1.35;
	min-height: 100%;
}

#ResourceInspectorBody code {
	font-family: Consolas, Monaco, monospace;
	font-size: 12px;
	line-height: 1.35;
	white-space: pre-wrap;
	word-break: break-word;
}

pre,
code {
	margin: 0;
	padding-top: 0;
}

@media (max-width: 900px) {
	#pageShell {
		padding: 10px;
	}

	#leftRail {
		width: min(340px, calc(100vw - 20px));
	}

	#ResourceInspector {
		width: calc(100vw - 20px);
	}

	#NetworkToolbar {
		top: 10px;
		left: 10px;
	}

	#GraphModeBadge {
		top: 10px;
		right: 10px;
	}
}
</style>

<script type="text/javascript">
var resourceTypesHidden = {};
var resourceTypes = {};
var fhirResource = {};
var fhirResourceUrnUuids = {};

var allNodesById = {};
var allLinks = [];
var hiddenResourceIds = {};

var graph = null;
var colors = null;

function parse() {
	var tMpiid = getMpiid();
	if (tMpiid == "") {
		console.log("No MPIID found in current session. Search for a patient first.");
		return;
	}

	var tFHIR = getFhirData();
	if (tFHIR == "") {
		console.log("No FHIR data found in sessionStorage. Search for a patient first.");
		return;
	}

	unfocusInspector();
	cleanSession();

	var bundle = JSON.parse(tFHIR);
	if (!bundle.entry || !bundle.entry.length) {
		console.log("FHIR bundle has no entries.");
		return;
	}

	bundle.entry.forEach(processEntry);
	bundle.entry.forEach(processReferences);

	resourceTypes = Object.fromEntries(Object.entries(resourceTypes).sort());
	for (var key in resourceTypes) {
		updateTypeControls(key, resourceTypes[key]);
	}

	refreshGraphData(true);
}

function cleanSession() {
	resourceTypesHidden = {};
	resourceTypes = {};
	fhirResource = {};
	fhirResourceUrnUuids = {};
	allNodesById = {};
	allLinks = [];
	hiddenResourceIds = {};

	$('#resourceTypeControls ul').empty();
	$('#HiddenResourceTray').empty();
	closeLeftDrawer();
	unfocusInspector();

	if (graph) {
		graph.graphData({ nodes: [], links: [] });
	}
}

function processEntry(entry) {
	if (!entry || !entry.resource) return;

	var rsc = entry.resource;
	var resourceType = rsc.resourceType;

	if (resourceType === "OperationOutcome") {
		console.log('<OperationOutcome> Missing some data? ', JSON.stringify(entry));
		return;
	}

	if (rsc.id === undefined) {
		rsc.id = entry.fullUrl.split('/')[1] || entry.fullUrl;
		entry.resource.id = rsc.id;
		fhirResourceUrnUuids[rsc.id] = resourceType;
	}

	if (entry.fullUrl && entry.fullUrl.split(':')[0] === "urn") {
		fhirResourceUrnUuids[rsc.id] = resourceType;
	}

	var resourceId = resourceType + '/' + rsc.id;

	var title = resourceType;
	var display = '';
	var label = '<b>' + resourceType + '</b>';

	if (resourceType === 'Condition') {
		display = safeCodingCode(rsc) + ' ' + safeCodingDisplay(rsc, 50) + '...';
		title = safeCodingDisplay(rsc, 120);

	} else if (resourceType === 'Observation') {
		display = safeCodingCode(rsc).substr(0, 10) + ' ' + safeCodingDisplay(rsc, 50) + '...';
		title = safeCodingDisplay(rsc, 120);

	} else if (resourceType === 'Procedure') {
		display = safeCodingCode(rsc) + ' ' + safeCodingDisplay(rsc, 50) + '...';
		title = safeCodingDisplay(rsc, 120);

	} else if (resourceType === 'Encounter') {
		display = rsc.identifier && rsc.identifier[0] ? rsc.identifier[0].value : rsc.id;

	} else if ((resourceType === 'Patient') || (resourceType === 'Practitioner')) {
		display = rsc.name;

		if (typeof display === 'object') {
			var prefix = (rsc.name && rsc.name[0] && rsc.name[0].prefix) ? rsc.name[0].prefix : '';
			var given = (rsc.name && rsc.name[0] && rsc.name[0].given) ? rsc.name[0].given : '';
			var family = (rsc.name && rsc.name[0] && rsc.name[0].family) ? rsc.name[0].family : '';
			display = prefix + ' ' + given.toString().replace(',', ' ') + ' ' + family;
		}

	} else if (resourceType === 'Organization') {
		display = rsc.name || (rsc.type && rsc.type[0] && rsc.type[0].coding[0].display) || (rsc.identifier && rsc.identifier[0].value) || rsc.id;

	} else if (resourceType === 'Location') {
		display = safePath(rsc, ['physicalType', 'coding', 0, 'display']) + ' ' + safePath(rsc, ['identifier', 0, 'value']);
		title = safePath(rsc, ['physicalType', 'coding', 0, 'display']) || resourceType;

	} else if (resourceType === 'Device') {
		title = safePath(rsc, ['deviceName', 0, 'name']) || resourceType;
		display = title || rsc.id;

	} else if (typeof rsc.type !== 'undefined') {
		if ((typeof rsc.type === 'object') && (typeof rsc.type.coding !== 'undefined')) {
			display = rsc.type.coding[0].display || rsc.type.coding[0].code;
		} else if (Array.isArray(rsc.type) && rsc.type[0] && rsc.type[0].coding && rsc.type[0].coding[0]) {
			display = rsc.type[0].coding[0].display || rsc.type[0].coding[0].code;
		}

	} else if (typeof rsc.code !== 'undefined') {
		display = safeCodingDisplay(rsc, 120) || safeCodingCode(rsc);

	} else {
		display = rsc.status || rsc.id;
	}

	label = label + '<br><i>' + escapeHtml(display || '') + '</i>';

	allNodesById[resourceId] = {
		id: resourceId,
		resourceType: resourceType,
		label: label,
		title: escapeHtml(title || resourceType),
        shortLabel: buildShortLabel(resourceType, display, rsc),
		color: color(resourceType),
		val: nodeValue(resourceType),
		entry: entry
	};

	resourceTypes[resourceType] = parseInt(resourceTypes[resourceType] || 0) + 1;
	fhirResource[resourceId] = entry;
}

function buildShortLabel(resourceType, display, rsc) {
	var text = '';

	if (resourceType === 'Patient') return 'Patient';

	if (resourceType === 'Observation') {
		text = safeCodingCode(rsc) || safeCodingDisplay(rsc, 18) || 'Observation';
	} else if (resourceType === 'Condition') {
		text = safeCodingCode(rsc) || safeCodingDisplay(rsc, 18) || 'Condition';
	} else if (resourceType === 'Procedure') {
		text = safeCodingCode(rsc) || safeCodingDisplay(rsc, 18) || 'Procedure';
	} else if (resourceType === 'Encounter') {
		text = 'Encounter';
	} else {
		text = display || resourceType;
	}

	text = String(text || '').trim();
	if (text.length > 22) text = text.substr(0, 22) + '...';
	return text;
}

function processReferences(entry) {
	if (!entry || !entry.resource) return;
	var rsc = entry.resource;
	traverse(rsc, rsc.resourceType, rsc.id);
}

function traverse(jsonObj, nodetype, nodeid, parent) {
	if ((jsonObj !== null) && (typeof jsonObj == "object")) {
		Object.entries(jsonObj).forEach(function (pair) {
			var key = pair[0];
			var value = pair[1];

			if (key == "reference" && typeof value === "string") {
				if (value.split(':')[0] === "urn") {
					value = value.split(':')[2];
					value = fhirResourceUrnUuids[value] + '/' + value;
				}
				createLink(nodetype + '/' + nodeid, value, parent);
			}

			traverse(value, nodetype, nodeid, key);
		});
	}
}

function createLink(from, to, label) {
	allLinks.push({
		source: from,
		target: to,
		label: label || '',
		color: '#94a3b8'
	});
}

function refreshGraphData(doFit) {
	if (!graph) return;

	var visibleNodes = [];
	var visibleNodeMap = {};

	Object.keys(allNodesById).forEach(function (id) {
		var node = allNodesById[id];
		if (resourceTypesHidden[node.resourceType]) return;
		if (hiddenResourceIds[id]) return;

		visibleNodes.push(node);
		visibleNodeMap[id] = true;
	});

	var visibleLinks = allLinks.filter(function (link) {
		var sourceId = normalizeLinkEndpoint(link.source);
		var targetId = normalizeLinkEndpoint(link.target);
		return !!visibleNodeMap[sourceId] && !!visibleNodeMap[targetId];
	});

	graph.graphData({
		nodes: visibleNodes,
		links: visibleLinks
	});

	graph.d3ReheatSimulation();

	if (doFit) {
		setTimeout(function () {
			fitGraph();
		}, 350);
	}
}

function normalizeLinkEndpoint(endpoint) {
	if (typeof endpoint === 'string') return endpoint;
	if (endpoint && endpoint.id) return endpoint.id;
	return '';
}

function nodeValue(resourceType) {
	if (resourceType === 'Patient') return 16;
	if (resourceType === 'Encounter') return 10;
	if (resourceType === 'Observation') return 6;
	return 7;
}

function safePath(obj, path) {
	try {
		var out = obj;
		for (var i = 0; i < path.length; i++) {
			if (out === undefined || out === null) return '';
			out = out[path[i]];
		}
		return out || '';
	} catch (e) {
		return '';
	}
}

function safeCodingCode(rsc) {
	return safePath(rsc, ['code', 'coding', 0, 'code']) || '';
}

function safeCodingDisplay(rsc, maxLen) {
	var s = safePath(rsc, ['code', 'coding', 0, 'display']) || '';
	if (maxLen && s.length > maxLen) return s.substr(0, maxLen);
	return s;
}

function escapeHtml(str) {
	return String(str)
		.replace(/&/g, '&amp;')
		.replace(/</g, '&lt;')
		.replace(/>/g, '&gt;')
		.replace(/"/g, '&quot;')
		.replace(/'/g, '&#39;');
}

function updateTypeControls(resourceType, resourceCount) {
	$('#resourceTypeControls ul').append(
		$('<li>').attr('id', 'TypeControl' + resourceType)
			.append(
				$('<div>').addClass('typeLeft')
					.append($('<span>').addClass('typeLabel').text(resourceType))
					.append($('<span>').addClass('typeCount').attr('id', 'TypeCount' + resourceType).text(resourceCount))
			)
			.append(
				$('<input>')
					.attr({
						type: 'checkbox',
						checked: true,
						ref: resourceType
					})
					.addClass('typeToggle')
					.on('click', function () {
						toggleResourceType(this.getAttribute('ref'));
					})
			)
	);
}

function toggleAllResourceTypes() {
	$('.typeToggle[ref]').each(function () {
		var resourceType = this.getAttribute('ref');

		if (this.checked) {
			this.checked = false;
			resourceTypesHidden[resourceType] = true;
		} else {
			this.checked = true;
			delete resourceTypesHidden[resourceType];
		}
	});

	refreshGraphData(false);
}

function toggleResourceType(resourceType) {
	var checkbox = $('.typeToggle[ref="' + resourceType + '"]');

	if (resourceTypesHidden[resourceType]) {
		delete resourceTypesHidden[resourceType];
		if (checkbox.length) checkbox.prop('checked', true);
	} else {
		resourceTypesHidden[resourceType] = true;
		if (checkbox.length) checkbox.prop('checked', false);
	}

	refreshGraphData(false);
}

function color(rscType) {
	if (colors === null) {
		colors = {};
		colors['Patient'] = '#48CFAD';
		colors['Location'] = '#A0CECB';
		colors['Organization'] = '#FFCE54';
		colors['Encounter'] = '#A0D468';
		colors['DiagnosticReport'] = '#8067B7';
		colors['ServiceRequest'] = '#AC92EC';
		colors['Observation'] = '#4FC1E9';
		colors['Specimen'] = '#DCE6F7';
		colors['MedicationStatement'] = '#D8334A';
		colors['Medication'] = '#ED5565';
		colors['Practitioner'] = '#5D9CEC';
		colors['DocumentReference'] = '#E8CE4D';
		colors['Substance'] = '#FC6E51';
		colors['Composition'] = '#EC87C0';
		colors['Provenance'] = '#6EA8FE';
	}
	return colors[rscType] || '#CBD5E1';
}

function createUnhideButton(fhirResourceId) {
	$('#HiddenResourceTray').append(
		$('<input/>')
			.attr({
				type: 'button',
				id: 'unhide' + cssSafeId(fhirResourceId),
				ref: fhirResourceId,
				class: 'unhideButton',
				value: 'Unhide ' + fhirResourceId
			})
			.on('click', function () {
				var ref = this.getAttribute('ref');
				delete hiddenResourceIds[ref];
				this.remove();
				refreshGraphData(false);
			})
	);
}

function cssSafeId(str) {
	return String(str).replace(/[^A-Za-z0-9_-]/g, '_');
}

function hideResource(nodeId) {
	if (!nodeId) return;
	hiddenResourceIds[nodeId] = true;
	createUnhideButton(nodeId);
	unfocusInspector();
	refreshGraphData(false);
}

function openLeftDrawer() {
	$('#leftRail').addClass('open');
	syncBackdrop();
}

function closeLeftDrawer() {
	$('#leftRail').removeClass('open');
	syncBackdrop();
}

function toggleLeftDrawer() {
	$('#leftRail').toggleClass('open');
	syncBackdrop();
}

function openInspectorDrawer() {
	$('#ResourceInspector').addClass('open');
	syncBackdrop();
}

function closeInspectorDrawer() {
	$('#ResourceInspector').removeClass('open');
	syncBackdrop();
}

function syncBackdrop() {
	var leftOpen = $('#leftRail').hasClass('open');
	var inspectorOpen = $('#ResourceInspector').hasClass('open');

	if (leftOpen || inspectorOpen) {
		$('#DrawerBackdrop').addClass('open');
	} else {
		$('#DrawerBackdrop').removeClass('open');
	}
}

function focusInspector(nodeId) {
	var resourceEntry = fhirResource[nodeId];
	if (!resourceEntry) return;

	$('#resourceJSON').text(JSON.stringify(resourceEntry, null, 4));
	$('#HideResourceButton').attr('ref', nodeId);

	openInspectorDrawer();
	focusNodeInScene(nodeId);
}

function unfocusInspector() {
	closeInspectorDrawer();
}

function focusNodeInScene(nodeId) {
	if (!graph) return;

	var gData = graph.graphData();
	if (!gData || !gData.nodes) return;

	var node = null;
	for (var i = 0; i < gData.nodes.length; i++) {
		if (gData.nodes[i].id === nodeId) {
			node = gData.nodes[i];
			break;
		}
	}
	if (!node) return;

	var distance = 140;
	var distRatio = 1;

	if (node.x || node.y || node.z) {
		var denom = Math.hypot(node.x || 0, node.y || 0, node.z || 0);
		if (denom > 0) distRatio = 1 + distance / denom;
	}

	graph.cameraPosition(
		{
			x: (node.x || 0) * distRatio,
			y: (node.y || 0) * distRatio,
			z: (node.z || 0) * distRatio
		},
		{ x: node.x || 0, y: node.y || 0, z: node.z || 0 },
		700
	);
}

function zoomGraph(factor) {
	if (!graph) return;

	var camera = graph.cameraPosition();
	if (!camera) return;

	graph.cameraPosition(
		{
			x: camera.x * factor,
			y: camera.y * factor,
			z: camera.z * factor
		},
		{ x: 0, y: 0, z: 0 },
		180
	);
}

function fitGraph() {
	if (!graph) return;

	var pane = document.getElementById('ForceGraphPane');
	if (pane) {
		graph.width(pane.clientWidth);
		graph.height(pane.clientHeight);
	}

	graph.zoomToFit(400, 50);
}

function wireButtons() {
	var zoomIn = document.getElementById('ZoomInButton');
	var zoomOut = document.getElementById('ZoomOutButton');
	var zoomFit = document.getElementById('ZoomFitButton');
	var railToggle = document.getElementById('RailToggleButton');
	var closeInspector = document.getElementById('CloseInspectorButton');
	var backdrop = document.getElementById('DrawerBackdrop');

	if (zoomIn) {
		zoomIn.onclick = function () {
			zoomGraph(0.85);
		};
	}

	if (zoomOut) {
		zoomOut.onclick = function () {
			zoomGraph(1.18);
		};
	}

	if (zoomFit) {
		zoomFit.onclick = function () {
			fitGraph();
		};
	}

	if (railToggle) {
		railToggle.onclick = function () {
			toggleLeftDrawer();
		};
	}

	if (closeInspector) {
		closeInspector.onclick = function () {
			unfocusInspector();
		};
	}

	if (backdrop) {
		backdrop.onclick = function () {
			closeLeftDrawer();
			unfocusInspector();
		};
	}
}

function shortNodeLabel(node) {
	if (node.resourceType === 'Patient') return 'Patient';
	if (node.resourceType === 'Encounter') return 'Encounter';
	if (node.resourceType === 'Observation') return node.shortLabel || 'Observation';
	if (node.resourceType === 'Condition') return node.shortLabel || 'Condition';
	return node.shortLabel || node.resourceType || node.id;
}

function makeGlassNode(node) {
	var group = new THREE.Group();

	var size = node.val || 7;
	var geometry;

	if (node.resourceType === 'Patient') {
		geometry = new THREE.SphereGeometry(size * 1.15, 24, 24);
	} else if (node.resourceType === 'Encounter') {
		geometry = new THREE.BoxGeometry(size * 1.7, size * 1.7, size * 1.7);
	} else if (node.resourceType === 'Condition') {
		geometry = new THREE.OctahedronGeometry(size * 1.15);
	} else if (node.resourceType === 'Observation') {
		geometry = new THREE.SphereGeometry(size * 0.9, 20, 20);
	} else {
		geometry = new THREE.SphereGeometry(size, 20, 20);
	}

	var material = new THREE.MeshPhysicalMaterial({
		color: node.color || '#CBD5E1',
		transparent: true,
		opacity: 0.72,
		transmission: 0.55,
		thickness: 1.2,
		ior: 1.15,
		roughness: 0.12,
		metalness: 0.02,
		clearcoat: 0.9,
		clearcoatRoughness: 0.1
	});

	var mesh = new THREE.Mesh(geometry, material);
	group.add(mesh);

	/* subtle halo */
	var haloGeometry = new THREE.SphereGeometry(size * 1.45, 18, 18);
	var haloMaterial = new THREE.MeshBasicMaterial({
		color: node.color || '#CBD5E1',
		transparent: true,
		opacity: 0.08
	});
	var halo = new THREE.Mesh(haloGeometry, haloMaterial);
	group.add(halo);

	/* label sprite */
	var label = new SpriteText(shortNodeLabel(node));
	label.color = '#334155';
	label.textHeight = 4.5;
	label.backgroundColor = 'rgba(255,255,255,0.82)';
	label.padding = 2;
	label.borderRadius = 4;
	label.material.depthWrite = false;
	label.center.y = -0.15;
	label.position.set(0, size * 1.7, 0);
	group.add(label);

	return group;
}

function buildGraph() {
	var pane = document.getElementById('ForceGraphPane');

	graph = ForceGraph3D({
        controlType: 'orbit'
    })(pane)
        .width(pane.clientWidth)
        .height(pane.clientHeight)
        .backgroundColor('#ffffff')
        .showNavInfo(false)
        .nodeLabel(function (node) {
            return '<div style="padding:6px 8px; font:12px Arial, sans-serif;">'
                + '<b>' + escapeHtml(node.resourceType || '') + '</b><br>'
                + escapeHtml(node.title || node.id || '')
                + '</div>';
        })
        .nodeThreeObject(function (node) {
            return makeGlassNode(node);
        })
        .linkLabel(function (link) {
            return escapeHtml(link.label || '');
        })
        .linkColor(function (link) { return link.color || '#94a3b8'; })
        .linkOpacity(0.22)
        .linkWidth(1)
        .linkDirectionalArrowLength(3.5)
        .linkDirectionalArrowRelPos(0.85)
        .linkDirectionalArrowColor(function (link) { return link.color || '#94a3b8'; })
        .linkCurvature(0.08)
        .cooldownTime(3500)
        .enableNodeDrag(true)
        .onNodeClick(function (node) {
            focusInspector(node.id);
        })
        .onBackgroundClick(function () {
            unfocusInspector();
        });

	graph.d3Force('charge').strength(-180);
	graph.d3Force('link').distance(90);
	graph.d3Force('center').strength(0.08);
}

window.addEventListener("load", function () {
	buildGraph();
	wireButtons();
	parse();

	$('#ToggleAllResourceTypesButton').on('click', function () {
		toggleAllResourceTypes();
	});

	$('#HideResourceButton').on('click', function () {
		var nodeId = this.getAttribute('ref');
		hideResource(nodeId);
	});

	window.addEventListener('resize', function () {
		if (!graph) return;
		var pane = document.getElementById('ForceGraphPane');
		graph.width(pane.clientWidth);
		graph.height(pane.clientHeight);
	});
});
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
						<button type="button" id="ZoomFitButton" title="Fit graph">&#9974;</button>
					</div>
				</div>

				<div id="GraphModeBadge">3D</div>
				<div id="ForceGraphPane"></div>
			</div>
		</div>

		<div id="DrawerBackdrop"></div>

		<div id="leftRail" class="drawer">
			<div id="resourceTypeControls" class="card">
				<div id="resourceTypeControlsHeader">
					<span>Resource types</span>
					<button type="button" id="ToggleAllResourceTypesButton" title="Invert selection">&#8646;</button>
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
					<button id="HideResourceButton" type="button">Hide in graph</button>
					<button id="CloseInspectorButton" type="button">Close</button>
				</div>
			</div>
			<div id="ResourceInspectorBody">
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
