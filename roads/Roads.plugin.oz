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
	   Module OS
	   OsTime
	   Cookie(toHeader) at 'x-ozlib://wmeyer/sawhorse/pluginSupport/Cookie.ozf'
	   IdIssuer(create) at 'x-ozlib://wmeyer/sawhorse/pluginSupport/IdIssuer.ozf'
	   Session at 'x-ozlib://wmeyer/roads/Session.ozf'
	   Context(forAll) at 'x-ozlib://wmeyer/roads/Context.ozf'
	   Routing at 'x-ozlib://wmeyer/roads/Routing.ozf'
	   Speculative at 'x-ozlib://wmeyer/roads/Speculative.ozf'
	   Html(render renderFragment mapAttributes removeAttribute)
	   at 'x-ozlib://wmeyer/sawhorse/common/Html.ozf'
	   Response(okResponse:OkResponse
		    contentTypeHeader:ContentTypeHeader
		    expiresHeader:ExpiresHeader
		    redirectResponse:RedirectResponse
		    notFoundResponse:NotFoundResponse
		    addHeader
		   ) at 'x-ozlib://wmeyer/sawhorse/common/Response.ozf'
	   Util(intercalate:Intercalate
		removeTrailingSlash
		tupleAdd:TupleAdd
		listToLookup:ListToLookup
	       ) at 'x-ozlib://wmeyer/sawhorse/common/Util.ozf'
	   Query at 'x-ozlib://wmeyer/sawhorse/common/Query.ozf'
	   Logging(newLogger:NewLogger) at 'x-ozlib://wmeyer/sawhorse/common/Logging.ozf'
	   Base62(is 'from' to) at 'x-ozlib://wmeyer/roads/Base62.ozf'
	   FormValidator('class') at 'x-ozlib://wmeyer/roads/FormValidator.ozf'
	   DocumentCache at 'x-ozlib://wmeyer/roads/DocumentCache.ozf'
	   ActiveObject at 'x-ozlib://wmeyer/roads/appSupport/ActiveObject.ozf'
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
			   documentCache:{New DocumentCache.'class' init}
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
			   documentCache:{New DocumentCache.'class' init}
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

	   fun {LinkFunctor Functr Session}
	      Result = {Link Functr}
	   in
	      if {HasFeature Result onLoad} then {Result.onLoad Session} end
	      Result
	   end

	   %% true -> true(Feat:unit)
	   %% true(Feat:[a b(c:e f)] -> true(Feat:unit(a:a b:b(c:e f)))
	   fun {SimplifyPageCachingConfig Feat PageCaching}
	      case PageCaching of false then false
	      else
		 {AdjoinAt PageCaching Feat
		  {ListToLookup {CondSelect PageCaching Feat nil}}
		 }
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
	      Functors = {Record.map AppModule.functors fun {$ F} {LinkFunctor F Resources} end}	      
	   in
	      application(module:AppModule
			  resources:Resources
			  functors:Functors
			  functorPageCaching:{Record.map Functors
					      fun {$ F}
						 {SimplifyPageCachingConfig functions
						  {CondSelect F pageCaching false}}
					      end}
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
			  pageCaching:{SimplifyPageCachingConfig functors {CondSelect AppModule pageCaching
									   {CondSelect Config pageCaching false}}}
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
	      RequestState = {StateFromRequest Req}
	      PathComponents
	      App Functr Function MaybeClosureId
	      {Routing.analyzePath RequestState Path
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
			  state:RequestState
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
				state:RequestState
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
	      {Response.addHeader Resp
	       {Cookie.toHeader
		cookie(name:Session.sessionCookie
		       value:{Int.toString @(CSession.id)}
		       'Path':{Routing.buildPath [PathComponents.app]}
		       'HTTPOnly':unit
		      )
	       }}
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
		Msg=unit(app:App
			 req:Req
			 pathComponents:PathComponents
			 state:RequestState
			 inputs:Inputs
			 session:CSession
			 closureId:CId
			 ...
			)}
	      AppPath = PathComponents.app
	      FunctorPath = PathComponents.'functor'
	      FunctorPG = RequestState.applications.AppPath.functorPageCaching.FunctorPath
	      PageCachingConfig = if FunctorPG == nothing then App.pageCaching else FunctorPG end
	      PageDuration
	      PageExpire
	      Unique
	   in
	      if CId == ~1 andthen
		 {PageShouldBeCached PageCachingConfig PathComponents
		  ?PageDuration ?PageExpire ?Unique} then
		 DefaultCookiePath = {Routing.buildPath [PathComponents.app]}
		 UniquePart = case Unique of nothing then nil
			      else
				 {Unique {Session.'prepare' State App.logger
					  CSession Req Inputs DefaultCookiePath}.interface}
			      end
		 Id = {VirtualString.toAtom page#Req.originalURI#UniquePart}
		 DocCache = RequestState.documentCache
	      in
		 case {DocCache getDocument(id:Id result:$)}
		 of just(Res) then
		    {Logger.trace "PAGE CACHED!!"}
		    Res
		 [] nothing then
		    {Logger.trace "...page not cached..."}
		    Result = {ExecuteUncachedGetRequest Msg}
		    Expire
		 in
		    {DocCache setDocument(id:Id duration:PageDuration data:Result result:Expire)}
		    {PageExpire Expire}
		    Result
		 end
	      else
		 {ExecuteUncachedGetRequest Msg}
	      end
	   end

	   %% PageCaching: config
	   %% PathComponents
	   %% Duration:
	   %% Expire: procedure to be called with expire token
	   %% Unique: maybe(function that takes session as only argument
	   %%               and returns a key which identifies different versions of a page)
	   fun {PageShouldBeCached PageCaching PathComponents ?Duration ?Expire ?Unique}
	      Functors = {CondSelect PageCaching functors nothing}
	      Functions = {CondSelect PageCaching functions nothing}
	      FunctorPath = PathComponents.'functor'
	      FunctionPath = PathComponents.function
	      fun {GetOption Opt GlobalName Default}
		 if {HasFeature Functors FunctorPath} andthen {HasFeature Functors.FunctorPath Opt} then
		    Functors.FunctorPath.Opt
		 elseif {HasFeature Functions FunctionPath} andthen {HasFeature Functions.FunctionPath Opt} then
		    Functions.FunctionPath.Opt
		 else
		    {CondSelect PageCaching Opt
		     {CondSelect Config GlobalName
		      Default}}
		 end
	      end
	   in
	      if {Label PageCaching} == false then false
	      else
		 Duration = {GetOption duration pageCacheDuration DefaultCacheDuration}
		 Expire = {GetOption expire nothing proc {$ _} skip end}
		 Unique = {GetOption unique nothing nothing}
		 %% all functors shall be cached
		 Functors == unit
		 orelse
		 %% all functions shall be cached
		 Functions == unit
		 orelse
		 %% this functor shall be cached
		 {HasFeature Functors FunctorPath}
		 orelse
		 %% this function shall be cached
		 {HasFeature Functions FunctionPath}
	      end
	   end
  
	   fun {ExecuteUncachedGetRequest
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
		     state:RequestState
		    )}
	      Res
	      HeadersToSend
	      TheResponse
	      MimeType = {CondSelect Functr mimeType App.mimeType}
	   in
	      {Context.forAll CSession closureCalled(ClosureId)}
	      Res#
	      SessionIdChanged#
	      HeadersToSend
	      =
	      {Speculative.evalInSpace ClosureSpace
	       fun {$}
		  %% Session must be prepared in the space
		  %% to make the private dict local
		  DefaultCookiePath = {Routing.buildPath [PathComponents.app]}
		  PSession =
		  {Session.'prepare' State App.logger CSession Req Inputs DefaultCookiePath}
		  RealFun = {NewCell {CallBefore PSession App Functr Function}}
		  FunResult
		  DocumentCache = {Value.byNeed
				   fun {$} {ActiveObject.newInterface RequestState.documentCache} end}
		  
		  fun {PreprocessIt Doc}
		     {PreprocessHtml Doc App Functr PSession ClosureSpace PathComponents}
		  end
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
		     [] HtmlDoc andthen MimeType == mimeType(text html) then
			{Html.render
			 {DoFragmentCaching
			  params(cache:DocumentCache
				 preprocessor:PreprocessIt
				 defaultFragmentId:fragment#Req.originalURI
				 defaultFragmentDuration:{CondSelect Functr fragmentCacheDuration
							  App.fragmentCacheDuration}
				 document:{PreprocessIt
					   {CallAfter PSession App Functr HtmlDoc}
					  }
				)
			 }
			}
		     else
			{CallAfter PSession App Functr FunResult}
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
		  @(PSession.headersToSend)
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
		  [{ContentTypeHeader
		    {AdjoinAt MimeType
		     charset {CondSelect Functr charset App.charset}
		    }
		   }
		   {ExpiresHeader {OsTime.gmtime {OS.time}+App.pagesExpireAfter}}]
		  withBody}
	      end
	      %% add application headers (incl. cookies)
	      {FoldL HeadersToSend Response.addHeader TheResponse}
	   end

	   fun {DoFragmentCaching
		Ps=params(cache:Cache
			  preprocessor:Preprocessor
			  defaultFragmentId:DefaultId
			  defaultFragmentDuration:DefaultFragmentDuration
			  document:Doc
			 )}
	      fun {Do X}
		 {DoFragmentCaching {AdjoinAt Ps document X}}
	      end
	   in
	      case Doc of cached(Fun ...) then
		 Id0 = {CondSelect Doc id DefaultId}
		 Id = if {VirtualString.is Id0} then {VirtualString.toAtom Id0} else Id0 end
		 Duration = {CondSelect Doc duration DefaultFragmentDuration}
		 Result
	      in
		 case {Cache getDocument(id:Id result:$)}
		 of just(Res) then
		    {Logger.trace "CACHED!"}
		    Result = Res
		 [] nothing then
		    Expire
		 in
		    {Logger.trace "...not cached..."}
		    Result = {Html.renderFragment {Do {Preprocessor {Fun Expire}}}}
		    {Cache setDocument(id:Id duration:Duration data:Result result:Expire)}
		 end
		 Result
	      elseif {Record.is Doc} then {Record.map Doc Do}
	      else Doc
	      end
	   end
	   
	   %% .../abc/def/ghi?a=c;b=d -> .../abc/def
	   fun {RemoveClosureId URI}
	      Parts = {String.tokens URI &/}
	      StartingParts NonEmptyStartingParts
	   in
	      StartingParts = {List.take Parts {Length Parts}-1}
	      NonEmptyStartingParts = {Filter StartingParts fun {$ S} S \= nil end}
	      {VirtualString.toString "/"#{Intercalate NonEmptyStartingParts "/"}}
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
		 {Intercalate
		  {Map {Record.toListInd Params}
		   fun {$ P#V} {VirtualString.toString {URLEncode P}#"="#{URLEncode V}} end
		  }
		  [&&]
		 }
	      end
	   end
	   
	   %% Add a secret token to every form to prevent CSRF attacks.
	   %% (Do not add it to form that use a url as the action handler, because
	   %%  those form use a bookmarkable handler without secret checking.)
	   fun {AddSecrets H}
	      if {IsFree H} then H
	      elsecase H of form(...) andthen {AttrIsProcedure H action} then
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

	   fun {IsFormInput Tag}
	      {Member {Label Tag} [input select textarea]}
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
			     nil fun {$ F} {@Validator with(F $)} end
			     Val}
		  [] href then
		     if App.useTokenInLinks then
			LinkSecret = {Base62.to {SecretGenerator}}
		     in
			href#{ProcessTargetAttribute App Functr
			      Sess CurrentSpace PathComponents
			      "?sid="#LinkSecret
			      fun {$ F}
				 fun {$ S}
				    {S.validateParameters [sid(validate:is(LinkSecret))]}
				    {F S}
				 end
			      end
			      Val}
		     else
			href#{ProcessTargetAttribute App Functr
			      Sess CurrentSpace PathComponents
			      nil fun {$ F} F end Val}
		     end
		  [] bind andthen {IsFormInput Parent} then
		     {CallValidator bind Parent}
		  [] bind then raise roads(bindAttributeOutsideOfInput) end
		  [] validate andthen {IsFormInput Parent} then
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
		Query Wrapper Val}
	      fun {NewClosure Fun DoFork}
		 {CreateNewClosure Sess PathComponents.basePath {Wrapper Fun}
		  Functr App CurrentSpace DoFork}
	      end
	   in
	      case Val of url(...) then {MakeURL PathComponents Val}
	      [] fork(V) then
		 {NewClosure V true}#Query
	      elseif {Procedure.is Val} then
		 {NewClosure Val App.forkedFunctions}#Query
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
