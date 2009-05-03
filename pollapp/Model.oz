functor
import
   DBServer at 'x-ozlib://wmeyer/db/RemoteServer.ozf'
   ActiveObject at 'x-ozlib://wmeyer/roads/appSupport/ActiveObject.ozf'
   MD5 at 'x-ozlib://wmeyer/sawhorse/pluginSupport/md5.so{native}'
   RandomBytesGenerator
   at 'x-ozlib://wmeyer/sawhorse/pluginSupport/RandomBytesGenerator.ozf'
export
   new:NewModel
define
   fun {NewModel}
      {ActiveObject.new Model init}
   end

   class Model
      feat
	 db
	 
      meth init
	 self.db = {CreateDBServer}
	 {self createAdmin}
      end

      meth shutDown
	 {DBServer.shutDown self.db}
      end
      
      meth hasVotedOn(Login PollId result:Res)
	 Res=
	 case {self.db
	       select(votedOn('*')
		      where:[[votedOn(user) '=' Login] 'AND' [votedOn(poll) '=' PollId]]
		      result:$)}
	 of nil then false
	 else true
	 end
      end
      
      meth vote(Login PollId OptionId result:Success)
	 Success =
	 if {self hasVotedOn(Login PollId result:$)} then false
	 else
	    {self.db insert(votedOn(user:Login poll:PollId))}
	    {self IncreaseVoteCount(OptionId)}
	    true
	 end
      end
      
      meth IncreaseVoteCount(OptionId)
	 VoteCount in
	 {self.db select(option(votes) where:[option(id) '=' OptionId]
			 result:[option(votes:?VoteCount)])}
	 {self.db update(option(votes:VoteCount+1)
			 where:[option(id) '=' OptionId])}
      end
      
      meth allPolls(result:Rows)
	 {self.db select(poll(id question)
			 result:?Rows)}
      end

      meth getPoll(Id result:P)
	 Rows
      in
	 {self.db select(poll(question)
			 where:[poll(id) '=' Id]
			 result:Rows)}
	 P = case Rows of [R] then just(R)
	     [] nil then nothing
	     end
      end

      meth getOptionsOfPoll(PollId result:As)
	 {self.db select(option('*') where:[option(poll) '=' PollId]
			 result:?As)}
      end

      meth createPoll(Question Options result:?NewId)
	 NewId = {self.db insert(poll(question:Question) $)}.id
	 for A in Options do
	    {self.db insert(option(poll:NewId text:A votes:0))}
	 end
      end

      meth deletePoll(Id)
	 {self.db delete(votedOn where:[votedOn(poll) '=' Id])}
	 {self.db delete(option where:[option(poll) '=' Id])}
	 {self.db delete(poll where:[poll(id) '=' Id])}
      end

      meth createAdmin
	 if {self.db select(user(login) where:[user(isAdmin) '=' true] result:$)} == nil
	 then
	    {self createUser("Admin" "Admin" true result:_)}
	 end
      end
      
      meth createUser(Login Password IsAdmin<=false result:User)
	 User =
	 case {self.db select(user('*') where:[user(login) '=' Login] result:$)}
	 of [_] then nothing
	 [] nil then
	    Salt = {SaltGenerator}
	    Hash = {EncryptPassword Password Salt}
	 in
	    {self.db insert(user(login:Login password:Hash salt:Salt isAdmin:IsAdmin))}
	    just(user(login:Login isAdmin:IsAdmin))
	 end
      end

      meth loginUser(Login Password result:User)
	 User =
	 case {self.db select(user('*') where:[user(login) '=' Login] result:$)}
	 of [user(password:Hash isAdmin:IsAdmin salt:Salt ...)] then
	    if {EncryptPassword Password Salt} == Hash then
	       just(user(login:Login isAdmin:IsAdmin))
	    else
	       nothing
	    end
	 [] nil then nothing
	 end
      end

      meth allNonAdmins(result:Rows)
	 {self.db select(user(login) where:[user(isAdmin) '=' false]
			 result:?Rows)}
      end

      meth makeAdmin(Login)
	 {self.db update(user(isAdmin:true) where:[user(login) '=' Login])}
      end
   end
   
   SaltGenerator = {RandomBytesGenerator.create 4}

   fun {EncryptPassword Password Salt}
      {MD5.createHash {Append Salt Password}}
   end
   
   fun {CreateDBServer}
      DBSchema =
      schema(poll(id(type:int generated)
		  question
		 )
	     option(id(type:int generated)
		    poll(references:poll)
		    text
		    votes)
	     user(login(type:string)
		  password
		  salt
		  isAdmin
		 )
	     votedOn(user(type:string references:user)
		     poll(type:int references:poll)
		     primaryKey:user#poll
		    )
	    )
   in
      {DBServer.create DBSchema 'PollApp.dat'}
   end
end
