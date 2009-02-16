%% Implementation of red-black trees.
functor
export
   Instantiate
   Standard

define
   fun {Instantiate LessThanP EqualP}

      fun {New} leaf end
      
      fun {IsEmpty Tree} case Tree of leaf then true else false end end

      fun {Equal Tree1 Tree2}
	 {ToOrderedList Tree1} == {ToOrderedList Tree2}
      end
   
      fun {Insert Tree Key Value}
	 fun {Ins TT}
	    case TT of leaf then
	       node(color:red left:leaf key:Key value:Value right:leaf)
	       
	    [] node(color:C left:L key:B value:W right:R) then
	       if {LessThanP Key B} then % insert into left subtree
		  {Balance node(color:C left:{Ins L} key:B value:W right:R)}
	       elseif {EqualP Key B} then
		  node(color:C left:L key:Key value:Value right:R)
	       else % insert into right subtree
		  {Balance node(color:C left:L key:B value:W right:{Ins R})}
	       end
	    end
	 end
      in
	 {Blacken {Ins Tree}}
      end

      fun {InsertCombine unit(tree:Tree key:Key value:Value combine:Combine default:Default)}
	 OldValue = {CondLookup Tree Key Default}
      in
	 {Insert Tree Key {Combine OldValue Value}}
      end
      
      fun {Delete Tree Key}
	 fun {Del N}
	    case N of leaf then leaf
	    [] node(color:_ left:A key:Y value:V right:B) then
	       if {LessThanP Key Y} then {DelFormLeft A Y V B}
	       elseif {EqualP Key Y} then {App A B}
	       else {DelFormRight A Y V B}
	       end
	    end
	 end
	 fun {DelFormLeft A Y V B}
	    case A of node(color:black ...) then {BalLeft {Del A} Y V B}
	    else
	       node(color:red left:{Del A} key:Y  value:V right:B)
	    end
	 end
	 fun {DelFormRight A Y V B}
	    case B of node(color:black ...) then {BalRight A Y V {Del B}}
	    else
	       node(color:red left:A key:Y value:V right:{Del B})
	    end
	 end
      in
	 {Blacken {Del Tree}}
      end
      
      %% Return: Maybe Value
      fun {Lookup Tree Key}
	 case Tree
	 of leaf then nothing
	 [] node(color:_ left:L key:B value:V right:R) then
	    if {LessThanP Key B} then {Lookup L Key}
	    elseif {EqualP Key B} then just(V)
	    else {Lookup R Key}
	    end
	 end	 
      end 

      fun {LookupWithInsert Tree Key Default ?NewTree}
	 case {Lookup Tree Key}
	 of just(X) then
	    NewTree = Tree
	    X
	 [] nothing then
	    NewTree = {Insert Tree Key Default}
	    Default
	 end
      end

      fun {CondLookup Tree Key Default}
	 case {Lookup Tree Key}
	 of just(X) then X
	 [] nothing then Default
	 end
      end
      
      fun {HasKey T K}
	 {Lookup T K} \= nothing
      end

      %% Builds a tree from a list of pairs Key#Value.
      %% If a key is repeated, the last one wins.
      fun {FromList Xs}
	 {List.foldR Xs fun {$ K#V T} {Insert T K V} end {New}} 
      end

      %% Returns a list of Key#Value, sorted by Key.
      fun {ToOrderedList Tree}
	 case Tree of leaf then nil
	 [] node(left:L right:R key:K value:V ...) then
	    {Append {ToOrderedList L} (K#V)|{ToOrderedList R}}
	 end
      end

      fun {Items Tree}
	 case Tree of leaf then nil
	 [] node(left:L right:R value:V ...) then
	    {Append {Items L} V|{Items R}}
	 end
      end
      
      %% Number of nodes.
      fun {Size Tree}
	 fun {DoSize T S}
	    case T of leaf then S
	    [] node(left:L right:R ...) then
	       {DoSize L {DoSize R S+1}}
	    end
	 end
      in
	 {DoSize Tree 0}
      end

      fun {Map Tree F}
	 case Tree of leaf then leaf
	 [] node(left:L right:R value:V ...) then
	    {Adjoin Tree node(left:{Map L F} right:{Map R F} value:{F V})}
	 end
      end

      %%
      %% private
      %%

      fun {CheckInvariants Tree}
	 {CheckRedBlackProperty Tree} andthen
	 {CheckMaxDepth Tree}
      end
   
      fun {CheckMaxDepth Tree}
	 fun {GetDepthOfLeaves T D}
	    case T of leaf then [D]
	    [] node(left:L right:R ...) then {Append {GetDepthOfLeaves L D+1} {GetDepthOfLeaves R D+1} }
	    end
	 end

	 MaxDepth = {Float.toInt 2.0 * {LogN {Int.toFloat {Size Tree}+1} 2.0}}
      in
	 {List.all {GetDepthOfLeaves Tree 0} fun {$ X} X =< MaxDepth end}
      end

      fun {CheckRedBlackProperty Tree}
	 fun {IsBlack N}
	    case N of leaf then true
	    else N.color == black
	    end
	 end
      
	 fun {RedNodesHaveOnlyBlackChildren T}
	    case T of leaf then true
	    [] node(color:red left:L right:R ...) then
	       {IsBlack L} andthen {IsBlack R} andthen
	       {RedNodesHaveOnlyBlackChildren L} andthen {RedNodesHaveOnlyBlackChildren R}
	    [] node(color:black left:L right:R ...) then
	       {RedNodesHaveOnlyBlackChildren L} andthen {RedNodesHaveOnlyBlackChildren R}
	    end
	 end

	 fun {GetBlackDepthOfLeaves T D}
	    case T of leaf then [D] 
	    [] node(color:black left:L right:R ...) then
	       {Append {GetBlackDepthOfLeaves L D+1} {GetBlackDepthOfLeaves R D+1}}
	    [] node(color:red left:L right:R ...) then
	       {Append {GetBlackDepthOfLeaves L D} {GetBlackDepthOfLeaves R D}}
	    end
	 end
	 fun {CheckIt T}
	    {IsBlack T} andthen
	    {RedNodesHaveOnlyBlackChildren T} andthen
	    {ListAllEqual {GetBlackDepthOfLeaves T 0}}
	 end
      in
	 {CheckIt Tree}
      end

      fun {Blacken N}
	 case N of node(color:_ left:L key:K value:V right:R) then
	    node(color:black left:L key:K value:V right:R)
	 [] leaf then leaf
	 end
      end

      fun {Balance T}
	 case T
	    %% bal B (N R (N R t1 a1 t2) a2 t3) a3 t4
	    %% = N R (N B t1 a1 t2) a2 (N B t3 a3 t4)
	 of node(color:black
		 left:node(color:red
			   left:node(color:red left:T1 key:A1 value:V1 right:T2)
			   key:A2 value:V2 right:T3)
		 key:A3 value:V3 right:T4)
	 then
	    node(color:red left:node(color:black left:T1 key:A1 value:V1 right:T2)
		 key:A2 value:V2 right:node(color:black left:T3 key:A3 value:V3 right:T4))
	    
	    %% bal B (N R t1 a1 (N R t2 a2 t3)) a3 t4
	    %% = N R (N B t1 a1 t2) a2 (N B t3 a3 t4)
	 [] node(color:black
		 left:node(color:red left:T1 key:A1 value:V1
			   right:node(color:red left:T2 key:A2 value:V2 right:T3))
		 key:A3 value:V3 right:T4)
	 then
	    node(color:red left:node(color:black left:T1 key:A1 value:V1 right:T2)
		 key:A2 value:V2 right:node(color:black left:T3 key:A3 value:V3 right:T4))
	    
	    %% bal B t1 a1 (N R (N R t2 a2 t3) a3 t4)
	    %% = N R (N B t1 a1 t2) a2 (N B t3 a3 t4)
	 [] node(color:black left:T1 key:A1 value:V1
		 right:node(color:red
			    left:node(color:red left:T2 key:A2 value:V2 right:T3)
			    key:A3 value:V3 right:T4))
	 then
	    node(color:red left:node(color:black left:T1 key:A1 value:V1 right:T2)
		 key:A2 value:V2
		 right:node(color:black left:T3 key:A3 value:V3 right:T4))
	    
	    %% bal B t1 a1 (N R t2 a2 (N R t3 a3 t4))
	    %% = N R (N B t1 a1 t2) a2 (N B t3 a3 t4)
	 [] node(color:black left:T1 key:A1 value:V1
		 right:node(color:red
			    left:T2
			    key:A2
			    value:V2
			    right:node(color:red
				       left:T3 key:A3 value:V3 right:T4)))
	 then
	    node(color:red left:node(color:black left:T1 key:A1 value:V1 right:T2)
		 key:A2 value:V2
		 right:node(color:black left:T3 key:A3 value:V3 right:T4))
	    
	    %% bal c l a r = N c l a r
	 else
	    T
	 end
      end

      fun {BalLeft BL Y V C}
	 case BL of node(color:red left:A key:X value:W right:B) then
	    node(color:red left:node(color:black left:A key:X value:W right:B)
		 key:Y value:V right:C)
	 else
	    case C of node(color:black left:A key:X value:W right:B) then
	       {Balance node(color:black left:BL key:Y value:V
			     right:node(color:red left:A key:X value:W right:B))}
	       %% balleft bl y (T R (T B a x b) z c) = T R (T B bl y a) x (balance b z (sub1 c))
	    [] node(color:red left:node(color:black left:A key:X value:W right:B)
		    key:Z value:W2 right:C) then
	       node(color:red left:node(color:black left:BL key:Y value:V right:A)
		    key:X value:W
		    right:{Balance node(color:black left:B key:Z value:W2
					right:{Sub1 C})})
	    end
	 end
      end
      
      fun {BalRight A Y V BL}
	 case BL of node(color:red left:B key:X value:W right:C) then
	    node(color:red left:A key:Y value:V
		 right:node(color:black left:B key:X value:W right:C))
	 else
	    case A of node(color:black left:A key:X value:W right:B) then
	       {Balance node(color:black
			     left:node(color:red left:A key:X value:W right:B)
			     key:Y value:V right:BL)}
	    [] node(color:red left:A key:X value:W
		    right:node(color:black left:B key:Z value:W2 right:C)) then
	       node(color:red left:{Balance node(color:black left:{Sub1 A}
						 key:X value:W right:B)}
		    key:Z value:W2
		    right:node(color:black left:C key:Y value:V right:BL))
	    end
	 end
      end
      
      fun {Sub1 node(color:black left:A key:X value:V right:B)}
	 node(color:red left:A key:X value:V right:B)
      end
      
      fun {App T1 T2}
	 case T1#T2
	 of leaf#_ then T2
	 [] _#leaf then T1
	 [] node(color:red left:A key:X value:V right:B)#
	    node(color:red left:C key:Y value:W right:D) then
	    case {App B C}
	    of node(color:red left:B2 key:Z value:U right:C2) then
	       node(color:red left:node(color:red left:A key:X value:V right:B2)
		    key:Z value:U right:node(color:red left:C2 key:Y value:W
					     right:D))
	    [] BC then
	       node(color:red left:A key:X value:V
		    right:node(color:red left:BC key:Y value:W right:D))
	    end
	 [] node(color:black left:A key:X value:V right:B)#
	    node(color:black left:C key:Y value:W right:D) then
	    case {App B C}
	    of node(color:red left:B2 key:Z value:U right:C2) then
	       node(color:red left:node(color:black left:A key:X value:V right:B2)
		    key:Z value:U
		    right:node(color:black left:C2 key:Y value:W right:D))
	    [] BC then
	       {BalLeft A X V node(color:black left:BC key:Y value:W right:D)}
	    end
	 [] _#node(color:red left:B key:X value:V right:C) then
	    node(color:red left:{App T1 B} key:X value:V right:C)
	 [] node(color:red left:A key:X value:V right:B)#_ then
	    node(color:red left:A key:X value:V right:{App B T2})
	 end
      end
   in
      redblacktree(
	 new:New
	 isEmpty:IsEmpty
	 equal:Equal
	 insert:Insert
	 insertCombine:InsertCombine
	 delete:Delete
	 lookup:Lookup
	 condLookup:CondLookup
	 lookupWithInsert:LookupWithInsert
	 hasKey:HasKey
	 fromList:FromList
	 toOrderedList:ToOrderedList
	 items:Items
	 size:Size
	 map:Map
	 checkInvariants:CheckInvariants
	 )
   end

   %% A tree module that used < and ==
   Standard = {Instantiate Value.'<' Value.'=='}

   fun {ListAllEqual Xs}
      case Xs of X|Y|Xr then
	 X==Y andthen {ListAllEqual Y|Xr}
      [] [_] then true
      [] nil then true % does this make sense?
      end
   end

   fun {LogN X N}
      {Float.log X} / {Float.log N}
   end
end

