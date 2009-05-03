%% A very primitive stack implementation.
functor
export
   New Top Push Pop
define
   fun {New Init}
      {NewCell {Reverse Init}}
   end

   fun {Top Stack}
      (@Stack).1
   end

   proc {Push Stack X}
      Stack:=X|@Stack
   end

   proc {Pop Stack}
      Stack:=(@Stack).2
   end
end
