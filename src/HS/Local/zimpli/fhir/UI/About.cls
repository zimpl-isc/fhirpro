/**
* About page for zimpliFHIR
*
* @version 1.0 2026-03-18
* @author Brandon Thomas
*/

Class HS.Local.zimpli.fhir.UI.About Extends HS.Local.zimpli.fhir.UI.Super
{

ClassMethod OnPage() As %Status
{
	&html<<!DOCTYPE html>
<html>
<head>
	<title>About zimpliFHIR</title>
	#(..MetaTags())#
	#(..DefaultStyle())#
	#(..LinkCSS("assets/About.css"))#
</head>
<body>

<div id="pageShell">

	<div class="card pageHeader">
		<div>
			<div class="logoRow">
				<svg class="logoMark" viewBox="0 0 48 48" xmlns="http://www.w3.org/2000/svg" aria-hidden="true">
					<defs>
						<linearGradient id="zfGradAbout" x1="0%" y1="0%" x2="100%" y2="100%">
							<stop offset="0%" stop-color="#333695"/>
							<stop offset="100%" stop-color="#44c7c2"/>
						</linearGradient>
					</defs>
					<circle cx="24" cy="24" r="4.2" fill="#333695"/>
					<circle cx="24" cy="8" r="4" fill="url(#zfGradAbout)"/>
					<circle cx="37.9" cy="16" r="4" fill="url(#zfGradAbout)"/>
					<circle cx="37.9" cy="32" r="4" fill="url(#zfGradAbout)"/>
					<circle cx="24" cy="40" r="4" fill="url(#zfGradAbout)"/>
					<circle cx="10.1" cy="32" r="4" fill="url(#zfGradAbout)"/>
					<circle cx="10.1" cy="16" r="4" fill="url(#zfGradAbout)"/>
					<line x1="24" y1="12.5" x2="24" y2="19" stroke="#94a3b8" stroke-width="2.4" stroke-linecap="round"/>
					<line x1="34.1" y1="18.3" x2="27.8" y2="21.8" stroke="#94a3b8" stroke-width="2.4" stroke-linecap="round"/>
					<line x1="34.1" y1="29.7" x2="27.8" y2="26.2" stroke="#94a3b8" stroke-width="2.4" stroke-linecap="round"/>
					<line x1="24" y1="35.5" x2="24" y2="29" stroke="#94a3b8" stroke-width="2.4" stroke-linecap="round"/>
					<line x1="13.9" y1="29.7" x2="20.2" y2="26.2" stroke="#94a3b8" stroke-width="2.4" stroke-linecap="round"/>
					<line x1="13.9" y1="18.3" x2="20.2" y2="21.8" stroke="#94a3b8" stroke-width="2.4" stroke-linecap="round"/>
				</svg>

				<div>
					<h1 class="pageTitle">About zimpliFHIR</h1>
					<div class="pageSubtitle">Interoperability toolkit for HealthShare demonstrations and analysis</div>
				</div>
			</div>
		</div>
	</div>

	<div class="card contentCard">
		<p class="intro">
			<b>zimpliFHIR</b> is a lightweight toolkit for exploring, validating and demonstrating
			HL7, SDA3 and FHIR transformations in HealthShare. It brings together interactive
			views for patient journeys, resource networks, DTL documentation and supporting
			developer utilities in a single UI.
		</p>

		<div class="metaGrid">
			<div class="metaLabel">Product</div>
			<div class="metaValue">zimpliFHIR</div>

			<div class="metaLabel">Version</div>
			<div class="metaValue">2.0 <span class="badge">Demo UI</span></div>

			<div class="metaLabel">Author</div>
			<div class="metaValue">brandon . thomas @ intersystems . com</div>

			<div class="metaLabel">Platform</div>
			<div class="metaValue">InterSystems IRIS / HealthShare / CSP</div>

			<div class="metaLabel">Purpose</div>
			<div class="metaValue">
				Demonstration, inspection and troubleshooting of interoperability flows
				across HL7, SDA3 and FHIR.
			</div>

			<div class="metaLabel">License</div>
			<div class="metaValue">
				<a href="https://opensource.org/license/MIT" target="_blank">
					MIT License
				</a>
			</div>

			<div class="metaLabel">Repository</div>
			<div class="metaValue">
				<a href="https://github.com/zimpl-isc/fhirpro" target="_blank">
					GitHub project
				</a>
			</div>
		</div>

		<div class="sectionDivider"></div>

		<div class="metaGrid">
			<div class="metaLabel">Included tools</div>
			<div class="metaValue">
				Datasource management, FHIR timeline, FHIR resource network, DTL viewer,
				find-in-files, HL7 annotations, comparison utilities and operational links.
			</div>

			<div class="metaLabel">Demo focus</div>
			<div class="metaValue">
				Clinical movement history, transformation transparency and traceable
				resource generation for presentations and workshops.
			</div>
		</div>
	</div>
    <div class="card disclaimerCard">
        <h2 class="disclaimerTitle">Disclaimer</h2>

        <div class="disclaimerText">
            <p>
                <b>zimpliFHIR</b> is intended solely for demonstration, inspection, analysis and
                development support purposes, especially during the design, implementation,
                validation and troubleshooting of FHIR profiles, transformations and related
                interoperability workflows.
            </p>

            <p>
                This product is <b>not intended for production use</b>. It is not designed,
                tested or warranted for use as a clinical system, operational decision support
                tool, diagnostic aid, or production-grade interoperability component.
            </p>

            <p>
                The software is provided <b>as is</b>, without warranties or guarantees of any
                kind, express or implied, including but not limited to correctness, completeness,
                reliability, fitness for a particular purpose, merchantability, availability,
                performance or non-infringement.
            </p>

            <p>
                No guarantee is made that outputs, transformations, rendered views, validations
                or derived results are accurate, complete or suitable for real-world operational,
                clinical, regulatory or business use. Any use is at the user's own risk.
            </p>

            <p>
                Before any productive or clinical use, all logic, mappings, transformations,
                profiles and results must be independently reviewed, validated and approved
                through appropriate project, quality and governance processes.
            </p>
        </div>
    </div>

</div>

</body>
</html>>
	
	return $$$OK
}

}
