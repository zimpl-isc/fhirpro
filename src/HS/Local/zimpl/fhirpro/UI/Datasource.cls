/**
* UI for selecting and retrieving SDA3 and FHIR data
*
* @version 1.0 2024-03-27
* @author Brandon Thomas
*/

Class HS.Local.zimpl.fhirpro.UI.Datasource Extends HS.Local.zimpl.fhirpro.UI.Super
{

ClassMethod OnPage() As %Status
{
	&html<<!DOCTYPE HTML>
<html>	
<head>
#(..MetaTags())#
#(..LinkJS("jquery-3.7.1.min.js"))#
#(..XDataJS("BeautifyJS"))#
#(..XDataJS("StorageHandler"))#
#(..DefaultStyle())#

<script type="text/javascript">
$(document).ready(function(){
	listStorages();
	
	let mpiid = getMpiid();
	if (mpiid !== null) {
		showCurrent(getMpiid());	
	}
	
	$('textarea').on('mousedown', function(){
		$('#CurrentMPIID').html('NEW');
		$('#CurrentSource').html('textarea');
		$('#ButtonCopysessionStorage').css({ display: 'unset' });
		$('#ButtonCopylocalStorage').css({ display: 'unset' });
	});
	
	$("a").hover(function(){
		$(this).css("text-decoration", "underline");
		}, function(){
		$(this).css("text-decoration", "none");
	});
	$(".wastebasket").hover(function(){
		$(this).css("filter", "drop-shadow(0 0 2px red)");
		}, function(){
		$(this).css("filter", "none");
	});
	
	// use localStorage to remeber the AA option setting
});
</script>

<script type="text/javascript">
async function fetchData()
{
	let prettyPrint =  new String();
	let pMPIID = $('#mpiid').val();
	const FHIRService = $('#FHIRService').val();
	let querystr = '?MPIID='+pMPIID+'&FHIRSvc='+FHIRService;
	
	if (pMPIID == "") {
		querystr += '&MRN='+$('#mrn').val()+'&AA='+$('#aa').val();
	} 
	
	//// Get SDA and place in a textarea						
	const sda = await fetch('#(..#SDAStreamServer)#'+querystr, {cache: "no-cache"})
							.then(response => response.text()
								.then(status = response.status));
	
	if (parseInt(status) !== 200) {
		prettyPrint = 'SDA Fetch failed with status code: ' + status;
		console.log(prettyPrint);
	} else {
		prettyPrint = vkbeautify.xml(sda, ' ');
	}


	if (pMPIID == "") {
		parser = new DOMParser();
		xmlDoc = parser.parseFromString(sda,"text/xml");
		pMPIID = xmlDoc.getElementsByTagName('Patient')[0].getElementsByTagName('MPIID')[0].childNodes[0].nodeValue;
	}
	setMpiid(pMPIID);

	setSdaData(prettyPrint);
	
	//// Get FHIR
	const fhir = await fetch('#(..#FHIRStreamServer)#?MPIID='+pMPIID+'&FHIRSvc='+FHIRService, {cache: "no-cache"})
							.then(response => response.json()
								.then(status = response.status));

	if (parseInt(status) !== 200) {
		prettyPrint = 'FHIR Fetch failed with status code: ' + status;
		console.log(prettyPrint);
	} else {
		prettyPrint = vkbeautify.json(JSON.stringify(fhir), ' ');
	}
	
	setFhirData(prettyPrint);
	setCurrent('sessionStorage',pMPIID);
	listStorages();
}
function listStorages() {
	
	// remove any storage items from display before drawing them (again)
	$('dd').remove();
	
	let key = new String();
	
	["localStorage","sessionStorage"].forEach(function(storageType){
		for (var i = 0; i < this[storageType].length; i++){
			
			// don't display other session variables
			if ((this[storageType].key(i) == "mpiid") || (this[storageType].key(i) == "storageType")) {
				continue;
			}
		
			key = this[storageType].key(i).split("#")[1];
			
			// ensure an mpiid is only listed once per storageType
			if ($('#'+storageType+'List [data-value='+key+']').length) {
				continue;
			}
			
			// Create a description list element
			var dd = $('<dd/>', {
				"data-value":key, 
				}).appendTo('#'+storageType+'List');
				
			// Add the text
			$('<a/>', {
				"html":key,
				"click":function(){setCurrent(storageType, $(this).parent().attr('data-value'))}
				}).prependTo(dd);
			
			// Add a wastebasket
			$('<a/>', {
				"html":"&#128465;&#65039;", "class":"wastebasket",
				"click":function(){deleteItem(storageType, $(this).parent().attr('data-value'))}
				}).prependTo(dd);
				
			}
	});		
}
function setCurrent(storageType, mpiid) {
	
	console.log("setCurrent(" + storageType +','+ mpiid +')');
	setStorage(storageType);
	setMpiid(mpiid);
	
	var parentWindow = window.parent;
	parentWindow.setCurrentItemInTitle(mpiid);
	
	showCurrent(mpiid);
}
function showCurrent(mpiid) {
	console.log('showCurrent('+mpiid+')');
	
	if (mpiid !== "undefined") {
		let storage = getStorage();
		let storageType = sessionStorage.getItem("storageType");
		
		$('#PreviewSDA').val(storage.getItem('SDA#'+mpiid));
		$('#PreviewFHIR').val(storage.getItem('FHIR#'+mpiid));
		$('#CurrentMPIID').html(mpiid);
		$('#CurrentSource').html(storageType);
		
		$('#ButtonCopysessionStorage').css({ display: storageType == "sessionStorage" ? 'none' : 'unset' });
		$('#ButtonCopylocalStorage').css({ display: storageType == "localStorage" ? 'none' : 'unset' });
		
		$('#localStorageList dd').removeClass("active");
		$('#sessionStorageList dd').removeClass("active")
		$('#'+storageType+'List [data-value='+mpiid+']').addClass("active");
	}
}
function deleteItem(storageType, id) {
	if (confirm('Delete '+id+' from '+storageType+'?')) {
		if (id=='*') {
			this[storageType].clear()
		} else {
			this[storageType].removeItem('SDA#'+id);
			this[storageType].removeItem('FHIR#'+id);
		}
		setCurrent('sessionStorage');
		listStorages();
		//location.reload();
	}
}
function copyToLocalStorage() {
	
	let name = prompt('Please give it a name', getMpiid() );
	if (name!== null) {
		name = name.replace(' ','_');
		localStorage.setItem('FHIR#'+name, $('#PreviewFHIR').val());
		localStorage.setItem('SDA#'+name, $('#PreviewSDA').val());
		location.reload();
	}
}
function copyToSessionStorage() {

	let name = prompt('Please give it a name', getMpiid());
	if (name!== null) {
		name = name.replace(' ','_');
		setMpiid(name);
		sessionStorage.setItem('FHIR#'+name, $('#PreviewFHIR').val());
		sessionStorage.setItem('SDA#'+name, $('#PreviewSDA').val());
		setStorage('sessionStorage');
		location.reload();
	}
}
function beautifyJS() {
	$('#PreviewFHIR').val( vkbeautify.json($('#PreviewFHIR').val(), ' ') );
}

function beautifyXML() {
	$('#PreviewSDA').val( vkbeautify.xml($('#PreviewSDA').val(), ' ') );
}
</script>
<style> /* for overrides */
body {padding:1em;}
#PreviewTable {width:96%;}
textarea {
	width: 99%;
	height: 50vh;
}
th {
	text-align: left;
}
td {
	vertical-align: top;
}
dt {
	font-weight: bold;
}
dd {
	cursor: pointer;
	font-weight: normal;
	margin-left:1em;
}
dl {
	margin: 0;
}
.wastebasket {
	font-size: small;
	padding: 0 0.2em;
	cursor: pointer;
	text-decoration: none !important;
}
.disclaimer {
	font-size: small;
	font-style: italic;
}
#DataNew, #DataStored {
	xmargin-bottom: 1em;
	xpadding-bottom: 1em;
	width: fit-content;
	display: inline-block;
	vertical-align: top;
	xmargin-right: 7em;
}
#DataSources {
	justify-content: flex-start;
	display: flex;
	padding-bottom:1em;
}
#DataSources div {
	padding-left: 3em;
}
#CurrentItemzzz {
	border: 1px solid #bfbfbf;
	padding: 1em !important;
	border-radius: 0.7em 0;
	background: white;
	width: fit-content;
	height: fit-content;
}
.active {
	color: #00b5afb8;
	filter: drop-shadow(0 0 2px white);
}
</style>
</head>
<body>
<div id="DataSources">

	<div id="CurrentItem" class="infoBox">
		<b>current:</b> <span id="CurrentMPIID"></span>
		<br />
		<b>source:</b> <span id="CurrentSource"></span>
		<br />
		<button id="ButtonCopylocalStorage" onclick="copyToLocalStorage()">Copy to localStorage</button>
		<button id="ButtonCopysessionStorage" onclick="copyToSessionStorage()">Copy to sessionStorage</button>
	</div>

	<div id="DataStored">
		<dl id="StorageList">
			<dt id="sessionStorageList" data-value="sessionStorage" title="Cached only for browser session">
				<a class="wastebasket" onclick="deleteItem('sessionStorage', '*')">&#128465;&#65039;</a>
				Session Items
			</dt>
		</dl>
	</div>

	<div id="DataStored">
		<dl id="StorageList">
			<dt id="localStorageList" data-value="localStorage">
				<a class="wastebasket" onclick="deleteItem('localStorage', '*')">&#128465;&#65039;</a>
				Stored Items
			</dt>
		</dl>
	</div>
	
		<div id="DataNew">
		<input id="mrn" name="mrn" placeholder="mrn...">
		#(..AssigningAuthSelect())#
			<br/> -- or -- <br/>
		<input id="mpiid" name="mpiid" placeholder="mpiid...">
			<br/>
		#(..FHIRServiceSelect())#
		<button onclick="fetchData()" style="float:right;">Fetch</button>
		
	</div>

</div>
	
<table id="PreviewTable">
	<colgroup>
		<col span="1" style="width:48%;">
		<col span="1" style="width:1%;">
		<col span="1" style="width:48%;">
	</colgroup>
	
	<tr>
		<th>SDA Preview
			<button onclick="beautifyXML()" style="width:3em; float:right;">&lt;&gt;</button>
		</th>
		<th></th>
		<th>FHIR Preview
			<button onclick="beautifyJS()" style="width:3em; float:right;">{}</button>
		</th>
	</tr>
	
	<tr> 
		<td>
			<textarea id="PreviewSDA"></textarea>
		</td>
		<td>
			
			
		</td>
		<td>
			<textarea id="PreviewFHIR"></textarea>
		</td>
	</tr>

</table>
	
</body>
</html>>
	
	return $$$OK
}

ClassMethod FHIRServiceSelect()
{
	#dim tDefaultServiceName = ##class(Ens.Director).GetItemSettingValue("HS.FHIRServer.Interop.HTTPOperation","Host","ServiceName",.tsc)
	set tSQL = "select * from HS_Registry_Service.HTTP where type='HTTP' and status=1 and url like '%fhir%'"
	set tRS = ##class(%ResultSet).%New()
	do tRS.Prepare(tSQL)
	do tRS.Execute()
	
	&html<<select id="FHIRService" name="ServiceName" title="#(tSQL)#">>
	
	while tRS.Next() {
		set tServiceName = tRS.Data("Name")
		set tSelected = $case(tServiceName, tDefaultServiceName:" selected", :"")
		&html<<option value="#(tServiceName)#"#(tSelected)#>#(tServiceName)#</option>>
	}
	
	&html<</select>>
	
	return ""
}

ClassMethod AssigningAuthSelect()
{
	set tSQL = "select Code,Name from HS_AssignAuth.Config where identifiertype='MR'"
	set tRS = ##class(%ResultSet).%New()
	do tRS.Prepare(tSQL)
	do tRS.Execute()
	
	&html<<select id="aa" name="aa" title="#(tSQL)#">>
	
	while tRS.Next() {
		&html<<option value="#(tRS.Data("Code"))#">#(tRS.Data("Name"))#</option>>
	}
	
	&html<</select>>
	
	return ""
}

}
