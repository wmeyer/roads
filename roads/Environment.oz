functor
export
   'class':Environment
define
      %% Keeps track of "bind" attributes of a form
   %% and can create a wrapped version of the "action" function.
   class Environment
      attr
	 counter
      feat
	 bindings
      meth init
	 counter := 0
	 self.bindings = {Dictionary.new}
      end
      meth newName(N)
	 New
	 Old = counter := New
      in
	 New = Old+1
	 N = {VirtualString.toAtom roadsFormBinding#Old}
      end
      meth add(Name Var)
	 self.bindings.Name := Var
      end
      meth with(F Res)
	 Res =
	 {FoldL {Dictionary.entries self.bindings}
	  fun {$ F0 B#V}
	     fun {$ S}
		V = {S.getParam B}
		{F0 S}
	     end
	  end
	  F}
      end
   end
end
