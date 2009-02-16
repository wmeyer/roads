functor
import
   Remote Finalize
export
   Make
define
   RegisterRemoteManager = {Finalize.guardian proc {$ RM} {RM close} end}

   %% Create a procedure that is executed in its own process.
   %% The process is started immediately. It is stopped when the
   %% procedure value is garbage collected.
   %% Features of Spec:
   %%  * moduleURL OR * moduleName
   %%  * procedure (atom)
   %% For example: {MakeRemoteProcedure spec(moduleName:'Pickle' procedure:save)}
   %% The resulting procedure always has two arguments:
   %%  - a list of arguments for the wrapped proc
   %%  - a variable that is bound to unit when the procedure call has finished
   %%    or to a failed value if an exception has occured.
   fun {Make Spec}
      LinkSpec = if {HasFeature Spec moduleURL} then link(url:Spec.moduleURL)
		 elseif {HasFeature Spec moduleName} then link(name:Spec.moduleName)
		 end
      Proc = Spec.procedure
      SharedPort
      RemoteFunctor =
      functor
      import
	 Module
      define
	 Mod
	 {{New Module.manager init} {Adjoin LinkSpec link(Mod)}}
	 thread
	    for Args#Return in {NewPort $ SharedPort} do
	       try
		  {Procedure.apply Mod.Proc {Access Args}}
		  Return = unit
	       catch E then Return={Value.failed E} end
	    end
	 end
      end
      RemoteM = {New Remote.manager init}
      {RegisterRemoteManager RemoteM}
   in
      {RemoteM apply(RemoteFunctor)}
      proc {$ Args ?Done}
	 %% wrap Args in a cell to avoid distribution bug with large immutable data
	 {Port.sendRecv SharedPort {NewCell Args} Done}
      end
   end
end
