functor
export
   ToTag
   Ul
   Lr Td
   Labelled
   Table
define
   fun {ToTag T Xs}
      {List.toTuple T Xs}
   end
   
   fun {ToTagMap T Xs F}
      {ToTag T 
       {Map Xs F}
      }
   end
   
   fun {Ul Xs}
      {ToTagMap ul Xs fun {$ X} li(X) end}
   end

   fun {Labelled Label Tag}
      'div'(label('for':Tag.id Label)
	    Tag)
   end

   fun {Table Rows}
      {ToTag table {Map Rows ToRow}}
   end

   %% [X Y] -> tr(td(X) td(Y))
   fun {ToRow Cols}
      {ToTag tr {Map Cols fun {$ C} td(C) end}}
   end
   
   fun {Lr Xs}
      {Table [Xs]}
   end

   fun {Td Xs}
      {Table {Map Xs fun {$ X} [X] end}}
   end
end
