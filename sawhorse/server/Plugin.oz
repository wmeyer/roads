
functor
import
   Module Resolve
   Path at 'x-oz://system/os/Path.ozf'
   Util(endsWith:EndsWith) at 'x-ozlib://wmeyer/sawhorse/common/Util.ozf'
export
   LoadPlugins
   ShutDownPlugins
   Find
   Call
define
   fun {LoadPlugins Config OldConfig}
      Ps = {LinkPlugins Config.pluginDir}
   in
      {Record.forAllInd Ps
       proc {$ URL Mod}
	  if {HasFeature OldConfig plugins}
	     andthen {HasFeature OldConfig.plugins URL} then
	     {Mod.reinitialize Config.serverName OldConfig.plugins.URL}
	  else
	     {Mod.initialize Config.serverName}
	  end
       end
      }
      Ps
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
   
   fun {Find Config Req}
      for P in {Record.toList Config.plugins} return:R default:nothing do
	 if {P.wantsRequest Req} then {R just(P)} end
      end
   end

   fun {Call Config Plugin Proc Req Inputs}
      {Config.trace "call plugin "#Plugin.name}
      R = {Plugin.Proc Config Req Inputs}
   in
      {Config.trace "call to plugin "#Plugin.name#" finished"}
      R
   end
end
