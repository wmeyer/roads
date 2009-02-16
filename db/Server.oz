%%
%% A database server with an object interface.
%% Every server has exactly one database.
%% The server can be used from multiple threads (it's an active object).
%% Transaction are not supported, but you can use the batch method to run
%% a series of operations uninterrupted.
%% Select queries run concurrently.
%% (Use RemoteServer if you want the database to run in its own process.)
%%
functor
import
   Pickle Inspector
   Ops at 'Operations.ozf'
%   RemoteProcedure
export
   Create
   ShutDown
define
   SaveEvery = 4 %% seconds
   
   %% Create a new database and an active object to access it.
   %% If a file with the name 'Filename' already exists, 'Schema' is ignored
   %% and the contents of the file are used as the initial database state.
   fun {Create Schema Filename}
      DB = {NewCell {GetInitialDatabase Schema Filename}}
      LastSavedAt = {NewCell 0}
      IsCurrentlySaving = {NewCell false}
      local
	 SavePort
	 thread
	    for D#Sync in {NewPort $ SavePort} do
	       IsCurrentlySaving := true
	       {Wait {SaveDatabase D Filename}}
	       LastSavedAt := {Time.time}
	       IsCurrentlySaving := false
	       Sync = unit
	    end
	 end
      in
	 %% Set the new db instance and save it concurrently.
	 %% (Altough saving is done in a different process, we still use a
	 %% dedicated thread here because preparation for saving can also
	 %% take some time.)
	 proc {SetNewDB NewDB} %% does not guarantee saving except for shutDown
	    case NewDB of shutDown(D) then
	       DB := {Value.failed databaseShutDown}
	       {Wait {Port.sendRecv SavePort D}} %% save last version
	    else
	       Now = {Time.time} in
	       DB := NewDB
	       if {Not @IsCurrentlySaving} andthen Now - @LastSavedAt >= SaveEvery then
		  {Port.sendRecv SavePort NewDB _}
	       end
	    end
	 end
      end
      ServerPort
   in
      thread
	 for Request#Sync in {NewPort $ ServerPort} do
	    try
	       case Request of batch(Xs) then
		  {SetNewDB {FoldL Xs ApplyMessage @DB}}
	       else
		  {SetNewDB {ApplyMessage @DB Request}}
	       end
	    catch E then Sync = E %% log error
	    finally if {IsFree Sync} then Sync = unit end
	    end
	 end
      end
      {CreateInterface ServerPort}
   end

   %% Save the database within a different process.
   %% (Pickle.save seems to be a native procedure which cannot be interrupted.
   %%  Executing it in its own process really makes a difference with large
   %%  databases on a multi-core system. While the average performance does
   %%  not change much, the maximum time needed by single database operations
   %%  becomes considerable smaller. The overhead is quite small.)
   
   /* Unfortunately, this causes problems in 1.4.0 (silent crashes in Debug mode;
      random freezes in release mode)
   local
      PickleSave = {RemoteProcedure.make spec(moduleName:'Pickle' procedure:save)}
   in
      proc {SaveDatabase DB Filename ?Done}
	 {PickleSave [{Ops.stripTableTypes DB} Filename] Done}
      end
   end
   */
   
   proc {SaveDatabase DB Filename ?Done}
      {Pickle.save {Ops.stripTableTypes DB} Filename}
      Done = true
   end
   
   fun {LoadDatabase Filename}
      {Ops.addTableTypes {Pickle.load Filename}}
   end

   fun {GetInitialDatabase Schema Filename}
      try {LoadDatabase Filename}
      catch _ then {Ops.init Schema}
      end
   end

   ShutDownToken = {NewName}

   fun {CreateInterface ServerPort}
      proc {Call Msg}
	 case {Port.sendRecv ServerPort Msg} of unit then skip
	 [] E then raise E end
	 end
      end
      class Interface
	 feat
	    name
	 meth init
	    self.name = {NewName}
	 end
	 meth select(where:W<=nil having:H<=nil orderBy:OB<=nothing
		     result:?Rows ...)=Msg
	    S = {Record.subtractList Msg [where result orderBy having]} 
	    Query = query(select:S where:W having:H orderBy:OB)
	 in
	    %% select is asynchronous: the client can sync on the result in Rows
	    {Port.sendRecv ServerPort select(Query Rows) _}
	 end
	 meth selectSync(result:?Rows ...)=Msg
	    NewMsg = {Adjoin Msg select}
	 in
	    {self NewMsg}
	    {Wait Rows}
	 end
	 %% the update methods are synchronous; in this way, select can never deliver
	 %% outdated results
	 meth insert(What ?NewRow<=_)
	    {Call insert(What ?NewRow)}
	 end
	 meth update(What where:Where)
	    {Call update(What where:Where)}
	 end
	 meth delete(Table where:W<=nil)
	    {Call delete(Table where:W)}
	 end
	 meth batch(Xs)
	    {Call batch(Xs)}
	 end
	 meth !ShutDownToken
	    {Call ShutDownToken}
	 end
	 meth inspect
	    {Port.sendRecv ServerPort inspect _}
	 end
      end
   in
      {New Interface init}
   end

   fun {ApplyMessage DB Msg}
      case Msg of insert(What NewRow) then
	 {Ops.insert DB What ?NewRow}
      [] update(What where:Where) then
	 {Ops.update DB What Where}
      [] delete(Table where:Where) then
	 {Ops.delete DB Table Where}
      [] select(Query Rows) then
	 thread
	    try
	       {Ops.select DB Query Rows}
	    catch E then Rows = {Value.failed E}
	    end
	 end
	 DB
      [] !ShutDownToken then shutDown(DB)
      [] inspect then {Inspector.inspect DB} DB
      end
   end

   %% Saves the database and makes sure that nobody can use this server anymore,
   %% so the db cannot be changed by this server anymore.
   proc {ShutDown Server}
      {Server ShutDownToken}
   end
end
