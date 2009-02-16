functor
import
   Support(divMap:DivMap divMapInd:DivMapInd)
export
   '':Admin
   Create
   Delete
   MakeAdmin
   Before
   After
define
   fun {Admin Session}
      h1("Administration")
   end

   fun {Create Session}
      Question
   in
      'div'(h1("Create a poll: Question")
	    form(label('for':"Question" "Enter the question: ")
		 input(type:text id:"Question" bind:Question
		       validate:length_in(1 1000))
		 input(type:submit value:"Submit question")
		 action:fun {$ S}
			   {S.set question Question.escaped}
			   {EnterOptions S}
			end
		 method:post
		)
	   )
   end

   fun {EnterOptions Session}
      Question = {Session.get question}
      Answers = {Session.condGet answers nil}
      NewAnswer
   in
      'div'(
	 h1("Create a poll: Options")
	 "Question: "#Question br
	 {ShowAnswers Answers} br
	 form(
	    label('for':"Option" "Enter a new option: ")
	    input(type:text value:"" bind:NewAnswer id:"Option"
		  validate:length_in(1 1000))
	    input(type:submit name:"submit" value:"Submit option") br
	    method:post
	    action:fun {$ S}
		      {S.set answers {Append Answers [NewAnswer.escaped]}}
		      {EnterOptions S}
		   end
	    a("Done" href:fun {$ S}
			     NewPollId = {S.model createPoll(Question Answers result:$)}
			  in
			     'div'("Poll added. " br
				   a(href:url('functor':'' function:show
					      extra:"?pollid="#NewPollId)
				     "View new poll")
				  )
			  end
	     )
	    )
	 )
   end

   fun {ShowAnswers Answers}
      {DivMapInd Answers
       fun {$ I A}
	  'div'("Option: \"" b(A) "\"  "
		a("(Remove this option)" href:fun {$ S}
						 {S.set answers {RemoveNth Answers I}}
						 {EnterOptions S}
					      end
		 )
	       )
       end
      }
   end
   
   fun {RemoveNth Xs I}
      {List.filterInd Xs fun {$ J _} J \= I end}
   end

   fun {Delete Session}
      'div'(h1("Delete polls")
	    {DivMap {Session.model allPolls(result:$)}
	     fun {$ Poll}
		'div'(a("Delete \""#Poll.question#"\""
			href:fun {$ S}
				'div'("Really? "
				      a("Yes"
					href:fun {$ S}
						{Session.model deletePoll(Poll.id)}
						{Delete Session}
					     end
				       )
				      " "
				      a("No" href:Delete)
				     )
			     end
		       ))
	     end
	    }
	   )
   end

   fun {MakeAdmin S}
      'div'(h1("Designate Admin")
	    {DivMap {S.model allNonAdmins(result:$)}
	     fun {$ user(login:L)}
		'div'(a("User: "#L
			href:fun {$ S}
				{S.model makeAdmin(L)}
				{MakeAdmin S}
			     end
		       ))
	     end
	    }
	   )
   end

   fun {IsAdmin S}
      User = {S.condGetShared user unit}
   in
      {CondSelect User isAdmin false}
   end
   
   fun {Before S Fun}
      if {IsAdmin S} then Fun
      else fun {$ Session} p("Permission denied") end
      end
   end

   fun {After S Doc}
      if {IsAdmin S} then
	 html(
	    head(title("Administrate polls"))
	    body(onLoad:"if(window.document.forms[0]&&window.document.forms[0].elements[0])"
		 #" window.document.forms[0].elements[0].focus();"
		 'div'(
		    h3("Administrate polls")
		    hr
		    Doc
		    hr
		    a(href:url('functor':admin function:create) "Create a poll")
		    "&nbsp;"
		    a(href:url('functor':admin function:delete) "Delete a poll")
		    "&nbsp;"
		    a(href:url('functor':admin function:makeAdmin) "Designate an admin")
		    "&nbsp;"
		    a(href:url('functor':'' function:showAll) "View all polls")
		    )
		)
	    )
      else
	 html(body(Doc))
      end
   end
end
