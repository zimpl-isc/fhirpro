/// TODO: When importing ValueSets save any codes to CodeSystem=ValueSet.Name & CodeSystem.  
/// Consider localization for display values on ValueSet but not (overwriting) CodeSystem
Class HS.Local.zimpl.Utils.Terminology.Importer Extends %RegisteredObject
{

/// The importer requires a valid SSL configuration for any https connections
Parameter SSLConfiguration = "simplifier";

Parameter RegistryNamespace = "HSREGISTRY";

Property URL As %String;

Property HttpRequest As %Net.HttpRequest;

Property Prefix As %String;

ClassMethod Main(pMethodNameForResourcesArray = "MII")
{
    do $classmethod($this, pMethodNameForResourcesArray, .tResourceArray)
       
	for {
		set tKey = $order(tResourceArray($get(tKey)))  quit:tKey=""
		set tResourceURL = tResourceArray(tKey)

		do ..FetchAndDispatch(tResourceURL)
	}

    return $$$OK
}

ClassMethod MII(Output oResourcesArray)
{
    #define URL(%rsc) "https://fhir.simplifier.net/R4/"_%rsc
    
    //set oResourcesArray("ICD10GM2023 CodeSystem") = $$$URL("CodeSystem/58851804-3afa-47a3-8d29-ee6aef7a680f")
    //set oResourcesArray("All ConceptMappings")    = $$$URL("ConceptMap?_count=2000")
    set oResourcesArray("OPS Operationen- und Prozedurenschlüssel") = $$$URL("CodeSystem/fb3ddb69-7b2e-4415-85f8-3e6f92c8b524")
}

ClassMethod KBVImpfpass(Output oResourcesArray)
{
    #define URL(%rsc) "https://fhir.simplifier.net/R4/"_%rsc

    set oResourcesArray("KBV_VS_MIO_Vaccination_Prior_Disease") = $$$URL("ValueSet/461cc67a-082d-4ae6-b350-a2ebf67c821a")
    set oResourcesArray("KBV_VS_MIO_Vaccination_TargetDisease") = $$$URL("ValueSet/beccbe3a-0c1f-4986-9b53-abd14094ad83")
	set oResourcesArray("KBV_CM_MIO_Vaccination_Vaccine_Targetdisease") = $$$URL("ConceptMap/599826dd-8963-43b5-802d-697812e44e99")
    set oResourcesArray("KBV_VS_MIO_Vaccination_Vaccine_ATC") = $$$URL("ValueSet/3531e0cd-dd2e-42f6-9bba-e2542ee6306f")
    set oResourcesArray("KBV_CM_MIO_Vaccination_Vaccine_ATC_Snomed") = $$$URL("ConceptMap/f4d88828-7145-4f7c-8ebc-e682de2805fc")

    // TODO: Folgende Ressourcen zusammenführen. https://simplifier.net/im1x0/kbvvsmiovaccinationvaccine
    set oResourcesArray("KBV_VS_MIO_Vaccination_Vaccine_List") = $$$URL("ValueSet/8a4e6169-fa0a-4855-b696-ba68cb828a3a")
    set oResourcesArray("KBV_VS_MIO_Vaccination_Vaccine_Immunoglobulin_List") = $$$URL("ValueSet/156151ed-ed6e-45e8-81ad-2ab8e16b7ecd")
    set oResourcesArray("KBV_VS_MIO_Vaccination_Vaccine_Brucella") = $$$URL("ValueSet/9f96b94c-8fc5-4846-9b8a-4bdb448b6bae")
}

/// Supports retrieval from an HTTP server (or TODO: a directory on the server)
ClassMethod FetchAndDispatch(pURL)
{
    #dim tException as %Exception.StatusException
    #dim tIsUpdate = 0
    #dim tImporter as HS.Local.Impl.Terminology.Importer = ..%New()

	try {

        //read !,"Enter a default prefix for any new CodeSystems created > ",tPrefix,!
        set tImporter.Prefix = "" //tPrefix
        
        if ($namespace '= ..#RegistryNamespace) {
            new $namespace
            set $namespace = ..#RegistryNamespace
        }

        set tStream = ..FetchData(pURL, , .tHTTPRequest)
        set tJSONData = {}.%FromJSON(tStream)

        set tImporter.URL = pURL
        set tImporter.HttpRequest = tHTTPRequest

        do tImporter.Dispatch(tJSONData)

    } catch tException {
		write "FetchAndDispatch failed on "_pURL,!
		write tException.AsStatus(),!
		break // Failed
	}
}

Method Dispatch(pJSONData)
{
    write !,"Dispatching "_pJSONData.resourceType,!
    do $case(pJSONData.resourceType,
                    "ValueSet"      : ..ProcessValueSet(pJSONData),
                    "CodeSystem"    : ..ProcessCodeSystem(pJSONData),
                    "ConceptMap"    : ..ProcessConceptMap(pJSONData),
                    "Bundle"        : ..ProcessBundle(pJSONData),
                                    : ..Catch(pJSONData))
}

Method ProcessCodeSystem(pJSONData As %DynamicObject)
{
    #dim tException as %Exception.StatusException
    
    try {

        set tOIDMapCode = ..PromptCodeSystemCode(pJSONData.url, pJSONData.name, pJSONData.description)
        do ..ImportCodesFromConcept(pJSONData, tOIDMapCode)

    } catch tException {
		write "Failed to import CodeSystem "_$this.URL,!
		write tException.AsStatus(),!
		break // Failed
	}

    return $$$OK
}

Method PromptCodeSystemCode(pURL, pCode = "", pDescription = "")
{
    #dim tException as %Exception.StatusException
    #dim tIsUpdate = 0

    try {

        set tOIDMapCode = ##class(HS.Data.OIDMap).GetCodeForURL(pURL, "")
        if (tOIDMapCode'="") {
            
            set tIsUpdate = 1
            write !,"Updating CodeSystem entries: "_tOIDMapCode,!
            if (tOIDMapCode '= pCode) {
                write "Existing entry code '"_tOIDMapCode_"' doesn't match data retrieved '"_pCode_"'. Continuing anyway...",!
            }

        } else {
            set tAutoCode=..Prefix_$piece(pURL, "/", *)
            write !,"Enter a Code for the new CodeSystem "_pURL,!,"["_tAutoCode_"] > "
            read tOIDMapCode,!
            set:(tOIDMapCode="") tOIDMapCode=tAutoCode
        }

        write $case(tIsUpdate, 1:"Updating", :"Adding")_" OIDMap entry for "_pURL,!
        $$$ThrowOnError(##class(HS.Data.OIDMap).CreateOrUpdateOID(tOIDMapCode, "CodeSystem", ,pDescription, ,pURL))

        if (tIsUpdate = 0) {
            write !,"Adding Terminology entry for "_tOIDMapCode,!
            $$$ThrowOnError(##class(HS.Registry.CodeSystem).AddCodeSystem(tOIDMapCode, pDescription))
        }

    } catch tException {
		write "Failed to create CodeSystem "_pURL,!
		write tException.AsStatus(),!
		break // Failed
	}

    return tOIDMapCode
}

Method ImportCodesFromConcept(tCodeSystem As %DynamicObject, pCodeSystemName = "") As %Status
{
	#dim tException as %Exception.StatusException

	try {
        
		set tIter = tCodeSystem.concept.%GetIterator()
		
		while tIter.%GetNext(.tKey, .tConcept) {
			
			set tCode = tConcept.code
			set tDisplay = tConcept.display
			if (tCode = tDisplay) && (tConcept.definition'="")
			{
				set tDisplay = tConcept.definition
			}

			write $char(9)_tCode_":"_tDisplay,!

			$$$ThrowOnError(##class(HS.Registry.Codes).AddEditCode(pCodeSystemName, tCode, tDisplay))			
		}

	} catch tException {
		write "Failed to import CodeSystem "_pCodeSystemName,!
		write tException.AsStatus(),!
		break // Failed
	}
	
	return $$$OK
}

Method ProcessValueSet(pJSONData As %DynamicObject, pURL As %String, tHTTPRequest As %Net.HttpRequest)
{
    #dim tException as %Exception.StatusException

	try {

        set tIncludeIter = pJSONData.compose.include.%GetIterator()
		while tIncludeIter.%GetNext(.tKey, .tIncludeItem) {

            // Workaround to import a each of the codesystems contained in a valueset as the valueset.name
            set tIncludeItem.system = pJSONData.name

            if (tIncludeItem.concept '= "") {
                set tOIDMapCode = ##class(HS.Data.OIDMap).GetCodeForURL(tIncludeItem.system, "")
                if (tOIDMapCode="") {
                    //write !,"CodeSystem unknown please create an entry in the OIDMap first (code and url required). "_tIncludeItem.system,!
                    set tOIDMapCode = ..PromptCodeSystemCode(tIncludeItem.system)
                }

                do ..ImportCodesFromConcept(tIncludeItem, tOIDMapCode)
            }

            // TODO: look into 'expansion' as well!

		}
    } catch tException {
		write "Failed to import ValueSet "_pURL,!
		write tException.AsStatus(),!
		break // Failed
	}

    return $$$OK
}

Method ProcessConceptMap(pJSONData As %DynamicObject)
{
    #dim tException as %Exception.StatusException

	try {

        set tGroupIter = pJSONData.group.%GetIterator()
		while tGroupIter.%GetNext(.tKey, .tGroupItem) {

			set tFromCodeSystem = ##class(HS.Data.OIDMap).GetCodeForURL(tGroupItem.source,"")
            if (tFromCodeSystem="") {
                set tFromCodeSystem = ..PromptCodeSystemCode(tGroupItem.source)
            }
            set tFromCodeSystemUpper = $zcvt(tFromCodeSystem, "U")

            set tToCodeSystem = ##class(HS.Data.OIDMap).GetCodeForURL(tGroupItem.target,"")
            if (tToCodeSystem="") {
                set tToCodeSystem = ..PromptCodeSystemCode(tGroupItem.target)
            }
            set tToCodeSystemUpper = $zcvt(tToCodeSystem, "U")

            set tElementIter = tGroupItem.element.%GetIterator()
            while tElementIter.%GetNext(.tKey, .tElementItem) {
                set tFromCode   = tElementItem.code
                if (tFromCode="") {
                    write "'From' code missing, skipping!"_tElementItem.%ToJSON(),!
                    continue
                }
                set tToCode     = tElementItem.target.%Get(0).code
                if (tToCode="") {
                    write "'To' code missing, skipping!"_tElementItem.%ToJSON(),!
                    continue
                }
                
                set tToDesc     = tElementItem.target.%Get(0).display

                set tMapId = tFromCodeSystemUpper_"||"_tToCodeSystemUpper_"||"_$zcvt(tFromCode, "U")

                if ##class(HS.Registry.TranslationMap).%ExistsId(tMapId) {
                    set tMap = ##class(HS.Registry.TranslationMap).%OpenId(tMapId)
                } else {
                    set tMap = ##class(HS.Registry.TranslationMap).%New()
                    set tMap.FromCodeSystem = tFromCodeSystem
                    set tMap.ToCodeSystem   = tToCodeSystem
                    set tMap.FromCode       = tFromCode
                }

                $$$ThrowOnError(##class(HS.Registry.Codes).AddEditCode(tFromCodeSystem, tFromCode, ""))
                $$$ThrowOnError(##class(HS.Registry.Codes).AddEditCode(tToCodeSystem, tToCode, ""))

                set tMap.ToCode         = tToCode
                set tMap.ToDescription  = tToDesc
                do tMap.%Save()

                write tFromCodeSystem_$c(9)_tToCodeSystem_$c(9)_tFromCode_$c(9)_tToCode,!
            }
        }

    } catch tException {
		write "Failed to import ConceptMap "_$this.URL,!
		write tException.AsStatus(),!
		break // Failed
	}

    return $$$OK
}

ClassMethod FetchData(pURL = "", pForceUTF8 As %Boolean = 0, Output tRequest As %Net.HttpRequest) As %Stream.GlobalCharacter
{
    #dim tException as %Exception.StatusException
	#dim tStream as %Stream.TmpCharacter = ##class(%Stream.TmpCharacter).%New()

    set tRequest = ##class(%Net.HttpRequest).%New()

    try {

		if ($extract(pURL,1,5)="https") {
			set tRequest.SSLCheckServerIdentity = 0
        	set tRequest.Https = 1
        	set tRequest.SSLConfiguration = ..#SSLConfiguration
		}

        set tRequest.Server = $piece(pURL,  "/", 3)
		set tRequest.Location = $piece($piece(pURL,  "/", 4, *), "?")
        set tRequest.ContentType = "application/fhir+json; charset=utf-8"
        do tRequest.SetHeader("Accept", "application/json") // "*/*"

		if (pURL [ "?") {
			set tParams = $piece(pURL, "?", 2)
			for tIter = 1:1:$length(pURL, "&") {
				set tParam = $piece(tParams, "&", tIter)
				do tRequest.SetParam($piece(tParam, "=", 1), $piece(tParam, "=", 2))
			}
		}

        $$$ThrowOnError(tRequest.Get())

		/// Convert to UTF-8
		set tFileBinaryGzip = tRequest.HttpResponse.Data
		do {
            if (pForceUTF8=1) {
			    do tStream.Write($ZCVT(tFileBinaryGzip.Read(),"I","UTF8"))
            } else {
                do tStream.Write(tFileBinaryGzip.Read())
            }
		} while 'tFileBinaryGzip.AtEnd

    } catch tException {
        write tException.AsStatus()
        break // FetchData() failed
    }

	return tStream
}

Method ProcessBundle(pJSONData As %DynamicObject)
{
    set tEntryIter = pJSONData.entry.%GetIterator()

	while tEntryIter.%GetNext(.tKey, .tEntryItem) {
        do ..Dispatch(tEntryItem.resource)
    }
}

Method Catch(pJSONData As %DynamicObject)
{
    write !,"<CATCH> pJSONData can't be processed.",!
    break // zw $this.JSONData
}

}
