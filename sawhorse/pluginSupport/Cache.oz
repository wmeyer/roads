%%
%% A thread-safe implementation of an LRU-like cache.
%% No upper bound in size.
%% All entries are removed after they have not been requested for a defined time period.
%%
functor
import
   Property(get)
export
   Create
define
   %% Not requested items are discarded after Milliseconds,
   %% at the latest after 2*Milliseconds.
   %% Returns a condGet function.
   %% Clear: procedure to clear the cache
   fun {Create Milliseconds Finalizer}
      SharedPort
      Nothing = {NewName}
      thread
	 Cache = {NewCell {NewDictionary}}
	 MinimizerThread = {NewCell unit}
      in
	 for Request#Result in {NewPort $ SharedPort} do
	    try {Thread.terminate @MinimizerThread} catch _ then skip end
	    case Request of condGet(Key DefVal) then
	       Result = {Dictionary.condGet @Cache Key DefVal#unit}.1
	       (@Cache).Key := Result#{Now}
	    [] condGetUncached(Key DefVal) then
	       case {Dictionary.condGet @Cache Key Nothing#unit}.1
	       of !Nothing then Result = DefVal
	       [] X then
		  Result = X
		  (@Cache).Key := Result#{Now}
	       end
	    [] clear then
	       Cache := {NewDictionary}
	       Result = unit
	    [] getSize then
	       Result := {Length {Dictionary.items @Cache}}
	    end
	    MinimizerThread := {StartMinimizer Cache Milliseconds Finalizer}
	 end
      end
   in
      fun {$ Cmd}
	 Res = {Port.sendRecv SharedPort Cmd}
      in
	 {Wait Res}
	 Res
      end
   end

   proc {StartMinimizer Cache Milliseconds Finalizer TId}
      proc {Minimizer}
	 local
	    N = {Now}
	    OldEntries
	    RemainingEntries
	    {List.partition {Dictionary.entries @Cache}
	     fun {$ _#(_#TS)} N - TS < Milliseconds end
	     RemainingEntries OldEntries
	    }
	 in
	    Cache := {ListToDictionary RemainingEntries}
	    {ForAll OldEntries proc {$ _#(O#_)} {Finalizer O} end}
	 end
	 %% the time specified here is also the maximum time that an object can stay
	 %% in the cash for too long
	 {Delay Milliseconds}
	 {Minimizer}
      end
   in
      thread
	 TId = {Thread.this}
	 {Minimizer}
      end
   end

   fun {Now} {Property.get 'time.total'} end

   fun {ListToDictionary Xs}
      D = {NewDictionary}
   in
      {ForAll Xs proc {$ K#V} D.K := V end}
      D
   end
end
