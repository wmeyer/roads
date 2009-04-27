functor
export
   ToTag
   Ul
   Labelled
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
end