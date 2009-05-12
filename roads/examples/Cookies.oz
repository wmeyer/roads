declare

[Roads] = {Module.link ['x-ozlib://wmeyer/roads/Roads.ozf']}

fun {CookieTest S}
   CookieName
   CookieText
   HeaderName
   HeaderValue
in
   form(
      "User agent: " {S.request.condGetHeader 'user-agent' "none"} br
      "Accept: " {S.request.condGetHeader 'accept' "none"} br
      "Accept-Language: " {S.request.condGetHeader 'accept-language' "none"} br
      "Accept-Encoding: " {S.request.condGetHeader 'accept-encoding' "none"} br
      "Accept-Charset: " {S.request.condGetHeader 'accept-charset' "none"} br br
      "Enter name of cookie: " input(type:text bind:CookieName) br
      "Enter text for cookie: " input(type:text bind:CookieText) br
      "Enter header name: " input(type:text bind:HeaderName) br
      "Enter header value: " input(type:text bind:HeaderValue) br
      input(type:submit)
      action:fun {$ S}
		{S.response.addCookie CookieName.escaped CookieText.escaped}
		{S.response.addHeader HeaderName.escaped#": "#HeaderValue.escaped}
		a("Show cookie from client..."
		  href:fun {$ S}
			  "Cookie value: "#{S.request.getCookie CookieName.escaped}
		       end
		 )
	     end
      )
end

in
{Roads.registerFunction cookies CookieTest}
{Roads.run}
