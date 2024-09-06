/**
* Displays a timeline visualization of FHIR data.
*
* @version 1.0 2024-03-27
* @author Brandon Thomas
*/

Class HS.Local.zimpl.fhirpro.UI.FHIRTimeline Extends HS.Local.zimpl.fhirpro.UI.Super
{

ClassMethod OnPage() As %Status
{
	&html<<!DOCTYPE HTML>
<html>
<head>
  <title>HSFHIRToolkit | FHIR timeline</title>
  	#(..MetaTags())#
	#(..LinkJS("jquery-3.7.1.min.js"))#
	#(..XDataJS("StorageHandler"))#
	#(..LinkJS("vis-timeline-graph2d.min.js"))#
	#(..LinkCSS("vis-timeline-graph2d.min.css"))#
	#(..DefaultStyle())#

  <style type="text/css">
.hint {
	font-style: italic;
	color: #adadad;
	padding-left: 2em;
}
#visualization, #patientData {
	visibility: hidden;
}
.vis-panel.vis-left {
	background-color: #f7f7f7;
	background-image: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' width='4' height='4' viewBox='0 0 4 4'%3E%3Cpath fill='%23d5ddf6' fill-opacity='0.7' d='M1 3h1v1H1V3zm2-2h1v1H3V1z'%3E%3C/path%3E%3C/svg%3E");
}
    #patientData h3 {
	color: gray;
	margin: 0;
	font-weight: lighter;
	font-style: italic;
}
	#PatientName {
		text-shadow: 0.1px 0.1px 1px gray;
		font-weight: lighter;
		margin: 0 0 0.5em;
	}
	#buttonRefit {
		float: right;
	}
	#visualization {
		background-color: white;
		}
	/* backgrounds for groups --disabled for now -- */
	.Encounters {xbackground-color:#A0D468;}
	.Conditions {xbackground-color:white;}
	.Procedures {xbackground-color:white;}
	.Observations {xbackground-color:#4FC1E9;}
	.Medications {xbackground-color:#ED5565;}
	.Vaccinations {xbackground-color:white;}
	
	fieldset.infoBox {
		min-width: 20%;
		padding-left: 2.5em;
	}
  </style>
  
</head>
<body>

<fieldset class="infoBox" id="patientData">
    <legend>patient</legend>
	<svg id="buttonRefit" fill="#9c9c9c" height="20px" width="20px" version="1.1" id="Capa_1" xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" 
	 viewBox="0 0 489.533 489.533" xml:space="preserve">
		<g><path d="M268.175,488.161c98.2-11,176.9-89.5,188.1-187.7c14.7-128.4-85.1-237.7-210.2-239.1v-57.6c0-3.2-4-4.9-6.7-2.9
				l-118.6,87.1c-2,1.5-2,4.4,0,5.9l118.6,87.1c2.7,2,6.7,0.2,6.7-2.9v-57.5c87.9,1.4,158.3,76.2,152.3,165.6
				c-5.1,76.9-67.8,139.3-144.7,144.2c-81.5,5.2-150.8-53-163.2-130c-2.3-14.3-14.8-24.7-29.2-24.7c-17.9,0-31.9,15.9-29.1,33.6
				C49.575,418.961,150.875,501.261,268.175,488.161z"/></g>
		</svg>
	<h2 id="PatientName" />
	<h3 id="PatientDemogs" />
	<h3 id="PatientIds" />
</fieldset>

<div class="hint">details in browser console</div>
<div id="visualization"></div>

<script type="text/javascript">

    $(document).ready(function() {
        parse();
    });

// Create a DataSet (allows two way data-binding)
// https://visjs.github.io/vis-timeline/docs/timeline/
	var timeline = new vis.Timeline(document.getElementById('visualization'));
	
	// Configuration for the Timeline
	var options = {
		// option groupOrder can be a property name or a sort function
		// the sort function must compare two groups and return a value
		//     > 0 when a > b
		//     < 0 when a < b
		//       0 when a == b
		order: function (a,b) {
			return b.id - a.id
		},
		groupOrder: function (a, b) {
			return a.value - b.value;
		},
		align: 'left',
		editable: false,
		configure: false, //displays configurable options on the webpage
		locale: 'de',
		min:'2010-01-01',
		max:'2030-12-31',
		orientation:'both',
		zoomMin: 1000 * 60 * 60 * 6, // quarter-hour (ms)
 		zoomMax: 1000 * 60 * 60 * 24 * 31 * 24, // about 24 months in milliseconds
		groupTemplate: function (group) {
			var container = document.createElement("div");
			var label = document.createElement("span");
			label.innerHTML = group.content + " ";
			container.insertAdjacentElement("afterBegin", label);
			var hide = document.createElement("button");
			hide.innerHTML = "hide";
			hide.style.fontSize = "small";
			hide.addEventListener("click", function () {
			  groups.update({ id: group.id, visible: false });
			});
			container.insertAdjacentElement("beforeEnd", hide);
			return container;
  		},
  		onInitialDrawComplete: () => {
	  		timeline.redraw();
	  		fitTimeline();
	  	},
	  	onTimeout: {
			timeoutMs: 200,
			callback: function (callback) {
			  var didUserCancel;
			  var didUserCancel = confirm(
			    "Too many items loaded! Would you like to continue rendering (this might take a while)?"
			  );
			  callback(didUserCancel);
			},
		},
	};

	var groups = new vis.DataSet([
		{
			id:'Encounter',
			value:0,
			content:'Encounters',
			subgroupStack:false,
			className: 'Encounters'
		},
		{
			id:'Condition',
			value:1,
			content:'Conditions',
			subgroupStack:false,
			className: 'Conditions'
		},
		{
			id:'Procedure',
			value:2,
			content:'Procedures',
			subgroupStack:false,
			className: 'Procedures'
		},
		{
			id:'Observation',
			value:3,
			content:'Observations',
			subgroupStack:false,
			className: 'Observations'
		},
		{
			id:'Medication',
			value:4,
			content:'Medications',
			subgroupStack:false,
			className: 'Medications'
		},
		{
			id:'Vaccination',
			value:5,
			content:'Vaccinations',
			subgroupStack:false,
			className: 'Vaccinations'
		},
		
	]);
	
	timeline.setOptions(options);
	timeline.setGroups(groups);
	
	// fhirRef[timeline.item.id]=entry.resource.id
	var fhirRef = new Array();
	
	// fhirResource[entry.resource.id]=entry.resource
	var fhirResource = new Array();
	
	document.getElementById("buttonRefit").onclick = function () {
		groups.forEach(function (group) {
    		groups.update({ id:group.id, visible:true });
  		});
		fitTimeline();
	}


function parse() {
	
	let tMpiid = getMpiid();
	if (tMpiid == "") {
		console.log("No MPIID found in current session. Search for a patient first.");
		return
	}
	
	let tFHIR = getFhirData();
	if (tFHIR == "") {
		console.log("No FHIR data found in sessionStorage. Search for a patient first.");
		return
	}
	
	document.getElementById('patientData').style.visibility='visible';
	document.getElementById('visualization').style.visibility='visible' 
	
	//bundle=JSON.parse(document.getElementById('FHIRBundle').value);
	bundle=JSON.parse(tFHIR);
	
	items = new Array();
	
	bundle.entry.forEach(processEntry);
	
	items2 = new vis.DataSet(items);
	
	timeline.setItems(items2);
	

	// workaround for onInitialDrawComplete bug
	this.timeline.on("currentTimeTick", (prop) => {
        // Do something here
        fitTimeline();
        timeline.redraw();
        // After fired the first time we un-subscribed
        this.timeline.off("currentTimeTick")
    })
	
	timeline.on('select', function (selectedObj) {
				// for timeline debugging:
				//  console.log('selectedObj:',selectedObj);
			if (selectedObj.items.length > 0) {
				// for timeline debugging:
				//  console.log('timeline.itemSet.getItemById("'+selectedObj.items+'").data :' , timeline.itemSet.getItemById(selectedObj.items).data);
				console.log('fhirResource[fhirRef["'+selectedObj.items[0]+'"]] :', fhirResource[fhirRef[selectedObj.items[0]]]);
				var selection = timeline.getSelection();
	  			timeline.focus(selection);
  			}
		});
		
	//timeline.focus(1);
	
	
	
}

function fitTimeline()
{
	// console.log('refit');
	timeline.fit({duration: 500, easingFunction: 'easeInOutQuint'});
}

function calculateAge(birthdate) {
    const birthdateObj = new Date(birthdate);

    // Get the current date
    const currentDate = new Date();

    // Calculate the difference in years
    let age = currentDate.getFullYear() - birthdateObj.getFullYear();

    // Check if the birthday has occurred this year
    const hasBirthdayOccurred = (
        currentDate.getMonth() > birthdateObj.getMonth() ||
        (currentDate.getMonth() === birthdateObj.getMonth() && currentDate.getDate() >= birthdateObj.getDate())
    );

    // If birthday hasn't occurred, subtract 1 from the age
    if (!hasBirthdayOccurred) {
        age--;
    }

    return age;
}

/// caches each resource for display in console
function cacheEntry(entry) {
	if (fhirResource[entry.resource.id] !== undefined) {
		console.log('<WARNING> Duplicate resource ID found in ',
					'1. '+fhirResource[entry.resource.id].resourceType+'/'+entry.resource.id,
					'2. '+entry.resource.resourceType+'/'+entry.resource.id
					);
	}
	
	fhirResource[entry.resource.id]=entry.resource;
}

function processEntry(entry) {
	cacheEntry(entry);
	
	const resource = entry.resource;
	let tItemId = items.length+1;
	let tItem = {id:tItemId, group:resource.resourceType};
	
	fhirRef[tItemId]=resource.id;
	
	if (resource.resourceType == 'Patient') {
		
		document.getElementById('PatientName').innerHTML = resource.name[0].family + ', ' + resource.name[0].given;
		document.getElementById('PatientDemogs').innerHTML = calculateAge(resource.birthDate) + ' Jahre, ' + resource.gender;
		
		identifiersString = new String;
		resource.identifier.forEach(getIdentifiersString);
		document.getElementById('PatientIds').innerHTML = identifiersString;
		
	} else if (resource.resourceType == 'Encounter') {
		
		if (resource.period === undefined) return;

		tItem.start = resource.period.start;
		if (tItem.start === undefined) return;
		if (resource.period.end !== undefined) {
			tItem.end = resource.period.end;
		}
		
		let subgroup = (resource.type === undefined) ? 'Einrichtungskontakt' : resource.type[0].coding[0].display;
		
		if (subgroup=='Einrichtungskontakt') {
			tItem.content = 'Fall #'+resource.identifier[0].value + ' status:'+resource.status;
			tItem.title = 'resource id:'+resource.id;
			
		} else if (subgroup=='Abteilungskontakt') {
			
			tItem.content = '[AK] '+ (resource.serviceType ? resource.serviceType.coding[0].display : '');
			tItem.title = 'resource id:'+resource.id;
			
		} else if (subgroup=='Versorgungsstellenkontakt') {
			locationsString = new String;
			if(resource.location) resource.location.forEach(getLocationsString);
			tItem.content = '[VK] ' + locationsString;	
			tItem.title = 'resource id:'+resource.id;
		
		} else {
			tItem.content = resource.reasonCode[0].coding[0].display;
		}
		
		if (tItem.start == tItem.end) {
			delete tItem.end;
			tItem.content = 'Konsil/OP';
			tItem.title = 'Konsil/OP';
		}				
		
		items.push(tItem);
		
	} else if (resource.resourceType == 'Condition') {
		
		tItem.start = resource.recordedDate;
		tItem.group = 'Condition';
		tItem.content = resource.code.coding[0].display;
		tItem.title = '[' + resource.code.coding[0].code + '] ' + resource.code.coding[0].display;
		
		items.push(tItem);
		
	} else if (resource.resourceType == 'Procedure') {
		
		tItem.start = resource.performedDateTime;
		tItem.group = 'Procedure';
		tItem.content = resource.code.coding[0].display;
		tItem.title = '[' + resource.code.coding[0].code + '] ' + resource.code.coding[0].display;
		
		items.push(tItem);
		
	} else if (resource.resourceType == 'Observation') {
		
		tItem.start = resource.effectiveDateTime;
		tItem.group = 'Observation';
		tItem.content = getObservationString(resource);
		tItem.title = '[' + resource.code.coding[0].code + '] ' + resource.code.coding[0].display;
		
		items.push(tItem);
		
	} else if (resource.resourceType == 'MedicationStatement') {
		if (resource.effectivePeriod !== undefined) {
			tItem.start = resource.effectivePeriod.start;
			tItem.end = resource.effectivePeriod.end;
		
		} else if (resource.effectiveDateTime !== undefined) {
			tItem.start = resource.effectiveDateTime;
			
		} else {
			console.log('No Timestamp, skipping resource:',resource);
			return
		}
		
		tItem.group = 'Medication';
		tItem.content = '[MS]'+resource.medicationReference.display;
		tItem.title = resource.resourceType;
		
		items.push(tItem);
	
	} else if (resource.resourceType == 'MedicationAdministration') {
		if (resource.effectivePeriod !== undefined) {
			tItem.start = resource.effectivePeriod.start;
			tItem.end = resource.effectivePeriod.end;
		
		} else if (resource.effectiveDateTime !== undefined) {
			tItem.start = resource.effectiveDateTime;
			
		} else {
			console.log('No Timestamp, skipping resource:',resource);
			return
		}
		
		tItem.group = 'Medication';
		tItem.content = '[MA]'+resource.medicationReference.display;
		tItem.title = resource.resourceType;
		
		items.push(tItem);
	
	} else if (resource.resourceType == 'OperationOutcome') {
		console.log('<WARNING> Issues were found!',resource);
	}
	
	if (tItem.start === undefined && resource.resourceType!=='Patient') {
		tItem.start = Date.now();
		console.log('tItem.start undefined for '+resource.resourceType+'/'+resource.id);
	}
	
}

function getObservationString(resource) {
	
	let prefix = new String;
	let value = new String;
	let unit = new String;
	let content = new String;
	
	// value is either a singleton in valueQuantity or a component (example: blood pressure)
	if (resource.valueQuantity !== undefined) {
		
		prefix	= '[' + resource.category[0].coding[0].code + '] ';
		
		if (resource.valueQuantity.unit !== undefined) {
			value	= resource.code.coding[0].display +' '+ resource.valueQuantity.value;
			unit	= ' ' +  resource.valueQuantity.unit;
			content	= prefix + value + unit;
			
		} else {
			
			value	= resource.valueQuantity.value;
			unit	= resource.code.coding[0].display;
			content	= prefix + unit +': '+ value;
		
		}
	
		
	} else if (resource.component !== undefined) {
		
		// presuming BP here
		prefix	= '[' + resource.category[0].coding[0].code + '] ';
		let systolicIdx = (resource.component[0].code.coding[0].code == '8480-6') ? 0 : 1;
		let diastolicIdx = (resource.component[0].code.coding[0].code == '8462-4') ? 0 : 1;
		value	= resource.component[systolicIdx].valueQuantity.value +'/'+ resource.component[diastolicIdx].valueQuantity.value;
		unit = ' mmHg';
		content	= prefix + value + unit;
		
	} else if (resource.valueString !== undefined) {
		
		prefix	= '[' + resource.category[0].coding[0].code + '] ';
		value	= resource.code.coding[0].display +': '+ resource.valueString;
		content	= prefix + value;
		
	} else {
		
		console.log('Observation value not found in:', resource);
	}
	
	
	return content
	
}	

function getIdentifiersString(identifier) {

	identifiersString += identifier.type ? (identifier.type.coding[0].code + ':' +	identifier.value + '; ') : identifier.value;
}
  
function getLocationsString(location)
{
	if (location.physicalType) {
		locationsString += location.physicalType.coding[0].display + ' ' + location.location.display + '; ';
	}
}
  
</script>
</body>
</html>
	
	>
	
	return $$$OK
}

}
