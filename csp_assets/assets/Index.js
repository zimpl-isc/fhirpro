$(document).ready(function () {
	setCurrentItemInTitle();
	refreshPatientNav();
	$('.list_item').on('click', function () { toggle(this.id); });

	$('#PatientButton').on('click', function (e) {
		e.stopPropagation();
		$('#PatientDropdown').toggle();
	});

	$(document).on('click', function () {
		$('#PatientDropdown').hide();
	});

	window.addEventListener('message', function (e) {
		if (e.data && e.data.type === 'patientLoaded' && _pendingPage) {
			var dest = _pendingPage;
			_pendingPage = null;
			toggle(dest);
		}
	});
});


var _loadingTimer = null;
var _loadingTarget = null;
var _pendingPage = null;

var PATIENT_GATED = {
	'Compare_SDA3_to_FHIR': true,
	'FHIR_Relationship_Graph': true,
	'Patient_Journey': true
};

function mainFrameReady() {
	clearLoadingTimer();
	$('#LoadingMessage').hide();
	$('#LoadingStatus').text('').removeClass('is-slow');
	refreshPatientNav();
}

function clearLoadingTimer() {
	if (_loadingTimer) { clearTimeout(_loadingTimer); _loadingTimer = null; }
}

function startLoadingTimer(targetUrl) {
	clearLoadingTimer();
	_loadingTarget = targetUrl;
	_loadingTimer = setTimeout(function () {
		_loadingTimer = null;
		$('#LoadingStatus')
			.addClass('is-slow')
			.html('Taking a while \u2014 the server may be busy. <a onclick="retryLoad()">Retry</a>');
	}, 10000);
}

window.retryLoad = function () {
	if (_loadingTarget) {
		$('#LoadingStatus').text('').removeClass('is-slow');
		startLoadingTimer(_loadingTarget);
		$('#MainFrame').attr('src', _loadingTarget);
	}
};

function toggle(activeElementId, queryParams) {
	if (PATIENT_GATED[activeElementId] && !getMpiid()) {
		_pendingPage = activeElementId;
		toggle('Configure_Datasource');
		var frame = document.getElementById('MainFrame');
		var send = function () {
			frame.contentWindow.postMessage({ type: 'needPatient', page: activeElementId }, '*');
		};
		if (frame.contentDocument && frame.contentDocument.readyState === 'complete') {
			send();
		} else {
			frame.addEventListener('load', function onLoad() {
				frame.removeEventListener('load', onLoad);
				send();
			});
		}
		return;
	}

	$('#LoadingMessage').css('display', 'flex');
	$('#LoadingStatus').text('').removeClass('is-slow');

	$('.list_item').removeClass('active');
	$('#' + activeElementId).addClass('active');

	let targetUrl = iframePages[activeElementId];

	if (queryParams) {
		const qs = new URLSearchParams(queryParams).toString();
		if (qs) {
			targetUrl += (targetUrl.indexOf('?') === -1 ? '?' : '&') + qs;
		}
	}

	$('#MainFrame').attr('src', targetUrl);
	startLoadingTimer(targetUrl);

	if (
		activeElementId === 'Management_Portal' ||
		activeElementId === 'HL7_Annotations' ||
		activeElementId === 'Registry'
	) {
		$('#MainFrame').css('background-color', 'white');
		$('#MainFrame').addClass('extShell');
	} else {
		$('#MainFrame').css('background-color', '#f5f7fb');
		$('#MainFrame').removeClass('extShell');
	}

	$('#PageName').html(activeElementId.replace(/\_/g, ' '));
	refreshPatientNav();
	setCurrentItemInTitle();
}

function openAbout() {
	toggle('About');
	$('#PatientDropdown').hide();
}

function setCurrentItemInTitle() {
	refreshPatientNav();
}

/* -------- patient nav -------- */

function refreshPatientNav() {
	var mpiid = getMpiid();
	if (!mpiid) {
		$('#PatientNav').hide();
		return;
	}

	var storage = getStorage ? getStorage() : sessionStorage;
	if (!storage) {
		$('#PatientNav').hide();
		return;
	}

	var fhirRaw = storage.getItem('FHIR#' + mpiid);
	if (!fhirRaw) {
		$('#PatientNav').hide();
		return;
	}

	try {
		var bundle = JSON.parse(fhirRaw);
		var patient = null;

		if (bundle.entry && bundle.entry.length) {
			for (var i = 0; i < bundle.entry.length; i++) {
				if (bundle.entry[i].resource && bundle.entry[i].resource.resourceType === 'Patient') {
					patient = bundle.entry[i].resource;
					break;
				}
			}
		}

		if (!patient) {
			$('#PatientNav').hide();
			return;
		}

		var family = (patient.name && patient.name[0] && patient.name[0].family) ? patient.name[0].family : '';
		var given = (patient.name && patient.name[0] && patient.name[0].given && patient.name[0].given[0]) ? patient.name[0].given[0] : '';
		var fullName = [family, given].filter(Boolean).join(', ');
		if (!fullName) fullName = 'Unknown patient';

		var gender = patient.gender || '';
		var birthDate = patient.birthDate || '';
		var age = birthDate ? calculateAgeFromBirthdate(birthDate) : '';
		var ageGender = [age ? age + ' Jahre' : '', gender].filter(Boolean).join(', ');

		var pi = '';
		var mr = '';
		if (patient.identifier && patient.identifier.length) {
			for (var j = 0; j < patient.identifier.length; j++) {
				var ident = patient.identifier[j];
				var code = (ident.type && ident.type.coding && ident.type.coding[0] && ident.type.coding[0].code) ? ident.type.coding[0].code : '';
				if (code === 'PI' && !pi) pi = ident.value || '';
				if (code === 'MR' && !mr) mr = ident.value || '';
			}
		}

		var inlineId = pi || mpiid;
		$('#PatientButton').html(
			'<span class="patient-text">' +
				'<span>' + escapeHtml(fullName) + '</span>' +
				'<span class="meta">' + escapeHtml('PI:' + inlineId) + '</span>' +
			'</span>'
		);
		$('#PatientDropdown').html(
			'<div class="title">' + escapeHtml(fullName) + '</div>' +
			(ageGender ? '<div class="line">' + escapeHtml(ageGender) + '</div>' : '') +
			'<div class="line"><span class="muted">MPIID:</span> ' + escapeHtml(mpiid) + '</div>' +
			(pi ? '<div class="line"><span class="muted">PI:</span> ' + escapeHtml(pi) + '</div>' : '') +
			(mr ? '<div class="line"><span class="muted">MR:</span> ' + escapeHtml(mr) + '</div>' : '') +
			'<div class="actions"><a onclick="toggle(\'Configure_Datasource\'); $(\'#PatientDropdown\').hide();">Change patient</a></div>'
		);

		$('#PatientNav').show();

	} catch (ex) {
		console.log('refreshPatientNav failed', ex);
		$('#PatientNav').hide();
	}
}

function calculateAgeFromBirthdate(birthdate) {
	var birthdateObj = new Date(birthdate);
	var currentDate = new Date();
	var age = currentDate.getFullYear() - birthdateObj.getFullYear();

	var hasBirthdayOccurred =
		currentDate.getMonth() > birthdateObj.getMonth() ||
		(currentDate.getMonth() === birthdateObj.getMonth() && currentDate.getDate() >= birthdateObj.getDate());

	if (!hasBirthdayOccurred) {
		age--;
	}
	return age;
}

function escapeHtml(value) {
	if (value === null || value === undefined) return '';
	return String(value)
		.replace(/&/g, '&amp;')
		.replace(/</g, '&lt;')
		.replace(/>/g, '&gt;')
		.replace(/"/g, '&quot;')
		.replace(/'/g, '&#39;');
}