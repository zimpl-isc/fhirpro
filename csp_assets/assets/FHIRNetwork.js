var resourceTypesHidden = {};
var resourceTypes = {};
var fhirResource = {};
var fhirResourceUrnUuids = {};
var bundleEntryIndex = {};
var nodes = null;
var edges = null;
var network = null;
var colors = null;

var zoomTimer = null;
var zoomHoldDelay = null;
var physicsFreezeTimer = null;

var selectedNodeId = null;
var selectedNodeOriginalStyle = {};
var fitButtonPrimed = false;

var validationState = {
    profile: "",
    result: null,
    resources: {},
    summary: null,
    bundleIssues: []
};

const PRESETS = {
    all: null,
    journey: ['Encounter', 'Location'],
    encounters: ['Encounter'],
    clinical: ['Observation', 'Condition', 'Encounter'],
    structure: ['Organization', 'Location', 'Encounter'],
    lineage: ['Provenance', 'Observation', 'Condition'],
    relevant: ['Encounter', 'Location', 'Observation', 'Condition','Procedure']
};

function unfixAllNodes() {
    if (!nodes) return;
    var updates = [];
    nodes.forEach(function (node) {
        updates.push({ id: node.id, fixed: { x: false, y: false } });
    });
    nodes.update(updates);
}

function parse() {
    var tMpiid = getMpiid();
    if (tMpiid == "") { console.log("No MPIID found."); return; }

    var tFHIR = getFhirData();
    if (tFHIR == "") { console.log("No FHIR data found."); return; }

    unfocusInspector();
    cleanSession();

    var bundle = JSON.parse(tFHIR);
    if (!bundle.entry || !bundle.entry.length) { console.log("FHIR bundle has no entries."); return; }

    bundle.entry.forEach(processEntry);
    bundle.entry.forEach(processReferences);

    resourceTypes = Object.fromEntries(Object.entries(resourceTypes).sort());
    for (var key in resourceTypes) { updateTypeControls(key, resourceTypes[key]); }

    populatePresetControls();

    network.setOptions({ physics: { enabled: true } });
    network.stabilize(80);

    network.once('stabilizationIterationsDone', function () {
        pinKeyNodesToCorners();
        network.fit({ animation: { duration: 300, easingFunction: 'easeInOutQuad' } });
        enablePhysicsTemporarily(2000);
    });
}

function cleanSession() {
    resourceTypesHidden = {};
    resourceTypes = {};
    fhirResource = {};
    fhirResourceUrnUuids = {};
    bundleEntryIndex = {};

    if (edges) edges.clear();
    if (nodes) nodes.clear();

    $('#resourceTypeControls ul').empty();
    $('#HiddenResourceTray').empty();

    var presetSelector = document.getElementById('PresetSelector');
    if (presetSelector) presetSelector.innerHTML = '';

    closeLeftDrawer();
    unfocusInspector();
}

function processEntry(entry) {
    if (!entry || !entry.resource) return;

    var rsc = entry.resource;
    var resourceType = rsc.resourceType;

    if (resourceType === "OperationOutcome") {
        console.log('<OperationOutcome>', JSON.stringify(entry));
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
        display = rsc.code.coding[0].code + ' ' + rsc.code.coding[0].display.substr(0, 50) + '...';
        title = rsc.code.coding[0].display;

    } else if (resourceType === 'Observation') {
        var code = '';
        var displayText = 'Observation';

        if (rsc.code && rsc.code.coding && rsc.code.coding[0]) {
            code = rsc.code.coding[0].code || '';
            displayText = rsc.code.coding[0].display || displayText;
        }

        // Detect category
        var isVital = false;

        if (rsc.category && rsc.category.length) {
            isVital = rsc.category.some(function (cat) {
                return cat.coding && cat.coding.some(function (c) {
                    return c.code === 'vital-signs';
                });
            });
        }

        // Choose icon
        var icon = isVital ? '\u{1FA7A}' : '\u{1F9EA}'; // 🩺 : 🧪

        // Build label
        display = icon + ' ' + code.substr(0, 10) + ' ' + displayText.substr(0, 50) + '...';
        title = displayText;

    } else if (resourceType === 'Procedure') {
        display = rsc.code.coding[0].code + ' ' + rsc.code.coding[0].display.substr(0, 50) + '...';
        title = rsc.code.coding[0].display;

    } else if (resourceType === 'Encounter') {
        display = rsc.identifier && rsc.identifier[0] ? rsc.identifier[0].value : rsc.id;

    } else if (resourceType === 'Patient' || resourceType === 'Practitioner') {
        display = rsc.name;
        if (typeof display === 'object') {
            var prefix = rsc.name[0].prefix || '';
            var given = rsc.name[0].given || '';
            var family = rsc.name[0].family || '';
            display = prefix + ' ' + given.toString().replace(',', ' ') + ' ' + family;
        }
    } else if (resourceType === 'Organization') {
        display = rsc.name || (rsc.type && rsc.type[0] && rsc.type[0].coding[0].display) || (rsc.identifier && rsc.identifier[0].value) || rsc.id;
    } else if (resourceType === 'Location') {
        var type = '';
        if (
            rsc.physicalType &&
            rsc.physicalType.coding &&
            rsc.physicalType.coding[0]
        ) {
            type = rsc.physicalType.coding[0].display;
        }

        var symbol =
            type === 'Ward' ? '\u{1F3E5}' :      // 🏥
            type === 'Room' ? '\u{1F6AA}' :      // 🚪
            type === 'Bed' ? '\u{1F6CF}' :       // 🛏️
            '\u{1F4CD}';                         // 📍 fallback

        var idVal = (rsc.identifier && rsc.identifier[0])
            ? rsc.identifier[0].value
            : '';

        display = symbol + ' ' + (idVal || type);
        title = type + (idVal ? ' ' + idVal : '');

    } else if (resourceType === 'Device') {
        title = rsc.deviceName[0].name;
        display = title || rsc.id;

    } else if (typeof rsc.type !== 'undefined') {
        if (typeof rsc.type === 'object' && typeof rsc.type.coding !== 'undefined') {
            display = rsc.type.coding[0].display || rsc.type.coding[0].code;
        } else if (Array.isArray(rsc.type)) {
            display = rsc.type[0].coding[0].display || rsc.type[0].coding[0].code;
        }
    } else if (typeof rsc.code !== 'undefined') {
        display = rsc.code.coding[0].display || rsc.code.coding[0].code;
    } else {
        display = rsc.status || rsc.id;
    }

    label = label + '\n' + display;
    createNode(resourceId, resourceType, label, title);
    fhirResource[resourceId] = entry;
}

function processReferences(entry) {
    if (!entry || !entry.resource) return;
    var rsc = entry.resource;
    traverse(rsc, rsc.resourceType, rsc.id);
}

function traverse(jsonObj, nodetype, nodeid, parent) {
    if (jsonObj !== null && typeof jsonObj == "object") {
        Object.entries(jsonObj).forEach(function (pair) {
            var key = pair[0];
            var value = pair[1];
            if (key == "reference") {
                if (typeof value === 'string' && value.split(':')[0] === "urn") {
                    value = value.split(':')[2];
                    value = fhirResourceUrnUuids[value] + '/' + value;
                }
                createEdge(nodetype + '/' + nodeid, value, parent);
            }
            traverse(value, nodetype, nodeid, key);
        });
    }
}

function createNode(resourceId, resourceType, label, title) {
	// removed title: title
    nodes.add({ id: resourceId, label: label, color: color(resourceType) });
    resourceTypes[resourceType] = parseInt(resourceTypes[resourceType] || 0) + 1;
}

function createEdge(from, to, label) {
    edges.add({ from: from, to: to, label: '<i>' + label + '</i>' });
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
                $('<input>').attr({ type: 'checkbox', checked: true, ref: resourceType })
                    .addClass('typeToggle')
                    .on('click', function () { toggleResourceType(this.getAttribute('ref')); })
            )
    );
}

function toggleAllResourceTypes() {
    $('.typeToggle[ref]').each(function () {
        var resourceType = this.getAttribute('ref');
        if (this.checked) {
            this.checked = false;
            if (resourceTypesHidden[resourceType] === undefined) hideResourceType(resourceType, true);
        } else {
            this.checked = true;
            if (resourceTypesHidden[resourceType] !== undefined) unhideResourceType(resourceType, true);
        }
    });
    enablePhysicsTemporarily(1500);
}

function populatePresetControls() {
    var presetSelector = document.getElementById('PresetSelector');
    if (!presetSelector) return;

    presetSelector.innerHTML = '';

    var labels = {
        all: 'All resources',
        journey: 'Patient journey',
        encounters: 'Encounters only',
        clinical: 'Clinical snapshot',
        structure: 'Organizations & structure',
        lineage: 'Data lineage',
        relevant: 'Relevant only'
    };

    Object.keys(PRESETS).forEach(function (key) {
        var opt = document.createElement('option');
        opt.value = key;
        opt.textContent = labels[key] || key;
        presetSelector.appendChild(opt);
    });

    presetSelector.value = 'all';
}

function applyPreset(name) {
    if (!PRESETS.hasOwnProperty(name)) return;
    var types = PRESETS[name];

    Object.keys(resourceTypes).forEach(function (type) {
        var checkbox = $('.typeToggle[ref="' + type + '"]');
        if (types === null || types.indexOf(type) !== -1) {
            if (resourceTypesHidden[type] !== undefined) unhideResourceType(type, true);
            if (checkbox.length) checkbox.prop('checked', true);
        } else {
            if (resourceTypesHidden[type] === undefined) hideResourceType(type, true);
            if (checkbox.length) checkbox.prop('checked', false);
        }
    });

    network.setOptions({ physics: { enabled: true } });
    network.stabilize(40);

    network.once('stabilizationIterationsDone', function () {
        pinKeyNodesToCorners();
        network.fit({ animation: { duration: 220, easingFunction: 'easeInOutQuad' } });
        enablePhysicsTemporarily(1500);
    });
}

function colorPastel(rscType) {
    if (colors === null) {
        colors = {};

        // Core
        colors['Patient'] = '#3B82F6';
        colors['Practitioner'] = '#93C5FD';

        // 🩺 Observations (teal)
        colors['Observation'] = '#B7E4DC';
        colors['DiagnosticReport'] = '#B7E4DC';

        // 🧾 Conditions (blue)
        colors['Condition'] = '#A7D8F0';

        // 🔧 Procedures (neutral blue-grey)
        colors['Procedure'] = '#D1DCEB';

        // 💊 Medications (warm)
        colors['Medication'] = '#F0C7C1';
        colors['MedicationStatement'] = '#F0C7C1';

        // Encounters & org (unchanged, already good)
        colors['Encounter'] = '#8FAADC';
        colors['Location'] = '#C9D8F0';
        colors['Organization'] = '#EFD8A6';

        // Supporting
        colors['Provenance'] = '#D8DEE9';
        colors['DocumentReference'] = '#E8D9B5';
        colors['Composition'] = '#E6DCCF';
        colors['ServiceRequest'] = '#DDD6C8';
        colors['Substance'] = '#EBC5B0';
        colors['Specimen'] = '#E5E7EB';
    }

    return colors[rscType] || '#CBD5E1';
}

function color(rscType) {
    if (colors === null) {
        colors = {};

        // Core
        colors['Patient'] = '#3B82F6';
        colors['Practitioner'] = '#93C5FD';

        // 🩺 Observations (teal)
        colors['Observation'] = '#E7F6F3';
        colors['DiagnosticReport'] = '#B7E4DC';

        // 🧾 Conditions (blue)
        colors['Condition'] = '#E4F3FA';

        // 🔧 Procedures (neutral blue-grey)
        colors['Procedure'] = '#EFF3F8';

        // 💊 Medications (warm)
        colors['Medication'] = '#FBF1EF';
        colors['MedicationStatement'] = '#FBF1EF';

        // Encounters & org (unchanged, already good)
        colors['Encounter'] = '#8FAADC';
        colors['Location'] = '#C9D8F0';
        colors['Organization'] = '#EFD8A6';

        // Supporting
        colors['Provenance'] = '#D8DEE9';
        colors['DocumentReference'] = '#E8D9B5';
        colors['Composition'] = '#E6DCCF';
        colors['ServiceRequest'] = '#DDD6C8';
        colors['Substance'] = '#EBC5B0';
        colors['Specimen'] = '#E5E7EB';
    }

    return colors[rscType] || '#CBD5E1';
}

function createUnhideButton(fhirResourceId) {
    $('#HiddenResourceTray').append(
        $('<input/>').attr({
            type: 'button',
            id: 'unhide' + fhirResourceId,
            ref: fhirResourceId,
            class: 'unhideButton',
            value: 'Unhide ' + fhirResourceId
        }).on('click', function () {
            processEntry(fhirResource[this.getAttribute('ref')]);
            document.getElementById('unhide' + fhirResourceId).remove();
            if (selectedNodeId === fhirResourceId) {
                applySelectedNodeStyle(fhirResourceId);
                if (network) network.selectNodes([fhirResourceId]);
            }
            network.setOptions({ physics: { enabled: true } });
            network.stabilize(30);
            enablePhysicsTemporarily(1500);
        })
    );
}

function toggleResourceType(resourceType) {
    var checkbox = $('.typeToggle[ref="' + resourceType + '"]');
    if (resourceTypesHidden[resourceType] === undefined) {
        hideResourceType(resourceType);
        if (checkbox.length) checkbox.prop('checked', false);
    } else {
        unhideResourceType(resourceType);
        if (checkbox.length) checkbox.prop('checked', true);
    }
}

function hideResourceType(resourceType, skipPhysics) {
    resourceTypesHidden[resourceType] = [];
    nodes.getDataSet().forEach(function (obj) {
        if (obj.id.indexOf(resourceType + '/') === 0) {
            resourceTypesHidden[resourceType].push(obj);
            if (selectedNodeId === obj.id) { clearSelectedNodeStyle(); closeInspectorDrawer(); }
            nodes.remove(obj.id);
        }
    });
    if (!skipPhysics) enablePhysicsTemporarily(1200);
}

function unhideResourceType(resourceType, skipPhysics) {
    if (!resourceTypesHidden[resourceType]) return;
    resourceTypesHidden[resourceType].forEach(function (obj) { nodes.add(obj); });
    delete resourceTypesHidden[resourceType];
    network.setOptions({ physics: { enabled: true } });
    network.stabilize(30);
    if (!skipPhysics) enablePhysicsTemporarily(1500);
}

function openLeftDrawer() { $('#leftRail').addClass('open'); syncBackdrop(); }
function closeLeftDrawer() { $('#leftRail').removeClass('open'); syncBackdrop(); }
function toggleLeftDrawer() { $('#leftRail').toggleClass('open'); syncBackdrop(); }
function openInspectorDrawer() { $('#ResourceInspector').addClass('open'); syncBackdrop(); }
function closeInspectorDrawer() { $('#ResourceInspector').removeClass('open'); syncBackdrop(); }

function syncBackdrop() {
    var leftOpen = $('#leftRail').hasClass('open');
    var inspectorOpen = $('#ResourceInspector').hasClass('open');
    if (leftOpen || inspectorOpen) {
        $('#DrawerBackdrop').addClass('open');
    } else {
        $('#DrawerBackdrop').removeClass('open');
    }
}

function storeOriginalNodeStyle(nodeId) {
    if (!nodes || !nodeId) return;
    if (selectedNodeOriginalStyle[nodeId]) return;
    var node = nodes.get(nodeId);
    if (!node) return;
    selectedNodeOriginalStyle[nodeId] = {
        borderWidth: node.borderWidth,
        borderWidthSelected: node.borderWidthSelected,
        font: $.extend(true, {}, node.font || {}),
        color: $.extend(true, {}, node.color || {})
    };
}

function applySelectedNodeStyle(nodeId) {
    if (!nodes || !nodeId) return;
    var node = nodes.get(nodeId);
    if (!node) return;
    storeOriginalNodeStyle(nodeId);
    var baseColor = color(nodeId.split('/')[0]);
	var border = darkenHex(baseColor, 0.3);
    nodes.update({
        id: nodeId,
        borderWidth: 3,
        borderWidthSelected: 3,
        color: {
            border: border,
            background: baseColor,
            highlight: { border: border},
            hover: { border: border}
        },
		shadow: {
			enabled: true,
			color: hexToRgba(baseColor, 0.6),
			size: 20,
			x: 0,
			y: 0
		},
        font: $.extend(true, {}, node.font || {}, {
            color: '#111827',
            bold: { color: '#111827', size: 13, face: 'Arial', mod: 'bold' }
        })
    });
    if (network) network.selectNodes([nodeId]);
}

function hexToRgba(hex, alpha) {
    if (!hex) return 'rgba(0,0,0,0.4)';

    // remove #
    hex = hex.replace('#', '');

    // handle shorthand (#abc)
    if (hex.length === 3) {
        hex = hex.split('').map(c => c + c).join('');
    }

    var r = parseInt(hex.substring(0, 2), 16);
    var g = parseInt(hex.substring(2, 4), 16);
    var b = parseInt(hex.substring(4, 6), 16);

    return 'rgba(' + r + ',' + g + ',' + b + ',' + alpha + ')';
}

function darkenHex(hex, factor) {
    if (!hex) return '#000000';

    hex = hex.replace('#', '');

    if (hex.length === 3) {
        hex = hex.split('').map(c => c + c).join('');
    }

    var r = Math.max(0, Math.floor(parseInt(hex.substring(0, 2), 16) * (1 - factor)));
    var g = Math.max(0, Math.floor(parseInt(hex.substring(2, 4), 16) * (1 - factor)));
    var b = Math.max(0, Math.floor(parseInt(hex.substring(4, 6), 16) * (1 - factor)));

    return '#' +
        r.toString(16).padStart(2, '0') +
        g.toString(16).padStart(2, '0') +
        b.toString(16).padStart(2, '0');
}

function clearSelectedNodeStyle() {
    if (!nodes || !selectedNodeId) { selectedNodeId = null; return; }
    var node = nodes.get(selectedNodeId);
    var original = selectedNodeOriginalStyle[selectedNodeId];
    if (node && original) {
        nodes.update({
            id: selectedNodeId,
            borderWidth: original.borderWidth !== undefined ? original.borderWidth : 1,
            borderWidthSelected: original.borderWidthSelected,
            color: original.color,
            font: original.font
        });
    }
    if (network) network.unselectAll();
    delete selectedNodeOriginalStyle[selectedNodeId];
    selectedNodeId = null;
}

function setSelectedNode(nodeId) {
    if (selectedNodeId === nodeId) {
        if (network) network.selectNodes([nodeId]);
        return;
    }
    clearSelectedNodeStyle();
    selectedNodeId = nodeId;
    applySelectedNodeStyle(nodeId);
}

function focusInspector(nodeId) {
    var resourceEntry = fhirResource[nodeId];
    if (!resourceEntry) return;

    setSelectedNode(nodeId);

    $('#resourceJSON').text(JSON.stringify(resourceEntry, null, 4));
    $('#resourceJSON').attr('data-highlighted', '');
    $('#HideResourceButton').attr('ref', nodeId);

    openInspectorDrawer();

    if (network) {
        network.setOptions({
            interaction: { hover: true, navigationButtons: false, keyboard: false, zoomView: false, dragView: false, hideEdgesOnDrag: false, hideEdgesOnZoom: false }
        });
        network.focus(nodeId, { scale: 1.2, animation: false });
        network.selectNodes([nodeId]);
    }

    // Always refresh validation panel when inspector opens
    refreshInspectorValidation();
}

function unfocusInspector() {
    closeInspectorDrawer();
    clearSelectedNodeStyle();
    if (network) {
        network.setOptions({
            interaction: { hover: true, navigationButtons: false, keyboard: false, zoomView: false, dragView: true, hideEdgesOnDrag: false, hideEdgesOnZoom: false }
        });
    }
}

// ─── Validation ───────────────────────────────────────────────────────────────

function buildBundleEntryIndex(bundle) {
    bundleEntryIndex = {};
    if (!bundle || !bundle.entry) return;
    bundle.entry.forEach(function (entry, idx) {
        if (!entry.resource) return;
        var r = entry.resource;
        if (r.resourceType && r.id) {
            bundleEntryIndex[idx] = r.resourceType + '/' + r.id;
        }
    });
}

function extractResourceKeyFromExpression(expression) {
    if (!expression) return "";

    // Named reference: Bundle.entry[3].resource/*Observation/3439*/
    var namedMatch = expression.match(/\/\*([^*]+)\*\//);
    if (namedMatch) return namedMatch[1];

    // Index only: Bundle.entry[3].resource or Bundle.entry[3].resource.something
    var indexMatch = expression.match(/Bundle\.entry\[(\d+)\]/);
    if (indexMatch) {
        var idx = parseInt(indexMatch[1]);
        return bundleEntryIndex[idx] || "";
    }

    return "";
}

function patchIssueResourceKeys(issues) {
    if (!issues) return;
    issues.forEach(function (issue) {
        if (!issue.resourceKey && issue.expression) {
            issue.resourceKey = extractResourceKeyFromExpression(issue.expression);
        }
    });
}

function loadValidationProfiles() {
    var select = document.getElementById('ValidationProfileSelector');
    if (!select) return;

    var profiles = window.FHIRNetworkConfig.validationProfiles || [];
    select.innerHTML = '<option value="">-- Select validation profile --</option>';
    profiles.forEach(function (p) {
        var opt = document.createElement('option');
        opt.value = p.code;
        opt.text = p.label || p.code;
        select.appendChild(opt);
    });
}

async function runValidation() {
    var select = document.getElementById('ValidationProfileSelector');
    var summaryEl = document.getElementById('ValidationSummary');
    if (!select) return;

    var profile = select.value;
    if (!profile) {
        summaryEl.innerHTML = "Select a validation profile.";
        return;
    }

    var bundle = buildVisibleBundleForValidation();
    buildBundleEntryIndex(bundle); // index the bundle we're actually sending

    try {
        summaryEl.classList.remove('is-hidden');
        summaryEl.innerHTML = "Validating...";

        const resp = await fetch(window.FHIRNetworkConfig.validationEndpoint, {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify({ validationProfile: profile, bundle: bundle })
        });

        if (!resp.ok) throw new Error("Validation failed: " + resp.status);

        var result = await resp.json();
        applyValidationResult(result);

    } catch (err) {
        console.error(err);
        summaryEl.innerHTML = "Validation failed.";
    }
}

function applyValidationResult(result) {
    if (!result || !result.resources) return;

    // Patch all missing resourceKeys using entry index
    Object.values(result.resources).forEach(function (v) {
        patchIssueResourceKeys(v.issues);
    });
    patchIssueResourceKeys(result.issues);

    validationState = result;

    renderValidationSummary(result.summary, result.resources["__bundle__"]);
    applyValidationBadges();
    refreshInspectorValidation();
}

function applyValidationBadges() {
    if (!nodes || !validationState || !validationState.resources) return;

    var updates = [];

    nodes.forEach(function (node) {
        var entry = fhirResource[node.id];
        if (!entry || !entry.resource) return;

        var key = entry.resource.resourceType + '/' + entry.resource.id;
        var v = validationState.resources[key];

        var baseLabel = node._baseLabel || node.label;
        if (!node._baseLabel) node._baseLabel = baseLabel;

        if (!v || v.severity === "ok") {
            updates.push({ id: node.id, label: baseLabel, borderWidth: 1 });
            return;
        }

        var badge = v.severity === "error"
            ? "\u{1F534}" //+ v.issueCount  	// 🔴
            : "\u{1F7E0}" //+ v.issueCount;		 // 🟠

        updates.push({
            id: node.id,
            label: baseLabel + "\n\n" + badge,
            borderWidth: v.severity === "error" ? 3 : 2
        });
    });

    nodes.update(updates);
}

function renderValidationSummary(summary, bundleNode) {
    var el = document.getElementById("ValidationSummary");
    if (!el) return;

    el.classList.remove("is-hidden");

    if (!summary || summary.issueCount === 0) {
        el.className = "validationSummary is-success";
        el.innerHTML = "No issues found.";
        return;
    }

    var cls = summary.error > 0 ? "is-error" : summary.warning > 0 ? "is-warning" : "is-info";
    el.className = "validationSummary " + cls;

    var html =
        "<div><b>Resources:</b> " + summary.resourceCount + "</div>" +
        "<div><b>Errors:</b> " + summary.error + "</div>" +
        "<div><b>Warnings:</b> " + summary.warning + "</div>" +
        "<div><b>Bundle issues:</b> " + summary.bundleIssueCount + "</div>";

    if (bundleNode && bundleNode.issues && bundleNode.issues.length) {
        html += "<div style='margin-top:8px; max-height:200px; overflow:auto;'>";
        bundleNode.issues.slice(0, 20).forEach(function (issue) {
            var rk = issue.resourceKey || "";
            var clickable = rk ? ' class="val-issue val-' + issue.severity + ' is-clickable" onclick="focusValidationResource(\'' + escapeHtml(rk) + '\')"'
                               : ' class="val-issue val-' + issue.severity + '"';
            html += "<div" + clickable + ">";
            if (rk) html += "<div class='val-resourcekey'>" + escapeHtml(rk) + "</div>";
            html += escapeHtml(issue.details || issue.code) + "</div>";
        });
        if (bundleNode.issues.length > 20) html += "<div>... (" + bundleNode.issues.length + " total)</div>";
        html += "</div>";
    }

    el.innerHTML = html;
}

function refreshInspectorValidation() {
    var panel = document.getElementById("InspectorValidationPanel");
    var headerRow = document.getElementById("InspectorValidationHeaderRow");
    var issuesEl = document.getElementById("InspectorValidationIssues");

    if (!panel || !issuesEl) return;

    if (!selectedNodeId || !validationState || !validationState.resources) {
        panel.classList.add("is-hidden");
        if (headerRow) headerRow.innerHTML = "";
        issuesEl.innerHTML = "";
        return;
    }

    var entry = fhirResource[selectedNodeId];
    if (!entry || !entry.resource) {
        panel.classList.add("is-hidden");
        if (headerRow) headerRow.innerHTML = "";
        issuesEl.innerHTML = "";
        return;
    }

    var resourceKey = entry.resource.resourceType + "/" + entry.resource.id;
    var v = validationState.resources[resourceKey];

    if (!v || !v.issues || !v.issues.length) {
        panel.classList.add("is-hidden");
        if (headerRow) headerRow.innerHTML = "";
        issuesEl.innerHTML = "";
        return;
    }

    var errorCount = 0;
    var warningCount = 0;
    var infoCount = 0;

    v.issues.forEach(function (issue) {
        var sev = (issue.severity || "").toLowerCase();

        if (sev === "fatal" || sev === "error") {
            errorCount++;
        } else if (sev === "warning") {
            warningCount++;
        } else {
            infoCount++;
        }
    });

	var parts = [];
	if (errorCount > 0) {
		parts.push('<span class="valCount valCount-error">\u{1F534} Errors: ' + errorCount + '</span>');
	}
	if (warningCount > 0) {
		parts.push('<span class="valCount valCount-warning">\u{1F7E0} Warnings: ' + warningCount + '</span>');
	}
	if (infoCount > 0) {
		parts.push('<span class="valCount valCount-info">\u{1F535} Infos: ' + infoCount + '</span>');
	}
	headerRow.innerHTML =
        '<div class="validationSectionTitle">Validation</div>' +
        '<div class="validationCountGroup">' + parts.join("") + '</div>';

    panel.classList.remove("is-hidden");
    issuesEl.innerHTML = "";

    v.issues.forEach(function (issue) {
        issuesEl.insertAdjacentHTML("beforeend", renderIssueHtml(issue));
    });
}

function focusValidationResource(resourceKey) {
    if (!resourceKey) return;
    var nodeId = resourceKey; // node IDs are already "ResourceType/id"
    if (!nodes.get(nodeId)) return;
    focusInspector(nodeId); // focusInspector now also calls refreshInspectorValidation
}

function buildVisibleBundleForValidation() {
    var entries = [];
    nodes.forEach(function (node) {
        if (node.hidden) return;
        var entry = fhirResource[node.id];
        if (!entry || !entry.resource) return;
        var resource = entry.resource;
        if (!resource.resourceType || !resource.id) return;
        entries.push({
            fullUrl: entry.fullUrl || (resource.resourceType + '/' + resource.id),
            resource: resource
        });
    });
    return { resourceType: "Bundle", type: "collection", entry: entries };
}

function escapeHtml(value) {
    return String(value == null ? "" : value)
        .replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;")
        .replace(/"/g, "&quot;").replace(/'/g, "&#39;");
}

function renderIssueHtml(issue) {
    var severity = escapeHtml(issue.severity || "");
    var details = escapeHtml(issue.details || "");
    var location = escapeHtml(issue.location || "");
    var resourceKey = issue.resourceKey || "";
    var resourceKeyHtml = escapeHtml(resourceKey);

    var clickableClass = resourceKey ? " is-clickable" : "";
    var clickAttr = resourceKey
        ? ' onclick="focusValidationResource(\'' + resourceKeyHtml.replace(/'/g, "\\'") + '\')"'
        : "";

    var html = '<div class="val-issue val-' + severity + clickableClass + '"' + clickAttr + '>';
    html += '<div><b>' + severity.toUpperCase() + '</b></div>';
    if (resourceKey) html += '<div class="val-resourcekey">' + resourceKeyHtml + '</div>';
    if (location) html += '<div class="val-location">' + location + '</div>';
    html += '<div>' + details + '</div>';
    html += '</div>';
    return html;
}

// ─── Zoom & layout ────────────────────────────────────────────────────────────

function zoomNetwork(factor) {
    if (!network) return;
    var scale = network.getScale();
    var newScale = Math.min(2.5, Math.max(0.3, scale * factor));
    network.moveTo({ scale: newScale, animation: { duration: 150, easingFunction: 'easeInOutQuad' } });
}

function enablePhysicsTemporarily(duration) {
    if (!network) return;
    if (physicsFreezeTimer) { clearTimeout(physicsFreezeTimer); physicsFreezeTimer = null; }
    network.setOptions({ physics: { enabled: true } });
    physicsFreezeTimer = setTimeout(function () {
        if (network) network.setOptions({ physics: { enabled: false } });
        physicsFreezeTimer = null;
    }, duration || 2000);
}

function fitNetwork() {
    if (!network) return;
    network.setSize('100%', '100%');
    network.redraw();
    network.fit({ animation: { duration: 200, easingFunction: 'easeInOutQuad' } });
}

function resetNetworkLayout() {
    if (!network || !nodes) return;
    unfixAllNodes();
    network.setOptions({ physics: { enabled: true } });
    network.stabilize(80);
    network.once('stabilizationIterationsDone', function () {
        pinKeyNodesToCorners();
        network.fit({ animation: { duration: 250, easingFunction: 'easeInOutQuad' } });
        network.setOptions({ physics: { enabled: false } });
    });
}

function handleZoomPress(factor) {
    stopZoomInteraction();
    zoomHoldDelay = setTimeout(function () {
        zoomHoldDelay = null;
        zoomTimer = setInterval(function () { zoomNetwork(factor); }, 120);
    }, 200);
}

function handleZoomRelease(factor) {
    if (zoomHoldDelay) { clearTimeout(zoomHoldDelay); zoomHoldDelay = null; zoomNetwork(factor); }
    stopZoomInteraction();
}

function stopZoomInteraction() {
    if (zoomHoldDelay) { clearTimeout(zoomHoldDelay); zoomHoldDelay = null; }
    if (zoomTimer) { clearInterval(zoomTimer); zoomTimer = null; }
}

function wireZoomButtons() {
    var zoomIn = document.getElementById('ZoomInButton');
    var zoomOut = document.getElementById('ZoomOutButton');
    var zoomFit = document.getElementById('ZoomFitButton');
    var railToggle = document.getElementById('RailToggleButton');
    var closeInspector = document.getElementById('CloseInspectorButton');
    var backdrop = document.getElementById('DrawerBackdrop');
    var presetSelector = document.getElementById('PresetSelector');

    function bindZoomButton(button, factor) {
        if (!button) return;
        button.onpointerdown = function (e) { e.preventDefault(); handleZoomPress(factor); };
        button.onpointerup = function (e) { e.preventDefault(); handleZoomRelease(factor); };
        button.onpointerleave = stopZoomInteraction;
        button.onpointercancel = stopZoomInteraction;
    }

    bindZoomButton(zoomIn, 1.15);
    bindZoomButton(zoomOut, 1 / 1.15);

    if (zoomFit) {
        zoomFit.onclick = function () {
            if (!fitButtonPrimed) {
                fitNetwork();
                fitButtonPrimed = true;
                zoomFit.title = 'Click again to reset layout';
                setTimeout(function () { fitButtonPrimed = false; zoomFit.title = 'Fit network'; }, 1500);
            } else {
                fitButtonPrimed = false;
                zoomFit.title = 'Fit network';
                resetNetworkLayout();
            }
        };
    }

    if (presetSelector) presetSelector.onchange = function () { applyPreset(this.value); };
    if (railToggle) railToggle.onclick = toggleLeftDrawer;
    if (closeInspector) closeInspector.onclick = unfocusInspector;
    if (backdrop) backdrop.onclick = function () { closeLeftDrawer(); unfocusInspector(); };
}

// ─── Init ─────────────────────────────────────────────────────────────────────

window.addEventListener("load", function () {
    nodes = new vis.DataSet();
    edges = new vis.DataSet();

    var container = document.getElementById("VisNetworkPane");
    var data = { nodes: nodes, edges: edges };

    var options = {
        autoResize: false,
        nodes: { shape: 'box', borderWidth: 1, margin: 12, font: { multi: 'html', size: 13, face: 'Arial' } },
        edges: {
            arrows: { to: true },
            color: { color: '#94a3b8', highlight: '#64748b' },
            font: { multi: 'html', size: 11, color: '#94a3b8', ital: { color: '#94a3b8', size: 11, face: 'Arial', vadjust: 0, mod: 'italic' } },
            smooth: { type: 'continuous', roundness: 0.24 }
        },
        layout: { improvedLayout: true },
        physics: {
            forceAtlas2Based: { gravitationalConstant: -42, centralGravity: 0.01, springLength: 285, springConstant: 0.06, damping: 0.55, avoidOverlap: 0.9 },
            maxVelocity: 18, minVelocity: 0.5, solver: "forceAtlas2Based", timestep: 0.18, adaptiveTimestep: true,
            stabilization: { enabled: true, iterations: 80, updateInterval: 25, fit: true }
        },
        interaction: { dragNodes: true, dragView: true, hover: true, zoomView: false }
    };

    network = new vis.Network(container, data, options);

    network.on('click', function (event) {
        if (event.nodes[0] === undefined) { unfocusInspector(); } else { focusInspector(event.nodes[0]); }
    });

    network.on('dragStart', function (params) {
        if (params.nodes && params.nodes.length) {
            nodes.update(params.nodes.map(function (id) { return { id: id, fixed: { x: false, y: false } }; }));
            network.setOptions({ physics: { enabled: true } });
        }
    });

    network.on('dragEnd', function (params) {
        if (params.nodes && params.nodes.length) {
            var positions = network.getPositions(params.nodes);
            nodes.update(params.nodes.map(function (id) {
                return { id: id, x: positions[id].x, y: positions[id].y, fixed: { x: true, y: true } };
            }));
            network.setOptions({ physics: { enabled: false } });
        }
    });

	network.on("hoverNode", function (params) {
		var nodeId = params.node;
		var node = nodes.get(nodeId);
		if (!node) return;

		var bg =
			(node.color && node.color.background)
			|| color(nodeId.split('/')[0]); // fallback

		nodes.update({
			id: nodeId,
			shadow: {
				enabled: true,
				color: hexToRgba(bg, 0.6),
				size: 20,
				x: 0,
				y: 0
			}
		});
	});

	network.on("blurNode", function (params) {
		nodes.update({
			id: params.node,
			shadow: { enabled: false }
		});
	});

    document.addEventListener('mouseup', stopZoomInteraction);
    document.addEventListener('pointerup', stopZoomInteraction);
    document.addEventListener('pointercancel', stopZoomInteraction);
    window.addEventListener('blur', stopZoomInteraction);

    parse();
    wireZoomButtons();
    loadValidationProfiles();

    var runBtn = document.getElementById('RunValidationButton');
    if (runBtn) runBtn.addEventListener('click', runValidation);

    $('#ToggleAllResourceTypesButton').on('click', toggleAllResourceTypes);

    $('#HideResourceButton').on('click', function () {
        var nodeId = this.getAttribute('ref');
        if (!nodeId) return;
        if (selectedNodeId === nodeId) clearSelectedNodeStyle();
        nodes.remove({ id: nodeId });
        createUnhideButton(nodeId);
        unfocusInspector();
    });

    window.addEventListener('resize', function () {
        if (network) { network.setSize('100%', '100%'); network.redraw(); }
    });
});

// ─── Pin key nodes ────────────────────────────────────────────────────────────

function pinKeyNodesToCorners() {
    if (!network || !nodes) return;
    var allNodes = nodes.get();
    if (!allNodes.length) return;

    var nodeCount = allNodes.length;
    var scale = 0.39;
    var spread = Math.max(700, Math.round(Math.sqrt(nodeCount) * 180));
    var halfWidth = Math.round(spread * 1.1 * scale);
    var halfHeight = Math.round(spread * 0.8 * scale);

    var positions = {
        topLeft:     { x: -halfWidth, y: -halfHeight },
        topRight:    { x:  halfWidth, y: -halfHeight },
        bottomLeft:  { x: -halfWidth, y:  halfHeight },
        bottomRight: { x:  halfWidth, y:  halfHeight }
    };

    function degree(nodeId) { return network.getConnectedNodes(nodeId).length; }

    var patientNode = allNodes.find(function (n) { return n.id.indexOf('Patient/') === 0; });

    var encounterNodes = allNodes.filter(function (n) { return n.id.indexOf('Encounter/') === 0; });
    encounterNodes.sort(function (a, b) { return degree(b.id) - degree(a.id); });
    var encounterNode = encounterNodes.length ? encounterNodes[0] : null;

    var excluded = {};
    if (patientNode) excluded[patientNode.id] = true;
    if (encounterNode) excluded[encounterNode.id] = true;

    function nodePriority(node) {
        var type = node.id.split('/')[0];
        var score = degree(node.id);
        if (type === 'Organization' || type === 'Condition' || type === 'Procedure') score += 2;
        return score;
    }

    var remaining = allNodes
        .filter(function (n) { return !excluded[n.id]; })
        .map(function (n) { return { id: n.id, score: nodePriority(n) }; })
        .sort(function (a, b) { return b.score - a.score; });

    var updates = [];
    if (patientNode)   updates.push({ id: patientNode.id,   ...positions.topLeft,    fixed: { x: true, y: true } });
    if (encounterNode) updates.push({ id: encounterNode.id, ...positions.topRight,   fixed: { x: true, y: true } });
    if (remaining[0])  updates.push({ id: remaining[0].id,  ...positions.bottomLeft, fixed: { x: true, y: true } });
    if (remaining[1])  updates.push({ id: remaining[1].id,  ...positions.bottomRight,fixed: { x: true, y: true } });

    if (updates.length) nodes.update(updates);
}