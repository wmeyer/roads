declare
[Roads Util] = {Module.link
		['x-ozlib://wmeyer/roads/Roads.ozf'
		 'x-ozlib://wmeyer/sawhorse/common/Util.ozf'
		]}

Languages = unit("Oz" "C" "C++" "Haskell" "Lisp" "Java" "Ruby" "Python" "C#" "Ocaml")

fun {FavoritePLs S}
   Favorites
in
   form(select(multiple:unit
	       size:10
	       validate:list({Adjoin Languages one_of})
	       bind:list(Favorites)
	       {Record.map Languages fun {$ L} option(L) end}
	      )
	br
	input(type:submit value:"Submit")
	method:post
	action:fun {$ S}
		  p("Your favorite programming languages are: "
		    {Util.intercalate Favorites.escaped ", "}
		   )
	       end
       )
end

in

{Roads.registerFunction favorite FavoritePLs}
{Roads.run}
