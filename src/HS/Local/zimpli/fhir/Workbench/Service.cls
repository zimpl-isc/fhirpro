Class HS.Local.zimpli.fhir.Workbench.Service Extends %RegisteredObject
{

ClassMethod PersistValidationIssues(pMPIID As %String, pValidationConvention As %String, pRunId As %String, pValidation As %DynamicObject) As %Status
{
    Set tSC = $$$OK
    Set tIssues = ""

    If '$IsObject(pValidation) {
        Quit $$$ERROR($$$GeneralError,"Validation payload is not an object")
    }

    If pValidation.%IsDefined("issues") {
        Set tIssues = pValidation.issues
    } Else {
        Set tIssues = []
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
    }

    Quit:$$$ISERR(tSC) tSC

    Quit ##class(HS.Local.zimpli.fhir.Workbench.Issue).ResolveMissingIssues(
        pMPIID,
        pValidationConvention,
        pRunId
    )
}

ClassMethod NormalizeValidationIssue(pIssue As %DynamicObject) As %DynamicObject
{
    Set o = {}

    Set tSeverity = ""
    Set tResourceType = ""
    Set tResourceId = ""
    Set tFHIRPath = ""
    Set tMessage = ""

    If pIssue.%IsDefined("severity") Set tSeverity = $ZCONVERT(pIssue.severity,"L")
    If pIssue.%IsDefined("resourceType") Set tResourceType = pIssue.resourceType
    If pIssue.%IsDefined("resourceId") Set tResourceId = pIssue.resourceId
    If pIssue.%IsDefined("fhirPath") Set tFHIRPath = pIssue.fhirPath
    If pIssue.%IsDefined("message") Set tMessage = pIssue.message

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
    Set tSourceClass = ""

    For {
        Set tSourceClass = $Order(^HS.XF.Transform("SDA3","vR4",tSourceClass))
        Quit:tSourceClass=""

        Set tDTL = ""
        For {
            Set tDTL = $Order(^HS.XF.Transform("SDA3","vR4",tSourceClass,tDTL))
            Quit:tDTL=""
            Continue:'..DTLTargetsFHIRType(tDTL,tFHIRType)

            Set tItem = {}
            Set tItem.sourceClass = tSourceClass
            Set tItem.baseDTL = tDTL
            Set tItem.effectiveDTL = ..ResolveEffectiveDTL(tDTL)
            Set tItem.condition = $Get(^HS.XF.Transform("SDA3","vR4",tSourceClass,tDTL))
            Set tItem.hasDTLXML = ..HasDTLXML(tItem.effectiveDTL)
            Do arr.%Push(tItem)
        }
    }

    Quit arr
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

}
