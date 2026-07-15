$(document).ready(function () {
	const localStorageLabel = 'Local Storage';
	const sessionStorageLabel = 'Session Cache';

	$('#localStorageLabel').text(localStorageLabel);
	$('#sessionStorageLabel').text(sessionStorageLabel);

	listStorages();

	let mpiid = getMpiid();
	if (mpiid !== null) {
		showCurrent(mpiid);
		var base = sessionStorage.getItem('mpiid.base') || mpiid;
		if (base) { $('#mpiid').val(base); updateFHIRPath(); }
	}

	$('#mpiid').on('input', updateFHIRPath);

	window.addEventListener('message', function (e) {
		if (e.data && e.data.type === 'needPatient') {
			$('#NeedPatientBanner').removeClass('is-hidden');
		}
		if (e.data && e.data.type === 'setCurrent' && e.data.mpiid) {
			setCurrent('sessionStorage', e.data.mpiid);
		}
	});

	$('textarea').on('mousedown', function () {
		$('#CurrentMPIID').html('NEW');
		$('#CurrentSource').html('textarea');
		$('#ButtonCopysessionStorage').css({ display: 'unset' });
		$('#ButtonCopylocalStorage').css({ display: 'unset' });
	});

	$(".wastebasket").hover(function () {
		$(this).css("filter", "drop-shadow(0 0 2px red)");
	}, function () {
		$(this).css("filter", "none");
	});
});

function defaultFHIRPath(mpiid) {
	return mpiid ? 'Patient/' + mpiid + '/$everything' : '';
}

function updateFHIRPath() {
	var mpiid = $('#mpiid').val().trim();
	var current = $('#fhirPath').val().trim();
	// Only overwrite if the field is empty or still matches the default pattern
	if (current === '' || /^Patient\/\d+\/\$everything$/.test(current)) {
		$('#fhirPath').val(defaultFHIRPath(mpiid));
	}
}

async function fetchData() {
	$('#LoadingMessage', window.parent.document).css('display', 'flex');

	try {
		let prettyPrint = new String();
		let pMPIID = $('#mpiid').val().trim();
		const FHIRService = $('#FHIRService').val();
		const fhirPath = $('#fhirPath').val().trim() || defaultFHIRPath(pMPIID);
		const isEverything = /\$everything/.test(fhirPath);

		//// Get SDA (only for $everything queries)
		if (isEverything) {
			let sdaQuerystr = '?MPIID=' + pMPIID + '&FHIRSvc=' + FHIRService;
			if (pMPIID === '') {
				sdaQuerystr += '&MRN=' + $('#mrn').val() + '&AA=' + $('#aa').val();
			}

			const sdaResp = await fetch(App.config.SDAStreamServer + sdaQuerystr, { cache: "no-cache" });
			const sda = await sdaResp.text();

			if (!sdaResp.ok) {
				prettyPrint = 'SDA Fetch failed with status code: ' + sdaResp.status;
				console.log(prettyPrint);
			} else {
				prettyPrint = vkbeautify.xml(sda, ' ');
			}

			if (pMPIID === '') {
				var parser = new DOMParser();
				var xmlDoc = parser.parseFromString(sda, "text/xml");
				pMPIID = xmlDoc.getElementsByTagName('Patient')[0].getElementsByTagName('MPIID')[0].childNodes[0].nodeValue;
			}

			setSdaData(prettyPrint);
		}

		setMpiid(pMPIID);
		sessionStorage.setItem("mpiid.base", pMPIID);
		sessionStorage.setItem("fhirSvc", FHIRService);

		//// Get FHIR
		const fhirUrl = App.config.FHIRStreamServer
			+ '?FHIRPath=' + encodeURIComponent(fhirPath)
			+ '&FHIRSvc=' + encodeURIComponent(FHIRService);

		const fhirResp = await fetch(fhirUrl, { cache: "no-cache" });

		if (!fhirResp.ok) {
			prettyPrint = 'FHIR Fetch failed with status ' + fhirResp.status + ': ' + fhirPath;
			console.log(prettyPrint);
			$('#PreviewFHIR').val(prettyPrint);
		} else {
			const fhir = await fhirResp.json();
			prettyPrint = vkbeautify.json(JSON.stringify(fhir), ' ');
			setFhirData(prettyPrint);
		}

		setCurrent('sessionStorage', pMPIID);
		listStorages();

	} catch (err) {
		console.error('fetchData error:', err);
		$('#PreviewFHIR').val('Fetch error: ' + err.message);
	} finally {
		$('#LoadingMessage', window.parent.document).css('display', 'none');
	}
}
function listStorages() {

	// remove any storage items from display before drawing them (again)
	$('#sessionStorageList dd').remove();
	$('#localStorageList dd').remove();

	let key = new String();

	["localStorage", "sessionStorage"].forEach((storageType) => {
		for (var i = 0; i < this[storageType].length; i++) {

			// don't display other session variables
			if ((!this[storageType].key(i).startsWith("SDA#")) && (!this[storageType].key(i).startsWith("FHIR#"))) {
				continue;
			}

			key = this[storageType].key(i).split("#")[1];

			// ensure an mpiid is only listed once per storageType
			if ($('#' + storageType + 'List [data-value="' + key + '"]').length) {
				continue;
			}

			var dd = $('<dd/>', {
				"data-value": key
			}).appendTo('#' + storageType + 'List');

			// Add the text
			$('<a/>', {
				"html": key,
				"click": function () { setCurrent(storageType, $(this).parent().attr('data-value')) }
			}).prependTo(dd);

			// Add a wastebasket
			$('<a/>', {
				"html": "&#128465;&#65039;", "class": "wastebasket",
				"click": function () { deleteItem(storageType, $(this).parent().attr('data-value')) }
			}).prependTo(dd);

		}
	});
}
function notifyPatientLoaded() {
	$('#NeedPatientBanner').addClass('is-hidden');
	window.parent.postMessage({ type: 'patientLoaded' }, '*');
}

function setCurrent(storageType, mpiid) {

	console.log("setCurrent(" + storageType + ',' + mpiid + ')');
	setStorage(storageType);
	setMpiid(mpiid);
	var m = mpiid && mpiid.match(/^\d+/);
	if (m) { sessionStorage.setItem('mpiid.base', m[0]); $('#mpiid').val(m[0]); updateFHIRPath(); }

	window.parent.setCurrentItemInTitle();
	if (mpiid) { notifyPatientLoaded(); }

	showCurrent(mpiid);
}
function showCurrent(mpiid) {
	console.log('showCurrent(' + mpiid + ')');

	if (mpiid) {
		let storage = getStorage();
		let storageType = sessionStorage.getItem("storageType");

		$('#PreviewSDA').val(storage.getItem('SDA#' + mpiid));
		$('#PreviewFHIR').val(storage.getItem('FHIR#' + mpiid));
		$('#CurrentMPIID').html(mpiid);
		$('#CurrentSource').html($('#' + storageType + 'Label').text());

		$('#ButtonCopysessionStorage').css({ display: storageType == "sessionStorage" ? 'none' : 'unset' });
		$('#ButtonCopylocalStorage').css({ display: storageType == "localStorage" ? 'none' : 'unset' });

		$('#localStorageList dd').removeClass("active");
		$('#sessionStorageList dd').removeClass("active")
		$('#' + storageType + 'List [data-value="' + mpiid + '"]').addClass("active");
	}
}
function deleteItem(storageType, id) {
	if (confirm('Delete ' + id + ' from ' + storageType + '?')) {
		if (id == '*') {
			this[storageType].clear()
		} else {
			this[storageType].removeItem('SDA#' + id);
			this[storageType].removeItem('FHIR#' + id);
		}
		setCurrent('sessionStorage');
		listStorages();
		//location.reload();
	}
}
function copyToLocalStorage() {

	let name = prompt('Please give it a name', getMpiid());
	if (name !== null) {
		name = name.replace(' ', '_');
		localStorage.setItem('FHIR#' + name, $('#PreviewFHIR').val());
		localStorage.setItem('SDA#' + name, $('#PreviewSDA').val());
		location.reload();
	}
}
function copyToSessionStorage() {

	let name = prompt('Please give it a name', getMpiid());
	if (name !== null) {
		name = name.replace(' ', '_');
		setMpiid(name);
		sessionStorage.setItem('FHIR#' + name, $('#PreviewFHIR').val());
		sessionStorage.setItem('SDA#' + name, $('#PreviewSDA').val());
		setStorage('sessionStorage');
		location.reload();
	}
}
function beautifyJS() {
	$('#PreviewFHIR').val(vkbeautify.json($('#PreviewFHIR').val(), ' '));
}

function beautifyXML() {
	$('#PreviewSDA').val(vkbeautify.xml($('#PreviewSDA').val(), ' '));
}