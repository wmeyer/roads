functor
import
   Module OS
   OsTime
   Cookie(toHeader) at 'x-ozlib://wmeyer/sawhorse/pluginSupport/Cookie.ozf'
   IdIssuer(create) at 'x-ozlib://wmeyer/sawhorse/pluginSupport/IdIssuer.ozf'
   Session at 'x-ozlib://wmeyer/roads/Session.ozf'
   Context(forAll) at 'x-ozlib://wmeyer/roads/Context.ozf'
   Routing at 'x-ozlib://wmeyer/roads/Routing.ozf'
   Speculative at 'x-ozlib://wmeyer/roads/Speculative.ozf'
   Html(render mapAttributes removeAttribute) at 'x-ozlib://wmeyer/sawhorse/common/Html.ozf'
   Response(okResponse:OkResponse
	    contentTypeHeader:ContentTypeHeader
	    expiresHeader:ExpiresHeader
	    redirectResponse:RedirectResponse
	   ) at 'x-ozlib://wmeyer/sawhorse/common/Response.ozf'
   Util(intercalate:Intercalate
	removeTrailingSlash
       ) at 'x-ozlib://wmeyer/sawhorse/common/Util.ozf'
   Base62('from' to) at 'x-ozlib://wmeyer/roads/Base62.ozf'
   Validation('class') at 'x-ozlib://wmeyer/roads/Validation.ozf'
   Environment('class') at 'x-ozlib://wmeyer/roads/Environment.ozf'
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

   RoadsName = "Roads 0.1"

   ConfigPath = 'x-ozlib://wmeyer/roads/Config.ozf'

   %% Initialize all configured applications.
   proc {Initialize ServerName}
      [Config] = {Module.link [ConfigPath]}
   in
      State = unit(applications:{Record.map Config.applications InitNewApp}
		   sessions:{Session.newCache Config}
		   sessionIdIssuer:{IdIssuer.create}
		   closureIdIssuer:{IdIssuer.create}
		   serverName:ServerName
		  )
   end

   %% Init. an app without a previous instance.
   fun {InitNewApp URL}
      {InitApp URL unit}
   end

   %% Re-initialize existing applications; initialize new applications.
   proc {Reinitialize ServerName OldInstance}
      OldState = OldInstance.state
      [Config] = {Module.link [ConfigPath]}
      Apps = {Record.mapInd Config.applications
	      fun {$ Path FunURL}
		 if {HasFeature OldState.applications Path} then
		    OldApp = OldState.applications.Path
		 in
		    {InitApp FunURL OldApp.resources}
		 else
		    {InitNewApp FunURL}
		 end
	      end
	     }
      ExpireSessionsOnRestart = {CondSelect Config expireSessionsOnRestart false}
   in
      State = unit(applications:Apps
		   sessions:if ExpireSessionsOnRestart then {Session.newCache Config}
			    else OldState.sessions end
		   sessionIdIssuer:OldState.sessionIdIssuer
		   closureIdIssuer:OldState.closureIdIssuer
		   serverName:ServerName
		  )
   end

   %% Re-initialize an app from its previous state.
   fun {InitApp URL OldResources}
      [AppModule] = {Module.link [URL]}
      Resources = if OldResources == unit then
		     if {HasFeature AppModule init} then {AppModule.init}
		     else session end
		  elseif {HasFeature AppModule onRestart} then
		     {AppModule.onRestart OldResources}
		  else OldResources
		  end
      Config = AppModule.config
      fun {Link URL}
	 if {Atom.is URL} then 
	    {Module.link [URL]}.1
	 elseif {Chunk.is URL} then
	    {Module.apply [URL]}.1
	 end
      end
   in
      application(module:AppModule
		  resources:Resources
		  functors:{Record.map Config.functors Link}
		  before:{CondSelect AppModule before fun {$ _ X} X end}
		  after:{CondSelect AppModule after fun {$ _ X} X end}
		  forkedFunctions:{CondSelect Config forkedFunctions true}
		  pagesExpireAfter:{CondSelect Config pagesExpireAfter 60*60}
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

   %% Check whether we want to process the given request: check whether there is a function
   %% for the given path.
   fun {WantsRequest Req=request(uri:URI ...)}
      case {Routing.getFunction {StateFromRequest Req} URI.path}
      of nothing then false
      [] just(_) then true
      end
   end

   fun {HandleGetRequest Config Req Inputs}
      {HandleRequest Config get Req Inputs}
   end

   fun {HandlePostRequest Config Req Inputs}
      {HandleRequest Config post Req Inputs}
   end

   %% The central function
   fun {HandleRequest Config Type Req=request(uri:URI ...) Inputs}
      {Config.trace "Roads::HandleRequest"}
      Path = URI.path
      %% get session from cookie or create a new one
      MyState = {StateFromRequest Req}
      IsNewSession
      RSession = case {Session.fromRequest State Req} of just(S) then
		    IsNewSession = false S
		 else
		    SessionId = {Session.newId State}
		 in
		    {Config.trace newSession}
		    IsNewSession = true
		    {State.sessions condGet(SessionId
					    {Session.new MyState Path SessionId})}
		 end
      {Config.trace "Roads::HandleRequest, got session"}
      %% find out which function to call (if no closure is given)
      PathComponents
      App Functr Function MaybeClosureId
      {Routing.analyzePath MyState Path
       ?PathComponents ?App ?Functr ?Function ?MaybeClosureId}
      = true
      BasePath = PathComponents.basePath
      {Config.trace "Roads::HandleRequest, got function"}
      TheResponse =
      case MaybeClosureId of nothing then
	 %% WITHOUT CLOSURE
	 if Type == get then
	    {Config.trace "Roads::HandleRequest, get"}
	    %% GET REQUEST: execute function
	    {ExecuteGetRequest
	     unit(config:Config
		  app:App
		  functr:Functr
		  function:Function
		  session:RSession
		  req:Req
		  inputs:Inputs
		  pathComponents:PathComponents
		  closureId:~1
		  closureSpace:unit
		 )}
	 elseif Type == post then
	    %% POST REQUEST
	    %% redirect to a get request to a newly created closure
	    %% (Post/Redirect/Get pattern)
	    NewClosureId = {Session.newClosureId State RSession}
	 in
	    {Config.trace "Roads::HandleRequest, post"}
	    {Session.addClosure
	     unit(closureId:NewClosureId
		  space:unit
		  fork:false
		  app:App
		  functr:Functr
		  session:{Session.prepareFutureSession RSession Inputs}
		  function:Function)
	    }
	    {RedirectResponse Config 303 {PathToClosure BasePath NewClosureId}}
	 end
      [] just(ClosureIdS) then
	 %% WITH CLOSURE
	 ClosureId = {Base62.'from' ClosureIdS} %% might throw
      in
	 {Config.trace "Roads::HandleRequest, got closure"}
	 case {Session.getClosure RSession ClosureId}
	 of nothing then %% expired closure
	    {Config.trace "Roads::HandleRequest, closure expired"}
	    %% redirect to same url without closure
	    %% It is up to the single function to decide if it works without previous state
	    {RedirectResponse Config 303 {RemoveClosureId Req.originalURI}
	    }
	 [] just(Closure) then
	    if Type == get then
	       {Config.trace "Roads::HandleRequest, get2"}
	       %% GET REQUEST: execute function, possibly in cloned space.
	       {ExecuteGetRequest
		unit(config:Config
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
		    )}
	    elseif Type == post then
	       %% POST REQUEST (redirect to get request of closure with bound params)
	       NewClosureId = {Session.newClosureId State RSession}
	       
	    in
	       {Config.trace "Roads::HandleRequest, post2"}
	       {Session.addClosure
		unit(closureId:NewClosureId
		     space:Closure.space
		     fork:Closure.fork
		     app:App
		     functr:Functr
		     session:{Session.prepareFutureSession Closure.session Inputs}
		     function:Closure.function)
	       }
	       {RedirectResponse Config 303 {PathToClosure BasePath NewClosureId}}
	    end
	 end
      end
   in
      if IsNewSession then
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
      {AdjoinAt Resp headers
       {Cookie.toHeader
	cookie(name:Session.sessionCookie
	       value:{Int.toString CSession.id}
	       'Path':{Routing.buildPath [PathComponents.app]})}
       |Resp.headers}
   end
   
   fun {ExecuteGetRequest
	unit(config:Config

	     app:App
	     functr:Functr
	     function:Function
	     
	     session:CSession
	     req:Req
	     inputs:Inputs
	     closureId:ClosureId
	     closureSpace:ClosureSpace
	     pathComponents:PathComponents
	    )}
      {Context.forAll CSession closureCalled(ClosureId)}
      Res
      = {Speculative.evalInSpace ClosureSpace
	 fun {$}
%	    try
	       %% Session must be prepared in the space to make the private dict local
	       PSession = {Session.'prepare' CSession Req Inputs}
	       RealFun = {CallBefore PSession App Functr Function}
	       FunResult = {RealFun PSession.interface}
	    in
	       case FunResult of redirect(...) then FunResult
	       [] response(...) then FunResult
	       [] HtmlDoc then
		  {Html.render
		   {PreprocessHtml
		    {CallAfter PSession App Functr HtmlDoc}
		    App Functr
		    PSession ClosureSpace PathComponents}
		  }
	       end
%	    catch E then
%	       exception(E)
%	    end
	 end
	}
   in
      case Res of exception(E) then raise E end
      [] response(...) then Res
      [] redirect(C Url) then
	 Location = {MakeURL PathComponents Url} in
	 {RedirectResponse Config C Location}
      else
	 {OkResponse
	  Config
	  generated(Res)
	  [{ContentTypeHeader mimeType(text html)}
	   {ExpiresHeader {OsTime.gmtime {OS.time}+App.pagesExpireAfter}}]
	  withBody}
      end
   end
   
   %% .../abc/def/ghi?a=c;b=d -> .../abc/def?a=c;b=d
   fun {RemoveClosureId URI}
      Parts = {String.tokens URI &/}
      Start Last
      Query
      FullQuery
   in
      {List.takeDrop Parts {Length Parts}-1 Start [Last]}
      {String.token Last &? _ Query}
      FullQuery = if Query == nil then nil else "?"#Query end
      {VirtualString.toString {Intercalate Start "/"}#FullQuery}
   end

   fun {MakeURL PathComponents Url}
      case Url of url(...) then
	 AppPath = {CondSelect Url app PathComponents.app}
	 FunctorPath = {CondSelect Url 'functor' PathComponents.'functor'}
	 FunPath = {CondSelect Url function PathComponents.function}
	 Extra = {VirtualString.toString {CondSelect Url extra nil}}
      in
	 {Append {Routing.buildPath [AppPath FunctorPath FunPath]} Extra}
      else Url
      end
   end

   %% Replace special elements in generated html.
   %% (might crash for ill-formed html)
   fun {PreprocessHtml HtmlDoc App Functr Sess CurrentSpace PathComponents}
      Env = {NewCell unit}
      Valid = {NewCell unit}
   in
      {Html.mapAttributes HtmlDoc
       proc {$ Tag OpenClose}
	  case Tag of form andthen OpenClose == open then
	     Env := {New Environment.'class' init}
	     Valid := {New Validation.'class' init}
	  [] input andthen OpenClose == open then {@Valid startInputTag}
	  [] input andthen OpenClose == close then {@Valid endInputTag}
	  else skip
	  end
       end
       fun {$ Name Val}
	  case Name of action then
	     action#{ProcessTargetAttribute App Functr
		     Sess CurrentSpace PathComponents
		     fun {$ F} {@Valid with({@Env with(F $)} $)} end
		     Val}
	  [] href then
	     href#{ProcessTargetAttribute App Functr
		   Sess CurrentSpace PathComponents
		   fun {$ F} F end
		   Val}
	  [] bind then
	     BindingName = {@Env newName($)}
	  in
	     {@Env add(BindingName Val)}
	     {@Valid setCurrentInputName(BindingName)}
	     name#BindingName
	  [] name then
	     {@Valid setCurrentInputName(Val)}
	     Name#Val
	  [] id then
	     {@Valid setCurrentInputId(Val)}
	     Name#Val
	  [] validate then
	     {@Valid addValidator(Val)}
	     Html.removeAttribute#unit
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
