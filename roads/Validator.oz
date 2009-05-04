functor
import
   Util(intercalate:Intercalate) at 'x-ozlib://wmeyer/sawhorse/common/Util.ozf'
   Regex at 'x-oz://contrib/regex'
export
   Create
define
   %% Evaluate regexs in a toplevel threads (not allowed in spaces).
   RegexPort
   thread
      for (RE#Txt)#Res in {Port.new $ RegexPort} do
	 {Regex.search RE Txt Res}
      end
   end
   
   class Validator
      feat id

      attr val
	 
      meth init(Id Val)
	 self.id = Id
	 val := Val
      end

	    
      meth length_in(Min Max result:R)
	 L = {Length @val}
      in
	 R =
	 if L >= Min andthen L =< Max then true
	 else
	    'false'("The value of field \""#self.id#"\" must be between "#Min#
		    " and "#Max#" characters long.")
	 end
      end

      meth length_is(L result:R)
	 R =
	 if {Length @val} == L then true
	 else
	    'false'("The value of field \""#self.id
		    #"\" must be exactly "#L#" characters long.")
	 end
      end

      meth int(result:R)
	 IsInt = try {String.toInt @val _} true catch _ then false end
      in
	 R =
	 if IsInt then true
	 else
	    'false'("The value of field \""#self.id#"\" must be an integer value.")
	 end
      end

      meth int_in(Min Max result:R)
	 R =
	 try
	    V = {String.toInt @val}
	 in
	    if V >= Min andthen V =< Max then true
	    else
	       'false'("The value of field \""#self.id#"\" must be between "#
		       Min#" and "#Max#".")
	    end
	 catch _ then
	    'false'("The value of field \""#self.id#"\" must be an integer value.")
	 end
      end
      
      meth float(result:R)
	 IsFloat = try {String.toFloat @val _} true catch _ then false end
      in
	 R =
	 if IsFloat then true
	 else
	    'false'("The value of field \""#self.id
		    #"\" must be an floating point value.")
	 end
      end

      meth is(X result:R)
	 R =
	 if @val == X then true
	 else
	    %% don't reveal the value of X here. might be security related!
	    'false'("The value of field \""#self.id#"\" is not as expected.")
	 end
      end
	    
      meth one_of(result:R ...)=Msg
	 Xs = {Map {Filter {Arity Msg} fun {$ I} I\=result end} fun {$ I} Msg.I end}
      in
	 R =
	 if {Member @val Xs} then true
	 else
	    'false'("The value of field \""#self.id#"\" must be one of {"#
		    {Intercalate
		     {Map Xs fun {$ X} {VirtualString.toString "\""#X#"\""} end} ", "}#"}.")
	 end
      end

      meth not_one_of(result:R ...)=Msg
	 Xs = {Map {Filter {Arity Msg} fun {$ I} I\=result end} fun {$ I} Msg.I end}
      in
	 R =
	 if {Not {Member @val Xs}} then true
	 else
	    'false'("The value of field \""#self.id#"\" must not be one of {"#
		    {Intercalate
		     {Map Xs fun {$ X} {VirtualString.toString "\""#X#"\""} end} ", "}#"}.")
	 end
      end

      meth regex(RE result:R)
	 R =
	 case {Port.sendRecv RegexPort RE#@val}
	 of match(...) then true
	 [] false then 'false'("The value of field \""#self.id
			       #"\" must match the regular expression \""#RE#"\".")
	 end
      end

      meth 'true'(result:R)
	 R = true
      end

      meth list(X result:R)
	 Vs = @val
      in
	 R =
	 for V in Vs default:true return:R do
	    Res
	    SpecWithRes = {AdjoinAt X result Res}
	 in
	    val := V
	    {self SpecWithRes}
	    if Res \= true then {R Res} end
	 end
      end
   end
   
   fun {Create Spec}
      fun {$ Id Val}
	 Specs = if {List.is Spec} then Spec else [Spec] end
	 V = {New Validator init(Id Val)}
      in
	 for S in Specs return:R default:true do
	    Res
	    SpecWithRes = {AdjoinAt S result Res}
	 in
	    {V SpecWithRes}
	    if Res \= true then {R Res} end
	 end
      end
   end
end
