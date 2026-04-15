Class HS.Local.zimpli.fhir.Workbench.ODS Extends %RegisteredObject
{

ClassMethod ReloadPatient(pMPIID As %String) As %Status
{
    new $namespace
    set $namespace = "HSODS"

    return ##class(HS.Local.Impl.Utils.ODS).ReloadPatient(+pMPIID,1)
}

ClassMethod ReloadOnly(pMPIID As %String, Output pResult As %DynamicObject) As %Status
{
    Set pResult = {}
    Set pResult.ok = 0
    Set pResult.mpiid = pMPIID
    Set pResult.runId = ..NewRunId()

    Try {
        Set tSC = ..ReloadPatient(pMPIID)
        return:$$$ISERR(tSC) tSC

        Set pResult.ok = 1
        Set pResult.message = "ReloadPatient executed successfully"
        return $$$OK
    }
    Catch ex {
        Set tSC = ex.AsStatus()
        Set pResult.error = $System.Status.GetErrorText(tSC)
        return tSC
    }
}

ClassMethod NewRunId() As %String
{
    Quit $TR($ZDATETIME($HOROLOG,8)," :","__")_"-"_$JOB_"-"_$R(1000000)
}

}
