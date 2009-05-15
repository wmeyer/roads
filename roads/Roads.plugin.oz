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
	   RemoteFunctor at 'x-ozlib://wmeyer/roads/RemoteFunctor.ozf'
	   Remote
	   System
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

	   %% don't make this depend on State
	   fun {CreateRoadsLogger ServerConfig}
	      LogLevel = {CondSelect Config logLevel trace}
	   in
	      {NewLogger init(module:"dispatcher"
			      stream:ServerConfig.logStream
			      logLevel:LogLevel)}
	   end

	   fun {StartAppServer ServerName server(init:Init options:Os)}
	      {Logger.trace "creating appserver: "#ServerName}
	      try
		 RM = {New Remote.manager Init}
		 {Logger.trace "created remote manager"}
		 M = {RemoteFunctor.create 'x-ozlib://wmeyer/roads/AppServer.ozf' RM}
		 {Logger.trace "created appserver successfully"}
	      in
		 server(manager:RM module:M options:Os init:Init)
	      catch E then
		 {Logger.error "could not create appserver:"}
		 {Logger.exception E}
		 nothing
	      end
	   end
	   
	   fun {CreateAppServers}
	      {Record.filter
	       {Record.mapInd {CondSelect Config appServers unit} StartAppServer}
	       fun {$ S} S \= nothing end}
	   end

	   fun {AddAppServers LState OldState}
	      RemoteAppServers = {CreateAppServers}
	      %% always CREATE local server (but depending on options, only use as fallback)
	      [LocalAppServer] = {Module.link ['x-ozlib://wmeyer/roads/AppServer.ozf']}
	      AppServers =
	      if {CondSelect Config useLocalAsAppServer true} then
		 {AdjoinAt RemoteAppServers 'local'
		  server(module:LocalAppServer manager:unit options:unit init:'local')
		 }
	      else
		 RemoteAppServers
	      end
	      proc {Init ServerName AppServer IsLocal}
		 if OldState == unit then
		    {AppServer.initialize
		     Config LState.serverConfig LState.applications ServerName}
		 else
		    {AppServer.reinitialize
		     Config LState.serverConfig LState.applications
		     OldState.appServers.ServerName}
		 end
	      end
	   in
	      {Init 'local' LocalAppServer true}
	      {Record.forAllInd RemoteAppServers
	       proc {$ ASName AS}
		 {Init ASName AS.module false}
	       end
	      }
	      {Adjoin LState
	       unit(localAppServer:LocalAppServer
		    remoteAppServers:{NewCell RemoteAppServers}
		    appServers:{NewCell AppServers}
		   )
	      }
	   end

	   local
	      Counter = {NewCell 0}
	   in
	      fun {GetAppServer ?ServerName}
		 AppServers = @(State.appServers)
		 AppServerNames = {Arity AppServers}
		 New
		 Old = (Counter := New)
		 try
		    New = (Old + 1) mod {Length AppServerNames}
		 catch E then
		    New = Old
		    raise E end
		 end
	      in
		 ServerName = {Nth AppServerNames New+1}
		 AppServers.ServerName
	      end
	   end
	   
	   fun {NewSessionCache}
	      {Session.newCache {CondSelect Config sessionDuration 60*60*1000}}
	   end

	   %% Initialize all configured applications.
	   proc {Initialize ServerConfig}
	      Applications = {Record.map Config.applications
			      fun {$ A} {InitApp ServerConfig A unit} end}
	   in
	      Logger = {CreateRoadsLogger ServerConfig}
	      State = {AddAppServers
		       unit(applications:Applications
			    sessionIdIssuer:{IdIssuer.create 8}
			    sessions:{NewSessionCache}
			    serverConfig:ServerConfig
			   )
		       unit}
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
	      ExpireSessionsOnRestart = {CondSelect Config expireSessionsOnRestart false}
	   in
	      Logger = {CreateRoadsLogger ServerConfig}
	      State = {AddAppServers
		       unit(applications:Applications
			    sessionIdIssuer:OldState.sessionIdIssuer
			    sessions:if ExpireSessionsOnRestart then
					{NewSessionCache}
				     else OldState.sessions end
			    serverConfig:ServerConfig
			   )
		       OldState
		      }
	      {Record.forAll OldState.remoteAppServers
	       proc {$ server(manager:RM ...)}
		  {RM close}
	       end
	      }
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
	      {State.localAppServer.module.shutDown}
	      {Record.forAll State.remoteAppServers
	       proc {$ AS}
		  {AS.moduleshutDown}
		  {AS.manager close}
	       end
	      }
	   end

	   fun {HandleGetRequest Req Inputs}
	      {HandleRequest get Req Inputs}
	   end

	   fun {HandlePostRequest Req Inputs}
	      {HandleRequest post Req Inputs}
	   end

	   fun {HandleRequest Type Req Inputs}
	      {Logger.trace "Roads::HandleRequest"}
	      %% find out which app server to use
	      SessionId
	      AppServerName
	      AppServer
	      SessionIdIsNew
	      case {Session.idFromRequest Req} of nothing then
		 {Logger.trace "New Session."}
		 AppServer = {GetAppServer ?AppServerName}
		 SessionId = {NewSessionId AppServerName}
		 SessionIdIsNew = true
	      [] just(SId) then
		 {Logger.trace "Session from cookie."}
		 case {State.sessions get(SId)} of just(ServerName) then
		    {Logger.trace "existing session"}
		    {System.showInfo "server name: "}
		    {System.show ServerName}
		    Servers = @(State.appServers)
		 in
		    SessionId = SId
		    {Logger.trace SessionId}
		    SessionIdIsNew = false
		    if {HasFeature Servers ServerName} then
		       {Logger.trace "found server for session."}
		       AppServer = Servers.ServerName
		       AppServerName = ServerName
		    else
		       {Logger.trace "Server of session no longer available."}
		       AppServer = {GetAppServer ?AppServerName}
		       {State.sessions set(SessionId AppServerName)}
		    end
		 [] nothing then %% session expired
		    {Logger.trace "Session expired."}
		    {GetAppServer ?AppServerName ?AppServer}
		    SessionId = {NewSessionId AppServerName}
		    SessionIdIsNew = true
		 end
	      end
	      NextSessionIdCandidate = {NewSessionId AppServerName}
	      {Logger.trace "NS3"}
	      SessionIdChanged = {NewCell false}
	   in
	      try
		 {Logger.trace "calling appserver"}
		 TheResponse = 
		 {AppServer.module.handleRequest
		  Type Req Inputs
		  sessionId(id:SessionId isNew:SessionIdIsNew
			    next:NextSessionIdCandidate
			    changed:?SessionIdChanged)}
	      in
		 {Logger.trace "returned from appserver"}
		 if @SessionIdChanged then
		    {State.sessions move(SessionId NextSessionIdCandidate) _}
		 else
		    %% remove NextSessionIdCandidate or just let expire?
		    skip
		 end
		 TheResponse
	      catch RF=remoteFunctor(Reason ...) then
		 {Logger.error "app server failed:"}
		 {Logger.logException RF}
		 if Reason == permFail orelse Reason == timeout then
		    NewSs
		    OldSs = (State.appServers := NewSs)
		 in
		    NewSs = {Record.subtract OldSs AppServerName}
		    %% TODO: maybe restart
		    %% maybe activate local app server as fallback
		 end
		 %% try again with different server
		 {State.sessions set(SessionId {GetAppServer $ _})}
		 {HandleRequest Type Req Inputs}
	      [] E then raise E end
	      end
	   end	   

	   fun {NewSessionId ServerName}
	      NewId = {State.sessionIdIssuer}
	   in
	      if {State.sessions setIfFree(NewId ServerName)} then
		 NewId
	      else
		 {NewSessionId ServerName}
	      end
	   end
	end
       ]}.1
   end
end
