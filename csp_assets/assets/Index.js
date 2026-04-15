$(document).ready(function () {
	setCurrentItemInTitle(getMpiid());
	refreshPatientNav();
	$('.list_item').on('click', function () { toggle(this.id); });

	$('#PatientButton').on('click', function (e) {
		e.stopPropagation();
		$('#PatientDropdown').toggle();
	});

	$(document).on('click', function () {
		$('#PatientDropdown').hide();
	});
});


function mainFrameReady() {
	$('#LoadingMessage').hide();
	refreshPatientNav();
}

function toggle(activeElementId, queryParams) {
	$('#LoadingMessage').css('display', 'flex');

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
	setCurrentItemInTitle(getMpiid());
}

function openAbout() {
	toggle('About');
	$('#PatientDropdown').hide();
}

function setCurrentItemInTitle(mpiid) {
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