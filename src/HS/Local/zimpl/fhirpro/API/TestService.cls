/**
* Business Service class for the toolkit Production
*  which handles the requests for SDA3 or FHIR data
*
* @version 1.0 2024-03-27
* @author Brandon Thomas
*/

Class HS.Local.zimpl.fhirpro.API.TestService Extends HS.Test.Service
{

Property FHIRRESTOperations As Ens.DataType.ConfigName [ InitialExpression = "HS.FHIRServer.Interop.HTTPOperation" ];

Method OnProcessInput(pInput As %RegisteredObject, Output pOutput As %RegisteredObject, ByRef pHint As %String) As %Status
{
	If pInput.%IsA("HS.FHIRServer.Interop.Request"){
		return ..SendRequestSync(..FHIRRESTOperations,pInput,.pOutput)
		
	} else {
		return ##super(pInput, .pOutput, .pHint)
	}
}

}
