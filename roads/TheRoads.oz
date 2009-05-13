functor
import
   RemoteFunctor at 'x-ozlib://wmeyer/roads/RemoteFunctor.ozf'
   Remote
export
   Reset
   SetOption
   SetSawhorseOption
   RegisterFunction
   RegisterFunctor
   RegisterApplication
   Run
   IsRunning
   ShutDown
   ColdRestart

   Close
define
   RemoteManager = {New Remote.manager init}
   Instance = {RemoteFunctor.create 'x-ozlib://wmeyer/roads/Roads.ozf' RemoteManager}
   {Instance.setSawhorseOption errorLogFile "http-error.log"}
   Reset = Instance.reset
   SetOption = Instance.setOption
   SetSawhorseOption = Instance.setSawhorseOption
   RegisterFunction = Instance.registerFunction
   RegisterFunctor = Instance.registerFunctor
   RegisterApplication = Instance.registerApplication
   Run = Instance.run
   IsRunning = Instance.isRunning
   proc {Close}
      try
	 {ShutDown}
      catch _ then skip end
      {RemoteManager close}
   end
   ShutDown = Instance.shutDown
   ColdRestart = Instance.coldRestart
end
