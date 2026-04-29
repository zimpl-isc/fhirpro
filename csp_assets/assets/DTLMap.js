(function () {
	'use strict';

	var network = null;

	var GROUPS = {
		entrypoint: {
			color: { background: '#3b82f6', border: '#1d4ed8',
			         highlight: { background: '#60a5fa', border: '#1d4ed8' } },
			font:  { color: '#ffffff', size: 13, face: 'Arial' },
			shape: 'box', borderWidth: 2, margin: 8
		},
		custom: {
			color: { background: '#8b5cf6', border: '#6d28d9',
			         highlight: { background: '#a78bfa', border: '#5b21b6' } },
			font:  { color: '#ffffff', size: 12, face: 'Arial' },
			shape: 'box', borderWidth: 1, margin: 6
		},
		base: {
			color: { background: '#e2e8f0', border: '#94a3b8',
			         highlight: { background: '#cbd5e1', border: '#64748b' } },
			font:  { color: '#1e293b', size: 12, face: 'Arial' },
			shape: 'box', borderWidth: 1, margin: 6
		},
		external: {
			color: { background: '#fef3c7', border: '#d97706',
			         highlight: { background: '#fde68a', border: '#b45309' } },
			font:  { color: '#78350f', size: 12, face: 'Arial' },
			shape: 'box', borderWidth: 1, borderDashes: [4, 3], margin: 6
		}
	};

	var NETWORK_OPTIONS = {
		groups: GROUPS,
		nodes: {
			shape: 'box',
			margin: { top: 6, bottom: 6, left: 10, right: 10 },
			font: { size: 12, face: 'Arial' }
		},
		edges: {
			arrows: { to: { enabled: true, scaleFactor: 0.6 } },
			color:  { color: '#94a3b8', highlight: '#64748b' },
			smooth: { type: 'continuous', roundness: 0.3 },
			width: 1.2
		},
		physics: { enabled: false },
		interaction: { dragNodes: true, dragView: true, hover: true, zoomView: false }
	};

	function zoomNetwork(factor) {
		if (!network) return;
		var newScale = Math.min(2.5, Math.max(0.3, network.getScale() * factor));
		network.moveTo({ scale: newScale, animation: { duration: 150, easingFunction: 'easeInOutQuad' } });
	}

	var zoomHoldDelay = null, zoomTimer = null;

	function stopZoomInteraction() {
		if (zoomHoldDelay) { clearTimeout(zoomHoldDelay); zoomHoldDelay = null; }
		if (zoomTimer)     { clearInterval(zoomTimer);    zoomTimer = null; }
	}

	function handleZoomPress(factor) {
		stopZoomInteraction();
		zoomHoldDelay = setTimeout(function () {
			zoomHoldDelay = null;
			zoomTimer = setInterval(function () { zoomNetwork(factor); }, 120);
		}, 200);
	}

	function handleZoomRelease(factor) {
		if (zoomHoldDelay) { clearTimeout(zoomHoldDelay); zoomHoldDelay = null; zoomNetwork(factor); }
		stopZoomInteraction();
	}

	function bindZoomButton(button, factor) {
		if (!button) return;
		button.onpointerdown   = function (e) { e.preventDefault(); handleZoomPress(factor); };
		button.onpointerup     = function (e) { e.preventDefault(); handleZoomRelease(factor); };
		button.onpointerleave  = stopZoomInteraction;
		button.onpointercancel = stopZoomInteraction;
	}

	function syncBackdrop() {
		var inspectorOpen = $('#DTLInspector').hasClass('open');
		if (inspectorOpen) {
			$('#DrawerBackdrop').addClass('open');
		} else {
			$('#DrawerBackdrop').removeClass('open');
		}
	}

	$(document).ready(function () {
		var container = document.getElementById('VisNetworkPane');

		(function () {
			var GAP = 50;

			var maxLevel = 0;
			GRAPH_DATA.nodes.forEach(function (n) {
				if ((n.level || 0) > maxLevel) maxLevel = n.level || 0;
			});

			var canvasW = container.clientWidth || 900;
			var LEVEL_W = maxLevel > 0
				? Math.max(160, Math.floor((canvasW * 0.92) / maxLevel))
				: 230;

			var SEC = { entrypoint: 0, custom: 0, base: 1, external: 2 };

			var columns = {};
			GRAPH_DATA.nodes.forEach(function (n) {
				var l = n.level || 0;
				var s = SEC[n.group] || 0;
				if (!columns[l]) columns[l] = [[], [], []];
				columns[l][s].push(n);
			});

			var nodeMap = {};
			var outDeg = {};
			var inDeg = {};
			GRAPH_DATA.nodes.forEach(function (n) {
				nodeMap[n.id] = n;
				outDeg[n.id] = 0;
				inDeg[n.id] = 0;
			});

			var parents = {};
			GRAPH_DATA.edges.forEach(function (e) {
				if (!parents[e.to]) parents[e.to] = [];
				parents[e.to].push(e.from);
				outDeg[e.from] = (outDeg[e.from] || 0) + 1;
				inDeg[e.to]    = (inDeg[e.to]    || 0) + 1;
			});

			function degree(id) {
				return (outDeg[id] || 0) + (inDeg[id] || 0);
			}

			function parentCentroidY(nodeId) {
				var ps = parents[nodeId];
				if (!ps || !ps.length) return 0;
				var sum = 0, cnt = 0;
				ps.forEach(function (pid) {
					var p = nodeMap[pid];
					if (p && p.y !== undefined) { sum += p.y; cnt++; }
				});
				return cnt ? (sum / cnt) : 0;
			}

			var canvasH = container.clientHeight || 800;
			var maxNodes = 0;
			Object.keys(columns).forEach(function (l) {
				var col  = columns[l];
				var n    = col[0].length + col[1].length + col[2].length;
				var secs = [0, 1, 2].filter(function (s) { return col[s].length > 0; }).length;
				var h    = n + secs * (GAP / 30);
				if (h > maxNodes) maxNodes = h;
			});

			var PITCH = maxNodes > 1
				? Math.max(30, Math.min(60, Math.floor((canvasH * 0.85 - GAP * 2) / maxNodes)))
				: 44;

			function degreeCenter(arr) {
				var sorted = arr.slice().sort(function (a, b) { return degree(a.id) - degree(b.id); });
				var result  = new Array(sorted.length);
				var midLeft = Math.floor((sorted.length - 1) / 2);
				var midRight = midLeft + 1;
				var placeLeft = true;
				for (var i = sorted.length - 1; i >= 0; i--) {
					if (placeLeft) { result[midLeft--]  = sorted[i]; }
					else           { result[midRight++] = sorted[i]; }
					placeLeft = !placeLeft;
				}
				return result.filter(function (n) { return !!n; });
			}

			function assignColumnY(l) {
				var col = columns[l];
				if (!col) return;
				[0, 1, 2].forEach(function (s) {
					col[s].sort(function (a, b) { return parentCentroidY(a.id) - parentCentroidY(b.id); });
					col[s] = degreeCenter(col[s]);
				});
				var totalH = 0;
				[0, 1, 2].forEach(function (s) {
					if (col[s].length) totalH += col[s].length * PITCH + (totalH > 0 ? GAP : 0);
				});
				var y = -totalH / 2;
				[0, 1, 2].forEach(function (s) {
					col[s].forEach(function (n) { n.x = l * LEVEL_W; n.y = y; y += PITCH; });
					if (col[s].length) y += GAP;
				});
			}

			Object.keys(columns).map(Number).sort(function (a, b) { return a - b; })
				.forEach(function (l) { assignColumnY(l); });
		}());

		var nodes = new vis.DataSet(GRAPH_DATA.nodes);
		var edges = new vis.DataSet(GRAPH_DATA.edges);

		network = new vis.Network(container, { nodes: nodes, edges: edges }, NETWORK_OPTIONS);

		bindZoomButton(document.getElementById('ZoomInBtn'),  1.15);
		bindZoomButton(document.getElementById('ZoomOutBtn'), 1 / 1.15);
		document.addEventListener('mouseup',      stopZoomInteraction);
		document.addEventListener('pointerup',    stopZoomInteraction);
		document.addEventListener('pointercancel', stopZoomInteraction);
		window.addEventListener('blur',           stopZoomInteraction);

		var fitBtn = document.getElementById('ZoomFitBtn');
		if (fitBtn) fitBtn.onclick = function () { window.fitNetwork(); };

		document.getElementById('DrawerBackdrop').addEventListener('click', function () {
			closeDTLInspector();
		});

		network.once('afterDrawing', function () {
			if (HIGHLIGHT_CLASS && nodes.get(HIGHLIGHT_CLASS)) {
				network.selectNodes([HIGHLIGHT_CLASS]);
				var scale   = Math.min(2.5, Math.max(0.3, 1.2));
				var nodePos = network.getPositions([HIGHLIGHT_CLASS])[HIGHLIGHT_CLASS];
				var canvasW = container.clientWidth || 900;
				var offsetX = (canvasW * 0.25 - canvasW * 0.5) / scale;
				network.moveTo({
					position:  { x: nodePos.x - offsetX, y: nodePos.y },
					scale:     scale,
					animation: { duration: 400, easingFunction: 'easeInOutQuad' }
				});
				openDTLInspector(HIGHLIGHT_CLASS);
			} else {
				network.fit({ animation: { duration: 400, easingFunction: 'easeInOutQuad' } });
			}
		});

		network.on('click', function (params) {
			if (params.nodes.length > 0) {
				openDTLInspector(params.nodes[0]);
			} else {
				closeDTLInspector();
			}
		});
	});

	function openDTLInspector(nodeId) {
		var node = null;
		for (var i = 0; i < GRAPH_DATA.nodes.length; i++) {
			if (GRAPH_DATA.nodes[i].id === nodeId) { node = GRAPH_DATA.nodes[i]; break; }
		}
		if (!node) return;

		$('#DTLInspectorGroup')
			.text(node.group.charAt(0).toUpperCase() + node.group.slice(1))
			.attr('class', 'nodeInfoGroup ' + node.group);

		var parents = [];
		for (var i = 0; i < GRAPH_DATA.edges.length; i++) {
			if (GRAPH_DATA.edges[i].to === nodeId) parents.push(GRAPH_DATA.edges[i].from);
		}
		var $parents = $('#DTLInspectorParents').empty();
		if (parents.length > 0) {
			$parents.append($('<span>').addClass('parentLabel').text('called by'));
			parents.forEach(function (pid) {
				var parentNode = null;
				for (var j = 0; j < GRAPH_DATA.nodes.length; j++) {
					if (GRAPH_DATA.nodes[j].id === pid) { parentNode = GRAPH_DATA.nodes[j]; break; }
				}
				var grp = parentNode ? parentNode.group : 'base';
				$('<span>')
					.addClass('parentChip ' + grp)
					.text(parentNode ? parentNode.label : pid)
					.attr('title', pid)
					.on('click', function () { openDTLInspector(pid); network.selectNodes([pid]); })
					.appendTo($parents);
			});
		}

		if (node.group === 'external') {
			$('#DTLViewerLink').removeAttr('data-href').prop('disabled', true);
			$('#DTLInspectorFrame').attr('src', 'about:blank').addClass('is-hidden');
			$('#DTLInspectorExternal').removeClass('is-hidden');
		} else {
			var viewerURL = DTL_VIEWER_PAGE + '?DTL=' + encodeURIComponent(node.id);
			$('#DTLViewerLink').attr('data-href', viewerURL).prop('disabled', false);
			$('#DTLInspectorExternal').addClass('is-hidden');
			$('#DTLInspectorFrame').removeClass('is-hidden').attr('src', viewerURL);
		}
		$('#DTLInspector').addClass('open');
		syncBackdrop();
	}

	window.closeDTLInspector = function () {
		$('#DTLInspector').removeClass('open');
		$('#DTLInspectorFrame').removeClass('is-hidden').attr('src', '');
		$('#DTLInspectorExternal').addClass('is-hidden');
		syncBackdrop();
	};

	window.fitNetwork = function () {
		if (network) network.fit({ animation: { duration: 400, easingFunction: 'easeInOutQuad' } });
	};

	window.changeType = function () {
		var type = $('#TypeSelect').val();
		var url  = window.location.pathname + '?type=' + encodeURIComponent(type);
		if (MAP_DIR === 'in') url += '&dir=in';
		window.open(url, '_self');
	};

	window.openPage = function () {
		window.open($('#GroupPage').val() + '.cls', '_self');
	};

}());
