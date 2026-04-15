/**
* JSON validation endpoint for zimpliFHIR.
*
* Accepts a POSTed JSON payload containing:
* {
*   "validationProfile": "core|mii|isik|...",
*   "bundle": { ...FHIR Bundle... }
* }
*
* Optional GET with ?action=catalog returns the configured validation profiles
* from the HTTP service registry using the configured prefix.
*
* Although this class extends %CSP.Page per project convention,
* the validation response itself is written as JSON via %response/write.
*
* Cleaned up to avoid large-string truncation by keeping request/response
* payloads as streams as long as possible.
*
* @version 1.2 2026-03-24
* @author Brandon Thomas
*/

Class HS.Local.zimpli.fhir.API.ValidateFHIR Extends %CSP.Page
{

/// Dispatching Business Service
Parameter BusinessService = "HS.Local.zimpli.fhir.API.TestService";

Parameter BusinessOperation = "HS.Local.zimpli.fhir.Production.HTTPOperation";

/// Prefix used to discover configured validation endpoints in service registry
Parameter ValidationEndpointPrefix = "zimpliFHIR:validation:";

/// Whether to include trimmed OperationOutcome.text.div-derived text in response
Parameter IncludeOutcomeText = 0;

/// Main entry point.
/// GET  ?action=catalog   -> returns available validation profiles
/// POST                    -> validates posted bundle against selected profile
ClassMethod OnPage() As %Status
{
	#dim tMethod As %String
	#dim tAction As %String

	set tMethod = $zconvert(%request.Method, "L")
	set tAction = $zconvert($get(%request.Data("action",1)), "L")

	if (tMethod = "get"), (tAction = "catalog") {
		quit ..HandleCatalogRequest()
	}

	if tMethod '= "post" {
		quit ..WriteErrorResponse("Only POST is supported for validation. Use GET ?action=catalog for profile discovery.", 405)
	}

	quit ..HandleValidationRequest()
}

/// No stream cleanup currently needed.
ClassMethod OnPostHTTP() As %Status [ ServerOnly = 1 ]
{
	quit $$$OK
}

/// Returns catalog of configured validation profiles.
/// Output:
/// {
///   "profiles": [
///     {"code":"core","serviceName":"zimpliFHIR:validation:core"},
///     ...
///   ]
/// }
ClassMethod HandleCatalogRequest() As %Status
{
	#dim tCatalog As %DynamicObject

	set tCatalog = ..GetValidationCatalogObject()
	quit ..WriteDynamicResponse(tCatalog, 200)
}

/// Handles validation POST request.
ClassMethod HandleValidationRequest() As %Status
{
	#dim tRequestBody As %Stream.Object
	#dim tReq As %DynamicObject
	#dim tProfile As %String
	#dim tBundle As %DynamicObject
	#dim tServiceName As %String
	#dim tOutcomeJSON As %Stream.Object
	#dim tResult As %DynamicObject

	set tRequestBody = ..ReadRequestBody()
	if '$isobject(tRequestBody) {
		return ..WriteErrorResponse("Request body could not be read.", 400)
	}

	if tRequestBody.Size = 0 {
		return ..WriteErrorResponse("Request body is empty.", 400)
	}

	try {
		do tRequestBody.Rewind()
		set tReq = {}.%FromJSON(tRequestBody)
	} catch tEx {
		return ..WriteErrorResponse("Request body is not valid JSON: "_tEx.DisplayString(), 400)
	}

	if '$isobject(tReq) {
		return ..WriteErrorResponse("Request body could not be parsed as a JSON object.", 400)
	}

	set tProfile = $zconvert(tReq.validationProfile, "L")
	if tProfile = "" {
		return ..WriteErrorResponse("Missing required property 'validationProfile'.", 400)
	}

	if '$isobject(tReq.bundle) {
		return ..WriteErrorResponse("Missing required property 'bundle'.", 400)
	}
	set tBundle = tReq.bundle

	if tBundle.resourceType '= "Bundle" {
		return ..WriteErrorResponse("Property 'bundle' must be a FHIR Bundle resource.", 400)
	}

	set tServiceName = ..ResolveValidationService(tProfile)
	if tServiceName = "" {
		return ..WriteErrorResponse("No active validation service configured for profile '"_tProfile_"'.", 404)
	}

	set tOutcomeJSON = ..GetValidationOutcomeJSON(tProfile, tServiceName, tBundle)
	if '$isobject(tOutcomeJSON) {
		return ..WriteErrorResponse("Validation returned no readable response.", 502)
	}
	if tOutcomeJSON.Size = 0 {
		return ..WriteErrorResponse("Validation returned an empty response.", 502)
	}

	try {
		set tResult = ..NormalizeValidationResponse(tProfile, tBundle, tOutcomeJSON)
	} catch tEx {
		return ..WriteErrorResponse("Validation response could not be normalized: "_tEx.DisplayString(), 500)
	}

	return ..WriteDynamicResponse(tResult, 200)
}

/// Reads raw request body from %request.Content into a temp character stream.
ClassMethod ReadRequestBody() As %Stream.TmpCharacter
{
	#dim tBody As %Stream.TmpCharacter

	set tBody = ##class(%Stream.TmpCharacter).%New()

	if '$isobject(%request.Content) {
		quit tBody
	}

	do %request.Content.Rewind()
	do tBody.CopyFrom(%request.Content)
	do tBody.Rewind()

	quit tBody
}

/// Queries HTTP service registry and returns dynamic catalog object.
ClassMethod GetValidationCatalogObject() As %DynamicObject
{
	#dim tObj As %DynamicObject
	#dim tArr As %DynamicArray
	#dim tStatement As %String
	#dim tResultSet As %SQL.StatementResult
	#dim tName As %String
	#dim tProfile As %String
	#dim tEntry As %DynamicObject

	set tObj = {}
	set tArr = []

	set tStatement = "select name from HS_Registry_Service.HTTP"
		_" where type='HTTP' and status=1"
		_" and name %STARTSWITH '"_..#ValidationEndpointPrefix_"'"
		_" order by name"

	set tResultSet = ##class(%SQL.Statement).%ExecDirect(, tStatement)

	while tResultSet.%Next() {
		set tName = tResultSet.%GetData(1)
		set tProfile = $piece(tName, ..#ValidationEndpointPrefix, 2)
		continue:tProfile=""

		set tEntry = {}
		set tEntry.code = tProfile
		set tEntry.serviceName = tName
		do tArr.%Push(tEntry)
	}

	set tObj.profiles = tArr
	quit tObj
}

/// Resolves requested profile to active HTTP service registry entry.
/// Returns "" if none is configured.
ClassMethod ResolveValidationService(pProfile As %String) As %String
{
	#dim tProfile As %String
	#dim tName As %String
	#dim tStatement As %String
	#dim tResultSet As %SQL.StatementResult

	set tProfile = $zconvert($get(pProfile), "L")
	if tProfile = "" {
		quit ""
	}

	set tName = ..#ValidationEndpointPrefix _ tProfile

	set tStatement = "select top 1 name from HS_Registry_Service.HTTP"
		_" where type='HTTP' and status=1"
		_" and name = ?"

	set tResultSet = ##class(%SQL.Statement).%ExecDirect(, tStatement, tName)
	if tResultSet.%Next() {
		quit tResultSet.%GetData(1)
	}

	quit ""
}

/// Calls backend business service and returns raw validation response JSON as a stream.
ClassMethod GetValidationOutcomeJSON(pProfile As %String, pServiceName As %String, pBundle As %DynamicObject) As %Stream.Object
{
	#dim tService As Ens.BusinessService
	#dim tRequest As EnsLib.REST.GenericMessage
	#dim tResponse As EnsLib.REST.GenericMessage
	#dim tSC As %Status
	#dim tBody As %Stream.TmpCharacter
	#dim tOutStream As %Stream.TmpCharacter

	set tBody = ##class(%Stream.GlobalCharacter).%New()
	do pBundle.%ToJSON(tBody)
	do tBody.Rewind()

	set tHeaders("EndPoint") = pServiceName
	set tHeaders("Method") = "POST"
	set tHeaders("Location") = "?profile=http://hl7.org/fhir/StructureDefinition/Bundle"
	set tHeaders("ContentType") = "application/fhir+json"
	set tHeaders("Accept") = "application/json"

	set tRequest = ##class(EnsLib.REST.GenericMessage).%New(tBody)
	for {
		set tHeader = $order(tHeaders($get(tHeader)))  quit:(tHeader="")
		do tRequest.HTTPHeaders.SetAt(tHeaders(tHeader), tHeader)
	}
	

	set tSC = ##class(Ens.Director).CreateBusinessService(..#BusinessService, .tService)
	do:$$$ISERR(tSC) ..ThrowStatus(tSC)

	set tSC = tService.SendRequestSync(..#BusinessOperation, tRequest, .tResponse)
	do:$$$ISERR(tSC) ..ThrowStatus(tSC)

	if '$isobject(tResponse) {
		quit ""
	}

	// GenericMessage response payload is in Stream
	if $isobject(tResponse.Stream) {
		do tResponse.Stream.Rewind()
		quit tResponse.Stream
	}

	// Fallback: copy empty/other response safely into a tmp stream
	set tOutStream = ##class(%Stream.TmpCharacter).%New()
	quit tOutStream
}

/// Normalizes raw OperationOutcome JSON into a frontend-friendly structure:
/// {
///   "summary": {...},
///   "resources": { "Observation/123": {...}, ... },
///   "issues": [...],
///   "profile": "mii"
/// }
ClassMethod NormalizeValidationResponse(pProfile As %String, pBundle As %DynamicObject, pOutcomeJSON As %Stream.Object) As %DynamicObject
{
	#dim tOutcome As %DynamicObject
	#dim tResult As %DynamicObject
	#dim tResources As %DynamicObject
	#dim tAllIssues As %DynamicArray
	#dim tIndex As %DynamicObject
	#dim tEntryIndex As %DynamicObject
	#dim tEntryCount As %Integer
	#dim tIssueCount As %Integer
	#dim tOkCount As %Integer
	#dim i As %Integer
	#dim tIssue As %DynamicObject
	#dim tNormIssue As %DynamicObject
	#dim tResourceKey As %String
	#dim tSeverity As %String
	#dim tRes As %DynamicObject
	#dim tSummary As %DynamicObject
	#dim tKeys As %Iterator.Object
	#dim tKey As %String

	do pOutcomeJSON.Rewind()
	set tOutcome = {}.%FromJSON(pOutcomeJSON)

	set tResult = {}
	set tResources = {}
	set tAllIssues = []
	set tIndex = ..BuildBundleResourceIndex(pBundle)
	set tEntryIndex = ..BuildBundleEntryIndex(pBundle)

	/// Seed all resources as OK
	set tKeys = tIndex.%GetIterator()
	while tKeys.%GetNext(.tKey, .tRes) {
		do tResources.%Set(tKey, ..CreateInitialResourceValidationNode(tRes, "ok"))
	}

	set tIssueCount = 0

	if $isobject(tOutcome.issue) {
		for i=0:1:tOutcome.issue.%Size()-1 {
			set tIssue = tOutcome.issue.%Get(i)
			continue:'$isobject(tIssue)

			set tNormIssue = ..NormalizeIssue(tIssue, tEntryIndex)
			do tAllIssues.%Push(tNormIssue)
			set tIssueCount = tIssueCount + 1

			set tSeverity = $zconvert(tNormIssue.severity, "L")
			set tResourceKey = tNormIssue.resourceKey
			if tResourceKey = "" {
				set tResourceKey = "__bundle__"
			}

			if 'tResources.%IsDefined(tResourceKey) {
				do tResources.%Set(tResourceKey, ..CreateInitialResourceValidationNode(, ..MapFHIRSeverity(tSeverity)))
			}

			set tRes = tResources.%Get(tResourceKey)
			do tRes.issues.%Push(tNormIssue)
			set tRes.issueCount = tRes.issueCount + 1
			set tRes.severity = ..MaxSeverity(tRes.severity, ..MapFHIRSeverity(tSeverity))
			do tResources.%Set(tResourceKey, tRes)
		}
	}

	set tEntryCount = 0
	set tOkCount = 0
	set tKeys = tResources.%GetIterator()
	while tKeys.%GetNext(.tKey, .tRes) {
		continue:tKey="__bundle__"
		set tEntryCount = tEntryCount + 1
		if tRes.severity="ok" {
			set tOkCount = tOkCount + 1
		}
	}

	set tSummary = {}
	set tSummary.profile = pProfile
	set tSummary.resourceCount = tEntryCount
	set tSummary.issueCount = tIssueCount
	set tSummary.ok = tOkCount
	set tSummary.warning = ..CountResourcesBySeverity(tResources, "warning")
	set tSummary.error = ..CountResourcesBySeverity(tResources, "error")
	set tSummary.bundleIssueCount = 0

	if tResources.%IsDefined("__bundle__") {
		set tSummary.bundleIssueCount = tResources.%Get("__bundle__").issueCount
	}

	set tSummary.resourceIssueCount = tIssueCount - tSummary.bundleIssueCount
	set tSummary.hasIssues = (tIssueCount>0)

	set tResult.profile = pProfile
	set tResult.summary = tSummary
	set tResult.resources = tResources
	set tResult.issues = tAllIssues

	if ..#IncludeOutcomeText, $isobject(tOutcome.text) {
		set tResult.outcomeText = ..ExtractOutcomeText(tOutcome.text.div)
	}

	quit tResult
}

/// Builds index:
/// {
///   "Observation/3306": {"resourceType":"Observation","id":"3306"},
///   ...
/// }
ClassMethod BuildBundleResourceIndex(pBundle As %DynamicObject) As %DynamicObject
{
	#dim tIndex As %DynamicObject
	#dim i As %Integer
	#dim tEntry As %DynamicObject
	#dim tRes As %DynamicObject
	#dim tKey As %String
	#dim tNode As %DynamicObject

	set tIndex = {}

	if '$isobject(pBundle.entry) {
		quit tIndex
	}

	for i=0:1:pBundle.entry.%Size()-1 {
		set tEntry = pBundle.entry.%Get(i)
		continue:'$isobject(tEntry)
		continue:'$isobject(tEntry.resource)

		set tRes = tEntry.resource
		set tKey = ..GetResourceKey(tRes)
		continue:tKey=""

		set tNode = {}
		set tNode.resourceType = tRes.resourceType
		set tNode.id = tRes.id
		set tNode.fullUrl = tEntry.fullUrl
		do tIndex.%Set(tKey, tNode)
	}

	quit tIndex
}

/// Builds index:
/// {
///   0: "Patient/100000028",
///   1: "Organization/4",
///   ...
/// }
ClassMethod BuildBundleEntryIndex(pBundle As %DynamicObject) As %DynamicObject
{
	#dim tIndex As %DynamicObject
	#dim i As %Integer
	#dim tEntry As %DynamicObject
	#dim tRes As %DynamicObject
	#dim tKey As %String

	set tIndex = {}

	if '$isobject(pBundle.entry) {
		quit tIndex
	}

	for i=0:1:pBundle.entry.%Size()-1 {
		set tEntry = pBundle.entry.%Get(i)
		continue:'$isobject(tEntry)
		continue:'$isobject(tEntry.resource)

		set tRes = tEntry.resource
		set tKey = ..GetResourceKey(tRes)
		continue:tKey=""

		do tIndex.%Set(i, tKey)
	}

	quit tIndex
}

ClassMethod ParseBundleEntryIndexFromExpression(pExpression As %String) As %Integer
{
	#dim tStart As %Integer
	#dim tEnd As %Integer
	#dim tNum As %String

	set tStart = $find(pExpression, "Bundle.entry[")
	if 'tStart quit -1

	set tEnd = $find(pExpression, "]", tStart)
	if 'tEnd quit -1

	set tNum = $extract(pExpression, tStart, tEnd-2)
	if tNum'?1.N quit -1

	quit +tNum
}

/// Resolves issue to a specific resource when possible.
/// 
/// Resource issue:
///   Bundle.entry[n].resource...
///   Bundle.entry[n].resource/*Observation/123*/...
/// 
/// Bundle issue:
///   Bundle.entry[n]
///   Bundle.entry[n].fullUrl
///   Bundle.type
ClassMethod ResolveIssueResourceKey(pIssue As %DynamicObject, pEntryIndex As %DynamicObject) As %String
{
	#dim tExpr As %String
	#dim tKey As %String
	#dim tEntryNo As %Integer

	set tExpr = ..GetIssueExpression(pIssue)
	if tExpr = "" {
		quit ""
	}

	/// 1) Preferred: explicit /*ResourceType/id*/
	set tKey = ..ParseResourceKeyFromExpression(tExpr)
	if tKey'="" {
		quit tKey
	}

	/// 2) Bundle.entry[n].resource...
	if (tExpr["Bundle.entry[") && (tExpr[".resource") {
		set tEntryNo = ..ParseBundleEntryIndexFromExpression(tExpr)
		if (tEntryNo'<0), $isobject(pEntryIndex), pEntryIndex.%IsDefined(tEntryNo) {
			quit pEntryIndex.%Get(tEntryNo)
		}
	}

	quit ""
}

ClassMethod CreateInitialResourceValidationNode(pResourceMeta = "", pSeverity As %String = "ok") As %DynamicObject
{
	#dim tObj As %DynamicObject

	set tObj = {}
	set tObj.severity = pSeverity
	set tObj.issueCount = 0
	set tObj.issues = []

	if $isobject(pResourceMeta) {
		set tObj.resourceType = pResourceMeta.resourceType
		set tObj.id = pResourceMeta.id
	}
		set tObj.fullUrl = pResourceMeta.fullUrl

	quit tObj
}

/// Converts one raw OperationOutcome.issue entry into normalized issue object.
ClassMethod NormalizeIssue(pIssue As %DynamicObject, pEntryIndex As %DynamicObject = "") As %DynamicObject
{
	#dim tObj As %DynamicObject
	#dim tExpr As %String
	#dim tParsedKey As %String

	set tObj = {}

	set tExpr = ..GetIssueExpression(pIssue)
	set tParsedKey = ..ResolveIssueResourceKey(pIssue, pEntryIndex)

	set tObj.severity = $zconvert(pIssue.severity, "L")
	set tObj.code = pIssue.code

	set tObj.details = ""
	if $isobject(pIssue.details) {
		set tObj.details = pIssue.details.text
	}
	if tObj.details="" {
		set tObj.details = pIssue.diagnostics
	}

	set tObj.expression = tExpr
	set tObj.location = ..TrimExpressionToLocation(tExpr)
	set tObj.resourceKey = tParsedKey
	set tObj.source = ..GetIssueExtensionValue(pIssue, "http://hl7.org/fhir/StructureDefinition/operationoutcome-issue-source")
	set tObj.line = +..GetIssueExtensionValue(pIssue, "http://hl7.org/fhir/StructureDefinition/operationoutcome-issue-line")
	set tObj.col = +..GetIssueExtensionValue(pIssue, "http://hl7.org/fhir/StructureDefinition/operationoutcome-issue-col")
	set tObj.messageId = ..GetIssueExtensionValue(pIssue, "http://hl7.org/fhir/StructureDefinition/operationoutcome-message-id")

	quit tObj
}

/// Returns first expression element if present.
ClassMethod GetIssueExpression(pIssue As %DynamicObject) As %String
{
	if $isobject(pIssue.expression), (pIssue.expression.%Size()>0) {
		quit pIssue.expression.%Get(0)
	}
	quit ""
}

/// Reads extension value by canonical URL.
/// Supports common primitive value[x] properties.
ClassMethod GetIssueExtensionValue(pIssue As %DynamicObject, pURL As %String) As %String
{
	#dim i As %Integer
	#dim tExt As %DynamicObject
	#dim tProp As %String

	if '$isobject(pIssue.extension) {
		quit ""
	}

	for i=0:1:pIssue.extension.%Size()-1 {
		set tExt = pIssue.extension.%Get(i)
		continue:'$isobject(tExt)
		continue:(tExt.url'=pURL)

		for tProp = "valueString","valueCode","valueInteger","valueUri","valueCanonical" {
			if tExt.%Get(tProp)'="" {
				return tExt.%Get(tProp)
			}
		}

		return ""
	}

	quit ""
}

/// Parses Bundle expression path such as:
/// Bundle.entry[32].resource/*Observation/3306*/.component[0].code
/// -> Observation/3306
ClassMethod ParseResourceKeyFromExpression(pExpression As %String) As %String
{
	#dim tStart As %Integer
	#dim tEnd As %Integer

	set tStart = $find(pExpression, "/*")
	if 'tStart quit ""

	set tEnd = $find(pExpression, "*/", tStart)
	if 'tEnd quit ""

	quit $extract(pExpression, tStart, tEnd-3)
}

/// Converts full expression into shorter location text relative to resource.
ClassMethod TrimExpressionToLocation(pExpression As %String) As %String
{
	#dim tPos As %Integer

	set tPos = $find(pExpression, "*/.")
	if tPos {
		quit $extract(pExpression, tPos, *)
	}

	set tPos = $find(pExpression, "*/")
	if tPos {
		quit $extract(pExpression, tPos, *)
	}

	/// For Bundle.entry[n].resource without explicit /*...*/,
	/// show a cleaner resource-relative label in UI.
	set tPos = $find(pExpression, ".resource.")
	if tPos {
		quit $extract(pExpression, tPos, *)
	}

	if $extract(pExpression, *-8, *) = ".resource" {
		quit ""
	}

	quit pExpression
}

ClassMethod GetResourceKey(pResource As %DynamicObject) As %String
{
	#dim tType As %String
	#dim tId As %String

	set tType = pResource.resourceType
	set tId = pResource.id

	if (tType="")!(tId="") {
		quit ""
	}

	quit tType_"/"_tId
}

/// Maps FHIR severities to UI states.
ClassMethod MapFHIRSeverity(pSeverity As %String) As %String
{
	set pSeverity = $zconvert(pSeverity, "L")

	if (pSeverity="fatal")!(pSeverity="error") quit "error"
	if pSeverity="warning" quit "warning"
	quit "ok"
}

/// Returns worse of two UI severities.
ClassMethod MaxSeverity(pA As %String, pB As %String) As %String
{
	if ..SeverityRank(pA) > ..SeverityRank(pB) quit pA
	quit pB
}

ClassMethod SeverityRank(pSeverity As %String) As %Integer
{
	set pSeverity = $zconvert(pSeverity, "L")
	if pSeverity="error" quit 3
	if pSeverity="warning" quit 2
	quit 1
}

ClassMethod CountResourcesBySeverity(pResources As %DynamicObject, pSeverity As %String) As %Integer
{
	#dim tCount As %Integer
	#dim tIter As %Iterator.Object
	#dim tKey As %String
	#dim tVal As %DynamicObject

	set tCount = 0
	set tIter = pResources.%GetIterator()
	while tIter.%GetNext(.tKey, .tVal) {
		continue:tKey="__bundle__"
		if tVal.severity = pSeverity {
			set tCount = tCount + 1
		}
	}

	quit tCount
}

/// Best-effort extraction of human summary from XHTML div.
ClassMethod ExtractOutcomeText(pDiv As %String) As %String
{
	#dim tText As %String
	#dim tStart As %Integer
	#dim tEnd As %Integer

	set tText = $get(pDiv)
	if tText = "" quit ""

	set tText = $replace(tText, "&lt;", "<")
	set tText = $replace(tText, "&gt;", ">")
	set tText = $replace(tText, "&amp;", "&")

	for  {
		quit:tText'["<"
		set tStart = $find(tText, "<")
		quit:'tStart
		set tEnd = $find(tText, ">", tStart)
		quit:'tEnd
		set tText = $extract(tText, 1, tStart-2)_$extract(tText, tEnd, *)
	}

	set tText = $zstrip(tText, "<W")
	quit tText
}

/// Writes dynamic object/array JSON response using a stream to avoid large-string limits.
ClassMethod WriteDynamicResponse(pDyn As %DynamicAbstractObject, pStatusCode As %Integer = 200) As %Status
{
	#dim tStream As %Stream.TmpCharacter

	set %response.Status = pStatusCode
	set %response.ContentType = "application/json; charset=utf-8"

	set tStream = ##class(%Stream.TmpCharacter).%New()
	do pDyn.%ToJSON(tStream)
	do tStream.Rewind()

	while 'tStream.AtEnd {
		write tStream.Read()
	}

	quit $$$OK
}

/// Writes error JSON response.
ClassMethod WriteErrorResponse(pMessage As %String, pStatusCode As %Integer = 400) As %Status
{
	#dim tObj As %DynamicObject

	set tObj = {}
	set tObj.error = 1
	set tObj.message = pMessage

	quit ..WriteDynamicResponse(tObj, pStatusCode)
}

/// Throws a status as exception text.
ClassMethod ThrowStatus(pSC As %Status) As %Status
{
	throw ##class(%Exception.StatusException).CreateFromStatus(pSC)
}

}
