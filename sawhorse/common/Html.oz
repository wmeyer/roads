functor
import
   Util(concatVS:ConcatVS)
   Css(toString:RenderCss)
   Javascript(convert:RenderJavascript) at 'x-ozlib://wmeyer/javascript/Javascript.ozf'
export
   Render
   RenderWith
   MapAttributes
   RemoveAttribute
   Escape
define
   fun {Render H}
      {RenderWith DefaultDocType H}
   end

   fun {RenderWith DocType H}
      {VirtualString.toString
       DocType#"\n"#{EscapeVariables {RenderElement H}}}
   end

   DefaultDocType =
   "<!DOCTYPE HTML PUBLIC \"-//W3C//DTD HTML 4.01//EN\" \"http://www.w3.org/TR/html4/strict.dtd\">"

   EmptyTags =
   [
    basefont 
    br 
    area 
    link 
    img 
    param 
    hr 
    input 
    isindex 
    base 
    meta 
    frame
   ]
   
   fun {RenderElement H}
      case H of '#'(...) then H % a virtual string
      [] '|'(...) then H % a string
      [] nil then H
      [] unit(...) then {ConcatVSMap {Record.toList H} RenderElement}
      [] noHtml then nil
      [] css(...) then {RenderCss H}
      [] javascript(...) then {RenderJavascript {Record.toList H}}
      else
	 Name = {AtomToString {Label H}}
	 AttribPart = {Record.filterInd H fun {$ F _} {IsAtom F} end}
	 ContentPart = {Record.filterInd H fun {$ F _} {IsInt F} end}
	 Content = {ConcatVSMap {Record.toList ContentPart} RenderElement}
	 Attrs = {ConcatVSMap {Record.toListInd AttribPart} RenderAttribute}
	 AttrStr = case Attrs of nil then nil else " "#Attrs end
      in
	 if {Member {Label H} EmptyTags} then
	    if Content \= nil then
	       raise html(tagShouldBeEmpty(tag:Name contents:Content)) end
	    end
	    "<"#Name#AttrStr#">"
	 else
	    "<"#Name#AttrStr#">"#Content
	    #"</"#Name#">"
	 end
      end
   end

   fun {ConcatVSMap Xs F} {ConcatVS {Map Xs F}} end

   fun {RenderAttribute Name#Value}
      Name#"=\""#Value#"\" "
   end

   RemoveAttribute = {NewName}
   
   fun {MapAttributes H TagNotifier Fun}
      case H of '#'(...) then H
      [] '|'(...) then H
      [] unit(...) then {Record.map H fun {$ E} {MapAttributes E TagNotifier Fun} end}
      else
	 {TagNotifier {Label H} open}
	 Res = 
	 {List.toRecord {Label H}
	  {Filter
	   {Map {Record.toListInd H}
	    fun {$ I#A}
	       if {IsAtom I} then {Fun I A H}
	       else I#{MapAttributes A TagNotifier Fun}
	       end
	    end
	   }
	   fun {$ I#_} I \= RemoveAttribute end
	  }
	 }
      in
	 {TagNotifier {Label H} close}
	 Res
      end
   end

   local
      M = {Dictionary.new}
      M.&& := "&amp;"
      M.&< := "&lt;"
      M.&> := "&gt;"
      M.&" := "&quot;"
      M.&' := "&#x27;"
      M.&/ := "&#x2F;"
   in
      fun {Escape Xs}
	 case Xs of nil then nil
	 [] X|Xr then
	    {Append {Dictionary.condGet M X [X]} {Escape Xr}}
	 end
      end
   end

   fun {EscapeVariables VS}
      case VS of externalInput(escaped:Xs ...) then Xs
      elseif {Record.is VS} then
	 {Record.map VS EscapeVariables}
      else VS
      end
   end
end
