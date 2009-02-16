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
   ClosureDict = Map

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
   fun {FromRequest State Req}
      case {SessionIdFromRequest Req} of nothing then nothing
      [] just(Id) then {GetSession State Id}
      end
   end
   
   fun {NewId State}
      Id = {State.sessionIdIssuer}
   in
      case {GetSession State Id} of nothing then Id
      else {NewId State}
      end
   end

   %% Add the user interface to a session.
   fun {AddInterface S}
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
	   )
       }
      }
   end

   fun {ExternalInput Xs}
      externalInput(original:Xs escaped:{Value.byNeed fun {$} {Html.escape Xs} end})
   end
   
   proc {Destroy Session}
      {ClosureDict.removeAll Session.closures}
      {PrivateDict.removeAll Session.private}
      {SharedDict.removeAll Session.shared}
      {TmpDict.removeAll Session.tmp}
   end
   
   fun {NewCache Config}
      {Cache.create {CondSelect Config sessionDuration 60*60*1000} Destroy}
   end
   
   fun {NewSession State Path Id}
      just(App) = {Routing.getApplication State Path}
      Closures = {ClosureDict.new}
   in
      {AddInterface
       session(closures:Closures
	       removeClosure:proc {$ CId} {ClosureDict.remove Closures CId} end 
	       private:{PrivateDict.new}
	       shared:{SharedDict.new}
	       tmp:{TmpDict.new}
	       params:unit
	       interface:App.resources
	       state:State
	       contexts:{Context.newDict}
	       request:unit
	       id:Id
	      )
      }
   end

   %% Prepare a session to be used in a user-defined function,
   fun {PrepareSession Session Req Inputs}
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
      {AddInterface
       {AdjoinList S2
	[params#RealInputs
	 private#{PrivateDict.clone Session.private}
	 tmp#{TmpDict.new}
	 request#Req
	]}
      }
   end
   
   fun {PrepareFutureSession Session Inputs}
      {AdjoinAt Session futureParams Inputs}
   end

   %% Session, Closure Id -> Maybe Closure
   fun {GetClosure Session ClId}
      case {ClosureDict.condGet Session.closures ClId nothing} of nothing then nothing
      [] C then just(C)
      end
   end
   
   fun {NewClosureId State Session}
      Id = {State.closureIdIssuer}
   in
      case {ClosureDict.member Session.closures Id} of false then Id
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
      {ClosureDict.put PSession.closures ClosureId
       closure(space:Space
	       fork:Fork
	       app:App
	       functr:Functor
	       function:Function
	       session:PSession)}
      {Context.forAll PSession newClosure(ClosureId)}
   end
end
