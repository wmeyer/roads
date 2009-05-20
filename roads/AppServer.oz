functor
import
   IdIssuer(create) at 'x-ozlib://wmeyer/sawhorse/pluginSupport/IdIssuer.ozf'
   Resolve
   OS
   OsTime
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
   Base62(is 'from' to) at 'x-ozlib://wmeyer/roads/Base62.ozf'
   FormValidator('class') at 'x-ozlib://wmeyer/roads/FormValidator.ozf'
   DocumentCache at 'x-ozlib://wmeyer/roads/DocumentCache.ozf'
   ActiveObject at 'x-ozlib://wmeyer/roads/appSupport/ActiveObject.ozf'
   Session at 'x-ozlib://wmeyer/roads/Session.ozf'
   Cookie(toHeader) at 'x-ozlib://wmeyer/sawhorse/pluginSupport/Cookie.ozf'
   Logging(newLogger:NewLogger newStream) at 'x-ozlib://wmeyer/sawhorse/common/Logging.ozf'
   Module
export
   Initialize
   Reinitialize
   ShutDown
   HandleRequest

   State
define
   State
   LoggerStream
   Logger
	   
   SecretGenerator = {IdIssuer.create 4}
   DefaultCacheDuration = 2*60*1000
   
   fun {CreateRoadsLogger}
      LogLevel = trace % {CondSelect State.roadsConfig logLevel trace}
      LogDir = "/home/user/" %{Atom.toString {Resolve.localize State.serverConfig.logDir}.1}

      Stream = %if State.appServerName == 'local' then State.serverConfig.logStream
	       %else
		  {Logging.newStream init(stderr dir:LogDir)} %State.appServerName#".log" dir:LogDir)}
	       %end
   in
      LoggerStream = Stream
      {NewLogger init(module:"appserver"
		      stream:Stream
		      logLevel:LogLevel)}
   end


   fun {NewSessionCache RoadsConfig}
      {Session.newCache {CondSelect RoadsConfig sessionDuration 60*60*1000}}
   end

   %% Logger (take from server config if local; otherwise create)
   %% Call OnDistribute to get updated ressources if not local
   %% initialize rest of state
   proc {Initialize RoadsConfig ServerConfig OriginalApplications ServerName}
      Logger = {CreateRoadsLogger}
      {Logger.trace "initialize"}
      State = unit(applications:{Record.map OriginalApplications
				 fun {$ A} {DistributeApp A ServerName=='local'} end}
		   sessions:{NewSessionCache RoadsConfig}
		   closureIdIssuer:{IdIssuer.create 4}
		   serverConfig:ServerConfig
		   roadsConfig:RoadsConfig
		   documentCache:{New DocumentCache.'class' init}
		   appServerName:ServerName
		  )
      {Logger.trace "end of initialize"}
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
   
   %% Adjust application to site. (Logger, resources, page caching)
   fun {DistributeApp App IsLocal}
      {Logger.trace "DistributeApp1"}
      AppName = {CondSelect App.module appName app}
      LogLevel = {CondSelect App.module logLevel trace}
      AppLogger = {NewLogger init(module:AppName
				  stream:LoggerStream
				  logLevel:LogLevel)}
      Resources = if IsLocal then App.resources
		  elseif {HasFeature App.module onDistribute} then
		     Local = 'local'(link:fun {$ URL} {Module.link [URL] [$]} end)
		  in
		     {App.module.onDistribute
		      {Adjoin App.resources
		       session('local':Local
			       logTrace:Logger.trace
			       logError:Logger.error)}}
		  else App.resources
		  end
      FunctorPageCaching =
      {Record.map App.functors
       fun {$ F}
	  {SimplifyPageCachingConfig functions
	   {{CondSelect F pageCaching
	     fun {$ _} false end}
	    Resources}
	  }
       end}
      PageCaching =
      {SimplifyPageCachingConfig functors
       {{CondSelect App.module pageCaching fun {$ _} false end}
	Resources}}
   in
      {Logger.trace "DistributeApp2"}
      {Adjoin App
       application(
	  resources:Resources
	  logger:AppLogger
	  functorPageCaching:FunctorPageCaching
	  pageCaching:PageCaching
	  )			  
      }
   end
   
   %% Reinitialize after restart;
   %% Old application resources are discarded; we need to work based on the applications from the dispatcher (new code!)
   %% We only inherit id issuers, isLocal and possibly the sessions.
   proc {Reinitialize RoadsConfig ServerConfig Applications OldInstance}
      OldState = OldInstance.state
      ExpireSessionsOnRestart = {CondSelect RoadsConfig expireSessionsOnRestart false}
   in
      State = unit(applications:{Map Applications fun {$ A} {DistributeApp A OldState.isLocal} end}
		   sessions:if ExpireSessionsOnRestart then
			       {NewSessionCache RoadsConfig}
			    else OldState.sessions end
		   sessionIdIssuer:OldState.sessionIdIssuer
		   closureIdIssuer:OldState.closureIdIssuer
		   serverName:ServerConfig.serverName
		   serverConfig:ServerConfig
		   roadsConfig:RoadsConfig
		   documentCache:{New DocumentCache.'class' init}
		   appServerName:OldState.appServerName
		  )
      Logger = {CreateRoadsLogger}
   end

   %% maybe minimize resource usage
   proc {ShutDown}
      skip
   end

   %% returns Maybe( Response )
   fun {HandleRequest Type Req=request(uri:URI ...) Inputs
	S=sessionId(id:SessionId next:NextSessionIdCandidate
		    isNew:SessionIdIsNew changed:_)}%changed:?SessionIdChanged)}
      try
      Path = URI.path
	 RSession
	 SessionIdChanged = {NewCell false}
      case {Session.get State SessionId} of just(S) then
	 RSession= S
      else
	 {Logger.trace newSession}
	 RSession = {Session.new State Path SessionId}
	 if RSession \= nothing then {Session.add State SessionId RSession} end
      end
      PathComponents
      App Functr Function MaybeClosureId
   in
      if RSession == nothing orelse
	 %% find out which function to call (if no closure is given)
	 %% (here we use request-dependent global state to use the old configuration
	 %%  for old sessions)
	 {Routing.analyzePath RSession.state Path
	  ?PathComponents ?App ?Functr ?Function ?MaybeClosureId} == false then
	 nothing
      else
	 RequestState = RSession.state
	 (RSession \= nothing) = true
	 BasePath = PathComponents.basePath
	 TheResponse =
	 case MaybeClosureId of nothing then
	    %% WITHOUT CLOSURE
	    if Type == get then
	       {Logger.trace "Roads::HandleRequest, get"}
	       %% GET REQUEST: execute function
	       {ExecuteGetRequest
		unit(app:App
		     functr:Functr
		     function:Function
		     session:RSession
		     req:Req
		     inputs:Inputs
		     pathComponents:PathComponents
		     closureId:~1
		     closureSpace:unit
		     state:RequestState
		     changeSessionId:SessionIdChanged
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
	       {RedirectResponse State.serverConfig 303
		{PathToClosure BasePath NewClosureId}}
	    end
	 [] just(ClosureIdS) then
	    %% WITH CLOSURE (candidate)
	    if {Not {Base62.is ClosureIdS}} then
	       {NotFoundResponse State.serverConfig}
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
		  {RedirectResponse State.serverConfig 303 NewPath}
	       [] just(Closure) then
		  if Type == get then
		     {Logger.trace "Roads::HandleRequest, get2"}
		     %% GET REQUEST: execute function, possibly in cloned space.
		     {ExecuteGetRequest
		      unit(app:Closure.app
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
			   state:RequestState
			   changeSessionId:SessionIdChanged
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
		     {RedirectResponse State.serverConfig 303
		      {PathToClosure BasePath NewClosureId}}
		  end
	       end
	    end
	 end
      in
	 SessionIdChanged := false
	 if @SessionIdChanged then
	    {State.sessions move(SessionId NextSessionIdCandidate) _}
	 end
	 if SessionIdIsNew orelse @SessionIdChanged then
	    just( {AddSessionCookie TheResponse NextSessionIdCandidate PathComponents} )
	 else
	    just( TheResponse )
	 end
      end
      catch E then
	 {Logger.error "HandleRequest failed"}
	 {Logger.error E}
	 {Logger.exception E}
	 exception({MakeStateless E nil})
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
   
   fun {AddSessionCookie Resp SessionId PathComponents}
      {Response.addHeader Resp
       {Cookie.toHeader
	cookie(name:Session.sessionCookie
	       value:{Int.toString SessionId}
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
			 {Unique
			  {Session.'prepare' State App.logger
			   CSession Req Inputs DefaultCookiePath {NewCell false}}.interface}
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
      fun {GetOption Opt Default}
	 if {HasFeature Functors FunctorPath} andthen {HasFeature Functors.FunctorPath Opt} then
	    Functors.FunctorPath.Opt
	 elseif {HasFeature Functions FunctionPath} andthen {HasFeature Functions.FunctionPath Opt} then
	    Functions.FunctionPath.Opt
	 else
	    {CondSelect PageCaching Opt Default}
	 end
      end
   in
      if {Label PageCaching} == false then false
      else
	 Duration = {GetOption duration DefaultCacheDuration}
	 Expire = {GetOption expire proc {$ _} skip end}
	 Unique = {GetOption unique nothing}
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
	unit(app:App
	     functr:Functr
	     function:Function
	     
	     session:CSession
	     req:Req
	     inputs:Inputs
	     closureId:ClosureId
	     closureSpace:ClosureSpace
	     pathComponents:PathComponents

	     state:RequestState
	     changeSessionId:SIC
	    )}
      Res
      HeadersToSend
      TheResponse
      MimeType = {CondSelect Functr mimeType App.mimeType}
   in
      {Context.forAll CSession closureCalled(ClosureId)}
      Res#
      HeadersToSend
      =
      {Speculative.evalInSpace ClosureSpace
       fun {$}
	  %% Session must be prepared in the space
	  %% to make the private dict local
	  DefaultCookiePath = {Routing.buildPath [PathComponents.app]}
	  PSession =
	  {Session.'prepare' State App.logger CSession
	   Req Inputs DefaultCookiePath SIC}
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
	  @(PSession.headersToSend)
       end
      }
      %% create response object (or propagate exception)
      TheResponse = 
      case Res of exception(E) then raise E end
      [] response(...) then Res
      [] redirect(C Url) then
	 Location = {MakeURL PathComponents Url} in
	 {RedirectResponse State.serverConfig C Location}
      else
	 {OkResponse
	  State.serverConfig
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
	   
   %% .../abc/def/ghi?a=c;b=d -> /.../abc/def
   fun {RemoveClosureId URI}
      Parts = {String.tokens URI &/}
      ButLast = {List.take Parts {Length Parts}-1}
      NonEmpty = {Filter ButLast fun {$ S} S \= nil end}
   in
      {Append "/" {Intercalate NonEmpty "/"}}
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
