/**
* Stylesheet for DTL Viewer
*
* @version 1.0 2024-03-27
* @author Brandon Thomas, Nils Dittberner
*/

Class HS.Local.zimpl.fhirpro.UI.DTLViewerXSL
{

XData XSL
{
<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="2.0"
	xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
	xmlns:isc="http://extension-functions.intersystems.com" >
	<xsl:output method="html" version="5.0" encoding="UTF-8" indent="yes"/>
	<xsl:template match="/">
	<xsl:text disable-output-escaping='yes'>&lt;!DOCTYPE html&gt;</xsl:text>
		<html>
			<head>
				<link rel="icon" type="image/x-icon" href="favicon.ico" />
				<meta http-equiv="cache-control" content="no-cache, must-revalidate, post-check=0, pre-check=0"/>
				<meta http-equiv="cache-control" content="max-age=0"/>
				<meta http-equiv="expires" content="0"/>
				<meta http-equiv="expires" content="Tue, 01 Jan 1980 1:00:00 GMT"/>
				<meta http-equiv="pragma" content="no-cache"/>
				<script src="[COLLATERALFOLDER]jquery-3.7.1.min.js" type="text/javascript" ></script>
				<script src="[COLLATERALFOLDER]simple-tree-table.js" type="text/javascript"></script>
				<link href="[COLLATERALFOLDER]DTLViewer.css" rel="stylesheet" />
			</head>
			<body>
				<h2 id="HeaderTitle" />
				<a id="DTLEditor" target="_blank"></a>
				<div class="content">
					<div>
						<ul>
							<li>
								<b>Source:</b>&#160;
								<xsl:value-of select="/transform/@sourceClass" />
								<xsl:if test="/transform/@sourceDocType">
									<span class="docType">
										<xsl:value-of select="/transform/@sourceDocType" />
									</span>
								</xsl:if>
							</li>
							<li>
								<b>Target:</b>&#160;
								<xsl:value-of select="/transform/@targetClass" />
								<xsl:if test="/transform/@targetDocType">
									<span class="docType">
										<xsl:value-of select="/transform/@targetDocType" />
									</span>
								</xsl:if>
							</li>
							<li>
								<pre class="comment">
									<!-- TODO: link currently has to be at the end of the description without any whitespace following it. Make this more flexible? -->
									<xsl:call-template name="main_description_link">
										<xsl:with-param name="description" select="/transform/annotation" />
									</xsl:call-template>
								</pre>
							</li>
						</ul>
					</div>
					<div class="contentTable">
						<table id="ActionTable">
							<thead>
								<tr>
									<th>
Action
										<br/>
										<span id="collapser" style="cursor:pointer;" class="simple-tree-table-icon">-</span>
										<span id="expander" style="cursor:pointer;" class="simple-tree-table-icon">+</span>
									</th>
									<th>Condition</th>
									<th>Property (Target)</th>
									<th>Value (Source)</th>
									<th class="tableColDescr">Description</th>
								</tr>
							</thead>
							<tbody>
								<xsl:apply-templates select="/transform/*" />
							</tbody>
						</table>
					</div>
				</div>
				<script type="text/javascript">
$(document).ready(function(){
	$('#ActionTable').simpleTreeTable({
		expander: $('#expander'),
		collapser: $('#collapser'),
		margin:0.75
		});
	var dtl = window.location.search.split('DTL=')[1];
	$('#HeaderTitle').text(dtl);
	$('#DTLEditor').attr('href', 'EnsPortal.DTLEditor.zen?DT='+dtl+'.dtl');
	<xsl:text disable-output-escaping='yes'><![CDATA[$('#DTLEditor').html(" &#9998;");]]></xsl:text>
	$(document).attr('title', '[DTL] '+dtl);
	if(window.location.protocol == 'file:') {$("#DTLEditor").remove()}
});
</script>
			</body>
		</html>
	</xsl:template>
	<xsl:template match="comment">
		<xsl:variable name="nodeId">
			<xsl:number level="multiple" format="1" count="*" />
		</xsl:variable>
		<xsl:variable name="parentId">
			<xsl:call-template name="substring-before-last">
				<xsl:with-param name="string1" select="$nodeId" />
				<xsl:with-param name="string2" select="'.'" />
			</xsl:call-template>
		</xsl:variable>
		<tr data-node-id="{$nodeId}" data-node-pid="{$parentId}">
			<xsl:attribute name="class">level
				<xsl:value-of select="count(ancestor::*)-count(ancestor::true|ancestor::false|ancestor::case)" />
			</xsl:attribute>
			<td>
				<xsl:value-of select="name(.)"/>
			</td>
			<td colspan="4">
				<pre class="comment">
					<xsl:value-of select="annotation"/>
				</pre>
			</td>
		</tr>
	</xsl:template>
	<xsl:template match="trace">
		<xsl:variable name="nodeId">
			<xsl:number level="multiple" format="1" count="*" />
		</xsl:variable>
		<xsl:variable name="parentId">
			<xsl:call-template name="substring-before-last">
				<xsl:with-param name="string1" select="$nodeId" />
				<xsl:with-param name="string2" select="'.'" />
			</xsl:call-template>
		</xsl:variable>
		<tr data-node-id="{$nodeId}" data-node-pid="{$parentId}">
			<xsl:attribute name="class">level
				<xsl:value-of select="count(ancestor::*)-count(ancestor::true|ancestor::false|ancestor::case)" />
			</xsl:attribute>
			<td>
				<xsl:value-of select="name(.)"/>
			</td>
			<td colspan="2"></td>
			<td>
				<span class="code">
					<xsl:value-of select="@value"/>
				</span>
			</td>
			<td>
				<span class="comment">
					<xsl:value-of select="annotation"/>
				</span>
			</td>
		</tr>
	</xsl:template>
	<xsl:template match="assign">
		<xsl:variable name="nodeId">
			<xsl:number level="multiple" format="1" count="*" />
		</xsl:variable>
		<xsl:variable name="parentId">
			<xsl:call-template name="substring-before-last">
				<xsl:with-param name="string1" select="$nodeId" />
				<xsl:with-param name="string2" select="'.'" />
			</xsl:call-template>
		</xsl:variable>
		<tr data-node-id="{$nodeId}" data-node-pid="{$parentId}">
			<xsl:attribute name="class">level
				<xsl:value-of select="count(ancestor::*)-count(ancestor::true|ancestor::false|ancestor::case)" />
			</xsl:attribute>
			<xsl:if test="@disabled">
				<xsl:attribute name="class">disabled</xsl:attribute>
				<xsl:attribute name="title">disabled</xsl:attribute>
			</xsl:if>
			<td>
				<xsl:value-of select="@action" />
				<!--(<i><xsl:value-of select="name(.)"/></i>)-->
			</td>
			<td/>
			<td>
				<span class="code">
					<xsl:value-of select="@property"/>
					<!-- workaround to save a column.  Instead of showing the key separately, it is appended to the target property -->
					<xsl:if test="@key">
	@
						<xsl:value-of select="@key" />
					</xsl:if>
				</span>
			</td>
			<td>
				<span class="code">
					<xsl:value-of select="@value"/>
				</span>
			</td>
			<td>
				<span class="comment">
					<xsl:value-of select="annotation"/>
				</span>
			</td>
		</tr>
	</xsl:template>
	<xsl:template match="subtransform">
		<xsl:variable name="nodeId">
			<xsl:number level="multiple" format="1" count="*" />
		</xsl:variable>
		<xsl:variable name="parentId">
			<xsl:call-template name="substring-before-last">
				<xsl:with-param name="string1" select="$nodeId" />
				<xsl:with-param name="string2" select="'.'" />
			</xsl:call-template>
		</xsl:variable>
		<tr data-node-id="{$nodeId}" data-node-pid="{$parentId}">
			<xsl:attribute name="class">level
				<xsl:value-of select="count(ancestor::*)-count(ancestor::true|ancestor::false|ancestor::case)" />
			</xsl:attribute>
			<xsl:if test="@disabled">
				<xsl:attribute name="class">disabled</xsl:attribute>
				<xsl:attribute name="title">disabled</xsl:attribute>
			</xsl:if>
			<td>
				<xsl:value-of select="name(.)"/>
			</td>
			<td title="ClassName of subtransform (not a condition)">
				<a href="?DTL={@class}" class="code">
					<xsl:value-of select="@class"/>
				</a>
			</td>
			<td>
				<span class="code">
					<xsl:value-of select="@targetObj"/>
				</span>
				<xsl:if test="isc:evaluate('getDtlTargetDoctype', @class)">
					<span class="docType">
						<xsl:value-of select="isc:evaluate('getDtlTargetDoctype', @class)"/>
					</span>
				</xsl:if>
			</td>
			<td>
				<span class="code">
					<xsl:value-of select="@sourceObj"/>
				</span>
				<xsl:if test="isc:evaluate('getDtlSourceDoctype', @class)">
					<span class="docType">
						<xsl:value-of select="isc:evaluate('getDtlSourceDoctype', @class)"/>
					</span>
				</xsl:if>
			</td>
			<td>
				<span class="comment">
					<xsl:value-of select="annotation"/>
				</span>
			</td>
		</tr>
	</xsl:template>
	<xsl:template match="if">
		<xsl:variable name="nodeId">
			<xsl:number level="multiple" format="1" count="*" />
		</xsl:variable>
		<xsl:variable name="parentId">
			<xsl:call-template name="substring-before-last">
				<xsl:with-param name="string1" select="$nodeId" />
				<xsl:with-param name="string2" select="'.'" />
			</xsl:call-template>
		</xsl:variable>
		<tr data-node-id="{$nodeId}" data-node-pid="{$parentId}">
			<xsl:attribute name="class">level
				<xsl:value-of select="count(ancestor::*)-count(ancestor::true|ancestor::false|ancestor::case)" />
			</xsl:attribute>
			<xsl:if test="@disabled">
				<xsl:attribute name="class">disabled</xsl:attribute>
				<xsl:attribute name="title">disabled</xsl:attribute>
			</xsl:if>
			<td>
				<xsl:value-of select="name(.)"/>
			</td>
			<td colspan="3">
				<span class="code">
					<xsl:value-of select="@condition"/>
				</span>
			</td>
			<td>
				<span class="comment">
					<xsl:value-of select="annotation"/>
				</span>
			</td>
		</tr>
		<xsl:apply-templates />
	</xsl:template>
	<xsl:template match="true|false">
		<xsl:variable name="nodeId">
			<xsl:number level="multiple" format="1" count="*" />
		</xsl:variable>
		<xsl:variable name="parentId">
			<xsl:call-template name="substring-before-last">
				<xsl:with-param name="string1" select="$nodeId" />
				<xsl:with-param name="string2" select="'.'" />
			</xsl:call-template>
		</xsl:variable>
		<tr data-node-id="{$nodeId}" data-node-pid="{$parentId}">
			<xsl:attribute name="class">level
				<xsl:value-of select="count(ancestor::*)-count(ancestor::true|ancestor::false|ancestor::case)" />
			</xsl:attribute>
			<td/>
			<td colspan="4">
				<xsl:value-of select="name(.)"/>
			</td>
		</tr>
		<xsl:apply-templates />
	</xsl:template>
	<xsl:template match="foreach">
		<xsl:variable name="nodeId">
			<xsl:number level="multiple" format="1" count="*" />
		</xsl:variable>
		<xsl:variable name="parentId">
			<xsl:call-template name="substring-before-last">
				<xsl:with-param name="string1" select="$nodeId" />
				<xsl:with-param name="string2" select="'.'" />
			</xsl:call-template>
		</xsl:variable>
		<tr data-node-id="{$nodeId}" data-node-pid="{$parentId}">
			<xsl:attribute name="class">level
				<xsl:value-of select="count(ancestor::*)-count(ancestor::true|ancestor::false|ancestor::case)" />
			</xsl:attribute>
			<xsl:if test="@disabled">
				<xsl:attribute name="class">disabled</xsl:attribute>
				<xsl:attribute name="title">disabled</xsl:attribute>
			</xsl:if>
			<td>
				<xsl:value-of select="name(.)"/>
			</td>
			<td></td>
			<td>
				<span class="code">
					<xsl:value-of select="@property"/>
				</span>
			</td>
			<td>
				<span class="code">
					<span class="group">key&lt;</span>
					<xsl:value-of select="@key" />
					<span class="group">&gt;</span>
				</span>
			</td>
			<td>
				<span class="comment">
					<xsl:value-of select="annotation"/>
				</span>
			</td>
		</tr>
		<xsl:apply-templates />
	</xsl:template>
	<xsl:template match="switch">
		<xsl:variable name="nodeId">
			<xsl:number level="multiple" format="1" count="*" />
		</xsl:variable>
		<xsl:variable name="parentId">
			<xsl:call-template name="substring-before-last">
				<xsl:with-param name="string1" select="$nodeId" />
				<xsl:with-param name="string2" select="'.'" />
			</xsl:call-template>
		</xsl:variable>
		<tr data-node-id="{$nodeId}" data-node-pid="{$parentId}">
			<xsl:attribute name="class">level
				<xsl:value-of select="count(ancestor::*)-count(ancestor::true|ancestor::false|ancestor::case)" />
			</xsl:attribute>
			<xsl:if test="@disabled">
				<xsl:attribute name="class">disabled</xsl:attribute>
				<xsl:attribute name="title">disabled</xsl:attribute>
			</xsl:if>
			<td>
				<xsl:value-of select="name(.)"/>
			</td>
			<td/>
			<td/>
			<td/>
			<td>
				<span class="comment">
					<xsl:value-of select="annotation"/>
				</span>
			</td>
		</tr>
		<xsl:apply-templates />
	</xsl:template>
	<xsl:template match="case">
		<xsl:variable name="nodeId">
			<xsl:number level="multiple" format="1" count="*" />
		</xsl:variable>
		<xsl:variable name="parentId">
			<xsl:call-template name="substring-before-last">
				<xsl:with-param name="string1" select="$nodeId" />
				<xsl:with-param name="string2" select="'.'" />
			</xsl:call-template>
		</xsl:variable>
		<tr data-node-id="{$nodeId}" data-node-pid="{$parentId}">
			<xsl:attribute name="class">level
				<xsl:value-of select="count(ancestor::*)-count(ancestor::true|ancestor::false|ancestor::case)" />
			</xsl:attribute>
			<xsl:if test="@disabled">
				<xsl:attribute name="class">disabled</xsl:attribute>
				<xsl:attribute name="title">disabled</xsl:attribute>
			</xsl:if>
			<td>
				<xsl:value-of select="name(.)"/>
			</td>
			<td>
				<span class="code">
					<xsl:value-of select="@condition"/>
				</span>
			</td>
			<td/>
			<td/>
			<td>
				<span class="comment">
					<xsl:value-of select="annotation"/>
				</span>
			</td>
		</tr>
		<xsl:apply-templates />
	</xsl:template>
	<xsl:template match="default">
		<xsl:variable name="nodeId">
			<xsl:number level="multiple" format="1" count="*" />
		</xsl:variable>
		<xsl:variable name="parentId">
			<xsl:call-template name="substring-before-last">
				<xsl:with-param name="string1" select="$nodeId" />
				<xsl:with-param name="string2" select="'.'" />
			</xsl:call-template>
		</xsl:variable>
		<tr data-node-id="{$nodeId}" data-node-pid="{$parentId}">
			<xsl:attribute name="class">level
				<xsl:value-of select="count(ancestor::*)-count(ancestor::true|ancestor::false|ancestor::case)" />
			</xsl:attribute>
			<xsl:if test="@disabled">
				<xsl:attribute name="class">disabled</xsl:attribute>
				<xsl:attribute name="title">disabled</xsl:attribute>
			</xsl:if>
			<td>
				<xsl:value-of select="name(.)"/>
			</td>
			<td>
				<span class="code">
					<xsl:value-of select="@condition"/>
				</span>
			</td>
			<td/>
			<td/>
			<td>
				<span class="comment">
					<xsl:value-of select="annotation"/>
				</span>
			</td>
		</tr>
		<xsl:apply-templates />
	</xsl:template>
	<xsl:template match="group">
		<xsl:variable name="nodeId">
			<xsl:number level="multiple" count="*" />
		</xsl:variable>
		<xsl:variable name="parentId">
			<xsl:call-template name="substring-before-last">
				<xsl:with-param name="string1" select="$nodeId" />
				<xsl:with-param name="string2" select="'.'" />
			</xsl:call-template>
		</xsl:variable>
		<tr data-node-id="{$nodeId}" data-node-pid="{$parentId}">
			<xsl:attribute name="class">level
				<xsl:value-of select="count(ancestor::*)-count(ancestor::true|ancestor::false|ancestor::case)" />
			</xsl:attribute>
			<xsl:if test="@disabled">
				<xsl:attribute name="class">disabled</xsl:attribute>
				<xsl:attribute name="title">disabled</xsl:attribute>
			</xsl:if>
			<td>
				<span class="group">
					<xsl:value-of select="name(.)"/>
				</span>
			</td>
			<td colspan="4">
				<span class="group">
					<xsl:value-of select="annotation"/>
				</span>
			</td>
		</tr>
		<xsl:apply-templates />
	</xsl:template>
	<xsl:template match="break">
		<xsl:variable name="nodeId">
			<xsl:number level="multiple" format="1" count="*" />
		</xsl:variable>
		<xsl:variable name="parentId">
			<xsl:call-template name="substring-before-last">
				<xsl:with-param name="string1" select="$nodeId" />
				<xsl:with-param name="string2" select="'.'" />
			</xsl:call-template>
		</xsl:variable>
		<tr data-node-id="{$nodeId}" data-node-pid="{$parentId}">
			<xsl:attribute name="class">level
				<xsl:value-of select="count(ancestor::*)-count(ancestor::true|ancestor::false|ancestor::case)" />
			</xsl:attribute>
			<xsl:if test="@disabled">
				<xsl:attribute name="class">disabled</xsl:attribute>
				<xsl:attribute name="title">disabled</xsl:attribute>
			</xsl:if>
			<td>
				<xsl:value-of select="name(.)"/>
			</td>
			<td/>
			<td/>
			<td/>
			<td>
				<span class="comment">
					<xsl:value-of select="annotation"/>
				</span>
			</td>
		</tr>
		<xsl:apply-templates />
	</xsl:template>
	<xsl:template match="annotation"></xsl:template>
	<xsl:template match="code">
		<xsl:variable name="nodeId">
			<xsl:number level="multiple" format="1" count="*" />
		</xsl:variable>
		<xsl:variable name="parentId">
			<xsl:call-template name="substring-before-last">
				<xsl:with-param name="string1" select="$nodeId" />
				<xsl:with-param name="string2" select="'.'" />
			</xsl:call-template>
		</xsl:variable>
		<tr data-node-id="{$nodeId}" data-node-pid="{$parentId}">
			<xsl:attribute name="class">level
				<xsl:value-of select="count(ancestor::*)-count(ancestor::true|ancestor::false|ancestor::case)" />
			</xsl:attribute>
			<xsl:if test="@disabled">
				<xsl:attribute name="class">disabled</xsl:attribute>
				<xsl:attribute name="title">disabled</xsl:attribute>
			</xsl:if>
			<td>
				<xsl:value-of select="@action" />
				<xsl:value-of select="name(.)"/>
			</td>
			<td></td>
			<td colspan="2">
				<span class="code">
					<xsl:value-of select="current()"/>
				</span>
			</td>
			<td>
				<span class="comment">
					<xsl:value-of select="annotation"/>
				</span>
			</td>
		</tr>
	</xsl:template>
	<xsl:template match="*">
		<xsl:message terminate="no">
	WARNING: Unmatched element: 
			<xsl:value-of select="name()"/>
		</xsl:message>
		<p>WARNING: Unmatched element: 
			<xsl:value-of select="name()"/>
		</p>
		<xsl:apply-templates />
	</xsl:template>
	<!-- Credits to https://stackoverflow.com/questions/1119449/removing-the-last-characters-in-an-xslt-string/1119666#1119666 -->
	<xsl:template name="substring-before-last">
		<xsl:param name="string1" select="''" />
		<xsl:param name="string2" select="''" />
		<xsl:if test="$string1 != '' and $string2 != ''">
			<xsl:variable name="head" select="substring-before($string1, $string2)" />
			<xsl:variable name="tail" select="substring-after($string1, $string2)" />
			<xsl:value-of select="$head" />
			<xsl:if test="contains($tail, $string2)">
				<xsl:value-of select="$string2" />
				<xsl:call-template name="substring-before-last">
					<xsl:with-param name="string1" select="$tail" />
					<xsl:with-param name="string2" select="$string2" />
				</xsl:call-template>
			</xsl:if>
		</xsl:if>
	</xsl:template>
	<!-- TODO: link currently has to be at the end of the description without anything (also whitespace) following it. Make this more flexible? -->
	<xsl:template name="main_description_link">
		<xsl:param name="description" select="''" />
		<xsl:choose>
			<xsl:when test="contains($description, 'https://')">
				<xsl:value-of select="substring-before($description, 'https://')"/>
				<a style="white-space:nowrap" href="https://{substring-after($description, 'https://')}" target="_blank">https://<xsl:value-of select="substring-after($description, 'https://')"/></a>
			</xsl:when>
			<xsl:otherwise>
				<xsl:value-of select="$description" />
			</xsl:otherwise>
		</xsl:choose>
	</xsl:template>
</xsl:stylesheet>
}

}
