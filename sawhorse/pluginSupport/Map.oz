functor
import
   NativeMap at 'x-ozlib://wmeyer/sawhorse/pluginSupport/Map.so{native}'
   Finalize
export
   New
   Put
   Get
   CondGet
   Member
   Remove
   RemoveAll
   Items
define
   proc {NativeMapFinalizer M}
      {NativeMap.delete M}
   end

   Guardian = {Finalize.guardian NativeMapFinalizer}
   
   fun {New}
      M = {NativeMap.new}
   in
      {Guardian M}
      M
   end

   proc {Put M LI Val}
      {NativeMap.put M LI Val}
   end

   fun {Get M LI}
      {NativeMap.get M LI}
   end

   proc {Remove M LI}
      {NativeMap.remove M LI}
   end

   proc {RemoveAll M}
      {NativeMap.removeAll M}
   end
   
   fun {CondGet M LI Defval}
      {NativeMap.condGet M LI Defval}
   end

   fun {Member M LI}
      {NativeMap.member M LI}
   end

   fun {Items M}
      {NativeMap.items M}
   end
end
