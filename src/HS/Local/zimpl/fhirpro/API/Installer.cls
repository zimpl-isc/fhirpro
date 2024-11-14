/**
* Installer class for the FHIR Profiler toolkit
*
* @version 1.0 2024-03-27
* @author Brandon Thomas
*/

Class HS.Local.zimpl.fhirpro.API.Installer
{

ClassMethod Install()
{
	set tInstallation = $listbuild("ZIMPLFHIRPRO:HS.Local.zimpl.fhirpro.Production:1")
	
	for tIter = 1:1:$listlength(tInstallation) {
		
		set tNamespace	= $piece($listget(tInstallation, tIter), ":", 1)
		set tProduction	= $piece($listget(tInstallation, tIter), ":", 2)
		set tAddMapping	= $piece($listget(tInstallation, tIter), ":", 3)
		
		do ..AddNamespace(tNamespace, tProduction, +tAddMapping)
	}
	
	write !,"Finished. Continue with configuration per README.md",!
	
	return $$$OK
}

ClassMethod AddNamespace(pNamespace, pProduction, pAddMappings As %Boolean = 1)
{
	if '##class(%SYS.Namespace).Exists(pNamespace) {
		
		write "Creating a Foundation Namespace for the new production in "_pNamespace,!
		
		set tOption("Production")=pProduction
		set tSC=##class(HS.Util.Installer.Foundation).Install(pNamespace,.tOption)
		
	} else {
		write "Namespace "_pNamespace_" already exists, continuing...",!
	}
	
	if pAddMappings {
		write !,"Add the Mappings needed to access registry tables such as OIDMap and services.",!
		do ..AddMappings(pNamespace)
	}
	
	return $$$OK
}

/// Add the Mappings needed to access registry tables such as OIDMap
ClassMethod AddMappings(pNamespace)
{
	write ##class(HS.Sync.Utils).Mapping(pNamespace,1)
}

}
