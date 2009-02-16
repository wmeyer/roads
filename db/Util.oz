functor
export
   RecordMember AddToTuple RecordNarrow MapListToRecord RecordMap2 AdjoinN
   GroupBy Nub None Concat FoldL1
   SetDifference IsSubset CartesianNProduct
   Sum Maximum Minimum Avg
define
   %% tuple / records
   fun {RecordMember X R}
      for I in {Arity R} return:Ret default:false do
	 if R.I == X then {Ret true} end
      end
   end

   fun {AddToTuple T V}
      {AdjoinAt T {Width T}+1 V}
   end

   fun {RecordNarrow R Fs}
      {Record.filterInd R fun {$ I _} {Member I Fs} end}
   end

   fun {MapListToRecord L Xs F}
      {List.toRecord L
       {Map Xs
	fun {$ X} X#{F X} end
       }
      }
   end

   fun {RecordMap2 R F}
      {List.toRecord {Label R}
       {Map {Record.toList R} F}
      }
   end

   fun {AdjoinN Xs} %% with N >= 1
      {FoldL1 Xs Adjoin}
   end

   %% lists
   fun {Nub Xs}
      {Map {GroupBy Value.'==' Xs} fun {$ G} G.1 end}
   end

   fun {GroupBy Comparer Xs}
      fun {Do Ys Acc}
	 case Ys of nil then {Record.toList Acc}
	 [] Y|Yr then
	    NewAcc =
	    for I in {Arity Acc} default:{AddToTuple Acc [Y]} return:R do
	       Group = Acc.I
	    in
	       if {Comparer Group.1 Y} then
		  {R {AdjoinAt Acc I Y|Group}}
	       end
	    end
	 in
	    {Do Yr NewAcc}
	 end
      end
   in
      {Do Xs '#'}
   end

   fun {None Xs Pred}
      {Not {Some Xs Pred}}
   end

   fun {Concat XXs}
      {FoldR XXs Append nil}
   end

   fun {FoldL1 X|Xr Fun}
      {FoldL Xr Fun X}
   end

   
   %% sets
   
   fun {SetDifference As Bs}
      {Filter As fun {$ A} {Member A Bs} end}
   end

   fun {IsSubset As Bs}
      {All As fun {$ A} {Member A Bs} end}
   end

   fun {CartesianNProduct Zs}
      fun {Do Xs}
	 case Xs of nil then nil
	 [] [Ys] then {Map Ys fun {$ Y} [[Y]] end}
	 [] Ys|Xr then
	    Rs = {Concat {Do Xr}}
	 in
	    {Map Ys fun {$ Y} {Map Rs fun {$ R} Y|R end} end}
	 end
      end
   in
      {Concat {Do Zs}}
   end

   
   %% aggregators
   
   fun {Sum Xs} {FoldL Xs Number.'+' 0} end

   fun {Maximum Xs} {FoldL1 Xs Value.max} end

   fun {Minimum Xs} {FoldL1 Xs Value.min} end

   fun {Avg Xs}
      S = {Sum Xs} L = {Length Xs}
   in
      if {IsFloat S} then S / {IntToFloat L}
      else S div L
      end
   end
end
