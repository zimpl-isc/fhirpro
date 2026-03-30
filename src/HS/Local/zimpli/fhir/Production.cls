Class HS.Local.zimpli.fhir.Production Extends Ens.Production [ Not ProcedureBlock ]
{

XData ProductionDefinition
{
<Production Name="HS.Local.zimpli.fhir.Production" TestingEnabled="true" LogGeneralTraceEvents="false">
  <Description></Description>
  <ActorPoolSize>1</ActorPoolSize>
  <Item Name="HS.Util.Trace.Operations" Category="" ClassName="HS.Util.Trace.Operations" PoolSize="1" Enabled="true" Foreground="false" Comment="" LogTraceEvents="false" Schedule="">
  </Item>
  <Item Name="GATEWAY" Category="" ClassName="HS.Gateway.Access.RemoteOperations" PoolSize="1" Enabled="true" Foreground="false" Comment="" LogTraceEvents="false" Schedule="">
    <Setting Target="Host" Name="ServiceName">dembpm3bthomas.local:HSACCESS</Setting>
    <Setting Target="Host" Name="ReplyCodeActions">E=C</Setting>
    <Setting Target="Host" Name="TraceOperations">*FULL*</Setting>
  </Item>
  <Item Name="HS.Local.zimpli.fhir.API.TestService" Category="" ClassName="HS.Local.zimpli.fhir.API.TestService" PoolSize="0" Enabled="true" Foreground="false" Comment="" LogTraceEvents="true" Schedule="">
    <Setting Target="Host" Name="FHIRRESTOperations">HS.Local.zimpli.fhir.Production.FHIRRouter</Setting>
  </Item>
  <Item Name="HS.FHIRServer.Interop.HTTPOperation" Category="" ClassName="HS.FHIRServer.Interop.HTTPOperation" PoolSize="1" Enabled="true" Foreground="false" Comment="" LogTraceEvents="true" Schedule="">
    <Setting Target="Host" Name="ServiceName">FHIR.ServiceSecure.R4</Setting>
    <Setting Target="Host" Name="TraceOperations">*FULL*</Setting>
    <Setting Target="Host" Name="ArchiveIO">1</Setting>
  </Item>
  <Item Name="HS.Local.zimpli.fhir.Production.FHIRRouter" Category="" ClassName="HS.Local.zimpli.fhir.Production.FHIRRouter" PoolSize="1" Enabled="true" Foreground="false" Comment="" LogTraceEvents="false" Schedule="">
  </Item>
</Production>
}

}
