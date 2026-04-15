Class HS.Local.zimpli.fhir.Workbench.Issue Extends (%Persistent, %JSON.Adaptor)
{

Parameter STORAGEDEFAULT = "Default";

Property MPIID As %String(MAXLEN = 64) [ Required ];

Property ValidationConvention As %String(MAXLEN = 128);

Property Severity As %String(MAXLEN = 16);

Property ResourceType As %String(MAXLEN = 64);

Property ResourceId As %String(MAXLEN = 128);

Property FHIRPath As %String(MAXLEN = 512);

Property Message As %String(MAXLEN = 4000);

Property NormalizedFingerprint As %String(MAXLEN = 512) [ Required ];

Property Status As %String(MAXLEN = 16, VALUELIST = ",Open,Ignored,Resolved") [ InitialExpression = "Open" ];

Property CauseBucket As %String(MAXLEN = 32);

Property IgnoreReason As %String(MAXLEN = 1000);

Property FirstSeenAt As %TimeStamp;

Property LastSeenAt As %TimeStamp;

Property ResolvedAt As %TimeStamp;

Property LastValidatorRunId As %String(MAXLEN = 64);

Index MPIIDIdx On MPIID;

Index StatusIdx On (MPIID, Status);

Index FingerprintIdx On (MPIID, ValidationConvention, NormalizedFingerprint);

ClassMethod FindTrackedIssueId(pMPIID As %String, pValidationConvention As %String, pFingerprint As %String) As %Integer
{
    &sql(
        SELECT TOP 1 ID
        INTO :tID
        FROM HS_Local_zimpli_fhir_Workbench.Issue
        WHERE MPIID = :pMPIID
          AND ValidationConvention = :pValidationConvention
          AND NormalizedFingerprint = :pFingerprint
          AND Status IN ('Open','Ignored')
        ORDER BY ID DESC
    )
    Quit +$Get(tID)
}

ClassMethod BuildFingerprint(pIssue As %DynamicObject) As %String
{
    Set tSeverity = ""
    Set tResourceType = ""
    Set tPath = ""
    Set tMessage = ""

    If pIssue.%IsDefined("severity") {
        Set tSeverity = $ZCONVERT(pIssue.severity,"L")
    }

    If pIssue.%IsDefined("resourceType") {
        Set tResourceType = $ZCONVERT(pIssue.resourceType,"L")
    }

    If pIssue.%IsDefined("fhirPath") {
        Set tPath = $ZCONVERT(pIssue.fhirPath,"L")
    }

    If pIssue.%IsDefined("message") {
        Set tMessage = ..NormalizeMessage(pIssue.message)
    }

    Quit tSeverity_"|"_tResourceType_"|"_tPath_"|"_tMessage
}

ClassMethod NormalizeMessage(pMessage As %String) As %String
{
    Set t = $ZSTRIP($Get(pMessage),"<W")
    Set t = $REPLACE(t,$C(13,10)," ")
    Set t = $REPLACE(t,$C(10)," ")
    For  Quit:t'["  "  Set t = $REPLACE(t,"  "," ")
    Quit $Extract(t,1,300)
}

ClassMethod UpsertFromDynamicIssue(pMPIID As %String, pValidationConvention As %String, pRunId As %String, pIssue As %DynamicObject) As %Status
{
    Set tNow = $ZDATETIME($HOROLOG,3,1,3)
    Set tFingerprint = ..BuildFingerprint(pIssue)
    Set tIssueId = ..FindTrackedIssueId(pMPIID,pValidationConvention,tFingerprint)

    If tIssueId {
        Set obj = ..%OpenId(tIssueId)
    } Else {
        Set obj = ..%New()
        Set obj.MPIID = pMPIID
        Set obj.ValidationConvention = pValidationConvention
        Set obj.NormalizedFingerprint = tFingerprint
        Set obj.FirstSeenAt = tNow
        Set obj.Status = "Open"
    }

    Set obj.LastSeenAt = tNow
    Set obj.LastValidatorRunId = pRunId

    If pIssue.%IsDefined("severity") Set obj.Severity = pIssue.severity
    If pIssue.%IsDefined("resourceType") Set obj.ResourceType = pIssue.resourceType
    If pIssue.%IsDefined("resourceId") Set obj.ResourceId = pIssue.resourceId
    If pIssue.%IsDefined("fhirPath") Set obj.FHIRPath = pIssue.fhirPath
    If pIssue.%IsDefined("message") Set obj.Message = $Extract(pIssue.message,1,4000)
    If pIssue.%IsDefined("causeBucket") Set obj.CauseBucket = pIssue.causeBucket

    Quit obj.%Save()
}

ClassMethod ResolveMissingIssues(pMPIID As %String, pValidationConvention As %String, pRunId As %String) As %Status
{
    Set tNow = $ZDATETIME($HOROLOG,3,1,3)

    &sql(
        UPDATE HS_Local_zimpli_fhir_Workbench.Issue
           SET Status = 'Resolved',
               ResolvedAt = :tNow
         WHERE MPIID = :pMPIID
           AND ValidationConvention = :pValidationConvention
           AND Status = 'Open'
           AND (LastValidatorRunId IS NULL OR LastValidatorRunId <> :pRunId)
    )

    Quit $$$OK
}

Storage Default
{
<Data name="IssueDefaultData">
<Value name="1">
<Value>%%CLASSNAME</Value>
</Value>
<Value name="2">
<Value>MPIID</Value>
</Value>
<Value name="3">
<Value>ValidationConvention</Value>
</Value>
<Value name="4">
<Value>Severity</Value>
</Value>
<Value name="5">
<Value>ResourceType</Value>
</Value>
<Value name="6">
<Value>ResourceId</Value>
</Value>
<Value name="7">
<Value>FHIRPath</Value>
</Value>
<Value name="8">
<Value>Message</Value>
</Value>
<Value name="9">
<Value>NormalizedFingerprint</Value>
</Value>
<Value name="10">
<Value>Status</Value>
</Value>
<Value name="11">
<Value>CauseBucket</Value>
</Value>
<Value name="12">
<Value>IgnoreReason</Value>
</Value>
<Value name="13">
<Value>FirstSeenAt</Value>
</Value>
<Value name="14">
<Value>LastSeenAt</Value>
</Value>
<Value name="15">
<Value>ResolvedAt</Value>
</Value>
<Value name="16">
<Value>LastValidatorRunId</Value>
</Value>
</Data>
<DataLocation>^HS.Local.zimpli.fhirE0D1.IssueD</DataLocation>
<DefaultData>IssueDefaultData</DefaultData>
<ExtentSize>3</ExtentSize>
<IdLocation>^HS.Local.zimpli.fhirE0D1.IssueD</IdLocation>
<IndexLocation>^HS.Local.zimpli.fhirE0D1.IssueI</IndexLocation>
<Property name="%%CLASSNAME">
<AverageFieldSize>2</AverageFieldSize>
<OutlierSelectivity>.999999:</OutlierSelectivity>
<Selectivity>0.0001%</Selectivity>
</Property>
<Property name="%%ID">
<AverageFieldSize>3</AverageFieldSize>
<Selectivity>1</Selectivity>
</Property>
<Property name="CauseBucket">
<AverageFieldSize>11</AverageFieldSize>
<OutlierSelectivity>.999999:"Ambiguous"</OutlierSelectivity>
<Selectivity>0.0001%</Selectivity>
</Property>
<Property name="FHIRPath">
<AverageFieldSize>2</AverageFieldSize>
<OutlierSelectivity>.999999:</OutlierSelectivity>
<Selectivity>0.0001%</Selectivity>
</Property>
<Property name="FirstSeenAt">
<AverageFieldSize>21</AverageFieldSize>
<OutlierSelectivity>.999999:"2026-04-15 10:44:40"</OutlierSelectivity>
<Selectivity>0.0001%</Selectivity>
</Property>
<Property name="IgnoreReason">
<AverageFieldSize>2</AverageFieldSize>
<OutlierSelectivity>.999999:</OutlierSelectivity>
<Selectivity>0.0001%</Selectivity>
</Property>
<Property name="LastSeenAt">
<AverageFieldSize>21</AverageFieldSize>
<OutlierSelectivity>.999999:"2026-04-15 10:44:40"</OutlierSelectivity>
<Selectivity>0.0001%</Selectivity>
</Property>
<Property name="LastValidatorRunId">
<AverageFieldSize>2</AverageFieldSize>
<OutlierSelectivity>.999999:</OutlierSelectivity>
<Selectivity>0.0001%</Selectivity>
</Property>
<Property name="MPIID">
<AverageFieldSize>11</AverageFieldSize>
<OutlierSelectivity>.999999:100000037</OutlierSelectivity>
<Selectivity>0.0001%</Selectivity>
</Property>
<Property name="Message">
<AverageFieldSize>2</AverageFieldSize>
<OutlierSelectivity>.999999:</OutlierSelectivity>
<Selectivity>0.0001%</Selectivity>
</Property>
<Property name="NormalizedFingerprint">
<AverageFieldSize>12.67</AverageFieldSize>
<Selectivity>33.3333%</Selectivity>
</Property>
<Property name="ResolvedAt">
<AverageFieldSize>21</AverageFieldSize>
<OutlierSelectivity>.999999:"2026-04-15 10:44:40"</OutlierSelectivity>
<Selectivity>0.0001%</Selectivity>
</Property>
<Property name="ResourceId">
<AverageFieldSize>2</AverageFieldSize>
<OutlierSelectivity>.999999:</OutlierSelectivity>
<Selectivity>0.0001%</Selectivity>
</Property>
<Property name="ResourceType">
<AverageFieldSize>2</AverageFieldSize>
<OutlierSelectivity>.999999:</OutlierSelectivity>
<Selectivity>0.0001%</Selectivity>
</Property>
<Property name="Severity">
<AverageFieldSize>9.67</AverageFieldSize>
<Selectivity>33.3333%</Selectivity>
</Property>
<Property name="Status">
<AverageFieldSize>10</AverageFieldSize>
<OutlierSelectivity>.999999:"Resolved"</OutlierSelectivity>
<Selectivity>0.0001%</Selectivity>
</Property>
<Property name="ValidationConvention">
<AverageFieldSize>5</AverageFieldSize>
<OutlierSelectivity>.999999:"MII"</OutlierSelectivity>
<Selectivity>0.0001%</Selectivity>
</Property>
<SQLMap name="FingerprintIdx">
<BlockCount>-4</BlockCount>
</SQLMap>
<SQLMap name="IDKEY">
<BlockCount>-16</BlockCount>
</SQLMap>
<SQLMap name="MPIIDIdx">
<BlockCount>-4</BlockCount>
</SQLMap>
<SQLMap name="StatusIdx">
<BlockCount>-4</BlockCount>
</SQLMap>
<StreamLocation>^HS.Local.zimpli.fhirE0D1.IssueS</StreamLocation>
<Type>%Storage.Persistent</Type>
}

}
