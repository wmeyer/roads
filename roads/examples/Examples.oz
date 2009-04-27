functor
export
   '':Overview
   Sum
   Counter
   CounterWithTest
   SharedCounter
   After
define
   fun {Overview Session}
      'div'
   end
   
   fun {Sum Session}
      A = {Session.condGet a 0}
      B = {Session.condGet b 0}
   in
      p(A#" + "#B#" = "#(A+B) br
	a("enter first" href:{EnterInt a A Sum})
	"&nbsp;"
	a("enter second" href:{EnterInt b B Sum})
       )
   end

   fun {EnterInt F OV Next}
      fun {$ Session} V in
	 form(input(type:text
		    validate:int
		    bind:V value:{IntToString OV})
	      input(type:submit)
	      method:post
	      action:fun {$ S}
			{S.set F {String.toInt V.original}}
			{Next S}
		     end
	     )
      end
   end

   fun {Counter S}
      Count = {S.condGet count 0}
   in
      'div'(
	 h1("Counter: "#Count)
	 p(a("++" href:fun {$ S} {S.set count Count+1} {Counter S} end)
	   "&nbsp;&nbsp;"
	   a("--" href:fun {$ S} {S.set count Count-1} {Counter S} end)
	  )
	 )
   end

   fun {CounterWithTest S}
      Count = {S.condGet count 0}
   in
      'div'(
	 h1("Counter: "#Count)
	 p(a("++" href:fun {$ S}
			  if Count == 5 then
			     {S.set count 0}
			     p("Count cannot exceed 5!"
			       a("Ok" href:CounterWithTest)
			      )
			  else
			     {S.set count Count+1}
			     {CounterWithTest S}
			  end
		       end)
	   "&nbsp;&nbsp;"
	   a("--" href:fun {$ S} {S.set count Count-1} {CounterWithTest S} end)
	  )
	 )
   end

   fun {SharedCounter S}
      'div'(
	 h1("Counter: "#{S.condGetShared count 0})
	 p(a("++" href:fun {$ S}
			  Count = {S.condGetShared count 0}
		       in
			  {S.setShared count Count+1} {SharedCounter S}
		       end)
	   "&nbsp;&nbsp;"
	   a("--" href:fun {$ S}
			  Count = {S.condGetShared count 0}
		       in
			  {S.setShared count Count-1} {SharedCounter S}
		       end)
	  )
	 )
   end

   fun {After Session HtmlDoc}
      html(
	 head(title("Examples"))
	 body(
	    'div'(
	       HtmlDoc
	       hr
	       'div'(
		  a(href:url(function:sum) "Sum") "&nbsp;"
		  a(href:url(function:counter) "Counter") "&nbsp;"
		  a(href:url(function:counterWithTest) "CounterWithTest") "&nbsp;"
		  a(href:url(function:sharedCounter) "SharedCounter")
		  )
	       )
	    )
	 )
   end
end
