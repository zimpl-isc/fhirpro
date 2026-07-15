/**
* Import and Export tool for InterSystems IRIS
* Uses the Atelier REST API (/api/atelier/v7+) for multi-instance support.
* Server-side relay methods handle writing files to the local IRIS filesystem.
*
* @version 1.0 2026-06-26
* @author Brandon Thomas
*/

Class HS.Local.zimpli.fhir.UI.ImportExport Extends HS.Local.zimpli.fhir.UI.Super
{

ClassMethod OnPage() As %Status
{
	&html<<!DOCTYPE html>
<html>
<head>
	<title>Import / Export</title>
	#(..MetaTags())#
	#(..LinkJS("assets/ext/jquery-3.7.1.min.js"))#
	#(..LinkJS("assets/ImportExport.js"))#
	#(..DefaultStyle())#
	#(..LinkCSS("assets/ImportExport.css"))#
</head>
<body>
<div id="pageShell">

	<!-- Host / Auth bar -->
	<div class="card hostCard">
		<div class="hostGrid">
			<div class="fieldGroup">
				<label for="host">Host</label>
				<input id="host" type="text" placeholder="http://localhost:52773">
			</div>
			<div class="fieldGroup">
				<label for="username">Username</label>
				<input id="username" type="text" value="_system">
			</div>
			<div class="fieldGroup">
				<label for="password">Password</label>
				<input id="password" type="password" value="SYS">
			</div>
			<div class="fieldGroup">
				<label for="namespace">Namespace</label>
				<div class="nsRow">
					<select id="namespace"></select>
					<button class="iconButton" id="refreshNs" title="Refresh namespaces" onclick="loadNamespaces()">
						<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"><polyline points="23 4 23 10 17 10"/><polyline points="1 20 1 14 7 14"/><path d="M3.51 9a9 9 0 0114.85-3.36L23 10M1 14l4.64 4.36A9 9 0 0020.49 15"/></svg>
					</button>
					<span id="hostStatus" class="hostStatus"></span>
				</div>
			</div>
		</div>
	</div>

	<!-- Tab bar -->
	<div class="tabBar">
		<button class="tabBtn active" id="tab-import" onclick="switchTab('import')">&#8659; Import</button>
		<button class="tabBtn" id="tab-export" onclick="switchTab('export')">&#8657; Export</button>
	</div>

	<!-- ═══ IMPORT PANEL ═══ -->
	<div id="panel-import" class="tabPanel">

		<div class="card toolbarCard">
			<div class="sectionLabel">Source</div>
			<div class="radioRow">
				<label><input type="radio" name="importSource" value="server" checked onchange="importSourceChanged()"> Server path</label>
				<label><input type="radio" name="importSource" value="upload" onchange="importSourceChanged()"> Upload from browser</label>
			</div>

			<div id="importServerPath" class="sourceBlock">
				<div class="inlineRow">
					<input id="importPath" type="text" placeholder="/mgr/import/MyClasses.xml  or  /mgr/import/">
					<button class="secondaryButton" onclick="listImportPath()">Preview</button>
				</div>
				<div class="checkboxRow" style="margin-top:8px">
					<input type="checkbox" id="importRecurse">
					<label for="importRecurse">Recurse into subdirectories</label>
				</div>
			</div>

			<div id="importUpload" class="sourceBlock" style="display:none">
				<input type="file" id="importFiles" multiple accept=".xml,.cls,.mac,.int,.inc,.ro">
				<span class="comment">XML export files or individual UDL source files</span>
			</div>
		</div>

		<div class="splitPane">
			<div class="card treeCard" id="importTreeCard" style="display:none">
				<div class="treeHeader">
					<span class="sectionLabel" id="importTreeTitle">Items to import</span>
					<span class="treeActions">
						<a href="#" onclick="treeSelectAll('import'); return false">All</a> /
						<a href="#" onclick="treeSelectNone('import'); return false">None</a>
					</span>
				</div>
				<div id="importTree" class="treeRoot"></div>
			</div>

			<div class="card optionsCard" id="importOptionsCard" style="display:none">
				<div class="sectionLabel">Options</div>

				<div class="fieldGroup" style="margin-bottom:12px">
					<label for="importTarget">Target namespace</label>
					<select id="importTarget"></select>
				</div>

				<div class="checkboxRow" style="margin-bottom:8px">
					<input type="checkbox" id="importCompile" checked onchange="toggleCompileFlags()">
					<label for="importCompile">Compile after import</label>
				</div>

				<div id="compileFlagBlock">
					<div class="sectionLabel" style="margin-top:10px">Compile flags</div>
					<div class="flagGrid">
						<label title="Compile only classes that are out of date"><input type="checkbox" class="cflag" value="u" checked> <b>u</b> Out-of-date only</label>
						<label title="Keep source after compile"><input type="checkbox" class="cflag" value="k" checked> <b>k</b> Keep source</label>
						<label title="Run in background job"><input type="checkbox" class="cflag" value="b"> <b>b</b> Background</label>
						<label title="Recurse — compile dependencies too"><input type="checkbox" class="cflag" value="r"> <b>r</b> Recursive</label>
						<label title="Display errors only, suppress info"><input type="checkbox" class="cflag" value="e"> <b>e</b> Errors only</label>
						<label title="Display verbose detail"><input type="checkbox" class="cflag" value="d"> <b>d</b> Verbose</label>
					</div>
				</div>

				<button class="primaryButton runButton" id="importRunBtn" onclick="runImport()" disabled>Import</button>
			</div>
		</div>

		<div class="card statusCard" id="importStatusCard" style="display:none">
			<div class="statusHeader">
				<span class="sectionLabel">Status</span>
				<button class="iconButton" title="Clear" onclick="clearStatus('import')">&#x2715;</button>
			</div>
			<pre id="importStatus" class="statusPre"></pre>
		</div>
	</div>

	<!-- ═══ EXPORT PANEL ═══ -->
	<div id="panel-export" class="tabPanel" style="display:none">

		<div class="card toolbarCard">
			<div class="sectionLabel">Filters</div>
			<div class="filterGrid">
				<div class="fieldGroup">
					<label for="exportPattern">Name pattern</label>
					<input id="exportPattern" type="text" placeholder="HS.Local.*.cls">
				</div>
				<div class="fieldGroup">
					<label for="exportFrom">Modified from</label>
					<input id="exportFrom" type="date">
				</div>
				<div class="fieldGroup">
					<label for="exportTo">Modified to</label>
					<input id="exportTo" type="date">
				</div>
				<div class="fieldGroup">
					<label>&nbsp;</label>
					<button class="primaryButton" onclick="searchExport()">Search</button>
				</div>
			</div>
			<div class="optionsRow">
				<div class="checkboxRow">
					<input type="checkbox" id="expSys">
					<label for="expSys">System items</label>
				</div>
				<div class="checkboxRow">
					<input type="checkbox" id="expGen">
					<label for="expGen">Generated items</label>
				</div>
				<div class="checkboxRow">
					<input type="checkbox" id="expMapped" checked>
					<label for="expMapped">Mapped items</label>
				</div>
			</div>
		</div>

		<div class="splitPane">
			<div class="card treeCard" id="exportTreeCard" style="display:none">
				<div class="treeHeader">
					<span class="sectionLabel" id="exportTreeTitle">Items to export</span>
					<span class="treeActions">
						<a href="#" onclick="treeSelectAll('export'); return false">All</a> /
						<a href="#" onclick="treeSelectNone('export'); return false">None</a>
					</span>
				</div>
				<div id="exportTree" class="treeRoot"></div>
			</div>

			<div class="card optionsCard" id="exportOptionsCard" style="display:none">
				<div class="sectionLabel">Export options</div>

				<div class="radioGroup" style="margin-bottom:12px">
					<div class="sectionLabel" style="margin-bottom:4px">Destination</div>
					<label><input type="radio" name="exportDest" value="server" checked onchange="exportDestChanged()"> Server path</label>
					<label><input type="radio" name="exportDest" value="browser" onchange="exportDestChanged()"> Download to browser</label>
				</div>

				<div class="radioGroup" style="margin-bottom:12px">
					<div class="sectionLabel" style="margin-bottom:4px">Format</div>
					<label><input type="radio" name="exportFormat" value="xml" checked onchange="exportFormatChanged()"> XML bundle</label>
					<label><input type="radio" name="exportFormat" value="udl" onchange="exportFormatChanged()"> Individual UDL files</label>
				</div>

				<div id="exportServerPathBlock" class="fieldGroup" style="margin-bottom:12px">
					<label for="exportPath">Server path</label>
					<input id="exportPath" type="text">
				</div>

				<div id="exportUdlDirBlock" class="fieldGroup" style="margin-bottom:12px; display:none">
					<label for="exportUdlDir">UDL directory</label>
					<input id="exportUdlDir" type="text">
					<div class="checkboxRow" style="margin-top:6px">
						<input type="checkbox" id="exportSubdirs" checked>
						<label for="exportSubdirs">Package subdirectories (VSCode-friendly)</label>
					</div>
				</div>

				<button class="primaryButton runButton" id="exportRunBtn" onclick="runExport()" disabled>Export</button>
			</div>
		</div>

		<div class="card statusCard" id="exportStatusCard" style="display:none">
			<div class="statusHeader">
				<span class="sectionLabel">Status</span>
				<button class="iconButton" title="Clear" onclick="clearStatus('export')">&#x2715;</button>
			</div>
			<pre id="exportStatus" class="statusPre"></pre>
		</div>
	</div>

</div>
</body>
</html>>

	return $$$OK
}

// ─────────────────────────────────────────────────────────────────

// SERVER-SIDE RELAY ENDPOINTS

// Called from browser via fetch to this same .cls page with ?action=

// ─────────────────────────────────────────────────────────────────

/// Dispatcher for relay actions
ClassMethod OnPreHTTP() As %Boolean
{
	set action = $get(%request.Data("action",1))
	if action = "" quit 1  // normal OnPage render

	set %response.ContentType = "application/json"
	set %response.CharSet = "utf-8"

	if action = "writeXml"    { do ..RelayWriteXml()    quit 0 }
	if action = "writeUdl"    { do ..RelayWriteUdl()    quit 0 }
	if action = "uploadTemp"  { do ..RelayUploadTemp()  quit 0 }
	if action = "listTemp"    { do ..RelayListTemp()    quit 0 }
	if action = "loadTemp"    { do ..RelayLoadTemp()    quit 0 }
	quit 1
}

/// Receives XML lines from browser (result of Atelier xml/export) and writes to server path.
/// POST ?action=writeXml  body: { "path": "/mgr/...", "lines": ["<?xml...", ...] }
ClassMethod RelayWriteXml()
{
	try {
		set body = {}.%FromJSON(%request.Content)
		set path = body.path
		set lines = body.lines

		set file = ##class(%FileCharacterStream).%New()
		set file.Filename = path
		set file.TranslateTable = "UTF8"

		set iter = lines.%GetIterator()
		while iter.%GetNext(.k, .line) {
			do file.WriteLine(line)
		}
		set sc = file.%Save()

		if $$$ISOK(sc) {
			write {"ok":true,"path":(path)}.%ToJSON()
		} else {
			write {"ok":false,"error":($system.Status.GetErrorText(sc))}.%ToJSON()
		}
	} catch ex {
		write {"ok":false,"error":(ex.DisplayString())}.%ToJSON()
	}
}

/// Receives the XML file content as JSON: { "filename": "...", "content": "<?xml..." }
/// Saves to /mgr/Temp/zimpliImport_<ts>_<filename> and returns { "ok": true, "path": "..." }.
ClassMethod RelayUploadTemp()
{
	try {
		set body     = {}.%FromJSON(%request.Content)
		set origName = body.filename
		set content  = body.content
		if origName = "" { set origName = "upload.xml" }
		set safeBase = ##class(%File).GetFilename(origName)
		set tempPath = "/mgr/Temp/zimpliImport_" _ $translate($horolog, ",", "_") _ "_" _ safeBase

		set file = ##class(%FileCharacterStream).%New()
		set file.Filename = tempPath

		do file.Write(content)
		set sc = file.%Save()
		if $$$ISOK(sc) {
			write {"ok":true,"path":(tempPath)}.%ToJSON()
		} else {
			write {"ok":false,"error":($system.Status.GetErrorText(sc))}.%ToJSON()
		}
	} catch ex {
		write {"ok":false,"error":(ex.DisplayString())}.%ToJSON()
	}
}

/// List documents in a server-side temp file without sending file content over the wire.
/// POST ?action=listTemp&ns=HSCUSTOM  body: { "path": "/mgr/Temp/..." }
/// Returns { "ok": true, "documents": [{ "name": "...", "tsCurrent": "..." }, ...] }
/// tsCurrent = timestamp of the document currently in the target namespace, "" if not present
ClassMethod RelayListTemp()
{
	try {
		set body = {}.%FromJSON(%request.Content)
		set path = body.path
		set tNs  = $get(%request.Data("ns", 1))

		set tStrm = ##class(%Stream.FileCharacter).%New()
		set tStrm.Filename = path

		kill tDocList
		set tSC = $SYSTEM.OBJ.LoadStream(tStrm, "/nodisplay", , .tDocList, 1)
		if $$$ISERR(tSC) {
			write {"ok":false,"error":($system.Status.GetErrorText(tSC))}.%ToJSON()
			quit
		}

		// Switch to target namespace to look up current timestamps
		set tOrigNs = $namespace
		if (tNs '= "") && (tNs '= tOrigNs) {
			znspace tNs
		}

		set docs = []
		set tDoc = $order(tDocList(""))
		while tDoc '= "" {
			set tsCurrent = ##class(%RoutineMgr).GetDate(tDoc)
			// GetDate returns -1 for documents that do not exist in the namespace
			if tsCurrent = -1 { set tsCurrent = "" }
			do docs.%Push({"name":(tDoc),"tsCurrent":(tsCurrent)})
			set tDoc = $order(tDocList(tDoc))
		}

		znspace tOrigNs
		write {"ok":true,"documents":(docs)}.%ToJSON()
	} catch ex {
		write {"ok":false,"error":(ex.DisplayString())}.%ToJSON()
	}
}

/// Load selected documents from a server-side temp file into the target namespace.
/// POST ?action=loadTemp&ns=HSCUSTOM  (flags omitted = load only, no compile)
/// POST ?action=loadTemp&ns=HSCUSTOM&flags=cuk  (load + compile with flags)
/// body: { "path": "/mgr/Temp/...", "selected": ["Foo.Bar.cls", ...] }
/// Returns { "ok": true, "imported": [...] }
ClassMethod RelayLoadTemp()
{
	try {
		set body    = {}.%FromJSON(%request.Content)
		set path    = body.path
		set selArr  = body.selected
		set tNs     = $get(%request.Data("ns", 1))
		set tFlags  = $get(%request.Data("flags", 1), "")

		// Switch to the requested namespace if specified
		if tNs '= "" {
			set tSC = ##class(%SYS.Namespace).Exists(tNs, .exists)
			if exists {
				znspace tNs
			}
		}

		// Build the selected list
		kill tSelectedList
		set iter = selArr.%GetIterator()
		while iter.%GetNext(.k, .name) {
			set tSelectedList(name) = ""
		}

		set tStrm = ##class(%Stream.FileCharacter).%New()
		set tStrm.Filename = path

		kill tImportedList, tErrorLog
		set tSC = $SYSTEM.OBJ.LoadStream(tStrm, tFlags, .tErrorLog, .tImportedList, , .tSelectedList, path)

		set imported = []
		set tDoc = $order(tImportedList(""))
		while tDoc '= "" {
			do imported.%Push(tDoc)
			set tDoc = $order(tImportedList(tDoc))
		}

		// Collect per-item errors from errorlog array.
		// LoadStream populates errorlog as errorlog(name, n) = errortext.
		set errors = []
		set tName = $order(tErrorLog(""))
		while tName '= "" {
			set tN = $order(tErrorLog(tName, ""))
			while tN '= "" {
				do errors.%Push(tName _ ": " _ tErrorLog(tName, tN))
				set tN = $order(tErrorLog(tName, tN))
			}
			set tName = $order(tErrorLog(tName))
		}

		if $$$ISOK(tSC) {
			write {"ok":true,"imported":(imported),"errors":(errors)}.%ToJSON()
		} else {
			write {"ok":false,"error":($system.Status.GetErrorText(tSC)),"imported":(imported),"errors":(errors)}.%ToJSON()
		}
	} catch ex {
		write {"ok":false,"error":(ex.DisplayString()),"imported":[]}.%ToJSON()
	}
}

/// Receives a single UDL document (result of Atelier GET /doc) and writes to server path.
/// POST ?action=writeUdl  body: { "dir": "/mgr/...", "name": "Pkg.Sub.Class.cls", "subdirs": true, "lines": [...] }
ClassMethod RelayWriteUdl()
{
	try {
		set body = {}.%FromJSON(%request.Content)
		set dir = body.dir
		set name = body.name
		set subdirs = body.subdirs
		set lines = body.lines

		// Build file path
		if subdirs {
			// e.g. Pkg.Sub.Class.cls  -> Pkg/Sub/Class.cls
			set parts = $listfromstring(name, ".")
			set ext = $list(parts, *)
			set pathParts = ""
			for i=1:1:$listlength(parts)-1 {
				set pathParts = pathParts _ $list(parts,i) _ "/"
			}
			set relPath = pathParts _ $list(parts,$listlength(parts)-1) _ "." _ ext
			// Actually name already has .cls etc as last piece - redo:
			set nameNoExt = $piece(name,".",1,*-1)
			set ext = $piece(name,".",*)
			set relPath = $translate(nameNoExt,".","/"_$char(0))  // temp trick
			set relPath = $translate(relPath,$char(0),"/")
			set relPath = relPath _ "." _ ext
		} else {
			set relPath = name
		}

		// Ensure dir ends with /
		if $extract(dir,*) '= "/" set dir = dir _ "/"
		set fullPath = dir _ relPath

		// Create parent directory
		set parentDir = ##class(%File).GetDirectory(fullPath)
		do ##class(%File).CreateDirectoryChain(parentDir)

		set file = ##class(%FileCharacterStream).%New()
		set file.Filename = fullPath
		set file.TranslateTable = "UTF8"

		set iter = lines.%GetIterator()
		while iter.%GetNext(.k, .line) {
			do file.WriteLine(line)
		}
		set sc = file.%Save()

		if $$$ISOK(sc) {
			write {"ok":true,"path":(fullPath)}.%ToJSON()
		} else {
			write {"ok":false,"error":($system.Status.GetErrorText(sc))}.%ToJSON()
		}
	} catch ex {
		write {"ok":false,"error":(ex.DisplayString())}.%ToJSON()
	}
}

}
