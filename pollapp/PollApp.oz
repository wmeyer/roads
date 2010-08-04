functor
import
   Model
   JavaScriptCode
   Support(table:Table)
export
   AppName
   Functors
   PagesExpireAfter
   UseTokenInLinks
   Init
   ShutDown
   Before
   After
define
   AppName = "pollapp"
   
   Functors = unit('':'x-ozlib://wmeyer/pollapp/ShowPolls.ozf'
		   'admin':'x-ozlib://wmeyer/pollapp/Admin.ozf'
		  )
   PagesExpireAfter = 0
   UseTokenInLinks = true
   
   fun {Init}
      session(model:{Model.new})
   end

   proc {ShutDown Session}
      {Session.model shutDown}
   end
   
   %% Authentication
   fun {Before Session Fun}
      IsLoggedIn = {Session.memberShared user}
      LoggingIn = {Session.condGet loginInProgress false}
   in
      if IsLoggedIn orelse LoggingIn then Fun
      else %% let user log in and then show original page
	 fun {$ Session} {Login Session Session.request.originalURI} end
      end
   end
   
   %% Add list of links for logged-in users
   fun {After Session Doc}
      IsLoggedIn = {Session.memberShared user}
   in
      if {Not IsLoggedIn} then
	 html(
	    head(title("Poll application"))
	    body(onLoad:JavaScriptCode.activateFirstForm
		 Doc))
      else
	 html(
	    head(title("Show polls")
		 style(type:"text/css"
		       css(a(':link') 'text-decoration':none)
		       css(a(':visited') 'text-decoration':none)
		       css(a(':active') 'text-decoration':none)
		       css(a(':hover') 'text-decoration':underline)
		       css(a(linkbar) margin:"5px" 'background-color':"#f0f0ff")
		      )
		)
	    body(
	       'div'(h3("Poll App")
		     hr
		     Doc
		     hr
		     'div'(a("Admin" href:url('functor':admin function:'') 'class':linkbar)
			   a("View all polls"
			     href:url('functor':'' function:showAll) 'class':linkbar)
			   a("Logout "#{Session.getShared user}.login
			     href:Logout 'class':linkbar)
			  )
		    )
	       )
	    )
      end
   end

   fun {Logout Session}
      {Session.removeShared user}
      redirect(303 url('functor':'' function:''))
   end
   
   fun {Login Session OriginalURL}
      {Session.set loginInProgress true}
      'div'({LoginExistingUser OriginalURL}
	    {LoginNewUser OriginalURL}
	   )
   end

   fun {LoginExistingUser Cont}
      UserName Password
   in
      {LoginForm "Login existing user"
       [ {EnterUserName ?UserName}
	 {EnterPassword "Password: " password ?Password}
       ]
       fun {$ Session}
	  case {Session.model loginUser(UserName.escaped
					Password.original
					result:$)}
	  of just(User) then {LoginSuccess Session User Cont}
	  [] nothing then {LoginError "Could not login." Cont}
	  end
       end
      }
   end

   fun {LoginNewUser Cont}
      UserName Password1 Password2
   in
      {LoginForm "New user"
       [ {EnterUserName ?UserName}
	 {EnterPassword "Password:" password ?Password1}
	 {EnterPassword "Repeat password:" repeat ?Password2}
       ]
       fun {$ Session}
	  if Password1.original == Password2.original then
	     case {Session.model createUser(UserName.escaped
					    Password1.original
					    result:$)}
	     of just(User) then {LoginSuccess Session User Cont}
	     [] nothing then {LoginError "Could not create user." Cont}
	     end
	  else {LoginError "Passwords do not match." Cont}
	  end
       end
      }
   end

   fun {LoginForm Title Rows Action}
      'div'(
	 h2(Title)
	 form({Table Rows}
	      input(type:submit value:"Login")
	      method:post
	      action:Action
	     )
	 )
   end

   fun {LoginSuccess Session User Cont}
      {Session.set loginInProgress false}
      {Session.setShared user User}
      redirect(303 Cont)
   end

   fun {LoginError Text Cont}
      html(body(p(Text)
		a("Try again" href:fun {$ S} {Login S Cont} end)
	       ))
   end

   fun {EnterUserName ?UserName}
      [label('for':"Login" "Login ")
       input(type:text id:"Login" bind:UserName
	     validate:length_in(4 12))
      ]
   end

   fun {EnterPassword Label Id ?Password}
      [label('for':Id Label)
       input(type:password id:Id bind:Password
	     validate:length_in(5 12))
      ]
   end
end
