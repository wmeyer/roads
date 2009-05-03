%% Some general utility functions.
functor
import
   Property
   Open
   Finalize
export
   ToHex
   FromHex
   Concat
   Interlace
   Replicate
   ReplaceElem
   AlmostEqualFloats
   FloatToString2
   MakeRecordFromAssocList
   LazyRead
define
   fun {Concat Xs}
      {FoldR Xs Append nil}
   end
   
   fun {UnfoldR Seed Fun}
      case {Fun Seed} of unit then nil
      [] A#NewSeed then A|{UnfoldR NewSeed Fun}
      end
   end

   fun {ToHexDigit N}
      %(N>=0 andthen N=<15)=true
      if N < 10 then &0 + N
      else &a + N - 10
      end
   end

   fun {FromHexDigit Y}
      X = {Char.toLower Y}
   in
      if X >= &0 andthen X =< &9 then X-&0
      elseif X >= &a andthen X =< &f then X-&a+10
      else raise util(illegalHexDigit(Y)) end
      end
   end
   
   fun {ToHex N ResultPlaces}
      (N >= 0)=true
      {Reverse
       {UnfoldR ResultPlaces#N
	fun {$ I#B}
	   if I > 0 then
	      {ToHexDigit B mod 16}
	      #
	      ((I-1)#(B div 16))
	   else unit
	   end
	end
       }
      }
   end

   fun {FromHex Xs}
      {FoldL
       {Map Xs FromHexDigit}
       fun {$ Z X} Z*16+X end 0
      }
   end
   
   fun {Interlace Sep Xs}
      case Xs of nil then nil
      [] [X] then X
      [] X|Xr then
	 X#Sep#{Interlace Sep Xr}
      end
   end

   fun {Replicate C N}
      case N of 0 then nil
      else C|{Replicate C N-1}
      end
   end

   fun {ReplaceElem Old New Xs}
      {Map Xs fun {$ X} if X == Old then New else X end end}
   end

   local
      MaxRelativeError = 0.00001
   in
      fun {AlmostEqualFloats A B}
	 if A == B then true
	 else
	    RelativeError = if {Abs B} > {Abs A} then {Abs (A-B)/B}
			    else {Abs (A-B)/A}
			    end
	 in
	    RelativeError =< MaxRelativeError
	 end
      end
   end

   fun {FloatToString2 F Precision}
      OldPrec = {Property.get 'print.floatPrecision'}
      R
   in
      {Property.put 'print.floatPrecision' Precision}
      R = {FloatToString F}
      {Property.put 'print.floatPrecision' OldPrec}
      R
   end

   %% Inverse to Record.toListInd.
   fun {MakeRecordFromAssocList Label Pairs}
      Features = {Map Pairs fun {$ F#_} F end}
      Obj = {Record.make Label Features}
   in
      for F#V in Pairs do
	 Obj.F = V
      end
      Obj
   end

   fun {LazyRead FN}
      InFile={New Open.file init(name:FN)}
      {Finalize.register InFile proc{$ F} {F close} end}
      fun lazy {LR} L T N in
	 {InFile read(list:L tail:T size:1024 len:N)}
	 if N==0 then T=nil {InFile close} else T={LR} end
	 L
      end
   in
      {LR}
   end
end
