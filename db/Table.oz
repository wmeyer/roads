%% Table ADT
functor
import
   RedBlackTree
export
   New CloneNew AddType RemoveType
   Map Fold Filter Partition ForAllRows
   SetRow CondGetRow HasRow GetRow
   ToList
define
   fun {IsRealTuple X} case X of '#'(_ ...) then true else false end end
   fun {LexicalLessThan Xs Ys}
      case Xs#Ys of nil#nil then false
      [] (_|_)#nil then false
      [] nil#(_|_) then true
      [] (X|Xr)#(Y|Yr) then
	 if X < Y then true
	 elseif X == Y then {LexicalLessThan Xr Yr}
	 else false
	 end
      end
   end
   
   RBT = RedBlackTree
   
   StringTree = {RBT.instantiate LexicalLessThan Value.'=='}
   TreeForType = unit(int:RBT.standard
		      float:RBT.standard
		      atom:RBT.standard
		      string:StringTree
		     )

   fun {GetLessThanOf T}
      case T of int then Value.'<'
      [] float then Value.'<'
      [] atom then Value.'<'
      [] string then LexicalLessThan
      else raise database(error:keyTypeNotSupported(T)) end
      end
   end

   fun {CreateTupleLessThan ElementComparers}
      fun {$ Tuple1 Tuple2}
	 for I in 1..{Width Tuple1} return:R default:false do
	    if {ElementComparers.I Tuple1.I Tuple2.I} then {R true}
	    elseif Tuple1.I == Tuple2.I then skip
	    else {R false}
	    end
	 end
      end
   end
   
   fun {GetTreeTypeFromKeyType K}
      if {IsRealTuple K} then
	 LessThanComparer = {Record.map K GetLessThanOf}
	 MyLessThan = {CreateTupleLessThan LessThanComparer}
      in
	 {RBT.instantiate MyLessThan Value.'=='}
      elseif {HasFeature TreeForType K} then TreeForType.K
      else raise database(error:keyTypeNotSupported(K)) end
      end
   end

   fun {New KeyType}
      TreeType = {GetTreeTypeFromKeyType KeyType}
   in
      table(type:TreeType data:{TreeType.new})
   end

   fun {AddType Table KeyType}
      table(type:{GetTreeTypeFromKeyType KeyType}
	    data:Table.data
	   )
   end

   fun {Map Table Fun}
      table(type:Table.type
	    data:{Table.type.map Table.data Fun}
	   )
   end

   fun {Fold Table Fun Init}
      {List.foldL {Table.type.items Table.data} Fun Init}
   end


   fun {SetRow Table Key Row}
      table(type:Table.type
	    data:{Table.type.insert Table.data Key Row}
	   )
   end

   proc {ForAllRows Table Proc}
      {ForAll {ToList Table} Proc}
   end

   fun {CondGetRow Table Key Default}
      {Table.type.condLookup Table.data Key Default}
   end

   local
      fun {DoFilter Type Tree Fun}
	 {Type.fromList {List.filter {Type.toOrderedList Tree}
			 fun {$ _#V} {Fun V} end}}
      end
   in
      fun {Filter Table Fun}
	 table(type:Table.type
	       data:{DoFilter Table.type Table.data Fun}
	      )
      end
   end

   local
      proc {DoPartition Type Tree Fun ?Result ?Other}
	 OtherList
      in
	 Result =
	 {Type.fromList
	  {List.partition {Type.toOrderedList Tree}
	   fun {$ _#V} {Fun V} end
	   $ OtherList}}
	 Other = {Type.fromList OtherList}
      end
   in
      proc {Partition Table Fun ?Result ?Other}
	 OtherData Data
      in
	 {DoPartition Table.type Table.data Fun Data OtherData}
	 Other = table(type:Table.type
		       data:OtherData)
	 Result = table(type:Table.type
			data:Data)
      end
   end

   fun {HasRow Table Key}
      {Table.type.hasKey Table.data Key}
   end

   fun {GetRow Table Key}
      case {Table.type.lookup Table.data Key}
      of just(X) then X
      end
   end

   fun {ToList Table}
      {Table.type.items Table.data}
   end

   %% Create an EMPTY version of Table
   fun {CloneNew Table}
      table(type:Table.type
	    data:{Table.type.new}
	   )
   end

   fun {RemoveType Table}
      table(type:unit
	    data:Table.data)
   end
end
