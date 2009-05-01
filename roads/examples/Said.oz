declare
[Roads] = {Module.link ['x-ozlib://wmeyer/roads/Roads.ozf']}

functor Pages
export
   Said
   After
define
   fun {Said Session}
      Foo
   in
      form(input(type:text bind:Foo)
	   input(type:submit)
	   method:post
	   action:fun {$ S}
		     p(a("click here"
			 href:fun {$ S}
				 p("you said: "#Foo
				  )
			      end
			))
		  end
	  )
   end
   
   fun {After Session Doc}
      html(head(title("Said"))
	   body(Doc)
	  )
   end
end

in

{Roads.registerFunctor '' Pages}
{Roads.run}

