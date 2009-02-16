functor
export
   Config
   After
define
   Config = config(functors:unit('':Pages))

   functor Pages
   export
      '':Said
   define
      fun {Said Session}
	 Foo
      in
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
      end
   end

   fun {After Session Doc}
      html(head(title("Said"))
	   body(Doc)
	  )
   end
end
