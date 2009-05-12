%%
%% A session holds all state that is specific to a sequence of function calls.
%% Only some of the state is shared among all function calls within a user session.
%% The input to user-defined functions is NOT this session data, but only the public
%% interface.
%%
functor
import
   Context at 'x-ozlib://wmeyer/roads/Context.ozf'
   Routing at 'x-ozlib://wmeyer/roads/Routing.ozf'
   Map at 'x-ozlib://wmeyer/sawhorse/pluginSupport/Map.ozf'
   Html at 'x-ozlib://wmeyer/sawhorse/common/Html.ozf'
   NonSituatedDictionary
   at 'x-ozlib://wmeyer/sawhorse/pluginSupport/NonSituatedDictionary.ozf'
   Cache(create) at 'x-ozlib://wmeyer/sawhorse/pluginSupport/Cache.ozf'
   Validator(create) at 'x-ozlib://wmeyer/roads/Validator.ozf'
   Toplevel at 'x-ozlib://wmeyer/roads/Toplevel.ozf'
   OsTime OS
   Util(formatTime:FormatTime) at 'x-ozlib://wmeyer/sawhorse/common/Util.ozf'
   Cookie(toHeader) at 'x-ozlib://wmeyer/sawhorse/pluginSupport/Cookie.ozf'
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
      case {Req.condGetCookie SessionCookie nothing} of nothing then nothing
      [] SessionString then
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

   fun {GetParamAsList S LI}
      P = if {HasFeature S.params LI} then
	     case S.params.LI of list(Xs) then list(Xs)
	     [] X then list([X])
	     end
	  else list(nil)
	  end
   in
      {ExternalInput P}
   end

   Time = {Toplevel.makeFun0 OS.time}
   GMTime = {Toplevel.makeFun1 OsTime.gmtime}
   TLCellAssign = {Toplevel.makeProc0 Cell.assign}
   
   fun {PostProcessCookie DefaultPath CookieName#C0}
      C1 = if {VirtualString.is C0} then cookie(value:C0) else C0 end
      %% give it a name
      C2 = {AdjoinAt C1 name CookieName}
      %% convert virtual string to string
      C3 = {AdjoinAt C2 value {VirtualString.toString C1.value}}
      %% convert expires if given as seconds
      C4 = if {HasFeature C3 expires} andthen {Int.is C3.expires} then
	      {AdjoinAt C3 expires {FormatTime {GMTime {Time} + C3.expires}}}
	   else C3
	   end
   in
      %% add default path
      {AdjoinAt C4 path {CondSelect C4 path DefaultPath}}
   end
	   
   %% Add the user interface to a session.
   fun {AddInterface State Logger S}
      proc {AddCookie Key ValOrDesc}
	 {AddHeader
	  {Cookie.toHeader
	   {PostProcessCookie S.defaultCookiePath Key#ValOrDesc}}}
      end
      proc {AddHeader H}
	 (S.headersToSend) := {VirtualString.toString H}|@(S.headersToSend)
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
	   getParamAsList:fun {$ LI}
			     {GetParamAsList S LI}
			  end
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
				  {TLCellAssign S.id NewSessionId}
				  (S.idChanged) := true %% -> session cookie will be send
			       end
	   %% response
	   response:response(addCookie:AddCookie addHeader:AddHeader)
	   %% logging
	   logTrace:Logger.trace
	   logError:Logger.error
	   )
       }
      }
   end
   
   fun {ExternalInput X}
      externalInput(original:case X of list(Ys) then Ys else X end
		    escaped:{Value.byNeed
			     fun {$}
				case X of list(Ys) then {List.map Ys Html.escape}
				else {Html.escape X}
				end
			     end
			    }
		   )
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
	     )
   end

   %% Prepare a session to be used in a user-defined function,
   fun {PrepareSession State Logger Session Req Inputs DefaultCookiePath}
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
	 headersToSend#{NewCell nil}
	 defaultCookiePath#DefaultCookiePath
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
