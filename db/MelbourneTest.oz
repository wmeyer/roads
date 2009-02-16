functor
import
   Server at 'RemoteServer.ozf'
   Property System Application OS
define
   BulkSize = 1000
   Filename = "Melbourne.dat"
   DB = {Server.create
	 schema(australia(id(type:int generated)
			  name firstName points licenseId
			 )
	       )
	 Filename
	}
   for NumObjects in [
		      %3000
		      %10000
		      30000
		      %100000
		     ] do
      StartTime = {Property.get 'time.total'}
      Delta
      NumBulks = NumObjects div BulkSize
   in
      {System.showInfo NumBulks#" bulks"}
      for J in 0..NumBulks-1 do
	 Bulk = {Map {List.number J*BulkSize+1 J*BulkSize+BulkSize 1}
		 fun {$ I}
		    insert(australia(name:{VirtualString.toString "Pilot "#I}
				     firstName:"Herkules"
				     points:I
				     licenseId:I)
			  )
		 end
		}
      in
	 {DB batch(Bulk)}
	 {System.printInfo {Length Bulk}#"."}
      end
      Delta = {Property.get 'time.total'} - StartTime
      {System.showInfo "Inserted "#NumObjects#" objects: "#Delta}
   end

/*   %% read all
   local
      StartTime = {Property.get 'time.total'}
      AllPilots = {DB select(australia('*') result:$)}
      Delta0 = {Property.get 'time.total'} - StartTime
      {System.showInfo "Select executed: "#Delta0}
      Sum = {NewCell 0}
      for P in AllPilots do
	 Sum := @Sum + P.australia.points
      end
      Delta = {Property.get 'time.total'} - StartTime
   in
      {System.showInfo "Read all objects: "#Delta}
      {System.show @Sum}
   end
   
   local
      %% delete all
      StartTime = {Property.get 'time.total'}
      {DB delete(australia)}
      Delta = {Property.get 'time.total'} - StartTime
   in
      {System.showInfo "Deleted all objects: "#Delta}
   end
  */ 
   {Server.shutDown DB}
   {OS.unlink Filename}
   {Application.exit 0}
end
