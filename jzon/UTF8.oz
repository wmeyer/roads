%% Translation to/from UTF-8
%% from/to IS0 8859-1, Mozart's native encoding.
%% Some additional iso encoding are used (see utf2iso.dat).
%%
%% Based on TkTranslator.oz, which is part of QTk by Donatien Grolaux.
functor
require
   Compiler
   Util(concat:Concat
	toHex:ToHex fromHex:FromHex)
export
   ToUTF8

   FromUTF8Strict %% throws if it encounters chars which cannot be encoded in ISO 8859-1
   FromUTF8Loose  %% replaces such characters with "?"
   FromUTF8Preserving %% replaces such charactera with one or two "\uabcd" sequences
   %% ToUTF8 translates such sequences back to the original representation.

   %% {ToUTF8 {FromUTF8Preserving X}} == X
   %% except that \u sequences in X will be unescaped in the result
   %% (except for control chars)
   
   FromUTF32ToUTF8
   FromUTF8ToUTF32

   CodePointToUTF32
   CodePointToUTF8
prepare
   \insert utf2iso.dat
  
   PatternDict={NewDictionary}
   InvDict={NewDictionary}
   proc{Put D L C}
      case L
      of X|nil then
	 {Dictionary.put D X C}
      [] X1|X2|Xs then
	 T={Dictionary.condGet D X1 unit}
      in
	 if T\=unit then
	    {Put T X2|Xs C}
	 else
	    T={NewDictionary}
	 in
	    {Dictionary.put D X1 T}
	    {Put T X2|Xs C}
	 end
      end
   end
   
   proc{Loop Data}
      S R2
      {List.takeDropWhile Data fun{$ C} C>=32 end S R2}
   in
      if S\="" then
	 L R {List.takeDropWhile S fun{$ C} C\=&: end L R}
	 C={Compiler.evalExpression L nil _}
	 V={Compiler.evalExpression R.2 nil _}
      in
	 {Put PatternDict V C}
	 {Dictionary.put InvDict C V}
	 {Loop {List.dropWhile R2 fun{$ C} C<32 end}
}
      end
   end
   
   fun{ToRecord D}
      if {Dictionary.is D} then
	 {Record.map
	  {Dictionary.toRecord c D}
	  ToRecord}
      else
	 D
      end
   end
   {Loop Data}
   
   DU2I={ToRecord PatternDict}
   DI2U={Dictionary.toRecord c InvDict}

   fun{Match D L S}
      if L==nil then false
      else
	 R={CondSelect D L.1 false}
      in
	 if R\=false then
	    if {Record.is R} then
	       {Match R L.2 S}
	    else
	       S=L.2
	       R
	    end
	 else R end
      end
   end

   %% Returns the first code point of the UTF-8 sequence Xs.
   %% The remaining sequence is returned in Res.
   fun {TakeCodePoint Xs ?Res}
      case Xs of X|Xr then
	 if X =< 127 then
	    Res=Xr
	    X
	 else case Xr of X2|Xs then
		 if X >= 194 andthen X =< 223 then
		    Res=Xs
		    (X-192)*64 + (X2-128)
		 else case Xs of X3|Xt then
			 if X >= 224 andthen X =< 239 then
			    Res=Xt
			    (X-224)*4096 + (X2-128)*64 + (X3-128)
			 else case Xt of X4|Xu then
				 if X >= 240 andthen X =< 244 then
				    Res = Xu
				    (X-0xf0)*0x40000 + (X2-128)*4096 + (X3-128)*64 + (X4-128)
				 end
			      end
			 end
		      end
		 end
	      end 
	 end
      end
   end

   fun {CodePointToUTF32 CP}
      [CP div 0x1000000
       (CP div 0x10000) mod 0x100
       (CP div 0x100 ) mod 0x100
       (CP mod 0x100)
      ]
   end
   
   fun {FromUTF8ToUTF32 Xs}
      case Xs of nil then nil
      else
	 Xr
	 CP = {TakeCodePoint Xs Xr}
      in
	 {Append
	  {CodePointToUTF32 CP}
	  {FromUTF8ToUTF32 Xr}
	 }
      end
   end

   %% Converts a unicode code point to its UTF-8 sequence.
   fun {CodePointToUTF8 X}
      if X =< 0x7f then [X]
      elseif X >= 0x80 andthen X =<0x07ff then
	 [(192 + X div 64) (128 + X mod 64)] 
      elseif X >= 0x0800 andthen X =< 0xffff then
	 [224 + X div 0x1000
	  128 + (X div 64) mod 64
	  128 + X mod 64
	 ]
      elseif X >= 0x10000 andthen X =< 0x10ffff then
	 [240 + X div 0x40000
	  128 + (X div 0x1000) mod 64
	  128 + (X div 64) mod 64
	  128 + X mod 64
	 ]
      else raise utf8(illegalCodePoint(X)) end
      end
   end

   fun {FromUTF32ToUTF8 Xs}
      case Xs of nil then nil
      [] B1|B2|B3|B4|Xr then
	 CP = B4 + B3*0x100 + B2*0x10000 + B1*0x1000000
      in
	 {Append {CodePointToUTF8 CP} {FromUTF32ToUTF8 Xr}}
      else
	 raise utf8(utf32EncodingError(Xs)) end
      end
   end
   
   fun {CalculateUTF16SurrogatePair S}
      if S >= 0x10000 andthen S =< 0x10ffff then
	 R = S-0x10000
      in
	 ((R div 0x400) + 0xd800)
	 #
	 ((R mod 0x400) + 0xdc00)
      else
	 raise utf8(illegalUnicodeCodePoint(S)) end
      end
   end

   fun {IsUTF16SurrogatePair HI LO}
      HI >= 0xd800 andthen HI =< 0xdbff andthen
      LO >= 0xdc00 andthen LO =< 0xdfff
   end
   
   fun {FromUTF16SurrogatePair HI LO}
      if {IsUTF16SurrogatePair HI LO} then
	 ((HI - 0xd800) * 0x400) + (LO - 0xdc00) + 0x10000
      else
	 raise utf8(illegalSurrogatePair(HI LO)) end
      end
   end

   %% Converts a unicode code point to a \u escape sequence
   fun {EscapeUTF8 CP}
      if CP =< 0xffff then
	 {Append "\\u" {ToHex CP 4}}
      else
	 SP1#SP2 = {CalculateUTF16SurrogatePair CP}
      in
	 {Concat ["\\u" {ToHex SP1 4}
		  "\\u" {ToHex SP2 4}]}
      end
   end

   %% Create a UTF-8 decoder function.
   fun {CreateFromUTF8 Mode}
      fun{U2I T}
	 case T of nil then nil
	 [] T1|TR then
	    if T1 =< 127 then
	       T1|{U2I TR}
	    else
	       Res
	       R = {Match DU2I T ?Res}
	    in
	       if R \= false then %% can be converted
		  R|{U2I Res}
	       else
		  case Mode
		  of strict then
		     raise utf8(cannotEncode(T)) end
		  [] loose then Res in
		     _ = {TakeCodePoint T ?Res}
		     &?|{U2I Res}
		  [] preserving then Res
		     CP = {TakeCodePoint T ?Res}
		  in
		     {Append {EscapeUTF8 CP} {U2I Res}}
		  end
	       end
	    end
	 end
      end
   in
      U2I
   end

   FromUTF8Strict = {CreateFromUTF8 strict}
   FromUTF8Loose = {CreateFromUTF8 loose}
   FromUTF8Preserving = {CreateFromUTF8 preserving}
   
   fun{Conv Data}
      fun{I2U T}
	 if T==nil then nil
	 else
	    R={CondSelect Data T.1 false}
	 in
	    if R==false then
	       T.1|{I2U T.2}
	    else
	       {Append R {I2U T.2}}
	    end
	 end
      end
   in
      I2U
   end

   fun {MustBeEscaped C}
      C < 32 orelse C == &" orelse C == &\\
   end
   
   %% Replace \u escape sequences with their direct UTF-8 encoding.
   %% Xs: UTF-8 sequence with u-escaped chars.
   %% Result: UTF-8 sequence without u-escaped chars except for control chars.
   fun {ReplaceEscSeqs Xs}
      case Xs of nil then nil
      [] &\\|&u|H1|H2|H3|H4|&\\|&u|I1|I2|I3|I4|Xr then
	 SP1 = {FromHex [H1 H2 H3 H4]}
	 SP2 = {FromHex [I1 I2 I3 I4]}
      in
	 if {IsUTF16SurrogatePair SP1 SP2} then
	    CP = {FromUTF16SurrogatePair SP1 SP2}
	 in
	    if {MustBeEscaped CP} then
	       &\\|&u|H1|H2|H3|H4|&\\|&u|I1|I2|I3|I4|{ReplaceEscSeqs Xr}
	    else
	       {Append {CodePointToUTF8 CP}
		{ReplaceEscSeqs Xr}
	       }
	    end
	 else
	    {Append
	     if {MustBeEscaped SP1} then
		&\\|&u|H1|H2|H3|H4|nil
	     else
		{CodePointToUTF8 SP1}
	     end
	     {ReplaceEscSeqs &\\|&u|I1|I2|I3|I4|Xr}
	    }
	 end
      [] &\\|&u|H1|H2|H3|H4|Xr then
	 CP = {FromHex [H1 H2 H3 H4]}
      in
	 if {MustBeEscaped CP} then
	    &\\|&u|H1|H2|H3|H4|{ReplaceEscSeqs Xr}
	 else
	    {Append {CodePointToUTF8 CP} {ReplaceEscSeqs Xr}}
	 end
      [] X|Xr then X|{ReplaceEscSeqs Xr}
      end
   end
      
   I2UF = {Conv DI2U}
   
   fun {ToUTF8 Xs}
      {ReplaceEscSeqs
       {I2UF Xs}
      }
   end
end
