functor
import
   Util(commaSep:CommaSep)
   at 'x-ozlib://wmeyer/sawhorse/common/Util.ozf'
   Response(badRequestResponse:BadRequestResponse
	    expectationFailedResponse:ExpectationFailedResponse)
   at 'x-ozlib://wmeyer/sawhorse/common/Response.ozf'
   Search
   ExtraString(strip:Strip) at 'x-oz://system/String.ozf'
   URL
   Cookie at 'x-ozlib://wmeyer/sawhorse/pluginSupport/Cookie.ozf'
export
   ParseRequest
define
   fun {ParseRequest Config Request|Headers}
      case {String.tokens Request 32}
      of [CMD URI HttpVersion] then
	 try
	    ReqCmd = {Do Config {ParseCommand CMD}}
	    ReqURI = {Do Config {ParseReqURI URI}}
	    ReqHttpVer = {Do Config {ParseHttpVersion HttpVersion}}
	    ReqHeaders = {ParseHeaders Config Headers}
	    Cookies = {ParseCookies ReqHeaders}
	    Request = request(cmd:ReqCmd uri:ReqURI originalURI:URI originalHeaders:Headers
			      httpVersion:ReqHttpVer headers:ReqHeaders cookies:Cookies)
	 in
	    ok({AddRequestInterface Request})
	 catch bad(ErrorResponse) then
	    bad(ErrorResponse)
	 end
      else
	 bad({BadRequestResponse Config})
      end
   end

   VS2A = VirtualString.toAtom
   
   fun {AddRequestInterface Req}
      ReqHeaders = Req.headers
      Cookies = Req.cookies
      fun {HasHeader Key} {HasFeature ReqHeaders {VS2A Key}} end
      fun {GetHeader Key} ReqHeaders.{VS2A Key}.1 end
      fun {CondGetHeader Key Def} {CondSelect ReqHeaders {VS2A Key} [Def]}.1 end
      fun {GetAllHeaders Key} ReqHeaders.{VS2A Key} end
      fun {CondGetAllHeaders Key Def} {CondSelect ReqHeaders {VS2A Key} Def} end
      fun {HasCookie Key} {HasFeature Cookies {VS2A Key}} end
      fun {GetCookieExt Key} Cookies.{VS2A Key} end
      fun {CondGetCookieExt Key Def} {CondSelect Cookies {VS2A Key} Def} end
      fun {GetCookie Key} Cookies.{VS2A Key}.value end
      fun {CondGetCookie Key Def}
	 {CondSelect {CondSelect Cookies {VS2A Key} unit} value Def}
      end
   in
      {Adjoin Req
       request(hasCookie:HasCookie getCookie:GetCookie condGetCookie:CondGetCookie
	       getCookieExt:GetCookieExt condGetCookieExt:CondGetCookieExt
	       hasHeader:HasHeader getHeader:GetHeader condGetHeader:CondGetHeader
	       getAllHeaders:GetAllHeaders condGetAllHeaders:CondGetAllHeaders)}
   end
   
   fun {Do Config MaybeValue}
      case MaybeValue of nothing then raise bad({BadRequestResponse Config}) end
      [] just(X) then X
      end
   end

   fun {ParseCommand CMD}
      case CMD
      of "OPTIONS" then just(options)
      [] "GET" then just(get)
      [] "HEAD" then just(head)
      [] "POST" then just(post)
      [] "PUT" then just(put)
      [] "DELETE" then just(delete)
      [] "TRACE" then just(trace)
      [] "CONNECT" then just(connect)
      [] _ then just(extensionReq(CMD))
      end
   end
   
   fun {ParseReqURI URI}
      case URI of "*" then just(noURI)
      else just({URL.make URI})
      end
   end

   fun {ParseHttpVersion S}
      fun {SearchProc}
	 S1 S2 S3
	 Major Minor
      in
	 S = &H|&T|&T|&P|&/|S1
	 Major = {Int S1 S2}
	 S2 = &.|S3
	 Minor = {Int S3 nil}
	 Major#Minor
      end
   in
      case {Search.base.one SearchProc}
      of [Sol] then just(Sol)
      else nothing
      end
   end

   fun {Int In Remainder}
      Digits = {TakeDigits In Remainder}
   in
      {FoldL Digits fun {$ Z X} Z*10+X end 0}
   end
   
   fun {TakeDigits In ?Rem}
      {Map
       {List.takeDropWhile In Char.isDigit $ Rem}
       fun {$ D} D-&0 end
      }
   end

   %% must throw bad if parsing fails
   fun {ParseHeaders Config Hs}
      case {Sequence {Map Hs fun {$ H} {ParseHeader Config H} end}}
      of ok(Hs) then
	 Dict = {Dictionary.new}
      in
	 for T#C in Hs do
	    Dict.T := C|{CondSelect Dict T nil}
	 end
	 {Dictionary.toRecord headers Dict}
      end
   end

   fun {ParseCookies Headers}
      CookieHeaders = {CondSelect Headers cookie nil}
      CookiesPerHeader = {Map CookieHeaders Cookie.fromHeader}
   in
      {FoldL CookiesPerHeader Adjoin cookies}
   end
   
   %% throws if some element turns out "bad"
   fun {Sequence Ys}
      fun {Do Xs}
	 case Xs of nil then nil
	 [] X|Xr then
	    case X of ok(V) then V|{Do Xr}
	    [] bad(V) then raise bad(V) end
	    end
	 end
      end
   in
      ok({Do Ys})
   end

   fun {ParseHeader Config Header}
      HeaderType Val
   in
      {List.takeDropWhile Header fun {$ H} H \= &: end HeaderType Val}
      case Val of &:|Value then
	 Type = {String.toAtom {Map HeaderType Char.toLower}}
      in
	 {ParseHeaderAs Config Type {Strip Value unit}}
      else bad({BadRequestResponse Config})
      end
   end

   fun {ParseHeaderAs Config Type Value}
      case Type of connection then {ParseConnection Value}
      [] 'content-length' then {ParseLength Config Value}
      [] expect then {ParseExpect Config Value}
      [] host then {ParseHost Config Value}
      else ok(Type#Value)
      end
   end

   fun {ParseConnection S}
      ok(connection#{Map {CommaSep S} String.toAtom})
   end

   fun {ParseExpect Config S}
      case {CommaSep S}
      of ["100-continue"] then ok(expect#continue)
      else bad({ExpectationFailedResponse Config})
      end
   end
   
   fun {ParseHost Config S}
      case {String.tokens S &:}
      of [Host] then ok(host#host(name:Host port:80))
      [] [Host Port] then ok(host#host(name:Host port:{StringToInt Port}))
      else bad({BadRequestResponse Config})
      end
   end

   fun {ParseLength Config S}
      Rem
      Len = {Int S Rem}
   in
      if Rem == nil then ok('content-length'#Len)
      else bad({BadRequestResponse Config})
      end
   end
end