functor
export
   To
   From
define
   fun {To IZ}
      fun {Do X}
	 if X == 0  then nil
	 else
	    Y = X mod 62
	    Res = X div 62
	 in
	    {ToDigit Y}|{Do Res}
	 end
      end
      Z = IZ + 0x80000000
   in
      case Z of 0 then "0"
      else {Reverse {Do Z}}
      end
   end

   fun {From Ys}
      {FoldL Ys
       fun {$ Z Y}
	  Z*62 + {FromDigit Y}
       end
       0
      }
      - 0x80000000
   end

   fun {ToDigit X}
      if X >= 0 andthen X =< 9 then &0 + X
      elseif X >= 10 andthen X =< 35 then &A + X - 10
      elseif X >= 36 andthen X =< 61 then &a + X - 36
      end
   end

   fun {FromDigit X}
      if X >= &0 andthen X =< &9 then X - &0
      elseif X >= &A andthen X =< &Z then X - &A + 10
      elseif X >= &a andthen X =< &z then X - &a + 36
      end
   end
end
