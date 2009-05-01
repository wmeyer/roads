functor
import
%   NonSituatedDictionary at 'x-ozlib://wmeyer/sawhorse/pluginSupport/NonSituatedDictionary.ozf'
export
   'class':Context   
   NewDict
   CloneDict
   ForAll
define
   ContextDict = Dictionary
   NewDict = ContextDict.new
   CloneDict = ContextDict.clone
   
   proc {ForAll Session Msg}
      for C in {ContextDict.items Session.contexts} do
	 {Port.send C Msg}
      end
   end
   
   fun {Counter Start}
      C = {NewCell Start}
      P
      thread
	 for get#Ret in {Port.new $ P} do
	    Ret = @C
	    C := @C + 1
	 end
      end
   in
      fun {$} {Port.sendRecv P get} end
   end

   local
      P
      thread
	 for get#(Por#Stream) in {Port.new $ P} do
	    {Port.new Stream Por}
	 end
      end
   in
      fun {CreateToplevelPort ?Stream}
	 Por#!Stream = {Port.sendRecv P get}
      in
	 Por
      end
   end

   local P in
      thread
	 for wait(Milli)#Sync in {Port.new $ P} do
	    thread
	       {Delay Milli}
	       Sync = unit
	    end
	 end
      end

      proc {Sleep Milliseconds}
	 {Wait {Port.sendRecv P wait(Milliseconds)}}
      end
   end
   
   %% manipulating sessions
   local C = {Counter 0} in
      class Context
	 feat
	    session
	    id
	    closures
	    port
	 attr
	    closureWasCalled
	 meth init(Session)
	    thread
	       for Msg in {CreateToplevelPort $ self.port} do
		  {self Msg}
	       end
	    end
	    self.session = Session
	    self.id = {C}
	    {Wait self.port}
	    {ContextDict.put Session.contexts self.id self.port}
	    self.closures = {Dictionary.new}
	 end
	 
	 meth newClosure(ClosureId)
	    {Dictionary.put self.closures ClosureId unit}
	 end
	 
	 meth closureCalled(ClosureId)
	    if {Dictionary.member self.closures ClosureId} then 
	       @closureWasCalled = unit
	    end
	 end

	 meth Expire
	    {ContextDict.remove self.session.contexts self.id}
	    for C in {Dictionary.keys self.closures} do
	       {self.session.removeClosure C}
	    end
	 end

	 meth expire
	    {Port.send self.port Expire}
	 end
	 
	 meth expireAfter(Milliseconds)
	    thread
	       {Sleep Milliseconds}
	       {self expire}
	    end
	 end
	 meth expireAfterInactivity(Milliseconds)
	    thread
	       closureWasCalled := _
	       case {Record.waitOr unit(1:{fun {$} thread {Sleep Milliseconds} unit end end}
					2:@closureWasCalled)}
	       of 1 then {self expire}
	       [] 2 then {self expireAfterInactivity(Milliseconds)}
	       end
	    end
	 end
      end
   end
end
