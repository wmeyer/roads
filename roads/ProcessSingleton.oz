functor
import
   Pickle
   Connection
   OS
   Module
export
   Run
define
   Timeout = 5000
   
   fun {URLToFileName URL}
      {Map {Atom.toString URL}
       fun {$ C}
	  if {Member C " <>:\"/\\|?*"} then &_ else C end
       end
      }
   end
   
   fun {URLToTicketLocation URL}
      {VirtualString.toAtom "./"#{URLToFileName URL}#".ticket"}
   end

   fun {ConnectToDetachedFunctor URL}
      try
	 Ticket = {Pickle.load {URLToTicketLocation URL}}
      in
	 just({Connection.take Ticket})
      catch _ then
	 nothing
      end
   end

   fun {StartDetachedFunctor URL}
      Result
      TmpTicket = {Connection.offerMany Result}
   in
      {OS.exec ozengine ['x-ozlib://wmeyer/roads/RunFunctor.ozf'
			 {VirtualString.toAtom '--functor='#URL}
			 {VirtualString.toAtom '--result='#TmpTicket}
			]
       true _}
      {Pickle.save
       TmpTicket
       {URLToTicketLocation URL}}
      Result
   end

   fun {SendRecv P Msg}
      Events = unit(1:{Port.sendRecv P Msg}
		    2:{Time.alarm Timeout}
		   )
   in
      case {Record.waitOr Events}
      of 1 then Events.1
      else processSingleton(timeout msg:Msg)
      end
   end
   
   fun {CreateClient URL P}
      [Mod] = {Module.link [URL]}
   in
      {Record.mapInd Mod
       fun {$ Ind F}
	  if {IsDet F} andthen {Procedure.is F} then
	     proc {CallWith Args}
		case {SendRecv P Ind#Args} of unit then skip
		[] E then
		   raise E end
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
   
   fun {Run URL}
      Port = 
      case {ConnectToDetachedFunctor URL}
      of just(F) then F
      [] nothing then {StartDetachedFunctor URL}
      end
   in
      {CreateClient URL Port}
   end
end
