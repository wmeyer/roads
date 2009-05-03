%%
%% Like Ajax2.oz, but uses JSON instead of HTML for the Ajax response.
%% This example needs both "javascript-0.2.0" and "jzon-0.2.0" installed.
%%
declare
[Roads] = {Module.link ['x-ozlib://wmeyer/roads/Roads.ozf']}

functor Select
export
   '':Select
require
   Javascript at 'x-ozlib://wmeyer/javascript/Javascript.ozf'
prepare
   JavaScriptCode =
   {Javascript.convertAndCheck
    [
     function onSelectChange(nil)
     [
      var selected '=' '$'("#selector option:selected")#val(nil)';'
      'if'(selected '!==' undefined '&&' selected '!==' "dummy")
      [
       '$'#getJSON( "/info" ','  object(type:selected) ','
		    function(data)
		    [
		     '$'("#content")#html("from: " '+' data#'from' '+' ", to: " '+' data#to)';' 
		    ]
		  )';'
      ]
     ]
     
     jQuery(document)#ready(
			function(nil)
			[
			 '$'("#selector")#change(onSelectChange)';'
			])';'
    ]
   }
define   
   fun {Select Session}
      html(
	 head(
	    title("JSON example")
	    %% load jQuery from Google
	    script(type:"text/javascript"
		   src:"http://ajax.googleapis.com/ajax/libs/jquery/1.3.2/jquery.min.js"
		  )
	    script(type:"text/javascript"
		   JavaScriptCode
		  )
	    style(css('div'#content
		      'border-width':".2em"
		      'border-style':solid
		      'border-color':"#900"))
	    )
	 body(
	    h2("Ajax with JSON Example")
	    'div'(
	       select(id:selector
		      option(value:dummy "--- Choose one ---")
		      option(value:sapiens "Homo sapiens")
		      option(value:neanderthal "Homo neanderthalensis")
		      option(value:heidelberg "Homo heidelbergensis")
		      option(value:erectus "Homo erectus")
		     )
	       br br
	       'div'(id:content "...")
	       )
	    )
	 )
   end
end

%% We define the Info function in a different functor because we need
%% a different mime type, which is only supported on functor (and app) level,
%% not on function level.
functor Info
import
   JSON at 'x-ozlib://wmeyer/jzon/JSON.ozf'
export
   '':Info
   MimeType
define
   MimeType = mimeType(application json)
   
   fun {Info S}
      {S.validateParameters [type]}
      {JSON.encode
       case {S.getParam type}.original
       of "sapiens" then object('from':200000 to:"now")
       [] "neanderthal" then object('from':400000 to:28000)
       [] "heidelberg" then object('from':600000 to:200000)
       [] "erectus" then object('from':1800000 to:40000)
       else null
       end
      }
   end
end
   
in

{Roads.registerFunctor select Select}
{Roads.registerFunctor info Info}
{Roads.run}
