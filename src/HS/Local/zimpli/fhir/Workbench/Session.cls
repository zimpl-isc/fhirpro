Class HS.Local.zimpli.fhir.Workbench.Session Extends (%Persistent, %JSON.Adaptor)
{

Property SessionKey As %String(MAXLEN = 128) [ Required ];

Property Username As %String(MAXLEN = 128);

Property MPIID As %String(MAXLEN = 64);

Property ValidationConvention As %String(MAXLEN = 128);

Property FocusResourceType As %String(MAXLEN = 64);

Property UIStateJSON As %String(MAXLEN = "");

Property LastRunId As %String(MAXLEN = 64);

Property UpdatedAt As %TimeStamp [ InitialExpression = {$ZDATETIME($HOROLOG,3,1,3)} ];

Index SessionKeyIdx On SessionKey [ Unique ];

ClassMethod SaveState(pSessionKey As %String, pUsername As %String = "", pMPIID As %String = "", pValidationConvention As %String = "", pFocusResourceType As %String = "", pUIStateJSON As %String = "", pLastRunId As %String = "") As %Status
{
    &sql(SELECT TOP 1 ID INTO :tID FROM HS_Local_zimpli_fhir_Workbench.Session WHERE SessionKey = :pSessionKey)

    If +$Get(tID) {
        Set obj = ..%OpenId(tID)
    } Else {
        Set obj = ..%New()
        Set obj.SessionKey = pSessionKey
    }

    Set obj.Username = pUsername
    Set obj.MPIID = pMPIID
    Set obj.ValidationConvention = pValidationConvention
    Set obj.FocusResourceType = pFocusResourceType
    Set obj.UIStateJSON = pUIStateJSON
    Set obj.LastRunId = pLastRunId
    Set obj.UpdatedAt = $ZDATETIME($HOROLOG,3,1,3)

    Quit obj.%Save()
}

Storage Default
{
<Data name="SessionDefaultData">
<Value name="1">
<Value>%%CLASSNAME</Value>
</Value>
<Value name="2">
<Value>SessionKey</Value>
</Value>
<Value name="3">
<Value>Username</Value>
</Value>
<Value name="4">
<Value>MPIID</Value>
</Value>
<Value name="5">
<Value>ValidationConvention</Value>
</Value>
<Value name="6">
<Value>FocusResourceType</Value>
</Value>
<Value name="7">
<Value>UIStateJSON</Value>
</Value>
<Value name="8">
<Value>LastRunId</Value>
</Value>
<Value name="9">
<Value>UpdatedAt</Value>
</Value>
</Data>
<DataLocation>^HS.Local.zimpli.fhE0D1.SessionD</DataLocation>
<DefaultData>SessionDefaultData</DefaultData>
<IdLocation>^HS.Local.zimpli.fhE0D1.SessionD</IdLocation>
<IndexLocation>^HS.Local.zimpli.fhE0D1.SessionI</IndexLocation>
<StreamLocation>^HS.Local.zimpli.fhE0D1.SessionS</StreamLocation>
<Type>%Storage.Persistent</Type>
}

}
