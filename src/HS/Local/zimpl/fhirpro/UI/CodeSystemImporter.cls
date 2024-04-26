/// Must be run in the REGISTRY Namespace
Class HS.Local.zimpl.fhirpro.UI.CodeSystemImporter Extends %CSP.Page
{

ClassMethod CodeSystemExists(pCode) As %String [ CodeMode = expression ]
{
##class(HS.Data.OIDMap).CodeTypeIndexExists(pCode)
}

ClassMethod JS()
{
	&html<
	<script type="text/javascript">
	
	function guessDelimiter(line) {
		var delim = [";", ",", "\t", "|"];
		delimCount = new Object();
		
		delim.forEach((element) => {
		    delimCount[line.split(element).length] = element;
		});
		
		var bestGuess = Object.keys(delimCount).sort(function(a, b){return b-a})[0];
		console.log('delimiter assumed to be: '+delimCount[bestGuess]);
		
		return delimCount[bestGuess]
	}
	
	function readURL(input) {
	  if (input.files && input.files[0]) {
		  
		$('#Workspace').show()
		  
	    var fr = new FileReader();
	    fr.onload = function () {
		    exampleLinesAry = this.result.split(/\n/g);
		    exampleLinesCount = exampleLinesAry.length;
		    $('#LineCount').html(exampleLinesAry.length);
		    exampleLine = exampleLinesAry[0];
		    exampleLine2 = exampleLinesAry[1];
		    exampleLine3 = exampleLinesAry[2];
		    
		    delimiter = guessDelimiter(exampleLine);
		    $('#delim').val(delimiter);
		    
			document.getElementById('contents').innerHTML = exampleLine+"\n"+exampleLine2+"\n"+exampleLine3;
			
			updateTable();
			//console.log(exampleLine);
		};
		fr.readAsText(input.files[0]);
  }
}

function updateTable() {
	var delim=$('#delim').val();
	
	var line = exampleLine.split(delim);
	var line2 = exampleLine2.split(delim);
	var line3 = exampleLine3.split(delim);
	
	var table = document.getElementById('previewTable');
	table.replaceChildren();
	
	var header = table.createTHead();
  	var row = header.insertRow(0);
	for(var i=0;i<line.length;i++) {
		var cell = row.insertCell();
		cell.appendChild(document.createTextNode(i+1));
	}
	
	var body = table.createTBody();
	var row = body.insertRow();
	for(var i=0;i<line.length;i++) {
		var cell = row.insertCell();
		cell.appendChild(document.createTextNode(line[i]));
	}
	
	var row = body.insertRow();
	for(var i=0;i<line.length;i++) {
		var cell = row.insertCell();
		cell.appendChild(document.createTextNode(line2[i]));
	}
	
	var row = body.insertRow();
	for(var i=0;i<line.length;i++) {
		var cell = row.insertCell();
		cell.appendChild(document.createTextNode(line3[i]));
	}
	
	$('#code').empty();
	$('#descr').empty();
	$('#code').append('<option>Code value column</option>');
	$('#descr').append('<option>Description value column</option>');
	for(var i=0;i<line.length;i++) {
		$('#code').append('<option value='+(i+1)+'>'+'column '+(i+1)+'</option>');
		$('#descr').append('<option value='+(i+1)+'>'+'column '+(i+1)+'</option>');
	}
}

function lookupCodeSystem(name) {
	
	$('#CodeSystemWarning').empty();
	$('#CodeSystemOK').empty();
	
	var exists = #(##class(%CSP.Page).HyperEventCall(..%ClassName(1)_".CodeSystemExists", "name", 0))#;
	console.log('Lookup for: '+name +'='+ exists);
	
	if(parseInt(exists)===1) {
		$('#CodeSystemWarning').html('Warning: existing CodeSystem will be updated.')
	} else {
		$('#CodeSystemOK').html('OK: CodeSystem will be created.')
	}
						
}
function markCodePreview() {
	var Idx = parseInt($('#code').find(":selected").val());
	
	$("#previewTable td").removeClass("code");
	$("#previewTable td").filter(":nth-child("+Idx+")").addClass("code");
}
function markDescrPreview() {
	var Idx = parseInt($('#descr').find(":selected").val());
	
	$("#previewTable td").removeClass("descr");
	$("#previewTable td").filter(":nth-child("+Idx+")").addClass("descr");
}

$(document).ready(function(){
  $("#form").submit(function(event){
    //event.preventDefault();
    //alert("Submit prevented");
  });
});
	</script>>
	return ""
}

ClassMethod CSS()
{
	&html<
	<style>
#TopNav {background: linear-gradient(180deg, rgba(164,226,222,1) 0%, rgba(214,255,253,1) 100%); border-bottom: 1px solid teal; padding: 0.5em 1em;}
#LeftNav {padding: 1em;	background: #e4e8e8;}
#Workspace {padding: 1em; background:#f9ffff80; display:none;}

#CodeSystemWarning {font-style: italic; color: red; padding-left: 1em;}
#CodeSystemOK {font-style: italic; color: green; padding-left: 1em;}

.code {background-color:#ff00004f !important;}
.descr {background-color:#0000ff26 !important;}
#validcol::placeholder {color: lightgrey;}

.card-footer {font-style:italic; color:gray;}
.table thead {font-weight: bolder;}
.container-fluid {--bs-gutter-x:0;}
</style>
	>
	return ""
}

ClassMethod OnPage() As %Status
{
	/// Bootstrap Layout helper: https://www.layoutit.com/build
	
	&html<
<!DOCTYPE html>
<head>
	<title>CodeSystemImporter</title>
	<meta charset="utf-8">
	<meta name="viewport" content="width=device-width, initial-scale=1">
	<link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.0-alpha3/dist/css/bootstrap.min.css" rel="stylesheet" integrity="sha384-KK94CHFLLe+nY2dmCWGMq91rCGa5gtU4mk92HdvYe+M/SXH301p5ILy+dN9+nJOZ" crossorigin="anonymous">
	<link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/bootstrap-icons@1.5.0/font/bootstrap-icons.css">
	<script src="https://cdn.jsdelivr.net/npm/jquery@3.6.0/dist/jquery.slim.min.js"></script>
	<script src="/csp/broker/cspxmlhttp.js"></script>

	#(..JS())#
	#(..CSS())#

</head>
<body>

<div class="container-fluid">
	<div class="row">
		<div class="col-md-12">
			<!--nav id="TopNav" class="navbar navbar-expand-lg navbar-light bg-light">
				 
				 <a class="navbar-brand" href="#">[HSFHIRToolkit]</a>
				<div class="collapse navbar-collapse" id="bs-example-navbar-collapse-1">
					<ul class="navbar-nav">
						<li class="nav-item active">
							 <a class="nav-link" href="#">Link <span class="sr-only">(current)</span></a>
						</li>
						<li class="nav-item">
							 <a class="nav-link" href="#">Link</a>
						</li>
						<li class="nav-item dropdown">
							 <a class="nav-link dropdown-toggle" href="http://example.com" id="navbarDropdownMenuLink" data-toggle="dropdown">Dropdown link</a>
							<div class="dropdown-menu" aria-labelledby="navbarDropdownMenuLink">
								 <a class="dropdown-item" href="#">Action</a> <a class="dropdown-item" href="#">Another action</a> <a class="dropdown-item" href="#">Something else here</a>
								<div class="dropdown-divider">
								</div> <a class="dropdown-item" href="#">Separated link</a>
							</div>
						</li>
					</ul>
					<form class="form-inline">
						<input class="form-control mr-sm-2" type="text" /> 
						<button class="btn btn-primary my-2 my-sm-0" type="submit">
							Search
						</button>
					</form>
					<ul class="navbar-nav ml-md-auto">
						<li class="nav-item active">
							 <a class="nav-link" href="#">Link <span class="sr-only">(current)</span></a>
						</li>
						<li class="nav-item dropdown">
							 <a class="nav-link dropdown-toggle" href="http://example.com" id="navbarDropdownMenuLink" data-toggle="dropdown">Dropdown link</a>
							<div class="dropdown-menu dropdown-menu-right" aria-labelledby="navbarDropdownMenuLink">
								 <a class="dropdown-item" href="#">Action</a> <a class="dropdown-item" href="#">Another action</a> <a class="dropdown-item" href="#">Something else here</a>
								<div class="dropdown-divider">
								</div> <a class="dropdown-item" href="#">Separated link</a>
							</div>
						</li>
					</ul>
				</div>
			</nav-->
			<div id="Main" class="row vh-100">
				<div id="LeftNav" class="col-md-3">
					<form id="form" autocomplete="off" method="POST" action="/csp/healthshare/hsregistry/HS.Local.zimpl.fhirpro.UI.CodeSystemProcessor.cls" enctype="multipart/form-data" target="_blank" accept-charset="utf-8">
					<div class="input-group mb-1">
					  <span class="input-group-text">CodeSystem Name</span>
					  <input id="codeSystem" name="codeSystem" class="form-control" type="text" onchange="lookupCodeSystem(this.value);" required/>
					</div>
					<small id="CodeSystemWarning"></small>
					<small id="CodeSystemOK"></small>
					
					<div class="mb-3 mt-2">
					  <!--label for="file" class="form-label">Choose CSV File</label-->
					  <input id="file" name="file" class="form-control" type="file" onchange="readURL(this);" required>
					</div>
					<div class="input-group mb-1">
					  <span class="input-group-text">delimiter</span>
					  <input id="delim" name="delim" class="form-control-sm" type="text" onchange="updateTable();" required/>
					</div>
					<div class="input-group mb-1">
					  <span class="input-group-text code">code</span>
					  <select id="code" name="code" class="form-select" onchange="markCodePreview();" required></select>
			  		</div>
					<div class="input-group mb-1">
					  <span class="input-group-text descr">description</span>
					  <select id="descr" name="descr" class="form-select" onchange="markDescrPreview();" required></select>
			  		</div>
			  		<div class="input-group mb-1">
					  <span class="input-group-text">valid when</span>
					  <input name="selector" class="form-control" type="text" id="validcol" onchange="" placeholder="({#1} '= 0)"/>
			  		</div>
			  		  <div class="col-12">
						<input class="btn btn-primary" type="submit" />
					  </div>

			  		</form>
			  		
				</div>
				<div id="Workspace" class="col-md-9">
					<div class="card mb-3 mt-3">
						<h5 class="card-header">Original contents</h5>
						<div class="card-body">
						
	   						<pre id="contents" class="card-text"></pre>
	   						
						</div>
						<div class="card-footer">showing first 3 lines of <span id="LineCount">...</span></div>
					</div>
					<div class="card">
						<h5 class="card-header">Tabular preview</h5>
						<div class="card-body">
						
						  <table id="previewTable" class="table table-striped-columns"></table>
							
						</div>
						<div class="card-footer"></div>
					</div>
				</div>
			</div>
		</div>
	</div>
</div>
      
</body>
</html>
	>
	
	return $$$OK
}

}
