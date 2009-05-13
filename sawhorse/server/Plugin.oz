
functor
import
   Module Resolve
   Path at 'x-oz://system/os/Path.ozf'
   Util(endsWith:EndsWith) at 'x-ozlib://wmeyer/sawhorse/common/Util.ozf'
export
   LoadPlugins
   InitializePlugins
   ShutDownPlugins
   Call
define
   fun {LoadPlugins Config}
      {LinkPlugins Config.pluginDir}
   end

   proc {InitializePlugins Config OldConfig}
      {Record.forAllInd Config.plugins
       proc {$ URL Mod}
	  if {HasFeature OldConfig plugins}
	     andthen {HasFeature OldConfig.plugins URL} then
	     {Mod.reinitialize Config OldConfig.plugins.URL}
	  else
	     {Mod.initialize Config}
	  end
       end
      }
   end

   fun {LinkPlugins PluginDir}
      Dir = {Path.make {Resolve.localize PluginDir}.1}
   in
      if {Not {Path.exists Dir}} orelse {Not {Path.isDir Dir}} then
	 raise plugin(pluginDirNotFound(PluginDir)) end
      end
      {List.toRecord plugins
       {Map {Filter {Path.readdir Dir} IsPlugin}
	fun {$ P}
	   URL = {Path.toAtom P}
	   [Mod] = {Module.link [URL]}
	in
	   %% make plugin module needed to make it easier to diagnose errors
	   {Wait Mod}
	   URL#Mod
	end
       }
      }
   end

   fun {IsPlugin P}
      {Path.extension P} == "ozf" andthen
      {EndsWith {Path.toString {Path.dropExtension P}} ".plugin"}
   end

   proc {ShutDownPlugins Config}
      {Record.forAll Config.plugins
       proc {$ P} {P.shutDown} end}
   end
   
   fun {Call Config Proc Req Inputs}
      for P in {Record.toList Config.plugins} return:R default:nothing do
	 {Config.trace "call plugin "#P.name}
	 case {P.Proc Req Inputs} of just(Response) then
	    {Config.trace "got response from "#P.name}
	    {R just(Response)}
	 [] nothing then
	    {Config.trace "no response from "#P.name}
	 end
      end
   end
end
