%%
%% A session holds all state that is specific to a sequence of function calls.
%% Only some of the state is shared among all function calls within a user session.
%% The input to user-defined functions is NOT this session data, but only the public
%% interface.
%%
functor
import
   Cookie(getCookie:GetCookie) at 'x-ozlib://wmeyer/sawhorse/pluginSupport/Cookie.ozf'
   Context at 'x-ozlib://wmeyer/roads/Context.ozf'
   Routing at 'x-ozlib://wmeyer/roads/Routing.ozf'
   Map at 'x-ozlib://wmeyer/sawhorse/pluginSupport/Map.ozf'
   Html at 'x-ozlib://wmeyer/sawhorse/common/Html.ozf'
   NonSituatedDictionary
   at 'x-ozlib://wmeyer/sawhorse/pluginSupport/NonSituatedDictionary.ozf'
   Cache(create) at 'x-ozlib://wmeyer/sawhorse/pluginSupport/Cache.ozf'
   Validator(create) at 'x-ozlib://wmeyer/roads/Validator.ozf'
export
   FromRequest
   NewId
   SessionCookie
   new:NewSession
   NewCache
   'prepare':PrepareSession
   PrepareFutureSession

   GetClosure
   NewClosureId
   AddClosure
define
   SessionCookie = roadsSession

   %% The dictionary module used for access to the private session data.
   PrivateDict = Dictionary
   %% The dictionary module used for access to the shared session data.
   SharedDict = NonSituatedDictionary
   TmpDict = Dictionary

   fun {SessionIdFromRequest Req}
      case {GetCookie Req SessionCookie} of nothing then nothing
      [] just(cookie(value:SessionString ...)) then
	 try just({String.toInt SessionString}) catch _ then nothing end
      end
   end
   
   fun {GetSession State Id}
      case {State.sessions condGetUncached(Id nothing)} of nothing then nothing
      [] S then just(S)
      end
   end

   %% Request -> Maybe Session
   %% (Always takes the current global state, not session-specific state.)
   fun {FromRequest State Req}
      case {SessionIdFromRequest Req} of nothing then nothing
      [] just(Id) then {GetSession State Id}
      end
   end
   
   %% (Always takes the current global state, not session-specific state.)
   fun {NewId State}
      Id = {State.sessionIdIssuer}
   in
      case {GetSession State Id} of nothing then Id
      else {NewId State}
      end
   end

   %% This is used when Session.validateParameters is called; not when automatic
   %% validation from form submission is used.
   proc {ValidateParameters Spec Params}
      SpecRec = {List.toRecord unit {List.map Spec fun {$ S} {Label S}#S end}}
   in
      %% check that everything in Spec exists
      for S in Spec do
	 ParameterName = {Label S}
      in
	 if {Not {HasFeature Params ParameterName}} then
	    raise validationFailed("Expected parameter "#ParameterName#" not found.") end
	 end
      end
      %% check that there is a spec for every actual parameter and that it validates
      {Record.forAllInd Params
       proc {$ ParamName V}
	  if {Not {HasFeature SpecRec ParamName}} then
	     raise validationFailed("Unexpected parameter "#ParamName) end
	  else
	     ValidatorSpec = {CondSelect SpecRec.ParamName validate 'true'}
	     ValFun = if {Procedure.is ValidatorSpec} then ValidatorSpec
		      else {Validator.create ValidatorSpec}
		      end
	  in
	     case {ValFun ParamName V}
	     of true then skip
	     [] false then
		raise validationFailed("Validation of field \""#ParamName#"\" failed.") end
	     [] Other then raise validationFailed(Other) end
	     end
	  end
       end
      }
   end

   local
      CookiePort
      thread
	 for getCookie(Request Key)#Res in {Port.new $ CookiePort} do
	    {Cookie.getCookie Request Key Res}
	 end
      end
   in
   %% Add the user interface to a session.
   fun {AddInterface State Logger S}
      fun {GetCookieExt Key}
	 {Port.sendRecv CookiePort getCookie(S.request Key)}
      end
      proc {SetCookie Key ValOrDesc}
	 (S.cookiesToSend) := (Key#ValOrDesc)|@(S.cookiesToSend)
      end
   in
      {AdjoinAt S interface
       {Adjoin S.interface
	session(
	   %% private
	   set:proc {$ LI X} {PrivateDict.put S.private LI X} end
	   get:fun {$ LI} {PrivateDict.get S.private LI} end
	   condGet:fun {$ LI DefVal} {PrivateDict.condGet S.private LI DefVal} end
	   member:fun {$ LI} {PrivateDict.member S.private LI} end
	   remove:proc {$ LI} {PrivateDict.remove S.private LI} end
	   %% shared
	   setShared:proc {$ LI X} {SharedDict.put S.shared LI X} end
	   getShared:fun {$ LI} {SharedDict.get S.shared LI} end
	   condGetShared:fun {$ LI DefVal} {SharedDict.condGet S.shared LI DefVal} end
	   memberShared:fun {$ LI} {SharedDict.member S.shared LI} end
	   removeShared:proc {$ LI} {SharedDict.remove S.shared LI} end
	   %% params
	   getParam:fun {$ LI} {ExternalInput S.params.LI} end
	   condGetParam:fun {$ LI DefVal}
			   if {HasFeature S.params LI} then {ExternalInput S.params.LI}
			   else DefVal
			   end
			end
	   memberParam:fun {$ LI} {HasFeature S.params LI} end
	   validateParameters:proc {$ Spec}
				 {ValidateParameters Spec S.params}
			      end
	   %% tmp
	   setTmp:proc {$ LI X} {TmpDict.put S.tmp LI X} end
	   getTmp:fun {$ LI} {TmpDict.get S.tmp LI} end
	   condGetTmp:fun {$ LI DefVal} {TmpDict.condGet S.tmp LI DefVal} end
	   memberTmp:fun {$ LI} {TmpDict.member S.tmp LI} end
	   removeTmp:proc {$ LI} {TmpDict.remove S.tmp LI} end
	   %% contexts
	   createContext:fun {$} {New Context.'class' init(S)} end
	   expireLinksAfter:proc {$ Milliseconds}
			       {{New Context.'class' init(S)} expireAfter(Milliseconds)}
			    end
	   expireLinksAfterInactivity:proc {$ Milliseconds}
					 {{New Context.'class' init(S)}
					  expireAfterInactivity(Milliseconds)}
				      end
	   %% request
	   request:S.request
	   %%
	   regenerateSessionId:proc{$}
				  NewSessionId = {NewId State}
			       in
				  {State.sessions move(@(S.id) NewSessionId) _}
				  {S.setId NewSessionId}
				  (S.idChanged) := true %% -> session cookie will be send
			       end
	   %% cookies
	   hasCookie:fun {$ Key}
			case {GetCookieExt Key} of just(...) then true else false end
		     end
	   getCookie:fun {$ Key}
			case {GetCookieExt Key} of just(C) then C.value
			else raise unknownCookie(key:Key) end end
		     end
	   getCookieExt:fun {$ Key}
			   case {GetCookieExt Key} of just(C) then C
			   else raise unknownCookie(key:Key) end end
			end
	   setCookie:SetCookie
	   %% logging
	   logTrace:Logger.trace
	   logError:Logger.error
	   )
       }
      }
   end
   end
   
   fun {ExternalInput Xs}
      externalInput(original:Xs
		    escaped:{Value.byNeed fun {$} {Html.escape Xs} end})
   end
   
   proc {Destroy Session}
      {Map.removeAll Session.closures}
      {PrivateDict.removeAll Session.private}
      {SharedDict.removeAll Session.shared}
      {TmpDict.removeAll Session.tmp}
   end
   
   fun {NewCache Config}
      {Cache.create {CondSelect Config sessionDuration 60*60*1000} Destroy}
   end
   
   fun {NewSession State Path Id}
      just(App) = {Routing.getApplication State Path}
      Closures = {Map.new}
      IdCell = {NewCell Id}
   in
      session(closures:Closures
	      removeClosure:proc {$ CId} {Map.remove Closures CId} end 
	      private:{PrivateDict.new}
	      shared:{SharedDict.new}
	      tmp:{TmpDict.new}
	      params:unit
	      interface:App.resources
	      state:State
	      contexts:{Context.newDict}
	      request:unit
	      id:IdCell
	      setId:local %% make id settable from subordinate space
		       IdPort
		    in
		       thread
			  for NewId in {Port.new $ IdPort} do
			     IdCell := NewId
			  end
		       end
		       proc {$ Id}
			  {Port.send IdPort Id}
		       end
		    end
	     )
   end

   %% Prepare a session to be used in a user-defined function,
   fun {PrepareSession State Logger Session Req Inputs}
      RealInputs
      S2
   in
      if {HasFeature Session futureParams} then
	 RealInputs = Session.futureParams
	 S2 = {Record.subtract Session futureParams}
      else
	 RealInputs = Inputs
	 S2 = Session
      end
      {AddInterface State Logger
       {AdjoinList S2
	[params#RealInputs
	 private#{PrivateDict.clone Session.private}
	 tmp#{TmpDict.new}
	 request#Req
	 idChanged#{NewCell false}
	 cookiesToSend#{NewCell nil}
	 contexts#{Context.cloneDict Session.contexts}
	]}
      }
   end
   
   fun {PrepareFutureSession Session Inputs}
      {AdjoinAt Session futureParams Inputs}
   end

   %% Session, Closure Id -> Maybe Closure
   fun {GetClosure Session ClId}
      case {Map.condGet Session.closures ClId nothing} of nothing then nothing
      [] C then just(C)
      end
   end
   
   fun {NewClosureId State Session}
      Id = {State.closureIdIssuer}
   in
      case {Map.member Session.closures Id} of false then Id
      else {NewClosureId State Session}
      end
   end

   %% Add a new closure to a session.
   proc {AddClosure
	 unit(closureId:ClosureId
	      space:Space
	      fork:Fork
	      app:App
	      functr:Functor
	      session:PSession
	      function:Function)}
      {Map.put PSession.closures ClosureId
       closure(space:Space
	       fork:Fork
	       app:App
	       functr:Functor
	       function:Function
	       session:PSession)}
      {Context.forAll PSession newClosure(ClosureId)}
   end
end
