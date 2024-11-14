/// Add custom styling overrides to existing CSS Files in the /csp/broker folder
/// Usage:
///     Put all new CSS styling declarations on one line
///     Provide a line handle for later automated updates / deletes
///     Call EditCSS(pFilename, pLineHandle = "/*deimpl*/", pNewCSSLine, pToggleOnOff)
/// A backup file is created before any changes are made
Class HS.Local.zimpl.Utils.SmpStyler [ Abstract ]
{

/// Fixes the inputs overflowing out of the menus, shortens extremely long buttons, suggests that text inputs fill the containing space
ClassMethod UserClinicianRegistry(pToggleOnOff As %Boolean = 1) As %Status
{
    #dim tCssFile = "ZEN_Component__core_3.css"
    #dim tLineHandle = "/*deimpl:UserClinicianRegistry*/"
    
    set tNewCss = "#hsSideBar, #menuBar.zendiv {width:  auto !important;}"
                    _" input[type=button].button {line-break: auto; white-space: normal;}"
                    _" input[type=text].text {width: -moz-available; width: -webkit-fill-available;}"

    return ..%EditCSS(tCssFile, tLineHandle, tNewCss, pToggleOnOff)
}

ClassMethod SmpTitleBarColor(pToggleOnOff As %Boolean = 1) As %Status
{
    #dim tCssFile = "ZEN_Component__core_3.css"
    #dim tLineHandle = "/*deimpl:TitlebarColoredBySystemMode*/"

    #dim tSystemMode = $get(^%SYS("SystemMode"), "UNSET")
    #dim tColors,tCss,tD,tL

	set tColors("LIVE")				= $listbuild("red","whitesmoke")
	set tColors("TEST")				= $listbuild("gold","yellow")
	set tColors("DEVELOPMENT")  	= $listbuild("#44c7c27d","#c1f1c157")
	set tColors("FAILOVER") 		= $listbuild("deepskyblue","lightskyblue")
	set tColors("UNSET")			= $listbuild("gray","white")
	
	set tD	= $listget(tColors(tSystemMode), 1)
	set tL	= $listget(tColors(tSystemMode), 2)
	
	set tNewCss	= ".portalTitle {"_
				"background: -webkit-linear-gradient(bottom,"_tD_","_tL_") !important; "_
				"background: -moz-linear-gradient(bottom,"_tD_","_tL_",silver 200%) !important; "_
				"background: linear-gradient(bottom,"_tD_","_tL_",silver 200%) !important; }"_
                " .portalTitleServerFlag {border: none !important; text-shadow: 0 0 0.5em #fffffffa; font-style: italic; color: dimgrey !important;}"_
                " .portalTitleInfoVal:nth-last-child(1 of .portalTitleInfoVal) {font-size: larger; text-shadow: 0 0 2px #e1c07d; text-decoration: underline;}"

    return ..%EditCSS(tCssFile, tLineHandle, tNewCss, pToggleOnOff)
}

ClassMethod %EditCSS(pFilename, pLineHandle = "/*deimpl:newtag*/", pNewCSSLine, pToggleOnOff As %Boolean = 1) As %Status
{
    #dim tFilename	= ##class(%Library.File).Construct(##class(%Library.File).ParentDirectoryName(##class(%Library.File).ManagerDirectory()), "csp", "broker", pFilename)
    #dim tOrigFile as %Stream.FileCharacter = ##class(%Stream.FileCharacter).%New()
    #dim tTmpFile as %Stream.TmpCharacter = ##class(%Stream.TmpCharacter).%New()
    #dim tException as %Exception.StatusException
    #dim tSc = $$$OK

    try {
        
        if ##class(%Library.File).Exists(tFilename) {

            // Create a backup
            set tBackup = tFilename_$zstrip($zdt($h,3),"*P")
            write "Creating a backup as "_tFilename_$zstrip($zdt($h,3),"*P"),!
            $$$ThrowOnError(##class(%Library.File).CopyFile(tFilename, tBackup))

            // Link to File
            write "Writing to file",!
            $$$ThrowOnError(tOrigFile.LinkToFile(tFilename))
            
            // Copy the contents of the original file, intentionally skipping any line containing pLineHandle
            while 'tOrigFile.AtEnd {
                set tLine=tOrigFile.ReadLine()
                continue:(tLine[pLineHandle)
                do tTmpFile.WriteLine(tLine)
            }
            
            // Now write pNewCSSLine if pToggleOnOff flag is set to 1
            do:(pToggleOnOff) tTmpFile.WriteLine(pLineHandle_" "_pNewCSSLine)

            // Copy the tmpFile back to the OrigFile and Save
            write "Saving",!
            $$$ThrowOnError(tOrigFile.CopyFrom(tTmpFile))
            $$$ThrowOnError(tOrigFile.%Save())
            
            write "Clearing caches",!
            do ..%ClearCache()	
        }

    } catch tException {
        set tSc = tException.AsStatus()
    }

    return tSc
}

/// ClearCache() executed for any known WebGateways. Unclear if this is effective in an HS2024 or later setup! 
ClassMethod %ClearCache()
{
    for tIter = 1:1:$SYSTEM.CSP.GetGatewayRegistry().GetGatewayMgrs().Count() {
        do $SYSTEM.CSP.GetGatewayRegistry().GetGatewayMgrs().GetAt(tIter).ClearCache()
    }
}

}
