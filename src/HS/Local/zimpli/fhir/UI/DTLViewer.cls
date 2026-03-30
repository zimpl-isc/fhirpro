/**
* Application for searching and documenting Data Transformations.
* Create an extension of this class for custom grouping of DTLs.
*
* @version 1.0 2024-03-27
* @author Brandon Thomas
*/

Class HS.Local.zimpli.fhir.UI.DTLViewer Extends HS.Local.zimpli.fhir.UI.Super
{

/* Customizable Parameters for Subclass ------------------------------------>*/
Parameter PageTitleDTLList = "System DTL Viewer";

/// Option link to the specification. Use html tags to create the link and description.
/// Example: "<a href=""https://simplifier.net/organization/koordinationsstellemii"" target=_blank>simplifier.net/koordinationsstellemii</a>"
Parameter SpecificationLink;

/// Comma-delimited list of Package names to look for DTLs
Parameter PackageNameList = "HS.FHIR.DTL.,HS.Gateway.,HS.Hub.";

Parameter DisplayOrder = 99;

/*<------------------------------------ Customizable Parameters for Subclass */
Parameter SuperClass = "HS.Local.zimpli.fhir.UI.DTLViewer";

/// Use of a Work-In-Progress (WIPString) in DTL comments or elsewhere will be displayed as a hint when found
Parameter WIPString = "TODO:";

/// Format: ClassName:XDataName
Parameter XDataForXSL = "HS.Local.zimpli.fhir.UI.DTLViewerXSL:XSL";

/// Name of callback handler for isc:evaluate() functions
Parameter XSLTCallbackHandlerClass = "HS.Local.zimpli.fhir.UI.Utils.XSLTCallbackHandler";

/// Delimiter used by the application for bundling searchterms.
/// Should be something that is never contained in the DTL content and therefore searchable
Parameter InternalDelim = "!$%&)";

/// Viewed with the DTL parameter it will show the documentation for that DTL
/// else a list of available DTLs within the <parameter>PackageName</parameter> are displayed 
ClassMethod OnPage() As %Status
{
	
	#dim tDTLClass
	#dim tSc as %Status
	
	#dim %tSelectedGroup = $get(%tSelectedGroup, $piece(%request.PageName, ".cls"))
	#dim tSelectedPackage = $get(%request.Data("package",1), $listget($listfromstring(..#PackageNameList),1))
	#dim tDTLName = $get(%request.Data("DTL",1))
	#dim tSearchParam = $get(%request.Data("search",1))
	#dim tSuperClass = ..#SuperClass
	
	if (tDTLName '= "") {
		
		do ..ShowDTL(tDTLName)
		
	} else {
		#dim tDTLStream as %Stream.TmpCharacter
		#dim tFoundTODO,tTODOSpan,tTODOTitle
	
		&html<<!DOCTYPE HTML>
<html>
<head>
	<title>#(..#PageTitleDTLList)#</title>
	#(..MetaTags())#
	#(..LinkJS("assets/ext/jquery-3.7.1.min.js"))#
	#(..LinkJS("assets/ext/jquery.dataTables.min.js"))#
	#(..LinkCSS("assets/ext/jquery.dataTables.min.css"))#
	#(..LinkCSS("assets/DTLViewer.css"))#
	<script src="/csp/broker/cspxmlhttp.js"></script>

	<script type="text/javascript">
	function exportDTLs() {
		var tExportSuggestion = '#($replace(##class(%File).NormalizeFilename($system.Util.InstallDirectory()_"/UserDocumentation"), "\", "\\"))#';
		var serverExportDir = window.prompt('Enter a folder on the server for the export:', tExportSuggestion);
		var packageName = $("#PackageName").val();
		var searchTerm = $("#Search").val();

		if (serverExportDir !== null && serverExportDir !== "") {
			var tSc = #(##class(%CSP.Page).HyperEventCall(..%ClassName(1)_".Export", "packageName,searchTerm,serverExportDir", 1))#;
			if (tSc !== null) {
				alert('Problem writing files?');
			} else {
				alert('Export to server finished.');
			}
		}
	}

	function openPage(chgGroup) {
		var groupPage = $("#GroupPage").val();
		var packageName = $("#PackageName").val();
		var searchTerm = $("#Search").val();
		var query = (chgGroup ? 'package=' + packageName : '') + '&search=' + searchTerm;
		window.open(groupPage + '.cls?' + query, '_self');
	}

	function wireDTLLinks(scope) {
		$(scope).find('.dataLinkEditor').each(function () {
			const doc = this.parentElement.getAttribute('data-doc');
			if (!doc) return;

			this.setAttribute('href', 'EnsPortal.DTLEditor.zen?DT=' + encodeURIComponent(doc) + '.dtl');
			this.setAttribute('target', '_blank');
		});

		$(scope).find('.dataLinkViewer').each(function () {
			const doc = this.parentElement.getAttribute('data-doc');
			if (!doc) return;

			this.setAttribute('href', '?DTL=' + encodeURIComponent(doc));
			this.setAttribute('target', '_blank');
		});
	}

	$(document).ready(function(){
		var table = $('#DTLList').DataTable({
			language: {
				search: "Filter records:"
			},
			pageLength: 50
		});

		wireDTLLinks(document);

		table.on('draw', function () {
			wireDTLLinks('#DTLList');
		});

		// delegated link protection
		$('#DTLList tbody').on('click', 'a', function (e) {
			e.stopPropagation();
		});

		// delegated hover
		$('#DTLList tbody').on('mouseenter', '.dataField', function () {
			const doc = this.getAttribute('data-doc');
			if (!doc) return;

			$('#tooltip-iframe').attr('src', '?DTL=' + encodeURIComponent(doc));
			$('#iframe-tooltip-container').show();
		});

		$('#DTLList tbody').on('mouseleave', '.dataField, #iframe-tooltip-container', function () {
			setTimeout(function () {
				if (!$('#iframe-tooltip-container').is(':hover') && !$('.dataField:hover').length) {
					$('#iframe-tooltip-container').hide();
					$('#tooltip-iframe').attr('src', '');
				}
			}, 200);
		});
	});
	</script>
</head>

<body>
<div id="pageShell">

	<div class="card pageHeader">
		<h1 class="pageTitle">#(..#PageTitleDTLList)#</h1>>
		if (..#SpecificationLink'="") {
			&html<<p class="specLink">Specification: #(..#SpecificationLink)#</p>>
		}
		&html<
	</div>

	<div class="card toolbarCard">
		<div class="toolbarGrid">
			<div class="fieldGroup">
				<label for="GroupPage">Page</label>
				<select id="GroupPage" onchange="openPage(false)">>
					
					set tQuery(1) = "select parent->ID as ParentId from %Dictionary.CompiledParameter"
					set tQuery(2) = "where (parent->Super=? or parent->ID=?)"
					set tQuery(3) = "and Name='DisplayOrder'"
					set tQuery(4) = "order by _Default"
					set tQuery = 4

					set tStatement = ##class(%SQL.Statement).%New()
					$$$ThrowOnError(tStatement.%Prepare(.tQuery))
					
					set tRS=tStatement.%Execute(tSuperClass,tSuperClass)
					#Dim tRS as %SQL.StatementResult
					
					While tRS.%Next() {
						set tGroupOption = tRS.%Get("ParentId")
						set tSelected = $select((tGroupOption = %tSelectedGroup):" selected", 1:"")
						&html<<option value="#(tGroupOption)#"#(tSelected)#>#($parameter(tGroupOption, "PageTitleDTLList"))#</option>>
					}
			
				&html<</select>
			</div>

			<div class="fieldGroup">
				<label for="PackageName">Package</label>
				<select id="PackageName" onchange="openPage(true)">>
				
				for tPackageIter = 1:1:$length(..#PackageNameList, ",") {
					set tPackageOption = $piece(..#PackageNameList, ",", tPackageIter)
					set tSelected = $select((tPackageOption = tSelectedPackage):" selected", 1:"")
					&html<<option value="#(tPackageOption)#"#(tSelected)#>#(tPackageOption)#</option>>	
				}
					
				&html<</select>
			</div>

			<div class="fieldGroup">
				<label for="Search">Search in DTLs</label>
				<input id="Search" type="text" value="#(tSearchParam)#" title="Case-sensitive search in DTL content">
			</div>

			<div class="actionGroup">
				<button class="exportButton" onclick="exportDTLs()">Export DTL Documentation</button>
			</div>
		</div>
	</div>

	<div class="card tableCard">
		<div class="tableHeader">
			<div class="tableTitle">Available data transformations</div>
		</div>

		<table id="DTLList" class="display hover">
			<thead>
				<tr>
					<th>Classname</th>
					<th>Source Object Type</th>
					<th>Target Object Type</th>
				</tr>
			</thead>
			<tbody>>
		
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
				<tr class="result">
					<td class="dataField" data-doc="#(tDTLClass)#">
						<a class="dataLinkEditor">&#9998;</a>
						<a class="dataLinkViewer">#(tDTLClass)#</a>
					</td>
					<td class="sourcetype">#(tSourceType)#>
					if (tSourceDocType'="") {
						&html<<span class="docType">#(tSourceDocType)#</span>>
					}
					&html<</td>
					<td class="targettype">#(tTargetType)#>
					if (tTargetDocType'="") {
						&html<<span class="docType">#(tTargetDocType)#</span>>
					}
					&html<#(tWarning)#</td>
				</tr>
				>
			}
		
		&html<</tbody>
		</table>
	</div>

	<div id="iframe-tooltip-container">
		<iframe id="tooltip-iframe" src="" frameborder="0"></iframe>
	</div>

</div>
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
	#dim tStream As %Stream.GlobalBinary
	#dim tDTLClass As %String
	#dim tLine As %String
	#dim tSc As %Status
	#dim tIndex As %Stream.FileCharacter
	#dim tFile As %Stream.FileCharacter
	#dim tRS As %ResultSet
	#dim tWarning As %String
	#dim tSearchParam As %String
	#dim tSearchTerms As %String
	#dim tDTLStream As %Stream.Object
	#dim tFoundTerms

	set tSc = $$$OK

	do ##class(%File).CreateDirectoryChain(pTargetDirectory)
	set tSc = ..CopyExportCollateral(pTargetDirectory)

	set tIndex = ##class(%Stream.FileCharacter).%New()
	set tIndex.Filename = ##class(%File).NormalizeFilename(pTargetDirectory_"/index.html")

	do tIndex.Write("<!DOCTYPE html><html><head>"_
		"<meta charset=""UTF-8"">"_
		"<meta name=""viewport"" content=""width=device-width, initial-scale=1"">"_
		"<script src=""jquery-3.7.1.min.js"" type=""text/javascript""></script>"_
		"<script src=""jquery.dataTables.min.js"" type=""text/javascript""></script>"_
		"<script src=""simple-tree-table.js"" type=""text/javascript""></script>"_
		"<link href=""jquery.dataTables.min.css"" rel=""stylesheet"" />"_
		"<link href=""DTLViewer.css"" rel=""stylesheet"" />"_
		"<style>"_
			"html,body{margin:0;padding:0;background:#f5f7fb;box-sizing:border-box;font-family:Arial,Helvetica,sans-serif;color:#1f2937;}"_
			"*,*::before,*::after{box-sizing:inherit;}"_
			"body{padding:16px;}"_
			"#pageShell{width:100%;padding:0;}"_
			".card{background:#ffffff;border:1px solid #e5e7eb;border-radius:12px;box-shadow:0 1px 3px rgba(0,0,0,0.06);margin-bottom:12px;}"_
			".pageHeader{padding:16px 18px 14px 18px;display:flex;align-items:center;justify-content:space-between;gap:12px;flex-wrap:wrap;}"_
			".pageTitle{margin:0;font-size:20px;font-weight:600;color:#1f2937;}"_
			".pageMeta{font-size:13px;color:#64748b;}"_
		"</style>"_
		"</head><body>")

	do tIndex.Write("<div id=""pageShell"">"_
		"<div class=""card pageHeader"">"_
			"<h1 class=""pageTitle"">"_..#PageTitleDTLList_"</h1>"_
			"<div class=""pageMeta"">Exported: "_$zdt($h,3)_"</div>"_
		"</div>"_
		"<table id=""DTLList"" class=""display hover"" data-page-length=""50"">"_
		"<thead><tr><th>Classname</th><th>Source Object Type</th><th>Target Object Type</th></tr></thead><tbody>")

	set tRS = ##class(%ResultSet).%New()
	do tRS.Prepare("select Name as tDTLClass,ClassCompileError,ClassDefinitionError from %Dictionary.CompiledClass "_
		"where Name like ? and PrimarySuper like '%Ens.DataTransformDTL%'")
	do tRS.Execute(pPackage_"%")

	while tRS.Next() {
		set tSearchParam = pSearchTerm
		set tDTLClass = tRS.Data("tDTLClass")
		kill tFoundTerms

		set tDTLStream = ..GetXData(tDTLClass,"DTL",1)
		set tSearchTerms = ..#WIPString_$select(tSearchParam'="":..#InternalDelim_tSearchParam,1:"")
		do ..SearchStream(tDTLStream,tSearchTerms,.tFoundTerms)

		continue:((tSearchParam'="") && '$get(tFoundTerms(tSearchParam)))

		if (tRS.Data("ClassCompileError")'="") {
			set tWarning = "<span title='"_##class(%CSP.Page).EscapeHTML(tRS.Data("ClassCompileError"))_"' class='warning'>CompileError</span>"
		} elseif ($get(tFoundTerms(..#WIPString))) {
			set tWarning = "<span title='""TODO:"" found in DTL' class='warning'>TODO</span>"
		} else {
			set tWarning = ""
		}

		#dim tSourceType = $classmethod(tDTLClass,"GetSourceType")
		#dim tSourceDocType = $classmethod(tDTLClass,"GetSourceDocType")
		#dim tTargetType = $classmethod(tDTLClass,"GetTargetType")
		#dim tTargetDocType = $classmethod(tDTLClass,"GetTargetDocType")

		do tIndex.Write("<tr onclick=""window.open('"_tDTLClass_".html?DTL="_tDTLClass_"','_blank');"" style=""cursor:pointer;"">"_
			"<td>"_tDTLClass_"</td>"_
			"<td>"_tSourceType_$select(tSourceDocType'="":"<span class=""docType"">"_tSourceDocType_"</span>",1:"")_"</td>"_
			"<td>"_tTargetType_$select(tTargetDocType'="":"<span class=""docType"">"_tTargetDocType_"</span>",1:"")_tWarning_"</td>"_
			"</tr>")

		do ..ShowDTL(tDTLClass,0,.tStream)

		set tFile = ##class(%Stream.FileCharacter).%New()
		set tFile.Filename = ##class(%File).NormalizeFilename(pTargetDirectory_"/"_tDTLClass_".html")

		while 'tStream.AtEnd {
			set tLine = tStream.ReadLine()
			set tLine = ..FlattenExportAssetReferences(tLine)

			if tLine["</body>" {
				do tFile.WriteLine(..ExportInjectScript(tDTLClass))
			}

			do tFile.WriteLine(tLine)
		}

		do tFile.%Save()
		set tFile = ""
		set tStream = ""
	}

	do tIndex.Write("</tbody></table>"_
		"<script type=""text/javascript"">"_
			"$(document).ready(function(){"_
				"$('#DTLList').DataTable({""language"":{""search"":""Filter records:""},""pageLength"":50});"_
			"});"_
		"</script>"_
		"</body></html>")

	do tIndex.%Save()

	quit tSc
}

ClassMethod CopyExportCollateral(pTargetDirectory) As %Status
{
	#dim tSc As %Status
	#dim tCollateral As %String
	#dim tCopyFrom As %String
	#dim tTargetName As %String
	#dim tTargetPath As %String

	set tSc = $$$OK

	for tCollateral = "assets/ext/jquery-3.7.1.min.js","assets/ext/jquery-ui-1.13.3.min.js","assets/ext/jquery.dataTables.min.js","assets/ext/jquery.dataTables.min.css","assets/ext/simple-tree-table.js","assets/DTLViewer.css","assets/ext/highlight.min.js","assets/ext/highlight.min.css","assets/ext/highlight.cos.js","assets/ext/highlight.xml.js","assets/ext/highlightjs-line-numbers.min.js","assets/ext/images/" {

		set tCopyFrom = ##class(%File).NormalizeFilename($system.Util.InstallDirectory()_"/csp/healthshare/zimplifhir/"_tCollateral)

		if $extract(tCollateral,*)="/" {
			set tTargetName = ..GetFinalPathSegment($extract(tCollateral,1,*-1))
			set tTargetPath = ##class(%File).NormalizeFilename(pTargetDirectory_"/"_tTargetName_"/")
			do ##class(%File).CopyDir(tCopyFrom,tTargetPath)
		} else {
			set tTargetName = ..GetFinalPathSegment(tCollateral)
			set tTargetPath = ##class(%File).NormalizeFilename(pTargetDirectory_"/"_tTargetName)
			set tSc = ##class(%File).CopyFile(tCopyFrom,tTargetPath)
		}
	}

	quit tSc
}

ClassMethod EscapeJS(pText As %String) As %String
{
	set pText = $replace(pText,"\","\\")
	set pText = $replace(pText,"'","\'")
	set pText = $replace(pText,$char(13),"")
	set pText = $replace(pText,$char(10),"\n")
	quit pText
}

/// Convert a source-relative collateral path into a real file-system path.
ClassMethod ResolveExportSourcePath(pRelativePath As %String) As %String
{
	quit ##class(%File).NormalizeFilename($system.Util.InstallDirectory()_"/csp/healthshare/zimplifhir/"_pRelativePath)
}

/// Return the last path segment of a file or directory path.
ClassMethod GetFinalPathSegment(pPath As %String) As %String
{
	#dim tPath As %String
	set tPath = pPath
	if $extract(tPath,*)="/" {
		set tPath = $extract(tPath,1,*-1)
	}
	quit $piece(tPath,"/",$length(tPath,"/"))
}

ClassMethod ExportInjectScript(pDTLClass As %String) As %String
{
	quit "<script type=""text/javascript"">"_
		"document.addEventListener('DOMContentLoaded',function(){"_
			"var t=document.getElementById('HeaderTitle');"_
			"if(t){t.textContent='"_..EscapeJS(pDTLClass)_"';"_
				"var m=document.createElement('div');"_
				"m.className='pageMeta';"_
				"m.textContent='Exported: "_$zdt($h,3)_"';"_
				"t.insertAdjacentElement('afterend',m);"_
			"}"_
			"var e=document.getElementById('DTLEditor');"_
			"if(e){e.style.display='none';}"_
		"});"_
		"</script>"
}

/// Rewrite live asset references to flat archive references.
ClassMethod FlattenExportAssetReferences(pLine As %String) As %String
{
	set pLine = $replace(pLine,"/csp/healthshare/zimplifhir/assets/ext/","")
	set pLine = $replace(pLine,"/csp/healthshare/zimplifhir/assets/","")
	set pLine = $replace(pLine,"assets/ext/","")
	set pLine = $replace(pLine,"assets/","")
	quit pLine
}

/// Resolve a referenced asset name in exported HTML back to its real source file.
ClassMethod ResolveAssetReferenceToSource(pAssetRef As %String) As %String
{
	#dim tBase As %String
	#dim tTry As %String

	set tBase = ##class(%File).NormalizeFilename($system.Util.InstallDirectory()_"/csp/healthshare/zimplifhir/")

	// already source-relative
	if ##class(%File).Exists(tBase_pAssetRef) {
		quit ##class(%File).NormalizeFilename(tBase_pAssetRef)
	}

	// ext assets
	set tTry = ##class(%File).NormalizeFilename(tBase_"assets/ext/"_pAssetRef)
	if ##class(%File).Exists(tTry) {
		quit tTry
	}

	// core assets
	set tTry = ##class(%File).NormalizeFilename(tBase_"assets/"_pAssetRef)
	if ##class(%File).Exists(tTry) {
		quit tTry
	}

	quit ""
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
