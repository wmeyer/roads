functor
export
   '<':LessThan
   '>':GreaterThan
   '=<':LessOrEqual
   '>=':GreaterOrEqual
define
   fun {LexicalLessThan Xs Ys}
      case Xs#Ys of nil#nil then false
      [] (_|_)#nil then false
      [] nil#(_|_) then true
      [] (X|Xr)#(Y|Yr) then
	 if X < Y then true
	 elseif X == Y then {LexicalLessThan Xr Yr}
	 else false
	 end
      end
   end

   fun {LessThan X Y}
      {Value.type X} = {Value.type Y}
      if {String.is X} then {LexicalLessThan X Y}
      else X < Y
      end
   end

   fun {LessOrEqual X Y}
      X == Y orelse {LessThan X Y}
   end

   fun {GreaterThan X Y}
      {Value.type X} = {Value.type Y}
      if {String.is X} then X \= Y andthen {Not {LexicalLessThan X Y}}
      else X > Y
      end
   end

   fun {GreaterOrEqual X Y}
      X == Y orelse {GreaterThan X Y}
   end
end
