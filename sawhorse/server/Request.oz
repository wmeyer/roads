functor
import
   Util(commaSep:CommaSep) at 'x-ozlib://wmeyer/sawhorse/common/Util.ozf'
   Response(badRequestResponse:BadRequestResponse
	    expectationFailedResponse:ExpectationFailedResponse)
   at 'x-ozlib://wmeyer/sawhorse/common/Response.ozf'
   Search
   ExtraString(strip:Strip) at 'x-oz://system/String.ozf'
   URL
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
	 in
	    ok(request(cmd:ReqCmd uri:ReqURI originalURI:URI
		       httpVersion:ReqHttpVer headers:ReqHeaders))
	 catch bad(ErrorResponse) then
	    bad(ErrorResponse)
	 end
      else
	 bad({BadRequestResponse Config})
      end
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
      of ok(Hs) then Hs
      end
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
      case Val of &:|Value then {ParseHeaderAs Config HeaderType
				 {Strip Value unit}}
      else bad({BadRequestResponse Config})
      end
   end

   fun {ParseHeaderAs Config Type Value}
      case {Map Type Char.toLower}
      of "connection"           then {ParseConnection Value}
      [] "date"                 then ok(date(Value))
      [] "pragma"               then ok(pragma(Value))
      [] "trailer"              then ok(trailer(Value))
      [] "transfer-encoding"    then ok(transferEncoding(Value))
      [] "upgrade"              then ok(upgrade(Value))
      [] "via"                  then ok(via(Value))
      [] "warning"              then ok(warning(Value))
      [] "content-type"         then ok(contentType(Value))
      [] "content-length"       then {ParseLength Config Value}
      [] "accept"               then ok(accept(Value))
      [] "accept-charset"       then ok(acceptCharset(Value))
      [] "accept-encoding"      then ok(acceptEncoding(Value))
      [] "accept-language"      then ok(acceptLanguage(Value))
      [] "authorization"        then ok(authorization(Value))
      [] "cache-control"        then ok(cacheControl(Value))
      [] "expect"               then {ParseExpect Config Value}
      [] "from"                 then ok('from'(Value))
      [] "host"                 then {ParseHost Config Value}
      [] "if-match"             then ok(ifMatch(Value))
      [] "if-modified-since"    then ok(ifModififiedSince(Value))
      [] "if-none-match"        then ok(ifNoneMatch(Value))
      [] "if-range"             then ok(ifRange(Value))
      [] "if-unmodified-since"  then ok(ifUnmodififiedSince(Value))
      [] "max-forwards"         then ok(maxForwards(Value))
      [] "proxy-authorization"  then ok(proxyAuthorization(Value))
      [] "range"                then ok(range(Value))
      [] "referer"              then ok(referer(Value))
      [] "te"                   then ok(te(Value))
      [] "user-agent"           then ok(userAgent(Value))
      [] "cookie"               then ok(cookie(Value))
      [] Other                  then ok(extensionHeader(Other Value))
      end
   end

   fun {ParseConnection S}
      ok(connection(
	    {Map {CommaSep S}
	     fun {$ T}
		case T of "close" then close
		[] "keep-alive" then keepAlive
		[] Other then other(Other)
		end
	     end
	    })
	)
   end

   fun {ParseExpect Config S}
      case {CommaSep S}
      of ["100-continue"] then ok(expect(continue))
      else bad({ExpectationFailedResponse Config})
      end
   end
   
   fun {ParseHost Config S}
      case {String.tokens S &:}
      of [Host] then ok(host(Host 80))
      [] [Host Port] then ok(host(Host {StringToInt Port}))
      else bad({BadRequestResponse Config})
      end
   end

   fun {ParseLength Config S}
      Rem
      Len = {Int S Rem}
   in
      if Rem == nil then ok(contentLength(Len))
      else bad({BadRequestResponse Config})
      end
   end
end