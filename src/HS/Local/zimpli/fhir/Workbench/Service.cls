Class HS.Local.zimpli.fhir.Workbench.Service Extends %RegisteredObject
{

ClassMethod PersistValidationIssues(pMPIID As %String, pValidationConvention As %String, pRunId As %String, pValidation As %DynamicObject) As %Status
{
    Set tSC = $$$OK
    Set tIssues = ""
    Set tPersistedCount = 0

    If '$IsObject(pValidation) {
        Quit $$$ERROR($$$GeneralError,"Validation payload is not an object")
    }

    If pValidation.%IsDefined("issues") {
        Set tIssues = pValidation.issues
    } Else {
        // Log what fields are actually present
        Set tKeys = ""
        Set tIter = pValidation.%GetIterator()
        While tIter.%GetNext(.tKey, .tVal) {
            Set tKeys = tKeys_tKey_", "
        }
        Quit $$$ERROR($$$GeneralError,"Validation payload missing 'issues' field. Found fields: "_tKeys)
    }

    If '$IsObject(tIssues) {
        Quit $$$ERROR($$$GeneralError,"Validation issues collection missing or invalid")
    }

    For i=0:1:tIssues.%Size()-1 {
        Set tIssue = tIssues.%Get(i)
        Continue:'$IsObject(tIssue)

        Set tNormalized = ..NormalizeValidationIssue(tIssue)
        Set tSC = ##class(HS.Local.zimpli.fhir.Workbench.Issue).UpsertFromDynamicIssue(
            pMPIID,
            pValidationConvention,
            pRunId,
            tNormalized
        )
        Quit:$$$ISERR(tSC)
        Set tPersistedCount = tPersistedCount + 1
    }

    Quit:$$$ISERR(tSC) tSC

    // Mark issues that disappeared in this validation run as "Resolved"
    // (only if runId is provided, indicating we're tracking across runs)
    If pRunId'="" {
        Set tSC = ##class(HS.Local.zimpli.fhir.Workbench.Issue).ResolveMissingIssues(
            pMPIID,
            pValidationConvention,
            pRunId
        )
        Quit:$$$ISERR(tSC) tSC
    }

    // Log success
    Do ##class(%SYS.System).WriteToConsoleLog("Workbench: Persisted "_tPersistedCount_" issues for MPIID "_pMPIID)

    Quit $$$OK
}

ClassMethod NormalizeValidationIssue(pIssue As %DynamicObject) As %DynamicObject
{
    Set o = {}

    Set tSeverity = ""
    Set tResourceType = ""
    Set tResourceId = ""
    Set tFHIRPath = ""
    Set tMessage = ""

    // Extract severity
    If pIssue.%IsDefined("severity") Set tSeverity = $ZCONVERT(pIssue.severity,"L")

    // Extract message from "details" field (validator response format)
    If pIssue.%IsDefined("details") {
        Set tMessage = pIssue.details
    } ElseIf pIssue.%IsDefined("message") {
        Set tMessage = pIssue.message
    }

    // Extract FHIRPath from "location" or "expression" field
    If pIssue.%IsDefined("location") {
        Set tFHIRPath = pIssue.location
    } ElseIf pIssue.%IsDefined("fhirPath") {
        Set tFHIRPath = pIssue.fhirPath
    } ElseIf pIssue.%IsDefined("expression") {
        Set tFHIRPath = pIssue.expression
    }

    // Parse resourceType and resourceId from "resourceKey" field (e.g., "Observation/123")
    If pIssue.%IsDefined("resourceKey") {
        Set tResourceKey = pIssue.resourceKey
        If tResourceKey'="" {
            Set tSlashPos = $FIND(tResourceKey,"/")
            If tSlashPos>0 {
                Set tResourceType = $EXTRACT(tResourceKey,1,tSlashPos-2)
                Set tResourceId = $EXTRACT(tResourceKey,tSlashPos,*)
            }
        }
    }

    // Fallback: extract from standalone fields if present
    If tResourceType="", pIssue.%IsDefined("resourceType") {
        Set tResourceType = pIssue.resourceType
    }
    If tResourceId="", pIssue.%IsDefined("resourceId") {
        Set tResourceId = pIssue.resourceId
    }

    Set o.severity = tSeverity
    Set o.resourceType = tResourceType
    Set o.resourceId = tResourceId
    Set o.fhirPath = tFHIRPath
    Set o.message = tMessage
    Set o.causeBucket = ..GuessCauseBucket(tMessage,tFHIRPath)

    Quit o
}

ClassMethod GuessCauseBucket(tMsg As %String, tPath As %String) As %String
{
    Set tMsg = $ZCONVERT($Select($Data(tMsg):tMsg,1:""),"L")
    Set tPath = $ZCONVERT($Select($Data(tPath):tPath,1:""),"L")

    Return $Select(
        (tMsg["unknown code system")!(tMsg["value set")!(tMsg["terminology"): "Terminology",
        (tPath[".system")!(tMsg["system uri")!(tMsg["oid"): "Config",
        (tPath[".display"): "Terminology",
        (tMsg["reference")!(tMsg["required")!(tMsg["cardinality"): "Transform",
        1: "Ambiguous"
    )
}

ClassMethod BuildMinimalSDAContext(pSDA As %String, pResourceType As %String, pFHIRPath As %String = "") As %DynamicObject
{
    Set o = {}
    Set o.resourceType = pResourceType
    Set o.fhirPath = pFHIRPath
    Set o.note = "Raw SDA kept as text; targeted extraction can be added later"
    Set o.preview = $Extract($Get(pSDA),1,4000)
    Quit o
}

ClassMethod ExtractFHIRResourceContext(pFHIR As %DynamicObject, pResourceType As %String, pResourceId As %String = "") As %DynamicObject
{
    Set o = {}
    Set o.resourceType = pResourceType
    Set o.resourceId = pResourceId
    Set o.note = "Matching resource extraction can be improved later"

    If '$IsObject(pFHIR) Quit o
    If '$IsObject(pFHIR.entry) Quit o

    Set tEntries = pFHIR.entry
    For i=0:1:tEntries.%Size()-1 {
        Set tEntry = tEntries.%Get(i)
        Continue:'tEntry.%IsDefined("resource")
        Set tRes = tEntry.resource
        Continue:(tRes.resourceType'=pResourceType)
        If (pResourceId="") || (tRes.id=pResourceId) {
            return tRes
        }
    }

    Quit o
}

ClassMethod BuildInvestigationContext(pResourceType As %String, pFHIRPath As %String = "") As %DynamicObject
{
    Set o = {}
    Set o.resourceType = pResourceType
    Set o.fhirPath = pFHIRPath
    Set o.candidateTransforms = ..FindCandidateTransformsByFHIRType(pResourceType)
    Set o.configHints = ..BuildConfigHints(pFHIRPath)
    Quit o
}

ClassMethod BuildConfigHints(pFHIRPath As %String = "") As %DynamicArray
{
    Set arr = []
    Set tPath = $ZCONVERT($Get(pFHIRPath),"L")

    If tPath[".system" {
        Do arr.%Push({
            "type":"OIDMap",
            "hint":"coding.system problems often point to OID map or URI assignment"
        })
    }

    If tPath[".display" {
        Do arr.%Push({
            "type":"Terminology",
            "hint":"display may come from SDA source or terminology lookup"
        })
    }

    Quit arr
}

ClassMethod FindCandidateTransformsByFHIRType(pFHIRType As %String) As %DynamicArray
{
    Set arr = []
    If pFHIRType="" Quit arr

    Set tFHIRType = $Get(pFHIRType)
    Set tCustomPkg = ##class(HS.FHIR.DTL.Util.API.ExecDefinition).GetCustomDTLPackage()
    Set tSeenDTLs = {}  // Track which DTLs we've already added

    // 1. Scan standard transform registry
    Set tSourceClass = ""
    For {
        Set tSourceClass = $Order(^HS.XF.Transform("SDA3","vR4",tSourceClass))
        Quit:tSourceClass=""

        Set tDTL = ""
        For {
            Set tDTL = $Order(^HS.XF.Transform("SDA3","vR4",tSourceClass,tDTL))
            Quit:tDTL=""
            Continue:'..DTLTargetsFHIRType(tDTL,tFHIRType)

            Set tCondition = $Get(^HS.XF.Transform("SDA3","vR4",tSourceClass,tDTL))
            Set tEffectiveDTL = ..ResolveEffectiveDTL(tDTL)

            Set tItem = {}
            Set tItem.sourceClass = tSourceClass
            Set tItem.baseDTL = tDTL
            Set tItem.effectiveDTL = tEffectiveDTL
            Set tItem.condition = tCondition
            Set tItem.conditionType = ..InterpretCondition(tCondition)
            Set tItem.hasDTLXML = ..HasDTLXML(tEffectiveDTL)
            Set tItem.isCustom = (tCustomPkg '= "") && (tEffectiveDTL '= tDTL)
            Do arr.%Push(tItem)
            Do tSeenDTLs.%Set(tEffectiveDTL, 1)
        }
    }

    // 2. Scan custom DTL package for additional DTLs not in registry
    If tCustomPkg '= "" {
        Set tScanPkg = tCustomPkg_".SDA3.vR4."

        // Query for all DTL classes in the custom package
        // Use PrimarySuper to check direct inheritance, and also check Super for indirect
        Set sql = "SELECT Name FROM %Dictionary.ClassDefinition "
            _"WHERE (PrimarySuper = 'Ens.DataTransformDTL' OR Super [ 'Ens.DataTransformDTL') "
            _"AND Name %STARTSWITH ?"

        Set stmt = ##class(%SQL.Statement).%New()
        Set sc = stmt.%Prepare(sql)
        Quit:$$$ISERR(sc) arr

        Set rs = stmt.%Execute(tScanPkg)

        While rs.%Next() {
            Set tClassName = rs.%Get("Name")

            // Check if this DTL targets the FHIR type
            Continue:'..DTLTargetsFHIRType(tClassName, tFHIRType)

            // Skip if we've already seen this DTL (it was in the registry)
            Continue:tSeenDTLs.%IsDefined(tClassName)

            // Try to determine source class from package structure
            // e.g., HS.Local.MII.FHIR.DTL.SDA3.vR4.Patient.Patient -> Patient
            Set tSourceClass = ..ExtractSourceClassFromDTLPath(tClassName, tCustomPkg)

            Set tItem = {}
            Set tItem.sourceClass = tSourceClass
            Set tItem.baseDTL = tClassName
            Set tItem.effectiveDTL = tClassName
            Set tItem.condition = ""
            Set tItem.conditionType = "custom-only"
            Set tItem.hasDTLXML = ..HasDTLXML(tClassName)
            Set tItem.isCustom = 1
            Do arr.%Push(tItem)
        }
    }

    Quit arr
}

ClassMethod InterpretCondition(pCondition As %String) As %String
{
    If pCondition="" Quit "subtransform"
    If pCondition="1" Quit "top-level"
    Quit "conditional"
}

ClassMethod ExtractSourceClassFromDTLPath(pDTLClassName As %String, pCustomPkg As %String = "") As %String
{
    // Extract source class from DTL path
    // e.g., HS.Local.MII.FHIR.DTL.SDA3.vR4.Patient.Patient -> Patient
    // e.g., HS.FHIR.DTL.SDA3.vR4.Patient.Patient -> Patient

    If pCustomPkg = "" {
        Set pCustomPkg = ##class(HS.FHIR.DTL.Util.API.ExecDefinition).GetCustomDTLPackage()
    }

    // Try custom package first if available
    If pCustomPkg '= "" {
        Set tPrefix = pCustomPkg_".SDA3.vR4."
        If $Extract(pDTLClassName, 1, $Length(tPrefix)) = tPrefix {
            Set tRemainder = $Extract(pDTLClassName, $Length(tPrefix)+1, *)
            // Get first segment after prefix (e.g., "Patient.Patient" -> "Patient")
            Set tSourceClass = $Piece(tRemainder, ".", 1)
            Quit tSourceClass
        }
    }

    // Fallback: try standard package
    Set tPrefix = "HS.FHIR.DTL.SDA3.vR4."
    If $Extract(pDTLClassName, 1, $Length(tPrefix)) = tPrefix {
        Set tRemainder = $Extract(pDTLClassName, $Length(tPrefix)+1, *)
        Set tSourceClass = $Piece(tRemainder, ".", 1)
        Quit tSourceClass
    }

    // Last resort: return last segment before target type
    Set tNumPieces = $Length(pDTLClassName, ".")
    If tNumPieces >= 2 {
        Quit $Piece(pDTLClassName, ".", tNumPieces - 1)
    }

    Quit ""
}

ClassMethod DTLTargetsFHIRType(pDTL As %String, pFHIRType As %String) As %Boolean
{
    If pFHIRType="" Quit 0
    Quit $Extract(pDTL,*-$Length(pFHIRType)+1,*)=pFHIRType
}

ClassMethod ResolveEffectiveDTL(pDTL As %String) As %String
{
    Set useCustom = (##class(HS.FHIR.DTL.Util.API.ExecDefinition).GetCustomDTLPackage() '= "")
    Quit $Select(useCustom: ##class(HS.FHIR.DTL.Util.API.ExecDefinition).GetDTLPackageAndClass(pDTL), 1: pDTL)
}

ClassMethod HasDTLXML(pDTLClassName As %String) As %Boolean
{
    Set tSC = ##class(Ens.Util.URLStream).GetURLStream("xdata://"_pDTLClassName_":DTL",.tXMLStream)
    Quit $$$ISOK(tSC) && $IsObject($Get(tXMLStream))
}

ClassMethod GetDTLXML(pDTLClassName As %String, Output pXML As %String) As %Status
{
    Set pXML = ""
    Set tSC = ##class(Ens.Util.URLStream).GetURLStream("xdata://"_pDTLClassName_":DTL",.tXMLStream)
    Quit:$$$ISERR(tSC) tSC
    Quit:'$IsObject($Get(tXMLStream)) $$$ERROR($$$GeneralError,"DTL XML stream not found")

    While 'tXMLStream.AtEnd {
        Set pXML = pXML_tXMLStream.Read(32000)
    }

    Quit $$$OK
}

ClassMethod ExtractDTLMetadata(pDTLClassName As %String) As %DynamicObject
{
    Set o = {
        "className": (pDTLClassName),
        "hasXML": 0,
        "xmlPreview": "",
        "subtransforms": []
    }

    Set tSC = ..GetDTLXML(pDTLClassName,.tXML)
    Quit:$$$ISERR(tSC) o

    Set o.hasXML = 1
    Set o.xmlPreview = $Extract(tXML,1,4000)

    // Extremely lightweight first pass:
    // find occurrences of sourceClass='...' or class='...'
    Set tPos = 1
    For {
        Set tPos = $Find(tXML,"subtransform",tPos)
        Quit:'tPos
        Set tSlice = $Extract(tXML,tPos-50,tPos+500)
        Do o.subtransforms.%Push(tSlice)
    }

    Quit o
}

ClassMethod GetAllIssuesForMPIID(pMPIID As %String, pValidationConvention As %String = "") As %DynamicArray
{
    Set arr = []
    Set sql = "SELECT ResourceType, ResourceId FROM HS_Local_zimpli_fhir_Workbench.Issue WHERE MPIID = ? AND Status = 'Open'"

    If pValidationConvention'="" {
        Set sql = sql_" AND ValidationConvention = ?"
    }

    Set stmt = ##class(%SQL.Statement).%New()
    Set sc = stmt.%Prepare(sql)
    Quit:$$$ISERR(sc) arr

    If pValidationConvention'="" {
        Set rs = stmt.%Execute(pMPIID, pValidationConvention)
    } Else {
        Set rs = stmt.%Execute(pMPIID)
    }

    While rs.%Next() {
        Set obj = {}
        Set obj.resourceType = rs.%Get("ResourceType")
        Set obj.resourceId = rs.%Get("ResourceId")
        Do arr.%Push(obj)
    }

    Quit arr
}

ClassMethod GetIssueListAsJSON(pMPIID As %String, pValidationConvention As %String = "", pStatus As %String = "Open") As %DynamicArray
{
    Set arr = []
    Set sql = "SELECT ID FROM HS_Local_zimpli_fhir_Workbench.Issue WHERE MPIID = ?"

    If pValidationConvention'="" {
        Set sql = sql_" AND ValidationConvention = ?"
    }

    If pStatus'="" {
        Set sql = sql_" AND Status = ?"
    }

    Set sql = sql_" ORDER BY LastSeenAt DESC"

    Set stmt = ##class(%SQL.Statement).%New()
    Set sc = stmt.%Prepare(sql)
    Quit:$$$ISERR(sc) arr

    If (pValidationConvention'="")&&(pStatus'="") {
        Set rs = stmt.%Execute(pMPIID,pValidationConvention,pStatus)
    } ElseIf pValidationConvention'="" {
        Set rs = stmt.%Execute(pMPIID,pValidationConvention)
    } ElseIf pStatus'="" {
        Set rs = stmt.%Execute(pMPIID,pStatus)
    } Else {
        Set rs = stmt.%Execute(pMPIID)
    }

    While rs.%Next() {
        Set obj = ##class(HS.Local.zimpli.fhir.Workbench.Issue).%OpenId(rs.%Get("ID"))
        Continue:'$IsObject(obj)

        Do arr.%Push({
            "id": (obj.%Id()),
            "mpiid": (obj.MPIID),
            "severity": (obj.Severity),
            "resourceType": (obj.ResourceType),
            "resourceId": (obj.ResourceId),
            "fhirPath": (obj.FHIRPath),
            "message": (obj.Message),
            "status": (obj.Status),
            "causeBucket": (obj.CauseBucket),
            "ignoreReason": (obj.IgnoreReason),
            "firstSeenAt": (obj.FirstSeenAt),
            "lastSeenAt": (obj.LastSeenAt),
            "resolvedAt": (obj.ResolvedAt)
        })
    }

    Quit arr
}

ClassMethod SetIssueStatus(pIssueId As %Integer, pStatus As %String, pIgnoreReason As %String = "") As %Status
{
    Set obj = ##class(HS.Local.zimpli.fhir.Workbench.Issue).%OpenId(pIssueId)
    Quit:'$IsObject(obj) $$$ERROR($$$GeneralError,"Issue not found")

    Set obj.Status = pStatus
    Set obj.LastSeenAt = $ZDATETIME($HOROLOG,3,1,3)

    If pStatus="Ignored" {
        Set obj.IgnoreReason = pIgnoreReason
    } ElseIf pStatus="Resolved" {
        Set obj.ResolvedAt = $ZDATETIME($HOROLOG,3,1,3)
    } Else {
        Set obj.IgnoreReason = ""
    }

    Quit obj.%Save()
}

ClassMethod InvestigateIssue(pIssueId As %Integer) As %DynamicObject
{
    Set o = {"ok":0}

    Set issue = ##class(HS.Local.zimpli.fhir.Workbench.Issue).%OpenId(pIssueId)
    If '$IsObject(issue) {
        Set o.error = "Issue not found"
        Quit o
    }

    Set o.ok = 1
    Set o.issueId = pIssueId
    Set o.resourceType = issue.ResourceType
    Set o.resourceId = issue.ResourceId
    Set o.fhirPath = issue.FHIRPath
    Set o.message = issue.Message
    Set o.causeBucket = issue.CauseBucket
    Set o.candidateTransforms = ..FindCandidateTransformsByFHIRType(issue.ResourceType)
    Quit o
}

/// Deletes all issues for a given MPIID
/// Called when ReloadPatient() is triggered to clear stale validation issues
ClassMethod DeleteIssuesForMPIID(pMPIID As %String) As %Status
{
    If pMPIID="" Quit $$$OK

    &sql(DELETE FROM HS_Local_zimpli_fhir_Workbench.Issue WHERE MPIID = :pMPIID)

    If SQLCODE=0 Quit $$$OK
    If SQLCODE=100 Quit $$$OK  // No rows found is OK

    Quit $$$ERROR($$$GeneralError,"Failed to delete issues for MPIID "_pMPIID_": SQLCODE="_SQLCODE)
}

/// Returns backend tool links from Service Registry
/// Queries entries like: zimpliFHIR:links:DTLEditor
/// Can be called directly or via FHIRNetwork.GetBackendToolLinksJSON()
ClassMethod GetBackendToolLinks() As %DynamicArray
{
    Set tPrefix = "zimpliFHIR:links:"

    Set sql = "SELECT name, url FROM HS_Registry_Service.HTTP"
        _" WHERE type='HTTP' AND status=1"
        _" AND name %STARTSWITH '"_tPrefix_"'"
        _" ORDER BY name"

    Set stmt = ##class(%SQL.Statement).%New()
    Set sc = stmt.%Prepare(sql)

    Set arr = []
    Quit:$$$ISERR(sc) arr

    Set rs = stmt.%Execute()

    While rs.%Next() {
        Set tName = rs.%Get("name")
        Set tURL = rs.%Get("url")
        Set tCode = $Piece(tName, tPrefix, 2)
        Continue:tCode=""

        Do arr.%Push({
            "code": (tCode),
            "url": (tURL),
            "label": (..GetBackendToolLabel(tCode))
        })
    }

    Quit arr
}

/// Returns display label for backend tool code
ClassMethod GetBackendToolLabel(pCode As %String) As %String
{
    If pCode="DTLEditor" Quit "DTL Editor"
    If pCode="DTLViewer" Quit "DTL Viewer"
    If pCode="OIDMap" Quit "OID Map"
    If pCode="Terminology" Quit "Terminology Viewer"
    If pCode="CodeRegistry" Quit "Code Registry"
    Quit pCode
}

/// Returns grouped resource summary for overview pane
/// Groups by ResourceType, with Observations further grouped by subtype
/// Output: {
///   "groups": [
///     {
///       "resourceType": "Patient",
///       "displayName": "Patient",
///       "errorCount": 3,
///       "warningCount": 9,
///       "resources": [
///         {"id": "100000037", "errorCount": 3, "warningCount": 9}
///       ]
///     },
///     {
///       "resourceType": "Observation",
///       "subType": "vital-signs",
///       "displayName": "Vital Signs",
///       "errorCount": 0,
///       "warningCount": 23,
///       "resources": [...]
///     }
///   ]
/// }
ClassMethod GetResourceGroupSummary(pMPIID As %String, pValidationConvention As %String = "") As %DynamicObject
{
    Set tResult = {"groups":[]}
    Set tGroups = {}

    // Query all open issues for this MPIID
    Set sql = "SELECT ResourceType, ResourceId, Severity, COUNT(*) AS IssueCount"
        _" FROM HS_Local_zimpli_fhir_Workbench.Issue"
        _" WHERE MPIID = ? AND Status = 'Open'"

    If pValidationConvention'="" {
        Set sql = sql_" AND ValidationConvention = ?"
    }

    Set sql = sql_" GROUP BY ResourceType, ResourceId, Severity"

    Set stmt = ##class(%SQL.Statement).%New()
    Set sc = stmt.%Prepare(sql)
    Quit:$$$ISERR(sc) tResult

    If pValidationConvention'="" {
        Set rs = stmt.%Execute(pMPIID, pValidationConvention)
    } Else {
        Set rs = stmt.%Execute(pMPIID)
    }

    // Aggregate by resource type and resource ID
    While rs.%Next() {
        Set tResourceType = rs.%Get("ResourceType")
        Set tResourceId = rs.%Get("ResourceId")
        Set tSeverity = $ZCONVERT(rs.%Get("Severity"),"L")
        Set tIssueCount = rs.%Get("IssueCount")

        Continue:tResourceType=""

        Set tKey = tResourceType

        // Initialize group if not exists
        If 'tGroups.%IsDefined(tKey) {
            Set tGroup = {
                "resourceType": (tResourceType),
                "subType": "",
                "displayName": (tResourceType),
                "errorCount": 0,
                "warningCount": 0,
                "informationCount": 0,
                "totalCount": 0,
                "resources": []
            }
            Do tGroups.%Set(tKey, tGroup)
        }

        Set tGroup = tGroups.%Get(tKey)

        // Update counts
        If tSeverity="error" {
            Set tGroup.errorCount = tGroup.errorCount + tIssueCount
        } ElseIf tSeverity="warning" {
            Set tGroup.warningCount = tGroup.warningCount + tIssueCount
        } Else {
            Set tGroup.informationCount = tGroup.informationCount + tIssueCount
        }
        Set tGroup.totalCount = tGroup.totalCount + tIssueCount

        Do tGroups.%Set(tKey, tGroup)
    }

    // Convert to array and sort
    Set tIter = tGroups.%GetIterator()
    While tIter.%GetNext(.tKey, .tGroup) {
        Do tResult.groups.%Push(tGroup)
    }

    Quit tResult
}

/// Gets detailed resource list for a specific group
/// Returns array of resources with issue counts
ClassMethod GetResourcesForGroup(pMPIID As %String, pResourceType As %String, pValidationConvention As %String = "") As %DynamicArray
{
    Set tResult = []

    Set sql = "SELECT ResourceId, Severity, COUNT(*) AS IssueCount"
        _" FROM HS_Local_zimpli_fhir_Workbench.Issue"
        _" WHERE MPIID = ? AND ResourceType = ? AND Status = 'Open'"

    If pValidationConvention'="" {
        Set sql = sql_" AND ValidationConvention = ?"
    }

    Set sql = sql_" GROUP BY ResourceId, Severity"

    Set stmt = ##class(%SQL.Statement).%New()
    Set sc = stmt.%Prepare(sql)
    Quit:$$$ISERR(sc) tResult

    If pValidationConvention'="" {
        Set rs = stmt.%Execute(pMPIID, pResourceType, pValidationConvention)
    } Else {
        Set rs = stmt.%Execute(pMPIID, pResourceType)
    }

    Set tResources = {}

    While rs.%Next() {
        Set tResourceId = rs.%Get("ResourceId")
        Set tSeverity = $ZCONVERT(rs.%Get("Severity"),"L")
        Set tIssueCount = rs.%Get("IssueCount")

        If 'tResources.%IsDefined(tResourceId) {
            Set tRes = {
                "id": (tResourceId),
                "errorCount": 0,
                "warningCount": 0,
                "informationCount": 0,
                "totalCount": 0
            }
            Do tResources.%Set(tResourceId, tRes)
        }

        Set tRes = tResources.%Get(tResourceId)

        If tSeverity="error" {
            Set tRes.errorCount = tRes.errorCount + tIssueCount
        } ElseIf tSeverity="warning" {
            Set tRes.warningCount = tRes.warningCount + tIssueCount
        } Else {
            Set tRes.informationCount = tRes.informationCount + tIssueCount
        }
        Set tRes.totalCount = tRes.totalCount + tIssueCount

        Do tResources.%Set(tResourceId, tRes)
    }

    // Convert to array
    Set tIter = tResources.%GetIterator()
    While tIter.%GetNext(.tKey, .tRes) {
        Do tResult.%Push(tRes)
    }

    Quit tResult
}

}
