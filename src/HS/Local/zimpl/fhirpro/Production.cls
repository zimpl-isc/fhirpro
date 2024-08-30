Class HS.Local.zimpl.fhirpro.Production Extends Ens.Production [ Not ProcedureBlock ]
{

XData ProductionDefinition
{
<Production Name="HS.Local.zimpl.fhirpro.Production" TestingEnabled="true" LogGeneralTraceEvents="false">
  <Description></Description>
  <ActorPoolSize>1</ActorPoolSize>
  <Item Name="HS.Util.Trace.Operations" Category="" ClassName="HS.Util.Trace.Operations" PoolSize="1" Enabled="true" Foreground="false" Comment="" LogTraceEvents="false" Schedule="">
  </Item>
  <Item Name="GATEWAY" Category="" ClassName="HS.Gateway.Access.RemoteOperations" PoolSize="1" Enabled="true" Foreground="false" Comment="" LogTraceEvents="false" Schedule="">
    <Setting Target="Host" Name="ServiceName">dembpm3bthomas.local:HSACCESS</Setting>
    <Setting Target="Host" Name="ReplyCodeActions">E=C</Setting>
    <Setting Target="Host" Name="TraceOperations">*FULL*</Setting>
  </Item>
  <Item Name="HS.Local.zimpl.fhirpro.API.TestService" Category="" ClassName="HS.Local.zimpl.fhirpro.API.TestService" PoolSize="0" Enabled="true" Foreground="false" Comment="" LogTraceEvents="true" Schedule="">
    <Setting Target="Host" Name="FHIRRESTOperations">HS.FHIRServer.Interop.HTTPOperation</Setting>
  </Item>
  <Item Name="HS.FHIRServer.Interop.HTTPOperation" Category="" ClassName="HS.FHIRServer.Interop.HTTPOperation" PoolSize="1" Enabled="true" Foreground="false" Comment="" LogTraceEvents="false" Schedule="">
    <Setting Target="Host" Name="ServiceName">FHIR.Service.R4</Setting>
    <Setting Target="Host" Name="TraceOperations">*FULL*</Setting>
  </Item>
</Production>
}

}
