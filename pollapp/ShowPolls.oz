functor
import
   Support(ul:UL)
export
   '':ShowAll
   ShowAll
   Show
define
   %% All polls as a list of links.
   fun {ShowAll Session}
      'div'(h1("All polls:")
	    {UL
	     {Map {Session.model allPolls(result:$)}
	      fun {$ P}
		 a(href:url(function:show params:unit(pollid:P.id))
		   "Poll: "#P.question
		  )
	      end
	     }
	    }
	   )
   end

   %% Bookmarkable function to show a specific vote.
   fun {Show Session}
      {Session.validateParameters [pollid(validate:int)]}
      PollId = {StringToInt {Session.getParam pollid}.original}
   in
      {ShowPoll Session PollId}
   end

   %% Show a specific poll. With vote links if user did not yet vote.
   fun {ShowPoll Session PollId}
      case {Session.model getPoll(PollId result:$)}
      of nothing then "Poll not found"
      [] just(Poll) then
	 Options = {Session.model getOptionsOfPoll(PollId result:$)}
	 User = {Session.getShared user}.login
	 UserHasVoted = {Session.model hasVotedOn(User PollId result:$)}
      in
	 'div'(h1(Poll.question)
	       if UserHasVoted then {ShowVotedOptions Options}
	       else {ShowOptionsForVoting Options}
	       end
	      )
      end
   end
   
   fun {ShowOptionsForVoting Options}
      {UL
       {Map Options
	fun {$ option(id:OptionId text:Text poll:PollId ...)}
	   a(Text
	     href:fun {$ S}
		     UserName = {S.getShared user}.login
		  in
		     if {S.model vote(UserName PollId OptionId result:$)} then
			{ShowPoll S PollId}
		     else
			"You already voted on this."
		     end
		  end
	    )
	end
       }
      }
   end

   fun {ShowVotedOptions Options}
      {UL
       {Map Options
	fun {$ option(text:Text votes:VoteCount ...)}
	   Text#": "#VoteCount#" vote(s)"
	end
       }
      }
   end
end
