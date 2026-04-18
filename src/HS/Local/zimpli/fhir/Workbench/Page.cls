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

        ElseIf pAction="getDTLXML" {
            Set dtlClass = $Get(%request.Data("dtlClass",1))
            Set tSC = ##class(HS.Local.zimpli.fhir.Workbench.Service).GetDTLXML(dtlClass, .tXML)
            If $$$ISOK(tSC) {
                Set result.ok = 1
                Set result.xml = tXML
                Set result.dtlClass = dtlClass
            } Else {
                Set result.ok = 0
                Set result.error = $System.Status.GetErrorText(tSC)
            }
        }

        ElseIf pAction="resourceGroupSummary" {
            Set mpiid = $Get(%request.Data("mpiid",1))
            Set validationConvention = $Get(%request.Data("validationConvention",1))
            Set result = ##class(HS.Local.zimpli.fhir.Workbench.Service).GetResourceGroupSummary(mpiid, validationConvention)
        }

        ElseIf pAction="resourcesForGroup" {
            Set mpiid = $Get(%request.Data("mpiid",1))
            Set resourceType = $Get(%request.Data("resourceType",1))
            Set validationConvention = $Get(%request.Data("validationConvention",1))
            Set result.ok = 1
            Set result.resources = ##class(HS.Local.zimpli.fhir.Workbench.Service).GetResourcesForGroup(mpiid, resourceType, validationConvention)
        }

        ElseIf pAction="issuesForResource" {
            Set mpiid = $Get(%request.Data("mpiid",1))
            Set resourceType = $Get(%request.Data("resourceType",1))
            Set resourceId = $Get(%request.Data("resourceId",1))
            Set validationConvention = $Get(%request.Data("validationConvention",1))

            Set sql = "SELECT ID FROM HS_Local_zimpli_fhir_Workbench.Issue"
                _" WHERE MPIID = ? AND ResourceType = ? AND Status = 'Open'"

            If resourceId'="" {
                Set sql = sql_" AND ResourceId = ?"
            }
            If validationConvention'="" {
                Set sql = sql_" AND ValidationConvention = ?"
            }

            Set stmt = ##class(%SQL.Statement).%New()
            Set sc = stmt.%Prepare(sql)

            If resourceId'="", validationConvention'="" {
                Set rs = stmt.%Execute(mpiid, resourceType, resourceId, validationConvention)
            } ElseIf resourceId'="" {
                Set rs = stmt.%Execute(mpiid, resourceType, resourceId)
            } ElseIf validationConvention'="" {
                Set rs = stmt.%Execute(mpiid, resourceType, validationConvention)
            } Else {
                Set rs = stmt.%Execute(mpiid, resourceType)
            }

            Set result.ok = 1
            Set result.issues = []

            While rs.%Next() {
                Set obj = ##class(HS.Local.zimpli.fhir.Workbench.Issue).%OpenId(rs.%Get("ID"))
                Continue:'$IsObject(obj)

                Do result.issues.%Push({
                    "id": (obj.%Id()),
                    "severity": (obj.Severity),
                    "resourceType": (obj.ResourceType),
                    "resourceId": (obj.ResourceId),
                    "fhirPath": (obj.FHIRPath),
                    "message": (obj.Message),
                    "causeBucket": (obj.CauseBucket)
                })
            }
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
    // Get validation profiles as JSON string
    Set tProfilesJSON = ##class(HS.Local.zimpli.fhir.UI.FHIRNetwork).GetValidationCatalogJSON()

    // Parse it into a dynamic array so we can embed it properly
    Set tProfilesArray = [].%FromJSON(tProfilesJSON)

    // Get backend tool links from Workbench Service
    Set tToolLinksArray = ##class(HS.Local.zimpli.fhir.Workbench.Service).GetBackendToolLinks()

    Set o = {
        "fhirStreamServer": (..#FHIRStreamServer),
        "sdaStreamServer": (..#SDAStreamServer),
        "validationProfiles": (tProfilesArray),
        "validationEndpoint": (##class(HS.Local.zimpli.fhir.UI.FHIRNetwork).GetValidationEndpointURL()),
        "backendTools": (tToolLinksArray)
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

    <script type="text/javascript">
        window.FHIRWorkbenchConfig = #(..GetWorkbenchConfigJSON())#;
    </script>
    #(..XDataJS("StorageHandler"))#
    #(..XDataJS("WorkbenchCore"))#
    #(..XDataJS("WorkbenchUI"))#
    #(..XDataJS("BackendTools"))#
    #(..XDataJS("Init"))#
    #(..XDataCSS("DefaultStyle"))#
</head>
<body>
    <div class="top">
        <div class="mpiid-display">
            <span class="label">Patient:</span>
            <span id="mpiidDisplay" class="value">Loading...</span>
        </div>
        <label>Validation Profile
            <select id="validationConvention"></select>
        </label>
        <button onclick="reloadPatient()" title="Trigger async ODS reload job and clear all validation issues for this patient">🔄 Reload in ODS (async)</button>
        <button onclick="refreshData()" title="Fetch latest FHIR/SDA from server and save as new timestamped workbench session">📥 Refresh from Server</button>
        <button onclick="validateCurrentData()" title="Send current FHIR to validator and persist results">✓ Validate</button>
        <button onclick="loadIssues()" title="Reload validation issues from database">🔍 Refresh Issues</button>
        <span id="status"></span>
    </div>

    <div class="main">
        <!-- Pane 1: Resource Tree -->
        <div class="pane tree">
            <div class="section">
                <h3 style="margin:0 0 8px 0;font-size:14px;">Resources</h3>
                <div id="resourceTree" class="resource-tree"></div>
            </div>
        </div>

        <!-- Pane 2: Issue List -->
        <div class="pane issues">
            <div class="section">
                <div style="display:flex;justify-content:space-between;align-items:center;margin-bottom:8px;">
                    <h3 style="margin:0;font-size:14px;">Issues</h3>
                    <button id="aiPromptAllBtn" onclick="openAIPromptAll()" style="padding:4px 8px;font-size:11px;background:#8b5cf6;color:#fff;border:none;border-radius:6px;cursor:pointer;font-weight:500;display:none;" title="Generate AI prompt with all issues for this resource">🤖 AI All</button>
                </div>
                <div class="issue-count" id="issueCount">Select a resource</div>
                <div id="issueList"></div>
            </div>
        </div>

        <!-- Pane 3: Investigation -->
        <div class="pane investigation">
            <div class="section">
                <h3 style="margin:0 0 8px 0;font-size:14px;">Investigation</h3>
                <div id="investigationPane">
                    <p class="muted">Click an issue to investigate</p>
                </div>
            </div>
        </div>
    </div>

    <!-- DataInspector Overlay -->
    <div id="dataInspectorOverlay" class="inspector-overlay" style="display:none;">
        <div class="inspector-header">
            <button onclick="closeDataInspector()" class="inspector-close">✕</button>
            <span class="inspector-title">FHIR & SDA Inspector</span>
        </div>
        <iframe id="dataInspectorFrame" class="inspector-frame"></iframe>
    </div>

    <!-- DTL XML Viewer Overlay -->
    <div id="dtlXmlOverlay" class="inspector-overlay" style="display:none;">
        <div class="inspector-header">
            <span class="inspector-title" id="dtlXmlTitle">DTL XML</span>
            <button onclick="closeDTLXmlViewer()" class="inspector-close">✕</button>
        </div>
        <div class="inspector-frame" style="padding:16px;overflow:auto;">
            <div style="margin-bottom:12px;">
                <button onclick="copyDTLXmlToClipboard()" style="padding:8px 16px;background:#2563eb;color:#fff;border:none;border-radius:8px;cursor:pointer;font-size:13px;font-weight:500;">
                    📋 Copy to Clipboard
                </button>
            </div>
            <pre id="dtlXmlContent" style="background:#1f2937;color:#f9fafb;padding:16px;border-radius:8px;overflow:auto;font-family:Consolas,monospace;font-size:12px;line-height:1.5;margin:0;"></pre>
        </div>
    </div>

    <!-- AI Prompt Overlay -->
    <div id="aiPromptOverlay" class="inspector-overlay" style="display:none;">
        <div class="inspector-header">
            <span class="inspector-title" id="aiPromptTitle">AI Troubleshooting Prompt</span>
            <button onclick="closeAIPrompt()" class="inspector-close">✕</button>
        </div>
        <div class="inspector-frame" style="padding:16px;overflow:auto;">
            <div style="margin-bottom:12px;">
                <button onclick="copyAIPromptToClipboard()" style="padding:8px 16px;background:#8b5cf6;color:#fff;border:none;border-radius:8px;cursor:pointer;font-size:13px;font-weight:500;">
                    📋 Copy to Clipboard
                </button>
            </div>
            <pre id="aiPromptContent" style="background:#1f2937;color:#f9fafb;padding:16px;border-radius:8px;overflow:auto;font-family:Consolas,monospace;font-size:12px;line-height:1.5;margin:0;white-space:pre-wrap;"></pre>
        </div>
    </div>

</body>
</html>
    >
}

XData DefaultStyle [ MimeType = application/css ]
{
body { font-family: Arial, sans-serif; margin:0; padding:16px; background:#f5f7fb; }
.top {
    padding:14px 16px;
    background:#ffffff;
    color:#1f2937;
    display:flex;
    gap:12px;
    align-items:center;
    flex-wrap:wrap;
    border:1px solid #d9e2f2;
    border-radius:12px;
    margin-bottom:12px;
    box-shadow:0 1px 3px rgba(0,0,0,0.06);
}
.top input, .top select, .top button { padding:6px 10px; font-size:13px; border-radius:8px; }
.top button {
    background:#ffffff;
    border:1px solid #cbd5e1;
    color:#334155;
    cursor:pointer;
    font-weight:500;
}
.top button:hover { background:#f8fafc; }
.mpiid-display {
    display:flex;
    gap:6px;
    align-items:center;
    padding:6px 12px;
    background:#f8fafc;
    border:1px solid #e2e8f0;
    border-radius:8px;
}
.mpiid-display .label { font-size:12px; color:#64748b; font-weight:500; }
.mpiid-display .value { font-size:13px; font-weight:600; color:#1f2937; }
.main { display:grid; grid-template-columns:320px 380px 1fr; height:calc(100vh - 120px); gap:12px; }
.pane {
    overflow:auto;
    padding:12px;
    background:#ffffff;
    border:1px solid #d9e2f2;
    border-radius:12px;
    box-shadow:0 1px 3px rgba(0,0,0,0.06);
}
.pane.tree { padding:8px; }
.pane.issues { padding:10px; }
.pane.investigation { padding:10px; }

/* Issue cards */
.issue {
    border:1px solid #e2e8f0;
    border-radius:10px;
    padding:12px;
    margin-bottom:10px;
    cursor:pointer;
    background:#ffffff;
    border-left: 4px solid #cbd5e1;
    transition: all 0.2s;
    box-shadow:0 1px 2px rgba(0,0,0,0.04);
}
.issue:hover { background:#f8fafc; box-shadow: 0 2px 6px rgba(0,0,0,0.08); }
.issue.error { border-left-color:#dc2626; }
.issue.error.selected { background:#fef2f2; border-left-color:#dc2626; }
.issue.warning { border-left-color:#f59e0b; }
.issue.warning.selected { background:#fffbeb; border-left-color:#f59e0b; }
.issue.information { border-left-color:#3b82f6; }
.issue.information.selected { background:#eff6ff; border-left-color:#3b82f6; }

/* Severity badges */
.severity-badge {
    display:inline-block;
    padding:2px 8px;
    border-radius:12px;
    font-size:11px;
    font-weight:600;
    text-transform:uppercase;
    margin-right:6px;
}
.severity-badge.error { background:#fee2e2; color:#991b1b; }
.severity-badge.warning { background:#fef3c7; color:#92400e; }
.severity-badge.information { background:#dbeafe; color:#1e40af; }

/* Cause bucket tags */
.cause-tag {
    display:inline-block;
    padding:2px 6px;
    border-radius:4px;
    font-size:10px;
    background:#e5e7eb;
    color:#374151;
    margin-left:4px;
}
.cause-tag.Terminology { background:#ddd6fe; color:#5b21b6; }
.cause-tag.Transform { background:#fce7f3; color:#9f1239; }
.cause-tag.Config { background:#fef3c7; color:#92400e; }

/* Issue details */
.issue-header { display:flex; align-items:center; margin-bottom:4px; flex-wrap:wrap; gap:4px; }
.issue-resource { font-weight:600; font-size:13px; color:#374151; }
.issue-path { font-size:11px; color:#6b7280; margin-bottom:6px; }
.issue-path code { background:#e5e7eb; padding:2px 4px; border-radius:2px; font-family:Consolas,monospace; font-size:10px; }
.issue-message {
    font-size:12px;
    color:#1f2937;
    line-height:1.6;
}
.issue-message.truncated {
    max-height:3.6em;
    overflow:hidden;
    text-overflow:ellipsis;
    display:-webkit-box;
    -webkit-line-clamp:2;
    -webkit-box-orient:vertical;
}
.issue-url {
    color:#2563eb;
    font-size:11px;
    word-break:break-all;
    font-family:Consolas,monospace;
    display:inline-block;
    margin-top:2px;
}
.issue-code {
    background:#f1f5f9;
    color:#334155;
    padding:1px 4px;
    border-radius:3px;
    font-size:11px;
    font-family:Consolas,monospace;
}
.issue-break {
    display:inline-block;
    height:4px;
}

/* Filter controls */
.filters {
    display:flex;
    gap:8px;
    margin-bottom:12px;
    flex-wrap:wrap;
    padding:10px 12px;
    background:#f8fafc;
    border:1px solid #e2e8f0;
    border-radius:10px;
}
.filters select, .filters input {
    padding:6px 10px;
    font-size:12px;
    border:1px solid #cbd5e1;
    border-radius:8px;
    background:#ffffff;
}
.issue-count {
    font-size:12px;
    color:#64748b;
    font-weight:500;
    padding:10px 12px;
    background:#f8fafc;
    border:1px solid #e2e8f0;
    border-radius:10px;
    margin-bottom:10px;
}

textarea { width:100%; min-height:220px; box-sizing:border-box; font-family: Consolas, monospace; font-size:12px; }
.section { margin-bottom:14px; }
.section h3 { margin:0 0 8px 0; font-size:14px; color:#374151; }
.muted { color:#666; font-size:12px; }

/* Investigation pane */
.investigation-card {
    border:1px solid #d9e2f2;
    border-radius:12px;
    padding:14px;
    margin-bottom:12px;
    background:#ffffff;
    box-shadow:0 1px 3px rgba(0,0,0,0.06);
}
.investigation-card h4 {
    margin:0 0 10px 0;
    font-size:13px;
    color:#374151;
    font-weight:600;
    display:flex;
    justify-content:space-between;
    align-items:center;
}
.issue-detail-card {
    background:#fafafa;
}
.issue-detail-card.error {
    border-left:4px solid #dc2626;
    background:#fef2f2;
}
.issue-detail-card.warning {
    border-left:4px solid #f59e0b;
    background:#fffbeb;
}
.issue-detail-card.information {
    border-left:4px solid #3b82f6;
    background:#eff6ff;
}
.issue-detail-card h4 {
    gap:8px;
}
.inspector-btn {
    padding:8px 16px;
    background:#64748b;
    color:#fff;
    border:none;
    border-radius:8px;
    font-size:13px;
    font-weight:500;
    cursor:pointer;
    white-space:nowrap;
    transition:all 0.2s;
    box-shadow:0 1px 2px rgba(0,0,0,0.08);
}
.inspector-btn:hover {
    background:#475569;
    box-shadow:0 2px 4px rgba(0,0,0,0.12);
}
.message-item {
    white-space:pre-wrap;
    margin-top:8px;
    line-height:1.5;
}
.investigation-item {
    padding:8px 0;
    margin-bottom:6px;
    font-size:12px;
}
.investigation-item .label {
    font-weight:600;
    color:#6b7280;
    margin-right:4px;
}
.investigation-item code {
    background:#e5e7eb;
    padding:2px 4px;
    border-radius:2px;
    font-family:Consolas,monospace;
    font-size:11px;
}

/* Terminology fields */
.term-field {
    display:flex;
    align-items:center;
    gap:6px;
    padding:6px 10px;
    background:#f9fafb;
    border:1px solid #e5e7eb;
    border-radius:6px;
}
.term-label {
    font-size:11px;
    font-weight:600;
    color:#6b7280;
}
.term-value {
    background:#ffffff;
    border:1px solid #d1d5db;
    padding:4px 8px;
    border-radius:4px;
    font-family:Consolas,monospace;
    font-size:12px;
    color:#1f2937;
    cursor:pointer;
    transition:all 0.2s;
}
.term-value:hover {
    background:#f3f4f6;
    border-color:#9ca3af;
}

/* Tool links */
.tool-links {
    display:flex;
    flex-direction:column;
    gap:6px;
}
.tool-link {
    display:flex;
    align-items:center;
    gap:8px;
    padding:8px 12px;
    background:#f8fafc;
    border:1px solid #e2e8f0;
    border-radius:8px;
    text-decoration:none;
    color:#334155;
    font-size:12px;
    font-weight:500;
    transition:all 0.2s;
}
.tool-link:hover {
    background:#ffffff;
    box-shadow:0 1px 3px rgba(0,0,0,0.08);
}
.tool-icon {
    font-size:16px;
}

/* DTL list */
.dtl-list {
    display:flex;
    flex-direction:column;
    gap:6px;
}
.dtl-item {
    padding:10px 12px;
    background:#f8fafc;
    border:1px solid #e2e8f0;
    border-radius:10px;
    font-size:11px;
    border-left:3px solid transparent;
    margin-bottom:8px;
}
.dtl-item.custom {
    background:#fef5ff;
    border-color:#f3e8ff;
    border-left-color:#d946ef;
}
.dtl-item.standard {
    background:#f8fafc;
    border-color:#e2e8f0;
    border-left-color:#cbd5e1;
}
.dtl-header {
    display:flex;
    justify-content:space-between;
    align-items:flex-start;
    gap:8px;
    margin-bottom:4px;
    font-family:Consolas,monospace;
}
.dtl-header > div {
    flex:1;
    word-break:break-all;
}
.dtl-action-link {
    font-size:10px;
    text-decoration:none;
    padding:3px 8px;
    border-radius:3px;
    white-space:nowrap;
    font-weight:600;
}
.dtl-action-link.edit {
    color:#c026d3;
}
.dtl-action-link.edit:hover {
    background:#f5d0fe;
}
.dtl-action-link.view {
    color:#2563eb;
    background:#dbeafe;
}
.dtl-action-link.view:hover {
    background:#bfdbfe;
}
.dtl-action-link.ai-prompt {
    color:#8b5cf6;
    background:#ede9fe;
    border:none;
    cursor:pointer;
}
.dtl-action-link.ai-prompt:hover {
    background:#ddd6fe;
}
.dtl-action-link.xml {
    color:#059669;
    background:#d1fae5;
    border:none;
    cursor:pointer;
}
.dtl-action-link.xml:hover {
    background:#a7f3d0;
}
.dtl-badges {
    display:flex;
    gap:4px;
    margin-top:4px;
    flex-wrap:wrap;
}
.condition-badge {
    display:inline-block;
    padding:2px 6px;
    border-radius:10px;
    font-size:9px;
    font-weight:600;
    text-transform:uppercase;
    letter-spacing:0.3px;
}
.condition-badge.top-level {
    background:#dcfce7;
    color:#166534;
}
.condition-badge.subtransform {
    background:#e0e7ff;
    color:#3730a3;
}
.condition-badge.conditional {
    background:#fef3c7;
    color:#92400e;
}
.condition-badge.custom-only {
    background:#f3e8ff;
    color:#6b21a8;
}
.custom-badge {
    display:inline-block;
    padding:2px 6px;
    border-radius:10px;
    font-size:9px;
    font-weight:600;
    text-transform:uppercase;
    background:#fce7f3;
    color:#9f1239;
    letter-spacing:0.3px;
}

/* Resource display */
.resource-display {
    background:#1f2937;
    color:#f9fafb;
    padding:10px;
    border-radius:4px;
    font-size:11px;
    overflow:auto;
    max-height:400px;
    margin:0;
}
.resource-display code {
    font-family:Consolas,monospace;
    color:#f9fafb;
}
.toggle-btn {
    font-size:11px;
    padding:2px 8px;
    background:#e5e7eb;
    border:none;
    border-radius:3px;
    cursor:pointer;
}
.toggle-btn:hover {
    background:#d1d5db;
}

/* DataInspector Overlay */
.inspector-overlay {
    position:fixed;
    top:6px;
    left:720px;
    right:16px;
    bottom:16px;
    background:#ffffff;
    border:1px solid #d9e2f2;
    border-radius:12px;
    box-shadow:-2px 0 10px rgba(0,0,0,0.15), 0 4px 6px rgba(0,0,0,0.1);
    z-index:1000;
    display:flex;
    flex-direction:column;
    overflow:hidden;
}
.inspector-header {
    display:flex;
    justify-content:flex-start;
    align-items:center;
    gap:12px;
    padding:14px 16px;
    background:#ffffff;
    color:#1f2937;
    border-bottom:1px solid #e2e8f0;
}
.inspector-title {
    font-weight:600;
    font-size:14px;
    color:#1f2937;
}
.inspector-close {
    background:#f8fafc;
    border:1px solid #cbd5e1;
    color:#334155;
    font-size:18px;
    cursor:pointer;
    padding:4px 10px;
    line-height:1;
    border-radius:8px;
    font-weight:600;
}
.inspector-close:hover {
    background:#e2e8f0;
}
.inspector-frame {
    flex:1;
    border:none;
    width:100%;
}

/* Resource Tree */
.resource-tree { font-size:13px; }
.resource-group { margin-bottom:4px; }
.resource-group summary {
    cursor:pointer;
    padding:6px 8px;
    background:#f9fafb;
    border-radius:4px;
    list-style:none;
    user-select:none;
}
.resource-group summary:hover { background:#f3f4f6; }
.resource-group summary::-webkit-details-marker { display:none; }
.resource-group[open] > summary { background:#e5e7eb; }

.group-header { display:flex; align-items:center; gap:8px; }
.group-name { font-weight:600; flex:1; }
.group-counts { font-size:11px; color:#6b7280; white-space:nowrap; }
.severity-icon { font-size:14px; }

.subtype-group { margin-left:12px; margin-top:2px; }
.severity-group { margin-left:12px; margin-top:2px; }

.resource-list { list-style:none; padding:0; margin:4px 0 0 12px; }
.resource-list li {
    padding:4px 8px;
    margin:2px 0;
    cursor:pointer;
    border-radius:4px;
    font-size:12px;
}
.resource-list li:hover { background:#f3f4f6; }
.resource-list li.selected { background:#dbeafe; border-left:3px solid #2196F3; }

.resource-counts { font-size:10px; color:#9ca3af; margin-left:4px; }

.clean-check { color:#10b981; }
.resource-group.clean { opacity:0.7; }
.resource-group.clean:hover { opacity:1; }
}

XData WorkbenchCore [ MimeType = application/javascript ]
{
// Global state
let currentFHIR = null;
let currentSDA = "";
let currentValidation = null;
let currentRunId = "";
let allIssues = [];
let selectedIssueId = null;
let selectedResourceType = null;
let selectedResourceId = null;
let selectedSeverityFilter = null;
let mpiidLabel = ""; // Full label like "100000037_Lars_Maier"
let mpiidNumeric = ""; // Just the number "100000037"

// Extract numeric MPIID from FHIR Bundle or label
function extractMpiidFromFHIR(fhirBundle) {
    if (!fhirBundle || !fhirBundle.entry) return extractMpiidFromLabel(mpiidLabel);

    // Find the Patient resource
    for (let entry of fhirBundle.entry) {
        if (entry.resource && entry.resource.resourceType === "Patient") {
            return entry.resource.id;
        }
    }

    // Fallback: try to parse from label if no Patient resource
    return extractMpiidFromLabel(mpiidLabel);
}

// Extract numeric part from label (e.g., "100000037_Lars_Maier" -> "100000037")
function extractMpiidFromLabel(label) {
    if (!label) return null;

    // If label starts with digits, extract them
    const match = label.match(/^(\d+)/);
    if (match) {
        return match[1];
    }

    // Otherwise return the label as-is (might need manual override)
    return label;
}

// API helper
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

// Workflow functions
async function reloadPatient() {
    if (!mpiidNumeric) {
        setStatus("No patient selected");
        return false;
    }

    setStatus("Reloading patient in ODS...");

    const reloadResp = await api("reload", { mpiid: mpiidNumeric });
    if (!reloadResp.ok) {
        setStatus("Reload failed: " + (reloadResp.error || "unknown error"));
        return false;
    }

    currentRunId = reloadResp.runId || "";

    // Start countdown timer
    let countdown = 10;
    setStatus(`Asyncronous reload started in ODS. Refresh from Server in ${countdown}s...`);

    const countdownInterval = setInterval(() => {
        countdown--;
        if (countdown > 0) {
            setStatus(`Asyncronous reload started in ODS. Refresh from Server in ${countdown}s...`);
        } else {
            clearInterval(countdownInterval);
            setStatus("Asyncronous reload complete. Ready to Refresh from Server - GO! 🚀");
        }
    }, 1000);

    return true;
}

async function refreshData() {
    if (!mpiidNumeric) {
        setStatus("No numeric MPIID available - load FHIR data first");
        return false;
    }

    setStatus("Fetching FHIR from server...");
    currentFHIR = await fetchFHIR(mpiidNumeric);

    setStatus("Fetching SDA from server...");
    currentSDA = await fetchSDA(mpiidNumeric);

    // Re-extract numeric MPIID in case data changed
    if (currentFHIR) {
        mpiidNumeric = extractMpiidFromFHIR(currentFHIR);
    }

    // Create a new timestamped workbench session label (compact format: MMDD_HHMM)
    const now = new Date();
    const month = String(now.getMonth() + 1).padStart(2, '0');
    const day = String(now.getDate()).padStart(2, '0');
    const hours = String(now.getHours()).padStart(2, '0');
    const minutes = String(now.getMinutes()).padStart(2, '0');
    const timestamp = `${month}${day}_${hours}${minutes}`;
    const newLabel = mpiidNumeric + "_wb_" + timestamp;

    // Update the current label to point to this new session
    mpiidLabel = newLabel;
    document.getElementById('mpiidDisplay').textContent = newLabel;

    // Update shared storage to use this new label
    setMpiid(newLabel);

    // Store using StorageHandler functions (uses FHIR#<mpiid> and SDA#<mpiid> format)
    if (currentFHIR) {
        setFhirData(JSON.stringify(currentFHIR));
    }
    if (currentSDA) {
        setSdaData(currentSDA);
    }

    // Reset workbench view - clear selections and show old issues with warning
    selectedResourceType = null;
    selectedResourceId = null;
    selectedIssueId = null;
    document.getElementById("issueList").innerHTML = '<p class="muted">Select a resource to view issues</p>';
    document.getElementById("issueCount").textContent = "Select a resource";
    document.getElementById("investigationPane").innerHTML = '<p class="muted">Select an issue to investigate</p>';

    // Load existing issues for this numeric MPIID (they're still valid)
    await loadIssues();

    if (hasIncompleteResult(currentFHIR)) {
        setStatus("⚠️ Data refreshed (incomplete). Showing OLD validation issues. Re-validate to update!");
    } else {
        setStatus("✓ Data refreshed. Saved as: " + newLabel + ". Showing OLD validation issues - re-validate to update!");
    }

    return true;
}

async function validateCurrentData() {
    // Use numeric MPIID for persisting issues (so they're shared across all snapshots)
    if (!mpiidNumeric) {
        setStatus("No numeric MPIID available");
        return;
    }

    const validationConvention = document.getElementById("validationConvention").value || "";

    if (!currentFHIR) {
        setStatus("No FHIR loaded - click 'Refresh from Server' first");
        return;
    }

    if (hasIncompleteResult(currentFHIR)) {
        setStatus("FHIR fetch is incomplete; refresh again before validating");
        return;
    }

    setStatus("Validating...");
    currentValidation = await validateFHIR(validationConvention, currentFHIR);

    setStatus("Persisting issues...");
    const persistResult = await persistIssues(mpiidNumeric, validationConvention, currentRunId, currentValidation);

    if (!persistResult.ok) {
        setStatus("Failed to persist issues: " + (persistResult.error || "unknown error"));
        return;
    }

    await loadResourceTree();
    const summary = currentValidation?.summary;
    if (summary) {
        setStatus(`Validation complete - (${summary.error || 0} errors, ${summary.warning || 0} warnings)`);
    } else {
        setStatus("Validation complete");
    }
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
        { mpiid: mpiid, validationConvention: validationConvention, runId: runId },
        JSON.stringify({ validation: validation })
    );
}

// Utility functions
function esc(v) {
    return String(v)
        .replaceAll("&", "&amp;")
        .replaceAll("<", "&lt;")
        .replaceAll(">", "&gt;");
}

function extractTerminologyData(message) {
    if (!message) return {};

    const result = {};

    // Pattern: "for code http://loinc.org#8867-4" or "system http://snomed.info/sct code 12345"
    const codeSystemPattern = /(https?:\/\/[^\s#`'"]+)#([^\s.`'"]+)/;
    const match = message.match(codeSystemPattern);
    if (match) {
        result.codeSystem = match[1];
        result.code = match[2].replace(/[`'"]/g, ''); // Strip any backticks/quotes

        // Extract system name (last part of URL)
        const systemParts = result.codeSystem.split('/');
        result.codeSystemName = systemParts[systemParts.length - 1] || result.codeSystem;
    } else {
        // Try alternate pattern: "code 12345" or "code `12345`"
        const codeOnlyPattern = /\bcode\s+[`'"]?([A-Za-z0-9\-]+)[`'"]?/i;
        const codeMatch = message.match(codeOnlyPattern);
        if (codeMatch) {
            result.code = codeMatch[1];
        }
    }

    // Pattern: "A valid display is Heart rate." or "valid display: Heart rate" or with backticks
    // Capture everything after "valid display is" until the ending period
    const displayPattern = /valid display\s+(?:is\s+)?[`'"]?([^`'"\n]+?)[`'"]?\s*\.?\s*$/im;
    const displayMatch = message.match(displayPattern);
    if (displayMatch) {
        let display = displayMatch[1].trim();
        // Remove all backticks and quotes
        display = display.replace(/[`'"]/g, '');
        // Remove "for code..." suffix if present
        display = display.replace(/\s+for\s+code\s+.*/i, '');
        // Remove trailing period if present
        display = display.replace(/\.\s*$/, '');
        result.display = display.trim();
    }

    return result;
}

function copyToClipboard(text, label) {
    navigator.clipboard.writeText(text).then(() => {
        setStatus(`✓ ${label} copied: ${text}`);
    }).catch(() => {
        setStatus(`Failed to copy ${label}`);
    });
}

function formatIssueMessage(message) {
    if (!message) return "";

    // Extract URLs (http/https/urn)
    const urlPattern = /(https?:\/\/[^\s]+|urn:[^\s]+)/g;
    const urls = [];
    let text = message;

    // Replace URLs with placeholders and collect them
    text = text.replace(urlPattern, (url) => {
        urls.push(url);
        return `__URL${urls.length - 1}__`;
    });

    // Escape the text
    text = esc(text);

    // Restore URLs as styled links
    urls.forEach((url, index) => {
        const escapedUrl = esc(url);
        text = text.replace(`__URL${index}__`, `<span class="issue-url">${escapedUrl}</span>`);
    });

    // Highlight code-like patterns (text between backticks)
    text = text.replace(/`([^`]+)`/g, '<code class="issue-code">$1</code>');

    // Add subtle breaks after periods (not at end, not in middle of abbreviations)
    const sentences = text.split(/\.\s+/);
    if (sentences.length > 1) {
        text = sentences.map((s, i) => {
            if (i === sentences.length - 1) return s; // Last sentence
            if (s.length < 10) return s + '. '; // Too short, probably abbreviation
            return s + '.<br><span class="issue-break"></span>';
        }).join('');
    }

    return text;
}

function setStatus(msg) {
    document.getElementById("status").textContent = msg;
}

async function loadIssues() {
    await loadResourceTree();
}

async function loadResourceTree() {
    // Use numeric MPIID for querying issues (they're stored by numeric ID)
    if (!mpiidNumeric) {
        document.getElementById("resourceTree").innerHTML = '<p class="muted">No numeric MPIID available</p>';
        return;
    }

    const validationConvention = document.getElementById("validationConvention").value || "";
    const resp = await api("resourceGroupSummary", { mpiid: mpiidNumeric, validationConvention: validationConvention });

    if (!resp || !resp.groups) {
        document.getElementById("resourceTree").innerHTML = '<p class="muted">No issues found</p>';
        return;
    }

    renderResourceTree(resp.groups);
}

function renderResourceTree(groups) {
    const container = document.getElementById("resourceTree");
    container.innerHTML = "";

    // Sort by total count descending
    groups.sort((a, b) => b.totalCount - a.totalCount);

    groups.forEach((group, index) => {
        const details = document.createElement("details");
        details.className = "resource-group";
        if (group.totalCount === 0) details.classList.add("clean");

        // Auto-open first group (noisiest)
        if (index === 0 && group.totalCount > 0) {
            details.open = true;
        }

        const summary = document.createElement("summary");
        const errorIcon = group.errorCount > 0 ? '<span class="severity-icon" style="color:#dc2626;">●</span>' : '';
        const warningIcon = group.warningCount > 0 ? '<span class="severity-icon" style="color:#f59e0b;">●</span>' : '';
        const cleanIcon = group.totalCount === 0 ? '<span class="clean-check">✓</span>' : '';

        summary.innerHTML = `
            <div class="group-header">
                <span class="group-name">${errorIcon}${warningIcon}${cleanIcon} ${esc(group.displayName)}</span>
                <span class="group-counts">
                    ${group.errorCount > 0 ? `<span style="color:#dc2626;">${group.errorCount} errors</span>` : ''}
                    ${group.errorCount > 0 && group.warningCount > 0 ? ', ' : ''}
                    ${group.warningCount > 0 ? `<span style="color:#f59e0b;">${group.warningCount} warnings</span>` : ''}
                    ${group.totalCount === 0 ? 'No issues' : ''}
                </span>
            </div>
        `;

        details.appendChild(summary);

        if (group.totalCount > 0) {
            // Add resource-level loading on expand
            details.addEventListener("toggle", async () => {
                if (details.open && !details.dataset.loaded) {
                    details.dataset.loaded = "true";
                    await loadResourcesForGroup(details, group.resourceType);
                }
            });
        }

        container.appendChild(details);
    });
}

async function loadResourcesForGroup(groupElement, resourceType) {
    // Use numeric MPIID for querying issues
    if (!mpiidNumeric) return;

    const validationConvention = document.getElementById("validationConvention").value || "";
    const resp = await api("resourcesForGroup", { mpiid: mpiidNumeric, resourceType: resourceType, validationConvention: validationConvention });

    if (!resp.ok || !resp.resources || resp.resources.length === 0) {
        return;
    }

    // Create severity groups
    const resources = resp.resources;
    const withErrors = resources.filter(r => r.errorCount > 0);
    const withWarnings = resources.filter(r => r.warningCount > 0 && r.errorCount === 0);
    const withInformation = resources.filter(r => r.informationCount > 0 && r.errorCount === 0 && r.warningCount === 0);

    if (withErrors.length > 0) {
        const errorDetails = document.createElement("details");
        errorDetails.className = "severity-group";
        errorDetails.open = true;

        const errorSummary = document.createElement("summary");
        errorSummary.innerHTML = `<span style="color:#dc2626;">● Errors (${withErrors.length})</span>`;
        errorDetails.appendChild(errorSummary);

        const errorList = document.createElement("ul");
        errorList.className = "resource-list";
        withErrors.forEach(res => {
            const li = document.createElement("li");
            li.textContent = res.id || '(no id)';
            li.innerHTML += `<span class="resource-counts">${res.errorCount} error${res.errorCount !== 1 ? 's' : ''}</span>`;
            li.onclick = () => selectResource(resourceType, res.id, 'error');
            errorList.appendChild(li);
        });
        errorDetails.appendChild(errorList);
        groupElement.appendChild(errorDetails);
    }

    if (withWarnings.length > 0) {
        const warningDetails = document.createElement("details");
        warningDetails.className = "severity-group";
        warningDetails.open = (withErrors.length === 0);

        const warningSummary = document.createElement("summary");
        warningSummary.innerHTML = `<span style="color:#f59e0b;">● Warnings (${withWarnings.length})</span>`;
        warningDetails.appendChild(warningSummary);

        const warningList = document.createElement("ul");
        warningList.className = "resource-list";
        withWarnings.forEach(res => {
            const li = document.createElement("li");
            li.textContent = res.id || '(no id)';
            li.innerHTML += `<span class="resource-counts">${res.warningCount} warning${res.warningCount !== 1 ? 's' : ''}</span>`;
            li.onclick = () => selectResource(resourceType, res.id, 'warning');
            warningList.appendChild(li);
        });
        warningDetails.appendChild(warningList);
        groupElement.appendChild(warningDetails);
    }

    if (withInformation.length > 0) {
        const infoDetails = document.createElement("details");
        infoDetails.className = "severity-group";
        infoDetails.open = false;

        const infoSummary = document.createElement("summary");
        infoSummary.innerHTML = `<span style="color:#3b82f6;">● Information (${withInformation.length})</span>`;
        infoDetails.appendChild(infoSummary);

        const infoList = document.createElement("ul");
        infoList.className = "resource-list";
        withInformation.forEach(res => {
            const li = document.createElement("li");
            li.textContent = res.id || '(no id)';
            li.innerHTML += `<span class="resource-counts">${res.informationCount} info</span>`;
            li.onclick = () => selectResource(resourceType, res.id, 'information');
            infoList.appendChild(li);
        });
        infoDetails.appendChild(infoList);
        groupElement.appendChild(infoDetails);
    }
}
}

XData WorkbenchUI [ MimeType = application/javascript ]
{
async function selectResource(resourceType, resourceId, severityFilter) {
    selectedResourceType = resourceType;
    selectedResourceId = resourceId;
    selectedSeverityFilter = severityFilter || null;
    selectedIssueId = null; // Clear selected issue

    // Update UI selection
    document.querySelectorAll(".resource-list li").forEach(li => li.classList.remove("selected"));
    event.target.classList.add("selected");

    // Clear investigation pane
    document.getElementById("investigationPane").innerHTML = '<p class="muted">Select an issue to investigate</p>';

    // Close any open overlays
    closeDataInspector();
    closeDTLXmlViewer();
    closeAIPrompt();

    // Load issues for this resource (use numeric MPIID)
    if (!mpiidNumeric) return;

    const validationConvention = document.getElementById("validationConvention").value || "";
    const resp = await api("issuesForResource", { mpiid: mpiidNumeric, resourceType: resourceType, resourceId: resourceId, validationConvention: validationConvention });

    allIssues = resp.issues || [];
    renderIssueList();
}

function renderIssueList() {
    const container = document.getElementById("issueList");
    const countEl = document.getElementById("issueCount");
    const aiPromptAllBtn = document.getElementById("aiPromptAllBtn");
    container.innerHTML = "";

    if (!selectedResourceType) {
        countEl.textContent = "Select a resource";
        aiPromptAllBtn.style.display = "none";
        return;
    }

    // Filter by severity if a severity group was clicked
    let filtered = allIssues;
    if (selectedSeverityFilter) {
        filtered = allIssues.filter(issue => issue.severity === selectedSeverityFilter);
    }

    const severityLabel = selectedSeverityFilter ? ` (${selectedSeverityFilter})` : '';
    countEl.textContent = `${filtered.length} issue${filtered.length !== 1 ? 's' : ''} for ${selectedResourceType}/${selectedResourceId || '?'}${severityLabel}`;

    // Show AI Prompt All button if there are issues
    if (allIssues.length > 0) {
        aiPromptAllBtn.style.display = "block";
    } else {
        aiPromptAllBtn.style.display = "none";
    }

    filtered.forEach(issue => {
        const div = document.createElement("div");
        div.className = `issue ${issue.severity}`;
        if (issue.id === selectedIssueId) div.classList.add("selected");

        const severityBadge = `<span class="severity-badge ${issue.severity}">${issue.severity}</span>`;
        const causeTag = issue.causeBucket ? `<span class="cause-tag ${issue.causeBucket}">${issue.causeBucket}</span>` : "";

        div.innerHTML = `
            <div class="issue-header">
                ${severityBadge}
                ${causeTag}
            </div>
            ${issue.fhirPath ? `<div class="issue-path"><code>${esc(issue.fhirPath)}</code></div>` : ""}
            <div class="issue-message">${formatIssueMessage(issue.message || "")}</div>
        `;

        div.onclick = (e) => {
            // Don't navigate if user is selecting text
            if (window.getSelection().toString().length > 0) {
                return;
            }
            investigateIssue(issue.id, issue.severity);
        };
        container.appendChild(div);
    });
}

async function investigateIssue(issueId, severity) {
    selectedIssueId = issueId;
    renderIssueList();

    const resp = await api("investigateIssue", { issueId: issueId });
    resp.severity = severity; // Pass severity through to rendering
    renderInvestigation(resp);
}

async function renderInvestigation(data) {
    const pane = document.getElementById("investigationPane");

    if (!data.ok) {
        pane.innerHTML = `<p class="muted">${esc(data.error || "Failed to load investigation")}</p>`;
        return;
    }

    // Ensure FHIR is loaded
    if (!currentFHIR && data.resourceType && data.resourceId) {
        const mpiid = getMpiid();
        if (mpiid) {
            currentFHIR = await fetchFHIR(mpiid);
        }
    }

    let html = "";

    // Quick actions card
    if (data.resourceType && data.resourceId) {
        html += `<div class="investigation-card">
            <div style="display:flex;gap:12px;align-items:center;">
                <button onclick="openDataInspector('${esc(data.resourceType)}', '${esc(data.resourceId)}')" class="inspector-btn">
                    🔍 Open Inspector
                </button>
                <p class="muted" style="font-size:11px;margin:0;">View ${esc(data.resourceType)}/${esc(data.resourceId)} FHIR & SDA side-by-side with search</p>
            </div>
        </div>`;
    }

    // Code Registry card for terminology issues
    const msgLower = (data.message || "").toLowerCase();
    const causeLower = (data.causeBucket || "").toLowerCase();
    const hasCodingIssue = causeLower === 'terminology' ||
                           msgLower.includes('value set') || msgLower.includes('code system') ||
                           msgLower.includes('coding') || msgLower.includes('terminology') ||
                           msgLower.includes('invalid code') || msgLower.includes('unknown code');

    if (hasCodingIssue) {
        const codeRegistryURL = BackendTools.buildCodeRegistryLink();
        if (codeRegistryURL) {
            // Try to extract code and display from message
            const termData = extractTerminologyData(data.message || "");

            html += `<div class="investigation-card">
                <div style="display:flex;gap:12px;align-items:center;margin-bottom:${termData.code || termData.display ? '8px' : '0'};">
                    <button onclick="window.open('${codeRegistryURL}', '_blank')" class="inspector-btn" style="background:#7c3aed;">
                        📖 Code Registry
                    </button>
                    <p class="muted" style="font-size:11px;margin:0;">Manage terminology codes and value sets</p>
                </div>`;

            // Show extracted terminology values
            if (termData.codeSystemName || termData.code || termData.display) {
                html += `<div style="display:flex;gap:8px;flex-wrap:wrap;">`;

                if (termData.codeSystemName) {
                    html += `<div class="term-field">
                        <span class="term-label">Code System:</span>
                        <code class="term-value" style="cursor:default;" title="${esc(termData.codeSystem || '')}">${esc(termData.codeSystemName)}</code>
                    </div>`;
                }

                if (termData.code) {
                    html += `<div class="term-field">
                        <span class="term-label">Code:</span>
                        <code class="term-value" onclick="copyToClipboard('${esc(termData.code)}', 'Code')" title="Click to copy">${esc(termData.code)}</code>
                    </div>`;
                }

                if (termData.display) {
                    html += `<div class="term-field">
                        <span class="term-label">Valid Display:</span>
                        <code class="term-value" onclick="copyToClipboard('${esc(termData.display)}', 'Display')" title="Click to copy">${esc(termData.display)}</code>
                    </div>`;
                }

                html += `</div>`;
            }

            html += `</div>`;
        }
    }

    // Candidate DTLs card
    if (data.candidateTransforms && data.candidateTransforms.length > 0) {
        // Sort: custom DTLs first, then standard
        const sortedDTLs = data.candidateTransforms.slice().sort((a, b) => {
            if (a.isCustom && !b.isCustom) return -1;
            if (!a.isCustom && b.isCustom) return 1;
            return 0;
        });

        const customCount = sortedDTLs.filter(d => d.isCustom).length;
        const standardCount = sortedDTLs.length - customCount;
        const countLabel = customCount > 0
            ? `${customCount} custom, ${standardCount} standard`
            : `${data.candidateTransforms.length}`;

        html += `<div class="investigation-card">
            <h4>Candidate DTLs <span style="font-weight:normal;font-size:11px;color:#6b7280;">(${countLabel})</span></h4>
            <div class="dtl-list">`;

        sortedDTLs.forEach(dtl => {
            const editorURL = BackendTools.buildDTLEditorLink(dtl.effectiveDTL);
            const viewerURL = BackendTools.buildDTLViewerLink(dtl.effectiveDTL);

            // Format condition type with badge
            let conditionBadge = "";
            if (dtl.conditionType) {
                const condType = dtl.conditionType;
                let badgeClass = "condition-badge";
                let badgeText = condType;

                if (condType === "top-level") {
                    badgeClass += " top-level";
                    badgeText = "Top-Level";
                } else if (condType === "subtransform") {
                    badgeClass += " subtransform";
                    badgeText = "Subtransform";
                } else if (condType === "conditional") {
                    badgeClass += " conditional";
                    badgeText = "Conditional";
                } else if (condType === "custom-only") {
                    badgeClass += " custom-only";
                    badgeText = "Custom Only";
                }

                conditionBadge = `<span class="${badgeClass}">${badgeText}</span>`;
            }

            // Show custom badge if applicable
            const customBadge = dtl.isCustom ? `<span class="custom-badge">Custom</span>` : "";

            // Action links: Edit for custom, View for standard, AI Prompt for custom, XML viewer for all
            let actionLinks = "";
            if (dtl.isCustom && editorURL) {
                actionLinks += `<a href="${editorURL}" target="_blank" class="dtl-action-link edit" title="Edit in DTL Editor">✏️ Edit</a>`;
            } else if (viewerURL) {
                actionLinks += `<a href="${viewerURL}" target="_blank" class="dtl-action-link view" title="View DTL">👁️ View</a>`;
            }

            // Add AI Prompt button for custom/editable DTLs
            if (dtl.isCustom && dtl.hasDTLXML) {
                actionLinks += `<button onclick="openAIPromptForDTL('${esc(dtl.effectiveDTL)}')" class="dtl-action-link ai-prompt" title="Generate AI troubleshooting prompt">🤖 AI Prompt</button>`;
            }

            // Add XML viewer button for all DTLs (if they have XML)
            if (dtl.hasDTLXML) {
                actionLinks += `<button onclick="openDTLXmlViewer('${esc(dtl.effectiveDTL)}')" class="dtl-action-link xml" title="View DTL XML for AI/copy-paste">🤖 XML</button>`;
            }

            html += `<div class="dtl-item ${dtl.isCustom ? 'custom' : 'standard'}">
                <div class="dtl-header">
                    <div><strong>${esc(dtl.sourceClass || "")}</strong> → ${esc(dtl.effectiveDTL || "")}</div>
                    <div style="display:flex;gap:6px;">
                        ${actionLinks}
                    </div>
                </div>
                <div class="dtl-badges">
                    ${conditionBadge}
                    ${customBadge}
                </div>
                ${dtl.conditionType === "conditional" && dtl.condition ? `<div class="muted" style="font-size:10px;margin-top:4px;">Expression: <code>${esc(dtl.condition)}</code></div>` : ""}
            </div>`;
        });

        html += `</div></div>`;
    } else if (data.resourceType) {
        html += `<div class="investigation-card">
            <p class="muted">No DTLs found for ${esc(data.resourceType)}</p>
        </div>`;
    }

    // Backend Tools card (only show non-DTL tools)
    const backendToolLinks = [];

    // OID Map for .system issues
    if (data.fhirPath && data.fhirPath.includes('.system')) {
        const oidURL = BackendTools.buildOIDMapLink();
        if (oidURL) {
            backendToolLinks.push({
                url: oidURL,
                label: 'OID Map',
                icon: '🔗'
            });
        }
    }

    // Terminology for coding/valueset issues
    if (msgLower.includes('value set') || msgLower.includes('code system') || msgLower.includes('coding') || msgLower.includes('terminology')) {
        const termURL = BackendTools.buildTerminologyLink();
        if (termURL) {
            backendToolLinks.push({
                url: termURL,
                label: 'Terminology Viewer',
                icon: '📖'
            });
        }
    }

    if (backendToolLinks.length > 0) {
        html += `<div class="investigation-card">
            <h4>Backend Tools</h4>
            <div class="tool-links">`;

        backendToolLinks.forEach(tool => {
            html += `<a href="${tool.url}" target="_blank" class="tool-link" title="${esc(tool.label)}">
                <span class="tool-icon">${tool.icon}</span> ${esc(tool.label)}
            </a>`;
        });

        html += `</div></div>`;
    }

    pane.innerHTML = html;
}

function openDataInspector(resourceType, resourceId) {
    const mpiid = getMpiid();

    // Store data in sessionStorage for DataInspector to read (it uses StorageHandler)
    if (currentFHIR) {
        setFhirData(JSON.stringify(currentFHIR));
    }
    if (currentSDA) {
        setSdaData(currentSDA);
    }

    // Build URL with resource identifier
    const inspectorURL = 'HS.Local.zimpli.fhir.UI.DataInspector.cls?resourceId=' + encodeURIComponent(resourceId);

    // Open overlay
    document.getElementById('dataInspectorFrame').src = inspectorURL;
    document.getElementById('dataInspectorOverlay').style.display = 'flex';
}

function closeDataInspector() {
    document.getElementById('dataInspectorOverlay').style.display = 'none';
    document.getElementById('dataInspectorFrame').src = '';
}

async function openDTLXmlViewer(dtlClass) {
    setStatus("Loading DTL XML...");

    const resp = await api("getDTLXML", { dtlClass: dtlClass });

    if (!resp.ok) {
        alert("Failed to load DTL XML: " + (resp.error || "Unknown error"));
        setStatus("Failed to load DTL XML");
        return;
    }

    // Display XML
    document.getElementById('dtlXmlTitle').textContent = "DTL XML: " + dtlClass;
    document.getElementById('dtlXmlContent').textContent = resp.xml || "(empty)";
    document.getElementById('dtlXmlOverlay').style.display = 'flex';
    document.getElementById('dtlXmlOverlay').dataset.dtlClass = dtlClass;

    setStatus("DTL XML loaded");
}

function closeDTLXmlViewer() {
    document.getElementById('dtlXmlOverlay').style.display = 'none';
    document.getElementById('dtlXmlContent').textContent = '';
}

async function copyDTLXmlToClipboard() {
    const xml = document.getElementById('dtlXmlContent').textContent;
    const dtlClass = document.getElementById('dtlXmlOverlay').dataset.dtlClass || "DTL";

    try {
        await navigator.clipboard.writeText(xml);
        setStatus("✓ DTL XML copied to clipboard!");
    } catch (err) {
        console.error("Failed to copy:", err);
        alert("Failed to copy to clipboard. Please select and copy manually.");
    }
}

async function openAIPromptForDTL(dtlClass) {
    if (!selectedResourceType || !selectedResourceId || !selectedIssueId) {
        alert("No issue selected");
        return;
    }

    setStatus("Generating AI prompt for " + dtlClass + "...");

    // Ensure FHIR is loaded
    if (!currentFHIR && mpiidNumeric) {
        setStatus("Loading FHIR data...");
        currentFHIR = await fetchFHIR(mpiidNumeric);
    }

    // Get the FHIR resource from current data
    let fhirResource = null;
    if (currentFHIR && currentFHIR.entry) {
        const entry = currentFHIR.entry.find(e => {
            if (!e.resource) return false;
            const matchType = e.resource.resourceType.toLowerCase() === selectedResourceType.toLowerCase();
            const matchId = e.resource.id == selectedResourceId;
            return matchType && matchId;
        });
        if (entry) {
            fhirResource = entry.resource;
        }
    }

    if (!fhirResource) {
        alert(`Could not find FHIR resource ${selectedResourceType}/${selectedResourceId} in current data`);
        return;
    }

    // Get the currently selected issue only
    const currentIssue = allIssues.find(issue => issue.id === selectedIssueId);
    if (!currentIssue) {
        alert("Could not find the selected issue");
        return;
    }

    // Fetch DTL XML
    let dtlXml = "";
    try {
        const dtlResp = await api("getDTLXML", { dtlClass: dtlClass });
        if (dtlResp.ok && dtlResp.xml) {
            dtlXml = dtlResp.xml;
        } else {
            alert("Could not load DTL XML for " + dtlClass);
            return;
        }
    } catch (err) {
        alert("Error loading DTL XML: " + err.message);
        return;
    }

    // Build the prompt (single issue context)
    let prompt = `You are an integration specialist troubleshooting generated FHIR resources in InterSystems IRIS DTL. Analyze the issue and resource and make suggestions to fix. Let me know if this is not likely the correct DTL.\n\n`;

    prompt += `## Issue\n\n`;
    prompt += `- **Severity**: ${currentIssue.severity || 'unknown'}\n`;
    if (currentIssue.causeBucket) {
        prompt += `- **Cause**: ${currentIssue.causeBucket}\n`;
    }
    if (currentIssue.fhirPath) {
        prompt += `- **Location**: ${currentIssue.fhirPath}\n`;
    }
    prompt += `- **Message**: ${currentIssue.message || 'No message'}\n\n`;

    prompt += `## FHIR Resource (${selectedResourceType})\n\n`;
    prompt += `\`\`\`json\n${JSON.stringify(fhirResource, null, 2)}\n\`\`\`\n\n`;

    prompt += `## DTL Transform: ${dtlClass}\n\n`;
    prompt += `\`\`\`xml\n${dtlXml}\n\`\`\`\n\n`;

    prompt += `## Context\n\n`;
    prompt += `- Resource Type: ${selectedResourceType}\n`;
    prompt += `- Resource ID: ${selectedResourceId}\n`;
    prompt += `- Patient MPIID: ${mpiidNumeric || 'unknown'}\n`;
    prompt += `- DTL Class: ${dtlClass}\n`;

    document.getElementById('aiPromptTitle').textContent = `AI Prompt: ${dtlClass}`;
    document.getElementById('aiPromptContent').textContent = prompt;
    document.getElementById('aiPromptOverlay').style.display = 'flex';
    setStatus("AI prompt generated");
}

function closeAIPrompt() {
    document.getElementById('aiPromptOverlay').style.display = 'none';
    document.getElementById('aiPromptContent').textContent = '';
}

async function copyAIPromptToClipboard() {
    const prompt = document.getElementById('aiPromptContent').textContent;
    try {
        await navigator.clipboard.writeText(prompt);
        setStatus("✓ AI prompt copied to clipboard!");
    } catch (err) {
        console.error("Failed to copy:", err);
        alert("Failed to copy to clipboard. Please select and copy manually.");
    }
}

async function openAIPromptAll() {
    if (!selectedResourceType || !selectedResourceId || !allIssues || allIssues.length === 0) {
        alert("No issues available for the selected resource");
        return;
    }

    setStatus("Generating AI prompt with all issues...");

    // Ensure FHIR is loaded
    if (!currentFHIR && mpiidNumeric) {
        setStatus("Loading FHIR data...");
        currentFHIR = await fetchFHIR(mpiidNumeric);
    }

    // Get the FHIR resource from current data
    let fhirResource = null;
    if (currentFHIR && currentFHIR.entry) {
        const entry = currentFHIR.entry.find(e => {
            if (!e.resource) return false;
            const matchType = e.resource.resourceType.toLowerCase() === selectedResourceType.toLowerCase();
            const matchId = e.resource.id == selectedResourceId;
            return matchType && matchId;
        });
        if (entry) {
            fhirResource = entry.resource;
        }
    }

    if (!fhirResource) {
        alert(`Could not find FHIR resource ${selectedResourceType}/${selectedResourceId} in current data`);
        return;
    }

    // Build the prompt with all issues
    let prompt = `You are an integration specialist troubleshooting generated FHIR resources in InterSystems IRIS DTL. Analyze the issues and resource and make suggestions to fix.\n\n`;

    prompt += `## Issues Found (${allIssues.length} total)\n\n`;
    allIssues.forEach((issue, idx) => {
        prompt += `### Issue ${idx + 1}\n`;
        prompt += `- **Severity**: ${issue.severity || 'unknown'}\n`;
        if (issue.causeBucket) {
            prompt += `- **Cause**: ${issue.causeBucket}\n`;
        }
        if (issue.fhirPath) {
            prompt += `- **Location**: ${issue.fhirPath}\n`;
        }
        prompt += `- **Message**: ${issue.message || 'No message'}\n\n`;
    });

    prompt += `## FHIR Resource (${selectedResourceType})\n\n`;
    prompt += `\`\`\`json\n${JSON.stringify(fhirResource, null, 2)}\n\`\`\`\n\n`;

    prompt += `## Context\n\n`;
    prompt += `- Resource Type: ${selectedResourceType}\n`;
    prompt += `- Resource ID: ${selectedResourceId}\n`;
    prompt += `- Patient MPIID: ${mpiidNumeric || 'unknown'}\n`;

    document.getElementById('aiPromptTitle').textContent = `AI Prompt: All Issues for ${selectedResourceType}/${selectedResourceId}`;
    document.getElementById('aiPromptContent').textContent = prompt;
    document.getElementById('aiPromptOverlay').style.display = 'flex';
    setStatus("AI prompt generated with all issues");
}
}

XData BackendTools [ MimeType = application/javascript ]
{
var BackendTools = {
    config: null,

    init: function() {
        this.config = window.FHIRWorkbenchConfig.backendTools || [];
        console.log("Backend tools loaded:", this.config);
    },

    getToolURL: function(toolCode) {
        var tool = this.config.find(function(t) { return t.code === toolCode; });
        return tool ? tool.url : null;
    },

    buildDTLEditorLink: function(dtlClass) {
        var baseURL = this.getToolURL('DTLEditor');
        if (!baseURL) return null;
        var dtlFile = dtlClass.endsWith('.dtl') ? dtlClass : dtlClass + '.dtl';
        return baseURL + '?DT=' + encodeURIComponent(dtlFile);
    },

    buildDTLViewerLink: function(dtlClass) {
        var baseURL = this.getToolURL('DTLViewer');
        if (!baseURL) return null;
        return baseURL + '?class=' + encodeURIComponent(dtlClass);
    },

    buildOIDMapLink: function(oid) {
        var baseURL = this.getToolURL('OIDMap');
        if (!baseURL) return null;
        return oid ? baseURL + '?oid=' + encodeURIComponent(oid) : baseURL;
    },

    buildTerminologyLink: function(code) {
        var baseURL = this.getToolURL('Terminology');
        if (!baseURL) return null;
        return code ? baseURL + '?code=' + encodeURIComponent(code) : baseURL;
    },

    buildCodeRegistryLink: function() {
        var baseURL = this.getToolURL('CodeRegistry');
        if (!baseURL) return null;
        return baseURL;
    },

    getRelevantTools: function(issue) {
        var tools = [];
        var self = this;

        if (issue.candidateTransforms && issue.candidateTransforms.length > 0) {
            issue.candidateTransforms.forEach(function(dtl) {
                var url = self.buildDTLEditorLink(dtl.effectiveDTL);
                if (url) {
                    tools.push({
                        type: 'DTLEditor',
                        label: 'Edit: ' + dtl.effectiveDTL.split('.').pop(),
                        url: url,
                        icon: '🛠️'
                    });
                }

                var viewURL = self.buildDTLViewerLink(dtl.effectiveDTL);
                if (viewURL) {
                    tools.push({
                        type: 'DTLViewer',
                        label: 'View: ' + dtl.effectiveDTL.split('.').pop(),
                        url: viewURL,
                        icon: '📄'
                    });
                }
            });
        }

        if (issue.fhirPath && (issue.fhirPath.includes('.system') || issue.message.toLowerCase().includes('oid'))) {
            var url = this.buildOIDMapLink();
            if (url) {
                tools.push({
                    type: 'OIDMap',
                    label: 'Check OID Mapping',
                    url: url,
                    icon: '🔗'
                });
            }
        }

        var msg = issue.message.toLowerCase();
        if (msg.includes('value set') || msg.includes('code system') || msg.includes('coding')) {
            var url = this.buildTerminologyLink();
            if (url) {
                tools.push({
                    type: 'Terminology',
                    label: 'Check Terminology',
                    url: url,
                    icon: '📖'
                });
            }
        }

        return tools;
    }
};
}

XData Init [ MimeType = application/javascript ]
{
function initValidationProfiles() {
    const select = document.getElementById("validationConvention");
    const profiles = window.FHIRWorkbenchConfig.validationProfiles || [];

    // Add placeholder option
    select.innerHTML = '<option value="">-- Select validation profile --</option>';

    profiles.forEach(profile => {
        const option = document.createElement("option");
        option.value = profile.code;
        option.textContent = profile.label || profile.code;
        select.appendChild(option);
    });

    // Select first profile by default if available
    if (profiles.length > 0) {
        select.value = profiles[0].code;
    }
}

document.addEventListener('DOMContentLoaded', async function() {
    BackendTools.init();
    initValidationProfiles();

    // Get label from storage (could be anything: "Lars_Maier", "100000037", "Patient1", etc.)
    mpiidLabel = getMpiid();

    if (mpiidLabel) {
        document.getElementById('mpiidDisplay').textContent = mpiidLabel;

        // Load FHIR and SDA from shared storage (uses FHIR#<mpiid> and SDA#<mpiid> keys)
        const sharedFHIR = getFhirData();
        if (sharedFHIR) {
            currentFHIR = JSON.parse(sharedFHIR);
        }

        const sharedSDA = getSdaData();
        if (sharedSDA) {
            currentSDA = sharedSDA;
        }

        // Extract numeric MPIID from FHIR Patient resource
        if (currentFHIR) {
            mpiidNumeric = extractMpiidFromFHIR(currentFHIR);
            if (!mpiidNumeric) {
                console.warn("Could not extract numeric MPIID from FHIR data");
            }
        }

        if (currentFHIR || currentSDA) {
            setStatus("Loaded data from storage");
        }

        // Load issues
        if (mpiidNumeric) {
            await loadIssues();
        } else {
            setStatus("No FHIR data available - cannot extract MPIID");
        }
    } else {
        document.getElementById('mpiidDisplay').textContent = "No patient selected";
        setStatus("No patient selected - select a patient in another tool first");
    }
});
}

}
