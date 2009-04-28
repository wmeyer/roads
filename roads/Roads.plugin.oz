functor
import
   Module
export
   Create
define
   fun {Create Config}
      {Module.apply
       [functor
	import
	   Module OS
	   OsTime
	   Cookie(setCookie) at 'x-ozlib://wmeyer/sawhorse/pluginSupport/Cookie.ozf'
	   IdIssuer(create) at 'x-ozlib://wmeyer/sawhorse/pluginSupport/IdIssuer.ozf'
	   Session at 'x-ozlib://wmeyer/roads/Session.ozf'
	   Context(forAll) at 'x-ozlib://wmeyer/roads/Context.ozf'
	   Routing at 'x-ozlib://wmeyer/roads/Routing.ozf'
	   Speculative at 'x-ozlib://wmeyer/roads/Speculative.ozf'
	   Html(render mapAttributes removeAttribute)
	   at 'x-ozlib://wmeyer/sawhorse/common/Html.ozf'
	   Response(okResponse:OkResponse
		    contentTypeHeader:ContentTypeHeader
		    expiresHeader:ExpiresHeader
		    redirectResponse:RedirectResponse
		    notFoundResponse:NotFoundResponse
		   ) at 'x-ozlib://wmeyer/sawhorse/common/Response.ozf'
	   Util(intercalate:Intercalate
		removeTrailingSlash
		tupleAdd:TupleAdd
		formatTime:FormatTime
	       ) at 'x-ozlib://wmeyer/sawhorse/common/Util.ozf'
	   Query at 'x-ozlib://wmeyer/sawhorse/server/Query.ozf'
	   Logging(newLogger:NewLogger) at 'x-ozlib://wmeyer/sawhorse/server/Logging.ozf'
	   Base62(is 'from' to) at 'x-ozlib://wmeyer/roads/Base62.ozf'
	   FormValidator('class') at 'x-ozlib://wmeyer/roads/FormValidator.ozf'
	export
	   %% Plugin interface
	   name:RoadsName
	   Initialize
	   Reinitialize
	   ShutDown
	   WantsRequest
	   HandleGetRequest
	   HandlePostRequest
   
	   %% internal
	   State
	define
	   State
	   Logger
	   
	   RoadsName = "Roads 0.2"
	   
	   SecretGenerator = {IdIssuer.create 4}

	   fun {CreateRoadsLogger ServerConfig}
	      LogLevel = {CondSelect Config logLevel trace}
	   in
	      {NewLogger init(module:"roads"
			      stream:ServerConfig.logStream
			      logLevel:LogLevel)}
	   end
	   
	   %% Initialize all configured applications.
	   proc {Initialize ServerConfig}
	      State = unit(applications:{Record.map Config.applications
					 fun {$ A} {InitApp ServerConfig A unit} end}
			   sessions:{Session.newCache Config}
			   sessionIdIssuer:{IdIssuer.create 8}
			   closureIdIssuer:{IdIssuer.create 4}
			   serverName:ServerConfig.serverName
			   serverConfig:ServerConfig

			  )
	      Logger = {CreateRoadsLogger ServerConfig}
	   end

	   %% Re-initialize existing applications; initialize new applications.
	   proc {Reinitialize ServerConfig OldInstance}
	      OldState = OldInstance.state
	      Apps = {Record.mapInd Config.applications
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
	      State = unit(applications:Apps
			   sessions:if ExpireSessionsOnRestart then
				       {Session.newCache Config}
				    else OldState.sessions end
			   sessionIdIssuer:OldState.sessionIdIssuer
			   closureIdIssuer:OldState.closureIdIssuer
			   serverName:ServerConfig.serverName
			   serverConfig:ServerConfig
			  )
	      Logger = {CreateRoadsLogger ServerConfig}
	   end

	   fun {Link Functor}
	      if {IsChunk Functor} then {Module.apply [Functor]}.1
	      elseif {VirtualString.is Functor} then {Module.link [Functor]}.1
	      else Functor
	      end
	   end
	   
	   %% Re-initialize an app from its previous state.
	   fun {InitApp ServerConfig Functor OldResources}
	      AppModule = {Link Functor}
	      AppName = {CondSelect AppModule appName app}
	      LogLevel = {CondSelect AppModule logLevel trace}
	      AppLogger = {NewLogger init(module:AppName
					  stream:ServerConfig.logStream
					  logLevel:LogLevel)}
	      Resources = if OldResources == unit then
			     if {HasFeature AppModule init} then {AppModule.init}
			     else session end
			  elseif {HasFeature AppModule onRestart} then
			     {AppModule.onRestart OldResources}
			  else OldResources
			  end
	      
	   in
	      application(module:AppModule
			  resources:Resources
			  functors:{Record.map AppModule.functors Link}
			  before:{CondSelect AppModule before fun {$ _ X} X end}
			  after:{CondSelect AppModule after fun {$ _ X} X end}
			  forkedFunctions:{CondSelect AppModule forkedFunctions true}
			  pagesExpireAfter:{CondSelect AppModule pagesExpireAfter 60*60}
			  logger:AppLogger
			 )
	   end

	   %% Shutdown all apps and the plugin.
	   proc {ShutDown}
	      {Record.forAll State.applications
	       proc {$ application(module:AppMod resources:R ...)}
		  if {HasFeature AppMod shutDown} then {AppMod.shutDown R} end
	       end
	      }
	   end

	   %% Check whether we want to process the given request: check whether
	   %% there is a function for the given path.
	   fun {WantsRequest Req=request(uri:URI ...)}
	      case {Routing.getFunction {StateFromRequest Req} URI.path}
	      of nothing then false
	      [] just(_) then true
	      end
	   end

	   fun {HandleGetRequest ServerConfig Req Inputs}
	      {HandleRequest ServerConfig get Req Inputs}
	   end

	   fun {HandlePostRequest ServerConfig Req Inputs}
	      {HandleRequest ServerConfig post Req Inputs}
	   end

	   %% The central function
	   fun {HandleRequest ServerConfig Type Req=request(uri:URI ...) Inputs}
	      {Logger.trace "Roads::HandleRequest"}
	      Path = URI.path
	      %% get session from cookie or create a new one
	      IsNewSession
	      SessionIdChanged
	      RSession = case {Session.fromRequest State Req} of just(S) then
			    IsNewSession = false
			    S
			 else
			    SessionId = {Session.newId State}
			 in
			    {Logger.trace newSession}
			    IsNewSession = true
			    {State.sessions condGet(SessionId
						    {Session.new State Path
						     SessionId})}
			 end
	      %% find out which function to call (if no closure is given)
	      %% (here we use request-dependent global state to use the old configuration
	      %%  for old sessions)
	      PathComponents
	      App Functr Function MaybeClosureId
	      {Routing.analyzePath {StateFromRequest Req} Path
	       ?PathComponents ?App ?Functr ?Function ?MaybeClosureId}
	      = true
	      BasePath = PathComponents.basePath
	      TheResponse =
	      case MaybeClosureId of nothing then
		 %% WITHOUT CLOSURE
		 if Type == get then
		    {Logger.trace "Roads::HandleRequest, get"}
		    %% GET REQUEST: execute function
		    {ExecuteGetRequest
		     unit(serverConfig:ServerConfig
			  app:App
			  functr:Functr
			  function:Function
			  session:RSession
			  req:Req
			  inputs:Inputs
			  pathComponents:PathComponents
			  closureId:~1
			  closureSpace:unit
			  sessionIdChanged:SessionIdChanged
			 )}
		 elseif Type == post then
		    %% POST REQUEST
		    %% redirect to a get request to a newly created closure
		    %% (Post/Redirect/Get pattern)
		    NewClosureId = {Session.newClosureId State RSession}
		 in
		    {Logger.trace "Roads::HandleRequest, post"}
		    {Session.addClosure
		     unit(closureId:NewClosureId
			  space:unit
			  fork:false
			  app:App
			  functr:Functr
			  session:{Session.prepareFutureSession RSession Inputs}
			  function:Function)
		    }
		    {RedirectResponse ServerConfig 303
		     {PathToClosure BasePath NewClosureId}}
		 end
	      [] just(ClosureIdS) then
		 %% WITH CLOSURE (candidate)
		 if {Not {Base62.is ClosureIdS}} then
		    {NotFoundResponse ServerConfig}
		 else
		    ClosureId = {Base62.'from' ClosureIdS}
		 in
		    {Logger.trace "Roads::HandleRequest, got closure"}
		    case {Session.getClosure RSession ClosureId}
		    of nothing then %% expired closure
		       NewPath = {RemoveClosureId Req.originalURI}
		    in
		       {Logger.trace
			"Roads::HandleRequest, closure expired; redirecting to "#NewPath}
		       %% redirect to same url without closure
		       %% It is up to the single function to decide if it works
		       %% without previous state
		       {RedirectResponse ServerConfig 303 NewPath}
		    [] just(Closure) then
		       if Type == get then
			  {Logger.trace "Roads::HandleRequest, get2"}
			  %% GET REQUEST: execute function, possibly in cloned space.
			  {ExecuteGetRequest
			   unit(serverConfig:ServerConfig
				app:Closure.app
				functr:Closure.functr
				function:Closure.function
				session:Closure.session
				req:Req
				inputs:Inputs
				pathComponents:PathComponents
				closureId:ClosureId
				closureSpace:if Closure.fork then
						{Speculative.newSubspace Closure.space}
					     else
						Closure.space
					     end
				sessionIdChanged:SessionIdChanged
			       )}
		       elseif Type == post then
			  %% POST REQUEST (redirect to get request of closure
			  %% with bound params)
			  NewClosureId = {Session.newClosureId State RSession}
			  
		       in
			  {Logger.trace "Roads::HandleRequest, post2"}
			  {Session.addClosure
			   unit(closureId:NewClosureId
				space:Closure.space
				fork:Closure.fork
				app:App
				functr:Functr
				session:{Session.prepareFutureSession
					 Closure.session Inputs}
				function:Closure.function)
			  }
			  {RedirectResponse ServerConfig 303
			   {PathToClosure BasePath NewClosureId}}
		       end
		    end
		 end
	      end
	   in
	      if IsNewSession orelse {IsDet SessionIdChanged} andthen SessionIdChanged then
		 {AddSessionCookie TheResponse RSession PathComponents}
	      else
		 TheResponse
	      end
	   end

	   %% Req -> State
	   %% (if a request belongs to a phased-out application, it gets the old state).
	   fun {StateFromRequest Req}
	      case {Session.fromRequest State Req} of nothing then State
		 %% no session: global state
	      [] just(S) then S.state
	      end
	   end

	   %% Apply one of the configured postprocess handlers to the html doc.
	   fun {CallAfter Sess App Functr HtmlDoc}
	      PostProcessor = {CondSelect Functr after App.after}
	   in
	      {PostProcessor Sess.interface HtmlDoc}
	   end
   
	   fun {CallBefore Sess App Functr Fun}
	      PreProcessor = {CondSelect Functr before App.before}
	   in
	      {PreProcessor Sess.interface Fun}
	   end
   
	   fun {AddSessionCookie Resp CSession PathComponents}
	      {Cookie.setCookie Resp
	       cookie(name:Session.sessionCookie
		      value:{Int.toString @(CSession.id)}
		      'Path':{Routing.buildPath [PathComponents.app]}
		      'HTTPOnly':unit
		     )
	      }
	   end

	   %% so that we can send an exception from a subordinate space
	   fun {MakeStateless E Visited}
	      if {IsFree E} then freeVar
	      else
		 if {Member E Visited} then cycleDetected
		 else
		    Visited2 = E|Visited
		 in
		    if {Procedure.is E} then procedure(arity:{Procedure.arity E})
		    elseif {Cell.is E} then cell({MakeStateless @E Visited2})
		    elseif {Atom.is E} orelse {Name.is E} orelse {Number.is E} then E
		    elseif {Record.is E} then
		       {Record.map E fun {$ X} {MakeStateless X Visited2} end}
		    else unknownEntity
		    end
		 end
	      end
	   end
	   
	   fun {ExecuteGetRequest
		unit(serverConfig:ServerConfig

		     app:App
		     functr:Functr
		     function:Function
	     
		     session:CSession
		     req:Req
		     inputs:Inputs
		     closureId:ClosureId
		     closureSpace:ClosureSpace
		     pathComponents:PathComponents

		     sessionIdChanged:SessionIdChanged
		    )}
	      Res
	      CookiesToSend
	      TheResponse
	   in
	      {Context.forAll CSession closureCalled(ClosureId)}
	      Res#
	      SessionIdChanged#
	      CookiesToSend
	      =
	      {Speculative.evalInSpace ClosureSpace
	       fun {$}
		  %% Session must be prepared in the space
		  %% to make the private dict local
		  PSession = {Session.'prepare' State App.logger CSession Req Inputs}
		  RealFun = {NewCell {CallBefore PSession App Functr Function}}
		  FunResult
	       in
		  try
		     FunResult =
 		     %% Execute application function;
		     %% repeat until validation either succeeds or
		     %% fails with a non-procedure result
		     for return:R do
			try
			   {R {@RealFun PSession.interface}}
			catch validationFailed(X) andthen {Procedure.is X} then
			   RealFun := X
			[] validationFailed(X) then {R X} %% return error message
			end
		     end
		     %% If result is a html doc, preprocess and render it;
		     %% otherwise pass through
		     case FunResult of redirect(...) then FunResult
		     [] response(...) then FunResult
		     [] HtmlDoc then
			{Html.render
			 {PreprocessHtml
			  {CallAfter PSession App Functr HtmlDoc}
			  App Functr
			  PSession ClosureSpace PathComponents
			 }
			}
		     end
		  catch E then
		     exception(
			{MakeStateless
			 {AdjoinAt E roadsURL {String.toAtom Req.originalURI}}
			 nil
			})
		  end
		  #
		  @(PSession.idChanged)#
		  @(PSession.cookiesToSend)
	       end
	      }
	      %% create response object (or propagate exception)
	      TheResponse = 
	      case Res of exception(E) then raise E end
	      [] response(...) then Res
	      [] redirect(C Url) then
		 Location = {MakeURL PathComponents Url} in
		 {RedirectResponse ServerConfig C Location}
	      else
		 {OkResponse
		  ServerConfig
		  generated(Res)
		  [{ContentTypeHeader mimeType(text html)}
		   {ExpiresHeader {OsTime.gmtime {OS.time}+App.pagesExpireAfter}}]
		  withBody}
	      end
	      %% add application cookies
	      {FoldR CookiesToSend
	       fun {$ MyCookie Resp}
		  {Cookie.setCookie Resp
		   {PostProcessCookie {Routing.buildPath [PathComponents.app]} MyCookie}}
	       end
	       TheResponse}
	   end

	   fun {PostProcessCookie DefaultPath CookieName#C0}
	      C1 = if {VirtualString.is C0} then cookie(value:C0) else C0 end
	      %% give it a name
	      C2 = {AdjoinAt C1 name CookieName}
	      %% convert virtual string to string
	      C3 = {AdjoinAt C2 value {VirtualString.toString C1.value}}
	      %% convert expires if given as seconds
	      C4 = if {HasFeature C3 expires} andthen {Int.is C3.expires} then
		      {AdjoinAt C3 expires {FormatTime {OsTime.gmtime {OS.time} + C3.expires}}}
		   else C3
		   end
	   in
	      %% add default path
	      {AdjoinAt C4 path {CondSelect C4 path DefaultPath}}
	   end
	   
	   %% .../abc/def/ghi?a=c;b=d -> .../abc/def?a=c;b=d
	   fun {RemoveClosureId URI}
	      Parts = {String.tokens URI &/}
	      StartingParts NonEmptyStartingParts LastPart
	      Query
	      FullQuery
	   in
	      {List.takeDrop Parts {Length Parts}-1 StartingParts [LastPart]}
	      NonEmptyStartingParts = {Filter StartingParts fun {$ S} S \= nil end}
	      {String.token LastPart &? _ Query}
	      FullQuery = if Query == nil then nil else "?"#Query end
	      {VirtualString.toString "/"#{Intercalate NonEmptyStartingParts "/"}#FullQuery}
	   end

	   fun {MakeURL PathComponents Url}
	      case Url of url(...) then
		 AppPath = {CondSelect Url app PathComponents.app}
		 FunctorPath = {CondSelect Url 'functor' PathComponents.'functor'}
		 FunPath = {CondSelect Url function PathComponents.function}
		 Params = {CondSelect Url params unit}
		 Extra = {VirtualString.toString
			  {CondSelect Url extra {ParamsToQuery Params}}
			 }
	      in
		 {Append {Routing.buildPath [AppPath FunctorPath FunPath]} Extra}
	      else Url
	      end
	   end

	   fun {URLEncode X}
	      {Query.percentEncode {VirtualString.toString X}}
	   end
	   
	   fun {ParamsToQuery Params}
	      case Params of unit then nil
	      else "?"#
		 {List.toTuple '#'
		  {Map {Record.toListInd Params}
		   fun {$ P#V} {URLEncode P}#"="#{URLEncode V} end
		  }}
	      end
	   end
	   
	   %% Add a secret token to every form to prevent CSRF attacks.
	   %% (Do not add it to form that use a url as the action handler, because
	   %%  those form use a bookmarkable handler without secret checking.)
	   fun {AddSecrets H}
	      case H of form(...) andthen {AttrIsProcedure H action} then
		 S = {Int.toString {SecretGenerator}}
	      in
		 {TupleAdd H
		  input(type:hidden value:S name:roadsSecret validate:is(S))
		 }
	      elseif {Record.is H} then
		 {Record.map H AddSecrets}
	      else H
	      end
	   end

	   fun {AttrIsProcedure Tag Attr}
	      A = {CondSelect Tag Attr unit}
	   in
	      case A of fork(V) then {Procedure.is V}
	      else {Procedure.is A}
	      end
	   end
	   
	   %% Replace special elements in generated html.
	   %% (might crash for ill-formed html)
	   fun {PreprocessHtml HtmlDoc App Functr Sess
		CurrentSpace PathComponents}
	      Validator = {NewCell unit}
	      fun {CallValidator Type Tag}
		 GenName
	      in
		 {@Validator Type(Tag ?GenName)}
		 case GenName of nothing then Html.removeAttribute#unit
		 [] just(N) then name#N
		 end
	      end
	   in
	      {Html.mapAttributes {AddSecrets HtmlDoc}
	       %% a new FormValidator for every form tag
	       proc {$ Tag OpenClose}
		  case Tag of form andthen OpenClose == open then
		     Validator := {New FormValidator.'class' init}
		  [] form andthen OpenClose == close then
		     Validator := unit
		  else skip
		  end
	       end
	       fun {$ Name Val Parent}
		  case Name of action andthen {Label Parent} == form then
		     action#{ProcessTargetAttribute App Functr
			     Sess CurrentSpace PathComponents
			     fun {$ F} {@Validator with(F $)} end
			     Val}
		  [] href then
		     href#{ProcessTargetAttribute App Functr
			   Sess CurrentSpace PathComponents
			   fun {$ F} F end
			   Val}
		  [] bind andthen {Label Parent} == input then
		     {CallValidator bind Parent}
		  [] bind then raise roads(bindAttributeOutsideOfInput) end
		  [] validate andthen {Label Parent} == input then
		     {CallValidator validate Parent}
		  [] validate then raise roads(validateAttributeOutsideOfInput) end
		  else
		     Name#Val
		  end
	       end
	      }
	   end

	   fun {ProcessTargetAttribute App Functr
		Sess CurrentSpace PathComponents
		Wrapper Val}
	      fun {NewClosure Fun DoFork}
		 {CreateNewClosure Sess PathComponents.basePath {Wrapper Fun}
		  Functr App CurrentSpace DoFork}
	      end
	   in
	      case Val of url(...) then {MakeURL PathComponents Val}
	      [] fork(V) then
		 {NewClosure V true}
	      elseif {Procedure.is Val} then
		 {NewClosure Val App.forkedFunctions}
	      else Val
	      end
	   end
   
	   fun {PathToClosure BasePath ClId}
	      {VirtualString.toString BasePath#"/"#{Base62.to ClId}}
	   end
   
	   fun {CreateNewClosure Sess Path Fun Functr App ClosureSpace DoFork}
	      NewClosureId = {Session.newClosureId State Sess}
	   in
	      {Session.addClosure
	       unit(closureId:NewClosureId
		    space:ClosureSpace
		    fork:DoFork
		    app:App
		    functr:Functr
		    session:Sess
		    function:Fun)
	      }
	      {PathToClosure Path NewClosureId}
	   end
	end
       ]}.1
   end
end
