Class HS.Local.zimpl.Utils.Terminology.FunctionSet Extends Ens.Util.FunctionSet
{

ClassMethod TermsDescriptionForCode(pCodeSystem, pCode) As %String [ CodeMode = expression ]
{
##class(HS.Registry.Codes).GetDescription(pCodeSystem, pCode)
}

/// Return an HS.Registry.TranslationMap object
ClassMethod TermsMappingForCode(pFromCodeSystem As %String = "", pToCodeSystem As %String = "", pFromCode As %String = "") As HS.Registry.TranslationMap
{
    #dim tObject As HS.Registry.TranslationMap = ""
    #dim tMapId = $zcvt(pFromCodeSystem _ "||" _ pToCodeSystem _ "||" _ pFromCode, "U")

    if ##class(HS.Registry.TranslationMap).%ExistsId(tMapId)
    {
        // TODO: target code system could be inferred via HS.Registry.TranslationProfile.GetTranslationTarget
        // and an "active" Translation Profile. not supported atm.
        
        set tObject = ##class(HS.Registry.TranslationMap).%OpenId(tMapId)

        // if no description is given in the TranslationMap, try to get one from HS.Registry.Codes. returns "" if non-existent.
        if (tObject.ToDescription = "") {
            set tObject.ToDescription = ##class(HS.Registry.Codes).GetDescription(tObject.ToCodeSystem, tObject.ToCode)
        }
    }

    return tObject
}

ClassMethod TranslationMapRev(pFromCodeSystem As %String = "", pToCodeSystem As %String = "", pFromCode As %String = "")
{
    #dim tToCode = ""

    &sql(select FromCode into :tToCode from HS_Registry.TranslationMap where ToCode = :pFromCode and ToCodeSystem = :pFromCodeSystem and FromCodeSystem = :pToCodeSystem)

    set:(SQLCODE '= 0) tToCode=""

    return tToCode
}

ClassMethod TranslationMap(pFromCodeSystem As %String = "", pToCodeSystem As %String = "", pFromCode As %String = "")
{
    #dim tToCode = ""

    &sql(select ToCode into :tToCode from HS_Registry.TranslationMap where FromCode = :pFromCode and ToCodeSystem = :pToCodeSystem and FromCodeSystem = :pFromCodeSystem)

    set:(SQLCODE '= 0) tToCode=""

    return tToCode
}

}
