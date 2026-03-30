$(document).ready(function () {
	const localStorageLabel = 'Local Storage';
	const sessionStorageLabel = 'Session Cache';

	$('#localStorageLabel').text(localStorageLabel);
	$('#sessionStorageLabel').text(sessionStorageLabel);

	listStorages();

	let mpiid = getMpiid();
	if (mpiid !== null) {
		showCurrent(getMpiid());
	}

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

async function fetchData() {
	$('#LoadingMessage', window.parent.document).toggle(true);

	let prettyPrint = new String();
	let pMPIID = $('#mpiid').val();
	const FHIRService = $('#FHIRService').val();
	let querystr = '?MPIID=' + pMPIID + '&FHIRSvc=' + FHIRService;

	if (pMPIID == "") {
		querystr += '&MRN=' + $('#mrn').val() + '&AA=' + $('#aa').val();
	}

	//// Get SDA and place in a textarea						
	const sda = await fetch(App.config.SDAStreamServer + querystr, { cache: "no-cache" })
		.then(response => response.text()
			.then(status = response.status));

	if (parseInt(status) !== 200) {
		prettyPrint = 'SDA Fetch failed with status code: ' + status;
		console.log(prettyPrint);
	} else {
		prettyPrint = vkbeautify.xml(sda, ' ');
	}


	if (pMPIID == "") {
		var parser = new DOMParser();
		var xmlDoc = parser.parseFromString(sda, "text/xml");
		pMPIID = xmlDoc.getElementsByTagName('Patient')[0].getElementsByTagName('MPIID')[0].childNodes[0].nodeValue;
	}
	setMpiid(pMPIID);

	setSdaData(prettyPrint);

	//// Get FHIR
	const fhir = await fetch(App.config.FHIRStreamServer + '?MPIID=' + pMPIID + '&FHIRSvc=' + FHIRService, { cache: "no-cache" })
		.then(response => response.json()
			.then(status = response.status));

	if (parseInt(status) !== 200) {
		prettyPrint = 'FHIR Fetch failed with status code: ' + status;
		console.log(prettyPrint);
	} else {
		prettyPrint = vkbeautify.json(JSON.stringify(fhir), ' ');
	}

	setFhirData(prettyPrint);
	setCurrent('sessionStorage', pMPIID);
	listStorages();

	$('#LoadingMessage', window.parent.document).toggle(false);
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
function setCurrent(storageType, mpiid) {

	console.log("setCurrent(" + storageType + ',' + mpiid + ')');
	setStorage(storageType);
	setMpiid(mpiid);

	var parentWindow = window.parent;
	parentWindow.setCurrentItemInTitle(mpiid);

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