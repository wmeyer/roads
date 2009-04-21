functor
import
   ProcessSingleton
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
define
   Instance = {ProcessSingleton.run 'x-ozlib://wmeyer/roads/Roads.ozf'}
   Reset = Instance.reset
   SetOption = Instance.setOption
   SetSawhorseOption = Instance.setSawhorseOption
   RegisterFunction = Instance.registerFunction
   RegisterFunctor = Instance.registerFunctor
   RegisterApplication = Instance.registerApplication
   Run = Instance.run
   IsRunning = Instance.isRunning
   ShutDown = Instance.shutDown
end
