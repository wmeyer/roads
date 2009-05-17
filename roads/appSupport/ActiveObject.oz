%%
%% Creates a special kind of active object which can be used in subordinate spaces
%% (and thereby in Roads functions).
%%
%% The objects must follow a protocol:
%%  - a method can have at most one result parameter
%%  - the result parameter must be labelled "result"
%%  - all other parameters must be bound when calling a method
%%
%% Example:
%%  - {Object methodA(1 atom other:nil result:$)}: okay
%%  - {Object methodB(42 result:nil)}: okay, although unusual
%%  - {Object methodC(31): okay; result is optional
%%  - {Object methodD(result:_): okay
%%  - {Object methodE(_): NOT okay; unbound, non-result param
%%
functor
export
   new:NewActive
   NewInterface
define
   fun {NewInterface TheObject}
      Channel
      thread
	 for Msg0 in {Port.new $ Channel} do
	    {TheObject {UnmarshalMessage Msg0}}
	 end
      end
   in
      proc {$ Msg0}
	 ReturnValue
	 Msg = {MarshalMessage Msg0 ?ReturnValue}
      in
	 {Port.sendRecv Channel Msg ?ReturnValue}
      end
   end
   
   fun {NewActive Class Init}
      {NewInterface {New Class Init}}
   end
   
   fun {MarshalMessage Msg ?ReturnValue}
      ReturnValue = {CondSelect Msg result _}
      {Needed
       if {HasFeature Msg result} then {AdjoinAt Msg result unit} else Msg end
      }
   end

   fun {UnmarshalMessage Msg#ReturnValue}
      if {HasFeature Msg result} then
	 {AdjoinAt Msg result ReturnValue}
      else
	 Msg
      end
   end

   fun {Needed X}
      {MakeNeeded X}
      X
   end

   proc {MakeNeeded X}
      {Wait X}
      if {Record.is X} then
	 {Record.forAll X MakeNeeded}
      end
   end
end
