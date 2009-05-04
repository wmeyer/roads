%%
%% A class that colects information about the "bind" and "validate" attributes of
%% the input tags of a form element and creates a wrapper function that
%% validates and/or binds every input tag in order of textual appearance.
%%
functor
import
   Validator(create) at 'x-ozlib://wmeyer/roads/Validator.ozf'
export
   'class':FormValidator
define
   fun {ValidationWrapper TagInfo F0}
      fun {$ S}
	 if {Not {HasFeature TagInfo validate}} then {F0 S}
	 else
	    TagVal = TagInfo.validate
	    ParamIdent = TagInfo.ident
	    V
	    ValFun
	 in
	    if {Procedure.is TagVal} then
	       V = {S.getParam TagInfo.name}.original
	       ValFun = TagVal
	    elseif {Label TagVal} == list then
	       V = {S.getParamAsList TagInfo.name}.original
	       ValFun = if {Procedure.is TagVal.1} then TagVal.1
			else {Validator.create TagVal}
			end
	    else
	       V = {S.getParam TagInfo.name}.original
	       ValFun = {Validator.create TagVal}
	    end
	    case {ValFun ParamIdent V}
	    of true then {F0 S}
	    [] false then "Validation of field \""#ParamIdent#"\" failed."
	    [] 'false'(Xs) andthen {VirtualString.is Xs} then Xs
	    [] 'false'(F) andthen {Procedure.is F} then {F S}
	    end
	 end
      end
   end

   fun {BindingWrapper TagInfo F0}
      fun {$ S}
	 if {HasFeature TagInfo bind} then
	    Binder = TagInfo.bind
	    Val
	    BindProc = {CreateBindProc Binder}
	 in
	    if {IsDet Binder} andthen {Record.is Binder} andthen {Label Binder} == list then
	       Val = {S.getParamAsList TagInfo.name}
	    else
	       Val = {S.getParam TagInfo.name}
	    end
	    {BindProc Val}
	 end
	 {F0 S}
      end
   end

   fun {CreateBindProc Binder}   
      proc {SimpleBinder V}
	 Binder = V
      end
      proc {ListBinder V}
	 Binder.1 = V
      end
   in
      if {IsFree Binder} then SimpleBinder %% single value -> free var
      elseif {Procedure.is Binder} then Binder %% single value -> proc
      elseif {Label Binder} == list then
	 if {IsFree Binder.1} then %% list -> free var
	    ListBinder
	 elseif {Procedure.is Binder.1} then %% list -> proc
	    Binder.1
	 else %% unif. of list with determined var
	    ListBinder
	 end
      else %% unification of single value with determined var
	 SimpleBinder
      end
   end
   
   class FormValidator
      attr
	 counter
	 tags
      meth init
	 counter := 0
	 tags := nil
      end

      %% precondition: InputTag has a bind attribute
      %% return: 'nothing' or just(the name of the input tag if generated)
      meth bind(InputTag ?GenTagName)
	 Binder = InputTag.bind
	 TagName
      in
	 if {HasFeature InputTag name} then GenTagName = nothing TagName = InputTag.name
	 else TagName = {self NewName($)} GenTagName = just(TagName)
	 end
	 tags := unit(name:TagName id:{CondSelect InputTag id unknown}
		      bind:Binder)
	 |@tags
      end

      %% precondition: InputTag has a validate attribute
      %% return: 'nothing' or just(the name of the input tag if generated)
      meth validate(InputTag ?GenTagName)
	 TagExists = {NewCell false}
	 %% TagIdent: user-visible identifier used for error messages
	 TagIdent = if {HasFeature InputTag name} then InputTag.name
		    else {CondSelect InputTag id unknown}
		    end
	 TagName
	 TagInfo = unit(name:TagName ident:TagIdent
			validate:InputTag.validate)
      in
	 if {HasFeature InputTag name} then
	    TagName = InputTag.name
	    GenTagName = nothing
	 elseif {HasFeature InputTag bind} then 
	    %% IF the tag has a bind attribute,
	    %% it MUST be the one we processed last.
	    TagExists := true
	    TagName = @tags.1.name
	    GenTagName = nothing
	 else
	    TagName = {self NewName($)}
	    GenTagName = just(TagName)
	 end
	 if @TagExists then
	    tags := {Adjoin @tags.1 TagInfo}|@tags.2
	 else
	    tags := TagInfo|@tags
	 end
      end

      meth with(F ?Res)
	 Res =
	 {FoldL @tags
	  fun {$ F0 TagInfo}
	     {ValidationWrapper TagInfo
	      {BindingWrapper TagInfo F0}
	     }
	  end
	  F
	 }
      end
      
      meth NewName(?N)
	 New
	 Old = counter := New
      in
	 New = Old+1
	 N = {VirtualString.toAtom roadsFormBinding#Old}
      end
   end
end
