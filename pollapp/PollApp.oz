functor
import
   DBServer at 'x-ozlib://wmeyer/db/Server.ozf'
   Model
   System
export
   Config
   Init
   ShutDown
   Before
   After
define
   Config =
   config(functors:unit('':'x-ozlib://wmeyer/pollapp/ShowPolls.ozf'
			'admin':'x-ozlib://wmeyer/pollapp/Admin.ozf'
		       )
	  pagesExpireAfter:0
	 )

   fun {Init}
      Db = {DBServer.create
	    schema(poll(id(type:int generated)
			question
		       )
		   answer(id(type:int generated)
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
	    'PollApp.dat'}
      M = {Model.new Db}
   in
      {M createAdmin}
      session(db:Db
	      model:M
	     )
   end

   proc {ShutDown Session}
      {System.showInfo "shutting down PollApp."}
      {DBServer.shutDown Session.db}
   end

   fun {Before Session Fun}
      IsLoginPage = {Session.condGet loginInProgress false}
      User = {Session.condGetShared user none}
   in
      if IsLoginPage then Fun
      elseif User == none then fun {$ Session} {Login Session Fun} end
      else Fun
      end
   end
   
   fun {After Session Doc}
      User = {Session.condGetShared user none}
   in
      if User == none then
	 html(
	    body(onLoad:"if(window.document.forms[0]&&window.document.forms[0].elements[0])"
		 #" window.document.forms[0].elements[0].focus();"
		 Doc))
      else
	 html(
	    head(title("Show polls")
		 style(type:"text/css"
		       css(a(':link') 'text-decoration':none)
		       css(a(':visited') 'text-decoration':none)
		       css(a(':active') 'text-decoration':none)
		       css(a(':hover') 'text-decoration':underline)
		      )
		)
	    body(
	       'div'(h3("Poll App")
		     hr
		     Doc
		     hr
		     a(href:url('functor':admin function:'') "Admin")
		     "&nbsp;"
		     a(href:url('functor':'' function:showAll) "View all polls")
		     "&nbsp;"
		     a(href:Logout "Logout "#User.login)
		    )
	       )
	    )
      end
   end

   fun {Logout Session}
      {Session.removeShared user}
      "Good bye!"
   end

   fun {Login Session Fun}
      {Session.set loginInProgress true}
      'div'(h2("Login existing user")
	    {LoginForm Fun loginUser "Could not login." false}
	    h2("New user")
	    {LoginForm Fun createUser "Could not create user" true}
	   )
   end

   fun {LoginForm Fun Method FailureText DoublePassword}
      L Password1 Password2
   in
      form(table(
	      tr(td(label('for':"Login" "Login: "))
		 td(input(type:text id:"Login" bind:L
			  validate:length_in(4 12))))
	      tr(td(label('for':"Password" "Password: "))
		 td(input(type:password id:"Password" bind:Password1
			  validate:length_in(5 12))))
	   if DoublePassword then
	      tr(
		 td(label('for':"passwordAgain" "Repeat password: "))
		 td(input(type:password id:"passwordAgain" bind:Password2))
		 )
	   else tr("")
	   end)
	   input(type:submit value:"Login")
	   action:fun {$ Session}
		     if {Not DoublePassword}
			orelse Password1.original == Password2.original then
			case {Session.model Method(L.escaped Password1.original result:$)}
			of just(User) then
			   {Session.set loginInProgress false}
			   {Session.setShared user User}
			   {Fun Session}
			[] nothing then
			   html(body(p(FailureText) br
				     a("Try again" href:fun {$ S} {Login S Fun} end)
				    ))
			end
		     else
			html(
			   body(
			      p("Passwords do not match.") br
			      a(href:Login "Try again")
			      )
			   )
		     end
		  end
	   method:post
	  )
   end
end
