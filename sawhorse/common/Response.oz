functor
import
   Config(serverSoftware:ServerSoftware serverVersion:ServerVersion)
   Util(concat:Concat formatTime:FormatTime)
   Html(render:RenderHtml)
   OS Open
export
   AddHeader
   SendResponse
   ContentTypeHeader
   LastModifiedHeader
   ExpiresHeader
   LocationHeader
   ContResponse
   SwitchingProtocolsResponse
   OkResponse
   CreatedResponse
   AcceptedResponse
   NonAuthoritiveInformationResponse
   NoContentResponse
   ResetContentResponse
   PartialContentResponse
   RedirectResponse
   BadRequestResponse
   UnauthorizedResponse
   PaymentRequiredResponse
   ForbiddenResponse
   NotFoundResponse
   MethodNotAllowedResponse
   NotAcceptableResponse
   ProxyAuthenticationRequiredResponse
   RequestTimeOutResponse
   ConflictResponse
   GoneResponse
   LengthRequiredResponse
   PreconditionFailedResponse
   RequestEntityTooLargeResponse
   RequestURITooLargeResponse
   UnsupportedMediaTypeResponse
   RequestedRangeNotSatisfiableResponse
   ExpectationFailedResponse
   InternalServerErrorResponse
   InternalServerErrorResponseWithDesc
   NotImplementedResponse
   BadGatewayResponse
   ServiceUnavailableResponse
   GatewayTimeOutResponse
   VersionNotSupportedResponse
define
   fun {AddHeader Resp H}
      {AdjoinAt Resp headers H|Resp.headers}
   end
   
   proc {SendResponse Socket
	 response(code:Code headers:Headers coding:TES body:Body sendBody:DoSendBody)}
      proc {SendL L} {SendLine Socket L} end
      ContentLen = {ContentLength Body}
   in
      {SendL {StatusLine Code}}
      {SendL ServerHeader}
      {SendL {DateHeader}}
      {ForAll Headers SendL}

      if ContentLen \= 0 andthen TES == nil then
	 {SendL {ContentLengthHeader ContentLen}}
      end

      {ForAll {Map TES TransferCodingHeader} SendL}

      {SendL nil}

      %% ToDo: implement transfer codings

      if DoSendBody then {SendBody Socket Body} end
   end

   proc {SendLine Socket L}
      {Socket write(vs:L#"\r\n")}
   end

   fun {ContentLength Body}
      case Body of noBody then 0
      [] generated(Stuff) then {Length Stuff}
      [] fileBody(Size ...) then Size
      end
   end

   proc {SendBody Socket Body}
      case Body of noBody then skip
      [] generated(Stuff) then
	 {Socket write(vs:Stuff)}
	 {Socket flush}
      [] fileBody(_ Filename) then
	 {WithOpenFile Filename [read]
	  proc {$ File}
	     {Squirt File Socket}
	     {Socket flush}
	  end
	 }
      end
   end

   proc {WithOpenFile Filename Flags Proc}
      F
   in
      try
	 F = {New Open.file init(name:Filename flags:Flags)}
      in
	 {Proc F}
      finally
	 if {IsDet F} then {F close} end
      end
   end

   local
      BufSize = 4096
   in
      proc {Squirt File Socket}
	 Buf L
      in
	 {File read(list:Buf size:BufSize len:L)}
	 if L == 0 then skip
	 else
	    {Socket write(vs:Buf)}
	    if L == BufSize then
	       {Squirt File Socket}
	    end
	 end
      end
   end

   fun {StatusLine Code}
      {Concat
       [HttpVersion
	32|{IntToString Code}
	32|{ResponseDescription Code}
       ]}
   end

   fun {DateHeader} {Append "Date: " {FormatTime {OS.gmTime}}} end

   ServerHeader = {Concat ["Server: " ServerSoftware &/|ServerVersion]}

   fun {ContentLengthHeader I} {Append "Content-Length: " {IntToString I}} end

   fun {ContentTypeHeader M=mimeType(P1 P2 ...)}
      {VirtualString.toString "Content-Type: "#P1#"/"#P2#
       if P1 == text then
	  "; charset="#{CondSelect M charset "ISO-8859-1"}
       else
	  nil
       end
      }
   end

   fun {LastModifiedHeader T} {Append "Last-Modified: " {FormatTime T}} end

   fun {ExpiresHeader T} {Append "Expires: " {FormatTime T}} end
   
   fun {LocationHeader L} {Append "Location: " L} end

   fun {TransferCodingHeader TE} {Append "Transfer-Coding: " {TransferCodingStr TE}} end

   fun {TransferCodingStr TE}
      case TE of chunked then "chunked"
      [] gzip then "gzip"
      [] compress then "compress"
      [] deflate then "deflate"
      end
   end

   
   fun {ErrorResponse Code}
      fun {$ Config}
	 response(code:Code headers:[{ContentTypeHeader mimeType( text html )}]
		  coding:nil body:{GenerateErrorPage Code Config nil}
		  sendBody:true)
      end
   end

   fun {ErrorResponseWithDesc Code}
      fun {$ Config Desc}
	 response(code:Code headers:[{ContentTypeHeader mimeType( text html )}]
		  coding:nil body:{GenerateErrorPage Code Config Desc}
		  sendBody:true)
      end
   end
   
   fun {BodyResponse Code}
      fun {$ Config Body Headers BodyFlag}
	 SendBody = case BodyFlag of withBody then true [] withoutBody then false end
      in
	 response(code:Code headers:Headers
		  coding:nil body:Body
		  sendBody:SendBody)
      end
   end

   ContResponse                         = {ErrorResponse 100}
   SwitchingProtocolsResponse           = {ErrorResponse 101}
   OkResponse                           = {BodyResponse 200}
   CreatedResponse                      = {ErrorResponse 201}
   AcceptedResponse                     = {ErrorResponse 202}
   NonAuthoritiveInformationResponse    = {ErrorResponse 203}
   NoContentResponse                    = {ErrorResponse 204}
   ResetContentResponse                 = {ErrorResponse 205}
   PartialContentResponse               = {ErrorResponse 206}
   BadRequestResponse                   = {ErrorResponse 400}
   UnauthorizedResponse                 = {ErrorResponse 401}
   PaymentRequiredResponse              = {ErrorResponse 402}
   ForbiddenResponse                    = {ErrorResponse 403}
   NotFoundResponse                     = {ErrorResponse 404}
   MethodNotAllowedResponse             = {ErrorResponse 405}
   NotAcceptableResponse                = {ErrorResponse 406}
   ProxyAuthenticationRequiredResponse  = {ErrorResponse 407}
   RequestTimeOutResponse               = {ErrorResponse 408}
   ConflictResponse                     = {ErrorResponse 409}
   GoneResponse                         = {ErrorResponse 410}
   LengthRequiredResponse               = {ErrorResponse 411}
   PreconditionFailedResponse           = {ErrorResponse 412}
   RequestEntityTooLargeResponse        = {ErrorResponse 413}
   RequestURITooLargeResponse           = {ErrorResponse 414}
   UnsupportedMediaTypeResponse         = {ErrorResponse 415}
   RequestedRangeNotSatisfiableResponse = {ErrorResponse 416}
   ExpectationFailedResponse            = {ErrorResponse 417}
   InternalServerErrorResponse          = {ErrorResponse 500}
   InternalServerErrorResponseWithDesc  = {ErrorResponseWithDesc 500}
   NotImplementedResponse               = {ErrorResponse 501}
   BadGatewayResponse                   = {ErrorResponse 502}
   ServiceUnavailableResponse           = {ErrorResponse 503}
   GatewayTimeOutResponse               = {ErrorResponse 504}
   VersionNotSupportedResponse          = {ErrorResponse 505}

   fun {RedirectResponse Config Code NewLocation}
      response(code:Code
	       headers:[{ContentTypeHeader mimeType( text html )}
			{LocationHeader NewLocation}]
	       coding:nil
	       body:generated(
		       {VirtualString.toString "<a href=\""#NewLocation#"\">redirect</a>"})
	       sendBody:true)
   end
   
   HttpVersion = "HTTP/1.1"

   local
      Desc = unit(100:"Continue"
		  101: "Switching Protocols"              

		  200: "OK"                          
		  201: "Created"                          
		  202: "Accepted"                         
		  203: "Non-Authoritative Information"    
		  204: "No Content"                       
		  205: "Reset Content"                    
		  206: "Partial Content"                  

		  300: "Multiple Choices"                 
		  301: "Moved Permanently"                
		  302: "Found"                            
		  303: "See Other"                        
		  304: "Not Modified"                     
		  305: "Use Proxy"                        
		  307: "Temporary Redirect"               
		  
		  400: "Bad Request"                      
		  401: "Unauthorized"                     
		  402: "Payment Required"                 
		  403: "Forbidden"                        
		  404: "Not Found"                        
		  405: "Method Not Allowed"               
		  406: "Not Acceptable"                   
		  407: "Proxy Authentication Required"    
		  408: "Request Time-out"                 
		  409: "Conflict"                         
		  410: "Gone"                             
		  411: "Length Required"                  
		  412: "Precondition Failed"              
		  413: "Request Entity Too Large"         
		  414: "Request-URI Too Large"            
		  415: "Unsupported Media Type"           
		  416: "Requested range not satisfiable"  
		  417: "Expectation Failed"               

		  500: "Internal Server Error"            
		  501: "Not Implemented"                  
		  502: "Bad Gateway"                      
		  503: "Service Unavailable"              
		  504: "Gateway Time-out"                 
		  505: "HTTP Version not supported"       
		 )
   in
      fun {ResponseDescription Code}
	 {CondSelect Desc Code "Unknown response"}
      end
   end

   fun {GenerateErrorPage Code Config Desc}
      generated({RenderHtml {GenErrorHtml Code Config Desc}})
   end
   
   fun {GenErrorHtml Code Config Desc}
      Response = Code#" "#{ResponseDescription Code}
   in
      html(
	 header(title(Response))
	 body(
	    h1(Response)
	    case Desc of nil then noHtml
	    else
	       p("Error description:"
		 br br
		 Desc
		)
	    end
	    hr
	    p(ServerSoftware#"/"#ServerVersion
	      case Config.serverName
	      of nil then noHtml
	      [] S then " on "#S
	      end br
	      case Config.serverAdmin
	      of nil then noHtml
	      [] Admin then a(href:"mailto:"#Admin
			      Admin
			     )
	      end
	     )
	    )
	 )
   end
end
