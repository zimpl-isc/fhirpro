/**
* UI for selecting and retrieving SDA3 and FHIR data
*
* @version 1.0 2024-03-27
* @author Brandon Thomas
*/

Class HS.Local.zimpli.fhir.UI.Datasource Extends HS.Local.zimpli.fhir.UI.Super
{

ClassMethod OnPage() As %Status
{
	&html<<!DOCTYPE HTML>
<html>	
<head>
#(..MetaTags())#
#(..LinkJS("assets/ext/jquery-3.7.1.min.js"))#
#(..XDataJS("BeautifyJS"))#
#(..XDataJS("StorageHandler"))#
#(..LinkJS("assets/Datasource.js"))#
#(..DefaultStyle())#
#(..LinkCSS("assets/Datasource.css"))#

<script type="text/javascript">
    window.App = window.App || {};
    App.state = {};
    App.config = {};
    App.config.SDAStreamServer = '#(..#SDAStreamServer)#';
    App.config.FHIRStreamServer = '#(..#FHIRStreamServer)#';
</script>

</head>
<body>
<div id="pageShell">

    <div id="fetchCard" class="card">
        <div class="cardTitle">Fetch patient data</div>
        <form id="fetchForm" onsubmit="fetchData(); return false;">
            <div class="formRow">
                <input id="mrn" name="mrn" placeholder="MRN">
                #(..AssigningAuthSelect())#
                <span class="orDivider">or</span>
                <input id="mpiid" name="mpiid" placeholder="MPIID">
                #(..FHIRServiceSelect())#
                <button type="submit" class="primaryButton">Fetch</button>
            </div>
        </form>
    </div>

    <div id="contentGrid">
        <div class="card" id="storageCard">
            <div class="cardTitle">Available data</div>

            <div id="CurrentItem" class="currentBox">
                <div><b>Current:</b> <span id="CurrentMPIID"></span></div>
                <div><b>Source:</b> <span id="CurrentSource"></span></div>
                <div class="buttonRow">
                    <button id="ButtonCopylocalStorage" onclick="copyToLocalStorage()" type="button">Save to Local</button>
                    <button id="ButtonCopysessionStorage" onclick="copyToSessionStorage()" type="button">Save to Session</button>
                </div>
            </div>

            <div class="storageColumns">
                <div class="storagePanel">
                    <div class="storageHeader">
                        <a class="wastebasket" onclick="deleteItem('sessionStorage', '*')">&#128465;&#65039;</a>
                        <span id="sessionStorageLabel">Session Cache</span>
                    </div>
                    <dl id="sessionStorageList"></dl>
                </div>

                <div class="storagePanel">
                    <div class="storageHeader">
                        <a class="wastebasket" onclick="deleteItem('localStorage', '*')">&#128465;&#65039;</a>
                        <span id="localStorageLabel">Local Storage</span>
                    </div>
                    <dl id="localStorageList"></dl>
                </div>
            </div>
        </div>

        <div class="card" id="previewCard">
            <div class="previewHeader">
                <div class="cardTitle">Preview</div>
                <div class="buttonRow">
                    <button onclick="beautifyXML()" type="button">Format XML</button>
                    <button onclick="beautifyJS()" type="button">Format JSON</button>
                </div>
            </div>

            <div class="previewGrid">
                <div class="previewPane">
                    <div class="paneTitle">SDA Preview</div>
                    <textarea id="PreviewSDA"></textarea>
                </div>
                <div class="previewPane">
                    <div class="paneTitle">FHIR Preview</div>
                    <textarea id="PreviewFHIR"></textarea>
                </div>
            </div>
        </div>
    </div>

</div>	
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
	set tSQL = "select Code,Name from HS_AssignAuth.Config where identifiertype='MR' or identifiertype='KVNR'"
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
