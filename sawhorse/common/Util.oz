functor
import
   ExtraString(lstrip:LStrip split:Split) at 'x-oz://system/String.ozf'
   Open
   Finalize
   Regex at 'x-oz://contrib/regex'
export
   LazyRead
   Lines
   Words
   Concat
   ConcatMap
   FilterRecordsByLabel
   ListToLookup
   TupleLessThan
   CommaSep
   RegexGroups
   Extension
   FormatTime
   ConcatVS
   Replicate
   Intersperse
   Intercalate
   BeginsWith
   EndsWith
   CompareCaseInsensitive
   NubBy
   Nub
   RemoveTrailingSlash
   TupleAdd
define
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
   
   fun {Lines Xs}
      {String.tokens
       {Filter Xs fun {$ C} C \= 13 end}
       &\n}
   end

   fun {Words Xs}
      {Split Xs unit} 
   end

   fun {Concat Xs}
      {FoldR Xs Append nil}
   end

   fun {ConcatMap Xs F}
      {Concat {Map Xs F}}
   end

   fun lazy {FilterRecordsByLabel Lab Rs}
      {Filter Rs fun {$ R} {Label R} == Lab end}
   end

   fun {ListToLookup Xs}
      {List.toRecord unit {Map Xs fun {$ X} {Label X}#X end}}
   end
   
   fun {TupleLessThan T1 T2}
      for I in {Arity T1} return:R default:false do
	 if T1.I < T2.I then {R true}
	 elseif T1.I > T2.I then {R false}
	 end
      end
   end

   fun {Intersperse Xs Y}
      case Xs of nil then nil
      [] [X] then [X]
      [] X|Xr then X|Y|{Intersperse Xr Y}
      end
   end

   fun {Intercalate Xss Ys}
      {Concat {Intersperse Xss Ys}}
   end
   
   fun {CommaSep S}
      {Map
       {String.tokens {Map S Char.toLower} &,}
       fun {$ T} {LStrip T unit} end
      }
   end

   fun {RegexGroups RE L}
      {Regex.groups {Regex.search RE L} L}
   end

   fun {Extension Filename}
      fun {Go Xs Acc}
	 case Xs of nil then nil
	 [] &.|_ then Acc
	 [] X|Xr then {Go Xr X|Acc}
	 end
      end
   in
      {Go {Reverse Filename} nil}
   end

   local
      WeekDay = weekDay(0:"Sun" 1:"Mon" 2:"Tue" 3:"Wed" 4:"Thu" 5:"Fri" 6:"Sat")
      Month = month(0:"Jan" 1:"Feb" 2:"Mar" 3:"Apr" 4:"May" 5:"Jun"
	    6:"Jul" 7:"Aug" 8:"Sep" 9:"Oct" 10:"Nov" 11:"Dec")
      fun {Padded I}
	 S = {IntToString I}
      in
	 case S of [_ _] then S
	 [] [D] then [&0 D]
	 end
      end
   in
      fun {FormatTime
	   time(hour:H mDay:MDay min:Min mon:Mon sec:Sec wDay:WDay year:Year ...)}
	 {VirtualString.toString
	  WeekDay.WDay#", "#{Padded MDay}#" "#Month.Mon#" "#
	  (1900+Year)#" "#{Padded H}#":"#{Padded Min}#":"#Sec#" GMT"}
      end
   end

   fun {ConcatVS Xs}
      case Xs of nil then nil
      else {List.toTuple '#' Xs}
      end
   end

   fun {Replicate N Fun}
      for _ in 1..N collect:Collect do {Collect {Fun}} end
   end

   fun {BeginsWith Xs Start ?Remaining}
      {List.takeDrop Xs {Length Start} $ ?Remaining} == Start
   end

   fun {EndsWith Xs End}
      {List.drop Xs {Length Xs}-{Length End}} == End
   end

   fun {CompareCaseInsensitive A B}
      {Map A Char.toLower} == {Map B Char.toLower}
   end

   fun {NubBy EQ Xs}
      case Xs of nil then nil
      [] X|Xr then X|{NubBy EQ {Filter Xr fun {$ Y} {Not {EQ X Y}} end}}
      end
   end

   fun {Nub Xs}
      {NubBy Value.'==' Xs}
   end
   
   fun {RemoveTrailingSlash Xs}
      case Xs of nil then nil
      else if {List.last Xs} == &/ then {List.take Xs {Length Xs}-1}
	   else Xs
	   end
      end
   end   

   %% Add E as the last numeric element of tuple T.
   %% Non-numeric indices in T are allowed.
   fun {TupleAdd T E}
      Index = {FoldL {Filter {Arity T} IsInt} Max 0} + 1
   in
      {Adjoin
       unit(Index:E)
       T}
   end
end