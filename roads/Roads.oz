functor
import
   Server at 'x-ozlib://wmeyer/sawhorse/server/Server.ozf'
   Plugin at 'x-ozlib://wmeyer/roads/Roads.plugin.ozf'
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
   SawhorseConfig = {NewCell config}
   RoadsConfig = {NewCell config}
   Applications = {NewCell unit}

   ServerInstance = {NewCell unit}

   L = {NewLock}
   
   proc {Reset}
      lock L then
	 SawhorseConfig := config
	 RoadsConfig := config
	 Applications := unit
      end
   end

   proc {SetOption Option Value}
      lock L then
	 RoadsConfig := {AdjoinAt @RoadsConfig Option Value}
      end
   end
   
   proc {SetSawhorseOption Option Value}
      lock L then
	 SawhorseConfig := {AdjoinAt @SawhorseConfig Option Value}
      end
   end
   
   proc {RegisterFunction Path Fun}
      lock L then
	 App = {CondSelect @Applications '' unit(functors:unit)}
	 Functor = {AdjoinAt {CondSelect App.functors '' unit} Path Fun}
	 ExtendedFunctors = {AdjoinAt App.functors '' Functor}
	 ExtendedApp = {AdjoinAt App functors ExtendedFunctors}
      in
	 Applications := {AdjoinAt @Applications '' ExtendedApp}
      end
   end

   proc {RegisterFunctor Path Fun}
      lock L then
	 App = {CondSelect @Applications '' unit(functors:unit)}
	 ExtendedFunctors = {AdjoinAt App.functors Path Fun}
	 ExtendedApp = {AdjoinAt App functors ExtendedFunctors}
      in
	 Applications := {AdjoinAt @Applications '' ExtendedApp}
      end
   end

   proc {RegisterApplication Path App}
      lock L then
	 Applications := {AdjoinAt @Applications Path App}
      end
   end

   fun {IsRunning}
      @ServerInstance \= unit
   end
   
   proc {Run}
      lock L then
	 RoadsConf = {AdjoinAt @RoadsConfig applications @Applications}
	 RoadsPlugin = {Plugin.create RoadsConf}
	 Config = {AdjoinAt @SawhorseConfig plugins unit(roadsAtHoc:RoadsPlugin)}
      in
	 if {Not {IsRunning}} then
	    ServerInstance := {Server.start Config}
	 else
	    {Server.restart @ServerInstance Config}
	 end
      end
   end

   proc {ShutDown}
      lock L then
	 if {IsRunning} then
	    {Server.kill @ServerInstance}
	    ServerInstance := unit
	 else
	    raise roads(shutDown(notStarted)) end
	 end
      end
   end
end
