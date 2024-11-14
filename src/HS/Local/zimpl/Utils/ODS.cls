Class HS.Local.zimpl.Utils.ODS
{

/// Also for use in  FHIR Inbound Namespaces
ClassMethod GetCustomDTLPackage()
{
	return ##class(HS.FHIR.DTL.Util.API.ExecDefinition).GetCustomDTLPackage()
}

/// Also for use in  FHIR Inbound Namespaces
ClassMethod SetCustomDTLPackage(pPackage = "HS.Local.MII.FHIR.DTL")
{
	return ##class(HS.FHIR.DTL.Util.API.ExecDefinition).SetCustomDTLPackage(pPackage)
}

/// Run this method in the REGISTRY to fill an **EMPTY** ODS (depending on the settings in ODS)
ClassMethod RePopulateODS()
{
	#dim SessionId
	
	do ##class(HS.Flash.Services).PopulateFlash(.SessionId)
 	write "SessionId = "_SessionId,!
 	
 	return $$$OK
}

/// Reload FHIR resources from SDA available in ODS for known MRNs
ClassMethod ReloadFHIRResources() As %Status
{
	do ##class(HS.Flash.Status).ForceResyncFHIR()
	do ##class(HS.Flash.Status).QueueAllFHIR(1)

	return $$$OK
}

/// Utility Method to change the status of all patients so that the next activity on them will
/// make all data be re-submitted to Flash.
/// It will change any MRN status of 1 (Ready) or 2 (Busy) to 3 (Error)
/// *** Stop the Flash production while running this. ***  ///
ClassMethod InvalidateAllRecords()
{
	Do ##class(HS.Flash.Status).ForceResendAll()
}

/// Utility Method to change the status of a single MPIID so that the next activity on it will
/// make all data be re-submitted to Flash. 
/// It will change any MRN status of 1 (Ready) or 2 (Busy) to 3 (Error)
ClassMethod InvalidateMPIID(pMPIID)
{
	Do ##class(HS.Flash.Status).ForceResendMPIID(pMPIID)
}

ClassMethod SDAString(pMPIID, pSubstring = "", Output tStreamlet) As %String
{
	#dim tId,tSDA
	
	set tId = "*^+"_pMPIID
	set tStreamlet = ##class(HS.SDA3.Streamlet.Flash).%OpenId(tId)
	set tSDA = tStreamlet.SDAString
	
	if (pSubstring '="") {
		set tSDA = $piece(tSDA, "<"_pSubstring_">",2)
		set tSDA = $piece(tSDA, "</"_pSubstring_">",1)
	}
	
	return tSDA
}

ClassMethod AllSDAStrings(pMPIID, pSubstring = "", Output pSDA = "", pOutputToTerminal = 1) As %Status
{
	#dim tId,tSDA,tIter,tFlashIds=""
	
	&sql(select list(ID) into :tFlashIds from HS_SDA3_Streamlet.Flash where MPIID = :pMPIID)
	
	for tIter = 1:1:$length(tFlashIds, ",") {
		set tId = $piece(tFlashIds, ",", tIter)
		
		set tStreamlet = ##class(HS.SDA3.Streamlet.Flash).%OpenId(tId)
		set tSDA = tStreamlet.SDAString
	
		if (pSubstring '="") {
			set tSDA = $piece(tSDA, "<"_pSubstring_">",2)
			set tSDA = $piece(tSDA, "</"_pSubstring_">",1)
		}
		
		write:pOutputToTerminal tSDA
		set pSDA = pSDA_tSDA
	}
	
	return $$$OK
}

/// To run in a background process call using:
/// 		HSODS> job ##class(HS.Local.Impl.Utils.ODS).ReloadAllPatients({lowest}, {highest})
ClassMethod ReloadAllPatients(pLowestMPIID = 100000001, pHighestMPIID = 0) As %Status
{
	#dim tTimeStamp = $zdt($h,3) 
	#dim tLogFilename = "ReloadAllPatients_"_$zstrip(tTimeStamp,"*P")_".log"
	
	OPEN tLogFilename:"wns" 
	USE tLogFilename
	
	write tTimeStamp,!
	write "Starting ##class(HS.Local.Impl.Utils.ODS).ReloadAllPatients("_pLowestMPIID_","_pHighestMPIID_")",!
	write "Process ID: "_$job,!
	write "Cancel job in terminal using %SYS> do ^JOBEXAM --> T(terminate) --> P"_$job,!,!
	
	for tMPIID = pLowestMPIID:1:pHighestMPIID {
		do ..ReloadPatient(tMPIID)
	}
	
	CLOSE tLogFilename
	
	return $$$OK
}

ClassMethod ReloadPatient(pMPIID = "") As %Status
{
	#dim tSc = $$$OK
	#dim tEnd,tStart,tElapsed
	
	if (pMPIID="") { // Use the latest
		&sql(select top 1 MPIID into :pMPIID from HS_SDA3_Streamlet.Flash order by MPIID desc)
	}
	
		set tStart = $piece($ztimestamp, ",", 2)
	
	set tSc = ..DeletePatient(pMPIID)
	set tSc = ..LoadPatient(pMPIID)
	
		set tEnd = $piece($ztimestamp, ",", 2)
		set tElapsed = tEnd - tStart
	
	write "Elapsed: "_tElapsed_" seconds",!
	
	return tSc
}

ClassMethod ReloadPatientTest(pMPIID = "") As %Status
{
	#dim tSc = $$$OK
	#dim tEnd,tStart,tElapsed
	
	if (pMPIID="") { // Use the latest
		&sql(select top 1 MPIID into :pMPIID from HS_SDA3_Streamlet.Flash order by MPIID desc)
	}
	
		set tStart = $piece($ztimestamp, ",", 2)
	
	set tSc = ..DeletePatient(pMPIID)
	set tSc = ..LoadPatient(pMPIID)
	
		set tEnd = $piece($ztimestamp, ",", 2)
		set tElapsed = tEnd - tStart
	
	write "Elapsed: "_tElapsed_" seconds",!
	
	return tSc
}

ClassMethod DeletePatient(pMPIID) As %Status
{
	#dim tException As %Exception.StatusException
	#dim tUpdateManager = ##class(HS.Flash.UpdateManager).%New("HS.Flash.UpdateManager")
	#dim tSc = $$$OK
	
	write "DeletePatient: "_pMPIID,!
	
	try {
		$$$ThrowOnError(tUpdateManager.DeletePatient(pMPIID, 1))
		
	} catch tException {
		
		if (tException.Code = 5810) {
			write "DeletePatient: Patient not found in ODS",!
		} else {
			
			if ($increment(%NoEndlessLoop)>25) {
				write "Some error was found! Breaking...",!
				break
			} else {
				write "DeletePatient: Patient record locked, trying again",!
				set tSc = ..DeletePatient(pMPIID)
			}
		}
	}
	
	return tSc
}

ClassMethod LoadPatientTest(pMPIID) As %Status
{
	#dim tUpdateManager = ##class(HS.Local.Impl.ODS.FlashUpdateManager).%New("HS.Local.Impl.ODS.FlashUpdateManager")
	#dim tSc = $$$OK
	
	write "LoadPatient: "_pMPIID,!
	
	set tMessage = ##class(HS.Message.FlashLoadMPIIDSync).%New()
	set tMessage.MPIID = pMPIID
	set tMessage.force = 1
	
	set tSc = tUpdateManager.LoadMPIID(tMessage)
	
	return tSc
}

ClassMethod LoadPatient(pMPIID) As %Status
{
	#dim tUpdateManager = ##class(HS.Flash.UpdateManager).%New("HS.Flash.UpdateManager")
	#dim tSc = $$$OK
	
	write "LoadPatient: "_pMPIID,!
	
	set tMessage = ##class(HS.Message.FlashLoadMPIIDSync).%New()
	set tMessage.MPIID = pMPIID
	set tMessage.force = 1
	
	set tSc = tUpdateManager.LoadMPIID(tMessage)
	
	return tSc
}

ClassMethod FHIRLogOn(pMode = "all") As %Status
{
	set ^FSLogChannel(pMode) = 1
	write "Events logged to ^FSLOG",!
	
	return $$$OK
}

ClassMethod FHIRLogOff() As %Status
{
	kill ^FSLogChannel
	write "Events logged to ^FSLOG",!
	
	return $$$OK
}

ClassMethod SetCustomDTL(pName = "HS.Local.MII.FHIR.DTL")
{
	write "Setting custom DTL package in "_$namespace_" to "_pName,!
	do ##class(HS.FHIR.DTL.Util.API.ExecDefinition).SetCustomDTLPackage(pName)
}

}
