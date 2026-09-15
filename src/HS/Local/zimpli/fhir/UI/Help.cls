/**
* User guide for zimpliFHIR — explains every tool and the end-to-end workflow
*
* @version 1.0 2026-07-15
* @author Brandon Thomas
*/

Class HS.Local.zimpli.fhir.UI.Help Extends HS.Local.zimpli.fhir.UI.Super
{

ClassMethod OnPage() As %Status
{
	&html<<!DOCTYPE html>
<html>
<head>
	<title>zimpliFHIR – User Guide</title>
	#(..MetaTags())#
	#(..DefaultStyle())#
	#(..LinkCSS("assets/Help.css"))#
</head>
<body>

<div id="pageShell">

	<!-- ── Header ── -->
	<div class="card pageHeader">
		<div class="logoRow">
			<svg class="logoMark" viewBox="0 0 48 48" xmlns="http://www.w3.org/2000/svg" aria-hidden="true">
				<defs>
					<linearGradient id="zfGradHelp" x1="0%" y1="0%" x2="100%" y2="100%">
						<stop offset="0%" stop-color="#333695"/>
						<stop offset="100%" stop-color="#44c7c2"/>
					</linearGradient>
				</defs>
				<circle cx="24" cy="24" r="4.2" fill="#333695"/>
				<circle cx="24" cy="8"  r="4" fill="url(#zfGradHelp)"/>
				<circle cx="37.9" cy="16" r="4" fill="url(#zfGradHelp)"/>
				<circle cx="37.9" cy="32" r="4" fill="url(#zfGradHelp)"/>
				<circle cx="24" cy="40" r="4" fill="url(#zfGradHelp)"/>
				<circle cx="10.1" cy="32" r="4" fill="url(#zfGradHelp)"/>
				<circle cx="10.1" cy="16" r="4" fill="url(#zfGradHelp)"/>
				<line x1="24"    y1="12.5" x2="24"    y2="19"   stroke="#94a3b8" stroke-width="2.4" stroke-linecap="round"/>
				<line x1="34.1"  y1="18.3" x2="27.8"  y2="21.8" stroke="#94a3b8" stroke-width="2.4" stroke-linecap="round"/>
				<line x1="34.1"  y1="29.7" x2="27.8"  y2="26.2" stroke="#94a3b8" stroke-width="2.4" stroke-linecap="round"/>
				<line x1="24"    y1="35.5" x2="24"    y2="29"   stroke="#94a3b8" stroke-width="2.4" stroke-linecap="round"/>
				<line x1="13.9"  y1="29.7" x2="20.2"  y2="26.2" stroke="#94a3b8" stroke-width="2.4" stroke-linecap="round"/>
				<line x1="13.9"  y1="18.3" x2="20.2"  y2="21.8" stroke="#94a3b8" stroke-width="2.4" stroke-linecap="round"/>
			</svg>
			<div>
				<h1 class="pageTitle">User Guide</h1>
				<div class="pageSubtitle">How to use every tool in zimpliFHIR</div>
			</div>
		</div>
	</div>

	<!-- ── Tab card ── -->
	<div class="card">

		<div class="tabBar">
			<button class="tabBtn active" onclick="showTab('overview',this)">Overview</button>
			<button class="tabBtn" onclick="showTab('datasource',this)">Datasource</button>
			<button class="tabBtn" onclick="showTab('inspector',this)">SDA &amp; FHIR Inspector</button>
			<button class="tabBtn" onclick="showTab('network',this)">FHIR Network</button>
			<button class="tabBtn" onclick="showTab('timeline',this)">Patient Journey</button>
			<button class="tabBtn" onclick="showTab('workbench',this)">FHIR Workbench</button>
			<button class="tabBtn" onclick="showTab('dtlviewer',this)">DTL Viewer</button>
			<button class="tabBtn" onclick="showTab('dtlmap',this)">DTL Map</button>
			<button class="tabBtn" onclick="showTab('findfiles',this)">Find in Files</button>
			<button class="tabBtn" onclick="showTab('importexport',this)">Import / Export</button>
			<button class="tabBtn" onclick="showTab('utilities',this)">Utilities</button>
			<button class="tabBtn" onclick="showTab('configuration',this)">Configuration</button>
		</div>

		<!-- ── OVERVIEW ── -->
		<div id="tab-overview" class="tabPanel active">
			<p>
				<b>zimpliFHIR</b> is a browser-based inspection and demonstration toolkit that runs
				inside InterSystems HealthShare as a CSP application. It lets you fetch patient
				data from the HealthShare ODS, visualise how that data was transformed through
				HL7v2 → SDA3 → FHIR pipelines, browse and validate the resulting FHIR resources,
				and trace the DTL classes responsible for every mapping decision.
			</p>

			<div class="sectionDivider"></div>

			<div class="subsection">
				<h2 class="sectionTitle">End-to-end workflow</h2>
				<p class="sectionSubtitle">Follow these steps to get the most out of the toolkit.</p>

				<ol class="stepList">
					<li>
						<span><b>Configure a Datasource</b> — enter the patient MRN or MPIID and
						choose a storage mode (session or local). The toolkit fetches the patient's
						SDA3 and FHIR bundle and keeps them in browser storage for every other page
						to use without making additional server requests.</span>
					</li>
					<li>
						<span><b>Inspect the data</b> — open <i>Compare SDA3 to FHIR</i> to see
						both representations side-by-side. Search, filter and drill into individual
						fields to understand exactly what was mapped and what was dropped.</span>
					</li>
					<li>
						<span><b>Explore relationships</b> — use <i>FHIR Relationship Graph</i> to
						see how resources reference each other as an interactive network. Click any
						node to read its raw JSON and trigger validation on the fly.</span>
					</li>
					<li>
						<span><b>Follow the patient journey</b> — switch to <i>Patient Journey</i>
						for a chronological timeline of encounters, observations, medications and
						other clinical events.</span>
					</li>
					<li>
						<span><b>Trace the transformation</b> — open <i>DTL Viewer</i> to read the
						ObjectScript source of any DTL class, then use <i>DTL Map</i> to visualise
						the complete call-chain between DTL classes and see which class handles each
						resource type.</span>
					</li>
					<li>
						<span><b>Search the codebase</b> — use <i>Find in Files</i> to locate any
						class, method or string across the active IRIS namespace.</span>
					</li>
				</ol>
			</div>

			<div class="sectionDivider"></div>

			<div class="subsection">
				<h2 class="sectionTitle">Navigation</h2>
				<p>
					The thin sidebar on the left edge of the screen is the main navigation. Each
					icon corresponds to a tool. Click an icon to load that tool in the main area.
					The currently active tool is highlighted. All tools share the same patient
					context — if you change the patient in Datasource the other pages will use
					the new data the next time they load.
				</p>
				<div class="tipBox">
					<strong>Tip</strong>
					The Patient button in the top-right header shows the active MPIID and provides
					a shortcut back to Datasource without navigating away from your current tool.
				</div>
			</div>

			<div class="subsection">
				<h2 class="sectionTitle">Data lifecycle</h2>
				<div class="flowDiagram">
					<div class="flowNode">HL7v2 ADT / ORU</div>
					<div class="flowArrow">→</div>
					<div class="flowNode">SDA3 (XML)</div>
					<div class="flowArrow">→</div>
					<div class="flowNode">FHIR Bundle (JSON)</div>
					<div class="flowArrow">→</div>
					<div class="flowNode">Browser storage</div>
					<div class="flowArrow">→</div>
					<div class="flowNode">zimpliFHIR views</div>
				</div>
				<p>
					Data is fetched once via the <code>StreamSDA</code> and <code>StreamFHIR</code>
					API endpoints and stored in <code>sessionStorage</code> (cleared when you close
					the tab) or <code>localStorage</code> (persists across sessions). Switching
					storage type in Datasource takes effect immediately.
				</p>
			</div>
		</div>

		<!-- ── DATASOURCE ── -->
		<div id="tab-datasource" class="tabPanel">
			<div class="subsection">
				<h2 class="sectionTitle">Configure Datasource</h2>
				<p class="sectionSubtitle">Fetch a patient record and manage browser storage.</p>
				<p>
					This is the starting point for every other tool. It retrieves the SDA3 XML and
					FHIR JSON bundles for a patient from the HealthShare ODS and places them in
					browser storage so they are available to every other page without repeated
					server calls.
				</p>
			</div>

			<div class="subsection">
				<h2 class="sectionTitle">Loading a patient</h2>
				<ol class="stepList">
					<li>
						<span>Enter the patient <b>MRN</b> or <b>MPIID</b> in the search box at
						the top of the page.</span>
					</li>
					<li>
						<span>Press <kbd>Enter</kbd> or click <b>Fetch</b>. The page contacts the
						HealthShare API and downloads both the SDA3 and FHIR representations of the
						patient's record.</span>
					</li>
					<li>
						<span>A preview of the FHIR bundle appears in the lower pane. You can
						expand and inspect the JSON directly here before moving to another
						tool.</span>
					</li>
				</ol>
				<div class="tipBox">
					<strong>Tip</strong>
					If the patient has no FHIR data yet, the FHIR pane will be empty but the SDA3
					pane will still show the raw clinical document. This is useful for diagnosing
					why the transformation did not run.
				</div>
			</div>

			<div class="subsection">
				<h2 class="sectionTitle">Storage modes</h2>
				<ul class="featureList">
					<li>
						<b>Session storage</b> — data is kept only for the current browser tab.
						Closing the tab clears the data. This is the default and is recommended for
						demonstrations where you do not want data to linger.
					</li>
					<li>
						<b>Local storage</b> — data persists until you explicitly clear it or call
						<i>Clear All</i>. Multiple patients can be cached simultaneously and
						selected from the patient list on the left side of the page.
					</li>
				</ul>
			</div>

			<div class="subsection">
				<h2 class="sectionTitle">Managing stored patients</h2>
				<p>
					The patient list on the left shows every MPIID currently in storage. Click an
					entry to switch context to that patient — all other tools will immediately use
					the selected patient's data. Use <b>Remove</b> next to any entry to delete
					that patient's data, or <b>Clear All</b> to wipe all stored data.
				</p>
			</div>
		</div>

		<!-- ── INSPECTOR ── -->
		<div id="tab-inspector" class="tabPanel">
			<div class="subsection">
				<h2 class="sectionTitle">Compare SDA3 to FHIR</h2>
				<p class="sectionSubtitle">Side-by-side inspection of the two representations of the same patient record.</p>
				<p>
					The Data Inspector places the raw SDA3 XML and the FHIR JSON bundle in two
					adjacent panes so you can compare them field by field. It is the primary tool
					for confirming that a DTL mapping produced the expected output, or for
					identifying fields that are present in SDA3 but absent from FHIR (or vice
					versa).
				</p>
			</div>

			<div class="subsection">
				<h2 class="sectionTitle">View modes</h2>
				<ul class="featureList">
					<li>
						<b>Tree view</b> — the document is rendered as a collapsible tree.
						Individual nodes can be expanded or collapsed. Click a node label to
						highlight all occurrences of that path across both panes.
					</li>
					<li>
						<b>Raw view</b> — shows the full pretty-printed source text. Use this when
						you need to copy a specific value or inspect an attribute that the tree
						view condenses.
					</li>
				</ul>
			</div>

			<div class="subsection">
				<h2 class="sectionTitle">Search and filter</h2>
				<p>
					Type in the search bar above either pane to filter the visible nodes in real
					time. The filter matches against element names and values. Clear the filter
					to restore the full tree. Both panes can be filtered independently, which is
					useful when an SDA3 field name differs from its FHIR equivalent.
				</p>
				<div class="tipBox">
					<strong>Tip</strong>
					Use the search to quickly locate a specific code value (e.g. a SNOMED or LOINC
					code) in the FHIR output and trace it back to the SDA3 source field in the
					left pane.
				</div>
			</div>
		</div>

		<!-- ── NETWORK ── -->
		<div id="tab-network" class="tabPanel">
			<div class="subsection">
				<h2 class="sectionTitle">FHIR Relationship Graph</h2>
				<p class="sectionSubtitle">Interactive network diagram of every resource in the patient's FHIR bundle.</p>
				<p>
					Each node in the graph represents one FHIR resource. Directed edges represent
					references — for example, an <code>Encounter</code> node will have edges
					pointing to its <code>Patient</code>, <code>Location</code>,
					<code>Organization</code> and any referenced <code>Condition</code> resources.
					The layout is force-directed: related resources cluster together automatically.
				</p>
			</div>

			<div class="subsection">
				<h2 class="sectionTitle">Exploring nodes</h2>
				<ol class="stepList">
					<li>
						<span><b>Click a node</b> to open the inspector drawer on the right. The
						drawer shows the full JSON of that resource, with syntax
						highlighting.</span>
					</li>
					<li>
						<span><b>Validate the resource</b> by clicking the <i>Validate</i> button
						inside the drawer. The toolkit sends the resource to the configured FHIR
						validator and surfaces any errors or warnings inline.</span>
					</li>
					<li>
						<span><b>Follow references</b> by clicking any reference value inside the
						drawer — the graph will pan and highlight the referenced node.</span>
					</li>
				</ol>
			</div>

			<div class="subsection">
				<h2 class="sectionTitle">Filtering the graph</h2>
				<p>
					Use the resource-type checkboxes in the toolbar to show or hide entire
					resource types. This is useful when a large bundle makes the graph hard to
					read — hiding <code>Observation</code> nodes, for example, can make the
					encounter structure much clearer.
				</p>
				<div class="tipBox">
					<strong>Tip</strong>
					Scroll to zoom in and out. Drag the background to pan. Drag individual nodes
					to reposition them — the physics engine will adjust the rest of the layout
					around your changes.
				</div>
			</div>

			<div class="subsection">
				<h2 class="sectionTitle">Validation integration</h2>
				<p>
					When validation is triggered, issues are rendered as coloured badges on the
					node: green for pass, amber for warnings, red for errors. Click a badged node
					to read the full list of validation messages in the drawer.
				</p>
			</div>
		</div>

		<!-- ── TIMELINE ── -->
		<div id="tab-timeline" class="tabPanel">
			<div class="subsection">
				<h2 class="sectionTitle">Patient Journey</h2>
				<p class="sectionSubtitle">A chronological timeline of clinical events derived from the patient's FHIR bundle.</p>
				<p>
					The Patient Journey page reads the FHIR bundle from storage and extracts all
					resources that carry a clinical date — encounters, observations, medication
					statements, conditions, procedures and diagnostic reports. These are placed on
					an interactive timeline ordered by their effective or recorded date.
				</p>
			</div>

			<div class="subsection">
				<h2 class="sectionTitle">Using the timeline</h2>
				<ul class="featureList">
					<li>
						<b>Scroll horizontally</b> to move along the time axis. Use the scroll
						wheel or drag the timeline background.
					</li>
					<li>
						<b>Zoom</b> by pinching on a trackpad or holding <kbd>Ctrl</kbd> and
						scrolling. The time scale adjusts from years down to individual hours.
					</li>
					<li>
						<b>Click any event</b> to open a details panel showing the full resource
						content and its FHIR type.
					</li>
					<li>
						<b>Filter by resource type</b> using the checkboxes above the timeline
						to focus on a single category such as encounters or medications.
					</li>
				</ul>
			</div>

			<div class="subsection">
				<h2 class="sectionTitle">Replay mode</h2>
				<p>
					Press <b>Play</b> in the toolbar to animate the timeline from the earliest to
					the most recent event. Each event lights up as the playhead passes it. This
					is useful in demonstrations to walk an audience through a patient's clinical
					history in chronological order.
				</p>
			</div>
		</div>

		<!-- ── WORKBENCH ── -->
		<div id="tab-workbench" class="tabPanel">
			<div class="subsection">
				<h2 class="sectionTitle">FHIR Workbench</h2>
				<p class="sectionSubtitle">Structured validation issue investigation for the active patient's FHIR bundle.</p>
				<p>
					The FHIR Workbench provides a more structured view of validation results than
					the inline badges in the FHIR Relationship Graph. It runs the full bundle
					through the FHIR validator and groups issues by resource type, severity and
					profile, making it easier to triage errors during development.
				</p>
			</div>

			<div class="subsection">
				<h2 class="sectionTitle">Reading the results</h2>
				<ul class="featureList">
					<li>
						<b>Errors</b> <span class="badge" style="background:#fee2e2;color:#b91c1c;">error</span>
						indicate that the resource violates the profile or the base FHIR
						specification. These must be resolved before the bundle will be accepted by
						a conformant server.
					</li>
					<li>
						<b>Warnings</b> <span class="badge amber">warning</span> flag issues that
						do not prevent processing but indicate missing recommended content or
						ambiguous values.
					</li>
					<li>
						<b>Information</b> <span class="badge green">info</span> messages are
						advisory — they highlight optional extensions or best-practice
						recommendations.
					</li>
				</ul>
			</div>

			<div class="subsection">
				<h2 class="sectionTitle">Acting on issues</h2>
				<p>
					Click on any issue row to see the full validation message, the FHIR path that
					caused it, and the profile constraint that was violated. Use the resource ID
					link to jump to that resource in the FHIR Relationship Graph for a full JSON
					inspection.
				</p>
				<div class="tipBox">
					<strong>Tip</strong>
					After fixing a mapping in a DTL class and recompiling, reload the patient from
					Datasource (which fetches fresh data from the server) then re-run the
					Workbench to confirm the issue is resolved.
				</div>
			</div>
		</div>

		<!-- ── DTL VIEWER ── -->
		<div id="tab-dtlviewer" class="tabPanel">
			<div class="subsection">
				<h2 class="sectionTitle">DTL Viewer</h2>
				<p class="sectionSubtitle">Browse and read the source of any DTL transformation class in the active namespace.</p>
				<p>
					The DTL Viewer lets you search for and read DTL (Data Transformation Language)
					classes without leaving the browser. It fetches the ObjectScript source from
					IRIS and renders it with full syntax highlighting, including colour-coded
					keywords, string literals, comments and COS-specific tokens.
				</p>
			</div>

			<div class="subsection">
				<h2 class="sectionTitle">Finding a class</h2>
				<ol class="stepList">
					<li>
						<span>Type part of the class name in the <b>Search</b> box. The results
						list updates as you type, showing all matching DTL classes in the current
						namespace.</span>
					</li>
					<li>
						<span>Click a result to load the full source into the viewer pane on the
						right.</span>
					</li>
					<li>
						<span>Use the <b>Filter by type</b> dropdown to narrow results to a
						specific resource type (e.g. only DTL classes that handle
						<code>Patient</code> resources).</span>
					</li>
				</ol>
			</div>

			<div class="subsection">
				<h2 class="sectionTitle">Reading the source</h2>
				<p>
					Line numbers are shown in the gutter. The viewer supports the full COS
					highlight grammar including ObjectScript macros, class keywords and embedded
					SQL. Use <kbd>Ctrl</kbd> + <kbd>F</kbd> in the viewer pane to search within
					the currently displayed class.
				</p>
				<div class="tipBox">
					<strong>Tip</strong>
					The <b>Export</b> button copies the current source to the clipboard so you
					can paste it into Studio or VS Code for editing.
				</div>
			</div>
		</div>

		<!-- ── DTL MAP ── -->
		<div id="tab-dtlmap" class="tabPanel">
			<div class="subsection">
				<h2 class="sectionTitle">DTL Map</h2>
				<p class="sectionSubtitle">Interactive call-chain graph showing how DTL classes invoke each other.</p>
				<p>
					Large interoperability implementations typically involve dozens of DTL classes
					that delegate to each other. The DTL Map builds a directed graph of these
					relationships — each node is a DTL class, and each edge represents a
					<code>TRANSFORM</code> or <code>CALL</code> invocation from one class to
					another. This makes it easy to understand the full transformation pipeline at
					a glance.
				</p>
			</div>

			<div class="subsection">
				<h2 class="sectionTitle">Navigating the map</h2>
				<ol class="stepList">
					<li>
						<span>The graph renders automatically when the page loads. Root classes —
						those that are not called by any other class — appear at the top of the
						hierarchy.</span>
					</li>
					<li>
						<span><b>Click a node</b> to open the inspector drawer showing the class
						metadata: display name, source type, target type, description, and a link
						to open the class in DTL Viewer.</span>
					</li>
					<li>
						<span><b>Expand sub-trees</b> by clicking the expand icon on any node.
						Leaf nodes are classes that do not call any further DTL classes.</span>
					</li>
					<li>
						<span>Use the <b>breadcrumb bar</b> at the top of the graph to track your
						navigation path and jump back to any ancestor node.</span>
					</li>
				</ol>
			</div>

			<div class="subsection">
				<h2 class="sectionTitle">Understanding node colours</h2>
				<ul class="featureList">
					<li><b>Dark blue</b> — root entry-point class (called from a production business process, not from another DTL).</li>
					<li><b>Teal</b> — intermediate class called by at least one other DTL.</li>
					<li><b>Light grey</b> — leaf class with no further outgoing calls.</li>
				</ul>
				<div class="tipBox">
					<strong>Tip</strong>
					If you are investigating a mapping bug, start from the root node for the
					relevant resource type and expand the tree until you reach the class that
					contains the failing field assignment.
				</div>
			</div>
		</div>

		<!-- ── FIND IN FILES ── -->
		<div id="tab-findfiles" class="tabPanel">
			<div class="subsection">
				<h2 class="sectionTitle">Find in Files</h2>
				<p class="sectionSubtitle">Full-text search across all classes in the active IRIS namespace.</p>
				<p>
					Find in Files sends a search string to the IRIS backend and returns a list of
					every class and line that contains a match. It is faster than opening Studio
					for a global search and works directly in the browser.
				</p>
			</div>

			<div class="subsection">
				<h2 class="sectionTitle">Running a search</h2>
				<ol class="stepList">
					<li>
						<span>Enter your search term in the <b>Search</b> box. The search is
						case-insensitive by default; tick <b>Case sensitive</b> to change
						this.</span>
					</li>
					<li>
						<span>Optionally restrict the search to a class name pattern using the
						<b>Class filter</b> box (e.g. <code>HS.Local.*</code>).</span>
					</li>
					<li>
						<span>Press <kbd>Enter</kbd> or click <b>Search</b>. Results appear in the
						table below, grouped by class name with the matching line shown in
						context.</span>
					</li>
					<li>
						<span>Click any result row to open that class in <b>DTL Viewer</b> at the
						matching line.</span>
					</li>
				</ol>
			</div>

			<div class="subsection">
				<h2 class="sectionTitle">Tips for effective searches</h2>
				<ul class="featureList">
					<li>
						Search for a LOINC or SNOMED code to find every DTL class that references
						that code — useful when auditing coverage or refactoring code tables.
					</li>
					<li>
						Search for a FHIR element name (e.g. <code>clinicalStatus</code>) to
						find every place it is set across all transformation classes.
					</li>
					<li>
						Use the class filter with a specific package prefix to scope a search to
						one project when multiple implementations share the same namespace.
					</li>
				</ul>
			</div>
		</div>

		<!-- ── IMPORT / EXPORT ── -->
		<div id="tab-importexport" class="tabPanel">
			<div class="subsection">
				<h2 class="sectionTitle">Import / Export</h2>
				<p class="sectionSubtitle">Bulk data operations — move FHIR and SDA3 data in and out of the system.</p>
				<p>
					The Import / Export page allows you to load test data into the browser or
					export the currently stored patient data to a file. It is primarily used
					for preparing reproducible demonstration scenarios without needing live
					patient records.
				</p>
			</div>

			<div class="subsection">
				<h2 class="sectionTitle">Importing data</h2>
				<ol class="stepList">
					<li>
						<span>Click <b>Import FHIR Bundle</b> (or <b>Import SDA3</b>) and select
						a <code>.json</code> (or <code>.xml</code>) file from your local
						machine.</span>
					</li>
					<li>
						<span>The data is parsed and validated to confirm it is a well-formed FHIR
						Bundle or SDA3 document.</span>
					</li>
					<li>
						<span>Provide an MPIID to associate the data with. The imported data is
						written to browser storage under that key and immediately available to all
						other tools.</span>
					</li>
				</ol>
			</div>

			<div class="subsection">
				<h2 class="sectionTitle">Exporting data</h2>
				<p>
					Click <b>Export FHIR</b> or <b>Export SDA3</b> to download the currently
					stored data for the active patient as a formatted file. Exported files can be
					shared with colleagues, used as test fixtures, or submitted to an external
					validator.
				</p>
				<div class="warnBox">
					<strong>Data handling note</strong>
					Exported files contain real patient data if the record was fetched from a
					live HealthShare instance. Handle them in accordance with your organisation's
					data governance policy.
				</div>
			</div>
		</div>

		<!-- ── UTILITIES ── -->
		<div id="tab-utilities" class="tabPanel">
			<div class="subsection">
				<h2 class="sectionTitle">Utilities</h2>
				<p class="sectionSubtitle">Small developer tools for common interoperability tasks.</p>
			</div>

			<div class="subsection">
				<h2 class="sectionTitle">Base64 Decoder / Encoder</h2>
				<p>
					FHIR <code>Binary</code> resources and attachment data elements store content
					as Base64-encoded strings. Paste a Base64 value into the input box and click
					<b>Decode</b> to see the raw text or binary content. The <b>Encode</b>
					direction is also available for constructing test payloads.
				</p>
				<ol class="stepList">
					<li><span>Paste a Base64 string into the <b>Input</b> field.</span></li>
					<li><span>Click <b>Decode</b>. The decoded output appears in the field below.</span></li>
					<li><span>If the decoded content is XML or JSON, click <b>Pretty print</b> to format it.</span></li>
				</ol>
			</div>

			<div class="subsection">
				<h2 class="sectionTitle">More tools</h2>
				<p>
					Additional utilities may be added to this page over time. The utilities page
					is designed to host lightweight one-off tools that do not warrant a dedicated
					page of their own.
				</p>
			</div>
		</div>

		<!-- ── CONFIGURATION ── -->
		<div id="tab-configuration" class="tabPanel">
			<div class="subsection">
				<h2 class="sectionTitle">Configuration</h2>
				<p class="sectionSubtitle">Manage gateway registrations, service connections and application preferences.</p>
				<p>
					The Configuration page is the administrative centre for the toolkit. It gives
					visibility into how zimpliFHIR connects to HealthShare services and allows
					those connections to be adjusted without editing ObjectScript.
				</p>
			</div>

			<div class="subsection">
				<h2 class="sectionTitle">Gateway registry</h2>
				<p>
					The gateway table lists every ODS / Flash gateway endpoint that the toolkit
					knows about. Each row shows the gateway type (<code>F</code> for Flash,
					<code>O</code> for ODS), the namespace it serves and the base URL.
					The <b>active</b> gateway is used by Datasource when fetching patient data.
				</p>
				<p>
					To switch the active gateway, click the row you want to use and confirm. The
					selected base URL is written to <code>sessionStorage</code> so it is available
					to all pages in the current session.
				</p>
			</div>

			<div class="subsection">
				<h2 class="sectionTitle">Federation graph</h2>
				<p>
					If your HealthShare deployment includes multiple facilities connected in a
					federation, the federation graph displays the topology as a network diagram.
					Each node is a facility and each edge represents a configured connection.
					This view is read-only and is intended for orientation and demonstration
					purposes.
				</p>
			</div>

			<div class="subsection">
				<h2 class="sectionTitle">Service registry</h2>
				<p>
					The service registry tab lists the production business services and operations
					that are registered in the current namespace. Use this to confirm that the
					correct FHIR and SDA3 services are running before fetching patient data.
				</p>
			</div>

			<div class="subsection">
				<h2 class="sectionTitle">Preferences</h2>
				<p>
					Application preferences — such as the default storage mode, the preferred
					validator endpoint, and UI density — are saved in <code>localStorage</code>
					and persist between sessions. Reset to defaults by clicking <b>Reset
					preferences</b> at the bottom of the preferences tab.
				</p>
			</div>
		</div>

	</div><!-- /.card -->

</div><!-- /#pageShell -->

<script type="text/javascript">
function showTab(id, btn) {
	document.querySelectorAll('.tabPanel').forEach(function(p) { p.classList.remove('active'); });
	document.querySelectorAll('.tabBtn').forEach(function(b) { b.classList.remove('active'); });
	document.getElementById('tab-' + id).classList.add('active');
	btn.classList.add('active');
}
</script>

</body>
</html>>

	return $$$OK
}

}
