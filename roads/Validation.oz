functor
import
   Validator(create) at 'x-ozlib://wmeyer/roads/Validator.ozf'
export
   'class':Validation
define
   %% Keeps track of the validators of a form
   %% and can create a wrapped "action" function.
   class Validation
      attr
	 inInputTag
	 currentInputId
	 currentInputName
      feat
	 validators
      meth init
	 inInputTag := false
	 currentInputId := unit
	 currentInputName := unit
	 self.validators = {NewDictionary}
      end
      meth startInputTag
	 inInputTag := true
	 currentInputId := unnamed
      end
      meth endInputTag
	 inInputTag := false
	 currentInputId := unnamed
      end
      meth setCurrentInputId(Id)
	 if @inInputTag then
	    currentInputId := if {Atom.is Id} then Id else {String.toAtom Id} end
	 end
      end
      meth setCurrentInputName(N)
	 if @inInputTag then
	    currentInputName := if {Atom.is N} then N else {String.toAtom N} end
	 end
      end
      meth addValidator(Validator)
	 self.validators.@currentInputName := Validator#@currentInputId
      end
      meth with(F Res)
	 Res =
	 {FoldL {Dictionary.entries self.validators}
	  fun {$ F0 ParamName#(ValidatorSpec#ParamId)}
	     fun {$ S}
		V = {S.getParam ParamName}.original
		ValFun = if {Procedure.is ValidatorSpec} then ValidatorSpec
			 else {Validator.create ValidatorSpec}
			 end
	     in
		case {ValFun ParamId V}
		of true then {F0 S}
		[] false then "Validation of field \""#ParamId#"\" failed."
		[] 'false'(Xs) andthen {VirtualString.is Xs} then Xs
		[] 'false'(F) andthen {Procedure.is F} then {F S}
		end
	     end
	  end
	  F}
      end
   end
end

