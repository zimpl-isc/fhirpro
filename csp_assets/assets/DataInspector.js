(function () {
	"use strict";

	window.ViewerState = {
		sdaXmlRaw: "",
		fhirJsonRaw: "",
		fhirJsonObj: null,
		searchHits: [],
		currentHitIndex: -1,
		selectedJsonPath: null,
		selectedResourceId: null,
		selectedFullUrl: null,
		fhirDraftDirty: false,
		index: {
			byResourceId: {},
			byFullUrl: {}
		}
	};

	$(document).ready(function () {
		dragElement(document.getElementById("separator"));
		$('fieldset.infoBox').draggable();

		wireTabs();
		loadData();
		wireGlobalEvents();
		applyDeepLinkFromUrl();
	});

	function setStatus(msg) {
		$("#statusBar").text(msg || "");
	}

	function wireTabs() {
		$(".tabBtn").on("click", function () {
			const pane = $(this).data("pane");
			const view = $(this).data("view");

			$('.tabBtn[data-pane="' + pane + '"]').removeClass("active");
			$(this).addClass("active");

			if (pane === "sda") {
				$("#sdaPane .paneView").removeClass("active");
				if (view === "tree") $("#sdaTreeView").addClass("active");
				if (view === "raw") $("#sdaRawView").addClass("active");
			}

			if (pane === "fhir") {
				$("#fhirPane .paneView").removeClass("active");
				if (view === "tree") $("#fhirTreeView").addClass("active");
				if (view === "raw") $("#fhirRawView").addClass("active");
			}
		});
	}

	function wireGlobalEvents() {
		$(document).on("dblclick", ".textValue, .jsonLeaf, .xmlText, .rawToken", function () {
			const text = $(this).text().trim().replace(/^"+|"+$/g, "");
			if (!text) return;
			$("#searchTerm").val(text);
			viewerSearch(text);
		});

		$(document).on("click", ".toggle", function (e) {
			e.stopPropagation();
			const row = $(this).closest(".treeNode");
			row.toggleClass("collapsed");
			updateToggleGlyph(row);
		});

		$(document).on("click", ".treeLabel", function () {
			$(".selectedNode").removeClass("selectedNode");
			$(this).addClass("selectedNode");
		});

		$(document).on("click", ".jsonNode[data-resource-id], .jsonNode[data-full-url]", function () {
			const rid = $(this).attr("data-resource-id") || null;
			const furl = $(this).attr("data-full-url") || null;
			ViewerState.selectedResourceId = rid;
			ViewerState.selectedFullUrl = furl;
			setStatus(
				(rid ? "resource.id=" + rid : "") +
				(rid && furl ? " | " : "") +
				(furl ? "fullUrl=" + furl : "")
			);
		});

		$("#fhirRawText").on("input", function () {
			ViewerState.fhirDraftDirty = true;
			$("#fhirRawState").text("draft modified");
		});
	}

	function loadData() {
		const mpiid = getMpiid();
		if (!mpiid) {
			setStatus("No MPIID found in sessionStorage.");
			return;
		}

		const sda = getSdaData();
		const fhir = getFhirData();

		if (!sda) {
			setStatus("No SDA data found in storage.");
		} else {
			ViewerState.sdaXmlRaw = sda;
			renderXmlPane(sda);
		}

		if (!fhir) {
			setStatus("No FHIR data found in storage.");
		} else {
			ViewerState.fhirJsonRaw = prettyJsonString(fhir);
			try {
				ViewerState.fhirJsonObj = JSON.parse(fhir);
				renderJsonPane(ViewerState.fhirJsonObj);
				renderFhirRaw(ViewerState.fhirJsonRaw);
			} catch (ex) {
				setStatus("FHIR JSON parse error: " + ex.message);
				renderFhirRaw(fhir);
			}
		}
	}

	function renderXmlPane(xmlText) {
		$("#sdaRawPre").text(xmlText);

		let xmlDoc;
		try {
			xmlDoc = new DOMParser().parseFromString(xmlText, "application/xml");
		} catch (ex) {
			$("#sdaTreeView").html('<div class="errorBox">XML parse error: ' + escapeHtml(ex.message) + '</div>');
			return;
		}

		const parseErr = xmlDoc.getElementsByTagName("parsererror");
		if (parseErr && parseErr.length > 0) {
			$("#sdaTreeView").html('<div class="errorBox">XML parse error.</div>');
			return;
		}

		const root = xmlDoc.documentElement;
		const tree = buildXmlNode(root, "/"+root.nodeName, 0);
		$("#sdaTreeView").empty().append(tree);
	}

	function renderJsonPane(obj) {
		ViewerState.index.byResourceId = {};
		ViewerState.index.byFullUrl = {};

		const root = buildJsonNode("(root)", obj, "$", 0, null);
		$("#fhirTreeView").empty().append(root);
		indexBundleEntries(obj);
		applyDeepLinkFromUrl();
	}

	function renderFhirRaw(prettyText) {
		$("#fhirRawText").val(prettyText);
		$("#fhirRawState").text("read from sessionStorage");
		ViewerState.fhirDraftDirty = false;
	}

	function prettyJsonString(jsonText) {
		try {
			return JSON.stringify(JSON.parse(jsonText), null, 2);
		} catch (ex) {
			return jsonText;
		}
	}

	function buildXmlNode(node, path, depth) {
		const wrapper = $('<div class="treeNode xmlNode"></div>').attr("data-path", path);

		const hasElementChildren = Array.from(node.childNodes || []).some(function (n) {
			return n.nodeType === 1;
		});
		const textChildren = Array.from(node.childNodes || []).filter(function (n) {
			return n.nodeType === 3 && n.nodeValue && n.nodeValue.trim() !== "";
		});

		const header = $('<div class="treeLine"></div>');
		const toggle = $('<span class="toggle"></span>');
		const label = $('<span class="treeLabel"></span>');
		const attrs = $('<span class="treeAttrs"></span>');

		if (hasElementChildren || textChildren.length > 0) {
			toggle.text("▾");
		} else {
			toggle.addClass("empty").text("•");
		}

		label.append('<span class="tag">&lt;' + escapeHtml(node.nodeName) + '&gt;</span>');

		if (node.attributes && node.attributes.length > 0) {
			for (let i = 0; i < node.attributes.length; i++) {
				const a = node.attributes[i];
				attrs.append(
					'<span class="attrPair"> ' +
					'<span class="attrName">' + escapeHtml(a.name) + '</span>' +
					'=<span class="attrValue">"' + escapeHtml(a.value) + '"</span>' +
					'</span>'
				);
			}
		}

		header.append(toggle).append(label).append(attrs);
		wrapper.append(header);

		const children = $('<div class="children"></div>');

		textChildren.forEach(function (tNode, idx) {
			const textVal = tNode.nodeValue.trim();
			const tRow = $('<div class="treeNode leaf xmlTextNode"></div>')
				.attr("data-path", path + "/text()[" + (idx + 1) + "]");
			const tLine = $('<div class="treeLine"></div>');
			tLine.append('<span class="toggle empty">•</span>');
			tLine.append('<span class="treeLabel xmlText textValue">' + escapeHtml(textVal) + '</span>');
			tRow.append(tLine);
			children.append(tRow);
		});

		Array.from(node.childNodes || []).forEach(function (child, idx) {
			if (child.nodeType === 1) {
				children.append(buildXmlNode(child, path + "/" + child.nodeName + "[" + (idx + 1) + "]", depth + 1));
			}
		});

		if (children.children().length > 0) {
			wrapper.append(children);
		} else {
			wrapper.addClass("leaf");
		}

		return wrapper;
	}

	function buildJsonNode(key, value, path, depth, context) {
        const node = $('<div class="treeNode jsonNode"></div>').attr("data-path", path);

        const line = $('<div class="treeLine"></div>');
        const toggle = $('<span class="toggle"></span>');
        const label = $('<span class="treeLabel"></span>');

        const isArray = Array.isArray(value);
        const isObject = value !== null && typeof value === "object" && !isArray;
        const isContainer = isArray || isObject;

        if (isContainer) {
            toggle.text("▾");
        } else {
            toggle.addClass("empty").text("•");
        }

        if (key !== "(root)") {
            label.append('<span class="jsonKey">' + escapeHtml(String(key)) + '</span><span class="colon">: </span>');
        }

        if (isArray) {
            label.append('<span class="jsonType">[ ]</span> <span class="jsonMeta">(' + value.length + ')</span>');
        } else if (isObject) {
            label.append('<span class="jsonType">{ }</span>');
        } else {
            label.append(formatJsonScalar(value));
            node.addClass("leaf");
        }

        line.append(toggle).append(label);
        node.append(line);

        const children = $('<div class="children"></div>');

        if (isArray) {
            value.forEach(function (item, idx) {
                children.append(buildJsonNode(idx, item, path + "[" + idx + "]", depth + 1, context));
            });
            node.append(children);
        } else if (isObject) {
            let localContext = context ? Object.assign({}, context) : {};

            if (Object.prototype.hasOwnProperty.call(value, "resourceType")) {
                localContext.resourceType = value.resourceType;
            }
            if (Object.prototype.hasOwnProperty.call(value, "id")) {
                localContext.resourceId = value.id;
            }

            if (value.resource && typeof value.resource === "object") {
                if (value.resource.resourceType) {
                    localContext.resourceType = value.resource.resourceType;
                }
                if (value.resource.id) {
                    localContext.resourceId = value.resource.id;
                }
            }

            if (Object.prototype.hasOwnProperty.call(value, "fullUrl")) {
                localContext.fullUrl = value.fullUrl;
            }

            if (localContext.resourceId) node.attr("data-resource-id", localContext.resourceId);
            if (localContext.fullUrl) node.attr("data-full-url", localContext.fullUrl);

            Object.keys(value).forEach(function (k) {
                children.append(buildJsonNode(k, value[k], path + "." + safePathKey(k), depth + 1, localContext));
            });

            if (children.children().length > 0) node.append(children);

            const summary = getJsonNodeSummary(path, value, localContext);
            if (summary) {
                const badges = $('<span class="resourceBadges"></span>');
                badges.append(
                    '<span class="badge resourceSummary">' +
                    escapeHtml(summary) +
                    '</span>'
                );
                label.append(badges);
            }
        }

        return node;
    }

    function getJsonNodeSummary(path, value, context) {
        if (!value || typeof value !== "object" || Array.isArray(value)) return "";

        const isBundleEntry = /\.entry\[\d+\]$/.test(path);
        const isEntryResource = /\.entry\[\d+\]\.resource$/.test(path);
        const isCoding = /\.coding\[\d+\]$/.test(path);
        const isCodeableConcept =
            Array.isArray(value.coding) &&
            !/\.coding\[\d+\]$/.test(path);

        if (isBundleEntry || isEntryResource) {
            return [
                context && context.resourceType ? context.resourceType : "",
                context && context.resourceId ? context.resourceId : ""
            ].filter(Boolean).join(" ");
        }

        if (isCoding) {
            const parts = [];
            if (value.code) parts.push(value.code);
            if (value.display) parts.push(value.display);
            if (!parts.length && value.system) parts.push(value.system);
            return parts.join(" | ");
        }

        if (isCodeableConcept) {
            const c = value.coding && value.coding.length ? value.coding[0] : null;
            if (c) {
                const parts = [];
                if (c.code) parts.push(c.code);
                if (c.display) parts.push(c.display);
                if (parts.length) return parts.join(" | ");
            }
            if (value.text) return value.text;
        }

        return "";
    }

    function getNodeSummaryBadge(path, value, context) {
        if (!value || typeof value !== "object" || Array.isArray(value)) return "";

        const isBundleEntry = /\.entry\[\d+\]$/.test(path);
        const isEntryResource = /\.entry\[\d+\]\.resource$/.test(path);

        if (isBundleEntry || isEntryResource) {
            const summary = [
                context && context.resourceType ? context.resourceType : "",
                context && context.resourceId ? context.resourceId : ""
            ].filter(Boolean).join(" ");
            return summary;
        }

        // Coding
        if (
            value.code !== undefined ||
            value.display !== undefined ||
            value.system !== undefined
        ) {
            const parts = [];
            if (value.code) parts.push(value.code);
            if (value.display) parts.push(value.display);
            if (!parts.length && value.system) parts.push(value.system);
            if (parts.length) return parts.join(" | ");
        }

        // CodeableConcept
        if (Array.isArray(value.coding) && value.coding.length > 0) {
            const c = value.coding[0] || {};
            const parts = [];
            if (c.code) parts.push(c.code);
            if (c.display) parts.push(c.display);
            if (parts.length) return parts.join(" | ");
        }
        if (value.text) return value.text;

        return "";
    }

	function formatJsonScalar(value) {
		if (value === null) return '<span class="jsonNull jsonLeaf">null</span>';
		if (typeof value === "string") return '<span class="jsonString jsonLeaf textValue">"' + escapeHtml(value) + '"</span>';
		if (typeof value === "number") return '<span class="jsonNumber jsonLeaf">' + escapeHtml(String(value)) + '</span>';
		if (typeof value === "boolean") return '<span class="jsonBool jsonLeaf">' + escapeHtml(String(value)) + '</span>';
		return '<span class="jsonLeaf">' + escapeHtml(String(value)) + '</span>';
	}

	function safePathKey(key) {
		return String(key).replace(/\./g, "\\.");
	}

	function indexBundleEntries(bundle) {
		if (!bundle || !Array.isArray(bundle.entry)) return;

		bundle.entry.forEach(function (entry, idx) {
			const path = "$.entry[" + idx + "]";
			const rid = entry && entry.resource && entry.resource.id ? String(entry.resource.id) : null;
			const furl = entry && entry.fullUrl ? String(entry.fullUrl) : null;

			if (rid) ViewerState.index.byResourceId[rid] = path;
			if (furl) ViewerState.index.byFullUrl[furl] = path;
		});
	}

	function applyDeepLinkFromUrl() {
		const params = new URLSearchParams(window.location.search);
		const resourceId = params.get("resourceId");
		const fullUrl = params.get("fullUrl");

		if (resourceId) {
			console.log("Deep link attempt for resourceId:", resourceId);
			console.log("Available resourceIds in index:", Object.keys(ViewerState.index.byResourceId));

			if (ViewerState.index.byResourceId[resourceId]) {
				openJsonPath(ViewerState.index.byResourceId[resourceId], { resourceId: resourceId });
				setStatus("Deep-linked by resource.id=" + resourceId);
				return;
			} else {
				console.warn("ResourceId not found in index:", resourceId);
				setStatus("ResourceId not found: " + resourceId);
			}
		}

		if (fullUrl) {
			if (ViewerState.index.byFullUrl[fullUrl]) {
				openJsonPath(ViewerState.index.byFullUrl[fullUrl], { fullUrl: fullUrl });
				setStatus("Deep-linked by fullUrl");
				return;
			}
		}
	}

	function openJsonPath(path, meta) {
		const root = $("#fhirTreeView");
        // Collapse all nodes first for a clean view
        root.find(".treeNode").addClass("collapsed");

        // Ensure root stays expanded
        root.children(".treeNode").removeClass("collapsed");

		const selector = '.jsonNode[data-path="' + cssEscape(path) + '"]';
		const target = root.find(selector).first();

		if (target.length === 0) return;

		$("#fhirPane .tabBtn").removeClass("active");
		$('.tabBtn[data-pane="fhir"][data-view="tree"]').addClass("active");
		$("#fhirPane .paneView").removeClass("active");
		$("#fhirTreeView").addClass("active");

		target.parents(".treeNode").removeClass("collapsed").each(function () {
            updateToggleGlyph($(this));
        });

        target.removeClass("collapsed");
        target.find(".treeNode").removeClass("collapsed");

        target.addBack().each(function () {
            updateToggleGlyph($(this));
        });

		const targetLabel = target.children(".treeLine").children(".treeLabel");
		$(".selectedNode").removeClass("selectedNode");
		targetLabel.addClass("selectedNode");

		if (meta && meta.resourceId) {
			target.attr("data-resource-id", meta.resourceId);
			ViewerState.selectedResourceId = meta.resourceId;
		}
		if (meta && meta.fullUrl) {
			target.attr("data-full-url", meta.fullUrl);
			ViewerState.selectedFullUrl = meta.fullUrl;
		}

		scrollNodeIntoPane(target[0]);
	}

    function scrollNodeIntoPane(nodeEl) {
        const paneBody = nodeEl.closest(".paneBody");
        if (!paneBody) return;

        const nodeRect = nodeEl.getBoundingClientRect();
        const paneRect = paneBody.getBoundingClientRect();

        const currentScroll = paneBody.scrollTop;
        // Scroll to put the node at the top of the pane (with a small offset for visibility)
        const topOffset = 20; // pixels from top
        const targetScroll = currentScroll + (nodeRect.top - paneRect.top) - topOffset;

        paneBody.scrollTo({
            top: Math.max(0, targetScroll),
            behavior: "smooth"
        });
    }

	function cssEscape(s) {
		return String(s).replace(/\\/g, "\\\\").replace(/"/g, '\\"');
	}

	function updateToggleGlyph(row) {
		const t = row.children(".treeLine").find("> .toggle");
		if (t.hasClass("empty")) return;
		t.text(row.hasClass("collapsed") ? "▸" : "▾");
	}

	window.expandAllVisible = function () {
		$(".paneView.active .treeNode").removeClass("collapsed");
		$(".paneView.active .toggle").each(function () {
			const row = $(this).closest(".treeNode");
			updateToggleGlyph(row);
		});
	};

	window.collapseAllVisible = function () {
		$(".paneView.active .treeNode").each(function () {
			const hasChildren = $(this).children(".children").length > 0;
			if (hasChildren) $(this).addClass("collapsed");
			updateToggleGlyph($(this));
		});
	};

	window.viewerSearch = function (term) {
		term = (term || "").trim();
		ViewerState.searchHits = [];
		ViewerState.currentHitIndex = -1;

		$(".searchHit").removeClass("searchHit");
		$("#currentFound").text("0");
		$("#totalFound").text("0");

		if (!term) return;

		const rx = new RegExp(escapeRegExp(term), "i");

		$("#sdaTreeView .treeLabel, #fhirTreeView .treeLabel, #sdaRawPre, #fhirRawText").each(function () {
			const el = $(this);

			if (el.is("textarea")) {
				return;
			}

			if (rx.test(el.text())) {
				el.addClass("searchHit");
				ViewerState.searchHits.push(el);
			}
		});

		$("#totalFound").text(String(ViewerState.searchHits.length));
		if (ViewerState.searchHits.length > 0) viewerNext();
	};

	window.clearSearch = function () {
		$("#searchTerm").val("");
		ViewerState.searchHits = [];
		ViewerState.currentHitIndex = -1;
		$(".searchHit, .currentHit").removeClass("searchHit currentHit");
		$("#currentFound").text("0");
		$("#totalFound").text("0");
	};

	window.viewerNext = function () {
		if (!ViewerState.searchHits.length) return;
		ViewerState.currentHitIndex++;
		if (ViewerState.currentHitIndex >= ViewerState.searchHits.length) ViewerState.currentHitIndex = 0;
		gotoCurrentHit();
	};

	window.viewerPrev = function () {
		if (!ViewerState.searchHits.length) return;
		ViewerState.currentHitIndex--;
		if (ViewerState.currentHitIndex < 0) ViewerState.currentHitIndex = ViewerState.searchHits.length - 1;
		gotoCurrentHit();
	};

    window.expandPane = function (pane) {
        var selector = pane === "sda" ? "#sdaPane .paneView.active .treeNode" : "#fhirPane .paneView.active .treeNode";
        $(selector).removeClass("collapsed");
        $(selector).each(function () {
            updateToggleGlyph($(this));
        });
    };

    window.collapsePane = function (pane) {
        var selector = pane === "sda" ? "#sdaPane .paneView.active .treeNode" : "#fhirPane .paneView.active .treeNode";
        $(selector).each(function () {
            var node = $(this);
            if (node.children(".children").length > 0) {
                node.addClass("collapsed");
            }
            updateToggleGlyph(node);
        });
    };

	function gotoCurrentHit() {
		$(".currentHit").removeClass("currentHit");

		const el = ViewerState.searchHits[ViewerState.currentHitIndex];
		if (!el || !el.length) return;

		el.addClass("currentHit");

		el.parents(".treeNode").removeClass("collapsed").each(function () {
			updateToggleGlyph($(this));
		});

		scrollNodeIntoPane(el[0]);
		$("#currentFound").text(String(ViewerState.currentHitIndex + 1));
	}

	function escapeRegExp(s) {
		return String(s).replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
	}

	function escapeHtml(s) {
		return $("<div/>").text(s == null ? "" : String(s)).html();
	}

	window.applyFhirRaw = function () {
		const txt = $("#fhirRawText").val();

		try {
			const parsed = JSON.parse(txt);
			const pretty = JSON.stringify(parsed, null, 2);

			setFhirData(pretty);

			ViewerState.fhirJsonRaw = pretty;
			ViewerState.fhirJsonObj = parsed;
			ViewerState.fhirDraftDirty = false;

			renderJsonPane(parsed);
			renderFhirRaw(pretty);
			applyDeepLinkFromUrl();

			setStatus("FHIR JSON draft applied to sessionStorage.");
		} catch (ex) {
			setStatus("Apply failed: invalid JSON - " + ex.message);
		}
	};

	window.resetFhirRaw = function () {
		renderFhirRaw(ViewerState.fhirJsonRaw);
		setStatus("FHIR raw draft reset.");
	};

	function dragElement(element) {
	const container = document.getElementById("container");
	if (!element || !container) return;

	element.addEventListener("mousedown", onMouseDown);

	function onMouseDown(e) {
		e.preventDefault();

		const rect = container.getBoundingClientRect();
		const sepWidth = element.getBoundingClientRect().width;

		function onMouseMove(ev) {
			const x = ev.clientX - rect.left;
			const minPane = 220;
			const maxLeft = rect.width - sepWidth - minPane;
			const left = Math.max(minPane, Math.min(x, maxLeft));
			const right = rect.width - left - sepWidth;

			container.style.gridTemplateColumns = left + "px " + sepWidth + "px " + right + "px";
		}

		function onMouseUp() {
			document.removeEventListener("mousemove", onMouseMove);
			document.removeEventListener("mouseup", onMouseUp);
			document.body.classList.remove("resizing");
		}

		document.body.classList.add("resizing");
		document.addEventListener("mousemove", onMouseMove);
		document.addEventListener("mouseup", onMouseUp);
	}
    }
 })();