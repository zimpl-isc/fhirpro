Class HS.Local.zimpli.fhir.Workbench.Page Extends HS.Local.zimpli.fhir.UI.Super
{

Parameter CONTENTTYPE = "text/html; charset=utf-8";

ClassMethod OnPage() As %Status
{
    Set tAction = $Get(%request.Data("action",1))
    If tAction'="" {
        Quit ..HandleAPI(tAction)
    }

    Do ..RenderShell()
    Quit $$$OK
}

ClassMethod HandleAPI(pAction As %String) As %Status
{
    Set %response.ContentType = "application/json; charset=utf-8"
    Set result = {}
    Set sc = $$$OK

    Try {
        If pAction="reload" {
            Set mpiid = $Get(%request.Data("mpiid",1))
            Set sc = ##class(HS.Local.zimpli.fhir.Workbench.ODS).ReloadOnly(mpiid,.result)
        }

        ElseIf pAction="persistIssues" {
            Set mpiid = $Get(%request.Data("mpiid",1))
            Set validationConvention = $Get(%request.Data("validationConvention",1))
            Set runId = $Get(%request.Data("runId",1))

            Set tStream = ##class(%Stream.TmpCharacter).%New()
            Do tStream.CopyFrom(%request.Content)
            Do tStream.Rewind()
            Set payload = {}.%FromJSON(tStream)

            If '$IsObject(payload) {
                Set result.ok = 0
                Set result.error = "Invalid JSON payload"
                Write result.%ToJSON()
                return $$$ERROR($$$GeneralError,result.error)
            }

            If 'payload.%IsDefined("validation") {
                Set result.ok = 0
                Set result.error = "Payload missing validation"
                Write result.%ToJSON()
                return $$$ERROR($$$GeneralError,result.error)
            }

            Set tValidation = payload.validation

            Set sc = ##class(HS.Local.zimpli.fhir.Workbench.Service).PersistValidationIssues(
                mpiid,
                validationConvention,
                runId,
                tValidation
            )

            Set result.ok = $$$ISOK(sc)
        }

        ElseIf pAction="issues" {
            Set mpiid = $Get(%request.Data("mpiid",1))
            Set validationConvention = $Get(%request.Data("validationConvention",1))
            Set status = $Get(%request.Data("status",1),"Open")
            Set result.ok = 1
            Set result.issues = ##class(HS.Local.zimpli.fhir.Workbench.Service).GetIssueListAsJSON(
                mpiid,validationConvention,status
            )
        }

        ElseIf pAction="ignoreIssue" {
            Set issueId = +$Get(%request.Data("issueId",1))
            Set reason = $Get(%request.Data("reason",1))
            Set sc = ##class(HS.Local.zimpli.fhir.Workbench.Service).SetIssueStatus(issueId,"Ignored",reason)
            Set result.ok = $$$ISOK(sc)
        }

        ElseIf pAction="reopenIssue" {
            Set issueId = +$Get(%request.Data("issueId",1))
            Set sc = ##class(HS.Local.zimpli.fhir.Workbench.Service).SetIssueStatus(issueId,"Open","")
            Set result.ok = $$$ISOK(sc)
        }

        ElseIf pAction="investigateIssue" {
            Set issueId = +$Get(%request.Data("issueId",1))
            Set result = ##class(HS.Local.zimpli.fhir.Workbench.Service).InvestigateIssue(issueId)
        }

        ElseIf pAction="candidateTransforms" {
            Set resourceType = $Get(%request.Data("resourceType",1))
            Set result.ok = 1
            Set result.candidateTransforms = ##class(HS.Local.zimpli.fhir.Workbench.Service).FindCandidateTransformsByFHIRType(resourceType)
        }

        ElseIf pAction="dtlMetadata" {
            Set dtlClass = $Get(%request.Data("dtlClass",1))
            Set result.ok = 1
            Set result.metadata = ##class(HS.Local.zimpli.fhir.Workbench.Service).ExtractDTLMetadata(dtlClass)
        }

        Else {
            Set result.ok = 0
            Set result.error = "Unknown action"
        }
    }
    Catch ex {
        Set sc = ex.AsStatus()
        Set result.ok = 0
        Set result.error = $System.Status.GetErrorText(sc)
    }

    Write result.%ToJSON()
    Quit sc
}

ClassMethod GetWorkbenchConfigJSON() As %String
{
    Set o = {
        "fhirStreamServer": (..#FHIRStreamServer),
        "sdaStreamServer": (..#SDAStreamServer),
        "validationProfiles": (##class(HS.Local.zimpli.fhir.UI.FHIRNetwork).GetValidationCatalogJSON()),
        "validationEndpoint": (##class(HS.Local.zimpli.fhir.UI.FHIRNetwork).GetValidationEndpointURL())
    }
    Quit o.%ToJSON()
}

ClassMethod RenderShell()
{
    &html<
<!doctype html>
<html>
<head>
    <meta charset="utf-8"/>
    <title>FHIR Workbench</title>
    <style>
        body { font-family: Arial, sans-serif; margin:0; padding:0; background:#f5f5f5; }
        .top { padding:10px; background:#1f2937; color:#fff; display:flex; gap:8px; align-items:center; flex-wrap:wrap; }
        .top input, .top select, .top button { padding:6px; }
        .main { display:grid; grid-template-columns:320px 1fr 360px; height:calc(100vh - 58px); }
        .pane { overflow:auto; padding:10px; background:#fff; border-right:1px solid #ddd; }
        .issue { border:1px solid #ddd; border-radius:6px; padding:8px; margin-bottom:8px; cursor:pointer; background:#fafafa; }
        .issue:hover { background:#f0f0f0; }
        textarea { width:100%; min-height:220px; box-sizing:border-box; font-family: Consolas, monospace; }
        .section { margin-bottom:14px; }
        .muted { color:#666; font-size:12px; }
    </style>
    <script>
        window.FHIRWorkbenchConfig = #(..GetWorkbenchConfigJSON())#;
    </script>
</head>
<body>
    <div class="top">
        <label>MPIID <input id="mpiid" value="100000001"/></label>
        <label>Validation
            <input id="validationConvention" value=""/>
        </label>
        <button onclick="reloadPatient()">Reload</button>
        <button onclick="refreshData()">Refresh Data</button>
        <button onclick="validateCurrentData()">Validate</button>
        <button onclick="reloadRefreshValidate()">Reload + Refresh + Validate</button>
        <button onclick="loadIssues()">Refresh Issues</button>
        <span id="status"></span>
    </div>

    <div class="main">
        <div class="pane">
            <div class="section">
                <h3>Issues</h3>
                <div id="issues"></div>
            </div>
        </div>

        <div class="pane">
            <div class="section">
                <h3>FHIR</h3>
                <textarea id="fhirBox"></textarea>
            </div>
            <div class="section">
                <h3>SDA</h3>
                <textarea id="sdaBox"></textarea>
            </div>
        </div>

        <div class="pane">
            <div class="section">
                <h3>Investigation</h3>
                <textarea id="investigationBox"></textarea>
            </div>
        </div>
    </div>

    <script type="text/javascript">
        let currentFHIR = null;
        let currentSDA = "";
        let currentValidation = null;
        let currentRunId = "";

        async function api(action, params = {}, body = null) {
            const url = new URL(window.location.href);
            const fd = new URLSearchParams();
            fd.append("action", action);
            Object.entries(params).forEach(([k, v]) => fd.append(k, v ?? ""));

            const opts = { method: "POST", headers: {} };

            if (body !== null) {
                opts.body = body;
                opts.headers["Content-Type"] = "application/json";
                url.search = "action=" + encodeURIComponent(action);
                Object.entries(params).forEach(([k, v]) => {
                    url.search += "&" + encodeURIComponent(k) + "=" + encodeURIComponent(v ?? "");
                });
                return fetch(url.toString(), opts).then(r => r.json());
            } else {
                opts.headers["Content-Type"] = "application/x-www-form-urlencoded";
                opts.body = fd.toString();
                return fetch(window.location.pathname, opts).then(r => r.json());
            }
        }

        async function reloadPatient() {
            const mpiid = document.getElementById("mpiid").value;
            setStatus("Reloading patient...");

            const reloadResp = await api("reload", { mpiid });
            if (!reloadResp.ok) {
                setStatus("Reload failed: " + (reloadResp.error || "unknown error"));
                return false;
            }

            currentRunId = reloadResp.runId || "";
            setStatus("Reload started");
            return true;
        }

        async function refreshData() {
            const mpiid = document.getElementById("mpiid").value;

            setStatus("Fetching FHIR...");
            currentFHIR = await fetchFHIR(mpiid);
            document.getElementById("fhirBox").value = JSON.stringify(currentFHIR, null, 2);

            setStatus("Fetching SDA...");
            currentSDA = await fetchSDA(mpiid);
            document.getElementById("sdaBox").value = currentSDA;

            if (hasIncompleteResult(currentFHIR)) {
                setStatus("Data refreshed, but FHIR result is incomplete");
            } else {
                setStatus("Data refreshed");
            }
        }

        async function validateCurrentData() {
            const mpiid = document.getElementById("mpiid").value;
            const validationConvention = document.getElementById("validationConvention").value || "";

            if (!currentFHIR) {
                setStatus("No FHIR loaded");
                return;
            }

            if (hasIncompleteResult(currentFHIR)) {
                setStatus("FHIR fetch is incomplete; refresh again before validating");
                return;
            }

            setStatus("Validating...");
            currentValidation = await validateFHIR(validationConvention, currentFHIR);

            setStatus("Persisting issues...");
            await persistIssues(mpiid, validationConvention, currentRunId, currentFHIR, currentSDA, currentValidation);

            await loadIssues();
            setStatus("Validation complete");
        }

        async function reloadRefreshValidate() {
            const ok = await reloadPatient();
            if (!ok) return;

            setStatus("Waiting briefly before refresh...");
            await sleep(3000);

            await refreshData();

            if (hasIncompleteResult(currentFHIR)) {
                setStatus("FHIR still incomplete after reload; refresh again in a moment");
                return;
            }

            await validateCurrentData();
        }

        function normalizeBundleForValidation(bundle) {
            return {
                resourceType: "Bundle",
                type: "collection",
                entry: (bundle.entry || [])
                    .filter(e =>
                        e &&
                        e.resource &&
                        e.resource.resourceType &&
                        e.resource.resourceType !== "OperationOutcome"
                    )
                    .map(e => ({
                        fullUrl: e.fullUrl,
                        resource: e.resource
                    }))
            };
        }

        function hasIncompleteResult(bundle) {
            return (bundle?.entry || []).some(e =>
                e &&
                e.resource &&
                e.resource.resourceType === "OperationOutcome" &&
                (e.resource.issue || []).some(i =>
                    String(i.diagnostics || "").includes("IncompleteResult")
                )
            );
        }

        async function fetchFHIR(mpiid) {
            const url = window.FHIRWorkbenchConfig.fhirStreamServer + "?MPIID=" + encodeURIComponent(mpiid);
            const resp = await fetch(url, { cache: "no-cache" });
            return await resp.json();
        }

        async function fetchSDA(mpiid) {
            const querystr = "?MPIID=" + encodeURIComponent(mpiid);
            const resp = await fetch(window.FHIRWorkbenchConfig.sdaStreamServer + querystr, { cache: "no-cache" });
            return await resp.text();
        }

        async function validateFHIR(profile, bundle) {
            const normalizedBundle = normalizeBundleForValidation(bundle);

            const resp = await fetch(window.FHIRWorkbenchConfig.validationEndpoint, {
                method: "POST",
                headers: { "Content-Type": "application/json" },
                body: JSON.stringify({
                    validationProfile: profile,
                    bundle: normalizedBundle
                })
            });

            return await resp.json();
        }

        async function persistIssues(mpiid, validationConvention, runId, validation) {
            return await api(
                "persistIssues",
                { mpiid, validationConvention, runId },
                JSON.stringify({ validation })
            );
        }

        async function loadIssues() {
            const mpiid = document.getElementById("mpiid").value;
            const validationConvention = document.getElementById("validationConvention").value || "";
            const resp = await api("issues", { mpiid, validationConvention, status: "Open" });

            const container = document.getElementById("issues");
            container.innerHTML = "";

            (resp.issues || []).forEach(issue => {
                const div = document.createElement("div");
                div.className = "issue";
                div.innerHTML =
                    "<b>" + esc(issue.severity || "") + "</b> " +
                    esc(issue.resourceType || "") + "<br/>" +
                    "<span class='muted'>" + esc(issue.fhirPath || "") + "</span><br/>" +
                    esc(issue.message || "");
                div.onclick = () => investigateIssue(issue.id);
                container.appendChild(div);
            });
        }

        async function investigateIssue(issueId) {
            const resp = await api("investigateIssue", { issueId });
            document.getElementById("investigationBox").value = JSON.stringify(resp, null, 2);
        }

        function esc(v) {
            return String(v)
                .replaceAll("&", "&amp;")
                .replaceAll("<", "&lt;")
                .replaceAll(">", "&gt;");
        }

        function setStatus(msg) {
            document.getElementById("status").textContent = msg;
        }

        function sleep(ms) {
            return new Promise(resolve => setTimeout(resolve, ms));
        }

        loadIssues();
    </script>
</body>
</html>
    >
}

}
