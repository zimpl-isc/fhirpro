var ns;
$(document).ready(function () {
    currentHighlight = 0;
    const params = new URLSearchParams(location.search);
    const doc = params.get("doc");
    const st = params.get("st");
    ns = params.get("ns");
    $('#currentDoc').text(doc);
    $('#searchTerm').val(st);
    ApiGetDoc();

    $("#Controls").draggable({
        handle: ".controls-header",
        containment: "window",
        scroll: false
    });
    $('#searchTerm').select();


    setTimeout(() => {
        $('.hljs-ISC_ClassName').each(function (ix) {
            $(this).html("<a title='&#10548; " + $(this).text() + "' target=_blank onclick='openPage(\"" + $(this).text() + ".cls\")'>" + $(this).text() + "</a>");
        });
    }, 1000);

    setTimeout(() => {
        $('.hljs-ISC_Include').each(function (ix) {
            $(this).html("<a title='&#10548; " + $(this).text() + "' target=_blank onclick='openPage(\"" + $(this).text() + ".inc\")'>" + $(this).text() + "</a>");
        });
    }, 1000);

    setTimeout(() => {
        highlightSearchTerm(st);
    }, "2000");
});
function openPage(pageName) {

    window.open('?doc=' + pageName + '&ns=' + ns + '&st=' + $('#searchTerm').val(), '_blank');
    return false
}
function escapeHTML(html) {
    return jQuery('<div />').text(html).html()
}
async function ApiGetDoc(namespace, documentName, searchTerm) {
    const params = new URLSearchParams(location.search);
    const host = window.location.href.split('/csp')[0];
    const doc = documentName || params.get("doc");
    const ns = namespace || params.get("ns");
    const st = searchTerm || params.get("st");
    const api = host + '/api/atelier/v5/' + ns + '/doc/' + encodeURI(doc);

    // Fetch
    queryResponse = await fetch(api, { cache: "no-cache" })
        .then(response => response.text()
            .then(status = response.status));

    if (parseInt(status) !== 200) {
        let tSc = 'Fetch failed with status code: ' + status;
        console.log(tSc);
    } else {
        const results = JSON.parse(queryResponse).result;
        let html = "";
        results.content.forEach((codeLine) => {
            html += escapeHTML(codeLine) + '\n';
        });
        $('pre code').html(html);
        highlightSyntax();
    }
}
function highlightSyntax() {
    hljs.highlightAll();
    hljs.initLineNumbersOnLoad();
}
function removeHighlightSearch() {
    currentHighlight = 0;
    delete foundTerm;
    $('mark').each(function () {
        $(this).replaceWith($(this).text());
    });
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
function highlightSearchTerm(searchTerm = $('#searchTerm').val()) {
    if (searchTerm === "" || searchTerm === null) {
        return
    }

    removeHighlightSearch();

    $('body :not(script,#currentDoc)').contents().filter(function () {
        return this.nodeType === 3;
    }).replaceWith(function () {
        //if (this.nodeValue == searchTerm) {
        if (this.nodeValue.search(searchTerm) !== -1) {
            return this.nodeValue.replace(searchTerm, '<mark>' + searchTerm + '</mark>');
        } else {
            return escapeHTML(this.nodeValue);
        }

    });

    foundTerm = new Array();

    $('mark').each(function (iter, blk) {

        foundTerm.push($(this).offset().top);
    });

    currentHighlight = -1;

    $('#totalFound').text(foundTerm.length);
    hscroll('+');
}