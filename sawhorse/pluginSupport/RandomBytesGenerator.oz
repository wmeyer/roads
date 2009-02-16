functor
import
   Random at 'x-ozlib://wmeyer/sawhorse/pluginSupport/Random.so{native}'
   Finalize
export
   Create
define
   Guardian = {Finalize.guardian proc {$ G} {Random.close_generator G} end}
   
   fun {Create NumBytes}
      G = {Random.create_generator}
   in
      if G == 0 then raise randomNumberGenerator(couldNotCreate) end end
      {Guardian G}
      fun {$}
	 {Random.generate G NumBytes}
      end
   end
end
