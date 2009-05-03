%%
%% A database server object that runs in its own process.
%% The interface is compatible to Server.oz.
%%
functor
import
   Remote
export
   Create
   ShutDown
   ShutDownAll
define
   local
      Manager = {New Remote.manager init}
      Servers = {NewDictionary}
   in
      fun {Create Schema Filename}
	 ServerObject
	 ShutDown Finished
	 RemoteF = functor
		   import
		      Server at 'x-ozlib://wmeyer/db/Server.ozf'
		      Application
		   define
		      !ServerObject = {Server.create Schema Filename}
		      {Wait ShutDown}
		      {Server.shutDown ServerObject}
		      !Finished = unit
		      {Application.exit 0}
		   end
      in
	 thread {Manager apply(RemoteF)} end
	 Servers.(ServerObject.name) := ShutDown#Finished
	 ServerObject
      end

      proc {ShutDownSync ShutDown#Finished}
	 ShutDown = unit
	 {Wait Finished}
      end
      
      proc {ShutDownAll}
	 {ForAll {Dictionary.items Servers} ShutDownSync}
	 {Dictionary.removeAll Servers}
	 {Manager close}
      end

      proc {ShutDown ServerObject}
	 {ShutDownSync Servers.(ServerObject.name)}
	 {Dictionary.remove Servers ServerObject.name}
      end
   end
end
