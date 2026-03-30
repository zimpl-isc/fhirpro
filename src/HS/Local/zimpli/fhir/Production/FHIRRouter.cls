Class HS.Local.zimpli.fhir.Production.FHIRRouter Extends Ens.BusinessProcess
{

Property ValidationHost As Ens.DataType.ConfigName [ InitialExpression = "HS.FHIRServer.Interop.HTTPOperation" ];

Property FHIRRepoHost As Ens.DataType.ConfigName [ InitialExpression = "HS.FHIRServer.Interop.HTTPOperation" ];

Parameter SETTINGS = "ValidationHost:zimpliFHIR,FHIRRepoHost:zimpliFHIR";

Method OnRequest(pRequest As HS.FHIRServer.Interop.Request, Output pResponse As HS.FHIRServer.Interop.Response) As %Status
{
    if (pRequest.Request.RequestMethod = "POST") && (pRequest.Request.RequestPath [ "/validate") {
        // TODO: path contains profile or mode, defaulting to core
        set tSc = ..CallValidationHost(pRequest, .pResponse)
    } else {

        set tSc = ..SendRequestSync(..FHIRRepoHost, pRequest, .pResponse)
    }

	return $$$OK
}

Method CallValidationHost(pRequest As HS.FHIRServer.Interop.Request, Output pResponse As HS.FHIRServer.Interop.Response) As %Status
{
    set tProfile = "http://hl7.org/fhir/StructureDefinition/Bundle"

    return ..SendRequestSync(..ValidationHost, pRequest, .pResponse)
}

Storage Default
{
<Data name="FHIRRouterDefaultData">
<Subscript>"FHIRRouter"</Subscript>
<Value name="1">
<Value>ValidationHost</Value>
</Value>
<Value name="2">
<Value>FHIRRepoHost</Value>
</Value>
</Data>
<DefaultData>FHIRRouterDefaultData</DefaultData>
<Type>%Storage.Persistent</Type>
}

}
