declare
[Roads] = {Module.link ['x-ozlib://wmeyer/roads/Roads.ozf']}

fun {Expire Session}
   C = {Session.createContext}
in
   html(
      head(title("Expire example"))
      body(p(a("A simple link" href:fun {$ S} "success" end) br
	     a("Expire links" href:fun {$ S} {C expire} "expired" end)
	    )
	  )
      )
end

in

{Roads.registerFunction expire Expire}
{Roads.run}

