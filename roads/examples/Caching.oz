declare
[Roads] = {Module.link ['x-ozlib://wmeyer/roads/Roads.ozf']}

functor Pages
import
   Toplevel at 'x-ozlib://wmeyer/roads/Toplevel.ozf'
export
   Test
   PageCaching
define
   TLUnify = {Toplevel.makeProc2 Value.'='}
   Time = {Toplevel.makeFun0 OS.time}

   ExpirePage = {NewCell unit}
   PageCaching = unit(functions:[test]
		      expire:proc {$ E} ExpirePage := E end
		     )

%   fun {PageCaching Session}
%   end
   
   fun {Test Session}
      html(
	 body(
	    p("hello "#{Time})
	    cached(
	       fun {$ ExpireFragment}
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
	    ))
   end
end

in
{Roads.registerFunctor '' Pages}
{Roads.run}
