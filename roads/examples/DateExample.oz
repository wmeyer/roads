declare

[Roads] = {Module.link ['x-ozlib://wmeyer/roads/Roads.ozf']}

fun {Date Res}
   D M
in
   'div'(input(type:text id:day
	       validate:int_in(1 31) bind:D)
	 input(type:text id:month
	       validate:int_in(1 12) bind:M)
	 input(type:text id:year
	       validate:int_in(1900 3000)
	       bind:proc {$ Y}
		       Res = date(day:D month:M year:Y)
		    end
	      )
	)
end

fun {Test S}
   D
in
   form({Date D}
	method:post
	action:fun {$ S}
		  p("You entered "#D.year#"-"#D.month#"-"#D.day#".")
	       end
       )
end

in

{Roads.setSawhorseOption errorLogFile stdout}
{Roads.registerFunction date Test}
{Roads.run}
