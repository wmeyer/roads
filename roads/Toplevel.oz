functor
export
   MakeProc0
   MakeProc2
   MakeFun0
   MakeFun1
define
   fun {CreateToplevelFunApplier}
      ApplyPort
      thread
	 for (Proc#Args)#Res in {Port.new $ ApplyPort} do
	    {Procedure.apply Proc {Append Args [Res]}}
	 end
      end
   in
      fun {$ Proc Args}
	 {Port.sendRecv ApplyPort Proc#Args}
      end
   end

   fun {CreateToplevelProcApplier}
      ApplyPort
      thread
	 for (Proc#Args)#Sync in {Port.new $ ApplyPort} do
	    {Procedure.apply Proc Args}
	    Sync = unit
	 end
      end
   in
      fun {$ Proc Args}
	 {Port.sendRecv ApplyPort Proc#Args}
      end
   end

   fun {MakeFun0 Proc}
      A = {CreateToplevelFunApplier}
   in
      fun {$}
	 {A Proc nil}
      end
   end

   fun {MakeFun1 Proc}
      A = {CreateToplevelFunApplier}
   in
      fun {$ Arg1}
	 {A Proc [Arg1]}
      end
   end

   fun {MakeProc0 Proc}
      A = {CreateToplevelProcApplier}
   in
      proc {$}
	 {Wait {A Proc nil}}
      end
   end

   fun {MakeProc2 Proc}
      A = {CreateToplevelProcApplier}
   in
      proc {$ A1 A2}
	 {Wait {A Proc [A1 A2]}}
      end
   end
end
