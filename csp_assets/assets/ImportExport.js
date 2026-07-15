// ─────────────────────────────────────────────────────────────────────────────
// ImportExport.js
// Atelier REST API-driven import/export tool for InterSystems IRIS
// ─────────────────────────────────────────────────────────────────────────────

// ── State ────────────────────────────────────────────────────────────────────
let importItems = [];   // [{name, ts, type}] populated by preview
let exportItems = [];   // [{name, ts, type}] populated by search

// ── Init ─────────────────────────────────────────────────────────────────────
$(document).ready(function () {
    $('#host').val(window.location.href.split('/csp')[0]);
    setSuggestedExportPath();

    // Export defaults
    const oneYearAgo = new Date();
    oneYearAgo.setFullYear(oneYearAgo.getFullYear() - 1);
    document.getElementById('exportFrom').value = oneYearAgo.toISOString().substring(0, 10);
    document.getElementById('exportPattern').value = 'HS.Local.*.cls';

    loadNamespaces().then(() => {
        // After namespaces load, switch to export tab and trigger search
        switchTab('export');
        searchExport();
    });

    // Upload: auto-preview on file selection
    $('#importFiles').on('change', function () {
        listUploadedFiles();
    });

    // Tree checkbox delegation
    $(document).on('change', '.pkgCheck', function () { onPkgCheck(this); });
    $(document).on('change', '.itemCheck', function () { onItemCheck(this); });
});

// ── Helpers ───────────────────────────────────────────────────────────────────
function apiBase() {
    return $('#host').val().replace(/\/$/, '');
}

function authHeaders() {
    const u = $('#username').val();
    const p = $('#password').val();
    return { 'Authorization': 'Basic ' + btoa(u + ':' + p) };
}

function ns() { return $('#namespace').val() || 'USER'; }

async function atelierGet(path) {
    const r = await fetch(apiBase() + path, {
        cache: 'no-cache',
        headers: authHeaders()
    });
    if (!r.ok) throw new Error('HTTP ' + r.status + ' ' + r.statusText);
    return r.json();
}

async function atelierPost(path, body) {
    const r = await fetch(apiBase() + path, {
        cache: 'no-cache',
        method: 'POST',
        headers: { ...authHeaders(), 'Content-Type': 'application/json' },
        body: JSON.stringify(body)
    });
    if (!r.ok) throw new Error('HTTP ' + r.status + ' ' + r.statusText);
    return r.json();
}

function setHostStatus(msg, ok) {
    const el = document.getElementById('hostStatus');
    el.textContent = msg;
    el.className = 'hostStatus ' + (ok ? 'ok' : 'err');
}

function compileFlagsValue() {
    let f = 'c';
    document.querySelectorAll('.cflag:checked').forEach(cb => { f += cb.value; });
    return f;
}

function statusLog(side, msg, cls) {
    const el = document.getElementById(side + 'Status');
    const line = document.createElement('div');
    line.className = 'logLine' + (cls ? ' ' + cls : '');
    line.textContent = msg;
    el.appendChild(line);
    el.scrollTop = el.scrollHeight;
}

function clearStatus(side) {
    document.getElementById(side + 'Status').innerHTML = '';
    document.getElementById(side + 'StatusCard').style.display = 'none';
}

function showStatus(side) {
    document.getElementById(side + 'StatusCard').style.display = '';
}

function isoToDateStr(ts) {
    // Atelier ts: "2024-03-15T10:22:00" or "%TimeStamp" style; -1 means not present
    if (!ts || typeof ts !== 'string') return '';
    return ts.substring(0, 10);
}

function nowStamp() {
    const d = new Date();
    return d.getFullYear() +
        String(d.getMonth() + 1).padStart(2, '0') +
        String(d.getDate()).padStart(2, '0') + '_' +
        String(d.getHours()).padStart(2, '0') +
        String(d.getMinutes()).padStart(2, '0') +
        String(d.getSeconds()).padStart(2, '0');
}

function setSuggestedExportPath() {
    document.getElementById('exportPath').value = '/mgr/Temp/export_' + nowStamp() + '.xml';
    document.getElementById('exportUdlDir').value = '/mgr/Temp/export_' + nowStamp() + '/';
}

// ── Namespace loading ─────────────────────────────────────────────────────────
async function loadNamespaces() {
    setHostStatus('connecting…', true);
    try {
        const data = await atelierGet('/api/atelier/');
        const nsList = data.result.content.namespaces || [];
        ['namespace', 'importTarget'].forEach(id => {
            const sel = document.getElementById(id);
            const prev = sel.value;
            sel.innerHTML = '';
            nsList.forEach(n => {
                const opt = document.createElement('option');
                opt.value = n; opt.textContent = n;
                if (n === prev) opt.selected = true;
                sel.appendChild(opt);
            });
        });
        // Default to first preferred namespace found
        const prefer = ['HSCUSTOM', 'ZIMPLIFHIR', 'USER'];
        const defaultNs = prefer.find(p => nsList.includes(p)) || nsList[0] || 'USER';
        document.getElementById('namespace').value = defaultNs;
        document.getElementById('importTarget').value = defaultNs;
        setHostStatus('connected (' + nsList.length + ' namespaces)', true);
    } catch (e) {
        setHostStatus('error: ' + e.message, false);
    }
}

// ── Tab switching ─────────────────────────────────────────────────────────────
function switchTab(tab) {
    ['import', 'export'].forEach(t => {
        document.getElementById('panel-' + t).style.display = t === tab ? '' : 'none';
        document.getElementById('tab-' + t).classList.toggle('active', t === tab);
    });
}

// ── Import: source toggle ────────────────────────────────────────────────────
function importSourceChanged() {
    const val = document.querySelector('input[name="importSource"]:checked').value;
    document.getElementById('importServerPath').style.display = val === 'server' ? '' : 'none';
    document.getElementById('importUpload').style.display = val === 'upload' ? '' : 'none';
    hideImportTree();
}

function hideImportTree() {
    document.getElementById('importTreeCard').style.display = 'none';
    document.getElementById('importOptionsCard').style.display = 'none';
    document.getElementById('importRunBtn').disabled = true;
    importItems = [];
}

// ── Import: compile flag toggle ──────────────────────────────────────────────
function toggleCompileFlags() {
    document.getElementById('compileFlagBlock').style.display =
        document.getElementById('importCompile').checked ? '' : 'none';
}

// ── Import: list server path ──────────────────────────────────────────────────
async function listImportPath() {
    const path = document.getElementById('importPath').value.trim();
    if (!path) return;

    hideImportTree();
    showStatus('import');
    statusLog('import', 'Listing ' + path + '…');

    try {
        // Use xml/list with a file reference
        const body = [{ file: path }];
        const data = await atelierPost('/api/atelier/v7/' + encodeURIComponent(ns()) + '/action/xml/list', body);

        const result = (data.result && data.result.content) ? data.result.content : [];
        importItems = [];
        result.forEach(fileResult => {
            if (fileResult.documents) {
                fileResult.documents.forEach(d => {
                    const ts = (d.ts && typeof d.ts === 'string') ? d.ts : '';
                    importItems.push({ name: d.name, ts });
                });
            }
            if (fileResult.status && fileResult.status.errors && fileResult.status.errors.length) {
                fileResult.status.errors.forEach(e => statusLog('import', '[ERROR] ' + e.text, 'logError'));
            }
        });

        if (importItems.length === 0) {
            statusLog('import', 'No items found in ' + path, 'logWarn');
            return;
        }

        statusLog('import', 'Found ' + importItems.length + ' item(s)', 'logOk');
        buildTree('import', importItems);
        document.getElementById('importTreeCard').style.display = '';
        document.getElementById('importOptionsCard').style.display = '';
        document.getElementById('importRunBtn').disabled = false;

    } catch (e) {
        statusLog('import', '[ERROR] ' + e.message, 'logError');
    }
}

// ── Import: browser file upload ───────────────────────────────────────────────

// Cache of file lines keyed by filename, populated during preview and reused at load time.
const uploadedFileLines = {};

async function listUploadedFiles() {
    const files = document.getElementById('importFiles').files;
    if (!files.length) return;

    hideImportTree();
    showStatus('import');
    importItems = [];

    for (const file of files) {
        statusLog('import', 'Reading ' + file.name + '…');
        try {
            const text = await file.text();
            const lines = text.split('\n');
            uploadedFileLines[file.name] = lines;

            const body = [{ content: lines, file: file.name }];
            const data = await atelierPost('/api/atelier/v7/' + encodeURIComponent(ns()) + '/action/xml/list', body);

            const result = (data.result && data.result.content) ? data.result.content : [];
            result.forEach(fileResult => {
                if (fileResult.documents) {
                    fileResult.documents.forEach(d => {
                        const tsCurrent = (d.ts && typeof d.ts === 'string') ? d.ts : '';
                        importItems.push({ name: d.name, tsCurrent, _file: file.name });
                    });
                }
                if (fileResult.status && fileResult.status.errors && fileResult.status.errors.length) {
                    fileResult.status.errors.forEach(e => statusLog('import', '[ERROR] ' + e.text, 'logError'));
                }
            });
        } catch (e) {
            statusLog('import', '[ERROR] ' + file.name + ': ' + e.message, 'logError');
        }
    }

    if (importItems.length === 0) {
        statusLog('import', 'No importable items found in selected files', 'logWarn');
        return;
    }

    const cNew  = importItems.filter(i => !i.tsCurrent).length;
    const cHas  = importItems.length - cNew;
    statusLog('import',
        'Found ' + importItems.length + ' item(s): ' + cNew + ' new, ' + cHas + ' already in namespace',
        'logOk');
    buildTree('import', importItems);
    document.getElementById('importTreeCard').style.display = '';
    document.getElementById('importOptionsCard').style.display = '';
    document.getElementById('importRunBtn').disabled = false;
}

// ── Import: run ───────────────────────────────────────────────────────────────
async function runImport() {
    const selected = getCheckedItems('import');
    if (!selected.length) { alert('No items selected.'); return; }

    const targetNs = document.getElementById('importTarget').value;
    const doCompile = document.getElementById('importCompile').checked;
    const flags = doCompile ? compileFlagsValue() : '';

    showStatus('import');
    document.getElementById('importRunBtn').disabled = true;
    statusLog('import', '── Import started ──────────────────────');

    try {
        const source = document.querySelector('input[name="importSource"]:checked').value;

        let loaded = 0, errors = 0;
        let importedDocs = [];

        if (source === 'server') {
            // Server-path mode: use Atelier xml/load with file reference + selected list
            const path = document.getElementById('importPath').value.trim();
            const flagParam = flags ? '?flags=' + encodeURIComponent(flags) : '';
            const data = await atelierPost(
                '/api/atelier/v7/' + encodeURIComponent(targetNs) + '/action/xml/load' + flagParam,
                [{ file: path, selected: selected.map(i => i.name) }]
            );
            const result = (data.result && data.result.content) ? data.result.content : [];
            result.forEach(fileResult => {
                if (fileResult.imported) {
                    fileResult.imported.forEach(name => { statusLog('import', '[OK] ' + name, 'logOk'); loaded++; importedDocs.push(name); });
                }
                if (fileResult.status && fileResult.status.errors) {
                    fileResult.status.errors.forEach(e => { statusLog('import', '[ERROR] ' + e.text, 'logError'); errors++; });
                }
            });
            if (data.console && data.console.length) data.console.forEach(line => statusLog('import', line));
        } else {
            // Upload mode: group selected items by filename, load via Atelier xml/load with cached lines
            const byFile = new Map();
            selected.forEach(item => {
                const f = item._file || '';
                if (!byFile.has(f)) byFile.set(f, []);
                byFile.get(f).push(item.name);
            });

            // If lines cache is missing (page reloaded between preview and import), re-read files
            const fileInputs = document.getElementById('importFiles').files;
            for (const file of fileInputs) {
                if (!uploadedFileLines[file.name]) {
                    statusLog('import', 'Re-reading ' + file.name + '…');
                    uploadedFileLines[file.name] = (await file.text()).split('\n');
                }
            }

            const flagParam = flags ? '?flags=' + encodeURIComponent(flags) : '';
            for (const [filename, names] of byFile) {
                const lines = uploadedFileLines[filename];
                if (!lines) { statusLog('import', '[ERROR] No content cached for ' + filename, 'logError'); errors++; continue; }
                const data = await atelierPost(
                    '/api/atelier/v7/' + encodeURIComponent(targetNs) + '/action/xml/load' + flagParam,
                    [{ content: lines, file: filename, selected: names }]
                );
                const result = (data.result && data.result.content) ? data.result.content : [];
                result.forEach(fileResult => {
                    if (fileResult.imported) {
                        fileResult.imported.forEach(name => { statusLog('import', '[OK] ' + name, 'logOk'); loaded++; importedDocs.push(name); });
                    }
                    if (fileResult.status && fileResult.status.errors) {
                        fileResult.status.errors.forEach(e => { statusLog('import', '[ERROR] ' + e.text, 'logError'); errors++; });
                    }
                });
                if (data.console && data.console.length) data.console.forEach(line => statusLog('import', line));
            }
        }

        statusLog('import', '── Loaded ' + loaded + ' item(s), ' + errors + ' error(s) ──────────────────────',
            errors ? 'logError' : 'logOk');

        // Separate compile step if background flag not set via load
        if (doCompile && !flags.includes('b') && loaded > 0) {
            await runCompileStep('import', targetNs, [{ imported: importedDocs }], flags);
        }

        if (loaded > 0) {
            statusLog('import',
                'ℹ Sync local workspace: InterSystems panel → right-click namespace → "Export all" ' +
                'or pull individual classes via the ObjectScript extension.',
                'logWarn');
        }

    } catch (e) {
        statusLog('import', '[ERROR] ' + e.message, 'logError');
    }

    document.getElementById('importRunBtn').disabled = false;
}

async function runCompileStep(side, targetNs, loadResults, flags) {
    let docs = [];
    loadResults.forEach(r => { if (r.imported) docs = docs.concat(r.imported); });
    if (!docs.length) return;

    statusLog(side, '── Compiling ' + docs.length + ' item(s)… ──────────────────────');

    // Atelier compile endpoint expects an array of document name strings.
    // Batch into chunks of 50 to avoid request size limits.
    const BATCH = 50;
    let ok = 0, err = 0;
    try {
        for (let i = 0; i < docs.length; i += BATCH) {
            const batch = docs.slice(i, i + BATCH);
            const flagParam = flags ? '?flags=' + encodeURIComponent(flags) : '';
            const data = await atelierPost(
                '/api/atelier/v7/' + encodeURIComponent(targetNs) + '/action/compile' + flagParam,
                batch
            );

            if (data.result && data.result.content) {
                data.result.content.forEach(item => {
                    statusLog(side, '[COMPILE] ' + item.name + (item.status === 0 ? ' OK' : ' ERROR'),
                        item.status === 0 ? 'logOk' : 'logError');
                    item.status === 0 ? ok++ : err++;
                });
            }
            if (data.console && data.console.length) {
                data.console.forEach(line => statusLog(side, line));
            }
        }
        statusLog(side, '── Compiled ' + ok + ' OK, ' + err + ' error(s) ──────────────────────',
            err ? 'logError' : 'logOk');
    } catch (e) {
        statusLog(side, '[COMPILE ERROR] ' + e.message, 'logError');
    }
}

// ── Export: search ────────────────────────────────────────────────────────────
async function searchExport() {
    exportItems = [];
    document.getElementById('exportTreeCard').style.display = 'none';
    document.getElementById('exportOptionsCard').style.display = 'none';
    document.getElementById('exportRunBtn').disabled = true;
    showStatus('export');
    statusLog('export', 'Searching…');

    const pattern = document.getElementById('exportPattern').value.trim().toLowerCase();
    const fromDate = document.getElementById('exportFrom').value;
    const toDate = document.getElementById('exportTo').value;
    const sys = document.getElementById('expSys').checked ? 1 : 0;
    const gen = document.getElementById('expGen').checked ? 1 : 0;
    const mapped = document.getElementById('expMapped').checked ? 1 : 0;

    const cats = ['CLS', 'RTN', 'OTH'];  // fetch in parallel
    try {
        const responses = await Promise.all(cats.map(cat =>
            atelierGet('/api/atelier/v7/' + encodeURIComponent(ns()) +
                '/docnames/' + cat +
                '?sys=' + sys + '&gen=' + gen + '&mapped=' + mapped)
        ));

        responses.forEach((data, ci) => {
            const docs = (data.result && data.result.content) ? data.result.content : [];
            docs.forEach(doc => {
                const name = typeof doc === 'string' ? doc : doc.name;
                const ts = (doc && doc.ts) ? doc.ts : '';

                // Pattern filter (simple glob: * → .*)
                if (pattern) {
                    const regex = new RegExp('^' + pattern.replace(/[.+^${}()|[\]\\]/g, '\\$&').replace(/\*/g, '.*') + '$', 'i');
                    if (!regex.test(name)) return;
                }

                // Date filter
                if (fromDate && ts && ts.substring(0, 10) < fromDate) return;
                if (toDate && ts && ts.substring(0, 10) > toDate) return;

                exportItems.push({ name, ts, type: cats[ci] });
            });
        });

        if (!exportItems.length) {
            statusLog('export', 'No items matched the filters', 'logWarn');
            return;
        }

        statusLog('export', 'Found ' + exportItems.length + ' item(s)', 'logOk');
        buildTree('export', exportItems);
        document.getElementById('exportTreeCard').style.display = '';
        document.getElementById('exportOptionsCard').style.display = '';
        document.getElementById('exportRunBtn').disabled = false;
        setSuggestedExportPath();

    } catch (e) {
        statusLog('export', '[ERROR] ' + e.message, 'logError');
    }
}

// ── Export: option toggles ────────────────────────────────────────────────────
function exportDestChanged() {
    const dest = document.querySelector('input[name="exportDest"]:checked').value;
    document.getElementById('exportServerPathBlock').style.display = dest === 'server' ? '' : 'none';
    exportFormatChanged();  // re-sync UDL dir visibility
}

function exportFormatChanged() {
    const fmt = document.querySelector('input[name="exportFormat"]:checked').value;
    const dest = document.querySelector('input[name="exportDest"]:checked').value;
    document.getElementById('exportUdlDirBlock').style.display =
        (fmt === 'udl' && dest === 'server') ? '' : 'none';
    document.getElementById('exportServerPathBlock').style.display =
        (fmt === 'xml' && dest === 'server') ? '' : 'none';
}

// ── Export: run ───────────────────────────────────────────────────────────────
async function runExport() {
    const selected = getCheckedItems('export');
    if (!selected.length) { alert('No items selected.'); return; }

    const dest = document.querySelector('input[name="exportDest"]:checked').value;
    const fmt = document.querySelector('input[name="exportFormat"]:checked').value;

    showStatus('export');
    document.getElementById('exportRunBtn').disabled = true;
    statusLog('export', '── Export started (' + selected.length + ' items) ──────────────────────');

    try {
        if (fmt === 'xml') {
            await exportXml(selected, dest);
        } else {
            await exportUdl(selected, dest);
        }
    } catch (e) {
        statusLog('export', '[ERROR] ' + e.message, 'logError');
    }

    document.getElementById('exportRunBtn').disabled = false;
}

async function exportXml(selected, dest) {
    const names = selected.map(i => i.name);

    // Call Atelier xml/export to get XML content
    const data = await atelierPost(
        '/api/atelier/v7/' + encodeURIComponent(ns()) + '/action/xml/export',
        names
    );

    const lines = (data.result && data.result.content) ? data.result.content : [];
    const errors = (data.result && data.result.status && data.result.status.errors) ? data.result.status.errors : [];
    errors.forEach(e => statusLog('export', '[ERROR] ' + e.text, 'logError'));

    if (!lines.length) {
        statusLog('export', 'Export returned no content', 'logWarn');
        return;
    }

    if (dest === 'browser') {
        const xml = lines.join('\n');
        const blob = new Blob([xml], { type: 'application/xml' });
        const url = URL.createObjectURL(blob);
        const a = document.createElement('a');
        a.href = url;
        a.download = 'export_' + nowStamp() + '.xml';
        a.click();
        URL.revokeObjectURL(url);
        statusLog('export', '[OK] Downloaded export_' + nowStamp() + '.xml (' + lines.length + ' lines)', 'logOk');
    } else {
        const path = document.getElementById('exportPath').value.trim();
        // Relay write to server
        const relay = await fetch(window.location.href.split('?')[0] + '?action=writeXml', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ path, lines })
        });
        const result = await relay.json();
        if (result.ok) {
            statusLog('export', '[OK] Written to ' + result.path + ' (' + lines.length + ' lines)', 'logOk');
        } else {
            statusLog('export', '[ERROR] ' + result.error, 'logError');
        }
    }

    statusLog('export', '── Export complete ──────────────────────', 'logOk');
}

async function exportUdl(selected, dest) {
    const subdirs = document.getElementById('exportSubdirs').checked;
    const dir = dest === 'server' ? document.getElementById('exportUdlDir').value.trim() : null;

    let ok = 0, err = 0;
    let zipEntries = [];   // for browser download: [{path, content}]

    for (const item of selected) {
        try {
            const data = await atelierGet('/api/atelier/v7/' + encodeURIComponent(ns()) + '/doc/' + encodeURIComponent(item.name));
            const content = (data.result && data.result.content) ? data.result.content : {};
            const lines = content.content || [];
            const text = lines.join('\n');

            if (dest === 'server') {
                const relay = await fetch(window.location.href.split('?')[0] + '?action=writeUdl', {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify({ dir, name: item.name, subdirs, lines })
                });
                const result = await relay.json();
                if (result.ok) {
                    statusLog('export', '[OK] ' + result.path, 'logOk');
                    ok++;
                } else {
                    statusLog('export', '[ERROR] ' + item.name + ': ' + result.error, 'logError');
                    err++;
                }
            } else {
                // Collect for zip download
                let filePath = item.name;
                if (subdirs) {
                    const parts = item.name.split('.');
                    const ext = parts.pop();
                    filePath = parts.join('/') + '.' + ext;
                }
                zipEntries.push({ path: filePath, content: text });
                statusLog('export', '[OK] ' + item.name, 'logOk');
                ok++;
            }
        } catch (e) {
            statusLog('export', '[ERROR] ' + item.name + ': ' + e.message, 'logError');
            err++;
        }
    }

    if (dest === 'browser' && zipEntries.length) {
        downloadZip(zipEntries);
    }

    statusLog('export', '── Export complete: ' + ok + ' OK, ' + err + ' error(s) ──────────────────────',
        err ? 'logError' : 'logOk');
}

// Simple ZIP builder (no library dependency — uses Blob + zip format manually)
// Falls back to downloading as a single concatenated text file if only 1 item
function downloadZip(entries) {
    if (entries.length === 1) {
        const blob = new Blob([entries[0].content], { type: 'text/plain' });
        const url = URL.createObjectURL(blob);
        const a = document.createElement('a');
        a.href = url;
        a.download = entries[0].path.replace(/\//g, '_');
        a.click();
        URL.revokeObjectURL(url);
        return;
    }

    // Build a minimal ZIP file in-browser
    const enc = new TextEncoder();
    const localHeaders = [];
    const centralHeaders = [];
    let offset = 0;

    function crc32(buf) {
        let crc = -1;
        const table = crc32.table || (crc32.table = (() => {
            const t = new Uint32Array(256);
            for (let i = 0; i < 256; i++) {
                let c = i;
                for (let j = 0; j < 8; j++) c = (c & 1) ? 0xEDB88320 ^ (c >>> 1) : c >>> 1;
                t[i] = c;
            }
            return t;
        })());
        for (let i = 0; i < buf.length; i++) crc = table[(crc ^ buf[i]) & 0xFF] ^ (crc >>> 8);
        return (crc ^ -1) >>> 0;
    }

    function u16(n) { const b = new Uint8Array(2); new DataView(b.buffer).setUint16(0, n, true); return b; }
    function u32(n) { const b = new Uint8Array(4); new DataView(b.buffer).setUint32(0, n, true); return b; }

    const parts = [];

    entries.forEach(({ path, content }) => {
        const nameBytes = enc.encode(path);
        const dataBytes = enc.encode(content);
        const crc = crc32(dataBytes);
        const date = new Date();
        const dosDate = ((date.getFullYear() - 1980) << 9) | ((date.getMonth() + 1) << 5) | date.getDate();
        const dosTime = (date.getHours() << 11) | (date.getMinutes() << 5) | Math.floor(date.getSeconds() / 2);

        // Local file header
        const lh = new Uint8Array([
            0x50, 0x4B, 0x03, 0x04, // signature
            0x14, 0x00,             // version needed
            0x00, 0x00,             // flags
            0x00, 0x00,             // compression (stored)
            ...u16(dosTime), ...u16(dosDate),
            ...u32(crc),
            ...u32(dataBytes.length),
            ...u32(dataBytes.length),
            ...u16(nameBytes.length),
            0x00, 0x00              // extra field length
        ]);

        localHeaders.push({ offset, nameBytes, crc, size: dataBytes.length, dosTime, dosDate });

        parts.push(lh, nameBytes, dataBytes);
        offset += lh.length + nameBytes.length + dataBytes.length;
    });

    const cdOffset = offset;
    localHeaders.forEach(({ offset: lhOffset, nameBytes, crc, size, dosTime, dosDate }) => {
        const ch = new Uint8Array([
            0x50, 0x4B, 0x01, 0x02, // signature
            0x14, 0x00,             // version made by
            0x14, 0x00,             // version needed
            0x00, 0x00,             // flags
            0x00, 0x00,             // compression
            ...u16(dosTime), ...u16(dosDate),
            ...u32(crc),
            ...u32(size), ...u32(size),
            ...u16(nameBytes.length),
            0x00, 0x00,             // extra
            0x00, 0x00,             // comment
            0x00, 0x00,             // disk start
            0x00, 0x00,             // int attrs
            0x00, 0x00, 0x00, 0x00, // ext attrs
            ...u32(lhOffset)
        ]);
        parts.push(ch, nameBytes);
        offset += ch.length + nameBytes.length;
    });

    const cdSize = offset - cdOffset;
    const eocd = new Uint8Array([
        0x50, 0x4B, 0x05, 0x06,
        0x00, 0x00, 0x00, 0x00,
        ...u16(entries.length), ...u16(entries.length),
        ...u32(cdSize), ...u32(cdOffset),
        0x00, 0x00
    ]);
    parts.push(eocd);

    const blob = new Blob(parts, { type: 'application/zip' });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = 'export_' + nowStamp() + '.zip';
    a.click();
    URL.revokeObjectURL(url);
}

// ── Tree builder ──────────────────────────────────────────────────────────────
const TREE_DEPTH = 3;  // max package nesting levels shown; deeper items land at this level

function buildTree(side, items) {
    const containerId = side + 'Tree';
    const container = document.getElementById(containerId);
    container.innerHTML = '';

    const tree = {};  // nested: { _items: [], _subPkgs: {} }

    items.forEach(item => {
        const parts = item.name.split('.');
        // Everything except the final segment is the package path.
        // e.g. HS.Local.zimpli.fhir.UI.About.cls → pkg parts [HS,Local,zimpli,fhir,UI,About]
        const pkgParts = parts.length >= 2 ? parts.slice(0, -1) : [];
        insertIntoTree(tree, pkgParts, item, 0);
    });

    renderTree(container, tree, side, '');

    document.getElementById(side + 'TreeTitle').textContent =
        'Items (' + items.length + ')';
}

function insertIntoTree(node, pkgParts, item, depth) {
    if (!node._items) node._items = [];
    if (!node._subPkgs) node._subPkgs = {};

    // At or beyond the depth cap — attach item here regardless of remaining parts
    if (pkgParts.length === 0 || depth >= TREE_DEPTH) {
        node._items.push(item);
    } else {
        const key = pkgParts[0];
        if (!node._subPkgs[key]) node._subPkgs[key] = { _items: [], _subPkgs: {} };
        insertIntoTree(node._subPkgs[key], pkgParts.slice(1), item, depth + 1);
    }
}

function renderTree(container, node, side, prefix) {
    const pkgKeys = Object.keys(node._subPkgs || {}).sort();
    const items = node._items || [];

    pkgKeys.forEach(key => {
        const fullPkg = prefix ? prefix + '.' + key : key;
        const child = node._subPkgs[key];
        const childCount = countItems(child);

        const pkgDiv = document.createElement('div');
        pkgDiv.className = 'treePkg';
        pkgDiv.innerHTML =
            '<label class="pkgLabel">' +
            '<input type="checkbox" class="pkgCheck" data-side="' + side + '" data-pkg="' + fullPkg + '" checked> ' +
            '<span class="pkgToggle" onclick="togglePkg(this.parentElement.parentElement)">&#9660;</span> ' +
            '<b>' + key + '</b>' +
            ' <span class="itemCount">' + childCount + '</span>' +
            '</label>';

        const childDiv = document.createElement('div');
        childDiv.className = 'treeChildren';
        renderTree(childDiv, child, side, fullPkg);
        pkgDiv.appendChild(childDiv);
        container.appendChild(pkgDiv);
    });

    items.forEach(item => {
        const leaf = document.createElement('label');
        leaf.className = 'treeItem';

        // Compute diff badge for import side
        // tsCurrent: timestamp of doc in the file (from Atelier xml/list); '' = not in namespace
        let badge = '', badgeClass = '';
        if (side === 'import') {
            if (!item.tsCurrent) {
                badge = 'new'; badgeClass = 'badgeNew';
            } else {
                badge = 'exists'; badgeClass = 'badgeSame';
            }
        }

        const badgeHtml = badge ? ' <span class="itemBadge ' + badgeClass + '">' + badge + '</span>' : '';
        const metaDate = isoToDateStr(item.tsCurrent || item.ts || '');
        const titleText = item.name
            + (item.tsCurrent ? '\nIn namespace: ' + item.tsCurrent : '\nNot in namespace');

        leaf.innerHTML =
            '<input type="checkbox" class="itemCheck" data-side="' + side + '" data-name="' + item.name + '" checked> ' +
            '<span class="itemName"></span>' +
            badgeHtml +
            '<span class="itemMeta">' + item.name + (metaDate ? ' · ' + metaDate : '') + '</span>';

        leaf.querySelector('.itemName').textContent = item.name.split('.').slice(-2).join('.');
        leaf.title = titleText;

        container.appendChild(leaf);
    });
}

function countItems(node) {
    let n = (node._items || []).length;
    Object.values(node._subPkgs || {}).forEach(child => { n += countItems(child); });
    return n;
}

function togglePkg(pkgDiv) {
    const children = pkgDiv.querySelector('.treeChildren');
    if (children) children.style.display = children.style.display === 'none' ? '' : 'none';
    const arrow = pkgDiv.querySelector('.pkgToggle');
    if (arrow) arrow.innerHTML = children && children.style.display === 'none' ? '&#9654;' : '&#9660;';
}

function onPkgCheck(cb) {
    const pkg = cb.dataset.pkg;
    const checked = cb.checked;
    // Check/uncheck all item children under this package
    const container = cb.closest('.treePkg').querySelector('.treeChildren');
    if (container) {
        container.querySelectorAll('.itemCheck').forEach(ic => { ic.checked = checked; });
        container.querySelectorAll('.pkgCheck').forEach(pc => { pc.checked = checked; });
    }
}

function onItemCheck(cb) {
    // Update parent package checkbox state
    const pkg = cb.closest('.treeChildren');
    if (!pkg) return;
    const pkgDiv = pkg.closest('.treePkg');
    if (!pkgDiv) return;
    const pkgCb = pkgDiv.querySelector(':scope > label > .pkgCheck');
    if (!pkgCb) return;
    const siblings = pkg.querySelectorAll('.itemCheck');
    const allChecked = Array.from(siblings).every(s => s.checked);
    const someChecked = Array.from(siblings).some(s => s.checked);
    pkgCb.indeterminate = someChecked && !allChecked;
    pkgCb.checked = allChecked;
}

function treeSelectAll(side) {
    document.querySelectorAll('#' + side + 'Tree .itemCheck, #' + side + 'Tree .pkgCheck')
        .forEach(cb => { cb.checked = true; cb.indeterminate = false; });
}

function treeSelectNone(side) {
    document.querySelectorAll('#' + side + 'Tree .itemCheck, #' + side + 'Tree .pkgCheck')
        .forEach(cb => { cb.checked = false; cb.indeterminate = false; });
}

function getCheckedItems(side) {
    const items = side === 'import' ? importItems : exportItems;
    const checkedNames = new Set();
    document.querySelectorAll('#' + side + 'Tree .itemCheck:checked')
        .forEach(cb => checkedNames.add(cb.dataset.name));
    return items.filter(i => checkedNames.has(i.name));
}
