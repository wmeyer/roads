declare
[Roads] = {Module.link ['x-ozlib://wmeyer/roads/Roads.ozf']}

Passwords = unit(john:"guitar"
		 paul:"bass"
		 george:"guitar"
		 ringo:"drums"
		)

fun {GetUserName ?UserName}
   input(type:text validate:length_in(4 10) bind:UserName)
end

fun {CheckPassword User}
   input(type:password
	 name:password
	 validate:fun {$ _ X}
		     Pwd = {CondSelect Passwords {String.toAtom User.escaped} {NewName}}
		  in
		     if X == Pwd then true
		     else 'false'("Wrong password or user name.")
		     end			
		  end)
end

fun {Login Session}
   UserName
in
   form({GetUserName ?UserName}
	{CheckPassword UserName}
	input(type:submit)
	method:post
	action:fun {$ Session}
		  p("Hello "#UserName#"! You logged in successfully.")
	       end
       )
end

in

{Roads.registerFunction login Login}
{Roads.run}

