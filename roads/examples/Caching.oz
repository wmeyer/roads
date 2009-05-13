declare
[Roads] = {Module.link ['x-ozlib://wmeyer/roads/Roads.ozf']}

functor Pages
import
   Toplevel at 'x-ozlib://wmeyer/roads/Toplevel.ozf'
export
   Test
   PageCaching
define
   TLUnify = {Toplevel.makeProcedure Value.'='}
   Time = {Toplevel.makeFunction OS.time}

   ExpirePage = {NewCell unit}

   fun {PageCaching Session}
      true(functions:[test]
	   expire:proc {$ E} ExpirePage := E end
	  )
   end
   
   fun {Test Session}
      p("hello "#{Time}
	cached(fun {$ ExpireFragment}
		  p("fragment "#{Time} br
		    a("Expire fragment"
		      href:fun {$ _}
			      {TLUnify ExpireFragment unit}
			      redirect(303 url(function:test))
			   end
		     )
		   )
	       end
	      )
	a("Expire page"
	  href:fun {$ _}
		  {TLUnify @ExpirePage unit}
		  redirect(303 url(function:test))
	       end
	 )
       )
   end
end

in
{Roads.registerFunctor '' Pages}
{Roads.run}
