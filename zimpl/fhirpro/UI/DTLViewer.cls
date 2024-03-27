/**
* Application for searching and documenting Data Transformations.
* Create an extension of this class for custom grouping of DTLs.
*
* @version 1.0 2024-03-27
* @author Brandon Thomas
*/

Class HS.Local.zimpl.fhirpro.UI.DTLViewer Extends HS.Local.zimpl.fhirpro.UI.Super
{

/* Customizable Parameters for Subclass ------------------------------------>*/
Parameter PageTitleDTLList = "System DTL Viewer";

/// Option link to the specification. Use html tags to create the link and description.
/// Example: "<a href=""https://simplifier.net/organization/koordinationsstellemii"" target=_blank>simplifier.net/koordinationsstellemii</a>"
Parameter SpecificationLink;

/// Comma-delimited list of Package names to look for DTLs
Parameter PackageNameList = "HS.FHIR.DTL.,HS.Gateway.,HS.Hub.";

/*<------------------------------------ Customizable Parameters for Subclass */
Parameter SuperClass = "HS.Local.zimpl.fhirpro.UI.DTLViewer";

/// Use of a Work-In-Progress (WIPString) in DTL comments or elsewhere will be displayed as a hint when found
Parameter WIPString = "TODO:";

/// Format: ClassName:XDataName
Parameter XDataForXSL = "HS.Local.zimpl.fhirpro.UI.DTLViewerXSL:XSL";

/// Name of callback handler for isc:evaluate() functions
Parameter XSLTCallbackHandlerClass = "HS.Local.zimpl.fhirpro.UI.Utils.XSLTCallbackHandler";

/// Delimiter used by the application for bundling searchterms.
/// Should be something that is never contained in the DTL content and therefore searchable
Parameter InternalDelim = "!$%&)";

/// Viewed with the DTL parameter it will show the documentation for that DTL
/// else a list of available DTLs within the <parameter>PackageName</parameter> are displayed 
ClassMethod OnPage() As %Status
{
	
	#dim tDTLClass
	#dim tSc as %Status
	
	#dim tSelectedGroup = $piece(%request.PageName, ".cls")
	#dim tSelectedPackage = $get(%request.Data("package",1), $listget($listfromstring(..#PackageNameList),1))
	#dim tDTLName = $get(%request.Data("DTL",1))
	#dim tSearchParam = $get(%request.Data("search",1))
	#dim tSuperClass = ..#SuperClass
	
	if (tDTLName '= "") {
		
		do ..ShowDTL(tDTLName)
		
	} else {	// Show list of available DTLs for the PackageName (Class Parameter)
		#dim tDTLStream as %Stream.TmpCharacter
		#dim tFoundTODO,tTODOSpan,tTODOTitle
	
		&html<<!DOCTYPE HTML>
		<html>
			<head>
				<title>#(..#PageTitleDTLList)#</title>
				#(..MetaTags())#
				
				<script src="/csp/broker/cspxmlhttp.js"></script>
				<script type="text/javascript">
				function exportDTLs() {
					var tExportSuggestion = '#($replace(##class(%File).NormalizeFilename($system.Util.InstallDirectory()_"/UserDocumentation"), "\", "\\"))#';
					var serverExportDir = window.prompt('Enter a folder on the server for the export:',tExportSuggestion);
					var package = $("#PackageName").val();
					var searchTerm = $("#Search").val();
					if (serverExportDir !== null && serverExportDir !== "") {
						var tSc = #(##class(%CSP.Page).HyperEventCall(..%ClassName(1)_".Export", "package,searchTerm,serverExportDir", 1))#;
						if (tSc!==null) {alert('Problem writing files?')} else {alert('Export to server finished.')}
					}
				}
				function openPage(chgGroup) {
					var groupPage = $("#GroupPage").val();
					var package = $("#PackageName").val();
					var searchTerm = $("#Search").val();
					var query = (chgGroup ? 'package='+package : '') + '&search='+searchTerm;
					window.open(groupPage+'.cls?'+query, '_self');
				}
				</script>
				
				#(..LinkJS("jquery-3.7.1.min.js"))#
				#(..LinkJS("jquery.dataTables.min.js"))#
				#(..LinkCSS("jquery.dataTables.min.css"))#
				#(..LinkCSS("DTLViewer.css"))#
				
			</head>
			
			<body>
				<h2>#(..#PageTitleDTLList)#</h2>
				>
				if (..#SpecificationLink'="") {
					&html<<h6 class="specLink">Specification:#(..#SpecificationLink)#</h6>>
				}
				&html<
				<ul>
					<li><b>Page:</b>
						<select id="GroupPage" onchange="openPage(false)">>
							&sql(select list(ID) into :tGroupList from %Dictionary.CompiledClass where Super = :tSuperClass)
							
							set tGroupList = $listfromstring(tGroupList)_$listbuild(tSuperClass)
							set tGroupList = $listtostring(tGroupList)
							
							for tGroupIter = 1:1:$length($get(tGroupList), ",") {
								set tGroupOption = $piece(tGroupList, ",", tGroupIter)
								set tSelected = $select((tGroupOption = tSelectedGroup):" selected", 1:"")
								&html<<option value="#(tGroupOption)#"#(tSelected)#>#($parameter(tGroupOption, "PageTitleDTLList"))#</option>>
							}
					
						&html<</select></li>
					<li><b>Package:</b> 
						<select id="PackageName" onchange="openPage(true)">>
						
						for tPackageIter = 1:1:$length(..#PackageNameList, ",") {
							set tPackageOption = $piece(..#PackageNameList, ",", tPackageIter)
							set tSelected = $select((tPackageOption = tSelectedPackage):" selected", 1:"")
							&html<<option value="#(tPackageOption)#"#(tSelected)#>#(tPackageOption)#</option>>	
						}
							
						&html<</select></li>
					<li><label>Search in DTLs: <input id="Search" value="#(tSearchParam)#" title="Case-sensitive search in DTL content"></label></li>
				</ul>
			
				<table id="DTLList" class="display hover" data-page-length='50'>
					<thead>
					<tr>
						<th>Classname</th>
						<th>Source Object Type</th>
						<th>Target Object Type</th>
					</tr>
					</thead>
					<tbody>
				>
		
				set tRS = ##class(%ResultSet).%New()
				do tRS.Prepare("select Name as tDTLClass,ClassCompileError,ClassDefinitionError from %Dictionary.CompiledClass "_
								"where Name like ? and PrimarySuper like '%Ens.DataTransformDTL%'")
				do tRS.Execute(tSelectedPackage_"%")
				
				while tRS.Next() {
					
					set tDTLClass = tRS.Data("tDTLClass")
					kill tFoundTerms
					
					set tDTLStream = ..GetXData(tDTLClass, "DTL", 1)
					set tSearchTerms = ..#WIPString _ $select(tSearchParam'="": ..#InternalDelim_tSearchParam, 1:"")
					do ..SearchStream(tDTLStream, tSearchTerms, .tFoundTerms)
					
					continue:((tSearchParam'="") && '$get(tFoundTerms(tSearchParam)))
					
					// If there is a compiler error on the DTL, that will be shown instead of any possible TODO:
					if (tRS.Data("ClassCompileError")'="") {
						set tWarning = "<span title='"_##class(%CSP.Page).EscapeHTML(tRS.Data("ClassCompileError"))_"' class='warning'>CompileError</span>"
						
					} elseif ($get(tFoundTerms(..#WIPString))) {
						set tWarning = "<span title='""TODO:"" found in DTL' class='warning'>TODO</span>"
						
					} else {
						set tWarning = ""
					}
					
					#dim tSourceType	= $classmethod(tDTLClass, "GetSourceType")
					#dim tSourceDocType	= $classmethod(tDTLClass, "GetSourceDocType")
					#dim tTargetType	= $classmethod(tDTLClass, "GetTargetType")
					#dim tTargetDocType	= $classmethod(tDTLClass, "GetTargetDocType")
					
					&html<
					<tr onclick="window.open('?DTL=#(tDTLClass)#', '_blank');" style="cursor:pointer;">
						<td>#(tDTLClass)#</td>
						<td>#(tSourceType)#>
						if (tSourceDocType'="") {
							&html<<span class="docType">#(tSourceDocType)#</span>>
						}
				&html<</td>
						<td>#(tTargetType)#>
						if (tTargetDocType'="") {
							&html<<span class="docType">#(tTargetDocType)#</span>>
						}
				&html<#(tWarning)# </td> 
					</tr>
					>
				}
		
		&html<</tbody></table>
				<script type="text/javascript">
				$(document).ready(function(){
					$('#DTLList').DataTable({
					  "language": {
					    "search": "Filter records:"
					  }});
					$("#Search").select();
					$("#Search").on('keyup', function (e) {
					    if (e.key === 'Enter' || e.keyCode === 13) {
						    var package = $("#PackageName").val();
						    var search = $("#Search").val();
					        window.open('?package='+package+'&search='+search,'_self');
					    }
					});
				});
				
				</script>
				<button onclick="exportDTLs()">Export DTL Documentation</button>
			</body>
		</html>>
		
	}
	
	return $$$OK
}

ClassMethod SearchStream(pStream, pSearchTerms, Output pFoundTerms = "")
{
	do pStream.Rewind()
	while 'pStream.AtEnd {
		set tChunk = pStream.Read()
		
		for tTermIter = 1:1:$length(pSearchTerms, ..#InternalDelim) {
			set tSearchTerm = $piece(pSearchTerms, ..#InternalDelim, tTermIter)
			if (tChunk [ tSearchTerm) {
				set pFoundTerms(tSearchTerm)=1
			}
		}
	}
	
	return $$$OK
}

ClassMethod ShowDTL(pDTLClassName, pOutputToDevice As %Boolean = 1, pOutputStream As %FileCharacterStream)
{
	
		/*  For client-side transformations...
		if '$$$ISERR(tSc) {
			&html<<?xml version="1.0" encoding="UTF-8"?>
			<?xml-stylesheet type="text/xsl" href="#(..#StyleSheet)#.cls?DTL=#(tDTLName)#" ?>
			#(tXML.Read())#>
			
		} else {
			&html<#(tSc)#>
		}
		*/
	#dim tException,tParams,tPort,tSc,tXML,tXSL		
		
	try {
		
		$$$ThrowOnError(##class(Ens.Util.URLStream).GetURLStream("xdata://"_pDTLClassName_":DTL",.tXML))
		
		set pOutputStream = ##class(%FileCharacterStream).%New()
		set tPort = $Get(%request.CgiEnvs("SERVER_PORT"))
		set tParams("URL") = "'"_$Select(%request.Secure = 1: "https://", 1:"http://")_$Get(%request.CgiEnvs("SERVER_NAME"), "localhost")_$Select(tPort '= "" : ":"_tPort, 1:"")_%request.URL_"'"
			
		#dim tTransformer = ##class(HS.Util.XSLTTransformer).%New()
		set tTransformer.CallbackHandler = $classmethod(..#XSLTCallbackHandlerClass, "%New")
		
		$$$ThrowOnError(tTransformer.Transform(tXML, "xdata://"_..#XDataForXSL, .pOutputStream, .tParams))
		
		do ..ReplaceCollateralFolder(.pOutputStream)
		
		if pOutputToDevice {
			set tSc = pOutputStream.OutputToDevice()
		}
	
	} catch tException {
		
		&html<#($get(sc))#>
		
		&html<<hr>>
		
		&html<#(tException.AsStatus())#>
		
	}
}

ClassMethod ReplaceCollateralFolder(ByRef pStream As %Stream.TmpCharacter) As %Status
{
	set tStream  = ##class(%Stream.TmpCharacter).%New()
	while 'pStream.AtEnd {
		
		do tStream.Write($replace(pStream.ReadLine(), "[COLLATERALFOLDER]", ..#COLLATERALFOLDER))
	}
	
	set pStream = tStream
	
	return $$$OK
}

ClassMethod Export(pPackage, pSearchTerm, pTargetDirectory) As %Status
{
	#dim tStream as %Stream.GlobalBinary
	#dim tDTLClass
	#dim tCollateral,tCollateralFilename,tCopyFrom,tLine,tSc
	
	do ##class(%File).CreateDirectoryChain(pTargetDirectory)
	
	for tCollateral = "jquery-3.7.1.min.js","jquery.dataTables.min.js","jquery.dataTables.min.css","DTLViewer.css","images/" {
		set tCollateralFilename = ##class(%File).NormalizeFilename(pTargetDirectory_"/"_tCollateral)
		set tCopyFrom = ##class(%File).NormalizeFilename($system.Util.InstallDirectory()_..#COLLATERALFOLDER_tCollateral)
		
		if tCollateral["/" {
			// copy directory
			do ##class(%File).CopyDir(tCopyFrom,tCollateralFilename)
		} else {
			// copy file
			set tSc = ##class(%File).CopyFile(tCopyFrom,tCollateralFilename)
		}
	}
	
	set tIndex = ##class(%Stream.FileCharacter).%New()
	set tIndex.Filename = ##class(%File).NormalizeFilename(pTargetDirectory_"/index.html")
	do tIndex.Write("<html><head>"_
				"<script src=""jquery-3.3.1.slim.min.js"" type=""text/javascript"" language=""javascript""></script>"_
				"<script src=""jquery.dataTables.min.js"" type=""text/javascript"" language=""javascript""></script>"_
				"<link href=""jquery.dataTables.min.css"" rel=""stylesheet"" />"_
				"<link href=""DocsDtls.css"" rel=""stylesheet"" />"_
					"</head><body>")
					
	do tIndex.Write("<h2>"_..#PageTitleDTLList_"</h2><ul><li>Exported:"_$zdt($h, 3)_"</li></ul>")
	
	do tIndex.Write("<table id=""DTLList"" class=""display"" data-page-length=""50"">"_
					"<thead>"_"<tr>"_
						"<th>Classname</th>"_"<th>Source Object Type</th>"_"<th>Target Object Type</th>"_
					"</tr>"_"</thead>"_
					"<tbody>")
	
	
	set tRS = ##class(%ResultSet).%New()
	do tRS.Prepare("select Name as tDTLClass,ClassCompileError,ClassDefinitionError from %Dictionary.CompiledClass "_
								"where Name like ? and PrimarySuper like '%Ens.DataTransformDTL%'")
	do tRS.Execute(pPackage_"%")
	
	while tRS.Next() {
		
		set tSearchParam = pSearchTerm
		set tDTLClass = tRS.Data("tDTLClass")
		kill tFoundTerms
		
		set tDTLStream = ..GetXData(tDTLClass, "DTL", 1)
		set tSearchTerms = ..#WIPString _ $select(tSearchParam'="": ..#InternalDelim_tSearchParam, 1:"")
		do ..SearchStream(tDTLStream, tSearchTerms, .tFoundTerms)
					
		continue:((tSearchParam'="") && '$get(tFoundTerms(tSearchParam)))
		
		// If there is a compiler error on the DTL, that will be shown instead of any possible TODO:
		if (tRS.Data("ClassCompileError")'="") {
			set tWarning = "<span title='"_##class(%CSP.Page).EscapeHTML(tRS.Data("ClassCompileError"))_"' class='warning'>CompileError</span>"
			
		} elseif ($get(tFoundTerms(..#WIPString))) {
			set tWarning = "<span title='""TODO:"" found in DTL' class='warning'>TODO</span>"
			
		} else {
			set tWarning = ""
		}
				
			
		#dim tSourceType	= $classmethod(tDTLClass, "GetSourceType")
		#dim tSourceDocType	= $classmethod(tDTLClass, "GetSourceDocType")
		#dim tTargetType	= $classmethod(tDTLClass, "GetTargetType")
		#dim tTargetDocType	= $classmethod(tDTLClass, "GetTargetDocType")
		
		do tIndex.Write("<tr onclick=""window.open('"_tDTLClass_".html?DTL="_tDTLClass_"', '_blank');"" style=""cursor:pointer;"">"_
						"<td>"_tDTLClass_"</td>"_
						"<td>"_tSourceType_$select(tSourceDocType'="":"<span class=""docType"">"_tSourceDocType_"</span>", 1:"")_"</td>"_
						"<td>"_tTargetType_$select(tTargetDocType'="":"<span class=""docType"">"_tTargetDocType_"</span>", 1:"")_
								tWarning_"</td>"_
						"</tr>")
		
		do ..ShowDTL(tDTLClass,0,.tStream)
		
		set tFile = ##class(%Stream.FileCharacter).%New()
		set tFile.Filename = ##class(%File).NormalizeFilename(pTargetDirectory_"/"_tDTLClass_".html")
		
		while 'tStream.AtEnd {
			
			set tLine = tStream.ReadLine()
			
			if (tLine [ ..#COLLATERALFOLDER) {
				
				for tCollateralIter = 1:1:$length(tLine, ..#COLLATERALFOLDER) {
				
					set tCollateral = $piece($piece(tLine, ..#COLLATERALFOLDER, tCollateralIter), """")
					continue:(tCollateral'[".js")&&(tCollateral'[".css")
					
					set tCollateralFilename = ##class(%File).NormalizeFilename(pTargetDirectory_"/"_tCollateral)
					if '##class(%File).Exists(tCollateralFilename) {
						
						set tCopyFrom = ##class(%File).NormalizeFilename($system.Util.InstallDirectory()_..#COLLATERALFOLDER_tCollateral)
						set tSc = ##class(%File).CopyFile(tCopyFrom,tCollateralFilename)
					}
				}
				set tLine = $replace(tLine, ..#COLLATERALFOLDER, "")
			}
			
			do tFile.Write(tLine)
		}
		
		do tFile.%Save()
		
		set tFile = ""
		set tStream = ""
	}
	
	do tIndex.Write("</tbody></table>"_
					"<script type=""text/javascript"">"_
						"$(document).ready(function(){"_
						"$('#DTLList').DataTable({"_
							"""language"": {"_
							"""search"": ""Filter records:"""_
						"}});"_
						"});"_
					"</script>"_
					"</body></html>")
					
	do tIndex.%Save()	
	
	return $$$OK
}

ClassMethod GetXData(pClassName, pXDataName, pStripCRLF = 0) As %Stream.TmpCharacter
{
	#dim tXDataDef = ##class(%Dictionary.XDataDefinition).IDKEYOpen(pClassName, pXDataName)
	#dim tStream = ##class(%Stream.TmpCharacter).%New()
	#dim tData as %String
	
	if pStripCRLF {
	
		set tData = tXDataDef.Data.Read()
		set tData = $replace(tData, $char(13,10), "")
		set tData = $replace(tData, $char(9), "")
		do tStream.Write(tData)
		
	} else {
		do tStream.CopyFrom(tXDataDef.Data)
	}
	
	do tStream.Rewind()

	return tStream
}

}
