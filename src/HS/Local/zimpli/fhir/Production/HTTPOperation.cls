/**
* @description Generic BusinessOperation for sending REST requests. Expects an EnsLib.REST.GenericMessage.
* @version 1.0 2025-09-16
* @author brandon.thomas@intersystems.com
*
*   Send in query parameters as headers:
*    set tHeaders("Method")="POST"  // defaults to GET
*    set tHeaders("Location")="/tasks"
*    set tHeaders("ContentType")="application/vnd.intersystems.com.hs.hspc.tasks.v0+json"
*
*    set tRequest = ##class(EnsLib.REST.GenericMessage).%New(tEntityBodyStream,,.tHeaders)
*        // or add headers this way: do tRequest.HTTPHeaders.SetAt("application/vnd.intersystems.com.hs.hspc.tasks.v0+json","ContentType")
*/

Include HS.HC.TraceHelper

Class HS.Local.zimpli.fhir.Production.HTTPOperation Extends (Ens.BusinessOperation, HS.HC.Util.Trace.Helper)
{

/// HTTP Service Registry Endpoint. Configure name in the Production settings or pass as a Header entry named "EndPoint".
Property EndPoint As %String [ InitialExpression = "PersonalCommunity:RESTAPI" ];

Property ContentType As %String(MAXLEN = 150) [ InitialExpression = "application/json" ];

/// A custom implementation may be used for debugging
Property HttpRequestClass As %String [ InitialExpression = "%Net.HttpRequest" ];

Parameter SETTINGS = "ContentType:Basic,EndPoint:Connection:selector?Select=1&context={HS.Util.ContextSearch/ServiceNameItemsByParam?Type=HTTP},HttpRequestClass:Dev:selector?Select=1&context={HS.Util.ContextSearch/Classes?super=%Net.HttpRequest}";

Method OnMessage(pRequest As EnsLib.REST.GenericMessage, Output pResponse As EnsLib.REST.GenericMessage) As %Status
{
    #dim tException As %Exception.StatusException
	#dim tEndPoint As HS.Registry.Service.HTTP
	#dim tCredentials As Ens.Config.Credentials
    #dim tHttpRequest as %Net.HttpRequest = $classmethod(..HttpRequestClass, "%New")  //##class(%Net.HttpRequest).%New() or custom HttpRequest which extends %XML.Adaptor for better traces

	Try {

        set tEndPointName = ..GetValue(pRequest.HTTPHeaders.GetAt("EndPoint"), ..EndPoint)
        set tEndPoint = ##class(HS.Registry.Service.HTTP).EndPointForNameType(tEndPointName, "HTTP")
			$$$HSTRACE("HTTP Service Registry Endpoint", "EndPoint", tEndPoint)
        
        set tMethod = ..GetValue($zcvt(pRequest.HTTPHeaders.GetAt("Method"), "U"), "GET")

        /// Get Credentials from tEndPoint.HTTPCredentialsConfig
		set tSc = ##class(Ens.Config.Credentials).GetCredentialsObj(.tCredentials,$classname(),"Ens.Config.Credentials", tEndPoint.HTTPCredentialsConfig)
        set tHttpRequest.Username = tCredentials.Username
        set tHttpRequest.Password = tCredentials.Password
		
		set tHttpRequest.Server = tEndPoint.Host
        set tHttpRequest.Port = tEndPoint.Port

        /// Split out any query parameters
        set tLocation = pRequest.HTTPHeaders.GetAt("Location")
        if tLocation [ "?" {
            set tLocation = $piece(pRequest.HTTPHeaders.GetAt("Location"), "?", 1)
            set tParamList = $piece(pRequest.HTTPHeaders.GetAt("Location"), "?", 2)
            set tParamList = $listfromstring(tParamList, "&")
            for tIter = 1:1:$listlength(tParamList) {
                set tParam = $listget(tParamList, tIter)
                set tName = $piece(tParam, "=", 1)
                set tValue = $piece(tParam, "=", 2, *)
                do tHttpRequest.SetParam(tName,tValue)
            }
        }

        set tHttpRequest.Location = tEndPoint.URL _ tLocation

        set tHttpRequest.Https = (tEndPoint.SSLConfig'="")
        set tHttpRequest.SSLCheckServerIdentity = 0 // tEndPoint.SSLCheckServerIdentity 
		set tHttpRequest.SSLConfiguration = tEndPoint.SSLConfig
    
        set tHttpRequest.ContentType = ..GetValue(pRequest.HTTPHeaders.GetAt("ContentType"), ..ContentType)
        
        // Must be set after ContentType
        set tHttpRequest.ContentCharset = "utf-8"
        
        //set tHttpRequest.WriteRawMode = 1
        if (tMethod'="GET") {
            while 'pRequest.Stream.AtEnd {
                do tHttpRequest.EntityBody.Write(pRequest.Stream.Read())
            }
        }
        do tHttpRequest.SetHeader("Accept", ..GetValue(pRequest.HTTPHeaders.GetAt("Accept"), ..ContentType))

		    $$$HSTRACE("HTTPPequest before "_tMethod, "HTTPRequest", tHttpRequest)

        set tSc = $case(tMethod,
                           "POST"   : tHttpRequest.Post(),
                           "PUT"    : tHttpRequest.Put(),
                           "GET"    : tHttpRequest.Get(),
                                    : tHttpRequest.Get())

		
			$$$HSTRACE("HTTPRequest after "_tMethod, "HTTPRequest", tHttpRequest)
            $$$HSTRACE("HTTPRequest Response data", "tHttpRequest.HttpResponse.Data", tHttpRequest.HttpResponse.Data)
        do tHttpRequest.HttpResponse.Data.Rewind()

        if pRequest.HTTPHeaders.GetAt("X-Response-Base64")=1 {
            set tTmpStream = ..StreamEncodeBase64(tHttpRequest.HttpResponse.Data)
            
        } else {
            /// HttpResponse.Data might be a %Stream.FileCharacterGzip, 
            ///     which is not directly supported by EnsLib.REST.GenericMessage.
            ///     Convert to a %Stream.GlobalBinary first
            set tTmpStream = ##class(%Stream.GlobalBinary).%New()
            do tTmpStream.CopyFrom(tHttpRequest.HttpResponse.Data)
        
        }

        set pResponse = ##class(EnsLib.REST.GenericMessage).%New(tTmpStream)
        
	
	} Catch tException {
		$$$LOGERROR(tException.AsStatus())
	}
	
	return $$$OK
}

ClassMethod StreamEncodeBase64(pStreamIn) As %Stream.GlobalCharacter
{
    /// From https://community.intersystems.com/post/large-stream-base64encoded
	// Base64 encoding means:
	// you take 3*N characters from the source
	// and put  4*N characters into the destination.
	// If the size of the source is not a multiple of 3 then
	// the last one or two bytes will be padded.
	// 
	// If you take an N such that 4*N less or equal 32767
	// (the max size of a short string) then Cache or IRIS
	// can work with short strings, which perform (usually)
	// better than long strings
	// 
	// N is integer.
	// 
	// A good value for N is 8190,
	// so you read 24570 bytes from the source and write 32760 to the destination
	// 
	// Of course, you can take whatever number up to  910286
	// (3 * 910286 = 2730858,  4 * 910286 = 3641144)
	// 
	set tLen = 8190*3
	set tFlag = 1 // this flag instructs $system.Encryption.Base64Encode
			// not to insert linebreaks at every 76 characters

	set tStreamOut = ##class(%Stream.GlobalCharacter).%New()
	do pStreamIn.Rewind()

	while 'pStreamIn.AtEnd {
		do tStreamOut.Write($system.Encryption.Base64Encode(pStreamIn.Read(tLen), tFlag))
	}

	return tStreamOut
}

ClassMethod GetValue(pTestValue = "", pDefaultValue = "") As %String
{
    if (pTestValue '="") {
        return pTestValue
    } else {
        return pDefaultValue
    }
}

}
