%%
%%  Demonstrates that HTML form parts can easily be made composable.
%%  Allows to switch dynamically between textual and menu-based input of dates.
%%

declare

fun {EnterDate S}
   Date
   InputMethod = {S.condGet inputMethod TextualDate}
in
   'div'(
      form({InputMethod 2009 2020 ?Date}
	   input(type:submit value:"Submit date")
	   method:post
	   action:fun {$ _}
		     p("You entered "#Date.year#"-"#Date.month#"-"#Date.day#".")
		  end
	  )
      a("textual" href:fun {$ S} {S.set inputMethod TextualDate} {EnterDate S} end)
      " "
      a("popup" href:fun {$ S} {S.set inputMethod SelectDate} {EnterDate S} end)
      )
end

[Roads] = {Module.link ['x-ozlib://wmeyer/roads/Roads.ozf']}
{Roads.registerFunction date EnterDate}
{Roads.registerFunction dateSimple EnterDateSimple}
{Roads.run}

fun {EnterDateSimple S}
   Date
in
   form({TextualDate 2009 2020 ?Date}
	input(type:submit value:"Submit date")
	method:post
	action:fun {$ _}
		  p("You entered "#Date.year#"-"#Date.month#"-"#Date.day#".")
	       end
       )
end

%% Res will contain the date after successfull submission.
fun {TextualDate FirstYear LastYear Res}
   D M
in
   'div'(input(type:text id:day
	       validate:int_in(1 31) bind:D)
	 input(type:text id:month
	       validate:int_in(1 12) bind:M)
	 input(type:text id:year
	       validate:int_in(FirstYear LastYear)
	       bind:proc {$ Y}
		       Res = date(day:D month:M year:Y)
		    end
	      )
	)
end

%% Enter a date with popup menus.
fun {SelectDate FirstYear LastYear Res}
   D M
in
   'div'({Selector 1 31 ?D}
	 {Selector 1 12 ?M}
	 {Selector FirstYear LastYear
	  proc {$ Y}
	     Res = date(day:D month:M year:Y)
	  end
	 }
	)
end

fun {Selector F T ?Res}
   {Adjoin
    {List.toTuple select
     {Map {FromTo F T}
      fun {$ X} option({VirtualString.toString X}) end
     }
    }
    select(bind:Res
	   validate:int_in(F T)
	  )
   }
end

fun lazy {FromTo F T}
   if F =< T then F|{FromTo F+1 T}
   else nil
   end
end
