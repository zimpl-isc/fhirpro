/**
* Displays a network visualization of FHIR data.
*
* @version 1.5 2024-09-01
* @author Brandon Thomas
*/

Class HS.Local.zimpl.fhirpro.UI.FHIRNetwork Extends HS.Local.zimpl.fhirpro.UI.Super
{

ClassMethod OnPage() As %Status
{
	
	&html<<!DOCTYPE html>
<html>
<head>
	<title>FHIR Bundle Visualizer</title>
	#(..MetaTags())#
	#(..LinkJS("jquery-3.7.1.min.js"))#
	#(..LinkJS("vis-network.min.js"))#
	#(..XDataJS("StorageHandler"))#
	#(..LinkJS("highlight.min.js"))#
	#(..LinkJS("highlightjs-line-numbers.min.js"))#
	#(..LinkCSS("highlight.min.css"))#
	#(..DefaultStyle())#

<style type="text/css">
html,body,#VizualizerPanel {
    height:100%;
     width:100%;
     font-family:Helvetica, Arial, sans-serif;
}
 #VisNetworkPane,#ResourceInspector {
    display:inline-block;
}
 #ResourceInspector {
    overflow:auto;
    border-left:1px solid #333896;
    background: linear-gradient(42deg, #cfddddc7, #ffffffc7);
  	backdrop-filter: blur(3px);
	position: fixed;
	top: 0;
	right: 0;
	height: 100vh;
}
.hljs {
	background: none !important;
}
pre, code {
	padding-top: 0;
	margin-top: 0;
}
 #VisNetworkPane {
    vertical-align:top;
     width:100vw;
     height:100vh;
}
 .nodeLabel {
    font-weight:bolder
}
 .nodeType {
    font-size:smaller
}
 #resourceTypeControls ul {
     list-style-type: none;
     padding: 0px;
     margin: 0 0.5em 0 1em;
}
 #resourceTypeControls li {
     text-align: right;
}
 .typeCount {
     padding-left: 0.5em;
     color: #868282;
}
 fieldset.infoBox {
     position: absolute;
     z-index: 999;
}
</style>

<script type="text/javascript">
	let resourceTypesHidden = new Object();
	let resourceTypes = new Object(); // createNode() updates a count,  updateTypeControls() draws a control

	function parse() {	
		
		let tMpiid = getMpiid();
		if (tMpiid == "") {
			console.log("No MPIID found in current session. Search for a patient first.");
			return
		}

		let tFHIR = getFhirData();
		if (tFHIR == "") {
			console.log("No FHIR data found in localStorage. Search for a patient first.");
			return
		}

		unfocusInspector();
		cleanSession();
		
		bundle=JSON.parse(tFHIR);
		bundle.entry.forEach(processEntry);
		bundle.entry.forEach(processReferences);
		

		// sort the list of resourceTypes and draw the control
		resourceTypes = Object.fromEntries(Object.entries(resourceTypes).sort());
		for (let key in resourceTypes) {
			updateTypeControls(key, resourceTypes[key]);
		}
	}

	function cleanSession() {
		edges.clear();
		nodes.clear();
		$('.unhideButton').remove();
	}
	
	function processEntry(entry) {
		console.log('processEntry:'+entry.resource.resourceType);
		const rsc = entry.resource;
		const resourceType = rsc.resourceType;

		if (resourceType === "OperationOutcome") {
			console.log('<OperationOutcome> Missing some data? ',JSON.stringify(entry));
			return
		}

		if (rsc.id===undefined) {
			console.log(entry);
			rsc.id = entry.fullUrl.split('/')[1] || entry.fullUrl //  is a urn //.split(':')[2];
			entry.resource.id = rsc.id;
			fhirResourceUrnUuids[rsc.id] = resourceType;
			console.log('generating missing resource.id for ',entry);
		}

		if (entry.fullUrl.split(':')[0]==="urn") {
			fhirResourceUrnUuids[rsc.id] = resourceType;
			console.log('handling urn:uuid type ids for ',entry);
		}

		const resourceId = resourceType+'/'+rsc.id;
		
		let title = resourceType;
		let display = '';
		let label = '<b>'+resourceType+'</b>';

		if(resourceType === 'Condition') {
			display = rsc.code.coding[0].code + ' ' + rsc.code.coding[0].display.substr(0,50)+'...';
			title = rsc.code.coding[0].display;

		} else if(resourceType === 'Observation') {
			display = rsc.code.coding[0].code.substr(0,10) + ' ' + rsc.code.coding[0].display.substr(0,50)+'...';
			title = rsc.code.coding[0].display;

		} else if(resourceType === 'Procedure') {
			display = rsc.code.coding[0].code + ' ' + rsc.code.coding[0].display.substr(0,50)+'...';
			title = rsc.code.coding[0].display;

		} else if(resourceType === 'Encounter') {
			display = rsc.identifier[0].value;

		} else if((resourceType === 'Patient') ||(resourceType === 'Practitioner')) {
			display = rsc.name;
			
			if(typeof display==='object') {
				var prefix	= rsc.name[0].prefix || '';
				var given	= rsc.name[0].given  || '';
				var family	= rsc.name[0].family || '';
				display = prefix +' '+ given.toString().replace(',',' ') +' '+ family;
			}

		} else if(resourceType === 'Organization') {
			display = rsc.name || rsc.type[0].coding[0].display || rsc.identifier[0].value;

		} else if(resourceType === 'Location') {
			display = rsc.physicalType.coding[0].display + ' ' + rsc.identifier[0].value;
			title = rsc.physicalType.coding[0].display;

		} else if(typeof rsc.type!=='undefined') {
			if((typeof rsc.type==='object') && (typeof rsc.type.coding!=='undefined')) {
				display = rsc.type.coding[0].display || rsc.type.coding[0].code;
				
			} else if(Array.isArray(rsc.type)) {
				display = rsc.type[0].coding[0].display || rsc.type[0].coding[0].code;
				console.log('typeof rsc.type for '+label+'= Array');
			}
			
		} else if(typeof rsc.code!=='undefined') {
			display = rsc.code.coding[0].display || rsc.code.coding[0].code;
	
		} else {
			display = rsc.status;
		}
		label = label +'\n'+ '<i>'+display+'</i>';
		
		createNode(resourceId, resourceType, label, title);
		console.log('createNode', resourceId, resourceType);
		fhirResource[resourceId] = entry;
	}

	function processReferences(entry) {
		const rsc = entry.resource;
		const resourceType = rsc.resourceType;
		traverse(rsc, resourceType, rsc.id);
	}
	
	function traverse(jsonObj, nodetype, nodeid, parent) {
		if((jsonObj !== null) && (typeof jsonObj == "object")) {
			Object.entries(jsonObj).forEach(([key, value]) => {
				// key is either an array index or object key
				if(key=="reference"){
					// if the id is a urn:uuid, lookup the resourceType and add it to the id (value)
					if (value.split(':')[0]==="urn") {
						console.log('urn ref value:'+value);
						value = value.split(':')[2];
						value = fhirResourceUrnUuids[value]+'/'+value;
						console.log('urn ref value:'+value);
					}
					
					createEdge(nodetype+'/'+nodeid, value, parent);
					console.log('createEdge(',nodetype+'/'+nodeid, value, parent,')');
				}
				traverse(value, nodetype, nodeid, key);
			});
		}
		else {
			// do nothing, jsonObj is a number or string
		}
	}
	function createNode(resourceId,resourceType,label,title) {
		nodes.add({id:resourceId, label:label, title:title, color:color(resourceType)});
		
		// Create a count for each resourceType
		resourceTypes[resourceType] = parseInt(resourceTypes[resourceType] || 0) + 1; 
	}

	function createEdge(from,to,label) {
		edges.add({from:from, to:to, label:'<i>'+label+'</i>'});
	}

	function updateTypeControls(resourceType, resourceCount = 1) {
		$('#resourceTypeControls ul').append(
			$('<li>').attr('id','TypeControl'+resourceType)
				.append($('<span>').text(resourceType))
				.append($('<span>').text(resourceCount)
					.attr({
						id		: 'TypeCount'+resourceType,
						class	: 'typeCount'}))
				.append($('<input>')
					.attr({
						type	: 'checkbox',
						checked	: true,
						ref		: resourceType})
					.on('click', function(){
									toggleResourceType(this.getAttribute('ref'))
								}
					)
				)
		);
	}

	function color(rscType) {
		if (typeof colors==='undefined') {
			console.log('generating color palette');
			
			colors = new Array();
	
			/** Palette https://codepen.io/chorijan/pen/azVzPO **/
			colors['Patient']			= '#48CFAD'; // mint
			colors['Location']			= '#A0CECB'; // teal
			colors['Organization']		= '#FFCE54'; // sunflower
			colors['Encounter']			= '#A0D468'; // grass
			colors['DiagnosticReport']	= '#8067B7'; // plum
			colors['ServiceRequest']	= '#AC92EC'; // lavender
			colors['Observation']		= '#4FC1E9'; // aqua
			colors['Specimen']			= '#F5F7FA'; // light gray
			colors['MedicationStatement']= '#D8334A'; // ruby
			colors['Medication']		= '#ED5565'; // grapefruit
			colors['Practitioner']		= '#5D9CEC'; // blue jeans
			colors['DocumentReference']	= '#E8CE4D'; // straw
			colors['Substance']			= '#FC6E51'; // bittersweet
			colors['Composition']		= '#EC87C0'; // pink rose
		}
		
		return colors[rscType]
	}

	function createUnhideButton(fhirResourceId) {
		$('#HiddenResourceTray').append(
			$('<input/>').attr({
							type	: 'button',
							id		: 'unhide'+fhirResourceId,
							ref		: fhirResourceId,
							class	: 'unhideButton',
							value	: 'unhide '+fhirResourceId})
						.on('click', function() {
							console.log(this);
							processEntry(fhirResource[this.getAttribute('ref')]);
							document.getElementById('unhide'+fhirResourceId).remove();
						}));
	}
	function toggleResourceType(resourceType) {
		if (resourceTypesHidden[resourceType] === undefined) {
			hideResourceType(resourceType);
		} else {
			unhideResourceType(resourceType);
		}
	}
	function hideResourceType(resourceType)	{
		resourceTypesHidden[resourceType] = new Array();

		nodes.getDataSet().forEach((obj)=>{
			if (obj.id.includes(resourceType+'/')){
				resourceTypesHidden[resourceType].push(obj);
				nodes.remove(obj.id)
				}
			}
		);
	}
	function unhideResourceType(resourceType) {
		resourceTypesHidden[resourceType].forEach((obj)=>{
			nodes.add(obj);
		});
		delete resourceTypesHidden[resourceType];
	}
	function focusInspector(nodeId) {
		console.log(nodeId);
		$('#resourceJSON').text(JSON.stringify(fhirResource[nodeId], null, 4));
		$('#resourceJSON').attr('data-highlighted',''); // resets lib
		hljs.highlightAll();
		hljs.initLineNumbersOnLoad();
		$('#HideResourceButton').attr('ref', nodeId);
		//$("#VisNetworkPane").animate({width:"59%"});
		$("#ResourceInspector").show('fast');
		$("#ResourceInspector").animate({width:"72%"},800);
		network.moveTo({scale:2.5,});
		network.focus(nodeId);
	}
	function unfocusInspector() {
		//console.log('unfocusInspector');
		$("#ResourceInspector").hide('fast');
		$("#VisNetworkPane").animate({width:"100%"});
		network.moveTo({
			position: {x:0, y:0},
			scale: 1
		});
		network.fit();
		network.stopSimulation();
	}
	window.addEventListener("load", () => {
		fhirResource = new Array();
		fhirResourceUrnUuids = new Object();
		
		// create an array with nodes
		nodes = new vis.DataSet();

		// create an array with edges
		edges = new vis.DataSet();

		// create a network
		container = document.getElementById("VisNetworkPane");
		data = {
			nodes: nodes,
			edges: edges,
		};
		options = {
			nodes: {
				shape:'box',
				font: {
    			    multi: 'html'
				}
			},
			edges: {
				arrows:{to:true},
				font: {
    			    multi: 'html',
    			    ital: {
						color: 'silver',
						size: 12, // px
						face: 'arial',
						vadjust: 0,
						mod: 'italic',
					}
				}
			},
			physics: {
				forceAtlas2Based: {
					gravitationalConstant: -26,
					centralGravity: 0.005,
					springLength: 230,
					springConstant: 0.18,
				},
				maxVelocity: 50,
				solver: "forceAtlas2Based",
				timestep: 0.15,
				stabilization: {
					enabled: true,
					iterations: 10,
					updateInterval: 25,
				},
			},
			/*physics: {
				/*springLength and springConstant*
				repulsion: {
					centralGravity: 0.2,
					springLength: 400,
					springConstant: 1.05,
					nodeDistance: 200,
					damping: 0.09
				},
				stabilization: {
					enabled: true,
					iterations: 20,
					updateInterval: 100,
					onlyDynamicEdges: false,
					fit: true
			    },
			    barnesHut: {
					springConstant: 0.05,
					avoidOverlap: 0.3
				}
			}*/
			
		};
		network = new vis.Network(container, data, options);

		network.on('click', function (event, properties, senderId) {
			//console.log('onclick',event);
			if(event.nodes[0] === undefined) {
				unfocusInspector();
			} else {
				focusInspector(event.nodes[0]);
			}
		});
		
		
		network.on("zoom",function(){
			minScale = 0.5;
			maxScale = 2;
			canvasWidth = this.canvas.frame.clientWidth;
			canvasHeight = this.canvas.frame.clientHeight;
			maxOffsetLeft = (canvasWidth / 3);
			maxOffsetRight = (canvasWidth / -3);
			maxOffsetUp = (canvasHeight / 3);
			maxOffsetDown = (canvasHeight / -3);

			pos = this.getViewPosition();
			currScale = this.getScale();
			//console.log('zoom','scale:',network.getScale(),'pos:',network.getViewPosition());
			
			// Limit scale and position
			this.moveTo({
				position: {
						x:(pos.x < maxOffsetRight) ? maxOffsetRight
							: (pos.x > maxOffsetLeft) ? maxOffsetLeft 
							: pos.x,
						y:(pos.y < maxOffsetDown) ? maxOffsetDown
							: (pos.x > maxOffsetUp) ? maxOffsetUp
							: pos.x
				}, 
				scale:(currScale < minScale ) ? minScale
						: (currScale > maxScale ) ? maxScale
						: currScale
				});
		});
		
		$("#ResourceInspector").hide('fast');
		parse();
	});
	</script>
</head>
<body>
  	<div id="VizualizerPanel">
		<fieldset class="infoBox" id="resourceTypeControls">
    		<legend>resource types</legend>
			<ul></ul>
		</fieldset>

  		<div id="HiddenResourceTray"></div>
  		<div id="VisNetworkPane"></div>
  		<div id="ResourceInspector">
  			<button id="HideResourceButton" 
  					onclick="nodes.remove({id:this.getAttribute('ref')}); 
  							createUnhideButton(this.getAttribute('ref'));
  							unfocusInspector();">
  				hide this resource on map
			</button>
		    <pre><code id="resourceJSON" class='language-json' autocomplete="off" readonly placeholder="FHIR Data..."></code></pre>
  		</div>
  	</div>
</body>
</html>>

	return $$$OK
}

}
