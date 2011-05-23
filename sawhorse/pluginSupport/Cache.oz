%%
%% A thread-safe implementation of an LRU-like cache.
%% No upper bound in size.
%% All entries are removed after they have not been requested for a defined time period.
%%
functor
import
   Property(get)
   Queue at 'x-oz://system/adt/Queue.ozf'
export
   Create
define

   fun {Create Milliseconds Finalizer}
      SharedPort
      Nothing = {NewName}
      thread
	 Cache = {NewDictionary}
	 Keys = {Queue.new} %% redundant collection to have fast access to a sequence of keys that is "mostly ordered" by time
	 SyncMinimizer = {NewCell unit}
      in
	 for Request#Result in {NewPort $ SharedPort} do
	    T = {Now}
	    Sync
	 in
	    {SyncTwoWay @SyncMinimizer}
	    case Request of condGet(Key DefVal) then
	       Old
	    in
	       Result#Old = {Dictionary.condGet Cache Key DefVal#unit}
	       Cache.Key := Result#T
	       if Old==unit then {Keys.put Key#T} end
	    [] condGetUncached(Key DefVal) then
	       case {Dictionary.condGet Cache Key Nothing#unit}.1
	       of !Nothing then Result = DefVal
	       [] X then
		  Result = X
		  Cache.Key := Result#T
	       end
	    [] clear then
	       {Dictionary.removeAll Cache}
	       {Keys.reset}
	       Result = unit
	    [] getSize then
	       Result = {Length {Dictionary.items Cache}}
	    [] move(Key NewKey) then
	       Val = {Dictionary.get Cache Key}.1
	    in
	       {Dictionary.remove Cache Key}
	       Cache.NewKey := Val#T
	       {Keys.put NewKey#T} %% cannot directly remove old key from somewhere in queue (will be removed when cleaning)
	       Result = unit
	    end
	    %% remove old entries
	    {Minimize Cache Keys Milliseconds Finalizer}
	    %% remove old entries again after a while if there has been no new request
	    Sync = {CreateTwoWaySync}
	    SyncMinimizer := Sync
	    thread
	       for break:Break do
		  {Value.waitOr Sync.1 {Alarm Milliseconds}}
		  if {IsSynced Sync} then
		     {Ack Sync}
		     {Break}
		  else
		     {Minimize Cache Keys Milliseconds Finalizer}
		  end
	       end
	    end
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

   proc {Minimize Cache Keys Milliseconds Finalizer}
      T = {Now}
   in
      for while:{Not {Keys.isEmpty}} andthen T - {Keys.top}.2 > Milliseconds do
	 K#_ = {Keys.get}
      in
	 case {Dictionary.condGet Cache K unit}
	 of unit then skip %% must have been moved
	 [] Val#CreationTime then
	    %% if it really has expired, remove
	    if T - CreationTime > Milliseconds then
	       {Dictionary.remove Cache K}
	       {Finalizer Val}
	    else
	       %% otherwise, it has been accessed recently. Put back into queue.
	       {Keys.put K#CreationTime}
	    end
	 end
      end
   end

   fun {Now} {Property.get 'time.total'} end

   fun {CreateTwoWaySync}
      _#_
   end
   
   proc {SyncTwoWay Sy}
      case Sy of unit then skip
      [] S#A then
	 S=unit
	 {Wait A}
      end
   end
   
   fun {IsSynced S#_}
      {IsDet S}
   end
   
   proc {Ack _#A}
      A = unit
   end
end
