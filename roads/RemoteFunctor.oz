functor
import
%   DP
   Property
export
   Create
define
   %% Create an "active functor" whose procedures will be executed at RemoteManager.
   %% Procedure calls are synchronous and may not have more than 11 arguments.
   %% Will throw at creation if the module could not be linked.
   %% Exceptions from application code are forwarded to the local machine.
   %% Customizable timeout: property 'remoteFunctor.timeout'
   %%
   %% URL: where the functor is installed at the remote site
   %% RemoteManager: properly initialized Remote.manager
   %% Return: a record that behaves like an applied functor
   fun {Create URL RemoteManager}
      ModSpec
      Prt = {StartRemoteFunctor RemoteManager URL ?ModSpec}
   in
      if {Value.isFailed Prt} then raise Prt end end
      {CreateClient ModSpec Prt}
   end

   %% Returns a distributed port.
   %% In ModSpec: record that describes the linked module.
   %% (We cannot link the module locally because for some reason(?), we
   %% cannot use "Module" in this functor.)
   fun {StartRemoteFunctor RemoteManager URL ?ModSpec}
      functor F
      import
	 Module
      export
	 Prt
	 Spec
      define
	 fun {CreateServer Mod}
	    P
	    thread
	       for (ProcFeat#Args)#Sync in {Port.new $ P} do
		  thread
		     try
			{Procedure.apply Mod.ProcFeat Args}
			Sync = unit
		     catch E then
			Sync = E
		     end
		  end
	       end
	    end
	 in
	    P
	 end

	 fun {CreateSpec Mod}
	    {Record.map Functr
	     fun {$ F}
		{Value.makeNeeded F}
		if {IsDet F} andthen {Procedure.is F} then procedure({Procedure.arity F})
		else nothing
		end
	     end}
	 end
	 
	 Functr Prt Spec
	 try
	    [Functr] = {Module.link [URL]}
	    Spec = {CreateSpec Functr}
	    Prt = {CreateServer Functr}
	 catch _ then
	    Prt = {Value.failed remoteFunctor(cannotLinkFunctorAtRemoteSite
					      manager:RemoteManager url:URL)}
	 end
      end
      AF = {RemoteManager apply(F $)}
   in
      ModSpec = AF.spec
      AF.prt
   end

   %% like Port.sendRecv but with timeout
   fun {SendRecv P Msg}
      Events = unit(1:{Port.sendRecv P Msg}
		    2:{Time.alarm {Property.condGet 'remoteFunctor.timeout' 10000}}
		   )
   in
      case {Record.waitOr Events}
      of 1 then Events.1
      else remoteFunctor(timeout msg:Msg)
      end
   end

/*   ImplementationHasFaultStreams = try {HasFeature DP getFaultStream} catch _ then false end
   
   CheckFaultState = if ImplementationHasFaultStreams then
			proc {$ P}
			   case {DP.getFaultStream P}
			   of ok|_ then skip
			   [] FailType|_ then raise remoteFunctor(FailType) end
			   end
			end
		     else
			proc {$ P}
			   skip
			end
		     end
  */ 
   %% 
   fun {CreateClient ModSpec Prt}
      {Record.mapInd ModSpec
       fun {$ Ind F}
	  case F of procedure(Ar) then
	     proc {CallWith Args}
%		{CheckFaultState Prt}
		case {SendRecv Prt Ind#Args} of unit then skip
		[] E=remoteFunctor(...) then raise E end
		[] E then
		   raise remoteFunctor(applicationException:E) end
		end
	     end
	  in			  
	     case Ar
	     of 0 then proc {$} {CallWith nil} end
	     [] 1 then proc {$ A1} {CallWith [A1]} end
	     [] 2 then proc {$ A1 A2} {CallWith [A1 A2]} end
	     [] 3 then proc {$ A1 A2 A3} {CallWith [A1 A2 A3]} end
	     [] 4 then proc {$ A1 A2 A3 A4} {CallWith [A1 A2 A3 A4]} end
	     [] 5 then proc {$ A1 A2 A3 A4 A5} {CallWith [A1 A2 A3 A4 A5]} end
	     [] 6 then proc {$ A1 A2 A3 A4 A5 A6} {CallWith [A1 A2 A3 A4 A5 A6]} end
	     [] 7 then proc {$ A1 A2 A3 A4 A5 A6 A7} {CallWith [A1 A2 A3 A4 A5 A6 A7]} end
	     [] 8 then proc {$ A1 A2 A3 A4 A5 A6 A7 A8}
			  {CallWith [A1 A2 A3 A4 A5 A6 A7 A8]} end
	     [] 9 then proc {$ A1 A2 A3 A4 A5 A6 A7 A8 A9}
			  {CallWith [A1 A2 A3 A4 A5 A6 A7 A8 A9]} end
	     [] 10 then proc {$ A1 A2 A3 A4 A5 A6 A7 A8 A9 A10}
			   {CallWith [A1 A2 A3 A4 A5 A6 A7 A8 A9 A10]} end
	     [] 11 then proc {$ A1 A2 A3 A4 A5 A6 A7 A8 A9 A10 A11}
			   {CallWith [A1 A2 A3 A4 A5 A6 A7 A8 A9 A10 A11]} end
	     end
	  else F
	  end
       end
      }
   end
end
