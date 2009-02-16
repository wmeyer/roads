functor
import
   Support(divMap:DivMap)
export
   '':ShowAll
   ShowAll
   Show
define
   fun {ShowAll Session}
      'div'(h1("All polls:")
	    {DivMap {Session.model allPolls(result:$)}
	     fun {$ P}
		'div'(a(href:url(function:show extra:"?pollid="#P.id)
			"Poll: "#P.question
		       ))
	     end
	    }
	   )
   end

   fun {Show Session}
      if {Not {Session.memberParam pollid}} then
	 'div'("No poll specified." br
	       a(href:ShowAll "Show all polls")
	      )
      else
	 {ShowPoll Session {StringToInt {Session.getParam pollid}.original}}
      end
   end

   
   fun {ShowPoll Session PollId}
      case {Session.model getPoll(PollId result:$)}
      of nothing then "Poll not found"
      [] just(Poll) then
	 Answers = {Session.model getAnswersOfPoll(PollId result:$)}
      in
	 'div'(h1(Poll.question)
	       if {Session.model hasVotedOn({Session.getShared user}.login PollId result:$)}
	       then
		  {ShowVotedAnswers Answers}
	       else
		  {ShowAnswersToVote Answers}
	       end
	      )
      end
   end
   
   fun {ShowAnswersToVote Answers}
      {DivMap Answers
       fun {$ answer(id:AId text:ATxt poll:PollId ...)}
	  'div'(a(ATxt
		  href:fun {$ S}
			  if {Not {S.model vote({S.getShared user}.login PollId AId result:$)}}
			  then
			     "You already voted on this."
			  else
			     {ShowPoll S PollId}
			  end
		       end
		 )
		br
	       )
       end
      }
   end

   fun {ShowVotedAnswers Answers}
      {DivMap Answers
       fun {$ answer(text:ATxt votes:V ...)}
	  'div'(ATxt#": "#V#" votes"
		br
	       )
       end
      }
   end
end
