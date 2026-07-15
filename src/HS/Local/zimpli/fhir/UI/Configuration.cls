/**
* zimpliFHIR Configuration page
*
* Tabs:
*   1. Gateway Registry   — Gateway Registry entries with derived links and production status
*   2. Service Registry   — read-only view of all zimpliFHIR:* entries
*   3. Preferences        — browser-local UI preferences (localStorage)
*
* @version 3.0 2026-07-09
* @author Brandon Thomas
*/

Class HS.Local.zimpli.fhir.UI.Configuration Extends HS.Local.zimpli.fhir.UI.Super
{

ClassMethod OnPage() As %Status
{
    &html<<!DOCTYPE html>
<html>
<head>
    <title>Configuration</title>
    #(..MetaTags())#
    #(..LinkJS("assets/ext/jquery-3.7.1.min.js"))#
    #(..LinkJS("assets/ext/vis-network.min.js"))#
    #(..DefaultStyle())#
    #(..LinkCSS("assets/Configuration.css"))#
</head>
<body>
<div id="pageShell">

    <div class="card pageHeader">
        <h1 class="pageTitle">Configuration</h1>
        <p class="pageDesc">Gateway Registry, Service Registry entries, and UI preferences.</p>
    </div>

    <!-- Tabbed card -->
    <div class="card tabbedCard">

        <div class="tabBar">
            <button class="tab active" data-tab="gw">Gateway Registry</button>
            <button class="tab" data-tab="fed">Federation</button>
            <button class="tab" data-tab="sr">Service Registry</button>
            <button class="tab" data-tab="prefs">Preferences</button>
        </div>

        <div id="tab-gw" class="tabPanel tabContent">
            <div id="GatewayMsg" class="statusMsg"></div>
            <table class="dataTable" id="GatewayTable">
                <thead><tr>
                    <th>Namespace</th>
                    <th>Type</th>
                    <th>Production status</th>
                    <th>Links</th>
                </tr></thead>
                <tbody id="GatewayRows"><tr><td colspan="4" class="muted">Loading&#x2026;</td></tr></tbody>
            </table>
        </div>

        <div id="tab-fed" class="tabPanel tabContent is-hidden">
            <div id="FedMsg" class="statusMsg"></div>
            <div class="fedWrapper">
                <div id="FedGraph" class="fedGraph"></div>
                <div id="FedPanel" class="fedPanel">
                    <div class="fedPanel-header">
                        <span class="fedPanel-title" id="FedPanel-title"></span>
                        <button class="fedPanel-close" id="FedPanel-close">&#x2715;</button>
                    </div>
                    <div class="fedPanel-body">
                        <div class="fedPanel-badge" id="FedPanel-badge"></div>
                        <div class="fedPanel-links" id="FedPanel-links"></div>
                        <div class="fedPanel-section" id="FedPanel-stats">
                            <div class="fedPanel-section-title" id="FedPanel-statsTitle">Last 3 hours</div>
                            <div id="FedPanel-statsBody" class="fedPanel-statsBody">
                                <span class="muted">Loading&#x2026;</span>
                            </div>
                        </div>
                        <div class="fedPanel-section" id="FedPanel-errSection" style="display:none">
                            <div class="fedPanel-section-title">Recent errors</div>
                            <div id="FedPanel-errBody" class="fedPanel-errBody"></div>
                        </div>
                    </div>
                </div>
            </div>
        </div>

        <div id="tab-sr" class="tabPanel tabContent is-hidden">
            <div id="SRMsg" class="statusMsg"></div>
            <table class="dataTable" id="SRTable">
                <thead><tr>
                    <th>Name</th>
                    <th>Host</th>
                    <th>Port</th>
                    <th>URL / Path</th>
                    <th>SSL</th>
                    <th>Status</th>
                </tr></thead>
                <tbody id="SRRows"><tr><td colspan="6" class="muted">Loading&#x2026;</td></tr></tbody>
            </table>
        </div>

        <div id="tab-prefs" class="tabPanel tabContent is-hidden">
            <p class="hint">Stored in browser localStorage. Cleared only if you use "clear all" on patient data.</p>
            <table class="dataTable">
                <tbody>
                    <tr>
                        <td style="width:220px;font-weight:500">DTL Editor UI</td>
                        <td>
                            <label class="prefRadio"><input type="radio" name="dtlEditorUI" value="classic"> Classic (<code>EnsPortal.DTLEditor.zen</code>)</label>
                            <label class="prefRadio"><input type="radio" name="dtlEditorUI" value="new"> New UI (<code>ui/interop/dtl-editor/</code>)</label>
                        </td>
                    </tr>
                </tbody>
            </table>
        </div>

    </div>

</div>

<script type="text/javascript">
(function () {

    var API = 'HS.Local.zimpli.fhir.API.InstanceProxy.cls';

    // ---- tab switching ----
    document.querySelectorAll('.tab').forEach(function (btn) {
        btn.addEventListener('click', function () {
            document.querySelectorAll('.tab').forEach(function (b) { b.classList.remove('active'); });
            document.querySelectorAll('.tabPanel').forEach(function (p) { p.classList.add('is-hidden'); });
            btn.classList.add('active');
            document.getElementById('tab-' + btn.dataset.tab).classList.remove('is-hidden');
            // vis-network needs a rendered container to lay out correctly
            if (btn.dataset.tab === 'fed' && _fedGateways.length) {
                buildFedGraph(_fedGateways, _fedStatusByNS);
            }
        });
    });

    // ---- helpers ----
    // Normalize a gateway baseURL: match current page scheme, strip :0 port
    function normalizeBaseURL(url) {
        if (!url) return url;
        url = url.replace(/^https?:/, window.location.protocol);
        url = url.replace(/:0\//, '/');
        return url;
    }

    function esc(s) {
        if (s == null) return '';
        return String(s).replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;').replace(/"/g,'&quot;');
    }
    function showMsg(id, msg, isError) {
        var el = document.getElementById(id);
        if (!el) return;
        el.textContent = msg;
        isError ? el.classList.add('is-error') : el.classList.remove('is-error');
    }

    // ---- gateway registry ----
    // prodState values from %SYS.Ensemble.GetStatusAll; 'auth' is a synthetic sentinel
    var _stateMap = { '1': ['badge-ok','Running'], '2': ['badge-none','Stopped'],
                      '3': ['badge-warn','Suspended'], '4': ['badge-warn','Troubled'],
                      'auth': ['badge-warn','Auth?'], 'err': ['badge-none','Unreachable'] };

    // Sort order: R=0, F=1, E=2, then others alphabetically
    var _typeOrder = { 'R': 0, 'F': 1, 'E': 2, 'A': 3, 'A2': 4, 'B': 5, 'S': 6, 'V': 7 };

    function typeOrder(t) { return _typeOrder.hasOwnProperty(t) ? _typeOrder[t] : 99; }

    function gatewayTypeLabel(t) {
        var map = { 'F': 'Flash (ODS)', 'E': 'Edge', 'A': 'Access', 'A2': 'Access 2',
                    'B': 'Bus', 'R': 'Registry', 'S': 'System Index', 'V': 'Event Log' };
        return map[t] || t;
    }

    function stateBadge(prodState) {
        var info = (prodState != null && prodState !== '') ? _stateMap[String(prodState)] : null;
        return info
            ? '<span class="badge ' + info[0] + '">' + info[1] + '</span>'
            : '<span class="muted">—</span>';
    }

    function sortedGateways(gateways) {
        return gateways.slice().sort(function (a, b) {
            var diff = typeOrder(a.type) - typeOrder(b.type);
            if (diff !== 0) return diff;
            return (a.namespace || '').localeCompare(b.namespace || '');
        });
    }

    function renderGateways(gateways, statusByNS) {
        var sorted = sortedGateways(gateways);
        var rows = sorted.map(function (gw) {
            var linkParts = [];
            if (gw.links && gw.links.productionOld)
                linkParts.push('<a href="' + esc(gw.links.productionOld) + '" target="_blank" class="quickLink">Production</a>');
            if (gw.links && gw.links.registryHome)
                linkParts.push('<a href="' + esc(gw.links.registryHome) + '" target="_blank" class="quickLink">Registry</a>');
            var links = linkParts.length ? linkParts.join(' ') : '<span class="muted">—</span>';
            var ns = (gw.namespace || '').toUpperCase();
            var prodState = statusByNS.hasOwnProperty(ns) ? statusByNS[ns] : null;
            var gwRegistered = (gw.status === 'Registered' || gw.status === 'R');
            return '<tr' + (gwRegistered ? '' : ' class="gw-inactive"') + '>'
                + '<td><code>' + esc(gw.namespace) + '</code></td>'
                + '<td>' + esc(gatewayTypeLabel(gw.type)) + '</td>'
                + '<td>' + stateBadge(prodState) + '</td>'
                + '<td>' + links + '</td>'
                + '</tr>';
        }).join('');
        $('#GatewayRows').html(rows || '<tr><td colspan="4" class="muted">No gateways found.</td></tr>');
    }

    // ---- federation graph ----
    var _fedNetwork = null;
    var _fedGateways = [];
    var _fedStatusByNS = {};

    // Muted pastel palette — type determines color only, no status border override
    var _fedTypeColors = {
        R:  { bg:'#fce4e4', border:'#f87171', hi:'#fca5a5' },
        F:  { bg:'#d1fae5', border:'#6ee7b7', hi:'#a7f3d0' },
        E:  { bg:'#fef3c7', border:'#fcd34d', hi:'#fde68a' },
        B:  { bg:'#dbeafe', border:'#93c5fd', hi:'#bfdbfe' },
        A:  { bg:'#ede9fe', border:'#c4b5fd', hi:'#ddd6fe' },
        A2: { bg:'#ede9fe', border:'#c4b5fd', hi:'#ddd6fe' },
        _:  { bg:'#f1f5f9', border:'#cbd5e1', hi:'#e2e8f0' }
    };
    var _statusTextColor = { '1':'#15803d', '2':'#6b7280', '3':'#c2410c', '4':'#c2410c' };

    function fedNodeColor(type) {
        var tc = _fedTypeColors[type] || _fedTypeColors['_'];
        return { background: tc.bg, border: tc.border, highlight: { background: tc.hi, border: tc.border } };
    }

    function buildFedGraph(gateways, statusByNS) {
        var container = document.getElementById('FedGraph');
        if (!container) return;

        // Layout: Registry top-center, Bus left, ODS+Access right (stacked), Edges below in rows of 3
        var nodes = [];
        var edges = [];
        var regId = null;
        var edgeCount = 0, accessCount = 0, otherCount = 0;
        var COLS = 3, COL_STEP = 160, ROW_STEP = 90;

        gateways.forEach(function (gw, i) {
            var t = gw.type;
            var ns = (gw.namespace || '').toUpperCase();
            var ps = statusByNS.hasOwnProperty(ns) ? statusByNS[ns] : null;
            var stateLabel = ps != null ? (_stateMap[String(ps)] || ['','—'])[1] : '';
            var stateColor = (ps != null && _statusTextColor[String(ps)]) ? _statusTextColor[String(ps)] : '#6b7280';

            var label = (gw.namespace || gw.name || '?')
                        + (stateLabel ? '\n' + stateLabel : '');

            var pos;
            if      (t === 'R')              { pos = { x:0,    y:0   }; }
            else if (t === 'B')              { pos = { x:-260, y:0   }; }
            else if (t === 'F')              { pos = { x:260,  y:-60 }; }
            else if (t === 'A' || t === 'A2'){ accessCount++; pos = { x:260, y:60 + (accessCount-1)*90 }; }
            else if (t === 'E') {
                var col = edgeCount % COLS;
                var row = Math.floor(edgeCount / COLS);
                edgeCount++;
                var totalCols = Math.min(COLS, gateways.filter(function(g){return g.type==='E';}).length);
                var startX = -Math.floor(totalCols / 2) * COL_STEP;
                pos = { x: startX + col * COL_STEP, y: 200 + row * ROW_STEP };
            }
            else { otherCount++; pos = { x:-200 + otherCount*130, y:380 }; }

            nodes.push({
                id: i,
                label: label,
                gwData: gw,
                x: pos.x, y: pos.y,
                color: fedNodeColor(t),
                font: { color: '#1f2937', size: 13, face: 'Arial' },
                shape: 'box',
                borderWidth: (t === 'R') ? 2 : 1.5,
                margin: { top:8, bottom:8, left:12, right:12 }
            });

            if (t === 'R') regId = i;
        });

        // Straight edges from Registry to everyone
        if (regId !== null) {
            nodes.forEach(function (n) {
                if (n.id === regId) return;
                var t = n.gwData.type;
                var bidir = (t === 'E' || t === 'F');
                edges.push({
                    from: regId, to: n.id,
                    width: 1.5,
                    color: { color:'#94a3b8', highlight:'#64748b' },
                    arrows: {
                        to:   { enabled: true,  scaleFactor: 0.6 },
                        from: { enabled: bidir, scaleFactor: 0.6 }
                    },
                    smooth: { enabled: false }
                });
            });
        }

        var options = {
            nodes:   { shape: 'box' },
            edges:   { smooth: { enabled: false } },
            physics: { enabled: false },
            interaction: { dragNodes: true, dragView: false, hover: true, zoomView: false,
                           selectable: true, selectConnectedEdges: false }
        };

        if (_fedNetwork) { _fedNetwork.destroy(); _fedNetwork = null; }
        _fedNetwork = new vis.Network(container, { nodes: nodes, edges: edges }, options);
        _fedNetwork.once('afterDrawing', function () {
            _fedNetwork.fit({ animation: { duration: 300, easingFunction: 'easeInOutQuad' } });
        });

        var panel = document.getElementById('FedPanel');
        document.getElementById('FedPanel-close').onclick = function () {
            panel.classList.remove('open');
        };

        function loadInteropStats(gw) {
            var ns = gw.namespace;
            var baseURL = normalizeBaseURL(gw.baseURL);
            if (!ns || !baseURL) {
                document.getElementById('FedPanel-stats').style.display = 'none';
                return;
            }
            // Hours window: UTC offset (in hours) + 1 buffer, minimum 1
            // getTimezoneOffset() is negative for UTC+ zones, e.g. UTC+2 → -120
            var tzOffsetHours = -new Date().getTimezoneOffset() / 60;
            var hours = Math.max(1, Math.ceil(Math.abs(tzOffsetHours)) + 1);
            document.getElementById('FedPanel-statsTitle').textContent =
                'Last ' + hours + 'h (UTC' + (tzOffsetHours >= 0 ? '+' : '') + tzOffsetHours + ')';

            document.getElementById('FedPanel-stats').style.display = '';
            document.getElementById('FedPanel-statsBody').innerHTML = '<span class="muted">Loading&#x2026;</span>';
            document.getElementById('FedPanel-errSection').style.display = 'none';

            fetch(baseURL + 'HS.Local.zimpli.fhir.API.InstanceProxy.cls?action=status.interop&hours=' + hours, { cache: 'no-store' })
                .then(function(r) { return r.json(); })
                .then(function(d) {
                    if (!d.ok) {
                        var msg = (d.error || 'Unavailable');
                        document.getElementById('FedPanel-statsBody').innerHTML = '<span class="muted">' + esc(msg) + '</span>';
                        return;
                    }
                    var errClass = d.errors > 0 ? ' stat-err' : '';
                    document.getElementById('FedPanel-statsBody').innerHTML =
                        '<div class="statRow"><span class="statLabel">Total</span><span class="statVal">' + d.total + '</span></div>'
                      + '<div class="statRow"><span class="statLabel">Completed</span><span class="statVal">' + d.completed + '</span></div>'
                      + '<div class="statRow"><span class="statLabel">Queued</span><span class="statVal">' + d.queued + '</span></div>'
                      + '<div class="statRow"><span class="statLabel">Errors</span><span class="statVal' + errClass + '">' + d.errors + '</span></div>';

                    var errs = d.recentErrors || [];
                    if (errs.length) {
                        var errHTML = errs.map(function(e) {
                            var t = (e.timeCreated || '').replace('T', ' ').slice(0, 19);
                            return '<div class="errRow">'
                                + '<span class="errTime">' + esc(t) + '</span>'
                                + '<span class="errRoute">' + esc(e.source || '') + ' → ' + esc(e.target || '') + '</span>'
                                + '</div>';
                        }).join('');
                        document.getElementById('FedPanel-errBody').innerHTML = errHTML;
                        document.getElementById('FedPanel-errSection').style.display = '';
                    }
                })
                .catch(function() {
                    document.getElementById('FedPanel-statsBody').innerHTML = '<span class="muted">Unavailable</span>';
                });
        }

        _fedNetwork.on('click', function (params) {
            if (!params.nodes.length) {
                panel.classList.remove('open');
                return;
            }
            var nodeId = params.nodes[0];
            var node = nodes[nodeId];
            if (!node) return;
            var gw = node.gwData;
            var ns = (gw.namespace || '').toUpperCase();
            var ps = statusByNS.hasOwnProperty(ns) ? statusByNS[ns] : null;
            var stateInfo = (ps != null) ? (_stateMap[String(ps)] || null) : null;

            document.getElementById('FedPanel-title').textContent =
                (gw.namespace || gw.name || '?') + ' \u2014 ' + gatewayTypeLabel(gw.type);
            document.getElementById('FedPanel-badge').innerHTML = stateInfo
                ? '<span class="badge ' + stateInfo[0] + '">' + stateInfo[1] + '</span>'
                : '<span class="muted">Status unknown</span>';

            var lp = [];
            if (gw.links && gw.links.productionOld)
                lp.push('<a href="' + esc(gw.links.productionOld) + '" target="_blank" class="quickLink">Production</a>');
            if (gw.links && gw.links.registryHome)
                lp.push('<a href="' + esc(gw.links.registryHome) + '" target="_blank" class="quickLink">Registry</a>');
            document.getElementById('FedPanel-links').innerHTML = lp.join(' ') || '<span class="muted">No links</span>';

            panel.classList.add('open');
            loadInteropStats(gw);
        });
    }

    function loadGateways() {
        $('#GatewayRows').html('<tr><td colspan="4" class="muted">Loading&#x2026;</td></tr>');
        $('#GatewayMsg').text('').removeClass('is-error');

        fetch(API + '?action=config.gateways', { cache: 'no-store' })
            .then(function (r) { return r.json(); })
            .then(function (data) {
                if (!data.ok) { showMsg('GatewayMsg', data.error, true); return; }
                var gateways = data.gateways || [];
                _fedGateways = gateways;

                renderGateways(gateways, {});

                // Dedup by scheme://host:port/prefix/csp/healthshare/ — one call per IRIS instance
                function instanceKey(url) {
                    var marker = '/csp/healthshare/';
                    var pos = url.indexOf(marker);
                    return pos >= 0 ? url.slice(0, pos + marker.length) : url;
                }
                // Build a map from instanceKey -> [namespaces] so we can mark all on failure
                var keyToNS = {};
                gateways.forEach(function (gw) {
                    if (!gw.baseURL || !gw.namespace) return;
                    var key = instanceKey(normalizeBaseURL(gw.baseURL));
                    (keyToNS[key] = keyToNS[key] || []).push(gw.namespace.toUpperCase());
                });

                var seen = {};
                var fetches = [];
                gateways.forEach(function (gw) {
                    if (!gw.baseURL) return;
                    var base = normalizeBaseURL(gw.baseURL);
                    var key = instanceKey(base);
                    if (seen[key]) return;
                    seen[key] = true;
                    var url = base + 'HS.Local.zimpli.fhir.API.InstanceProxy.cls?action=status.productions';
                    fetches.push(
                        fetch(url, { cache: 'no-store' })
                            .then(function (r) {
                                if (r.status === 401 || r.status === 403)
                                    return { ok: 0, _sentinel: 'auth', _key: key };
                                return r.json().then(function(d) { d._key = key; return d; });
                            })
                            .catch(function () { return { ok: 0, _sentinel: 'err', _key: key }; })
                    );
                });

                Promise.allSettled(fetches).then(function (results) {
                    var statusByNS = {};
                    results.forEach(function (r) {
                        if (r.status !== 'fulfilled') return;
                        var val = r.value;
                        if (val.ok) {
                            (val.productions || []).forEach(function (p) {
                                statusByNS[p.namespace.toUpperCase()] = p.prodState;
                            });
                        } else if (val._sentinel && val._key) {
                            // Mark every namespace on that instance with the sentinel
                            (keyToNS[val._key] || []).forEach(function (ns) {
                                statusByNS[ns] = val._sentinel;
                            });
                        }
                    });
                    _fedStatusByNS = statusByNS;
                    renderGateways(gateways, statusByNS);
                    buildFedGraph(gateways, statusByNS);
                });
            })
            .catch(function (e) { showMsg('GatewayMsg', e.message, true); });
    }

    // ---- service registry ----
    function loadSR() {
        $('#SRRows').html('<tr><td colspan="6" class="muted">Loading&#x2026;</td></tr>');
        $('#SRMsg').text('').removeClass('is-error');
        fetch(API + '?action=config.srEntries', { cache: 'no-store' })
            .then(function (r) { return r.json(); })
            .then(function (data) {
                if (!data.ok) { showMsg('SRMsg', data.error, true); return; }
                var rows = (data.entries || []).map(function (e) {
                    return '<tr>'
                        + '<td><code>' + esc(e.name) + '</code></td>'
                        + '<td>' + esc(e.host) + '</td>'
                        + '<td>' + esc(e.port) + '</td>'
                        + '<td class="endpoint-cell">' + esc(e.url) + '</td>'
                        + '<td>' + esc(e.ssl || '—') + '</td>'
                        + '<td>' + (e.status == 1 ? '<span class="badge badge-ok">Active</span>' : '<span class="badge badge-none">Inactive</span>') + '</td>'
                        + '</tr>';
                }).join('');
                $('#SRRows').html(rows || '<tr><td colspan="6" class="muted">No entries found.</td></tr>');
            })
            .catch(function (e) { showMsg('SRMsg', e.message, true); });
    }

    // ---- preferences ----
    var PREFS_KEY = 'zimplifhir.prefs';

    function loadPrefs() {
        try { return JSON.parse(localStorage.getItem(PREFS_KEY) || '{}'); } catch(e) { return {}; }
    }
    function savePrefs(prefs) {
        localStorage.setItem(PREFS_KEY, JSON.stringify(prefs));
    }

    function initPrefsTab() {
        var prefs = loadPrefs();
        var dtlUI = prefs.dtlEditorUI || 'classic';
        document.querySelectorAll('input[name="dtlEditorUI"]').forEach(function (r) {
            r.checked = (r.value === dtlUI);
            r.addEventListener('change', function () {
                var p = loadPrefs();
                p.dtlEditorUI = this.value;
                savePrefs(p);
            });
        });
    }

    // ---- init ----
    loadGateways();
    loadSR();
    initPrefsTab();

}());
</script>

</div>
#(##class(HS.Local.zimpli.fhir.UI.Configuration).Footer())#
</body>
</html>>
    return $$$OK
}

ClassMethod Footer()
{
    return ""
}

}
