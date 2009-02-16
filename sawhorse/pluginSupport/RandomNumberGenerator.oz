functor
import
   RandomBytesGenerator
   at 'x-ozlib://wmeyer/sawhorse/pluginSupport/RandomBytesGenerator.ozf'
export
   Create
define
   fun {Create NumBytes}
      G = {RandomBytesGenerator.create NumBytes}
   in
      fun {$}
	 {FoldL {G}
	  fun {$ Z R}
	     Z * 256 + R
	  end
	  0
	 }
	 -0x80000000
      end
   end
end
