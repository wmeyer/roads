functor
import
   Pickle
   MD5 at 'x-ozlib://wmeyer/sawhorse/pluginSupport/md5.so{native}'
   RandomBytesGenerator
   at 'x-ozlib://wmeyer/sawhorse/pluginSupport/RandomBytesGenerator.ozf'
export
   new:NewModel
define
   SaltGenerator = {RandomBytesGenerator.create 4}

   fun {EncryptPassword Password Salt}
      {MD5.createHash {Append Salt Password}}
   end
   
   class Model
      feat
	 db
	 
      meth init(DB)
	 self.db = DB
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
	 {self.db select(answer(votes) where:[answer(id) '=' OptionId]
			 result:[row(answer:answer(votes:VoteCount))])}
	 {self.db update(answer(votes:VoteCount+1)
			 where:[answer(id) '=' OptionId])}
      end
      
      meth allPolls(result:Rows)
	 Rs
      in
	 {self.db select(poll(id question)
			 result:Rs)}
	 Rows = {Map Rs fun {$ row(poll:P)} P end}
      end

      meth getPoll(Id result:P)
	 Rows
      in
	 {self.db select(poll(question)
			 where:[poll(id) '=' Id]
			 result:Rows)}
	 P = case Rows of [R] then just(R.poll)
	     [] nil then nothing
	     end
      end

      meth getAnswersOfPoll(PollId result:As)
	 Rows in
	 {self.db select(answer('*') where:[answer(poll) '=' PollId]
			 result:Rows)}
	 As = {Map Rows fun {$ row(answer:A)} A end}
      end

      meth createPoll(Question Answers result:?NewId)
	 NewId = {self.db insert(poll(question:Question) $)}.id
	 for A in Answers do
	    {self.db insert(answer(poll:NewId text:A votes:0))}
	 end
      end

      meth deletePoll(Id)
	 {self.db delete(votedOn where:[votedOn(poll) '=' Id])}
	 {self.db delete(answer where:[answer(poll) '=' Id])}
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
	 of [row(user:user(password:Hash isAdmin:IsAdmin salt:Salt ...))] then
	       if {EncryptPassword Password Salt} == Hash then
		  just(user(login:Login isAdmin:IsAdmin))
	       else
		  nothing
	       end
	 [] nil then nothing
	 end
      end

      meth allNonAdmins(result:Rows)
	 Rs
      in
	 {self.db select(user(login) where:[user(isAdmin) '=' false]
			 result:Rs)}
	 Rows = {Map Rs fun {$ row(user:U)} U end}
      end

      meth makeAdmin(Login)
	 {self.db update(user(isAdmin:true) where:[user(login) '=' Login])}
      end
   end
   
   fun {NewModel Db}
      %% By making the model an active model, its operations become atomic!
      {NewActive Model init(Db)}
   end

   proc {MakeNeeded X}
      {Wait X}
      if {Record.is X} then
	 {Record.forAll X MakeNeeded}
      end
   end
   
   fun {Decouple X}
      {MakeNeeded X}
      {Pickle.unpack {Pickle.pack X}}
   end
   
   fun {NewActive Class Init}
      P
      thread
	 O = {New Class Init}
      in
	 for Msg#Return in {Port.new $ P} do
	    Msg2 = if {HasFeature Msg result} then {AdjoinAt Msg result Return} else Msg end
	 in
	    {O Msg2}
	 end
      end
   in
      proc {$ Msg}
	 Result = {CondSelect Msg result _}
	 Msg2 = if {HasFeature Msg result} then {AdjoinAt Msg result unit} else Msg end
      in
	 {Port.sendRecv P {Decouple Msg2} Result}
      end
   end
end
