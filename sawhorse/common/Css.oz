functor
import
   Util(concatVS:ConcatVS
	intercalate:Intercalate
       )
export
   ToString
define

   fun {ToString CSS=css(Selector ...)}
      Selectors = if {List.is Selector} then Selector else [Selector] end
      Properties = {Record.toListInd {Record.subtract CSS 1}}
   in
      {VirtualString.toString
       {Intercalate {Map Selectors SelectorToString} ", "}#"\n{\n "#
       {Intercalate {Map Properties PropertyToString} ";\n "}#
       "\n}\n"
      }
   end

   fun {PropertyToString F#V}
      {VirtualString.toString F#":"#V}
   end

   fun {SelectorToString Sel}
      fun {RelatedTag Feature Sep}
	 case {CondSelect Sel Feature Nothing} of !Nothing then ""
	 [] Tag then {SelectorToString Tag}#Sep
	 end
      end
      NumberElements = {Record.toList {Record.filterInd Sel fun {$ I _} {Int.is I} end}}
   in
      {VirtualString.toString
       {RelatedTag descendentFrom " "}
       #
       {RelatedTag childOf " > "}
       #
       {RelatedTag preceededBy " + "}
       #
       {Label Sel}
       #
       case {CondSelect Sel 'class' Nothing} of !Nothing then ""
       [] Class then {ClassSelectorToString Class}
       end
       #
       {MapToVS NumberElements
	fun {$ E}
	   if {List.is E} then {AttributeSelectorToString E}
	   elseif {Record.is E} andthen {Atom.toString {Label E}}.1 == &: then
	      {PseudoClassToString E}
	   elseif {Atom.is E} then {ClassSelectorToString E}
	   end
	end
       }
      }
   end

   fun {MapToVS Xs F}
      {ConcatVS {Map Xs F}}
   end

   Nothing = {NewName}


   fun {ClassSelectorToString Class}
      "."#Class
   end
   
   fun {PseudoClassToString PC}
      if {HasFeature PC 1} then
	 {Label PC}#"("#PC.1#")"
      else
	 PC
      end
   end

   fun {AttributeSelectorToString AS}
      case AS of [Attr Op Value] then
	 "["#Attr#Op#"\""#Value#"\"]"
      [] [Attr] then
	 "["#Attr#"]"
      end
   end
end

