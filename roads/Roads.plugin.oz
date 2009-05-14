functor
import
   Module
export
   Create
define
   DefaultCacheDuration = 2*60*1000
   
   fun {Create Config}
      {Module.apply
       [functor
	import
	   IdIssuer(create) at 'x-ozlib://wmeyer/sawhorse/pluginSupport/IdIssuer.ozf'
	   Logging(newLogger:NewLogger) at 'x-ozlib://wmeyer/sawhorse/common/Logging.ozf'
	   Session at 'x-ozlib://wmeyer/roads/Session.ozf'
	export
	   %% Plugin interface
	   name:RoadsName
	   Initialize
	   Reinitialize
	   ShutDown
	   HandleGetRequest
	   HandlePostRequest

	   %% internal
	   State
	define
	   State
	   RoadsName = "Roads 0.2"
	   Logger
	   
	   fun {CreateRoadsLogger ServerConfig}
	      LogLevel = {CondSelect Config logLevel trace}
	   in
	      {NewLogger init(module:"dispatcher"
			      stream:ServerConfig.logStream
			      logLevel:LogLevel)}
	   end
	   
	   %% Initialize all configured applications.
	   proc {Initialize ServerConfig}
	      Applications = {Record.map Config.applications
			      fun {$ A} {InitApp ServerConfig A unit} end}
	      [LocalAppServer] = {Module.link ['x-ozlib://wmeyer/roads/AppServer.ozf']}
	   in
	      {LocalAppServer.initialize Config ServerConfig Applications true}
	      State = unit(applications:Applications
			   localAppServer:LocalAppServer
			   sessionIdIssuer:{IdIssuer.create 8}
			   sessions:{Dictionary.new}
			  )
	      Logger = {CreateRoadsLogger ServerConfig}
	   end
	   
	   
	   %% Re-initialize existing applications; initialize new applications.
	   proc {Reinitialize ServerConfig OldInstance}
	      OldState = OldInstance.state
	      Applications =
	      {Record.mapInd Config.applications
	       fun {$ Path Functor}
		  if {HasFeature OldState.applications Path} then
		     OldApp = OldState.applications.Path
		  in
		     {InitApp ServerConfig Functor OldApp.resources}
		  else
		     {InitApp ServerConfig Functor unit}
		  end
	       end
	      }
	      [LocalAppServer] = {Module.link ['x-ozlib://wmeyer/roads/AppServer.ozf']}
	   in
	      {LocalAppServer.reinitialize Config ServerConfig Applications OldState.localAppServer}
	      State = unit(applications:Applications
			   localAppServer:LocalAppServer
			   sessionIdIssuer:OldState.sessionIdIssuer
			   sessions:OldState.sessions
			  )
	      Logger = {CreateRoadsLogger ServerConfig}
	   end

	   fun {Link Functr}
	      if {IsChunk Functr} then {Module.apply [Functr]}.1
	      elseif {VirtualString.is Functr} then {Module.link [Functr]}.1
	      elseif {Functor.is Functr} then Functr
	      elseif {Record.is Functr} then Functr
	      else raise roads(unknownTypeAsFunctor(Functr)) end
	      end
	   end

	   %% Re-initialize an app from its previous state.
	   fun {InitApp ServerConfig Functor OldResources}
	      AppModule = {Link Functor}
	      Resources = if OldResources == unit orelse {Not {HasFeature AppModule onRestart}} then
			     if {HasFeature AppModule init} then {AppModule.init}
			     else session end
			  else
			     {AppModule.onRestart OldResources}
			  end
	      Functors = {Record.map AppModule.functors Link}
	   in
	      application(module:AppModule
			  resources:Resources
			  functors:Functors
			  before:{CondSelect AppModule before fun {$ _ X} X end}
			  after:{CondSelect AppModule after fun {$ _ X} X end}
			  forkedFunctions:{CondSelect AppModule forkedFunctions true}
			  pagesExpireAfter:{CondSelect AppModule pagesExpireAfter 0}
			  useTokenInLinks:{CondSelect AppModule useTokenInLinks true}
			  charset:{CondSelect AppModule charset "ISO-8859-1"}
			  mimeType:{CondSelect AppModule mimeType mimeType(text html)}
			  fragmentCacheDuration:{CondSelect AppModule fragmentCacheDuration
						 {CondSelect Config fragmentCacheDuration
						  DefaultCacheDuration}}
			 )
	   end

	   %% Shutdown all apps and the plugin.
	   proc {ShutDown}
	      {Record.forAll State.applications
	       proc {$ application(module:AppMod resources:R ...)}
		  if {HasFeature AppMod shutDown} then {AppMod.shutDown R} end
	       end
	      }
	      {State.localAppServer.shutDown}
	   end

	   fun {HandleGetRequest Req Inputs}
	      {HandleRequest get Req Inputs}
	   end

	   fun {HandlePostRequest Req Inputs}
	      {HandleRequest post Req Inputs}
	   end

	   fun {HandleRequest Type Req Inputs}
	      {Logger.trace "Roads::HandleRequest"}
	      SessionId =
	      case {Session.idFromRequest Req} of nothing then {NewSessionId}
	      [] just(S) then S
	      end
	      NextSessionIdCandidate = {NewSessionId}
	      SessionIdChanged = {NewCell false}
	   in
	      %% TODO find AppServer for id
	      {State.localAppServer.handleRequest
	       Type Req Inputs SessionId NextSessionIdCandidate ?SessionIdChanged}
	      %% TODO: failover
	      %% update id registry with NewSessionId
	      %% TODO: expired session from appserver
	   end	   

	   fun {NewSessionId}
	      NewId = {State.sessionIdIssuer}
	   in
	      %% thread-safe access to State.sessions
	      if {Dictionary.condExchange State.sessions NewId free $ unit} == free then NewId
	      else {NewSessionId}
	      end
	   end
	end
       ]}.1
   end
end
