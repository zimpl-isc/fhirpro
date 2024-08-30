/**
* Starting web page for the FHIR Profiling toolkit which 
* consolidates all graphical tools into one UI
*
* @version 1.0 2024-03-27
* @author Brandon Thomas
*/

Class HS.Local.zimpl.fhirpro.UI.Index Extends HS.Local.zimpl.fhirpro.UI.Super
{

ClassMethod OnPage() As %Status
{
	&html<<!DOCTYPE HTML>
<html>
<head>
	<title>zimpl:FHIR Profiling Toolkit</title>
	#(..MetaTags())#
	#(..LinkJS("jquery-3.7.1.min.js"))#
	#(..XDataJS("StorageHandler"))#
	#(..DefaultStyle())#
	<style>
/* MENU CONTAINER ----- */
	.side_menu {
		background-color: #f7f7f7;
		/*background-image: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' width='4' height='4' viewBox='0 0 4 4'%3E%3Cpath fill='%23d5ddf6' fill-opacity='0.7' d='M1 3h1v1H1V3zm2-2h1v1H3V1z'%3E%3C/path%3E%3C/svg%3E");*/
		/*border-right: 2px ridge lightgray;*/
		height: 100vh;
		left: 0;
		position: fixed;
		top: 1em;
		width: 42px;
		box-shadow: 1px 0px 1px 0px #3339969c;
	}
	.side_menu .container {
		padding: 0 0.5em;
	}

/* STAGGER LIST ----- */

	.list_load {
		list-style: none;
		padding: 0;
	}
	.list_item {
		margin-bottom: 0.75em;
		-webkit-transition: all 200ms ease-in-out;
		transition: all 200ms ease-in-out;
		filter: opacity(0.3);
	}
	.list_item a {
		color: #fff;
		display: block;
		padding: 5px 10px;
		text-decoration: none;
	}
	.list_item a:hover {
		background: rgba(255,255,255,.2);
	}
	
	#StorageList dd {
		margin-left: 1em;
	}
    .inactive {
		filter: invert(50%);
	}
	.active {
		filter: drop-shadow(0px 0px 2px #333695);
	}
	.spacer_box {
		height: 2px;
		background: #7f7f7f;
		border-radius: 3px;
	}
	#TopBanner {
	top: 0;
	height: 22px;
	position: fixed;
	z-index: 100;
	width: 100%;
	background: linear-gradient(45deg, #333695, #44c7c2 40%);
	/*border-bottom: 2px silver ridge;*/
	font-size: 0.7em;
	font-style: italic;
	padding-left: 2em;
	color: whitesmoke;
	box-shadow: 0px 1px 1px 0px #3339969c;
}
	#PageDescr {
	float: right;
	margin-right: 3em;
	color: darkslategray;
}
#PageName {
	font-weight: bold;
	border-left: 1px solid whitesmoke;
	padding-left: 1em;
	margin-left: 1em;
}
	</style>
	<script type="text/javascript">
	$(document).ready(function(){
		setCurrentItemInTitle(getMpiid());
		$('.list_item').on('click', function(){toggle(this.id)});
	});


	iframePages = {
		"Compare_SDA3_to_FHIR":"HS.Local.zimpl.fhirpro.UI.SDA3uFHIRViewer.cls",
		"Configure_Datasource":"HS.Local.zimpl.fhirpro.UI.Datasource.cls",
		"FHIR_Network":"HS.Local.zimpl.fhirpro.UI.FHIRNetwork.cls",
		"FHIR_Timeline":"HS.Local.zimpl.fhirpro.UI.FHIRTimeline.cls",
		"Management_Portal":"EnsPortal.ProductionConfig.zen?$NAMESPACE=ZIMPLFHIRPRO&ts="+Date.now(), //Fixes caching issues in iframe?
		"FHIR_Tester_Inbound_to_Outbound":"HS.Local.Impl.Test.FHIR.UnitTest.cls",
		"DTL_Viewer":"HS.Local.zimpl.fhirpro.UI.DTLViewer.cls",
		"Find_In_Files":"HS.Local.zimpl.fhirpro.UI.FindInFiles.cls",
		"CodeSystem_Importer":"HS.Local.zimpl.fhirpro.UI.CodeSystemImporter.cls",
		"HL7_Annotations":"HS.UI.HL7.cls",
		"Registry":"../hsregistry/HS.UI.Home.cls",
	};

	function mainFrameReady() {
		console.log('mainframe ready');
		$('#LoadingMessage').toggle(false);
	}
	
	function toggle(activeElementId) {
		console.log('toggle ' + activeElementId);
		$('#LoadingMessage').toggle(true);
		
		$('.list_item').removeClass('active');
		$('#'+activeElementId).addClass('active');
		
		$('#MainFrame').attr('src',iframePages[activeElementId]);
		
		if ((activeElementId === 'Management_Portal') 
			|| (activeElementId === 'HL7_Annotations')
			|| (activeElementId === 'Registry')) {
			$('#MainFrame').css('background-color','white')
		} else {
			$('#MainFrame').css('background-color','none')
		}
		
		$('#PageName').html(activeElementId.replace(/\_/gi, " "));
		setCurrentItemInTitle(getMpiid());
	}
	function setCurrentItemInTitle(mpiid) {
		$('#CurrentItem').html(' [' + mpiid + ']');
	}
	</script>
	
</head>
<body>

<div id="TopBanner">
	
	<span id="SysDescr">Instance: #($P($zu(86),"*",2)_" ["_$get(^%SYS("SystemMode"))_"] ")#</span>
	<span id="PageName">Configure Datasource</span>
	<span id="CurrentItem"></span>
	<span id="PageDescr">zimpl:FHIR Profiling Toolkit for HealthShare</span>
	
</div>

<iframe id="MainFrame" class="frame" src="HS.Local.zimpl.fhirpro.UI.Datasource.cls" onload="mainFrameReady()"></iframe>
<div id="LoadingMessage" class="frame" style="display:none;"><span class="blink">Loading...</span></div>


<div class="side_menu">
	<div class="container">
		<ul class="list_load">
			<li class="list_item active" id="Configure_Datasource">
				<svg width="25px" height="25px" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
					<title>Einstellungen</title>
					<path fill-rule="evenodd" clip-rule="evenodd" d="M12 8.25C9.92894 8.25 8.25 9.92893 8.25 12C8.25 14.0711 9.92894 15.75 12 15.75C14.0711 15.75 15.75 14.0711 15.75 12C15.75 9.92893 14.0711 8.25 12 8.25ZM9.75 12C9.75 10.7574 10.7574 9.75 12 9.75C13.2426 9.75 14.25 10.7574 14.25 12C14.25 13.2426 13.2426 14.25 12 14.25C10.7574 14.25 9.75 13.2426 9.75 12Z" fill="#1C274C"/>
					<path fill-rule="evenodd" clip-rule="evenodd" d="M11.9747 1.25C11.5303 1.24999 11.1592 1.24999 10.8546 1.27077C10.5375 1.29241 10.238 1.33905 9.94761 1.45933C9.27379 1.73844 8.73843 2.27379 8.45932 2.94762C8.31402 3.29842 8.27467 3.66812 8.25964 4.06996C8.24756 4.39299 8.08454 4.66251 7.84395 4.80141C7.60337 4.94031 7.28845 4.94673 7.00266 4.79568C6.64714 4.60777 6.30729 4.45699 5.93083 4.40743C5.20773 4.31223 4.47642 4.50819 3.89779 4.95219C3.64843 5.14353 3.45827 5.3796 3.28099 5.6434C3.11068 5.89681 2.92517 6.21815 2.70294 6.60307L2.67769 6.64681C2.45545 7.03172 2.26993 7.35304 2.13562 7.62723C1.99581 7.91267 1.88644 8.19539 1.84541 8.50701C1.75021 9.23012 1.94617 9.96142 2.39016 10.5401C2.62128 10.8412 2.92173 11.0602 3.26217 11.2741C3.53595 11.4461 3.68788 11.7221 3.68786 12C3.68785 12.2778 3.53592 12.5538 3.26217 12.7258C2.92169 12.9397 2.62121 13.1587 2.39007 13.4599C1.94607 14.0385 1.75012 14.7698 1.84531 15.4929C1.88634 15.8045 1.99571 16.0873 2.13552 16.3727C2.26983 16.6469 2.45535 16.9682 2.67758 17.3531L2.70284 17.3969C2.92507 17.7818 3.11058 18.1031 3.28089 18.3565C3.45817 18.6203 3.64833 18.8564 3.89769 19.0477C4.47632 19.4917 5.20763 19.6877 5.93073 19.5925C6.30717 19.5429 6.647 19.3922 7.0025 19.2043C7.28833 19.0532 7.60329 19.0596 7.8439 19.1986C8.08452 19.3375 8.24756 19.607 8.25964 19.9301C8.27467 20.3319 8.31403 20.7016 8.45932 21.0524C8.73843 21.7262 9.27379 22.2616 9.94761 22.5407C10.238 22.661 10.5375 22.7076 10.8546 22.7292C11.1592 22.75 11.5303 22.75 11.9747 22.75H12.0252C12.4697 22.75 12.8407 22.75 13.1454 22.7292C13.4625 22.7076 13.762 22.661 14.0524 22.5407C14.7262 22.2616 15.2616 21.7262 15.5407 21.0524C15.686 20.7016 15.7253 20.3319 15.7403 19.93C15.7524 19.607 15.9154 19.3375 16.156 19.1985C16.3966 19.0596 16.7116 19.0532 16.9974 19.2042C17.3529 19.3921 17.6927 19.5429 18.0692 19.5924C18.7923 19.6876 19.5236 19.4917 20.1022 19.0477C20.3516 18.8563 20.5417 18.6203 20.719 18.3565C20.8893 18.1031 21.0748 17.7818 21.297 17.3969L21.3223 17.3531C21.5445 16.9682 21.7301 16.6468 21.8644 16.3726C22.0042 16.0872 22.1135 15.8045 22.1546 15.4929C22.2498 14.7697 22.0538 14.0384 21.6098 13.4598C21.3787 13.1586 21.0782 12.9397 20.7378 12.7258C20.464 12.5538 20.3121 12.2778 20.3121 11.9999C20.3121 11.7221 20.464 11.4462 20.7377 11.2742C21.0783 11.0603 21.3788 10.8414 21.6099 10.5401C22.0539 9.96149 22.2499 9.23019 22.1547 8.50708C22.1136 8.19546 22.0043 7.91274 21.8645 7.6273C21.7302 7.35313 21.5447 7.03183 21.3224 6.64695L21.2972 6.60318C21.0749 6.21825 20.8894 5.89688 20.7191 5.64347C20.5418 5.37967 20.3517 5.1436 20.1023 4.95225C19.5237 4.50826 18.7924 4.3123 18.0692 4.4075C17.6928 4.45706 17.353 4.60782 16.9975 4.79572C16.7117 4.94679 16.3967 4.94036 16.1561 4.80144C15.9155 4.66253 15.7524 4.39297 15.7403 4.06991C15.7253 3.66808 15.686 3.2984 15.5407 2.94762C15.2616 2.27379 14.7262 1.73844 14.0524 1.45933C13.762 1.33905 13.4625 1.29241 13.1454 1.27077C12.8407 1.24999 12.4697 1.24999 12.0252 1.25H11.9747ZM10.5216 2.84515C10.5988 2.81319 10.716 2.78372 10.9567 2.76729C11.2042 2.75041 11.5238 2.75 12 2.75C12.4762 2.75 12.7958 2.75041 13.0432 2.76729C13.284 2.78372 13.4012 2.81319 13.4783 2.84515C13.7846 2.97202 14.028 3.21536 14.1548 3.52165C14.1949 3.61826 14.228 3.76887 14.2414 4.12597C14.271 4.91835 14.68 5.68129 15.4061 6.10048C16.1321 6.51968 16.9974 6.4924 17.6984 6.12188C18.0143 5.9549 18.1614 5.90832 18.265 5.89467C18.5937 5.8514 18.9261 5.94047 19.1891 6.14228C19.2554 6.19312 19.3395 6.27989 19.4741 6.48016C19.6125 6.68603 19.7726 6.9626 20.0107 7.375C20.2488 7.78741 20.4083 8.06438 20.5174 8.28713C20.6235 8.50382 20.6566 8.62007 20.6675 8.70287C20.7108 9.03155 20.6217 9.36397 20.4199 9.62698C20.3562 9.70995 20.2424 9.81399 19.9397 10.0041C19.2684 10.426 18.8122 11.1616 18.8121 11.9999C18.8121 12.8383 19.2683 13.574 19.9397 13.9959C20.2423 14.186 20.3561 14.29 20.4198 14.373C20.6216 14.636 20.7107 14.9684 20.6674 15.2971C20.6565 15.3799 20.6234 15.4961 20.5173 15.7128C20.4082 15.9355 20.2487 16.2125 20.0106 16.6249C19.7725 17.0373 19.6124 17.3139 19.474 17.5198C19.3394 17.72 19.2553 17.8068 19.189 17.8576C18.926 18.0595 18.5936 18.1485 18.2649 18.1053C18.1613 18.0916 18.0142 18.045 17.6983 17.8781C16.9973 17.5075 16.132 17.4803 15.4059 17.8995C14.68 18.3187 14.271 19.0816 14.2414 19.874C14.228 20.2311 14.1949 20.3817 14.1548 20.4784C14.028 20.7846 13.7846 21.028 13.4783 21.1549C13.4012 21.1868 13.284 21.2163 13.0432 21.2327C12.7958 21.2496 12.4762 21.25 12 21.25C11.5238 21.25 11.2042 21.2496 10.9567 21.2327C10.716 21.2163 10.5988 21.1868 10.5216 21.1549C10.2154 21.028 9.97201 20.7846 9.84514 20.4784C9.80512 20.3817 9.77195 20.2311 9.75859 19.874C9.72896 19.0817 9.31997 18.3187 8.5939 17.8995C7.86784 17.4803 7.00262 17.5076 6.30158 17.8781C5.98565 18.0451 5.83863 18.0917 5.73495 18.1053C5.40626 18.1486 5.07385 18.0595 4.81084 17.8577C4.74458 17.8069 4.66045 17.7201 4.52586 17.5198C4.38751 17.314 4.22736 17.0374 3.98926 16.625C3.75115 16.2126 3.59171 15.9356 3.4826 15.7129C3.37646 15.4962 3.34338 15.3799 3.33248 15.2971C3.28921 14.9684 3.37828 14.636 3.5801 14.373C3.64376 14.2901 3.75761 14.186 4.0602 13.9959C4.73158 13.5741 5.18782 12.8384 5.18786 12.0001C5.18791 11.1616 4.73165 10.4259 4.06021 10.004C3.75769 9.81389 3.64385 9.70987 3.58019 9.62691C3.37838 9.3639 3.28931 9.03149 3.33258 8.7028C3.34348 8.62001 3.37656 8.50375 3.4827 8.28707C3.59181 8.06431 3.75125 7.78734 3.98935 7.37493C4.22746 6.96253 4.3876 6.68596 4.52596 6.48009C4.66055 6.27983 4.74468 6.19305 4.81093 6.14222C5.07395 5.9404 5.40636 5.85133 5.73504 5.8946C5.83873 5.90825 5.98576 5.95483 6.30173 6.12184C7.00273 6.49235 7.86791 6.51962 8.59394 6.10045C9.31998 5.68128 9.72896 4.91837 9.75859 4.12602C9.77195 3.76889 9.80512 3.61827 9.84514 3.52165C9.97201 3.21536 10.2154 2.97202 10.5216 2.84515Z" fill="#1C274C"/>
				</svg></li>
			<li id="Compare_SDA3_to_FHIR" class="list_item">
				<svg width="25px" height="25px" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg">
					<title>SDA & FHIR</title>
					<path d="M2 4h9v1H3v15h8v1H2zm10 19h1V2h-1zM8.283 10.283l-.566-.566L4.934 12.5l2.783 2.783.566-.566L6.566 13H11v-1H6.566zM14 12h4.08l-1.54-1.54.92-.92 2.96 2.96-2.96 2.96-.92-.92L18.08 13H14v8h9V4h-9z"/>
					<path fill="none" d="M0 0h24v24H0z"/>
				</svg></li>
			<li id="FHIR_Network" class="list_item">
				<svg width="25px" height="25px" viewBox="0 0 32 32" fill="#000000" version="1.1" xmlns="http://www.w3.org/2000/svg">
					<title>FHIR Network</title>
					<path d="M27 21.75c-0.795 0.004-1.538 0.229-2.169 0.616l0.018-0.010-2.694-2.449c0.724-1.105 1.154-2.459 1.154-3.913 0-1.572-0.503-3.027-1.358-4.212l0.015 0.021 3.062-3.062c0.57 0.316 1.249 0.503 1.971 0.508h0.002c2.347 0 4.25-1.903 4.25-4.25s-1.903-4.25-4.25-4.25c-2.347 0-4.25 1.903-4.25 4.25v0c0.005 0.724 0.193 1.403 0.519 1.995l-0.011-0.022-3.062 3.062c-1.147-0.84-2.587-1.344-4.144-1.344-0.868 0-1.699 0.157-2.467 0.443l0.049-0.016-0.644-1.17c0.726-0.757 1.173-1.787 1.173-2.921 0-2.332-1.891-4.223-4.223-4.223s-4.223 1.891-4.223 4.223c0 2.332 1.891 4.223 4.223 4.223 0.306 0 0.605-0.033 0.893-0.095l-0.028 0.005 0.642 1.166c-1.685 1.315-2.758 3.345-2.758 5.627 0 0.605 0.076 1.193 0.218 1.754l-0.011-0.049-0.667 0.283c-0.78-0.904-1.927-1.474-3.207-1.474-2.334 0-4.226 1.892-4.226 4.226s1.892 4.226 4.226 4.226c2.334 0 4.226-1.892 4.226-4.226 0-0.008-0-0.017-0-0.025v0.001c-0.008-0.159-0.023-0.307-0.046-0.451l0.003 0.024 0.667-0.283c1.303 2.026 3.547 3.349 6.1 3.349 1.703 0 3.268-0.589 4.503-1.574l-0.015 0.011 2.702 2.455c-0.258 0.526-0.41 1.144-0.414 1.797v0.001c0 2.347 1.903 4.25 4.25 4.25s4.25-1.903 4.25-4.25c0-2.347-1.903-4.25-4.25-4.25v0zM8.19 5c0-0.966 0.784-1.75 1.75-1.75s1.75 0.784 1.75 1.75c0 0.966-0.784 1.75-1.75 1.75v0c-0.966-0.001-1.749-0.784-1.75-1.75v-0zM5 22.42c-0.966-0.001-1.748-0.783-1.748-1.749s0.783-1.749 1.749-1.749c0.966 0 1.748 0.782 1.749 1.748v0c-0.001 0.966-0.784 1.749-1.75 1.75h-0zM27 3.25c0.966 0 1.75 0.784 1.75 1.75s-0.784 1.75-1.75 1.75c-0.966 0-1.75-0.784-1.75-1.75v0c0.001-0.966 0.784-1.749 1.75-1.75h0zM11.19 16c0-0.001 0-0.002 0-0.003 0-2.655 2.152-4.807 4.807-4.807 1.328 0 2.53 0.539 3.4 1.409l0.001 0.001 0.001 0.001c0.87 0.87 1.407 2.072 1.407 3.399 0 2.656-2.153 4.808-4.808 4.808s-4.808-2.153-4.808-4.808c0-0 0-0 0-0v0zM27 27.75c-0.966 0-1.75-0.784-1.75-1.75s0.784-1.75 1.75-1.75c0.966 0 1.75 0.784 1.75 1.75v0c-0.001 0.966-0.784 1.749-1.75 1.75h-0z"></path>
				</svg></li>
			<li id="FHIR_Timeline" class="list_item">
				<svg width="25px" height="25px" version="1.1" id="Layer_1" xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" viewBox="0 0 32 32" enable-background="new 0 0 32 32" xml:space="preserve">
					<title>FHIR Timeline</title>
					<line fill="none" stroke="#000000" stroke-width="2" stroke-miterlimit="10" x1="5" y1="28" x2="5" y2="4"/>
					<circle fill="none" stroke="#000000" stroke-width="2" stroke-miterlimit="10" cx="16" cy="10" r="2"/>
					<circle fill="none" stroke="#000000" stroke-width="2" stroke-miterlimit="10" cx="23" cy="16" r="2"/>
					<circle fill="none" stroke="#000000" stroke-width="2" stroke-miterlimit="10" cx="11" cy="22" r="2"/>
					<line fill="none" stroke="#000000" stroke-width="2" stroke-miterlimit="10" x1="28" y1="16" x2="25" y2="16"/>
					<line fill="none" stroke="#000000" stroke-width="2" stroke-miterlimit="10" x1="21" y1="16" x2="5" y2="16"/>
					<line fill="none" stroke="#000000" stroke-width="2" stroke-miterlimit="10" x1="28" y1="10" x2="18" y2="10"/>
					<line fill="none" stroke="#000000" stroke-width="2" stroke-miterlimit="10" x1="14" y1="10" x2="5" y2="10"/>
					<line fill="none" stroke="#000000" stroke-width="2" stroke-miterlimit="10" x1="28" y1="22" x2="13" y2="22"/>
					<line fill="none" stroke="#000000" stroke-width="2" stroke-miterlimit="10" x1="9" y1="22" x2="5" y2="22"/>
				</svg></li>
			
			</ul>
			<div class="spacer_box"><p> </p></div>
			<ul class="list_load">
				
			<li id="DTL_Viewer" class="list_item">
				<svg width="25px" height="25px" fill="#000000" version="1.1" id="Layer_1" xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" viewBox="0 0 32 32" xml:space="preserve">
					<title>DTL Viewer</title>
					<g id="SVGRepo_bgCarrier" stroke-width="0"></g>
					<g id="SVGRepo_tracerCarrier" stroke-linecap="round" stroke-linejoin="round" stroke="#000000" stroke-width="0.96">
						<path id="transform--02" d="M31,31.36h-8c-0.199,0-0.36-0.161-0.36-0.36V17c0-0.199,0.161-0.36,0.36-0.36h3.64V5.36H23V4.64h4 c0.199,0,0.36,0.161,0.36,0.36v11.64H31c0.199,0,0.36,0.161,0.36,0.36v14C31.36,31.199,31.199,31.36,31,31.36z M23.36,30.64h7.279 V17.36H23.36V30.64z M5,31.36c-2.404,0-4.36-1.956-4.36-4.36S2.596,22.64,5,22.64c2.283,0,4.162,1.764,4.345,4H20v0.721H9.345 C9.162,29.597,7.283,31.36,5,31.36z M5,23.36c-2.007,0-3.64,1.633-3.64,3.64S2.993,30.64,5,30.64S8.64,29.007,8.64,27 S7.007,23.36,5,23.36z M5.36,20.5H4.64V5c0-0.199,0.161-0.36,0.36-0.36h8.64V1c0-0.133,0.073-0.255,0.19-0.317 s0.26-0.056,0.37,0.018l6,4C20.3,4.767,20.36,4.879,20.36,5s-0.06,0.233-0.161,0.299l-6,4c-0.11,0.074-0.253,0.081-0.37,0.018 C13.713,9.255,13.64,9.133,13.64,9V5.36H5.36V20.5z M14.36,1.673v6.654L19.351,5L14.36,1.673z"></path></g>
					<g id="SVGRepo_iconCarrier"> <path id="transform--02" d="M31,31.36h-8c-0.199,0-0.36-0.161-0.36-0.36V17c0-0.199,0.161-0.36,0.36-0.36h3.64V5.36H23V4.64h4 c0.199,0,0.36,0.161,0.36,0.36v11.64H31c0.199,0,0.36,0.161,0.36,0.36v14C31.36,31.199,31.199,31.36,31,31.36z M23.36,30.64h7.279 V17.36H23.36V30.64z M5,31.36c-2.404,0-4.36-1.956-4.36-4.36S2.596,22.64,5,22.64c2.283,0,4.162,1.764,4.345,4H20v0.721H9.345 C9.162,29.597,7.283,31.36,5,31.36z M5,23.36c-2.007,0-3.64,1.633-3.64,3.64S2.993,30.64,5,30.64S8.64,29.007,8.64,27 S7.007,23.36,5,23.36z M5.36,20.5H4.64V5c0-0.199,0.161-0.36,0.36-0.36h8.64V1c0-0.133,0.073-0.255,0.19-0.317 s0.26-0.056,0.37,0.018l6,4C20.3,4.767,20.36,4.879,20.36,5s-0.06,0.233-0.161,0.299l-6,4c-0.11,0.074-0.253,0.081-0.37,0.018 C13.713,9.255,13.64,9.133,13.64,9V5.36H5.36V20.5z M14.36,1.673v6.654L19.351,5L14.36,1.673z"></path></g>
				</svg></li>

			<li id="Find_In_Files" class="list_item">
				<svg width="30px" height="30px" viewBox="0 -0.5 25 25" fill="none" xmlns="http://www.w3.org/2000/svg">
					<title>Find in Files</title>
					<path fill-rule="evenodd" clip-rule="evenodd" d="M11.132 9.71395C10.139 11.2496 10.3328 13.2665 11.6 14.585C12.8468 15.885 14.8527 16.0883 16.335 15.065C16.6466 14.8505 16.9244 14.5906 17.159 14.294C17.3897 14.0023 17.5773 13.679 17.716 13.334C18.0006 12.6253 18.0742 11.8495 17.928 11.1C17.7841 10.3573 17.4268 9.67277 16.9 9.12995C16.3811 8.59347 15.7128 8.22552 14.982 8.07395C14.2541 7.92522 13.4982 8.00197 12.815 8.29395C12.1254 8.58951 11.5394 9.08388 11.132 9.71395Z" stroke="#000000" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"/>
					<path d="M17.5986 13.6868C17.2639 13.4428 16.7947 13.5165 16.5508 13.8513C16.3069 14.1861 16.3806 14.6552 16.7154 14.8991L17.5986 13.6868ZM19.0584 16.6061C19.3931 16.85 19.8623 16.7764 20.1062 16.4416C20.3501 16.1068 20.2764 15.6377 19.9416 15.3938L19.0584 16.6061ZM7.5 12.7499C7.91421 12.7499 8.25 12.4142 8.25 11.9999C8.25 11.5857 7.91421 11.2499 7.5 11.2499V12.7499ZM5.5 11.2499C5.08579 11.2499 4.75 11.5857 4.75 11.9999C4.75 12.4142 5.08579 12.7499 5.5 12.7499V11.2499ZM7.5 15.7499C7.91421 15.7499 8.25 15.4142 8.25 14.9999C8.25 14.5857 7.91421 14.2499 7.5 14.2499V15.7499ZM5.5 14.2499C5.08579 14.2499 4.75 14.5857 4.75 14.9999C4.75 15.4142 5.08579 15.7499 5.5 15.7499V14.2499ZM8.5 9.74994C8.91421 9.74994 9.25 9.41415 9.25 8.99994C9.25 8.58573 8.91421 8.24994 8.5 8.24994V9.74994ZM5.5 8.24994C5.08579 8.24994 4.75 8.58573 4.75 8.99994C4.75 9.41415 5.08579 9.74994 5.5 9.74994V8.24994ZM16.7154 14.8991L19.0584 16.6061L19.9416 15.3938L17.5986 13.6868L16.7154 14.8991ZM7.5 11.2499H5.5V12.7499H7.5V11.2499ZM7.5 14.2499H5.5V15.7499H7.5V14.2499ZM8.5 8.24994H5.5V9.74994H8.5V8.24994Z" fill="#000000"/>
				</svg></li>

			<li id="Management_Portal" class="list_item">		
				<svg width="25px" height="25px" id="logo" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 40 160.3">
					<title>zimplFHIRPro Production</title>
					<defs><style>.cls-1{fill:#333695;}.cls-2{fill:#00b5af;}</style></defs>
					<polygon class="cls-1" points="20.12 22.5 0 12.43 0 140.17 40.24 160.3 40.24 137.8 20.12 127.74 20.12 22.5"/>
					<polygon class="cls-2" points="40.24 137.8 60.36 147.88 60.36 20.13 20.12 0 20.12 22.5 40.24 32.56 40.24 137.8"/>
				</svg></li>
			<!-- Fix bugs first!-- li id="FHIR_Tester_Inbound_to_Outbound" class="list_item">		
				<svg width="25px" height="25px" viewBox="0 0 24 24" id="Layer_1" data-name="Layer 1" xmlns="http://www.w3.org/2000/svg">
					<title>FHIR Unittest</title>
					<defs><style>.cls-11{fill:none;stroke:#020202;stroke-miterlimit:10;stroke-width:1.91px;}</style></defs>
					<path class="cls-11" d="M5.32,1.5H9.14a0,0,0,0,1,0,0V13.91a1.91,1.91,0,0,1-1.91,1.91h0a1.91,1.91,0,0,1-1.91-1.91V1.5A0,0,0,0,1,5.32,1.5Z"/>
					<line class="cls-11" x1="3.41" y1="1.5" x2="11.05" y2="1.5"/>
					<path class="cls-11" d="M14.86,1.5h3.82a0,0,0,0,1,0,0V13.91a1.91,1.91,0,0,1-1.91,1.91h0a1.91,1.91,0,0,1-1.91-1.91V1.5A0,0,0,0,1,14.86,1.5Z"/>
					<line class="cls-11" x1="12.95" y1="1.5" x2="20.59" y2="1.5"/>
					<line class="cls-11" x1="14.86" y1="5.32" x2="9.14" y2="5.32"/>
					<polyline class="cls-11" points="18.68 5.32 22.5 5.32 22.5 18.68 22.5 22.5 1.5 22.5 1.5 18.68 1.5 5.32 5.32 5.32"/><rect class="cls-1" x="1.5" y="18.68" width="21" height="3.82"/>
					<line class="cls-11" x1="5.32" y1="9.14" x2="9.14" y2="9.14"/>
					<line class="cls-11" x1="14.86" y1="9.14" x2="18.68" y2="9.14"/>
				</svg></li-->
			
			<li id="Registry" class="list_item">
				<svg width="25px" height="25px" viewBox="0 0 48 48" xmlns="http://www.w3.org/2000/svg" style="fill:none; stroke:black; stroke-linecap:round;m stroke-linejoin:round;">
					<path d="M6.3,42.5H40.4"/>
					<path d="M6.4,40.5l7-.2L12.9,5.6,6.6,5.5Z"/>
					<path d="M15,13.5l-.3,26.3,6.5-.2L22,13.7Z"/>
					<path d="M24,7.9,22.6,40.1l8.7-.1L33,8.4Z"/>
					<path d="M34,14.2,32.5,40.5l7.8.1,1.4-26.3Z"/>
					<path d="M35,14.2a8.51,8.51,0,0,1,5.7-3.7"/>
					<path d="M12.9,5.6,14.8,9l.1,4.6"/>
					<path d="M13.4,40.3l1.3-.5"/>
				</svg>
			</li>

			<li id="HL7_Annotations" class="list_item">
				<img style="width:25px" title="HL7 Annotations" src="data:image/png;base64,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" />
			</li>
			<!--li id="CodeSystem_Importer" class="list_item">
				<svg width="25px" height="25px" viewBox="0 0 512 512" version="1.1" xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink">
				    <title>import</title>
				    <g id="Page-1" stroke="none" stroke-width="1" fill="none" fill-rule="evenodd">
				        <g id="Combined-Shape" fill="#000000" transform="translate(42.666667, 85.333333)">
				            <path d="M405.333333,-1.42108547e-14 L405.333333,362.666667 L21.3333333,362.666667 L21.3333333,85.3333333 L64,85.3333333 L64,320 L362.666667,320 L362.666667,42.6666667 L277.333333,42.6666667 L277.333333,-1.42108547e-14 L405.333333,-1.42108547e-14 Z M128,-1.42108547e-14 C185.3601,-1.42108547e-14 232.145453,45.2758765 234.568117,102.039688 L234.666667,106.666667 L234.666,183.152 L283.581722,134.248389 L313.751611,164.418278 L213.333333,264.836556 L112.915055,164.418278 L143.084945,134.248389 L192,183.152 L192,106.666667 C192,72.5828078 165.356374,44.7219012 131.760486,42.7753108 L128,42.6666667 L7.10542736e-15,42.6666667 L7.10542736e-15,-1.42108547e-14 L128,-1.42108547e-14 Z"></path>
				        </g>
				    </g>
				</svg>
			</li-->

		</ul>
	</div>
</div>

</body>
</html>
	
	>
	
	return $$$OK
}

}
