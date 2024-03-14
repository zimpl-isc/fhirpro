Class HS.Local.zimpl.fhirpro.UI.FHIRNetwork Extends HS.Local.zimpl.fhirpro.UI.Super
{

ClassMethod OnPage() As %Status
{
	
	&html<<!DOCTYPE html>
<html>
<head>
	<title>FHIR Bundle Visualizer</title>
	#(..LinkJS("jquery-3.7.1.min.js"))#
	#(..LinkJS("vis-network.min.js"))#
	#(..XDataJS("StorageHandler"))#
	
	<script type="text/javascript">
	    
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
	}

	function cleanSession() {
		edges.clear();
		nodes.clear();
		$('.unhideButton').remove();
	}
	
	function processEntry(entry) {
		//console.log(entry.resource.resourceType);
		var resourceId = entry.resource.resourceType+'/'+entry.resource.id;
		var resourceType = entry.resource.resourceType;
		var label = '<b>'+resourceType+'</b>';
		var display = '';
		
		if(typeof entry.resource.name!=='undefined') {
			display = entry.resource.name;
			
			if(typeof display==='object') {
				var prefix	= entry.resource.name[0].prefix || '';
				var given	= entry.resource.name[0].given || '';
				var family	= entry.resource.name[0].family || '';
				display = prefix +' '+ given.toString().replace(',',' ') +' '+ family;
			}
			
		} else if(typeof entry.resource.type!=='undefined') {
			if((typeof entry.resource.type==='object') && (typeof entry.resource.type.coding!=='undefined')) {
				display = entry.resource.type.coding[0].display || entry.resource.type.coding[0].code;
				
			} else if(Array.isArray(entry.resource.type)){
				display = entry.resource.type[0].coding[0].display || entry.resource.type[0].coding[0].code;
				console.log('typeof entry.resource.type for '+label+'= Array');
			}
			
		} else if(typeof entry.resource.code!=='undefined') {
			display = entry.resource.code.coding[0].display || entry.resource.code.coding[0].code;
	
		} else {
			display = entry.resource.status;
		}
		label = label +'\n'+ '<i>'+display+'</i>';
		
		
		createNode(resourceId, entry.resource.resourceType, label);
		console.log('createNode',resourceId, entry.resource.resourceType);
		fhirResource[resourceId] = entry.resource;
		traverse(entry.resource, entry.resource.resourceType, entry.resource.id);
	}

	function traverse(jsonObj, nodetype, nodeid, parent) {
		if( jsonObj !== null && typeof jsonObj == "object" ) {
			Object.entries(jsonObj).forEach(([key, value]) => {
				// key is either an array index or object key
				if(key=="reference"){
					createEdge(nodetype+'/'+nodeid, value, parent);
					console.log('createEdge',nodetype,nodeid,value,parent);
				}
				traverse(value, nodetype, nodeid, key);
			});
		}
		else {
			// jsonObj is a number or string
		}
	}
	function createNode(resourceId,resourceType,label) {
		let rscColor = color(resourceType);
		nodes.add({id:resourceId, label:label, title:resourceType, color:color(resourceType)});
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

	function createEdge(from,to,label) {
		edges.add({from:from, to:to, label:'<i>'+label+'</i>'});
	}
	function createUnhideButton(fhirResourceId) {
		var button = document.createElement('button');
		button.innerText='unhide '+fhirResourceId;
		button.setAttribute('fhirresourceid',fhirResourceId);
		button.setAttribute('id','unhide'+fhirResourceId);
		button.setAttribute('class','unhideButton');
		button.onclick=function() {
			nodes.add({id:this.getAttribute('fhirresourceid'), label:this.getAttribute('fhirresourceid').split('/')[0]});
			document.getElementById('unhide'+fhirResourceId).remove()
		};
		document.getElementById('HiddenResourceTray').appendChild(button);
	}
	function focusInspector(nodeId) {
		document.getElementById('resourceJSON').innerText = JSON.stringify(fhirResource[nodeId], null, 4);
		document.getElementById('HideResourceButton').setAttribute('fhirresourceid', nodeId);
		$("#VisNetworkPane").animate({width:"59%"});
		$("#ResourceInspector").show('fast');
		$("#ResourceInspector").animate({width:"39%"});
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
	function fetchFhir(flocation) {
		let headers = new Headers();
		headers.set('Authorization', 'Basic ' + btoa('_system' + ":" + 'SYS'));

		fetch(flocation, {
			method:'GET',
			headers: headers})
		.then(response => response.json())
		.then(data => {
			document.getElementById('BundleText').value = JSON.stringify(data);
			parse();
		})
		.catch(error => console.error(error))
	}
	//$(document).ready(function()
	window.addEventListener("load", () => {
		$('#Loading').toggle(true)
		//console.log('document ready');
		
		fhirResource = new Array();
		
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
					iterations: 1000,
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
			canvasWidth = network.canvas.frame.clientWidth;
			canvasHeight = network.canvas.frame.clientHeight;
			maxOffsetLeft = (canvasWidth / 3);
			maxOffsetRight = (canvasWidth / -3);
			maxOffsetUp = (canvasHeight / 3);
			maxOffsetDown = (canvasHeight / -3);

			pos = network.getViewPosition();
			currScale = network.getScale();
			//console.log('zoom','scale:',network.getScale(),'pos:',network.getViewPosition());
			
			// Limit scale and position
			network.moveTo({
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

	<style type="text/css">
		html,body,#VizualizerPanel {height:100%; width:100%; font-family:Helvetica, Arial, sans-serif;}
		#VisNetworkPane,#ResourceInspector {display:inline-block;}
		#ResourceInspector {overflow:auto; border-left:1px silver dashed; height:90%; background-color:whitesmoke;}
		#VisNetworkPane {vertical-align:top; width:100%; height:100%;}
		#ConfigureBundleControl span {padding:0.5em; background:linear-gradient(180deg, rgba(164,226,222,1) 0%, rgba(214,255,253,1) 100%); cursor:pointer;}
		#ConfigureBundlePane {padding:1em; background:rgba(214,255,253,1); width:fit-content;}
		#BundleText {width:800px; height:20em;}
		.nodeLabel {font-weight:bolder}
		.nodeType {font-size:smaller}
		#Loading {
			width: 100%;
			height: 100%;
			background: #ffffffde;
			position: absolute;
			z-index: 100;
		}
		#Loading img {
			margin-left: calc(50vw - 60px);
			width: 60px;
			margin-top: calc(50vh - 60px);
		}
	</style>
</head>
<body>
  	<div id="VizualizerPanel">
  		<div id="HiddenResourceTray"></div>
  		<div id="VisNetworkPane"></div>
  		<div id="ResourceInspector">
  			<button id="HideResourceButton" 
  					onclick="nodes.remove({id:this.getAttribute('fhirresourceid')}); 
  							createUnhideButton(this.getAttribute('fhirresourceid'));
  							unfocusInspector();">
  				hide this resource on map
			</button>
		    <pre id="resourceJSON"></pre>
  		</div>
  	</div>
</body>
</html>>

	return $$$OK
}

}
