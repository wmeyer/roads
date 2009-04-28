declare
[Roads] = {Module.link ['x-ozlib://wmeyer/roads/Roads.ozf']}

fun {Said Session}
   Foo
in
   html(
      body(
	 form(input(type:text bind:Foo)
	      input(type:submit)
	      method:post
	      action:fun {$ _}
			p(a("click here"
			    href:fun {$ _}
				    p("you said: "#Foo)
				 end
			   ))
		     end
	     )
	 ))
end

in

{Roads.registerFunction said Said}
{Roads.run}

