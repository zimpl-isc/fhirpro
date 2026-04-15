var dataSet = [];

async function ApiSearch() {
	$('#LoadingMessage', window.parent.document).toggle(true);

	const host = $('#host').val();
	const namespace = $('#namespace').val();
	const apiRsc = host + '/api/atelier/v5/' + namespace + '/action/search';

	let query = encodeURI($('#queryString').val());
	let documents = encodeURI($('#documents').val());
	let regex = $('#regex').is(":checked");
	let sys = $('#sys').is(":checked");
	let gen = $('#gen').is(":checked");
	let max = $('#max').val();

	let querystr = '?query=' + query + '&documents=' + documents + '&regex=' + regex + '&sys=' + sys + '&gen=' + gen + '&max=' + max;

	let headers = new Headers();
	headers.set('Authorization', 'Basic ' + btoa('_system' + ":" + 'SYS'));

	queryResponse = await fetch(apiRsc + querystr, { cache: "no-cache", method: 'GET', headers: headers })
		.then(response => response.text().then(status = response.status));

	if (parseInt(status) !== 200) {
		let tSc = 'Fetch failed with status code: ' + status;
		console.log(tSc);
	} else {
		const results = JSON.parse(queryResponse).result;
		dataSet = [];
		dataSet.filtered = false;

		results.forEach((result) => {
			result.matches.forEach((match) => {
				dataSet.push([result.doc, match.attr || "", match.member || "", escapeHTML(match.text)]);
			});
		});

		drawTable(dataSet);
	}

	$('#LoadingMessage', window.parent.document).toggle(false);
}

function drawTable(pData) {
	$('#queryResults').DataTable({
		destroy: true,
		language: {
			search: "Filter rows:"
		},
		pageLength: 50,
		columns: [
			{
				title: 'Classname',
				createdCell: function (td, cellData, rowData, row, col) {
					$(td).addClass('dataField');
					$(td).attr('data-doc', rowData[0]);
				},
				render: function (data, type, row, meta) {
					return "<a class='dataLink'>" + data + "</a>";
				}
			},
			{ title: 'Attr' },
			{ title: 'Member' },
			{ title: 'Text' }
		],
		data: pData,
		drawCallback: updateTableLinks
	});

	if (!$('#filterForUnique').length) {
		$('#queryResults th').first().append('<a id="filterForUnique" title="Toggle unique classes"></a>');
	}

	$('#filterForUnique').html('<svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 16 16"><path d="M1.5 1.5A.5.5 0 0 1 2 1h12a.5.5 0 0 1 .5.5v2a.5.5 0 0 1-.128.334L10 8.692V13.5a.5.5 0 0 1-.342.474l-3 1A.5.5 0 0 1 6 14.5V8.692L1.628 3.834A.5.5 0 0 1 1.5 3.5zm1 .5v1.308l4.372 4.858A.5.5 0 0 1 7 8.5v5.306l2-.666V8.5a.5.5 0 0 1 .128-.334L13.5 3.308V2z"></path></svg>');
	$('#filterForUnique').off('click').on('click', distill);

	if (pData.filtered) {
		$('#filterForUnique svg').addClass('active');
	}
}

function distill() {
	function uniqBy(a, key) {
		var seen = {};
		return a.filter(function (item) {
			var k = key(item[0]);
			return seen.hasOwnProperty(k) ? false : (seen[k] = true);
		});
	}

	if (dataSet.filtered) {
		dataSet.filtered = false;
		drawTable(dataSet);
	} else {
		dataSet.filtered = true;
		let dataSetDistilled = uniqBy(dataSet, JSON.stringify);
		dataSetDistilled.filtered = true;
		drawTable(dataSetDistilled);
	}
}

function escapeHTML(html) {
	return jQuery('<div />').text(html).html();
}

$(document).ready(function () {
	$('#host').val(window.location.href.split('/csp')[0]);
});

function updateTableLinks() {
	let query = encodeURI($('#queryString').val());
	let namespace = $('#namespace').val();

	$('.dataLink').each(function () {
		const doc = $(this).parent().data("doc");
		const href = 'HS.Local.zimpli.fhir.UI.FileViewer.cls?doc=' + doc + '&ns=' + namespace + '&st=' + query;
		$(this).attr({
			href: href,
			target: '_blank'
		});
	});

	$('.dataField').off('mouseenter').on('mouseenter', function () {
		const iframeUrl = 'HS.Local.zimpli.fhir.UI.FileViewer.cls?doc=' + $(this).data("doc") + '&ns=' + namespace + '&st=' + query;
		$('#tooltip-iframe').attr('src', iframeUrl);
		$('#iframe-tooltip-container').css({
			display: 'block'
		});
	});

	$('.dataField, #iframe-tooltip-container').off('mouseleave').on('mouseleave', function () {
		setTimeout(function () {
			if (!$('#iframe-tooltip-container').is(':hover') && !$('.dataField:hover').length) {
				$('#iframe-tooltip-container').hide();
				$('#tooltip-iframe').attr('src', '');
			}
		}, 200);
	});
}