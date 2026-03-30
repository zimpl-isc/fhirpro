$(document).ready(function () {
	dragElement(document.getElementById("separator"), "H");
	parse();
	hljs.highlightAll();
	hljs.initLineNumbersOnLoad();

	setTimeout(() => {
		$('.hljs-xmlval, .hljs-string').on('dblclick', highlightUserSelection);
	}, 1000);

	$('fieldset.infoBox').draggable();
});

function escapeHTML(html) {
	return jQuery('<div />').text(html).html()
}
function parse() {

	let tMpiid = getMpiid();
	if (tMpiid == "") {
		console.log("No MPIID found in current session. Search for a patient first.");
		return
	}

	let tSDA = getSdaData();
	if (tSDA === null) {
		console.log("No SDA data found in localStorage. Search for a patient first.");
	} else {
		$('#sdaSource').html(escapeHTML(tSDA, ' '));
	}

	let tFHIR = getFhirData();
	if (tFHIR === null) {
		console.log("No FHIR data found in localStorage. Search for a patient first.");
	} else {
		$('#fhirSource').html(vkbeautify.json(tFHIR, ' '));
	}

}
function dragElement(element, direction) {
	var md; // remember mouse down info
	const first = document.getElementById("sdaSource");
	const second = document.getElementById("fhirSource");

	element.onmousedown = onMouseDown;

	function onMouseDown(e) {
		//console.log("mouse down: " + e.clientX);
		md = {
			e: e,
			offsetLeft: element.offsetLeft,
			offsetTop: element.offsetTop,
			firstWidth: first.offsetWidth,
			secondWidth: second.offsetWidth
		};

		document.onmousemove = onMouseMove;
		document.onmouseup = () => {
			//console.log("mouse up");
			document.onmousemove = document.onmouseup = null;
		}
	}

	function onMouseMove(e) {
		//console.log("mouse move: " + e.clientX);
		var delta = {
			x: e.clientX - md.e.clientX,
			y: e.clientY - md.e.clientY
		};

		if (direction === "H") // Horizontal
		{
			// Prevent negative-sized elements
			delta.x = Math.min(Math.max(delta.x, -md.firstWidth),
				md.secondWidth);

			element.style.left = md.offsetLeft + delta.x + "px";
			first.style.width = (md.firstWidth + delta.x) + "px";
			second.style.width = (md.secondWidth - delta.x) + "px";
		}
	}
}
function hscroll(direction = '+') {
	if (direction === '+') {
		currentHighlight = currentHighlight + 1;
		if (currentHighlight > (foundTerm.length - 1)) {
			currentHighlight = 0;
		}
	} else {
		currentHighlight = currentHighlight - 1;
		if (currentHighlight < 0) {
			currentHighlight = foundTerm.length - 1;
		}
	}
	$('#currentFound').text(currentHighlight + 1);
	$('html').animate({ scrollTop: foundTerm[currentHighlight] }, 800);
}
function highlightUserSelection(jQueryEle) {
	let userSelection = $(this).text().replaceAll('"', '');
	$('#searchTerm').val(userSelection);
	highlightSearchTerm(userSelection);
}
function highlightSearchTerm(searchTerm) {
	if (searchTerm === "" || searchTerm === null) {
		return
	}

	$('.highlight').removeClass('highlight');

	const regx = new RegExp(String.raw`${searchTerm}`, "g");

	foundTerm = new Array();

	$('.hljs-xmlval, .hljs-string').each(function (iter, blk) {
		if ($(this).html().match(regx)) {
			console.log(iter, $(this).offset().top);
			foundTerm.push($(this).offset().top);
			//$(this).html($(this).html().replaceAll(searchTerm, '<mark>'+searchTerm+'</mark>'));
			$(this).addClass('highlight');
			currentHighlight = -1;
		}

	});

	$('#totalFound').text(foundTerm.length);
	hscroll('+');
}