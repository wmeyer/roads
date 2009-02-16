functor
export
   SafeThread
   Blocked
   Unblocked
   RaiseTo
define
   proc {Nothing} skip end
   
   %% Create a thread that can safely receive asynchonous exceptions.
   fun {SafeThread Ps=unit(run:What ...)}
      Finally = {CondSelect Ps 'finally' Nothing}
      Blocked = {CondSelect Ps blocked false}
      T
   in
      thread
	 try
	    T = {Thread.this}
	    {What}
	 finally
	    {Finally}
	 end
      end
      'thread'(handle:T 'lock':{NewLock} flag:{NewCell if Blocked then _ else unit end})
   end

   %% Execute some code with blocked asynchronous exceptions.
   proc {Blocked 'thread'('lock':L flag:F ...) What}
      lock L then
	 %% Now we are sure that we are not about to get killed
	 F := _
	 %% As long as @F is unbound, we cannot get killed
      end
      try
	 {What}
      finally
	 (@F) = unit %% this might not be the same variable as we assigned
	 %% but in this case we can be sure that Kill is not waiting on the old one
	 %% (because of the design of Unblocked)
      end
   end
   
   %% Inject an exception into another thread.
   %% Blocks if asynchronous exceptions are blocked for that thread.
   proc {RaiseTo 'thread'(handle:T 'lock':L flag:F) E}
      %% Wait until unblocked and Make sure that we won't get blocked until T's death
      lock L then
	 {Wait @F}
	 try
	    {Thread.injectException T E}
	 catch _ then skip end
      end
   end
   
   proc {Unblocked 'thread'('lock':L flag:F ...) What}
      WasBlocked = {IsFree @F}
   in
      (@F)=unit
      %% now we can be killed
      try
	 {What}
      %% if Kill was called before Unblocked, we are killed at the latest here
      finally
	 lock L then %% we are NOT about to get killed, so nobody can be waiting on the old @F
	    if WasBlocked then F:=_ end
	 end
      end
   end
end
