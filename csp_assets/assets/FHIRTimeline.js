var timeline = null;

var allItems = [];
var items2 = null;
var initialWindowSet = false;

var replayTimer = null;
var replayIndex = 0;
var replayIds = [];
var lastReplayId = null;

var fhirRef = [];
var fhirResource = [];
var tooltipEl = null;

var selectedEncounterId = null;
var encounterScopes = {};

var options = {
	order: function (a, b) {
		return b.id - a.id;
	},
	groupOrder: function (a, b) {
		return a.value - b.value;
	},
	align: 'left',
	editable: false,
	configure: false,
	locale: 'de',
	orientation: 'both',
	zoomable: false,
	verticalScroll: true,
	stack: false,
	stackSubgroups: false,
	showCurrentTime: false,
	autoResize: true,
	margin: {
		item: {
			horizontal: 0
		},
		axis: 5
	},
	zoomMin: 1000 * 60 * 60 * 6,
	zoomMax: 1000 * 60 * 60 * 24 * 31 * 24,
	groupTemplate: function (group) {
		var container = document.createElement("div");

		if (group.id === 'EncounterFall') {
			container.innerHTML = '<span>Episode</span>';
		} else if (group.id === 'EncounterAK') {
			container.innerHTML = '<span style="padding-left:1em;">&#x25B8; Department</span>';
		} else if (group.id === 'EncounterVK') {
			container.innerHTML = '<span style="padding-left:1em;">&#x25B8; Care Unit</span>';
		} else {
			container.innerHTML = '<span>' + group.content + '</span>';
		}

		return container;
	},
	template: function (item) {
		var container = document.createElement('div');
		container.className = 'timeline-tooltip-anchor';
		container.innerHTML = item.content || '';

		if (item.tooltip) {
			container.addEventListener('mouseenter', function (evt) {
				showTooltip(item.tooltip, evt);
			});

			container.addEventListener('mousemove', function (evt) {
				moveTooltip(evt);
			});

			container.addEventListener('mouseleave', function () {
				hideTooltip();
			});
		}

		return container;
	}
};

var groups = new vis.DataSet([
	{
		id: 'EncounterFall',
		value: 0,
		content: 'Fall',
		className: 'Encounters'
	},
	{
		id: 'EncounterAK',
		value: 1,
		content: 'Abteilung',
		className: 'Encounters'
	},
	{
		id: 'EncounterVK',
		value: 2,
		content: 'Versorgungsstelle',
		className: 'Encounters'
	},
	{
		id: 'Condition',
		value: 3,
		content: 'Conditions',
		className: 'Conditions'
	},
	{
		id: 'Procedure',
		value: 4,
		content: 'Procedures',
		className: 'Procedures'
	},
	{
		id: 'Observation',
		value: 5,
		content: 'Observations',
		className: 'Observations'
	},
	{
		id: 'Medication',
		value: 6,
		content: 'Medications',
		className: 'Medications'
	}
]);

$(document).ready(function () {
	var container = document.getElementById('visualization');
	if (!container) {
		console.error('Timeline container #visualization not found');
		return;
	}

	timeline = new vis.Timeline(container);
	timeline.setOptions(options);
	timeline.setGroups(groups);

	wireUiEvents();
	wireTimelineEvents();
	parse();
});

function animateToItem(itemId, delayMs) {
	delayMs = delayMs || 0;

	if (!items2) return;

	var item = items2.get(itemId);
	if (!item || !item.start) return;

	setTimeout(function () {
		timeline.moveTo(item.start, {
			animation: {
				duration: 600,
				easingFunction: 'easeInOutQuad'
			}
		});

		setTimeout(function () {
			timeline.focus(itemId, {
				animation: {
					duration: 600,
					easingFunction: 'easeInOutQuad'
				}
			});
		}, 100);
	}, delayMs);
}

function wireUiEvents() {
	var buttonRefit = document.getElementById("buttonRefit");
	if (buttonRefit) {
		buttonRefit.onclick = function () {
			groups.forEach(function (group) {
				groups.update({ id: group.id, visible: true });
			});

			var focusItem = getInitialFocusItem();
			fitTimeline();
			if (focusItem) animateToItem(focusItem.id, 200);
		};
	}

	var buttonReplay = document.getElementById("buttonReplay");
	if (buttonReplay) {
		buttonReplay.onclick = function () {
			if (!replayIds.length) {
				startReplay();
			} else {
				showReplayStep();
			}
		};
	}

	var buttonReplayCardPrev = document.getElementById("buttonReplayCardPrev");
	if (buttonReplayCardPrev) {
		buttonReplayCardPrev.onclick = function () {
			buttonReplayCardPrev.disabled = (replayIndex <= 1);
			if (!replayIds.length) return;

			replayIndex = Math.max(0, replayIndex - 2); 
			// -2 because showReplayStep() increments afterwards

			showReplayStep();
		};
	}

	var buttonReplayCardNext = document.getElementById("buttonReplayCardNext");
	if (buttonReplayCardNext) {
		buttonReplayCardNext.onclick = function () {

			// If finished → refit + reset
			if (replayIndex >= replayIds.length) {
				stopReplay();

				var focusItem = getInitialFocusItem();
				fitTimeline();

				if (focusItem) {
					animateToItem(focusItem.id, 200);
				}

				return;
			}

			if (!replayIds.length) {
				startReplay();
			} else {
				showReplayStep();
			}
		};
	}

	var buttonReplayCardCancel = document.getElementById("buttonReplayCardCancel");
	if (buttonReplayCardCancel) {
		buttonReplayCardCancel.onclick = function () {
			stopReplay();
			var focusItem = getInitialFocusItem();
			fitTimeline();

			if (focusItem) {
				animateToItem(focusItem.id, 200);
			}
		};
	}

	var encounterSelector = document.getElementById('EncounterSelector');
	if (encounterSelector) {
		encounterSelector.onchange = function () {
			applyEncounterScope(this.value);
		};
	}
}

function wireTimelineEvents() {
	timeline.on('select', function (selectedObj) {
		if (selectedObj.items.length > 0) {
			var id = selectedObj.items[0];
			console.log('fhirResource[fhirRef["' + id + '"]] :', fhirResource[fhirRef[id]]);
			animateToItem(id);
		}
	});

	timeline.on('rangechange', function () {
		hideTooltip();
	});

	timeline.on('changed', function () {
		hideTooltip();
	});
}

function ensureTooltipElement() {
	if (!tooltipEl) {
		tooltipEl = document.getElementById('timelineTooltip');
	}
	return tooltipEl;
}

function showTooltip(html, evt) {
	var el = ensureTooltipElement();
	if (!el || !html) return;

	el.innerHTML = html;
	el.style.display = 'block';
	moveTooltip(evt);
}

function moveTooltip(evt) {
	var el = ensureTooltipElement();
	if (!el || el.style.display === 'none') return;

	var offsetX = 14;
	var offsetY = 14;
	var left = evt.clientX + offsetX;
	var top = evt.clientY + offsetY;

	var rect = el.getBoundingClientRect();
	var maxLeft = window.innerWidth - rect.width - 8;
	var maxTop = window.innerHeight - rect.height - 8;

	if (left > maxLeft) left = Math.max(8, evt.clientX - rect.width - 14);
	if (top > maxTop) top = Math.max(8, evt.clientY - rect.height - 14);

	el.style.left = left + 'px';
	el.style.top = top + 'px';
}

function hideTooltip() {
	var el = ensureTooltipElement();
	if (!el) return;

	el.style.display = 'none';
	el.innerHTML = '';
}

function zzzupdateReplayStatus() {
	var el = document.getElementById('replayStatus');
	if (!el) return;

	if (replayIds.length > 0 && replayIndex > 0 && replayIndex <= replayIds.length) {
		el.style.display = 'inline';
		el.innerHTML = 'Move ' + replayIndex + '/' + replayIds.length;
	} else {
		el.style.display = 'none';
		el.innerHTML = '';
	}
}

function getReplayItems() {
	if (!selectedEncounterId || !encounterScopes[selectedEncounterId] || !items2) return [];

	var scope = encounterScopes[selectedEncounterId];

	var replayItems = items2.get({
		filter: function (item) {
			return scope.vkItemIds.indexOf(item.id) !== -1 && item.className !== 'enc-special';
		}
	});

	replayItems.sort(function (a, b) {
		return new Date(a.start) - new Date(b.start);
	});

	return replayItems;
}

function startReplay() {
	var replayItems = getReplayItems();
	if (!replayItems.length) {
		console.log('No VK items available for replay.');
		return;
	}

	timeline.setSelection([]);

	replayIds = replayItems.map(function (item) {
		return item.id;
	});

	replayIndex = 0;
	hideTooltip();
	hideReplayCard();
	updateReplayControls();

	var btn = document.getElementById('buttonReplay');
	if (btn) btn.innerHTML = '&#9654; Next';

	showReplayStep();
}

function stopReplay() {
	if (replayTimer) {
		clearInterval(replayTimer);
		replayTimer = null;
	}

	if (lastReplayId !== null && items2) {
		var prevItem = items2.get(lastReplayId);
		if (prevItem) {
			var cleanedClass = (prevItem.className || '').replace(/\s*replay-active\b/g, '');
			items2.update({
				id: lastReplayId,
				className: cleanedClass.trim()
			});
		}
		lastReplayId = null;
	}

	replayIndex = 0;
	replayIds = [];
	hideTooltip();
	hideReplayCard();
	updateReplayControls();

	var btn = document.getElementById('buttonReplay');
	if (btn) btn.innerHTML = '&#9654; Replay';
}

function showReplayStep() {
	if (!replayIds.length || !items2) {
		stopReplay();
		return;
	}

	if (replayIndex >= replayIds.length) {
		stopReplay();
		return;
	}

	var id = replayIds[replayIndex];
	var item = items2.get(id);

	if (!item) {
		replayIndex++;
		showReplayStep();
		return;
	}

	if (lastReplayId !== null) {
		var prevItem = items2.get(lastReplayId);
		if (prevItem) {
			var cleanedClass = (prevItem.className || '').replace(/\s*replay-active\b/g, '');
			items2.update({
				id: lastReplayId,
				className: cleanedClass.trim()
			});
		}
	}

	item = items2.get(id);

	var newClass = (item.className || '');
	if (!/\breplay-active\b/.test(newClass)) {
		newClass = (newClass + ' replay-active').trim();
	}
	items2.update({
		id: id,
		className: newClass
	});

	lastReplayId = id;

	animateToItem(id);

	replayIndex++;
	updateReplayControls();

	showReplayCard(buildReplayCardHtml(item, replayIndex, replayIds.length));

	console.log('Replay focus on item', id, fhirResource[fhirRef[id]]);
}

function parse() {
	stopReplay();

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

	document.getElementById('pageToolbar').style.visibility = 'visible';
	document.getElementById('visualization').style.visibility = 'visible';

	var bundle = JSON.parse(tFHIR);

	allItems = [];
	fhirRef = [];
	fhirResource = [];
	encounterScopes = {};
	selectedEncounterId = null;
	initialWindowSet = false;

	bundle.entry.forEach(processEntry);

	console.log("Total timeline items:", allItems.length);
	console.log("Timeline items:", allItems);

	buildEncounterScopes();
	populateEncounterSelector();

	var latestEkId = getLatestEncounterScopeId();
	if (latestEkId) {
		applyEncounterScope(latestEkId);
	}
}

function applyEncounterScope(ekId) {
	stopReplay();

	if (!ekId || !encounterScopes[ekId]) {
		console.log('Encounter scope not found:', ekId);
		return;
	}

	selectedEncounterId = ekId;
	initialWindowSet = false; // ✅ reset per scope

	var scope = encounterScopes[ekId];

	var visibleItems = allItems.filter(function (item) {
		return scope.itemIds.indexOf(item.id) !== -1;
	});

	items2 = new vis.DataSet(visibleItems);
	timeline.setItems(items2);

	var summary = buildPatientSummary();
	var summaryEl = document.getElementById('PatientSummary');
	if (summaryEl) summaryEl.innerHTML = summary;

	var selector = document.getElementById('EncounterSelector');
	if (selector && selector.value !== ekId) {
		selector.value = ekId;
	}

	timeline.once('changed', function () {
		if (initialWindowSet) return;

		var focusItem = getInitialFocusItem();
		if (!focusItem) return;

		timeline.fit({ animation: false });

		timeline.focus(focusItem.id, {
			animation: false,
			scale: 0.5
		});

		initialWindowSet = true;
	});
}

function fitTimeline() {
	timeline.fit({ duration: 500, easingFunction: 'easeInOutQuint' });
}

function calculateAge(birthdate) {
	var birthdateObj = new Date(birthdate);
	var currentDate = new Date();
	var age = currentDate.getFullYear() - birthdateObj.getFullYear();

	var hasBirthdayOccurred = (
		currentDate.getMonth() > birthdateObj.getMonth() ||
		(currentDate.getMonth() === birthdateObj.getMonth() && currentDate.getDate() >= birthdateObj.getDate())
	);

	if (!hasBirthdayOccurred) {
		age--;
	}

	return age;
}

function cacheEntry(entry) {
	if (fhirResource[entry.resource.id] !== undefined) {
		console.log(
			'<WARNING> Duplicate resource ID found in ',
			'1. ' + fhirResource[entry.resource.id].resourceType + '/' + entry.resource.id,
			'2. ' + entry.resource.resourceType + '/' + entry.resource.id
		);
	}

	if (entry.fullUrl) {
		entry.resource.fullUrl = entry.fullUrl;
	}

	fhirResource[entry.resource.id] = entry.resource;
}

function ensureMinimumDuration(tItem, minutes) {
	if (tItem.start === undefined) return;
	if (tItem.end === undefined) return;
	if (tItem.start != tItem.end) return;

	var startDate = new Date(tItem.start);
	var endDate = new Date(startDate.getTime() + (1000 * 60 * minutes));
	tItem.end = endDate.toISOString();
}

function subtractOneMinute(isoDateString) {
	var d = new Date(isoDateString);
	d.setMinutes(d.getMinutes() - 1);
	return d.toISOString();
}

function processEntry(entry) {
	var supportedTypes = {
		Patient: true,
		Encounter: true,
		Condition: true,
		Procedure: true,
		Observation: true,
		Medication: true,
		MedicationStatement: true,
		MedicationAdministration: true,
		OperationOutcome: true
	};

	if (!supportedTypes[entry.resource.resourceType]) {
		return;
	}

	cacheEntry(entry);
	var resource = entry.resource;

	var tItemId = allItems.length + 1;
	var tItem = {
		id: tItemId,
		resourceId: resource.id,
		resourceType: resource.resourceType
	};

	if (resource.encounter && resource.encounter.reference) {
		tItem.encounterRef = resource.encounter.reference;
	}

	fhirRef[tItemId] = resource.id;

	if (resource.resourceType == 'Patient') {
		// patient identity shown elsewhere

	} else if (resource.resourceType == 'Encounter') {
		if (resource.period === undefined) return;

		var isA04 = false;
		if (resource.meta && resource.meta.tag && Array.isArray(resource.meta.tag)) {
			isA04 = resource.meta.tag.some(function (t) {
				return t.system === 'http://healthshare/mii/tags' && t.code === 'A04';
			});
		}

		tItem.start = resource.period.start;
		if (tItem.start === undefined) return;

		if (resource.period.end !== undefined) {
			tItem.end = resource.period.end;
		}

		var encounterType = (resource.type === undefined)
			? 'Einrichtungskontakt'
			: resource.type[0].coding[0].display;

		tItem.encounterLevel = encounterType;
		tItem.parentEncounterId = getEncounterParentId(resource);

		if (isA04) {
			if (encounterType == 'Abteilungskontakt') {
				tItem.group = 'EncounterAK';
				tItem.content = (resource.serviceProvider ? resource.serviceProvider.display : '\u2695 A04') +
					(resource.serviceType ? ' (' + resource.serviceType.coding[0].display + ')' : '');
				tItem.title = '\u2695 Konsil / OP';
			} else if (encounterType == 'Versorgungsstellenkontakt') {
				tItem.group = 'EncounterVK';
				var locationsString = (resource.location || [])
					.map(getLocationString)
					.filter(Boolean)
					.join('; ');
				tItem.content = locationsString || '\u2695 A04';
				tItem.title = '\u2695 Konsil / OP';
			} else {
				tItem.group = 'EncounterFall';
				tItem.content = '\u2695 A04';
				tItem.title = '\u2695 Konsil / OP';
			}

			tItem.type = 'box';
			tItem.className = 'enc-special';
			delete tItem.end;

		} else if (encounterType == 'Einrichtungskontakt') {
			tItem.group = 'EncounterFall';
			tItem.className = 'enc-fall';
			tItem.content = '\u{1F3E2} Episode #' + resource.identifier[0].value + ' status:' + resource.status;

			var startText = formatDateTime(tItem.start);
			var endText = formatDateTime(tItem.end);

			tItem.tooltip =
				'<b>\u{1F3E2} Fallnummer:</b> ' + (resource.identifier && resource.identifier[0] ? resource.identifier[0].value : resource.id) + '<br>' +
				'<br><b>Status</b><br>' + (resource.status || '-') + '<br>' +
				'<br><b>Zeit</b><br>' +
				'von: ' + startText + '<br>' +
				(endText ? 'bis: ' + endText : '') + '<br>';

		} else if (encounterType == 'Abteilungskontakt') {
			tItem.group = 'EncounterAK';
			tItem.className = 'enc-ak';
			tItem.content = (resource.serviceProvider ? resource.serviceProvider.display : 'AK') +
				(resource.serviceType ? ' (' + resource.serviceType.coding[0].display + ')' : '');

		} else if (encounterType == 'Versorgungsstellenkontakt') {
			tItem.group = 'EncounterVK';
			tItem.className = 'enc-vk';

			var locationSummary = getLocationSummary(resource);
			var vkStartText = formatDateTime(tItem.start);
			var vkEndText = formatDateTime(tItem.end);

			tItem.content = locationSummary.short || (resource.class ? resource.class.code : 'VK');
			tItem.locationLong = locationSummary.long || (resource.class ? resource.class.code : 'VK');
			tItem.tooltip =
				'<b>Location</b><br>' + tItem.locationLong.replace(/\n/g, '<br>') + '<br>' +
				'<br><b>Zeit</b><br>' +
				'von: ' + vkStartText + '<br>' +
				(vkEndText ? 'bis: ' + vkEndText : '') + '<br>';
		} else {
			tItem.group = 'EncounterVK';
			tItem.className = 'enc-vk';
			tItem.content = 'Encounter';
			tItem.title = 'resource id: ' + resource.id;
		}

		if (tItem.type !== 'box') {
			ensureMinimumDuration(tItem, 30);
		}
		allItems.push(tItem);

	} else if (resource.resourceType == 'Condition') {
		tItem.start = resource.recordedDate;
		tItem.group = 'Condition';
		tItem.content = resource.code.coding[0].display;
		tItem.title = '[' + resource.code.coding[0].code + '] ' + resource.code.coding[0].display;
		allItems.push(tItem);

	} else if (resource.resourceType == 'Procedure') {
		tItem.start = resource.performedDateTime;
		tItem.group = 'Procedure';
		tItem.content = resource.code.coding[0].display;
		tItem.title = '[' + resource.code.coding[0].code + '] ' + resource.code.coding[0].display;
		allItems.push(tItem);

	} else if (resource.resourceType == 'Observation') {
		tItem.start = resource.effectiveDateTime;
		tItem.group = 'Observation';
		tItem.content = getObservationString(resource);

		var obsCode = '';
		var obsDisplay = 'Observation';

		if (resource.code && resource.code.coding && resource.code.coding[0]) {
			obsCode = resource.code.coding[0].code || '';
			obsDisplay = resource.code.coding[0].display || obsDisplay;
		}

		tItem.title = (obsCode ? '[' + obsCode + '] ' : '') + obsDisplay;
		allItems.push(tItem);

	} else if (resource.resourceType == 'MedicationStatement') {
		if (resource.effectivePeriod !== undefined) {
			tItem.start = resource.effectivePeriod.start;
			if (resource.effectivePeriod.end !== undefined) {
				tItem.end = resource.effectivePeriod.end;
			}
		} else if (resource.effectiveDateTime !== undefined) {
			tItem.start = resource.effectiveDateTime;
		} else {
			console.log('No Timestamp, skipping resource:', resource);
			return;
		}

		tItem.group = 'Medication';
		tItem.className = 'medication-statement';
		tItem.content = '\u{1F48A} ' + getMedicationTimelineLabel(resource);
		tItem.tooltip = buildMedicationTooltip(resource);
		tItem.title = getMedicationTimelineLabel(resource);

		if (tItem.end !== undefined) {
			ensureMinimumDuration(tItem, 15);
		}

		allItems.push(tItem);

	} else if (resource.resourceType == 'MedicationAdministration') {
		if (resource.effectivePeriod !== undefined) {
			tItem.start = resource.effectivePeriod.start;
			if (resource.effectivePeriod.end !== undefined) {
				tItem.end = resource.effectivePeriod.end;
			}
		} else if (resource.effectiveDateTime !== undefined) {
			tItem.start = resource.effectiveDateTime;
		} else {
			console.log('No Timestamp, skipping resource:', resource);
			return;
		}

		tItem.group = 'Medication';
		tItem.className = 'medication-administration';
		tItem.content = '\u{1F48A} ' + getMedicationTimelineLabel(resource);
		tItem.tooltip = buildMedicationTooltip(resource);
		tItem.title = getMedicationTimelineLabel(resource);

		if (tItem.end !== undefined) {
			ensureMinimumDuration(tItem, 15);
		}

		allItems.push(tItem);
	} else if (resource.resourceType == 'Medication') {
		// cached for reference resolution, no timeline item
		return;

	} else if (resource.resourceType == 'OperationOutcome') {
		console.log('<WARNING> Issues were found!', resource);
	}

	if (tItem.start === undefined && resource.resourceType !== 'Patient') {
		tItem.start = Date.now();
		console.log('tItem.start undefined for ' + resource.resourceType + '/' + resource.id);
	}
}

function buildEncounterScopes() {
	encounterScopes = {};

	var encounterItems = allItems.filter(function (item) {
		return item.resourceType === 'Encounter';
	});

	var encounterItemByResourceId = {};
	encounterItems.forEach(function (item) {
		encounterItemByResourceId[item.resourceId] = item;
	});

	var ekItems = encounterItems.filter(function (item) {
		return item.group === 'EncounterFall';
	});

	ekItems.forEach(function (ekItem) {
		encounterScopes[ekItem.resourceId] = {
			ekId: ekItem.resourceId,
			ekItemId: ekItem.id,
			akItemIds: [],
			vkItemIds: [],
			itemIds: [ekItem.id],
			start: ekItem.start,
			end: ekItem.end,
			label: buildEncounterLabel(ekItem)
		};
	});

	encounterItems.forEach(function (item) {
		if (item.group === 'EncounterFall') return;

		var ekId = resolveRootEkId(item.resourceId, encounterItemByResourceId);
		if (!ekId || !encounterScopes[ekId]) return;

		encounterScopes[ekId].itemIds.push(item.id);

		if (item.group === 'EncounterAK') {
			encounterScopes[ekId].akItemIds.push(item.id);
		} else if (item.group === 'EncounterVK') {
			encounterScopes[ekId].vkItemIds.push(item.id);
		}
	});

	allItems.forEach(function (item) {
		if (item.resourceType === 'Encounter' || item.resourceType === 'Patient') return;

		var ekId = resolveItemScopeByEncounterOrTime(item, encounterItemByResourceId);
		if (!ekId || !encounterScopes[ekId]) return;

		encounterScopes[ekId].itemIds.push(item.id);
	});
}

function resolveItemScopeByEncounterOrTime(item, encounterItemByResourceId) {
	var encounterId = normalizeEncounterReference(item.encounterRef);
	if (encounterId) {
		var ekId = resolveRootEkId(encounterId, encounterItemByResourceId);
		if (ekId) return ekId;
	}

	var itemTime = item.start ? new Date(item.start).getTime() : null;
	if (!itemTime) return null;

	var matchingScopeIds = Object.keys(encounterScopes).filter(function (ekId) {
		var scope = encounterScopes[ekId];
		if (!scope.start) return false;

		var start = new Date(scope.start).getTime();
		var end = scope.end ? new Date(scope.end).getTime() : start;
		return itemTime >= start && itemTime <= end;
	});

	if (!matchingScopeIds.length) return null;

	matchingScopeIds.sort(function (a, b) {
		return new Date(encounterScopes[b].start) - new Date(encounterScopes[a].start);
	});

	return matchingScopeIds[0];
}

function resolveRootEkId(encounterResourceId, encounterItemByResourceId) {
	var seen = {};
	var currentId = encounterResourceId;

	while (currentId && !seen[currentId]) {
		seen[currentId] = true;

		var item = encounterItemByResourceId[currentId];
		if (!item) return null;

		if (item.group === 'EncounterFall') {
			return currentId;
		}

		currentId = item.parentEncounterId;
	}

	return null;
}

function getEncounterParentId(resource) {
	if (!resource || !resource.partOf || !resource.partOf.reference) return null;

	var ref = resource.partOf.reference;
	if (ref.indexOf('Encounter/') === 0) {
		return ref.split('/')[1];
	}

	return null;
}

function normalizeEncounterReference(ref) {
	if (!ref) return null;

	if (ref.indexOf('Encounter/') === 0) {
		return ref.split('/')[1];
	}

	return null;
}

function populateEncounterSelector() {
	var selector = document.getElementById('EncounterSelector');
	if (!selector) return;

	selector.innerHTML = '';

	var scopeList = Object.keys(encounterScopes).map(function (ekId) {
		return encounterScopes[ekId];
	});

	scopeList.sort(function (a, b) {
		return new Date(b.start) - new Date(a.start);
	});

	scopeList.forEach(function (scope) {
		var opt = document.createElement('option');
		opt.value = scope.ekId;
		opt.textContent = scope.label;
		selector.appendChild(opt);
	});
}

function getLatestEncounterScopeId() {
	var scopeIds = Object.keys(encounterScopes);
	if (!scopeIds.length) return null;

	scopeIds.sort(function (a, b) {
		return new Date(encounterScopes[b].start) - new Date(encounterScopes[a].start);
	});

	return scopeIds[0];
}

function buildEncounterLabel(ekItem) {
	var resource = fhirResource[ekItem.resourceId];
	var encounterNo = resource && resource.identifier && resource.identifier[0]
		? resource.identifier[0].value
		: ekItem.resourceId;

	var start = formatDateShort(ekItem.start);
	var end = formatDateShort(ekItem.end);

	return 'Episode #' + encounterNo + ' | ' + start + (end ? ' - ' + end : '');
}

function formatDateShort(value) {
	if (!value) return '';
	return new Date(value).toLocaleDateString('de-DE');
}

function getObservationString(resource) {
	var prefix = '';
	var value = '';
	var unit = '';
	var content = '';

	var categoryCode = '';
	if (
		resource.category &&
		resource.category[0] &&
		resource.category[0].coding &&
		resource.category[0].coding[0] &&
		resource.category[0].coding[0].code
	) {
		categoryCode = resource.category[0].coding[0].code;
	}

	var display = '';
	if (
		resource.code &&
		resource.code.coding &&
		resource.code.coding[0] &&
		resource.code.coding[0].display
	) {
		display = resource.code.coding[0].display;
	} else {
		display = 'Observation';
	}

	//prefix = categoryCode ? '[' + categoryCode + '] ' : '';
	prefix = categoryCode ? (categoryCode === 'vital-signs' ? '\u{1FA7A} ' : '[' + categoryCode + '] ') : '';

	if (resource.valueQuantity !== undefined) {
		if (resource.valueQuantity.unit !== undefined) {
			value = display + ' ' + resource.valueQuantity.value;
			unit = ' ' + resource.valueQuantity.unit;
			content = prefix + value + unit;
		} else {
			value = resource.valueQuantity.value;
			content = prefix + display + ': ' + value;
		}
	} else if (resource.component !== undefined && resource.component.length >= 2) {
		var systolicIdx = (resource.component[0].code.coding[0].code == '8480-6') ? 0 : 1;
		var diastolicIdx = (resource.component[0].code.coding[0].code == '8462-4') ? 0 : 1;
		value = resource.component[systolicIdx].valueQuantity.value + '/' + resource.component[diastolicIdx].valueQuantity.value;
		unit = ' mmHg';
		content = prefix + value + unit;
	} else if (resource.valueString !== undefined) {
		content = prefix + display + ': ' + resource.valueString;
	} else {
		content = prefix + display;
		console.log('Observation value not found in:', resource);
	}

	return content;
}

function getReferencedResource(reference) {
	if (!reference) return null;

	if (reference.indexOf('urn:uuid:') === 0) {
		for (var key in fhirResource) {
			if (!fhirResource.hasOwnProperty(key)) continue;
			var res = fhirResource[key];
			if (res && res.fullUrl === reference) {
				return res;
			}
		}
		return null;
	}

	var parts = reference.split('/');
	if (parts.length >= 2) {
		var id = parts[parts.length - 1];
		return fhirResource[id] || null;
	}

	return null;
}

function getCodeableConceptDisplay(concept) {
	if (!concept) return '';

	if (concept.text) return concept.text;

	if (concept.coding && concept.coding.length > 0) {
		var coding = concept.coding[0];
		return coding.display || coding.code || '';
	}

	return '';
}

function getMedicationDisplay(resource) {
	if (!resource) return 'Medication';

	if (resource.medicationCodeableConcept) {
		return getCodeableConceptDisplay(resource.medicationCodeableConcept) || 'Medication';
	}

	if (resource.medicationReference) {
		var medRef = resource.medicationReference.reference;
		var medRes = getReferencedResource(medRef);

		if (medRes && medRes.code) {
			var medName = getCodeableConceptDisplay(medRes.code);
			if (medName) return medName;
		}

		if (resource.medicationReference.display) {
			return resource.medicationReference.display;
		}
	}

	return 'Medication';
}

function getMedicationRoute(resource) {
	if (!resource || !resource.dosage || !resource.dosage.length) return '';

	var dosage = resource.dosage[0];
	if (!dosage.route) return '';

	return getCodeableConceptDisplay(dosage.route);
}

function getMedicationDose(resource) {
	if (!resource || !resource.dosage || !resource.dosage.length) return '';

	var dosage = resource.dosage[0];
	if (!dosage.doseAndRate || !dosage.doseAndRate.length) return '';

	var dose = dosage.doseAndRate[0].doseQuantity;
	if (!dose) return '';

	var value = (dose.value !== undefined && dose.value !== null) ? dose.value : '';
	var unit = dose.unit || dose.code || '';

	if (value === '' && unit === '') return '';
	return (value + ' ' + unit).trim();
}

function getMedicationTimelineLabel(resource) {
	var medName = getMedicationDisplay(resource);
	var dose = getMedicationDose(resource);
	var route = getMedicationRoute(resource);

	var parts = [medName];
	if (dose) parts.push(dose);
	if (route) parts.push('(' + route + ')');

	return parts.join(' ');
}

function buildMedicationTooltip(resource) {
	var medName = getMedicationDisplay(resource);
	var route = getMedicationRoute(resource);
	var dose = getMedicationDose(resource);
	var status = resource.status || '-';

	var start = '';
	var end = '';

	if (resource.effectivePeriod) {
		start = resource.effectivePeriod.start || '';
		end = resource.effectivePeriod.end || '';
	} else if (resource.effectiveDateTime) {
		start = resource.effectiveDateTime;
	}

	var html = '';
	html += '<b>Medication</b><br>' + medName + '<br>';

	if (dose) {
		html += '<br><b>Dose</b><br>' + dose + '<br>';
	}

	if (route) {
		html += '<br><b>Route</b><br>' + route + '<br>';
	}

	html += '<br><b>Status</b><br>' + status + '<br>';

	if (start || end) {
		html += '<br><b>Zeit</b><br>';
		if (start) html += 'von: ' + formatDateTime(start) + '<br>';
		if (end) html += 'bis: ' + formatDateTime(end) + '<br>';
	}

	if (resource.medicationReference && resource.medicationReference.reference) {
		html += '<br><b>Medication Ref</b><br>' + resource.medicationReference.reference + '<br>';
	}

	return html;
}

function getInitialFocusItem() {
	var item = getLatestItemByGroups(['EncounterFall']);
	if (item) return item;

	return getLatestItemByGroups([
		'EncounterFall',
		'EncounterAK',
		'EncounterVK'
	]);
}

function getLatestItemByGroups(groupIds) {
	if (!items2) return null;

	var matches = items2.get({
		filter: function (item) {
			return groupIds.indexOf(item.group) !== -1 && item.start;
		}
	});

	if (!matches.length) return null;

	matches.sort(function (a, b) {
		return new Date(b.start) - new Date(a.start);
	});

	return matches[0];
}

function getIdentifierString(identifier) {
	if (!identifier) return '';

	if (identifier.type && identifier.type.coding && identifier.type.coding[0] && identifier.type.coding[0].code) {
		return identifier.type.coding[0].code + ':' + identifier.value;
	}

	return identifier.value || '';
}

function getLocationString(location) {
	if (
		location &&
		location.physicalType &&
		location.physicalType.coding &&
		location.physicalType.coding[0] &&
		location.location &&
		location.location.display
	) {
		var type = location.physicalType.coding[0].display;

		var symbol =
			type === 'Ward' ? '\u{1F3E5}' :
			type === 'Room' ? '\u{1F6AA}' :
			type === 'Bed' ? '\u{1F6CF}' :
			'';

		return symbol + ' ' + location.location.display;
	}

	return '';
}

function showReplayCard(html) {
	var card = document.getElementById('replayCard');
	var body = document.getElementById('replayCardBody');
	var nextBtn = document.getElementById('buttonReplayCardNext');
	if (!card || !body) return;

	body.innerHTML = html || '';
	card.style.display = 'block';
	if (nextBtn) nextBtn.style.display = 'inline-block';
}

function hideReplayCard() {
	var card = document.getElementById('replayCard');
	var body = document.getElementById('replayCardBody');
	var nextBtn = document.getElementById('buttonReplayCardNext');
	if (!card || !body) return;

	body.innerHTML = '';
	card.style.display = 'none';
	if (nextBtn) nextBtn.style.display = 'none';
}

function buildReplayCardHtml(item, moveNumber, totalMoves) {
	var episodeNumber = getReplayEpisodeNumber() || '-';
	var department = getDepartmentForItem(item) || '-';
	var longLocation = item.locationLong || item.content || '-';
	var fromText = formatDateTime(item.start);
	var toText = item.end ? formatDateTime(item.end) : '-';
	var durationText = formatDuration(item.start, item.end);

	var html = '';
	html += '<div class="move-count">Move ' + moveNumber + ' of ' + totalMoves + '</div>';

	// Episode
	html += '<div class="section section-meta">';
	html += '<div class="section-title">Episode</div>';
	html += '<div class="meta-value">' + episodeNumber + '</div>';
	html += '</div>';

	// Department
	html += '<div class="section section-meta">';
	html += '<div class="section-title">Department</div>';
	html += '<div class="meta-value">' + department + '</div>';
	html += '</div>';

	// Location
	html += '<div class="section">';
	html += '<div class="section-title">Location</div>';
	html += '<div class="location-block">';
	html += formatLocationLines(longLocation);
	html += '</div>';
	html += '</div>';

	// Duration
	html += '<div class="section">';
	html += '<div class="section-title">Duration</div>';
	html += '<div class="duration-main">' + durationText + '</div>';

	html += '<div class="duration-row">';
	html += '<span class="duration-label">from</span>';
	html += '<span class="duration-value">' + fromText + '</span>';
	html += '</div>';

	if (item.end) {
		html += '<div class="duration-row">';
		html += '<span class="duration-label">to</span>';
		html += '<span class="duration-value">' + toText + '</span>';
		html += '</div>';
	}

	html += '</div>';

	return html;
}

function formatLocationLines(longLocation) {
	return longLocation
		.split('\n')
		.map(function (line) {
			var parts = line.split(':');
			if (parts.length < 2) return '<div class="loc-row">' + line + '</div>';

			var label = parts[0];
			var value = parts.slice(1).join(':').trim();

			return '<div class="loc-row">' +
				'<span class="loc-label">' + label + '</span>' +
				'<span class="loc-value">' + value + '</span>' +
				'</div>';
		})
		.join('');
}

function updateReplayControls() {
	var nextBtn = document.getElementById('buttonReplayCardNext');
	var prevBtn = document.getElementById('buttonReplayCardPrev');

	if (!nextBtn) return;

	var isLast = replayIndex >= replayIds.length;

	// NEXT button
	if (isLast) {
		nextBtn.innerHTML = '&check; Finished';
		nextBtn.classList.add('finished');
	} else {
		nextBtn.innerHTML = '&#9654; Next';
		nextBtn.classList.remove('finished');
	}

	// PREV button
	if (prevBtn) {
		prevBtn.disabled = (replayIndex <= 1);
	}
}

function getReplayEpisodeNumber() {
	if (!selectedEncounterId) return '';
	var encounter = fhirResource[selectedEncounterId];
	return (encounter && encounter.identifier && encounter.identifier[0])
		? encounter.identifier[0].value
		: '';
}

function getDepartmentForItem(item) {
	if (!items2 || !item || !item.start) return '';

	var itemTime = new Date(item.start).getTime();

	var matches = items2.get({
		filter: function (candidate) {
			if (candidate.group !== 'EncounterAK' || !candidate.start) return false;

			var start = new Date(candidate.start).getTime();
			var end = candidate.end ? new Date(candidate.end).getTime() : start;

			return itemTime >= start && itemTime <= end;
		}
	});

	if (!matches.length) return '';

	matches.sort(function (a, b) {
		return new Date(b.start) - new Date(a.start);
	});

	return matches[0].content || '';
}

function formatDateTime(value) {
	if (!value) return '';
	return new Date(value).toLocaleString('de-DE');
}

function formatDuration(start, end) {
	if (!start || !end) return '-';

	var ms = new Date(end) - new Date(start);
	if (!(ms > 0)) return '-';

	var minutes = Math.floor(ms / (1000 * 60));
	var hours = Math.floor(minutes / 60);
	var days = Math.floor(hours / 24);

	minutes = minutes % 60;
	hours = hours % 24;

	var parts = [];

	if (days > 0) parts.push(days + 'd');
	if (hours > 0) parts.push(hours + 'h');
	if (minutes > 0) parts.push(minutes + 'm');

	return parts.join(' ') || '0m';
}

function buildPatientSummary() {
	if (!items2) return '';

	var vkItems = items2.get({
		filter: function (item) {
			return item.group === 'EncounterVK';
		}
	});

	if (!vkItems.length) return '';

	vkItems.sort(function (a, b) {
		return new Date(a.start) - new Date(b.start);
	});

	var moveCount = vkItems.length > 0 ? vkItems.length - 1 : 0;

	var locations = {};
	vkItems.forEach(function (item) {
		var key = item.content || '';
		locations[key] = true;
	});
	var locationCount = Object.keys(locations).length;

	var akItems = items2.get({
		filter: function (item) {
			return item.group === 'EncounterAK' && item.className !== 'enc-special';
		}
	});

	var departments = {};
	akItems.forEach(function (item) {
		departments[item.content] = true;
	});
	var departmentCount = Object.keys(departments).length;

	var first = vkItems[0];
	var last = vkItems[vkItems.length - 1];

	var totalDuration = formatDuration(first.start, last.end || first.start);

	return 'Moves: ' + moveCount +
		' • Locations: ' + locationCount +
		' • Departments: ' + departmentCount +
		' • Stay: ' + totalDuration;
}

function getLocationLine(location) {
	if (
		location &&
		location.physicalType &&
		location.physicalType.coding &&
		location.physicalType.coding[0] &&
		location.location &&
		location.location.display
	) {
		var type = location.physicalType.coding[0].display;

		var symbol =
			type === 'Ward' ? '\u{1F3E5}' :
			type === 'Room' ? '\u{1F6AA}' :
			type === 'Bed' ? '\u{1F6CF}' :
			'';

		var fullName =
			type === 'Ward' ? 'Ward' :
			type === 'Room' ? 'Room' :
			type === 'Bed' ? 'Bed' :
			type;

		return {
			short: symbol + ' ' + location.location.display,
			long: symbol + ' ' + fullName + ': ' + location.location.display
		};
	}

	return null;
}

function getLocationSummary(resource) {
	var parts = (resource.location || [])
		.map(getLocationLine)
		.filter(Boolean);

	return {
		short: parts.map(function (x) { return x.short; }).join('; '),
		long: parts.map(function (x) { return x.long; }).join('\n')
	};
}