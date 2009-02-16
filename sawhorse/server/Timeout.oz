functor
import
   AsyncExcept(raiseTo:RaiseTo safeThread:SafeThread)
export
   WithTimeout
   Either
define
   fun {WithTimeout MilliSeconds What}
      {Either
       What
       fun {$} {Delay MilliSeconds} timeout end
      }
   end

   %% Assumes that no exceptions are thrown at the main thread.
   fun {Either A B}
      KillException = {NewName}
      Result = unit(a:_ b:_)
      fun {Alternative Feat What}
	 proc {$}
	    try
	       Result.Feat = {What}
	    catch !KillException then skip
	    [] E then Result.Feat = {Value.failed E}
	    end
	 end
      end
      Threads = unit(a:{SafeThread unit(run:{Alternative a A})}
		     b:{SafeThread unit(run:{Alternative b B})})
      Other = unit(a:Threads.b b:Threads.a)
      FirstFinished = {Record.waitOr Result}
   in
      {RaiseTo Other.FirstFinished KillException}
      Result.FirstFinished
   end
end
