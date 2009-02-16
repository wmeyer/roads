functor
import
   Regex at 'x-oz://contrib/regex'
   ExtraString(strip:Strip) at 'x-oz://system/String.ozf'
   Util(nubBy:NubBy
	filterRecordsByLabel:FilterRecordsByLabel)
   at 'x-ozlib://wmeyer/sawhorse/common/Util.ozf'
export
   FromHeader
   ToHeader
   GetCookie
   SetCookie
define
   %% Parses cookies sent from the client.
   %% Returns: cookies(
   %%            'cookie1':cookie(value:Val1 path:"/" domain:nil ... version:0)
   %%                 )
   fun {FromHeader cookie(Val)}
      KeyValuePairs = {Map {RegexSplit ",|;" Val}
		       fun {$ Line} {Map {Token Line &=} StripWS} end}
      Version = {NewCell 0}
      CurrentCookieName = {NewCell nil}
      CurrentCookie = {NewDictionary}
      fun {CreateCurrentCookie}
	 {ParseName @CurrentCookieName}#{Dictionary.toRecord cookie CurrentCookie}
      end
   in
      {List.toRecord cookies
       {NubBy fun {$ K1#_ K2#_} K1 == K2 end
	{Append
	 for [Key Value] in KeyValuePairs collect:C do
	    case Key of "$Version" then Version := Value
	    [] "$Path" then CurrentCookie.path := Value
	    [] "$Domain" then CurrentCookie.domain := Value
	    [] CookieName then
	       if @CurrentCookieName \= nil then
		  {C {CreateCurrentCookie}}
	       end
	       CurrentCookieName := CookieName
	       {Dictionary.removeAll CurrentCookie}
	       CurrentCookie.version := @Version
	       CurrentCookie.value := {ParseValue Value}
	    end
	 end
	 %% collect the last one
	 if @CurrentCookieName \= nil then
	    [{CreateCurrentCookie}]
	 else nil
	 end
	}
       }
      }
   end

   fun {Token Xs Sep}
      L R
   in
      {String.token Xs Sep L R}
      [L R]
   end
   
   fun {RegexSplit RE Txt}
      {Map {Regex.split {Regex.make RE} Txt} ByteString.toString}
   end
   
   fun {ParseValue Val}
      case Val of nil then nil
      [] &"|R andthen {List.last Val}==&" then {List.take R {Length R}-1}
      else Val
      end
   end

   fun {ParseName Key}
      {String.toAtom Key}
   end
   
   fun {StripWS Xs}
      {Strip Xs unit}
   end

   %% Create a set-cookie header for a single cookie.
   %% F.e. cookie(name:"string" otherAttribute:"val2" other:unit)
   %% -> "Set-Cookie: name=string; other; otherAttribute=val2"
   fun {ToHeader C=cookie(name:CookieName value:Val ...)}
      {VirtualString.toString
       "Set-Cookie: "#CookieName#"=\""#Val#"\""#
       {List.toTuple '#'
	{Map {Filter {Record.toListInd C} fun {$ K#_} K \= name andthen K \= value end}
	 fun {$ K#V}
	    "; "#{Atom.toString K}#
	    if V \= unit then "="#V#"" else "" end
	 end
	}}
      }
   end

   fun {GetCookie Request CookieName}
      for Header in {FilterRecordsByLabel cookie Request.headers}
	 return:R default:nothing do
	 Cookies = {FromHeader Header}
      in
	 if {HasFeature Cookies CookieName} then {R just(Cookies.CookieName)} end
      end
   end

   fun {SetCookie Response Cookie}
      {AdjoinAt Response headers {ToHeader Cookie}|Response.headers}
   end   
end