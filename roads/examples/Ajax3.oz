declare
[Roads] = {Module.link ['x-ozlib://wmeyer/roads/Roads.ozf']}

functor Ajax
export
   Select
   Info
define   
   fun {Select Session}
      html(
	 head(
	    title("Ajax example")
	    %% load jQuery from Google
	    script(type:"text/javascript"
		   src:"http://ajax.googleapis.com/ajax/libs/jquery/1.3.2/jquery.min.js"
		  )
	    script(type:"text/javascript"
		   javascript(
		      function onSelectChange(nil)
		      [
		       var selected '=' '$'("#selector option:selected")#val(nil)';'
		       'if'(selected '!==' undefined '&&' selected '!==' "dummy")
		       [
			'$'("#content")#load("info" ',' object(type:selected))';'
		       ]
		      ]
		      
		      jQuery(document)#ready(
					 function(nil)
					 [
					  '$'("#selector")#change(onSelectChange)';'
					 ])';'
		      )
		  )
	    style(type:"text/css"
		  css('div'#content
		      'border-width':".2em"
		      'border-style':solid
		      'border-color':"#900"))
	    )
	 body(
	    h2("Simple Ajax Example")
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

   fun {Info S}
      "existed from "#
      case {S.getParam type}.original
      of "sapiens" then "200,000 years ago to now"
      [] "neanderthal" then "400,000 years ago to 28,000 years ago"
      [] "heidelberg" then "600,000 years ago to 200,000 years ago"
      [] "erectus" then "1,800,000 years ago to 40,000 years ago"
      else "unknown"
      end
   end
end
   
in

{Roads.setSawhorseOption errorLogFile stdout}
{Roads.registerFunctor '' Ajax}
{Roads.run}
