# zimpl:FHIR Profiling Toolkit for HealthShare
*2024-03-27 • Brandon Thomas*

## Contents
- [Scope](#scope)
- [Installation](#installation)
    - [Classes and Dependencies](#classes-and-dependencies)
    - [Configure Production](#configure-production)
    - [Navigate to the Startpage](#navigate-to-the-startpage)
    - [Disclaimer](#disclaimer)
- [Known Issues](#known-issues)
- [Roadmap](#roadmap)
- [License](#license)

## Scope
This package provides a number of tools which were developed to aid in the implementation of the [German MII FHIR profiles](https://simplifier.net/organization/koordinationsstellemii) in [InterSystems HealthShare](https://www.intersystems.com/interoperability-platform/).  These tools are not intended for production use.

Many thanks to our sponsor for this project, the University Hospital of Hamburg-Eppendorf, Germany :tada:

[<img src="README_img/UKE_logo_klassisch.png">](https://www.uke.de)

The following screenshots narrate the basic functionality ...

---
![Retrieval and viewer of SDA Containers and FHIR Bundles by MRN or MPIID for comparison](README_img/SAFI_Datasource.png)
*Retrieve and compare SDA Containers with FHIR Bundles by MRN/AA or MPIID*

---
![Network diagram which displays the hierarchy of all FHIR resources within a bundle](README_img/SAFI_FHIR-Network.png)
*Network diagram which displays the hierarchy of all resources within a FHIR bundle*

---
![Timeline diagram of specific FHIR resources within a bundle](README_img/SAFI_FHIR-Timeline.png)
*Timeline diagram of specific FHIR resources within a bundle*

---
![DTL Viewer with search and filter capabilities](README_img/DTL-Viewer.png)
*Extensible DTL Viewer with search, filter and export capabilities*

---
![Integrated Management Portal](README_img/SMP.png)
*Integrated Management Portal*


## Installation
### Import Classes
- [ ] Import and compile the classes from GitHub in the *HSCUSTOM* namespace.

### Configure Production
A foundation-type production is required in HealthShare for retrieving SDA and FHIR. An installer method will configure this for you.

- [ ] From the terminal, use the installer script to setup the new namespace `ZIMPLFHIRPRO` and configure the production:
``` objectscript
HSCUSTOM> do ##class(HS.Local.zimpl.fhirpro.API.Installer).Install()
```
#### Now in the Management Portal:

- [ ] Configure the *Business Operation* **GATEWAY**
    - The **ServiceName** setting needs to use an AccessGateway known in the Service Registry, for example: `dembp18bthomas.local:HSACCESS`
- [ ] Configure the *Business Operation* **HS.FHIRServer.Interop.HTTPOperation**
    - The **ServiceName** setting needs an HTTP Endpoint for FHIR (ODS), for example: `FHIR.Service.R4`  
    Note: you may need to configure the `HTTPCredentialsConfig` and  `SSL Configuration` settings in the *Service Registry* entry.
- [ ] :bulb: Optionally add the *Business Operation* **HS.Util.Trace.Operations** 

- [ ] Start the production

### Web Dependencies
The following external libraries are contained in the included zip file:
- [jQuery](https://jquery.com/)
- [DataTables css and js](https://datatables.net/)
- [simple tree table](https://github.com/kanety/jquery-simple-tree-table)
- [vis-network](https://visjs.org/)
- [vis-timeline](https://visjs.org/)

---
- [ ] Unzip and save the contents of 

`zimplfhirpro_Dependencies-*.zip` 

to the following directory:

`{HealthShare Installation}/csp/healthshare/zimplfhirpro/`

### Navigate to the Startpage
<http://localhost:52774/csp/healthshare/zimplfhirpro/HS.Local.zimpl.fhirpro.UI.Index.cls>
### In Docker
<http://localhost:42773/csp/healthshare/zimplfhirpro/HS.Local.zimpl.fhirpro.UI.Index.cls>
## Disclaimer
:warning: This application is not supported by InterSystems Corporation. Please be notified that you use it at your own risk.

## Known Issues & Caveats
### 2024-01-12
- custom DTLViewer classes should now extend 
`HS.Local.zimpl.fhirpro.UI.DTLViewer`

## Roadmap
- Add REST API in ODS to handle ReloadPatient(), etc from this tool
- Add tools for managing ^ISCSOAP,^FSLOG; verify custom DTL package; Extension Mapping; FHIR validation

## License
This and all external libraries included with this package are available as open source under the terms of the [MIT License](https://opensource.org/license/MIT).

## Docker Support
This repository provides a generic development environment 
for coding productively with InterSystems ObjectScript.    
This template:   
* Runs InterSystems Community Edition in a docker container
* besides ZPM it includes WEBTERMINAL and PASSWORDLESS package
* the namespace defaults to USER
* any additional setting is provided by additional package related installation
 
### Usage
The container is built directly from **intersystemsdc/irishealth-community** without any Dockerfile
- **bscript.sh** runs BEFORE IRIS is started  
- **ascript.sh** is executed AFTER the start of IRIS and executes **iris.script** by default
- changing of port mapping happens in **docker-compose.yml** 

### Prerequisites
Make sure you have [git](https://git-scm.com/book/en/v2/Getting-Started-Installing-Git) and [Docker desktop](https://www.docker.com/products/docker-desktop) installed.
### Installation
Clone/git pull the repo into any local directory
```
$ git clone https://github.com/rcemper/PR_fhirpro.git
```
To build and start the container run:
```
$ docker compose up -d && docker compose logs -f
```
To open IRIS Terminal do:
```
$ docker-compose exec iris iris session iris
USER>
```
or using **WebTerminal**    
<http://localhost:42773/terminal/>    

To access IRIS System Management Portal    
<http://localhost:42773/csp/sys/UtilHome.csp>    
Access Production   
<http://localhost:42773/csp/hscustom/EnsPortal.ProductionConfig.zen?PRODUCTION=HS.Local.zimpl.fhirpro.Production>   
```