/**
* Shows the full DTL call chain for a selected SDA3 resource type as a
* top-down vis-network hierarchy.
*
* Pick a resource type from the dropdown (Patient, Observation, …).
* The graph roots at the effective entry-point DTL — preferring the custom
* package (HS.Local.MII.FHIR.DTL) over the base — and fans downward through
* every subtransform it invokes, recursively.
*
* Node colour coding:
*   Blue   = entry point (registered in ^HS.XF.Transform)
*   Purple = subtransform from the custom package
*   Grey   = subtransform from HS.FHIR.DTL (base)
*   Amber  = referenced class with no DTL XData (external/utility)
*
* @version 3.0 2026-04-27
* @author Brandon Thomas
*/

Class HS.Local.zimpli.fhir.UI.DTLMap Extends HS.Local.zimpli.fhir.UI.Super
{

/* Customizable Parameters for Subclass ------------------------------------>*/
Parameter PageTitleDTLList = "DTL Transform Map";

/// SDA version key in ^HS.XF.Transform
Parameter SDAVersion = "SDA3";

/// FHIR version key in ^HS.XF.Transform
Parameter FHIRVersion = "vR4";

Parameter DisplayOrder = 98;

/// Default SDA source type shown on first load (no ?type= param).
/// Must match an entry in ^HS.XF.Transform for the configured SDA/FHIR versions.
Parameter DefaultSrcType = "HS.SDA3.Patient";

/*<------------------------------------ Customizable Parameters for Subclass */
Parameter SuperClass = "HS.Local.zimpli.fhir.UI.DTLViewer";

Parameter DTLViewerPage = "HS.Local.zimpli.fhir.UI.DTLViewer.cls";

// ---------------------------------------------------------------------------

// Page rendering

// ---------------------------------------------------------------------------

ClassMethod OnPage() As %Status
{
	// API: getCallers — scans all DTL classes and returns every class that calls pTargetClass
	if $get(%request.Data("action",1)) = "getCallers" {
		set %response.ContentType = "application/json; charset=utf-8"
		set tTargetClass = $get(%request.Data("dtlClass",1))
		set tCustomPkg   = ##class(HS.FHIR.DTL.Util.API.ExecDefinition).GetCustomDTLPackage()

		// Build entry-point set across both directions for classification
		kill tEntryPoints
		for tDirIdx = 1:1:2 {
			set tSV = $case(tDirIdx, 1:..#SDAVersion, :..#FHIRVersion)
			set tTV = $case(tDirIdx, 1:..#FHIRVersion, :..#SDAVersion)
			set tSrc = ""
			for {
				set tSrc = $order(^HS.XF.Transform(tSV, tTV, tSrc))
				quit:tSrc=""
				set tDTL = ""
				for {
					set tDTL = $order(^HS.XF.Transform(tSV, tTV, tSrc, tDTL))
					quit:tDTL=""
					set tEff = ..ResolveEffectiveDTL(tDTL)
					if tEff '= "" { set tEntryPoints(tEff) = 1 }
				}
			}
		}

		// Scan every DTL class in HS.FHIR.DTL and the custom package
		set tStmt = ##class(%SQL.Statement).%New()
		if tCustomPkg '= "" {
			set tSQL = "SELECT Name FROM %Dictionary.CompiledClass WHERE PrimarySuper LIKE '%Ens.DataTransformDTL%' AND (Name %STARTSWITH 'HS.FHIR.DTL.' OR Name %STARTSWITH ?)"
			$$$ThrowOnError(tStmt.%Prepare(tSQL))
			set tRS = tStmt.%Execute(tCustomPkg)
		} else {
			set tSQL = "SELECT Name FROM %Dictionary.CompiledClass WHERE PrimarySuper LIKE '%Ens.DataTransformDTL%' AND Name %STARTSWITH 'HS.FHIR.DTL.'"
			$$$ThrowOnError(tStmt.%Prepare(tSQL))
			set tRS = tStmt.%Execute()
		}

		set tCallers = ##class(%DynamicArray).%New()
		while tRS.%Next() {
			set tClass = tRS.%Get("Name")
			continue:(tClass = tTargetClass)
			do ..ExtractSubtransforms(tClass, .tSubList)
			continue:'$data(tSubList(tTargetClass))
			set tGroup = $case(1,
				$data(tEntryPoints(tClass)):"entrypoint",
				(tCustomPkg'="")&&($extract(tClass,1,$length(tCustomPkg))=tCustomPkg):"custom",
				:"base")
			set tCaller      = ##class(%DynamicObject).%New()
			set tCaller.cls  = tClass
			set tCaller.group = tGroup
			do tCallers.%Push(tCaller)
		}

		set tResult         = {}
		set tResult.ok      = 1
		set tResult.callers = tCallers
		write tResult.%ToJSON()
		return $$$OK
	}

	// API: getDTLXML — returns the raw DTL XData block as JSON
	if $get(%request.Data("action",1)) = "getDTLXML" {
		set %response.ContentType = "application/json; charset=utf-8"
		set tDTLClass  = $get(%request.Data("dtlClass",1))
		set tResult    = {}
		set tXDataDef  = ##class(%Dictionary.XDataDefinition).IDKEYOpen(tDTLClass, "DTL")
		if $isobject(tXDataDef) {
			set tResult.ok  = 1
			set tResult.xml = tXDataDef.Data.Read()
		} else {
			set tResult.ok    = 0
			set tResult.error = "DTL XData not found for: "_tDTLClass
		}
		write tResult.%ToJSON()
		return $$$OK
	}

	#dim tSuperClass = ..#SuperClass

	#dim tHighlightClass = $get(%request.Data("highlight",1))
	#dim tSelectedSrc    = $get(%request.Data("type",1))
	#dim tSrcVersion     As %String
	#dim tTgtVersion     As %String
	#dim tDir            As %String

	// Auto-detect direction from the highlight class name if present,
	// otherwise use the explicit ?dir= param, otherwise default to outbound.
	if tHighlightClass [ ".vR4.SDA3." {
		set tSrcVersion = ..#FHIRVersion
		set tTgtVersion = ..#SDAVersion
		set tDir        = "in"
	} elseif tHighlightClass [ ".SDA3.vR4." {
		set tSrcVersion = ..#SDAVersion
		set tTgtVersion = ..#FHIRVersion
		set tDir        = "out"
	} elseif $get(%request.Data("dir",1)) = "in" {
		set tSrcVersion = ..#FHIRVersion
		set tTgtVersion = ..#SDAVersion
		set tDir        = "in"
	} else {
		set tSrcVersion = ..#SDAVersion
		set tTgtVersion = ..#FHIRVersion
		set tDir        = "out"
	}

	// Collect all source types registered in the transform registry for this direction.
	// These drive the Resource dropdown — ^HS.XF.Transform is only used for this.
	kill tSrcClasses
	set tSrc = ""
	for {
		set tSrc = $order(^HS.XF.Transform(tSrcVersion, tTgtVersion, tSrc))
		quit:tSrc=""
		if $order(^HS.XF.Transform(tSrcVersion, tTgtVersion, tSrc, "")) '= "" {
			set tSrcClasses(tSrc) = 1
		}
	}

	// Resolve selected source type.
	// 1. Fast path: extract the resource segment from the class name marker.
	//    e.g. HS.Local.MII.FHIR.DTL.SDA3.vR4.QuestionnaireResponse.item.answer
	//         → marker ".SDA3.vR4." → root "QuestionnaireResponse" → HS.SDA3.QuestionnaireResponse
	// 2. Slow fallback: walk each registered source type's chain looking for the class.
	//    Only reached for deeply nested subtransforms whose resource segment doesn't
	//    map directly to a registered source type.
	if (tSelectedSrc="") || '$data(tSrcClasses(tSelectedSrc)) {
		if tHighlightClass '= "" {
			set tDirMarker  = $select(tDir="in": ".vR4.SDA3.", 1: ".SDA3.vR4.")
			set tSrcPrefix  = $select(tDir="in": "HS.FHIR.SDA3.", 1: "HS.SDA3.")
			set tMarkerPos  = $find(tHighlightClass, tDirMarker)
			if tMarkerPos > 0 {
				set tResourceRoot = $piece($extract(tHighlightClass, tMarkerPos, *), ".", 1)
				set tInferred = tSrcPrefix _ tResourceRoot
				if $data(tSrcClasses(tInferred)) {
					set tSelectedSrc = tInferred
				}
			}
			// Slow fallback: chain reachability scan
			if (tSelectedSrc="") || '$data(tSrcClasses(tSelectedSrc)) {
				set tSrc = $order(tSrcClasses(""))
				while tSrc '= "" {
					if ..ClassInChain(tSrc, tHighlightClass, tSrcVersion, tTgtVersion) {
						set tSelectedSrc = tSrc
						quit
					}
					set tSrc = $order(tSrcClasses(tSrc))
				}
			}
		}
		if (tSelectedSrc="") || '$data(tSrcClasses(tSelectedSrc)) {
			set tDefault = ..#DefaultSrcType
			if (tDefault '= "") && $data(tSrcClasses(tDefault)) {
				set tSelectedSrc = tDefault
			} else {
				set tSelectedSrc = $order(tSrcClasses(""))
			}
		}
	}

	&html<<!DOCTYPE html>
<html>
<head>
	<title>#(..#PageTitleDTLList)#</title>
	#(..MetaTags())#
	#(..LinkJS("assets/ext/jquery-3.7.1.min.js"))#
	#(..LinkJS("assets/ext/vis-network.min.js"))#
	#(..LinkCSS("assets/DTLMap.css"))#
</head>
<body>
<div id="pageShell">

	<div class="card pageHeader">
		<h1 class="pageTitle">#(..#PageTitleDTLList)#</h1>
	</div>

	<div class="card toolbarCard">
		<div class="toolbarGrid">

			<div class="fieldGroup">
				<label for="GroupPage">Page</label>
				<select id="GroupPage" onchange="openPage()">
>
			set tQuery(1) = "select parent->ID as ParentId from %Dictionary.CompiledParameter"
			set tQuery(2) = "where (parent->Super=? or parent->ID=?)"
			set tQuery(3) = "and Name='DisplayOrder'"
			set tQuery(4) = "order by _Default"
			set tQuery = 4
			set tStatement = ##class(%SQL.Statement).%New()
			$$$ThrowOnError(tStatement.%Prepare(.tQuery))
			set tRS = tStatement.%Execute(tSuperClass, tSuperClass)
			while tRS.%Next() {
				set tGroupOption = tRS.%Get("ParentId")
				set tSelected = $select((tGroupOption = $piece(%request.PageName,".cls")):" selected", 1:"")
				&html<<option value="#(tGroupOption)#"#(tSelected)#>#($parameter(tGroupOption, "PageTitleDTLList"))#</option>>
			}
			&html<</select>
			</div>

			<div class="fieldGroup">
				<label for="TypeSelect">SDA Type</label>
				<select id="TypeSelect" onchange="changeType()">
>
			set tSrc = $order(tSrcClasses(""))
			while tSrc '= "" {
				set tShort    = $piece(tSrc, ".", *)
				set tSelected = $select((tSrc = tSelectedSrc):" selected", 1:"")
				&html<<option value="#(tSrc)#"#(tSelected)#>#(tShort)#</option>>
				set tSrc = $order(tSrcClasses(tSrc))
			}
			&html<</select>
			</div>

			<div class="fieldGroup legendGroup">
				<span class="legendDot entrypoint"></span><span class="legendLabel">Entry</span>
				<span class="legendDot custom"></span><span class="legendLabel">Custom</span>
				<span class="legendDot base"></span><span class="legendLabel">Base</span>
				<span class="legendDot external"></span><span class="legendLabel">External</span>
			</div>
		</div>
	</div>

	<div class="card networkCard">
		<div id="NetworkZoomControls">
			<button type="button" id="ZoomInBtn"  title="Zoom in">+</button>
			<button type="button" id="ZoomOutBtn" title="Zoom out">&#8722;</button>
			<button type="button" id="ZoomFitBtn" title="Fit">&#9974;</button>
		</div>
		<div id="DrawerBackdrop"></div>
		<div id="VisNetworkPane"></div>
		<div id="DTLInspector" class="dtlInspector">
			<div id="DTLInspectorHeader">
				<div class="dtlInspectorActions">
					<button id="CloseDTLInspector" onclick="closeDTLInspector()">&#10005;</button>
					<button id="DTLViewerLink" onclick="window.open(this.dataset.href,'_blank')">&#8599; Full view</button>
					<button id="DTLEditorLink" onclick="window.open(this.dataset.href,'_blank')" disabled>&#9998; Edit</button>
					<button id="DTLXMLBtn" onclick="openDTLXMLOverlay()">&#60;/&#62; XML</button>
				</div>
				<div class="dtlInspectorParentRow">
					<span id="DTLInspectorGroup" class="nodeInfoGroup"></span>
					<div id="DTLInspectorParents"></div>
				</div>
			</div>
			<iframe id="DTLInspectorFrame" src="" frameborder="0"></iframe>
			<div id="DTLInspectorExternal" class="is-hidden">External utility &#x2014; no DTL XData</div>
		</div>
	</div>

	<div id="DTLXMLOverlay" class="dtlXmlOverlay is-hidden">
		<div class="dtlXmlOverlayHeader">
			<button onclick="closeDTLXMLOverlay()" class="dtlXmlCloseBtn">&#10005;</button>
			<span id="DTLXMLOverlayTitle" class="dtlXmlOverlayTitle"></span>
		</div>
		<div class="dtlXmlBody">
			<div style="margin-bottom:12px;">
				<button id="DTLXMLCopyBtn" onclick="copyDTLXML()" style="padding:8px 16px;background:#2563eb;color:#fff;border:none;border-radius:8px;cursor:pointer;font-size:13px;font-weight:500;">
					&#128203; Copy to Clipboard
				</button>
			</div>
			<pre id="DTLXMLContent" style="background:#1f2937;color:#f9fafb;padding:16px;border-radius:8px;overflow:auto;font-family:Consolas,monospace;font-size:12px;line-height:1.5;margin:0;"></pre>
		</div>
	</div>

</div>
<script type="text/javascript">
	var DTL_VIEWER_PAGE    = '#(..#DTLViewerPage)#';
	var HIGHLIGHT_CLASS    = '#(tHighlightClass)#';
	var MAP_DIR            = '#(tDir)#';
	var DTL_EDITOR_URL     = '#(##class(HS.Local.zimpli.fhir.API.InstanceProxy).GatewayBaseURL("F"))#EnsPortal.DTLEditor.zen';
	var DTL_EDITOR_NEW_URL = '#(##class(HS.Local.zimpli.fhir.API.InstanceProxy).GatewayBaseURL("F"))#ui/interop/dtl-editor/index.html';
	var DTL_EDITOR_NS      = '#(##class(HS.Local.zimpli.fhir.UI.DTLViewer).GetODSNamespace())#';
	var GRAPH_DATA = #(..GetTreeJSON(tSelectedSrc, tSrcVersion, tTgtVersion))#;
</script>
#(..LinkJS("assets/DTLMap.js"))#
</body>
</html>>

	return $$$OK
}

// ---------------------------------------------------------------------------

// Graph data builder

// ---------------------------------------------------------------------------

/// Builds vis-network { nodes, edges } JSON for the DTL chain rooted at
/// the registered entry-point(s) for pSrcClass (e.g. "HS.SDA3.Patient").
/// 
/// Node groups: "entrypoint" | "custom" | "base" | "external"
ClassMethod GetTreeJSON(pSrcClass As %String, pSrcVersion As %String = {..#SDAVersion}, pTgtVersion As %String = {..#FHIRVersion}) As %String
{
	set tCustomPkg = ##class(HS.FHIR.DTL.Util.API.ExecDefinition).GetCustomDTLPackage()

	kill tNodeGroup, tEdgeList, tVisited

	// --- 1. Entry points from the transform registry ---
	set tBaseDTL = ""
	for {
		set tBaseDTL = $order(^HS.XF.Transform(pSrcVersion, pTgtVersion, pSrcClass, tBaseDTL))
		quit:tBaseDTL=""

		set tEffective = ..ResolveEffectiveDTL(tBaseDTL)
		continue:tEffective=""

		if '$data(tNodeGroup(tEffective)) {
			set tNodeGroup(tEffective) = "entrypoint"
		}
	}

	// --- 2. Recursively trace subtransforms ---
	set tClass = $order(tNodeGroup(""))
	while tClass '= "" {
		do ..TraceSubtransforms(tClass, tCustomPkg, .tNodeGroup, .tEdgeList, .tVisited)
		set tClass = $order(tNodeGroup(tClass))
	}

	// --- 3. BFS to assign hierarchical levels (left = roots, right = leaves) ---
	// Standard BFS: first-visit wins (minimum depth).  Each node is enqueued
	// at most once, so shared subtransforms land as close to the root as
	// possible — keeps the total column count low.
	kill tLevel
	kill tQueue
	set tQHead = 1, tQTail = 0

	set tClass = $order(tNodeGroup(""))
	while tClass '= "" {
		if tNodeGroup(tClass) = "entrypoint" {
			set tLevel(tClass) = 0
			set tQTail = tQTail + 1
			set tQueue(tQTail) = tClass
		}
		set tClass = $order(tNodeGroup(tClass))
	}

	while tQHead <= tQTail {
		set tCurrent = tQueue(tQHead)
		set tQHead = tQHead + 1
		set tCurrentLevel = $get(tLevel(tCurrent), 0)
		set tNeighbour = $order(tEdgeList(tCurrent, ""))
		while tNeighbour '= "" {
			if '$data(tLevel(tNeighbour)) {
				set tLevel(tNeighbour) = tCurrentLevel + 1
				set tQTail = tQTail + 1
				set tQueue(tQTail) = tNeighbour
			}
			set tNeighbour = $order(tEdgeList(tCurrent, tNeighbour))
		}
	}

	// --- 4. Assemble JSON ---
	set tNodes = ##class(%DynamicArray).%New()
	set tEdges = ##class(%DynamicArray).%New()

	set tClass = $order(tNodeGroup(""))
	while tClass '= "" {
		set tNode       = ##class(%DynamicObject).%New()
		set tNode.id    = tClass
		set tNode.label = ..ShortLabel(tClass)
		set tNode.group = tNodeGroup(tClass)
		set tNode.title = tClass
		set tNode.level = $get(tLevel(tClass), 0)
		do tNodes.%Push(tNode)
		set tClass = $order(tNodeGroup(tClass))
	}

	set tFrom = $order(tEdgeList(""))
	while tFrom '= "" {
		set tTo = $order(tEdgeList(tFrom, ""))
		while tTo '= "" {
			set tEdge        = ##class(%DynamicObject).%New()
			set tEdge.from   = tFrom
			set tEdge.to     = tTo
			set tEdge.arrows = "to"
			do tEdges.%Push(tEdge)
			set tTo = $order(tEdgeList(tFrom, tTo))
		}
		set tFrom = $order(tEdgeList(tFrom))
	}

	set tResult       = ##class(%DynamicObject).%New()
	set tResult.nodes = tNodes
	set tResult.edges = tEdges
	return tResult.%ToJSON()
}

// ---------------------------------------------------------------------------

// Subtransform tracer

// ---------------------------------------------------------------------------

/// Recursively extracts subtransforms from pClass, classifies each target
/// node, and records directed edges.  pVisited prevents infinite loops.
/// 
/// Resolution rule — mirrors what the HS engine does at runtime:
///   Custom/entry node calls base → use the raw class name as written in the XML.
///     (The custom DTL is deliberately calling the base; resolving it again
///      would create a self-cycle back to the parent we just came from.)
///   Base node calls something → resolve to the effective (custom-override) class.
///     (The engine substitutes custom overrides at this level automatically.)
ClassMethod TraceSubtransforms(pClass As %String, pCustomPkg As %String, ByRef pNodeGroup, ByRef pEdgeList, ByRef pVisited)
{
	quit:$data(pVisited(pClass))
	set pVisited(pClass) = 1

	set tParentType = $get(pNodeGroup(pClass), "base")
	set tParentIsCustom = (tParentType = "entrypoint") || (tParentType = "custom")

	do ..ExtractSubtransforms(pClass, .tSubList)

	set tSub = $order(tSubList(""))
	while tSub '= "" {

		// Choose the edge target:
		//   custom/entry parent → keep raw class (intentional call to base)
		//   base parent        → resolve to effective override (runtime substitution)
		if tParentIsCustom {
			set tTarget = tSub
		} else {
			set tTarget = ..ResolveEffectiveDTL(tSub)
			set:tTarget="" tTarget = tSub
		}

		set pEdgeList(pClass, tTarget) = 1

		if '$data(pNodeGroup(tTarget)) {
			set tHasXML = $isobject(##class(%Dictionary.XDataDefinition).IDKEYOpen(tTarget, "DTL"))
			if 'tHasXML {
				set pNodeGroup(tTarget) = "external"
			} elseif (pCustomPkg '= "") && ($extract(tTarget, 1, $length(pCustomPkg)) = pCustomPkg) {
				set pNodeGroup(tTarget) = "custom"
			} else {
				set pNodeGroup(tTarget) = "base"
			}
		}

		if pNodeGroup(tTarget) '= "external" {
			do ..TraceSubtransforms(tTarget, pCustomPkg, .pNodeGroup, .pEdgeList, .pVisited)
		}

		set tSub = $order(tSubList(tSub))
	}
}

// ---------------------------------------------------------------------------

// Subtransform extraction

// ---------------------------------------------------------------------------

/// Scans the DTL XData block of pClass for all subtransform references:
/// 
///   1. <subtransform class='HS.FHIR.DTL...'/>
///      — declarative subtransform element, class in single-quoted attribute
/// 
///   2. .GetDTL(..., "HS.FHIR.DTL.SubXFrm...")
///      — dynamic dispatch via transformer.GetDTL(); class name is the second
///        argument, stored as &quot;ClassName&quot; inside a value='...' attribute
///        (XML entity-encoded because the outer attribute uses single quotes)
/// 
/// Populates pSubList(className) = 1 for each unique class found.
ClassMethod ExtractSubtransforms(pClass As %String, Output pSubList)
{
	kill pSubList

	#dim tXDataDef = ##class(%Dictionary.XDataDefinition).IDKEYOpen(pClass, "DTL")
	quit:'$isobject(tXDataDef)

	set tXML = tXDataDef.Data.Read()

	// --- Pattern 1: <subtransform class='ClassName' ...> ---
	set tPos = 1
	for {
		set tHit = $find(tXML, "<subtransform", tPos)
		quit:tHit=0

		set tEnd     = $find(tXML, ">", tHit)
		set tElement = $extract(tXML, tHit-1, tEnd)

		set tClassAttr = ..ExtractAttr(tElement, "class")
		if tClassAttr '= "" {
			set pSubList(tClassAttr) = 1
		}
		set tPos = tHit
	}

	// --- Pattern 2: GetDTL(source.Xxx, "ClassName") ---
	// The value='' attribute uses single quotes, so the inner double-quote chars
	// around the class name are stored literally in the XData — not as &quot;.
	// Anchor on "GetDTL(", skip to the comma, then extract the "..." second arg.
	set tPos = 1
	for {
		set tHit = $find(tXML, "GetDTL(", tPos)
		quit:tHit=0

		// Find the comma separating the two arguments
		set tComma = $find(tXML, ",", tHit)
		if tComma > 0 {
			// Find the opening double-quote of the class-name argument
			set tQOpen = $find(tXML, """", tComma)
			if tQOpen > 0 {
				// Find the closing double-quote
				set tQClose = $find(tXML, """", tQOpen)
				if tQClose > 0 {
					// tQOpen is the pos after the opening ", tQClose-2 is the last char before "
					set tClassName = $extract(tXML, tQOpen, tQClose-2)
					if tClassName '= "" {
						set pSubList(tClassName) = 1
					}
				}
			}
		}
		set tPos = tHit
	}
}

/// Extracts a single-quoted XML attribute value from an element text fragment.
ClassMethod ExtractAttr(pElementText As %String, pAttrName As %String) As %String
{
	set tStart = $find(pElementText, pAttrName_"='")
	quit:tStart=0 ""
	set tEnd = $find(pElementText, "'", tStart)
	quit:tEnd=0 ""
	quit $extract(pElementText, tStart, tEnd-2)
}

// ---------------------------------------------------------------------------

// Helpers

// ---------------------------------------------------------------------------

/// Returns the effective (custom-preferred) class for pDTL.
ClassMethod ResolveEffectiveDTL(pDTL As %String) As %String
{
	set tCustomPkg = ##class(HS.FHIR.DTL.Util.API.ExecDefinition).GetCustomDTLPackage()
	quit:tCustomPkg="" pDTL
	set tResolved = ##class(HS.FHIR.DTL.Util.API.ExecDefinition).GetDTLPackageAndClass(pDTL)
	quit:tResolved="" pDTL
	quit tResolved
}

/// Returns true if pTarget appears anywhere in the call chain rooted at the
/// entry points registered for pSrcClass.  Used to match a highlight class to
/// its owning source type without building the full vis-network JSON.
ClassMethod ClassInChain(pSrcClass As %String, pTarget As %String, pSrcVersion As %String = {..#SDAVersion}, pTgtVersion As %String = {..#FHIRVersion}) As %Boolean
{
	set tCustomPkg = ##class(HS.FHIR.DTL.Util.API.ExecDefinition).GetCustomDTLPackage()
	kill tVisited, tQueue
	set tQHead = 1, tQTail = 0

	// Seed queue with entry points for this source type
	set tBaseDTL = ""
	for {
		set tBaseDTL = $order(^HS.XF.Transform(pSrcVersion, pTgtVersion, pSrcClass, tBaseDTL))
		quit:tBaseDTL=""
		set tEffective = ..ResolveEffectiveDTL(tBaseDTL)
		continue:tEffective=""
		if '$data(tVisited(tEffective)) {
			set tVisited(tEffective) = 1
			set tQTail = tQTail + 1
			set tQueue(tQTail) = tEffective
		}
	}

	while (tQHead <= tQTail) && ($data(tVisited) < 300) {
		set tClass = tQueue(tQHead)
		set tQHead = tQHead + 1
		quit:tClass=pTarget  // found

		do ..ExtractSubtransforms(tClass, .tSubList)
		set tSub = $order(tSubList(""))
		while tSub '= "" {
			set tTarget = $select(
				(tCustomPkg '= "") && ($extract(tClass,1,$length(tCustomPkg)) = tCustomPkg): tSub,
				1: ..ResolveEffectiveDTL(tSub))
			set:tTarget="" tTarget = tSub
			if '$data(tVisited(tTarget)) {
				set tVisited(tTarget) = 1
				set tQTail = tQTail + 1
				set tQueue(tQTail) = tTarget
			}
			set tSub = $order(tSubList(tSub))
		}
	}

	quit $data(tVisited(pTarget))
}

/// Returns the last two dot-separated segments of a class name.
/// e.g. "HS.FHIR.DTL.SDA3.vR4.PatientNumbers.Identifier" -> "PatientNumbers.Identifier"
ClassMethod ShortLabel(pClass As %String) As %String
{
	set tParts = $length(pClass, ".")
	quit:tParts<2 pClass
	quit $piece(pClass, ".", tParts-1)_" "_$char(8594)_" "_$piece(pClass, ".", tParts)
}

}
