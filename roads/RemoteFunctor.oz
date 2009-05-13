functor
import
   Property
   Module
export
   Create
define
   %% Create an "active functor" whose procedures will be executed at RemoteManager.
   %% Procedure calls are synchronous and may not have more than 11 arguments.
   %% Will throw at creation if the module could not be linked.
   %% Exceptions from application code are forwarded to the local machine.
   %% Customizable timeout: property 'remoteFunctor.timeout'
   %%
   %% URL: where the functor is installed both locally(!!) and at the remote site
   %% RemoteManager: properly initialized Remote.manager
   %% Return: a record that behaves like an applied functor.
   fun {Create URL RemoteManager}
      Prt
      Res = {CreateClient URL Prt RemoteManager} %% create local client first (fail cheaply)
   in
      Prt = {StartRemoteFunctor RemoteManager URL}
      if {Value.isFailed Prt} then raise Prt end end
      Res
   end

   %% returns a distributed port
   fun {StartRemoteFunctor RemoteManager URL}
      functor F
      import
	 Module
      export
	 Prt
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

	 Functr Prt
	 
	 try
	    [Functr] = {Module.link [URL]}
	    {Record.forAll Functr Value.makeNeeded}
	    Prt = {CreateServer Functr}
	 catch _ then
	    Prt = {Value.failed remoteFunctor(cannotLinkFunctorAtRemoteSite manager:RemoteManager url:URL)}
	 end
      end
   in
      {RemoteManager apply(F $)}.prt
   end

   %% like Port.sendRecv but with timeout
   fun {SendRecv P Msg}
      Events = unit(1:{Port.sendRecv P Msg}
		    2:{Time.alarm {Property.condGet 'remoteFunctor.timeout' 2000}}
		   )
   in
      case {Record.waitOr Events}
      of 1 then Events.1
      else remoteFunctor(timeout msg:Msg)
      end
   end
   
   fun {CreateClient URL P RM}
      [Mod] = {Module.link [URL]}
   in
      {Record.mapInd Mod
       fun {$ Ind F}
	  if {IsDet F} andthen {Procedure.is F} then
	     proc {CallWith Args}
		case {SendRecv P Ind#Args} of unit then skip
		[] E then
		   raise remoteFunctor(applicationException:E manager:RM url:URL) end
		end
	     end
	  in			  
	     case {Procedure.arity F}
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
