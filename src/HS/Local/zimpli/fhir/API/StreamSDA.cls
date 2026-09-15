/**
* Utility class supporting the transmission of SDA3 data 
* between the frontend UI and backend Production
*
* @version 1.0 2024-03-27
* @author Brandon Thomas
*/

Class HS.Local.zimpli.fhir.API.StreamSDA Extends %CSP.StreamServer
{

/// Dispatching Business Service
Parameter BusinessService = "HS.Local.zimpli.fhir.API.TestService";

/// The <method>OnPostHTTP()</method> is called by the CSP dispatcher before the HTTP
/// headers have been sent.  Here, we check that the incoming STREAMOID value is valid,
/// then we set the appropriate content type and content length values into the %response
/// object (see <class>%CSP.Request</class>), in preparation for sending the image data
/// in the <method>OnPage()</method>.
ClassMethod OnPreHTTP() As %Boolean
{
	set tMPIID	= $get(%request.Data("MPIID",1))
	set tMRN	= $get(%request.Data("MRN",1))
	set tAA		= $get(%request.Data("AA",1))
	set tFilters= $get(%request.Data("Filter",1))
	
	if (tMPIID'="")||((tMRN'="") && (tAA'="")) {
		set %request.Data("STREAMOID",1) = ..GetSDAStreamOID(tMPIID, tMRN, tAA, tFilters)
	}
	
	return ##super()
}

/// Event handler for <b>POSTPAGE</b> event: this is invoked after the data
/// for the CSP page has been sent to the browser from the the InterSystems IRIS server.
ClassMethod OnPostHTTP() [ ServerOnly = 1 ]
{
	if $get(%request.Data("STREAMOID",1)) '="" {
		do ##class(%CSP.BinaryStream).%Delete(%request.Data("STREAMOID",1))
	}
	
	return $$$OK
}

/// Diagnostic: retrieve SDA for a patient via the access gateway and parse every
/// object with GetNextSDA(), reporting type counts and any errors to the current device.
/// Call from a terminal: do ##class(HS.Local.zimpli.fhir.API.StreamSDA).DiagnoseSDA(mpiid)
ClassMethod DiagnoseSDA(pMPIID As %String = "", pMRN As %String = "", pAA As %String = "") As %Status
{
	set tSC = $$$OK

	write !,"=== SDA Diagnostic  MPIID="""_pMPIID_"""  MRN="""_pMRN_"""  AA="""_pAA_"""",!

	// --- fetch ---
	set tRequest = ##class(HS.Message.SearchAndFetchRequest).%New()
	set tRequest.MPIID = pMPIID
	set tRequest.MRN   = pMRN
	set tRequest.AssigningAuthority = pAA

	set tSC = ##class(Ens.Director).CreateBusinessService(..#BusinessService, .tService)
	if $$$ISERR(tSC) {
		write !,"[ERROR] CreateBusinessService: ", $system.Status.GetErrorText(tSC), !
		return tSC
	}

	set tSC = tService.OnProcessInput(tRequest, .tResponse)
	if $$$ISERR(tSC) {
		write !,"[ERROR] OnProcessInput: ", $system.Status.GetErrorText(tSC), !
		return tSC
	}

	if '$IsObject(tResponse) {
		write !,"[ERROR] No response object returned", !
		return $$$ERROR($$$GeneralError, "No response from SearchAndFetch")
	}
	if '$IsObject(tResponse.XMLData) {
		write !,"[ERROR] Response.XMLData is empty — no SDA on file for this patient", !
		return $$$ERROR($$$GeneralError, "Response.XMLData is not an object")
	}

	write "[OK] SDA stream retrieved — size: "_tResponse.XMLData.Size_" bytes",!

	// --- parse ---
	set tContainer = ##class(HS.SDA3.Container).%New()
	set tSC = tContainer.InitializeXMLParse(tResponse.XMLData)
	if $$$ISERR(tSC) {
		write !,"[ERROR] InitializeXMLParse: ", $system.Status.GetErrorText(tSC), !
		return tSC
	}
	write "[OK] InitializeXMLParse succeeded",!

	set tTotal = 0, tErrors = 0
	for {
		set tGot = tContainer.GetNextSDA(.tType, .tSDA, .tItemSC, .tDate)
		if $$$ISERR(tItemSC) {
			set tErrors = tErrors + 1
			write "[ERROR] item "_tTotal_" (type="_tType_"): ", $system.Status.GetErrorText(tItemSC), !
			set tSC = $$$ADDSC(tSC, tItemSC)
		}
		quit:'tGot
		set tTotal = tTotal + 1
		set tCounts(tType) = $get(tCounts(tType), 0) + 1
		if (tType = "Patient") && $IsObject(tSDA) {
			write "    Patient MPIID="""_tSDA.MPIID_"""",!
		}
	}

	// --- summary ---
	write !,"=== Summary ===",!
	write "Total objects : "_tTotal, !
	write "Parse errors  : "_tErrors, !
	write "By type:", !
	set tType = ""
	for {
		set tType = $order(tCounts(tType))
		quit:tType=""
		write "  "_$justify(tCounts(tType),5)_"  "_tType, !
	}
	if $$$ISOK(tSC) {
		write "[OK] No errors",!
	} else {
		write "[WARN] Completed with errors — see above",!
	}
	return tSC
}

ClassMethod GetSDAStreamOID(pMPIID = "", pMRN = "", pAA = "", pFilters = "") As %String
{
	#dim tRequest as HS.Message.SearchAndFetchRequest = ##class(HS.Message.SearchAndFetchRequest).%New()
	#dim tStreamHandle = ""
	
	set tRequest.MPIID = pMPIID
	set tRequest.MRN = pMRN
	set tRequest.AssigningAuthority = pAA

	// Filters can be passed in to retrieve only specific datatypes, 
	// 	for example: "ENC,OBS" for encounters and Observations
	if (pFilters '= "") {
		set tFilter = ##class(HS.Types.Filters).%New()
		for tIter = 1:1:$length(pFilters, ",") {
			do tFilter.InfoTypes.Insert($piece(pFilters, ",", tIter))
		}
		set tRequest.Filters = tFilter
	}

	set tSc=##class(Ens.Director).CreateBusinessService(..#BusinessService,.tService)
	set tSc = tService.OnProcessInput(tRequest, .tResponse)
	
	if $IsObject(tResponse) {
		set tCSPStream = ##class(%CSP.BinaryStream).%New()
		do tCSPStream.CopyFrom(tResponse.XMLData)
		do tCSPStream.SetAttribute("ContentType","text/xml")
		do tCSPStream.SetAttribute("Content-Disposition","inline; filename="_pMPIID_".xml")
		do tCSPStream.SetAttribute("CharSet","UTF-8")
		
		do tCSPStream.%Save()
		
		set tStreamHandle = ##class(%CSP.StreamServer).Encrypt(tCSPStream.%Oid())
	}
	
	return tStreamHandle
}

}
