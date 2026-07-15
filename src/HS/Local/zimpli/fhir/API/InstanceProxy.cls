/**
* General-purpose proxy for actions that must execute on a specific IRIS instance/namespace.
*
* Endpoint pattern:  HS.Local.zimpli.fhir.API.InstanceProxy.cls?action=<action>&<params>
* All responses are JSON:  {"ok": 1, ...}  or  {"ok": 0, "error": "..."}
*
* The ODS instance is resolved from HS_Gateway.Config (Type='F', Flash Gateway) — no manual
* Service Registry entry is required.  On a single-instance dev setup the local $namespace
* switch is used as a fallback when no Flash Gateway endpoint is registered.
*
* Actions:
*   reload          - ReloadPatient in the ODS namespace
*                     Required param:  mpiid=<MPIID>
*   config.gateways      - List all HS.Gateway.Config entries with derived base URL and links
*   config.srEntries     - List all ServiceRegistry HTTP entries starting with "zimpliFHIR:"
*   status.productions   - Production status for all namespaces on this instance (via %SYS.Ensemble.GetStatusAll)
*   status.interop       - Message counts + recent errors for a namespace over the last N hours
*                          Required param: ns=<namespace>   Optional: hours=<1-24> (default 1)
*/

Class HS.Local.zimpli.fhir.API.InstanceProxy Extends %CSP.Page
{

/// Prefix for all zimpliFHIR ServiceRegistry entries
Parameter SRPrefix = "zimpliFHIR:";

ClassMethod OnPage() As %Status
{
    set action = $get(%request.Data("action", 1))

    do %response.SetHeader("Content-Type", "application/json")

    if action = "reload" {
        set mpiid = $get(%request.Data("mpiid", 1))
        set tSC = ..ActionReload(mpiid, .tResult)

    } elseif action = "config.gateways" {
        set tSC = ..ActionConfigGateways(.tResult)

    } elseif action = "config.srEntries" {
        set tSC = ..ActionConfigSREntries(.tResult)

    } elseif action = "status.productions" {
        set tSC = ..ActionStatusProductions(.tResult)

    } elseif action = "status.interop" {
        set tNamespace = $get(%request.Data("ns", 1))
        set tHours     = +$get(%request.Data("hours", 1), 1)
        set tSC = ..ActionStatusInterop(tNamespace, tHours, .tResult)

    } else {
        set tResult = {"ok": 0, "error": ("Unknown action: " _ action)}
        set tSC = $$$OK
    }

    if $$$ISERR(tSC) {
        set tResult = {"ok": 0, "error": ($system.Status.GetErrorText(tSC))}
    }

    write tResult.%ToJSON()
    return $$$OK
}

// ---------------------------------------------------------------------------

// Action: reload

// ---------------------------------------------------------------------------

ClassMethod ActionReload(pMPIID As %String, Output pResult As %DynamicObject) As %Status
{
    set pResult = {"ok": 0, "mpiid": (pMPIID)}

    if pMPIID = "" {
        set pResult.error = "mpiid parameter is required"
        return $$$OK
    }

    try {
        // The browser routes directly to the correct instance, so just execute locally
        set tSC = ..ReloadPatientLocal(pMPIID)
        if $$$ISERR(tSC) {
            set pResult.error = $system.Status.GetErrorText(tSC)
            return $$$OK
        }
        set pResult.ok = 1
        set pResult.message = "ReloadPatient executed successfully"
    } catch ex {
        set pResult.error = ex.DisplayString()
    }

    return $$$OK
}

ClassMethod ReloadPatientLocal(pMPIID As %String) As %Status
{
    return ##class(HS.Local.Impl.Utils.ODS).ReloadPatient(+pMPIID, 1)
}

// ---------------------------------------------------------------------------

// Action: config.gateways

// Returns all gateways with derived base URL and useful links

// ---------------------------------------------------------------------------

ClassMethod ActionConfigGateways(Output pResult As %DynamicObject) As %Status
{
    set pResult = {"ok": 1}
    set tRows = []

    try {
        // Map full Type strings to short codes for the client
        set tTypeMap("Flash Gateway")     = "F"
        set tTypeMap("Edge Gateway")      = "E"
        set tTypeMap("Bus")               = "B"
        set tTypeMap("Access Gateway")    = "A"
        set tTypeMap("Access Gateway 2")  = "A2"
        set tTypeMap("Registry")          = "R"
        set tTypeMap("System Index")      = "S"
        set tTypeMap("Event Log")         = "V"

        set tSQL = "SELECT ID, Name, Type, Status, EndPoint, GatewayNamespace FROM HS_Gateway.Config ORDER BY Type, Name"
        set tRS = ##class(%SQL.Statement).%ExecDirect(, tSQL)
        while tRS.%Next() {
            set tEndpoint  = tRS.%Get("EndPoint")
            set tName      = tRS.%Get("Name")
            set tTypeRaw   = tRS.%Get("Type")
            set tTypeCode  = $get(tTypeMap(tTypeRaw), tTypeRaw)
            set tNamespace = $piece(tName, ":", 2)
            // Registry row has Name="Registry" (no colon) — fall back to GatewayNamespace
            if tNamespace = "" { set tNamespace = tRS.%Get("GatewayNamespace") }
            set tBaseURL   = ..BaseURLFromEndpoint(tEndpoint)

            set tRow = {
                "id":        (tRS.%Get("ID")),
                "name":      (tName),
                "namespace": (tNamespace),
                "type":      (tTypeCode),
                "status":    (tRS.%Get("Status")),
                "endpoint":  (tEndpoint),
                "baseURL":   (tBaseURL)
            }

            // Derive useful links — fall back to synthesizing from the current request when no endpoint
            if tBaseURL = "" && (tNamespace '= "") {
                set tBaseURL = ..BaseURLFromRequest(tNamespace)
            }
            if tBaseURL '= "" {
                set tLinks = {
                    "productionNew": (tBaseURL _ "ui/interop/interop-editor/index.html?$NAMESPACE=" _ tNamespace),
                    "productionOld": (tBaseURL _ "EnsPortal.ProductionConfig.zen?$NAMESPACE=" _ tNamespace),
                    "dtlEditor":     (tBaseURL _ "EnsPortal.DTLEditor.zen?$NAMESPACE=" _ tNamespace)
                }
                if tTypeCode = "R" {
                    set tLinks.registryHome = tBaseURL _ "HS.UI.Home.cls?$NAMESPACE=" _ tNamespace
                }
                set tRow.links = tLinks
                set tRow.baseURL = tBaseURL
            }

            do tRows.%Push(tRow)
        }
        set pResult.gateways = tRows

    } catch ex {
        set pResult = {"ok": 0, "error": (ex.DisplayString())}
    }

    return $$$OK
}

// ---------------------------------------------------------------------------

// Action: status.productions

// Returns production status for all namespaces on this instance

// ---------------------------------------------------------------------------

ClassMethod ActionStatusProductions(Output pResult As %DynamicObject) As %Status
{
    set pResult = {"ok": 1}
    set tRows = []

    try {
        do ##class(%SYS.Ensemble).GetStatusAll(.tProdInfo)
        set tNS = $order(tProdInfo(""))
        while tNS '= "" {
            set tInfo = tProdInfo(tNS)
            do tRows.%Push({
                "namespace":  (tNS),
                "production": ($list(tInfo, 1)),
                "statusText": ($list(tInfo, 2)),
                "prodState":  ($list(tInfo, 5))
            })
            set tNS = $order(tProdInfo(tNS))
        }
        set pResult.productions = tRows

    } catch ex {
        set pResult = {"ok": 0, "error": (ex.DisplayString())}
    }

    return $$$OK
}

// ---------------------------------------------------------------------------

// Action: status.interop

// 

// Returns message counts and recent errors for a namespace over the last N hours.

// Queries Ens.MessageHeader directly — works in any Interop-enabled namespace.

// 

// Parameters:  ns=<namespace>   (required)

//              hours=<n>        (default 1)

// 

// Returns:

//   { ok, namespace, hours,

//     total, errors, completed, queued,

//     recentErrors: [ {id, timeCreated, source, target, error, sessionId} ]

//   }

// ---------------------------------------------------------------------------

ClassMethod ActionStatusInterop(pNamespace As %String, pHours As %Integer, Output pResult As %DynamicObject) As %Status
{
    set pResult = {"ok": 0}

    if pHours < 1 { set pHours = 1 }
    if pHours > 24 { set pHours = 24 }

    try {
        // Runs in the namespace of the calling URL — no switch needed
        // Use DATEADD/CURRENT_TIMESTAMP in SQL — avoids string-vs-PosixTime mismatch
        set tCutoffExpr = "DATEADD('hh',-" _ pHours _ ",NOW())"

        set tTotal     = 0
        set tErrors    = 0
        set tCompleted = 0
        set tQueued    = 0
        set tErrRows   = []
        
        // Aggregate counts — Status is a string in Ens.MessageHeader
        set tSQL = "SELECT COUNT(*) AS cnt,"
            _ " SUM(CASE WHEN UPPER(Status)='ERROR' THEN 1 ELSE 0 END) AS errs,"
            _ " SUM(CASE WHEN UPPER(Status)='COMPLETED' THEN 1 ELSE 0 END) AS done,"
            _ " SUM(CASE WHEN UPPER(Status) IN ('CREATED','QUEUED','DELIVERED') THEN 1 ELSE 0 END) AS queued"
            _ " FROM Ens.MessageHeader"
            _ " WHERE TimeCreated >= " _ tCutoffExpr
        set tRS = ##class(%SQL.Statement).%ExecDirect(, tSQL)
        if tRS.%SQLCODE < 0 {
            set pResult = {"ok": 0, "error": ("SQL error " _ tRS.%SQLCODE _ ": " _ tRS.%Message), "sql": (tSQL)}
            return $$$OK
        }
        if tRS.%Next() {
            set tTotal     = +tRS.%Get("cnt")
            set tErrors    = +tRS.%Get("errs")
            set tCompleted = +tRS.%Get("done")
            set tQueued    = +tRS.%Get("queued")
        }

        // Recent errors (up to 10, most recent first)
        set tErrSQL = "SELECT TOP 10 ID, TimeCreated, SourceConfigName, TargetConfigName,"
            _ " MessageBodyClassName, SessionId"
            _ " FROM Ens.MessageHeader"
            _ " WHERE UPPER(Status)='ERROR' AND TimeCreated >= " _ tCutoffExpr
            _ " ORDER BY TimeCreated DESC"
        set tErrRS = ##class(%SQL.Statement).%ExecDirect(, tErrSQL)
        while tErrRS.%Next() {
            do tErrRows.%Push({
                "id":          (tErrRS.%Get("ID")),
                "timeCreated": (tErrRS.%Get("TimeCreated")),
                "source":      (tErrRS.%Get("SourceConfigName")),
                "target":      (tErrRS.%Get("TargetConfigName")),
                "bodyClass":   (tErrRS.%Get("MessageBodyClassName")),
                "sessionId":   (tErrRS.%Get("SessionId"))
            })
        }

        set pResult = {
            "ok":           1,
            "namespace":    (pNamespace),
            "hours":        (pHours),
            "total":        (tTotal),
            "errors":       (tErrors),
            "completed":    (tCompleted),
            "queued":       (tQueued),
            "recentErrors": (tErrRows)
        }

    } catch ex {
        set pResult = {"ok": 0, "error": (ex.DisplayString())}
    }

    return $$$OK
}

// ---------------------------------------------------------------------------

// Action: config.srEntries — list all zimpliFHIR: ServiceRegistry entries

// ---------------------------------------------------------------------------

ClassMethod ActionConfigSREntries(Output pResult As %DynamicObject) As %Status
{
    set pResult = {"ok": 1}
    set tRows = []

    try {
        set tSQL = "SELECT name, host, port, url, SSLConfig, HTTPCredentialsConfig, status"
            _ " FROM HS_Registry_Service.HTTP"
            _ " WHERE name %STARTSWITH '" _ ..#SRPrefix _ "'"
            _ " ORDER BY name"
        set tRS = ##class(%SQL.Statement).%ExecDirect(, tSQL)
        while tRS.%Next() {
            do tRows.%Push({
                "name":        (tRS.%Get("name")),
                "host":        (tRS.%Get("host")),
                "port":        (tRS.%Get("port")),
                "url":         (tRS.%Get("url")),
                "ssl":         (tRS.%Get("SSLConfig")),
                "credentials": (tRS.%Get("HTTPCredentialsConfig")),
                "status":      (tRS.%Get("status"))
            })
        }
        set pResult.entries = tRows

    } catch ex {
        set pResult = {"ok": 0, "error": (ex.DisplayString())}
    }

    return $$$OK
}

// ---------------------------------------------------------------------------

// Helpers

// ---------------------------------------------------------------------------

/// Returns the base URL for the first registered gateway of a given short type code.
/// Type codes: F=Flash(ODS), E=Edge, B=Bus, A=Access, A2=Access2, R=Registry
/// Returns "" when no matching gateway is found (single-instance fallback).
ClassMethod GatewayBaseURL(pType As %String) As %String
{
    // Map short code to full Type string stored in HS_Gateway.Config
    set tTypeMap("F")  = "Flash Gateway"
    set tTypeMap("E")  = "Edge Gateway"
    set tTypeMap("B")  = "Bus"
    set tTypeMap("A")  = "Access Gateway"
    set tTypeMap("A2") = "Access Gateway 2"
    set tTypeMap("R")  = "Registry"
    set tTypeMap("S")  = "System Index"
    set tTypeMap("V")  = "Event Log"
    set tTypeFull = $get(tTypeMap(pType), pType)

    set tSQL = "SELECT TOP 1 EndPoint FROM HS_Gateway.Config"
        _ " WHERE Type = ? AND Status = 'Registered' ORDER BY ID"
    set tRS = ##class(%SQL.Statement).%ExecDirect(, tSQL, tTypeFull)
    if tRS.%Next() {
        return ..BaseURLFromEndpoint(tRS.%Get("EndPoint"))
    }
    return ""
}

/// Synthesizes a base URL for a namespace on the current instance using the incoming request.
/// pNamespace should be the actual IRIS namespace (e.g. HSREGISTRY), not the gateway label.
/// e.g. HSREGISTRY on https://host:443/hs20242b/csp/healthshare/zimplifhir/...
///   →  https://host:443/hs20242b/csp/healthshare/hsregistry/
ClassMethod BaseURLFromRequest(pNamespace As %String) As %String
{
    set tScheme = $select(%request.Secure:"https", 1:"http")
    set tHost   = %request.GetCgiEnv("HTTP_HOST")
    set tPath   = %request.URL
    set tMarker = "/csp/healthshare/"
    set tPos    = $find(tPath, tMarker)
    if tPos = 0 return ""
    set tPrefix = $extract(tPath, 1, tPos - 1)   // /hs20242b/csp/healthshare/
    return tScheme _ "://" _ tHost _ tPrefix _ $zconvert(pNamespace, "L") _ "/"
}

/// Strips the /services/... suffix from a gateway EndPoint to produce a base URL.
/// Also fixes two known HealthShare installation artifacts:
///   - Port :0  → stripped (no explicit port, rely on scheme default)
///   - http://  → corrected to match the scheme of the incoming request (avoids mixed-content blocks)
/// e.g. http://host:0/prefix/csp/healthshare/hsods/services/HS.Flash.WebServices.cls
///   →  https://host/prefix/csp/healthshare/hsods/
ClassMethod BaseURLFromEndpoint(pEndpoint As %String) As %String
{
    if pEndpoint = "" return ""
    // Strip /services/... suffix
    set tPos = $find(pEndpoint, "/services/")
    if tPos > 1 {
        set tBase = $extract(pEndpoint, 1, tPos - $length("/services/"))
    } else {
        // Fallback: strip trailing filename after last "/"
        set tPos = $length(pEndpoint, "/")
        set tBase = $piece(pEndpoint, "/", 1, tPos - 1) _ "/"
    }
    // Fix port :0 — remove it entirely
    set tBase = $replace(tBase, ":0/", "/")
    // Fix scheme — match the incoming request scheme to avoid mixed-content blocks
    set tScheme = $select(%request.Secure:"https", 1:"http")
    if $extract(tBase, 1, 5) = "http:" {
        set tBase = tScheme _ $extract(tBase, 5, *)
    } elseif $extract(tBase, 1, 6) = "https:" {
        set tBase = tScheme _ $extract(tBase, 6, *)
    }
    return tBase
}

/// Forward an action to a remote InstanceProxy at the given base URL.
ClassMethod ForwardToBaseURL(pBaseURL As %String, pAction As %String, pQueryString As %String, Output pResult As %DynamicObject) As %Status
{
    set pResult = {"ok": 0}

    try {
        // Parse host, port, https from the base URL
        set tHttps = $extract(pBaseURL, 1, 5) = "https"
        set tNoScheme = $piece(pBaseURL, "://", 2)          // host:port/path...
        set tHost  = $piece(tNoScheme, "/", 1)              // host:port
        set tPort  = $piece(tHost, ":", 2)
        set tHost  = $piece(tHost, ":", 1)
        set tPathBase = "/" _ $piece(tNoScheme, "/", 2, *)  // /prefix/csp/.../hsods/

        set tHttp = ##class(%Net.HttpRequest).%New()
        set tHttp.Server = tHost
        set tHttp.Port   = +tPort
        if tHttps {
            set tHttp.Https = 1
            // SSLConfiguration left empty — uses system default; set if needed
        }

        set tPath = tPathBase _ "HS.Local.zimpli.fhir.API.InstanceProxy.cls"
            _ "?action=" _ $zcvt(pAction, "O", "URL")
            _ "&" _ pQueryString

        set tSC = tHttp.Get(tPath)
        return:$$$ISERR(tSC) tSC

        set tBody = tHttp.HttpResponse.Data
        do tBody.Rewind()
        set pResult = ##class(%DynamicObject).%FromJSON(tBody.Read())

    } catch ex {
        set pResult = {"ok": 0, "error": (ex.DisplayString())}
    }

    return $$$OK
}

}
