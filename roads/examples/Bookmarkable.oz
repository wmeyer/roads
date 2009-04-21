declare
[Roads] = {Module.link ['x-ozlib://wmeyer/roads/Roads.ozf']}

functor Pages
export
   Said
   HandleSaid
   After
define
   fun {Said Session}
      form(input(type:text name:foo)
	   input(type:submit)
	   method:get
	   action:"/handleSaid" %url(function:handleSaid)
	  )
   end

   fun {HandleSaid S}
      Foo = {S.getParam foo}
   in
      {S.validateParameters [foo(validate:length_in(1 10))]}
      p(a("click here"
	  href:fun {$ S}
		  {S.regenerateSessionId}
		  p("you said: "#Foo)
	       end
	 ))
   end

   fun {After Session Doc}
      html(head(title("Said"))
	   body(Doc)
	  )
   end
end

in

{Roads.setSawhorseOption errorLogFile stdout}
{Roads.registerFunctor '' Pages}
{Roads.run}

