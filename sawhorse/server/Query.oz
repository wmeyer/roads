%%
%% Decode a string of key value pairs as in HTTP requests.
%%
functor
export
   Parse
define
   fun {Parse Xs}
      case Xs of unit then unit
      else
	 Pairs = {Map {String.tokens Xs &&} fun {$ X} {String.tokens X &=} end}
      in
	 {List.toRecord unit
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
end
