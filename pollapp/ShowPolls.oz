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
	 Answers = {Session.model getAnswersOfPoll(PollId result:$)}
	 UserHasVoted = {Session.model hasVotedOn({Session.getShared user}.login
						  PollId
						  result:$)}
      in
	 'div'(h1(Poll.question)
	       if UserHasVoted then {ShowVotedAnswers Answers}
	       else {ShowAnswersForVoting Answers}
	       end
	      )
      end
   end
   
   fun {ShowAnswersForVoting Answers}
      {UL
       {Map Answers
	fun {$ answer(id:AId text:ATxt poll:PollId ...)}
	   a(ATxt
	     href:fun {$ S}
		     UserName = {S.getShared user}.login
		  in
		     if {S.model vote(UserName
				      PollId AId
				      result:$)}
		     then
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

   fun {ShowVotedAnswers Answers}
      {UL
       {Map Answers
	fun {$ answer(text:ATxt votes:V ...)}
	   'div'(ATxt#": "#V#" votes"
		 br
		)
	end
       }
      }
   end
end
