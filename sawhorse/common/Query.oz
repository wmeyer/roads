%%
%% Decode a string of key value pairs as in HTTP requests.
%%
functor
export
   Parse
   PercentDecode
   PercentEncode
define
   fun {Parse Xs}
      case Xs of unit then unit
      else
	 Pairs = {Map {String.tokens Xs &&} fun {$ X} {String.tokens X &=} end}
      in
	 {ListToRecord2 unit
	  {Map Pairs fun {$ Vs}
			%% keep the original charset!
			case Vs of [K V] then
			   {String.toAtom {PercentDecode K}}#{PercentDecode V}
			[] [K] then
			   {String.toAtom {PercentDecode K}}#""
			end
		     end
	  }
	 }
      end
   end

   fun {ListToRecord2 Lab Xs}
      Dict = {Dictionary.new}
      KeyCount = {Dictionary.new} %% needed to distinguish from strings
   in
      for K#V in Xs do
	 Dict.K := {Append {CondSelect Dict K nil} [V]}
	 KeyCount.K := {CondSelect KeyCount K 0} + 1
      end
      for K in {Dictionary.keys Dict} do
	 Multiple = {CondSelect KeyCount K 0} > 1
      in
	 %% if Multiple, then it is definitely a list.
	 %% if not, it could still be a one-element list,
	 %% but this has to be handled in app code, depending on expectations.
	 Dict.K := if Multiple then list(Dict.K) else Dict.K.1 end
      end
      {Dictionary.toRecord Lab Dict}
   end
   
   fun {PercentDecode Xs}
      case Xs of nil then nil
      [] &+|Xr then 32|{PercentDecode Xr}
      [] &%|D1|D2|Xr then {ParseHex [D1 D2]}|{PercentDecode Xr}
      [] X|Xr then X|{PercentDecode Xr}
      end
   end

   fun {ParseHex Xs}
      fun {Do Ys Acc}
	 case Ys of nil then Acc
	 [] Y|Yr then {Do Yr Acc*16 + {HexDigit Y}}
	 end
      end
   in
      {Do Xs 0}
   end

   fun {HexDigit X}
      if X >= &0 andthen X =< &9 then X-&0
      elseif X >= &a andthen X =< &F then 10 + X-&a
      elseif X >= &A andthen X =< &F then 10 + X-&A
      end
   end
   
   fun {PercentEncode Xs}
      case Xs of nil then nil
      [] X|Xr then
	 if {Char.isDigit X} orelse {Member X [&- &_ &.	&~]}
	    orelse X >= &a andthen X =< &z
	    orelse X >= &z andthen X =< &Z then
	    X|{PercentEncode Xr}
	 else
	    {Append &%|{ToHex2 X} {PercentEncode Xr}}
	 end
      end
   end

   fun {ToHex2 X}
      [{ToHex1 X div 16} {ToHex1 X mod 16}]
   end

   fun {ToHex1 X}
      if X >= 0 andthen X =< 9 then &0 + X
      elseif X >= 10 andthen X =< 15 then &A + X - 10
      end
   end
end
