/**
* Utility class supporting the transmission of FHIR data 
* between the frontend UI and backend Production
*
* @version 1.0 2024-03-27
* @author Brandon Thomas
*/

Class HS.Local.zimpl.fhirpro.API.StreamFHIR Extends %CSP.StreamServer
{

/// Dispatching Business Service
Parameter BusinessService = "HS.Local.zimpl.fhirpro.API.TestService";

/// The <method>OnPostHTTP()</method> is called by the CSP dispatcher before the HTTP
/// headers have been sent.  Here, we check that the incoming STREAMOID value is valid,
/// then we set the appropriate content type and content length values into the %response
/// object (see <class>%CSP.Request</class>), in preparation for sending the image data
/// in the <method>OnPage()</method>.
ClassMethod OnPreHTTP() As %Boolean
{
	set tMPIID = $get(%request.Data("MPIID",1))
	set tFHIRSvc = $get(%request.Data("FHIRSvc",1))
	
	if (tMPIID'="") {
		set %request.Data("STREAMOID",1) = ..GetStreamOID(tMPIID, tFHIRSvc)
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

ClassMethod GetStreamOID(pMPIID, pFHIRSvc = "") As %String
{
	#dim tInteropRequest = ##class(HS.FHIRServer.Interop.Request).%New()
	#dim tFHIRDataRequest = ##class(HS.FHIRServer.API.Data.Request).%New()
	
	set tFHIRDataRequest.RequestMethod = "GET"
	set tFHIRDataRequest.RequestPath = "/Patient/"_ pMPIID _"/$everything"
	set tFHIRDataRequest.RequestFormatCode = "JSON"
	set tFHIRDataRequest.ResponseFormatCode = "JSON"
	do:(pFHIRSvc'="") tFHIRDataRequest.AdditionalInfo.SetAt(pFHIRSvc,"ServiceName")

	set tInteropRequest.Request = tFHIRDataRequest
	
	set tSc=##class(Ens.Director).CreateBusinessService(..#BusinessService,.tService)
	set tsc = tService.OnProcessInput(tInteropRequest, .tResponse)
	
	set tCSPStream = ##class(%CSP.BinaryStream).%New()
	do tCSPStream.CopyFrom(##class(HS.SDA3.QuickStream).%OpenId(tResponse.QuickStreamId))
	do tCSPStream.SetAttribute("ContentType","text/json")
	do tCSPStream.SetAttribute("Content-Disposition","inline; filename="_pMPIID_".json")
	do tCSPStream.SetAttribute("CharSet","UTF-8")
	
	do tCSPStream.%Save()
	
	return ##class(%CSP.StreamServer).Encrypt(tCSPStream.%Oid())
}

}
