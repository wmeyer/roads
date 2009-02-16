%%
%% A dictionary that can be manipulated in subordinate spaces.
%%
functor
export
   New
   Is
   Put
   Get CondGet
   Exchange CondExchange
   Remove RemoveAll
   Member
   Items
   Clone
   ToRecord
define
   fun {NewServer D}
      P
      thread
	 for Req in {NewPort $ P} do
	    case Req of put(LI X)#Sync then
	       {Dictionary.put D LI X}
	       Sync = unit
	    [] get(LI)#Reply then
	       {Dictionary.get D LI Reply}
	    [] condGet(LI Defval)#Reply then
	       {Dictionary.condGet D LI Defval Reply}
	    [] member(LI)#Reply then
	       {Dictionary.member D LI Reply}
	    [] items#Reply then
	       {Dictionary.items D Reply}
	    [] exchange(LI NewVal)#Reply then
	       OldVal in
	       {Dictionary.exchange D LI OldVal NewVal}
	       Reply = OldVal#unit
	    [] condExchange(LI DefVal NewVal)#Reply then
	       OldVal in
	       {Dictionary.condExchange D LI DefVal OldVal NewVal}
	       Reply = OldVal#unit
	    [] remove(LI)#Sync then
	       {Dictionary.remove D LI}
	       Sync = unit
	    [] removeAll#Sync then {Dictionary.removeAll D} Sync = unit
	    end
	 end
      end
   in
      unsituatedDictionary(port:P dict:D)
   end

   fun {New} {NewServer {Dictionary.new}} end

   fun {Is D}
      case D of unsituatedDictionary(port:P dict:D)
	 andthen {Port.is P} andthen {Dictionary.is D} then true
      else false
      end
   end

   proc {Put D LI X}
      {Wait {Port.sendRecv D.port put(LI X)}}
   end

   fun {Get D LI}
      {Port.sendRecv D.port get(LI)}
   end

   fun {CondGet D LI DefVal}
      {Port.sendRecv D.port condGet(LI DefVal)}
   end

   proc {Exchange D LI OldVal NewVal}
      !OldVal#Sync = {Port.sendRecv D.port exchange(LI NewVal)}
   in
      {Wait Sync}
   end

   proc {CondExchange D LI DefVal OldVal NewVal}
      !OldVal#Sync = {Port.sendRecv D.port condExchange(LI DefVal NewVal)}
   in
      {Wait Sync}
   end

   fun {Items D}
      {Port.sendRecv D.port items}
   end
   
   proc {Remove D LI}
      {Wait {Port.sendRecv D.port remove(LI)}}
   end

   proc {RemoveAll D}
      {Wait {Port.sendRecv D.port removeAll}}
   end

   fun {Member D LI}
      {Port.sendRecv D.port member(LI)}
   end

   fun {Clone D}
      {NewServer {Dictionary.clone D.dict}}
   end

   fun {ToRecord L D}
      {Dictionary.toRecord L D.dict}
   end
end
