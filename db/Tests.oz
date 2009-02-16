functor
import
   OS System Application
   ServerT at 'RemoteServer.ozf'
define
   proc {AssertRaises Proc}
      try
	 {Proc}
	 fail
      catch database(...) then skip
     [] _ then fail
     end
   end
   
   fun {MakeRow TableRows}
      TRs = if {IsList TableRows} then TableRows else [TableRows] end
   in
      {FoldL TRs
       fun {$ R TR}
	  {AdjoinAt R {Label TR} TR}
       end
       row
      }
   end

   Log = System.showInfo
   
   Filename = "test_database.dat"

   fun {Setup}
      Schema =
      schema(customer(email(type:string) name city(references:city))
	     city(name(type:atom) country)
	     purchase(id(type:int generated) customer(references:customer))
	    )
   in
      {ServerT.create Schema Filename}
   end
   proc {TearDown Server}
      {ServerT.shutDown Server}
      {OS.unlink Filename}
   end

   Server = {Setup}
   try
      %% insert with existing foreign row
      {Server insert(city(name:rome country:italy))}
      {Server insert(city(name:newyork country:us))}
      {Server insert(customer(email:"hans@example.com" name:hans city:rome))}
      %% insert without existing foreign row
      {AssertRaises
       proc {$}
	  {Server insert(customer(email:"freddy@example.de" name:freddy city:berlin))}
       end}
      %% delete a row that is still referenced
      {AssertRaises
       proc {$} {Server delete(city where:[city(name) '=' rome])} end}
      %% try to update a key (in this case used as a foreign key, but that doesn't matter)
      {AssertRaises
       proc {$} {Server update(city(name:milano) where:[city(name) '=' rome])} end}
      %% try to update a foreign key to a non-existing value
      {AssertRaises
       proc {$}
	  {Server update(customer(city:naples)
			 where:[customer(email) '=' "hans@example.com"])}
       end}
      %% update a foreign key to an existing value
      {Server update(customer(city:newyork)
		     where:[customer(email) '=' "hans@example.com"])}
      {Server selectSync(customer(city)
		     where:[customer(email) '=' "hans@example.com"] result:$)}
      = [{MakeRow customer(city:newyork)}]
      {Server update(customer(city:rome)
		     where:[customer(email) '=' "hans@example.com"])}
      %% check auto generated key
      {Server insert(purchase(customer:"hans@example.com"))}
      {Server selectSync(purchase('*') result:$)}
      = [{MakeRow purchase(id:0 customer:"hans@example.com")}]
      {AssertRaises
       proc {$} {Server insert(purchase(id:1 customer:"hans@example.com"))} end}
      %% test aliases in where-clauses
      {Server select(customer(name(as:cn) city)
		     where:[customer(cn) '=' hans] result:$)}
      = [{MakeRow customer(cn:hans city:rome)}]
      %% delete a referencing row and then the referenced row
      {Server delete(purchase)}
      {Server delete(customer where:[customer(email) '=' "hans@example.com"])}
      {Server delete(city where:[city(name) '=' rome])}
      {Log done}
%      {Server inspect}
   finally
      {TearDown Server}
   end
   {Application.exit 0}
end
   