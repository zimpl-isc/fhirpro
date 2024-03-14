Class HS.Local.zimpl.fhirpro.UI.CodeSystemProcessor Extends %CSP.Page
{

ClassMethod OnPage() As %Status
{
	#dim TF = 1
	#dim file as %CSP.BinaryStream
	set codeSystem = $get(%request.Data("codeSystem",1))
	set delim = $get(%request.Data("delim",1))
	set codeCol = $get(%request.Data("code",1))
	set descrCol = $get(%request.Data("descr",1))
	set selector = $get(%request.Data("selector",1))
	set file = $get(%request.MimeData("file",1))
	
	
	//w file.CharSetSet("UTF8")_"<BR>"
	//w file.ContentTypeSet("application/octet-stream")
	
	w "selector: "_selector_"<br>"
	
	//return 1
	
	if (codeSystem'="") && (delim'="") &&(codeCol'="") && (descrCol'="") && (file'="") {
		
		// Create an entry in the OIDMap for the CodeSystem (if not exists!)
		
		set tSc = ##class(HS.Data.OIDMap).FileOID(codeSystem, "CodeSystem", codeSystem, "HSFHIRToolkit Generated")
		&html<#(tSc)# CodeSystem #(codeSystem)# added to the OIDMap. Please manually edit the description, OID and URL as needed.<br>>
		
		while 'file.AtEnd {
			set TF=1
			set line = file.ReadLine()
			set cnt = $get(cnt)+1
			
			set tCode = $piece(line, delim, codeCol)
			set tDescr = $piece(line, delim, descrCol)
			set tDescr = $ZCVT(tDescr, "I", "UTF8")
			
			if (selector'="") {
				set sCol = $piece(selector, "{#", 2)
				set sCol = $piece(sCol, "}")
				
				set sVal = $piece(line, delim, sCol)
				set sOpr = $piece(selector, "}" ,2)
				
				continue:(sVal="")||(sOpr="")
				
				xecute "set TF="_sVal_sOpr
				if 'TF {
					write "SKIPPING "_tCode_"<BR>"
					continue
				}
				
				
			}
			set tSc = ##class(HS.Registry.Codes).AddEditCode(codeSystem,tCode,tDescr)
			&html<#(tCode)#:#(tDescr)#:#(tSc)#<br>>
			quit:'tSc
			//quit:cnt=100
			
		}	
		
		
		
		
	}
	
	
	
	return $$$OK
}

}
