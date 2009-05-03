%%
%% Decode data from UTF-8 JSON text to Oz objects.
%% Encode (certain) Oz objects to UTF-8 JSON text.
%%
%% JSON objects are decoded to records with the label 'object'.
%% JSON arrays are decoded to tuples with the label 'array'.
%%
%% See also UTF8.oz for different UTF-8 decoders.
%%
%% (c) 2008 Wolfgang Meyer, Wolfgang.Meyer@gmx.net
%%
functor
import
   UTF8
   Search
   Util(concat:Concat toHex:ToHex interlace:Interlace replicate:Replicate
	replaceElem:ReplaceElem floatToString2:FloatToString2
	almostEqualFloats:AlmostEqualFloats
	makeRecordFromAssocList:MakeRecordFromAssocList)
   Stack
export
   Decode %% decode using loose utf8 decoding
   DecodeWith %% decode with custom character decoding
   
   Encode %% encode to JSON in UTF-8
   Print %% encode to JSON in UTF-8 with pretty printing
   EncodeWith %% encode with custom character encoding
   PrintWith %% print with custom character encoding
   GenericEncode
   
   GetPrinter

   Equal %% compare JSON objects for equality (with approximate comparison for doubles)
define
   %% JSON literal in UTF-8
   %%  =>  Oz record (if toplevel is object) or list (if toplevel is array)
   %% Strings in the result are encoded in ISO 8859-1 (the native Oz encoding).
   %% Characters that could not be encoded are replaced by '?'.
   fun {Decode Xs}
      {DecodeWith UTF8.fromUTF8Loose Xs}
   end

   fun {DecodeWith CharacterDecoder Xs}
      Ys = {CharacterDecoder Xs}
      proc {SearchProc R}
	 choice
	    R={Object Ys nil}
	 [] R={Array Ys nil}
	 end
      end
   in
      case {Search.base.one SearchProc} of [X] then X else unit end
   end

   %%
   %% Meta rules
   %%
   fun {OneOrMore What Sep In ?Res}
      {ManyInternal What Sep In false Res}
   end

   fun {Many What Sep In ?Res}
      {ManyInternal What Sep In true Res}
   end

   fun {ManyInternal What Sep In ZeroAllowed ?Res}
      choice
	 In2 R
      in
	 R = {What In In2}      
	 choice In3 in
	    {Sep In2 In3}
	    R|{OneOrMore What Sep In3 Res}
	 [] Res = In2
	    [R]
	 end
      [] % special case: no occurence (not involved in recursion)
	 ZeroAllowed=true
	 Res=In
	 nil
      end
   end


   %%
   %% JSON parsing
   %%
   fun {JSONValue In ?Res}
      choice
	 {Object In Res}
      [] {Array In Res}
      [] {QuotedString In Res}
      [] {Number In Res}
      [] {BoolValue In Res}
      [] {Null In Res}
      end
   end

   %% parsing separators
   
   fun {Skip Pred In}
      case In of H|T then
	 if {Pred H} then {Skip Pred T}
	 else In
	 end
      else nil
      end
   end

   fun {IsWhiteSpace C}
      C==&\n orelse C==&  orelse C==&\n orelse C==&\r
   end

   %% "Structural chars" can have white space around them
   fun {CreateStructuralChar C}
      proc {$ In ?Res}
	 In2 In3
      in
	 {Skip IsWhiteSpace In In2}
	 In2 = C|In3
	 {Skip IsWhiteSpace In3 Res}
      end
   end

   OpenBracket = {CreateStructuralChar &[}
   CloseBracket = {CreateStructuralChar &]}
   OpenCurlyBrace = {CreateStructuralChar &{}
   CloseCurlyBrace = {CreateStructuralChar &}}
   Colon = {CreateStructuralChar &:}
   Comma = {CreateStructuralChar &,}

   %% parsing strings
   
   fun {TakeString In ?Res}
      case In of &"|R then Res=R nil
	 %% leave escaped unicode alone
      [] &\\|&u|A1|A2|A3|A4|R then
	 &\\|&u|{Char.toLower A1}|{Char.toLower A2}|{Char.toLower A3}|
	 {Char.toLower A4}|{TakeString R Res}
	 %% convert escaped chars to real chars
      [] &\\|X|R then
	 case X of &" then &"
	 [] &\\ then &\\
	 [] &/ then &/
	 [] &b then &\b
	 [] &f then &\f
	 [] &n then &\n
	 [] &r then &\r
	 [] &t then &\t
	 else fail
	 end|{TakeString R Res}
      [] X|R then if X<20 then fail else X|{TakeString R Res} end
      [] nil then fail
      end
   end

   fun {QuotedString In ?Res}
      In2
   in
      In = &"|In2
      {TakeString In2 Res}
   end

   %% null, boolean values
   
   fun {Null In ?Res}
      In = &n|&u|&l|&l|Res
      null
   end

   fun {BoolValue In ?Res}
      choice
	 In = &t|&r|&u|&e|Res
	 true
      []
	 In = &f|&a|&l|&s|&e|Res
	 false
      end      
   end

   %% numbers
   
   fun {Number In ?Res}
      if In.1 == &- then
	 ~{UnsignedNumber In.2 Res}
      else
	 {UnsignedNumber In Res}
      end
   end

   fun {NonZeroDigit In ?Res}
      D
   in
      In = D|Res
      (D \= &0)=true
      {Char.isDigit D}=true
      D - &0
   end

   fun {Digit In ?Res}
      D
   in
      In = D|Res
      {Char.isDigit D}=true
      D - &0
   end

   fun {UnsignedInt In ?Res}
      if In.1 == &0 then
	 Res=In.2
	 0
      else
	 In2 Digits
      in
	 Digits = {NonZeroDigit In In2}|{TakeDigits In2 Res}
	 {FoldL Digits fun {$ Z X} Z*10+X end 0}
      end
   end

   fun {TakeDigits In ?Res}
      {Map
       {List.takeDropWhile In Char.isDigit $ Res}
       fun {$ D} D-&0 end
      }
   end

   fun {Exponent In ?Res}
      Digits = {TakeDigits In Res}
   in
      Digits = _|_
      {Int.toFloat {FoldL Digits fun {$ Z X} Z*10+X end 0}}
   end

   fun {UnsignedFloatNumber In ?Res}
      In2 In3
      X1 X2 X3
      HasPoint HasE
   in
      X1 = {Int.toFloat {UnsignedInt In In2}}
      X2 = X1 + {AfterPoint In2 In3 HasPoint}
      X3 = X2 * {ExpFactor In3 Res HasE}
      (HasPoint orelse HasE) = true
      X3
   end

   fun {GetSign In ?Res}
      In2 S
   in
      In = S|In2
      choice S=&+ Res=In2 1.0
      [] S=&- Res=In2 ~1.0
      [] Res=In 1.0
      end
   end

   fun {E}
      choice &e [] &E end
   end

   fun {ExpFactor In ?Res ?HasE}
      choice In2 In3 Sign in
	 In = {E}|In2
	 HasE = true
	 Sign = {GetSign In2 In3}
	 {Pow 10.0 Sign*{Exponent In3 Res}}
      [] HasE = false
	 Res = In
	 1.0
      end
   end

   fun {NoSep X}
      X
   end

   fun {AfterPoint In ?Res ?HasPoint}
      D In2
   in
      In = D|In2
      if D == &. then
	 AfterPointDigits in
	 AfterPointDigits = {OneOrMore Digit NoSep In2 Res}
	 HasPoint = true
	 {FoldL AfterPointDigits
	  fun {$ S#F X} (S+F*{Int.toFloat X})#(F/10.0) end
	  0.0#0.1
	 }.1
      else
	 Res = In
	 HasPoint = false
	 0.0
      end
   end

   UnsignedIntNumber = UnsignedInt

   fun {UnsignedNumber In ?Res}
      choice
	 {UnsignedFloatNumber In Res}
      []
	 {UnsignedIntNumber In Res}
      end
   end

   %% objects and arrays
   
   fun {KeyValuePair In ?Res}
      In2 In3
      K V
   in
      K = {QuotedString In In2}
      {Colon In2 In3}
      V = {JSONValue In3 Res}
      K#V
   end

   fun {Object In ?Res}
      In2 In3
      Pairs
   in
      {OpenCurlyBrace In In2}
      Pairs = {Many KeyValuePair Comma In2 In3}
      {CloseCurlyBrace In3 Res}
      {MakeRecordFromAssocList object
       {Map Pairs fun {$ K#V} {String.toAtom K}#V end}}
   end

   fun {Array In ?Res}
      In2 In3 Values
   in
      {OpenBracket In In2}
      Values = {Many JSONValue Comma In2 In3}
      {CloseBracket In3 Res}
      {List.toTuple array Values}
   end

   %%
   %% JSON printing
   %%

   %% Oz record or list which represents a valid JSON value (with strings in ISO 8859-1)
   %%  =>  JSON literal in UTF-8 (printed compactly)
   fun {Encode O}
      {EncodeWith UTF8.toUTF8 O}
   end

   fun {Print O}
      {PrintWith UTF8.toUTF8 O}
   end

   fun {EncodeWith CharacterEncoder O}
      {GenericEncode CompactPrinter CharacterEncoder O}
   end

   fun {PrintWith CharacterEncoder O}
      {GenericEncode {CreatePrettyPrinter} CharacterEncoder O}
   end

   fun {GenericEncode Printer CharacterEncoder O}
      {CharacterEncoder
       {Printer
	{EncodeInternal O}#newline}
      }
   end
   
   fun {GetPrinter Type}
      case Type of compact then CompactPrinter
      [] pretty then {CreatePrettyPrinter}
      end
   end
   
   fun {CreatePrettyPrinter}
      N = {NewCell 0} %% current column
      I = {Stack.new [0]} %% recent indentations
      fun {PrettyPrinter X}
	 case X of '#'(...) then
	    {Record.map X PrettyPrinter}
	 [] newline then N:=0 "\n" 
	 [] indent then N:={Stack.top I} {Replicate &  @N}
	 [] space then N:=@N+1 [& ]
	 [] beginIndent then {Stack.push I @N} ""
	 [] endIndent then {Stack.pop I} ""
	 [] Txt then N:=@N+{Length Txt} Txt
	 end
      end
   in
      fun {$ X}
	 {VirtualString.toString {PrettyPrinter X}}
      end
   end

   fun {CompactPrinter Y}
      fun {Do X}
	 case X of '#'(...) then
	    {Record.map X CompactPrinter}
	 [] newline then nil
	 [] indent then nil
	 [] space then nil
	 [] beginIndent then nil
	 [] endIndent then nil
	 [] Txt then Txt
	 end
      end
   in
      {VirtualString.toString {Do Y}}
   end

   %% result: virtual strings with 'special' atoms
   fun {EncodeInternal O}
      case O of object(...) then {EncodeObject {Record.toListInd O}}
      [] array(...) then {EncodeArray {Record.toList O}}
      [] true then "true"
      [] false then "false"
      [] null then "null"
      else
	 if {IsFloat O} then {ReplaceElem &~ &- {FloatToString2 O 15}}
	 elseif {IsInt O} then {ReplaceElem &~ &- {IntToString O}}
	 else {EncodeString O}
	 end
      end
   end

   fun {EncodeString Xs}
      {VirtualString.toString
       "\""#{EscapeString Xs}#"\""}
   end

   fun {EncodeObject Xs}
      case Xs of nil then "{}"
      else
	 "{"#space#beginIndent#newline#
	 {Interlace
	  ","#newline
	  {Map Xs
	   fun {$ F#V}
	      indent#{EncodeString {AtomToString F}}#":"#space#
	      beginIndent#{EncodeInternal V}#endIndent
	   end}
	 }#newline#
	 endIndent#indent#"}"
      end
   end

   fun {EncodeArray Xs}
      case Xs of nil then "[]"
      else
	 "["#space#beginIndent#newline#
	 {Interlace
	  ","#newline
	  {Map Xs
	   fun {$ V}
	      indent#{EncodeInternal V}
	   end}
	 }#newline#
	 endIndent#indent#"]"
      end
   end
   
   fun {EscapeString Xs}
      case Xs of nil then nil
	 %% leave escaped unicode alone (might be originally escaped or might be unicode
	 %% chars that can not be represented in ISO 8859-1)
      [] &\\|&u|H1|H2|H3|H4|Xr then &\\|&u|H1|H2|H3|H4|{EscapeString Xr}
      [] X|Xr then
	 case X of &" then &\\|&"|{EscapeString Xr}
	 [] &\\ then &\\|&\\|{EscapeString Xr}
	 [] &\n then &\\|&n|{EscapeString Xr}
	 [] &\r then &\\|&r|{EscapeString Xr}
	 [] &\t then &\\|&t|{EscapeString Xr}
	 [] &\f then &\\|&f|{EscapeString Xr}
	 [] &\b then &\\|&b|{EscapeString Xr}
	 elseif X < 32 then
	    %% here we assume unicode
	    {Concat ["\\u" {ToHex X 4} {EscapeString Xr}]}
	 else X|{EscapeString Xr}
	 end
      end
   end

   
   %% comparison
   
   local
      fun {EqualJSONRecords A B}
	 {Arity A} == {Arity B} andthen
	 {All {Arity A} fun {$ F} {Equal A.F B.F} end}
      end
   in
      fun {Equal A B}
	 case A#B of
	    object(...)#object(...) then {EqualJSONRecords A B}
	 [] array(...)#array(...) then  {EqualJSONRecords A B}
	 [] null#null then true
	 [] true#true then true
	 [] false#false then true
	 else
	    if {IsInt A} andthen {IsInt B} then A==B
	    elseif {IsString A} andthen {IsString B} then A==B
	    elseif {IsFloat A} andthen {IsFloat B} then {AlmostEqualFloats A B}
	    else false
	    end
	 end
      end
   end
end
