/**
* Utility class supporting the DTL Viewer
*
* @version 1.0 2024-03-27
* @author Brandon Thomas
*/

Class HS.Local.zimpl.fhirpro.UI.Utils.XSLTCallbackHandler Extends HS.Util.XSLTHelper
{

Method evaluate(Args...) As %String
{
	#if 0
	/// debugging code not used in production code
	Do ..LogAccess(Args(1))
	#endif	
	If Args(1)="xmltimestamp" {
		Quit ..xmltimestamp(Args(2))
	} ElseIf Args(1)="getDtlSourceDoctype" {
		Quit $select(##class(%Dictionary.ClassDefinition).%Exists(Args(2)):$classmethod(Args(2), "GetSourceDocType"), 1:"")
	}ElseIf Args(1)="getDtlTargetDoctype" {
		Quit $select(##class(%Dictionary.ClassDefinition).%Exists(Args(2)):$classmethod(Args(2), "GetTargetDocType"), 1:"")
	}ElseIf Args(1)="createGUID" {
		Quit $System.Util.CreateGUID()
	} ElseIf Args(1)="currentDate" {
		Quit $ZDT($P($H,","),3)
	} ElseIf Args(1)="lookup" {
		Quit ..lookup(Args(2),Args(3))
	} ElseIF Args(1)="dateNoDash" {
		Quit ..dateNoDash(Args(2))
	} ElseIf Args(1)="stripapos" {
		Quit $zstrip(Args(2),"<>","'")
	} ElseIf Args(1)="piece" {
		Quit $P(Args(2),Args(3),Args(4))
	} ElseIf Args(1)="pieceStrip" {
		Quit $ZSTRIP($P(Args(2),Args(3),Args(4)),"<>W")
	} ElseIf Args(1)="strip" {
		Quit $ZSTRIP(Args(2),"<>"_Args(3))
	} ElseIf Args(1)="encode" {
		Quit $system.Encryption.Base64Encode(Args(2))
	} ElseIf Args(1)="decode" {
		Quit $system.Encryption.Base64Decode(Args(2))
	} ElseIf Args(1)="timestamp" {
		Quit ..timestamp($g(Args(2),$h))
	} ElseIf Args(1)="xmltimestampisbefore" {
		Quit ..xmltimestampisbefore(Args(2),Args(3))
	} ElseIf Args(1)="dateDiff" {
		Quit ..dateDiff(Args(2), Args(3), $Get(Args(4), $ZDateTime($Horolog, 3)))
	} ElseIf Args(1)="GWtoOID" {
		#; Consider deleting this function in favor of ..getOIDForCode()
		Quit ##class(HS.Data.OIDMap).OIDForType(Args(2),"Repository","")
	} ElseIf Args(1)="CodetoOID" {
		Quit:Args(2)="" ""
		Quit ##class(HS.Data.OIDMap).GetOIDForCode(Args(2),$g(Args(3),"Unknown code:"_Args(2)))
	} ElseIf Args(1)="OIDtoCode" {
		Quit:Args(2)="" ""
		Quit ##class(HS.Data.OIDMap).GetCodeForOID(Args(2),$G(Args(3),"Unknown OID:"_Args(2)))
	} ElseIf Args(1)="OIDtoGW" {
		#; Consider deleting this function in favor of ..getCodeForOID()
		Quit ##class(HS.Data.OIDMap).GetCodeForOID(Args(2))
	} ElseIf Args(1)="OIDtoFacilityName" {
		Set tReturn=Args(2)
		Set tFACCode=##class(HS.Data.OIDMap).GetCodeForOID(Args(2))
		If ##class(HS.Facility.Config).%ExistsId(tFACCode) {Set tReturn=##class(HS.Facility.Config).NameGetStored(tFACCode)}
		Quit tReturn
	} ElseIf Args(1)="OIDtoFacilityContact" {
		Set tReturn=Args(2)
		Set tFACCode=##class(HS.Data.OIDMap).GetCodeForOID(Args(2))
		Set tFAC=##class(HS.Facility.Config).%OpenId(tFACCode)
		If $ISObject(tFAC) {
			Set tReturn=tFAC.Contact.FirstName_" "_tFAC.Contact.LastName
		}
		Quit tReturn
	} ElseIf Args(1)="getHomeCommunityCode" {
		Quit $$$HomeCommunity
	} ElseIf Args(1)="getSystemOID" {
		#; Consider deleting this function in favor of ..getOIDForCode()
		Quit ##class(HS.Data.OIDMap).OIDForType($g(Args(2)),"AssigningAuthority",$g(Args(2)))
	} ElseIf Args(1)="GetIdentifierType" { Quit ##class(HS.AssignAuth.Config).GetIdentifierType($g(Args(2)))
	} ElseIf Args(1)="lookupIHETransaction" {
		Quit ..lookupIHETransaction(Args(2))
	} ElseIf Args(1)="resultFlag" {
		Quit ##class(HS.SDA3.LabResultItem).RangeResult(Args(2),Args(3))
	} ElseIf Args(1)="getNumberType" {
		Quit ##class(HS.AssignAuth.Config).GetNumberType(Args(2))
	} ElseIf Args(1)="debug" {
		Set @("^" _ Args(2)) = Args(3)
		Quit ""
	} ElseIf Args(1)="getOIDForCode" {
		Quit ..getOIDForCode(Args(2), $Get(Args(3)), $Get(Args(4)))
	} ElseIf Args(1)="getCodeForOID" {
		Quit ..getCodeForOID(Args(2), $Get(Args(3)), $Get(Args(4)))
	} ElseIf Args(1)="getDescriptionForOID" {
		Quit ..getDescriptionForOID(Args(2), $Get(Args(3)), $Get(Args(4), Args(2)))
	} ElseIf Args(1)="getURLForCode" {
		Quit ..getURLForCode(Args(2), $Get(Args(3)), $Get(Args(4)))
	} ElseIf Args(1)="getCodeForURL" {
		Quit ..getCodeForURL(Args(2), $Get(Args(3)), $Get(Args(4)))
	} ElseIf Args(1)="getDescriptionForURL" {
		Quit ..getDescriptionForURL(Args(2), $Get(Args(3)), $Get(Args(4), Args(2)))
	} ElseIf Args(1)="hex2dec" { Quit ..hex2dec(Args(2))
	} ElseIf Args(1)="uuid2oid" { Quit ..uuid2oid(Args(2))
	} ElseIf Args(1)="createUUID" { Quit ..createUUID()
	} ElseIf Args(1)="createOID" { Quit ..createOID()
	} ElseIf Args(1)="createHL7Timestamp" { Quit ..createHL7Timestamp()
	} ElseIf Args(1)="createID" { Quit ..createID($G(Args(2))) 
	} ElseIf Args(1)="varReset" { Quit ..varReset()	 
	} ElseIf Args(1)="varSet" { Quit ..varSet(Args...) 
	} ElseIf Args(1)="varGet"	{ Quit ..varGet(Args...) 
	} ElseIf Args(1)="varInc" { Quit ..varInc(Args...) 
	} ElseIf Args(1)="varKill" { Quit ..varKill(Args...) 
	} ElseIf Args(1)="varData" { Quit ..varData(Args...) 
	} ElseIf Args(1)="varConcat" { Quit ..varConcat(Args...) 
	} ElseIf Args(1)="varDebug" { Quit ..varDebug(Args...) 
	} ElseIf Args(1)="getPreviousUUID" { Quit ..getPreviousUUID(Args(2))
	} ElseIf Args(1)="encodeURL" { Quit $ZCVT(Args(2),"O","URL") 
	} ElseIf Args(1)="decodeURL" { Quit $ZCVT(Args(2),"I","URL")
	} ElseIf Args(1)="makeURL" { Quit ..makeURL(Args...)
	} ElseIf Args(1)="encodeJS" { Quit $ZCVT(Args(2),"O","JS") 
	} ElseIf Args(1)="decodeJS" { Quit $ZCVT(Args(2),"I","JS")
	} ElseIf Args(1)="getConfigValue" { Quit ..getConfigValue(Args(2))
	} ElseIf Args(1)="getHierarchicalConfigValue" { Quit ..getHierarchicalConfigValue(Args(2),Args...)
	} ElseIf Args(1)="getCodedEntryConfig" { Quit ..getCodedEntryConfig(Args(2),Args...)
	} ElseIf Args(1)="getCID" { 
		Set tCID=Args(2)
		Set:tCID["cid:" tCID=$e(tCID,5,*)
		Quit $ZCVT(tCID,"I","URL")
	} ElseIf Args(1)="getUniqueTime" { Quit ..getUniqueTime(Args(2),Args(3))
	} ElseIf Args(1)="toUpper" { Quit $ZConvert($Get(Args(2)), "U")
	} ElseIf Args(1)="toLower" { Quit $ZConvert($Get(Args(2)), "L")
	} ElseIf Args(1)="getServiceNameFromOID" { Quit ..getServiceNameFromOID($G(Args(2)),$G(Args(3)),$G(Args(4)),$G(Args(5)))
	} ElseIf Args(1)="getServiceHostFromOID" { Quit ..getServiceHostFromOID($G(Args(2)),$G(Args(3)),$G(Args(4)),$G(Args(5)))
	} ElseIf Args(1)="getServiceURLFromOID" { Quit ..getServiceURLFromOID($G(Args(2)),$G(Args(3)),$G(Args(4)),$G(Args(5)))
	} ElseIf Args(1)="getServiceNameFromURL" { Quit ..getServiceNameFromURL($G(Args(2)))
	} ElseIf Args(1)="getServiceOIDFromURL" { Quit ..getServiceOIDFromURL($G(Args(2)))
	} ElseIf Args(1)="addFilterEntity" { Quit ##Class(HS.Reports.Patient.ReportRun).AddFilterEntity(Args(2),$G(Args(3)),$G(Args(4)),$G(Args(5)),$G(Args(6)),$G(Args(7)),$G(Args(8)))
	} ElseIf Args(1)="includeEntity" { Quit ##Class(HS.Reports.Patient.ReportRun).IncludeEntity(Args(2))
	} ElseIf Args(1)="generateVisitNumber" { Quit $TR($ZTIMESTAMP,",.","")_$R(10000)
	} ElseIf Args(1)="addStreamletType" { Set %streamletType(Args(2))=$G(Args(3)) Quit ""
	} ElseIf Args(1)="recordSDAData" { Set %SDAData=Args(2) Quit ""
	} ElseIf Args(1)="xmltimestampToUTC" {
		Quit ..xmltimestampToUTC(Args(2))
	} ElseIf Args(1)="getQuickStream" { Quit ..getQuickStream(Args(2))
	} ElseIf Args(1)="addUTCtoDateTime" { Quit ..returnAsUTC(Args(2))  
	} ElseIf Args(1)="xmltimestampToLocal" { Quit ..returnAsLocal(..xmltimestamp(Args(2))) }
	
	
	ZTRAP "BAD:"_$g(Args(1))
}

}
