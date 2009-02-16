functor
import
   Space
   Finalize
export
   NewSpace
   NewSubspace
   DoInSpace
   EvalInSpace
define
   proc {StartSpace Stream}
      _ =
      {Space.new
       proc {$ _}
	  for P in Stream do
	     {P}
	  end
       end
      }
   end

   local
      proc {DestroySpace S}
	 try
	    {DoInSpace S proc {$} fail end}
	 catch _ then skip
	 end
      end
   in
      Register = {Finalize.guardian DestroySpace}
   end
   
   fun {NewSpace}
      Stream P
   in
      {StartSpace Stream}
      P = {Port.new Stream}
      {Register P}
      P
   end
   
   fun {NewSubspace Parent}
      case Parent of unit then {NewSpace}
      else
	 Stream
	 P = {Port.new Stream}
	 {Port.send Parent proc {$} {StartSpace Stream} end}
      in
	 {Register P}
	 P
      end
   end
   
   proc {DoInSpace S Proc}
      case S of unit then thread {Proc} end
      else {Port.send S Proc}
      end
   end

   fun {EvalInSpace S Fun}
      P
   in
      {DoInSpace S proc {$}
		      {Port.send P {Fun}}
		   end
      }
      {NewPort $ P}.1
   end
end
