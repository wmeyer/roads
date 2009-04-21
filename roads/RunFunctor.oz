functor
import
   Application
   Connection
   Module
define
   fun {CreateServer Mod}
      P
      thread
	 for (ProcFeat#Args)#Sync in {Port.new $ P} do
	    try
	       {Procedure.apply Mod.ProcFeat Args}
	       Sync = unit
	    catch E then
	       Sync = E
	    end
	 end
      end
   in
      P
   end
   
   Args = {Application.getCmdArgs
	   record(
	      'functor'(single type:string optional:false)
	      result(single type:string optional:false)
	      )}
   Result = {Connection.take {String.toAtom Args.result}}
   [Functor] = {Module.link [{String.toAtom Args.'functor'}]}
   Result = {CreateServer Functor}
end
