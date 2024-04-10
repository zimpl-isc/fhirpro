/**
* Utility class supporting the transmission of SDA3 data 
* between the frontend UI and backend Production
*
* @version 1.0 2024-03-27
* @author Brandon Thomas
*/

Class HS.Local.zimpl.fhirpro.API.StreamSDA Extends %CSP.StreamServer
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
	set tMRN = $get(%request.Data("MRN",1))
	set tAA = $get(%request.Data("AA",1))
	
	if $get(%request.Data("Filter",1))'="" {
		set %request.Data("STREAMOID",1) = ..GetSDAStreamOID(tMPIID, tMRN, tAA)
	}
	
	if (tMPIID'="")||((tMRN'="") && (tAA'="")) {
		set %request.Data("STREAMOID",1) = ..GetSDAStreamOIDEnc(tMPIID, tMRN, tAA)
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

ClassMethod GetSDAStreamOID(pMPIID = "", pMRN = "", pAA = "") As %String
{
	#dim tRequest as HS.Message.SearchAndFetchRequest = ##class(HS.Message.SearchAndFetchRequest).%New()
	#dim tStreamHandle = ""
	
	set tRequest.MPIID = pMPIID
	set tRequest.MRN = pMRN
	set tRequest.AssigningAuthority = pAA

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

ClassMethod GetSDAStreamOIDEnc(pMPIID = "", pMRN = "", pAA = "") As %String
{
	#dim tRequest as HS.Message.SearchAndFetchRequest = ##class(HS.Message.SearchAndFetchRequest).%New()
	#dim tStreamHandle = ""
	
	set tRequest.MPIID = pMPIID
	set tRequest.MRN = pMRN
	set tRequest.AssigningAuthority = pAA
	
	/* // Set a Filter the types of requested data
	set tFilter = ##class(HS.Types.Filters).%New()
	do tFilter.InfoTypes.Insert("ENC")
	set tRequest.Filters = tFilter
	*/

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
